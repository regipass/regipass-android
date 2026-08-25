/// js/modules/utils/password-policy.js portu.
///
/// Şifre gücü kuralı: en az 6 karakter, en az 1 büyük harf, 1 küçük harf ve
/// 1 rakam. Türkçe karakterler (Ç, Ğ, İ, Ö, Ş, Ü ve küçükleri) de harf sayılır.
/// Kayıt oluşturma ve Google/Apple hesabına şifre bağlama akışlarının
/// tümünde aynı kural kullanılır.
library;

final RegExp _upper = RegExp(r'[A-ZÇĞİÖŞÜ]');
final RegExp _lower = RegExp(r'[a-zçğıöşü]');
final RegExp _digit = RegExp(r'[0-9]');

bool isStrongPassword(String? password) {
  final String value = password ?? '';
  return value.length >= 6 &&
      _upper.hasMatch(value) &&
      _lower.hasMatch(value) &&
      _digit.hasMatch(value);
}
