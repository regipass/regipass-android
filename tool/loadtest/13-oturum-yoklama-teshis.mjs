/**
 * TEST 13 (teşhis) — Öğrenci oturum QR'ını okuttuğunda yazım neden
 * `permission-denied` alıyor?
 *
 * Mobildeki `EventRepository.markOwnSessionCheckIn` yazımının BİREBİR aynısını
 * gerçek kural dosyasına (Regipass-Web/firestore.rules) karşı çalıştırır ve
 * hangi veri şeklinde düştüğünü tek tek gösterir.
 *
 * Çalıştırma:
 *   cd tool/loadtest/rules-env && firebase emulators:start --only firestore --project eventapp-604a5
 *   node 13-oturum-yoklama-teshis.mjs
 */

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

/// Yama içinde bu değeri taşıyan alan belgeden TAMAMEN çıkarılır
/// (SIL set() ile kullanılamıyor).
const SIL = Symbol('sil');

function uygula(temel, yama) {
  const cikti = { ...temel, ...yama };
  for (const [anahtar, deger] of Object.entries(yama)) {
    if (deger === SIL) delete cikti[anahtar];
  }
  return cikti;
}
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { WEB_ROOT } from './lib/web-repo.mjs';

import { PROJECT_ID } from './lib/harness.mjs';

const PORT = Number(process.env.LOADTEST_RULES_PORT ?? 8733);
/// Varsayılan: asıl kural dosyası. Eski bir kopyayla karşılaştırmak için
/// `LOADTEST_RULES=tool/loadtest/firestore.rules node 13-...mjs`.
const RULES = process.env.LOADTEST_RULES
  ?? join(WEB_ROOT, 'firestore.rules');

const CLUB = 'sess_club';
const STUDENT = 'sess_student';
const EVENT = 'sess_event';
const REG = `${EVENT}_${STUDENT}`;

const DOOR_MS = Date.parse('2026-09-06T08:30:00Z');
const NOW_MS = Date.parse('2026-09-06T10:00:00Z');

/// Web'in club-create-event.js ile yazdığı etkinliğin oturum/check-in alanları.
function eventData(patch = {}) {
  const temel = {
    clubId: CLUB,
    title: 'Teşhis Etkinliği',
    sessionCount: 3,
    currentSession: 1,
    sessionsCompleted: false,
    checkinMode: 'checkin_attendance',
    allowSessionWithoutCheckin: false,
    entryOpen: false,
    entryStartedAtMs: DOOR_MS,
    registrationClosed: true,
    hiddenGlobally: false,
    targetScope: 'all',
    deadlineAtMs: NOW_MS + 86400000,
  };
  return uygula(temel, patch);
}

/// Kapı check-in'ini yapmış öğrencinin kaydı.
function registrationData(patch = {}) {
  const temel = {
    registrationId: REG,
    eventId: EVENT,
    studentId: STUDENT,
    studentEmail: 'ogrenci@ornek.com',
    studentName: 'Ayşe Yılmaz',
    clubId: CLUB,
    eventTitle: 'Teşhis Etkinliği',
    registeredAtMs: DOOR_MS - 100000,
    checkedInAtMs: DOOR_MS,
    checkedInAt: Timestamp.fromMillis(DOOR_MS),
    checkedInVia: 'self-qr',
    sessionsAttended: 0,
    lastAttendedSession: 0,
    createdAt: Timestamp.fromMillis(DOOR_MS - 100000),
    updatedAt: Timestamp.fromMillis(DOOR_MS),
  };
  return uygula(temel, patch);
}

/// lib/services/event_repository.dart > markOwnSessionCheckIn
function mobilYazimi(reg, currentSession) {
  return {
    checkedInAtMs: reg.checkedInAtMs ?? NOW_MS,
    checkedInAt: serverTimestamp(),
    sessionsAttended: (reg.sessionsAttended ?? 0) + 1,
    lastSessionCheckInAtMs: NOW_MS,
    lastAttendedSession: currentSession,
    updatedAt: serverTimestamp(),
  };
}

/// js/pages/student-qr-checkin.js — web aynı işi nasıl yazıyor?
function webYazimi(reg, currentSession) {
  return {
    checkedInAtMs: reg.checkedInAtMs || NOW_MS,
    checkedInAt: reg.checkedInAtMs ? (reg.checkedInAt ?? serverTimestamp()) : serverTimestamp(),
    sessionsAttended: (Number(reg.sessionsAttended) || 0) + 1,
    lastSessionCheckInAtMs: NOW_MS,
    lastAttendedSession: currentSession,
    updatedAt: serverTimestamp(),
  };
}

let testEnv;

