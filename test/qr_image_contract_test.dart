import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/checkin_qr.dart';

/// İP-O / O3: QR artık cihazda üretilir (api.qrserver.com kullanılmaz).
void main() {
  void expectValidMatrix(List<List<bool>> m) {
    final int n = m.length;
    expect((n - 17) % 4, 0, reason: 'geçerli QR sürümü');
    for (final List<bool> row in m) {
      expect(row.length, n);
    }
    for (final (int r, int c) in <(int, int)>[(0, 0), (0, n - 7), (n - 7, 0)]) {
      expect(m[r][c], isTrue);
      expect(m[r + 1][c + 1], isFalse);
      expect(m[r + 3][c + 3], isTrue);
    }
  }

  for (final bool located in <bool>[false, true]) {
    for (final bool session in <bool>[false, true]) {
      test('QR matrisi cihazda üretilir: located=$located session=$session', () {
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
        expectValidMatrix(buildQrMatrix(link));
        expect(parseCheckinQrToken(link), payload);
      });
    }
  }

  test('bilet (kodlu) çizilir, aynı içerik aynı matris', () {
    final String token = createCheckinQrToken(
      buildStudentCheckinPayload(
        registrationId: 'event_student',
        eventId: 'event',
        studentId: 'student',
        ticketCode: 'ABCDEFGHIJ',
      ),
    );
    final List<List<bool>> a = buildQrMatrix(token);
    expectValidMatrix(a);
    expect(buildQrMatrix(token), a);
    expect(kQrQuietZone, 4);
  });
}
