/// Kulüp > etkinlik detayı: "Değerlendirmeler" (İP-D, kimliksiz özet).
/// Web: js/modules/feedback/feedback-ui.js#renderFeedbackSummary.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/event_feedback.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/event_feedback_service.dart';

class EventFeedbackSummaryCard extends ConsumerWidget {
  const EventFeedbackSummaryCard({required this.event, super.key});

  final AppEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.cancelled ||
        !eventFeedbackEnded(event, DateTime.now().millisecondsSinceEpoch)) {
      return const SizedBox.shrink();
    }
    final AsyncValue<FeedbackSummary> summary = ref.watch(
      clubEventFeedbackProvider(event.id),
    );
    return Container(
      key: const ValueKey<String>('event-feedback-summary'),
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
            context.t('feedback.club.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...summary.when(
            loading: () => <Widget>[_Hint(context.t('common.loading'))],
            error: (Object e, StackTrace _) => <Widget>[
              _Hint(context.t('feedback.club.loadError')),
            ],
            data: (FeedbackSummary s) => _body(context, s),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, FeedbackSummary s) {
    if (s.count == 0) return <Widget>[_Hint(context.t('feedback.club.empty'))];
    final String avg = s.average
        .toStringAsFixed(1)
        .replaceAll('.', context.t('feedback.decimal'));
    return <Widget>[
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: <Widget>[
          Text(
            avg,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            starText(s.average),
            style: const TextStyle(fontSize: 18, color: Color(0xFFF59E0B)),
          ),
          Text(
            context.t('feedback.club.count', <String, Object?>{'n': s.count}),
            style: TextStyle(color: context.inkMuted),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final ({int stars, int count, int percent}) row in s.rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: <Widget>[
              SizedBox(width: 34, child: Text('${row.stars} ★')),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: row.percent / 100,
                    minHeight: 8,
                    backgroundColor: context.subtleFill,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text('${row.count}', textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
      if (s.comments.isNotEmpty) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          context.t('feedback.club.comments'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final ({int rating, String comment}) c in s.comments)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.subtleFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  starText(c.rating),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                Text(c.comment),
              ],
            ),
          ),
      ],
      if (s.commentsHidden)
        _Hint(
          context.t('feedback.club.commentsHidden', <String, Object?>{
            'n': s.minForComments,
          }),
        ),
      const SizedBox(height: 4),
      _Hint(context.t('feedback.club.anonymous')),
    ];
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
