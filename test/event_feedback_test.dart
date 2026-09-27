// İP-D: etkinlik sonrası değerlendirme — pencere (sunucuyla aynı), rozet,
// özet, form ve kulüp kartı.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_feedback.dart';
import 'package:regipass/features/club/event_feedback_summary_card.dart';
import 'package:regipass/features/student/event_feedback_card.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/inbox_entry.dart';
import 'package:regipass/services/event_feedback_service.dart';

const int _h = 3600000;
const int _day = 24 * _h;
final int _start = DateTime.utc(2026, 9, 30, 11).millisecondsSinceEpoch;
final int _end = _start + 2 * _h;

AppEvent _event([Map<String, dynamic> extra = const <String, dynamic>{}]) =>
    AppEvent.fromMap('e1', <String, dynamic>{
      'clubId': 'clubA',
      'title': 'Söyleşi',
      'eventDateAtMs': _start,
      'eventStartAtMs': _start,
      'eventEndAtMs': _end,
      ...extra,
    });

EventRegistration _reg([
  Map<String, dynamic> extra = const <String, dynamic>{},
]) => EventRegistration.fromMap('e1_stu1', <String, dynamic>{
  'eventId': 'e1',
  'studentId': 'stu1',
  ...extra,
});

class _FakeService extends EventFeedbackService {
  _FakeService();

  final List<String> calls = <String>[];

  @override
  Future<MyFeedback> submit(String eventId, int rating, String comment) async {
    calls.add('$eventId:$rating:$comment');
    return MyFeedback(
      eventId: eventId,
      rating: rating,
      comment: comment,
      updatedAtMs: 1,
    );
  }

  @override
  Future<Map<String, MyFeedback>> listMine() async => <String, MyFeedback>{};
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  test(
    'bitiş anı: bitiş → başlangıç + 3 saat → gün 20:00 TR (sunucuyla aynı)',
    () {
      expect(
        eventEndAnchorMs(startMs: _start, endMs: _end, dayMs: _start),
        _end,
      );
      expect(eventEndAnchorMs(startMs: _start, dayMs: _start), _start + 3 * _h);
      final int day = DateTime.utc(2026, 9, 30, 9).millisecondsSinceEpoch;
      expect(
        eventEndAnchorMs(dayMs: day),
        DateTime.utc(2026, 9, 30, 17).millisecondsSinceEpoch,
      );
      expect(eventEndAnchorMs(), 0);
      // Saniye cinsinden kayıtlı eski alanlar da ms'ye çevrilir.
      expect(
        eventEndAnchorMs(startMs: _start ~/ 1000, endMs: _end ~/ 1000),
        _end,
      );
    },
  );

  test('pencere: yalnızca giriş yapan, etkinlik bitince, 14 gün', () {
    final AppEvent e = _event();
    final EventRegistration inReg = _reg(<String, dynamic>{
      'checkedInAtMs': _start + 1000,
    });
    expect(feedbackWindowFor(e, inReg, _end + 1).ok, isTrue);
    expect(feedbackWindowFor(e, inReg, _end - 1).reason, 'event-not-finished');
    expect(feedbackWindowFor(e, _reg(), _end + 1).reason, 'not-checked-in');
    expect(
      feedbackWindowFor(
        e,
        _reg(<String, dynamic>{'sessionsAttended': 1}),
        _end + 1,
      ).ok,
      isTrue,
    );
    expect(
      feedbackWindowFor(
        _event(<String, dynamic>{'sessionsCompleted': true}),
        inReg,
        _start,
      ).ok,
      isTrue,
    );
    expect(
      feedbackWindowFor(
        _event(<String, dynamic>{'cancelled': true}),
        inReg,
        _end + 1,
      ).reason,
      'event-cancelled',
    );
    expect(feedbackWindowFor(e, null, _end + 1).reason, 'not-registered');
    expect(feedbackWindowFor(null, inReg, _end + 1).reason, 'event-not-found');
    final FeedbackWindow closed = feedbackWindowFor(
      e,
      inReg,
      _end + 14 * _day + 1,
    );
    expect(closed.reason, 'feedback-closed');
    expect(closed.closesAtMs, _end + 14 * _day);
  });

  test('rozet, yıldız metni, hata anahtarı, rota', () {
    const FeedbackWindow open = FeedbackWindow(
      ok: true,
      reason: '',
      opensAtMs: 1,
      closesAtMs: 2,
    );
    const FeedbackWindow shut = FeedbackWindow(
      ok: false,
      reason: 'x',
      opensAtMs: 1,
      closesAtMs: 2,
    );
    const MyFeedback mine = MyFeedback(
      eventId: 'e1',
      rating: 4,
      comment: '',
      updatedAtMs: 1,
    );
    expect(feedbackBadge(open, null), FeedbackBadge.rate);
    expect(feedbackBadge(shut, mine), FeedbackBadge.rated);
    expect(feedbackBadge(shut, null), FeedbackBadge.none);
    expect(starText(4), '★★★★☆');
    expect(starText(3.7), '★★★★☆');
    expect(feedbackErrorKey('feedback-closed'), 'feedback.error.closed');
    expect(feedbackErrorKey('?'), 'feedback.error.generic');
    expect(
      safeInboxRoute('/student/appointments?feedbackEventId=e1'),
      '/student/appointments?feedbackEventId=e1',
    );
  });

