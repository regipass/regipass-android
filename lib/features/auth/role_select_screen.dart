import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import 'auth_actions.dart';

/// login-modal.js#showRoleStep karşılığı.
///
/// **Tek durumda gösterilir:** hesapta hiç tamamlanmış rol yok (ilk
/// Google/Apple girişi ya da eski yarım iskelet) ve kullanıcı hesabının
/// TÜRÜNÜ seçiyor. Bu adım kaldırılamaz — OAuth ile gelen kullanıcının rolünü
/// başka türlü belirleyemeyiz, kaldırılırsa Google/Apple ile hesap açmak
/// imkânsız hale gelir.
///
/// Eskiden ikinci bir durum daha vardı: hesapta iki rol de varsa "hangisiyle
/// devam edeceksin" sorusu. Bir e-postaya artık tek rol bağlanabildiği için o
/// soru kalktı (bkz. `lib/app/router.dart` rol seçimi bölümü). Aşağıdaki
/// `hasCompletedRole` dalı yalnızca kural gelmeden önce açılmış çift rollü
/// hesaplar bu ekrana elle gelirse diye duruyor.
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(String role) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final Session session = ref.read(sessionProvider);

      if (session.hasCompletedRole(role)) {
        // İki tamamlanmış hesabı olan kullanıcı yalnız aktif hesabını seçer;
        // yeni bir profil oluşturulmaz.
        final String? uid = session.user?.uid;
        if (uid != null) {
          await ref
              .read(authRepositoryProvider)
              .syncActiveRoleToUserDoc(uid, role);
        }
        await ref.read(activeRoleProvider.notifier).select(role);
      } else {
        // Yeni rol yalnız bellekte yaşar. Bilgi formu başarıyla kaydedilene
        // kadar Firestore ve SharedPreferences'a hiçbir rol yazılmaz.
        final activeRole = ref.read(activeRoleProvider.notifier);
        final pendingRole = ref.read(pendingOnboardingRoleProvider.notifier);
        try {
          await activeRole.clear();
        } catch (_) {
          // Bellekteki pending rol yeterlidir; eski yerel tercih bir sonraki
          // başarılı kalıcı seçimde üzerine yazılır.
        }
        pendingRole.select(role);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = context.t('feedback.saveErrorRetry');
          _busy = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await logout(ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 24),
              const Center(child: BrandLogo(size: 130)),
              const SizedBox(height: 32),
              Text(
                context.t('auth.roleStep.title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.t('auth.roleStep.desc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),

              FeedbackBanner(message: _error, tone: FeedbackTone.error),

              _RoleTile(
                title: context.t('auth.role.student'),
                description: context.t('auth.roleStep.student.desc'),
                icon: Icons.school_outlined,
                enabled: !_busy,
                onTap: () => _choose(UserRole.student),
              ),
              const SizedBox(height: 14),
              _RoleTile(
                title: context.t('auth.role.club'),
                description: context.t('auth.roleStep.club.desc'),
                icon: Icons.groups_outlined,
                enabled: !_busy,
                onTap: () => _choose(UserRole.club),
              ),

              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: Text(context.t('common.logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rol kartı.
///
/// Kart zemini sabit beyaz kalıyordu; koyu modda üzerine gelen açık metinle
/// birlikte "Öğrenciyim / Kulübüm" başlıkları neredeyse okunmuyordu. Artık
/// zemin de metin de temadan geliyor ve başlık, marka kırmızısıyla nefes alan
/// bir neon parıltı taşıyor — hangi kartın dokunulabilir olduğu bir bakışta
/// belli oluyor.
class _RoleTile extends StatefulWidget {
  const _RoleTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        // Devre dışıyken parıltı sabit kalır: bekleyen bir kart göz çelmesin.
        final double glow = widget.enabled ? t : 0;

        return InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          borderRadius: BorderRadius.circular(BrandShape.cardRadius),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(BrandShape.cardRadius),
                border: Border.all(
                  color: BrandColors.red.withValues(alpha: 0.20 + 0.30 * glow),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: BrandColors.red.withValues(
                      alpha: (context.isDarkMode ? 0.22 : 0.14) + 0.16 * glow,
                    ),
                    blurRadius: 18 + 14 * glow,
                    spreadRadius: 1 + 2 * glow,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: BrandColors.gradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: BrandColors.red.withValues(
                            alpha: 0.30 + 0.30 * glow,
                          ),
                          blurRadius: 14 + 10 * glow,
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: BrandColors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: context.ink,
                            shadows: <Shadow>[
                              Shadow(
                                color: BrandColors.red.withValues(
                                  alpha: 0.35 + 0.35 * glow,
                                ),
                                blurRadius: 10 + 10 * glow,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.brandInk),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
