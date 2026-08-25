import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import 'club_providers.dart';
import 'club_shell.dart';

/// club-events.html + js/pages/club-events.js karşılığı — kulübün kendi
/// etkinlikleri.
///
/// Web'de üç ayrı ızgara vardı (aktif / beklemede / geçmiş). Mobilde aynı üç
/// grup, listenin üstündeki yuvarlak sayaçlı düğmelerle değiştirilir.
class ClubEventsScreen extends ConsumerStatefulWidget {
  const ClubEventsScreen({super.key});

  @override
  ConsumerState<ClubEventsScreen> createState() => _ClubEventsScreenState();
}

enum _Group { active, pending, past }

class _ClubEventsScreenState extends ConsumerState<ClubEventsScreen> {
  _Group _group = _Group.active;

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  /// Süresi geçmemiş etkinlik herkesten silinir; geçmiş etkinlik yalnızca
  /// kulüp listesinden kaldırılır (öğrencinin geçmiş kaydı bozulmasın).
  Future<void> _delete(AppEvent event) async {
    final bool globally = !isPastEvent(event);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.t('clubEvents.delete.title')),
        content: Text(
          globally
              ? dialogContext.t('clubEvents.delete.confirmGlobal')
              : dialogContext.t('clubEvents.delete.confirmLocal'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dialogContext.t('clubEvents.delete.action'),
              style: const TextStyle(color: BrandColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (globally) {
        await ref.read(eventRepositoryProvider).deleteEvent(event.id);
      } else {
        await ref.read(eventRepositoryProvider).hideFromClubList(event.id);
      }
      if (mounted) _toast(context.t('clubEvents.feedback.deleted'));
    } catch (_) {
      if (mounted) _toast(context.t('clubEvents.feedback.deleteError'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppEvent>> events = ref.watch(clubEventsProvider);

    return Scaffold(
      appBar: ClubAppBar(title: context.t('club.nav.myEvents')),
      body: events.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('clubEvents.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<AppEvent> _) {
          final ClubEventGroups groups = ref.watch(clubEventGroupsProvider);

          final List<AppEvent> visible = switch (_group) {
            _Group.active => groups.active,
            _Group.pending => groups.pending,
            _Group.past => groups.past,
          };

          final String emptyMessage = switch (_group) {
            _Group.active => context.t('clubEvents.empty.active'),
            _Group.pending => context.t('clubEvents.empty.pending'),
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
                      label: context.t('clubEvents.group.pending'),
                      count: groups.pending.length,
                      selected: _group == _Group.pending,
                      onTap: () => setState(() => _group = _Group.pending),
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
                              canEdit: !isPastEvent(event),
                              onEdit: () => context.push(
                                '${Routes.clubCreateEvent}?eventId=${Uri.encodeComponent(event.id)}',
                              ),
                              onDelete: () => _delete(event),
                              deleteLabel: isPastEvent(event)
                                  ? context.t('clubEvents.delete.local')
                                  : context.t('clubEvents.delete.global'),
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

/// Aktif / beklemede / geçmiş seçimi — öğrenci tarafındaki sayaçlı yuvarlak
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
