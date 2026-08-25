/**
 * TEST 5b — ÖNERİLEN KURULUM, tek başına ve geniş tarama.
 *
 * `05-realistic.mjs` üç stratejiyi karşılaştırıyor; "jitter yok" dalı yüksek
 * eşzamanlılıkta bilerek çok yavaş (herkes aynı anda uyanıp çarpışıyor) ve
 * koşuyu saatlerce sürüklüyor. Bu dosya yalnızca ÖNERİLEN kurulumu ölçer:
 *
 *     parçalı sayaç + üstel backoff + TAM JITTER
 *
 * Aradığımız sayı bu: kontenjanı bozmadan, aynı anda kaç kişinin "Kaydol"a
 * basmasını sindirebiliyoruz.
 */

import {
  connect, RunLog, fireAtOnce, summarize, fmtRow, TABLE_HEADER,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_jitter';
const QUOTA = 500;
const SHARDS = 16;
const LEVELS = [50, 100, 250, 500, 1000, 2000, 5000];

const MAX_ROUNDS = 8;
const BASE_DELAY_MS = 150;
const MAX_DELAY_MS = 6000;

const log = new RunLog('05b-jitter');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function backoff(round) {
  return Math.random() * Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** round);
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
          title: 'Yuk Testi Etkinligi',
          clubId: 'loadtest_club',
          clubName: 'Yuk Testi Kulubu',
          deadlineAtMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
        }),
      );
      tx.update(shardRef, { count: count + 1 });
    },
    { maxAttempts: 1 },
  );
}

/** lib/services/registration_service.dart#register ile aynı akış. */
async function register(db, uid, i) {
  let hash = 0;
  for (let c = 0; c < uid.length; c++) hash = (hash * 31 + uid.charCodeAt(c)) | 0;
  const start = Math.abs(hash) % SHARDS;

  let retries = 0;

  for (let round = 0; round < MAX_ROUNDS; round++) {
    let fullShards = 0;
    let contended = false;

    for (let step = 0; step < SHARDS; step++) {
      try {
        await tryShard(db, uid, i, (start + step) % SHARDS);
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

    // Çekişme yokken bütün parçalar doluysa kontenjan gerçekten bitmiştir.
    if (!contended && fullShards === SHARDS) {
      const full = new Error('quota-full');
      full.code = 'quota-full';
      throw full;
    }
    if (round < MAX_ROUNDS - 1) await sleep(backoff(round));
  }

  const exhausted = new Error('retry-exhausted');
  exhausted.code = 'retry-exhausted';
  throw exhausted;
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 5b — PARÇALI SAYAÇ + BACKOFF + TAM JITTER');
  log.say('══════════════════════════════════════════════════════════════');
  log.say(`\nKontenjan ${QUOTA} · ${SHARDS} parça · ${MAX_ROUNDS} tur`);
  log.say(`Backoff penceresi ${BASE_DELAY_MS}ms→${MAX_DELAY_MS}ms, tam jitter`);
  log.say('\nN kişi AYNI ANDA "Kaydol"a basıyor (N ayrı cihaz, merkezî kuyruk yok)');
  log.say('─'.repeat(116));
  log.say(TABLE_HEADER + '  kayıt  kont.doldu  GERÇEK HATA  süre');
  log.say('─'.repeat(116));

  for (const n of LEVELS) {
    await prepareShards(db, QUOTA, SHARDS);
    const run = await fireAtOnce(n, (i) => register(db, studentUid(i), i));
    const s = summarize(run);
    const stored = await countRegistrations(db, EVENT_ID);
    const quotaFull = run.results.filter(
      (r) => !r.ok && r.code === 'quota-full',
    ).length;
    const realErrors = s.failed - quotaFull;

    log.event('jitter', { n, ...s, stored, quotaFull, realErrors });
    log.say(
      fmtRow(n, s) +
        `   ${String(stored).padStart(4)}` +
        `   ${String(quotaFull).padStart(9)}` +
        `   ${String(realErrors).padStart(10)}` +
        `   ${(s.wallMs / 1000).toFixed(1)}sn` +
        (stored > QUOTA ? `  ⚠ AŞIM ${stored - QUOTA}` : '') +
        (stored < Math.min(n, QUOTA) ? `  ⚠ EKSİK ${Math.min(n, QUOTA) - stored}` : ''),
    );
  }

  log.say('');
  log.say('Okuma notu:');
  log.say('  • "kont.doldu" hata değil, DOĞRU cevaptır: kontenjan bitmiştir.');
  log.say('  • "GERÇEK HATA" ölçtüğümüz sayıdır — çekişme yüzünden kaydı');
  log.say('    yapılamayan öğrenci. Sıfır olmalı.');
  log.say('  • "AŞIM"/"EKSİK" kontenjan bütünlüğüdür; ikisi de 0 olmalı.');
  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
