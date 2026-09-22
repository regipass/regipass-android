import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/router.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/checkin_qr.dart';
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

Session _studentSession({required bool phoneVerified}) => Session(
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

Session _clubSession() => Session(
  isLoading: false,
  user: _FakeUser(),
  appUser: AppUser.fromMap('student-1', <String, dynamic>{
    'role': UserRole.club,
    'lastRole': UserRole.club,
  }),
  studentProfile: null,
  clubProfile: ClubProfile.fromMap('student-1', <String, dynamic>{
    'onboardingCompleted': true,
    'phoneVerified': true,
    'clubStatus': ClubStatus.approved,
  }),
  activeRole: UserRole.club,
);

Uri _entryUri() => Uri(
  path: Routes.qrEntry,
  queryParameters: <String, String>{
    kQrTokenParam: createCheckinQrToken(<String, dynamic>{
      'v': 1,
      'type': 'event-entry',
      'eventId': 'event-42',
    }),
  },
);

void main() {
  test('tam kayıtlı öğrenci dış QR ile etkinlik penceresine yönelir', () {
    final Uri entry = _entryUri();

    final Uri destination = Uri.parse(
      resolveRedirectUriForTest(_studentSession(phoneVerified: true), entry)!,
    );

    expect(destination.path, Routes.studentHome);
    expect(destination.queryParameters['openEventId'], 'event-42');
    expect(destination.queryParameters['qr'], isNotEmpty);
  });

  test('onaylı kulüp dış QR ile etkinlik sahipliği kontrolüne yönelir', () {
    final Uri destination = Uri.parse(
      resolveRedirectUriForTest(_clubSession(), _entryUri())!,
    );

    expect(destination.path, Routes.clubHome);
    expect(destination.queryParameters['openEventId'], 'event-42');
  });

  test('telefon doğrulaması QR niyetini korur ve sonra etkinliğe döner', () {
    final Uri entry = _entryUri();
    final Uri verify = Uri.parse(
      resolveRedirectUriForTest(_studentSession(phoneVerified: false), entry)!,
    );

    expect(verify.path, Routes.phoneVerify);
    expect(externalQrLinkForUri(verify)?.eventId, 'event-42');

    final Uri destination = Uri.parse(
      resolveRedirectUriForTest(_studentSession(phoneVerified: true), verify)!,
    );
    expect(destination.path, Routes.studentHome);
    expect(destination.queryParameters['openEventId'], 'event-42');
  });

  test('oturumsuz kullanıcı dış QR rotasında etkinlik bilgisini görebilir', () {
    const Session guest = Session(
      isLoading: false,
      user: null,
      appUser: null,
      studentProfile: null,
      clubProfile: null,
      activeRole: null,
    );

    expect(resolveRedirectUriForTest(guest, _entryUri()), isNull);
  });
}
