import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_extras.dart';

void main() {
  test('fiş durumları (web ile aynı)', () {
    final List<VoucherState> v = participantVouchers(
      <String, dynamic>{'types': <Object>[
        <String, dynamic>{'id': 'v1', 'name': 'Yemek', 'icon': 'meal', 'perPerson': 1},
        <String, dynamic>{'id': 'v2', 'name': 'Kahve', 'icon': 'coffee', 'perPerson': 2, 'eligibility': 'registered'},
        <String, dynamic>{'id': 'v3', 'name': 'Çanta', 'icon': 'x', 'perPerson': 1},
      ]},
      <String, dynamic>{'used': <String, dynamic>{'v1': <Object>[<String, dynamic>{}], 'v2': <Object>[<String, dynamic>{}]}},
    );
    expect(v.map((VoucherState x) => x.state), <String>['used', 'partial', 'available']);
    expect(v[1].remaining, 1);
    expect(v[1].needsDoor, isFalse);
    expect(voucherIcon('x'), '🎟️');
    expect(participantVouchers(null, null), isEmpty);
  });

  test('pasaport ilerlemesi', () {
    final PassportState? p = passportProgress(
      <String, dynamic>{'stops': <Object>[<String, dynamic>{'id': 's1', 'name': 'A'}, <String, dynamic>{'id': 's2', 'name': 'B'}, <String, dynamic>{'id': 's3', 'name': 'C'}], 'goal': 2, 'rewardName': 'Çanta'},
      <String, dynamic>{'stamps': <String, dynamic>{'s1': <String, dynamic>{}, 's3': <String, dynamic>{}}},
    );
    expect(p!.count, 2);
    expect(p.complete, isTrue);
    expect(p.rewardGiven, isFalse);
    expect(passportProgress(<String, dynamic>{}, null), isNull);
  });

  test('programım', () {
    final ({List<ProgramSlot> slots, int count, int? minSessions})? r = myProgram(
      <String, dynamic>{
        'halls': <Object>[<String, dynamic>{'id': 'h1', 'name': 'Büyük'}, <String, dynamic>{'id': 'h2', 'name': 'B'}],
        'slots': <Object>[
          <String, dynamic>{'id': 's2', 'hallId': 'h2', 'title': 'Panel', 'startMs': 200, 'endMs': 300},
          <String, dynamic>{'id': 's1', 'hallId': 'h1', 'title': 'Açılış', 'startMs': 100, 'endMs': 300},
        ],
        'minSessions': 2,
      },
      <String, dynamic>{'attended': <String, dynamic>{'s2': <String, dynamic>{}}},
    );
    expect(r!.slots.map((ProgramSlot s) => s.id), <String>['s1', 's2']);
    expect(r.slots[1].attended, isTrue);
    expect(r.slots[1].hallName, 'B');
    expect(r.count, 1);
    expect(r.minSessions, 2);
    expect(r.slots[0].liveAt(150), isTrue);
  });
}
