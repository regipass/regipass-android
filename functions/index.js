/**
 * Regipass Cloud Functions.
 *
 * personalizeCertificates
 * ------------------------
 * Kulup bir PDF sertifika sablonu yukleyip ogrencilere dagittiginda, sablonda
 * isim yazilacak alani (kilit kelime / noktali-cizgili yer tutucu / vektor
 * cizgi / genis bosluk) bulup her ogrencinin adini oraya basar.
 *
 * Bu mantik daha once yalnizca web istemcisinde (pdf.js + pdf-lib tarayicida
 * calisiyordu, js/modules/certificates/certificate-engine.js) vardi; Flutter
 * kulup panelindeki dagitim ayni islemi hic yapmiyor, sablonu oldugu gibi her
 * ogrenciye kopyaliyordu (bkz. club_event_detail_screen.dart, personalized:
 * false). certificateEngine.js (bu klasordeki, ayni algoritmanin Node portu)
 * burada cagrilarak iki istemcinin de AYNI kodla isim bastigi tek nokta
 * haline getirildi — web taraf da ileride buraya tasinabilir.
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
const { createPasswordResetHintHandler } = require('./passwordResetHint');
const { createPhoneOwnershipHandler } = require('./phoneOwnership');

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
const PHONE_OWNERSHIP_ATTEMPTS_COLLECTION = 'phone_ownership_attempts';
const MAX_PHONE_OWNERSHIP_ATTEMPTS_PER_WINDOW = 30;

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
async function enforceRateLimit(emailHash, maxAttempts = MAX_ATTEMPTS_PER_WINDOW) {
  const ref = db.collection(RATE_LIMIT_COLLECTION).doc(emailHash);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart =
      data && typeof data.windowStart === 'number' ? data.windowStart : 0;
    const withinWindow = now - windowStart < WINDOW_MS;
    const count = withinWindow && typeof data.count === 'number' ? data.count : 0;

    if (withinWindow && count >= maxAttempts) {
      throw new HttpsError('resource-exhausted', 'Too many attempts.');
    }

    tx.set(ref, {
      windowStart: withinWindow ? windowStart : now,
      count: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function enforcePhoneOwnershipRateLimit(uid) {
  const ref = db.collection(PHONE_OWNERSHIP_ATTEMPTS_COLLECTION).doc(uid);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart =
      data && typeof data.windowStart === 'number' ? data.windowStart : 0;
    const withinWindow = now - windowStart < WINDOW_MS;
    const count = withinWindow && typeof data.count === 'number' ? data.count : 0;

    if (withinWindow && count >= MAX_PHONE_OWNERSHIP_ATTEMPTS_PER_WINDOW) {
      throw new HttpsError('resource-exhausted', 'Too many attempts.');
    }

    tx.set(ref, {
      windowStart: withinWindow ? windowStart : now,
      count: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/// Firebase Auth sonucuyla `phone_owners` dizinini uzlaştırır. Auth'ta sahibi
/// olmayan numaradan yalnızca doğrulanmış eski kayıt temizlenir; devam eden
/// SMS rezervasyonuna hiç dokunulmaz.
async function reconcilePhoneOwner({ phoneE164, ownerUid }) {
  const ref = db.collection('phone_owners').doc(phoneE164);
  if (ownerUid) {
    await ref.set({
      uid: ownerUid,
      status: 'verified',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists && snap.data()?.status === 'verified') tx.delete(ref);
  });
}

exports.getPasswordResetHint = onCall(
  { timeoutSeconds: 10 },
  createPasswordResetHintHandler({
    auth: admin.auth(),
    // İpucu okumaları eski SMS ön kontrolünün deneme hakkını tüketmez.
    rateLimit: (email) => enforceRateLimit(`hint_${hashEmail(email)}`, 60),
    logError: (fields) => logger.warn('passwordResetHint.lookupFailed', fields),
  }),
);

exports.checkPhoneOwnership = onCall(
  { timeoutSeconds: 10 },
  createPhoneOwnershipHandler({
    auth: admin.auth(),
    rateLimit: enforcePhoneOwnershipRateLimit,
    reconcile: reconcilePhoneOwner,
    logError: (fields) => logger.warn('phoneOwnership.lookupFailed', fields),
  }),
);

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

const MAX_TEMPLATE_BYTES = 10 * 1024 * 1024; // storage.rules certificates/ limitiyle aynı.
const MAX_STUDENTS_PER_CALL = 300;
const STUDENT_ID_RE = /^[A-Za-z0-9_-]{1,200}$/;
const DOCUMENT_KEY_RE = /^[A-Za-z0-9_-]{1,200}$/;

/** Client SDK'nin getDownloadURL() ile ürettiğiyle aynı biçimde bir indirme adresi kurar. */
function buildDownloadUrl(bucketName, filePath, token) {
  const encodedPath = encodeURIComponent(filePath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${token}`;
}

exports.personalizeCertificates = onCall(
  { memory: '1GiB', timeoutSeconds: 300 },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError('unauthenticated', 'Sign-in required.');
    }

    const payload = request.data || {};
    const clubId = typeof payload.clubId === 'string' ? payload.clubId : '';
    const eventId = typeof payload.eventId === 'string' ? payload.eventId : '';
    const documentKey =
      typeof payload.documentKey === 'string' ? payload.documentKey : '';
    const templateBase64 =
      typeof payload.templateBase64 === 'string' ? payload.templateBase64 : '';
    const students = Array.isArray(payload.students) ? payload.students : [];

    if (auth.uid !== clubId) {
      throw new HttpsError('permission-denied', 'clubId must match caller.');
    }
    if (!eventId || !DOCUMENT_KEY_RE.test(documentKey)) {
      throw new HttpsError('invalid-argument', 'Invalid eventId/documentKey.');
    }
    if (!templateBase64) {
      throw new HttpsError('invalid-argument', 'Missing templateBase64.');
    }
    if (students.length === 0 || students.length > MAX_STUDENTS_PER_CALL) {
      throw new HttpsError('invalid-argument', 'Invalid students list.');
    }
    for (const student of students) {
      const studentId = student && student.studentId;
      const fullName = student && student.fullName;
      if (typeof studentId !== 'string' || !STUDENT_ID_RE.test(studentId)) {
        throw new HttpsError('invalid-argument', 'Invalid studentId.');
      }
      if (typeof fullName !== 'string' || !fullName.trim()) {
        throw new HttpsError('invalid-argument', 'Invalid fullName.');
      }
    }

    // Belge kulübün KENDİ etkinliğine mi ait — clubId sahteciliğine karşı
    // ikinci katman (storage.rules zaten aynı kontrolü yapar, burada da
    // yüklenen sertifikanın gerçekten bu kulübe ait olduğundan emin oluyoruz).
    const eventSnap = await db.collection('events').doc(eventId).get();
    if (!eventSnap.exists || eventSnap.data().clubId !== clubId) {
      throw new HttpsError('permission-denied', 'Event does not belong to caller.');
    }

    let templateBuffer;
    try {
      templateBuffer = Buffer.from(templateBase64, 'base64');
    } catch (error) {
      throw new HttpsError('invalid-argument', 'templateBase64 could not be decoded.');
    }
    if (templateBuffer.length === 0 || templateBuffer.length > MAX_TEMPLATE_BYTES) {
      throw new HttpsError('invalid-argument', 'Template too large or empty.');
    }

    // Telefon kurtarma fonksiyonlarının soğuk başlangıcı PDF motorunu beklemez.
    const { analyzePdfTemplate, personalizePdfWithName } = require('./certificateEngine');
    let analysis = { found: false };
    try {
      analysis = await analyzePdfTemplate(templateBuffer);
    } catch (error) {
      logger.warn('personalizeCertificates.analyzeFailed', {
        message: error && error.message,
      });
    }

    const bucket = admin.storage().bucket();
    const results = [];

    for (const student of students) {
      const studentId = student.studentId;
      const fullName = student.fullName.trim();

      let bytes = templateBuffer;
      let personalized = false;

      if (analysis.found) {
        try {
          bytes = Buffer.from(await personalizePdfWithName(templateBuffer, analysis, fullName));
          personalized = true;
        } catch (error) {
          logger.warn('personalizeCertificates.stampFailed', {
            studentId,
            message: error && error.message,
          });
          bytes = templateBuffer;
          personalized = false;
        }
      }

      const filePath = `certificates/${clubId}/${eventId}/${studentId}-${documentKey}.pdf`;
      const token = crypto.randomUUID();

      await bucket.file(filePath).save(bytes, {
        contentType: 'application/pdf',
        metadata: { metadata: { firebaseStorageDownloadTokens: token } },
      });

      results.push({
        studentId,
        filePath,
        fileUrl: buildDownloadUrl(bucket.name, filePath, token),
        personalized,
      });
    }

    return { results, analysisFound: analysis.found };
  }
);
