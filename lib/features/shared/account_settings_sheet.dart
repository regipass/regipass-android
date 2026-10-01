/// Hesap ekranlarının sağ üstündeki iki simge ve arkalarındaki alt sayfalar.
///
/// Görünüm/dil tercihleri ile güvenlik işlemleri eskiden hesap sayfasının
/// gövdesinde iki kart olarak duruyordu: profil bilgilerini görmek isteyen
/// kullanıcı her seferinde onların arasından geçiyor, ayar değiştirmek
/// isteyen ise sayfanın sonuna kadar iniyordu. İkisi de artık tek bir
/// "Hesap Ayarlarım" alt sayfasında; sayfada yalnızca üst çubuktaki çıkış
/// düğmesinin altına oturan bir dişli simgesi görünüyor.
///
/// Simgenin yanındaki ikinci düğme destek hattını arar (bkz.
/// `support_contact.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/demo_mode.dart';
import '../../app/theme.dart';
import '../../domain/legal_docs.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../../state/theme_mode.dart';
import 'account_security.dart';
import 'support_contact.dart';

/// Hesap sayfasının sağ üstündeki simge çifti: iletişim + hesap ayarları.
class AccountToolbar extends StatelessWidget {
  const AccountToolbar({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      _ToolbarButton(
        icon: Icons.support_agent_outlined,
        label: context.t('account.contact'),
        onTap: () => showSupportContactSheet(context),
      ),
      const SizedBox(width: 10),
      _ToolbarButton(
        icon: Icons.settings_outlined,
        label: context.t('account.settings'),
        onTap: () => showAccountSettingsSheet(context),
      ),
    ],
  );
}

/// Yuvarlak, yalnız simgeli düğme. Etiket ekranda yazılmadığı için hem
/// ipucu (uzun basış) hem de ekran okuyucu adı olarak veriliyor.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.subtleFill,
        shape: CircleBorder(side: BorderSide(color: context.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 21, color: context.brandInk),
          ),
        ),
      ),
    ),
  );
}

// ── Hesap ayarları alt sayfası ────────────────────────────────────────

Future<void> showAccountSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) => const _AccountSettingsSheet(),
    );

