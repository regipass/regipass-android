import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../l10n/app_strings.dart';
import '../notifications/notification_list_view.dart';
import 'club_shell.dart';

/// Kulüp bildirimleri.
///
/// Öğrenci tarafıyla aynı liste; metinler düzenleyici gözüyle yazılır
/// (ör. "başvurular kapandı, katılımcı listesi kesinleşti").
class ClubNotificationsScreen extends StatelessWidget {
  const ClubNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReadableScaffold(
      appBar: ClubAppBar(
        title: context.t('student.notifications.title'),
        showBack: true,
        actions: const <Widget>[SizedBox.shrink()],
      ),
      body: const NotificationListView(),
    );
  }
}
