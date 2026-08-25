import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import 'club_shell.dart';

/// club-pending.html — yönetici onayı bekleme ekranı.
///
/// Kabuğun (alt çubuğun) dışındadır: bu aşamada gezilecek bir panel yok.
class ClubPendingScreen extends ConsumerWidget {
  const ClubPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('clubPending.title'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await logout(ref);
            },
            child: Text(context.t('common.logout')),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.hourglass_top_outlined,
                size: 56,
                color: BrandColors.red,
              ),
              const SizedBox(height: 20),
              Text(
                context.t('clubPending.title'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                context.t('clubPending.subtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),

              // Kulüp "bir şey mi unuttum" diye beklemesin: onayın henüz
              // gelmediği açıkça yazılıyor.
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: BrandColors.red.withValues(
                    alpha: context.isDarkMode ? 0.16 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(BrandShape.controlRadius),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: context.brandInk,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t('clubPending.notApprovedYet'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.brandInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Durum canlı dinlendiği için onay geldiğinde router kullanıcıyı
              // kendiliğinden panele alır; bu düğme web'deki "Durumu Yenile"
              // bağlantısının karşılığı.
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(clubProfileProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.t('clubPending.refresh')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
