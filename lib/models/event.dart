import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../domain/checkin_mode.dart';
import '../domain/paid_event_consent.dart';
import 'profiles.dart';

/// `events/{eventId}` — club-create-event.js#saveEvent yükünün karşılığı.
class AppEvent {
  const AppEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.purpose,
    required this.feeType,
    required this.feeAmount,
    required this.feeInfo,
    required this.targetScope,
    required this.targetUniversity,
    required this.targetUniversities,
    required this.targetDepartment,
    required this.targetDepartments,
    required this.targetSector,
    required this.imageUrl,
    required this.quota,
    this.quotaShardCount = 0,
    required this.deadlineAtMs,
    required this.sessionCount,
    this.checkinMode = '',
    this.allowSessionWithoutCheckin = false,
    this.entryOpen = false,
    this.entryStartedAtMs = 0,
    this.doorQrPublished = false,
    this.sessionQrPublished = 0,
    required this.certificateThresholdPercent,
    required this.locationName,
    required this.locationLat,
    required this.locationLng,
    required this.locationRadius,
    required this.clubId,
    required this.clubName,
    required this.clubUniversity,
    required this.clubLogoUrl,
    required this.clubPhone,
    required this.clubEmail,
    required this.clubField,
    required this.clubFields,
    required this.registrationClosed,
    this.registrationClosedReason = '',
    this.cancelled = false,
    this.cancelReason = '',
    this.seatsFull = false,
    this.contactMode = '',
    this.contactPhone = '',
    this.contactEmail = '',
    required this.hiddenFromClubList,
    required this.hiddenGlobally,
    required this.currentSession,
    required this.sessionsCompleted,
    required this.createdAtMs,
    required this.eventDate,
    required this.eventDateAtMs,
    required this.eventStartTime,
    required this.eventEndTime,
    required this.eventEndAtMs,
    this.eventStartAtMs,
    this.autoNotifications = const <String, bool>{},
    this.notificationsSent = const <String, int>{},
    required this.certificateTemplateUrl,
    required this.certificateTemplateName,
    required this.certificateTemplateType,
    required this.certificateDocuments,
    this.clubConsentLog,
  });

  factory AppEvent.fromMap(String id, Map<String, dynamic> data) {
    final int rawSessionCount = asInt(data['sessionCount']) ?? 1;
    return AppEvent(
      id: id,
      title: asString(data['title']),
      description: asString(data['description']),
      purpose: asString(data['purpose']),
      feeType: asString(data['feeType']),
      feeAmount: asInt(data['feeAmount']) ?? 0,
      feeInfo: asString(data['feeInfo']),
      targetScope: (data['targetScope'] as String?) ?? TargetScope.public,
      targetUniversity: asString(data['targetUniversity']),
      // Çoklu hedef: yeni kayıtlarda dizi, eski kayıtlarda yalnızca tekil
      // alan var. `clubFields` ile aynı yaklaşım — okuyan taraf iki durumu
      // ayırt etmek zorunda kalmasın diye tek biçime indiriliyor.
      targetUniversities: asStringList(
        data['targetUniversities'],
        asString(data['targetUniversity']),
      ),
      targetDepartment: asString(data['targetDepartment']),
      targetDepartments: asStringList(
        data['targetDepartments'],
        asString(data['targetDepartment']),
      ),
      targetSector: asString(data['targetSector']),
      imageUrl: asString(data['imageUrl']),
      quota: asInt(data['quota']) ?? 0,
      quotaShardCount: asInt(data['quotaShardCount']) ?? 0,
      // Yeni kayıtlar `deadlineAtMs` ile yazılır. Eski web kayıtlarında aynı
      // tarih `deadlineAt` veya Firestore Timestamp olarak bulunabiliyor;
      // ikisini de okuyup her zaman epoch milisaniyesine dönüştürüyoruz.
      deadlineAtMs:
          asEpochMilliseconds(data['deadlineAtMs']) ??
          asEpochMilliseconds(data['deadlineAt']) ??
          0,
      // Web'de 1 ve altı her değer "tek oturumlu" sayılır.
      sessionCount: rawSessionCount > 1 ? rawSessionCount : 1,
      // Boş değer eski web kayıtlarını belirtir; [resolvedCheckinMode] onların
      // davranışını sessionCount'tan türetir.
      checkinMode: asString(data['checkinMode']),
      allowSessionWithoutCheckin: data['allowSessionWithoutCheckin'] == true,
      entryOpen: data['entryOpen'] == true,
      // Kapı BİR KEZ açıldığında yazılır ve bir daha silinmez; check-in
      // "bitti" ile "hiç başlamadı" ancak bu alanla ayrılabilir.
      entryStartedAtMs: asEpochMilliseconds(data['entryStartedAtMs']) ?? 0,
      doorQrPublished: data['doorQrPublished'] == true,
      sessionQrPublished: asInt(data['sessionQrPublished']) ?? 0,
      certificateThresholdPercent: asInt(data['certificateThresholdPercent']),
      locationName: asString(data['locationName']),
      locationLat: asDouble(data['locationLat']),
      locationLng: asDouble(data['locationLng']),
      locationRadius: asInt(data['locationRadius']),
      clubId: asString(data['clubId']),
      clubName: asString(data['clubName']),
      clubUniversity: asString(data['clubUniversity']),
      clubLogoUrl: asString(data['clubLogoUrl']),
      clubPhone: asString(data['clubPhone']),
      clubEmail: asString(data['clubEmail']),
      clubField: asString(data['clubField']),
      // Çoklu alan: yeni kayıtlarda dizi var, eski kayıtlarda yalnızca tekil
      // `clubField`. Keşif algoritması her iki durumda da aynı listeyi görsün
      // diye burada tek biçime indiriliyor.
      clubFields: asStringList(data['clubFields'], asString(data['clubField'])),
      registrationClosed: data['registrationClosed'] == true,
      registrationClosedReason: asString(data['registrationClosedReason']),
      // İP-K: iptal ve "kontenjan dolu" ipucu yalnızca sunucudan yazılır
      // (functions/registrations.js).
      cancelled: data['cancelled'] == true,
      cancelReason: asString(data['cancelReason']),
      seatsFull: data['seatsFull'] == true,
      // İP-K: etkinlikte gösterilecek iletişim bilgisi seçimi.
      contactMode: asString(data['contactMode']),
      contactPhone: asString(data['contactPhone']),
      contactEmail: asString(data['contactEmail']),
      hiddenFromClubList: data['hiddenFromClubList'] == true,
      hiddenGlobally: data['hiddenGlobally'] == true,
      currentSession: asInt(data['currentSession']) ?? 0,
      sessionsCompleted: data['sessionsCompleted'] == true,
      createdAtMs: asInt(data['createdAtMs']) ?? 0,
      // Etkinliğin YAPILDIĞI gün — son başvurudan (deadlineAtMs) farklı.
      eventDate: asString(data['eventDate']),
      eventDateAtMs: asEpochMilliseconds(data['eventDateAtMs']),
      eventStartTime: asString(data['eventStartTime']),
      eventEndTime: asString(data['eventEndTime']),
      eventEndAtMs: asEpochMilliseconds(data['eventEndAtMs']),
      eventStartAtMs: asEpochMilliseconds(data['eventStartAtMs']),
      autoNotifications: _readBoolMap(data['autoNotifications']),
      notificationsSent: _readIntMap(data['notificationsSent']),
      certificateTemplateUrl: asString(data['certificateTemplateUrl']),
      certificateTemplateName: asString(data['certificateTemplateName']),
      certificateTemplateType: asString(data['certificateTemplateType']),
      certificateDocuments: _readCertificateDocuments(data),
      // Ücretli etkinliğin kulüp onay logu etkinliğin kendi belgesinde
      // durur; ücretsiz etkinlikte alanlar hiç yazılmadığı için null kalır.
      clubConsentLog: PaidEventConsentLog.fromMap(
        data,
        role: PaidEventConsentRole.club,
      ),
    );
  }

  static AppEvent? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.exists ? AppEvent.fromMap(doc.id, doc.data()!) : null;

  /// Etkinliğe yüklenmiş belgeler.
  ///
  /// Yeni kayıtlarda `certificateDocuments` dizisi var. Diziden önce yazılmış
  /// (ve web'in hâlâ yazdığı) kayıtlarda yalnızca tek şablonun alanları
  /// bulunur; o belge de listede tek eleman olarak görünsün diye burada
  /// dizinin ilk elemanına dönüştürülür — aksi hâlde kulüp eskiden yüklediği
  /// belgeyi listede hiç göremezdi.
  static List<EventDocument> _readCertificateDocuments(
    Map<String, dynamic> data,
  ) {
    final Object? raw = data['certificateDocuments'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) =>
                EventDocument.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((EventDocument doc) => doc.url.isNotEmpty)
          .toList();
    }

    final String legacyUrl = asString(data['certificateTemplateUrl']);
    if (legacyUrl.isEmpty) return const <EventDocument>[];

    return <EventDocument>[
      EventDocument(
        url: legacyUrl,
        name: asString(data['certificateTemplateName']),
        path: asString(data['certificateTemplatePath']),
        contentType: asString(data['certificateTemplateType']),
        uploadedAtMs: asEpochMilliseconds(data['certificateUploadedAt']) ?? 0,
      ),
    ];
  }

  final String id;
  final String title;
  final String description;
  final String purpose;
  final String feeType;
  final int feeAmount;
  final String feeInfo;
  final String targetScope;

  /// Geriye dönük uyumluluk için tutulan tekil hedefler (dizinin ilk elemanı).
  final String targetUniversity;
  final String targetDepartment;

  /// Etkinliğin hedeflediği tüm üniversiteler / bölümler.
  final List<String> targetUniversities;
  final List<String> targetDepartments;

  final String targetSector;
  final String imageUrl;
  final int quota;

  /// Kontenjan sayacının kaç parçaya bölündüğü
  /// (`events/{id}/quota_shards/{0..n-1}`).
  ///
  /// Kulüp etkinliği oluştururken yazar. **0 ise parça yoktur**: ya kontenjansız
  /// bir etkinliktir ya da bu alan eklenmeden önce oluşturulmuş eski bir kayıt.
  /// İki durumda da kayıt eski (kontenjansız) yoldan geçer — eski etkinliklere
  /// kaydolmak engellenmemeli. Bkz. `lib/services/registration_service.dart`.
  final int quotaShardCount;

  final int deadlineAtMs;
  final int sessionCount;
  final String checkinMode;
  final bool allowSessionWithoutCheckin;
  final bool entryOpen;
  final int entryStartedAtMs;
  final bool doorQrPublished;
  final int sessionQrPublished;

  bool get hasActiveDoorQr => hasDoorCheckin && entryOpen && doorQrPublished;
  bool get hasActiveSessionQr =>
      isMultiSession &&
      !sessionsCompleted &&
      currentSession > 0 &&
      sessionQrPublished == currentSession;
  final int? certificateThresholdPercent;
  final String locationName;
  final double? locationLat;
  final double? locationLng;
  final int? locationRadius;
  final String clubId;
  final String clubName;
  final String clubUniversity;

  /// Etkinliği düzenleyen kulübün logosu — kayıt anında kulüp profilinden
  /// kopyalanır.
  ///
  /// Etkinlik penceresinde kulüp adının sağındaki küçük rozet budur. Öğrenci
  /// `club_profiles` dokümanlarını okuyamadığı için logo etkinliğin içinde
  /// durur; kulüp logosunu değiştirdiğinde eski etkinlikler
  /// `EventRepository.syncClubLogo` ile güncellenir.
  final String clubLogoUrl;

  /// Kulübün iletişim bilgileri — logoyla aynı gerekçeyle etkinlik
  /// dokümanına kopyalanır: öğrenci `club_profiles` dokümanlarını okuyamaz.
  ///
  /// Yalnızca ÜCRETLİ etkinliklerin penceresinde gösterilir (ücretsizde
  /// kulübün numarasını yaymanın bir gerekçesi yok). Bu alanlar eklenmeden
  /// önce oluşturulmuş etkinliklerde boştur; kulüp hesabını bir kez
  /// kaydettiğinde `EventRepository.syncClubContact` ile dolar.
  final String clubPhone;
  final String clubEmail;

  /// Ücretli mi. Kulüp formunda `free` / `paid` seçiliyor; alanı hiç olmayan
  /// çok eski kayıtlar ücretsiz sayılır.
  bool get isPaid => feeType == 'paid';

  final String clubField;

  /// Kulübün tüm alanları. Tek alanlı eski kayıtlarda tek elemanlıdır.
  final List<String> clubFields;

  final bool registrationClosed;

  /// Kayıtlar neden kapalı: [ClosedReason.quotaFull] ya da
  /// [ClosedReason.manual]. Boşsa eski bir kayıttır (sebep yazılmadan
  /// kapatılmış) ve kontenjan takibi ona dokunmaz.
  ///
  /// Ayrım şart: kontenjan dolduğu için kendiliğinden kapanan etkinlik yer
  /// açılınca geri açılmalı, kulübün eliyle durdurduğu etkinlik açılmamalı.
  final String registrationClosedReason;

  /// İP-K: kulüp etkinliği iptal etti (kayıtlar korunur, biletler geçersiz).
  final bool cancelled;
  final String cancelReason;

  /// İP-K: kontenjan doldu — öğrenci bekleme listesine girebilir.
  final bool seatsFull;

  /// İP-K: 'club' (varsayılan, kulübün kayıtlı bilgisi) | 'custom' (etkinliğe
  /// özel [contactPhone]/[contactEmail]) | 'hidden' (yalnızca ücretsizde).
  final String contactMode;
  final String contactPhone;
  final String contactEmail;

  /// Etkinlikte gösterilecek iletişim (web event-chips.js#resolveEventContact).
  ({String phone, String email, bool hidden}) get shownContact {
    if (contactMode == 'hidden' && !isPaid) {
      return (phone: '', email: '', hidden: true);
    }
    if (contactMode == 'custom') {
      return (phone: contactPhone.trim(), email: contactEmail.trim(), hidden: false);
    }
    return (phone: clubPhone.trim(), email: clubEmail.trim(), hidden: false);
  }

  /// Yeni etkinlik: kontenjan sunucuda kurulana kadar kayda kapalı.
  bool get quotaSetupPending => registrationClosed && registrationClosedReason == 'quota-setup';
  final bool hiddenFromClubList;
  final bool hiddenGlobally;
  final int currentSession;
  final bool sessionsCompleted;
  final int createdAtMs;

  /// `yyyy-MM-dd` — etkinliğin yapılacağı gün.
  final String eventDate;
  final int? eventDateAtMs;

  /// `HH:mm` biçiminde saat aralığı (boş olabilir).
  final String eventStartTime;
  final String eventEndTime;

  /// Etkinliğin bitiş anı (gün + bitiş saati). Saat girilmediyse yazılmaz;
  /// "etkinlik bitti mi" kararı o durumda gün sonuna düşer (bkz.
  /// `isEventFinished`).
  final int? eventEndAtMs;

  /// Başlangıç anı (gün + başlangıç saati); saat girilmediyse null.
  final int? eventStartAtMs;

  /// İP-B: kulübün kapattığı otomatik bildirimler (`false`); yoksa açık.
  final Map<String, bool> autoNotifications;

  /// İP-B: sunucunun gönderdiği otomatik bildirimler → gönderim anı (ms).
  final Map<String, int> notificationsSent;

  /// Kulübün dağıtım için yüklediği SON belge şablonu (yalnızca kulüp görür).
  ///
  /// Çoklu belge desteğinden önce tek kaynak buydu; web tarafı hâlâ bu
  /// alanları okuduğu için yazılmaya devam ediyor. Uygulama içinde
  /// [certificateDocuments] kullanılır.
  final String certificateTemplateUrl;
  final String certificateTemplateName;
  final String certificateTemplateType;

  /// Etkinliğe yüklenmiş tüm belgeler (yükleme sırasına göre).
  final List<EventDocument> certificateDocuments;

  /// Ücretli etkinlikte kulübün oluşturma anındaki onay logu; yoksa `null`.
  final PaidEventConsentLog? clubConsentLog;

  String get resolvedCheckinMode =>
      CheckinMode.resolve(checkinMode, sessionCount);

  /// Bu alan yeni modlarla birlikte yazıldı mı? Eski tek oturum kayıtları
  /// öğrenci QR'ını kulübe okutmaya devam eder; kapıdaki paylaşılan QR'a
  /// kendiliğinden taşınmaz.
  bool get usesDoorQr =>
      CheckinMode.isValid(checkinMode) &&
      CheckinMode.hasDoorCheckin(resolvedCheckinMode);

  bool get hasDoorCheckin => CheckinMode.hasDoorCheckin(resolvedCheckinMode);

  bool get isMultiSession => CheckinMode.hasSessions(resolvedCheckinMode);

  bool get requiresDoorCheckinForSession =>
      CheckinMode.requiresDoorCheckinForSession(
        mode: resolvedCheckinMode,
        allowSessionWithoutCheckin: allowSessionWithoutCheckin,
      );

  /// Kapı check-in'inin aşaması: başlamadı / açık / bitti.
  /// Kapı girişi olmayan modda (`attendance_only`) `null`.
  CheckinStage? get checkinStage => resolveCheckinStage(
    mode: resolvedCheckinMode,
    entryStartedAtMs: entryStartedAtMs,
    entryOpen: entryOpen,
  );

  /// İlk oturum, kapı check-in'i bitirilmediği için kilitli mi?
  bool get doorCheckinBlocksSessions => doorCheckinBlocksSessionsFor(
    mode: resolvedCheckinMode,
    currentSession: currentSession,
    entryStartedAtMs: entryStartedAtMs,
    entryOpen: entryOpen,
  );

  bool get hasCertificateTemplate => certificateTemplateUrl.isNotEmpty;

  bool get hasCertificateDocuments => certificateDocuments.isNotEmpty;

  /// Saat aralığı gösterimi: "14:00 - 17:00", tek taraf varsa yalnızca o.
  String get timeRangeLabel {
    if (eventStartTime.isEmpty && eventEndTime.isEmpty) return '';
    if (eventEndTime.isEmpty) return eventStartTime;
    if (eventStartTime.isEmpty) return eventEndTime;
    return '$eventStartTime - $eventEndTime';
  }

  /// Konum doğrulaması yapılacak mı? (Her iki koordinat da yazılmışsa.)
  bool get hasLocationCheck =>
      locationLat != null &&
      locationLng != null &&
      locationLat!.isFinite &&
      locationLng!.isFinite &&
      locationLat!.abs() <= 90 &&
      locationLng!.abs() <= 180;

  /// Etkinlik oluşturulurken haritadan hiç konum seçilmediyse, QR okutma
  /// sırasında öğrencinin cihazından konum istenmez. Yarım ya da hatalı
  /// koordinatlar bu kapsama girmez; bunlar doğrulama hatası olarak kalır.
  bool get hasNoLocationCheck => locationLat == null && locationLng == null;

  /// Konum yarıçapı — girilmemişse web ile aynı varsayılan: 50 m.
  int get effectiveRadius => (locationRadius ?? 0) > 0 ? locationRadius! : 50;

  /// Kartlarda ve detay penceresinde gösterilecek kapak.
  ///
  /// Kulübün gerçekten seçtiği kapak yoksa boş döner: yer tutucu ağdan
  /// çekilen bir görsel değil, `EventImage`'ın çizdiği gri marka
  /// perdesidir (bkz. [isAutoCoverUrl]).
  String get displayImageUrl => isAutoCoverUrl(imageUrl) ? '' : imageUrl;
}