class _AccountSettingsSheet extends StatelessWidget {
  const _AccountSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Sayfanın tamamını kaplamaz: arkadaki hesap ekranının bir kısmı
        // görünür kalır ve alt sayfanın kapatılabilir olduğu belli olur.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // Sayfa zemini: içindeki iki kart bu zeminin üstünde ayrı ayrı
            // yüzey olarak okunsun.
            color: context.canvas,
            borderRadius: BorderRadius.circular(BrandShape.cardRadius),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.hairline,
                  borderRadius: BorderRadius.circular(BrandShape.pillRadius),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: context.brandInk,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t('account.settings'),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    children: <Widget>[
                      const AccountPreferencesCard(),
                      if (!kDemoMode) ...<Widget>[
                        const SizedBox(height: 14),
                        const ConsentPreferencesCard(),
                      ],
                      // Demo: ortak hazır hesapta şifre değiştirme / hesap
                      // silme gösterilmez (web demosuyla aynı).
                      if (!kDemoMode) ...<Widget>[
                        const SizedBox(height: 14),
                        // Hesap silinince oturum kapanır ve router giriş
                        // ekranına döner; bu alt sayfa kök gezginde durduğu
                        // için kendiliğinden kapanmaz, elle kapatılır.
                        AccountSecurityCard(
                          onAccountDeleted: () => Navigator.of(context).pop(),
                        ),
                      ],
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

// ── Görünüm ve dil ────────────────────────────────────────────────────

/// Görünüm ve dil tercihleri.
///
/// İkisi de anında uygulanır ve cihazda saklanır; bu yüzden "Kaydet" düğmesi
/// yok — seçim eylemin kendisi.
///
/// Öğrenci ve kulüp hesap ekranlarında ayrı ayrı iki kopya olarak duruyordu;
/// iki ekran da artık aynı bileşeni bu alt sayfada gösteriyor.
class AccountPreferencesCard extends ConsumerWidget {
  const AccountPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final String language = ref.watch(languageProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PreferenceLabel(
            icon: Icons.brightness_6_outlined,
            label: context.t('settings.appearance'),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ChoiceChip(
                  icon: Icons.light_mode_outlined,
                  label: context.t('settings.appearance.light'),
                  selected: mode != ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceChip(
                  icon: Icons.dark_mode_outlined,
                  label: context.t('settings.appearance.dark'),
                  selected: mode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PreferenceLabel(
            icon: Icons.language_outlined,
            label: context.t('settings.language'),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ChoiceChip(
                  // Dil adları çevrilmez: "English" seçeneğini arayan biri
                  // onu Türkçe arayüzde de "English" diye arar.
                  label: 'Türkçe',
                  selected: language == 'tr',
                  onTap: () =>
                      ref.read(languageProvider.notifier).setLanguage('tr'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceChip(
                  label: 'English',
                  selected: language == 'en',
                  onTap: () =>
                      ref.read(languageProvider.notifier).setLanguage('en'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceLabel extends StatelessWidget {
  const _PreferenceLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 18, color: context.inkMuted),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: context.ink,
        ),
      ),
    ],
  );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color fill = selected
        ? BrandColors.redSoft
        : context.isDarkMode
        ? BrandColors.red.withValues(alpha: 0.16)
        : BrandColors.redTint;

    final Color fg = selected ? BrandColors.white : context.brandInk;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
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

// ── Açık rıza tercihleri (İP-PZ) ──────────────────────────────────────

/// KVKK metni "her tercih ayarlardan geri çekilebilir" diyor: kampanya
/// bildirimi (ticari ileti) ve üçüncü kurumla paylaşım burada açılıp kapanır.
class ConsentPreferencesCard extends ConsumerStatefulWidget {
  const ConsentPreferencesCard({super.key});

  @override
  ConsumerState<ConsentPreferencesCard> createState() =>
      _ConsentPreferencesCardState();
}

class _ConsentPreferencesCardState
    extends ConsumerState<ConsentPreferencesCard> {
  String? _busyKey;
  String? _message;
  // Kaydedilirken anahtar hemen yeni konumda durur (sunucudan güncel değer
  // gelene kadar eski renge dönüp yanıp sönmesin).
  final Map<String, bool> _pending = <String, bool>{};

  Future<void> _set(String key, bool on) async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;
    final bool en = context.lang == 'en';
    setState(() {
      _busyKey = key;
      _message = null;
      _pending[key] = on;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .setConsentPreference(uid, key, on, kLegalDocsVersion);
      if (!mounted) return;
      setState(() => _message = en ? 'Saved.' : 'Kaydedildi.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending.remove(key);
        _message = en
            ? 'Could not save, try again.'
            : 'Kaydedilemedi, tekrar dene.';
      });
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool en = context.lang == 'en';
    final user = ref.watch(sessionProvider).appUser;
    final bool commercialServer = user?.commercialMessages ?? false;
    final bool shareServer = user?.thirdPartyShare ?? false;
    // Sunucu yeni değeri gönderince bekleyen değer bırakılır.
    if (_pending['commercialMessages'] == commercialServer) {
      _pending.remove('commercialMessages');
    }
    if (_pending['marketingThirdPartyShare'] == shareServer) {
      _pending.remove('marketingThirdPartyShare');
    }
    final bool commercial = _pending['commercialMessages'] ?? commercialServer;
    final bool share = _pending['marketingThirdPartyShare'] ?? shareServer;

    Widget row(String key, String title, String note, bool value) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        // iOS'ta varsayılan yeşil yerine marka kırmızısı (açıkken her zaman aynı renk).
        activeThumbColor: Colors.white,
        activeTrackColor: BrandColors.red,
        onChanged: _busyKey == null ? (bool v) => _set(key, v) : null,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          note,
          style: TextStyle(fontSize: 12.5, color: context.inkMuted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PreferenceLabel(
            icon: Icons.verified_user_outlined,
            label: en ? 'Privacy preferences' : 'Gizlilik tercihlerim',
          ),
          row(
            'commercialMessages',
            en
                ? 'Campaign and announcement notifications'
                : 'Kampanya ve duyuru bildirimleri',
            en
                ? 'Regipass campaigns and partnerships (commercial messages). Event and account notifications are not affected.'
                : "Regipass'in kampanya ve iş birliği bildirimleri (ticari ileti). Etkinlik ve hesap bildirimleri bundan etkilenmez.",
            commercial,
          ),
          row(
            'marketingThirdPartyShare',
            en
                ? 'Sharing my data with third parties for marketing'
                : 'Verilerimin üçüncü kurumlarla pazarlama amaçlı paylaşılması',
            en
                ? 'Data Protection Notice section 5.7.'
                : 'KVKK Aydınlatma Metni madde 5.7.',
            share,
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _message!,
                style: TextStyle(fontSize: 12.5, color: context.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
