/**
 * TEST 3 — Önerilen algoritma: PARÇALI SAYAÇ + BÖLÜK BÖLÜK KUYRUK.
 *
 * İki ayrı dert, iki ayrı çare:
 *
 *  1) Kontenjanı korumak SERİLEŞTİRME ister (Test 2). Tek sayaç yerine
 *     kontenjanı S parçaya bölüyoruz: `events/{id}/quota_shards/{0..S-1}`.
 *     Her parça kendi kapasitesini tutar, toplamları tam olarak kontenjandır.
 *     Öğrenci bir parçaya yazar → çekişme S kat azalır, toplam yine kesin.
 *     Parça dolarsa sıradaki parçaya geçilir; hepsi doluysa kontenjan
 *     gerçekten bitmiştir. Yani AŞIM DA EKSİK DE olmaz.
 *
 *  2) Kalan çekişmeyi de düşürmek için istemci hepsini birden salmaz:
 *     aynı anda en fazla K istek uçar (bölük bölük). Gerisi kuyrukta bekler.
 *
 * Bu test (S, K) çiftlerini tarayıp çalışan aralığı bulur.
 */

import {
  connect, RunLog, fireAtOnce, runThrottled, summarize, fmtRow, TABLE_HEADER,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_sharded';
const QUOTA = 500;
const MAX_ATTEMPTS = 5;

const log = new RunLog('03-sharded-queue');

/** Kontenjanı S parçaya bölerken artan payı ilk parçalara dağıt. */
function shardCapacities(quota, shards) {
  const base = Math.floor(quota / shards);
  const extra = quota % shards;
  return Array.from({ length: shards }, (_, s) => base + (s < extra ? 1 : 0));
}

async function prepareShards(db, eventId, quota, shards) {
  await resetEvent(db, eventId, { quota });
  const caps = shardCapacities(quota, shards);
  const batch = db.batch();
  caps.forEach((capacity, s) => {
    batch.set(db.doc(`events/${eventId}/quota_shards/${s}`), {
      count: 0,
      capacity,
    });
  });
  await batch.commit();
  return caps;
}

/** Bir öğrencinin kaydı: parça seç, dolu ise sıradakine yürü. */
async function registerSharded(db, eventId, uid, i, shards) {
  // Başlangıç parçası uid'den türetilir: yük parçalara eşit dağılsın.
  let hash = 0;
  for (let c = 0; c < uid.length; c++) hash = (hash * 31 + uid.charCodeAt(c)) | 0;
  const start = Math.abs(hash) % shards;

  let retries = 0;
  let shardsTried = 0;

  for (let step = 0; step < shards; step++) {
    const s = (start + step) % shards;
    const shardRef = db.doc(`events/${eventId}/quota_shards/${s}`);
    shardsTried += 1;

    let attempts = 0;
    try {
      await db.runTransaction(
        async (tx) => {
          attempts += 1;
          const snap = await tx.get(shardRef);
          const { count, capacity } = snap.data();
          if (count >= capacity) {
            const full = new Error('shard-full');
            full.code = 'shard-full';
            throw full;
          }
          tx.set(
            db.doc(`event_registrations/${registrationId(eventId, uid)}`),
            registrationPayload(eventId, uid, i, {
              title: 'Yuk Testi Etkinligi',
              clubId: 'loadtest_club',
              clubName: 'Yuk Testi Kulubu',
              deadlineAtMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
            }),
          );
          tx.update(shardRef, { count: count + 1 });
        },
        { maxAttempts: MAX_ATTEMPTS },
      );
      retries += attempts - 1;
      return { retries, shardsTried, shard: s };
    } catch (error) {
      retries += attempts - 1;
      if (error.code === 'shard-full') continue; // sıradaki parçaya yürü
      throw error;
    }
  }

  const full = new Error('quota-full');
  full.code = 'quota-full';
  throw full;
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 3 — PARÇALI SAYAÇ + BÖLÜK BÖLÜK KUYRUK');
  log.say('══════════════════════════════════════════════════════════════');
  log.say(`\nKontenjan: ${QUOTA} · her istek transaction ile yazıyor\n`);

  // ── A. Parça sayısı taraması (kuyruk YOK, hepsi aynı anda) ─────────
  log.say('A) Parça sayısının etkisi — 500 kişi AYNI ANDA, kuyruk yok');
  log.say('─'.repeat(104));
  log.say('parça'.padEnd(10) + TABLE_HEADER.slice(10) + '  kayıt');
  log.say('─'.repeat(104));

  for (const shards of [1, 4, 8, 16, 32, 64]) {
    await prepareShards(db, EVENT_ID, QUOTA, shards);
    const run = await fireAtOnce(500, (i) =>
      registerSharded(db, EVENT_ID, studentUid(i), i, shards),
    );
    const s = summarize(run);
    const stored = await countRegistrations(db, EVENT_ID);
    log.event('shard_sweep', { shards, n: 500, ...s, stored });
    log.say(fmtRow(shards, s) + `   ${String(stored).padStart(5)}`);
  }

  // ── B. Kuyruk genişliği taraması (parça sabit) ─────────────────────
  const SHARDS = 16;
  log.say('');
  log.say(`B) Kuyruk genişliğinin etkisi — 500 kişi, ${SHARDS} parça sabit`);
  log.say('   "K" = aynı anda uçmasına izin verilen istek sayısı');
  log.say('─'.repeat(104));
  log.say('K'.padEnd(10) + TABLE_HEADER.slice(10) + '  kayıt');
  log.say('─'.repeat(104));

  for (const k of [8, 16, 32, 64, 128, 500]) {
    await prepareShards(db, EVENT_ID, QUOTA, SHARDS);
    const run = await runThrottled(500, k, (i) =>
      registerSharded(db, EVENT_ID, studentUid(i), i, SHARDS),
    );
    const s = summarize(run);
    const stored = await countRegistrations(db, EVENT_ID);
    log.event('queue_sweep', { k, shards: SHARDS, n: 500, ...s, stored });
    log.say(fmtRow(k, s) + `   ${String(stored).padStart(5)}`);
  }

  // ── C. Kontenjanın gerçekten bittiği hâl ───────────────────────────
  log.say('');
  log.say('C) Kontenjan taşması — 500 kişilik etkinliğe 2000 kişi başvuruyor');
  log.say(`   (${SHARDS} parça, K=64 kuyruk)`);
  log.say('─'.repeat(104));

  await prepareShards(db, EVENT_ID, QUOTA, SHARDS);
  const overflow = await runThrottled(2000, 64, (i) =>
    registerSharded(db, EVENT_ID, studentUid(i), i, SHARDS),
  );
  const os = summarize(overflow);
  const stored = await countRegistrations(db, EVENT_ID);
  const quotaFull = overflow.results.filter(
    (r) => !r.ok && r.code === 'quota-full',
  ).length;
  const realErrors = os.failed - quotaFull;

  log.event('overflow', { n: 2000, ...os, stored, quotaFull, realErrors });
  log.say(`  başvuru        : 2000`);
  log.say(`  kaydolan       : ${os.ok}`);
  log.say(`  "kontenjan doldu": ${quotaFull}  ← hata değil, doğru cevap`);
  log.say(`  gerçek hata    : ${realErrors}`);
  log.say(`  veritabanında  : ${stored} kayıt (kontenjan ${QUOTA})`);
  log.say(`  aşım           : ${stored - QUOTA}`);
  log.say(`  p50/p95        : ${Math.round(os.p50)}ms / ${Math.round(os.p95)}ms`);
  log.say(`  toplam süre    : ${(os.wallMs / 1000).toFixed(1)} sn`);

  // Parça dağılımı
  const shardSnap = await db.collection(`events/${EVENT_ID}/quota_shards`).get();
  const dist = shardSnap.docs
    .map((d) => `${d.id}:${d.data().count}/${d.data().capacity}`)
    .join(' ');
  log.say(`  parça dolumu   : ${dist}`);

  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
