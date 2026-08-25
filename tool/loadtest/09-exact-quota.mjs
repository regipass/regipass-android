/**
 * TEST 9 — "Kontenjanı 100, aynı anda 100 kişi basıyor. Kaldırır mı?"
 *
 * Şimdiye kadarki testler AŞIRI talebi ölçtü (kontenjandan çok başvuru).
 * Asıl merak edilen soru daha somut:
 *
 *   • kontenjan 100, aynı anda 100 kişi  → kaçı kaydolur?
 *   • kontenjan 400, aynı anda 400 kişi  → kaçı kaydolur?
 *
 * Yani "tam dolduracak kadar" talep geldiğinde herkes içeri girebiliyor mu.
 * Boş kalan her yer, gerçek hayatta kulübün kaybettiği katılımcıdır.
 *
 * İki kurulum karşılaştırılıyor:
 *   A) hepsi AYNI ANDA  — gerçek istemci davranışı (merkezî kuyruk yok)
 *   B) kabul denetimli  — arka ucun sindirebileceği hızda
 *
 * Ayrıca parça sayısının etkisi ölçülüyor: kapasitenin kolu bu.
 */

import {
  connect, RunLog, fireAtOnce, runThrottled, summarize,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_exact';
const MAX_ROUNDS = 8;
const BASE_DELAY_MS = 150;
const MAX_DELAY_MS = 6000;

const log = new RunLog('09-exact-quota');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
          title: 'Tam Kontenjan Testi',
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

async function register(db, uid, i, shards) {
  let hash = 0;
  for (let c = 0; c < uid.length; c++) hash = (hash * 31 + uid.charCodeAt(c)) | 0;
  const start = Math.abs(hash) % shards;

  for (let round = 0; round < MAX_ROUNDS; round++) {
    let fullShards = 0;
    let contended = false;

    for (let step = 0; step < shards; step++) {
      try {
        await tryShard(db, uid, i, (start + step) % shards);
        return { round };
      } catch (error) {
        if (error.code === 'shard-full') {
          fullShards += 1;
          continue;
        }
        contended = true;
        break;
      }
    }

    if (!contended && fullShards === shards) {
      const full = new Error('quota-full');
      full.code = 'quota-full';
      throw full;
    }
    if (round < MAX_ROUNDS - 1) {
      await sleep(Math.random() * Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** round));
    }
  }

  const exhausted = new Error('retry-exhausted');
  exhausted.code = 'retry-exhausted';
  throw exhausted;
}

async function runCase(db, { quota, applicants, shards, admission }) {
  await prepareShards(db, quota, shards);
  const work = (i) => register(db, studentUid(i), i, shards);
  const run = admission
    ? await runThrottled(applicants, admission, work)
    : await fireAtOnce(applicants, work);
  const s = summarize(run);
  const stored = await countRegistrations(db, EVENT_ID);
  const quotaFull = run.results.filter((r) => !r.ok && r.code === 'quota-full').length;
  return { s, stored, quotaFull, exhausted: s.failed - quotaFull };
}

function row(label, quota, r) {
  const fillPct = ((r.stored / quota) * 100).toFixed(1);
  return (
    String(label).padEnd(26) +
    String(r.stored).padStart(7) +
    ` / ${String(quota).padEnd(5)}` +
    `${fillPct.padStart(7)}%` +
    String(r.exhausted).padStart(11) +
    String(Math.round(r.s.p50)).padStart(9) +
    String(Math.round(r.s.p95)).padStart(9) +
    `${(r.s.wallMs / 1000).toFixed(1).padStart(8)}sn` +
    (r.stored > quota ? '  ⚠ AŞIM' : '')
  );
}

const HEADER =
  'kurulum'.padEnd(26) +
  'kayıt'.padStart(7) + ' / kota ' + 'dolum'.padStart(6) +
  'kaçan'.padStart(11) + 'p50ms'.padStart(9) + 'p95ms'.padStart(9) + 'süre'.padStart(10);

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 9 — TAM KONTENJAN KADAR TALEP');
  log.say('══════════════════════════════════════════════════════════════');
  log.say('\n"kaçan" = kontenjanda yer olduğu hâlde kaydolamayan kişi.');
  log.say('Kulübün kaybettiği katılımcı budur; sıfır olmalı.\n');

  for (const quota of [100, 400]) {
    log.say(`━━━ Kontenjan ${quota}, aynı anda ${quota} kişi ━━━`);
    log.say('─'.repeat(96));
    log.say(HEADER);
    log.say('─'.repeat(96));

    // quotaShardCount tablosu (lib/domain/registration_capacity.dart):
    // 100→8, 400→16. Parça başına ~12 kişilik kapasite hedefleniyor.
    //
    // UYARI: bu testin "hepsi birden" satırlarına bakıp parça sayısı
    // AYARLAMAYIN. Emulator 400 ölçeğinde doyuyor; aynı kurulum iki koşuda
    // 95 ve 45 verdi. Yalnızca "kabul denetimli" satırı yorumlanabilir.
    const fromTable = quota <= 50 ? 4 : quota <= 200 ? 8 : quota <= 1000 ? 16 : 32;
    const defaultShards = Math.min(fromTable, quota);

    for (const shards of [defaultShards, defaultShards * 2, defaultShards * 4]) {
      const r = await runCase(db, { quota, applicants: quota, shards, admission: 0 });
      log.event('all_at_once', { quota, applicants: quota, shards, ...r.s, stored: r.stored, exhausted: r.exhausted });
      log.say(row(`hepsi birden, ${shards} parça`, quota, r));
    }

    // Kabul denetimli: arka ucun sindirebileceği hız
    const r2 = await runCase(db, {
      quota, applicants: quota, shards: defaultShards, admission: defaultShards,
    });
    log.event('admission', { quota, applicants: quota, shards: defaultShards, ...r2.s, stored: r2.stored, exhausted: r2.exhausted });
    log.say(row(`kabul denetimli (K=${defaultShards})`, quota, r2));
    log.say('');
  }

  log.say('Okuma notu: "hepsi birden" satırları emulator\'ün kendi işlem');
  log.say('tavanını da içerir (saniyede 6–16 transaction). "kabul denetimli"');
  log.say('satırı algoritmanın arka uç doymadığındaki davranışını gösterir —');
  log.say('üretimde beklenen tablo ona daha yakındır.');
  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
