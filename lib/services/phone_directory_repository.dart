import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import 'firebase_refs.dart';

/// Bir numaranın sahiplik durumu.
enum PhoneOwnership {
  /// Dizinde kayıt yok (ya da rezervasyonun süresi dolmuş) — numara serbest.
  free,

  /// Numara zaten bu hesaba ait; yeniden doğrulaması serbest.
  mine,

  /// Numarayı başka bir hesap DOĞRULAMIŞ. Kalıcıdır.
  takenByOther,

  /// Başka bir hesap bu numaraya doğrulama kodu istedi ama kodu henüz
  /// onaylamadı. [PhoneDirectoryRepository.kPendingTtl] kadar geçerlidir;
  /// süresi dolunca numara yeniden serbest kalır (kimse bir numarayı süresiz
  /// kilitleyip başkasının kaydolmasını engelleyemesin).
  pendingByOther,

  /// Sorgu yapılamadı (kural yayınlanmamış, çevrimdışı vb.).
  /// Çağıran taraf akışı durdurmaz: Firebase Auth telefon bağlama sırasında
  /// zaten `credential-already-in-use` ile ikinci kez kontrol eder.
  unknown,
}

/// Doğrulanmış telefon numaralarının sahiplik dizini.
///
/// **Neden ayrı bir koleksiyon?** `student_profiles` / `club_profiles`
/// yalnızca sahibine (ve yöneticiye) okunabilir — firestore.rules'ta
/// `allow read: if isOwner(userId) || isAdmin()`. Yani istemci "bu numara
/// başkasına ait mi" sorusunu profil koleksiyonlarını sorgulayarak
/// yanıtlayamaz; sorgu her zaman `permission-denied` alır.
///
/// **Belge kimliği neden numaranın kendisi (hash değil)?** Kurallar hash
/// hesaplayamaz. Kimlik düz E.164 olduğu için kural, yazan kişinin ID
/// token'ındaki `phone_number` iddiasını belge kimliğiyle karşılaştırabilir:
/// böylece kimse sahibi olmadığı bir numarayı işgal edemez. Karşılığında
/// giriş yapmış bir kullanıcı bir numaranın kayıtlı olup olmadığını tek tek
/// yoklayabilir (`list` kapalı olduğu için toplu tarama yapılamaz).
///
/// **Belge şeması — yayındaki firestore.rules ile birebir aynı olmalı:**
/// `{uid, status, updatedAt}`.
///
/// `status` alanı olmadan yazılan bir belgeyi kural REDDEDER: hem
/// `isVerifiedClaim()` hem `canReserve()` önce `status`'e bakar. Buradaki
/// yazımlar "en iyi çaba" olduğu için hata sessizce yutulur — yani eksik
/// şema, görünürde hiçbir hata vermeden dizinin hiç dolmamasına ve
/// "bu numara başkasına ait" uyarısının hiç çıkmamasına yol açar. Alan
/// adları değişecekse kural da birlikte güncellenmeli.
/// Bkz. `docs/telefon-sahiplik-kurali.md`.
class PhoneDirectoryRepository {
  const PhoneDirectoryRepository();

  /// Numaraya SMS gönderildi, kod henüz onaylanmadı.
  static const String statusPending = 'pending';

  /// Numara Firebase Auth'ta gerçekten bu hesaba bağlı.
  static const String statusVerified = 'verified';

  /// Rezervasyon ömrü. Kuraldaki `duration.value(15, 'm')` ile aynı olmalı.
  static const Duration kPendingTtl = Duration(minutes: 15);

  Doc _doc(String phoneE164) =>
      fbDb.collection(Collections.phoneOwners).doc(phoneE164);

  /// Belge kimliği olarak yalnızca düzgün E.164 kabul edilir; böylece yol
  /// bozan karakterler ya da boş değer koleksiyona sızmaz. Desen, web
  /// tarafındaki `js/modules/auth/phone-registry.js#keyFor` ile aynı olmalı —
  /// aksi hâlde bir platformun yazdığı kimliği diğeri bulamaz.
  static final RegExp _e164 = RegExp(r'^\+\d{6,20}$');

  bool _isUsableKey(String key) => _e164.hasMatch(key);

  /// SMS gönderilmeden önceki sahiplik sorgusu.
  Future<PhoneOwnership> lookup({
    required String phoneE164,
    required String uid,
  }) async {
    final String key = phoneE164.trim();
    if (!_isUsableKey(key)) return PhoneOwnership.unknown;

    try {
      final Snap snap = await _doc(key).get();
      if (!snap.exists) return PhoneOwnership.free;

      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      if (data['uid'] == uid) return PhoneOwnership.mine;

      // `status` taşımayan eski kayıtlar doğrulanmış sayılır: emin olmadığımız
      // durumda numarayı serbest göstermek, iki hesabın aynı numarayı
      // doğrulamaya çalışmasına yol açar.
      if (data['status'] != statusPending) return PhoneOwnership.takenByOther;

      // Rezervasyon kanıt taşımaz; süresi dolduysa numara yeniden serbesttir.
      final Object? updatedAt = data['updatedAt'];
      if (updatedAt is! Timestamp) return PhoneOwnership.pendingByOther;

      final Duration age = DateTime.now().toUtc().difference(
        updatedAt.toDate().toUtc(),
      );
      return age > kPendingTtl
          ? PhoneOwnership.free
          : PhoneOwnership.pendingByOther;
    } catch (_) {
      return PhoneOwnership.unknown;
    }
  }

