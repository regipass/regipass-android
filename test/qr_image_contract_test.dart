import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/checkin_qr.dart';

void main() {
  for (final bool located in <bool>[false, true]) {
    for (final bool session in <bool>[false, true]) {
      test(
        'QR image preserves URL/token: located=$located session=$session',
        () {
          final Map<String, dynamic> payload = <String, dynamic>{
            'v': 1,
            'type': session ? 'session-checkin' : 'event-entry',
            'eventId': 'qr-diagnostic-no-event',
            if (session) ...<String, dynamic>{'session': 2, 'slot': 89451234},
            if (located) ...<String, dynamic>{
              'locationLat': 41.012345,
              'locationLng': 29.012345,
              'locationRadius': 100,
            },
          };
          final String token = createCheckinQrToken(payload);
          final String link = buildCheckinQrUrl(token);
          final Uri image = Uri.parse(buildCheckinQrImageUrl(link, size: 600));
          expect(image.queryParameters['qzone'], '4');
          expect(image.queryParameters['margin'], '0');
          expect(image.queryParameters['size'], '600x600');
          expect(image.queryParameters['data'], link);
          expect(extractCheckinQrToken(image.queryParameters['data']), token);
          expect(parseCheckinQrToken(image.queryParameters['data']), payload);
        },
      );
    }
  }

  test('legacy ticket data and size limits are preserved', () {
    final String token = createCheckinQrToken(
      buildStudentCheckinPayload(
        registrationId: 'event_student',
        eventId: 'event',
        studentId: 'student',
      ),
    );
    for (final MapEntry<int, int> size in <int, int>{
      0: 180,
      400: 400,
      9999: 600,
    }.entries) {
      final Uri image = Uri.parse(
        buildCheckinQrImageUrl(token, size: size.key),
      );
      expect(image.queryParameters['size'], '${size.value}x${size.value}');
      expect(image.queryParameters['data'], token);
      expect(image.queryParameters['qzone'], '4');
    }
  });
}
