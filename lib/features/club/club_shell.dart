import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../notifications/notification_bell.dart';
import '../shared/common_widgets.dart';
import '../shared/shell_location.dart';

/// Alt çubuğun ortasındaki QR düğmesinin çapı.
const double _kQrButtonSize = 66;

/// Çubuğun boyalı yüzeyinin yüksekliği (güvenli alan hariç).
const double _kBarHeight = 64;

const double _kOverhang = _kQrButtonSize / 2;

/// QR düğmesinin merkezi, çubuk üst çizgisinin biraz altında kalır.
const double _kQrDrop = 5;

const double _kNotchRadius = _kQrButtonSize / 2 + 7;

/// Ortadaki düğmenin sekmelerle çakışmasını önleyen yatay aralık.
const double _kQrClearance = _kQrButtonSize + 12;

const Key clubQrToggleKey = Key('club.qrToggle');
const Key clubQrScanActionKey = Key('club.qrAction.scan');
const Key clubQrCreateActionKey = Key('club.qrAction.create');

/// club-dashboard.html içindeki yan çekmecenin mobil karşılığı.
///
/// Öğrenci kabuğuyla birebir aynı dil: dört sekme ve ortadaki çöküntüye oturan
/// QR düğmesi. Düğme iki eylemi temsil eder — **QR Okut** (öğrencinin kodunu
/// okutmak) ve **QR Oluştur** (oturum kodunu ekrana basmak) — dokunulduğunda
/// ikisi düğmenin hemen üstünde yan yana açılır.
class ClubShell extends ConsumerStatefulWidget {
  const ClubShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<ClubShell> createState() => _ClubShellState();
}

class _ClubShellState extends ConsumerState<ClubShell> {
  bool _qrMenuOpen = false;

  static const List<({String route, IconData icon, String labelKey})>
  _leftTabs = <({String route, IconData icon, String labelKey})>[
    (
      route: Routes.clubHome,
      icon: Icons.explore_outlined,
      labelKey: 'dashboard.drawer.events',
    ),
    (
      route: Routes.clubEvents,
      icon: Icons.event_note_outlined,
      labelKey: 'club.nav.myEvents',
    ),
  ];

  static const List<({String route, IconData icon, String labelKey})>
  _rightTabs = <({String route, IconData icon, String labelKey})>[
    (
      route: Routes.clubCreateEvent,
      icon: Icons.add_circle_outline,
      labelKey: 'club.nav.newEvent',
    ),
    (
      route: Routes.clubAccount,
      icon: Icons.person_outline,
      labelKey: 'student.nav.account',
    ),
  ];

  /// Vurgulama, ShellRoute'un verdiği konumdan değil router'ın canlı
  /// durumundan okunur (bkz. ShellLocationBuilder).
  String get _location => liveLocation(context, widget.location);

  /// QR ekranlarındayken orta düğme de seçili görünmeli.
  bool _qrRouteActive(String location) =>
      location == Routes.clubQrCheckin || location == Routes.clubSessionQr;

  void _toggleQrMenu() => setState(() => _qrMenuOpen = !_qrMenuOpen);

  void _closeQrMenu() {
    if (_qrMenuOpen) setState(() => _qrMenuOpen = false);
  }

  void _goTab(String route) {
    _closeQrMenu();
    if (_location == route) return;

    // Etkinlik oluşturma bir sekme değil, üzerine itilen bir form: geri
    // dönebilmek gerekiyor.
    if (route == Routes.clubCreateEvent) {
      context.push(route);
      return;
    }
    context.go(route);
  }

