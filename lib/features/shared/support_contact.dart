/// Hesap ekranlarındaki "İletişim" düğmesi.
///
/// Düğme, işletim sisteminin bir telefon numarasına dokunulduğunda açtığı
/// sayfanın aynısını taklit eder: numara alttan yukarı kayan bir sayfada
/// büyükçe yazılır ve "aransın mı?" diye sorulur. Onaylanınca çağrı, cihazın
/// kendi arama uygulamasına devredilir — uygulama numarayı kendisi çevirmez,
/// yalnızca `tel:` bağlantısını açar; son onay her zaman kullanıcının arama
/// ekranında kalır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import 'common_widgets.dart';

/// Destek numarasını gösteren "aransın mı?" alt sayfası.
Future<void> showSupportContactSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (BuildContext _) => const _SupportContactSheet(),
);

class _SupportContactSheet extends StatelessWidget {
  const _SupportContactSheet();

  /// Çağrıyı cihazın arama uygulamasına devreder.
  ///
  /// Arama uygulaması yoksa (tablet, emülatör) sessizce kaybolmak yerine
  /// numara panoya alınır: kullanıcı hiç değilse numarayı elinde tutar.
  Future<void> _call(BuildContext context) async {
    Navigator.of(context).pop();

    bool launched = false;
    try {
      launched = await launchUrl(
        Uri(scheme: 'tel', path: kSupportPhoneE164),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (launched || !context.mounted) return;

    await Clipboard.setData(const ClipboardData(text: kSupportPhoneDisplay));
    if (context.mounted) {
      showFloatingToast(context, context.t('support.callFailed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(BrandShape.cardRadius),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Alt sayfaların tepesindeki tutamak — sayfanın aşağı
            // sürüklenerek kapatılabildiğini gösterir.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(BrandShape.pillRadius),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BrandColors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_outlined,
                size: 26,
                color: BrandColors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('support.title'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            // Numaranın kendisi sayfanın en büyük öğesi: kullanıcı kimi
            // aradığını onaylamadan önce okuyabilmeli.
            const Text(
              kSupportPhoneDisplay,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.t('support.callPrompt'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _call(context),
                icon: const Icon(Icons.call, size: 20),
                label: Text(context.t('support.call')),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t('common.cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
