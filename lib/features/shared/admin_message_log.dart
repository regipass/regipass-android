/// Yöneticinin bir kulübe yazdığı notların listesi.
///
/// İki taraf da aynı görünümü kullanır: yönetici ekranında "gönderilenler"
/// geçmişi (`features/admin/club_message_panel.dart`), kulüp tarafında onay
/// bekleme ekranındaki gelen kutusu (`features/club/club_pending_screen.dart`).
/// Web'de de tek bir işlev iki sayfaya çiziyordu
/// (`js/modules/admin/club-messages.js`).
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';

class AdminMessageLog extends StatelessWidget {
  const AdminMessageLog({
    required this.messages,
    this.emptyLabelKey = 'admin.message.none',
    this.titleKey = 'admin.message.logTitle',
    super.key,
  });

  /// En yenisi başta sıralanmış notlar (bkz. [asAdminMessages]).
  final List<AdminMessage> messages;

  /// Liste boşken gösterilecek metnin anahtarı. Boş dize verilirse hiçbir
  /// şey çizilmez — kulüp tarafında "mesaj yok" demeye gerek yok, bölümün
  /// kendisi gizleniyor.
  final String emptyLabelKey;

  /// Boş dize verilirse başlık çizilmez.
  final String titleKey;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      if (emptyLabelKey.isEmpty) return const SizedBox.shrink();
      return Text(
        context.t(emptyLabelKey),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (titleKey.isNotEmpty) ...<Widget>[
          Text(
            context.t(titleKey),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        for (final AdminMessage entry in messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.subtleFill,
                borderRadius: BorderRadius.circular(BrandShape.controlRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    formatDateTime(entry.createdAtMs, locale: context.lang),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: context.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
