/// Kontenjanı koruyan, çekişmeye dayanıklı etkinlik kaydı.
///
/// ── Neden gerekti ────────────────────────────────────────────────────
///
/// `EventRepository.registerToEvent` kaydı doğrudan `set()` ile yazıyordu.
/// Kontenjan hiçbir yerde — ne istemcide ne `firestore.rules` içinde —
/// kontrol edilmiyordu. Yük testi (`tool/loadtest/01-baseline.mjs`)
/// kontenjanı 100 olan bir etkinliğe 2000 kişinin **tek hata almadan**
/// kaydolabildiğini gösterdi: uygulama çökmüyor, sessizce yanlış çalışıyor.
///
/// ── Algoritma ────────────────────────────────────────────────────────
///
/// Kontenjanı korumak, kaydı sayaçla birlikte atomik yazmayı gerektirir.
/// Sayaç tek dokümanda tutulursa o doküman bütün etkinliğin darboğazı olur
/// (Firestore'da tek dokümana sürdürülebilir yazma: saniyede ~1). Yük
/// testinde tek sayaçlı kurulum 50 eşzamanlı istekte %38, 100'de %99 hata
/// verdi.
///
/// Bu yüzden kontenjan **parçalara** bölünür:
///
///     events/{eventId}/quota_shards/{0..S-1}   →  { count, capacity }
///
/// Kapasitelerin toplamı tam olarak kontenjandır, dolayısıyla ne aşım ne
/// eksik olur. Öğrenci kimliğinden türeyen bir parçadan başlar; parça
/// doluysa sıradakine yürür. Bütün parçalar doluysa kontenjan gerçekten
/// bitmiştir.
///
/// Parça sayısı tavanı belirler; **kalan yük zamana yayılır**. Çarpışan
/// istek üstel büyüyen ve rastgeleleştirilmiş (tam jitter) bir bekleyişten
/// sonra yeniden dener. Merkezî bir kuyruk kuramayız — 500 öğrencinin 500
/// ayrı telefonu var, hiçbiri diğerini beklemiyor — ama yeniden deneme
/// dağıtık bir kuyruk kurar. "Bölük bölük" olan budur: her turda parça
/// sayısı kadar kayıt geçer, gerisi bir sonraki turu bekler.
///
/// Ölçülen davranış: bir turda **parça sayısı kadar** kayıt geçiyor (500
/// kişi aynı anda, 16 parça, yeniden deneme kapalı → tam 16 kayıt). Emilen
/// patlama bu yüzden kabaca `parça sayısı × etkin tur sayısı`; büyük
/// patlama beklenen etkinlikte artırılacak kollar `quotaShardCount` ve
/// [kRegistrationMaxRounds]. Modelin turlarla doğrusal büyüdüğü emulator'de
/// doğrulanamadı — bkz. `docs/kayit-kapasitesi.md` §1.5.
///
/// Politikanın tamamı `lib/domain/registration_capacity.dart` içinde ve
/// Firebase'e dokunmadan test edilebilir.
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_log.dart';
import '../domain/paid_event_consent.dart';
import '../domain/registration_capacity.dart';
import '../models/event.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';

/// Kayıt denemesinin sonucu — sonuç kodu + tanı alanları.
class RegistrationResult {
  const RegistrationResult({
    required this.outcome,
    required this.rounds,
    required this.contentions,
    required this.shardsScanned,
    required this.elapsed,
    this.shard,
  });

  final RegistrationOutcome outcome;

  /// Kaç tur döndü (0 = ilk denemede oldu).
  final int rounds;

  /// Kaç kez çekişmeye takılıp geri çekildi.
  final int contentions;

  /// Kaç parça tarandı.
  final int shardsScanned;

  final Duration elapsed;

  /// Kaydın düştüğü parça (başarılıysa).
  final int? shard;

  bool get isSuccess => outcome.isSuccess;

  Map<String, Object?> toFields() => <String, Object?>{
    'outcome': outcome.name,
    'rounds': rounds,
    'contentions': contentions,
    'shardsScanned': shardsScanned,
    'ms': elapsed.inMilliseconds,
    if (shard != null) 'shard': shard,
  };
}

