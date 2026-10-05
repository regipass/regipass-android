import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:regipass/features/club/registrations_export.dart';
import 'package:regipass/models/event.dart';

/// Excel çıktısının web ile aynı biçimde üretildiğini doğrular
/// (club-events.js#buildRegistrationsExcelXml).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  const RegistrationsSheetLabels labels = RegistrationsSheetLabels(
    sheetName: 'Kayıtlı Öğrenciler',
    reportTitle: 'Etkinlik Raporu',
    eventNameLabel: 'Etkinlik Adı',
    clubLabel: 'Kulüp',
    countLabel: 'Kayıtlı Öğrenci Sayısı',
    reportDateLabel: 'Rapor Tarihi',
    headers: <String>[
      'Ad Soyad',
      'E-posta',
      'Telefon',
      'Üniversite',
      'Bölüm',
      'Kayıt Tarihi',
    ],
  );

  AppEvent buildEvent({String title = 'Kariyer Günleri'}) =>
      AppEvent.fromMap('e1', <String, dynamic>{
        'title': title,
        'clubName': 'Yazılım Kulübü',
      });

  EventRegistration registration({
    String id = 'e1_s1',
    String name = 'Ayşe Yılmaz',
    String email = 'ayse@example.com',
  }) =>
      EventRegistration.fromMap(id, <String, dynamic>{
        'eventId': 'e1',
        'studentId': id.split('_').last,
        'studentName': name,
        'studentEmail': email,
        'studentPhone': '+905551112233',
        'studentUniversity': 'İstanbul Üniversitesi',
        'studentDepartment': 'Bilgisayar Mühendisliği',
        'registeredAtMs': DateTime(2026, 3, 14, 9, 30).millisecondsSinceEpoch,
      });

  group('Excel çıktısı', () {
    test('özet satırları + başlıklar + kayıtlar sırayla yazılır', () {
      final String xml = buildRegistrationsExcelXml(
        event: buildEvent(),
        registrations: <EventRegistration>[registration()],
        labels: labels,
        now: DateTime(2026, 3, 20, 12),
      );

      expect(xml, startsWith('<?xml version="1.0"?>'));
      expect(xml, contains('<?mso-application progid="Excel.Sheet"?>'));
      expect(xml, contains('ss:Name="Kayıtlı Öğrenciler"'));

      // Özet blok web ile aynı sırada: rapor başlığı -> etkinlik -> kulüp ->
      // sayı -> tarih.
      expect(
        xml.indexOf('Etkinlik Raporu') < xml.indexOf('Kariyer Günleri'),
        isTrue,
      );
      expect(
        xml.indexOf('Yazılım Kulübü') < xml.indexOf('Ad Soyad'),
        isTrue,
      );
      expect(xml.indexOf('Ad Soyad') < xml.indexOf('Ayşe Yılmaz'), isTrue);

      // Kayıtlı öğrenci sayısı satırı.
      expect(xml, contains('<Data ss:Type="String">1</Data>'));

      // Altı sütunluk sabit genişlik bloğu korunur.
      expect('<Column '.allMatches(xml).length, 6);
    });

    test('XML kaçışı web ile aynı beş karakteri kapsar', () {
      final String xml = buildRegistrationsExcelXml(
        event: buildEvent(title: 'A & B <script> "x" \'y\''),
        registrations: const <EventRegistration>[],
        labels: labels,
      );

      expect(xml, contains('A &amp; B &lt;script&gt; &quot;x&quot; &apos;y&apos;'));
      expect(xml, isNot(contains('<script>')));
    });

    test('kayıt yoksa yalnızca özet ve başlık satırları kalır', () {
      final String xml = buildRegistrationsExcelXml(
        event: buildEvent(),
        registrations: const <EventRegistration>[],
        labels: labels,
      );

      // 6 özet satırı (biri boş) + 1 başlık satırı.
      expect('<Row>'.allMatches(xml).length, 7);
    });
  });

  group('Dosya adı', () {
    test('Türkçe başlık okunabilir bir sluga iner', () {
      expect(
        registrationsFileName('Kariyer Günleri 2026'),
        'kariyer-gunleri-2026-kayitli-ogrenciler.xls',
      );
    });

    test('boş/işaretlerden ibaret başlıkta varsayılan ada düşer', () {
      expect(registrationsFileName(''), 'etkinlik-kayitli-ogrenciler.xls');
      expect(registrationsFileName('!!! ???'), 'etkinlik-kayitli-ogrenciler.xls');
    });
  });

  test('İP-G6: ücretli etkinlikte Ödeme sütunu yazılır', () {
    final AppEvent paid = AppEvent.fromMap('e1', <String, dynamic>{
      'title': 'Gala',
      'clubName': 'Kulüp',
      'feeType': 'paid',
      'feeAmount': 100,
    });
    final EventRegistration reg = EventRegistration.fromMap('e1_s1', <String, dynamic>{
      'eventId': 'e1',
      'studentId': 's1',
      'studentName': 'Ali Can',
      'paymentStatus': 'pending',
      'registeredAtMs': DateTime(2026, 3, 14, 9, 30).millisecondsSinceEpoch,
    });
    final String xml = buildRegistrationsExcelXml(
      event: paid,
      registrations: <EventRegistration>[reg],
      labels: labels,
      now: DateTime(2026, 3, 20, 12),
    );
    expect(xml, contains('Ödeme'));
    expect(xml, contains('Bekleniyor'));
  });
}