/// Kulübün bir etkinliğe yüklediği tek belge.
///
/// `events/{eventId}.certificateDocuments` dizisinin elemanı. Kulüp aynı
/// etkinliğe birden fazla belge yükleyebilir; her biri ayrı bir Storage
/// nesnesidir ([path]) ve listeden silinirken o nesne de silinir.
class EventDocument {
  const EventDocument({
    required this.url,
    required this.name,
    required this.path,
    required this.contentType,
    required this.uploadedAtMs,
    this.distributedAtMs = 0,
    this.distributedCount = 0,
  });

  factory EventDocument.fromMap(Map<String, dynamic> data) => EventDocument(
    url: asString(data['url']),
    name: asString(data['name']),
    path: asString(data['path']),
    contentType: asString(data['contentType']),
    uploadedAtMs: asInt(data['uploadedAtMs']) ?? 0,
    distributedAtMs: asInt(data['distributedAtMs']) ?? 0,
    distributedCount: asInt(data['distributedCount']) ?? 0,
  );

  final String url;
  final String name;

  /// Storage yolu — silme işlemi buna dayanır. Diziden önceki kayıtlarda boş
  /// olabilir; o durumda yalnızca liste kaydı silinir.
  final String path;

  final String contentType;
  final int uploadedAtMs;

