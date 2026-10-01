// İP-TK: kulüp takip — filtre, hata metinleri, düğme, profil listesi, sayı.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/club_follow.dart';
import 'package:regipass/features/club/club_dashboard_screen.dart';
import 'package:regipass/features/shared/club_follow_button.dart';
import 'package:regipass/features/student/followed_clubs_section.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/inbox_entry.dart';
import 'package:regipass/services/club_follow_service.dart';

class _FakeFollowService extends ClubFollowService {
  _FakeFollowService();

  final List<String> calls = <String>[];

  @override
  Future<void> setFollow(String clubId, {required bool follow}) async {
    calls.add('$clubId:$follow');
  }

  @override
  Future<List<FollowedClub>> listFollowedClubs() async =>
      const <FollowedClub>[];
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);

void main() {
  test('Takip ettiklerim filtresi yalnızca takip edilen kulüpleri bırakır', () {
    final List<String> events = <String>['clubA:e1', 'clubB:e2', ':e3'];
    String clubOf(String e) => e.split(':').first;
    expect(
      filterByFollow(events, FollowFilter.all, <String>{'clubA'}, clubOf),
      events,
    );
    expect(
      filterByFollow(events, FollowFilter.following, <String>{'clubA'}, clubOf),
      <String>['clubA:e1'],
    );
    expect(
      filterByFollow(events, FollowFilter.following, <String>{}, clubOf),
      isEmpty,
    );
  });

  test('yeni etkinlik bildirimi etkinliği açan rotaya gider', () {
    expect(
      safeInboxRoute('/student?openEventId=ev%201'),
      '/student?openEventId=ev%201',
    );
  });

  test('sunucu hata nedeni çeviri anahtarına döner', () {
    expect(followErrorKey('too-many-follows'), 'follow.error.tooMany');
    expect(followErrorKey('club-unavailable'), 'follow.error.clubUnavailable');
    expect(followErrorKey('bilinmeyen'), 'follow.error.generic');
  });

  test('listFollowedClubs kaydı okunur', () {
    final FollowedClub c = FollowedClub.fromMap(<Object?, Object?>{
      'clubId': 'clubA',
      'clubName': 'Farma',
      'available': true,
      'followedAtMs': 12,
    });
    expect(c.clubId, 'clubA');
    expect(c.available, isTrue);
    expect(c.followedAtMs, 12);
    expect(FollowedClub.fromMap(<Object?, Object?>{}).available, isFalse);
  });

  testWidgets('düğme durumu canlı listeden; dokununca sunucuya gider', (
    WidgetTester tester,
  ) async {
    final _FakeFollowService fake = _FakeFollowService();
    await tester.pumpWidget(
      _wrap(const ClubFollowButton(clubId: 'clubA'), <Override>[
        followedClubIdsProvider.overrideWith(
          (Ref ref) => Stream<Set<String>>.value(<String>{'clubB'}),
        ),
        clubFollowServiceProvider.overrideWithValue(fake),
        followedClubsProvider.overrideWith(
          (Ref ref) async => const <FollowedClub>[],
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('Takip et'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('club-follow-button')));
    await tester.pump();
    expect(fake.calls, <String>['clubA:true']);
    // İyimser durum: sunucu yanıtıyla "Takip ediliyor".
    expect(find.text('Takip ediliyor'), findsOneWidget);
  });

  testWidgets('takip edilen kulüpte "Takip ediliyor" yazar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ClubFollowButton(clubId: 'clubA'), <Override>[
        followedClubIdsProvider.overrideWith(
          (Ref ref) => Stream<Set<String>>.value(<String>{'clubA'}),
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('Takip ediliyor'), findsOneWidget);
  });

  testWidgets('profilde takip edilen kulüpler listelenir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SingleChildScrollView(child: FollowedClubsSection()),
        <Override>[
          followedClubsProvider.overrideWith(
            (Ref ref) async => const <FollowedClub>[
              FollowedClub(
                clubId: 'clubA',
                clubName: 'Farma Kulübü',
                university: 'Ege',
                city: 'İzmir',
                logoUrl: '',
                available: false,
                followedAtMs: 1,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Takip ettiğim kulüpler'), findsOneWidget);
    expect(find.text('Farma Kulübü'), findsOneWidget);
    expect(find.text('Ege · İzmir'), findsOneWidget);
    expect(find.text('Bu kulüp şu an etkinlik yayınlamıyor.'), findsOneWidget);
    expect(find.text('Takibi bırak'), findsOneWidget);
  });

  testWidgets('boş takip listesinde yol gösteren metin', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SingleChildScrollView(child: FollowedClubsSection()),
        <Override>[
          followedClubsProvider.overrideWith(
            (Ref ref) async => const <FollowedClub>[],
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.textContaining('Henüz organizatör takip etmiyorsun'), findsOneWidget);
  });

  testWidgets('kulüp panelinde yalnızca takipçi sayısı', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ClubFollowerCountChip(), <Override>[
        clubFollowerCountProvider.overrideWith(
          (Ref ref) => Stream<int>.value(42),
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('takipçi'), findsOneWidget);
  });
}
