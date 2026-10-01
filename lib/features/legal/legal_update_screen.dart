import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/legal_docs.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/account_security.dart';
import '../shared/legal_document_screen.dart';

/// İP-HK: hukuki metinler güncellendiğinde gösterilen tek seferlik onay ekranı
/// (web: js/modules/auth/reconsent-gate.js). Onay verilmeden panele geçilmez;
/// kabul etmeyen kullanıcı hesabını silebilir ya da çıkış yapabilir.
class LegalUpdateScreen extends ConsumerStatefulWidget {
  const LegalUpdateScreen({super.key});

  @override
  ConsumerState<LegalUpdateScreen> createState() => _LegalUpdateScreenState();
}

class _LegalUpdateScreenState extends ConsumerState<LegalUpdateScreen> {
  bool _agreement = false;
  bool _kvkk = false;
  bool _saving = false;
  String? _error;

  static const Map<String, Map<String, Object>> _text =
      <String, Map<String, Object>>{
    'tr': <String, Object>{
      'title': 'Sözleşmelerimiz güncellendi',
      'lead':
          "Regipass'i kullanmaya devam etmek için güncellenen metinleri onaylaman gerekiyor. Başlıca değişiklikler:",
      'items': <String>[
        'Kulüp ve öğrenci yerine Organizatör ve Katılımcı adları kullanılıyor.',
        'Hesapsız kayıt, etkinlik linkleri, bilet, kapıda giriş ve katılım belgeleri için yeni maddeler eklendi.',
        "Verilerinin saklandığı yerler düzeltildi: ana veritabanı ABD'de, sunucu işlemleri ABD ve Belçika'da.",
        'Sorumluluk, organizatör yükümlülükleri ve saklama süreleri ayrıntılandırıldı.',
      ],
      'agreement':
          "Kullanıcı ve Organizatör Sözleşmesi'ni (v1.1) okudum ve kabul ediyorum.",
      'kvkk':
          "KVKK Aydınlatma Metni'ni (v1.1) okudum; verilerimin yurt dışında (ABD ve AB) işlenmesi dahil anladım.",
      'read': 'Metni oku',
      'accept': 'Onaylıyorum, devam et',
      'signout': 'Çıkış yap',
      'delete': 'Kabul etmiyorum, hesabımı silmek istiyorum',
      'error':
          'Onay kaydedilemedi. İnternet bağlantını kontrol edip tekrar dene.',
    },
    'en': <String, Object>{
      'title': 'Our terms have been updated',
      'lead':
          'To keep using Regipass, please accept the updated texts. Main changes:',
      'items': <String>[
        'Clubs and students are now called Organizers and Participants.',
        'New sections for registration without an account, event links, tickets, door entry and participation certificates.',
        'Where your data is stored has been corrected: main database in the US, server functions in the US and Belgium.',
        'Liability, organizer obligations and retention periods are described in more detail.',
      ],
      'agreement':
          'I have read and accept the User and Organizer Agreement (v1.1).',
      'kvkk':
          'I have read the Data Protection Notice (v1.1) and understand that my data is processed abroad (US and EU).',
      'read': 'Read the text',
      'accept': 'I accept, continue',
      'signout': 'Sign out',
      'delete': "I don't accept, I want to delete my account",
      'error':
          'Your acceptance could not be saved. Check your connection and try again.',
    },
  };

  Future<void> _accept() async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .acceptLegalUpdate(uid, kLegalDocsVersion);
      // Kullanıcı belgesi akışı güncellenince yönlendirme kendiliğinden
      // panele döner (bkz. lib/app/router.dart).
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _t('error') as String;
      });
    }
  }

  Object _t(String key) =>
      _text[context.lang == 'en' ? 'en' : 'tr']![key]!;

  @override
  Widget build(BuildContext context) {
    final List<String> items = _t('items') as List<String>;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: <Widget>[
            Text(
              _t('title') as String,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _t('lead') as String,
              style: TextStyle(fontSize: 14.5, color: context.inkMuted, height: 1.45),
            ),
            const SizedBox(height: 10),
            for (final String item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('•  ', style: TextStyle(color: BrandColors.red, fontSize: 14)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 14, color: context.inkBody, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _ConsentBox(
              value: _agreement,
              label: _t('agreement') as String,
              readLabel: _t('read') as String,
              onChanged: _saving ? null : (bool v) => setState(() => _agreement = v),
              onRead: () => openLegalDocument(context, kUserClubAgreement),
            ),
            const SizedBox(height: 10),
            _ConsentBox(
              value: _kvkk,
              label: _t('kvkk') as String,
              readLabel: _t('read') as String,
              onChanged: _saving ? null : (bool v) => setState(() => _kvkk = v),
              onRead: () => openLegalDocument(context, kKvkkNotice),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.red,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: (_agreement && _kvkk && !_saving) ? _accept : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        _t('accept') as String,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: BrandColors.redDark, fontSize: 13.5)),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: <Widget>[
                TextButton(
                  onPressed: _saving ? null : () => showDeleteAccountDialog(context),
                  child: Text(_t('delete') as String,
                      style: TextStyle(color: context.inkMuted, decoration: TextDecoration.underline)),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => ref.read(authRepositoryProvider).signOut(),
                  child: Text(_t('signout') as String,
                      style: TextStyle(color: context.inkMuted, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentBox extends StatelessWidget {
  const _ConsentBox({
    required this.value,
    required this.label,
    required this.readLabel,
    required this.onChanged,
    required this.onRead,
  });

  final bool value;
  final String label;
  final String readLabel;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.inkMuted.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: value,
                activeColor: BrandColors.red,
                onChanged: onChanged == null ? null : (bool? v) => onChanged!(v == true),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label, style: TextStyle(fontSize: 14, color: context.ink, height: 1.4)),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          foregroundColor: BrandColors.red,
                        ),
                        onPressed: onRead,
                        child: Text(readLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
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
