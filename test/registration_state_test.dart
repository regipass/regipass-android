// İP-K: öğrencinin etkinlik penceresindeki durum/düğme kararı ve sunucu
// hata çevirisi (lib/domain/registration_state.dart,
// lib/services/registration_service.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/registration_capacity.dart';
import 'package:regipass/domain/registration_state.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/services/registration_service.dart';

AppEvent ev({
  bool cancelled = false,
  bool seatsFull = false,
  bool closed = false,
  String feeType = 'free',
}) {
  final DateTime now = DateTime.now();
  return AppEvent.fromMap('e1', <String, dynamic>{
    'title': 'Söyleşi',
    'clubId': 'club1',
    'feeType': feeType,
    'quota': 2,
    'quotaShardCount': 2,
    'deadlineAtMs': now.add(const Duration(days: 2)).millisecondsSinceEpoch,
    'eventDateAtMs': now.add(const Duration(days: 3)).millisecondsSinceEpoch,
    'registrationClosed': closed,
    'cancelled': cancelled,
    'seatsFull': seatsFull,
    'cancelReason': cancelled ? 'Salon' : '',
  });
}

void main() {
  test('açık etkinlik: Kaydol', () {
    final StudentRegistrationView v = studentRegistrationView(
      event: ev(),
      registered: false,
      paymentPending: false,
      waitlisted: false,
    );
    expect(v.primaryAction, StudentPrimaryAction.register);
    expect(v.primaryKey, 'dashboard.actions.register');
    expect(v.secondary, StudentSecondaryAction.none);
  });

  test('dolu etkinlik: Bekleme listesine gir', () {
    final StudentRegistrationView v = studentRegistrationView(
      event: ev(seatsFull: true),
      registered: false,
      paymentPending: false,
      waitlisted: false,
    );
    expect(v.primaryAction, StudentPrimaryAction.joinWaitlist);
    expect(v.statusKey, 'registration.status.fullWaitlist');
  });

  test(
    'bekleme listesinde: dolu → pasif + listeden çık; yer açıldı → Kaydol',
    () {
      final StudentRegistrationView full = studentRegistrationView(
        event: ev(seatsFull: true),
        registered: false,
        paymentPending: false,
        waitlisted: true,
      );
      expect(full.primaryEnabled, isFalse);
      expect(full.secondary, StudentSecondaryAction.leaveWaitlist);

      final StudentRegistrationView open = studentRegistrationView(
        event: ev(),
        registered: false,
        paymentPending: false,
        waitlisted: true,
      );
      expect(open.primaryAction, StudentPrimaryAction.register);
      expect(open.primaryKey, 'registration.actions.registerSeatOpen');
      expect(open.secondary, StudentSecondaryAction.leaveWaitlist);
    },
  );

  test('kayıtlı + ödeme bekliyor', () {
    final StudentRegistrationView v = studentRegistrationView(
      event: ev(feeType: 'paid'),
      registered: true,
      paymentPending: true,
      waitlisted: false,
    );
    expect(v.statusKey, 'registration.status.registeredPaymentPending');
    expect(v.statusTone, StudentStatusTone.warning);
    expect(v.secondary, StudentSecondaryAction.unregister);
  });

  test('iptal edilen etkinlik her şeyin önünde', () {
    final StudentRegistrationView v = studentRegistrationView(
      event: ev(cancelled: true, closed: true),
      registered: true,
      paymentPending: true,
      waitlisted: false,
    );
    expect(v.statusKey, 'registration.status.cancelled');
    expect(v.primaryEnabled, isFalse);
    expect(v.secondary, StudentSecondaryAction.none);
  });

  test('kapalı etkinlikte bekleyen listeden çıkabilir', () {
    final StudentRegistrationView v = studentRegistrationView(
      event: ev(closed: true),
      registered: false,
      paymentPending: false,
      waitlisted: true,
    );
    expect(v.primaryEnabled, isFalse);
    expect(v.secondary, StudentSecondaryAction.leaveWaitlist);
  });

  test(
    'ödeme durumu: eski kayıt onaylı, pending yalnızca ücretli etkinlikte',
    () {
      final EventRegistration pending = EventRegistration.fromMap(
        'e1_s1',
        <String, dynamic>{
          'eventId': 'e1',
          'studentId': 's1',
          'paymentStatus': 'pending',
        },
      );
      final EventRegistration legacy = EventRegistration.fromMap(
        'e1_s2',
        <String, dynamic>{'eventId': 'e1', 'studentId': 's2'},
      );
      expect(pending.paymentPendingFor(ev(feeType: 'paid')), isTrue);
      expect(pending.paymentPendingFor(ev()), isFalse);
      expect(legacy.paymentPendingFor(ev(feeType: 'paid')), isFalse);
    },
  );

  test('sunucu hataları: sebep korunur, ağ hataları "network"', () {
    expect(
      registrationFailureFrom('failed-precondition', <String, Object?>{
        'reason': 'deadline-passed',
      }).reason,
      'deadline-passed',
    );
    expect(
      registrationFailureFrom('failed-precondition', <String, Object?>{
        'reason': 'below-registered',
        'registered': 4,
      }).registered,
      4,
    );
    expect(registrationFailureFrom('unavailable', null).isNetwork, isTrue);
    expect(registrationFailureFrom('aborted', null).isNetwork, isTrue);
    expect(outcomeForReason('deadline-passed'), RegistrationOutcome.closed);
    expect(outcomeForReason('not-eligible'), RegistrationOutcome.notEligible);
    expect(outcomeForReason('event-not-found'), RegistrationOutcome.notFound);
    expect(outcomeForReason('busy'), RegistrationOutcome.retryExhausted);
  });
}
