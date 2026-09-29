import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../auth/auth_actions.dart';
import '../shared/common_widgets.dart';
import '../shared/shell_location.dart';

/// admin-nav.js içindeki yan çekmecenin mobil karşılığı.
///
/// Öğrenci ve kulüp kabuklarından farkı: ortada QR düğmesi yok — yöneticinin
/// QR ile işi olmuyor. Bu yüzden düz, dört eşit sekmeli bir çubuk.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<({String route, IconData icon, String labelKey})> _tabs =
      <({String route, IconData icon, String labelKey})>[
    (
      route: Routes.adminHome,
      icon: Icons.fact_check_outlined,
      labelKey: 'admin.nav.pending',
    ),
    (
      route: Routes.adminStats,
      icon: Icons.insights_outlined,
      labelKey: 'admin.nav.stats',
    ),
    (
      route: Routes.adminClubs,
      icon: Icons.groups_outlined,
      labelKey: 'admin.nav.clubs',
    ),
    (
      route: Routes.adminBan,
      icon: Icons.block_outlined,
      labelKey: 'admin.nav.ban',
    ),
    (
      route: Routes.adminNotifications,
      icon: Icons.notifications_none_rounded,
      labelKey: 'student.notifications.title',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: child,
      bottomNavigationBar: ShellLocationBuilder(
        fallback: location,
        builder: (BuildContext context, String current) => Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: BrandColors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: safeBottom),
            child: SizedBox(
              height: 64,
              child: Row(
                children: <Widget>[
                  for (final ({
                        IconData icon,
                        String labelKey,
                        String route,
                      })
                      tab in _tabs)
                    Expanded(
                      child: _NavTab(
                        tab: tab,
                        selected: current == tab.route,
                        onTap: () {
                          if (current != tab.route) context.go(tab.route);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ({String route, IconData icon, String labelKey}) tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? context.brandInk : context.inkMuted;

    // Ink dalgası simgeyle sınırlı bir daire: sınırsız bırakıldığında
    // çubuğun tamamı yanıyormuş gibi görünüyordu.
    return InkResponse(
      onTap: onTap,
      radius: 26,
      containedInkWell: false,
      highlightShape: BoxShape.circle,
      splashColor: BrandColors.red.withValues(alpha: 0.16),
      highlightColor: BrandColors.red.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(tab.icon, size: 23, color: color),
          const SizedBox(height: 3),
          Text(
            context.t(tab.labelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yönetici ekranlarının ortak üst çubuğu.
class AdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const AdminAppBar({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: <Widget>[
          const BrandMark(size: 30, color: BrandColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: BrandFonts.heading,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.3, color: context.inkMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          tooltip: context.t('common.logout'),
          onPressed: () async {
            await logout(ref);
          },
          icon: const Icon(Icons.logout, color: BrandColors.danger),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
