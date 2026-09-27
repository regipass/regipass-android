/// Kulüpten engelleme penceresi (İP-KB) — js/modules/club/club-blocks.js
/// #runBlockFlow karşılığı. Gerekçe zorunlu (öğrenciye gösterilmez);
/// isteğe bağlı olarak öğrencinin gelecek etkinliklerdeki kayıtları silinir.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/club_block.dart';

class ClubBlockDecision {
  const ClubBlockDecision({
    required this.reason,
    required this.removeFutureRegistrations,
  });

  final String reason;
  final bool removeFutureRegistrations;
}

/// Vazgeçilirse null.
Future<ClubBlockDecision?> askClubBlock(BuildContext context, String name) =>
    showDialog<ClubBlockDecision>(
      context: context,
      builder: (BuildContext dialogContext) => _ClubBlockDialog(name: name),
    );

class _ClubBlockDialog extends StatefulWidget {
  const _ClubBlockDialog({required this.name});

  final String name;

  @override
  State<_ClubBlockDialog> createState() => _ClubBlockDialogState();
}

class _ClubBlockDialogState extends State<_ClubBlockDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _removeFuture = false;
  bool _showError = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final String reason = cleanClubBlockReason(_reason.text);
    if (reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(
      ClubBlockDecision(
        reason: reason,
        removeFutureRegistrations: _removeFuture,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('clubBlock.title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.t('clubBlock.body', <String, Object?>{
                'name': widget.name,
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('clubBlockReason'),
              controller: _reason,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.t('clubBlock.reasonLabel'),
                helperText: context.t('clubBlock.reasonHelper'),
                helperMaxLines: 2,
                errorText: _showError
                    ? context.t('clubBlock.reasonRequired')
                    : null,
              ),
            ),
            CheckboxListTile(
              key: const Key('clubBlockRemoveFuture'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _removeFuture,
              onChanged: (bool? v) => setState(() => _removeFuture = v == true),
              title: Text(context.t('clubBlock.removeFuture')),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        TextButton(
          key: const Key('clubBlockSubmit'),
          onPressed: _submit,
          child: Text(
            context.t('clubBlock.action'),
            style: const TextStyle(color: BrandColors.danger),
          ),
        ),
      ],
    );
  }
}
