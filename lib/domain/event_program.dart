/// İP-P1: etkinlik programı (oturum listesi) — web event-program.js ile aynı.
library;

import '../models/event.dart';
import 'session_attendance.dart';
import 'session_names.dart';

enum ProgramState { done, live, upcoming }

class ProgramItem {
  const ProgramItem({
    required this.n,
    required this.name,
    required this.time,
    required this.state,
    this.attended = false,
    this.manual = false,
    this.count,
  });

  final int n;
  final String name;
  final String time;
  final ProgramState state;
  final bool attended;
  final bool manual;

  /// Organizatör görünümü: bu oturuma katılan kişi sayısı.
  final int? count;
}

class EventProgram {
  const EventProgram({
    required this.items,
    this.attendedCount,
    this.needed,
  });

  final List<ProgramItem> items;
  final int? attendedCount;

  /// Belge için gereken en az oturum (eşik yoksa null).
  final int? needed;
}

EventProgram? buildEventProgram(
  AppEvent event, {
  EventRegistration? registration,
  List<EventRegistration>? registrations,
}) {
  if (!event.isMultiSession) return null;
  final int total = event.sessionCount < 1 ? 1 : event.sessionCount;
  final int current = event.currentSession;
  final ({List<int> sessions, List<int> manual, bool exact})? mine =
      registration == null ? null : resolveAttendedSessions(registration, total);
  final List<int>? perSession = registrations == null
      ? null
      : <int>[
          for (int n = 1; n <= total; n++)
            registrations
                .where(
                  (EventRegistration r) =>
                      resolveAttendedSessions(r, total).sessions.contains(n),
                )
                .length,
        ];
  final List<ProgramItem> items = <ProgramItem>[
    for (int n = 1; n <= total; n++)
      ProgramItem(
        n: n,
        name: sessionNameAt(event.sessionNames, n),
        time: sessionTimeAt(event.sessionTimes, n),
        state: event.sessionsCompleted || n < current
            ? ProgramState.done
            : n == current
            ? ProgramState.live
            : ProgramState.upcoming,
        attended: mine?.sessions.contains(n) ?? false,
        manual: mine?.manual.contains(n) ?? false,
        count: perSession?[n - 1],
      ),
  ];
  final int threshold = event.certificateThresholdPercent ?? 0;
  return EventProgram(
    items: items,
    attendedCount: mine?.sessions.length,
    needed: threshold > 0 ? (threshold / 100 * total).ceil() : null,
  );
}
