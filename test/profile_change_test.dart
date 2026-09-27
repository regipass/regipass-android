// İP-KP: onaya giden alanlar web (profile-change-diff.js) ile aynı.
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/profile_change.dart';

void main() {
  const Map<String, String> current = <String, String>{
    'clubName': 'Farma',
    'university': 'Ege',
    'city': 'İzmir',
    'clubPurpose': 'A',
    'clubContents': 'B',
  };

  test('değişmeyen alan onaya gitmez', () {
    expect(
      gatedClubChanges(
        current: current,
        currentFields: <String>['Sağlık'],
        next: <String, String>{...current, 'clubName': 'Farma '},
        nextFields: <String>['Sağlık'],
      ),
      isEmpty,
    );
  });

  test('ad ve alanlar değişince onaya gider', () {
    expect(
      gatedClubChanges(
        current: current,
        currentFields: <String>['Sağlık'],
        next: <String, String>{...current, 'clubName': 'Ege Farma'},
        nextFields: <String>['Sağlık', 'Bilim'],
      ),
      <String, Object>{
        'clubName': 'Ege Farma',
        'clubFields': <String>['Sağlık', 'Bilim'],
      },
    );
  });

  test('istek satırları; logo yolu atlanır', () {
    final ClubProfileChange change = ClubProfileChange.fromMap(
      <String, dynamic>{
        'status': 'pending',
        'after': <String, dynamic>{
          'clubName': 'Yeni',
          'clubFields': <String>['A', 'B'],
          'logoUrl': 'u',
          'logoPath': 'p',
        },
        'before': <String, dynamic>{
          'clubName': 'Eski',
          'clubFields': <String>['A'],
        },
      },
    );
    expect(change.isPending, isTrue);
    expect(
      change.rows().map(
        (({String key, String before, String after}) r) =>
            '${r.key}:${r.before}>${r.after}',
      ),
      <String>['clubName:Eski>Yeni', 'clubFields:A>A, B', 'logoUrl:>u'],
    );
    final ClubProfileChange rejected = ClubProfileChange.fromMap(
      <String, dynamic>{'status': 'rejected', 'reviewedAtMs': 1000},
    );
    expect(rejected.recentlyRejected(2000), isTrue);
    expect(rejected.recentlyRejected(20 * 24 * 3600 * 1000), isFalse);
  });
}
