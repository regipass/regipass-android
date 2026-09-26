/// Engelleme kararı (İP-M1) — js/modules/admin/ban-actions.js#askBanDecision
/// karşılığı.
///
/// Engellemede gerekçe ZORUNLU (işlem kaydına yazılır, öğrencilere
/// gösterilmez). Kulüpte önce sunucudan etkisi okunur: kaç gelecek etkinlik
/// iptal edilecek, kaç kişiye bildirim gidecek. Engel kaldırmada yalnızca onay.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../services/admin_repository.dart';
import '../../state/providers.dart';

/// Engelleme gerekçesinin en fazla uzunluğu (sunucuyla aynı).
const int kBanReasonMaxLength = 300;

/// Gerekçe metnini temizler: boşluklar tekilleşir, uzunluk kırpılır.
String cleanBanReason(String? value) {
  final String text = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > kBanReasonMaxLength
      ? text.substring(0, kBanReasonMaxLength)
      : text;
}

/// Dönüş: engellemede gerekçe, engel kaldırmada '' (onay), vazgeçilirse null.
Future<String?> askBanDecision(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
  required String message,
  required bool banning,
  required bool isClub,
  String? title,
}) async {
  if (!banning) {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('common.continueAction')),
          ),
        ],
      ),
    );
    return ok == true ? '' : null;
  }

  final Future<BanPreview?> preview = isClub
      ? ref
            .read(adminRepositoryProvider)
            .previewBan(uid)
            .then<BanPreview?>((BanPreview p) => p)
            .catchError((Object _) => null)
      : Future<BanPreview?>.value(null);

  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _BanReasonDialog(
      title: title,
      message: message,
      preview: preview,
      isClub: isClub,
    ),
  );
}

class _BanReasonDialog extends StatefulWidget {
  const _BanReasonDialog({
    required this.message,
    required this.preview,
    required this.isClub,
    this.title,
  });

  final String? title;
  final String message;
  final Future<BanPreview?> preview;
  final bool isClub;

  @override
  State<_BanReasonDialog> createState() => _BanReasonDialogState();
}

class _BanReasonDialogState extends State<_BanReasonDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final String reason = cleanBanReason(_reason.text);
    if (reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title == null ? null : Text(widget.title!),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.message),
            if (widget.isClub)
              FutureBuilder<BanPreview?>(
                future: widget.preview,
                builder:
                    (BuildContext context, AsyncSnapshot<BanPreview?> snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final BanPreview? p = snap.data;
                      if (p == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          context.t('admin.ban.clubImpact', <String, Object?>{
                            'events': p.futureEvents,
                            'people': p.registrations,
                          }),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('banReasonField'),
              controller: _reason,
              maxLength: kBanReasonMaxLength,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.t('admin.ban.reasonLabel'),
                helperText: context.t('admin.ban.reasonHelper'),
                errorText: _showError
                    ? context.t('admin.ban.reasonRequired')
                    : null,
              ),
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
          key: const Key('banReasonSubmit'),
          onPressed: _submit,
          child: Text(context.t('common.continueAction')),
        ),
      ],
    );
  }
}
