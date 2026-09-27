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
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/message_templates.dart';
import '../../domain/reminder_schedule.dart';
import '../../domain/routing.dart';
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
  'payment_pending',
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
  const EventNotifyCard({
    super.key,
    required this.event,
    this.editableAuto = false,
    this.compact = false,
  });

  final AppEvent event;

  /// İP-KN: gönderilmemiş otomatik bildirimler için aç/kapa anahtarı.
  final bool editableAuto;

  /// İP-KN: etkinlik detayında yalnızca durum + Bildirimler ekranına kısayol.
  final bool compact;

  bool _canToggle(ReminderState s) {
    final bool enabled = event.autoNotifications[s.key] != false;
    return !event.cancelled &&
        s.status != ReminderStatus.sent &&
        s.status != ReminderStatus.missed &&
        !(enabled && s.atMs == null);
  }

  String _statusText(BuildContext context, ReminderState s) {
    final bool enabled = event.autoNotifications[s.key] != false;
    if (s.status == ReminderStatus.off && enabled) {
      return context.t('eventNotify.status.noTime');
    }
    if (s.status == ReminderStatus.pending) {
      return context.t('eventNotify.status.planned');
    }
    return context.t('eventNotify.status.${s.status.name}');
  }

  Future<void> _toggle(BuildContext context, String key, bool value) async {
    try {
      await eventDoc(event.id).update(<String, Object>{'autoNotifications.$key': value});
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('eventNotify.toggleError'))),
        );
      }
    }
  }

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
        if (!compact) ...<Widget>[
          Text(
            context.t(editableAuto ? 'eventNotify.autoHelpEditable' : 'eventNotify.autoHelp'),
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        for (final ReminderState s in states)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(context.t('autoNotify.${s.key}'))),
                Text(
                  <String>[
                    _statusText(context, s),
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
                if (editableAuto) ...<Widget>[
                  const SizedBox(width: 6),
                  Switch(
                    key: Key('autoToggle_${s.key}'),
                    value: event.autoNotifications[s.key] != false,
                    onChanged: _canToggle(s)
                        ? (bool v) => _toggle(context, s.key, v)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (compact) ...<Widget>[
          FilledButton.icon(
            key: const Key('eventNotifyOpenPage'),
            onPressed: () => context.push(
              '${Routes.clubEventNotifications}?eventId=${Uri.encodeComponent(event.id)}',
            ),
            icon: const Icon(Icons.campaign_outlined),
            label: Text(context.t('eventNotify.openPage')),
          ),
        ] else ...<Widget>[
        if (!event.cancelled)
          FilledButton.icon(
            key: const Key('eventNotifySend'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _SendMessageDialog(event: event),
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
      ],
    );
  }
}

class _SendMessageDialog extends ConsumerStatefulWidget {
  const _SendMessageDialog({required this.event});

  final AppEvent event;

  @override
  ConsumerState<_SendMessageDialog> createState() => _SendMessageDialogState();
}

class _SendMessageDialogState extends ConsumerState<_SendMessageDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _messageFocus = FocusNode();
  TextEditingController? _lastField;
  String _audience = 'registered';
  String _templateId = '';
  EventMessageResult? _preview;
  bool _counting = true;
  bool _sending = false;
  String? _error;
  int _previewSeq = 0;
  late final Map<String, String> _context = eventTagContext(
    title: widget.event.title,
    clubName: widget.event.clubName,
    eventDateAtMs: widget.event.eventDateAtMs,
    eventStartAtMs: widget.event.eventStartAtMs,
    eventEndAtMs: widget.event.eventEndAtMs,
    locationName: widget.event.locationName,
  );

  @override
  void initState() {
    super.initState();
    _lastField = _message;
    _titleFocus.addListener(() {
      if (_titleFocus.hasFocus) _lastField = _title;
    });
    _messageFocus.addListener(() {
      if (_messageFocus.hasFocus) _lastField = _message;
    });
    _title.addListener(_onText);
    _message.addListener(_onText);
    _refreshPreview();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _titleFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  Future<void> _refreshPreview() async {
    final int seq = ++_previewSeq;
    setState(() => _counting = true);
    try {
      final EventMessageResult r = await ref
          .read(registrationServiceProvider)
          .previewEventMessage(eventId: widget.event.id, audience: _audience);
      if (mounted && seq == _previewSeq) {
        setState(() {
          _preview = r;
          _counting = false;
        });
      }
    } on RegistrationFailure catch (_) {
      if (mounted && seq == _previewSeq) setState(() => _counting = false);
    }
  }

  void _applyTemplate(String? id) {
    final MessageTemplate? t = kMessageTemplates
        .where((MessageTemplate x) => x.id == id)
        .firstOrNull;
    setState(() => _templateId = id ?? '');
    if (t == null) return;
    _title.text = t.title;
    _message.text = t.message;
    if (_audience != t.audience) {
      setState(() => _audience = t.audience);
      _refreshPreview();
    }
    final int at = t.message.indexOf(kFillMark);
    if (at >= 0) {
      _messageFocus.requestFocus();
      _message.selection = TextSelection(baseOffset: at, extentOffset: at + 1);
    }
  }

  void _insertTag(String tag) {
    final TextEditingController c = _lastField ?? _message;
    final TextSelection sel = c.selection;
    final int start = sel.isValid ? sel.start : c.text.length;
    final int end = sel.isValid ? sel.end : c.text.length;
    c.text = c.text.replaceRange(start, end, tag);
    c.selection = TextSelection.collapsed(offset: start + tag.length);
  }

  Future<void> _send() async {
    final String title = _title.text.trim();
    final String message = _message.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(() => _error = context.t('eventNotify.errors.required'));
      return;
    }
    if (unknownMessageTags(title + message).isNotEmpty) {
      setState(() => _error = context.t('eventNotify.errors.unknown-tag'));
      return;
    }
    if (hasFillMark(title + message)) {
      setState(() => _error = context.t('eventNotify.errors.fill'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final EventMessageResult r = await ref
          .read(registrationServiceProvider)
          .sendEventMessage(
            eventId: widget.event.id,
            audience: _audience,
            title: title,
            message: message,
            templateId: _templateId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('eventNotify.sent', <String, Object?>{
              'count': r.recipients,
            }),
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

  String _quotaText(BuildContext context) {
    final EventMessageResult? p = _preview;
    if (p == null) return '';
    final List<String> parts = <String>[
      context.t('eventNotify.quota', <String, Object?>{
        'left': p.remainingToday,
        'limit': p.dailyLimit,
      }),
    ];
    final int? next = p.nextAllowedAtMs;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (next != null && next > now) {
      parts.add(
        context.t('eventNotify.nextIn', <String, Object?>{
          'minutes': ((next - now) / 60000).ceil(),
        }),
      );
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Map<String, String> sample = <String, String>{
      ..._context,
      'ad': 'Ayşe',
    };
    final String previewTitle = renderMessageTags(_title.text, sample);
    final String previewBody = renderMessageTags(_message.text, sample);
    return AlertDialog(
      title: Text(context.t('eventNotify.send')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<String>(
              key: const Key('eventNotifyTemplate'),
              initialValue: _templateId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.t('eventNotify.templateLabel'),
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(context.t('eventNotify.templateNone')),
                ),
                for (final MessageTemplate t in kMessageTemplates)
                  DropdownMenuItem<String>(value: t.id, child: Text(t.label)),
              ],
              onChanged: _sending ? null : _applyTemplate,
            ),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('aud_$_audience'),
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
                      _refreshPreview();
                    },
            ),
            const SizedBox(height: 6),
            Text(
              _counting
                  ? context.t('eventNotify.counting')
                  : context.t('eventNotify.willReach', <String, Object?>{
                      'count': _preview?.recipients ?? 0,
                    }),
              style: text.bodySmall,
            ),
            if (_quotaText(context).isNotEmpty)
              Text(
                _quotaText(context),
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            TextField(
              key: const Key('eventNotifyTitle'),
              controller: _title,
              focusNode: _titleFocus,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: context.t('eventNotify.titleLabel'),
              ),
            ),
            TextField(
              key: const Key('eventNotifyMessage'),
              controller: _message,
              focusNode: _messageFocus,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.t('eventNotify.messageLabel'),
              ),
            ),
            Text(context.t('eventNotify.tagsLabel'), style: text.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final MessageTag t in kMessageTags)
                  ActionChip(
                    key: Key('tag_${t.key}'),
                    label: Text(t.tag),
                    tooltip: context.t(t.labelKey),
                    visualDensity: VisualDensity.compact,
                    onPressed: _sending ? null : () => _insertTag(t.tag),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.t('eventNotify.previewLabel'),
                    style: text.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    previewTitle.isEmpty ? '—' : previewTitle,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    previewBody.isEmpty ? '—' : previewBody,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              FeedbackBanner(message: _error, tone: FeedbackTone.error),
            ],
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