  /// Bu belgenin en son ne zaman ve kaç öğrenciye dağıtıldığı.
  ///
  /// Yükleme ile dağıtım aynı an olmak zorunda değil: kulüp belgeyi çoğu
  /// zaman yoklamalar tamamlanmadan hazırlıyor, hak sahipleri sonra
  /// belirleniyor. Bu iki alan olmasa "bu belge kimseye gitmemiş" bilgisi
  /// hiçbir yerde durmuyordu; belge arşivde görünüyor, kulüp gönderilmiş
  /// sanıyor, öğrenci hiç alamıyordu. Otomatik dağıtım da bunlara bakar:
  /// hak sahibi sayısı [distributedCount] değerini geçtiyse belge yeniden
  /// dağıtılır.
  final int distributedAtMs;
  final int distributedCount;

  bool get isDistributed => distributedAtMs > 0;

  /// Belgeyi aynı etkinliğin diğer belgelerinden ayıran sabit anahtar.
  ///
  /// Öğrenciye yazılan belge kaydının kimliği (`{eventId}_{studentId}_{key}`)
  /// ve öğrenciye kopyalanan dosyanın adı bundan üretilir. İkisi de eskiden
  /// yalnızca öğrenciye göre adlandırılıyordu: kulüp aynı etkinliğe ikinci bir
  /// belge yüklediğinde birincinin kaydını da dosyasını da eziyordu — öğrencide
  /// her zaman tek belge kalıyor, ilk belgenin adresi de geçersizleşiyordu.
  ///
  /// Anahtar belgeye bağlı olduğu için AYNI belgenin yeniden dağıtımı hâlâ
  /// mevcut kaydın üstüne yazar, kopya oluşturmaz.
  String get key {
    if (uploadedAtMs > 0) return '$uploadedAtMs';

    // Diziden önce (web tarafında) yazılmış kayıtlarda zaman damgası yok;
    // yolun dosya adı, o da yoksa adresin özeti ayırt edici olarak yeter.
    final String named = path.isNotEmpty ? path.split('/').last : '';
    final String cleaned = named.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (cleaned.isNotEmpty) return cleaned;

    return 'belge${url.hashCode.toUnsigned(32)}';
  }

