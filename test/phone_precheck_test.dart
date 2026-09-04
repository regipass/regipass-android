import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/phone_precheck.dart';

/// SMS gönderilmeden önceki yapı denetimi: numara gerçekten o ülkenin cep
/// numarası mı? (bkz. lib/domain/phone_precheck.dart)
void main() {
  group('countryForE164', () {
    test('arama kodunu doğru eşler', () {
      expect(countryForE164('+905551234567')?.code, 'TR');
      expect(countryForE164('+4915112345678')?.code, 'DE');
    });

    test('aynı kodu paylaşan ülkelerde sonuç kararlıdır', () {
      // NANP'nin tamamı "+1": hangi ülkenin döndüğü veri dosyasındaki sıraya
      // bağlıdır ve çalışmadan çalışmaya değişmemelidir (List.sort kararlı
      // değil — bkz. _sortedByDialLength).
      final String? first = countryForE164('+15551234567')?.code;
      expect(first, isNotNull);
      expect(countryForE164('+15559876543')?.code, first);
      expect(countryForE164('+15551234567')?.dial, '+1');
    });

    test('E.164 olmayan değerde null', () {
      expect(countryForE164('05551234567'), isNull);
      expect(countryForE164(''), isNull);
      expect(countryForE164(null), isNull);
    });
  });

  group('checkPhoneNumber', () {
    test('geçerli Türkiye cep numarası geçer', () {
      final PhoneNumberCheck check = checkPhoneNumber('+905551234567');

      expect(check.isOk, isTrue);
      expect(check.country?.code, 'TR');
      expect(check.nationalDigits, '5551234567');
    });

    test('ülke kodu çözülemezse unknownCountry', () {
      expect(
        checkPhoneNumber('05551234567').issue,
        PhoneNumberIssue.unknownCountry,
      );
    });

    test('eksik hane digitCount döndürür', () {
      final PhoneNumberCheck check = checkPhoneNumber('+90555123');

      expect(check.issue, PhoneNumberIssue.digitCount);
      expect(check.expectedDigits, '10');
    });

    test('fazla hane digitCount döndürür', () {
      expect(
        checkPhoneNumber('+9055512345678').issue,
        PhoneNumberIssue.digitCount,
      );
    });

    test('sabit hat operatorPrefix döndürür', () {
      // 212 İstanbul sabit hattı: hane sayısı doğru, ön ek cep değil.
      expect(
        checkPhoneNumber('+902121234567').issue,
        PhoneNumberIssue.operatorPrefix,
      );
    });

    test('tahsis edilmemiş cep bloğu operatorPrefix döndürür', () {
      expect(
        checkPhoneNumber('+905121234567').issue,
        PhoneNumberIssue.operatorPrefix,
      );
    });

    test('ön ek verisi olmayan ülkede yalnızca hane sayısı denetlenir', () {
      // Almanya tabloda yok: doğru uzunluktaki numara ön ek denetimine
      // takılmamalı (eksik listeyle gerçek numarayı bloklamayız).
      expect(checkPhoneNumber('+4915112345678').isOk, isTrue);
    });

    test('denetim sırası: önce hane sayısı, sonra ön ek', () {
      // Hem kısa hem yanlış ön ekli numarada kullanıcıya önce uzunluk
      // söylenir; ön ek uyarısı tamamlanmamış numarada yanıltıcı olurdu.
      expect(checkPhoneNumber('+90212').issue, PhoneNumberIssue.digitCount);
    });
  });

  group('mobil ön ek eşleştirme', () {
    test('tamamlanmış numarada startsWith denetimi', () {
      expect(matchesMobilePrefix('5551234567', 'TR'), isTrue);
      expect(matchesMobilePrefix('2121234567', 'TR'), isFalse);
    });

    test('verisi olmayan ülkede her numara kabul edilir', () {
      expect(matchesMobilePrefix('15112345678', 'DE'), isTrue);
    });

    test('yazılırken eksik ön ek çakışma sayılmaz', () {
      expect(conflictsWithMobilePrefix('', 'TR'), isFalse);
      expect(conflictsWithMobilePrefix('5', 'TR'), isFalse);
      expect(conflictsWithMobilePrefix('55', 'TR'), isFalse);
    });

    test('ilk uyumsuz hanede çakışma bildirilir', () {
      expect(conflictsWithMobilePrefix('2', 'TR'), isTrue);
      expect(conflictsWithMobilePrefix('51', 'TR'), isTrue);
    });

    test('ön ekler kullanıcıya listelenebilir', () {
      expect(describeMobilePrefixes('TR'), '50, 53, 54, 55, 56');
      expect(describeMobilePrefixes('DE'), '');
    });
  });
}
