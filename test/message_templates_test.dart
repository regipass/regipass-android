// İP-B ek: mobil akıllı etiketler sunucuyla (functions/eventReminders.js)
// birebir aynı sonuç vermeli. Beklenen çıktılar sunucu kodundan üretildi:
// test/fixtures/message_tags.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/message_templates.dart';

void main() {
  test('etiket bağlamı ve doldurma sunucuyla aynı', () {
    final List<dynamic> cases =
        jsonDecode(File('test/fixtures/message_tags.json').readAsStringSync())
            as List<dynamic>;
    expect(cases, isNotEmpty);
    for (final dynamic raw in cases) {
      final Map<String, dynamic> c = raw as Map<String, dynamic>;
      final Map<String, dynamic> e = c['event'] as Map<String, dynamic>;
      final Map<String, String> ctx = eventTagContext(
        title: '${e['title'] ?? ''}',
        clubName: '${e['clubName'] ?? ''}',
        eventDateAtMs: (e['eventDateAtMs'] as num?)?.toInt(),
        eventStartAtMs: (e['eventStartAtMs'] as num?)?.toInt(),
        eventEndAtMs: (e['eventEndAtMs'] as num?)?.toInt(),
        locationName: '${e['locationName'] ?? ''}',
      );
      expect(
        ctx,
        Map<String, String>.from(c['context'] as Map<String, dynamic>),
      );
      expect(
        renderMessageTags('${c['text']}', <String, String>{
          ...ctx,
          'ad': '${c['ad']}',
        }),
        c['rendered'],
        reason: '${c['text']} / ${c['ad']}',
      );
    }
  });

  test('şablonlar geçerli; bilinmeyen etiket ve doldurma işareti', () {
    const Set<String> audiences = <String>{
      'registered',
      'checked_in',
      'not_checked_in',
      'payment_pending',
      'waitlist',
    };
    for (final MessageTemplate t in kMessageTemplates) {
      expect(unknownMessageTags(t.title + t.message), isEmpty, reason: t.id);
      expect(t.title.length <= 80 && t.message.length <= 500, isTrue);
      expect(audiences.contains(t.audience), isTrue, reason: t.id);
    }
    expect(unknownMessageTags('{ad} {Kulüp} {telefon}'), <String>['telefon']);
    expect(hasFillMark('Yeni yer: …'), isTrue);
  });
}
