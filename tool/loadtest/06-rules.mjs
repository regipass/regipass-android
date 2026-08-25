/**
 * TEST 6 — Kontenjan parçalarının GÜVENLİK kuralları.
 *
 * Parçalı sayaç kontenjanı ancak `firestore.rules` onu koruyorsa korur.
 * İstemciye "sayacı artır" izni verilirken şu delikler açık kalabilir:
 *
 *   • kayıt yazmadan sayaç artırmak (yer kapatmak)
 *   • kaydı silmeden sayaç azaltmak (kontenjanı şişirmek)
 *   • kapasiteyi kendi belirlemek
 *   • bir parçayı artırıp kaydı başka parçaya yazmak
 *
 * Kurallar bunları `getAfter`/`existsAfter` ile kapatıyor: sayaç değişimi
 * ancak işlem BİTTİĞİNDE kaydın beklenen hâlde olmasıyla geçerli. Bu test
 * her deliği ayrı ayrı deniyor.
 */

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, runTransaction,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { RunLog, ROOT, PROJECT_ID, waitForEmulator } from './lib/harness.mjs';

const log = new RunLog('06-rules');

const CLUB = 'rulestest_club';
const STUDENT = 'rulestest_student';
const OTHER = 'rulestest_other';
const EVENT = 'rulestest_event';
const QUOTA = 10;
const SHARDS = 4;

let passed = 0;
let failed = 0;

async function check(name, fn) {
  try {
    await fn();
    passed += 1;
    log.say(`  ✓ ${name}`);
    log.event('rule_case', { name, result: 'pass' });
  } catch (error) {
    failed += 1;
    log.say(`  ✗ ${name}`);
    log.say(`      ${String(error.message ?? error).slice(0, 160)}`);
    log.event('rule_case', { name, result: 'fail', error: String(error.message ?? error) });
  }
}

