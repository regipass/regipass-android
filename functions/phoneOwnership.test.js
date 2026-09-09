const test = require('node:test');
const assert = require('node:assert/strict');
const { createPhoneOwnershipHandler } = require('./phoneOwnership');

function handler({ auth, rateLimit = async () => {}, reconcile = async () => {}, logError = () => {} }) {
  return createPhoneOwnershipHandler({ auth, rateLimit, reconcile, logError });
}

test('Firebase Auth sahibi farklıysa SMS istemeden önce numarayı dolu döndürür', async () => {
  const reconciled = [];
  const lookup = handler({
    auth: { getUserByPhoneNumber: async () => ({ uid: 'other-user' }) },
    reconcile: async update => reconciled.push(update),
  });

  assert.deepEqual(
    await lookup({ auth: { uid: 'caller' }, data: { phoneE164: '+905551234567' } }),
    { ownership: 'taken' },
  );
  assert.deepEqual(reconciled, [{ phoneE164: '+905551234567', ownerUid: 'other-user' }]);
});

test('Firebase Auth sahibi çağıransa numara kendi hesabına ait döner', async () => {
  const lookup = handler({
    auth: { getUserByPhoneNumber: async () => ({ uid: 'caller' }) },
  });

  assert.deepEqual(
    await lookup({ auth: { uid: 'caller' }, data: { phoneE164: '+905551234567' } }),
    { ownership: 'mine' },
  );
});

test('Auth kaydı olmayan numara serbest döner ve yalnız bayat doğrulanmış kayıt temizlenir', async () => {
  const reconciled = [];
  const lookup = handler({
    auth: { getUserByPhoneNumber: async () => { throw { code: 'auth/user-not-found' }; } },
    reconcile: async update => reconciled.push(update),
  });

  assert.deepEqual(
    await lookup({ auth: { uid: 'caller' }, data: { phoneE164: '+905551234567' } }),
    { ownership: 'free' },
  );
  assert.deepEqual(reconciled, [{ phoneE164: '+905551234567', ownerUid: null }]);
});

test('oturumsuz ve geçersiz istekler Auth sorgusuna ulaşmaz', async () => {
  const auth = { getUserByPhoneNumber: () => assert.fail('Auth sorgulanmamalı') };
  const lookup = handler({ auth });

  await assert.rejects(
    lookup({ auth: null, data: { phoneE164: '+905551234567' } }),
    { code: 'unauthenticated' },
  );
  await assert.rejects(
    lookup({ auth: { uid: 'caller' }, data: { phoneE164: '05551234567' } }),
    { code: 'invalid-argument' },
  );
});
