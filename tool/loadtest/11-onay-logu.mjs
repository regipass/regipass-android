/**
 * TEST 11 — KVKK/sözleşme onay logu gerçekten DB'ye yazılıyor mu?
 *
 * Kayıt ekranındaki onay kutucuklarının Firestore'a düştüğünü uçtan uca
 * doğrular. Dart tarafındaki iki yazımın birebir aynısını yapar:
 *
 *   1. ProfileRepository.recordConsent  → users/{uid}
 *      (hesap oluşur oluşmaz; profil belgesi henüz yok)
 *   2. ProfileRepository.saveStudentProfile / saveClubProfile
 *      → student_profiles/{uid} · club_profiles/{uid}
 *      (bilgi formu kaydedilirken onayın kopyası)
 *
 * Ölçtüğü şeyler GERÇEK: güvenlik kuralları bu yazımlara izin veriyor mu,
 * alanlar hangi tiple saklanıyor, saniye çözünürlüğü yazma/okuma turunda
 * korunuyor mu.
 *
 * Kurallar ASIL dosyadan okunur (Desktop/REGİPASS/firestore.rules) —
 * tool/loadtest altındaki kopyalar bayat olabilir (bkz. README).
 *
 * Çalıştırma:
 *   cd tool/loadtest/rules-env && firebase emulators:start --only firestore --project eventapp-604a5
 *   node 11-onay-logu.mjs
 */

import {
  initializeTestEnvironment,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  serverTimestamp,
  deleteField,
  Timestamp,
} from 'firebase/firestore';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

import { RunLog, PROJECT_ID } from './lib/harness.mjs';

const log = new RunLog('11-onay-logu');

const PORT = Number(process.env.LOADTEST_RULES_PORT ?? 8733);

/// Asıl kural dosyası; yoksa depodaki kopyaya düşülür ama bu AÇIKÇA belirtilir
/// (bayat kopyayla yapılan test bir kez yanlış sonuç vermişti).
const AUTHORITATIVE = join(homedir(), 'Desktop', 'REGİPASS', 'firestore.rules');
const FALLBACK = join(import.meta.dirname, 'firestore.rules');

const STUDENT = 'consent_student';
const CLUB = 'consent_club';
const OTHER = 'consent_other';
const EXISTING_CLUB = 'consent_existing_club';

const STUDENT_PHONE = '+905551112233';
const CLUB_PHONE = '+905551112244';
const TERMS_VERSION = '2026-09-02';

/// Kullanıcının "kaydol"a bastığı an — saniyesi (45) ve milisaniyesi (123)
/// bilerek sıfırdan farklı: yazma/okuma turunda kırpılırsa test yakalar.
const CLICK_AT = new Date(2026, 8, 3, 14, 23, 45, 123);
const CLICK_MS = CLICK_AT.getTime();

let passed = 0;
let failed = 0;

