import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/core/input_guard.dart';
import 'package:regipass/core/sanitize.dart';

/// Biçimlendirici zincirini tıpkı [TextField] gibi sırayla uygular.
String run(List<TextInputFormatter> formatters, String typed) {
  TextEditingValue value = TextEditingValue.empty;
  for (final TextInputFormatter formatter in formatters) {
    value = formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ),
    );
    typed = value.text;
  }
  return value.text;
}

void main() {
  group('SafeTextInputFormatter — XSS', () {
    final List<TextInputFormatter> guard = guardedInput(200);

    test('etiket sınırlayıcıları hiç geçemez', () {
      expect(run(guard, '<script>alert(1)</script>'), 'scriptalert(1)/script');
      expect(run(guard, '<img src=x onerror=alert(1)>'), 'img src=x onerror=alert(1)');
      expect(run(guard, '<iframe src="evil"></iframe>'), 'iframe src="evil"/iframe');
      expect(run(guard, '<>'), '');
    });

    test('çalıştırılabilir protokoller sökülür', () {
      expect(run(guard, 'javascript:alert(1)'), 'alert(1)');
      expect(run(guard, 'JavaScript : alert(1)').trim(), 'alert(1)');
      expect(run(guard, 'vbscript:msgbox(1)'), 'msgbox(1)');
      expect(run(guard, 'data:text/html;base64,PHN2Zz4='), ';base64,PHN2Zz4=');
    });

    test('elenen metin artık işaretleme değil', () {
      // Kutudan çıkan metin etiket kuramaz, dolayısıyla ne mobilde ne de
      // aynı kaydı okuyan web istemcisinde çalıştırılabilir bir şeye dönüşür.
      expect(detectHarmfulInput(run(guard, '<b>Kariyer</b> Günleri')), isFalse);
    });

    test('olay yakalayıcı kalıntısı kaydetme katmanında durdurulur', () {
      // `onload=` canlı elenmiyor: Türkçe'de "onay=" gibi masum yazımları
      // kullanıcının gözü önünde silerdi. Etiket sınırlayıcısı olmadan zaten
      // çalışamaz, kalan kalıntıyı da ikinci katman yakalıyor.
      const String attack = '<svg/onload=alert(1)>Kariyer Günleri';
      final String typed = run(guard, attack);

      expect(typed, isNot(contains('<')));
      expect(typed, isNot(contains('>')));
      expect(typed, contains('Kariyer Günleri'));

      expect(detectHarmfulInput(typed), isTrue);
      expect(sanitizeText(typed), isNot(contains('onload')));
    });

    test('görünmez karakterler atılır', () {
      // Sıfır genişlikli boşluk, bidi geçersiz kılma ve BOM: ekranda iz
      // bırakmadan kaydedilen değeri görünenden farklı hâle getirebiliyorlar.
      // Kaynağa çıplak yazılmıyorlar — dosyayı okuyan da göremezdi.
      for (final int codePoint in <int>[0x200B, 0x202E, 0xFEFF]) {
        final String hidden = String.fromCharCode(codePoint);
        expect(run(guard, 'Ali${hidden}Veli'), 'AliVeli');
      }
    });

    test('çift kod birimli karakterler bozulmaz', () {
      // Eleme kod birimi kod birimi ilerliyor; vekil çiftin (emoji) yarısını
      // düşürseydi geriye geçersiz bir dize kalırdı.
      final String emoji = String.fromCharCode(0xD83C) + String.fromCharCode(0xDF89);
      expect(run(guard, 'Kutlama $emoji'), 'Kutlama $emoji');
      expect(run(guard, '<b>$emoji</b>'), 'b$emoji/b');
    });

    test('meşru Türkçe metin bozulmaz', () {
      const String text = "Bilim & Teknoloji Kulübü — 2026'da 100. yıl etkinliği!";
      expect(run(guard, text), text);
    });

    test('tek satırlık alanda satır sonu boşluğa iner', () {
      expect(run(guard, 'Ali\nVeli'), 'Ali Veli');
    });

    test('çok satırlı alanda satır sonu korunur', () {
      expect(run(guardedInput(200, multiline: true), 'Ali\nVeli'), 'Ali\nVeli');
    });

    test('imleç elenen karakter kadar geri alınır', () {
      const SafeTextInputFormatter formatter = SafeTextInputFormatter();
      final TextEditingValue result = formatter.formatEditUpdate(
        const TextEditingValue(text: 'Ab'),
        const TextEditingValue(
          text: 'A<b>c',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(result.text, 'Abc');
      expect(result.selection.baseOffset, 3);
    });
  });

  group('Uzunluk sınırları', () {
    test('sınırı aşan metin kabul edilmez', () {
      expect(run(guardedInput(10), 'a' * 50).length, 10);
      expect(run(digitsInput(6), '1234567890'), '123456');
      expect(run(lengthOnlyInput(8), 'x' * 20).length, 8);
    });

    test('eleme kırpmadan önce yapılır — sınırdan yer çalınmaz', () {
      // Etiket önce silinir, kalan 5 karakter sınıra sığar.
      expect(run(guardedInput(5), '<b>Merhaba'), 'bMerh');
    });

    test('sayı kutuları yalnızca rakam alır', () {
      expect(run(digitsInput(9), '12a3<b>4'), '1234');
    });

    test('sınırdan uzun eski kayıt kesilmez, yalnızca kısalabilir', () {
      // Webden gelen 1800 karakterlik bir kulüp amacı mobilde düzenlemeye
      // açıldığında ilk tuşta kuyruğunu kaybetmemeli.
      const BoundedLengthTextInputFormatter limiter =
          BoundedLengthTextInputFormatter(10);
      final String existing = 'a' * 18;

      // Uzatan düzenleme reddedilir — metin olduğu gibi kalır.
      expect(
        limiter
            .formatEditUpdate(
              TextEditingValue(text: existing),
              TextEditingValue(text: '$existing b'),
            )
            .text,
        existing,
      );

      // Kısaltan düzenleme, sınırın hâlâ üstünde olsa bile geçer.
      expect(
        limiter
            .formatEditUpdate(
              TextEditingValue(text: existing),
              TextEditingValue(text: 'a' * 15),
            )
            .text,
        'a' * 15,
      );
    });

    test('sınırın içindeki alanda fazlalık kırpılır', () {
      const BoundedLengthTextInputFormatter limiter =
          BoundedLengthTextInputFormatter(10);
      expect(
        limiter
            .formatEditUpdate(
              const TextEditingValue(text: 'abc'),
              const TextEditingValue(text: 'abcdefghijklmno'),
            )
            .text,
        'abcdefghij',
      );
    });

    test('şifre alanı içeriğe dokunmaz — yalnızca uzunluk sınırlanır', () {
      // Şifre hiçbir belgeye yazılmıyor; temizlemek kullanıcıyı hesabından
      // eder, güvenlik faydası ise yok.
      const String password = 'A<b>c1!javascript:';
      expect(run(lengthOnlyInput(InputLimits.password), password), password);
    });
  });

  group('Sınır değerleri kaydetme katmanıyla uyumlu', () {
    test('alan sınırı, kaydederken kırpılan sınırın altında', () {
      // Aksi hâlde kullanıcının yazdığı metnin kuyruğu kaydederken sessizce
      // kesilir ve kimse nedenini anlamaz.
      expect(sanitizeName('a' * InputLimits.name).length, InputLimits.name);
      expect(
        sanitizeText('a' * InputLimits.title, maxLength: 200).length,
        InputLimits.title,
      );
      expect(
        sanitizeLongText('a' * InputLimits.longText).length,
        InputLimits.longText,
      );
    });
  });
}
