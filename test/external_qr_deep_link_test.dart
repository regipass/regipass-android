import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/checkin_qr.dart';
import 'package:regipass/domain/routing.dart';

void main() {
  Uri entryUri(Map<String, dynamic> payload) {
    final String token = createCheckinQrToken(payload);
    return Uri(
      path: Routes.qrEntry,
      queryParameters: <String, String>{kQrTokenParam: token},
    );
  }

  test('dış kapı QR bağlantısı öğrenci etkinlik hedefine dönüşür', () {
    final Uri uri = entryUri(<String, dynamic>{
      'v': 1,
      'type': 'event-entry',
      'eventId': 'event-42',
    });

    final CheckinQrDeepLink? link = CheckinQrDeepLink.parse(uri);

    expect(link, isNotNull);
    expect(link!.eventId, 'event-42');
    expect(link.type, 'event-entry');

    final Uri destination = Uri.parse(link.studentDestination());
    expect(destination.path, Routes.studentHome);
    expect(destination.queryParameters['openEventId'], 'event-42');
    expect(destination.queryParameters['qr'], link.token);
  });

  test('oturum QR bağlantısı session alanı olmadan dış rota kabul edilmez', () {
    final Uri uri = entryUri(<String, dynamic>{
      'v': 1,
      'type': 'session-checkin',
      'eventId': 'event-42',
    });

    expect(CheckinQrDeepLink.parse(uri), isNull);
  });

  test(
    'görevlinin kişisel öğrenci bileti dış bağlantı olarak kabul edilmez',
    () {
      final Uri uri = entryUri(
        buildStudentCheckinPayload(
          registrationId: 'event-42_student-8',
          eventId: 'event-42',
          studentId: 'student-8',
        ),
      );

      expect(CheckinQrDeepLink.parse(uri), isNull);
    },
  );

  test('onboarding devam parametresi yalnız doğrulanmış QR niyetini taşır', () {
    final Uri entry = entryUri(<String, dynamic>{
      'v': 1,
      'type': 'session-checkin',
      'eventId': 'event-42',
      'session': 2,
      'slot': 1,
    });

    final Uri target = Uri.parse(
      routeWithExternalQrContinuation(Routes.phoneVerify, entry),
    );

    expect(target.path, Routes.phoneVerify);
    expect(externalQrLinkForUri(target)?.eventId, 'event-42');

    final Uri unsafe = Uri(
      path: Routes.phoneVerify,
      queryParameters: const <String, String>{
        kExternalQrContinueParam: '/admin',
      },
    );
    expect(externalQrLinkForUri(unsafe), isNull);
    expect(
      routeWithExternalQrContinuation(Routes.studentHome, unsafe),
      Routes.studentHome,
    );
  });
}
