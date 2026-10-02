import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/session_names.dart';

void main() {
  test('adlar oturum sayısına göre kesilir, hepsi boşsa boş liste', () {
    expect(
      normalizeSessionNames(<Object?>['  Giriş ', '', 'Fazla'], 2),
      <String>['Giriş', ''],
    );
    expect(normalizeSessionNames(<Object?>['A'], 3), <String>['A', '', '']);
    expect(normalizeSessionNames(<Object?>['', ' '], 2), isEmpty);
    expect(
      normalizeSessionNames(<Object?>['x' * 99], 1).first.length,
      kSessionNameMax,
    );
  });

  test('etiket: ad varsa "Oturum 2: ad", yoksa yalnız numara', () {
    const List<String> names = <String>['Açılış', 'Makine Öğrenmesi'];
    expect(withSessionName('Oturum 2', names, 2), 'Oturum 2: Makine Öğrenmesi');
    expect(withSessionName('Oturum 3', names, 3), 'Oturum 3');
    expect(sessionNameAt(const <String>[], 1), '');
  });

  test('oturum saatleri: geçersiz/başlangıçsız atılır, etiket "baş – bit"', () {
    final List<SessionTime> out = normalizeSessionTimes(<SessionTime>[
      const SessionTime(start: '14:45', end: '15:30'),
      const SessionTime(end: '16:00'),
      const SessionTime(start: '25:00'),
    ], 3);
    expect(out.map((SessionTime t) => t.label), <String>[
      '14:45 – 15:30',
      '',
      '',
    ]);
    expect(
      normalizeSessionTimes(const <SessionTime>[SessionTime()], 2),
      isEmpty,
    );
    expect(sessionTimeAt(out, 1), '14:45 – 15:30');
    expect(sessionTimeAt(out, 9), '');
    expect(
      SessionTime.fromMap(<String, Object?>{'start': '09:00'}).label,
      '09:00',
    );
  });
}