  /// Aynı belgenin dağıtım damgası tazelenmiş kopyası.
  EventDocument copyWithDistribution({
    required int distributedAtMs,
    required int distributedCount,
  }) => EventDocument(
    url: url,
    name: name,
    path: path,
    contentType: contentType,
    uploadedAtMs: uploadedAtMs,
    distributedAtMs: distributedAtMs,
    distributedCount: distributedCount,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'url': url,
    'name': name,
    'path': path,
    'contentType': contentType,
    'uploadedAtMs': uploadedAtMs,
    'distributedAtMs': distributedAtMs,
    'distributedCount': distributedCount,
  };
}

/// `event_registrations/{eventId}_{studentId}` — doküman kimliği
/// deterministiktir (firestore.rules bunu zorunlu kılar).
class EventRegistration {
  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.eventImageUrl,
    required this.deadlineAtMs,
    required this.clubId,
    required this.clubName,
    required this.studentId,
    required this.studentEmail,
    required this.studentFirstName,
    required this.studentLastName,
    required this.studentName,
    required this.studentPhone,
    required this.studentUniversity,
    required this.studentDepartment,
    required this.studentClassYear,
    required this.studentCity,
    required this.registeredAtMs,
    required this.checkedInAtMs,
    required this.checkedInByClubId,
    required this.sessionsAttended,
    required this.lastAttendedSession,
    required this.lastSessionCheckInAtMs,
    this.studentConsentLog,
    this.checkedInVia = '',
    this.ticketCode = '',
    this.attendanceFlags = const <String>[],
    this.attendanceVerified = const <String, int>{},
    this.studentPhotoUrl = '',
    this.paymentStatus = '',
    this.paymentMarkedAtMs = 0,
  });

  factory EventRegistration.fromMap(String id, Map<String, dynamic> data) {
    return EventRegistration(
      id: id,
      eventId: asString(data['eventId']),
      eventTitle: asString(data['eventTitle']),
      eventImageUrl: asString(data['eventImageUrl']),
      deadlineAtMs: asInt(data['deadlineAtMs']) ?? 0,
      clubId: asString(data['clubId']),
      clubName: asString(data['clubName']),
      studentPhotoUrl: asString(data['studentPhotoUrl']),
      studentId: asString(data['studentId']),
      studentEmail: asString(data['studentEmail']),
      studentFirstName: asString(data['studentFirstName']),
      studentLastName: asString(data['studentLastName']),
      studentName: asString(data['studentName']),
      studentPhone: asString(data['studentPhone']),
      studentUniversity: asString(data['studentUniversity']),
      studentDepartment: asString(data['studentDepartment']),
      studentClassYear: asString(data['studentClassYear']),
      studentCity: asString(data['studentCity']),
      registeredAtMs: asInt(data['registeredAtMs']) ?? 0,
      checkedInAtMs: asInt(data['checkedInAtMs']),
      checkedInByClubId: asString(data['checkedInByClubId']),
      sessionsAttended: asInt(data['sessionsAttended']) ?? 0,
      lastAttendedSession: asInt(data['lastAttendedSession']) ?? 0,
      lastSessionCheckInAtMs: asInt(data['lastSessionCheckInAtMs']),
      // Ücretli etkinlikte öğrencinin kabul ettiği metnin logu kaydın
      // kendisinde tutulur (bkz. RegistrationService).
      studentConsentLog: PaidEventConsentLog.fromMap(
        data,
        role: PaidEventConsentRole.student,
      ),
      checkedInVia: asString(data['checkedInVia']),
      // İP-K: ödeme durumu (yalnızca sunucu yazar). Alan yoksa (eski kayıt)
      // onaylı sayılır; bkz. [paymentPendingFor].
      paymentStatus: asString(data['paymentStatus']),
      paymentMarkedAtMs: asInt(data['paymentMarkedAtMs']) ?? 0,
      // İP-Y: aşağıdakileri yalnızca sunucu yazar (functions/attendance.js).
      ticketCode: asString(data['ticketCode']),
      attendanceFlags: data['attendanceFlags'] is List
          ? (data['attendanceFlags'] as List<dynamic>).whereType<String>().toList()
          : const <String>[],
      attendanceVerified: data['attendanceVerified'] is Map
          ? <String, int>{
              for (final MapEntry<dynamic, dynamic> e
                  in (data['attendanceVerified'] as Map<dynamic, dynamic>).entries)
                if (e.key is String && e.value is num) e.key as String: (e.value as num).toInt(),
            }
          : const <String, int>{},
    );
  }

  static EventRegistration? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => doc.exists ? EventRegistration.fromMap(doc.id, doc.data()!) : null;

  final String id;

  /// İP-K: '' (eski kayıt, onaylı sayılır) | 'pending' | 'paid'.
  final String paymentStatus;
  final int paymentMarkedAtMs;

  /// Ücretli etkinlikte ödemesi onaylanmamış mı? (registrations.js ile aynı)
  bool paymentPendingFor(AppEvent? event) =>
      (event?.isPaid ?? false) && paymentStatus == 'pending';

  final String eventId;
  final String eventTitle;
  final String eventImageUrl;
  final int deadlineAtMs;
  final String clubId;
  final String clubName;
  final String studentId;
  final String studentEmail;
  final String studentFirstName;
  final String studentLastName;
  final String studentName;
  final String studentPhone;
  final String studentUniversity;
  final String studentDepartment;
  final String studentClassYear;
  final String studentCity;
  final int registeredAtMs;
  final int? checkedInAtMs;
  final String checkedInByClubId;
  final int sessionsAttended;
  final int lastAttendedSession;
  final int? lastSessionCheckInAtMs;

  /// Ücretli etkinlikte öğrencinin onay logu; yoksa `null`.
  final PaidEventConsentLog? studentConsentLog;

  /// Öğrencinin kendi kapı QR'ı ile girişinde `self-qr`.
  final String checkedInVia;

  /// Sunucunun ürettiği bilet kodu (İP-Y); kapıda kayıtla karşılaştırılır.
  final String ticketCode;

  /// Kayıt anındaki profil fotoğrafı (web yazar); kapı kartında gösterilir.
  final String studentPhotoUrl;

  /// Sunucunun koyduğu şüphe işaretleri: `door:edge`, `session:2:low-accuracy`.
  final List<String> attendanceFlags;

  /// Sunucudan geçen adımlar: `door`, `s1`, `s2` ... → zaman (ms).
  final Map<String, int> attendanceVerified;

  bool get isCheckedIn => checkedInAtMs != null && checkedInAtMs! > 0;

  /// club-events.js#getStudentName ile aynı sıra.
  String get displayName {
    if (studentName.isNotEmpty) return studentName;
    final String full = '$studentFirstName $studentLastName'.trim();
    if (full.isNotEmpty) return full;
    if (studentEmail.isNotEmpty) return studentEmail.split('@').first;
    return 'Öğrenci';
  }
}

