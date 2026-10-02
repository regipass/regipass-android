/// Bilet kodunu ELLE girme (yalnızca kapıda giriş) — web
/// js/modules/events/ticket-code.js ile aynı kurallar. Kamera okumadığında
/// öğrenci biletinin altındaki kodu söyler, görevli yazar.
library;

import 'door_gate.dart';

const int kManualCodeMin = 6;

/// Ekranda okunaklı biçim: "K7P2Q X9A1B".
String formatTicketCode(String code) {
  if (code.length <= 5) return code;
  final int half = (code.length / 2).ceil();
  return '${code.substring(0, half)} ${code.substring(half)}';
}

String normalizeTicketCodeInput(String value) =>
    value.replaceAll(RegExp(r'\s+'), '');

enum TicketCodeMatch { tooShort, none, ambiguous, found }

/// Büyük/küçük harf ve boşluk önemsenmez; yalnızca harf büyüklüğü farklı iki
/// kod varsa tam yazım istenir.
({TicketCodeMatch status, GateRegistration? registration}) matchTicketCode(
  List<GateRegistration> registrations,
  String input,
) {
  final String typed = normalizeTicketCodeInput(input);
  if (typed.length < kManualCodeMin) {
    return (status: TicketCodeMatch.tooShort, registration: null);
  }
  final List<GateRegistration> list = registrations
      .where((GateRegistration r) => r.ticketCode.isNotEmpty)
      .toList(growable: false);
  final List<GateRegistration> exact = list
      .where((GateRegistration r) => r.ticketCode == typed)
      .toList(growable: false);
  if (exact.length == 1) {
    return (status: TicketCodeMatch.found, registration: exact.first);
  }
  final String lower = typed.toLowerCase();
  final List<GateRegistration> loose = list
      .where((GateRegistration r) => r.ticketCode.toLowerCase() == lower)
      .toList(growable: false);
  if (loose.length == 1) {
    return (status: TicketCodeMatch.found, registration: loose.first);
  }
  return (
    status: loose.length > 1 ? TicketCodeMatch.ambiguous : TicketCodeMatch.none,
    registration: null,
  );
}

/// Üst üste yanlış denemede kısa bekletme.
class AttemptLimiter {
  AttemptLimiter({this.max = 5, this.lockMs = 30000, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final int max;
  final int lockMs;
  final DateTime Function() _now;
  int _fails = 0;
  int _lockedUntilMs = 0;

  int get lockedForMs {
    final int left = _lockedUntilMs - _now().millisecondsSinceEpoch;
    return left > 0 ? left : 0;
  }

  void fail() {
    _fails += 1;
    if (_fails >= max) {
      _fails = 0;
      _lockedUntilMs = _now().millisecondsSinceEpoch + lockMs;
    }
  }

  void success() => _fails = 0;
}
