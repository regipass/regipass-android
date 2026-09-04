import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/paid_event_consent.dart';
import 'package:regipass/models/event.dart';

/// Ücretli etkinlik onay logu: kabul edilen metin ve saniyeye kadar inen
/// damga ETKİNLİK verisinde (etkinlik belgesi + kayıt belgesi) tutulur.
///
/// Şema WEB ile ortaktır (`paidConsentLog`); bu testler alan adlarını
/// sabitler — adlar değişirse web aynı logu okuyamaz.
void main() {
  final DateTime at = DateTime(2026, 9, 3, 14, 22, 7);

  group('onay damgasi', () {
    test('gun.ay.yil saat:dakika:saniye biciminde yazilir', () {
      expect(formatPaidEventConsentStamp(at), '03.09.2026 14:22:07');
    });

    test('tek haneli deger sifirla doldurulur', () {
      expect(
        formatPaidEventConsentStamp(DateTime(2026, 1, 5, 9, 4, 3)),
        '05.01.2026 09:04:03',
      );
    });
  });

  group('yazilan harita', () {
    test('web ile ayni anahtarlari tasir', () {
      final Map<String, Object?> map = PaidEventConsentAcceptance(
        role: PaidEventConsentRole.student,
        title: 'Ödeme Bilgilendirme Onayı',
        text: 'Onay metni.',
        checkboxLabel: 'Metni okudum ve kabul ediyorum.',
        language: 'tr',
        acceptedAt: at,
      ).toLogMap();

      expect(map.keys.toSet(), <String>{
        'approved',
        'text',
        'approvedAtMs',
        'approvedAtFormatted',
      });
      expect(map['approved'], isTrue);
      expect(map['text'], 'Onay metni.');
      expect(map['approvedAtMs'], at.millisecondsSinceEpoch);
      expect(map['approvedAtFormatted'], '03.09.2026 14:22:07');
    });

    test('alan adi iki belgede de paidConsentLog', () {
      expect(kPaidConsentLogField, 'paidConsentLog');
    });
  });

  group('log okuma', () {
    test('etkinlik belgesindeki kulup onayi okunur', () {
      final AppEvent event = AppEvent.fromMap('event-1', <String, dynamic>{
        'feeType': 'paid',
        'paidConsentLog': <String, dynamic>{
          'approved': true,
          'text': 'Kulüp onay metni.',
          'approvedAtMs': at.millisecondsSinceEpoch,
          'approvedAtFormatted': '03.09.2026 14:22:07',
        },
      });

      expect(event.clubConsentLog, isNotNull);
      expect(event.clubConsentLog!.approved, isTrue);
      expect(event.clubConsentLog!.stamp, '03.09.2026 14:22:07');
      expect(event.clubConsentLog!.text, 'Kulüp onay metni.');
    });

    test('ucretsiz etkinlikte onay logu bulunmaz', () {
      final AppEvent event = AppEvent.fromMap('event-2', <String, dynamic>{
        'feeType': 'free',
      });

      expect(event.clubConsentLog, isNull);
    });

    test('kayit belgesindeki ogrenci onayi okunur', () {
      final EventRegistration reg = EventRegistration.fromMap(
        'event-1_student-1',
        <String, dynamic>{
          'eventId': 'event-1',
          'studentId': 'student-1',
          'paidConsentLog': <String, dynamic>{
            'approved': true,
            'text': 'Öğrenci onay metni.',
            'approvedAtMs': at.millisecondsSinceEpoch,
            'approvedAtFormatted': '03.09.2026 14:22:07',
          },
        },
      );

      expect(reg.studentConsentLog, isNotNull);
      expect(reg.studentConsentLog!.stamp, '03.09.2026 14:22:07');
      expect(reg.studentConsentLog!.text, 'Öğrenci onay metni.');
    });

    test('okunabilir damga yoksa epoch alanindan turetilir', () {
      final EventRegistration reg = EventRegistration.fromMap(
        'event-1_student-4',
        <String, dynamic>{
          'eventId': 'event-1',
          'studentId': 'student-4',
          'paidConsentLog': <String, dynamic>{
            'approved': true,
            'text': 'Metin.',
            'approvedAtMs': at.millisecondsSinceEpoch,
          },
        },
      );

      expect(reg.studentConsentLog!.stamp, '03.09.2026 14:22:07');
    });

    // Web şeması benimsenmeden önce mobil düz alanlar yazıyordu; o kayıtlar
    // da log olarak görünmeli, yoksa geçmiş onaylar ekrandan kaybolur.
    test('eski duz alanli kayit da log olarak okunur', () {
      final EventRegistration reg = EventRegistration.fromMap(
        'event-1_student-2',
        <String, dynamic>{
          'eventId': 'event-1',
          'studentId': 'student-2',
          'paidEventStudentConsentVersion': 1,
          'paidEventStudentConsentAtMs': at.millisecondsSinceEpoch,
        },
      );

      expect(reg.studentConsentLog, isNotNull);
      expect(reg.studentConsentLog!.approved, isTrue);
      expect(reg.studentConsentLog!.text, isEmpty);
      expect(reg.studentConsentLog!.stamp, '03.09.2026 14:22:07');
    });

    test('onaysiz kayitta log null kalir', () {
      final EventRegistration reg = EventRegistration.fromMap(
        'event-1_student-3',
        <String, dynamic>{'eventId': 'event-1', 'studentId': 'student-3'},
      );

      expect(reg.studentConsentLog, isNull);
    });
  });
}
