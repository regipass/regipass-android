/// Etkinliğe özel iletişim bilgisi: telefon biçimi ve denetim
/// (web js/modules/forms/contact-phone.js ve
/// js/pages/club-create-event.js#readContactPayload ile aynı kurallar).
///
/// Kayıt/doğrulama telefonundan farklı olarak 05xx şartı yok: sabit hat
/// (0212, 0850 ...) da olur. Biçim "0XXX XXX XX XX" — 11 hane; baştaki 0
/// yazılmazsa eklenir.
library;

import 'package:flutter/services.dart';

const int kContactPhoneDigits = 11;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _nonDigit = RegExp(r'\D');

/// Yazılanı "0XXX XXX XX XX" biçimine çevirir (fazla hane atılır).
String formatContactPhone(String value) {
  String digits = value.replaceAll(_nonDigit, '');
  // +90 ile yapıştırılan numara.
  if (digits.startsWith('90') && digits.length > kContactPhoneDigits) {
    digits = digits.substring(2);
  }
  if (digits.isNotEmpty && !digits.startsWith('0')) digits = '0$digits';
  if (digits.length > kContactPhoneDigits) {
    digits = digits.substring(0, kContactPhoneDigits);
  }
  final List<String> parts = <String>[];
  const List<int> cuts = <int>[0, 4, 7, 9, 11];
  for (int i = 0; i < cuts.length - 1; i++) {
    if (digits.length <= cuts[i]) break;
    final int end = digits.length < cuts[i + 1] ? digits.length : cuts[i + 1];
    parts.add(digits.substring(cuts[i], end));
  }
  return parts.join(' ');
}

bool isCompleteContactPhone(String value) =>
    value.replaceAll(_nonDigit, '').length == kContactPhoneDigits;

/// Yazarken "0XXX XXX XX XX" biçimi; imleç hane sayısına göre korunur.
class ContactPhoneFormatter extends TextInputFormatter {
  const ContactPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String formatted = formatContactPhone(newValue.text);
    final int caret = newValue.selection.end.clamp(0, newValue.text.length);
    final String before = newValue.text.substring(0, caret);
    final bool hadZero = newValue.text
        .replaceAll(_nonDigit, '')
        .startsWith('0');
    int want =
        before.replaceAll(_nonDigit, '').length +
        (hadZero || formatted.isEmpty ? 0 : 1);
    int pos = 0;
    while (pos < formatted.length && want > 0) {
      if (formatted.codeUnitAt(pos) >= 48 && formatted.codeUnitAt(pos) <= 57) {
        want -= 1;
      }
      pos += 1;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

/// Hata varsa çeviri anahtarı, yoksa `null`.
String? contactFieldsError(String phone, String email) {
  final String p = phone.trim();
  final String e = email.trim();
  if (p.isEmpty && e.isEmpty) return 'clubCreateEvent.contact.errorEmpty';
  if (e.isNotEmpty && !_emailPattern.hasMatch(e)) {
    return 'clubCreateEvent.contact.errorEmail';
  }
  if (p.isNotEmpty && !isCompleteContactPhone(p)) {
    return 'clubCreateEvent.contact.errorPhone';
  }
  return null;
}
