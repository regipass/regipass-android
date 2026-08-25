/**
 * TEST 1 — Mevcut kayıt akışının eşzamanlılık davranışı.
 *
 * lib/services/event_repository.dart#registerToEvent + çağıran ekran
 * (student_dashboard_screen.dart#_register) ne yapıyorsa aynısı:
 *
 *   1. fetchEventFromServer(eventId)        → 1 doküman okuma (önbelleksiz)
 *   2. registrationDoc(...).set(payload)    → 1 doküman yazma
 *   3. ref.invalidate(studentVisibleEvents) → events koleksiyonunun TAMAMI
 *
 * Ölçtüğümüz iki şey:
 *   • KONTENJAN AŞIMI: kontenjan hiçbir yerde kontrol edilmediği için
 *     N kişi aynı anda basınca kaç fazla kayıt oluşuyor?
 *   • OKUMA ÇOĞALMASI: 3. adım yüzünden tek kayıt kaç okumaya mal oluyor?
 */

import {
  connect, RunLog, fireAtOnce, summarize, fmtRow, TABLE_HEADER,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_baseline';
const QUOTA = 100;
const LEVELS = [10, 50, 100, 250, 500, 1000, 2000];
/** Kulüplerin toplam etkinlik sayısı — 3. adımın maliyetini bu belirler. */
const EVENT_CATALOG_SIZE = 300;

const log = new RunLog('01-baseline');

async function seedCatalog(db) {
  const existing = await db.collection('events').count().get();
  const have = existing.data().count;
  if (have >= EVENT_CATALOG_SIZE) return have;

  for (let start = have; start < EVENT_CATALOG_SIZE; start += 400) {
    const batch = db.batch();
    for (let i = start; i < Math.min(start + 400, EVENT_CATALOG_SIZE); i++) {
      batch.set(db.doc(`events/loadtest_catalog_${i}`), {
        title: `Katalog Etkinligi ${i}`,
        clubId: `loadtest_club_${i % 40}`,
        clubName: `Kulup ${i % 40}`,
        quota: 100,
        deadlineAtMs: Date.now() + 30 * 24 * 60 * 60 * 1000,
        registrationClosed: false,
        hiddenGlobally: false,
        targetScope: 'public',
        description: 'x'.repeat(400),
      });
    }
    await batch.commit();
  }
  return EVENT_CATALOG_SIZE;
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 1 — MEVCUT KAYIT AKIŞI (kontenjan kontrolü YOK)');
  log.say('══════════════════════════════════════════════════════════════');

  const catalog = await seedCatalog(db);
  log.say(`\nEtkinlik kataloğu: ${catalog} doküman`);
  log.say(`Test etkinliği kontenjanı: ${QUOTA}\n`);

  // ── A. Yalnızca yazma yolu ─────────────────────────────────────────
  log.say('A) Kayıt yolu (oku + yaz), N kişi AYNI ANDA "Kaydol"a basıyor');
  log.say('─'.repeat(96));
  log.say(TABLE_HEADER + '  kayıt/kontenjan');
  log.say('─'.repeat(96));

  for (const n of LEVELS) {
    await resetEvent(db, EVENT_ID, { quota: QUOTA });
    const eventRef = db.doc(`events/${EVENT_ID}`);

    const run = await fireAtOnce(n, async (i) => {
      const uid = studentUid(i);
      // 1. adım: sunucudan taze etkinlik
      const snap = await eventRef.get();
      const event = snap.data();
      if (event.registrationClosed) throw new Error('registration-closed');
      // 2. adım: kaydı yaz
      await db
        .doc(`event_registrations/${registrationId(EVENT_ID, uid)}`)
        .set(registrationPayload(EVENT_ID, uid, i, event), { merge: true });
      return { reads: 1, writes: 1 };
    });

    const s = summarize(run);
    const stored = await countRegistrations(db, EVENT_ID);
    const overshoot = stored - QUOTA;

    log.event('baseline_write', { n, ...s, stored, overshoot });
    log.say(
      fmtRow(n, s) +
        `   ${String(stored).padStart(5)}/${QUOTA}` +
        (overshoot > 0 ? `  ⚠ +${overshoot} FAZLA` : ''),
    );
  }

  // ── B. Ekranın gerçekte yaptığı tam yol ────────────────────────────
  log.say('');
  log.say('B) Tam istemci yolu: kayıt + ardından studentVisibleEvents tazeleme');
  log.say(`   (her başarılı kayıttan sonra ${catalog} etkinlik yeniden okunuyor)`);
  log.say('─'.repeat(96));
  log.say(TABLE_HEADER + '  toplam okuma');
  log.say('─'.repeat(96));

  for (const n of [10, 50, 100, 250, 500]) {
    await resetEvent(db, EVENT_ID, { quota: QUOTA });
    const eventRef = db.doc(`events/${EVENT_ID}`);
    let totalReads = 0;

    const run = await fireAtOnce(n, async (i) => {
      const uid = studentUid(i);
      const snap = await eventRef.get();
      const event = snap.data();
      await db
        .doc(`event_registrations/${registrationId(EVENT_ID, uid)}`)
        .set(registrationPayload(EVENT_ID, uid, i, event), { merge: true });
      // 3. adım: ref.invalidate(studentVisibleEventsProvider) → fetchAllEvents()
      const all = await db.collection('events').get();
      totalReads += 1 + all.size;
      return { reads: 1 + all.size, writes: 1 };
    });

    const s = summarize(run);
    log.event('baseline_full', { n, ...s, totalReads });
    log.say(fmtRow(n, s) + `   ${String(totalReads).padStart(9)}`);
  }

  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
