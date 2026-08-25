import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';

/// js/modules/ui/media-viewer.js karşılığı.
///
/// Yüklenen bir belgeye ya da fotoğrafa dokununca ne yüklendiğini görmek için.
/// **Her şey uygulama içinde açılır:** görseller yakınlaştırılabilir tam ekran
/// görüntüleyicide, PDF'ler gömülü PDF görüntüleyicide. Cihazın başka bir
/// uygulamasına yalnızca hiçbir şekilde çizemediğimiz bir tür gelirse
/// (ör. .docx) düşülür — kulüp belgeleri ve belgeler PDF/JPEG/PNG ile
/// sınırlı olduğu için pratikte bu yola girilmez.
Future<void> openMedia(
  BuildContext context, {
  /// Ağ adresi, `data:` adresi ya da cihazdaki dosya yolu.
  required String source,
  String? title,

  /// Bilinmiyorsa uzantıdan/başlıktan çıkarılır.
  String? contentType,
}) async {
  if (_looksLikeImage(source, contentType)) {
    final ImageProvider<Object>? provider = _imageProviderFor(source);
    if (provider != null) {
      await showDialog<void>(
        context: context,
        barrierColor: BrandColors.blackDeep.withValues(alpha: 0.92),
        builder: (BuildContext dialogContext) =>
            _ImageViewer(image: provider, title: title),
      );
      return;
    }
  }

  if (_looksLikePdf(source, contentType)) {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PdfViewerPage(source: source, title: title),
      ),
    );
    return;
  }

  // Çizemediğimiz tür: son çare olarak cihazın uygulamasına devredilir.
  final Uri? uri = _uriFor(source);
  if (uri == null) {
    if (context.mounted) _toast(context);
    return;
  }

  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) _toast(context);
  } catch (_) {
    if (context.mounted) _toast(context);
  }
}

void _toast(BuildContext context) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(context.t('media.openError'))));

bool _looksLikeImage(String source, String? contentType) {
  if (contentType != null && contentType.isNotEmpty) {
    return contentType.startsWith('image/');
  }
  if (source.startsWith('data:image/')) return true;

  // Sorgu dizesi (Storage imzaları) uzantıyı gölgelemesin.
  final String path = _pathOf(source);
  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif');
}

bool _looksLikePdf(String source, String? contentType) {
  if (contentType != null && contentType.isNotEmpty) {
    return contentType.contains('pdf');
  }
  if (source.startsWith('data:application/pdf')) return true;
  return _pathOf(source).endsWith('.pdf');
}

/// Adresin uzantı taşıyan kısmı (küçük harfe indirgenmiş).
///
/// Storage indirme adreslerinde dosya adı `%2F` ile kaçırılmış yol içinde
/// duruyor; çözülmeden bakılırsa `.pdf` uzantısı görülmüyordu.
String _pathOf(String source) {
  final String path = Uri.tryParse(source)?.path ?? source;
  try {
    return Uri.decodeComponent(path).toLowerCase();
  } catch (_) {
    return path.toLowerCase();
  }
}

ImageProvider<Object>? _imageProviderFor(String source) {
  final Uint8List? inlineBytes = _dataUrlBytes(source);
  if (inlineBytes != null) return MemoryImage(inlineBytes);
  if (source.startsWith('data:')) return null;

  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }

  // Cihazdaki dosya (henüz yüklenmemiş seçim).
  final File file = File(source);
  return file.existsSync() ? FileImage(file) : null;
}

Uint8List? _dataUrlBytes(String source) {
  if (!source.startsWith('data:')) return null;

  final int comma = source.indexOf(',');
  if (comma < 0 || !source.substring(0, comma).contains('base64')) return null;

  try {
    return base64Decode(source.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

Uri? _uriFor(String source) {
  if (source.startsWith('http://') ||
      source.startsWith('https://') ||
      source.startsWith('data:')) {
    return Uri.tryParse(source);
  }
  return File(source).existsSync() ? Uri.file(source) : null;
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.image, this.title});

  final ImageProvider<Object> image;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Image(
                  image: image,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, _, _) => Center(
                    child: Text(
                      context.t('media.openError'),
                      style: const TextStyle(color: BrandColors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Başlık + kapatma, görselin üstünde yüzer.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BrandColors.white,
                          fontWeight: FontWeight.w600,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: BrandColors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uygulama içi PDF görüntüleyici.
///
/// Ağdaki belge önce belleğe indirilir: `pdfx` yalnızca yerel dosya ya da bayt
/// dizisi açabiliyor. Sayfalar arasında kaydırılır, iki parmakla
/// yakınlaştırılır — cihazın PDF uygulamasına çıkmaya gerek kalmaz.
class _PdfViewerPage extends StatefulWidget {
  const _PdfViewerPage({required this.source, this.title});

  final String source;
  final String? title;

  @override
  State<_PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<_PdfViewerPage> {
  PdfControllerPinch? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Future<PdfDocument> document = _openDocument();
      // Belge açılamıyorsa (bozuk dosya, ağ hatası) hatayı burada yakalayıp
      // görüntüleyici yerine anlaşılır bir mesaj gösteriyoruz.
      await document;
      if (!mounted) return;

      setState(() => _controller = PdfControllerPinch(document: document));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<PdfDocument> _openDocument() async {
    final String source = widget.source;

    final Uint8List? inline = _dataUrlBytes(source);
    if (inline != null) return PdfDocument.openData(inline);

    if (source.startsWith('http://') || source.startsWith('https://')) {
      final http.Response response = await http
          .get(Uri.parse(source))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('${response.statusCode}');
      }
      return PdfDocument.openData(response.bodyBytes);
    }

    return PdfDocument.openFile(source);
  }

  @override
  Widget build(BuildContext context) {
    final PdfControllerPinch? controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title?.isNotEmpty == true
              ? widget.title!
              : context.t('media.documentTitle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (controller != null)
            // Sayfa göstergesi: çok sayfalı belgelerde nerede olduğunu söyler.
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: controller.pageListenable,
                  builder: (BuildContext context, int page, _) => Text(
                    '$page / ${controller.pagesCount ?? 1}',
                    style: TextStyle(fontSize: 13, color: context.inkMuted),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.t('media.openError'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.inkMuted),
                ),
              ),
            )
          : controller == null
          ? const Center(child: CircularProgressIndicator())
          : PdfViewPinch(
              controller: controller,
              backgroundDecoration: BoxDecoration(color: context.canvas),
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                pageLoaderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder: (BuildContext context, Exception error) => Center(
                  child: Text(
                    context.t('media.openError'),
                    style: TextStyle(color: context.inkMuted),
                  ),
                ),
              ),
            ),
    );
  }
}
