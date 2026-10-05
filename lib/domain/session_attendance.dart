/// İP-B5: hangi oturuma katıldı — sunucu eventReport.js#attendedSessions ve
/// web session-attendance.js ile aynı kural.
///  - QR yoklaması `attendanceVerified.sN` (kesin), elle işaret
///    `manualAttendance.sN` (raporda "!").
///  - Eski yolda yalnız sayı + son oturum: eşitse 1..son kesin, değilse belirsiz.
library;

import '../models/event.dart';

List<int> _sessionKeys(Map<String, int> map, int sessionCount) {
  final List<int> out = <int>[];
  for (final String k in map.keys) {
    final RegExpMatch? m = RegExp(r'^s(\d{1,3})$').firstMatch(k);
    if (m == null) continue;
    final int n = int.parse(m.group(1)!);
    if (n >= 1 && n <= sessionCount) out.add(n);
  }
  return out;
}

({List<int> sessions, List<int> manual, bool exact}) resolveAttendedSessions(
  EventRegistration reg,
  int sessionCount,
) {
  final List<int> manual = _sessionKeys(reg.manualAttendance, sessionCount);
  final List<int> known = <int>{
    ..._sessionKeys(reg.attendanceVerified, sessionCount),
    ...manual,
  }.toList()..sort();
  final int count = reg.sessionsAttended > 0 ? reg.sessionsAttended : 0;
  final int last = reg.lastAttendedSession > 0 ? reg.lastAttendedSession : 0;
  if (known.length >= count) {
    return (sessions: known, manual: manual, exact: true);
  }
  if (count > 0 && count == last) {
    final int upto = last < sessionCount ? last : sessionCount;
    return (
      sessions: <int>[for (int i = 1; i <= upto; i++) i],
      manual: manual,
      exact: true,
    );
  }
  final Set<int> set = <int>{...known};
  if (last >= 1 && last <= sessionCount) set.add(last);
  return (sessions: set.toList()..sort(), manual: manual, exact: false);
}

/// Elle işaretlenebilecek son oturum (başlamış olanlar).
int lastReachedSession(AppEvent event) {
  final int count = event.sessionCount < 1 ? 1 : event.sessionCount;
  return event.sessionsCompleted ? count : event.currentSession;
}
