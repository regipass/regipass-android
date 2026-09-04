import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/router.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/state/providers.dart';

/// Kayıt ekranının "bu hesapta bu rol zaten var mı" yoklaması sırasında
/// router'ın yerinde kaldığını doğrular.
///
/// Bildirilen hata buydu: kayıt ekranından var olan bir e-posta + şifre
/// girilince uygulama uyarı vermek yerine doğrudan o hesaba giriş yapıyordu.
/// Sebep, rolü sorabilmek için açılan kısa oturumu router'ın gerçek bir giriş
/// sanıp kullanıcıyı panele taşımasıydı — uyarı ekranla birlikte kayboluyordu.
class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  String? get email => 'kulup@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Tamamlanmış kulüp rolü olan, oturumu AÇIK bir hesap.
Session _clubSession({required bool isProbingAccount}) => Session(
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
    'clubStatus': ClubStatus.approved,
  }),
  activeRole: UserRole.club,
  isProbingAccount: isProbingAccount,
);

void main() {
  test('yoklama sürerken kayıt ekranı kapanmaz', () {
    expect(
      resolveRedirectForTest(
        _clubSession(isProbingAccount: true),
        Routes.register,
      ),
      isNull,
    );
  });

  test('yoklama bitince router hesabın gerçek durumuna göre karar verir', () {
    expect(
      resolveRedirectForTest(
        _clubSession(isProbingAccount: false),
        Routes.register,
      ),
      Routes.clubHome,
    );
  });

  test('yoklama bayrağı yalnız bellekte yaşar', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authProbeProvider), isFalse);
    container.read(authProbeProvider.notifier).begin();
    expect(container.read(authProbeProvider), isTrue);
    container.read(authProbeProvider.notifier).end();
    expect(container.read(authProbeProvider), isFalse);
  });
}
