// İP-W: cüzdan düğmeleri — ayar kapalıyken (şu an) görünmez; açıkken cihaza göre.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/wallet.dart';
import 'package:regipass/features/shared/wallet_buttons.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/services/wallet_service.dart';

Widget _wrap(Widget child, Map<String, Object?> config) => ProviderScope(
  overrides: <Override>[
    walletConfigProvider.overrideWith((Ref ref) async => config),
  ],
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);

void main() {
  test('ayar + cihaz → düğmeler', () {
    const Map<String, Object?> on = <String, Object?>{
      'apple': true,
      'google': true,
    };
    expect(walletButtonsFor(null, isIos: true, isAndroid: false), isEmpty);
    expect(
      walletButtonsFor(
        const <String, Object?>{'apple': false, 'google': false},
        isIos: false,
        isAndroid: true,
      ),
      isEmpty,
    );
    expect(
      walletButtonsFor(on, isIos: true, isAndroid: false),
      <WalletPlatform>[WalletPlatform.apple],
    );
    expect(
      walletButtonsFor(on, isIos: false, isAndroid: true),
      <WalletPlatform>[WalletPlatform.google],
    );
    expect(walletAllowed(cancelled: false, paymentPending: true), isFalse);
    expect(isSafeWalletUrl('https://pay.google.com/gp/v/save/x'), isTrue);
    expect(isSafeWalletUrl('https://evil.example/pass'), isFalse);
    expect(walletErrorKey('wallet-not-configured'), 'wallet.error.disabled');
  });

  testWidgets('kapalı ayarda hiçbir düğme yok', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        const WalletButtons(
          registrationId: 'e1_s',
          cancelled: false,
          paymentPending: false,
          platformOverride: TargetPlatform.iOS,
        ),
        const <String, Object?>{'apple': false, 'google': false},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('açık ayarda iPhone: Apple, Android: Google', (
    WidgetTester tester,
  ) async {
    const Map<String, Object?> on = <String, Object?>{
      'apple': true,
      'google': true,
    };
    await tester.pumpWidget(
      _wrap(
        const WalletButtons(
          registrationId: 'e1_s',
          cancelled: false,
          paymentPending: false,
          platformOverride: TargetPlatform.iOS,
        ),
        on,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Apple Cüzdan'a ekle"), findsOneWidget);
    expect(find.text("Google Cüzdan'a ekle"), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const WalletButtons(
          registrationId: 'e1_s',
          cancelled: false,
          paymentPending: false,
          platformOverride: TargetPlatform.android,
        ),
        on,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Google Cüzdan'a ekle"), findsOneWidget);
  });
}
