/// İP-FS / İP-PS / İP-SL (mobil 1.0.13): katılımcının fiş, pasaport ve
/// program durumları — saf. Web: voucher-rules.js, passport-rules.js,
/// hall-rules.js (aynı hesap).
library;

const Map<String, String> kVoucherIcons = <String, String>{
  'meal': '🍽️', 'coffee': '☕', 'photo': '📸', 'gift': '🎁', 'drink': '🥤', 'other': '🎟️',
};

String voucherIcon(String icon) => kVoucherIcons[icon] ?? kVoucherIcons['other']!;

List<Map<String, dynamic>> _maps(Object? raw) => raw is List
    ? <Map<String, dynamic>>[for (final Object? x in raw) if (x is Map) Map<String, dynamic>.from(x)]
    : const <Map<String, dynamic>>[];

Map<String, dynamic> _map(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};

class VoucherState {
  const VoucherState({required this.id, required this.name, required this.icon, required this.perPerson, required this.used, required this.needsDoor});
  final String id;
  final String name;
  final String icon;
  final int perPerson;
  final int used;
  final bool needsDoor;
  int get remaining => (perPerson - used).clamp(0, perPerson);

  /// 'used' | 'partial' | 'available'
  String get state => remaining == 0 ? 'used' : (used > 0 ? 'partial' : 'available');
}

List<VoucherState> participantVouchers(Map<String, dynamic>? config, Map<String, dynamic>? redemption) {
  final Map<String, dynamic> used = _map(redemption?['used']);
  return <VoucherState>[
    for (final Map<String, dynamic> t in _maps(config?['types']))
      VoucherState(
        id: '${t['id']}',
        name: '${t['name'] ?? ''}',
        icon: '${t['icon'] ?? 'other'}',
        perPerson: (t['perPerson'] as num?)?.toInt() ?? 1,
        used: used['${t['id']}'] is List ? (used['${t['id']}'] as List).length : 0,
        needsDoor: t['eligibility'] != 'registered',
      ),
  ];
}

class PassportState {
  const PassportState({required this.stops, required this.count, required this.goal, required this.rewardName, required this.rewardGiven});
  final List<({String id, String name, bool stamped})> stops;
  final int count;
  final int goal;
  final String rewardName;
  final bool rewardGiven;
  bool get complete => goal > 0 && count >= goal;
  double get progress => goal == 0 ? 0 : (count / goal).clamp(0, 1).toDouble();
}

PassportState? passportProgress(Map<String, dynamic>? passport, Map<String, dynamic>? stampsDoc) {
  final List<Map<String, dynamic>> stops = _maps(passport?['stops']);
  if (stops.isEmpty) return null;
  final Map<String, dynamic> stamps = _map(stampsDoc?['stamps']);
  final List<({String id, String name, bool stamped})> list = <({String id, String name, bool stamped})>[
    for (final Map<String, dynamic> s in stops) (id: '${s['id']}', name: '${s['name'] ?? ''}', stamped: stamps.containsKey('${s['id']}')),
  ];
  final int count = list.where((({String id, String name, bool stamped}) s) => s.stamped).length;
  final int rawGoal = (passport?['goal'] as num?)?.toInt() ?? stops.length;
  return PassportState(
    stops: list,
    count: count,
    goal: rawGoal.clamp(1, stops.length),
    rewardName: '${passport?['rewardName'] ?? ''}',
    rewardGiven: stampsDoc?['reward'] != null,
  );
}

class ProgramSlot {
  const ProgramSlot({required this.id, required this.title, required this.speaker, required this.hallName, required this.startMs, required this.endMs, required this.attended});
  final String id;
  final String title;
  final String speaker;
  final String hallName;
  final int startMs;
  final int endMs;
  final bool attended;
  bool liveAt(int nowMs) => nowMs >= startMs && nowMs <= endMs;
}

({List<ProgramSlot> slots, int count, int? minSessions})? myProgram(Map<String, dynamic>? config, Map<String, dynamic>? record) {
  final List<Map<String, dynamic>> halls = _maps(config?['halls']);
  if (halls.isEmpty) return null;
  final Map<String, dynamic> attended = _map(record?['attended']);
  final Map<String, String> hallNames = <String, String>{for (final Map<String, dynamic> h in halls) '${h['id']}': '${h['name'] ?? ''}'};
  final List<ProgramSlot> slots = <ProgramSlot>[
    for (final Map<String, dynamic> s in _maps(config?['slots']))
      ProgramSlot(
        id: '${s['id']}',
        title: '${s['title'] ?? ''}',
        speaker: '${s['speaker'] ?? ''}',
        hallName: hallNames['${s['hallId']}'] ?? '',
        startMs: (s['startMs'] as num?)?.toInt() ?? 0,
        endMs: (s['endMs'] as num?)?.toInt() ?? 0,
        attended: attended.containsKey('${s['id']}'),
      ),
  ]..sort((ProgramSlot a, ProgramSlot b) => a.startMs.compareTo(b.startMs));
  return (slots: slots, count: attended.length, minSessions: (config?['minSessions'] as num?)?.toInt());
}
