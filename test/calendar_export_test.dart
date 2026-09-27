// İP-T: takvime ekle (lib/domain/calendar_export.dart) — web ile aynı çıktı.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/calendar_export.dart';

void main() {
  final int start = DateTime.utc(2026, 9, 30, 11).millisecondsSinceEpoch;
  final CalendarEventInput e = CalendarEventInput(
    id: 'e1',
    title: 'Farmakolojiye Giriş; Söyleşi',
    clubName: 'Farmakoloji Kulübü',
    description: 'Satır 1\nSatır 2',
    eventDateAtMs: DateTime.utc(2026, 9, 29, 21).millisecondsSinceEpoch,
    eventStartAtMs: start,
    eventEndAtMs: start + 7200000,
    locationName: 'Konferans Salonu',
    locationLat: 38.456,
    locationLng: 27.221,
  );

  test('Google Takvim bağlantısı', () {
    final Uri url = Uri.parse(googleCalendarUrl(e));
    expect(url.host, 'calendar.google.com');
    expect(url.queryParameters['dates'], '20260930T110000Z/20260930T130000Z');
    expect(
      url.queryParameters['location'],
      'Konferans Salonu (38.456000,27.221000)',
    );
  });

  test('.ics kaçış, katlama, hatırlatma; saatsiz = tüm gün', () {
    final String ics = buildIcs(e, nowMs: 0);
    expect(ics, contains('DTSTART:20260930T110000Z'));
    expect(ics, contains(r'SUMMARY:Farmakolojiye Giriş\; Söyleşi'));
    expect(ics, contains('TRIGGER:-PT1H'));
    for (final String line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
    final String allDay = buildIcs(
      CalendarEventInput(
        id: 'x',
        title: 'X',
        eventDateAtMs: DateTime.utc(2026, 9, 29, 21).millisecondsSinceEpoch,
      ),
      nowMs: 0,
    );
    expect(allDay, contains('DTSTART;VALUE=DATE:20260930'));
    expect(buildIcs(const CalendarEventInput(id: '', title: '')), '');
  });

  test('dosya adı', () {
    expect(
      icsFileName('Farmakolojiye Giriş; Söyleşi'),
      'farmakolojiye-giris-soylesi.ics',
    );
    expect(icsFileName(''), 'etkinlik.ics');
  });
}
