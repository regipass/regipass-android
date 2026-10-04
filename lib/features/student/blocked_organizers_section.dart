/// Hesabım > Engellediğim organizatörler (İP-ŞK). Liste boşsa görünmez.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/event_complaint.dart';
import '../../l10n/app_strings.dart';
import '../../services/event_complaint_service.dart';

class BlockedOrganizersSection extends ConsumerStatefulWidget {
  const BlockedOrganizersSection({super.key});

  @override
  ConsumerState<BlockedOrganizersSection> createState() =>
      _BlockedOrganizersSectionState();
}

class _BlockedOrganizersSectionState
    extends ConsumerState<BlockedOrganizersSection> {
  final Set<String> _busy = <String>{};

  Future<void> _unblock(BlockedOrganizer organizer, String name) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String doneText = context.t(
      'complaint.blocked.unblocked',
      <String, Object?>{'name': name},
    );
    setState(() => _busy.add(organizer.clubId));
    try {
      await ref
          .read(eventComplaintServiceProvider)
          .setBlocked(organizer.clubId, block: false);
      ref.invalidate(blockedOrganizersProvider);
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.t(complaintErrorKey(complaintErrorReason(error))),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(organizer.clubId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<BlockedOrganizer> list =
        ref.watch(blockedOrganizersProvider).value ??
        const <BlockedOrganizer>[];
    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        key: const ValueKey<String>('blocked-organizers-section'),
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
              context.t('complaint.blocked.title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('complaint.blocked.help'),
              style: TextStyle(fontSize: 13.5, color: context.inkMuted),
            ),
            const SizedBox(height: 4),
            for (final BlockedOrganizer organizer in list)
              Builder(
                builder: (BuildContext context) {
                  final String name = organizer.clubName.isNotEmpty
                      ? organizer.clubName
                      : context.t('dashboard.clubFallback');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _busy.contains(organizer.clubId)
                              ? null
                              : () => _unblock(organizer, name),
                          child: Text(context.t('complaint.blocked.unblock')),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
