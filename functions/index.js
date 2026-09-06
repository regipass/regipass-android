/**
 * Regipass Cloud Functions.
 *
 * checkPasswordResetPhone
 * ------------------------
 * "Şifremi unuttum" ekranında kullanıcının yazdığı telefon numarasının,
 * girilen e-postanın Firebase Auth hesabına kayıtlı GERÇEK numarayla birebir
 * aynı olup olmadığını sunucu tarafında doğrular.
 *
 * Neden istemci tarafında değil: `phone_hints/{emailHash}` Firestore belgesi
 * herkese açık okunuyor (bkz. firestore.rules) ve yalnızca maskelenmiş
 * numarayı taşıyor — amaç, e-postayı bilen birinin oradan telefon numarasını
 * öğrenememesi. Telefon numaraları parola gibi yüksek entropili değil (TR cep
 * numarası için ~1 milyar ihtimal), bu yüzden tam numarayı ya da onun hash'ini
 * herkese açık bir belgeye koymak kaba kuvvetle kırılabilir olurdu. Bu
 * fonksiyon karşılaştırmayı sunucuda yapar ve istemciye yalnızca evet/hayır
 * döner — gerçek numara hiçbir zaman dışarı çıkmaz.
 *
 * Neden hız sınırlaması var: fonksiyon yalnızca true/false döndürse bile,
 * sınırsız deneme hakkı olan biri farklı numaraları deneyip yanıtı izleyerek
 * numarayı adım adım bulabilir (özellikle son N hanesi zaten maskeyle
 * biliniyorsa). Bu yüzden aynı e-posta için saat başına deneme sayısı
 * sınırlanır.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

// Bölge: kullanıcı kitlesine (Türkiye) coğrafi olarak en yakın bölgelerden
// biri. Firestore/diğer kaynakların bölgesinden bağımsız çalışır, yalnızca
// gecikmeyi etkiler. Değiştirilirse Flutter tarafındaki
// `FirebaseFunctions.instanceFor(region: ...)` çağrısı da güncellenmeli.
const REGION = 'europe-west1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

const db = admin.firestore();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const E164_RE = /^\+[1-9]\d{6,14}$/;

const RATE_LIMIT_COLLECTION = 'password_reset_phone_attempts';
const MAX_ATTEMPTS_PER_WINDOW = 6;
const WINDOW_MS = 60 * 60 * 1000; // 1 saat

/** phone_hint_repository.dart#hashEmail ile aynı: trim + toLowerCase + sha256 hex. */
function hashEmail(email) {
  return crypto
    .createHash('sha256')
    .update(email.trim().toLowerCase(), 'utf8')
    .digest('hex');
}

/**
 * Aynı e-posta için saat başına en fazla [MAX_ATTEMPTS_PER_WINDOW] deneme.
 * Admin SDK Firestore güvenlik kurallarından etkilenmez; bu koleksiyon
 * yalnızca bu fonksiyon tarafından okunup yazılır, istemciye hiç açılmaz.
 */
async function enforceRateLimit(emailHash) {
  const ref = db.collection(RATE_LIMIT_COLLECTION).doc(emailHash);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart =
      data && typeof data.windowStart === 'number' ? data.windowStart : 0;
    const withinWindow = now - windowStart < WINDOW_MS;
    const count = withinWindow && typeof data.count === 'number' ? data.count : 0;

    if (withinWindow && count >= MAX_ATTEMPTS_PER_WINDOW) {
      throw new HttpsError('resource-exhausted', 'Too many attempts.');
    }

    tx.set(ref, {
      windowStart: withinWindow ? windowStart : now,
      count: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

exports.checkPasswordResetPhone = onCall(async (request) => {
  const payload = request.data || {};
  const email = typeof payload.email === 'string' ? payload.email.trim() : '';
  const phoneE164 =
    typeof payload.phoneE164 === 'string' ? payload.phoneE164.trim() : '';

  if (!EMAIL_RE.test(email)) {
    throw new HttpsError('invalid-argument', 'Invalid email.');
  }
  if (!E164_RE.test(phoneE164)) {
    throw new HttpsError('invalid-argument', 'Invalid phone number.');
  }

  // Format hatalarını sayaca hiç yazmadan reddet; yalnızca gerçek denemeler
  // sınırlamaya dahil olsun.
  await enforceRateLimit(hashEmail(email));

  let match = false;
  try {
    const user = await admin.auth().getUserByEmail(email);
    match = Boolean(user.phoneNumber) && user.phoneNumber === phoneE164;
    // Tanılama: gerçek numaralar hiçbir zaman loglanmaz, yalnızca eşleşip
    // eşleşmediğini anlamaya yeten meta bilgi (uzunluk, son 2 hane hash'i).
    logger.info('checkPasswordResetPhone.compared', {
      userFound: true,
      hasStoredPhone: Boolean(user.phoneNumber),
      storedLength: user.phoneNumber ? user.phoneNumber.length : null,
      typedLength: phoneE164.length,
      match,
    });
  } catch (error) {
    if (error && error.code === 'auth/user-not-found') {
      match = false;
      logger.info('checkPasswordResetPhone.compared', {
        userFound: false,
        match: false,
      });
    } else {
      logger.error('checkPasswordResetPhone.lookupFailed', {
        code: error && error.code,
        message: error && error.message,
      });
      throw new HttpsError('internal', 'Lookup failed.');
    }
  }

  // Gerçek numara asla dönmez, yalnızca eşleşip eşleşmediği.
  return { match };
});
