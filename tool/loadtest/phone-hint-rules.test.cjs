// Run only against a local Firestore emulator, never a production project.
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, collection, getDoc, getDocs, setDoc, serverTimestamp } = require('firebase/firestore');

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-regipass-phone-reset',
    firestore: {host:'127.0.0.1', port:9087, rules:fs.readFileSync(process.env.REGIPASS_RULES_PATH || 'tool/loadtest/firestore.rules','utf8')},
  });
  try {
    const guest = env.unauthenticatedContext().firestore();
    const user = env.authenticatedContext('phone-user', {email:'test@example.com',phone_number:'+905551234567'}).firestore();
    const basic = {maskedPhone:'+90 XXX XXX XX 67',updatedAt:serverTimestamp()};
    await assertSucceeds(setDoc(doc(user,'phone_hints/mobile'), {...basic, roles:['student','club']}));
    await assertSucceeds(setDoc(doc(user,'phone_hints/fallback'), basic));
    await assertSucceeds(setDoc(doc(user,'phone_hints/web'), {...basic,phoneHash:'a'.repeat(64)}));
    await assertSucceeds(getDoc(doc(guest,'phone_hints/mobile')));
    await assertFails(getDocs(collection(guest,'phone_hints')));
    await assertFails(setDoc(doc(guest,'phone_hints/anonymous'),basic));
    await assertFails(setDoc(doc(user,'phone_hints/private-phone'),{...basic,phone:'+905551234567'}));
    await assertFails(setDoc(doc(user,'phone_hints/invalid-role'),{...basic,roles:['admin']}));
    await assertFails(setDoc(doc(user,'phone_hints/invalid-hash'),{...basic,phoneHash:'short'}));
    await assertFails(setDoc(doc(user,'phone_hints/empty-mask'),{...basic,maskedPhone:''}));
    console.log('PASS: 10 phone_hints rules checks (mobile, fallback, legacy web, read, denied writes/list).');
  } finally {
    await env.cleanup();
  }
})().catch(error => {console.error(error.message);process.exitCode=1;});
