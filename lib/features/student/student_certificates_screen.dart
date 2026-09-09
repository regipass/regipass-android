import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/media_viewer.dart';
import 'student_providers.dart';
import 'student_shell.dart';

/// student-certificates.html + js/pages/student-certificates.js karşılığı.
///
/// Belge indirme web'de blob olarak yapılıyordu; mobilde dosya sistem
/// tarayıcısına devredilir (harici uygulamada açılır/indirilir).
class StudentCertificatesScreen extends ConsumerWidget {
  const StudentCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StudentCertificate>> certificates =
        ref.watch(studentCertificatesProvider);

    return Scaffold(
      appBar: StudentAppBar(title: context.t('studentCertificates.title')),
      body: certificates.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('studentCertificates.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<StudentCertificate> list) {
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                EmptyState(
                  message: context.t('studentCertificates.empty'),
                  icon: Icons.workspace_premium_outlined,
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) =>
                _CertificateRow(certificate: list[index]),
          );
        },
      ),
    );
  }
}

class _CertificateRow extends ConsumerWidget {
  const _CertificateRow({required this.certificate});

  final StudentCertificate certificate;

  /// Belgenin öğrenciye gösterilen adı.
  ///
  /// Dosya adları neredeyse her zaman "katilim-belgesi.pdf" gibi tireli
  /// geliyor; başlıkta tire kelimelerin arasında okumayı zorlaştırdığı için
  /// boşluğa çevrilir. Dosyanın kendi adı değişmez, yalnızca gösterim.
  String get _displayName {
    final String raw = certificate.fileName.isNotEmpty
        ? certificate.fileName
        : certificate.eventTitle;

    return raw.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Belgeyi uygulama içinde görüntüler (görsel ve PDF).
  Future<void> _open(BuildContext context) => openMedia(
        context,
        source: certificate.fileUrl,
        title: _displayName,
        contentType: certificate.contentType,
      );

  /// Belgeyi indirir: web'de `<a download>` ile doğrudan indiriliyordu,
  /// mobilde eşdeğeri yok — dosya geçici dizine yazılıp paylaşım sayfası
  /// açılır (kullanıcı "Dosyalar"a kaydedebilir). Önceden burada yanlışlıkla
  /// görüntüleyici açılıyordu; "İndir" bir kayıt/dışa aktarma işlemi olmalı.
  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin =
        box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      final http.Response response =
          await http.get(Uri.parse(certificate.fileUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('${response.statusCode}');
      }

      final String name =
          certificate.fileName.isNotEmpty ? certificate.fileName : '$_displayName.pdf';
      final Directory directory = await getTemporaryDirectory();
      final File file = File('${directory.path}/$name');
      await file.writeAsBytes(response.bodyBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(
              file.path,
              mimeType: certificate.contentType.isNotEmpty ? certificate.contentType : null,
            ),
          ],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('studentCertificates.feedback.downloadError')),
          ),
        );
      }
    }
  }

  /// Belgenin bağlantısını hızlıca paylaşır (indirmeden) — sohbete/e-postaya
  /// yapıştırmak gibi hafif kullanımlar için.
  Future<void> _share(BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin =
        box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.tryParse(certificate.fileUrl),
          subject: _displayName,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('studentCertificates.feedback.shareError')),
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(dialogContext.t('studentCertificates.deleteConfirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dialogContext.t('studentCertificates.menu.delete'),
              style: const TextStyle(color: BrandColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(eventRepositoryProvider).deleteCertificate(certificate.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('studentCertificates.feedback.deleteError')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: BrandColors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.workspace_premium_outlined, color: BrandColors.red),
        ),
        title: Text(
          certificate.eventTitle.isNotEmpty ? certificate.eventTitle : 'Belge',
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Belgenin adı da yazılır: kulüp aynı etkinliğe birden fazla belge
        // yükleyebiliyor (katılım + başarı gibi) ve yalnızca etkinlik adıyla
        // iki satır birbirinden ayırt edilemiyordu.
        subtitle: Text(
          <String>[
            if (certificate.fileName.isNotEmpty) _displayName,
            certificate.clubName.isNotEmpty ? certificate.clubName : '-',
            formatDeadline(certificate.issuedAtMs, locale: context.lang),
          ].join(' • '),
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _open(context),
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'download') _download(context, ref);
            if (value == 'share') _share(context);
            if (value == 'delete') _delete(context, ref);
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'download',
              child: Row(
                children: <Widget>[
                  const Icon(Icons.download_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(context.t('studentCertificates.menu.download')),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: <Widget>[
                  const Icon(Icons.ios_share_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(context.t('studentCertificates.menu.share')),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: <Widget>[
                  const Icon(Icons.delete_outline,
                      size: 18, color: BrandColors.danger),
                  const SizedBox(width: 10),
                  Text(
                    context.t('studentCertificates.menu.delete'),
                    style: const TextStyle(color: BrandColors.danger),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
