import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_contact.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/services/registration_service.dart';

AppEvent _event(Map<String, dynamic> extra) =>
    AppEvent.fromMap('e1', <String, dynamic>{
      'title': 'T',
      'clubPhone': '05321112233',
      'clubEmail': 'kulup@ornek.edu',
      ...extra,
    });

void main() {
  group('shownContact', () {
    test('varsayılan: kulübün sistem bilgileri', () {
      final c = _event(<String, dynamic>{}).shownContact;
      expect(c.hidden, isFalse);
      expect(c.phone, '05321112233');
      expect(c.email, 'kulup@ornek.edu');
    });

    test('custom: etkinliğe özel bilgi', () {
      final c = _event(<String, dynamic>{
        'contactMode': 'custom',
        'contactPhone': '05559998877',
        'contactEmail': '',
      }).shownContact;
      expect(c.phone, '05559998877');
      expect(c.email, '');
    });

    test('hidden yalnızca ücretsizde gizler', () {
      expect(_event(<String, dynamic>{'contactMode': 'hidden'}).shownContact.hidden, isTrue);
      final paid = _event(<String, dynamic>{
        'contactMode': 'hidden',
        'feeType': 'paid',
        'feeAmount': 100,
      }).shownContact;
      expect(paid.hidden, isFalse);
      expect(paid.phone, '05321112233');
    });
  });

  group('contactFieldsError', () {
    test('boş', () => expect(contactFieldsError('', ' '), 'clubCreateEvent.contact.errorEmpty'));
    test('bozuk e-posta', () => expect(contactFieldsError('', 'a@b'), 'clubCreateEvent.contact.errorEmail'));
    test('kısa telefon', () => expect(contactFieldsError('0532 11', ''), 'clubCreateEvent.contact.errorPhone'));
    test('geçerli', () {
      expect(contactFieldsError('0532 111 22 33', ''), isNull);
      expect(contactFieldsError('', 'a@b.co'), isNull);
    });
  });

  test('bulkResultFrom', () {
    final r = bulkResultFrom(<String, dynamic>{
      'changedCount': 3,
      'notFound': <Object?>['x'],
    }, countKey: 'changedCount');
    expect(r.count, 3);
    expect(r.notFound, <String>['x']);
    expect(bulkResultFrom(<String, dynamic>{}, countKey: 'removed').count, 0);
  });
}
