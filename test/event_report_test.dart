// İP-R: kulübe etkinlik raporu — sunucu yanıtı, dosya adı, kart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/club/event_report_card.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/services/event_report_service.dart';

class _FakeReports extends EventReportService {
  _FakeReports();

  final List<String> calls = <String>[];

  @override
  Future<ReportFile> fetch(
    String eventId,
    ReportFormat format, {
    String lang = 'tr',
  }) async {
    calls.add('fetch:$eventId:${format.name}:$lang');
    return ReportFile(
      fileName: 'r.${format.name}',
      mimeType: 'x',
      bytes: const <int>[1],
    );
  }

  @override
  Future<void> share(
    ReportFile file, {
    required String subject,
    required Rect? sharePositionOrigin,
  }) async {
    calls.add('share:${file.fileName}:$subject');
  }
}

void main() {
  test('sunucu yanıtı çözülür; dosya adı güvenli', () {
    final ReportFile pdf = ReportFile.fromResponse(<String, Object>{
      'fileName': 'regipass-rapor-kariyer-2026-09-30.pdf',
      'base64': base64Encode(utf8.encode('%PDF-1.7')),
    }, ReportFormat.pdf);
    expect(pdf.fileName, 'regipass-rapor-kariyer-2026-09-30.pdf');
    expect(pdf.mimeType, 'application/pdf');
    expect(utf8.decode(pdf.bytes), '%PDF-1.7');

    final ReportFile bad = ReportFile.fromResponse(<String, Object>{
      'fileName': '../../etc/passwd',
      'base64': '',
    }, ReportFormat.xls);
    expect(bad.fileName, 'regipass-rapor.xls');
    expect(bad.mimeType, 'application/vnd.ms-excel');
    expect(ReportFile.fromResponse(null, ReportFormat.pdf).bytes, isEmpty);
  });

  testWidgets('kart: PDF ve Excel düğmeleri sunucudan alıp paylaşır', (
    WidgetTester tester,
  ) async {
    final _FakeReports fake = _FakeReports();
    final AppEvent event = AppEvent.fromMap('e1', <String, dynamic>{
      'clubId': 'clubA',
      'title': 'Söyleşi',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventReportServiceProvider.overrideWithValue(fake)],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            home: Scaffold(body: EventReportCard(event: event)),
          ),
        ),
      ),
    );
    expect(find.text('Etkinlik Raporu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('report-pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('report-xls')));
    await tester.pumpAndSettle();
    expect(fake.calls, <String>[
      'fetch:e1:pdf:tr',
      'share:r.pdf:Etkinlik Raporu — Söyleşi',
      'fetch:e1:xls:tr',
      'share:r.xls:Etkinlik Raporu — Söyleşi',
    ]);
    expect(find.text('Rapor indirildi.'), findsWidgets);
  });
}
