const test = require('node:test');
const assert = require('node:assert/strict');
const { maskAuthPhone, createPasswordResetHintHandler } = require('./passwordResetHint');

test('Auth numarasi yalnizca son iki haneyle maskelenir', () => {
  assert.equal(maskAuthPhone('+905551234567'), '+90 XXX XXX XX 67');
  assert.equal(maskAuthPhone('+14155552671'), '+XXXXXXXXX71');
  assert.equal(maskAuthPhone('5551234567'), '');
  assert.equal(maskAuthPhone(null), '');
});

test('eksik ipucu icin normalize e-postanin Auth numarasi kullanilir', async () => {
  const calls = [];
  const handler = createPasswordResetHintHandler({
    auth: {getUserByEmail: async email => {
      calls.push(email);
      return {uid:'private-uid', email, phoneNumber:'+905551234567'};
    }},
    rateLimit: async email => calls.push(email),
    logError: () => assert.fail('unexpected error'),
  });
  assert.deepEqual(await handler({data:{email:' Test@Example.com '}}), {
    maskedPhone:'+90 XXX XXX XX 67', roles:[],
  });
  assert.deepEqual(calls, ['test@example.com', 'test@example.com']);
});

test('numarasiz ve devre disi hesaplar kurtarma numarasi vermez', async () => {
  for (const user of [{}, {disabled:true, phoneNumber:'+905551234567'}]) {
    const handler = createPasswordResetHintHandler({auth:{getUserByEmail:async()=>user}, rateLimit:async()=>{}, logError:()=>{}});
    assert.deepEqual(await handler({data:{email:'test@example.com'}}), {maskedPhone:'', roles:[]});
  }
});

test('olmayan hesap bos ipucu verir; altyapi hatasi hesap yok diye gizlenmez', async () => {
  const logs=[];
  for (const code of ['auth/user-not-found', 'auth/internal-error']) {
    const handler = createPasswordResetHintHandler({auth:{getUserByEmail:async()=>{throw {code};}},rateLimit:async()=>{},logError:x=>logs.push(x)});
    if (code === 'auth/user-not-found') {
      assert.deepEqual(await handler({data:{email:'test@example.com'}}), {maskedPhone:'',roles:[]});
    } else {
      await assert.rejects(handler({data:{email:'test@example.com'}}), {code:'unavailable'});
    }
  }
  assert.deepEqual(logs,[{code:'auth/internal-error'}]);
});

test('gecersiz e-posta Auth sorgusuna veya deneme sayacina ulasmaz', async () => {
  const handler = createPasswordResetHintHandler({auth:{getUserByEmail:()=>assert.fail()},rateLimit:()=>assert.fail(),logError:()=>assert.fail()});
  await assert.rejects(handler({data:{email:'invalid'}}), {code:'invalid-argument'});
});

test('hiz siniri Auth sorgusundan once uygulanir', async () => {
  const handler = createPasswordResetHintHandler({auth:{getUserByEmail:()=>assert.fail()},rateLimit:async()=>{throw new Error('rate-limited');},logError:()=>assert.fail()});
  await assert.rejects(handler({data:{email:'test@example.com'}}), /rate-limited/);
});
