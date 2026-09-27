/// Kulüp mesajı: hazır şablonlar ve akıllı etiketler (İP-B ek) —
/// js/modules/club/message-templates.js ve
/// functions/eventReminders.js#renderMessageTags ile AYNI kurallar
/// (test/message_templates_test.dart sunucunun çıktısıyla karşılaştırır).
library;

class MessageTag {
  const MessageTag(this.tag, this.key, this.labelKey);

  final String tag;
  final String key;
  final String labelKey;
}

const List<MessageTag> kMessageTags = <MessageTag>[
  MessageTag('{ad}', 'ad', 'eventNotify.tag.ad'),
  MessageTag('{etkinlik}', 'etkinlik', 'eventNotify.tag.etkinlik'),
  MessageTag('{tarih}', 'tarih', 'eventNotify.tag.tarih'),
  MessageTag('{saat}', 'saat', 'eventNotify.tag.saat'),
  MessageTag('{yer}', 'yer', 'eventNotify.tag.yer'),
  MessageTag('{kulüp}', 'kulup', 'eventNotify.tag.kulup'),
];

const String kFillMark = '…';

class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.label,
    required this.audience,
    required this.title,
    required this.message,
  });

  final String id;
  final String label;
  final String audience;
  final String title;
  final String message;
}

const List<MessageTemplate> kMessageTemplates = <MessageTemplate>[
  MessageTemplate(
    id: 'today',
    label: 'Bugün görüşüyoruz',
    audience: 'registered',
    title: '{etkinlik} bugün!',
    message:
        'Merhaba {ad}, {etkinlik} bugün {saat} saatinde {yer} konumunda. '
        'Biletini hazır tutmayı unutma!',
  ),
  MessageTemplate(
    id: 'place',
    label: 'Yer değişti',
    audience: 'registered',
    title: 'Yer değişikliği: {etkinlik}',
    message:
        'Merhaba {ad}, {etkinlik} için yer değişti. Yeni yer: …. '
        'Saat aynı: {saat}.',
  ),
  MessageTemplate(
    id: 'time',
    label: 'Saat değişti',
    audience: 'registered',
    title: 'Saat değişikliği: {etkinlik}',
    message:
        'Merhaba {ad}, {etkinlik} {tarih} günü … saatinde başlayacak. '
        'Yer: {yer}.',
  ),
  MessageTemplate(
    id: 'postponed',
    label: 'Ertelendi',
    audience: 'registered',
    title: '{etkinlik} ertelendi',
    message:
        'Merhaba {ad}, {etkinlik} ileri bir tarihe ertelendi. Yeni tarih '
        'netleşince buradan haber vereceğiz; kaydın geçerli.',
  ),
  MessageTemplate(
    id: 'started',
    label: 'Başladık, bekliyoruz',
    audience: 'not_checked_in',
    title: '{etkinlik} başladı',
    message:
        'Merhaba {ad}, {etkinlik} başladı! Hâlâ gelebilirsin; kapıda '
        'biletini okutman yeterli.',
  ),
  MessageTemplate(
    id: 'thanks',
    label: 'Katılım teşekkürü',
    audience: 'checked_in',
    title: 'Teşekkürler {ad}!',
    message:
        '{etkinlik} etkinliğine katıldığın için teşekkürler. Bir sonraki '
        'etkinlikte görüşmek üzere! — {kulüp}',
  ),
  MessageTemplate(
    id: 'certificate',
    label: 'Belge hazır',
    audience: 'checked_in',
    title: 'Belgen hazır',
    message:
        "Merhaba {ad}, {etkinlik} katılım belgen Regipass'ta Belgelerim "
        'bölümüne yüklendi.',
  ),
  MessageTemplate(
    id: 'feedback',
    label: 'Geri bildirim iste',
    audience: 'checked_in',
    title: '{etkinlik} nasıldı?',
    message:
        'Merhaba {ad}, {etkinlik} hakkındaki görüşün bizim için önemli. '
        'Kısa bir geri bildirim bırakır mısın? …',
  ),
  MessageTemplate(
    id: 'payment',
    label: 'Ödeme hatırlatması',
    audience: 'payment_pending',
    title: 'Ödeme hatırlatması: {etkinlik}',
    message:
        'Merhaba {ad}, {etkinlik} için ödemeni henüz alamadık. Ödeme '
        'bilgileri etkinlik sayfasında; sorun varsa bize yaz.',
  ),
  MessageTemplate(
    id: 'waitlist',
    label: 'Bekleme listesine bilgi',
    audience: 'waitlist',
    title: '{etkinlik}: bekleme listesi',
    message:
        'Merhaba {ad}, {etkinlik} için bekleme listesindesin. Yer açılırsa '
        'hemen bildirim alacaksın.',
  ),
];

const List<String> _keys = <String>[
  'ad',
  'etkinlik',
  'tarih',
  'saat',
  'yer',
  'kulup',
];
const Map<String, String> _aliases = <String, String>{
  'kulüp': 'kulup',
  'isim': 'ad',
};
final RegExp _tagRe = RegExp(r'\{([^{}\s]{1,20})\}');
const int _trOffsetMs = 3 * 60 * 60 * 1000;
const List<String> _months = <String>[
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _trLower(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

String _normalize(String raw) {
  final String key = _trLower(raw);
  return _aliases[key] ?? key;
}

List<String> unknownMessageTags(String text) => _tagRe
    .allMatches(text)
    .map((RegExpMatch m) => m.group(1)!)
    .where((String t) => !_keys.contains(_normalize(t)))
    .toList();

bool hasFillMark(String text) => text.contains(kFillMark);

String _two(int n) => n.toString().padLeft(2, '0');

String _trTime(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(
    ms + _trOffsetMs,
    isUtc: true,
  );
  return '${_two(d.hour)}:${_two(d.minute)}';
}

Map<String, String> eventTagContext({
  required String title,
  required String clubName,
  required int? eventDateAtMs,
  required int? eventStartAtMs,
  required int? eventEndAtMs,
  required String locationName,
}) {
  final int start = eventStartAtMs ?? 0;
  final int endRaw = eventEndAtMs ?? 0;
  final int end = endRaw > start ? endRaw : 0;
  final int day = (eventDateAtMs ?? 0) > 0 ? eventDateAtMs! : start;
  String date = '';
  if (day > 0) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(
      day + _trOffsetMs,
      isUtc: true,
    );
    date = '${d.day} ${_months[d.month - 1]}';
  }
  return <String, String>{
    'etkinlik': title.isNotEmpty ? title : 'Etkinlik',
    'kulup': clubName,
    'tarih': date,
    'saat': start > 0
        ? '${_trTime(start)}${end > 0 ? '–${_trTime(end)}' : ''}'
        : '',
    'yer': locationName.trim(),
  };
}

String renderMessageTags(String text, Map<String, String> values) => text
    .replaceAllMapped(_tagRe, (Match m) {
      final String key = _normalize(m.group(1)!);
      return _keys.contains(key) ? (values[key] ?? '') : m.group(0)!;
    })
    .replaceAllMapped(RegExp(r'[ \t]+([,.!?;:])'), (Match m) => m.group(1)!)
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .trim();
