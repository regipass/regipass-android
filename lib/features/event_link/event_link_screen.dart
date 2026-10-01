/// İP-EL: regipass.com/e/<kod> uygulamada açıldığında.
///
/// - Katılımcı hesabıyla girilmişse: etkinlik penceresi doğrudan açılır.
/// - Organizatör kendi etkinliğiyse: etkinlik detayı açılır.
/// - Oturum yoksa: etkinlik özeti + "Giriş yap" + "Hesapsız kaydol"
///   (misafir formu webde; uygulama içi tarayıcıda açılır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../services/event_link_service.dart';
import '../../state/providers.dart';

class EventLinkScreen extends ConsumerStatefulWidget {
  const EventLinkScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<EventLinkScreen> createState() => _EventLinkScreenState();
}

class _EventLinkScreenState extends ConsumerState<EventLinkScreen> {
  late final Future<PublicLinkEvent> _future = _resolve();
  bool _routed = false;

  Future<PublicLinkEvent> _resolve() {
    final String key = eventLinkKeyFromPath('/e/${widget.code}');
    if (key.isEmpty) return Future<PublicLinkEvent>.error(StateError('link-not-found'));
    return const EventLinkService().resolve(key);
  }

  /// Oturum açık ve hesap tamamsa kullanıcıyı kendi panelindeki etkinliğe götürür.
  void _routeSignedIn(Session session, PublicLinkEvent ev) {
    if (_routed || !session.isSignedIn || session.isLoading) return;
    final String? role = session.resolvedRole;
    String? target;
    if (role == UserRole.student) {
      target = '${Routes.studentHome}?openEventId=${Uri.encodeComponent(ev.id)}';
    } else if (role == UserRole.club && ev.clubId == session.user?.uid) {
      target = '${Routes.clubEventDetail}?eventId=${Uri.encodeComponent(ev.id)}';
    }
    if (target == null) return;
    _routed = true;
    final String to = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(to);
    });
  }

  void _login(PublicLinkEvent ev) {
    pendingEventLinkCode = ev.key;
    context.go(Routes.landing);
  }

  Future<void> _guest(PublicLinkEvent ev) async {
    final bool ok = await launchUrl(
      Uri.parse(eventLinkWebFormUrl(ev.key)),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!ok && mounted) {
      await launchUrl(
        Uri.parse(eventLinkWebFormUrl(ev.key)),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _home(Session session) {
    if (!session.isSignedIn) {
      context.go(Routes.explore);
      return;
    }
    context.go(
      session.resolvedRole == UserRole.club ? Routes.clubHome : Routes.studentHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: context.t('eventLink.close'),
          onPressed: () => _home(session),
        ),
        title: const Text('Regipass'),
      ),
      body: SafeArea(
        child: FutureBuilder<PublicLinkEvent>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<PublicLinkEvent> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final PublicLinkEvent? ev = snap.data;
            if (ev == null) return _NotFound(onHome: () => _home(session));
            _routeSignedIn(session, ev);
            if (_routed || (session.isSignedIn && session.isLoading)) {
              return const Center(child: CircularProgressIndicator());
            }
            return _Summary(
              event: ev,
              session: session,
              onLogin: () => _login(ev),
              onGuest: () => _guest(ev),
              onHome: () => _home(session),
            );
          },
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.link_off_rounded, size: 48, color: context.inkMuted),
          const SizedBox(height: 12),
          Text(
            context.t('eventLink.notFound'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            context.t('eventLink.notFoundHint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.inkMuted),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onHome, child: Text(context.t('eventLink.toHome'))),
        ],
      ),
    ),
  );
}

String _two(int v) => v.toString().padLeft(2, '0');

String _when(PublicLinkEvent ev) {
  if (ev.eventStartAtMs > 0) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ev.eventStartAtMs);
    return '${_two(d.day)}.${_two(d.month)}.${d.year} · ${_two(d.hour)}:${_two(d.minute)}';
  }
  return <String>[ev.eventDate, ev.eventStartTime]
      .where((String s) => s.isNotEmpty)
      .join(' · ');
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.event,
    required this.session,
    required this.onLogin,
    required this.onGuest,
    required this.onHome,
  });

  final PublicLinkEvent event;
  final Session session;
  final VoidCallback onLogin;
  final VoidCallback onGuest;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final bool open = event.status == 'open';
    final String when = _when(event);
    final String fee = event.feeType == 'paid'
        ? (event.feeAmount > 0 ? '${event.feeAmount} TL' : context.t('eventLink.paid'))
        : context.t('eventLink.free');
    final bool clubOther = session.isSignedIn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        if (event.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                event.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          event.clubName,
          style: TextStyle(color: context.inkMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          event.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (when.isNotEmpty) _Fact(icon: Icons.event_outlined, text: when),
        if (event.locationName.isNotEmpty)
          _Fact(icon: Icons.place_outlined, text: event.locationName),
        _Fact(icon: Icons.confirmation_number_outlined, text: fee),
        if (!open) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrandColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.t('eventLink.status.${event.status}'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (clubOther) ...<Widget>[
          // Organizatör hesabı (başkasının etkinliği): kayıt katılımcı hesabıyla.
          Text(
            context.t('eventLink.clubCannot'),
            style: TextStyle(color: context.inkMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onHome, child: Text(context.t('eventLink.toHome'))),
        ] else if (open) ...<Widget>[
          FilledButton.icon(
            key: const Key('eventLinkLogin'),
            icon: const Icon(Icons.login_rounded),
            label: Text(context.t('eventLink.login')),
            onPressed: onLogin,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('eventLinkGuest'),
            icon: const Icon(Icons.how_to_reg_outlined),
            label: Text(context.t('eventLink.guest')),
            onPressed: onGuest,
          ),
          const SizedBox(height: 8),
          Text(
            context.t('eventLink.guestHint'),
            style: TextStyle(fontSize: 12.5, color: context.inkMuted),
            textAlign: TextAlign.center,
          ),
        ] else
          OutlinedButton(onPressed: onHome, child: Text(context.t('eventLink.toHome'))),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: context.inkMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