async function seed(event, registration) {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', STUDENT), { uid: STUDENT, role: 'student' });
    await setDoc(doc(db, 'users', CLUB), { uid: CLUB, role: 'club', clubStatus: 'approved' });
    await setDoc(doc(db, 'student_profiles', STUDENT), {
      uid: STUDENT,
      university: 'Boğaziçi Üniversitesi',
      department: 'Bilgisayar Mühendisliği',
    });
    await setDoc(doc(db, 'events', EVENT), event);
    await setDoc(doc(db, 'event_registrations', REG), registration);
  });
}

async function senaryo(ad, { event, registration, yazim = mobilYazimi, currentSession = 1, beklenen }) {
  const ev = eventData(event);
  const reg = registrationData(registration);
  await seed(ev, reg);

  const db = testEnv.authenticatedContext(STUDENT).firestore();
  let sonuc;
  try {
    await updateDoc(doc(db, 'event_registrations', REG), yazim(reg, currentSession));
    sonuc = 'IZIN';
  } catch (error) {
    sonuc = String(error?.code ?? error).includes('permission-denied')
      ? 'RED'
      : `HATA (${error?.code ?? error})`;
  }

  const isaret = beklenen ? (sonuc === beklenen ? '✓' : '✗ BEKLENMEYEN') : ' ';
  console.log(`  ${isaret} ${ad.padEnd(58)} → ${sonuc}`);
  return sonuc;
}

