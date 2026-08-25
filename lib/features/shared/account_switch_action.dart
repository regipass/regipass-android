import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';

/// Yalnızca aynı Firebase hesabında öğrenci ve kulüp rolleri birlikte varsa
/// görünen, aktif rolü karşı role çeviren üst çubuk eylemi.
class AccountSwitchAction extends ConsumerWidget {
  const AccountSwitchAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session session = ref.watch(sessionProvider);
    final String? activeRole = session.resolvedRole;

    if (!session.hasBothRoles || activeRole == null) {
      return const SizedBox.shrink();
    }

    final String nextRole = activeRole == UserRole.student
        ? UserRole.club
        : UserRole.student;

    return IconButton(
      tooltip: context.t('account.switchRole'),
      onPressed: () => ref.read(activeRoleProvider.notifier).select(nextRole),
      icon: const Icon(Icons.swap_horiz_rounded),
    );
  }
}
