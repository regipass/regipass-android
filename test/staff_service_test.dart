import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/services/staff_service.dart';

void main() {
  test('görevli etkinliği sunucu yanıtından okunur', () {
    final StaffEvent e = StaffEvent.fromMap(<String, dynamic>{
      'eventId': 'e1', 'clubId': 'c1', 'title': 'Kongre', 'clubName': 'Kulüp', 'role': 'assistant',
      'eventDateAtMs': 1791400000000, 'eventFormat': 'online', 'locationName': '',
    });
    expect(e.clubId, 'c1');
    expect(e.role, 'assistant');
    expect(e.online, isTrue);
    expect(StaffEvent.fromMap(<String, dynamic>{'eventId': 'e2'}).role, 'gate');
  });
}
