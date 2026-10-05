import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/session_names.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../core/app_log.dart';
import '../domain/paid_event_consent.dart';
import '../domain/event_utils.dart';
import '../domain/registration_capacity.dart';
import '../models/event.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';
import 'registration_service.dart';

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

  Stream<List<AppEvent>> watchAllEvents() => eventsCol.snapshots().map(
    (QSnap snap) => snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              AppEvent.fromMap(doc.id, doc.data()),
        )
        .toList(),
  );

  /// QR, canlı giriş aşaması doğrulandıktan sonra yayınlanır.
  ///
  /// Etkinliğin konumu isteğe bağlıdır: koordinat yoksa öğrenci tarafında
  /// konum denetimi atlanır. Böylece konumsuz etkinliklerde de kapı ve oturum
  /// QR'ları, konumlu etkinliklerdeki aynı yayın/geçerlilik kurallarıyla
  /// çalışır.
  Future<AppEvent> publishSharedQr(String eventId, {int? session}) =>
      fbDb.runTransaction((Transaction tx) async {
        final Doc doc = eventDoc(eventId);
        final AppEvent? event = AppEvent.fromDoc(await tx.get(doc));
        if (event == null) throw StateError('scan.eventNotFound');
        if (session == null) {
          if (!event.hasDoorCheckin || !event.entryOpen) {
            throw StateError('scan.doorClosed');
          }
        } else if (!event.isMultiSession ||
            event.sessionsCompleted ||
            session < 1 ||
            session != event.currentSession) {
          throw StateError('scan.qrExpired');
        }
        tx.update(doc, <String, dynamic>{
          if (session == null) 'doorQrPublished': true,
          'sessionQrPublished': ?session,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return event;
      });

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

  /// İP-K: öğrencinin bekleme listesinde olduğu etkinlik kimlikleri (canlı).
  Stream<Set<String>> watchStudentWaitlist(String studentId) => waitlistCol
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map(
        (QSnap snap) => snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  asString(d.data()['eventId']),
            )
            .where((String id) => id.isNotEmpty)
            .toSet(),
      );

  /// İP-K: kulüp, kendi etkinliğinin bekleme listesi uzunluğu.
  Future<int> countEventWaitlist(String eventId) async {
    final AggregateQuerySnapshot snap = await waitlistCol
        .where('eventId', isEqualTo: eventId)
        .count()
        .get();
    return snap.count ?? 0;
  }

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
      // Kapı kartında gösterilir (web de kayıtta yazıyor).
      'studentPhotoUrl': profile?.photoUrl ?? '',
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

  /// Kulübün, öğrencinin **biletini** okutmasıyla yazılan kapı giriş damgası
  /// (club-qr-checkin.js#processQrToken).
  ///
  /// Yalnızca kapı damgası yazılır; oturum alanlarına dokunulmaz. "Check-in +
  /// Yoklama" modunda gün içindeki yoklama ayrı bir adımdır ve öğrencinin
  /// salondaki oturum QR'ını kendi telefonuyla okutmasıyla işler
  /// (bkz. [markOwnSessionCheckIn]). Görevlinin bilet okutması bir yoklama
  /// saymaz — yoksa aynı öğrenci hem kapıda hem salonda sayılırdı.
  ///
  /// `checkedInByClubId` bu yoldan yazılır: girişin kulüp doğrulamasıyla mı
  /// öğrencinin kendisi tarafından mı yapıldığı buradan ayırt edilir.
  Future<void> markCheckInByClub({
    required EventRegistration registration,
    required String clubId,
  }) => registrationsCol.doc(registration.id).update(<String, dynamic>{
    'checkedInAtMs': DateTime.now().millisecondsSinceEpoch,
    'checkedInAt': FieldValue.serverTimestamp(),
    'checkedInByClubId': clubId,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // İP-Y: öğrencinin kendi kapı girişi ve oturum yoklaması artık sunucuda
  // yazılıyor (AttendanceService.checkInWithQr → functions/attendance.js).
  // Buradaki doğrudan yazma yolları (markOwnSessionCheckIn /
  // markOwnDoorCheckin) kaldırıldı; kurallardaki eski yol aşama 2'de kapanır.

  /// Kapıyı açar/kapatır. Öğrenci verisine hiçbir aşamada dokunulmaz.
  ///
  /// `entryStartedAtMs` "Check-in'i Bitir" sonrasında "Yeniden Başlat"ta
  /// **korunur** (club-events.js#setEntryOpen ile aynı davranış): aşama
  /// "hiç başlamadı"ya dönmesin, okunan girişler kaybolmasın diye
  /// [alreadyStartedAtMs] geçirilir. Etkinliğin oturumları en başa kadar
  /// geri alındığında bu damga [advanceSession] tarafından sıfırlanır — o
  /// zaman kapı da gerçekten "hiç açılmamış" durumuna döner (bkz.
  /// `sessionRegistrationGateAction`).
  ///
  /// Kapı her AÇILDIĞINDA (yalnızca ilkinde değil) kayıtlar da kendiliğinden
  /// durdurulur: kulüp kapıyı bitirip kayıtları elle yeniden açmış olabilir
  /// (bkz. `_toggleRegistrations`), sonra kapıyı tekrar açtığında kayıt
  /// bayrağının açık kalması kulübün panelini gerçekle çelişir hâle
  /// getirirdi. Okuma tarafındaki asıl kapı zaten [eventHasStarted]'tır —
  /// bayrak, kulübün gördüğü durumun onunla aynı kalması için yazılır.
  /// Kulübün ELLE ya da kontenjan yüzünden zaten kapattığı bir kayda
  /// dokunulmaz (sebep korunur).
  Future<void> setEntryOpen(
    String eventId,
    bool open, {
    int alreadyStartedAtMs = 0,
    bool registrationClosed = false,
  }) {
    return fbDb.runTransaction((Transaction tx) async {
      final Doc doc = eventDoc(eventId);
      final AppEvent? live = AppEvent.fromDoc(await tx.get(doc));
      if (live == null) throw StateError('scan.eventNotFound');
      final bool firstOpen = open && live.entryStartedAtMs <= 0;
      tx.update(doc, <String, dynamic>{
        'entryOpen': open,
        'doorQrPublished': false,
        if (firstOpen)
          'entryStartedAtMs': DateTime.now().millisecondsSinceEpoch,
        // İP-2: "Check-in'i Bitir" anı (web club-events.js ile aynı). Yeniden
        // açılınca silinir; sertifika Gönder düğmesi bitirilene kadar kilitli.
        'entryFinishedAtMs': open
            ? null
            : DateTime.now().millisecondsSinceEpoch,
        'entryOpenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (open &&
            !live.registrationClosed &&
            !live.allowLateRegistration) ...<String, dynamic>{
          'registrationClosed': true,
          'registrationClosedAt': FieldValue.serverTimestamp(),
          'registrationClosedReason': ClosedReason.checkinStarted,
          'registrationReopenedAt': null,
        },
      });
    });
  }

  Future<void> setAllowSessionWithoutCheckin(String eventId, bool allow) =>
      eventDoc(eventId).update(<String, dynamic>{
        'allowSessionWithoutCheckin': allow,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Oturum yönetimi (kulüp) ─────────────────────────────────────────

  /// Etkinlik başlarken (0 -> 1) kayıtları kendiliğinden durdurur; en başa
  /// geri alınırken (-> 0) — yalnızca bu yüzden kapalıysa — kendiliğinden
  /// açar (bkz. [sessionRegistrationGateAction]). Kulübün elle kapattığı ya
  /// da kontenjan yüzünden kapanan bir etkinliğe dokunmaz.
  ///
  /// [nextSession] `<= 0` ise (kulüp oturumları tek tek en başa kadar geri
  /// aldı) kapı check-in'i de sıfırlanır: `entryOpen: false`,
  /// `entryStartedAtMs: 0`. Etkinlik böylece kulübün ekranında da gerçekten
  /// "hiç başlamamış" görünür — kapı aşaması [CheckinStage.notStarted]'a
  /// döner ve oturumları yeniden başlatmak için (varsa) kapı check-in'inin
  /// baştan Başlat→Bitir sırasıyla geçilmesi gerekir
  /// ([doorCheckinBlocksSessionsFor] zaten bunu zorunlu kılar). Kapı
  /// check-in'i olmayan modlarda alan zaten hep 0'dır; yazım no-op'tur.
  ///
  /// Keşfe dönüşün ölçütü bu damga DEĞİL, `entryOpen` + `currentSession`
  /// (bkz. [eventHasStarted]): kapıyı "Bitir" ile kapatmak da etkinliği
  /// yürümüyor sayar, kulüp o noktada kayıtları elle yeniden açabilir.
  Future<void> advanceSession(AppEvent event, int nextSession) =>
      fbDb.runTransaction((Transaction tx) async {
        final Doc doc = eventDoc(event.id);
        final AppEvent? live = AppEvent.fromDoc(await tx.get(doc));
        if (live == null ||
            live.currentSession != event.currentSession ||
            nextSession < 0 ||
            nextSession > live.sessionCount ||
            (nextSession > live.currentSession &&
                live.doorCheckinBlocksSessions)) {
          throw StateError('clubEvents.feedback.updateError');
        }
        final Map<String, dynamic> data = <String, dynamic>{
          'currentSession': nextSession,
          'sessionQrPublished': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (nextSession <= 0) {
          data['entryOpen'] = false;
          data['entryStartedAtMs'] = 0;
          data['doorQrPublished'] = false;
          data['sessionsCompleted'] = false;
          data['sessionsCompletedAt'] = null;
        }

        switch (sessionRegistrationGateAction(
          previousSession: live.currentSession,
          nextSession: nextSession,
          registrationClosed: live.registrationClosed,
          closedReason: live.registrationClosedReason,
          allowLateRegistration: live.allowLateRegistration,
        )) {
          case SessionRegistrationGateAction.close:
            data['registrationClosed'] = true;
            data['registrationClosedAt'] = FieldValue.serverTimestamp();
            data['registrationClosedReason'] = ClosedReason.sessionsStarted;
            data['registrationReopenedAt'] = null;
          case SessionRegistrationGateAction.reopen:
            data['registrationClosed'] = false;
            data['registrationClosedAt'] = null;
            data['registrationClosedReason'] = null;
            data['registrationReopenedAt'] = FieldValue.serverTimestamp();
          case SessionRegistrationGateAction.none:
            break;
        }

        tx.update(doc, data);
      });

  /// Kulüp "Oturumu Geri Al"a bastığında (js/pages/club-events.js#revertSessionBtn
  /// ile aynı gerekçe), o oturuma kendi QR'ıyla girmiş öğrencilerin
  /// yoklamasını da geri alır.
  ///
  /// Yalnızca `currentSession` geri alınsaydı bu öğrencilerin
  /// `lastAttendedSession`'ı, hiç yaşanmamış sayılan oturumu işaretli
  /// bırakırdı — oturum yeniden (doğru şekilde) başladığında okuma
  /// tarafındaki `lastAttendedSession >= currentSession` kontrolü onları
  /// ikinci kez giriş yapmaktan alıkoyardu.
  ///
  /// SIRA ÖNEMLİ: firestore.rules > `clubCanRevertSessionCheckIn`, bu yazımı
  /// yalnızca etkinliğin **canlı** `currentSession` alanı hâlâ
  /// [undoneSession]'a eşitken kabul eder; çağıran bunu etkinlik
  /// dokümanındaki `currentSession`'ı geri almadan (bkz. [advanceSession])
  /// ÖNCE çağırmalı.
  ///
  /// Yazım **en iyi çaba** ve kayıt kayıt yapılır (bkz.
  /// [syncStudentInfoOnRegistrations] ile aynı gerekçe): bu kural web'in
  /// aksine henüz üretime dağıtılmamış olabilir; tek bir kaydın (hatta
  /// tümünün) reddi asıl geri alma işlemini (`currentSession`) hiçbir zaman
  /// engellememeli — çağıran taraf bu yüzden bunu ayrı bir try/catch'e alır.
  ///
  /// Etkilenen öğrenci sayısını döndürür.
  Future<int> revertSessionAttendance({
    required String eventId,
    required int undoneSession,
  }) async {
    if (undoneSession < 1) return 0;

    final List<EventRegistration> registrations = await fetchEventRegistrations(
      eventId,
    );
    final Iterable<EventRegistration> affected = registrations.where(
      (EventRegistration r) => r.lastAttendedSession == undoneSession,
    );

    int updated = 0;
    for (final EventRegistration reg in affected) {
      try {
        await registrationsCol.doc(reg.id).update(<String, dynamic>{
          'lastAttendedSession': undoneSession - 1,
          'sessionsAttended': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        updated += 1;
      } catch (_) {
        // Yoksay: kalan kayıtlar denenmeye devam eder.
      }
    }
    return updated;
  }

  Future<void> finishSessions(String eventId) =>
      eventDoc(eventId).update(<String, dynamic>{
        'sessionsCompleted': true,
        'sessionQrPublished': 0,
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
      fbDb.runTransaction((Transaction tx) async {
        final Doc doc = eventDoc(eventId);
        final AppEvent? event = AppEvent.fromDoc(await tx.get(doc));
        if (event == null) throw StateError('scan.eventNotFound');
        if (!closed && lateRegistrationBlocked(event)) {
          throw StateError('clubEvents.registrations.blockedRunning');
        }
        tx.update(doc, <String, dynamic>{
          'registrationClosed': closed,
          'registrationClosedAt': closed ? FieldValue.serverTimestamp() : null,
          'registrationReopenedAt': closed
              ? null
              : FieldValue.serverTimestamp(),
          'registrationClosedReason': closed ? ClosedReason.manual : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
    if (action == QuotaGateAction.resume && !eventHasStarted(event)) {
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

  /// Yalnızca GÜNÜ GEÇMİŞ etkinlik istemciden silinebilir (kurallar). Gelecek
  /// etkinlik için [RegistrationService.cancelEvent] kullanılır (İP-K).
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

  /// Belge anahtarı gelmeden önce yazılmış (`{eventId}_{studentId}`) kaydı
  /// temizler — çağıran taraf aynı belgeyi yeni kimlikle yeniden yazdıysa.
  ///
  /// Yoksa hiçbir şey yapmaz: kural `resource.data` okuduğu için olmayan
  /// dokümanın silinmesi izin hatası verir, o yüzden hata yutulur. Temizlik
  /// "en iyi çaba"dır; başarısız olsa da dağıtım geçerlidir.
  Future<void> deleteLegacyCertificate({
    required String eventId,
    required String studentId,
  }) async {
    try {
      await certificatesCol.doc('${eventId}_$studentId').delete();
    } catch (_) {
      // Kayıt zaten yok ya da silinemedi; öğrencide en fazla eski bir kopya
      // kalır.
    }
  }

  /// PDF şablonunda isim yazılacak alanı bulup her öğrencinin adını basar
  /// (functions/certificateEngine.js — web istemcisindeki
  /// certificate-engine.js'in birebir Node portu, aynı fonksiyon her iki
  /// istemci için de tek doğruluk kaynağıdır).
  ///
  /// PDF olmayan belgeler (görsel) için çağrılmamalı; şablonda isim alanı hiç
  /// bulunamazsa (`personalized: false`) belge olduğu gibi döner. Bu çağrının
  /// kendisi başarısız olursa (ağ, yetki, fonksiyon kapalı) çağıran taraf
  /// (`club_event_detail_screen.dart#_distribute`) ham baytları kendisi
  /// yükler — dağıtım hiçbir zaman bu adım yüzünden durmaz.
  ///
  /// [students] tek çağrıda en fazla 300 kayıt taşıyabilir (fonksiyon
  /// tarafındaki sınırla aynı); daha büyük listeler çağıran tarafta
  /// parçalanmalıdır.
  Future<List<PersonalizedCertificate>> personalizeCertificates({
    required String clubId,
    required String eventId,
    required String documentKey,
    required Uint8List templateBytes,
    required List<({String studentId, String fullName})> students,
  }) async {
    final HttpsCallable callable = fbFunctions.httpsCallable(
      'personalizeCertificates',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );

    final HttpsCallableResult<Object?> result = await callable.call(
      <String, dynamic>{
        'clubId': clubId,
        'eventId': eventId,
        'documentKey': documentKey,
        'templateBase64': base64Encode(templateBytes),
        'students': students
            .map(
              (({String studentId, String fullName}) s) => <String, String>{
                'studentId': s.studentId,
                'fullName': s.fullName,
              },
            )
            .toList(),
      },
    );

    final List<dynamic> rawResults =
        (result.data as Map<Object?, Object?>)['results'] as List<dynamic>;

    return rawResults
        .map(
          (dynamic item) => PersonalizedCertificate.fromMap(
            Map<Object?, Object?>.from(item as Map<Object?, Object?>),
          ),
        )
        .toList();
  }

  /// Bir öğrenciye belge kaydı yazar.
  ///
  /// Doküman kimliği deterministiktir (`{eventId}_{studentId}_{documentKey}`):
  /// AYNI belge ikinci kez dağıtılırsa kopya oluşmaz, mevcut kayıt güncellenir
  /// (club-events.js#distributeCertificates ile aynı desen).
  ///
  /// [documentKey] kimliğe 2026-09'da eklendi. Öncesinde kimlik yalnızca
  /// etkinlik+öğrenciydi ve aynı etkinliğe yüklenen ikinci belge birincinin
  /// kaydını eziyordu: öğrencide etkinlik başına yalnızca EN SON belge
  /// duruyordu, öğrenci o kaydı silince de kulüp aynı belgeyi elle yeniden
  /// dağıtmadıkça yerine hiçbir şey gelmiyordu.
  Future<void> issueCertificate({
    required String eventId,
    required String studentId,
    required String documentKey,
    required String eventTitle,
    required String clubId,
    required String clubName,
    required String fileUrl,
    required String filePath,
    required String fileName,
    required String contentType,
    required bool personalized,
  }) => certificateDoc(eventId, studentId, documentKey).set(<String, dynamic>{
    'studentId': studentId,
    'eventId': eventId,
    'documentKey': documentKey,
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
    required PaidEventConsentAcceptance? paidEventConsent,
  }) async {
    // Bu denetim yalnızca ekrandaki düğmeye güvenmez: ücretli bir taslak,
    // onay olmadan bu depodan da oluşturulamaz. firestore.rules onay
    // alanlarını zorunlu TUTMUYOR (bkz. tool/loadtest/12-ucretli-onay-logu.mjs),
    // bu yüzden tek sınır burasıdır.
    if (draft.feeType == 'paid' && paidEventConsent == null) {
      throw ArgumentError('Paid event creation requires club consent.');
    }

    // Kimlik önceden alınır (yazma yapmadan): etkinlik dokümanı ile kontenjan
    // parçaları TEK toplu yazımda, atomik olarak oluşsun. Ayrı ayrı yazılsaydı
    // arada kalan anda etkinlik "parçalı" görünüp parçaları bulunmayacak,
    // kaydolmaya çalışan herkes "kontenjan doldu" cevabını alacaktı.
    final Doc ref = eventsCol.doc();

    // İP-K (L3): kontenjan parçalarını sunucu kurar (setEventQuota). Etkinlik
    // kontenjan kurulana kadar KAYDA KAPALI oluşturulur; kurulum başarısız
    // olursa etkinlik kapalı kalır, hiçbir zaman kontenjansız değil.
    final bool needsQuota = draft.quota > 0;

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
      'registrationClosed': needsQuota,
      if (needsQuota) 'registrationClosedReason': 'quota-setup',
      'hiddenFromClubList': false,
      'hiddenGlobally': false,
      'currentSession': 0,
      'sessionsCompleted': false,
      'entryOpen': false,
      'allowSessionWithoutCheckin': false,
      'quotaShardCount': 0,
      // Ücretli etkinliğin onay logu ETKİNLİK BELGESİNDE durur: kulübün
      // kabul ettiği metnin kendisi ve saniyeye kadar inen damgası.
      // Şema web ile ortak (club-create-event.js#saveEvent); ücretsiz
      // etkinliğe hiçbir alan yazılmaz.
      if (draft.feeType == 'paid' && paidEventConsent != null)
        kPaidConsentLogField: <String, dynamic>{
          ...paidEventConsent.toLogMap(),
          // Sunucu damgası istemcinin saatine güvenmeyen ikinci kayıt.
          'approvedAt': FieldValue.serverTimestamp(),
        },
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });

    await batch.commit();

    if (needsQuota) {
      // Hata olursa çağırana iletilir; etkinlik kapalı kalır ve kulüp
      // düzenleyip kaydederek kurulumu yeniden dener.
      await const RegistrationService().setEventQuota(
        eventId: ref.id,
        quota: draft.quota,
      );
    }

    AppLog.info('event.created', <String, Object?>{
      'eventId': ref.id,
      'quota': draft.quota,
    });

    return ref.id;
  }

  /// Etkinliği günceller ve kontenjan değiştiyse parçaları yeniden dengeler.
  ///
  /// [paidEventConsent] verilmişse ücretli etkinliğin onay logu TAZELENİR
  /// (web'deki `saveEvent` de her kayıtta tazeler). Etkinlik ücretsize
  /// çevrildiyse log anlamını yitirir ve silinir — aksi hâlde ücretsiz bir
  /// etkinlikte bayat bir ödeme onayı kalırdı.
  ///
  /// Ücretsizden ücretliye geçişte onay ZORUNLU: firestore.rules logsuz
  /// ücretli etkinliği kabul etmez.
  Future<void> updateEvent(
    String eventId,
    EventDraft draft, {
    PaidEventConsentAcceptance? paidEventConsent,
  }) async {
    final bool paid = draft.feeType == 'paid';

    // İP-K: kontenjan ÖNCE sunucuda değişir (parça silinmez, sayımlar
    // kayıtlardan yeniden hesaplanır). Kayıtlı sayısının altına inilirse
    // sunucu `below-registered` ile reddeder ve diğer değişiklikler de
    // yazılmaz — kulüp düzeltip yeniden kaydeder.
    final AppEvent? current = await fetchEventFromServer(eventId);
    final bool quotaChanged =
        current == null ||
        current.quota != draft.quota ||
        current.quotaSetupPending ||
        (draft.quota > 0 && current.quotaShardCount <= 0);
    if (quotaChanged) {
      await const RegistrationService().setEventQuota(
        eventId: eventId,
        quota: draft.quota,
      );
    }

    final Map<String, dynamic> fields = <String, dynamic>{...draft.toMap()}
      // Kontenjan alanlarını yalnızca sunucu yazar.
      ..remove('quota')
      ..remove('quotaShardCount');

    // İP-B4: başlamış etkinlikte geç kayıt sonradan açılırsa, başlarken
    // kendiliğinden kapanan kayıtlar geri açılır (elle durdurulduysa değil).
    final bool lateReopen =
        draft.allowLateRegistration &&
        current != null &&
        current.registrationClosed &&
        <String>[
          ClosedReason.sessionsStarted,
          ClosedReason.checkinStarted,
          'event-started',
        ].contains(current.registrationClosedReason);
    await eventDoc(eventId).update(<String, dynamic>{
      ...fields,
      if (lateReopen) ...<String, dynamic>{
        'registrationClosed': false,
        'registrationClosedAt': null,
        'registrationClosedReason': null,
        'registrationReopenedAt': FieldValue.serverTimestamp(),
      },
      if (paid && paidEventConsent != null)
        kPaidConsentLogField: <String, dynamic>{
          ...paidEventConsent.toLogMap(),
          'approvedAt': FieldValue.serverTimestamp(),
        },
      if (!paid) kPaidConsentLogField: FieldValue.delete(),
    });
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

  /// Kulübün adını, üniversitesini ve alan(lar)ını TÜM etkinliklerine işler.
  ///
  /// Logo ve iletişim bilgileriyle aynı gerekçe (bkz. [syncClubLogo]):
  /// öğrenci `club_profiles` dokümanını okuyamadığı için bu alanlar da
  /// etkinlik dokümanına kopyalanır. Kulüp adını (veya üniversite/alanını)
  /// hesap ekranından değiştirdiğinde eski etkinliklerin penceresi eski
  /// bilgide kalmasın diye kayıt bunu çağırır.
  Future<void> syncClubIdentity({
    required String clubId,
    required String clubName,
    required String clubUniversity,
    required List<String> clubFields,
  }) async {
    await _syncClubFields(clubId, <String, dynamic>{
      'clubName': clubName,
      'clubUniversity': clubUniversity,
      'clubField': clubFields.isEmpty ? '' : clubFields.first,
      'clubFields': clubFields,
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
/// İP-B: otomatik bildirim anahtarları; varsayılan hepsi açık.
const Map<String, bool> kDefaultAutoNotifications = <String, bool>{
  'dayBefore': true,
  'hourBefore': true,
  'atStart': true,
  'afterEnd': true,
};

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
    this.sessionNames = const <String>[],
    this.sessionTimes = const <SessionTime>[],
    required this.checkinMode,
    required this.certificateThresholdPercent,
    required this.locationName,
    required this.locationLat,
    required this.locationLng,
    required this.locationRadius,
    this.contactMode = 'club',
    this.contactPhone = '',
    this.contactEmail = '',
    this.autoNotifications = kDefaultAutoNotifications,
    this.visibility = 'public',
    this.allowLateRegistration = false,
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
  final List<String> sessionNames;
  final List<SessionTime> sessionTimes;
  final String checkinMode;
  final int? certificateThresholdPercent;
  final String locationName;
  final double? locationLat;
  final double? locationLng;
  final int? locationRadius;

  /// İletişim bilgisi: `club` (kulübün sistemdeki bilgileri), `custom`
  /// (bu etkinliğe özel), `hidden` (gösterme; yalnızca ücretsiz etkinlik).
  final String contactMode;
  final String contactPhone;
  final String contactEmail;

  /// İP-B: otomatik bildirimler (functions/eventReminders.js REMINDER_KEYS).
  final Map<String, bool> autoNotifications;

  /// İP-EL: `public` (keşfette görünür) ya da `link` (yalnızca linki olan görür).
  final String visibility;

  /// İP-B4: başladıktan sonra da kayıt al.
  final bool allowLateRegistration;

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
    sessionNames: sessionNames,
    sessionTimes: sessionTimes,
    checkinMode: checkinMode,
    certificateThresholdPercent: certificateThresholdPercent,
    locationName: locationName,
    locationLat: locationLat,
    locationLng: locationLng,
    locationRadius: locationRadius,
    contactMode: contactMode,
    contactPhone: contactPhone,
    contactEmail: contactEmail,
    autoNotifications: autoNotifications,
    visibility: visibility,
    allowLateRegistration: allowLateRegistration,
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
    'targetUniversity': targetUniversities.isEmpty
        ? ''
        : targetUniversities.first,
    'targetUniversities': targetUniversities,
    'targetDepartment': targetDepartments.isEmpty
        ? ''
        : targetDepartments.first,
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
    'autoNotifications': autoNotifications,
    'sessionCount': sessionCount,
    'sessionNames': sessionNames,
    'sessionTimes': sessionTimes
        .map((SessionTime t) => t.toMap())
        .toList(growable: false),
    'checkinMode': checkinMode,
    'certificateThresholdPercent': certificateThresholdPercent,
    'locationName': locationName,
    'locationLat': locationLat,
    'locationLng': locationLng,
    // Konum adı girilmediyse yarıçapın anlamı yok.
    'locationRadius': locationName.isEmpty ? null : locationRadius,
    'contactMode': contactMode,
    'contactPhone': contactMode == 'custom' ? contactPhone : '',
    'contactEmail': contactMode == 'custom' ? contactEmail : '',
    'visibility': visibility == 'link' ? 'link' : 'public',
    'allowLateRegistration': allowLateRegistration,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// `personalizeCertificates` Cloud Function'ının tek bir öğrenci için
/// döndürdüğü sonuç: isim zaten basılmış belgenin Storage konumu.
class PersonalizedCertificate {
  const PersonalizedCertificate({
    required this.studentId,
    required this.filePath,
    required this.fileUrl,
    required this.personalized,
  });

  factory PersonalizedCertificate.fromMap(Map<Object?, Object?> map) =>
      PersonalizedCertificate(
        studentId: map['studentId'] as String? ?? '',
        filePath: map['filePath'] as String? ?? '',
        fileUrl: map['fileUrl'] as String? ?? '',
        personalized: map['personalized'] as bool? ?? false,
      );

  final String studentId;
  final String filePath;
  final String fileUrl;
  final bool personalized;
}