  /// SMS gönderilmeden hemen önce numarayı geçici olarak rezerve eder.
  ///
  /// Amaç: iki kullanıcının aynı numaraya aynı anda kod istemesini önlemek.
  /// Kayıt kanıt taşımadığı için (kod henüz onaylanmadı) kural yalnızca
  /// [kPendingTtl] boyunca geçerli sayar; sonrasında başkası aynı numarayı
  /// rezerve edebilir.
  ///
  /// En iyi çaba: yazılamazsa doğrulama akışı bozulmaz.
  Future<void> reserve({required String phoneE164, required String uid}) async {
    final String key = phoneE164.trim();
    if (!_isUsableKey(key)) return;

    try {
      await _doc(key).set(<String, dynamic>{
        'uid': uid,
        'status': statusPending,
        // Kural `updatedAt == request.time` şartını arar: istemci ileri
        // tarihli damga yazıp rezervasyonunu sonsuza kadar taze gösteremesin.
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      return;
    }
  }

  /// Kullanıcı doğrulamadan vazgeçtiğinde (pop-up kapatıldı, numara
  /// değiştirildi) kendi rezervasyonunu bırakır — numara [kPendingTtl]
  /// beklemeden serbest kalsın. En iyi çaba.
  Future<void> release({required String phoneE164, required String uid}) async {
    final String key = phoneE164.trim();
    if (!_isUsableKey(key)) return;

    try {
      final Snap snap = await _doc(key).get();
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      // Doğrulanmış kaydı silme: yalnızca kendi bekleyen rezervasyonunu bırak.
      if (data['uid'] != uid || data['status'] != statusPending) return;

      await _doc(key).delete();
    } catch (_) {
      return;
    }
  }

  /// Dizini geçmişe dönük doldurur: giriş yapmış kullanıcının Auth hesabında
  /// bağlı olan numarayı, dizinde yoksa (ya da başka bir uid'ye/bekleyen
  /// kayda yazılmışsa) bu hesaba doğrulanmış olarak yazar.
  ///
  /// **Neden gerekli:** dizin yalnızca kural yayınlandıktan SONRA doğrulanan
  /// numaralarla doluyordu. Daha eski hesapların numaraları dizinde
  /// bulunmadığı için başka bir kullanıcıya "serbest" görünüyor, uyarı da
  /// ancak SMS gönderildikten ve kod girildikten sonra Firebase Auth telefon
  /// bağlama adımında çıkıyordu. Her kullanıcı uygulamayı açtığında kendi
  /// numarasını bir kez yazınca dizin kendiliğinden dolar.
  ///
  /// Kural, yazanın ID token'ındaki `phone_number` iddiasının belge kimliğiyle
  /// eşleşmesini şart koştuğu için bu geriye dönük yazım güvenlidir; kimse
  /// sahibi olmadığı bir numarayı işgal edemez.
  ///
  /// En iyi çaba: yazılamazsa hiçbir akış bozulmaz.
  Future<void> ensureSelfClaim(User user) async {
    final String phone = (user.phoneNumber ?? '').trim();
    if (!_isUsableKey(phone)) return;

    try {
      final Snap snap = await _doc(phone).get();
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      if (snap.exists &&
          data['uid'] == user.uid &&
          data['status'] == statusVerified) {
        return;
      }

      await _doc(phone).set(<String, dynamic>{
        'uid': user.uid,
        'status': statusVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Kural yayınlanmamış / çevrimdışı / token'da phone_number iddiası yok.
    }
  }

  /// Doğrulama tamamlandıktan sonra numarayı bu hesaba yazar ve varsa eski
  /// numarayı dizinden düşürür (numara serbest kalsın).
  ///
  /// En iyi çaba: yazılamazsa doğrulama akışı bozulmaz, yalnızca sonraki
  /// sorgular bu numarayı "serbest" görür.
  Future<void> claim({
    required String phoneE164,
    required String uid,
    String? previousPhoneE164,
  }) async {
    final String key = phoneE164.trim();
    if (!_isUsableKey(key)) return;

    try {
      await _doc(key).set(<String, dynamic>{
        'uid': uid,
        'status': statusVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      return;
    }

    final String previous = (previousPhoneE164 ?? '').trim();
    if (!_isUsableKey(previous) || previous == key) return;

    try {
      await _doc(previous).delete();
    } catch (_) {
      // Eski kayıt silinemezse yalnızca o numara gereksiz yere rezerve kalır.
    }
  }
}