function registrationPayload(uid, shard) {
  return {
    registrationId: `${EVENT}_${uid}`,
    eventId: EVENT,
    studentId: uid,
    studentName: 'Test Ogrenci',
    studentEmail: `${uid}@ornek.edu.tr`,
    quotaShard: shard,
    registeredAtMs: Date.now(),
  };
}

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: 8733,
      rules: readFileSync(join(ROOT, 'firestore.rules'), 'utf8'),
    },
  });

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 6 — quota_shards GÜVENLİK KURALLARI');
  log.say('══════════════════════════════════════════════════════════════');
  log.say('');

  // ── Zemin: kulüp kullanıcıları ve profiller ────────────────────────
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `users/${CLUB}`), {
      uid: CLUB, role: 'club', lastRole: 'club', roles: { club: true },
    });
    for (const uid of [STUDENT, OTHER]) {
      await setDoc(doc(db, `users/${uid}`), {
        uid, role: 'student', lastRole: 'student', roles: { student: true },
      });
      await setDoc(doc(db, `student_profiles/${uid}`), {
        uid, university: 'Istanbul Universitesi',
        department: 'Bilgisayar Muhendisligi', phoneVerified: true,
      });
      await deleteDoc(doc(db, `event_registrations/${EVENT}_${uid}`)).catch(() => {});
    }
  });

  const club = testEnv.authenticatedContext(CLUB).firestore();
  const student = testEnv.authenticatedContext(STUDENT).firestore();
  const other = testEnv.authenticatedContext(OTHER).firestore();

  /** Etkinliği ve parçaları temiz hâle getirir. */
  async function reset() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `events/${EVENT}`), {
        title: 'Kural Testi', clubId: CLUB, clubName: 'Kural Kulubu',
        quota: QUOTA, quotaShardCount: SHARDS, targetScope: 'public',
        registrationClosed: false, hiddenGlobally: false,
        deadlineAtMs: Date.now() + 86400000,
      });
      for (let s = 0; s < SHARDS; s++) {
        await setDoc(doc(db, `events/${EVENT}/quota_shards/${s}`), {
          count: 0, capacity: QUOTA / SHARDS,
        });
      }
      for (const uid of [STUDENT, OTHER]) {
        await deleteDoc(doc(db, `event_registrations/${EVENT}_${uid}`)).catch(() => {});
      }
    });
  }

  // ── 1. Parça oluşturma ─────────────────────────────────────────────
  log.say('1) Parçaları kim kurabilir');

  await check('kulüp etkinlik + parçaları TEK batch\'te kurabilir', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), `events/rulestest_new`)).catch(() => {});
    });
    const batch = writeBatch(club);
    batch.set(doc(club, 'events/rulestest_new'), {
      title: 'Yeni', clubId: CLUB, quota: 8, quotaShardCount: 4,
      targetScope: 'public', registrationClosed: false, hiddenGlobally: false,
    });
    for (let s = 0; s < 4; s++) {
      batch.set(doc(club, `events/rulestest_new/quota_shards/${s}`), {
        count: 0, capacity: 2,
      });
    }
    await assertSucceeds(batch.commit());
  });

  await check('öğrenci parça KURAMAZ (kapasiteyi kendi belirleyemez)', async () => {
    await reset();
    await assertFails(
      setDoc(doc(student, `events/${EVENT}/quota_shards/99`), {
        count: 0, capacity: 100000,
      }),
    );
  });

  // ── 2. Yer kapma ───────────────────────────────────────────────────
  log.say('');
  log.say('2) Sayacı artırma (yer kapma)');

  await check('kayıt + sayaç aynı transaction\'da yazılabilir', async () => {
    await reset();
    await assertSucceeds(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        const snap = await tx.get(shardRef);
        tx.set(
          doc(student, `event_registrations/${EVENT}_${STUDENT}`),
          registrationPayload(STUDENT, 0),
        );
        tx.update(shardRef, { count: snap.data().count + 1 });
      }),
    );
  });

  await check('kayıt YAZMADAN sayaç artırılamaz', async () => {
    await reset();
    await assertFails(
      updateDoc(doc(student, `events/${EVENT}/quota_shards/0`), { count: 1 }),
    );
  });

  await check('kapasiteyi aşan artırma reddedilir', async () => {
    await reset();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${EVENT}/quota_shards/0`), {
        count: 2, capacity: 2, // parça dolu
      });
    });
    await assertFails(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        await tx.get(shardRef);
        tx.set(
          doc(student, `event_registrations/${EVENT}_${STUDENT}`),
          registrationPayload(STUDENT, 0),
        );
        tx.update(shardRef, { count: 3 });
      }),
    );
  });

  await check('sayaç bir kerede 1\'den fazla artırılamaz', async () => {
    await reset();
    await assertFails(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        await tx.get(shardRef);
        tx.set(
          doc(student, `event_registrations/${EVENT}_${STUDENT}`),
          registrationPayload(STUDENT, 0),
        );
        tx.update(shardRef, { count: 2 });
      }),
    );
  });

  await check('kapasite istemciden DEĞİŞTİRİLEMEZ', async () => {
    await reset();
    await assertFails(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        const snap = await tx.get(shardRef);
        tx.set(
          doc(student, `event_registrations/${EVENT}_${STUDENT}`),
          registrationPayload(STUDENT, 0),
        );
        tx.update(shardRef, { count: snap.data().count + 1, capacity: 9999 });
      }),
    );
  });

  await check('bir parçayı artırıp kaydı BAŞKA parçaya yazmak reddedilir', async () => {
    await reset();
    await assertFails(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        const snap = await tx.get(shardRef);
        // Kayıt 3. parçayı gösteriyor ama artırılan 0. parça.
        tx.set(
          doc(student, `event_registrations/${EVENT}_${STUDENT}`),
          registrationPayload(STUDENT, 3),
        );
        tx.update(shardRef, { count: snap.data().count + 1 });
      }),
    );
  });

  await check('BAŞKASININ kaydını yazarak yer kapılamaz', async () => {
    await reset();
    await assertFails(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        const snap = await tx.get(shardRef);
        tx.set(
          doc(student, `event_registrations/${EVENT}_${OTHER}`),
          registrationPayload(OTHER, 0),
        );
        tx.update(shardRef, { count: snap.data().count + 1 });
      }),
    );
  });

  // ── 3. Yer bırakma ─────────────────────────────────────────────────
  log.say('');
  log.say('3) Sayacı azaltma (yer bırakma)');

  /** Öğrenciyi 0. parçaya gerçekten kaydeder. */
  async function seedRegistration() {
    await reset();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(
        doc(db, `event_registrations/${EVENT}_${STUDENT}`),
        registrationPayload(STUDENT, 0),
      );
      await setDoc(doc(db, `events/${EVENT}/quota_shards/0`), {
        count: 1, capacity: QUOTA / SHARDS,
      });
    });
  }

  await check('kaydı silerken sayaç azaltılabilir', async () => {
    await seedRegistration();
    await assertSucceeds(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        const snap = await tx.get(shardRef);
        tx.delete(doc(student, `event_registrations/${EVENT}_${STUDENT}`));
        tx.update(shardRef, { count: snap.data().count - 1 });
      }),
    );
  });

  await check('kaydı SİLMEDEN sayaç azaltılamaz (kontenjan şişirilemez)', async () => {
    await seedRegistration();
    await assertFails(
      updateDoc(doc(student, `events/${EVENT}/quota_shards/0`), { count: 0 }),
    );
  });

  await check('sayaç 0\'ın altına indirilemez', async () => {
    await reset(); // count = 0
    await assertFails(
      runTransaction(student, async (tx) => {
        const shardRef = doc(student, `events/${EVENT}/quota_shards/0`);
        await tx.get(shardRef);
        tx.update(shardRef, { count: -1 });
      }),
    );
  });

  // ── 4. Okuma ───────────────────────────────────────────────────────
  log.say('');
  log.say('4) Okuma');

  await check('giriş yapmış öğrenci parçaları okuyabilir', async () => {
    await reset();
    await assertSucceeds(
      getDoc(doc(student, `events/${EVENT}/quota_shards/0`)),
    );
  });

  await check('misafir parçaları okuyamaz', async () => {
    await reset();
    const guest = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(guest, `events/${EVENT}/quota_shards/0`)));
  });

  await check('başka bir kulüp parçaları silemez', async () => {
    await reset();
    await assertFails(
      deleteDoc(doc(other, `events/${EVENT}/quota_shards/0`)),
    );
  });

  log.say('');
  log.say('─'.repeat(60));
  log.say(`SONUÇ: ${passed} geçti, ${failed} kaldı`);
  log.say('');
  log.close();

  await testEnv.cleanup();
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
