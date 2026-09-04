/// Ücretli etkinlik onay logu — **web ile ortak şema**.
///
/// Hem etkinlik (`events/{eventId}`) hem kayıt
/// (`event_registrations/{eventId}_{studentId}`) belgesinde aynı ada sahip
/// tek bir harita tutulur:
///
/// ```
/// paidConsentLog: {
///   approved:            true
///   text:                kabul edilen metnin TAM hâli
///   approvedAtMs:        epoch milisaniye (sorgulanabilir asıl değer)
///   approvedAt:          FieldValue.serverTimestamp()
///   approvedAtFormatted: "03.09.2026 14:22:07"
/// }
/// ```
///
/// Alan adları web'deki `js/pages/dashboard.js#buildRegistrationPayload` ve
/// `js/pages/club-create-event.js#saveEvent` ile BİREBİR aynıdır; iki istemci
/// aynı logu okuyup yazar. Değiştirilecekse iki tarafta birden değişmeli.
library;

/// Onay metinlerinin sürümü.
///
/// Yeni kayıtlarda metnin kendisi saklandığı için sürüm YAZILMAZ; alan
/// yalnızca bu değerle yazılmış eski kayıtları okumak için duruyor.
const int kPaidEventConsentVersion = 1;

/// Firestore'daki harita alanının adı — iki belgede de aynı.
const String kPaidConsentLogField = 'paidConsentLog';

/// Onayı veren taraf. Yalnızca ESKİ (düz alanlı) kayıtları okurken ve
/// ekranda etiketlemek için gerekir; yazılan harita her iki tarafta aynıdır.
class PaidEventConsentRole {
  static const String club = 'club';
  static const String student = 'student';
}

/// İşlem logunun okunabilir damgası: `03.09.2026 14:22:07`.
///
/// Web'deki `formatConsentTimestamp` (Intl `tr-TR`, 2 haneli gün/ay/saat)
/// ile aynı çıktıyı verir. Sorgulanabilir asıl değer her zaman yanındaki
/// `approvedAtMs`; bu alan yalnızca okunabilirlik içindir.
String formatPaidEventConsentStamp(DateTime at) {
  final DateTime t = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Kullanıcının ekranda gördüğü ve kutuyu işaretleyerek kabul ettiği onay.
///
/// Onay penceresi `bool` yerine bunu döndürür: yazan taraf, ekranda hangi
/// metnin gösterildiğini tahmin etmek zorunda kalmaz — metin kabul anındaki
/// hâliyle taşınır ve aynen kaydedilir.
class PaidEventConsentAcceptance {
  const PaidEventConsentAcceptance({
    required this.role,
    required this.title,
    required this.text,
    required this.checkboxLabel,
    required this.language,
    required this.acceptedAt,
  });

  /// [PaidEventConsentRole] değerlerinden biri.
  final String role;

  /// Pencere başlığı ve işaretlenen kutunun metni yalnızca ekran içindir;
  /// web ile ortak şemada saklanmazlar (log tek bir `text` taşır).
  final String title;
  final String checkboxLabel;
  final String language;

  final String text;
  final DateTime acceptedAt;

  bool get isClub => role == PaidEventConsentRole.club;

  /// Belgeye yazılacak `paidConsentLog` haritası.
  ///
  /// Sunucu damgası (`approvedAt`) burada üretilmez: `FieldValue` Firestore'a
  /// aittir, bu katman saf tutulur. Yazan depo bu haritanın üstüne kendi
  /// `FieldValue.serverTimestamp()` alanını ekler.
  Map<String, Object?> toLogMap() => <String, Object?>{
    'approved': true,
    'text': text,
    'approvedAtMs': acceptedAt.millisecondsSinceEpoch,
    'approvedAtFormatted': formatPaidEventConsentStamp(acceptedAt),
  };
}

/// Belgeden okunmuş onay logu — ekranda gösterilen biçim.
class PaidEventConsentLog {
  const PaidEventConsentLog({
    required this.role,
    required this.approved,
    required this.atMs,
    required this.stamp,
    required this.text,
  });

  /// [data] içinden `paidConsentLog` haritasını okur.
  ///
  /// Harita yoksa ESKİ düz alanlara bakılır: mobil bir süre
  /// `paidEventClubConsentAt/Version` ve `paidEventStudentConsentAt/Version`
  /// yazıyordu. O kayıtlar da log olarak görünür, metin alanları boş kalır.
  /// Hiçbiri yoksa `null` döner (ücretsiz etkinlik ya da onaysız kayıt).
  static PaidEventConsentLog? fromMap(
    Map<String, dynamic> data, {
    required String role,
  }) {
    final Object? raw = data[kPaidConsentLogField];

    if (raw is Map) {
      final Map<Object?, Object?> map = raw;
      final int atMs = _asInt(map['approvedAtMs']);
      final String text = map['text'] is String ? map['text']! as String : '';
      final String formatted = map['approvedAtFormatted'] is String
          ? map['approvedAtFormatted']! as String
          : '';

      return PaidEventConsentLog(
        role: role,
        approved: map['approved'] == true,
        atMs: atMs,
        stamp: formatted.isNotEmpty ? formatted : _stampFromMs(atMs),
        text: text,
      );
    }

    return _legacy(data, role: role);
  }

  /// Web şeması eklenmeden önce mobilin yazdığı düz alanlar.
  static PaidEventConsentLog? _legacy(
    Map<String, dynamic> data, {
    required String role,
  }) {
    final String prefix = role == PaidEventConsentRole.club
        ? 'paidEventClubConsent'
        : 'paidEventStudentConsent';

    final int atMs = _asInt(data['${prefix}AtMs']);
    final int version = _asInt(data['${prefix}Version']);
    final bool accepted = data['${prefix}Accepted'] == true;
    if (!accepted && version <= 0 && atMs <= 0) return null;

    final Object? local = data['${prefix}AtLocal'];
    final Object? text = data['${prefix}Text'];

    return PaidEventConsentLog(
      role: role,
      approved: true,
      atMs: atMs,
      stamp: local is String && local.isNotEmpty ? local : _stampFromMs(atMs),
      text: text is String ? text : '',
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _stampFromMs(int atMs) => atMs > 0
      ? formatPaidEventConsentStamp(DateTime.fromMillisecondsSinceEpoch(atMs))
      : '';

  final String role;
  final bool approved;
  final int atMs;

  /// `03.09.2026 14:22:07`
  final String stamp;
  final String text;

  bool get isClub => role == PaidEventConsentRole.club;
}
