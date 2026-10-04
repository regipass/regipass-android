/// Etkinlik penceresinin altındaki "Şikâyet et" / "Organizatörü engelle"
/// satırı (İP-ŞK, App Store 1.2). Yalnızca giriş yapmış katılımcıya görünür.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/event_complaint.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/event_complaint_service.dart';
import '../../state/providers.dart';

class EventComplaintSection extends ConsumerStatefulWidget {
  const EventComplaintSection({required this.event, this.onBlocked, super.key});

  final AppEvent event;

  /// Organizatör engellenince (ör. etkinlik penceresini kapatmak için).
  final VoidCallback? onBlocked;

  @override
  ConsumerState<EventComplaintSection> createState() =>
      _EventComplaintSectionState();
}

class _EventComplaintSectionState extends ConsumerState<EventComplaintSection> {
  bool _busy = false;

  Future<void> _report() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String doneText = context.t('complaint.sent');
    final bool? sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext _) => _ComplaintSheet(event: widget.event),
    );
    if (sent == true) {
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
    }
  }

  Future<void> _block() async {
    if (_busy) return;
    final String name = widget.event.clubName.isNotEmpty
        ? widget.event.clubName
        : context.t('dashboard.clubFallback');
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String doneText = context.t('complaint.block.done', <String, Object?>{
      'name': name,
    });
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('complaint.block.title')),
        content: Text(
          ctx.t('complaint.block.confirm', <String, Object?>{'name': name}),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            key: const ValueKey<String>('complaint-block-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t('complaint.block.action')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(eventComplaintServiceProvider)
          .setBlocked(widget.event.clubId, block: true);
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
      widget.onBlocked?.call();
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = ref.watch(currentUidProvider);
    final String clubId = widget.event.clubId;
    if (uid == null || clubId.isEmpty || clubId == uid) {
      return const SizedBox.shrink();
    }
    final ButtonStyle style = TextButton.styleFrom(
      foregroundColor: context.inkMuted,
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(
        fontFamily: BrandFonts.body,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
    return Column(
      key: const ValueKey<String>('event-complaint-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Divider(height: 1, color: context.hairline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: <Widget>[
            TextButton.icon(
              key: const ValueKey<String>('complaint-report-button'),
              onPressed: _report,
              style: style,
              icon: const Icon(Icons.flag_outlined, size: 17),
              label: Text(context.t('complaint.report')),
            ),
            TextButton.icon(
              key: const ValueKey<String>('complaint-block-button'),
              onPressed: _busy ? null : _block,
              style: style,
              icon: const Icon(Icons.block, size: 17),
              label: Text(context.t('complaint.block.button')),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComplaintSheet extends ConsumerStatefulWidget {
  const _ComplaintSheet({required this.event});

  final AppEvent event;

  @override
  ConsumerState<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends ConsumerState<_ComplaintSheet> {
  final TextEditingController _note = TextEditingController();
  ComplaintReason? _reason;
  bool _sending = false;
  String? _errorKey;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ComplaintReason? reason = _reason;
    if (reason == null || _sending) return;
    final NavigatorState navigator = Navigator.of(context);
    setState(() {
      _sending = true;
      _errorKey = null;
    });
    try {
      await ref
          .read(eventComplaintServiceProvider)
          .reportEvent(
            eventId: widget.event.id,
            reason: reason,
            note: _note.text,
          );
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorKey = complaintErrorKey(complaintErrorReason(error));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = complaintReady(_reason, _note.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.t('complaint.title'),
              style: const TextStyle(
                fontFamily: BrandFonts.heading,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('complaint.help'),
              style: TextStyle(fontSize: 13.5, color: context.inkMuted),
            ),
            const SizedBox(height: 10),
            for (final ComplaintReason reason in ComplaintReason.values)
              InkWell(
                key: ValueKey<String>('complaint-reason-${reason.wire}'),
                borderRadius: BorderRadius.circular(10),
                onTap: _sending ? null : () => setState(() => _reason = reason),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _reason == reason
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 21,
                        color: _reason == reason
                            ? BrandColors.red
                            : context.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t(reason.labelKey),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('complaint-note'),
              controller: _note,
              enabled: !_sending,
              minLines: 2,
              maxLines: 4,
              maxLength: kComplaintNoteMax,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.t(
                  _reason == ComplaintReason.other
                      ? 'complaint.noteRequiredHint'
                      : 'complaint.noteHint',
                ),
              ),
            ),
            if (_errorKey != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                context.t(_errorKey!),
                style: const TextStyle(fontSize: 13, color: BrandColors.danger),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('complaint-send'),
              onPressed: ready && !_sending ? _send : null,
              child: Text(
                context.t(_sending ? 'complaint.sending' : 'complaint.send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
