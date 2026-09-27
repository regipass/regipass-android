/// Kulüp etkinlik detayı > Bildirimler (İP-B) —
/// js/modules/club/event-messages.js karşılığı.
///
/// 1) Otomatik bildirimlerin durumu (gitti / bekliyor / kapalı).
/// 2) "Bildirim gönder": grup, başlık, mesaj; kaç kişiye gideceği önizlenir.
/// 3) Gönderilen mesajların geçmişi (events/{id}/club_messages).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/reminder_schedule.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/firebase_refs.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';

const List<String> kEventMessageAudiences = <String>[
  'registered',
  'checked_in',
  'not_checked_in',
  'waitlist',
];

class EventClubMessage {
  const EventClubMessage({
    required this.title,
    required this.message,
    required this.audience,
    required this.recipients,
    required this.sentAtMs,
  });

  final String title;
  final String message;
  final String audience;
  final int recipients;
  final int sentAtMs;
}

// ignore: always_specify_types
final eventClubMessagesProvider =
    StreamProvider.family<List<EventClubMessage>, String>((
      Ref ref,
      String eventId,
    ) {
      return eventDoc(eventId)
          .collection('club_messages')
          .orderBy('sentAtMs', descending: true)
          .limit(20)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snap) =>
                snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
                  final Map<String, dynamic> m = d.data();
                  return EventClubMessage(
                    title: '${m['title'] ?? ''}',
                    message: '${m['message'] ?? ''}',
                    audience: '${m['audience'] ?? ''}',
                    recipients: (m['recipients'] as num?)?.toInt() ?? 0,
                    sentAtMs: (m['sentAtMs'] as num?)?.toInt() ?? 0,
                  );
                }).toList(),
          );
    });

String _formatDateTime(int ms) {
  if (ms <= 0) return '';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

class EventNotifyCard extends ConsumerWidget {
  const EventNotifyCard({super.key, required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ReminderState> states = reminderStates(
      eventDateAtMs: event.eventDateAtMs,
      eventStartAtMs: event.eventStartAtMs,
      eventEndAtMs: event.eventEndAtMs,
      cancelled: event.cancelled,
      flags: event.autoNotifications,
      sent: event.notificationsSent,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final AsyncValue<List<EventClubMessage>> history = ref.watch(
      eventClubMessagesProvider(event.id),
    );
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.t('eventNotify.autoHelp'), style: text.bodySmall),
        const SizedBox(height: 8),
        for (final ReminderState s in states)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(context.t('autoNotify.${s.key}'))),
                Text(
                  <String>[
                    context.t('eventNotify.status.${s.status.name}'),
                    if (s.status == ReminderStatus.sent)
                      _formatDateTime(s.sentAtMs ?? 0)
                    else if (s.atMs != null)
                      _formatDateTime(s.atMs!),
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(
                    color: s.status == ReminderStatus.sent
                        ? BrandColors.success
                        : null,
                    fontWeight: s.status == ReminderStatus.sent
                        ? FontWeight.w700
                        : null,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (!event.cancelled)
          FilledButton.icon(
            key: const Key('eventNotifySend'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _SendMessageDialog(eventId: event.id),
            ),
            icon: const Icon(Icons.campaign_outlined),
            label: Text(context.t('eventNotify.send')),
          ),
        const SizedBox(height: 12),
        Text(context.t('eventNotify.historyTitle'), style: text.titleSmall),
        const SizedBox(height: 6),
        ...history.when(
          loading: () => <Widget>[const LinearProgressIndicator()],
          error: (Object _, StackTrace _) => <Widget>[
            Text(context.t('eventNotify.historyError'), style: text.bodySmall),
          ],
          data: (List<EventClubMessage> list) => list.isEmpty
              ? <Widget>[
                  Text(
                    context.t('eventNotify.historyEmpty'),
                    style: text.bodySmall,
                  ),
                ]
              : list
                    .map(
                      (EventClubMessage m) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(m.title),
                          subtitle: Text(
                            '${m.message}\n'
                            '${context.t('eventNotify.audience.${m.audience}')}'
                            ' · ${m.recipients} · ${_formatDateTime(m.sentAtMs)}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

class _SendMessageDialog extends ConsumerStatefulWidget {
  const _SendMessageDialog({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_SendMessageDialog> createState() => _SendMessageDialogState();
}

class _SendMessageDialogState extends ConsumerState<_SendMessageDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();
  String _audience = 'registered';
  int? _count;
  bool _sending = false;
  String? _error;
  int _previewSeq = 0;

  @override
  void initState() {
    super.initState();
    _preview();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final int seq = ++_previewSeq;
    setState(() => _count = null);
    try {
      final int n = await ref
          .read(registrationServiceProvider)
          .sendEventMessage(
            eventId: widget.eventId,
            audience: _audience,
            title: 'preview',
            message: 'preview',
            preview: true,
          );
      if (mounted && seq == _previewSeq) setState(() => _count = n);
    } on RegistrationFailure catch (_) {
      if (mounted && seq == _previewSeq) setState(() => _count = 0);
    }
  }

  Future<void> _send() async {
    final String title = _title.text.trim();
    final String message = _message.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(() => _error = context.t('eventNotify.errors.required'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final int n = await ref
          .read(registrationServiceProvider)
          .sendEventMessage(
            eventId: widget.eventId,
            audience: _audience,
            title: title,
            message: message,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('eventNotify.sent', <String, Object?>{'count': n}),
          ),
        ),
      );
    } on RegistrationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failure.isNetwork
            ? context.t('clubEvents.feedback.updateError')
            : context.t('eventNotify.errors.${failure.reason}');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('eventNotify.send')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _audience,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.t('eventNotify.audienceLabel'),
              ),
              items: kEventMessageAudiences
                  .map(
                    (String a) => DropdownMenuItem<String>(
                      value: a,
                      child: Text(context.t('eventNotify.audience.$a')),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (String? v) {
                      if (v == null) return;
                      setState(() => _audience = v);
                      _preview();
                    },
            ),
            const SizedBox(height: 6),
            Text(
              _count == null
                  ? context.t('eventNotify.counting')
                  : context.t('eventNotify.willReach', <String, Object?>{
                      'count': _count,
                    }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              key: const Key('eventNotifyTitle'),
              controller: _title,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: context.t('eventNotify.titleLabel'),
              ),
            ),
            TextField(
              key: const Key('eventNotifyMessage'),
              controller: _message,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.t('eventNotify.messageLabel'),
              ),
            ),
            if (_error != null)
              FeedbackBanner(message: _error, tone: FeedbackTone.error),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          key: const Key('eventNotifySubmit'),
          onPressed: _sending ? null : _send,
          child: Text(context.t('eventNotify.submit')),
        ),
      ],
    );
  }
}