  void _goQr(String route) {
    final String current = _location;
    setState(() => _qrMenuOpen = false);
    if (current != route) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          widget.child,

          // Menü açıkken arka içerik hafif buğulanır.
          if (_qrMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeQrMenu,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
                  child: ColoredBox(
                    color: BrandColors.black.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),

          // İki QR eylemi: QR düğmesinin hemen üstünde, yan yana.
          Positioned(
            left: 0,
            right: 0,
            bottom: _kOverhang + _kQrDrop + 12,
            child: IgnorePointer(
              ignoring: !_qrMenuOpen,
              child: AnimatedOpacity(
                opacity: _qrMenuOpen ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: AnimatedSlide(
                  offset: Offset(0, _qrMenuOpen ? 0 : 0.35),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _QrAction(
                        key: clubQrScanActionKey,
                        icon: Icons.qr_code_scanner,
                        label: context.t('dashboard.drawer.qrCheckin'),
                        onTap: () => _goQr(Routes.clubQrCheckin),
                      ),
                      const SizedBox(width: 12),
                      _QrAction(
                        key: clubQrCreateActionKey,
                        icon: Icons.qr_code_2,
                        label: context.t('dashboard.drawer.qrGenerate'),
                        onTap: () => _goQr(Routes.clubSessionQr),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ShellLocationBuilder(
        fallback: widget.location,
        builder: (BuildContext context, String location) => _FloatingQrNavBar(
          location: location,
          leftTabs: _leftTabs,
          rightTabs: _rightTabs,
          qrActive: _qrRouteActive(location) || _qrMenuOpen,
          qrMenuOpen: _qrMenuOpen,
          onTabSelected: _goTab,
          onQrPressed: _toggleQrMenu,
        ),
      ),
    );
  }
}

/// Ortası çökük alt çubuk ve onun üzerinde yüzen QR düğmesi.
class _FloatingQrNavBar extends StatelessWidget {
  const _FloatingQrNavBar({
    required this.location,
    required this.leftTabs,
    required this.rightTabs,
    required this.qrActive,
    required this.qrMenuOpen,
    required this.onTabSelected,
    required this.onQrPressed,
  });

  final String location;
  final List<({String route, IconData icon, String labelKey})> leftTabs;
  final List<({String route, IconData icon, String labelKey})> rightTabs;
  final bool qrActive;
  final bool qrMenuOpen;
  final ValueChanged<String> onTabSelected;
  final VoidCallback onQrPressed;

  @override
  Widget build(BuildContext context) {
    // Cihazın gezinme çubuğu görünürken kapladığı alan çubuğun altına boşluk
    // olarak eklenir; sekmeler her hâlükârda çubuğun üstünde kalır.
    final double safeBottom = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _kBarHeight + safeBottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _NotchedBarPainter(surface: context.surface),
              child: Padding(
                padding: EdgeInsets.only(bottom: safeBottom),
                // Ink'in çubuk yüzeyinin ÜZERİNDE çizilmesi için araya saydam
                // bir Material giriyor; yoksa dalga arkadaki Scaffold
                // yüzeyine düşüyor ve tüm çubuk yanıyormuş gibi görünüyor.
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    children: <Widget>[
                      for (final ({
                            IconData icon,
                            String labelKey,
                            String route,
                          })
                          tab
                          in leftTabs)
                        Expanded(
                          child: _NavTab(
                            tab: tab,
                            selected: location == tab.route,
                            onTap: () => onTabSelected(tab.route),
                          ),
                        ),
                      const SizedBox(width: _kQrClearance),
                      for (final ({
                            IconData icon,
                            String labelKey,
                            String route,
                          })
                          tab
                          in rightTabs)
                        Expanded(
                          child: _NavTab(
                            tab: tab,
                            selected: location == tab.route,
                            onTap: () => onTabSelected(tab.route),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: -_kOverhang + _kQrDrop,
            left: 0,
            right: 0,
            child: Center(
              child: _QrButton(
                key: clubQrToggleKey,
                active: qrActive,
                menuOpen: qrMenuOpen,
                onPressed: onQrPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üst kenarı yuvarlatılmış, ortasında QR için çöküntü bulunan çubuk zemini.
class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({required this.surface});

  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final Path bar = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
        ),
      );

    final Path notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, _kQrDrop),
          radius: _kNotchRadius,
        ),
      );

    final Path shape = Path.combine(PathOperation.difference, bar, notch);

    canvas.drawShadow(shape, const Color(0x40000000), 10, true);
    canvas.drawPath(shape, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) =>
      oldDelegate.surface != surface;
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
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton({
    required this.active,
    required this.menuOpen,
    required this.onPressed,
    super.key,
  });

  final bool active;
  final bool menuOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kQrButtonSize,
      height: _kQrButtonSize,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: BrandColors.gradient,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: BrandColors.redDark.withValues(
                  alpha: active ? 0.45 : 0.3,
                ),
                blurRadius: active ? 20 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: AnimatedRotation(
                turns: menuOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  menuOpen ? Icons.close : Icons.qr_code_2,
                  color: BrandColors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// QR düğmesine basınca açılan iki eylemden biri.
class _QrAction extends StatelessWidget {
  const _QrAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(BrandShape.pillRadius);
    final Color glassBase = context.isDarkMode
        ? BrandColors.white.withValues(alpha: 0.16)
        : BrandColors.white.withValues(alpha: 0.48);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: BrandColors.red.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: BrandColors.white.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  BrandColors.white.withValues(alpha: 0.58),
                  glassBase,
                  BrandColors.redOnDark.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: BrandColors.white.withValues(alpha: 0.64),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 19, color: context.brandInk),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.ink,
                          shadows: <Shadow>[
                            Shadow(
                              color: BrandColors.white.withValues(alpha: 0.72),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kulüp ekranlarının ortak üst çubuğu — öğrenci tarafıyla aynı düzen.
class ClubAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClubAppBar({
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = false,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Verilmezse bildirimler düğmesi gösterilir.
  final List<Widget>? actions;

  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack ? BackButton(onPressed: () => context.pop()) : null,
      titleSpacing: showBack ? 0 : 16,
      title: Row(
        children: <Widget>[
          const BrandMark(size: 30),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: context.inkMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions:
          actions ??
          <Widget>[
            const NotificationBellButton(route: Routes.clubNotifications),
            const SizedBox(width: 4),
          ],
    );
  }
}
