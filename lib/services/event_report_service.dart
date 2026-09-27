/// Kulübe etkinlik raporu (İP-R) — PDF ve Excel.
///
/// Web tarayıcıda dosyayı kendisi üretir (js/modules/report/); mobilde AYNI
/// kod sunucuda çalışır (`clubEventReportFile`, functions/shared/report) ve
/// dosya paylaşım sayfasına verilir — iki platformun raporu birebir aynıdır.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_refs.dart';

enum ReportFormat { pdf, xls }

class ReportFile {
  const ReportFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  /// Sunucu yanıtını çözer; dosya adı güvenli karakterlere indirgenir.
  factory ReportFile.fromResponse(Object? data, ReportFormat format) {
    final Map<Object?, Object?> map = data is Map
        ? Map<Object?, Object?>.from(data)
        : <Object?, Object?>{};
    final String ext = format == ReportFormat.pdf ? 'pdf' : 'xls';
    final String raw = map['fileName'] is String
        ? map['fileName'] as String
        : 'regipass-rapor.$ext';
    final String safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    final String base64Text = map['base64'] is String
        ? map['base64'] as String
        : '';
    return ReportFile(
      fileName: safe.endsWith('.$ext') ? safe : 'regipass-rapor.$ext',
      mimeType: format == ReportFormat.pdf
          ? 'application/pdf'
          : 'application/vnd.ms-excel',
      bytes: base64Decode(base64Text),
    );
  }

  final String fileName;
  final String mimeType;
  final List<int> bytes;
}

class EventReportService {
  const EventReportService();

  Future<ReportFile> fetch(
    String eventId,
    ReportFormat format, {
    String lang = 'tr',
  }) async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable(
          'clubEventReportFile',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
        )
        .call(<String, Object>{
          'eventId': eventId,
          'format': format == ReportFormat.pdf ? 'pdf' : 'xls',
          'lang': lang,
        });
    final ReportFile file = ReportFile.fromResponse(result.data, format);
    if (file.bytes.isEmpty) throw StateError('empty-report');
    return file;
  }

  /// Dosyayı geçici klasöre yazıp paylaşım sayfasını açar. iPad'de
  /// [sharePositionOrigin] ŞART (bkz. registrations_export.dart).
  Future<void> share(
    ReportFile file, {
    required String subject,
    required Rect? sharePositionOrigin,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final File out = File('${dir.path}/${file.fileName}');
    await out.writeAsBytes(file.bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(out.path, mimeType: file.mimeType)],
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

final Provider<EventReportService> eventReportServiceProvider =
    Provider<EventReportService>((Ref ref) => const EventReportService());
