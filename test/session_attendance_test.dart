import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/session_attendance.dart';
import 'package:regipass/models/event.dart';

/// İP-B5: oturum oturum katılım (sunucu eventReport.js ile aynı kural).
void main() {
  EventRegistration reg(Map<String, dynamic> data) =>
      EventRegistration.fromMap('ev_s1', <String, dynamic>{
        'eventId': 'ev',
        'studentId': 's1',
        ...data,
      });

  test('QR + elle işaretli oturumlar; elle olanlar ayrı', () {
    final r = resolveAttendedSessions(
      reg(<String, dynamic>{
        'attendanceVerified': <String, dynamic>{'s1': 10},
        'manualAttendance': <String, dynamic>{
          's3': <String, dynamic>{'atMs': 20},
        },
        'sessionsAttended': 2,
        'lastAttendedSession': 3,
      }),
      4,
    );
    expect(r.sessions, <int>[1, 3]);
    expect(r.manual, <int>[3]);
    expect(r.exact, isTrue);
  });

  test('eski kayıt: sayı = son oturum ise 1..son kesin, değilse belirsiz', () {
    expect(
      resolveAttendedSessions(
        reg(<String, dynamic>{'sessionsAttended': 2, 'lastAttendedSession': 2}),
        4,
      ).sessions,
      <int>[1, 2],
    );
    final r = resolveAttendedSessions(
      reg(<String, dynamic>{'sessionsAttended': 2, 'lastAttendedSession': 3}),
      4,
    );
    expect(r.exact, isFalse);
    expect(r.sessions, <int>[3]);
  });
}
