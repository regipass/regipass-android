import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_utils.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/profiles.dart';

AppEvent _event(String id, String clubId, String university) =>
    AppEvent.fromMap(id, <String, dynamic>{
      'clubId': clubId,
      'clubUniversity': university,
      'targetScope': 'public',
      'title': id,
      'deadlineAtMs': DateTime.now()
          .add(const Duration(days: 5))
          .millisecondsSinceEpoch,
    });

void main() {
  final StudentProfile student = StudentProfile.fromMap('s1', <String, dynamic>{
    'university': 'Boğaziçi Üniversitesi',
    'department': 'Tarih',
  });

  test('takip edilen kulüp +60 alır', () {
    final AppEvent e = _event('a', 'k1', 'İTÜ');
    final int base = getStudentEventScore(e, student);
    final int followed = getStudentEventScore(
      e,
      student,
      followedClubIds: <String>{'k1'},
    );
    expect(followed - base, DiscoveryWeights.followedClub);
    expect(DiscoveryWeights.followedClub, 60);
  });

  test('sıralama: kendi üniversitesi > takip edilen > diğerleri', () {
    final AppEvent own = _event('own', 'k2', 'Boğaziçi Üniversitesi');
    final AppEvent followed = _event('fol', 'k1', 'İTÜ');
    final AppEvent other = _event('oth', 'k3', 'ODTÜ');
    final List<AppEvent> sorted = sortEventsForStudent(
      <AppEvent>[other, followed, own],
      student,
      followedClubIds: <String>{'k1'},
    );
    expect(sorted.map((AppEvent e) => e.id).toList(), <String>[
      'own',
      'fol',
      'oth',
    ]);
  });
}
