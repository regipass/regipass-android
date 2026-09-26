/// Etkinliğe özel iletişim bilgisi denetimi
/// (web js/pages/club-create-event.js#readContactPayload ile aynı kurallar).
library;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Hata varsa çeviri anahtarı, yoksa `null`.
String? contactFieldsError(String phone, String email) {
  final String p = phone.trim();
  final String e = email.trim();
  if (p.isEmpty && e.isEmpty) return 'clubCreateEvent.contact.errorEmpty';
  if (e.isNotEmpty && !_emailPattern.hasMatch(e)) {
    return 'clubCreateEvent.contact.errorEmail';
  }
  if (p.isNotEmpty && p.replaceAll(RegExp(r'\D'), '').length < 10) {
    return 'clubCreateEvent.contact.errorPhone';
  }
  return null;
}
