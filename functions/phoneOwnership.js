const { HttpsError } = require('firebase-functions/v2/https');

const E164_RE = /^\+[1-9]\d{6,14}$/;

/// Firebase Auth telefon sahipliğinin tek gerçek kaynağıdır. Firestore'daki
/// `phone_owners` yalnızca SMS'ten önce hızlı uyarı verebilmek için tutulan
/// bir dizindir; eski hesaplarda eksik veya numara değişimi sonrasında bayat
/// kalmış olabilir.
///
/// İstemciye hiçbir zaman uid ya da telefon numarası dönmeyiz. Yalnızca
/// çağıranın girdiği numaranın kendi hesabında mı, başka hesapta mı, yoksa
/// serbest mi olduğunu söyleriz.
function createPhoneOwnershipHandler({ auth, rateLimit, reconcile, logError }) {
  return async (request) => {
    const callerUid = typeof request.auth?.uid === 'string'
      ? request.auth.uid
      : '';
    if (!callerUid) {
      throw new HttpsError('unauthenticated', 'Sign-in required.');
    }

    const rawPhone = request.data?.phoneE164;
    const phoneE164 = typeof rawPhone === 'string' ? rawPhone.trim() : '';
    if (!E164_RE.test(phoneE164)) {
      throw new HttpsError('invalid-argument', 'Invalid phone number.');
    }

    // Callable doğrudan çağrılabildiği için, alanın her tuş vuruşunda yaptığı
    // yerel/dizin sorgusundan ayrı bir hız sınırı gerekir.
    await rateLimit(callerUid);

    try {
      const owner = await auth.getUserByPhoneNumber(phoneE164);
      // Dizini yalnızca Auth'un gerçekten bağlı olduğunu kanıtladığı bilgiyle
      // tazele. Bu yazım başarısız olsa bile gerçek sahiplik yanıtı geçerlidir.
      try {
        await reconcile({ phoneE164, ownerUid: owner.uid });
      } catch (error) {
        logError({ stage: 'reconcileOwner', code: error?.code || 'unknown' });
      }
      return { ownership: owner.uid === callerUid ? 'mine' : 'taken' };
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        // Yalnızca bayat "verified" kaydı silinir. Başka kullanıcının 15
        // dakikalık "pending" rezervasyonunu bu sorgu asla düşürmez.
        try {
          await reconcile({ phoneE164, ownerUid: null });
        } catch (reconcileError) {
          logError({
            stage: 'reconcileFree',
            code: reconcileError?.code || 'unknown',
          });
        }
        return { ownership: 'free' };
      }

      logError({ stage: 'lookup', code: error?.code || 'unknown' });
      throw new HttpsError('unavailable', 'Could not check phone ownership.');
    }
  };
}

module.exports = { createPhoneOwnershipHandler };
