import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_log.dart';
import '../domain/registration_capacity.dart';
import '../models/event.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';

/// Etkinlik, kayıt ve sertifika okuma/yazma işlemleri.
///
/// Web'deki `getDocs` çağrıları tek seferlik `Future`'a, `onSnapshot`
/// dinleyicileri `Stream`'e karşılık gelir.
class EventRepository {
  const EventRepository();

  // ── Etkinlikler ─────────────────────────────────────────────────────

  /// dashboard.js#loadStudentVisibleEvents: tüm etkinlikler çekilip
  /// görünürlük filtresi **istemcide** uygulanır.
  ///
  /// NOT: Bu, web'in yaptığı iş yükünün birebir kopyası. Etkinlik sayısı
  /// arttığında sunucu tarafı filtre (targetScope + deadlineAtMs üzerinde
  /// bileşik index) gerekecek; şimdilik davranış eşitliği korundu.
  Future<List<AppEvent>> fetchAllEvents() async {
    final QSnap snap = await eventsCol.get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              AppEvent.fromMap(d.id, d.data()),
        )
        .toList();
  }

  Stream<List<AppEvent>> watchClubEvents(String clubId) => eventsCol
      .where('clubId', isEqualTo: clubId)
      .snapshots()
      .map(
        (QSnap snap) => snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  AppEvent.fromMap(d.id, d.data()),
            )
            .toList(),
      );

  Stream<AppEvent?> watchEvent(String eventId) =>
      eventDoc(eventId).snapshots().map(AppEvent.fromDoc);

  Future<AppEvent?> fetchEvent(String eventId) async =>
      AppEvent.fromDoc(await eventDoc(eventId).get());

  /// Sunucudan taze okuma (dashboard.js kayıt öncesi `getDocFromServer`
  /// kullanıyordu — önbellekteki eski "kayıt açık" durumuna güvenmemek için).
  Future<AppEvent?> fetchEventFromServer(String eventId) async =>
      AppEvent.fromDoc(
        await eventDoc(eventId).get(const GetOptions(source: Source.server)),
      );

  // ── Kayıtlar ────────────────────────────────────────────────────────

  Stream<List<EventRegistration>> watchStudentRegistrations(String studentId) =>
      registrationsCol
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map(_mapRegistrations);

  Stream<List<EventRegistration>> watchEventRegistrations(String eventId) =>
      registrationsCol
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .map(_mapRegistrations);

  Future<List<EventRegistration>> fetchEventRegistrations(
    String eventId,
  ) async => _mapRegistrations(
    await registrationsCol.where('eventId', isEqualTo: eventId).get(),
  );

  List<EventRegistration> _mapRegistrations(QSnap snap) => snap.docs
      .map(
        (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            EventRegistration.fromMap(d.id, d.data()),
      )
      .toList();

  Future<EventRegistration?> fetchRegistration(
    String eventId,
    String studentId,
  ) async => EventRegistration.fromDoc(
    await registrationDoc(eventId, studentId).get(),
  );

  /// dashboard.js#registerToSelectedEvent yükü.
  /// Etkinlik verisi kaydın içine kopyalanır (denormalizasyon): kulüp
  /// etkinliği silse bile öğrenci geçmişinde başlık/görsel görünür kalır.
  Future<void> registerToEvent({
    required AppEvent event,
    required String studentId,
    required String studentEmail,
    required StudentProfile? profile,
    required String displayName,
    required String eventFallbackTitle,
    required String clubFallbackName,
  }) async {
    final Doc ref = registrationDoc(event.id, studentId);

    await ref.set(<String, dynamic>{
      'registrationId': ref.id,
      'eventId': event.id,
      'eventTitle': event.title.isNotEmpty ? event.title : eventFallbackTitle,
      'eventImageUrl': event.imageUrl,
      'deadlineAtMs': event.deadlineAtMs,
      'clubId': event.clubId,
      'clubName': event.clubName.isNotEmpty ? event.clubName : clubFallbackName,
      'studentId': studentId,
      'studentEmail': studentEmail,
      'studentFirstName': profile?.firstName ?? '',
      'studentLastName': profile?.lastName ?? '',
      'studentName': displayName,
      'studentPhone': profile?.phone ?? '',
      'studentUniversity': profile?.university ?? '',
      'studentDepartment': profile?.department ?? '',
      'studentClassYear': profile?.classYear ?? '',
      'studentCity': profile?.city ?? '',
      'registeredAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregisterFromEvent(String eventId, String studentId) =>
      registrationDoc(eventId, studentId).delete();

  /// Profil değişince kayıttaki **kopya öğrenci alanlarını** tazeler.
  ///
  /// Kayıt dokümanı, kulübün gördüğü tek öğrenci kaynağıdır: katılımcı
  /// listesi, Excel dışa aktarımı ve belgeye işlenen isim hep buradan okunur
  /// (firestore.rules kulübe `student_profiles` okuma izni vermez). Bu alanlar
  /// kayıt anında bir kez kopyalanıp bir daha güncellenmediği için öğrenci
  /// adını/bölümünü değiştirdiğinde kulüp eski bilgiyi görüyordu.
  ///
  /// Yazım **en iyi çaba** ve kayıt kayıt yapılır (toplu `WriteBatch` değil):
  /// tek bir kaydın kuralca reddedilmesi (bkz.
  /// `docs/kayit-profil-senkronu.md`) diğerlerini de geri almasın, çağıran
  /// akış (profil kaydetme) hiçbir durumda hata vermesin.
  ///
  /// Güncellenen kayıt sayısını döndürür.
  Future<int> syncStudentInfoOnRegistrations({
    required String studentId,
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
    required String university,
    required String department,
    required String classYear,
    String email = '',
  }) async {
    final QSnap snap = await registrationsCol
        .where('studentId', isEqualTo: studentId)
        .get();

    if (snap.docs.isEmpty) return 0;

    final String fullName = '$firstName $lastName'.trim();

    final Map<String, dynamic> payload = <String, dynamic>{
      'studentFirstName': firstName,
      'studentLastName': lastName,
      'studentPhone': phone,
      'studentCity': city,
      'studentUniversity': university,
      'studentDepartment': department,
      'studentClassYear': classYear,
      'updatedAt': FieldValue.serverTimestamp(),
      // `eventId`/`studentId` yeniden yazılır: firestore.rules güncellemede
      // BİRLEŞMİŞ belgeye bakar ve bu iki alanın tutarlılığını şart koşar.
      'studentId': studentId,
    };

    // Boş isim kaydı bozmasın: ad/soyad silinmişse eski görünen ad korunur.
    if (fullName.isNotEmpty) payload['studentName'] = fullName;
    if (email.trim().isNotEmpty) payload['studentEmail'] = email.trim();

    int updated = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      try {
        await doc.reference.update(<String, dynamic>{
          ...payload,
          'eventId': asString(doc.data()['eventId']),
        });
        updated += 1;
      } catch (_) {
        // Kural reddi / çevrimdışı: kalan kayıtlar denenmeye devam eder.
      }
    }
    return updated;
  }

  /// Kulübün QR okutmasıyla giriş onayı
  /// (club-qr-checkin.js / club-events.js#processScannedQrToken).
  ///
  /// `checkedInAtMs` yalnızca ilk girişte yazılır; sonraki oturumlar
  /// `lastSessionCheckInAtMs` alanını günceller.
  Future<void> markCheckInByClub({
    required EventRegistration registration,
    required String clubId,
    required bool isMultiSession,
    required int currentSession,
  }) async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    final Map<String, dynamic> payload = <String, dynamic>{
      'checkedInAtMs': registration.checkedInAtMs ?? nowMs,
      'checkedInAt': FieldValue.serverTimestamp(),
      'checkedInByClubId': clubId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isMultiSession) {
      payload['sessionsAttended'] = registration.sessionsAttended + 1;
      payload['lastSessionCheckInAtMs'] = nowMs;
      payload['lastAttendedSession'] = currentSession;
    }

    await registrationsCol.doc(registration.id).update(payload);
  }

  /// Öğrencinin, kulübün ekrana bastığı oturum QR'ını okutmasıyla giriş
  /// (student-qr-checkin.js). `checkedInByClubId` bu yoldan YAZILMAZ —
  /// firestore.rules kulüp doğrulaması ile öğrencinin kendi bildirimini
  /// bu alana bakarak ayırt eder.
  Future<void> markOwnSessionCheckIn({
    required String eventId,
    required String studentId,
    required EventRegistration registration,
    required int currentSession,
  }) async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    await registrationDoc(eventId, studentId).update(<String, dynamic>{
      'checkedInAtMs': registration.checkedInAtMs ?? nowMs,
      'checkedInAt': FieldValue.serverTimestamp(),
      'sessionsAttended': registration.sessionsAttended + 1,
      'lastSessionCheckInAtMs': nowMs,
      'lastAttendedSession': currentSession,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Oturum yönetimi (kulüp) ─────────────────────────────────────────

  Future<void> advanceSession(String eventId, int nextSession) =>
      eventDoc(eventId).update(<String, dynamic>{
        'currentSession': nextSession,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> finishSessions(String eventId) =>
      eventDoc(eventId).update(<String, dynamic>{
        'sessionsCompleted': true,
        'sessionsCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Bitirilmiş oturumları yeniden açar.
  ///
  /// `currentSession` bilerek korunur: kulüp son oturumun QR'ını tekrar
  /// gösterip eksik yoklamaları tamamlayabilsin. Kapanış damgası temizlenir,
  /// yerine yeniden açılış damgası yazılır (kayıtlarda olduğu gibi).
  Future<void> reopenSessions(String eventId) =>
      eventDoc(eventId).update(<String, dynamic>{
        'sessionsCompleted': false,
        'sessionsCompletedAt': null,
        'sessionsReopenedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Kayıtları durdurur ya da yeniden başlatır (kulübün ELLE yaptığı işlem).
  ///
  /// Yeniden açılırken eski kapanış damgası temizlenir; aksi hâlde "ne zaman
  /// kapandı" bilgisi yanlış kalırdı (club-events.js ile aynı davranış).
  ///
  /// Sebep `manual` yazılır: kontenjan takibi (bkz. [syncRegistrationStateWithQuota])
  /// yalnızca kendi kapattığı etkinliği geri açar, kulübün kararını bozmaz.
  Future<void> setRegistrationsClosed(String eventId, bool closed) =>
      eventDoc(eventId).update(<String, dynamic>{
        'registrationClosed': closed,
        'registrationClosedAt': closed ? FieldValue.serverTimestamp() : null,
        'registrationReopenedAt': closed ? null : FieldValue.serverTimestamp(),
        'registrationClosedReason': closed ? ClosedReason.manual : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Kontenjan doluluğu ──────────────────────────────────────────────

  /// Etkinliğin doluluk durumu — parça sayaçlarından toplanır (canlı).
  ///
  /// Doluluk etkinlik dokümanında tek sayı olarak TUTULMUYOR: o sayıyı yazan
  /// doküman kontenjanın darboğazı hâline gelirdi (bkz.
  /// `docs/kayit-kapasitesi.md` §1.3). Parça sayısı en çok 32 olduğu için
  /// toplamayı okurken yapmak ucuz.
  Stream<QuotaStatus> watchQuotaStatus(String eventId) =>
      quotaShardsCol(eventId).snapshots().map(_readQuotaStatus);

  Future<QuotaStatus> fetchQuotaStatus(String eventId) async =>
      _readQuotaStatus(await quotaShardsCol(eventId).get());

  QuotaStatus _readQuotaStatus(QSnap snap) {
    int used = 0;
    int capacity = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      used += asInt(doc.data()['count']) ?? 0;
      capacity += asInt(doc.data()['capacity']) ?? 0;
    }
    return QuotaStatus(
      used: used,
      capacity: capacity,
      shardsFound: snap.docs.length,
    );
  }

  /// Kontenjan dolunca etkinliği **beklemeye alır**, yer açılınca geri açar.
  ///
  /// Neden öğrenci değil de kulüp tarafı yazıyor: `firestore.rules` etkinlik
  /// dokümanını yalnızca sahibi kulübe açık tutuyor. Öğrenciye o izni vermek
  /// için kuralın "bütün parçalar dolu mu" diye bakması gerekirdi; kurallarda
  /// tek istekte en çok 10 doküman okunabildiği için 16-32 parçada bu mümkün
  /// değil. Kontenjanın kendisi zaten parça sayaçlarıyla korunuyor — bu bayrak
  /// yalnızca **görünürlük** için: kulüp listesinde etkinlik "beklemede"
  /// görünsün, öğrencinin keşif listesinden düşsün.
  ///
  /// Değişiklik yapıldıysa `true` döner.
  Future<bool> syncRegistrationStateWithQuota({
    required AppEvent event,
    required QuotaStatus status,
  }) async {
    final QuotaGateAction action = quotaGateAction(
      status: status,
      registrationClosed: event.registrationClosed,
      closedReason: event.registrationClosedReason,
    );

    if (action == QuotaGateAction.pause) {
      await eventDoc(event.id).update(<String, dynamic>{
        'registrationClosed': true,
        'registrationClosedAt': FieldValue.serverTimestamp(),
        'registrationClosedReason': ClosedReason.quotaFull,
        'registrationReopenedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLog.info('event.autoClosed', <String, Object?>{
        'eventId': event.id,
        'used': status.used,
        'capacity': status.capacity,
      });
      return true;
    }

    // Yer açıldı (iptal ya da kontenjan artışı) → geri aç.
    // Kulüp ELLE kapattıysa `quotaGateAction` bunu döndürmez.
    if (action == QuotaGateAction.resume) {
      await eventDoc(event.id).update(<String, dynamic>{
        'registrationClosed': false,
        'registrationClosedAt': null,
        'registrationClosedReason': null,
        'registrationReopenedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLog.info('event.autoReopened', <String, Object?>{
        'eventId': event.id,
        'remaining': status.remaining,
      });
      return true;
    }

    return false;
  }

  Future<void> closeRegistrations(String eventId) =>
      setRegistrationsClosed(eventId, true);

  /// Geçmiş etkinliği yalnızca kulüp listesinden gizler (silmez).
  Future<void> hideFromClubList(String eventId) =>
      eventDoc(eventId).update(<String, dynamic>{
        'hiddenFromClubList': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteEvent(String eventId) => eventDoc(eventId).delete();

  // ── Sertifikalar ────────────────────────────────────────────────────

  Stream<List<StudentCertificate>> watchStudentCertificates(String studentId) =>
      certificatesCol.where('studentId', isEqualTo: studentId).snapshots().map((
        QSnap snap,
      ) {
        final List<StudentCertificate> list = snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  StudentCertificate.fromMap(d.id, d.data()),
            )
            .toList();
        // Yeni yüklenen belgeler önce.
        list.sort(
          (StudentCertificate a, StudentCertificate b) =>
              b.issuedAtMs.compareTo(a.issuedAtMs),
        );
        return list;
      });

  Future<void> deleteCertificate(String certificateId) =>
      certificatesCol.doc(certificateId).delete();

  /// Bir öğrenciye belge kaydı yazar.
  ///
  /// Doküman kimliği deterministiktir (`{eventId}_{studentId}`): aynı öğrenciye
  /// ikinci kez dağıtım yapılırsa kopya oluşmaz, mevcut kayıt güncellenir
  /// (club-events.js#distributeCertificates ile aynı desen).
  Future<void> issueCertificate({
    required String eventId,
    required String studentId,
    required String eventTitle,
    required String clubId,
    required String clubName,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required String contentType,
    required bool personalized,
  }) => certificatesCol.doc('${eventId}_$studentId').set(<String, dynamic>{
    'studentId': studentId,
    'eventId': eventId,
    'eventTitle': eventTitle,
    'clubId': clubId,
    'clubName': clubName,
    'fileUrl': fileUrl,
    'filePath': filePath,
    'fileName': fileName,
    'contentType': contentType,
    'personalized': personalized,
    'issuedAt': FieldValue.serverTimestamp(),
    'issuedAtMs': DateTime.now().millisecondsSinceEpoch,
  }, SetOptions(merge: true));

  /// Belge listesinin tamamını taşıyan yazma yükü.
  ///
  /// `arrayUnion/arrayRemove` yerine tam liste yazılıyor: silme sırasında
  /// `arrayRemove` haritanın **birebir** aynı olmasını ister ve Firestore'dan
  /// okunan sayı türleri (int/double) yazdığımızla her zaman eşleşmiyor —
  /// belge listede kalıyordu.
  ///
  /// Tek şablon alanları da tazeleniyor: web istemcisi çoklu listeyi bilmiyor,
  /// "son yüklenen belge" bilgisini oradan okuyor.
  Map<String, dynamic> _certificateDocumentsPayload(
    List<EventDocument> documents,
  ) {
    final EventDocument? latest = documents.isEmpty ? null : documents.last;

    return <String, dynamic>{
      'certificateDocuments': documents
          .map((EventDocument doc) => doc.toMap())
          .toList(),
      'certificateTemplateUrl': latest?.url ?? '',
      'certificateTemplateName': latest?.name ?? '',
      'certificateTemplatePath': latest?.path ?? '',
      'certificateTemplateType': latest?.contentType ?? '',
      'certificateUploadedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Belge listesini **o anki sunucu hâlinin** üstüne yazar.
  ///
  /// Liste bir dizi olduğu için her ekleme/silme "oku-değiştir-yaz"dır ve
  /// ekrandaki `AppEvent` her zaman taze değildir: dosya seçici açıkken (ya da
  /// yükleme sürerken) liste değişmiş olabilir. Elde tutulan eski kopyanın
  /// üzerine yazmak, silinen bir belgeyi listeye geri getiriyordu — hem de
  /// Storage nesnesi artık silinmiş olduğu için AÇILMAYAN bir kayıt olarak.
  /// İşlem (transaction) içinde okuyup yazmak bu ihtimali tümden kaldırır.
  Future<void> _mutateCertificateDocuments(
    String eventId,
    List<EventDocument> Function(List<EventDocument> current) change,
  ) => fbDb.runTransaction((Transaction tx) async {
    final Doc ref = eventDoc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
    if (!snap.exists) return;

    final AppEvent current = AppEvent.fromMap(snap.id, snap.data()!);
    tx.update(
      ref,
      _certificateDocumentsPayload(change(current.certificateDocuments)),
    );
  });

  /// Yeni yüklenen belgeyi listenin sonuna ekler.
  Future<void> addCertificateDocument(String eventId, EventDocument document) =>
      _mutateCertificateDocuments(
        eventId,
        (List<EventDocument> current) => <EventDocument>[...current, document],
      );

  /// Belgeyi listeden çıkarır (Storage nesnesini çağıran siler).
  Future<void> removeCertificateDocument(
    String eventId,
    EventDocument document,
  ) => _mutateCertificateDocuments(
    eventId,
    (List<EventDocument> current) => current
        .where((EventDocument item) => item.url != document.url)
        .toList(),
  );

  /// Belgenin dağıtım damgasını tazeler.
  ///
  /// "Kaç kişiye gitti" bilgisi olmadan bir belgenin hiç dağıtılmadığı
  /// anlaşılamıyordu; otomatik dağıtım da hak sahibi sayısının bu değeri
  /// geçip geçmediğine bakar.
  Future<void> markCertificateDocumentDistributed(
    String eventId,
    EventDocument document,
    int distributedCount,
  ) => _mutateCertificateDocuments(
    eventId,
    (List<EventDocument> current) => current
        .map(
          (EventDocument item) => item.url == document.url
              ? item.copyWithDistribution(
                  distributedAtMs: DateTime.now().millisecondsSinceEpoch,
                  distributedCount: distributedCount,
                )
              : item,
        )
        .toList(),
  );

  // ── Etkinlik oluşturma / düzenleme (kulüp) ──────────────────────────

  /// club-create-event.js#saveEvent yükü.
  ///
  /// [draft] yalnızca formun doldurduğu alanları taşır; kulüp kimliği ve
  /// başlangıç durumu (kayıt açık, gizli değil) yalnızca OLUŞTURMA sırasında
  /// yazılır — düzenlemede bunlara dokunulmaz, aksi hâlde kulüp bir etkinliği
  /// düzenlediğinde durdurulmuş kayıtlar kendiliğinden yeniden açılırdı.
  Future<String> createEvent({
    required EventDraft draft,
    required String clubId,
    required ClubProfile? club,
    required String clubFallbackName,
  }) async {
    // Kimlik önceden alınır (yazma yapmadan): etkinlik dokümanı ile kontenjan
    // parçaları TEK toplu yazımda, atomik olarak oluşsun. Ayrı ayrı yazılsaydı
    // arada kalan anda etkinlik "parçalı" görünüp parçaları bulunmayacak,
    // kaydolmaya çalışan herkes "kontenjan doldu" cevabını alacaktı.
    final Doc ref = eventsCol.doc();

    final int shards = quotaShardCount(draft.quota);
    final List<int> capacities = shardCapacities(draft.quota, shards);

    final WriteBatch batch = fbDb.batch();
    batch.set(ref, <String, dynamic>{
          ...draft.toMap(),
          'clubId': clubId,
          'clubName': (club?.clubName ?? '').isNotEmpty
              ? club!.clubName
              : clubFallbackName,
          'clubUniversity': club?.university ?? '',
          // Logo etkinliğin içine kopyalanır: öğrenci `club_profiles`
          // dokümanlarını okuyamıyor, kulüp kimliği yalnızca buradan gelir.
          'clubLogoUrl': club?.logoUrl ?? '',
          // İletişim bilgileri de kopyalanır: ücretli etkinliklerde öğrenci
          // ücreti kulüple konuşarak ödüyor ve `club_profiles` dokümanını
          // okuma yetkisi yok.
          'clubPhone': club?.phone ?? '',
          'clubEmail': club?.email ?? '',
          'clubField': club?.clubField ?? '',
          'clubFields': club?.clubFields ?? const <String>[],
          'registrationClosed': false,
          'hiddenFromClubList': false,
          'hiddenGlobally': false,
          'currentSession': 0,
          'sessionsCompleted': false,
          'quotaShardCount': shards,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        });

    for (int shard = 0; shard < shards; shard++) {
      batch.set(quotaShardDoc(ref.id, shard), <String, dynamic>{
        'count': 0,
        'capacity': capacities[shard],
      });
    }

    await batch.commit();

    AppLog.info('event.created', <String, Object?>{
      'eventId': ref.id,
      'quota': draft.quota,
      'shards': shards,
    });

    return ref.id;
  }

  /// Etkinliği günceller ve kontenjan değiştiyse parçaları yeniden dengeler.
  Future<void> updateEvent(String eventId, EventDraft draft) async {
    await eventDoc(eventId).update(draft.toMap());
    await syncQuotaShards(eventId: eventId, quota: draft.quota);
  }

  /// Kontenjan parçalarını [quota] ile uyumlu hâle getirir.
  ///
  /// Üç işi birden görür:
  ///   • **Geri dolum**: bu alan eklenmeden önce oluşturulmuş etkinliklerde
  ///     parça yoktur; ilk çağrıda kurulur ve o ana kadar yapılmış kayıtlar
  ///     sayaca işlenir (yoksa kontenjan sıfırdan sayılıp aşılırdı).
  ///   • **Kontenjan değişimi**: kulüp kontenjanı büyütüp küçülttüğünde
  ///     kapasiteler yeniden dağıtılır.
  ///   • **Onarım**: sayaçlar gerçek kayıt sayısıyla yeniden hizalanır.
  ///
  /// Kapasite hiçbir parçada o parçadaki kayıt sayısının altına indirilmez:
  /// kontenjan, kayıtlı kişi sayısının altına çekilse bile kimsenin kaydı
  /// geçersizleşmez, yalnızca yeni kayıt alınmaz.
  Future<void> syncQuotaShards({
    required String eventId,
    required int quota,
  }) async {
    final int shards = quotaShardCount(quota);

    if (shards <= 0) {
      // Kontenjansız etkinliğe geçildi: parçalar anlamını yitirir.
      await eventDoc(eventId).update(<String, dynamic>{'quotaShardCount': 0});
      return;
    }

    final QSnap existing = await quotaShardsCol(eventId).get();

    // Her parçada kaç kayıt var? Parçalar yoksa (geri dolum) mevcut kayıtlar
    // sayılıp parçalara dağıtılır.
    final List<int> used = List<int>.filled(shards, 0);

    if (existing.docs.isEmpty) {
      final int already = await _countRegistrations(eventId);
      final int base = already ~/ shards;
      final int extra = already % shards;
      for (int s = 0; s < shards; s++) {
        used[s] = base + (s < extra ? 1 : 0);
      }
    } else {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in existing.docs) {
        final int? index = int.tryParse(doc.id);
        if (index == null) continue;
        final int count = asInt(doc.data()['count']) ?? 0;
        // Parça sayısı değiştiyse eski parçaların yükü modüler olarak taşınır.
        used[index % shards] += count;
      }
    }

    final int totalUsed = used.fold<int>(0, (int a, int b) => a + b);

    // Kayıtlı kişiyi geri alamayız: hedef, kontenjanla kullanılanın büyüğü.
    final int target = quota > totalUsed ? quota : totalUsed;
    final int free = target - totalUsed;
    final int freeBase = free ~/ shards;
    final int freeExtra = free % shards;

    final WriteBatch batch = fbDb.batch();
    for (int s = 0; s < shards; s++) {
      batch.set(quotaShardDoc(eventId, s), <String, dynamic>{
        'count': used[s],
        'capacity': used[s] + freeBase + (s < freeExtra ? 1 : 0),
      });
    }

    // Fazla parçalar (kontenjan küçüldüyse) silinir — yükleri yukarıda
    // kalan parçalara taşındı.
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in existing.docs) {
      final int? index = int.tryParse(doc.id);
      if (index != null && index >= shards) batch.delete(doc.reference);
    }

    batch.update(eventDoc(eventId), <String, dynamic>{
      'quotaShardCount': shards,
    });

    await batch.commit();

    AppLog.info('event.quotaShardsSynced', <String, Object?>{
      'eventId': eventId,
      'quota': quota,
      'shards': shards,
      'used': totalUsed,
    });
  }

  Future<int> _countRegistrations(String eventId) async {
    final AggregateQuerySnapshot snap = await registrationsCol
        .where('eventId', isEqualTo: eventId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Kulüp logosunu kulübün TÜM etkinliklerine işler.
  ///
  /// Logo etkinlik dokümanına kayıt anında kopyalanıyor (öğrenci kulüp
  /// profilini okuyamıyor); kulüp logosunu sonradan değiştirdiğinde eski
  /// etkinliklerin rozeti eski logoda kalmasın diye hesap ekranındaki yükleme
  /// bunu çağırır.
  ///
  /// Yalnızca `clubLogoUrl` yazılır — kapak görseline dokunulmaz.
  Future<void> syncClubLogo({
    required String clubId,
    required String logoUrl,
  }) async {
    await _syncClubFields(clubId, <String, dynamic>{'clubLogoUrl': logoUrl});
  }

  /// Kulübün iletişim bilgilerini TÜM etkinliklerine işler.
  ///
  /// Logo ile aynı gerekçe (bkz. [syncClubLogo]): bilgiler etkinlik
  /// dokümanına kopyalanıyor, kulüp numarasını değiştirdiğinde ücretli
  /// etkinliklerin penceresinde eski numara kalmasın diye profil kaydı
  /// bunu çağırıyor. Alanları eklenmeden önce oluşturulmuş eski etkinlikler
  /// de ilk çağrıda dolar.
  Future<void> syncClubContact({
    required String clubId,
    required String phone,
    required String email,
  }) async {
    await _syncClubFields(clubId, <String, dynamic>{
      'clubPhone': phone,
      'clubEmail': email,
    });
  }

  /// Kulübün tüm etkinliklerine aynı alanları yazar.
  Future<void> _syncClubFields(
    String clubId,
    Map<String, dynamic> fields,
  ) async {
    final QSnap snap = await eventsCol.where('clubId', isEqualTo: clubId).get();
    if (snap.docs.isEmpty) return;

    // Firestore tek batch'te en fazla 500 yazım kabul eder.
    const int batchLimit = 400;
    for (int start = 0; start < snap.docs.length; start += batchLimit) {
      final WriteBatch batch = fbDb.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snap.docs.skip(start).take(batchLimit)) {
        batch.update(doc.reference, fields);
      }
      await batch.commit();
    }
  }
}

/// Etkinlik formunun ürettiği yük.
///
/// Modelden ayrı bir tip: `AppEvent` okunan dokümanı temsil eder ve kulüp
/// kimliği/durum alanlarını da içerir; taslak ise yalnızca formun yazdığı
/// alanları taşır, böylece düzenlemede yanlışlıkla durum sıfırlanamaz.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.description,
    required this.purpose,
    required this.feeType,
    required this.feeAmount,
    required this.feeInfo,
    required this.targetScope,
    required this.targetUniversities,
    required this.targetDepartments,
    required this.targetSector,
    required this.imageUrl,
    required this.quota,
    required this.deadlineAtMs,
    required this.eventDate,
    required this.eventDateAtMs,
    required this.eventStartTime,
    required this.eventEndTime,
    required this.eventStartAtMs,
    required this.eventEndAtMs,
    required this.sessionCount,
    required this.certificateThresholdPercent,
    required this.locationName,
    required this.locationLat,
    required this.locationLng,
    required this.locationRadius,
  });

  final String title;
  final String description;
  final String purpose;
  final String feeType;
  final int feeAmount;
  final String feeInfo;
  final String targetScope;

  /// Hedeflenen üniversiteler / bölümler. Tekil `targetUniversity` ve
  /// `targetDepartment` alanları web istemcisi için ilk elemandan yazılır.
  final List<String> targetUniversities;
  final List<String> targetDepartments;

  final String targetSector;
  final String imageUrl;
  final int quota;
  final int deadlineAtMs;
  final String eventDate;
  final int? eventDateAtMs;
  final String eventStartTime;
  final String eventEndTime;
  final int? eventStartAtMs;
  final int? eventEndAtMs;
  final int sessionCount;
  final int? certificateThresholdPercent;
  final String locationName;
  final double? locationLat;
  final double? locationLng;
  final int? locationRadius;

  EventDraft copyWith({String? imageUrl}) => EventDraft(
    title: title,
    description: description,
    purpose: purpose,
    feeType: feeType,
    feeAmount: feeAmount,
    feeInfo: feeInfo,
    targetScope: targetScope,
    targetUniversities: targetUniversities,
    targetDepartments: targetDepartments,
    targetSector: targetSector,
    imageUrl: imageUrl ?? this.imageUrl,
    quota: quota,
    deadlineAtMs: deadlineAtMs,
    eventDate: eventDate,
    eventDateAtMs: eventDateAtMs,
    eventStartTime: eventStartTime,
    eventEndTime: eventEndTime,
    eventStartAtMs: eventStartAtMs,
    eventEndAtMs: eventEndAtMs,
    sessionCount: sessionCount,
    certificateThresholdPercent: certificateThresholdPercent,
    locationName: locationName,
    locationLat: locationLat,
    locationLng: locationLng,
    locationRadius: locationRadius,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'title': title,
    'description': description,
    'purpose': purpose,
    'feeType': feeType,
    'feeAmount': feeAmount,
    'feeInfo': feeInfo,
    'targetScope': targetScope,
    // Tekil alanlar web istemcisi (ve eski okuyucular) için korunur; çoklu
    // seçimin tamamı dizilerde durur.
    'targetUniversity': targetUniversities.isEmpty ? '' : targetUniversities.first,
    'targetUniversities': targetUniversities,
    'targetDepartment': targetDepartments.isEmpty ? '' : targetDepartments.first,
    'targetDepartments': targetDepartments,
    'targetSector': targetSector,
    'imageUrl': imageUrl,
    'quota': quota,
    'deadlineAtMs': deadlineAtMs,
    'eventDate': eventDate,
    'eventDateAtMs': eventDateAtMs,
    'eventStartTime': eventStartTime,
    'eventEndTime': eventEndTime,
    'eventStartAtMs': eventStartAtMs,
    'eventEndAtMs': eventEndAtMs,
    'sessionCount': sessionCount,
    'certificateThresholdPercent': certificateThresholdPercent,
    'locationName': locationName,
    'locationLat': locationLat,
    'locationLng': locationLng,
    // Konum adı girilmediyse yarıçapın anlamı yok.
    'locationRadius': locationName.isEmpty ? null : locationRadius,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
