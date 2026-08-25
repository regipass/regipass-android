/**
 * TEST 7 — ARKA UÇ KAPASİTESİ ve PATLAMA EMİLİMİ.
 *
 * 05b'de jitter'lı kurulum da yüksek eşzamanlılıkta düştü. Sebep algoritma
 * değil ÖLÇÜM ARACI olabilir: emulator tek süreçlidir ve saniyede ancak
 * belirli sayıda transaction işler. Teklif edilen yük bu tavanı aşınca
 * algoritma ne yaparsa yapsın istekler birikir.
 *
 * Bu test önce o tavanı ÖLÇER, sonra algoritmayı tavana GÖRE değerlendirir.
 *
 *   A) Kabul hızı: parça sayısı arttıkça saniyede kaç kayıt işlenebiliyor?
 *      (teklif edilen yük tavanın altında tutularak — doygunluk yok)
 *
 *   B) Patlama emilimi: kabul hızı sabitken, yeniden deneme bütçesi
 *      büyüdükçe aynı anda basan N kişinin kaçı kayıt olabiliyor?
 *
 * B'nin cevabı tasarımın asıl kolunu verir:
 *
 *      emilebilen patlama  ≈  kabul hızı  ×  en fazla bekleme süresi
 */

import {
  connect, RunLog, fireAtOnce, runThrottled, summarize, fmtRow, TABLE_HEADER,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_capacity';
const QUOTA = 2000;

const BASE_DELAY_MS = 150;
const MAX_DELAY_MS = 6000;

const log = new RunLog('07-capacity');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function backoff(round) {
  return Math.random() * Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** round);
}

/** Turların jitter penceresi toplamı — en kötü hâlde beklenecek süre. */
function retryBudgetMs(rounds) {
  let total = 0;
  for (let r = 0; r < rounds - 1; r++) {
    total += Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** r);
  }
  return total;
}

async function prepareShards(db, quota, shards) {
  await resetEvent(db, EVENT_ID, { quota });
  const base = Math.floor(quota / shards);
  const extra = quota % shards;
  const batch = db.batch();
  for (let s = 0; s < shards; s++) {
    batch.set(db.doc(`events/${EVENT_ID}/quota_shards/${s}`), {
      count: 0,
      capacity: base + (s < extra ? 1 : 0),
    });
  }
  await batch.commit();
}

async function tryShard(db, uid, i, shard) {
  const shardRef = db.doc(`events/${EVENT_ID}/quota_shards/${shard}`);
  await db.runTransaction(
    async (tx) => {
      const snap = await tx.get(shardRef);
      const { count, capacity } = snap.data();
      if (count >= capacity) {
        const full = new Error('shard-full');
        full.code = 'shard-full';
        throw full;
      }
      tx.set(
        db.doc(`event_registrations/${registrationId(EVENT_ID, uid)}`),
        registrationPayload(EVENT_ID, uid, i, {
          title: 'Kapasite Testi',
          clubId: 'loadtest_club',
          clubName: 'Kulup',
          deadlineAtMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
        }),
      );
      tx.update(shardRef, { count: count + 1 });
    },
    { maxAttempts: 1 },
  );
}

