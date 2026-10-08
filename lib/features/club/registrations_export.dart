/// Katılımcı listesinin Excel çıktısı — club-events.js#downloadRegistrationsAsExcel
/// karşılığı.
///
/// Biçim web ile **birebir aynı**: SpreadsheetML 2003 (`.xls` uzantılı XML).
/// Gerçek bir XLSX yazıcısına (paket bağımlılığı) gerek yok; Excel, Google
/// E-Tablolar ve LibreOffice bu biçimi doğrudan açar, dolayısıyla iki
/// platformun ürettiği dosya birbirinin aynısıdır.
///
/// Sütunlar da web'deki tabloyla aynı altı sütundur. Çok oturumlu
/// etkinliklerdeki oturum sayacı web'de yalnızca ekrandaki tabloda görünür,
/// Excel'e yazılmaz; buradaki çıktı da aynı ayrımı korur.
library;

import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/text_utils.dart';
import '../../domain/event_utils.dart';
import '../../models/event.dart';
import '../shared/share_origin.dart';

/// Çıktıdaki tüm metinler. Ekran katmanı bunları çevirilerden doldurur;
/// üretici fonksiyon `BuildContext` bilmediği için test edilebilir kalır.
class RegistrationsSheetLabels {
  const RegistrationsSheetLabels({
    required this.sheetName,
    required this.reportTitle,
    required this.eventNameLabel,
    required this.clubLabel,
    required this.countLabel,
    required this.reportDateLabel,
    required this.headers,
  });

  final String sheetName;
  final String reportTitle;
  final String eventNameLabel;
  final String clubLabel;
  final String countLabel;
  final String reportDateLabel;

  /// Altı sütun başlığı: ad, e-posta, telefon, üniversite, bölüm, kayıt tarihi.
  final List<String> headers;
}

/// club-events.js#escapeXml
String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _row(List<String> cells) {
  final String body = cells
      .map((String cell) => '<Cell><Data ss:Type="String">'
          '${_escapeXml(cell)}</Data></Cell>')
      .join();
  return '<Row>$body</Row>';
}

/// club-events.js#buildRegistrationsExcelXml
String buildRegistrationsExcelXml({
  required AppEvent event,
  required List<EventRegistration> registrations,
  required RegistrationsSheetLabels labels,
  String locale = 'tr',
  DateTime? now,
}) {
  // İP-G6: web ile aynı ek sütunlar — ücretli etkinlikte ödeme durumu, kapı
  // girişi olan etkinlikte giriş, oturumlu etkinlikte katıldığı oturum sayısı.
  final bool en = locale == 'en';
  final bool showPayment = event.isPaid;
  final bool showCheckin = event.hasDoorCheckin &&
      (event.entryOpen || event.entryStartedAtMs > 0);
  final bool showSessions = event.isMultiSession;
  final List<List<String>> rows = <List<String>>[
    <String>[labels.reportTitle, '', '', '', '', ''],
    <String>[labels.eventNameLabel, event.title, '', '', '', ''],
    <String>[labels.clubLabel, event.clubName, '', '', '', ''],
    <String>[labels.countLabel, '${registrations.length}', '', '', '', ''],
    <String>[
      labels.reportDateLabel,
      formatDateTime(
        (now ?? DateTime.now()).millisecondsSinceEpoch,
        locale: locale,
      ),
      '',
      '',
      '',
      '',
    ],
    <String>['', '', '', '', '', ''],
    <String>[
      ...labels.headers,
      if (showPayment) en ? 'Payment' : 'Ödeme',
      if (showCheckin) en ? 'Door entry' : 'Kapı Girişi',
      if (showSessions) en ? 'Sessions' : 'Oturum',
    ],
    for (final EventRegistration reg in registrations)
      <String>[
        reg.displayName,
        reg.studentEmail,
        reg.studentPhone,
        reg.studentUniversity,
        reg.studentDepartment,
        formatDateTime(reg.registeredAtMs, locale: locale),
        if (showPayment)
          reg.paymentStatus == 'pending'
              ? (en ? 'Pending' : 'Bekleniyor')
              : (en ? 'Paid' : 'Ödendi'),
        if (showCheckin)
          (reg.checkedInAtMs ?? 0) > 0
              ? '${en ? 'Attended' : 'Katıldı'} — ${formatDateTime(reg.checkedInAtMs, locale: locale)}'
              : (en ? 'Did not attend' : 'Katılmadı'),
        if (showSessions) '${reg.sessionsAttended}/${event.sessionCount}',
      ],
  ];

  final String xmlRows = rows.map(_row).join();
  final String extraColumns = <String>[
    if (showPayment) '      <Column ss:AutoFitWidth="0" ss:Width="110"/>\n',
    if (showCheckin) '      <Column ss:AutoFitWidth="0" ss:Width="220"/>\n',
    if (showSessions) '      <Column ss:AutoFitWidth="0" ss:Width="90"/>\n',
  ].join();

  return '''<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
  <Worksheet ss:Name="${_escapeXml(labels.sheetName)}">
    <Table>
      <Column ss:AutoFitWidth="0" ss:Width="180"/>
      <Column ss:AutoFitWidth="0" ss:Width="260"/>
      <Column ss:AutoFitWidth="0" ss:Width="160"/>
      <Column ss:AutoFitWidth="0" ss:Width="260"/>
      <Column ss:AutoFitWidth="0" ss:Width="220"/>
      <Column ss:AutoFitWidth="0" ss:Width="190"/>
$extraColumns      $xmlRows
    </Table>
  </Worksheet>
</Workbook>''';
}

