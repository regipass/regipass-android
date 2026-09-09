// Local emulator only. Run from repository root.
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc } = require('firebase/firestore');

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-regipass-event-gate',
    firestore: {
      host: '127.0.0.1', port: 9087,
      rules: fs.readFileSync(process.env.REGIPASS_RULES_PATH || 'tool/loadtest/firestore.rules', 'utf8'),
    },
  });
  try {
    await env.withSecurityRulesDisabled(async context => {
      await setDoc(doc(context.firestore(), 'events/gate'), {
        clubId: 'owner', feeType: 'free', registrationClosed: false,
        entryOpen: false, currentSession: 0,
      });
    });
    const owner = doc(env.authenticatedContext('owner').firestore(), 'events/gate');
    await assertFails(updateDoc(owner, {entryOpen: true}));
    await assertSucceeds(updateDoc(owner, {entryOpen: true, registrationClosed: true}));
    await assertFails(updateDoc(owner, {registrationClosed: false}));
    await assertSucceeds(updateDoc(owner, {entryOpen: false}));
    await assertSucceeds(updateDoc(owner, {currentSession: 1}));
    await assertFails(updateDoc(owner, {registrationClosed: false}));
    await assertSucceeds(updateDoc(owner, {currentSession: 0}));
    await assertSucceeds(updateDoc(owner, {registrationClosed: false}));
    await assertFails(updateDoc(owner, {currentSession: 1}));
    await assertSucceeds(updateDoc(owner, {currentSession: 1, registrationClosed: true}));
    await assertSucceeds(updateDoc(owner, {sessionQrPublished: 1}));
    await assertFails(updateDoc(doc(env.authenticatedContext('student').firestore(), 'events/gate'), {sessionQrPublished: 2}));
    // Older clients may have left registrationClosed=false during attendance.
    // Verify that the student write is still rejected for those records.
    for (const [id, state, allowed] of [
      ['open', {entryOpen: false, currentSession: 0}, true],
      ['door', {entryOpen: true, currentSession: 0}, false],
      ['session', {entryOpen: false, currentSession: 1}, false],
    ]) {
      await env.withSecurityRulesDisabled(context => setDoc(
        doc(context.firestore(), `events/${id}`), {
          clubId: 'owner', feeType: 'free', hiddenGlobally: false,
          registrationClosed: false, quotaShardCount: 0, ...state,
        },
      ));
      const write = setDoc(doc(env.authenticatedContext('student').firestore(),
        `event_registrations/${id}_student`), {eventId: id, studentId: 'student'});
      await (allowed ? assertSucceeds(write) : assertFails(write));
    }
    console.log('PASS: 15 event registration gate rules checks.');
  } finally {
    await env.cleanup();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
