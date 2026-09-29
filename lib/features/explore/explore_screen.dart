import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/system_ui.dart';
import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart' show eventCardDate, eventFeeLabel;
import '../auth/auth_widgets.dart' show LanguageToggleDark;
import 'explore_providers.dart';

/// Keşfet — misafir vitrini.
///
/// Giriş yapmadan etkinliklere göz atma. Salt görüntüleme: kayıt olma, QR
/// üretme, belge indirme gibi eylemler yok; hepsi giriş gerektiriyor.
///
/// Alt gezinme çubuğu yok, yalnızca üst çubuk: solda "Giriş Yap",
/// sağda dil değiştirici.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    this.initialEventId = '',
    this.externalQrUri,
    super.key,
  });

  /// Dış QR'dan gelindiyse liste beklenmeden bu etkinliğin penceresi açılır.
  final String initialEventId;

  /// Giriş/kayıt akışının tamamlanınca aynı QR niyetine geri dönebilmesi için
  /// özgün güvenli URI. Sadece router tarafından ayrıştırılmış QR rotasıdır.
  final Uri? externalQrUri;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  /// Etkinlik penceresi açıkken sol şerit gizlenir — pencerenin üstünde
  /// asılı kalıp dikkat dağıtmasın diye.
  bool _sheetOpen = false;
  Timer? _expiryTimer;
  String? _autoOpenedEventId;

  @override
  void initState() {
    super.initState();

    // Liste ekran açıkken bir etkinliğin son başvuru anı geçebilir. Tek seferlik
    // veri okuması bu anda kendiliğinden yenilenmediği için en yakın bitişe
    // zamanlayıcı kuruyoruz; böylece geçmiş kart ekranda kalmıyor.
    ref.listenManual<AsyncValue<ExploreResult>>(exploreEventsProvider, (
      AsyncValue<ExploreResult>? _,
      AsyncValue<ExploreResult> next,
    ) {
      next.whenData((ExploreResult result) {
        if (result is ExploreEvents) _scheduleExpiryRefresh(result.events);
      });
    }, fireImmediately: true);

    // Sayfa her açıldığında sıra değişsin — sabit bir sıralama olmasın.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exploreShuffleProvider.notifier).reshuffle();
    });
  }

  void _scheduleExpiryRefresh(List<AppEvent> events) {
    _expiryTimer?.cancel();

    final DateTime now = DateTime.now();
    DateTime? nearest;
    for (final AppEvent event in events) {
      if (event.deadlineAtMs <= 0) continue;
      final DateTime deadline = DateTime.fromMillisecondsSinceEpoch(
        event.deadlineAtMs,
      );
      if (!deadline.isAfter(now)) continue;
      if (nearest == null || deadline.isBefore(nearest)) nearest = deadline;
    }

    if (nearest == null) return;
    _expiryTimer = Timer(
      nearest.difference(now) + const Duration(seconds: 1),
      () {
        if (mounted) ref.invalidate(exploreEventsProvider);
      },
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _exit() => context.canPop() ? context.pop() : context.go(Routes.landing);

  /// Detay penceresini açar ve kapanana kadar şeridi gizli tutar.
  Future<void> _openDetail(AppEvent event) async {
    setState(() => _sheetOpen = true);
    await showEventDetailSheet(
      context,
      event,
      onSignIn: widget.externalQrUri == null
          ? null
          : () {
              final String destination = Uri(
                path: Routes.landing,
                queryParameters: <String, String>{
                  kExternalQrContinueParam: widget.externalQrUri.toString(),
                },
              ).toString();
              GoRouter.of(context).go(destination);
            },
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  void _openInitialEvent(AppEvent? event) {
    if (event == null || widget.initialEventId.isEmpty) return;
    if (_autoOpenedEventId == event.id) return;
    _autoOpenedEventId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDetail(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ExploreResult> result = ref.watch(exploreEventsProvider);
    final AppEvent? initialEvent = widget.initialEventId.isEmpty
        ? null
        : ref.watch(eventByIdProvider(widget.initialEventId)).value;

    _openInitialEvent(initialEvent);

    return DarkScreenSystemBars(
      child: Scaffold(
        backgroundColor: context.authColors.base,
        appBar: AppBar(
          backgroundColor: context.authColors.card,
          foregroundColor: context.authColors.text,
          // AppBar durum çubuğunun stilini kendi başına bildiriyor; temadan
          // gelen değer bırakılsaydı açık temada koyu simge çizilir ve
          // simgeler bu koyu başlığın üstünde kaybolurdu. Sarmalayıcının
          // (DarkScreenSystemBars) alt çubuk için verdiği karar burada üst
          // çubuk için de tekrarlanıyor.
          systemOverlayStyle: systemBarsStyle(brightness: Brightness.dark),
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          title: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _exit,
              style: TextButton.styleFrom(
                // Keşfet'te vurgu kırmızıya alındı; koyu zeminde okunaklı
                // kalması için marka kırmızısının açık tonu kullanılıyor.
                foregroundColor: context.authColors.accent,
                backgroundColor: context.authColors.field,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BrandShape.pillRadius),
                ),
              ),
              icon: const Icon(Icons.login, size: 18),
              label: Text(
                context.t('auth.emailLogin'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            LanguageToggleDark(
              accent: context.authColors.accent,
              animatedGlobe: true,
            ),
            SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: <Widget>[
            result.when(
              loading: () => const LoadingView(),
              error: (Object error, StackTrace _) =>
                  _ExploreMessage(text: context.t('explore.loadError')),
              data: (ExploreResult data) => switch (data) {
                ExplorePermissionDenied() => _ExploreMessage(
                  text: context.t('explore.permissionDenied'),
                ),
                ExploreFailed() => _ExploreMessage(
                  text: context.t('explore.loadError'),
                ),
                ExploreEvents(events: final List<AppEvent> events) =>
                  events.isEmpty
                      ? _ExploreMessage(text: context.t('explore.empty'))
                      : _ExploreList(events: events, onOpenDetail: _openDetail),
              },
            ),

            // Sol kenarda, dikey ortada duran çıkış şeridi.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ExitTab(visible: !_sheetOpen, onTap: _exit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sol kenarda yüzen çıkış düğmesi.
///
/// Tasarım kararları:
///
///  * **Kenara yapışık değil, 10 px içeride.** Android'de ekranın sol kenarı
///    sistemin geri-kaydırma bölgesi; oraya yapışık bir düğme sistem
///    hareketiyle çakışır ve basmak zorlaşır. İçeri almak bunu çözüyor,
///    üstelik yüzen düğme daha kasıtlı duruyor.
///  * **Görsel küçük, dokunma alanı büyük.** Görünen daire 34 px, ama
///    dokunulabilir alan 56x76 px. Material'ın önerdiği 48 px eşiğinin
///    üstünde; küçük görünüp rahat basılıyor.
///  * **Buzlu cam.** Giriş ekranındaki kartla aynı dil — beyaz blok yerine
///    arka planı süzen bir yüzey, koyu sahnede daha yumuşak oturuyor.
class _ExitTab extends StatefulWidget {
  const _ExitTab({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  static const double _visualSize = 34;
  static const double _tapWidth = 56;
  static const double _tapHeight = 76;

  @override
  State<_ExitTab> createState() => _ExitTabState();
}

class _ExitTabState extends State<_ExitTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      // Gizlenirken sola kayarak çıkar; ani kaybolmak yerine yön belli olur.
      child: AnimatedSlide(
        offset: widget.visible ? Offset.zero : const Offset(-1, 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: GestureDetector(
            // opaque: saydam boşluklar da dokunmayı yakalar, yani tüm
            // 56x76 alan basılabilir.
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: SizedBox(
              width: _ExitTab._tapWidth,
              height: _ExitTab._tapHeight,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? 0.88 : 1,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: const _ExitTabVisual(size: _ExitTab._visualSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Düğmenin görünen kısmı — buzlu cam daire, ince kenarlık, kırmızı ok.
class _ExitTabVisual extends StatelessWidget {
  const _ExitTabVisual({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: BrandColors.blackDeep.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.authColors.card.withValues(alpha: 0.7),
              border: Border.all(
                color: context.authColors.cardBorder,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: size * 0.42,
              color: context.authColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreList extends ConsumerWidget {
  const _ExploreList({required this.events, required this.onOpenDetail});

  final List<AppEvent> events;
  final ValueChanged<AppEvent> onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: BrandColors.red,
      backgroundColor: context.authColors.card,
      onRefresh: () async =>
          ref.read(exploreShuffleProvider.notifier).reshuffle(),
      child: ListView.separated(
        // Sol şerit kartların üstüne binmesin diye soldan biraz fazla boşluk.
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 28),
        itemCount: events.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) return const _GuestNotice();
          final AppEvent event = events[index - 1];
          return _ExploreCard(event: event, onTap: () => onOpenDetail(event));
        },
      ),
    );
  }
}

/// Misafir olduğunu ve neyin kısıtlı olduğunu açıkça söyleyen şerit.
class _GuestNotice extends StatelessWidget {
  const _GuestNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Ekrandaki diğer vurgularla aynı kırmızı; iki farklı kırmızı yan
        // yana gelince ikisi de yanlış görünüyor.
        color: context.authColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(
          color: context.authColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.visibility_outlined,
            color: context.authColors.accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.t('explore.guestTitle'),
                  style: TextStyle(
                    color: context.authColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t('explore.guestDesc'),
                  style: TextStyle(
                    color: context.authColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.event, required this.onTap});

  final AppEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool past = isPastEvent(event);

    return Material(
      color: context.authColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        side: BorderSide(color: context.authColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(BrandShape.controlRadius),
                child: Stack(
                  children: <Widget>[
                    EventImage(url: event.displayImageUrl, height: 168),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: EventDatePill(
                        label: eventCardDate(context, event),
                      ),
                    ),
                    // Geçmiş etkinlikler soluklaştırılır — vitrinde kalırlar ama
                    // aktif olanlarla karışmazlar.
                    if (past)
                      Positioned.fill(
                        child: ColoredBox(
                          color: context.authColors.base.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: StatusPill(
                        label: past
                            ? context.t('dashboard.status.expired')
                            : context.t('dashboard.status.open'),
                        tone: past ? FeedbackTone.error : FeedbackTone.success,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      style: TextStyle(
                        fontFamily: BrandFonts.heading,
                        color: context.authColors.text,
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _Meta(
                      icon: Icons.groups_outlined,
                      text: event.clubName.isNotEmpty
                          ? event.clubName
                          : context.t('dashboard.clubFallback'),
                    ),
                    _Meta(
                      icon: Icons.calendar_today_outlined,
                      text: formatDeadline(
                        event.deadlineAtMs,
                        locale: context.lang,
                      ),
                    ),
                    if (event.locationName.isNotEmpty)
                      _Meta(
                        icon: Icons.place_outlined,
                        text: event.locationName,
                      ),
                    _Meta(
                      icon: Icons.payments_outlined,
                      text: eventFeeLabel(context, event),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 16, color: context.authColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.authColors.muted,
              fontSize: 13.5,
              height: 1.35,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Salt görüntüleme detayı — kayıt olma düğmesi yok, yerine giriş çağrısı var.
///
/// Pencere kapanınca tamamlanır; çağıran taraf bunu bekleyip sol çıkış
/// şeridini geri getirir.
Future<void> showEventDetailSheet(
  BuildContext context,
  AppEvent event, {
  VoidCallback? onSignIn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.authColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(BrandShape.sheetRadius),
      ),
    ),
    builder: (BuildContext sheetContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        // Misafir vitrini listeyi tek sefer okur. Pencere ise etkinlik
        // dokümanını canlı izler; kulüp ad/alan/üniversite senkronizasyonu ve
        // etkinlik düzenlemeleri pencere açıkken de anında görünür.
        final AppEvent currentEvent =
            ref.watch(eventByIdProvider(event.id)).value ?? event;

        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController controller) => Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: EventImage(
                        url: currentEvent.displayImageUrl,
                        height: 190,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            currentEvent.title,
                            style: TextStyle(
                              color: context.authColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ExploreClubHeader(event: currentEvent),
                          const SizedBox(height: 12),
                          _Meta(
                            icon: Icons.calendar_today_outlined,
                            text: formatDeadline(
                              currentEvent.deadlineAtMs,
                              locale: context.lang,
                            ),
                          ),
                          _Meta(
                            icon: Icons.payments_outlined,
                            text: eventFeeLabel(context, currentEvent),
                          ),
                          if (currentEvent.locationName.isNotEmpty)
                            _Meta(
                              icon: Icons.place_outlined,
                              text: currentEvent.locationName,
                            ),
                          const SizedBox(height: 18),
                          Text(
                            currentEvent.description.isNotEmpty
                                ? currentEvent.description
                                : context.t('dashboard.modal.noDescription'),
                            style: TextStyle(
                              color: context.authColors.text,
                              height: 1.55,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: BrandColors.red,
                        foregroundColor: BrandColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        // Önce pencereyi kapat, sonra giriş ekranına dön.
                        // `pop` yerine `go`: pencere de bir rota olduğu için
                        // arka arkaya iki pop hangi katmanı kapatacağı belirsiz
                        // olurdu.
                        Navigator.of(sheetContext).pop();
                        if (onSignIn != null) {
                          onSignIn();
                        } else {
                          GoRouter.of(context).go(Routes.landing);
                        }
                      },
                      icon: const Icon(Icons.login, size: 20),
                      label: Text(context.t('explore.signInToJoin')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Etkinliği düzenleyen kulübün kısa kimliği.
///
/// Web'deki başlık düzeniyle aynı şekilde kulüp adı, etkinlik başlığının hemen
/// altında durur; alanı ve üniversitesi uzun açıklama yerine kısa baloncuklarla
/// verilir.
class _ExploreClubHeader extends StatelessWidget {
  const _ExploreClubHeader({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final String name = event.clubName.isNotEmpty
        ? event.clubName
        : context.t('dashboard.clubFallback');
    final List<String> facts = <String>[
      ...eventClubFields(event),
      if (event.clubUniversity.isNotEmpty) event.clubUniversity,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: BrandColors.gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.groups_outlined,
            size: 21,
            color: BrandColors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.authColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (facts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final String fact in facts)
                      _ExploreClubBubble(text: fact),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExploreClubBubble extends StatelessWidget {
  const _ExploreClubBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: context.authColors.accent.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      border: Border.all(
        color: context.authColors.accent.withValues(alpha: 0.28),
      ),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: context.authColors.accent,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ExploreMessage extends ConsumerWidget {
  const _ExploreMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.explore_off_outlined,
              size: 48,
              color: context.authColors.muted,
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.authColors.muted,
                height: 1.5,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.authColors.text,
                side: BorderSide(color: context.authColors.cardBorder),
              ),
              onPressed: () =>
                  ref.read(exploreShuffleProvider.notifier).reshuffle(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.t('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}
