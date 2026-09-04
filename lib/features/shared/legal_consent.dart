import 'package:flutter/gestures.dart';
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
/// 2. satır isteğe bağlıdır: pazarlama amaçlı üçüncü taraf paylaşımı — KVKK
///    Açık Rıza Metni'nin kendisi de bu maddeyi "reddetmeniz temel
///    işlevlerden yararlanmanızı engellemez" diye tarif ediyor, o yüzden
///    kayıt düğmesini bu ikinci kutu değil yalnızca birincisi kilitler.
///
/// [readOnly] true olduğunda kutucuklar dokunulamaz hâle gelir (bkz.
/// bilgi formu ekranlarındaki "onayladığın metinler" özeti); belge adları
/// yine de dokunulabilir kalır.
class LegalConsentSection extends StatefulWidget {
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
  State<LegalConsentSection> createState() => _LegalConsentSectionState();
}

class _LegalConsentSectionState extends State<LegalConsentSection> {
  /// Belge başına TEK ve kalıcı dokunma tanıyıcısı.
  ///
  /// Tanıyıcılar her build'de yeniden üretilmemeli: parmak metnin üzerindeyken
  /// (pointer down ile pointer up arasında) bir yeniden çizim olursa — ekranı
  /// besleyen bir provider yayın yapınca, belge ekranından geri dönülünce ya
  /// da bir setState çalışınca — eski tanıyıcı dispose edilir ve dokunuş
  /// sessizce yutulur. Kullanıcı açısından bu "basıyorum ama hiçbir şey
  /// olmuyor" demek; özellikle satır sonuna taşan uzun belge adlarında
  /// (ör. "KVKK Aydınlatma Metni") sık görülüyordu. Tanıyıcılar bir kez
  /// üretilir ve yalnızca [dispose] içinde bırakılır.
  final Map<LegalDocument, TapGestureRecognizer> _recognizers =
      <LegalDocument, TapGestureRecognizer>{};

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _openRecognizer(LegalDocument doc) {
    return _recognizers.putIfAbsent(
      doc,
      () => TapGestureRecognizer()
        ..onTap = () => openLegalDocument(context, doc),
    );
  }

  InlineSpan _linkSpan(LegalDocument doc, String language, Color color) {
    return TextSpan(
      text: doc.title(language),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: color,
      ),
      recognizer: _openRecognizer(doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String language = context.lang;
    final Color ink = widget.textColor ?? context.ink;
    final Color muted = widget.mutedColor ?? context.inkMuted;
    final Color accent = widget.accentColor ?? BrandColors.red;
    final bool isEn = language == 'en';

    final List<InlineSpan> termsSpans = isEn
        ? <InlineSpan>[
            const TextSpan(text: 'I have read and approve the '),
            _linkSpan(kUserClubAgreement, language, accent),
            const TextSpan(text: ' and the '),
            _linkSpan(kKvkkNotice, language, accent),
            const TextSpan(text: '.'),
          ]
        : <InlineSpan>[
            _linkSpan(kUserClubAgreement, language, accent),
            const TextSpan(text: "'ni ve "),
            _linkSpan(kKvkkNotice, language, accent),
            const TextSpan(text: "'ni okudum, onaylıyorum."),
          ];

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
          value: widget.termsAccepted,
          onChanged: widget.readOnly ? null : widget.onTermsChanged,
          readOnly: widget.readOnly,
          accent: accent,
          textColor: ink,
          spans: termsSpans,
        ),
        const SizedBox(height: 10),
        _ConsentRow(
          value: widget.marketingConsent,
          onChanged: widget.readOnly ? null : widget.onMarketingChanged,
          readOnly: widget.readOnly,
          accent: accent,
          textColor: muted,
          spans: <InlineSpan>[TextSpan(text: marketingText)],
        ),
      ],
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
