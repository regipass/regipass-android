/// Üst çubuktaki zil düğmesi — okunmamış bildirim rozetiyle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import 'notification_providers.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({required this.route, super.key});

  /// Öğrenci ya da kulüp bildirimler rotası.
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      tooltip: context.t('student.notifications.title'),
      onPressed: () => context.push(route),
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.notifications_none_rounded),
          if (unread > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                decoration: BoxDecoration(
                  color: BrandColors.red,
                  borderRadius: BorderRadius.circular(8),
                  // Zeminle arasında ince bir boşluk: rozet, simgenin
                  // çizgilerine yapışınca okunmuyordu.
                  border: Border.all(color: context.surface, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: BrandColors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
