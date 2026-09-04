// Komut satırı aracı (uygulama kodu değil): çıktısı stdout'a basılır.
// ignore_for_file: avoid_print
//
// Doğrulama aracı: uygulamanın ÜRETTİĞİ onay logu haritasını JSON olarak
// basar; emulator testi (tool/loadtest/12-ucretli-onay-logu.mjs) tam olarak
// bu haritayı yazar.
import 'dart:convert';

import 'package:regipass/domain/paid_event_consent.dart';

void main() {
  final Map<String, Object?> club = PaidEventConsentAcceptance(
    role: PaidEventConsentRole.club,
    title: 'Ücretli Etkinlik Onayı',
    text:
        'Girdiğim bilgilerin doğruluğunu ve katılımcılarla paylaşılmasını '
        'onaylıyorum. Ücretli bir etkinlik ise tahsilat, iade ve vergilendirme '
        'dâhil tüm ödeme sürecinin tek sorumlusunun kulübümüz olduğunu kabul '
        'ediyorum.',
    checkboxLabel: 'Metni okudum ve kabul ediyorum.',
    language: 'tr',
    acceptedAt: DateTime(2026, 9, 3, 14, 22, 7),
  ).toLogMap();

  final Map<String, Object?> student = PaidEventConsentAcceptance(
    role: PaidEventConsentRole.student,
    title: 'Ödeme Bilgilendirme Onayı',
    text:
        'Ödemenin Regipass dışında doğrudan Kulüple yapılacağını; dolandırıcılık '
        'veya ödemenin karşılıksız kalması durumunda Regipass\'ın hiçbir '
        'sorumluluğu olmadığını anladım ve kabul ediyorum.',
    checkboxLabel: 'Metni okudum ve kabul ediyorum.',
    language: 'tr',
    acceptedAt: DateTime(2026, 9, 3, 15, 41, 9),
  ).toLogMap();

  print(jsonEncode(<String, Object?>{'club': club, 'student': student}));
}