async function main() {
  console.log(`\nKural dosyası: ${RULES}`);
  console.log(`Emulator     : 127.0.0.1:${PORT}\n`);

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: '127.0.0.1', port: PORT, rules: readFileSync(RULES, 'utf8') },
  });

  console.log('Öğrenci oturum QR\'ını okutuyor (checkin_attendance, kapı girişi yapılmış):');
  await senaryo('mobil yazımı — normal durum', { beklenen: 'IZIN' });
  await senaryo('web yazımı  — normal durum', { yazim: webYazimi, beklenen: 'IZIN' });

  console.log('\nVeri şekli farklılıkları:');
  await senaryo('kayıtta checkedInAtMs yok (kapı girişi yapılmamış)', {
    registration: { checkedInAtMs: SIL, checkedInAt: SIL, checkedInVia: SIL },
    beklenen: 'RED',
  });
  // YENİ KAYIT tam olarak böyle görünür: ne web (dashboard.js) ne mobil
  // (EventRepository.registerToEvent) bu iki sayacı kayıt anında yazıyor.
  await senaryo('YENİ KAYIT: lastAttendedSession + sessionsAttended yok', {
    registration: { lastAttendedSession: SIL, sessionsAttended: SIL },
  });
  await senaryo('yalnızca lastAttendedSession yok', {
    registration: { lastAttendedSession: SIL },
  });
  await senaryo('yalnızca sessionsAttended yok', {
    registration: { sessionsAttended: SIL },
  });
  await senaryo('etkinlikte currentSession alanı yok', {
    event: { currentSession: SIL },
    currentSession: 0,
  });
  await senaryo('etkinlikte sessionsCompleted alanı yok', {
    event: { sessionsCompleted: SIL },
  });
  await senaryo('etkinlikte checkinMode alanı yok (eski kayıt)', {
    event: { checkinMode: SIL, allowSessionWithoutCheckin: SIL },
  });
  await senaryo('currentSession ondalık saklanmış (1.0)', {
    event: { currentSession: 1.0000001 },
  });
  await senaryo('checkedInAtMs metin olarak saklanmış', {
    registration: { checkedInAtMs: String(DOOR_MS) },
  });
  await senaryo('etkinlik ücretli, kayıtta onay logu var', {
    event: { isPaid: true, price: 100 },
    registration: {
      paidConsentLog: { approved: true, text: 'onay', approvedAtMs: DOOR_MS },
    },
  });
  await senaryo('kayıt kulüp tarafından işaretlenmiş (checkedInByClubId dolu)', {
    registration: { checkedInByClubId: CLUB, checkedInVia: SIL },
  });
  await senaryo('etkinlik kontenjan parçalı (quotaShardCount) ', {
    event: { quotaShardCount: 4, quota: 40 },
    registration: { quotaShard: 2 },
  });

  // Gerçek etkinlikler "herkese açık" değil: kulüpler kapsamı üniversiteye
  // ya da bölüme daraltıyor. Kapsam kontrolü `allow update` zincirinin İLK
  // dalında duruyor ve get() + liste taraması yapıyor; oturum yoklaması
  // dalına sıra geldiğinde 1000 ifade bütçesi tükenmiş olabilir.
  console.log('\nGerçekçi kapsam (allow update zincirinin ilk dalı ağırlaşıyor):');
  await senaryo('kapsam: üniversite', {
    event: { targetScope: 'university', targetUniversity: 'Boğaziçi Üniversitesi' },
    beklenen: 'IZIN',
  });
  await senaryo('kapsam: bölüm + üniversite', {
    event: {
      targetScope: 'department_university',
      targetUniversity: 'Boğaziçi Üniversitesi',
      targetDepartments: ['Bilgisayar Mühendisliği', 'Endüstri Mühendisliği'],
    },
    beklenen: 'IZIN',
  });
  await senaryo('kapsam: bölüm + üniversite, kontenjan parçalı, ücretli', {
    event: {
      targetScope: 'department_university',
      targetUniversity: 'Boğaziçi Üniversitesi',
      targetDepartments: ['Bilgisayar Mühendisliği', 'Endüstri Mühendisliği'],
      quotaShardCount: 4,
      quota: 40,
      isPaid: true,
      price: 150,
    },
    registration: {
      quotaShard: 2,
      paidConsentLog: { approved: true, text: 'onay', approvedAtMs: DOOR_MS },
    },
    beklenen: 'IZIN',
  });
  await senaryo('kapsam: bölüm (uzun bölüm listesi)', {
    event: {
      targetScope: 'department',
      targetDepartments: Array.from({ length: 25 }, (_, i) => `Bölüm ${i}`).concat([
        'Bilgisayar Mühendisliği',
      ]),
    },
    beklenen: 'IZIN',
  });

  console.log('\nKapı QR\'ı (öğrencinin kendi okutması):');
  await senaryo('kapı yazımı — kayıtta checkedInAtMs alanı HİÇ YOK', {
    event: { entryOpen: true },
    registration: { checkedInAtMs: SIL, checkedInAt: SIL, checkedInVia: SIL },
    yazim: () => ({
      checkedInAtMs: NOW_MS,
      checkedInAt: serverTimestamp(),
      checkedInVia: 'self-qr',
      updatedAt: serverTimestamp(),
    }),
    beklenen: 'IZIN',
  });
  await senaryo('kapı yazımı — kayıtta checkedInAtMs: 0 duruyor', {
    event: { entryOpen: true },
    registration: { checkedInAtMs: 0, checkedInAt: SIL, checkedInVia: SIL },
    yazim: () => ({
      checkedInAtMs: NOW_MS,
      checkedInAt: serverTimestamp(),
      checkedInVia: 'self-qr',
      updatedAt: serverTimestamp(),
    }),
    beklenen: 'IZIN',
  });

  // .get(alan, varsayilan) düzeltmesi kuralı gevşetmemeli: aşağıdaki
  // yazımların HEPSİ reddedilmek zorunda.
  console.log('\nGüvenlik — bunların hepsi RED olmalı:');
  await senaryo('aynı oturumda ikinci kez okutma', {
    registration: { lastAttendedSession: 1, sessionsAttended: 1 },
    beklenen: 'RED',
  });
  await senaryo('sayacı bir yerine iki artırma', {
    yazim: (reg, s) => ({ ...mobilYazimi(reg, s), sessionsAttended: 2 }),
    beklenen: 'RED',
  });
  await senaryo('aktif olmayan oturumu işaretleme (3. oturum)', {
    yazim: (reg) => mobilYazimi(reg, 3),
    beklenen: 'RED',
  });
  await senaryo('kulüp doğrulaması taklidi (checkedInByClubId yazma)', {
    yazim: (reg, s) => ({ ...mobilYazimi(reg, s), checkedInByClubId: CLUB }),
    beklenen: 'RED',
  });
  await senaryo('yoklamayla birlikte ad değiştirme', {
    yazim: (reg, s) => ({ ...mobilYazimi(reg, s), studentName: 'Başkası' }),
    beklenen: 'RED',
  });
  await senaryo('oturumlar tamamlanmış etkinlikte okutma', {
    event: { sessionsCompleted: true },
    beklenen: 'RED',
  });
  await senaryo('kapı girişi yok + checkin_attendance', {
    registration: { checkedInAtMs: SIL, checkedInAt: SIL, checkedInVia: SIL },
    beklenen: 'RED',
  });
  await senaryo('kapı yazımı — kapı KAPALI', {
    event: { entryOpen: false },
    registration: { checkedInAtMs: SIL, checkedInAt: SIL, checkedInVia: SIL },
    yazim: () => ({
      checkedInAtMs: NOW_MS,
      checkedInAt: serverTimestamp(),
      checkedInVia: 'self-qr',
      updatedAt: serverTimestamp(),
    }),
    beklenen: 'RED',
  });
  await senaryo('kapı yazımı — zaten giriş yapmış kayıt', {
    event: { entryOpen: true },
    yazim: () => ({
      checkedInAtMs: NOW_MS,
      checkedInAt: serverTimestamp(),
      checkedInVia: 'self-qr',
      updatedAt: serverTimestamp(),
    }),
    beklenen: 'RED',
  });
  await senaryo('başkasının kaydına yoklama yazma', {
    registration: { studentId: 'baska_ogrenci' },
    beklenen: 'RED',
  });

  await testEnv.cleanup();
  console.log('');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
