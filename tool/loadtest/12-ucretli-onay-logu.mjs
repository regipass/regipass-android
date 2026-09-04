/**
 * TEST 12 — ücretli etkinlik onay logu: yazılıyor mu, ZORUNLU mu?
 *
 * Yazılan alanlar ELLE yazılmaz: uygulamanın kendi kodu üretir.
 *
 *   dart run tool/consent_log_fields.dart > consent_fields.json
 *   node 12-ucretli-onay-logu.mjs consent_fields.json
 *
 * (Emulator: cd tool/loadtest/rules-env &&
 *  firebase emulators:start --only firestore --project eventapp-604a5)
 *
 * Kurallar ASIL dosyadan okunur (Desktop/REGİPASS/firestore.rules) —
 * tool/loadtest altındaki kopyalar bayat olabilir (bkz. README).
 *
 * Şema web ile ortaktır: iki belgede de `paidConsentLog` haritası
 * ({approved, text, approvedAtMs, approvedAt, approvedAtFormatted}).
 *
 * Kontrol edilenler:
 *   1. Kulüp, onay logu ile ücretli etkinlik oluşturabiliyor; logsuz
 *      ücretli etkinlik oluşturamıyor (kural reddediyor).
 *   2. Öğrenci, onay logu ile kayıt yazabiliyor; logsuz ücretli kayıt
 *      kural tarafından REDDEDİLİYOR. (Kayıt, kontenjan parçasının sayacıyla
 *      aynı commit'te yazılır — üretim kuralı bunu şart koşuyor.)
 *   3. Alanlar geri okunduğunda aynen duruyor (damga, metin).
 *   4. Kulüp öğrencinin onayını okuyabiliyor; öğrenci PROFİLİNE hiçbir onay
 *      alanı sızmıyor.
 *   5. Ücretsiz etkinlikte tek bir onay alanı bile yazılmıyor ve ücretsiz
 *      etkinlik onaysız oluşturulabiliyor (kural ücretsizi etkilemiyor).
 *   6. Var olan log silinemiyor; ücretsizden ücretliye geçişte onay şart.
 */

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, deleteDoc, getDoc, setDoc, updateDoc, writeBatch, increment, deleteField } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const PROJECT_ID = 'eventapp-604a5';
const PORT = Number(process.env.CONSENT_PORT ?? 8733);
const RULES = process.env.RULES_FILE
  ?? join(homedir(), 'Desktop', 'REGİPASS', 'firestore.rules');
const FIELDS = JSON.parse(readFileSync(process.argv[2], 'utf8'));

const CLUB = 'rulestest_club';
const STUDENT = 'rulestest_student';
const PAID_EVENT = 'consentlog_paid_event';
const FREE_EVENT = 'consentlog_free_event';
const NO_CONSENT_EVENT = 'consentlog_paid_noconsent';
const LEGACY_EVENT = 'consentlog_legacy_paid';
const SHARDLESS_EVENT = 'consentlog_shardless_paid';

let pass = 0;
let fail = 0;

