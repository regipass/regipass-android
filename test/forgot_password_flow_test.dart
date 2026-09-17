import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/features/auth/auth_widgets.dart';
import 'package:regipass/features/shared/phone_field.dart';
import 'package:regipass/features/auth/forgot_password_screen.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/services/password_reset_auth_session.dart';
import 'package:regipass/services/phone_hint_repository.dart';
import 'package:regipass/state/providers.dart';

class _Hints extends PhoneHintRepository {
  final Completer<PasswordResetHint>? pending;
  final PasswordResetHint hint;
  const _Hints([
    this.pending,
    this.hint = const PasswordResetHint(
      maskedPhone: '+90 XXX XXX XX 67',
      roles: [],
    ),
  ]);
  @override
  Future<PasswordResetHint> readHint(String email) async =>
      pending != null ? pending!.future : hint;

  @override
  Future<bool> matchesAccountPhone({
    required String email,
    required String phoneE164,
  }) async => phoneE164 == '+905551234567' || phoneE164 == '+4915112345667';
}

class _PendingCheck extends _Hints {
  final result = Completer<bool>();
  int calls = 0;
  String? checkedEmail;
  String? checkedPhone;

  @override
  Future<bool> matchesAccountPhone({
    required String email,
    required String phoneE164,
  }) {
    calls++;
    checkedEmail = email;
    checkedPhone = phoneE164;
    return result.future;
  }
}

class _User implements User {
  _User(this.email);
  @override
  final String? email;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(String email) : user = _User(email);
  @override
  final User user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ResetSession extends PasswordResetAuthSession {
  late PhoneVerificationCompleted completed;
  late PhoneVerificationFailed failed;
  late PhoneCodeSent sent;
  late PhoneCodeAutoRetrievalTimeout autoTimeout;
  final Completer<UserCredential> signInResult = Completer<UserCredential>();
  final Completer<void> saveResult = Completer<void>();
  int signInCalls = 0;
  bool closed = false;
  int? resendToken;
  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    completed = verificationCompleted;
    failed = verificationFailed;
    sent = codeSent;
    autoTimeout = codeAutoRetrievalTimeout;
    resendToken = forceResendingToken;
  }

  @override
  Future<UserCredential> signIn(PhoneAuthCredential credential) {
    signInCalls++;
    return signInResult.future;
  }

  @override
  Future<void> updatePassword(String password) => saveResult.future;
  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  late List<_ResetSession> sessions;
  final PhoneAuthCredential credential = PhoneAuthProvider.credential(
    verificationId: 'id',
    smsCode: '123456',
  );

