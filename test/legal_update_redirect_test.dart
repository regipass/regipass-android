import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/router.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/state/providers.dart';

class _FakeUser implements User {
  @override
  String get uid => 'student-1';

  @override
  String? get email => 'student@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session(Map<String, dynamic> extra, {bool onboarded = true}) =>
    Session(
      isLoading: false,
      user: _FakeUser(),
      appUser: AppUser.fromMap('student-1', <String, dynamic>{
        'role': UserRole.student,
        'lastRole': UserRole.student,
        ...extra,
      }),
      studentProfile: StudentProfile.fromMap('student-1', <String, dynamic>{
        'onboardingCompleted': onboarded,
        'phoneVerified': true,
      }),
      clubProfile: null,
      activeRole: UserRole.student,
    );

void main() {
  final Map<String, dynamic> oldTerms = <String, dynamic>{
    'termsAccepted': true,
    'termsVersion': '2026-09-02',
  };

  test('eski sürümü onaylamış kullanıcı panele değil onay ekranına gider', () {
    expect(
      resolveRedirectForTest(_session(oldTerms), Routes.studentHome),
      Routes.legalUpdate,
    );
    expect(
      resolveRedirectForTest(_session(oldTerms), Routes.legalUpdate),
      isNull,
    );
  });

  test('güncel sürümü onaylamış kullanıcı onay ekranından panele döner', () {
    final Session s = _session(<String, dynamic>{
      'termsAccepted': true,
      'termsVersion': 'v1.1',
    });
    expect(resolveRedirectForTest(s, Routes.studentHome), isNull);
    expect(resolveRedirectForTest(s, Routes.legalUpdate), Routes.studentHome);
  });

  test('kaydı yarım kullanıcı önce bilgi formunu tamamlar', () {
    expect(
      resolveRedirectForTest(
        _session(oldTerms, onboarded: false),
        Routes.legalUpdate,
      ),
      isNot(Routes.legalUpdate),
    );
  });

  // İP-G2: silinmeyi bekleyen hesap
  final Map<String, dynamic> pending = <String, dynamic>{
    'termsAccepted': true,
    'termsVersion': 'v1.1',
    'pendingDeletion': <String, dynamic>{
      'requestedAtMs': 1,
      'purgeAfterMs': 2592000001,
    },
  };

  test('silme talebi bekleyen kullanıcı panel yerine geri al ekranını görür', () {
    final Session s = _session(pending);
    expect(s.appUser!.pendingDeletionPurgeAfterMs, 2592000001);
    expect(resolveRedirectForTest(s, Routes.studentHome), Routes.pendingDeletion);
    expect(resolveRedirectForTest(s, Routes.pendingDeletion), isNull);
  });

  test('geri alınınca geri al ekranından panele döner', () {
    final Session s = _session(<String, dynamic>{
      'termsAccepted': true,
      'termsVersion': 'v1.1',
    });
    expect(s.appUser!.hasPendingDeletion, isFalse);
    expect(resolveRedirectForTest(s, Routes.pendingDeletion), Routes.studentHome);
  });
}