/// club-events.js#sanitizeFileName
///
/// Tek fark: web Türkçe harfleri **atıyor** ("Kariyer Günleri" ->
/// "kariyer-gnleri"), burada [foldTr] onları ASCII karşılığına indiriyor
/// ("kariyer-gunleri"). Dosya adı hiçbir yerde anahtar olarak kullanılmadığı
/// için bu sapma güvenli, okunaklı adı ise belirgin biçimde iyileştiriyor.
String registrationsFileName(String eventTitle) {
  final String slug = foldTr(eventTitle)
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  return '${slug.isEmpty ? 'etkinlik' : slug}-kayitli-ogrenciler.xls';
}

/// Dosyayı geçici dizine yazıp paylaşım sayfasını açar.
///
/// Web'de `<a download>` ile doğrudan indiriliyor; mobilde eşdeğeri paylaşım
/// sayfasıdır — kulüp dosyayı "Dosyalar"a kaydedebilir, Drive'a atabilir ya
/// da e-postayla gönderebilir.
/// [sharePositionOrigin]: iPad'de paylaşım sayfası tam ekran değil, bir
/// balonda (popover) açılır ve iOS balonun hangi dikdörtgenden çıkacağını
/// bilmek zorunda. Verilmezse **iPad'de uygulama çöker** — iPhone'da hiçbir
/// etkisi yoktur. `null` geçmek yalnızca render kutusu ölçülemediğinde
/// kabul edilebilir bir son çaredir.
Future<void> shareRegistrationsExcel({
  required AppEvent event,
  required List<EventRegistration> registrations,
  required RegistrationsSheetLabels labels,
  required String subject,
  required Rect? sharePositionOrigin,
  String locale = 'tr',
}) async {
  final String xml = buildRegistrationsExcelXml(
    event: event,
    registrations: registrations,
    labels: labels,
    locale: locale,
  );

  final Directory directory = await getTemporaryDirectory();
  final File file = File('${directory.path}/${registrationsFileName(event.title)}');

  // Excel'in Türkçe karakterleri doğru okuması için UTF-8 BOM. Gövde
  // web'inkiyle bayt bayt aynı kalır; BOM yalnızca kodlama imzasıdır ve
  // XML özelliği bunu açıkça serbest bırakır.
  await file.writeAsString('\uFEFF$xml');

  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile(file.path, mimeType: 'application/vnd.ms-excel'),
      ],
      subject: subject,
      sharePositionOrigin: safeShareOrigin(sharePositionOrigin),
    ),
  );
}