async function check(name, fn) {
  try {
    await fn();
    passed += 1;
    log.say(`  ✓ ${name}`);
    log.event('case', { name, result: 'pass' });
  } catch (error) {
    failed += 1;
    log.say(`  ✗ ${name}`);
    log.say(`      ${String(error.message ?? error).slice(0, 300)}`);
    log.event('case', { name, result: 'fail', error: String(error.message ?? error) });
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function equal(actual, expected, label) {
  assert(
    actual === expected,
    `${label}: beklenen ${JSON.stringify(expected)}, gelen ${JSON.stringify(actual)}`,
  );
}

/// Saklanan zaman damgasını "03.09.2026 14:23:45.123" olarak yazar.
function stamp(ts) {
  if (!ts || typeof ts.toDate !== 'function') return String(ts);
  const d = ts.toDate();
  const p = (n, w = 2) => String(n).padStart(w, '0');
  return (
    `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()} ` +
    `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}.${p(d.getMilliseconds(), 3)}`
  );
}

// ── Dart tarafındaki yazımların birebir karşılıkları ──────────────────

/// ProfileRepository.recordConsent
function consentPayload({ termsAccepted, marketingConsent, acceptedAtMs, uid }) {
  const acceptedAt = Timestamp.fromMillis(acceptedAtMs);
  return {
    uid,
    termsAccepted,
    termsAcceptedAt: acceptedAt,
    termsVersion: TERMS_VERSION,
    marketingConsent,
    marketingConsentAt: marketingConsent ? acceptedAt : deleteField(),
    updatedAt: serverTimestamp(),
  };
}

/// ProfileRepository.saveStudentProfile — onayla ilgili kısmı eksiksiz,
/// gerisi kuralların isteyeceği kadar.
function studentProfilePayload({ termsAccepted, marketingConsent, acceptedAtMs }) {
  return {
    uid: STUDENT,
    email: 'ogrenci@ornek.com',
    role: 'student',
    firstName: 'Ayşe',
    lastName: 'Yılmaz',
    phone: STUDENT_PHONE,
    city: 'İstanbul',
    university: 'Boğaziçi Üniversitesi',
    department: 'Bilgisayar Mühendisliği',
    studentNumber: '2021123456',
    classYear: '3. Sınıf',
    gender: 'female',
    photoUrl: '',
    photoPath: '',
    onboardingCompleted: true,
    phoneVerified: true,
    hasPassword: true,
    termsAccepted,
    termsAcceptedAt: Timestamp.fromMillis(acceptedAtMs),
    termsVersion: TERMS_VERSION,
    marketingConsent,
    updatedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
  };
}

function clubProfilePayload({ termsAccepted, marketingConsent, acceptedAtMs }) {
  return {
    uid: CLUB,
    email: 'kulup@ornek.com',
    role: 'club',
    firstName: 'Mehmet',
    lastName: 'Demir',
    phone: CLUB_PHONE,
    city: 'İstanbul',
    university: 'Boğaziçi Üniversitesi',
    clubName: 'Yazılım Kulübü',
    clubField: 'Teknoloji',
    clubFields: ['Teknoloji'],
    clubPurpose: 'Amaç',
    clubContents: 'İçerik',
    onboardingCompleted: true,
    clubStatus: 'documents_pending',
    phoneVerified: true,
    hasPassword: true,
    termsAccepted,
    termsAcceptedAt: Timestamp.fromMillis(acceptedAtMs),
    termsVersion: TERMS_VERSION,
    marketingConsent,
    updatedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
  };
}

async function main() {
  const rulesPath = existsSync(AUTHORITATIVE) ? AUTHORITATIVE : FALLBACK;
  log.say(`Kurallar: ${rulesPath}`);
  if (rulesPath === FALLBACK) {
    log.say('  ! UYARI: asıl kural dosyası bulunamadı, depodaki kopya kullanılıyor.');
  }

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: PORT,
      rules: readFileSync(rulesPath, 'utf8'),
    },
  });
  await testEnv.clearFirestore();

  // Telefonu doğrulanmış hesaplar: kurallar phoneVerified:true için ID
  // token'da phone_number iddiası arıyor (bkz. phoneVerificationValid).
  const student = testEnv.authenticatedContext(STUDENT, {
    phone_number: STUDENT_PHONE,
  });
  const club = testEnv.authenticatedContext(CLUB, { phone_number: CLUB_PHONE });
  const other = testEnv.authenticatedContext(OTHER);

  const studentDb = student.firestore();
  const clubDb = club.firestore();
  const otherDb = other.firestore();

  log.say('');
  log.say('── 1. Kayıt anı: users/{uid} ────────────────────────────────');

  await check('onay kaydı users/{uid} belgesine yazılır', async () => {
    await setDoc(
      doc(studentDb, 'users', STUDENT),
      consentPayload({
        uid: STUDENT,
        termsAccepted: true,
        marketingConsent: true,
        acceptedAtMs: CLICK_MS,
      }),
      { merge: true },
    );
  });

  let userDocData;
  await check('yazılan kayıt geri okunur ve alanlar doğrudur', async () => {
    const snap = await getDoc(doc(studentDb, 'users', STUDENT));
    assert(snap.exists(), 'users belgesi oluşmadı');
    userDocData = snap.data();

    equal(userDocData.termsAccepted, true, 'termsAccepted');
    equal(userDocData.marketingConsent, true, 'marketingConsent');
    equal(userDocData.termsVersion, TERMS_VERSION, 'termsVersion');
  });

  await check('onay anı SANİYESİYLE korunur (yazma/okuma turunda kırpılmaz)', async () => {
    const ts = userDocData.termsAcceptedAt;
    assert(ts && typeof ts.toMillis === 'function', 'termsAcceptedAt Timestamp değil');
    equal(ts.toMillis(), CLICK_MS, 'termsAcceptedAt (ms)');

    const d = ts.toDate();
    equal(d.getHours(), 14, 'saat');
    equal(d.getMinutes(), 23, 'dakika');
    equal(d.getSeconds(), 45, 'saniye');
  });

  await check('pazarlama izni verildiyse marketingConsentAt da yazılır', async () => {
    const ts = userDocData.marketingConsentAt;
    assert(ts && typeof ts.toMillis === 'function', 'marketingConsentAt yok');
    equal(ts.toMillis(), CLICK_MS, 'marketingConsentAt (ms)');
  });

  await check('pazarlama izni yoksa marketingConsentAt hiç oluşmaz', async () => {
    await setDoc(
      doc(clubDb, 'users', CLUB),
      consentPayload({
        uid: CLUB,
        termsAccepted: true,
        marketingConsent: false,
        acceptedAtMs: CLICK_MS,
      }),
      { merge: true },
    );
    const snap = await getDoc(doc(clubDb, 'users', CLUB));
    const data = snap.data();
    equal(data.termsAccepted, true, 'termsAccepted');
    equal(data.marketingConsent, false, 'marketingConsent');
    assert(
      !('marketingConsentAt' in data),
      `marketingConsentAt yazılmamalıydı: ${JSON.stringify(data.marketingConsentAt)}`,
    );
  });

  await check('başkası senin adına onay kaydı yazamaz (kural reddeder)', async () => {
    await assertFails(
      setDoc(
        doc(otherDb, 'users', STUDENT),
        consentPayload({
          uid: STUDENT,
          termsAccepted: true,
          marketingConsent: true,
          acceptedAtMs: CLICK_MS,
        }),
        { merge: true },
      ),
    );
  });

  // users belgesinde clubStatus/banned varsa merge semantiği yüzünden
  // kural dallarının hâlâ geçtiğini doğrular (kural dosyasındaki uyarı).
  await check('mevcut clubStatus/banned taşıyan belgeye onay yazılabilir', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', EXISTING_CLUB), {
        uid: EXISTING_CLUB,
        role: 'club',
        clubStatus: 'approved',
        banned: false,
      });
    });

    const existing = testEnv.authenticatedContext(EXISTING_CLUB);
    await setDoc(
      doc(existing.firestore(), 'users', EXISTING_CLUB),
      consentPayload({
        uid: EXISTING_CLUB,
        termsAccepted: true,
        marketingConsent: false,
        acceptedAtMs: CLICK_MS,
      }),
      { merge: true },
    );

    const snap = await getDoc(doc(existing.firestore(), 'users', EXISTING_CLUB));
    equal(snap.data().termsAccepted, true, 'termsAccepted');
    equal(snap.data().clubStatus, 'approved', 'clubStatus korunmalı');
  });

  log.say('');
  log.say('── 2. Bilgi formu: profil belgesine kopya ────────────────────');

  let studentProfile;
  await check('öğrenci profiline onay alanları yazılır', async () => {
    await setDoc(
      doc(studentDb, 'student_profiles', STUDENT),
      studentProfilePayload({
        termsAccepted: true,
        marketingConsent: true,
        acceptedAtMs: CLICK_MS,
      }),
      { merge: true },
    );
    const snap = await getDoc(doc(studentDb, 'student_profiles', STUDENT));
    assert(snap.exists(), 'öğrenci profili oluşmadı');
    studentProfile = snap.data();

    equal(studentProfile.termsAccepted, true, 'termsAccepted');
    equal(studentProfile.marketingConsent, true, 'marketingConsent');
    equal(studentProfile.termsVersion, TERMS_VERSION, 'termsVersion');
    equal(studentProfile.termsAcceptedAt.toMillis(), CLICK_MS, 'termsAcceptedAt (ms)');
  });

  let clubProfile;
  await check('kulüp profiline onay alanları yazılır', async () => {
    await setDoc(
      doc(clubDb, 'club_profiles', CLUB),
      clubProfilePayload({
        termsAccepted: true,
        marketingConsent: false,
        acceptedAtMs: CLICK_MS,
      }),
      { merge: true },
    );
    const snap = await getDoc(doc(clubDb, 'club_profiles', CLUB));
    assert(snap.exists(), 'kulüp profili oluşmadı');
    clubProfile = snap.data();

    equal(clubProfile.termsAccepted, true, 'termsAccepted');
    equal(clubProfile.marketingConsent, false, 'marketingConsent');
    equal(clubProfile.termsAcceptedAt.toMillis(), CLICK_MS, 'termsAcceptedAt (ms)');
  });

  await check('yönetici kulübün onay kaydını okuyabilir (kart bu veriyi gösteriyor)', async () => {
    const admin = testEnv.authenticatedContext('AY1gi7Zi9AcqhjZinEkR1baB9T72');
    const snap = await getDoc(doc(admin.firestore(), 'club_profiles', CLUB));
    assert(snap.exists(), 'yönetici kulüp profilini okuyamadı');
    equal(snap.data().termsAccepted, true, 'termsAccepted');
    assert(snap.data().termsAcceptedAt != null, 'termsAcceptedAt yönetici tarafında boş');
  });

  // ── DB'de ne var? ──────────────────────────────────────────────────
  log.say('');
  log.say('── 3. DB\'deki kayıt ─────────────────────────────────────────');
  const rows = [
    ['users/' + STUDENT, userDocData],
    ['student_profiles/' + STUDENT, studentProfile],
    ['club_profiles/' + CLUB, clubProfile],
  ];
  for (const [path, data] of rows) {
    if (!data) continue;
    log.say(`  ${path}`);
    log.say(`      termsAccepted     : ${data.termsAccepted}`);
    log.say(`      termsAcceptedAt   : ${stamp(data.termsAcceptedAt)}`);
    log.say(`      termsVersion      : ${data.termsVersion}`);
    log.say(`      marketingConsent  : ${data.marketingConsent}`);
    if (data.marketingConsentAt) {
      log.say(`      marketingConsentAt: ${stamp(data.marketingConsentAt)}`);
    }
  }

  log.say('');
  log.say(`Sonuç: ${passed} geçti, ${failed} kaldı.`);
  log.event('summary', { passed, failed });

  await testEnv.cleanup();
  log.close();
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((error) => {
  log.say(`ÇÖKTÜ: ${error?.stack ?? error}`);
  log.close();
  process.exit(1);
});
