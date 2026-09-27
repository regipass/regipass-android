/// Etkinliklerim > detay: etkinlik sonrası değerlendirme (İP-D).
/// Web: js/modules/feedback/feedback-ui.js#mountFeedbackForm.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/event_feedback.dart';
import '../../l10n/app_strings.dart';
import '../../services/event_feedback_service.dart';

class EventFeedbackCard extends ConsumerStatefulWidget {
  const EventFeedbackCard({
    required this.eventId,
    required this.window,
    this.startEditing = false,
    super.key,
  });

  final String eventId;
  final FeedbackWindow window;

  /// Bildirimden gelindiyse form doğrudan açık gelir.
  final bool startEditing;

  @override
  ConsumerState<EventFeedbackCard> createState() => _EventFeedbackCardState();
}

class _EventFeedbackCardState extends ConsumerState<EventFeedbackCard> {
  final TextEditingController _comment = TextEditingController();
  int _rating = 0;
  bool? _editing;
  bool _sending = false;
  bool _seeded = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _sending) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String thanks = context.t('feedback.thanks');
    setState(() => _sending = true);
    try {
      await ref
          .read(eventFeedbackServiceProvider)
          .submit(widget.eventId, _rating, _comment.text);
      ref.invalidate(myFeedbackProvider);
      if (!mounted) return;
      setState(() => _editing = false);
      messenger.showSnackBar(SnackBar(content: Text(thanks)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.t(feedbackErrorKey(feedbackErrorReason(error))),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _date(BuildContext context, int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    const List<String> tr = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const List<String> en = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return context.lang == 'en'
        ? '${d.day} ${en[d.month - 1]}'
        : '${d.day} ${tr[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final MyFeedback? mine = ref
        .watch(myFeedbackProvider)
        .value?[widget.eventId];
    final bool rated = (mine?.rating ?? 0) > 0;
    if (!widget.window.ok && !rated) return const SizedBox.shrink();

    if (!_seeded && (mine != null || ref.watch(myFeedbackProvider).hasValue)) {
      _seeded = true;
      _rating = mine?.rating ?? 0;
      _comment.text = mine?.comment ?? '';
    }
    final bool editing = _editing ?? (!rated || widget.startEditing);

    return Container(
      key: const ValueKey<String>('event-feedback-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t(editing ? 'feedback.title' : 'feedback.titleRated'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (!editing) ...<Widget>[
            Text(
              starText(mine?.rating ?? 0),
              style: const TextStyle(
                fontSize: 24,
                color: Color(0xFFF59E0B),
                letterSpacing: 2,
              ),
            ),
            if ((mine?.comment ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(mine!.comment),
              ),
            const SizedBox(height: 6),
            _Hint(context.t('feedback.anonymousNote')),
            if (widget.window.ok) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => _editing = true),
                child: Text(context.t('feedback.edit')),
              ),
              const SizedBox(height: 4),
              _Hint(
                context.t('feedback.editUntil', <String, Object?>{
                  'date': _date(context, widget.window.closesAtMs),
                }),
              ),
            ],
          ] else ...<Widget>[
            _Hint(context.t('feedback.help')),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                for (int n = 1; n <= 5; n++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _StarButton(
                      value: n,
                      on: n <= _rating,
                      label: context.t('feedback.starsAria', <String, Object?>{
                        'n': n,
                      }),
                      onTap: _sending
                          ? null
                          : () => setState(() => _rating = n),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 20,
              child: _rating == 0
                  ? null
                  : Text(
                      context.t('feedback.ratingLabel.$_rating'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('feedback-comment'),
              controller: _comment,
              enabled: !_sending,
              maxLength: maxFeedbackComment,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.t('feedback.commentLabel'),
                hintText: context.t('feedback.commentPlaceholder'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('feedback-submit'),
                onPressed: _rating == 0 || _sending ? null : _submit,
                child: Text(
                  context.t(
                    _sending
                        ? 'feedback.sending'
                        : (rated ? 'feedback.update' : 'feedback.submit'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _Hint(context.t('feedback.anonymousNote')),
          ],
        ],
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.value,
    required this.on,
    required this.label,
    required this.onTap,
  });

  final int value;
  final bool on;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: InkWell(
        key: ValueKey<String>('feedback-star-$value'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFFFBEB) : context.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? const Color(0xFFFCD34D) : context.hairline,
              width: 1.5,
            ),
          ),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_outline_rounded,
            color: on ? const Color(0xFFF59E0B) : context.inkMuted,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12.5, color: context.inkMuted, height: 1.45),
  );
}