  test('kulüp özeti okunur; dağılım satırları 5 → 1', () {
    final FeedbackSummary s = FeedbackSummary.fromMap(<Object?, Object?>{
      'count': 4,
      'average': 3.8,
      'distribution': <int>[1, 0, 0, 1, 2],
      'comments': <Map<String, Object>>[
        <String, Object>{'rating': 5, 'comment': 'Harika'},
      ],
      'commentsHidden': false,
      'minForComments': 3,
    });
    expect(
      s.rows.map((r) => '${r.stars}:${r.count}:${r.percent}').toList(),
      <String>['5:2:50', '4:1:25', '3:0:0', '2:0:0', '1:1:25'],
    );
    expect(s.comments.single.comment, 'Harika');
    expect(FeedbackSummary.fromMap(<Object?, Object?>{}).count, 0);
  });

  testWidgets('form: yıldız seç, yorum yaz, gönder', (
    WidgetTester tester,
  ) async {
    final _FakeService fake = _FakeService();
    await tester.pumpWidget(
      _wrap(
        const EventFeedbackCard(
          eventId: 'e1',
          window: FeedbackWindow(
            ok: true,
            reason: '',
            opensAtMs: 1,
            closesAtMs: 2,
          ),
        ),
        <Override>[eventFeedbackServiceProvider.overrideWithValue(fake)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Etkinliği değerlendir'), findsOneWidget);
    final FilledButton before = tester.widget(
      find.byKey(const ValueKey<String>('feedback-submit')),
    );
    expect(before.onPressed, isNull, reason: 'yıldız seçilmeden gönderilemez');

    await tester.tap(find.byKey(const ValueKey<String>('feedback-star-4')));
    await tester.pump();
    expect(find.text('Beğendim'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('feedback-comment')),
      'Güzeldi',
    );
    await tester.tap(find.byKey(const ValueKey<String>('feedback-submit')));
    await tester.pumpAndSettle();
    expect(fake.calls, <String>['e1:4:Güzeldi']);
  });

  testWidgets('pencere kapalı ve puan yoksa kart görünmez', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EventFeedbackCard(
          eventId: 'e1',
          window: FeedbackWindow(
            ok: false,
            reason: 'not-checked-in',
            opensAtMs: 1,
            closesAtMs: 2,
          ),
        ),
        <Override>[
          eventFeedbackServiceProvider.overrideWithValue(_FakeService()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('event-feedback-card')),
      findsNothing,
    );
  });

  testWidgets('kulüp kartı: ortalama, dağılım, yorumlar', (
    WidgetTester tester,
  ) async {
    final AppEvent past = _event(<String, dynamic>{
      'eventDateAtMs': _start - 5 * _day,
      'eventStartAtMs': _start - 5 * _day,
      'eventEndAtMs': _start - 5 * _day + 2 * _h,
    });
    await tester.pumpWidget(
      _wrap(EventFeedbackSummaryCard(event: past), <Override>[
        clubEventFeedbackProvider('e1').overrideWith(
          (Ref ref) async => FeedbackSummary.fromMap(<Object?, Object?>{
            'count': 3,
            'average': 4.3,
            'distribution': <int>[0, 0, 0, 2, 1],
            'comments': <Map<String, Object>>[
              <String, Object>{'rating': 5, 'comment': 'Çok iyiydi'},
            ],
          }),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Değerlendirmeler'), findsOneWidget);
    expect(find.text('4,3'), findsOneWidget);
    expect(find.text('3 değerlendirme'), findsOneWidget);
    expect(find.text('Çok iyiydi'), findsOneWidget);
  });

  testWidgets('kulüp kartı etkinlik bitmeden görünmez', (
    WidgetTester tester,
  ) async {
    final AppEvent future = _event(<String, dynamic>{
      'eventDateAtMs': DateTime.now().millisecondsSinceEpoch + 3 * _day,
      'eventStartAtMs': DateTime.now().millisecondsSinceEpoch + 3 * _day,
      'eventEndAtMs': DateTime.now().millisecondsSinceEpoch + 3 * _day + _h,
    });
    await tester.pumpWidget(
      _wrap(EventFeedbackSummaryCard(event: future), <Override>[]),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('event-feedback-summary')),
      findsNothing,
    );
  });
}
