import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/features/auth/auth_widgets.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/features/auth/forgot_password_screen.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/services/phone_hint_repository.dart';
import 'package:regipass/state/providers.dart';

/// Şifre sıfırlama kartı klavye açıkken görünür alana sığmalı.
///
/// Bildirilen hata: kullanıcı numarasını yazmaya başlayınca üstteki maskeli
/// numara ("+90 XXX XXX XX 67") ekrandan kayboluyordu. Sebep kaybolmak değil,
/// taşmaktı: kart klavyenin üstünde kalan pencereye sığmıyor, odaktaki alanı
/// görünür tutmak için içerik yukarı kaydırılıyor ve maske tepeden çıkıyordu.
/// Kart kısaltıldı (maske tek satır, klavye açıkken logo gizli); bu test
/// kartın yeniden uzamasını engeller.
class _FakeHints extends PhoneHintRepository {
  const _FakeHints();

  @override
  Future<PasswordResetHint> readHint(String email) async =>
      const PasswordResetHint(
        maskedPhone: '+90 XXX XXX XX 67',
        roles: <String>[UserRole.student],
      );
}

void main() {
  const double kScreenHeight = 700;
  const double kKeyboardHeight = 320;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, kScreenHeight);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneHintRepositoryProvider.overrideWithValue(const _FakeHints()),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(),
            home: const ForgotPasswordScreen(email: 'ogrenci@example.com'),
          ),
        ),
      ),
    );
    // `pumpAndSettle` kullanılmıyor: arka plan katmanı sürekli animasyonlu,
    // kare kuyruğu hiç boşalmıyor. Sabit sayıda kare yeterli.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Sabit sayıda kare: hem zamanlayıcıları tetikler hem başlattıkları
  /// animasyonları ilerletir. (`pumpAndSettle` kullanılamıyor — arka plan
  /// katmanı sürekli animasyonlu, kare kuyruğu hiç boşalmıyor.)
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('klavye açıkken maskeli numara ekranda kalır', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    final Finder mask = find.textContaining('XX 67', findRichText: true);
    expect(mask, findsOneWidget, reason: 'maske hiç çizilmemiş');

    // Kullanıcı numarayı yazmak için alana dokunuyor: klavye açılır.
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboardHeight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    const double visibleBottom = kScreenHeight - kKeyboardHeight;
    final Rect maskRect = tester.getRect(mask);

    expect(
      maskRect.top,
      greaterThanOrEqualTo(0),
      reason: 'maske ekranın üstünden taşmış',
    );
    expect(
      maskRect.bottom,
      lessThanOrEqualTo(visibleBottom),
      reason: 'maske klavyenin altında kalmış',
    );
  });

  testWidgets('klavye açıkken "kod gönder" düğmesi görünür alanda kalır', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    // Kullanıcı numarayı yazmak için alana dokunuyor: klavye açılır.
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboardHeight);
    await tester.pump();
    await settle(tester);

    const double visibleBottom = kScreenHeight - kKeyboardHeight;
    final Rect button = tester.getRect(find.byType(AuthPrimaryButton));

    // Bildirilen arıza: düğme y=392..444 aralığındaydı, görünür alan ise
    // 380'de bitiyordu. Dokunuş düğmeye hiç ulaşmıyor, hiçbir şey olmuyordu.
    expect(
      button.bottom,
      lessThanOrEqualTo(visibleBottom),
      reason: 'düğme klavyenin altında kalıyor — kullanıcı basamıyor',
    );

    // Sadece konumu değil, dokunuşun gerçekten düğmeye ulaştığını da doğrula:
    // düğmenin merkezindeki isabet testi düğmeye ulaşmalı.
    final Offset center = tester.getCenter(find.byType(AuthPrimaryButton));
    final HitTestResult hit = tester.hitTestOnBinding(center);
    expect(
      hit.path.any(
        (HitTestEntry<HitTestTarget> e) =>
            e.target is RenderBox &&
            find.byType(AuthPrimaryButton).evaluate().any(
              (Element el) => el.renderObject == e.target,
            ),
      ),
      isTrue,
      reason: 'dokunuş düğmeye ulaşmıyor — araya başka bir katman giriyor',
    );
  });

  testWidgets('hata mesajı gösterilince klavye kapanır', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboardHeight);
    await tester.pump();
    await settle(tester);

    // Numara eksikken gönderiliyor: ekran hata göstermeli.
    await tester.tap(find.byType(AuthPrimaryButton));
    await tester.pump();
    await settle(tester);

    expect(find.byType(AuthFeedback), findsOneWidget);

    // Mesaj kartın en üstünde; klavye açık kalırsa görünür alana girmiyor.
    // Bu yüzden hata gösterilirken klavye kapatılıyor.
    expect(
      tester.testTextInput.isVisible,
      isFalse,
      reason: 'klavye açık kaldı — hata mesajı ekranın dışında kalıyor',
    );
  });
}