  Future<void> frames(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> screen(
    WidgetTester tester, {
    PhoneHintRepository hints = const _Hints(),
    String number = '5551234567',
  }) async {
    sessions = [];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 850);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneHintRepositoryProvider.overrideWithValue(hints),
          passwordResetSessionFactoryProvider.overrideWithValue(() {
            final session = _ResetSession();
            sessions.add(session);
            return session;
          }),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(),
            home: const ForgotPasswordScreen(email: ' Test@Example.com '),
          ),
        ),
      ),
    );
    await frames(tester);
    await tester.enterText(find.byType(TextField).first, number);
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byType(AuthPrimaryButton).first);
    await frames(tester);
  }

  bool loading(WidgetTester tester) => tester
      .widget<AuthPrimaryButton>(find.byType(AuthPrimaryButton).first)
      .loading;

  testWidgets('sunucu onayi beklenir ve tekrar gonder tek sorguda kalir', (
    tester,
  ) async {
    final hints = _PendingCheck();
    await screen(tester, hints: hints);
    await send(tester);
    await send(tester);
    expect(hints.calls, 1);
    expect(hints.checkedEmail, ' Test@Example.com ');
    expect(hints.checkedPhone, '+905551234567');
    expect(sessions, isEmpty);
    hints.result.complete(true);
    await frames(tester);
    expect(sessions, hasLength(1));
  });

  testWidgets('sunucu sorgusu hata verirse SMS gonderilmez', (tester) async {
    final hints = _PendingCheck();
    await screen(tester, hints: hints);
    await send(tester);
    hints.result.completeError(
      FirebaseException(plugin: 'cloud_functions', code: 'unavailable'),
    );
    await frames(tester);
    expect(sessions, isEmpty);
    expect(loading(tester), isFalse);
    expect(find.byType(AuthFeedback), findsOneWidget);
  });

  testWidgets('sunucu zaman asimi sonrasi gec onay SMS baslatamaz', (
    tester,
  ) async {
    final hints = _PendingCheck();
    await screen(tester, hints: hints);
    await send(tester);
    await tester.pump(const Duration(seconds: 10));
    await frames(tester);
    expect(sessions, isEmpty);
    expect(loading(tester), isFalse);
    hints.result.complete(true);
    await frames(tester);
    expect(sessions, isEmpty);
  });

  testWidgets('ekran kapandiktan sonra sunucu onayi SMS baslatamaz', (
    tester,
  ) async {
    final hints = _PendingCheck();
    await screen(tester, hints: hints);
    await send(tester);
    await tester.pumpWidget(const SizedBox());
    hints.result.complete(true);
    await frames(tester);
    expect(sessions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'geciken ipucu beklenir, gelince numara dogrulanip SMS gonderilir',
    (tester) async {
      final pending = Completer<PasswordResetHint>();
      await screen(tester, hints: _Hints(pending));
      await send(tester);
      // Maske denetimi yapılamadan SMS gitmez: ipucu beklenir.
      expect(sessions, isEmpty);
      expect(loading(tester), isTrue);
      pending.complete(
        const PasswordResetHint(maskedPhone: '+90 XXX XXX XX 67', roles: []),
      );
      await frames(tester);
      expect(sessions, hasLength(1));
      expect(loading(tester), isTrue);
      expect(find.textContaining('XX 67', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(seconds: 76));
      await frames(tester);
      expect(loading(tester), isFalse);
      expect(
        find.textContaining('SMS isteği zamanında yanıtlanmadı'),
        findsOneWidget,
      );
    },
  );

  // --- SMS ONCESI MASKE DENETIMI ---------------------------------------
  //
  // Bu blogun tamaminda olculen tek sey su: `sessions` bos kalmali.
  // `sessions` yalnizca `passwordResetSessionFactoryProvider` cagrildiginda
  // doluyor, o da `verifyPhoneNumber`in tek yolu — yani bos liste "SMS
  // istegi hic yapilmadi" demek.

  testWidgets('maskeyle uyusmayan son hane SMS istegini hic baslatmaz', (
    tester,
  ) async {
    await screen(tester, number: '5551234568'); // kayitli: ...67
    await send(tester);
    expect(sessions, isEmpty);
    expect(loading(tester), isFalse);
    expect(find.textContaining('kayıtlı numaranla uyuşmuyor'), findsOneWidget);
    // Maske hata metninde de duruyor ki kullanici karsilastirabilsin.
    expect(find.textContaining('+90 XXX XXX XX 67'), findsWidgets);
  });

  testWidgets('yanlis ulke kodu kendi mesajiyla ve SMS gondermeden durur', (
    tester,
  ) async {
    await screen(
      tester,
      hints: const _Hints(
        null,
        PasswordResetHint(maskedPhone: '+49 XXX XXX XXX 67', roles: []),
      ),
      number: '5551234567',
    );
    await send(tester);
    expect(sessions, isEmpty);
    expect(find.textContaining('Ülke kodu'), findsOneWidget);
  });

  testWidgets('ayni ulkede hane sayisi tutmayan numara durur, tutan gecer', (
    tester,
  ) async {
    // Almanya 10-11 hane kabul ediyor: ayni ulkede iki farkli uzunluk
    // mumkun, yani uzunluk denetimi tek basina is goruyor.
    await screen(
      tester,
      hints: const _Hints(
        null,
        PasswordResetHint(maskedPhone: '+49 XXX XXX XXX 67', roles: []),
      ),
    );
    tester
        .widget<PhoneField>(find.byType(PhoneField))
        .controller
        .selectCountry(findCountry('DE'));
    await frames(tester);

    await tester.enterText(find.byType(TextField).first, '1511234567'); // 10
    await send(tester);
    expect(sessions, isEmpty);
    expect(find.textContaining('hane sayısı'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '15112345667'); // 11
    await send(tester);
    expect(sessions, hasLength(1));
  });

  testWidgets('dogru numara eskisi gibi SMS istegini baslatir', (tester) async {
    await screen(tester, number: '5551234567');
    await send(tester);
    expect(sessions, hasLength(1));
    expect(find.textContaining('uyuşmuyor'), findsNothing);
  });

  testWidgets(
    'maskenin gizledigi hane farkliysa sunucu SMS gonderimini engeller',
    (tester) async {
      // Son iki hane aynı olsa bile sunucu tam numarayı karşılaştırır.
      await screen(tester, number: '5339998867');
      await send(tester);
      expect(sessions, isEmpty);
      expect(
        find.textContaining('bu e-posta adresine kayıtlı değil'),
        findsOneWidget,
      );
    },
  );

  testWidgets('hesapta telefon yoksa SMS istenmeden aciklama gosterilir', (
    tester,
  ) async {
    await screen(
      tester,
      hints: const _Hints(null, PasswordResetHint(maskedPhone: '', roles: [])),
    );
    await send(tester);
    expect(sessions, isEmpty);
    expect(
      find.textContaining('doğrulanmış bir telefon numarası yok'),
      findsOneWidget,
    );
  });

  testWidgets('ipucu okunamadiysa kurtarma kapanmaz, SMS gonderilir', (
    tester,
  ) async {
    // Ag/kural hatasi: kaynak yanit vermedi. "Telefonu yok" diye
    // yorumlanirsa kullanici kurtarmadan tamamen kopar.
    await screen(
      tester,
      hints: const _Hints(null, PasswordResetHint.unavailable),
    );
    await send(tester);
    expect(sessions, hasLength(1));
    expect(find.textContaining('uyuşmuyor'), findsNothing);
  });

  testWidgets('ipucu hic gelmezse bekleme bitince SMS yine gonderilir', (
    tester,
  ) async {
    await screen(tester, hints: _Hints(Completer<PasswordResetHint>()));
    await send(tester);
    expect(sessions, isEmpty);
    await tester.pump(const Duration(seconds: 7));
    await frames(tester);
    expect(sessions, hasLength(1));
    await tester.pump(const Duration(seconds: 76));
    await frames(tester);
  });

  // --- MASKESIZ KIP (kRevealPasswordResetPhone) --------------------------

  testWidgets('tam numarali ipucu: basi yanlis numara SMS gondermez', (
    tester,
  ) async {
    // Bildirilen sorun: son iki hane dogru olunca numara geciyordu.
    // Ipucu tam numara tasidiginda ortadaki haneler de denetleniyor.
    await screen(
      tester,
      hints: const _Hints(
        null,
        PasswordResetHint(maskedPhone: '+905551234567', roles: []),
      ),
      number: '5339998867', // son iki hane ayni: ...67
    );
    await send(tester);
    expect(sessions, isEmpty);
    expect(find.textContaining('bu hesaba ait değil'), findsOneWidget);
  });

  testWidgets('tam numarali ipucu: tek hane farki bile SMS gondermez', (
    tester,
  ) async {
    await screen(
      tester,
      hints: const _Hints(
        null,
        PasswordResetHint(maskedPhone: '+905551234567', roles: []),
      ),
      number: '5551234667', // ortadaki bir hane farkli
    );
    await send(tester);
    expect(sessions, isEmpty);
  });

  testWidgets('tam numarali ipucu: dogru numara SMS gonderir', (tester) async {
    await screen(
      tester,
      hints: const _Hints(
        null,
        PasswordResetHint(maskedPhone: '+905551234567', roles: []),
      ),
      number: '5551234567',
    );
    await send(tester);
    expect(sessions, hasLength(1));
    expect(find.textContaining('ait değil'), findsNothing);
  });

  testWidgets('maske hatasi sonrasi duzeltilen numara gonderilebilir', (
    tester,
  ) async {
    await screen(tester, number: '5551234568');
    await send(tester);
    expect(sessions, isEmpty);
    await tester.enterText(find.byType(TextField).first, '5551234567');
    await send(tester);
    expect(sessions, hasLength(1));
  });

  testWidgets(
    'ilk hata sonrasi eski callback ikinci denemenin suresini durduramaz',
    (tester) async {
      await screen(tester);
      await send(tester);
      final first = sessions.first;
      first.failed(FirebaseAuthException(code: 'network-request-failed'));
      await frames(tester);
      expect(loading(tester), isFalse);
      await send(tester);
      expect(sessions, hasLength(2));
      first.failed(FirebaseAuthException(code: 'quota-exceeded'));
      first.sent('old-id', 9);
      first.completed(credential);
      await frames(tester);
      expect(first.signInCalls, 0);
      expect(find.byType(Dialog), findsNothing);
      expect(loading(tester), isTrue);
      await tester.pump(const Duration(seconds: 76));
      await frames(tester);
      expect(loading(tester), isFalse);
      expect(sessions.last.closed, isTrue);
    },
  );

  testWidgets('SMS otomatik okuma suresi dolunca kod elle girilebilir', (
    tester,
  ) async {
    await screen(tester);
    await send(tester);
    sessions.single.autoTimeout('valid-id');
    await frames(tester);
    expect(find.byType(Dialog), findsOneWidget);
    sessions.single.sent('valid-id', 7);
    await frames(tester);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await frames(tester);
    sessions.single.completed(credential);
    await frames(tester);
    expect(sessions.single.signInCalls, 0);
    await send(tester);
    expect(sessions.last.resendToken, 7);
    await tester.pump(const Duration(seconds: 76));
    await frames(tester);
  });

  testWidgets(
    'otomatik dogrulama takilinca yuklenme biter ve gec sonuc yok sayilir',
    (tester) async {
      await screen(tester);
      await send(tester);
      final auth = sessions.single;
      auth.completed(credential);
      await frames(tester);
      expect(loading(tester), isTrue);
      await tester.pump(const Duration(seconds: 31));
      await frames(tester);
      expect(loading(tester), isFalse);
      expect(auth.closed, isTrue);
      auth.signInResult.complete(_Credential('test@example.com'));
      await frames(tester);
      expect(find.text('Şifreyi Kaydet'), findsNothing);
    },
  );

  testWidgets(
    'otomatik dogrulama kod penceresini kapatir ve yalnizca bir kere islenir',
    (tester) async {
      await screen(tester);
      await send(tester);
      final auth = sessions.single;
      auth.sent('valid-id', 7);
      await frames(tester);
      auth.completed(credential);
      auth.completed(credential);
      auth.failed(FirebaseAuthException(code: 'session-expired'));
      await frames(tester);
      auth.signInResult.complete(_Credential('test@example.com'));
      await frames(tester);
      expect(auth.signInCalls, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Şifreyi Kaydet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('baska e-postanin SMS kodu sifre alanlarini acamaz', (
    tester,
  ) async {
    await screen(tester);
    await send(tester);
    final auth = sessions.single;
    auth.completed(credential);
    auth.signInResult.complete(_Credential('other@example.com'));
    await frames(tester);
    expect(find.text('Şifreyi Kaydet'), findsNothing);
    expect(
      find.textContaining('bu e-posta adresine kayıtlı değil'),
      findsOneWidget,
    );
    expect(auth.closed, isTrue);
  });

  testWidgets('sifre kaydetme takilinca buton tekrar kullanilabilir', (
    tester,
  ) async {
    await screen(tester);
    await send(tester);
    final auth = sessions.single;
    auth.completed(credential);
    auth.signInResult.complete(_Credential('test@example.com'));
    await frames(tester);
    await tester.enterText(find.byType(TextField).at(0), 'NewPassword1!');
    await tester.enterText(find.byType(TextField).at(1), 'NewPassword1!');
    await tester.tap(find.byType(AuthPrimaryButton));
    await frames(tester);
    expect(loading(tester), isTrue);
    await tester.pump(const Duration(seconds: 31));
    await frames(tester);
    expect(loading(tester), isFalse);
    expect(find.textContaining('İşlem zamanında yanıtlanmadı'), findsOneWidget);
  });

  testWidgets('kod elle girilince tek dogrulama baslatilir', (tester) async {
    await screen(tester);
    await send(tester);
    final auth = sessions.single;
    auth.sent('manual-id', 7);
    await frames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '123456',
    );
    await frames(tester);
    auth.completed(credential);
    auth.signInResult.complete(_Credential('test@example.com'));
    await frames(tester);
    expect(auth.signInCalls, 1);
    expect(find.text('Şifreyi Kaydet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekran kapandiktan sonraki callback oturum acamaz', (
    tester,
  ) async {
    await screen(tester);
    await send(tester);
    final auth = sessions.single;
    await tester.pumpWidget(const SizedBox());
    auth.completed(credential);
    auth.sent('stale-id', 7);
    await frames(tester);
    expect(auth.closed, isTrue);
    expect(auth.signInCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
