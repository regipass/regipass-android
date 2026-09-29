/// Etkinlik penceresindeki kulüp satırında "Takip et / Takip ediliyor" (İP-TK).
/// Web: js/modules/clubs/follow.js#mountFollowButton.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/club_follow.dart';
import '../../l10n/app_strings.dart';
import '../../services/club_follow_service.dart';

class ClubFollowButton extends ConsumerStatefulWidget {
  const ClubFollowButton({required this.clubId, super.key});

  final String clubId;

  @override
  ConsumerState<ClubFollowButton> createState() => _ClubFollowButtonState();
}

class _ClubFollowButtonState extends ConsumerState<ClubFollowButton> {
  bool _busy = false;

  /// Sunucu yanıtı gelene kadar gösterilen durum (anında tepki).
  bool? _optimistic;

  Future<void> _toggle(bool following) async {
    if (_busy) return;
    final bool next = !following;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String okText = context.t(
      next ? 'follow.toastFollowed' : 'follow.toastUnfollowed',
    );
    setState(() {
      _busy = true;
      _optimistic = next;
    });
    try {
      await ref
          .read(clubFollowServiceProvider)
          .setFollow(widget.clubId, follow: next);
      ref.invalidate(followedClubsProvider);
      messenger.showSnackBar(SnackBar(content: Text(okText)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _optimistic = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t(followErrorKey(followErrorReason(error)))),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clubId.isEmpty) return const SizedBox.shrink();
    final Set<String> ids =
        ref.watch(followedClubIdsProvider).value ?? const <String>{};
    final bool live = ids.contains(widget.clubId);
    // Canlı liste yetişince iyimser durum bırakılır.
    if (_optimistic != null && _optimistic == live && !_busy) {
      _optimistic = null;
    }
    final bool following = _optimistic ?? live;

    final ButtonStyle style = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      minimumSize: const Size(0, 34),
      shape: const StadiumBorder(),
      side: BorderSide(
        color: following ? context.hairline : BrandColors.red,
        width: 1.5,
      ),
      foregroundColor: following ? context.inkMuted : context.brandInk,
      backgroundColor: following ? context.subtleFill : null,
      textStyle: const TextStyle(
        fontFamily: BrandFonts.body,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );

    return Semantics(
      toggled: following,
      child: OutlinedButton.icon(
        key: const ValueKey<String>('club-follow-button'),
        onPressed: _busy ? null : () => _toggle(following),
        style: style,
        icon: Icon(following ? Icons.check : Icons.add, size: 16),
        label: Text(
          context.t(following ? 'follow.following' : 'follow.follow'),
        ),
      ),
    );
  }
}
