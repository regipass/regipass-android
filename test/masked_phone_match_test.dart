import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/masked_phone_match.dart';
import 'package:regipass/features/shared/phone_field.dart';

/// `functions/passwordResetHint.js#maskAuthPhone` biçiminin Dart karşılığı.
/// Cloud Function'ın ürettiği maske TR dışında istemcinin ürettiğinden
/// farklı (arama kodunu da gizliyor); denetim ikisini de tanımak zorunda.
String cloudFunctionMask(String e164) {
  if (RegExp(r'^\+90\d{10}$').hasMatch(e164)) {
    return '+90 XXX XXX XX ${e164.substring(e164.length - 2)}';
  }
  return '+${'X' * (e164.length - 3)}${e164.substring(e164.length - 2)}';
}

void main() {
  group('parseMaskedPhone', () {
    test('TR maskesi arama kodunu, hane sayısını ve son haneleri verir', () {
      final MaskedPhoneHint hint = parseMaskedPhone('+90 XXX XXX XX 67')!;
      expect(hint.dial, '+90');
      expect(hint.nationalDigitCount, 10);
      expect(hint.totalDigitCount, 12);
      expect(hint.visibleSuffix, '67');
    });

    test('arama kodu gizliyse yalnızca toplam hane ve son haneler kalır', () {
      final MaskedPhoneHint hint = parseMaskedPhone('+XXXXXXXXX71')!;
      expect(hint.dial, isNull);
      expect(hint.totalDigitCount, 11);
      expect(hint.visibleSuffix, '71');
    });

    test('maske olmayan girdiler reddedilir', () {
      // Maske karakteri yok: ham numara ya da bozuk veri — güvenilmez.
      expect(parseMaskedPhone('+905551234567'), isNull);
      expect(parseMaskedPhone('905551234567'), isNull);
      expect(parseMaskedPhone(''), isNull);
      expect(parseMaskedPhone(null), isNull);
    });

    test('küçük x ve farklı ayraçlar aynı sonucu verir', () {
      for (final String masked in <String>[
        '+90 XXX XXX XX 67',
        '+90xxxxxxxx67',
        '+90-XXX-XXX-XX-67',
        '  +90 (XXX) XXX XX 67  ',
      ]) {
        final MaskedPhoneHint hint = parseMaskedPhone(masked)!;
        expect(hint.dial, '+90', reason: masked);
        expect(hint.nationalDigitCount, 10, reason: masked);
        expect(hint.visibleSuffix, '67', reason: masked);
      }
    });
  });

  group('matchHintPhone — TR', () {
    const String masked = '+90 XXX XXX XX 67';

    test('kayıtlı numaranın kendisi geçer', () {
      expect(
        matchHintPhone(hint: masked, typedE164: '+905551234567'),
        isNull,
      );
    });

    test('son iki hane tutuyorsa geçer (maskenin gizlediği kısım bilinmez)', () {
      expect(
        matchHintPhone(hint: masked, typedE164: '+905339998867'),
        isNull,
      );
    });

    test('son hane farklıysa SMS gönderilmez', () {
      expect(
        matchHintPhone(hint: masked, typedE164: '+905551234568'),
        MaskedPhoneMismatch.suffix,
      );
      expect(
        matchHintPhone(hint: masked, typedE164: '+905551234576'),
        MaskedPhoneMismatch.suffix,
      );
    });

    test('başka ülkenin numarası ülke uyuşmazlığı verir', () {
      expect(
        matchHintPhone(hint: masked, typedE164: '+4915112345667'),
        MaskedPhoneMismatch.country,
      );
      expect(
        matchHintPhone(hint: masked, typedE164: '+15551234567'),
        MaskedPhoneMismatch.country,
      );
    });

    test('yapısal olarak bozuk numara burada rapor edilmez', () {
      // Hane sayısı/ön ek hatasını `phoneStructureError` kendi mesajıyla
      // veriyor; aynı hata iki kez gösterilmesin.
      expect(matchHintPhone(hint: masked, typedE164: '5551234567'), isNull);
      expect(matchHintPhone(hint: masked, typedE164: '+90'), isNull);
      expect(matchHintPhone(hint: masked, typedE164: ''), isNull);
    });

    test('maske yoksa engelleme yok', () {
      expect(matchHintPhone(hint: null, typedE164: '+905551234567'), isNull);
      expect(matchHintPhone(hint: '', typedE164: '+905551234567'), isNull);
    });
  });

  group('matchHintPhone — hane sayısı', () {
    test('arama kodu aynı, hane sayısı farklıysa yakalanır', () {
      // DE 10-11 hane kabul ediyor: aynı ülkede iki farklı uzunluk mümkün.
      const String masked = '+49 XXX XXX XXX 67'; // 11 hane
      expect(
        matchHintPhone(hint: masked, typedE164: '+4915112345667'),
        isNull,
      );
      expect(
        matchHintPhone(hint: masked, typedE164: '+491511234567'),
        MaskedPhoneMismatch.length,
      );
    });

    test('arama kodu gizliyken toplam uzunluk ölçüt olur', () {
      const String masked = '+XXXXXXXXX71'; // 11 hane, arama kodu dâhil
      expect(
        matchHintPhone(hint: masked, typedE164: '+14155552671'),
        isNull,
      );
      // +90 5xx xxx xx 71 -> 12 hane: uzunluk tutmaz.
      expect(
        matchHintPhone(hint: masked, typedE164: '+905551234571'),
        MaskedPhoneMismatch.length,
      );
    });

    test('arama kodu gizliyken son haneler yine denetlenir', () {
      expect(
        matchHintPhone(hint: '+XXXXXXXXX71', typedE164: '+14155552672'),
        MaskedPhoneMismatch.suffix,
      );
    });
  });

  group('üretilen maskelerle uçtan uca', () {
    // Denetimin ölçütü, maskeyi ÜRETEN kodun çıktısı olmak zorunda. Maske
    // biçimi değişirse (ör. gruplama) bu testler kırılır — sessizce herkesi
    // kurtarma akışından atan bir değişiklik fark edilmeden geçmesin.
    const List<String> numbers = <String>[
      '+905551234567',
      '+905339998800',
      '+14155552671',
      '+4915112345667',
      '+994501234567',
    ];

    test('istemci maskesi kendi numarasını geçirir', () {
      for (final String number in numbers) {
        final String masked = maskE164ForDisplay(number);
        expect(masked, isNotEmpty, reason: number);
        expect(
          matchHintPhone(hint: masked, typedE164: number),
          isNull,
          reason: '$number -> $masked',
        );
      }
    });

    test('Cloud Function maskesi kendi numarasını geçirir', () {
      for (final String number in numbers) {
        final String masked = cloudFunctionMask(number);
        expect(
          matchHintPhone(hint: masked, typedE164: number),
          isNull,
          reason: '$number -> $masked',
        );
      }
    });

    test('istemci maskesi listedeki diğer numaraların hepsini reddeder', () {
      for (final String owner in numbers) {
        final String masked = maskE164ForDisplay(owner);
        for (final String other in numbers) {
          if (other == owner) continue;
          expect(
            matchHintPhone(hint: masked, typedE164: other),
            isNotNull,
            reason: 'maske $masked ($owner) numarayı geçirdi: $other',
          );
        }
      }
    });

    test(
      'Cloud Function maskesi, TR dışında yalnızca uzunluk+son hane ayırt eder',
      () {
        // Bilinen sınır: `functions/passwordResetHint.js#maskAuthPhone` TR
        // dışındaki numaralarda arama kodunu da gizliyor (`+XXXXXXXXX71`),
        // istemcinin ürettiği maske ise gizlemiyor (`+1 XXX XXX XX7 1`).
        // Arama kodu okunamayınca ülke denetimi yapılamaz; geriye toplam hane
        // sayısı ve son haneler kalır. Bu yüzden "aynı toplam uzunluk + aynı
        // son iki hane" olan BAŞKA ülkenin numarası bu maskeden geçebilir.
        //
        // Pratikte dar bir boşluk: bu maske yalnızca Firestore ipucu hiç
        // yazılmamışsa yedek olarak okunuyor, TR numaralarında iki biçim de
        // aynı ve son söz hâlâ SMS sonrası e-posta eşleşmesinde. Test bu
        // boşluğun TAM olarak bu kadar olduğunu sabitler — genişlerse kırılır.
        int slipped = 0;
        for (final String owner in numbers) {
          final String masked = cloudFunctionMask(owner);
          for (final String other in numbers) {
            if (other == owner) continue;
            final bool sameShape =
                other.length == owner.length &&
                other.substring(other.length - 2) ==
                    owner.substring(owner.length - 2);
            final MaskedPhoneMismatch? result = matchHintPhone(              hint: masked,
              typedE164: other,
            );
            if (result == null) {
              slipped++;
              expect(
                sameShape,
                isTrue,
                reason:
                    'maske $masked ($owner) beklenmedik numarayı geçirdi: '
                    '$other',
              );
              // TR numarasının maskesi arama kodunu gösterdiği için asla
              // sızdırmamalı.
              expect(owner.startsWith('+90'), isFalse, reason: owner);
            }
          }
        }
        // Boşluğun gerçekten var olduğunu da doğrula: sıfırsa test artık
        // hiçbir şey ölçmüyor demektir.
        expect(slipped, greaterThan(0));
      },
    );

    test('son hanesi değiştirilmiş numara her zaman reddedilir', () {
      for (final String number in numbers) {
        final String last = number.substring(number.length - 1);
        final String flipped =
            number.substring(0, number.length - 1) +
            (last == '0' ? '1' : '0');
        for (final String masked in <String>[
          maskE164ForDisplay(number),
          cloudFunctionMask(number),
        ]) {
          expect(
            matchHintPhone(hint: masked, typedE164: flipped),
            MaskedPhoneMismatch.suffix,
            reason: '$masked vs $flipped',
          );
        }
      }
    });
  });

  group('maskesiz ipucu — birebir karşılaştırma', () {
    // kRevealPasswordResetPhone açıkken ipucu tam numara taşıyor. O zaman
    // maskenin gizlediği ORTADAKİ haneler de denetlenir: "başı yanlış, son
    // iki hanesi doğru" numara artık geçemez.
    const String full = '+905551234567';

    test('ipucu tam numara olarak tanınır', () {
      expect(fullPhoneFromHint(full), '+905551234567');
      expect(fullPhoneFromHint('+90 555 123 45 67'), '+905551234567');
      expect(fullPhoneFromHint('+90 XXX XXX XX 67'), isNull);
      expect(fullPhoneFromHint('905551234567'), isNull);
      expect(fullPhoneFromHint(''), isNull);
      expect(fullPhoneFromHint(null), isNull);
    });

    test('numaranın kendisi geçer', () {
      expect(matchHintPhone(hint: full, typedE164: full), isNull);
      expect(
        matchHintPhone(hint: '+90 555 123 45 67', typedE164: full),
        isNull,
      );
    });

    test('son iki hanesi doğru ama başı yanlış numara ARTIK geçmez', () {
      // Maskeli kipte bu numara geçiyordu; bildirilen sorun buydu.
      expect(
        matchHintPhone(hint: '+90 XXX XXX XX 67', typedE164: '+905339998867'),
        isNull,
      );
      expect(
        matchHintPhone(hint: full, typedE164: '+905339998867'),
        MaskedPhoneMismatch.exact,
      );
    });

    test('tek hane farkı bile yakalanır', () {
      for (int i = 3; i < full.length; i++) {
        final String digit = full[i];
        final String flipped =
            full.substring(0, i) +
            (digit == '0' ? '1' : '0') +
            full.substring(i + 1);
        if (flipped == full) continue;
        expect(
          matchHintPhone(hint: full, typedE164: flipped),
          MaskedPhoneMismatch.exact,
          reason: flipped,
        );
      }
    });

    test('başka ülke ve farklı uzunluk da birebir kipte yakalanır', () {
      expect(
        matchHintPhone(hint: full, typedE164: '+15551234567'),
        MaskedPhoneMismatch.exact,
      );
      expect(
        matchHintPhone(hint: full, typedE164: '+90555123456'),
        MaskedPhoneMismatch.exact,
      );
    });

    test('yapısal olarak bozuk numara birebir kipte de rapor edilmez', () {
      expect(matchHintPhone(hint: full, typedE164: '5551234567'), isNull);
      expect(matchHintPhone(hint: full, typedE164: ''), isNull);
    });

    test('passwordResetHintPhone maskesiz kipte tam E.164 üretir', () {
      // Anahtar açıkken ipucunu yazan üç ekran da bunu kullanıyor.
      expect(passwordResetHintPhone('+905551234567'), '+905551234567');
      expect(passwordResetHintPhone('+90 555 123 45 67'), '+905551234567');
      expect(passwordResetHintPhone('5551234567'), '');
      expect(passwordResetHintPhone(null), '');
      // Ürettiği değer kendi numarasını geçirmeli.
      expect(
        matchHintPhone(
          hint: passwordResetHintPhone('+905551234567'),
          typedE164: '+905551234567',
        ),
        isNull,
      );
    });
  });
}
