/**
 * TEST 8 — "Kontenjan doldu" cevabı doğru veriliyor mu?
 *
 * 07-capacity C'de kontenjanı 200 olan etkinliğe 1000 kişi başvurdu ve
 * **hiç kimse** "kontenjan doldu" cevabı almadı; 807 kişi "çok yoğun,
 * tekrar dene" gördü. Sebep: tur içindeki "bütün parçalar dolu" kontrolü
 * çekişme varsa bilerek atlanıyor (dolu gördüğümüz parça eski okuma
 * olabilir), ama yoğunlukta neredeyse her turda bir çekişme oluyor.
 *
 * Sonuç, kullanıcı açısından yanlış: kontenjan bitmiş bir etkinliği
 * saatlerce yeniden denemesi söyleniyor.
 *
 * Düzeltme (lib/services/registration_service.dart#_isQuotaFull): turlar
 * bitince pes etmeden önce parçalara bir kez temiz bakılır. Bu test
 * düzeltmenin ÖNCESİNİ ve SONRASINI aynı yük altında karşılaştırır.
 */

import {
  connect, RunLog, runThrottled, summarize,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_signal';
const QUOTA = 200;
const SHARDS = 16;
const APPLICANTS = 1000;
const MAX_ROUNDS = 8;
const BASE_DELAY_MS = 150;
const MAX_DELAY_MS = 6000;

const log = new RunLog('08-quota-full-signal');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function prepareShards(db) {
  await resetEvent(db, EVENT_ID, { quota: QUOTA });
  const base = Math.floor(QUOTA / SHARDS);
  const extra = QUOTA % SHARDS;
  const batch = db.batch();
  for (let s = 0; s < SHARDS; s++) {
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
          title: 'Sinyal Testi',
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

/** Son çare kontrolü: bütün parçalar gerçekten dolu mu? */
async function isQuotaFull(db) {
  const snap = await db.collection(`events/${EVENT_ID}/quota_shards`).get();
  if (snap.docs.length < SHARDS) return false;
  return snap.docs.every((d) => d.data().count >= d.data().capacity);
}

/** finalCheck: düzeltmenin açık/kapalı hâli. */
async function register(db, uid, i, finalCheck) {
  let hash = 0;
  for (let c = 0; c < uid.length; c++) hash = (hash * 31 + uid.charCodeAt(c)) | 0;
  const start = Math.abs(hash) % SHARDS;

  for (let round = 0; round < MAX_ROUNDS; round++) {
    let fullShards = 0;
    let contended = false;

    for (let step = 0; step < SHARDS; step++) {
      try {
        await tryShard(db, uid, i, (start + step) % SHARDS);
        return { outcome: 'registered' };
      } catch (error) {
        if (error.code === 'shard-full') {
          fullShards += 1;
          continue;
        }
        contended = true;
        break;
      }
    }

    if (!contended && fullShards === SHARDS) {
      const full = new Error('quota-full');
      full.code = 'quota-full';
      throw full;
    }
    if (round < MAX_ROUNDS - 1) {
      await sleep(Math.random() * Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** round));
    }
  }

  // ── Düzeltme burada ──
  if (finalCheck && (await isQuotaFull(db))) {
    const full = new Error('quota-full');
    full.code = 'quota-full';
    throw full;
  }

  const exhausted = new Error('retry-exhausted');
  exhausted.code = 'retry-exhausted';
  throw exhausted;
}

async function runCase(db, finalCheck) {
  await prepareShards(db);
  const run = await runThrottled(APPLICANTS, SHARDS, (i) =>
    register(db, studentUid(i), i, finalCheck),
  );
  const s = summarize(run);
  const stored = await countRegistrations(db, EVENT_ID);
  const quotaFull = run.results.filter((r) => !r.ok && r.code === 'quota-full').length;
  const exhausted = run.results.filter((r) => !r.ok && r.code === 'retry-exhausted').length;
  return { s, stored, quotaFull, exhausted };
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 8 — "KONTENJAN DOLDU" CEVABI DOĞRU MU?');
  log.say('══════════════════════════════════════════════════════════════');
  log.say(`\nKontenjan ${QUOTA} · ${APPLICANTS} başvuru · ${SHARDS} parça\n`);

  for (const finalCheck of [false, true]) {
    const label = finalCheck
      ? 'SONRA (son çare kontrolü var)'
      : 'ÖNCE  (son çare kontrolü yok)';
    const r = await runCase(db, finalCheck);

    log.event('signal', { finalCheck, ...r.s, stored: r.stored, quotaFull: r.quotaFull, exhausted: r.exhausted });
    log.say(label);
    log.say(`  kaydolan             : ${r.s.ok}`);
    log.say(`  "kontenjan doldu"    : ${r.quotaFull}   ← doğru cevap`);
    log.say(`  "yoğun, tekrar dene" : ${r.exhausted}   ← yanlış yönlendirme`);
    log.say(`  veritabanında        : ${r.stored} kayıt (kontenjan ${QUOTA})`);
    log.say(`  AŞIM                 : ${r.stored - QUOTA}`);
    log.say('');
  }

  log.say('Beklenen: son çare kontrolüyle "tekrar dene" cevaplarının ezici');
  log.say('çoğunluğu "kontenjan doldu"ya dönmeli. Kontenjan aşımı iki');
  log.say('durumda da 0 olmalı — düzeltme yalnızca CEVABI değiştirir.');
  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
