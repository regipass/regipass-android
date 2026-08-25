/**
 * TEST 4 — Eşzamanlı GİRİŞ yükü.
 *
 * Bir öğrenci giriş yaptığında uygulama şunları açıyor
 * (lib/state/providers.dart + student_providers.dart + notification_providers.dart):
 *
 *   1. users/{uid}                                  → canlı dinleyici   (1 okuma)
 *   2. student_profiles/{uid}                       → canlı dinleyici   (1 okuma)
 *   3. event_registrations where studentId == uid   → canlı dinleyici   (R okuma)
 *   4. student_certificates where studentId == uid  → canlı dinleyici   (C okuma)
 *   5. announcements (üniversiteye göre)            → canlı dinleyici   (A okuma)
 *   6. events KOLEKSİYONUNUN TAMAMI                 → tek seferlik      (E okuma)
 *   7. appointmentsProvider: kayıtlı her etkinlik için ayrı doküman okuma (R okuma)
 *
 * 6. madde belirleyici: öğrencinin göreceği etkinlikler sunucuda değil
 * İSTEMCİDE süzülüyor, bu yüzden her giriş bütün katalogu indiriyor.
 * Giriş sayısı × katalog büyüklüğü = okuma patlaması.
 */

import {
  connect, RunLog, fireAtOnce, runThrottled, summarize, fmtRow, TABLE_HEADER,
  studentUid, waitForEmulator,
} from './lib/harness.mjs';

const LEVELS = [10, 50, 100, 250, 500, 1000];
const CATALOG_SIZES = [100, 300, 1000];
/** Öğrenci başına kayıt ve belge sayısı (ortalama kullanıcı). */
const REGS_PER_STUDENT = 6;
const CERTS_PER_STUDENT = 3;

const log = new RunLog('04-login');

async function seedCatalog(db, size) {
  const snap = await db.collection('events').count().get();
  const have = snap.data().count;
  if (have >= size) return have;
  for (let start = have; start < size; start += 400) {
    const batch = db.batch();
    for (let i = start; i < Math.min(start + 400, size); i++) {
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
  return size;
}

async function seedStudents(db, count) {
  for (let start = 0; start < count; start += 100) {
    const batch = db.batch();
    for (let i = start; i < Math.min(start + 100, count); i++) {
      const uid = studentUid(i);
      batch.set(db.doc(`users/${uid}`), {
        uid, email: `${uid}@ornek.edu.tr`, role: 'student',
        lastRole: 'student', roles: { student: true },
      });
      batch.set(db.doc(`student_profiles/${uid}`), {
        uid, firstName: `Ogrenci${i}`, lastName: 'Test',
        university: 'Istanbul Universitesi',
        department: 'Bilgisayar Muhendisligi',
        classYear: '3', city: 'Istanbul', phoneVerified: true,
      });
      for (let r = 0; r < REGS_PER_STUDENT; r++) {
        batch.set(db.doc(`event_registrations/loadtest_catalog_${r}_${uid}`), {
          eventId: `loadtest_catalog_${r}`, studentId: uid,
          studentName: `Ogrenci${i} Test`, registeredAtMs: Date.now(),
          deadlineAtMs: Date.now() + 30 * 24 * 60 * 60 * 1000,
        });
      }
      for (let c = 0; c < CERTS_PER_STUDENT; c++) {
        batch.set(db.doc(`student_certificates/loadtest_catalog_${c}_${uid}`), {
          studentId: uid, eventId: `loadtest_catalog_${c}`,
          clubId: 'loadtest_club', issuedAtMs: Date.now(),
        });
      }
      batch.set(db.doc(`announcements/loadtest_ann_${i % 10}`), {
        title: `Duyuru ${i % 10}`, targetUniversity: 'Istanbul Universitesi',
        createdAtMs: Date.now(),
      });
    }
    await batch.commit();
  }
}

/** Tek bir girişin açtığı okumaların tamamı. */
async function loginSequence(db, uid) {
  let reads = 0;

  // 1-2: kullanıcı + profil (dinleyicinin ilk anlık görüntüsü)
  const [userSnap, profileSnap] = await Promise.all([
    db.doc(`users/${uid}`).get(),
    db.doc(`student_profiles/${uid}`).get(),
  ]);
  reads += 2;
  const university = profileSnap.data()?.university ?? '';

  // 3-5: kayıtlar, belgeler, duyurular
  const [regs, certs, anns] = await Promise.all([
    db.collection('event_registrations').where('studentId', '==', uid).get(),
    db.collection('student_certificates').where('studentId', '==', uid).get(),
    db.collection('announcements').where('targetUniversity', '==', university).get(),
  ]);
  reads += regs.size + certs.size + anns.size;

  // 6: studentVisibleEventsProvider → fetchAllEvents()
  const all = await db.collection('events').get();
  reads += all.size;

  // 7: appointmentsProvider → kayıtlı her etkinlik ayrı ayrı
  const eventIds = [...new Set(regs.docs.map((d) => d.data().eventId))];
  const fetched = await Promise.all(
    eventIds.map((id) => db.doc(`events/${id}`).get()),
  );
  reads += fetched.length;

  return { reads, userExists: userSnap.exists };
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 4 — EŞZAMANLI GİRİŞ');
  log.say('══════════════════════════════════════════════════════════════');

  log.say('\nTest verisi hazırlanıyor…');
  await seedStudents(db, Math.max(...LEVELS));
  log.say(`  ${Math.max(...LEVELS)} öğrenci · ${REGS_PER_STUDENT} kayıt · ${CERTS_PER_STUDENT} belge`);

  for (const catalog of CATALOG_SIZES) {
    const size = await seedCatalog(db, catalog);
    log.say('');
    log.say(`Katalog: ${size} etkinlik — N kişi AYNI ANDA giriş yapıyor`);
    log.say('─'.repeat(110));
    log.say(TABLE_HEADER + '  okuma/giriş   toplam okuma');
    log.say('─'.repeat(110));

    for (const n of LEVELS) {
      const run = await fireAtOnce(n, (i) => loginSequence(db, studentUid(i)));
      const s = summarize(run);
      const totalReads = run.results
        .map((r) => r.value?.reads ?? 0)
        .reduce((a, b) => a + b, 0);
      const perLogin = s.ok ? Math.round(totalReads / s.ok) : 0;

      log.event('login', { catalog: size, n, ...s, totalReads, perLogin });
      log.say(
        fmtRow(n, s) +
          `   ${String(perLogin).padStart(10)}   ${String(totalReads).padStart(12)}`,
      );
    }
  }

  // ── Kuyruklu giriş: aynı yük, sınırlı eşzamanlılık ─────────────────
  log.say('');
  log.say('Karşılaştırma: 1000 giriş, kuyruk genişliği sınırlı (katalog 1000)');
  log.say('─'.repeat(110));
  log.say('K'.padEnd(10) + TABLE_HEADER.slice(10));
  log.say('─'.repeat(110));
  for (const k of [32, 64, 128, 256]) {
    const run = await runThrottled(1000, k, (i) =>
      loginSequence(db, studentUid(i)),
    );
    const s = summarize(run);
    log.event('login_throttled', { k, n: 1000, ...s });
    log.say(fmtRow(k, s));
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
