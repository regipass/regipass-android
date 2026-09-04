import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/router.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/state/providers.dart';

/// Onay beklerken belge ekranına dönüşün kapıya takılmadığını doğrular.
///
/// Bildirilen sorun: kulüp yanlış belgeyi yükleyip inceleme kuyruğuna
/// düştüğünde belge ekranına geri dönemiyordu — kapı her denemede onu
/// bekleme ekranına geri fırlatıyordu.
class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  String? get email => 'kulup@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _clubSession(String clubStatus) => Session(
  isLoading: false,
  user: _FakeUser(),
  appUser: AppUser.fromMap('u1', <String, dynamic>{
    'role': UserRole.club,
    'lastRole': UserRole.club,
    'roles': <String, bool>{UserRole.club: true},
  }),
  studentProfile: null,
  clubProfile: ClubProfile.fromMap('u1', <String, dynamic>{
    'onboardingCompleted': true,
    'phoneVerified': true,
    'clubStatus': clubStatus,
  }),
  activeRole: UserRole.club,
);

void main() {
  test('onay beklerken belge ekranı açık kalır', () {
    expect(
      resolveRedirectForTest(
        _clubSession(ClubStatus.pendingReview),
        Routes.clubDocuments,
      ),
      isNull,
    );
  });

  test('onay beklerken diğer sayfalar hâlâ bekleme ekranına düşer', () {
    expect(
      resolveRedirectForTest(
        _clubSession(ClubStatus.pendingReview),
        Routes.clubHome,
      ),
      Routes.clubPending,
    );
  });

  test('belge eksikken hedef zaten belge ekranıdır', () {
    expect(
      resolveRedirectForTest(
        _clubSession(ClubStatus.documentsPending),
        Routes.clubPending,
      ),
      Routes.clubDocuments,
    );
  });
}