async function register(db, uid, i, shards, rounds) {
  let hash = 0;
  for (let c = 0; c < uid.length; c++) hash = (hash * 31 + uid.charCodeAt(c)) | 0;
  const start = Math.abs(hash) % shards;
  let retries = 0;

  for (let round = 0; round < rounds; round++) {
    let fullShards = 0;
    let contended = false;

    for (let step = 0; step < shards; step++) {
      try {
        await tryShard(db, uid, i, (start + step) % shards);
        return { retries, round };
      } catch (error) {
        if (error.code === 'shard-full') {
          fullShards += 1;
          continue;
        }
        retries += 1;
        contended = true;
        break;
      }
    }

    if (!contended && fullShards === shards) {
      const full = new Error('quota-full');
      full.code = 'quota-full';
      throw full;
    }
    if (round < rounds - 1) await sleep(backoff(round));
  }

  const exhausted = new Error('retry-exhausted');
  exhausted.code = 'retry-exhausted';
  throw exhausted;
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 7 — KABUL HIZI ve PATLAMA EMİLİMİ');
  log.say('══════════════════════════════════════════════════════════════');

  // ── A. Kabul hızı ──────────────────────────────────────────────────
  //
  // Teklif edilen yükü bilerek DÜŞÜK tutuyoruz (eşzamanlılık = parça sayısı):
  // doygunluk olmadan arka ucun saniyede kaç kayıt işleyebildiğini görmek
  // istiyoruz. Bu sayı üretimde çok daha yüksek olacak; buradaki değeri
  // "referans birim" olarak kullanıyoruz.
  log.say('');
  log.say('A) Kabul hızı — teklif edilen yük = parça sayısı (doygunluk yok)');
  log.say('   300 kayıt, eşzamanlılık parça sayısına eşit tutuldu');
  log.say('─'.repeat(104));
  log.say('parça'.padEnd(10) + TABLE_HEADER.slice(10) + '  kayıt/sn');
  log.say('─'.repeat(104));

  const rates = {};
  for (const shards of [1, 4, 8, 16, 32, 64]) {
    await prepareShards(db, QUOTA, shards);
    const run = await runThrottled(300, shards, (i) =>
      register(db, studentUid(i), i, shards, 8),
    );
    const s = summarize(run);
    rates[shards] = s.throughputPerSec;
    log.event('rate', { shards, ...s });
    log.say(fmtRow(shards, s) + `   ${s.throughputPerSec.toFixed(1).padStart(9)}`);
  }

  const SHARDS = 16;
  const rate = rates[SHARDS];
  log.say('');
  log.say(`Referans: ${SHARDS} parça ile ölçülen kabul hızı ≈ ${rate.toFixed(1)} kayıt/sn`);

  // ── B. Patlama emilimi ─────────────────────────────────────────────
  //
  // Kabul hızı sabit. Yeniden deneme bütçesini büyütünce aynı anda basan
  // 500 kişinin kaçı geçiyor? Beklenti: emilen patlama, bütçeyle doğrusal.
  log.say('');
  log.say('B) Patlama emilimi — 500 kişi AYNI ANDA, tur sayısı değişken');
  log.say(`   ${SHARDS} parça sabit`);
  log.say('─'.repeat(116));
  log.say(
    'tur'.padEnd(10) + TABLE_HEADER.slice(10) +
    '  bütçe   beklenen   gerçek',
  );
  log.say('─'.repeat(116));

  for (const rounds of [1, 4, 8, 12, 16, 20]) {
    await prepareShards(db, QUOTA, SHARDS);
    const run = await fireAtOnce(500, (i) =>
      register(db, studentUid(i), i, SHARDS, rounds),
    );
    const s = summarize(run);
    const stored = await countRegistrations(db, EVENT_ID);
    const budgetMs = retryBudgetMs(rounds);
    // Beklenen emilim: bütçenin yarısı (jitter ortalaması) × kabul hızı
    const predicted = Math.min(500, Math.round((budgetMs / 2 / 1000) * rate) + Math.round(rate));

    log.event('absorb', { rounds, ...s, stored, budgetMs, predicted });
    log.say(
      fmtRow(rounds, s) +
        `   ${(budgetMs / 1000).toFixed(1).padStart(5)}sn` +
        `   ${String(predicted).padStart(8)}` +
        `   ${String(s.ok).padStart(6)}` +
        (stored > QUOTA ? `  ⚠ AŞIM` : ''),
    );
  }

  // ── C. Kontenjan bütünlüğü, doygunluk altında ──────────────────────
  log.say('');
  log.say('C) Kontenjan bütünlüğü — kontenjan 200, 1000 kişi başvuruyor');
  log.say(`   ${SHARDS} parça, kuyruk genişliği kabul hızına ayarlı`);
  log.say('─'.repeat(104));

  await prepareShards(db, 200, SHARDS);
  const run = await runThrottled(1000, SHARDS, (i) =>
    register(db, studentUid(i), i, SHARDS, 8),
  );
  const s = summarize(run);
  const stored = await countRegistrations(db, 200);
  const storedReal = await countRegistrations(db, EVENT_ID);
  const quotaFull = run.results.filter((r) => !r.ok && r.code === 'quota-full').length;

  log.event('integrity', { n: 1000, quota: 200, ...s, stored: storedReal, quotaFull });
  log.say(`  başvuru          : 1000`);
  log.say(`  kaydolan         : ${s.ok}`);
  log.say(`  "kontenjan doldu": ${quotaFull}`);
  log.say(`  gerçek hata      : ${s.failed - quotaFull}`);
  log.say(`  veritabanında    : ${storedReal} kayıt (kontenjan 200)`);
  log.say(`  AŞIM             : ${storedReal - 200}`);

  const shardSnap = await db.collection(`events/${EVENT_ID}/quota_shards`).get();
  const total = shardSnap.docs.reduce((a, d) => a + d.data().count, 0);
  log.say(`  sayaç toplamı    : ${total} (kayıt sayısıyla eşleşmeli)`);
  void stored;

  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
