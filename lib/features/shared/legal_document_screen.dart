import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../domain/legal_docs.dart';
import '../../l10n/app_strings.dart';

/// Tam metnini gösteren tam ekran belge görüntüleyicisi — kayıt ekranındaki
/// onay kutucuklarının yanındaki renkli belge adlarına dokununca açılır.
///
/// Belge her zaman seçili uygulama diline göre (TR/EN) gösterilir.
Future<void> openLegalDocument(BuildContext context, LegalDocument doc) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => LegalDocumentScreen(document: doc),
    ),
  );
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  /// Kalın başlık satırlarını yakalayan basit sezgi: "BÖLÜM"/"PART" ile
  /// başlayan satırlar veya "4. Üyelik..." gibi numaralı madde başlıkları.
  static final RegExp _headingPattern = RegExp(
    r'^(BÖLÜM |PART |\d+(\.\d+)?\.\s+\S)',
  );

  bool _isHeading(String line) =>
      line.length < 90 && _headingPattern.hasMatch(line);

  @override
  Widget build(BuildContext context) {
    final String language = context.lang;
    final List<String> paragraphs = document
        .body(language)
        .trim()
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    return ReadableScaffold(
      appBar: AppBar(title: Text(document.title(language))),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: paragraphs.length,
          itemBuilder: (BuildContext context, int index) {
            final String paragraph = paragraphs[index];
            final bool heading = _isHeading(paragraph);
            return Padding(
              padding: EdgeInsets.only(
                bottom: 14,
                top: heading && index != 0 ? 6 : 0,
              ),
              child: SelectableText(
                paragraph,
                style: TextStyle(
                  fontSize: heading ? 14.5 : 13.5,
                  fontWeight: heading ? FontWeight.w700 : FontWeight.normal,
                  height: 1.45,
                  color: heading ? context.ink : context.inkMuted,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
