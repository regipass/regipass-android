import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../domain/certificate_rules.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/certificate_service.dart';
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
    // İP-9: yeni sistemin belgeleri (event_certificates) aynı listede, üstte.
    final String? uid = ref.watch(currentUidProvider);
    final List<Map<String, Object?>> fresh = uid == null
        ? const <Map<String, Object?>>[]
        : (ref.watch(studentNewCertificatesProvider(uid)).value ?? const <Map<String, Object?>>[]);
    final List<Map<String, Object?>> sortedFresh = List<Map<String, Object?>>.of(fresh)
      ..sort((Map<String, Object?> a, Map<String, Object?> b) =>
          ((b['issuedAtMs'] as num?) ?? 0).compareTo((a['issuedAtMs'] as num?) ?? 0));

    return ReadableScaffold(
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
          if (list.isEmpty && sortedFresh.isEmpty) {
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: sortedFresh.length + list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Text(
                    context.t('studentCertificates.subtitle'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: context.inkMuted,
                    ),
                  ),
                );
              }
              final int i = index - 1;
              return i < sortedFresh.length
                  ? _NewCertificateRow(certificate: sortedFresh[i])
                  : _CertificateRow(certificate: list[i - sortedFresh.length]);
            },
          );
        },
      ),
    );
  }
}

/// Yeni sistemin belgesi (İP-9): indir (sunucu yeniden üretir), LinkedIn'e
/// ekle, doğrulama bağlantısını kopyala, doğrulama sayfasında tam ad izni.
/// Web: js/pages/student-certificates.js#buildNewCertificateRow.
class _NewCertificateRow extends ConsumerStatefulWidget {
  const _NewCertificateRow({required this.certificate});

  final Map<String, Object?> certificate;

  @override
  ConsumerState<_NewCertificateRow> createState() => _NewCertificateRowState();
}

class _NewCertificateRowState extends ConsumerState<_NewCertificateRow> {
  bool _busy = false;

  Map<String, Object?> get _c => widget.certificate;
  Map<Object?, Object?> get _printed =>
      _c['printed'] is Map ? _c['printed'] as Map<Object?, Object?> : const <Object?, Object?>{};
  String get _code => '${_c['code'] ?? ''}';
  String get _eventId => '${_c['eventId'] ?? ''}';

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _reason(Object error) {
    final String key = 'cert.reason.${certificateErrorReason(error)}';
    final String text = context.t(key);
    return text == key ? context.t('cert.reason.generic') : text;
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final CertificateFile file = await ref.read(certificateServiceProvider).download(_eventId);
      if (!mounted) return;
      await openMedia(
        context,
        source: file.path,
        title: '${_printed['eventTitle'] ?? ''}',
        contentType: 'application/pdf',
      );
    } catch (error) {
      if (mounted) _snack(_reason(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkedIn() async {
    final Uri uri = linkedInAddUri(
      code: _code,
      issuedAtMs: ((_c['issuedAtMs'] as num?) ?? 0).toInt(),
      clubName: '${_printed['clubName'] ?? ''}',
      eventTitle: '${_printed['eventTitle'] ?? ''}',
      lang: context.lang,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: certificateVerifyUrl(_code)));
    if (mounted) _snack(context.t('studentCertificates.copied'));
  }

  Future<void> _toggleFullName() async {
    final bool allow = _c['fullNameConsent'] != true;
    try {
      await ref.read(certificateServiceProvider).setFullName(_eventId, allow);
      if (mounted) {
        _snack(context.t(allow ? 'studentCertificates.fullNameOn' : 'studentCertificates.fullNameOff'));
      }
    } catch (error) {
      if (mounted) _snack(_reason(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool revoked = _c['status'] == CertStatus.revoked;
    final int issuedAt = ((_c['issuedAtMs'] as num?) ?? 0).toInt();
    final String club = '${_printed['clubName'] ?? '-'}';
    final String meta = revoked
        ? '$club • ${context.t('studentCertificates.revoked')}'
        : '$club • ${issuedAt > 0 ? formatDeadline(issuedAt, locale: context.lang) : '-'}';
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            key: ValueKey<String>('new-cert-$_code'),
            onTap: revoked ? null : _download,
            leading: Icon(Icons.workspace_premium_outlined,
                color: revoked ? context.inkMuted : BrandColors.red),
            title: Text('${_printed['eventTitle'] ?? context.t('studentCertificates.fallbackTitle')}',
                style: TextStyle(color: revoked ? context.inkMuted : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(meta, style: TextStyle(color: revoked ? BrandColors.danger : null)),
                Text(_code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: context.inkMuted,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
            trailing: revoked
                ? null
                : _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : PopupMenuButton<String>(
                        tooltip: context.t('studentCertificates.menuLabel'),
                        onSelected: (String value) {
                          switch (value) {
                            case 'copy':
                              _copy();
                            case 'fullname':
                              _toggleFullName();
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(value: 'copy', child: Text(context.t('studentCertificates.menu.copyLink'))),
                          CheckedPopupMenuItem<String>(
                            value: 'fullname',
                            checked: _c['fullNameConsent'] == true,
                            child: Text(context.t('studentCertificates.menu.fullName')),
                          ),
                        ],
                      ),
          ),
          // İP-UX: LinkedIn ve indirme menüde saklı değil, her belgede görünür.
          if (!revoked)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey<String>('cert-linkedin-$_code'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A66C2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy ? null : _linkedIn,
                      icon: const _LinkedInGlyph(),
                      label: Text(
                        context.lang == 'en' ? 'Add to LinkedIn' : "LinkedIn'e ekle",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey<String>('cert-download-$_code'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.download_outlined, size: 20),
                      label: Text(context.t('studentCertificates.menu.download')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// LinkedIn "in" işareti (ek paket/varlık gerektirmeden).
class _LinkedInGlyph extends StatelessWidget {
  const _LinkedInGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'in',
        style: TextStyle(
          color: Color(0xFF0A66C2),
          fontWeight: FontWeight.w900,
          fontSize: 13,
          height: 1,
        ),
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
            // İP-G6: organizatörün şablon dosya adı ("sablon-2.pdf") belge adı
            // gibi görünüyordu; şablon adları gösterilmez.
            if (certificate.fileName.isNotEmpty &&
                !RegExp(r'(ş|s)ablon|template|taslak', caseSensitive: false)
                    .hasMatch(certificate.fileName))
              _displayName,
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
