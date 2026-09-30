// İP-DM2: demo organizatör havuzunun etkinlikleri yalnızca sahibine görünür.
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_utils.dart';
import 'package:regipass/models/event.dart';

AppEvent _event(String id, Map<String, dynamic> extra) => AppEvent.fromMap(
  id,
  <String, dynamic>{
    'title': 'Etkinlik',
    'targetScope': 'public',
    'clubId': 'demo-kulup1',
    'hiddenGlobally': false,
    ...extra,
  },
);

void main() {
  test('örnek kulüp etkinliği demo kopyası sayılmaz', () {
    final AppEvent e = _event('demo-ctf-gecesi', <String, dynamic>{});
    expect(e.isDemoSandbox, isFalse);
    expect(canStudentSeeEvent(e, null), isTrue);
  });

  test('organizatör kopyası öğrenciye görünmez', () {
    final AppEvent e = _event('demo-ctf-gecesi-o03', <String, dynamic>{
      'clubId': 'demo-o03',
      'demoCopy': true,
      'demoCopyOf': 'demo-ctf-gecesi',
    });
    expect(e.isDemoSandbox, isTrue);
    expect(e.demoCopyOf, 'demo-ctf-gecesi');
    expect(canStudentSeeEvent(e, null), isFalse);
  });

  test('organizatörün kendi oluşturduğu etkinlik de gizli', () {
    final AppEvent e = _event('x', <String, dynamic>{'clubId': 'demo-o12'});
    expect(e.isDemoSandbox, isTrue);
  });

  test('canlı kimlikler etkilenmez', () {
    for (final String id in <String>['demo-ogrenci1', 'abcDEF123', 'demo-organizer', 'demo-o']) {
      expect(_event('x', <String, dynamic>{'clubId': id}).isDemoSandbox, isFalse, reason: id);
    }
  });
}
