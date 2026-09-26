/// Kapı okutma kararı (İP-O) — js/modules/events/door-gate.js ile aynı kurallar.
///
/// Saf kod: ağ, saat ya da depolama yok. Okunan bilet + etkinlik + kayıt →
/// sonuç. Denetleyici (lib/services/door_gate.dart) bu kararı cihazdaki
/// bilet listesiyle verir; internet yokken de çalışır.
library;

import '../models/profiles.dart';
import 'checkin_mode.dart';
import 'qr_signing.dart';

enum GateResult {
  /// Giriş alındı.
  checkedIn('in'),

  /// Daha önce girmiş — HATA değil (dışarı çıkıp dönen olabilir).
  already('already'),

  /// Bilet kodu kayıtla eşleşmiyor (eski ya da taklit bilet).
  invalidTicket('invalid-ticket'),
  notRegistered('not-registered'),
  otherEvent('other-event'),
  notOwner('not-owner'),

  /// "Sadece Yoklama": kapı bileti yok.
  noDoor('no-door'),
  pastEvent('past-event'),

  /// Regipass bileti değil.
  notTicket('not-ticket'),

  /// Etkinlik bulunamadı (internetsiz ve listesi cihazda yok).
  unknownEvent('unknown-event'),

  /// Aynı bilet az önce okundu → sessizce yok sayılır.
  duplicate('duplicate');

  const GateResult(this.code);

  /// Web ile ortak ad (çeviri anahtarı: `gate.result.<code>`).
  final String code;
}

enum GateTone { ok, warn, bad, none }

GateTone toneForResult(GateResult result) => switch (result) {
  GateResult.checkedIn => GateTone.ok,
  GateResult.already => GateTone.warn,
  GateResult.duplicate => GateTone.none,
  _ => GateTone.bad,
};

/// Kapıda gereken etkinlik alanları.
class GateEvent {
  const GateEvent({
    required this.id,
    required this.title,
    required this.clubId,
    required this.checkinMode,
    required this.sessionCount,
    required this.eventDateAtMs,
    required this.deadlineAtMs,
  });

  factory GateEvent.fromMap(String id, Map<String, dynamic> data) => GateEvent(
    id: id,
    title: asString(data['title']),
    clubId: asString(data['clubId']),
    checkinMode: data['checkinMode'] is String
        ? data['checkinMode'] as String
        : null,
    sessionCount: asInt(data['sessionCount']) ?? 0,
    eventDateAtMs: asEpochMilliseconds(data['eventDateAtMs']) ?? 0,
    deadlineAtMs: asEpochMilliseconds(data['deadlineAtMs']) ?? 0,
  );

  final String id;
  final String title;
  final String clubId;
  final String? checkinMode;
  final int sessionCount;
  final int eventDateAtMs;
  final int deadlineAtMs;

  bool get hasDoorCheckin => CheckinMode.hasDoorCheckin(
    CheckinMode.resolve(checkinMode, sessionCount),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'clubId': clubId,
    'checkinMode': checkinMode,
    'sessionCount': sessionCount,
    'eventDateAtMs': eventDateAtMs,
    'deadlineAtMs': deadlineAtMs,
  };
}

/// Kapıda gereken kayıt alanları. Telefon ve e-posta cihaza YAZILMAZ.
class GateRegistration {
  GateRegistration({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.studentName,
    required this.studentPhotoUrl,
    required this.studentDepartment,
    required this.studentUniversity,
    required this.studentClassYear,
    required this.ticketCode,
    required this.checkedInAtMs,
  });

  factory GateRegistration.fromMap(String id, Map<String, dynamic> data) {
    String name = asString(data['studentName']);
    if (name.isEmpty) {
      name =
          '${asString(data['studentFirstName'])} ${asString(data['studentLastName'])}'
              .trim();
    }
    if (name.isEmpty) {
      final String email = asString(data['studentEmail']);
      if (email.isNotEmpty) name = email.split('@').first;
    }
    final int checked = asInt(data['checkedInAtMs']) ?? 0;
    return GateRegistration(
      id: id,
      eventId: asString(data['eventId']),
      studentId: asString(data['studentId']),
      studentName: name,
      studentPhotoUrl: asString(data['studentPhotoUrl']),
      studentDepartment: asString(data['studentDepartment']),
      studentUniversity: asString(data['studentUniversity']),
      studentClassYear: asString(data['studentClassYear']),
      ticketCode: asString(data['ticketCode']),
      checkedInAtMs: checked > 0 ? checked : 0,
    );
  }

