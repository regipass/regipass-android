/**
 * TEST 2 — Kontenjanı korumanın bedeli: tek dokümanlı sayaç.
 *
 * En akla yatkın çözüm: etkinlik dokümanında `registeredCount` tut, kaydı
 * transaction içinde yaz. Doğru sonuç verir (aşım = 0) ama tek doküman
 * SERİLEŞTİRME NOKTASIDIR: aynı anda basan herkes aynı satır için yarışır.
 *
 * Bu test o yarışmanın maliyetini ölçer:
 *   • kaç transaction yeniden denemesi (retry) oluyor
 *   • kaç tanesi tümden düşüyor (ABORTED / DEADLINE_EXCEEDED)
 *   • gecikme nereye çıkıyor
 *
 * Üretimde ek olarak tek dokümana sürekli yazma ~1 yazma/sn ile sınırlıdır;
 * emulator bu kotayı uygulamaz, yalnızca çekişmeyi gösterir. Yani buradaki
 * sayılar üretimin İYİMSER tarafıdır.
 */

import {
  connect, RunLog, fireAtOnce, summarize, fmtRow, TABLE_HEADER,
  resetEvent, registrationPayload, studentUid, registrationId,
  countRegistrations, waitForEmulator,
} from './lib/harness.mjs';

const EVENT_ID = 'loadtest_event_counter';
const QUOTA = 500;
const LEVELS = [10, 25, 50, 100, 250, 500];
const MAX_ATTEMPTS = 5;

const log = new RunLog('02-quota-contention');

async function main() {
  if (!(await waitForEmulator())) throw new Error('Emulator ayağa kalkmadı');
  const db = connect();

  log.say('══════════════════════════════════════════════════════════════');
  log.say(' TEST 2 — TEK DOKÜMANLI SAYAÇ (transaction ile kontenjan)');
  log.say('══════════════════════════════════════════════════════════════');
  log.say(`\nKontenjan: ${QUOTA} · transaction deneme hakkı: ${MAX_ATTEMPTS}\n`);
  log.say('─'.repeat(104));
  log.say(TABLE_HEADER + '  kayıt/kontenjan');
  log.say('─'.repeat(104));

  for (const n of LEVELS) {
    await resetEvent(db, EVENT_ID, { quota: QUOTA });
    const eventRef = db.doc(`events/${EVENT_ID}`);

    const run = await fireAtOnce(n, async (i) => {
      const uid = studentUid(i);
      let attempts = 0;

      await db.runTransaction(
        async (tx) => {
          attempts += 1;
          const snap = await tx.get(eventRef);
          const event = snap.data();
          const count = event.registeredCount ?? 0;
          if (count >= event.quota) {
            const full = new Error('quota-full');
            full.code = 'quota-full';
            throw full;
          }
          const regRef = db.doc(
            `event_registrations/${registrationId(EVENT_ID, uid)}`,
          );
          tx.set(regRef, registrationPayload(EVENT_ID, uid, i, event));
          tx.update(eventRef, { registeredCount: count + 1 });
        },
        { maxAttempts: MAX_ATTEMPTS },
      );

      return { retries: attempts - 1 };
    });

    const s = summarize(run);
    const stored = await countRegistrations(db, EVENT_ID);
    const overshoot = stored - Math.min(n, QUOTA);

    log.event('counter', { n, ...s, stored, overshoot });
    log.say(
      fmtRow(n, s) +
        `   ${String(stored).padStart(5)}/${QUOTA}` +
        (overshoot !== 0 ? `  ⚠ sapma ${overshoot}` : ''),
    );
  }

  log.say('');
  log.say('Okuma: "retry" toplam yeniden deneme sayısıdır. Eşzamanlılık arttıkça');
  log.say('her kayıt aynı satırı okuyup yazdığı için birbirini iptal ettirir;');
  log.say(`${MAX_ATTEMPTS} denemede başaramayan istek ABORTED ile düşer.`);
  log.say('');
  log.close();
  await db.terminate();
}

main().catch((error) => {
  console.error(error);
  log.close();
  process.exit(1);
});
