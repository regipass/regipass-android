import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../shared/common_widgets.dart';
import 'student_appointments_screen.dart';
import 'student_providers.dart';
import 'student_shell.dart';

/// student-qr-generate.html + js/pages/student-qr-generate.js karşılığı.
///
/// Randevular sayfasından farkı: yalnızca **aktif** kayıtlar listelenir ve
/// karta dokunulduğunda QR üretimi otomatik başlar (web'deki
/// `openAndGenerate` davranışı).
class StudentQrGenerateScreen extends ConsumerWidget {
  const StudentQrGenerateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RegistrationWithEvent>> items =
        ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: StudentAppBar(
        title: context.t('dashboard.drawer.qrGenerate'),
        subtitle: context.t('studentAppointments.modal.qrHint'),
      ),
      body: items.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('studentAppointments.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<RegistrationWithEvent> list) {
          final List<RegistrationWithEvent> active =
              list.where((RegistrationWithEvent item) => !item.isClosed).toList();

          if (active.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                EmptyState(
                  message: context.t('studentAppointments.empty.active'),
                  icon: Icons.qr_code_2,
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) => AppointmentCard(
              item: active[index],
              autoGenerateQr: true,
            ),
          );
        },
      ),
    );
  }
}
