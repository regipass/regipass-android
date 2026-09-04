import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/firebase_refs.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../shared/common_widgets.dart';
import '../shared/media_viewer.dart';
import 'club_shell.dart';

/// storage.rules sınırı: club_documents/ altına en fazla 5 MB.
const int kMaxClubDocumentBytes = 5 * 1024 * 1024;

/// Kabul edilen türler — storage.rules ile birebir aynı olmalı.
const List<String> kClubDocumentExtensions = <String>[
  'pdf',
  'jpg',
  'jpeg',
  'png',
];

/// club-documents.html + js/pages/club-documents.js karşılığı.
///
/// Her belge seçilir seçilmez sisteme kaydedilir. Dördüncü belge tamamlanınca
/// kulüp otomatik olarak inceleme kuyruğuna alınır.
class ClubDocumentsScreen extends ConsumerStatefulWidget {
  const ClubDocumentsScreen({super.key});

  @override
  ConsumerState<ClubDocumentsScreen> createState() =>
      _ClubDocumentsScreenState();
}

class _ClubDocumentsScreenState extends ConsumerState<ClubDocumentsScreen> {
  /// Seçilen dosyalar: belge türü -> dosya.
  final Map<String, PlatformFile> _selected = <String, PlatformFile>{};

  /// Firestore anlık görüntüsü gelene kadar, az önce kaydedilen belgeyi
  /// ekranda yüklü göstermek için yerel yansıma.
  final Map<String, Map<String, dynamic>> _saved =
      <String, Map<String, dynamic>>{};
  final Set<String> _removed = <String>{};

