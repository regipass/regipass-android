/**
 * TEST 5 — GERÇEKÇİ SENARYO: N AYRI TELEFON, aynı saniyede "Kaydol".
 *
 * Test 3'teki kuyruk tek bir istemcinin kendi isteklerini sıraya sokuyordu.
 * Gerçekte kuyruk kuracak merkezî bir yer YOK: 500 öğrencinin 500 ayrı
 * telefonu var ve hiçbiri diğerini beklemiyor. Cihaz başına kuyruk genişliği
 * zaten 1'dir (bir öğrenci aynı anda tek etkinliğe kaydolur).
 *
 * O hâlde yükü zamana yayacak tek araç istemcideki YENİDEN DENEME
 * davranışıdır: çekişme yüzünden düşen istek, üstel artan ve RASTGELELEŞTİRİLMİŞ
 * (jitter) bir bekleyişten sonra tekrar denenir. Bu, merkezî kuyruk olmadan
 * dağıtık bir kuyruk kurar — "bölük bölük" olan budur.
 *
 * Bu test üç şeyi karşılaştırır:
 *   1. yeniden deneme YOK              (SDK varsayılanı, 5 deneme)
 *   2. üstel backoff, jitter YOK       (herkes aynı anda uyanır → sürü etkisi)
 *   3. üstel backoff + tam jitter      (önerilen)
 */

import {
  connect, RunLog, fireAtOnce, summarize, fmtRow, TABLE_HEADER,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_realistic';
const QUOTA = 500;
const SHARDS = 16;
const LEVELS = [50, 100, 250, 500, 1000, 2000];

/** İstemci yeniden deneme ayarları. */
const MAX_ROUNDS = 8;
const BASE_DELAY_MS = 150;
const MAX_DELAY_MS = 6000;

const log = new RunLog('05-realistic');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function backoffDelay(round, mode) {
  const window = Math.min(MAX_DELAY_MS, BASE_DELAY_MS * 2 ** round);
  if (mode === 'jitter') return Math.random() * window; // tam jitter
  return window; // sabit — herkes aynı anda uyanır
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

/** Tek bir parçaya tek bir transaction denemesi. */
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
    { maxAttempts: 1 }, // yeniden denemeyi BİZ yönetiyoruz
  );
}

/**
 * Bir öğrencinin kayıt denemesi.
 * mode: 'none' | 'fixed' | 'jitter'
 */
async function register(db, uid, i, mode) {
  let hash = 0;
  for (let c = 0; c < uid.length; c++) hash = (hash * 31 + uid.charCodeAt(c)) | 0;
  const start = Math.abs(hash) % SHARDS;

  const rounds = mode === 'none' ? 1 : MAX_ROUNDS;
  let retries = 0;
  let fullShards = 0;

  for (let round = 0; round < rounds; round++) {
    fullShards = 0;
    // Bu turda bütün parçalar taranır: biri boşsa kayıt oradan geçer.
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
        break; // çekişme: bu turu bitir, bekle, baştan dene
      }
    }
    // Bütün parçalar GERÇEKTEN dolu → kontenjan bitti, beklemenin anlamı yok.
    if (fullShards === SHARDS) {
      const full = new Error('quota-full');
      full.code = 'quota-full';
      throw full;
    }
    if (round < rounds - 1) await sleep(backoffDelay(round, mode));
  }

  const exhausted = new Error('retry-exhausted');
  exhausted.code = 'retry-exhausted';
  throw exhausted;
}

async function runCase(db, n, mode) {
  await prepareShards(db, QUOTA, SHARDS);
  const run = await fireAtOnce(n, (i) => register(db, studentUid(i), i, mode));
  const s = summarize(run);
  const stored = await countRegistrations(db, EVENT_ID);
  const quotaFull = run.results.filter(
    (r) => !r.ok && r.code === 'quota-full',
  ).length;
  return { s, stored, quotaFull, realErrors: s.failed - quotaFull };
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 5 — N AYRI CİHAZ, AYNI ANDA (merkezî kuyruk yok)');
  log.say('══════════════════════════════════════════════════════════════');
  log.say(`\nKontenjan ${QUOTA} · ${SHARDS} parça · en fazla ${MAX_ROUNDS} tur`);
  log.say(`Backoff: ${BASE_DELAY_MS}ms tabanlı üstel, tavan ${MAX_DELAY_MS}ms\n`);

  for (const mode of ['none', 'fixed', 'jitter']) {
    const label = {
      none: '1) Yeniden deneme YOK',
      fixed: '2) Üstel backoff, jitter YOK (sürü etkisi)',
      jitter: '3) Üstel backoff + TAM JITTER  ← önerilen',
    }[mode];

    log.say(label);
    log.say('─'.repeat(112));
    log.say(TABLE_HEADER + '  kayıt  kont.doldu  GERÇEK HATA');
    log.say('─'.repeat(112));

    for (const n of LEVELS) {
      const { s, stored, quotaFull, realErrors } = await runCase(db, n, mode);
      log.event('realistic', { mode, n, ...s, stored, quotaFull, realErrors });
      log.say(
        fmtRow(n, s) +
          `   ${String(stored).padStart(4)}` +
          `   ${String(quotaFull).padStart(9)}` +
          `   ${String(realErrors).padStart(10)}` +
          (stored > QUOTA ? `  ⚠ AŞIM ${stored - QUOTA}` : ''),
      );
    }
    log.say('');
  }

  log.say('Okuma notu:');
  log.say('  • "kont.doldu" HATA DEĞİLDİR — kontenjan gerçekten bitmiştir,');
  log.say('    kullanıcıya "kontenjan doldu" denir. Doğru cevaptır.');
  log.say('  • "GERÇEK HATA" = çekişme yüzünden kaydı yapılamayan öğrenci.');
  log.say('    Ölçmeye çalıştığımız sayı budur; sıfıra yakın kalmalıdır.');
  log.say('  • "AŞIM" kontenjandan fazla kayıt demektir; algoritma doğruysa 0.');
  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
