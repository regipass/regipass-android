import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../domain/legal_docs.dart';
import '../../l10n/app_strings.dart';
import 'legal_document_screen.dart';

/// Kayıt ekranındaki iki zorunlu/opsiyonel onay satırı.
///
/// 1. satır ZORUNLUDUR: Kullanıcı ve Kulüp Sözleşmesi + KVKK Aydınlatma
///    Metni'nin okunduğunu onaylar; bu onay verilmeden kayıt tamamlanamaz.
///    Belge adları artık ortak bir cümlenin İÇİNE gömülü linkler değil,
///    onay metninin ALTINDA kendi başına duran, geniş dokunma alanlı iki ayrı
///    buton (bkz. [_DocumentChip]). Önceki tasarımda "KVKK Aydınlatma
///    Metni" gibi uzun bir belge adı satır sonuna taştığında, ikinci
///    satıra düşen kelimeye basmak gerçek cihazda güvenilir çalışmıyordu —
///    metin akışı içindeki dar bir kelimeyi parmakla isabet ettirmek zordu.
///    Belgelerin kendisi hâlâ ayrı ayrıdır (iki farklı [LegalDocument]);
///    yalnızca ONAY EYLEMİ (imzalama) tek bir onay kutusuyla birleşiktir.
/// 2. satır isteğe bağlıdır: pazarlama amaçlı üçüncü taraf paylaşımı — KVKK
///    Açık Rıza Metni'nin kendisi de bu maddeyi "reddetmeniz temel
///    işlevlerden yararlanmanızı engellemez" diye tarif ediyor, o yüzden
///    kayıt düğmesini bu ikinci kutu değil yalnızca birincisi kilitler.
///
/// [readOnly] true olduğunda kutucuklar dokunulamaz hâle gelir (bkz.
/// bilgi formu ekranlarındaki "onayladığın metinler" özeti); belge
/// butonları yine de dokunulabilir kalır.
class LegalConsentSection extends StatelessWidget {
  const LegalConsentSection({
    super.key,
    required this.termsAccepted,
    required this.marketingConsent,
    this.onTermsChanged,
    this.onMarketingChanged,
    this.readOnly = false,
    this.textColor,
    this.mutedColor,
    this.accentColor,
  });

  final bool termsAccepted;
  final bool marketingConsent;
  final ValueChanged<bool>? onTermsChanged;
  final ValueChanged<bool>? onMarketingChanged;
  final bool readOnly;
  final Color? textColor;
  final Color? mutedColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final String language = context.lang;
    final Color ink = textColor ?? context.ink;
    final Color muted = mutedColor ?? context.inkMuted;
    final Color accent = accentColor ?? BrandColors.red;
    final bool isEn = language == 'en';

    final String introText = isEn
        ? 'I have read and approve the following documents:'
        : 'Aşağıdaki belgeleri okudum ve onaylıyorum:';

    final String marketingText = isEn
        ? 'I allow my personal data to be shared with third-party '
              'institutions unaffiliated with Regipass for advertising/'
              'marketing purposes.'
        : 'Kişisel verilerimin, reklam/pazarlama amacıyla iş ortağı olmayan '
              'üçüncü kurum ve kuruluşlarla paylaşılmasına izin veriyorum.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ConsentRow(
          value: termsAccepted,
          onChanged: readOnly ? null : onTermsChanged,
          readOnly: readOnly,
          accent: accent,
          textColor: ink,
          spans: <InlineSpan>[TextSpan(text: introText)],
        ),
        const SizedBox(height: 8),
        Padding(
          // 24 (kutucuk) + 8 (ara boşluk) — üstteki metnin başladığı yerle
          // hizalanır.
          padding: const EdgeInsets.only(left: 32),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _DocumentChip(
                label: kUserClubAgreement.title(language),
                color: accent,
                onTap: () => openLegalDocument(context, kUserClubAgreement),
              ),
              _DocumentChip(
                label: kKvkkNotice.title(language),
                color: accent,
                onTap: () => openLegalDocument(context, kKvkkNotice),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ConsentRow(
          value: marketingConsent,
          onChanged: readOnly ? null : onMarketingChanged,
          readOnly: readOnly,
          accent: accent,
          textColor: muted,
          spans: <InlineSpan>[TextSpan(text: marketingText)],
        ),
      ],
    );
  }
}

/// Bir hukuki belgeyi açan, kendi başına duran dokunma hedefi.
///
/// Cümle içine gömülü bir link yerine bağımsız bir buton olması, hem
/// dokunma alanını büyütür (satır sonuna taşan bir kelimeye değil, tüm
/// çipe basılabilir) hem de belgenin kendi kimliğini (ayrı sözleşme, ayrı
/// KVKK metni) görsel olarak netleştirir.
class _DocumentChip extends StatelessWidget {
  const _DocumentChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.description_outlined, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hesap ve yönetici kartlarında tek satırlık onay bilgisi:
/// "03 Eylül 2026 14:23:45 · pazarlama izni verildi".
///
/// Onay kaydı olmayan (bu özellik eklenmeden önce açılmış) hesaplarda
/// tarih uydurmak yerine açıkça "kayıt yok" yazar.
String consentTileValue(
  BuildContext context, {
  required bool termsAccepted,
  required int? acceptedAtMs,
  required bool marketingConsent,
}) {
  if (!termsAccepted && acceptedAtMs == null) {
    return context.t('legal.consent.notRecorded');
  }
  return <String>[
    formatDateTimeWithSeconds(acceptedAtMs, locale: context.lang),
    context.t(
      marketingConsent
          ? 'legal.consent.marketingOn'
          : 'legal.consent.marketingOff',
    ),
  ].join(' · ');
}

/// Verilmiş onayın salt-okunur özeti — bilgi formunun en altında ve hesap
/// kartlarında gösterilir.
///
/// Kutucukların yanında onayın **tam anı** da yazar (gün, saat, dakika,
/// saniye): KVKK Aydınlatma Metni madde 7, onay kaydının onay zamanıyla
/// birlikte saklanmasını şart koşuyor ve kullanıcının bunu görebilmesi
/// kaydın kendisi kadar önemli.
class ConsentSummary extends StatelessWidget {
  const ConsentSummary({
    super.key,
    required this.termsAccepted,
    required this.marketingConsent,
    required this.acceptedAtMs,
  });

  final bool termsAccepted;
  final bool marketingConsent;
  final int? acceptedAtMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.t('legal.consent.summaryTitle'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 10),
        LegalConsentSection(
          readOnly: true,
          termsAccepted: termsAccepted,
          marketingConsent: marketingConsent,
        ),
        if (acceptedAtMs != null) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: context.inkMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${context.t('legal.consent.acceptedAt')}: '
                  '${formatDateTimeWithSeconds(acceptedAtMs, locale: context.lang)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.readOnly,
    required this.accent,
    required this.textColor,
    required this.spans,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool readOnly;
  final Color accent;
  final Color textColor;
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 24,
          height: 24,
          child: readOnly
              ? Icon(
                  value ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: value ? accent : textColor.withValues(alpha: 0.5),
                )
              : Checkbox(
                  value: value,
                  activeColor: accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: onChanged == null
                      ? null
                      : (bool? next) => onChanged!(next ?? false),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, height: 1.4, color: textColor),
                children: spans,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