/// Tek bir parçaya yapılan denemenin sonucu.
///
/// Transaction'ın İÇİNDEN istisna fırlatmak yerine bilerek değer
/// döndürülüyor: `runTransaction` gövdeden geçen istisnaları sarmalayabilir
/// ve o zaman "parça dolu" ile "çekişme" birbirine karışırdı — biri sıradaki
/// parçaya yürümeyi, diğeri bekleyip baştan denemeyi gerektirdiği için bu
/// ayrım algoritmanın merkezinde.
enum _ClaimResult {
  /// Yer kapıldı, kayıt yazıldı.
  claimed,

  /// Bu parçada yer yok (ya da parça hiç kurulmamış) — sıradakine bak.
  shardFull,

  /// Öğrenci zaten kayıtlı; kontenjan harcanmadı.
  alreadyRegistered,
}

class RegistrationService {
  const RegistrationService({this.random});

  /// Testlerde jitter'ı belirlenir kılmak için.
  final Random? random;

  /// Kontenjanı koruyarak kayıt oluşturur.
  ///
  /// [event] çağıran tarafından **sunucudan taze** okunmuş olmalıdır
  /// (`EventRepository.fetchEventFromServer`): önbellekteki "kayıt açık"
  /// hâline güvenilmez.
  Future<RegistrationResult> register({
    required AppEvent event,
    required String studentId,
    required String studentEmail,
    required StudentProfile? profile,
    required String displayName,
    required String eventFallbackTitle,
    required String clubFallbackName,
    required PaidEventConsentAcceptance? paidEventConsent,
    void Function(int round)? onWaiting,
  }) async {
    // Ekrandaki zorunlu pop-up atlatılsa bile servis ücretli kaydı kurmaz.
    // DİKKAT: firestore.rules onay alanlarını ZORUNLU TUTMUYOR (emulator ile
    // doğrulandı, bkz. tool/loadtest/12-ucretli-onay-logu.mjs) — zorunluluk şu an
    // yalnızca istemcide. Bu denetim son sınır, kaldırılmamalı.
    if (event.isPaid && paidEventConsent == null) {
      throw ArgumentError('Paid event registration requires student consent.');
    }

    final Stopwatch watch = Stopwatch()..start();

    AppLog.info('registration.start', <String, Object?>{
      'eventId': event.id,
      'studentId': studentId,
      'quota': event.quota,
      'shards': event.quotaShardCount,
    });

    // Kontenjansız etkinlik (quota <= 0) ya da parçaları henüz kurulmamış
    // ESKİ etkinlik: korunacak bir sayaç yok, eski yol aynen çalışır.
    // Davranışı bozmamak esas — parçasız etkinlikte kayıt reddedilmemeli.
    if (event.quota <= 0 || event.quotaShardCount <= 0) {
      AppLog.warn('registration.unbounded', <String, Object?>{
        'eventId': event.id,
        'quota': event.quota,
        'reason': event.quota <= 0 ? 'no-quota' : 'no-shards',
      });
      await _writeRegistration(
        event: event,
        studentId: studentId,
        studentEmail: studentEmail,
        profile: profile,
        displayName: displayName,
        eventFallbackTitle: eventFallbackTitle,
        clubFallbackName: clubFallbackName,
        paidEventConsent: paidEventConsent,
        shard: null,
      );
      return RegistrationResult(
        outcome: RegistrationOutcome.registered,
        rounds: 0,
        contentions: 0,
        shardsScanned: 0,
        elapsed: watch.elapsed,
      );
    }

    final int shards = event.quotaShardCount;
    final int start = startShardFor(studentId, shards);

    int contentions = 0;
    int shardsScanned = 0;

    for (int round = 0; round < kRegistrationMaxRounds; round++) {
      int fullShards = 0;
      bool contended = false;

      for (int step = 0; step < shards; step++) {
        final int shard = (start + step) % shards;
        shardsScanned += 1;

        try {
          final _ClaimResult claim = await _claimShard(
            event: event,
            shard: shard,
            studentId: studentId,
            studentEmail: studentEmail,
            profile: profile,
            displayName: displayName,
            eventFallbackTitle: eventFallbackTitle,
            clubFallbackName: clubFallbackName,
            paidEventConsent: paidEventConsent,
          );

          if (claim == _ClaimResult.shardFull) {
            fullShards += 1;
            continue; // sıradaki parçaya yürü
          }

          final RegistrationResult result = RegistrationResult(
            outcome: claim == _ClaimResult.claimed
                ? RegistrationOutcome.registered
                : RegistrationOutcome.alreadyRegistered,
            rounds: round,
            contentions: contentions,
            shardsScanned: shardsScanned,
            elapsed: watch.elapsed,
            shard: claim == _ClaimResult.claimed ? shard : null,
          );
          AppLog.info(
            claim == _ClaimResult.claimed
                ? 'registration.ok'
                : 'registration.already',
            <String, Object?>{
              'eventId': event.id,
              'studentId': studentId,
              ...result.toFields(),
            },
          );
          return result;
        } on FirebaseException catch (error) {
          // Ağ yok: yeniden denemenin faydası yok, kullanıcıya söyle.
          if (error.code == 'unavailable') {
            AppLog.warn('registration.unavailable', <String, Object?>{
              'eventId': event.id,
              'studentId': studentId,
              'round': round,
            });
            return RegistrationResult(
              outcome: RegistrationOutcome.unavailable,
              rounds: round,
              contentions: contentions,
              shardsScanned: shardsScanned,
              elapsed: watch.elapsed,
            );
          }

          // Kural reddi: kayıtlar kapanmış ya da öğrenci hedef kitlede değil.
          if (error.code == 'permission-denied') {
            AppLog.warn('registration.denied', <String, Object?>{
              'eventId': event.id,
              'studentId': studentId,
              'code': error.code,
            });
            return RegistrationResult(
              outcome: RegistrationOutcome.closed,
              rounds: round,
              contentions: contentions,
              shardsScanned: shardsScanned,
              elapsed: watch.elapsed,
            );
          }

          // ABORTED / DEADLINE_EXCEEDED: başkası aynı parçayı kaptı.
          //
          // İki başarısızlık türüne BİLEREK farklı tepki veriliyor:
          //   • parça dolu  -> sıradaki parçaya yürü (yer arıyoruz)
          //   • çekişme     -> turu bitir, bekle      (sistem meşgul)
          //
          // Çekişmede de yürümek cazip görünüyor ("belki öbür parça boştur")
          // ama yükü katlıyor: çekişme zaten herkesin aynı anda denediği an
          // demek; o anda her öğrencinin bütün parçaları taraması sürü
          // etkisini parça sayısı kadar büyütür. Geri çekilmek işbirlikçi
          // olan davranıştır.
          contentions += 1;
          contended = true;
          AppLog.debug('registration.contended', <String, Object?>{
            'eventId': event.id,
            'shard': shard,
            'round': round,
            'code': error.code,
          });
          break;
        }
      }

      // Çekişme YOKKEN bütün parçalar doluysa kontenjan gerçekten bitmiştir.
      // Çekişme varsa "dolu" gördüğümüz parçalar eski okuma olabilir.
      if (!contended && fullShards == shards) {
        final RegistrationResult result = RegistrationResult(
          outcome: RegistrationOutcome.quotaFull,
          rounds: round,
          contentions: contentions,
          shardsScanned: shardsScanned,
          elapsed: watch.elapsed,
        );
        AppLog.info('registration.quotaFull', <String, Object?>{
          'eventId': event.id,
          'studentId': studentId,
          ...result.toFields(),
        });
        return result;
      }

      if (round < kRegistrationMaxRounds - 1) {
        final Duration wait = registrationBackoff(round, random: random);
        AppLog.debug('registration.backoff', <String, Object?>{
          'eventId': event.id,
          'round': round,
          'waitMs': wait.inMilliseconds,
        });
        // Bekleme kullanıcıya görünür olmalı: "bölük bölük" alınan bir
        // kayıtta donmuş bir düğme, işlem başarısız sanılıp uygulamanın
        // kapatılmasına yol açar.
        onWaiting?.call(round);
        await Future<void>.delayed(wait);
      }
    }

    // Turlar bitti. Bu HENÜZ "tekrar dene" demek değil: kontenjan çoktan
    // dolmuş da olabilir.
    //
    // Tur içindeki "hepsi dolu" kontrolü çekişme varsa çalışmıyor — dolu
    // gördüğümüz parça eski bir okuma olabileceği için bilerek güvenmiyoruz.
    // Ama yoğunlukta neredeyse her turda bir çekişme oluyor, dolayısıyla
    // kontenjanı gerçekten dolmuş bir etkinlikte kullanıcı "kontenjan doldu"
    // yerine "çok yoğun, tekrar dene" görüyordu ve boşuna tekrar deniyordu.
    // (Yük testi 07-capacity C: 200 kişilik etkinliğe 1000 başvuru →
    // "kontenjan doldu" diyen 0, "tekrar dene" diyen 807.)
    //
    // Bu yüzden pes etmeden önce parçalara bir kez temiz bakılır: S okuma,
    // yalnızca başarısız yolda.
    final bool full = await _isQuotaFull(event.id, shards);

    final RegistrationResult result = RegistrationResult(
      outcome: full
          ? RegistrationOutcome.quotaFull
          : RegistrationOutcome.retryExhausted,
      rounds: kRegistrationMaxRounds,
      contentions: contentions,
      shardsScanned: shardsScanned,
      elapsed: watch.elapsed,
    );

    if (full) {
      AppLog.info('registration.quotaFull', <String, Object?>{
        'eventId': event.id,
        'studentId': studentId,
        'via': 'final-check',
        ...result.toFields(),
      });
    } else {
      AppLog.error(
        'registration.exhausted',
        fields: <String, Object?>{
          'eventId': event.id,
          'studentId': studentId,
          ...result.toFields(),
        },
      );
    }
    return result;
  }

