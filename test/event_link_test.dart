import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/router.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/event_utils.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/services/event_link_service.dart';
import 'package:regipass/state/providers.dart';

class _FakeUser implements User {
  @override
  String get uid => 'student-1';

  @override
  String? get email => 'student@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Session _signedOut = Session(
  isLoading: false,
  user: null,
  appUser: null,
  studentProfile: null,
  clubProfile: null,
  activeRole: null,
);

Session _student({bool phoneVerified = true}) => Session(
  isLoading: false,
  user: _FakeUser(),
  appUser: AppUser.fromMap('student-1', <String, dynamic>{
    'role': UserRole.student,
    'lastRole': UserRole.student,
  }),
  studentProfile: StudentProfile.fromMap('student-1', <String, dynamic>{
    'onboardingCompleted': true,
    'phoneVerified': phoneVerified,
  }),
  clubProfile: null,
  activeRole: UserRole.student,
);

void main() {
  tearDown(() => pendingEventLinkCode = null);

  test('linkten açılan kod yoldan okunur; geçersiz kod boş döner', () {
    expect(eventLinkKeyFromPath('/e/K7P2QX'), 'K7P2QX');
    expect(eventLinkKeyFromPath('/e/bahar-konseri/'), 'bahar-konseri');
    expect(eventLinkKeyFromPath('/e/'), '');
    expect(eventLinkKeyFromPath('/e/a%2'), '');
    expect(eventLinkKeyFromPath('/e/<script>'), '');
    expect(eventLinkKeyFromPath('/qr.html'), '');
  });

  test('misafir formu uygulama linkine düşmeyen yoldan açılır', () {
    expect(eventLinkWebFormUrl('K7P2QX'), endsWith('/kayit/K7P2QX?app=1'));
  });

  test('yalnızca linkle paylaşılan etkinlik keşfette görünmez', () {
    final AppEvent pub = AppEvent.fromMap('e1', <String, dynamic>{
      'hiddenGlobally': false,
    });
    final AppEvent link = AppEvent.fromMap('e2', <String, dynamic>{
      'hiddenGlobally': false,
      'visibility': 'link',
    });
    expect(pub.isLinkOnly, isFalse);
    expect(link.isLinkOnly, isTrue);
    expect(isDiscoverableEvent(link), isFalse);
  });

  test('oturum yokken link açılır (giriş ekranına atılmaz)', () {
    expect(
      resolveRedirectUriForTest(_signedOut, Uri(path: '/e/K7P2QX')),
      isNull,
    );
  });

  test('tam hesaplı katılımcı link ekranına girebilir', () {
    expect(resolveRedirectUriForTest(_student(), Uri(path: '/e/K7P2QX')), isNull);
  });

  test('hesap kurulumu bitmemişse kod saklanır, bitince linke dönülür', () {
    final String? first = resolveRedirectUriForTest(
      _student(phoneVerified: false),
      Uri(path: '/e/K7P2QX'),
    );
    expect(first, isNot('/e/K7P2QX'));
    expect(pendingEventLinkCode, 'K7P2QX');

    final String? after = resolveRedirectUriForTest(
      _student(),
      Uri(path: Routes.studentHome),
    );
    expect(after, '/e/K7P2QX');
    expect(pendingEventLinkCode, isNull);
    expect(resolveRedirectUriForTest(_student(), Uri(path: Routes.studentHome)), isNull);
  });
}
