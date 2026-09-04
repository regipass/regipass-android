import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/features/auth/auth_widgets.dart';
import 'package:regipass/features/shared/phone_field.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Giriş sahnesinde klavye açıldığında telefon alanı klavyenin altında
/// kalmamalı.
///
/// Ekranların `Scaffold`'u `resizeToAvoidBottomInset: false` kullanıyor (arka
/// plan katmanları klavyeyle birlikte ezilmesin diye); klavye payını
/// [AuthFixedBody] kendisi veriyor. Pay kaydırma görünümünün İÇİNE verildiği
/// sürece görünür pencere klavyenin altına uzanıyordu: Flutter odaktaki alanı
/// "zaten görünüyor" sayıyor, kullanıcı ise yazdığı numarayı göremiyordu.
void main() {
  const double kScreenHeight = 700;
  const double kKeyboardHeight = 320;

  Future<PhoneFieldController> pumpScene(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, kScreenHeight);
    addTearDown(tester.view.reset);

    final PhoneFieldController controller = PhoneFieldController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      LanguageScope(
        language: 'tr',
        child: MaterialApp(
          theme: buildRegipassTheme(),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: AuthFixedBody(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Kartın telefon alanının üstünde kalan kısmı
                          // (logo + başlık + açıklama) kadar yer.
                          const SizedBox(height: 380),
                          PhoneField(controller: controller),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return controller;
  }

  testWidgets('klavye açılınca telefon alanı klavyenin üstüne çekilir', (
    WidgetTester tester,
  ) async {
    await pumpScene(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    // Klavye açılıyor: yalnızca bu değişim düzeni oynatmalı.
    tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboardHeight);
    await tester.pumpAndSettle();

    final Rect field = tester.getRect(find.byType(PhoneField));
    expect(
      field.bottom,
      lessThanOrEqualTo(kScreenHeight - kKeyboardHeight),
      reason: 'telefon alanı klavyenin altında kalıyor',
    );
    expect(field.top, greaterThanOrEqualTo(0));
  });

  testWidgets('klavye kapalıyken düzen ortalanmış kalır', (
    WidgetTester tester,
  ) async {
    await pumpScene(tester);
    await tester.pumpAndSettle();

    // Kaydırma yok: içerik ekrana sığıyor ve alan olduğu yerde duruyor.
    final Rect field = tester.getRect(find.byType(PhoneField));
    expect(field.bottom, lessThanOrEqualTo(kScreenHeight));
    expect(
      tester
          .widget<Scrollable>(find.byType(Scrollable).first)
          .controller
          ?.hasClients,
      anyOf(isNull, isTrue),
    );
  });
}
