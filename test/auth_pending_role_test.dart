import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/services/role_session_store.dart';
import 'package:regipass/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('geçici onboarding rolü yalnız provider ömründe yaşar', () {
    final ProviderContainer first = ProviderContainer();
    addTearDown(first.dispose);

    first.read(pendingOnboardingRoleProvider.notifier).select(UserRole.student);
    expect(first.read(pendingOnboardingRoleProvider), UserRole.student);

    final ProviderContainer fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    expect(fresh.read(pendingOnboardingRoleProvider), isNull);
  });

  test('eski onboarding iskeleti tamamlanmış rol sayılmaz', () {
    final AppUser appUser = AppUser.fromMap('u1', <String, dynamic>{
      'role': UserRole.student,
      'lastRole': UserRole.student,
      'roles': <String, bool>{UserRole.student: true},
    });
    final StudentProfile incomplete = StudentProfile.fromMap(
      'u1',
      <String, dynamic>{'onboardingCompleted': false},
    );

    final Session session = Session(
      isLoading: false,
      user: null,
      appUser: appUser,
      studentProfile: incomplete,
      clubProfile: null,
      activeRole: UserRole.student,
    );

    expect(session.hasAnyRole, isFalse);
    expect(session.resolvedRole, isNull);
  });

  test('tam kaydedilmiş profil kalıcı rol olarak çözülür', () {
    final AppUser appUser = AppUser.fromMap('u1', <String, dynamic>{
      'role': UserRole.club,
      'lastRole': UserRole.club,
      'roles': <String, bool>{UserRole.club: true},
    });
    final ClubProfile completed = ClubProfile.fromMap('u1', <String, dynamic>{
      'onboardingCompleted': true,
    });

    final Session session = Session(
      isLoading: false,
      user: null,
      appUser: appUser,
      studentProfile: null,
      clubProfile: completed,
      activeRole: null,
    );

    expect(session.hasClubRole, isTrue);
    expect(session.resolvedRole, UserRole.club);
  });

  test('uid ile rol seçimi auth streamini beklemeden kaydedilir', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final RoleSessionStore store = await RoleSessionStore.create();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        roleSessionStoreProvider.overrideWithValue(store),
        currentUidProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(activeRoleProvider.notifier)
        .selectForUser('u-reset', UserRole.club);

    expect(container.read(activeRoleProvider), UserRole.club);
    expect(store.getActiveRole('u-reset'), UserRole.club);
  });
}