  /// Bütün parçaların sayaçları kapasitelerine ulaştı mı?
  ///
  /// Tek seferlik, transaction'sız bir okuma: kontenjan dolduktan sonra
  /// yeniden boşalması ancak birinin kaydını silmesiyle olur, o da nadirdir.
  /// Yanlış "doldu" demektense yanlış "tekrar dene" demek daha az zararlı
  /// olduğu için şüphede kalınırsa `false` döner.
  Future<bool> _isQuotaFull(String eventId, int shards) async {
    try {
      final QSnap snap = await quotaShardsCol(eventId).get();
      if (snap.docs.length < shards) return false; // eksik parça: emin değiliz

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        final int count = asInt(doc.data()['count']) ?? 0;
        final int capacity = asInt(doc.data()['capacity']) ?? 0;
        if (count < capacity) return false;
      }
      return true;
    } catch (error) {
      AppLog.warn('registration.quotaCheckFailed', <String, Object?>{
        'eventId': eventId,
        'error': error.toString(),
      });
      return false;
    }
  }

  /// Tek bir parçadan yer kapma denemesi — kayıt ve sayaç **aynı**
  /// transaction'da yazılır, böylece ikisi birbiri olmadan var olamaz.
  Future<_ClaimResult> _claimShard({
    required AppEvent event,
    required int shard,
    required String studentId,
    required String studentEmail,
    required StudentProfile? profile,
    required String displayName,
    required String eventFallbackTitle,
    required String clubFallbackName,
    required PaidEventConsentAcceptance? paidEventConsent,
  }) => fbDb.runTransaction<_ClaimResult>(
    (Transaction tx) async {
      final Doc shardRef = quotaShardDoc(event.id, shard);
      final Doc regRef = registrationDoc(event.id, studentId);

      // Firestore transaction'ında bütün okumalar yazımlardan önce olmalı.
      final DocumentSnapshot<Map<String, dynamic>> shardSnap =
          await tx.get(shardRef);
      final DocumentSnapshot<Map<String, dynamic>> regSnap =
          await tx.get(regRef);

      // Öğrenci zaten kayıtlı: sayacı İKİNCİ kez artırmak kontenjanı yerdi.
      // (Ağ kesilip kullanıcı tekrar bastığında bu yol işler.)
      if (regSnap.exists) return _ClaimResult.alreadyRegistered;

      // Parça yok: kulüp etkinliği oluştururken kurmamış olabilir. Burada
      // kurmak güvenlik açığı olurdu (istemci kapasiteyi kendisi belirlerdi
      // — firestore.rules de zaten izin vermez), bu yüzden dolu sayılır.
      if (!shardSnap.exists) return _ClaimResult.shardFull;

      final Map<String, dynamic> data = shardSnap.data()!;
      final int count = asInt(data['count']) ?? 0;
      final int capacity = asInt(data['capacity']) ?? 0;

      if (count >= capacity) return _ClaimResult.shardFull;

      tx.set(
        regRef,
        _registrationPayload(
          event: event,
          studentId: studentId,
          studentEmail: studentEmail,
          profile: profile,
          displayName: displayName,
          eventFallbackTitle: eventFallbackTitle,
          clubFallbackName: clubFallbackName,
          paidEventConsent: paidEventConsent,
          shard: shard,
        ),
      );
      tx.update(shardRef, <String, dynamic>{'count': count + 1});
      return _ClaimResult.claimed;
    },
    // Yeniden denemeyi BİZ yönetiyoruz: SDK'nın kendi denemesi jitter'sız
    // ve parçalar arası yürüyüşten habersiz.
    maxAttempts: 1,
  );

  /// Parçasız (eski / kontenjansız) etkinlik için düz yazım.
  Future<void> _writeRegistration({
    required AppEvent event,
    required String studentId,
    required String studentEmail,
    required StudentProfile? profile,
    required String displayName,
    required String eventFallbackTitle,
    required String clubFallbackName,
    required PaidEventConsentAcceptance? paidEventConsent,
    required int? shard,
  }) => registrationDoc(event.id, studentId).set(
    _registrationPayload(
      event: event,
      studentId: studentId,
      studentEmail: studentEmail,
      profile: profile,
      displayName: displayName,
      eventFallbackTitle: eventFallbackTitle,
      clubFallbackName: clubFallbackName,
      paidEventConsent: paidEventConsent,
      shard: shard,
    ),
    SetOptions(merge: true),
  );

  /// Kayıt yükü — `EventRepository.registerToEvent` ile alan alan aynı,
  /// üzerine kaydın hangi parçadan geçtiğini söyleyen `quotaShard`.
  /// Kayıt iptalinde o parçanın sayacı bu alan sayesinde geri alınır.
  Map<String, dynamic> _registrationPayload({
    required AppEvent event,
    required String studentId,
    required String studentEmail,
    required StudentProfile? profile,
    required String displayName,
    required String eventFallbackTitle,
    required String clubFallbackName,
    required PaidEventConsentAcceptance? paidEventConsent,
    required int? shard,
  }) => <String, dynamic>{
    'registrationId': registrationIdFor(event.id, studentId),
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
    'quotaShard': ?shard,
    // Ücretli etkinliğin öğrenci onay logu, kaydın KENDİ belgesinde
    // (etkinliğin katılımcı verisinde) durur — öğrenci profil belgesinde
    // değil. Şema web ile ortak (dashboard.js#buildRegistrationPayload):
    // kabul edilen metin + epoch + okunabilir damga. Ücretsiz etkinlikte
    // hiçbir alan eklenmez.
    if (event.isPaid && paidEventConsent != null)
      kPaidConsentLogField: <String, dynamic>{
        ...paidEventConsent.toLogMap(),
        // Sunucu damgası: istemcinin saatinden bağımsız ikinci kayıt.
        'approvedAt': FieldValue.serverTimestamp(),
      },
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Kaydı siler ve yerini kontenjana geri verir.
  ///
  /// Silme ile sayaç azaltması **aynı** transaction'dadır: biri olup diğeri
  /// olmazsa kontenjan ya sızar ya şişer. `firestore.rules` azaltmayı
  /// yalnızca kaydın aynı işlemde silinmesi şartıyla kabul eder
  /// (`existsAfter`), yani kimse kaydını silmeden yer açamaz.
  Future<void> unregister({
    required String eventId,
    required String studentId,
  }) async {
    final Doc regRef = registrationDoc(eventId, studentId);

    await fbDb.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> regSnap = await tx.get(regRef);
      if (!regSnap.exists) return;

      final int? shard = asInt(regSnap.data()?['quotaShard']);

      // Parçasız kayıt (eski etkinlik): yalnızca sil.
      if (shard == null) {
        tx.delete(regRef);
        return;
      }

      final Doc shardRef = quotaShardDoc(eventId, shard);
      final DocumentSnapshot<Map<String, dynamic>> shardSnap =
          await tx.get(shardRef);

      tx.delete(regRef);

      if (shardSnap.exists) {
        final int count = asInt(shardSnap.data()!['count']) ?? 0;
        if (count > 0) {
          tx.update(shardRef, <String, dynamic>{'count': count - 1});
        }
      }
    });

    AppLog.info('registration.cancelled', <String, Object?>{
      'eventId': eventId,
      'studentId': studentId,
    });
  }
}
