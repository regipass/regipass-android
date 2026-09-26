/// İP-K: öğrencinin etkinlik penceresindeki durum ve düğmeler (saf hesap).
///
/// Web karşılığı: js/pages/dashboard.js#getRegisterButtonState ve
/// #getUnregisterButtonState. Sıra önemli:
///   iptal edildi > kayıtlı > kapalı > (bekleme listesi) > dolu > açık
library;

import '../models/event.dart';
import 'event_utils.dart';

enum StudentPrimaryAction { register, joinWaitlist, none }

enum StudentSecondaryAction { unregister, leaveWaitlist, none }

/// Durum rozeti tonu (ekranda FeedbackTone'a çevrilir).
enum StudentStatusTone { info, success, warning, error }

class StudentRegistrationView {
  const StudentRegistrationView({
    required this.statusKey,
    required this.statusTone,
    required this.primaryKey,
    required this.primaryAction,
    required this.secondary,
    this.registered = false,
    this.waitlisted = false,
  });

  /// Çeviri anahtarı.
  final String statusKey;
  final StudentStatusTone statusTone;
  final String primaryKey;
  final StudentPrimaryAction primaryAction;
  final StudentSecondaryAction secondary;
  final bool registered;
  final bool waitlisted;

  bool get primaryEnabled => primaryAction != StudentPrimaryAction.none;
}

StudentRegistrationView studentRegistrationView({
  required AppEvent event,
  required bool registered,
  required bool paymentPending,
  required bool waitlisted,
  bool full = false,
  DateTime? now,
}) {
  final bool isFull = full || event.seatsFull;

  if (event.cancelled) {
    return StudentRegistrationView(
      statusKey: 'registration.status.cancelled',
      statusTone: StudentStatusTone.error,
      primaryKey: 'registration.status.cancelled',
      primaryAction: StudentPrimaryAction.none,
      secondary: StudentSecondaryAction.none,
      registered: registered,
    );
  }

  if (registered) {
    return StudentRegistrationView(
      statusKey: paymentPending
          ? 'registration.status.registeredPaymentPending'
          : 'dashboard.status.registered',
      statusTone: paymentPending
          ? StudentStatusTone.warning
          : StudentStatusTone.success,
      primaryKey: paymentPending
          ? 'registration.actions.registeredPaymentPending'
          : 'dashboard.actions.registered',
      primaryAction: StudentPrimaryAction.none,
      secondary: StudentSecondaryAction.unregister,
      registered: true,
    );
  }

  if (isRegistrationClosed(event, now: now)) {
    return StudentRegistrationView(
      statusKey: 'dashboard.status.expired',
      statusTone: StudentStatusTone.error,
      primaryKey: 'dashboard.status.expired',
      primaryAction: StudentPrimaryAction.none,
      secondary: waitlisted
          ? StudentSecondaryAction.leaveWaitlist
          : StudentSecondaryAction.none,
      waitlisted: waitlisted,
    );
  }

  if (waitlisted) {
    // Yer açıldıysa bekleyen hemen kayıt olabilir (ilk kayıt olan alır).
    return isFull
        ? const StudentRegistrationView(
            statusKey: 'registration.status.waitlisted',
            statusTone: StudentStatusTone.info,
            primaryKey: 'registration.status.waitlisted',
            primaryAction: StudentPrimaryAction.none,
            secondary: StudentSecondaryAction.leaveWaitlist,
            waitlisted: true,
          )
        : const StudentRegistrationView(
            statusKey: 'registration.status.waitlisted',
            statusTone: StudentStatusTone.success,
            primaryKey: 'registration.actions.registerSeatOpen',
            primaryAction: StudentPrimaryAction.register,
            secondary: StudentSecondaryAction.leaveWaitlist,
            waitlisted: true,
          );
  }

  if (isFull) {
    return const StudentRegistrationView(
      statusKey: 'registration.status.fullWaitlist',
      statusTone: StudentStatusTone.warning,
      primaryKey: 'registration.actions.joinWaitlist',
      primaryAction: StudentPrimaryAction.joinWaitlist,
      secondary: StudentSecondaryAction.none,
    );
  }

  return const StudentRegistrationView(
    statusKey: 'dashboard.status.open',
    statusTone: StudentStatusTone.info,
    primaryKey: 'dashboard.actions.register',
    primaryAction: StudentPrimaryAction.register,
    secondary: StudentSecondaryAction.none,
  );
}
