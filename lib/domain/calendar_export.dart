/// Etkinliği takvime ekle (İP-T) — js/modules/events/calendar-export.js
/// karşılığı. Google Takvim bağlantısı ve RFC 5545 .ics metni üretir.
library;

import 'dart:convert';

const int _trOffsetMs = 3 * 60 * 60 * 1000;
const String _site = 'https://regipass.com';

class CalendarEventInput {
  const CalendarEventInput({
    required this.id,
    required this.title,
    this.clubName = '',
    this.description = '',
    this.eventDateAtMs,
    this.eventStartAtMs,
    this.eventEndAtMs,
    this.locationName = '',
    this.locationLat,
    this.locationLng,
    this.cancelled = false,
  });

  final String id;
  final String title;
  final String clubName;
  final String description;
  final int? eventDateAtMs;
  final int? eventStartAtMs;
  final int? eventEndAtMs;
  final String locationName;
  final double? locationLat;
  final double? locationLng;
  final bool cancelled;
}

class CalendarTimes {
  const CalendarTimes.timed(this.start, this.end)
    : allDay = false,
      startDate = '',
      endDate = '';
  const CalendarTimes.allDay(this.startDate, this.endDate)
    : allDay = true,
      start = 0,
      end = 0;

  final bool allDay;
  final int start;
  final int end;
  final String startDate;
  final String endDate;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _utcStamp(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  return '${d.year}${_two(d.month)}${_two(d.day)}T${_two(d.hour)}${_two(d.minute)}00Z';
}

String _trDate(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(
    ms + _trOffsetMs,
    isUtc: true,
  );
  return '${d.year}${_two(d.month)}${_two(d.day)}';
}

CalendarTimes? calendarTimes(CalendarEventInput e) {
  final int start = e.eventStartAtMs ?? 0;
  final int endRaw = e.eventEndAtMs ?? 0;
  final int day = (e.eventDateAtMs ?? 0) > 0 ? e.eventDateAtMs! : start;
  if (day <= 0) return null;
  if (start > 0) {
    return CalendarTimes.timed(
      start,
      endRaw > start ? endRaw : start + 2 * 3600000,
    );
  }
  return CalendarTimes.allDay(_trDate(day), _trDate(day + 24 * 3600000));
}

String _eventUrl(CalendarEventInput e) => e.id.isNotEmpty
    ? '$_site/dashboard.html?event=${Uri.encodeComponent(e.id)}'
    : '$_site/student-appointments.html';

String _describe(CalendarEventInput e) {
  final List<String> parts = <String>[
    if (e.clubName.isNotEmpty) 'Düzenleyen: ${e.clubName}',
    if (e.description.isNotEmpty)
      e.description.length > 800
          ? e.description.substring(0, 800)
          : e.description,
    'Biletin ve ayrıntılar: ${_eventUrl(e)}',
  ];
  return parts.join('\n\n');
}

String _location(CalendarEventInput e) {
  final String name = e.locationName.trim();
  final double? lat = e.locationLat;
  final double? lng = e.locationLng;
  if (name.isNotEmpty && lat != null && lng != null && (lat != 0 || lng != 0)) {
    return '$name (${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)})';
  }
  return name;
}

String googleCalendarUrl(CalendarEventInput e) {
  final CalendarTimes? t = calendarTimes(e);
  if (t == null) return '';
  final String dates = t.allDay
      ? '${t.startDate}/${t.endDate}'
      : '${_utcStamp(t.start)}/${_utcStamp(t.end)}';
  return Uri.https('calendar.google.com', '/calendar/render', <String, String>{
    'action': 'TEMPLATE',
    'text': e.title.isNotEmpty ? e.title : 'Regipass etkinliği',
    'dates': dates,
    'details': _describe(e),
    'location': _location(e),
    'ctz': 'Europe/Istanbul',
  }).toString();
}

String _escapeIcs(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r?\n'), r'\n');

String _fold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final List<String> out = <String>[];
  final StringBuffer current = StringBuffer();
  int size = 0;
  for (final int rune in line.runes) {
    final String ch = String.fromCharCode(rune);
    final int len = utf8.encode(ch).length;
    if (size + len > (out.isEmpty ? 75 : 74)) {
      out.add(current.toString());
      current.clear();
      size = 0;
    }
    current.write(ch);
    size += len;
  }
  out.add(current.toString());
  return out.join('\r\n ');
}

String buildIcs(CalendarEventInput e, {int? nowMs}) {
  final CalendarTimes? t = calendarTimes(e);
  if (t == null) return '';
  final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final String title = e.title.isNotEmpty ? e.title : 'Regipass etkinliği';
  final String location = _location(e);
  final List<String> lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Regipass//Etkinlik//TR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${_escapeIcs(e.id.isNotEmpty ? e.id : 'etkinlik-$now')}@regipass.com',
    'DTSTAMP:${_utcStamp(now)}',
    if (t.allDay)
      'DTSTART;VALUE=DATE:${t.startDate}'
    else
      'DTSTART:${_utcStamp(t.start)}',
    if (t.allDay)
      'DTEND;VALUE=DATE:${t.endDate}'
    else
      'DTEND:${_utcStamp(t.end)}',
    'SUMMARY:${_escapeIcs(title)}',
    'DESCRIPTION:${_escapeIcs(_describe(e))}',
    if (location.isNotEmpty) 'LOCATION:${_escapeIcs(location)}',
    'URL:${_eventUrl(e)}',
    if (e.cancelled) 'STATUS:CANCELLED' else 'STATUS:CONFIRMED',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:${_escapeIcs(title)}',
    if (t.allDay) 'TRIGGER:-PT15H' else 'TRIGGER:-PT1H',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

String icsFileName(String title) {
  const Map<String, String> tr = <String, String>{
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };
  String base = title.toLowerCase().replaceAll('İ', 'i');
  tr.forEach((String k, String v) => base = base.replaceAll(k, v));
  base = base
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.length > 40) base = base.substring(0, 40);
  return '${base.isEmpty ? 'etkinlik' : base}.ics';
}
