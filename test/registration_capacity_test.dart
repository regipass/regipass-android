/// Eşzamanlı kayıt politikasının testleri.
///
/// Buradaki her şey saftır — Firebase yok, emulator yok. Politikanın
/// kendisi (`lib/domain/registration_capacity.dart`) Firestore'a
/// dokunmadığı için eşzamanlılık kararları böyle test edilebiliyor.
///
/// Sunucu tarafındaki gerçek davranış ayrıca `tool/loadtest/` altındaki
/// yük testleriyle Firestore emulator'e karşı ölçüldü.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/core/app_log.dart';
import 'package:regipass/domain/registration_capacity.dart';

void main() {
  group('quotaShardCount', () {
    test('kontenjansız etkinlikte parça yok', () {
      expect(quotaShardCount(0), 0);
      expect(quotaShardCount(-5), 0);
    });

    test('kontenjan büyüdükçe parça sayısı artar', () {
      expect(quotaShardCount(50), 4);
      expect(quotaShardCount(51), 8);
      expect(quotaShardCount(200), 8);
      expect(quotaShardCount(201), 16);
      expect(quotaShardCount(1000), 16);
      expect(quotaShardCount(1001), 32);
      expect(quotaShardCount(100000), 32);
    });

    test('parça başına kapasite makul aralıkta kalır', () {
      // Parça başına çok az kişi düşerse kayıt boş parça arayarak dolaşır
      // (yürüme maliyeti); çok fazla düşerse çekişme artar. Tablo bu
      // dengeyi ~12 kişi civarında kuruyor.
      for (final int quota in <int>[100, 200, 500, 1000, 5000]) {
        final int perShard = quota ~/ quotaShardCount(quota);
        expect(perShard, greaterThanOrEqualTo(10), reason: 'kontenjan $quota');
      }
    });

    test('parça sayısı kontenjanı ASLA aşmaz', () {
      // Aşarsa kapasitesi 0 olan ölü parçalar oluşur; kayıt onları boşuna
      // tarar, doluluk göstergesi de boşuna okur.
      for (final int quota in <int>[1, 2, 3, 4, 7, 10, 50, 200, 1000]) {
        expect(
          quotaShardCount(quota),
          lessThanOrEqualTo(quota),
          reason: 'kontenjan $quota',
        );
      }
      // Tablo 4 diyor ama kontenjan 1: parça da 1 olur.
      expect(quotaShardCount(1), 1);
      expect(quotaShardCount(3), 3);
      // Kontenjan tabloyu aştığı an tavan tablodan gelir.
      expect(quotaShardCount(5), 4);
    });

    test('her parçanın kapasitesi en az 1 olur', () {
      for (int quota = 1; quota <= 500; quota++) {
        final List<int> caps = shardCapacities(quota, quotaShardCount(quota));
        expect(
          caps.every((int c) => c >= 1),
          isTrue,
          reason: 'kontenjan $quota → $caps',
        );
      }
    });
  });

  group('shardCapacities', () {
    test('kapasitelerin toplamı TAM OLARAK kontenjandır', () {
      // Algoritmanın tamamı buna dayanıyor: toplam kontenjanı aşarsa
      // kontenjan aşılır, altında kalırsa yer boşa gider.
      for (int quota = 1; quota <= 300; quota++) {
        final int shards = quotaShardCount(quota);
        final List<int> caps = shardCapacities(quota, shards);
        expect(
          caps.fold<int>(0, (int a, int b) => a + b),
          quota,
          reason: 'kontenjan $quota, $shards parça',
        );
      }
    });

    test('artan pay ilk parçalara dağıtılır, fark en çok 1 olur', () {
      final List<int> caps = shardCapacities(10, 4);
      expect(caps, <int>[3, 3, 2, 2]);
      expect(caps.reduce(max) - caps.reduce(min), lessThanOrEqualTo(1));
    });

    test('parça sayısı kapasitedir — kontenjanla birlikte büyür', () {
      // Yeniden deneme kapalıyken 500 istekten TAM parça sayısı kadarı
      // geçiyor (07-capacity B): parça sayısı eşzamanlı kapasitedir.
      expect(quotaShardCount(400), greaterThan(quotaShardCount(100)));
      expect(quotaShardCount(2000), greaterThan(quotaShardCount(400)));
    });

    test('kontenjan parça sayısından küçükse boş parçalar oluşur', () {
      final List<int> caps = shardCapacities(3, 8);
      expect(caps.fold<int>(0, (int a, int b) => a + b), 3);
      expect(caps.where((int c) => c == 0).length, 5);
    });

    test('geçersiz girdide boş liste', () {
      expect(shardCapacities(0, 4), isEmpty);
      expect(shardCapacities(10, 0), isEmpty);
    });
  });

  group('startShardFor', () {
    test('her zaman geçerli aralıkta', () {
      for (int i = 0; i < 500; i++) {
        final int shard = startShardFor('student_$i', 16);
        expect(shard, inInclusiveRange(0, 15));
      }
    });

    test('aynı öğrenci hep aynı parçadan başlar', () {
      // Yeniden denemede başka parçaya savrulmak çekişmeyi çoğaltırdı.
      final int first = startShardFor('abc123', 16);
      for (int i = 0; i < 20; i++) {
        expect(startShardFor('abc123', 16), first);
      }
    });

    test('öğrenciler parçalara makul dengede dağılır', () {
      const int shards = 16;
      const int students = 1600;
      final List<int> hits = List<int>.filled(shards, 0);
      for (int i = 0; i < students; i++) {
        hits[startShardFor('loadtest_student_$i', shards)] += 1;
      }
      // Beklenen 100; dağılım bozuksa bazı parçalar erken dolup
      // yürüme maliyeti artar.
      const int expected = students ~/ shards;
      for (final int hit in hits) {
        expect(hit, greaterThan(expected ~/ 3));
        expect(hit, lessThan(expected * 3));
      }
    });

    test('parça yoksa 0 döner', () {
      expect(startShardFor('abc', 0), 0);
    });
  });

  group('registrationBackoff', () {
    test('pencere üstel büyür ve tavana oturur', () {
      expect(registrationBackoffWindow(0), kRegistrationBaseDelay);
      expect(registrationBackoffWindow(1).inMilliseconds, 300);
      expect(registrationBackoffWindow(2).inMilliseconds, 600);
      expect(registrationBackoffWindow(3).inMilliseconds, 1200);
      // 150 * 2^6 = 9600 > 6000 → tavan
      expect(registrationBackoffWindow(6), kRegistrationMaxDelay);
      expect(registrationBackoffWindow(40), kRegistrationMaxDelay);
    });

    test('bekleyiş pencerenin içinde kalır', () {
      final Random rng = Random(1);
      for (int round = 0; round < kRegistrationMaxRounds; round++) {
        for (int i = 0; i < 200; i++) {
          final Duration wait = registrationBackoff(round, random: rng);
          expect(wait, greaterThanOrEqualTo(Duration.zero));
          expect(wait, lessThanOrEqualTo(registrationBackoffWindow(round)));
        }
      }
    });

    test('JITTER: aynı turda farklı öğrenciler farklı süre bekler', () {
      // Bu testin koruduğu şey sürü etkisidir: sabit bekleyişte çekişmeden
      // düşen herkes aynı anda uyanıp aynı anda tekrar çarpışır. Faydası
      // emulator'de ölçülemedi (tek süreçli olduğu için kendi tavanına
      // çarpıyor), ama rastgelelik kaybolursa kurulum sessizce sürü
      // etkisine geri döner — bu yüzden test var.
      final Random rng = Random(7);
      final Set<int> waits = <int>{
        for (int i = 0; i < 50; i++)
          registrationBackoff(3, random: rng).inMilliseconds,
      };
      expect(
        waits.length,
        greaterThan(20),
        reason: 'bekleyişler rastgeleleşmeli, sabit olmamalı',
      );
    });

    test('negatif tur sıfır bekler', () {
      expect(registrationBackoff(-1), Duration.zero);
    });

    test('en kötü toplam bekleyiş sınırlıdır', () {
      // Kullanıcı sonsuza kadar bekletilmemeli; sınırı bilerek biliyoruz.
      expect(maxRegistrationWait.inSeconds, lessThanOrEqualTo(30));
      expect(maxRegistrationWait.inSeconds, greaterThan(10));
    });
  });

  group('RegistrationOutcome', () {
    test('kontenjan dolması HATA DEĞİLDİR', () {
      // Kullanıcıya "bir şeyler ters gitti" değil "kontenjan doldu" denir;
      // tekrar denemesinin de anlamı yoktur.
      expect(RegistrationOutcome.quotaFull.isRetryable, isFalse);
      expect(RegistrationOutcome.quotaFull.isSuccess, isFalse);
    });

    test('yalnızca geçici sorunlar tekrar denenebilir', () {
      expect(RegistrationOutcome.retryExhausted.isRetryable, isTrue);
      expect(RegistrationOutcome.unavailable.isRetryable, isTrue);
      expect(RegistrationOutcome.closed.isRetryable, isFalse);
      expect(RegistrationOutcome.notEligible.isRetryable, isFalse);
    });

    test('zaten kayıtlı olmak başarıdır', () {
      // Ağ kesilip kullanıcı tekrar bastığında hata göstermek yanlış olurdu.
      expect(RegistrationOutcome.alreadyRegistered.isSuccess, isTrue);
      expect(RegistrationOutcome.registered.isSuccess, isTrue);
    });
  });

  group('kontenjan bütünlüğü — parçalı sayaç benzetimi', () {
    /// Sunucudaki transaction davranışını taklit eden minik model:
    /// her parça bir sayaç, "kap" işlemi atomiktir.
    int simulate({
      required int quota,
      required int applicants,
    }) {
      final int shards = quotaShardCount(quota);
      if (shards == 0) return applicants; // kontenjansız

      final List<int> caps = shardCapacities(quota, shards);
      final List<int> counts = List<int>.filled(shards, 0);
      int registered = 0;

      for (int i = 0; i < applicants; i++) {
        final String uid = 'student_$i';
        final int start = startShardFor(uid, shards);
        for (int step = 0; step < shards; step++) {
          final int shard = (start + step) % shards;
          if (counts[shard] < caps[shard]) {
            counts[shard] += 1;
            registered += 1;
            break;
          }
        }
      }
      return registered;
    }

    test('başvuru kontenjandan çoksa TAM kontenjan kadar kayıt olur', () {
      // Ne aşım (mevcut kodun sorunu) ne de eksik: parça dolduğunda
      // sıradakine yürüdüğümüz için son yer de kullanılır.
      for (final int quota in <int>[1, 7, 50, 100, 500, 1000]) {
        expect(
          simulate(quota: quota, applicants: quota * 4),
          quota,
          reason: 'kontenjan $quota',
        );
      }
    });

    test('başvuru kontenjandan azsa herkes kaydolur', () {
      expect(simulate(quota: 500, applicants: 137), 137);
      expect(simulate(quota: 50, applicants: 1), 1);
    });

    test('tam kontenjan kadar başvuruda kimse boşta kalmaz', () {
      for (final int quota in <int>[4, 33, 200, 500]) {
        expect(simulate(quota: quota, applicants: quota), quota);
      }
    });
  });

  group('QuotaStatus', () {
    test('parçası olmayan etkinlikte takip yok', () {
      expect(QuotaStatus.untracked.isTracked, isFalse);
      expect(QuotaStatus.untracked.isFull, isFalse);
      // Takip yoksa "dolu" demek yanlış olurdu: eski etkinlikler kontenjansız
      // eski yoldan kaydediyor, kimseyi engellememeli.
      expect(
        const QuotaStatus(used: 0, capacity: 0, shardsFound: 0).isFull,
        isFalse,
      );
    });

    test('doluluk ve kalan yer', () {
      const QuotaStatus s = QuotaStatus(used: 75, capacity: 100, shardsFound: 16);
      expect(s.isTracked, isTrue);
      expect(s.isFull, isFalse);
      expect(s.remaining, 25);
      expect(s.percent, 75);
    });

    test('dolduğunda kalan 0, yüzde 100', () {
      const QuotaStatus s = QuotaStatus(used: 100, capacity: 100, shardsFound: 16);
      expect(s.isFull, isTrue);
      expect(s.remaining, 0);
      expect(s.percent, 100);
    });

    test('sayaç kontenjanı aşsa bile kalan negatif olmaz', () {
      // Olmaması gereken bir durum, ama gösterge "-3 yer kaldı" yazmamalı.
      const QuotaStatus s = QuotaStatus(used: 103, capacity: 100, shardsFound: 16);
      expect(s.remaining, 0);
      expect(s.percent, 100);
      expect(s.isFull, isTrue);
    });
  });

  group('quotaGateAction — kontenjan dolunca beklemeye alma', () {
    const QuotaStatus full = QuotaStatus(used: 100, capacity: 100, shardsFound: 16);
    const QuotaStatus open = QuotaStatus(used: 40, capacity: 100, shardsFound: 16);

    test('kontenjan dolunca kayıtlar beklemeye alınır', () {
      expect(
        quotaGateAction(
          status: full,
          registrationClosed: false,
          closedReason: '',
        ),
        QuotaGateAction.pause,
      );
    });

    test('zaten beklemedeyse tekrar yazılmaz', () {
      expect(
        quotaGateAction(
          status: full,
          registrationClosed: true,
          closedReason: ClosedReason.quotaFull,
        ),
        QuotaGateAction.none,
      );
    });

    test('yer açılınca KENDİ kapattığımız etkinlik geri açılır', () {
      expect(
        quotaGateAction(
          status: open,
          registrationClosed: true,
          closedReason: ClosedReason.quotaFull,
        ),
        QuotaGateAction.resume,
      );
    });

    test('kulübün ELLE durdurduğu etkinlik geri AÇILMAZ', () {
      // Bu ayrım olmasaydı kulüp kayıtları durdurur, uygulama hemen geri
      // açardı — kulübün kararı ezilirdi.
      expect(
        quotaGateAction(
          status: open,
          registrationClosed: true,
          closedReason: ClosedReason.manual,
        ),
        QuotaGateAction.none,
      );
    });

    test('sebebi yazılmamış eski kayıtlara dokunulmaz', () {
      expect(
        quotaGateAction(
          status: open,
          registrationClosed: true,
          closedReason: '',
        ),
        QuotaGateAction.none,
      );
    });

    test('parçası olmayan etkinlikte hiçbir şey yapılmaz', () {
      // Eski etkinlik: kontenjan takibi yok, bayrağa dokunmak yanlış olurdu.
      expect(
        quotaGateAction(
          status: QuotaStatus.untracked,
          registrationClosed: false,
          closedReason: '',
        ),
        QuotaGateAction.none,
      );
      expect(
        quotaGateAction(
          status: QuotaStatus.untracked,
          registrationClosed: true,
          closedReason: ClosedReason.quotaFull,
        ),
        QuotaGateAction.none,
      );
    });

    test('açık ve yer varken dokunulmaz', () {
      expect(
        quotaGateAction(
          status: open,
          registrationClosed: false,
          closedReason: '',
        ),
        QuotaGateAction.none,
      );
    });
  });

  group('AppLog', () {
    setUp(AppLog.clear);

    test('olay ve alanlar kaydedilir', () {
      AppLog.info('registration.ok', <String, Object?>{'shard': 3});
      expect(AppLog.records, hasLength(1));
      expect(AppLog.records.single.event, 'registration.ok');
      expect(AppLog.records.single.fields['shard'], 3);
    });

    test('seviye altındaki olaylar elenir', () {
      AppLog.minLevel = LogLevel.warn;
      AppLog.info('yok.sayilir');
      AppLog.warn('kaydedilir');
      expect(AppLog.records.map((LogRecord r) => r.event), <String>['kaydedilir']);
      AppLog.minLevel = LogLevel.debug;
    });

    test('önek ile süzülebilir', () {
      AppLog.info('registration.start');
      AppLog.info('event.created');
      AppLog.info('registration.ok');
      expect(AppLog.where('registration.'), hasLength(2));
    });

    test('tampon sınırlıdır — uzun kayıt fırtınası belleği yemez', () {
      for (int i = 0; i < 900; i++) {
        AppLog.info('registration.contended', <String, Object?>{'i': i});
      }
      expect(AppLog.records.length, lessThanOrEqualTo(500));
      // En YENİ olaylar tutulur, en eskiler düşer.
      expect(AppLog.records.last.fields['i'], 899);
    });

    test('dump JSONL üretir', () {
      AppLog.info('registration.ok', <String, Object?>{'rounds': 2});
      final String dump = AppLog.dump();
      expect(dump, contains('"event":"registration.ok"'));
      expect(dump, contains('"rounds":2'));
    });
  });
}
