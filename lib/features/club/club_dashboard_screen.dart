import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../services/club_follow_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import 'club_providers.dart';
import 'club_shell.dart';

/// club-dashboard.html + js/pages/club-dashboard.js karşılığı.
///
/// Kulüp burada **başka kulüplerin** etkinliklerini keşfeder; kendi
/// etkinliklerini yönettiği yer "Etkinliklerim" sekmesi. Sıralama öğrenci
/// keşfiyle aynı algoritmayı kullanır: kulübün üniversitesi ve alanı,
/// öğrencinin üniversite/bölümünün yerine geçer.
class ClubDashboardScreen extends ConsumerStatefulWidget {
  const ClubDashboardScreen({this.openEventId, super.key});

  final String? openEventId;

  @override
  ConsumerState<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends ConsumerState<ClubDashboardScreen> {
  String? _openedEventId;

  @override
  Widget build(BuildContext context) {
    final ClubProfile? club = ref.watch(sessionProvider).clubProfile;
    final AsyncValue<List<AppEvent>> events =
        ref.watch(clubDiscoverEventsProvider);

    final String? requestedId = widget.openEventId;
    if (requestedId != null && requestedId.isNotEmpty &&
        requestedId != _openedEventId) {
      final AppEvent? requested = ref.watch(eventByIdProvider(requestedId)).value;
      if (requested != null) {
        _openedEventId = requestedId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (requested.clubId == ref.read(currentUidProvider)) {
            context.go('${Routes.clubEventDetail}?eventId=${Uri.encodeComponent(requestedId)}');
          } else {
            showEventDetailSheet(context, event: requested, forClub: true);
          }
        });
      }
    }

    final String name = (club?.clubName ?? '').isNotEmpty
        ? club!.clubName
        : context.t('dashboard.clubFallback');

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('dashboard.welcome', <String, Object?>{'name': name}),
        subtitle: context.t('dashboard.drawer.events'),
      ),
      body: RefreshIndicator(
        color: BrandColors.red,
        onRefresh: () async => ref.invalidate(clubDiscoverEventsProvider),
        child: events.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace _) => ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              FeedbackBanner(
                message: context.t('clubEvents.feedback.loadError'),
                tone: FeedbackTone.error,
              ),
            ],
          ),
          data: (List<AppEvent> list) {
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  const ClubFollowerCountChip(),
                  const SizedBox(height: 14),
                  EmptyState(
                    message: context.t('clubDashboard.empty'),
                    icon: Icons.event_busy_outlined,
                  ),
                ],
              );
            }

            final StudentProfile? pseudo = pseudoStudentFromClub(club);

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (BuildContext context, int index) {
                // İP-TK: takipçi sayısı (liste yok; yalnızca sayı).
                if (index == 0) {
                  return Column(
                    children: <Widget>[
                      PageHeader(
                        title: context.t('clubDashboard.hero.title'),
                        subtitle: context.t('clubDashboard.hero.subtitle'),
                        center: true,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                      ),
                      const ClubFollowerCountChip(),
                    ],
                  );
                }
                final AppEvent event = list[index - 1];
                return EventSummaryCard(
                  event: event,
                  priority: getStudentEventPriority(event, pseudo),
                  onTap: () => showEventDetailSheet(
                    context,
                    event: event,
                    priority: getStudentEventPriority(event, pseudo),
                    forClub: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Kulübün takipçi sayısı (İP-TK) — web: club-dashboard.html #clubFollowerStat.
class ClubFollowerCountChip extends ConsumerWidget {
  const ClubFollowerCountChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? count = ref.watch(clubFollowerCountProvider).value;
    if (count == null) return const SizedBox.shrink();
    return Align(
      child: Container(
        key: const ValueKey<String>('club-follower-count'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.favorite_border, size: 16, color: context.brandInk),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 5),
            Text(
              context.t('follow.club.followers'),
              style: TextStyle(color: context.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
