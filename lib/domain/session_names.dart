/// Oturum adları (isteğe bağlı) — web js/modules/events/session-names.js ile
/// aynı kurallar. Etkinlik dokümanında `sessionNames`: [0] = 1. oturumun adı.
/// Boş ad = yalnızca numara gösterilir.
library;

const int kSessionNameMax = 60;
const int kSessionNamesLimit = 50;

String _clean(Object? value) {
  final String text = (value ?? '')
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.length > kSessionNameMax
      ? text.substring(0, kSessionNameMax)
      : text;
}

/// Oturum sayısına göre keser/doldurur; hepsi boşsa boş liste.
List<String> normalizeSessionNames(List<Object?>? raw, int sessionCount) {
  final int count = sessionCount.clamp(0, kSessionNamesLimit);
  final List<Object?> list = raw ?? const <Object?>[];
  final List<String> names = List<String>.generate(
    count,
    (int i) => i < list.length ? _clean(list[i]) : '',
  );
  return names.any((String n) => n.isNotEmpty) ? names : const <String>[];
}

/// n. oturumun adı (1'den başlar); yoksa ''.
String sessionNameAt(List<String> names, int n) {
  final int i = n - 1;
  return i >= 0 && i < names.length ? _clean(names[i]) : '';
}

/// "Oturum 2: Makine Öğrenmesi" — ad yoksa yalnızca [base].
String withSessionName(String base, List<String> names, int n) {
  final String name = sessionNameAt(names, n);
  return name.isEmpty ? base : '$base: $name';
}

// ── Oturum saatleri (isteğe bağlı) ─────────────────────────────────────────
// `sessionTimes`: [{start: "14:45", end: "15:30"}, ...] — [0] = 1. oturum.

final RegExp _timeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

String _cleanTime(Object? value) {
  final String text = (value ?? '').toString().trim();
  return _timeRe.hasMatch(text) ? text : '';
}

class SessionTime {
  const SessionTime({this.start = '', this.end = ''});

  factory SessionTime.fromMap(Object? raw) {
    if (raw is! Map) return const SessionTime();
    final String start = _cleanTime(raw['start']);
    // Başlangıçsız bitiş anlamsız: yok sayılır.
    return SessionTime(
      start: start,
      end: start.isEmpty ? '' : _cleanTime(raw['end']),
    );
  }

  final String start;
  final String end;

  bool get isEmpty => start.isEmpty;

  /// "14:45 – 15:30" / "14:45" / ''.
  String get label =>
      start.isEmpty ? '' : (end.isEmpty ? start : '$start – $end');

  Map<String, String> toMap() => <String, String>{'start': start, 'end': end};
}

/// Oturum sayısına göre keser/doldurur; hepsi boşsa boş liste.
List<SessionTime> normalizeSessionTimes(
  List<SessionTime> raw,
  int sessionCount,
) {
  final int count = sessionCount.clamp(0, kSessionNamesLimit);
  final List<SessionTime> times = List<SessionTime>.generate(
    count,
    (int i) => i < raw.length
        ? SessionTime.fromMap(raw[i].toMap())
        : const SessionTime(),
  );
  return times.any((SessionTime t) => !t.isEmpty)
      ? times
      : const <SessionTime>[];
}

/// n. oturumun saat etiketi (1'den başlar); yoksa ''.
String sessionTimeAt(List<SessionTime> times, int n) {
  final int i = n - 1;
  return i >= 0 && i < times.length ? times[i].label : '';
}

/// İP-B1: oturum saatleri tutarlı mı? Sorunlu ilk oturum (1'den) + kod;
/// sorun yoksa null. Kodlar: end-before-start, overlap, order, before-event,
/// after-event. Saati boş oturum atlanır. Web: session-names.js#findSessionTimeProblem.
({int session, String code})? findSessionTimeProblem(
  List<SessionTime> times, {
  String eventStart = '',
  String eventEnd = '',
}) {
  final String evStart = _cleanTime(eventStart);
  final String evEnd = _cleanTime(eventEnd);
  String? prevStart;
  String prevEnd = '';
  for (int i = 0; i < times.length; i++) {
    final String start = _cleanTime(times[i].start);
    if (start.isEmpty) continue;
    final String end = _cleanTime(times[i].end);
    final int session = i + 1;
    if (end.isNotEmpty && end.compareTo(start) <= 0) {
      return (session: session, code: 'end-before-start');
    }
    if (evStart.isNotEmpty && start.compareTo(evStart) < 0) {
      return (session: session, code: 'before-event');
    }
    if (evEnd.isNotEmpty && (end.isEmpty ? start : end).compareTo(evEnd) > 0) {
      return (session: session, code: 'after-event');
    }
    if (prevStart != null) {
      if (start.compareTo(prevStart) < 0) return (session: session, code: 'order');
      if (prevEnd.isNotEmpty && start.compareTo(prevEnd) < 0) {
        return (session: session, code: 'overlap');
      }
      if (prevEnd.isEmpty && start == prevStart) {
        return (session: session, code: 'overlap');
      }
    }
    prevStart = start;
    prevEnd = end;
  }
  return null;
}
