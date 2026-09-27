import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../notifications/notification_bell.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import 'club_providers.dart';
import 'club_shell.dart';

/// club-events.html + js/pages/club-events.js karşılığı — kulübün kendi
/// etkinlikleri.
///
/// Web'deki gelecek / aktif / geçmiş ayrımı, mobilde listenin üstündeki
/// yuvarlak sayaçlı düğmelerle değiştirilir. Kullanıcı ilk açılışta aktif
/// etkinlikleri görür; düğme sırası Aktif → Gelecek → Geçmiş'tir.
class ClubEventsScreen extends ConsumerStatefulWidget {
  const ClubEventsScreen({this.openEventId, super.key});

  /// QR okutma başarıyla tamamlandığında gösterilecek etkinlik.
  ///
  /// Tarayıcı ekranı doğrudan pencere açmaz; rota değişince ağaçtan düştüğü
  /// için pencerenin, güncel liste verisi ile burada açılması gerekir.
  final String? openEventId;

  @override
  ConsumerState<ClubEventsScreen> createState() => _ClubEventsScreenState();
}

enum _Group { active, upcoming, past }

class _ClubEventsScreenState extends ConsumerState<ClubEventsScreen> {
  _Group _group = _Group.active;

  /// Aynı URL parametresiyle yeniden build olduğunda pencerenin ikinci kez
  /// açılmasını engeller.
  String? _autoOpenedEventId;

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _openRequestedSheet(List<AppEvent> events) {
    final String? eventId = widget.openEventId;
    if (eventId == null || eventId.isEmpty || _autoOpenedEventId == eventId) {
      return;
    }

    AppEvent? event;
    for (final AppEvent candidate in events) {
      if (candidate.id == eventId) {
        event = candidate;
        break;
      }
    }
    if (event == null) return;

    _autoOpenedEventId = eventId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showEventDetailSheet(context, event: event!, forClub: true);
    });
  }

  /// İP-K (L5): günü geçmemiş etkinlik İPTAL edilir (sunucu: kayıtlılara ve
  /// bekleyenlere bildirim; kaydı yoksa tamamen siler). Geçmiş ya da iptal
  /// edilmiş etkinlik yalnızca kulüp listesinden kaldırılır.
  Future<void> _delete(AppEvent event) async {
    final bool cancellable = !isPastEvent(event) && !event.cancelled;
    final TextEditingController reason = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          cancellable
              ? dialogContext.t('registration.club.cancelEventTitle')
              : dialogContext.t('clubEvents.delete.title'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              cancellable
                  ? dialogContext.t('registration.club.cancelEventBody')
                  : dialogContext.t('clubEvents.delete.confirmLocal'),
            ),
            if (cancellable) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLength: 300,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: dialogContext.t('registration.club.reasonLabel'),
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              cancellable
                  ? dialogContext.t('registration.club.cancelEventAction')
                  : dialogContext.t('clubEvents.delete.action'),
              style: const TextStyle(color: BrandColors.danger),
            ),
          ),
        ],
      ),
    );

    final String reasonText = reason.text.trim();
    reason.dispose();
    if (confirmed != true) return;

    try {
      if (cancellable) {
        final ({String status, int notified}) result = await ref
            .read(registrationServiceProvider)
            .cancelEvent(eventId: event.id, reason: reasonText);
        if (!mounted) return;
        _toast(
          result.status == 'deleted'
              ? context.t('registration.club.eventDeleted')
              : context.t('registration.club.eventCancelled', <String, Object?>{
                  'n': result.notified,
                }),
        );
      } else {
        await ref.read(eventRepositoryProvider).hideFromClubList(event.id);
        if (mounted) _toast(context.t('clubEvents.feedback.deleted'));
      }
    } on RegistrationFailure catch (failure) {
      if (!mounted) return;
      _toast(
        failure.isNetwork
            ? context.t('clubEvents.feedback.deleteError')
            : context.t('registration.errors.${failure.reason}'),
      );
    } catch (_) {
      if (mounted) _toast(context.t('clubEvents.feedback.deleteError'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppEvent>> events = ref.watch(clubEventsProvider);

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('club.nav.myEvents'),
        actions: <Widget>[
          IconButton(
            key: const Key('clubEventNotificationsLink'),
            tooltip: context.t('clubNotify.title'),
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => context.push(Routes.clubEventNotifications),
          ),
          const NotificationBellButton(route: Routes.clubNotifications),
        ],
      ),
      body: events.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('clubEvents.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<AppEvent> allEvents) {
          _openRequestedSheet(allEvents);
          final ClubEventGroups groups = ref.watch(clubEventGroupsProvider);

          final List<AppEvent> visible = switch (_group) {
            _Group.active => groups.active,
            _Group.upcoming => groups.upcoming,
            _Group.past => groups.past,
          };

          final String emptyMessage = switch (_group) {
            _Group.active => context.t('clubEvents.empty.active'),
            _Group.upcoming => context.t('clubEvents.empty.upcoming'),
            _Group.past => context.t('clubEvents.empty.past'),
          };

          return Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Row(
                  children: <Widget>[
                    _GroupButton(
                      label: context.t('clubEvents.group.active'),
                      count: groups.active.length,
                      selected: _group == _Group.active,
                      onTap: () => setState(() => _group = _Group.active),
                    ),
                    const SizedBox(width: 8),
                    _GroupButton(
                      label: context.t('clubEvents.group.upcoming'),
                      count: groups.upcoming.length,
                      selected: _group == _Group.upcoming,
                      onTap: () => setState(() => _group = _Group.upcoming),
                    ),
                    const SizedBox(width: 8),
                    _GroupButton(
                      label: context.t('clubEvents.group.past'),
                      count: groups.past.length,
                      selected: _group == _Group.past,
                      onTap: () => setState(() => _group = _Group.past),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: <Widget>[
                          EmptyState(
                            message: emptyMessage,
                            icon: Icons.event_busy_outlined,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (BuildContext context, int index) {
                          final AppEvent event = visible[index];
                          return EventSummaryCard(
                            event: event,
                            onTap: () => context.push(
                              '${Routes.clubEventDetail}?eventId=${Uri.encodeComponent(event.id)}',
                            ),
                            footer: _CardActions(
                              // Geçmiş etkinlik düzenlenemez (web ile aynı).
                              canEdit: !isPastEvent(event) && !event.cancelled,
                              onEdit: () => context.push(
                                '${Routes.clubCreateEvent}?eventId=${Uri.encodeComponent(event.id)}',
                              ),
                              onDelete: () => _delete(event),
                              deleteLabel: isPastEvent(event) || event.cancelled
                                  ? context.t('clubEvents.delete.local')
                                  : context.t('registration.club.cancelEventAction'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.deleteLabel,
  });

  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (canEdit) ...<Widget>[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: Text(context.t('clubEvents.edit')),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: BrandColors.danger,
              minimumSize: const Size(0, 38),
            ),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 17),
            label: Text(
              deleteLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aktif / gelecek / geçmiş seçimi — öğrenci tarafındaki sayaçlı yuvarlak
/// düğmelerle aynı dil.
class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color idleFill = context.isDarkMode
        ? BrandColors.red.withValues(alpha: 0.18)
        : BrandColors.redTint;

    return Material(
      color: selected ? BrandColors.redSoft : idleFill,
      borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      elevation: selected ? 3 : 0,
      shadowColor: BrandColors.red.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? BrandColors.white : context.brandInk,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? BrandColors.white.withValues(alpha: 0.26)
                      : BrandColors.red.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(BrandShape.pillRadius),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? BrandColors.white : context.brandInk,
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