  final String id;
  final String eventId;
  final String studentId;
  final String studentName;
  final String studentPhotoUrl;
  final String studentDepartment;
  final String studentUniversity;
  final String studentClassYear;
  final String ticketCode;

  /// Giriş saati (cihazda alınır); 0 = girmedi.
  int checkedInAtMs;

  bool get isCheckedIn => checkedInAtMs > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'eventId': eventId,
    'studentId': studentId,
    'studentName': studentName,
    'studentPhotoUrl': studentPhotoUrl,
    'studentDepartment': studentDepartment,
    'studentUniversity': studentUniversity,
    'studentClassYear': studentClassYear,
    'ticketCode': ticketCode,
    'checkedInAtMs': checkedInAtMs,
  };
}

/// Web'deki isPastEvent ile aynı: etkinliğin GÜNÜ (yoksa son başvuru günü)
/// bugünden önceyse kapı kapanmıştır. Aynı gün içinde okutma serbesttir.
bool isGateEventOver(GateEvent event, {required DateTime now}) {
  final int ref = event.eventDateAtMs > 0
      ? event.eventDateAtMs
      : event.deadlineAtMs;
  if (ref <= 0) return false;
  final DateTime day = DateTime.fromMillisecondsSinceEpoch(ref);
  final DateTime refDay = DateTime(day.year, day.month, day.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  return refDay.isBefore(today);
}

GateRegistration? findGateRegistration(
  List<GateRegistration> regs,
  Map<String, dynamic> payload,
) {
  final String regId = '${payload['registrationId'] ?? ''}';
  final String studentId = '${payload['studentId'] ?? ''}';
  if (regId.isNotEmpty) {
    for (final GateRegistration r in regs) {
      if (r.id == regId) return r;
    }
  }
  if (studentId.isNotEmpty) {
    for (final GateRegistration r in regs) {
      if (r.studentId == studentId) return r;
    }
  }
  return null;
}

/// Saf karar.
({GateResult result, bool legacy}) evaluateGateTicket({
  required Map<String, dynamic>? payload,
  required GateEvent? event,
  required GateRegistration? registration,
  required String clubId,
  required DateTime now,
  String expectedEventId = '',
}) {
  ({GateResult result, bool legacy}) r(GateResult x) =>
      (result: x, legacy: false);

  if (payload == null || payload['type'] != 'event-checkin') {
    return r(GateResult.notTicket);
  }
  final String eventId = '${payload['eventId'] ?? ''}';
  final String studentId = '${payload['studentId'] ?? ''}';
  final String regId = '${payload['registrationId'] ?? ''}';
  if (eventId.isEmpty || (studentId.isEmpty && regId.isEmpty)) {
    return r(GateResult.notTicket);
  }
  if (expectedEventId.isNotEmpty && eventId != expectedEventId) {
    return r(GateResult.otherEvent);
  }
  if (event == null) return r(GateResult.unknownEvent);
  if (clubId.isNotEmpty && event.clubId.isNotEmpty && event.clubId != clubId) {
    return r(GateResult.notOwner);
  }
  if (isGateEventOver(event, now: now)) return r(GateResult.pastEvent);
  if (!event.hasDoorCheckin) return r(GateResult.noDoor);
  if (registration == null) return r(GateResult.notRegistered);
  if (registration.isCheckedIn) return r(GateResult.already);
  final ({bool ok, bool legacy}) ticket = verifyTicketCode(
    given: payload['c'] is String ? payload['c'] as String : null,
    expected: registration.ticketCode,
  );
  if (!ticket.ok) return r(GateResult.invalidTicket);
  return (result: GateResult.checkedIn, legacy: ticket.legacy);
}
