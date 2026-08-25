/**
 * Regipass kayıt yükü test düzeneği — ortak altyapı.
 *
 * Firestore emulator'e bağlanır, eşzamanlı iş çalıştırır, her işlemi
 * JSONL olarak kaydeder ve özet istatistik üretir.
 *
 * NOT: Emulator tek süreçli ve bellek içidir. Şunları GERÇEK ölçer:
 *   • transaction çekişmesi (optimistic concurrency, ABORTED/retry)
 *   • kontenjan aşımı (overshoot) — algoritmanın doğruluğu
 *   • işlem başına yapılan okuma/yazma sayısı
 * Şunları ölçMEZ (üretimdeki gerçek tavanlar belgelenmiş limitlerdir):
 *   • indeks sıcak noktası (~500 yazma/sn dar anahtar aralığı)
 *   • 500/50/5 rampası, ağ gecikmesi, bölgesel kota
 */

import { Firestore } from '@google-cloud/firestore';
import { mkdirSync, appendFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
export const LOG_DIR = join(ROOT, 'logs');
export const PROJECT_ID = 'eventapp-604a5';

/// Varsayılan emulator 8722. İkinci bir emulator'e yönlendirmek için
/// `LOADTEST_EMULATOR=127.0.0.1:8733 node 04-login.mjs`.
export const EMULATOR = process.env.LOADTEST_EMULATOR ?? '127.0.0.1:8722';

mkdirSync(LOG_DIR, { recursive: true });

// ── Bağlantı ─────────────────────────────────────────────────────────

export function connect() {
  process.env.FIRESTORE_EMULATOR_HOST = EMULATOR;
  return new Firestore({
    projectId: PROJECT_ID,
    // Yük testinde istemci kendi içinde kuyruklamasın: eşzamanlılığı
    // biz kontrol ediyoruz, gRPC kanal sayısı darboğaz olmamalı.
    maxIdleChannels: 20,
  });
}

// ── Günlük (JSONL) ───────────────────────────────────────────────────

export class RunLog {
  constructor(name) {
    this.name = name;
    this.startedAt = new Date();
    const stamp = this.startedAt.toISOString().replace(/[:.]/g, '-');
    this.path = join(LOG_DIR, `${name}_${stamp}.jsonl`);
    this.summaryPath = join(LOG_DIR, `${name}_${stamp}.summary.txt`);
    this.buffer = [];
    this.lines = [];
  }

  /** Tek bir olay — işlem bitişi, aşama başlangıcı, uyarı vb. */
  event(type, fields = {}) {
    const row = { t: Date.now(), type, ...fields };
    this.buffer.push(row);
    if (this.buffer.length >= 500) this.flush();
    return row;
  }

  flush() {
    if (this.buffer.length === 0) return;
    appendFileSync(
      this.path,
      this.buffer.map((r) => JSON.stringify(r)).join('\n') + '\n',
      'utf8',
    );
    this.buffer.length = 0;
  }

  /** Hem ekrana hem özet dosyasına giden satır. */
  say(line = '') {
    this.lines.push(line);
    console.log(line);
  }

  close() {
    this.flush();
    writeFileSync(this.summaryPath, this.lines.join('\n') + '\n', 'utf8');
    console.log(`\n  ham günlük : ${this.path}`);
    console.log(`  özet       : ${this.summaryPath}`);
  }
}

// ── Eşzamanlı çalıştırıcı ────────────────────────────────────────────

/**
 * [count] işi AYNI ANDA başlatır (gerçek eşzamanlılık: hepsi tek turda
 * kuyruğa girer). Her iş için süre ve sonuç kaydedilir.
 */
export async function fireAtOnce(count, work) {
  const started = process.hrtime.bigint();
  const results = await Promise.all(
    Array.from({ length: count }, async (_, i) => {
      const t0 = process.hrtime.bigint();
      try {
        const value = await work(i);
        return {
          i,
          ok: true,
          ms: Number(process.hrtime.bigint() - t0) / 1e6,
          value,
        };
      } catch (error) {
        return {
          i,
          ok: false,
          ms: Number(process.hrtime.bigint() - t0) / 1e6,
          code: error.code ?? error.status ?? 'unknown',
          message: String(error.message ?? error).slice(0, 200),
        };
      }
    }),
  );
  const wallMs = Number(process.hrtime.bigint() - started) / 1e6;
  return { results, wallMs };
}

/**
 * [count] işi en fazla [limit] tanesi aynı anda uçacak şekilde
 * "bölük bölük" çalıştırır — üretimdeki kuyruk algoritmasının aynısı.
 */
export async function runThrottled(count, limit, work) {
  const started = process.hrtime.bigint();
  const results = new Array(count);
  let next = 0;

  async function worker() {
    for (;;) {
      const i = next++;
      if (i >= count) return;
      const t0 = process.hrtime.bigint();
      try {
        const value = await work(i);
        results[i] = {
          i,
          ok: true,
          ms: Number(process.hrtime.bigint() - t0) / 1e6,
          value,
        };
      } catch (error) {
        results[i] = {
          i,
          ok: false,
          ms: Number(process.hrtime.bigint() - t0) / 1e6,
          code: error.code ?? error.status ?? 'unknown',
          message: String(error.message ?? error).slice(0, 200),
        };
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(limit, count) }, () => worker()),
  );
  const wallMs = Number(process.hrtime.bigint() - started) / 1e6;
  return { results, wallMs };
}

// ── İstatistik ───────────────────────────────────────────────────────

export function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  const idx = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil((p / 100) * sorted.length) - 1),
  );
  return sorted[idx];
}