  bool _uploading = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _pick(String docType) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kClubDocumentExtensions,
      withData: false,
    );

    final PlatformFile? file = result?.files.singleOrNull;
    if (file == null || file.path == null || !mounted) return;

    if (file.size > kMaxClubDocumentBytes) {
      _setFeedback(
        context.t('clubDocuments.feedback.tooLarge'),
        FeedbackTone.error,
      );
      return;
    }

    final String ext = (file.extension ?? '').toLowerCase();
    if (!kClubDocumentExtensions.contains(ext)) {
      _setFeedback(
        context.t('clubDocuments.feedback.invalidType'),
        FeedbackTone.error,
      );
      return;
    }

    await _upload(docType, file);
  }

  /// Seçilen belgeyi açar — "ne yüklemiştim" kontrolü için.
  ///
  /// Görsel de PDF de uygulama içinde açılır; başka bir uygulamaya çıkılmaz.
  Future<void> _preview(String docType) async {
    final PlatformFile? file = _selected[docType];
    final String? path = file?.path;
    if (path == null) return;

    await openMedia(
      context,
      source: path,
      title: file!.name,
      contentType: _contentTypeFor(file.extension ?? ''),
    );
  }

  String _contentTypeFor(String extension) => switch (extension.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };

  /// Sunucudan gelen kayıtla bu ekranda az önce yapılan işlemleri birleştirir.
  Map<String, Map<String, dynamic>> get _existing {
    final Map<String, Map<String, dynamic>> documents =
        <String, Map<String, dynamic>>{
          ...?ref.read(sessionProvider).clubProfile?.documents,
          ..._saved,
        };
    for (final String docType in _removed) {
      documents.remove(docType);
    }
    return documents;
  }

  Future<void> _upload(String docType, PlatformFile file) async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;

    final Map<String, Map<String, dynamic>> existing = _existing;
    setState(() {
      _selected[docType] = file;
      _uploading = true;
      _feedback = null;
    });
    _setFeedback(context.t('clubDocuments.feedback.saving'));

    Reference? storageRef;
    try {
      final String ext = (file.extension ?? 'dat').toLowerCase();
      final String contentType = _contentTypeFor(ext);
      final String path =
          'club_documents/$uid/$docType-${DateTime.now().millisecondsSinceEpoch}.$ext';
      storageRef = fbStorage.ref(path);
      await storageRef.putFile(
        File(file.path!),
        SettableMetadata(contentType: contentType),
      );

      final Map<String, dynamic> document = <String, dynamic>{
        'name': file.name,
        'url': await storageRef.getDownloadURL(),
        'path': path,
        'contentType': contentType,
        'size': file.size,
        'uploadedAt': DateTime.now().millisecondsSinceEpoch,
      };
      final Map<String, dynamic> documents = <String, dynamic>{
        ...existing,
        docType: document,
      };
      await ref
          .read(profileRepositoryProvider)
          .saveClubDocuments(uid, documents);

      // Değiştirilen belgenin eski dosyası artık referanssızdır; yeni kayıt
      // güvenle yazıldıktan sonra depolamadan da kaldırılır.
      final String oldPath = '${existing[docType]?['path'] ?? ''}';
      if (oldPath.isNotEmpty && oldPath != path) {
        try {
          await fbStorage.ref(oldPath).delete();
        } catch (_) {
          // Yeni belge kullanılmaya devam eder; eski nesne sonraki temizlikte
          // kaldırılabilir.
        }
      }

      if (mounted) {
        setState(() {
          _selected.remove(docType);
          _saved[docType] = Map<String, dynamic>.from(document);
          _removed.remove(docType);
        });
        _setFeedback(
          context.t('clubDocuments.feedback.uploaded'),
          FeedbackTone.success,
        );
      }
    } catch (error) {
      // Dosya depolamaya yazıldı ama profil kaydı başarısız olduysa erişimsiz
      // bir nesne bırakma.
      if (storageRef != null) {
        try {
          await storageRef.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      final String message = '$error';
      _setFeedback(
        message.contains('unauthorized')
            ? context.t('clubDocuments.feedback.permissionError')
            : context.t('clubDocuments.feedback.error'),
        FeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(String docType) async {
    // Bir yükleme hatasından sonra dosya yalnızca cihazda seçili kalabilir;
    // henüz sisteme gitmediği için bu durumda yerelden kaldırmak yeterlidir.
    if (_selected.containsKey(docType)) {
      setState(() => _selected.remove(docType));
      return;
    }

    final String? uid = ref.read(sessionProvider).user?.uid;
    final Map<String, Map<String, dynamic>> existing = _existing;
    final Map<String, dynamic>? document = existing[docType];
    if (uid == null || document == null) return;

    setState(() => _uploading = true);
    try {
      final String path = '${document['path'] ?? ''}';
      if (path.isNotEmpty) {
        try {
          await fbStorage.ref(path).delete();
        } on FirebaseException catch (error) {
          // Nesne daha önce silindiyse profil kaydı yine de temizlenmeli.
          if (error.code != 'object-not-found') rethrow;
        }
      }

      final Map<String, dynamic> documents = <String, dynamic>{...existing}
        ..remove(docType);
      await ref
          .read(profileRepositoryProvider)
          .saveClubDocuments(uid, documents);

      if (mounted) {
        setState(() {
          _saved.remove(docType);
          _removed.add(docType);
        });
        _setFeedback(
          context.t('clubDocuments.feedback.deleted'),
          FeedbackTone.success,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _setFeedback(
        context.t('clubDocuments.feedback.deleteError'),
        FeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _logout() async {
    await logout(ref);
  }

  /// Onay bekleme ekranına dönüş.
  ///
  /// Buraya genelde o ekrandaki "Belgeleri Düzenle" düğmesiyle gelinir, o
  /// yüzden önce yığın açılır. Yığın yoksa (ör. oturum değişiminde router
  /// sayfayı yeniden kurmuşsa) doğrudan rotaya gidilir; kullanıcı bu ekranda
  /// mahsur kalmasın.
  void _backToPending() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.clubPending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClubProfile? profile = ref.watch(sessionProvider).clubProfile;
    final String issue = profile?.documentIssue ?? '';

    // Belgeler tamamlanmış ve inceleme sürüyorsa bu ekrana yalnızca düzeltme
    // için gelinmiştir; dönüş yolu görünür olmalı.
    final bool underReview = profile?.clubStatus == ClubStatus.pendingReview;

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('clubDocuments.title'),
        actions: <Widget>[
          TextButton(
            onPressed: _logout,
            child: Text(context.t('common.logout')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            if (underReview) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _uploading ? null : _backToPending,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(context.t('clubDocuments.backToPending')),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              context.t('clubDocuments.subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Yönetici "belge eksik" dediyse gerekçesi burada görünür;
            // kulüp neyi düzelteceğini bilmeden aynı dosyaları yüklemesin.
            if (issue.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandColors.dangerBg,
                  borderRadius: BorderRadius.circular(BrandShape.controlRadius),
                  border: Border.all(
                    color: BrandColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.report_gmailerrorred_outlined,
                          size: 18,
                          color: BrandColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t('clubDocuments.issueTitle'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: BrandColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      issue,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: BrandColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            FeedbackBanner(message: _feedback, tone: _tone),

            for (final String docType in kClubDocTypes) ...<Widget>[
              _DocumentField(
                label: context.t('clubDocuments.doc.$docType.title'),
                description: context.t('clubDocuments.doc.$docType.desc'),
                file: _selected[docType],
                uploaded: _existing[docType],
                enabled: !_uploading,
                onPick: () => _pick(docType),
                onPreview: () => _preview(docType),
                onRemove: () => _remove(docType),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),
            // Web'deki kısmi italik biçim: etiket düz, format listesi italik.
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, color: context.inkMuted),
                children: <InlineSpan>[
                  TextSpan(
                    text: '${context.t('clubDocuments.upload.formatsLabel')} ',
                  ),
                  TextSpan(
                    text: context.t('clubDocuments.upload.formatsList'),
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Text(
              context.t('clubDocuments.notice'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.inkMuted,
              ),
            ),

            if (_uploading) ...<Widget>[
              const SizedBox(height: 20),
              const LinearProgressIndicator(minHeight: 6),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Tek belge alanı: seç / görüntüle / kaldır.
///
/// Üç durumu var:
///   * boş            — henüz belge yok
///   * yüklü          — önceki gönderimden kalmış, dokunulmazsa korunur
///   * yeni seçilmiş  — gönderimde yükleneceklerden biri
///
/// Yönetici "belge eksik" dediğinde eski belgeler silinmiyor; kulüp yalnızca
/// hatalı olanı değiştirsin diye "yüklü" durumu ayrıca gösteriliyor.
class _DocumentField extends StatelessWidget {
  const _DocumentField({
    required this.label,
    required this.description,
    required this.file,
    required this.uploaded,
    required this.enabled,
    required this.onPick,
    required this.onPreview,
    required this.onRemove,
  });

  final String label;
  final String description;
  final PlatformFile? file;

  /// Önceki gönderimden kalan belge kaydı (`name`, `url`, `contentType`).
  final Map<String, dynamic>? uploaded;

  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final PlatformFile? picked = file;
    final bool hasFile = picked != null;
    final bool hasUploaded = !hasFile && uploaded != null;
    final bool ready = hasFile || hasUploaded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(
          color: hasFile
              ? BrandColors.red
              : hasUploaded
              ? BrandColors.success
              : context.hairline,
          width: ready ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            hasFile
                ? Icons.description
                : hasUploaded
                ? Icons.check_circle_outline
                : Icons.upload_file_outlined,
            size: 22,
            color: hasFile
                ? context.brandInk
                : hasUploaded
                ? BrandColors.success
                : context.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: context.inkMuted,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasFile)
                  // Dosya adına dokunmak belgeyi açar — "ne yükledim" kontrolü.
                  InkWell(
                    onTap: onPreview,
                    child: Text(
                      picked.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.brandInk,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else if (hasUploaded)
                  InkWell(
                    onTap: () => openMedia(
                      context,
                      source: '${uploaded!['url'] ?? ''}',
                      title: '${uploaded!['name'] ?? ''}',
                      contentType: '${uploaded!['contentType'] ?? ''}',
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          context.t('clubDocuments.alreadyUploaded'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${uploaded!['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.brandInk,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    context.t('clubDocuments.upload.cta'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (ready)
            Material(
              color: BrandColors.danger,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onRemove : null,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.remove, size: 16, color: BrandColors.white),
                ),
              ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: enabled ? onPick : null,
              child: Text(
                hasUploaded
                    ? context.t('clubDocuments.replace')
                    : context.t('clubDocuments.pick'),
              ),
            ),
        ],
      ),
    );
  }
}
