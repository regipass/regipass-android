/// Kulüp > Bildirimler (İP-KN) — club-notifications.html karşılığı.
///
/// Etkinlik listesi (yaklaşan / süren / son 7 günde biten) → etkinliğe
/// dokununca aynı ekran o etkinlik için açılır: otomatik bildirim anahtarları,
/// elle mesaj ve geçmiş (EventNotifyCard). Listenin altında kulübün tüm
/// etkinliklerindeki gönderimler (elle + otomatik).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/notification_center.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/firebase_refs.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import 'club_providers.dart';
import 'event_notify_card.dart';

/// Kulübün tüm elle mesajları (collectionGroup; kurallar yalnızca kendi
/// `byUid` kayıtlarını açar).
// ignore: always_specify_types
final clubAllMessagesProvider = StreamProvider<List<ClubMessageRecord>>((
  Ref ref,
) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) {
    return Stream<List<ClubMessageRecord>>.value(const <ClubMessageRecord>[]);
  }
  return fbDb
      .collectionGroup('club_messages')
      .where('byUid', isEqualTo: uid)
      .orderBy('sentAtMs', descending: true)
      .limit(60)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) =>
            snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
              final Map<String, dynamic> m = d.data();
              return ClubMessageRecord(
                eventId: d.reference.parent.parent?.id ?? '',
                title: '${m['title'] ?? ''}',
                message: '${m['message'] ?? ''}',
                audience: '${m['audience'] ?? ''}',
                recipients: (m['recipients'] as num?)?.toInt() ?? 0,
                sentAtMs: (m['sentAtMs'] as num?)?.toInt() ?? 0,
              );
            }).toList(),
      );
});

String _when(int ms, {bool time = true}) {
  if (ms <= 0) return '';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return time
      ? '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}'
      : '${two(d.day)}.${two(d.month)}.${d.year}';
}

class ClubEventNotificationsScreen extends ConsumerStatefulWidget {
  const ClubEventNotificationsScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<ClubEventNotificationsScreen> createState() =>
      _ClubEventNotificationsScreenState();
}

class _ClubEventNotificationsScreenState
    extends ConsumerState<ClubEventNotificationsScreen> {
  NotifyStage? _stage;
  String _search = '';
  String _historyType = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppEvent>> events = ref.watch(clubEventsProvider);
    final String? eventId = widget.eventId;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('clubNotify.title'))),
      body: events.when(
        loading: () => const LoadingView(),
        error: (Object _, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('clubEvents.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<AppEvent> all) {
          if (eventId != null && eventId.isNotEmpty) {
            final AppEvent? event = all
                .where((AppEvent e) => e.id == eventId)
                .firstOrNull;
            if (event == null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyState(
                  message: context.t('clubNotify.notFound'),
                  icon: Icons.event_busy_outlined,
                ),
              );
            }
            return _EventDetail(event: event);
          }
          return _buildList(context, all);
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<AppEvent> all) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final NotifyGroups groups = groupEventsForNotify(all, now);
    final NotifyStage stage =
        _stage ??
        (groups.upcoming.isEmpty && groups.active.isNotEmpty
            ? NotifyStage.active
            : NotifyStage.upcoming);
    final String term = _search.trim().toLowerCase();
    final List<AppEvent> list = groups
        .of(stage)
        .where(
          (AppEvent e) =>
              term.isEmpty ||
              e.title.toLowerCase().contains(term) ||
              e.locationName.toLowerCase().contains(term),
        )
        .toList();
    final AsyncValue<List<ClubMessageRecord>> messages = ref.watch(
      clubAllMessagesProvider,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: <Widget>[
        Text(context.t('clubNotify.subtitle'), style: text.bodyMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final NotifyStage s in <NotifyStage>[
              NotifyStage.upcoming,
              NotifyStage.active,
              NotifyStage.recent,
            ])
              ChoiceChip(
                key: Key('notifyStage_${s.name}'),
                label: Text(
                  '${context.t('clubNotify.tab.${s.name}')} (${groups.of(s).length})',
                ),
                selected: stage == s,
                onSelected: (_) => setState(() => _stage = s),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            hintText: context.t('clubNotify.search'),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (String v) => setState(() => _search = v),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(
            message: context.t('clubNotify.empty.${stage.name}'),
            icon: Icons.event_busy_outlined,
          )
        else
          for (final AppEvent e in list)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: Key('notifyEvent_${e.id}'),
                title: Text(
                  e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  <String>[
                    _when(
                      notifyEventStartMs(e),
                      time: e.eventStartAtMs != null,
                    ),
                    if (e.locationName.isNotEmpty) e.locationName,
                    if (e.cancelled) context.t('clubNotify.cancelled'),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '${Routes.clubEventNotifications}?eventId=${Uri.encodeComponent(e.id)}',
                ),
              ),
            ),
        const SizedBox(height: 4),
        Text(context.t('clubNotify.windowNote'), style: text.bodySmall),
        const SizedBox(height: 22),
        EventSectionTitle(context.t('clubNotify.all')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final String t in <String>['', 'manual', 'auto'])
              ChoiceChip(
                label: Text(
                  context.t('clubNotify.filter.${t.isEmpty ? 'all' : t}'),
                ),
                selected: _historyType == t,
                onSelected: (_) => setState(() => _historyType = t),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...messages.when(
          loading: () => <Widget>[const LinearProgressIndicator()],
          error: (Object _, StackTrace _) => <Widget>[
            Text(context.t('eventNotify.historyError'), style: text.bodySmall),
          ],
          data: (List<ClubMessageRecord> msgs) {
            final List<SendHistoryItem> items = mergeSendHistory(
              all,
              msgs,
              type: _historyType,
            ).take(80).toList();
            if (items.isEmpty) {
              return <Widget>[
                Text(context.t('clubNotify.allEmpty'), style: text.bodySmall),
              ];
            }
            return items.map((SendHistoryItem i) {
              final ClubMessageRecord? m = i.message;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    i.isAuto
                        ? Icons.schedule_send_outlined
                        : Icons.campaign_outlined,
                    color: i.isAuto ? BrandColors.info : BrandColors.success,
                  ),
                  title: Text(
                    i.isAuto
                        ? context.t('autoNotify.${i.reminderKey}')
                        : m!.title,
                  ),
                  subtitle: Text(
                    <String>[
                      if (!i.isAuto && m!.message.isNotEmpty) m.message,
                      <String>[
                        i.eventTitle,
                        _when(i.atMs),
                        if (!i.isAuto)
                          '${context.t('eventNotify.audience.${m!.audience}')} · ${m.recipients}',
                      ].join(' · '),
                    ].join('\n'),
                  ),
                  onTap: () => context.push(
                    '${Routes.clubEventNotifications}?eventId=${Uri.encodeComponent(i.eventId)}',
                  ),
                ),
              );
            }).toList();
          },
        ),
      ],
    );
  }
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final NotifyStage stage = notifyStage(
      event,
      DateTime.now().millisecondsSinceEpoch,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: <Widget>[
        Text(
          event.title,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          <String>[
            _when(
              notifyEventStartMs(event),
              time: event.eventStartAtMs != null,
            ),
            if (event.locationName.isNotEmpty) event.locationName,
            if (event.cancelled)
              context.t('clubNotify.cancelled')
            else if (stage != NotifyStage.old)
              context.t('clubNotify.tab.${stage.name}'),
          ].join(' · '),
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        EventNotifyCard(event: event, editableAuto: true),
      ],
    );
  }
}