export function summarize({ results, wallMs }) {
  const ok = results.filter((r) => r.ok);
  const failed = results.filter((r) => !r.ok);
  const durations = ok.map((r) => r.ms).sort((a, b) => a - b);

  const byCode = {};
  for (const f of failed) byCode[f.code] = (byCode[f.code] ?? 0) + 1;

  const retries = results
    .map((r) => r.value?.retries ?? 0)
    .reduce((a, b) => a + b, 0);

  return {
    total: results.length,
    ok: ok.length,
    failed: failed.length,
    failRatePct: results.length ? (failed.length / results.length) * 100 : 0,
    wallMs: Math.round(wallMs),
    throughputPerSec: wallMs > 0 ? (results.length / wallMs) * 1000 : 0,
    p50: percentile(durations, 50),
    p95: percentile(durations, 95),
    p99: percentile(durations, 99),
    max: durations.length ? durations[durations.length - 1] : 0,
    retries,
    byCode,
  };
}

export function fmtRow(label, s) {
  const codes = Object.entries(s.byCode)
    .map(([k, v]) => `${k}×${v}`)
    .join(' ');
  return (
    `${String(label).padEnd(10)}` +
    `${String(s.ok).padStart(6)}` +
    `${String(s.failed).padStart(8)}` +
    `${s.failRatePct.toFixed(1).padStart(8)}%` +
    `${Math.round(s.p50).toString().padStart(9)}` +
    `${Math.round(s.p95).toString().padStart(9)}` +
    `${Math.round(s.p99).toString().padStart(9)}` +
    `${s.throughputPerSec.toFixed(0).padStart(10)}` +
    `${String(s.retries).padStart(9)}` +
    (codes ? `   ${codes}` : '')
  );
}

export const TABLE_HEADER =
  'eşzaman'.padEnd(10) +
  'ok'.padStart(6) +
  'hata'.padStart(8) +
  'hata%'.padStart(9) +
  'p50ms'.padStart(9) +
  'p95ms'.padStart(9) +
  'p99ms'.padStart(9) +
  'işlem/sn'.padStart(10) +
  'retry'.padStart(9);

// ── Test verisi ──────────────────────────────────────────────────────

export function studentUid(i) {
  return `loadtest_student_${String(i).padStart(5, '0')}`;
}

export function registrationId(eventId, uid) {
  return `${eventId}_${uid}`;
}

/** Gerçek kayıt yükünün alan alan aynısı (event_repository.dart). */
export function registrationPayload(eventId, uid, i, event) {
  return {
    registrationId: registrationId(eventId, uid),
    eventId,
    eventTitle: event.title,
    eventImageUrl: event.imageUrl ?? '',
    deadlineAtMs: event.deadlineAtMs,
    clubId: event.clubId,
    clubName: event.clubName,
    studentId: uid,
    studentEmail: `${uid}@ornek.edu.tr`,
    studentFirstName: `Ogrenci${i}`,
    studentLastName: 'Test',
    studentName: `Ogrenci${i} Test`,
    studentPhone: `+9055500${String(i).padStart(5, '0')}`,
    studentUniversity: 'Istanbul Universitesi',
    studentDepartment: 'Bilgisayar Muhendisligi',
    studentClassYear: '3',
    studentCity: 'Istanbul',
    registeredAtMs: Date.now(),
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

/** Test etkinliğini sıfırdan kurar; önceki kayıtları temizler. */
export async function resetEvent(db, eventId, { quota, shards = 0 }) {
  await deleteCollectionWhere(db, 'event_registrations', 'eventId', eventId);
  await deleteSubcollection(db, `events/${eventId}/quota_shards`);

  const event = {
    title: 'Yuk Testi Etkinligi',
    clubId: 'loadtest_club',
    clubName: 'Yuk Testi Kulubu',
    imageUrl: '',
    quota,
    registeredCount: 0,
    deadlineAtMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
    registrationClosed: false,
    hiddenGlobally: false,
    targetScope: 'public',
    currentSession: 0,
    sessionsCompleted: false,
  };
  await db.doc(`events/${eventId}`).set(event);

  if (shards > 0) {
    const batch = db.batch();
    for (let s = 0; s < shards; s++) {
      batch.set(db.doc(`events/${eventId}/quota_shards/${s}`), {
        count: 0,
        capacity: 0,
      });
    }
    await batch.commit();
  }

  return { id: eventId, ...event };
}

export async function deleteCollectionWhere(db, col, field, value) {
  for (;;) {
    const snap = await db
      .collection(col)
      .where(field, '==', value)
      .limit(400)
      .get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

export async function deleteSubcollection(db, path) {
  for (;;) {
    const snap = await db.collection(path).limit(400).get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

export async function countRegistrations(db, eventId) {
  const snap = await db
    .collection('event_registrations')
    .where('eventId', '==', eventId)
    .count()
    .get();
  return snap.data().count;
}

export async function waitForEmulator(timeoutMs = 120000) {
  const deadline = Date.now() + timeoutMs;
  const url = `http://${EMULATOR}/`;
  for (;;) {
    try {
      const res = await fetch(url, { method: 'GET' });
      if (res.status < 500) return true;
    } catch {
      /* henüz ayakta değil */
    }
    if (Date.now() > deadline) return false;
    await new Promise((r) => setTimeout(r, 500));
  }
}