/// `student_certificates/{eventId}_{studentId}`
class StudentCertificate {
  const StudentCertificate({
    required this.id,
    required this.studentId,
    required this.eventId,
    required this.eventTitle,
    required this.clubId,
    required this.clubName,
    required this.fileUrl,
    required this.filePath,
    required this.fileName,
    required this.contentType,
    required this.personalized,
    required this.issuedAtMs,
  });

  factory StudentCertificate.fromMap(String id, Map<String, dynamic> data) {
    return StudentCertificate(
      id: id,
      studentId: asString(data['studentId']),
      eventId: asString(data['eventId']),
      eventTitle: asString(data['eventTitle']),
      clubId: asString(data['clubId']),
      clubName: asString(data['clubName']),
      fileUrl: asString(data['fileUrl']),
      filePath: asString(data['filePath']),
      fileName: asString(data['fileName']),
      contentType: asString(data['contentType']),
      personalized: data['personalized'] == true,
      issuedAtMs: asInt(data['issuedAtMs']) ?? 0,
    );
  }

  final String id;
  final String studentId;
  final String eventId;
  final String eventTitle;
  final String clubId;
  final String clubName;
  final String fileUrl;
  final String filePath;
  final String fileName;
  final String contentType;
  final bool personalized;
  final int issuedAtMs;
}

Map<String, bool> _readBoolMap(Object? raw) {
  if (raw is! Map) return const <String, bool>{};
  return <String, bool>{
    for (final MapEntry<Object?, Object?> e in raw.entries)
      if (e.value is bool) '${e.key}': e.value! as bool,
  };
}

Map<String, int> _readIntMap(Object? raw) {
  if (raw is! Map) return const <String, int>{};
  return <String, int>{
    for (final MapEntry<Object?, Object?> e in raw.entries)
      if (e.value is num) '${e.key}': (e.value! as num).toInt(),
  };
}
