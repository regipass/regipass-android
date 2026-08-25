import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../notifications/notification_list_view.dart';
import 'student_shell.dart';

/// Öğrenci bildirimleri.
///
/// İçerik iki kaynaktan gelir (bkz. features/notifications/
/// notification_providers.dart): yöneticinin üniversiteye gönderdiği
/// duyurular ve öğrencinin kayıtlı olduğu etkinliklerden türeyen
/// hatırlatmalar (yaklaşıyor / başladı / başvurular kapandı).
class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(
        title: context.t('student.notifications.title'),
        showBack: true,
        actions: const <Widget>[SizedBox.shrink()],
      ),
      body: const NotificationListView(),
    );
  }
}
