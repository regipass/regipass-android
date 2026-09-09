import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/features/auth/auth_widgets.dart';
import 'package:regipass/features/auth/forgot_password_screen.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/services/password_reset_auth_session.dart';
import 'package:regipass/services/phone_hint_repository.dart';
import 'package:regipass/state/providers.dart';

class _Hints extends PhoneHintRepository {
  final Completer<PasswordResetHint>? pending;
  const _Hints([this.pending]);
  @override
  Future<PasswordResetHint> readHint(String email) async => pending != null
      ? pending!.future
      : const PasswordResetHint(maskedPhone: '+90 XXX XXX XX 67', roles: []);
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
    await tester.enterText(find.byType(TextField).first, '5551234567');
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byType(AuthPrimaryButton).first);
    await frames(tester);
  }

  bool loading(WidgetTester tester) => tester
      .widget<AuthPrimaryButton>(find.byType(AuthPrimaryButton).first)
      .loading;

  testWidgets(
    'ipucu okunamasa bile numara girilir; geciken ipucu SMS durumunu bozmaz',
    (tester) async {
      final pending = Completer<PasswordResetHint>();
      await screen(tester, hints: _Hints(pending));
      await send(tester);
      expect(sessions, hasLength(1));
      pending.complete(
        const PasswordResetHint(maskedPhone: '+90 XXX XXX XX 67', roles: []),
      );
      await frames(tester);
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
    expect(find.textContaining('hesapla eşleşmiyor'), findsOneWidget);
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
