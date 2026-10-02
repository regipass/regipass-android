/// "Takvime ekle" (İP-T): Google Takvim bağlantısı ya da .ics dosyasını
/// paylaşım menüsüyle takvim uygulamasına açma. Yeni eklenti gerekmez.
library;

import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/calendar_export.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';

CalendarEventInput calendarInputOf(AppEvent e) => CalendarEventInput(
  id: e.id,
  title: e.title,
  clubName: e.clubName,
  description: e.description,
  eventDateAtMs: e.eventDateAtMs,
  eventStartAtMs: e.eventStartAtMs,
  eventEndAtMs: e.eventEndAtMs,
  locationName: e.locationName,
  locationLat: e.locationLat,
  locationLng: e.locationLng,
  cancelled: e.cancelled,
);

/// Google Takvim'i etkinlik bilgileriyle dolu açar.
Future<void> openGoogleCalendar(AppEvent event) async {
  final String url = googleCalendarUrl(calendarInputOf(event));
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// .ics dosyasını paylaşım menüsüyle takvim uygulamasına açar.
Future<void> shareEventIcs(AppEvent event, Rect? origin) async {
  final CalendarEventInput input = calendarInputOf(event);
  final String ics = buildIcs(input);
  if (ics.isEmpty) return;
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/${icsFileName(event.title)}');
  await file.writeAsString(ics);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/calendar')],
      subject: event.title,
      sharePositionOrigin: origin,
    ),
  );
}

/// İP-UX: cihazın kendi takvim ekranını açar (iPhone: Apple Takvim,
/// Android: takvim uygulaması). Açılamazsa Google Takvim'e düşer.
Future<void> addToDeviceCalendar(AppEvent event) async {
  final CalendarTimes? times = calendarTimes(calendarInputOf(event));
  if (times == null) return;
  final bool allDay = times.start <= 0;
  DateTime start;
  DateTime end;
  if (!allDay) {
    start = DateTime.fromMillisecondsSinceEpoch(times.start);
    end = DateTime.fromMillisecondsSinceEpoch(
      times.end > times.start ? times.end : times.start + 2 * 3600 * 1000,
    );
  } else {
    final int day = event.eventDateAtMs ?? 0;
    start = DateTime.fromMillisecondsSinceEpoch(day);
    start = DateTime(start.year, start.month, start.day);
    end = start.add(const Duration(days: 1));
  }
  final String desc = <String>[
    if (event.clubName.trim().isNotEmpty) event.clubName.trim(),
    if (event.description.trim().isNotEmpty) event.description.trim(),
  ].join('\n\n');
  bool ok = false;
  try {
    ok = await a2c.Add2Calendar.addEvent2Cal(
      a2c.Event(
        title: event.title,
        description: desc,
        location: event.locationName,
        startDate: start,
        endDate: end,
        allDay: allDay,
        timeZone: 'Europe/Istanbul',
      ),
    );
  } catch (_) {
    ok = false;
  }
  if (!ok) await openGoogleCalendar(event);
}

bool canAddToCalendar(AppEvent event) =>
    !event.cancelled && calendarTimes(calendarInputOf(event)) != null;

class AddToCalendarButton extends StatelessWidget {
  const AddToCalendarButton({super.key, required this.event});

  final AppEvent event;

  Future<void> _openGoogle(BuildContext context) => openGoogleCalendar(event);

  Future<void> _shareIcs(BuildContext context, Rect? origin) =>
      shareEventIcs(event, origin);

  @override
  Widget build(BuildContext context) {
    if (event.cancelled || calendarTimes(calendarInputOf(event)) == null) {
      return const SizedBox.shrink();
    }
    // Tek dokunuş: cihazın takvim ekranı açılır. Uzun basınca diğer
    // seçenekler (Google Takvim, .ics dosyası) çıkar.
    return OutlinedButton.icon(
      key: const Key('addToCalendar'),
      icon: const Icon(Icons.event_available_outlined),
      label: Text(context.t('calendar.add')),
      onPressed: () => addToDeviceCalendar(event),
      onLongPress: () {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        final Rect? origin = box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size;
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(sheetContext.t('calendar.google')),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openGoogle(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: Text(sheetContext.t('calendar.ics')),
                  subtitle: Text(sheetContext.t('calendar.icsHint')),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareIcs(context, origin);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
