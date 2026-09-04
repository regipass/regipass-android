import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/router.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/state/providers.dart';

/// Şifre sıfırlama rotasının oturum kapısına takılmadığını doğrular.
///
/// SMS kodu doğrulandığı anda kullanıcı Auth'a giriş yapmış olur (şifre
/// değiştirmek oturum gerektiriyor). Router bu rotayı oturumlu kullanıcıya da
/// açık tutmazsa kullanıcı tam o anda panele fırlatılır ve yeni şifresini hiç
/// giremez — bildirilen hatanın kaynağı buydu.
class _FakeUser implements User {
  _FakeUser(this.email);

  @override
  final String? email;

  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _studentSession() => Session(
  isLoading: false,
  user: _FakeUser('ogrenci@example.com'),
  appUser: AppUser.fromMap('u1', <String, dynamic>{
    'role': UserRole.student,
    'lastRole': UserRole.student,
  }),
  studentProfile: StudentProfile.fromMap('u1', <String, dynamic>{
    'onboardingCompleted': true,
    'phoneVerified': true,
  }),
  clubProfile: null,
  activeRole: UserRole.student,
);

void main() {
  test('oturum acilmis kullanici sifre sifirlama ekraninda kalir', () {
    expect(
      resolveRedirectForTest(_studentSession(), Routes.forgotPassword),
      isNull,
    );
  });

  test('oturumsuz kullanici sifre sifirlama ekranina girebilir', () {
    const Session guest = Session(
      isLoading: false,
      user: null,
      appUser: null,
      studentProfile: null,
      clubProfile: null,
      activeRole: null,
    );

    expect(resolveRedirectForTest(guest, Routes.forgotPassword), isNull);
  });

  test('sifre sifirlama disinda kapi normal calisir', () {
    // Karsilastirma: ayni oturum baska bir dis rotada panele yonlendirilir.
    expect(
      resolveRedirectForTest(_studentSession(), Routes.register),
      Routes.studentHome,
    );
  });

  test('sifre yenileme surerken rol secimine yonlendirmez', () {
    final Session resetting = Session(
      isLoading: false,
      user: _FakeUser('ogrenci@example.com'),
      appUser: AppUser.fromMap('u1', <String, dynamic>{
        'role': UserRole.student,
        'lastRole': UserRole.student,
      }),
      studentProfile: StudentProfile.fromMap('u1', <String, dynamic>{
        'onboardingCompleted': true,
        'phoneVerified': true,
      }),
      clubProfile: null,
      activeRole: null,
      isResettingPassword: true,
    );

    expect(
      resolveRedirectForTest(resetting, Routes.roleSelect),
      Routes.forgotPassword,
    );
  });
}
