/// Yeni sertifika sistemi (İP-8) — saf kurallar.
///
/// Web + sunucu: js/modules/certificates/certificate-rules.js (sunucu kopyası
/// functions/shared/certificates). Mobil yalnızca panelde gösterilen sayıları
/// hesaplar; hak sahipliğinin asıl kararı gönderim anında SUNUCUDA verilir.
library;

import '../models/event.dart';
import 'checkin_mode.dart';

abstract final class CertStatus {
  static const String issued = 'issued';
  static const String revoked = 'revoked';
  static const String failed = 'failed';
}

/// Gönder düğmesinin durumu. [reason] null ise açık.
class SendGate {
  const SendGate(this.open, this.reason);
  final bool open;
  final String? reason;
}

/// Sadece Check-in: kapı bir kez açılmış ve şu an kapalı ("Check-in'i Bitir").
/// Yoklamalı modlar: "Oturumları Bitir" (sessionsCompleted).
SendGate certificateSendGate(AppEvent event) {
  if (event.cancelled) return const SendGate(false, 'event-cancelled');
  if (event.resolvedCheckinMode == CheckinMode.checkinOnly) {
    if (event.entryStartedAtMs <= 0) return const SendGate(false, 'checkin-not-started');
    if (event.entryOpen) return const SendGate(false, 'checkin-open');
    return const SendGate(true, null);
  }
  if (!event.sessionsCompleted) return const SendGate(false, 'sessions-not-finished');
  return const SendGate(true, null);
}

int certificateSessionTotal(AppEvent event) =>
    event.sessionCount > 1 ? event.sessionCount : 1;

/// Eşik: sertifika ayarındaki değer, yoksa etkinliktekiler; boş → null.
int? resolveCertificateThreshold(Object? configValue, AppEvent event) {
  for (final Object? raw in <Object?>[configValue, event.certificateThresholdPercent]) {
    if (raw == null) continue;
    final num? n = raw is num ? raw : num.tryParse('$raw');
    if (n != null && n > 0) return n.round().clamp(1, 100);
  }
  return null;
}

class CertEvaluation {
  const CertEvaluation({
    required this.eligible,
    required this.attended,
    required this.total,
    required this.percent,
    this.reason,
  });
  final bool eligible;
  final int attended;
  final int total;
  final double percent;
  final String? reason;
}

CertEvaluation evaluateCertificate(
  AppEvent event,
  EventRegistration reg,
  int? threshold,
) {
  final bool paymentPending = event.isPaid && reg.paymentStatus == 'pending';
  if (event.resolvedCheckinMode == CheckinMode.checkinOnly) {
    final bool inside = reg.isCheckedIn;
    if (!inside) {
      return const CertEvaluation(eligible: false, attended: 0, total: 1, percent: 0, reason: 'not-checked-in');
    }
    return CertEvaluation(
      eligible: !paymentPending,
      attended: 1,
      total: 1,
      percent: 100,
      reason: paymentPending ? 'payment-pending' : null,
    );
  }
  final int total = certificateSessionTotal(event);
  final int attended = reg.sessionsAttended.clamp(0, total);
  final double percent = (attended / total * 1000).round() / 10;
  String? reason;
  if (attended < 1) {
    reason = 'no-session';
  } else if (threshold != null && attended / total * 100 + 1e-9 < threshold) {
    reason = 'below-threshold';
  } else if (paymentPending) {
    reason = 'payment-pending';
  }
  return CertEvaluation(
    eligible: reason == null,
    attended: attended,
    total: total,
    percent: percent,
    reason: reason,
  );
}

class CertSummary {
  int registered = 0;
  int eligible = 0;
  int sent = 0;
  int pending = 0;
  int revoked = 0;
  int failed = 0;
  int belowThreshold = 0;
  int outdated = 0;
  final Map<String, int> distribution = <String, int>{};
}

/// Panel özeti. [certs]: öğrenci kimliği → { status, configVersion }.
CertSummary summarizeCertificates(
  AppEvent event,
  List<EventRegistration> registrations,
  int? threshold,
  Map<String, Map<String, Object?>> certs, {
  int configVersion = 0,
}) {
  final CertSummary s = CertSummary();
  for (final EventRegistration reg in registrations) {
    if (reg.studentId.isEmpty) continue;
    s.registered += 1;
    final CertEvaluation r = evaluateCertificate(event, reg, threshold);
    final String key = '${r.attended}/${r.total}';
    s.distribution[key] = (s.distribution[key] ?? 0) + 1;
    final String? status = certs[reg.studentId]?['status'] as String?;
    if (r.eligible) {
      s.eligible += 1;
      if (status != CertStatus.issued) s.pending += 1;
    } else if (status == CertStatus.issued) {
      s.belowThreshold += 1;
    }
  }
  for (final Map<String, Object?> c in certs.values) {
    final String? status = c['status'] as String?;
    if (status == CertStatus.issued) {
      s.sent += 1;
      final num v = (c['configVersion'] as num?) ?? 0;
      if (configVersion > 0 && v < configVersion) s.outdated += 1;
    }
    if (status == CertStatus.revoked) s.revoked += 1;
    if (status == CertStatus.failed) s.failed += 1;
  }
  return s;
}

/// LinkedIn "Lisanslar ve sertifikalar"a ekle bağlantısı (web ile aynı).
const String kLinkedInOrgId = '138504079';

Uri linkedInAddUri({
  required String code,
  required int issuedAtMs,
  required String clubName,
  required String eventTitle,
  String lang = 'tr',
}) {
  final String suffix = lang == 'en' ? 'Certificate of Attendance' : 'Katılım Belgesi';
  final String name = <String>[
    if (clubName.isNotEmpty) clubName,
    '$eventTitle $suffix'.trim(),
  ].join(' — ');
  final DateTime issued = DateTime.fromMillisecondsSinceEpoch(
    issuedAtMs > 0 ? issuedAtMs : DateTime.now().millisecondsSinceEpoch,
  );
  return Uri.https('www.linkedin.com', '/profile/add', <String, String>{
    'startTask': 'CERTIFICATION_NAME',
    'name': name,
    'issueYear': '${issued.year}',
    'issueMonth': '${issued.month}',
    'certUrl': 'https://regipass.com/dogrula/$code',
    'certId': code,
    'organizationId': kLinkedInOrgId,
  });
}

String certificateVerifyUrl(String code) => 'https://regipass.com/dogrula/$code';
