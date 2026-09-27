/// Profilim > Takip ettiğim kulüpler (İP-TK).
/// Web: js/pages/followed-clubs-section.js.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/club_follow.dart';
import '../../l10n/app_strings.dart';
import '../../services/club_follow_service.dart';

class FollowedClubsSection extends ConsumerStatefulWidget {
  const FollowedClubsSection({super.key});

  @override
  ConsumerState<FollowedClubsSection> createState() =>
      _FollowedClubsSectionState();
}

class _FollowedClubsSectionState extends ConsumerState<FollowedClubsSection> {
  final Set<String> _busy = <String>{};

  Future<void> _unfollow(FollowedClub club) async {
    final String name = club.clubName.isNotEmpty
        ? club.clubName
        : context.t('dashboard.clubFallback');
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        content: Text(
          ctx.t('follow.account.confirmUnfollow', <String, Object?>{
            'name': name,
          }),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t('follow.unfollow')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final String doneText = context.t(
      'follow.account.unfollowed',
      <String, Object?>{'name': name},
    );
    setState(() => _busy.add(club.clubId));
    try {
      await ref
          .read(clubFollowServiceProvider)
          .setFollow(club.clubId, follow: false);
      ref.invalidate(followedClubsProvider);
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t(followErrorKey(followErrorReason(error)))),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(club.clubId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<FollowedClub>> clubs = ref.watch(
      followedClubsProvider,
    );
    // Okunamazsa (ör. ağ yok) bölüm hiç görünmez; profil sayfası bozulmasın.
    if (clubs.hasError && !clubs.hasValue) return const SizedBox.shrink();
    final List<FollowedClub> list = clubs.value ?? const <FollowedClub>[];

    return Container(
      key: const ValueKey<String>('followed-clubs-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t('follow.account.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('follow.account.help'),
            style: TextStyle(fontSize: 13.5, color: context.inkMuted),
          ),
          const SizedBox(height: 12),
          if (clubs.isLoading && !clubs.hasValue)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (list.isEmpty)
            Text(
              context.t('follow.account.empty'),
              style: TextStyle(fontSize: 13.5, color: context.inkMuted),
            )
          else
            for (final FollowedClub club in list)
              _FollowedClubTile(
                club: club,
                busy: _busy.contains(club.clubId),
                onUnfollow: () => _unfollow(club),
              ),
        ],
      ),
    );
  }
}

class _FollowedClubTile extends StatelessWidget {
  const _FollowedClubTile({
    required this.club,
    required this.busy,
    required this.onUnfollow,
  });

  final FollowedClub club;
  final bool busy;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    final String name = club.clubName.isNotEmpty
        ? club.clubName
        : context.t('dashboard.clubFallback');
    final String meta = <String>[
      club.university,
      club.city,
    ].where((String s) => s.isNotEmpty).join(' · ');
    final String initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: club.logoUrl.startsWith('https://')
                  ? Image.network(
                      club.logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _Initial(initial),
                    )
                  : _Initial(initial),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: TextStyle(fontSize: 12.5, color: context.inkMuted),
                  ),
                if (!club.available)
                  Text(
                    context.t('follow.account.unavailable'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.danger,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : onUnfollow,
            child: Text(context.t('follow.unfollow')),
          ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.subtleFill,
    child: Center(
      child: Text(
        letter,
        style: TextStyle(fontWeight: FontWeight.w800, color: context.brandInk),
      ),
    ),
  );
}