async function check(name, fn) {
  try {
    await fn();
    pass += 1;
    console.log(`  ✓ ${name}`);
  } catch (error) {
    fail += 1;
    console.log(`  ✗ ${name}`);
    console.log(`      ${String(error.message ?? error).slice(0, 300)}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/** Reddedilmesi BEKLENEN yazım; geçerse test düşer. */
async function expectDenied(promiseFactory, message) {
  let allowed = false;
  try {
    await promiseFactory();
    allowed = true;
  } catch {
    // beklenen
  }
  assert(!allowed, message);
}

/** RegistrationService._registrationPayload karşılığı (onay dışı alanlar). */
function registrationPayload(eventId, consent) {
  return {
    registrationId: `${eventId}_${STUDENT}`,
    eventId,
    eventTitle: 'Ucretli Etkinlik',
    clubId: CLUB,
    clubName: 'Kural Kulubu',
    studentId: STUDENT,
    studentEmail: `${STUDENT}@ornek.edu.tr`,
    studentName: 'Test Ogrenci',
    studentUniversity: 'Istanbul Universitesi',
    studentDepartment: 'Bilgisayar Muhendisligi',
    registeredAtMs: Date.now(),
    quotaShard: 0,
    ...(consent ? { paidConsentLog: consent } : {}),
  };
}

/** EventRepository.createEvent karşılığı (onay dışı alanlar). */
function eventPayload(feeType, consent) {
  return {
    title: feeType === 'paid' ? 'Ucretli Etkinlik' : 'Ucretsiz Etkinlik',
    feeType,
    feeAmount: feeType === 'paid' ? 250 : 0,
    clubId: CLUB,
    clubName: 'Kural Kulubu',
    quota: 4,
    quotaShardCount: 1,
    targetScope: 'public',
    registrationClosed: false,
    hiddenFromClubList: false,
    hiddenGlobally: false,
    currentSession: 0,
    sessionsCompleted: false,
    deadlineAtMs: Date.now() + 86400000,
    createdAtMs: Date.now(),
    ...(consent ? { paidConsentLog: consent } : {}),
  };
}

/** Kaydı, kontenjan parçasının sayacıyla AYNI commit'te yazar. */
function claimAndRegister(db, eventId, consent) {
  const batch = writeBatch(db);
  batch.set(
    doc(db, `event_registrations/${eventId}_${STUDENT}`),
    registrationPayload(eventId, consent),
  );
  batch.update(doc(db, `events/${eventId}/quota_shards/0`), {
    count: increment(1),
  });
  return batch.commit();
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: PORT,
      rules: readFileSync(RULES, 'utf8'),
    },
  });

  // ── Zemin: onaylı kulüp + öğrenci profili ──────────────────────────
  // Önceki koşudan kalan belgeler silinir: kirli durum, "ücretsizden
  // ücretliye geçiş" gibi kontrolleri sessizce yanlış sonuçlandırır.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const id of [PAID_EVENT, FREE_EVENT, NO_CONSENT_EVENT, LEGACY_EVENT, SHARDLESS_EVENT]) {
      await deleteDoc(doc(db, `events/${id}`)).catch(() => {});
      await deleteDoc(doc(db, `events/${id}/quota_shards/0`)).catch(() => {});
      await deleteDoc(doc(db, `event_registrations/${id}_${STUDENT}`)).catch(() => {});
    }
    await setDoc(doc(db, `users/${CLUB}`), {
      uid: CLUB, role: 'club', lastRole: 'club', roles: { club: true },
    });
    await setDoc(doc(db, `club_profiles/${CLUB}`), {
      uid: CLUB, clubName: 'Kural Kulubu', clubStatus: 'approved',
      onboardingCompleted: true, university: 'Istanbul Universitesi',
    });
    await setDoc(doc(db, `users/${STUDENT}`), {
      uid: STUDENT, role: 'student', lastRole: 'student',
      roles: { student: true },
    });
    await setDoc(doc(db, `student_profiles/${STUDENT}`), {
      uid: STUDENT, university: 'Istanbul Universitesi',
      department: 'Bilgisayar Muhendisligi', phoneVerified: true,
    });
  });

  const club = testEnv.authenticatedContext(CLUB).firestore();
  const student = testEnv.authenticatedContext(STUDENT).firestore();

  console.log('══════════════════════════════════════════════════════');
  console.log(' ÜCRETLİ ETKİNLİK ONAY LOGU — emulator doğrulaması');
  console.log(`  kurallar: ${RULES}`);
  console.log('══════════════════════════════════════════════════════');
  console.log('');
  console.log('1) Kulüp onayı — etkinlik belgesi');

  await check('kulüp ücretli etkinliği onay logu ile oluşturabiliyor', async () => {
    const batch = writeBatch(club);
    batch.set(doc(club, `events/${PAID_EVENT}`), eventPayload('paid', FIELDS.club));
    batch.set(doc(club, `events/${PAID_EVENT}/quota_shards/0`), {
      count: 0, capacity: 4,
    });
    await batch.commit();
  });

  await check('onay logu ETKİNLİK belgesinde aynen duruyor', async () => {
    let data;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), `events/${PAID_EVENT}`));
      data = snap.data();
    });
    assert(data, 'etkinlik belgesi yok');
    const log = data.paidConsentLog;
    assert(log, 'paidConsentLog yok');
    for (const [key, value] of Object.entries(FIELDS.club)) {
      assert(
        JSON.stringify(log[key]) === JSON.stringify(value),
        `${key}: beklenen ${JSON.stringify(value)} — gelen ${JSON.stringify(log[key])}`,
      );
    }
    assert(
      /^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}$/.test(log.approvedAtFormatted),
      `damga biçimi beklenmedik: ${log.approvedAtFormatted}`,
    );
    console.log(`      damga : ${log.approvedAtFormatted}`);
    console.log(`      metin : ${String(log.text).slice(0, 60)}…`);
  });

  await check('KURAL: onaysız ücretli etkinlik oluşturulamıyor', async () => {
    await expectDenied(
      () => setDoc(doc(club, `events/${NO_CONSENT_EVENT}`), eventPayload('paid', null)),
      'onaysız ücretli etkinlik oluşturuldu',
    );
  });

  await check('KURAL: onayı bozuk (approved:false) ücretli etkinlik reddediliyor', async () => {
    await expectDenied(
      () => setDoc(doc(club, `events/${NO_CONSENT_EVENT}`), eventPayload('paid', {
        ...FIELDS.club, approved: false,
      })),
      'approved:false ile ücretli etkinlik oluşturuldu',
    );
  });

  await check('KURAL: metni boş onay reddediliyor', async () => {
    await expectDenied(
      () => setDoc(doc(club, `events/${NO_CONSENT_EVENT}`), eventPayload('paid', {
        ...FIELDS.club, text: '',
      })),
      'boş metinli onay kabul edildi',
    );
  });

  console.log('');
  console.log('2) Öğrenci onayı — kayıt belgesi');

  await check('KURAL: onaysız ücretli kayıt reddediliyor', async () => {
    await expectDenied(
      () => claimAndRegister(student, PAID_EVENT, null),
      'onaysız ücretli kayıt yazıldı',
    );
  });

  await check('öğrenci kaydı onay logu ile yazabiliyor', async () => {
    await claimAndRegister(student, PAID_EVENT, FIELDS.student);
  });

  await check('onay logu KAYIT belgesinde aynen duruyor', async () => {
    let data;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(
        doc(ctx.firestore(), `event_registrations/${PAID_EVENT}_${STUDENT}`),
      );
      data = snap.data();
    });
    assert(data, 'kayıt belgesi yok');
    const log = data.paidConsentLog;
    assert(log, 'paidConsentLog yok');
    for (const [key, value] of Object.entries(FIELDS.student)) {
      assert(
        JSON.stringify(log[key]) === JSON.stringify(value),
        `${key}: beklenen ${JSON.stringify(value)} — gelen ${JSON.stringify(log[key])}`,
      );
    }
    console.log(`      damga : ${log.approvedAtFormatted}`);
  });

  await check('kulüp, öğrencinin onay logunu OKUYABİLİYOR', async () => {
    const snap = await getDoc(
      doc(club, `event_registrations/${PAID_EVENT}_${STUDENT}`),
    );
    assert(snap.exists(), 'kulüp kaydı okuyamadı');
    assert(
      snap.data().paidConsentLog?.text === FIELDS.student.text,
      'kulübün okuduğu metin farklı',
    );
  });

  await check('öğrenci PROFİL belgesine hiçbir onay alanı yazılmadı', async () => {
    let data;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), `student_profiles/${STUDENT}`));
      data = snap.data();
    });
    const leaked = Object.keys(data).filter(
      (k) => k.toLowerCase().includes('consent'),
    );
    assert(leaked.length === 0, `profilde onay alanı var: ${leaked.join(', ')}`);
  });

  console.log('');
  console.log('3) Ücretsiz etkinlik kurallardan etkilenmiyor');

  await check('ücretsiz etkinlik onaysız oluşturulabiliyor ve onay alanı taşımıyor', async () => {
    const batch = writeBatch(club);
    batch.set(doc(club, `events/${FREE_EVENT}`), eventPayload('free', null));
    batch.set(doc(club, `events/${FREE_EVENT}/quota_shards/0`), {
      count: 0, capacity: 4,
    });
    await batch.commit();

    let data;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), `events/${FREE_EVENT}`));
      data = snap.data();
    });
    assert(!data.paidConsentLog, 'ücretsiz etkinlikte onay logu var');
  });

  await check('ücretsiz etkinliğe onaysız kayıt yazılabiliyor', async () => {
    await claimAndRegister(student, FREE_EVENT, null);
  });

  console.log('');
  console.log('4) Var olan log korunuyor');

  await check('KURAL: kulüp kendi onay logunu silemiyor', async () => {
    await expectDenied(
      () => updateDoc(doc(club, `events/${PAID_EVENT}`), {
        paidConsentLog: deleteField(),
      }),
      'onay logu silindi',
    );
  });

  await check('kulüp etkinliğin diğer alanlarını güncelleyebiliyor', async () => {
    await updateDoc(doc(club, `events/${PAID_EVENT}`), {
      registrationClosed: true,
    });
  });

  // Web (club-create-event.js) ücretsize dönerken logu deleteField() ile
  // siler; mobil updateEvent de aynısını yapar. Kural buna izin VERMELİ.
  await check('ücretliden ücretsize dönüşte log silinebiliyor', async () => {
    await updateDoc(doc(club, `events/${PAID_EVENT}`), {
      feeType: 'free', feeAmount: 0, paidConsentLog: deleteField(),
    });
    // Geri al: sonraki kontroller ücretli hâli bekliyor.
    await updateDoc(doc(club, `events/${PAID_EVENT}`), {
      feeType: 'paid', feeAmount: 250, paidConsentLog: FIELDS.club,
    });
  });

  await check('KURAL: ücretsizden ücretliye geçiş onay olmadan reddediliyor', async () => {
    await expectDenied(
      () => updateDoc(doc(club, `events/${FREE_EVENT}`), {
        feeType: 'paid', feeAmount: 100,
      }),
      'onaysız ücretliye çevrildi',
    );
  });

  await check('ücretliye geçiş onay logu ile kabul ediliyor', async () => {
    await updateDoc(doc(club, `events/${FREE_EVENT}`), {
      feeType: 'paid', feeAmount: 100, paidConsentLog: FIELDS.club,
    });
  });

  // Bu kural yayınlanmadan ÖNCE oluşmuş ücretli etkinlikler log taşımaz;
  // kulüp onları hâlâ yönetebilmeli (kayıt kapatma, check-in vb.).
  await check('eski (logsuz) ücretli etkinlik hâlâ güncellenebiliyor', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `events/${LEGACY_EVENT}`),
        eventPayload('paid', null),
      );
    });
    await updateDoc(doc(club, `events/${LEGACY_EVENT}`), {
      registrationClosed: true,
    });
  });

  console.log('');
  console.log('5) Mevcut akışlar bozulmuyor (1000 ifade bütçesi)');

  // Öğrenci profilini güncelleyince kayıttaki kopyayı tazeler
  // (studentCanRefreshOwnSnapshot). Onay koşulu bu yolu kırmamalı.
  await check('öğrenci ücretli kayıttaki kişisel bilgi kopyasını tazeleyebiliyor', async () => {
    await updateDoc(
      doc(student, `event_registrations/${PAID_EVENT}_${STUDENT}`),
      { studentName: 'Test Ogrenci (guncel)', profileSyncedAtMs: Date.now() },
    );
  });

  // Kontenjansız (parçasız) ETKİNLİK: kayıt merge ile yazılır, ikinci yazım
  // kuralın AĞIR update dalından geçer. Onay koşulu bu dalın 1000 ifade
  // bütçesini taşırmamalı — taşarsa eski etkinliklere kayıt tümden kırılır.
  await check('kontenjansız etkinlikte kayıt merge ile tekrar yazılabiliyor', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${SHARDLESS_EVENT}`), {
        ...eventPayload('paid', FIELDS.club),
        quota: 0,
        quotaShardCount: 0,
      });
    });
    const ref = doc(student, `event_registrations/${SHARDLESS_EVENT}_${STUDENT}`);
    const payload = registrationPayload(SHARDLESS_EVENT, FIELDS.student);
    delete payload.quotaShard;
    await setDoc(ref, payload, { merge: true });
    // İkincisi UPDATE yolundan geçer.
    await setDoc(ref, payload, { merge: true });
  });

  await check('KURAL: kayıttaki onay logu sonradan silinemiyor', async () => {
    await expectDenied(
      () => updateDoc(
        doc(student, `event_registrations/${PAID_EVENT}_${STUDENT}`),
        { paidConsentLog: deleteField() },
      ),
      'kayıttaki onay logu silindi',
    );
  });

  await testEnv.cleanup();

  console.log('');
  console.log(`  geçti: ${pass}   düştü: ${fail}`);
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
