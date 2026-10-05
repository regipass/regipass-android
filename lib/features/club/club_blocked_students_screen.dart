/// Hesabım > Engellenen öğrenciler (İP-KB) — club-account.html
/// #clubBlocksSection karşılığı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/club_block.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import 'club_providers.dart';

class ClubBlockedStudentsScreen extends ConsumerStatefulWidget {
  const ClubBlockedStudentsScreen({super.key});

  @override
  ConsumerState<ClubBlockedStudentsScreen> createState() =>
      _ClubBlockedStudentsScreenState();
}

class _ClubBlockedStudentsScreenState
    extends ConsumerState<ClubBlockedStudentsScreen> {
  String? _busyId;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  Future<void> _unblock(ClubBlock block) async {
    final String name = block.studentName.isNotEmpty
        ? block.studentName
        : context.t('clubBlock.studentFallback');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(
          dialogContext.t('clubBlock.unblockConfirm', <String, Object?>{
            'name': name,
          }),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('clubBlock.unblock')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = block.studentId);
    try {
      await ref
          .read(registrationServiceProvider)
          .clubUnblockStudent(block.studentId);
      if (!mounted) return;
      setState(() {
        _feedback = context.t('clubBlock.unblocked', <String, Object?>{
          'name': name,
        });
        _tone = FeedbackTone.success;
      });
    } on RegistrationFailure catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback = context.t('clubBlock.error');
        _tone = FeedbackTone.error;
      });
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _date(int ms) {
    if (ms <= 0) return '';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ClubBlock>> blocks = ref.watch(clubBlocksProvider);
    return ReadableScaffold(
      appBar: AppBar(title: Text(context.t('clubBlock.listTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(context.t('clubBlock.listHelp')),
          const SizedBox(height: 12),
          if (_feedback != null)
            FeedbackBanner(message: _feedback, tone: _tone),
          ...blocks.when(
            loading: () => <Widget>[const LoadingView()],
            error: (Object _, StackTrace _) => <Widget>[
              FeedbackBanner(
                message: context.t('clubBlock.error'),
                tone: FeedbackTone.error,
              ),
            ],
            data: (List<ClubBlock> list) => list.isEmpty
                ? <Widget>[EmptyState(message: context.t('clubBlock.empty'))]
                : list
                      .map(
                        (ClubBlock b) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(
                              b.studentName.isNotEmpty
                                  ? b.studentName
                                  : context.t('clubBlock.studentFallback'),
                            ),
                            subtitle: Text(
                              <String>[
                                if (b.studentUniversity.isNotEmpty)
                                  b.studentUniversity,
                                _date(b.createdAtMs),
                                '${context.t('clubBlock.reasonLabel')}: ${b.reason}',
                              ].where((String x) => x.isNotEmpty).join('\n'),
                            ),
                            isThreeLine: true,
                            trailing: _busyId == b.studentId
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _busyId == null
                                        ? () => _unblock(b)
                                        : null,
                                    child: Text(
                                      context.t('clubBlock.unblock'),
                                      style: const TextStyle(
                                        color: BrandColors.success,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }
}
