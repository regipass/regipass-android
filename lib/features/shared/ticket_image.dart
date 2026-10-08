/// Bileti resim olarak kaydet (İP-T2) — js/modules/events/ticket-card.js
/// karşılığı.
///
/// Bilet QR'ı sabittir (kayıt kimliği + sunucunun bilet kodu), bu yüzden resim
/// olarak saklanabilir. Kart cihazda çizilir (içerik dışarı gitmez) ve
/// paylaşım menüsüyle açılır: iOS'ta "Resmi Kaydet", Android'de Galeri /
/// Dosyalar. Kayıt iptal edilirse kapıda okutulan bilet reddedilir.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/calendar_export.dart';
import '../../domain/checkin_qr.dart';
import '../../models/event.dart';
import 'add_to_calendar_button.dart';
import 'share_origin.dart';

const double _w = 720;
const double _pad = 48;
const Color _ink = Color(0xFF161A1D);
const Color _muted = Color(0xFF4A4446);

/// Kartta görünen tarih ("30 Eylül 2026 Çarşamba · 14:00–16:00"), Türkiye saatiyle.
String ticketDateText(AppEvent event, {bool english = false}) {
  final CalendarTimes? times = calendarTimes(calendarInputOf(event));
  if (times == null) return '';
  final String locale = english ? 'en_US' : 'tr_TR';
  DateTime tr(int ms) => DateTime.fromMillisecondsSinceEpoch(
    ms,
    isUtc: true,
  ).add(const Duration(hours: 3));
  String day(int ms) => DateFormat('d MMMM y EEEE', locale).format(tr(ms));
  String hm(int ms) => DateFormat('HH:mm', locale).format(tr(ms));
  if (times.allDay) return day(event.eventDateAtMs ?? 0);
  return '${day(times.start)} · ${hm(times.start)}–${hm(times.end)}';
}

String ticketFileName(String title) {
  const Map<String, String> map = <String, String>{
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final String lower = title
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase();
  final String ascii = lower.split('').map((String c) => map[c] ?? c).join();
  String base = ascii
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.length > 50) {
    base = base.substring(0, 50).replaceAll(RegExp(r'-+$'), '');
  }
  return 'regipass-bilet-${base.isEmpty ? 'bilet' : base}.png';
}

TextPainter _text(
  String text,
  TextStyle style, {
  double maxWidth = _w - 2 * _pad,
  int? maxLines,
  TextAlign align = TextAlign.left,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);
}

/// Bilet kartını PNG olarak üretir.
Future<Uint8List> renderTicketPng({
  required String title,
  required String dateText,
  required String place,
  required String clubLine,
  required String studentName,
  required String qrData,
  required String note,
}) async {
  const double scale = 2;
  final TextPainter titleP = _text(
    title,
    const TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: _ink,
      height: 1.25,
    ),
    maxLines: 3,
  );
  final List<TextPainter> meta = <String>[dateText, place, clubLine]
      .where((String s) => s.isNotEmpty)
      .map(
        (String s) =>
            _text(s, const TextStyle(fontSize: 22, color: _muted), maxLines: 1),
      )
      .toList();
  const double qrSize = 420;
  final double h =
      130 + titleP.height + 16 + meta.length * 32 + 30 + qrSize + 150;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)..scale(scale);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _w, h),
    Paint()..color = const Color(0xFFF5F3F4),
  );
  final RRect card = RRect.fromRectAndRadius(
    Rect.fromLTWH(16, 16, _w - 32, h - 32),
    const Radius.circular(28),
  );
  canvas.drawRRect(card, Paint()..color = Colors.white);
  canvas.save();
  canvas.clipRRect(card);
  canvas.drawRect(
    const Rect.fromLTWH(16, 16, _w - 32, 96),
    Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFE5383B), Color(0xFFBA181B)],
      ).createShader(const Rect.fromLTWH(16, 16, _w - 32, 96)),
  );
  canvas.restore();
  final TextPainter brand = _text(
    'Regipass',
    const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    ),
  );
  brand.paint(canvas, Offset(_pad, 64 - brand.height / 2));
  final TextPainter kind = _text(
    'ETKİNLİK BİLETİ',
    const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  );
  kind.paint(canvas, Offset(_w - _pad - kind.width, 64 - kind.height / 2));

  double y = 130;
  titleP.paint(canvas, Offset(_pad, y));
  y += titleP.height + 16;
  for (final TextPainter m in meta) {
    m.paint(canvas, Offset(_pad, y));
    y += 32;
  }
  y += 30;

  final List<List<bool>> matrix = buildQrMatrix(qrData);
  final int dim = matrix.length + kQrQuietZone * 2;
  final double cell = (qrSize / dim).floorToDouble();
  final double qrPx = cell * dim;
  final double qx = ((_w - qrPx) / 2).roundToDouble();
  final Paint dark = Paint()..color = _ink;
  for (int r = 0; r < matrix.length; r += 1) {
    for (int c = 0; c < matrix.length; c += 1) {
      if (matrix[r][c]) {
        canvas.drawRect(
          Rect.fromLTWH(
            qx + (c + kQrQuietZone) * cell,
            y + (r + kQrQuietZone) * cell,
            cell,
            cell,
          ),
          dark,
        );
      }
    }
  }
  y += qrPx + 20;

  if (studentName.isNotEmpty) {
    final TextPainter name = _text(
      studentName,
      const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _ink),
      maxLines: 1,
      align: TextAlign.center,
    );
    name.paint(canvas, Offset((_w - name.width) / 2, y));
    y += 38;
  }
  final TextPainter noteP = _text(
    note,
    const TextStyle(fontSize: 17, color: Color(0xFF7A7274)),
    maxLines: 2,
    align: TextAlign.center,
  );
  noteP.paint(canvas, Offset((_w - noteP.width) / 2, y));

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    (_w * scale).round(),
    (h * scale).round(),
  );
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return bytes!.buffer.asUint8List();
}

/// Bilet kartını üretip paylaşım menüsüyle açar.
Future<void> shareTicketImage({
  required AppEvent event,
  required String registrationId,
  required String studentId,
  required String ticketCode,
  required String studentName,
  Rect? origin,
  bool english = false,
}) async {
  final String token = createCheckinQrToken(
    buildStudentCheckinPayload(
      registrationId: registrationId,
      eventId: event.id,
      studentId: studentId,
      ticketCode: ticketCode,
    ),
  );
  final Uint8List png = await renderTicketPng(
    title: event.title,
    dateText: ticketDateText(event, english: english),
    place: event.locationName,
    clubLine: event.clubName.isEmpty
        ? ''
        : (english
              ? 'Organizer: ${event.clubName}'
              : 'Düzenleyen: ${event.clubName}'),
    studentName: studentName,
    qrData: token,
    note: english
        ? 'Show this code at the door. The ticket is void if your registration is cancelled.'
        : 'Kapıda bu kodu göster. Kaydın iptal edilirse bilet geçersiz olur.',
  );
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/${ticketFileName(event.title)}');
  await file.writeAsBytes(png);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'image/png')],
      subject: event.title,
      sharePositionOrigin: safeShareOrigin(origin),
    ),
  );
}
