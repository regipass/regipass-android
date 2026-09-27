/// Hesabım > onay bekleyen profil değişikliği bandı (İP-KP).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/profile_change.dart';
import '../../l10n/app_strings.dart';
import '../../services/club_profile_change_service.dart';

const Color _pendingBg = Color(0xFFFFF7E8);
const Color _pendingFg = Color(0xFF5C3A00);
const Color _rejectBg = Color(0xFFFFF1F1);
const Color _rejectFg = Color(0xFF7A1216);

class ClubProfileChangeBanner extends ConsumerStatefulWidget {
  const ClubProfileChangeBanner({super.key});

  @override
  ConsumerState<ClubProfileChangeBanner> createState() =>
      _ClubProfileChangeBannerState();
}

class _ClubProfileChangeBannerState
    extends ConsumerState<ClubProfileChangeBanner> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        content: Text(c.t('profileChange.withdrawConfirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(c.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(c.t('profileChange.withdraw')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(clubProfileChangeServiceProvider).cancel();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('feedback.saveErrorRetry'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClubProfileChange? change = ref
        .watch(clubProfileChangeProvider)
        .value;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (change == null ||
        (!change.isPending && !change.recentlyRejected(now))) {
      return const SizedBox.shrink();
    }
    final bool pending = change.isPending;
    final Color fg = pending ? _pendingFg : _rejectFg;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      key: const Key('clubProfileChangeBanner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pending ? _pendingBg : _rejectBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t(
              pending
                  ? 'profileChange.pendingTitle'
                  : 'profileChange.rejectedTitle',
            ),
            style: text.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pending
                ? context.t('profileChange.pendingHelp')
                : context.t('profileChange.rejectedNote', <String, Object?>{
                    'note': change.note,
                  }),
            style: text.bodySmall?.copyWith(color: fg),
          ),
          const SizedBox(height: 8),
          for (final ({String key, String before, String after}) row
              in change.rows())
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: row.key == 'logoUrl'
                  ? Row(
                      children: <Widget>[
                        Text(
                          '${context.t('profileChange.field.logoUrl')}: ',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            row.after,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 40, height: 40),
                          ),
                        ),
                      ],
                    )
                  : Text.rich(
                      TextSpan(
                        style: TextStyle(color: fg),
                        children: <InlineSpan>[
                          TextSpan(
                            text:
                                '${context.t('profileChange.field.${row.key}')}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: row.before.isEmpty ? '–' : row.before,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const TextSpan(text: '  →  '),
                          TextSpan(
                            text: row.after,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
            ),
          if (pending)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('clubProfileChangeWithdraw'),
                onPressed: _busy ? null : _withdraw,
                child: Text(context.t('profileChange.withdraw')),
              ),
            ),
        ],
      ),
    );
  }
}
