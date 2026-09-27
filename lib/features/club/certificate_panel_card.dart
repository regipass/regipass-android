/// Kulüp > etkinlik detayı: yeni sertifika paneli (İP-8).
///
/// Web: js/modules/certificates/cert-panel.js. Mobilde editör ve şablon
/// yükleme YOK (karar: Arda, 27 Eylül): belge webde kaydedilir. Burada
/// kaydedilen belgenin örneği, yüzde eşiği, Gönder, Tüm gönderimi geri al,
/// eski sürüm uyarısı ve gönderilenler var. Web'e BAĞLANTI yok (Apple);
/// belge ayarlanmamışsa yalnızca tıklanmayan bir bilgi yazısı gösterilir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/certificate_rules.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/certificate_service.dart';
import '../shared/common_widgets.dart';
import '../shared/media_viewer.dart';

class CertificatePanelCard extends ConsumerStatefulWidget {
  const CertificatePanelCard({
    required this.event,
    required this.registrations,
    super.key,
  });

  final AppEvent event;
  final List<EventRegistration> registrations;

  @override
  ConsumerState<CertificatePanelCard> createState() => _CertificatePanelCardState();
}

class _CertificatePanelCardState extends ConsumerState<CertificatePanelCard> {
  String _busy = '';
  int? _threshold;
  bool _thresholdDirty = false;
  bool _showList = false;

  String _reason(String reason) {
    final String key = 'cert.reason.$reason';
    final String text = context.t(key);
    return text == key ? context.t('cert.reason.generic') : text;
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<bool> _confirm(String title, String message, String yes) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(c.t('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
            child: Text(yes),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(String kind, Future<void> Function() action) async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy = kind);
    try {
      await action();
    } catch (error) {
      if (mounted) _snack(_reason(certificateErrorReason(error)));
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _send({bool outdated = false}) => _run(outdated ? 'reissue' : 'send', () async {
    final Map<String, Object?> r = await ref
        .read(certificateServiceProvider)
        .send(widget.event.id, outdated: outdated);
    if (!mounted) return;
    final int sent = (r['sent'] as num?)?.toInt() ?? 0;
    final int failed = (r['failed'] as num?)?.toInt() ?? 0;
    _snack(failed > 0
        ? context.t('cert.toast.sentWithErrors', <String, Object?>{'sent': sent, 'failed': failed})
        : context.t('cert.toast.sent', <String, Object?>{'sent': sent}));
  });

  Future<void> _revoke() async {
    final bool ok = await _confirm(
      context.t('cert.revoke.title'),
      context.t('cert.revoke.text'),
      context.t('cert.revoke.yes'),
    );
    if (!ok || !mounted) return;
    await _run('revoke', () async {
      final Map<String, Object?> r = await ref.read(certificateServiceProvider).revoke(widget.event.id);
      if (mounted) {
        _snack(context.t('cert.toast.revoked', <String, Object?>{'n': (r['revoked'] as num?)?.toInt() ?? 0}));
      }
    });
  }

  Future<void> _preview() => _run('preview', () async {
    final String sample = widget.registrations.isNotEmpty
        ? _nameOf(widget.registrations.first)
        : context.t('cert.editor.sampleName');
    final CertificateFile file = await ref.read(certificateServiceProvider).preview(widget.event.id, sample);
    if (!mounted) return;
    await openMedia(context, source: file.path, title: context.t('cert.mobile.preview'), contentType: 'application/pdf');
  });

  Future<void> _open(String studentId, String name) => _run('open:$studentId', () async {
    final CertificateFile file = await ref
        .read(certificateServiceProvider)
        .download(widget.event.id, studentId: studentId);
    if (!mounted) return;
    await openMedia(context, source: file.path, title: name, contentType: 'application/pdf');
  });

  Future<void> _saveThreshold() => _run('threshold', () async {
    await ref.read(certificateServiceProvider).setThreshold(widget.event.id, _threshold);
    if (!mounted) return;
    setState(() => _thresholdDirty = false);
    _snack(context.t('cert.threshold.saved'));
  });

  static String _nameOf(EventRegistration r) {
    final String full = '${r.studentFirstName} ${r.studentLastName}'.trim();
    return full.isNotEmpty ? full : (r.studentName.isNotEmpty ? r.studentName : r.studentEmail);
  }

  Widget _box({required Widget child, Color? color, Color? border}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color ?? context.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border ?? context.hairline),
    ),
    child: child,
  );

  Widget _stat(String value, String label, {bool accent = false}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: context.subtleFill, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent ? BrandColors.red : context.ink,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              )),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.inkMuted)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppEvent event = widget.event;
    final AsyncValue<Map<String, Object?>?> configAsync = ref.watch(certificateConfigProvider(event.id));
    final Map<String, Map<String, Object?>> certs =
        ref.watch(clubEventCertificatesProvider('${event.clubId}|${event.id}')).value ??
            const <String, Map<String, Object?>>{};
    final List<Map<String, Object?>> issues = ref.watch(certificateIssuesProvider(event.id)).value ??
        const <Map<String, Object?>>[];

    if (configAsync.isLoading && !configAsync.hasValue) {
      return _box(child: Text(context.t('cert.panel.loading'), style: TextStyle(color: context.inkMuted)));
    }
    final Map<String, Object?>? config = configAsync.value;
    final bool saved = config != null && config['status'] == 'saved' && ((config['version'] as num?) ?? 0) > 0;
    final int? savedThreshold = resolveCertificateThreshold(config?['thresholdPercent'], event);
    final int? threshold = _thresholdDirty ? _threshold : savedThreshold;
    final int version = ((config?['version'] as num?) ?? 0).toInt();
    final CertSummary s = summarizeCertificates(event, widget.registrations, threshold, certs, configVersion: version);
    final SendGate gate = certificateSendGate(event);

    // Belge webde ayarlanmamış: yalnızca bilgi (tıklanmaz).
    if (!saved) {
      return _box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              Icon(Icons.desktop_windows_outlined, size: 20, color: context.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.t('cert.mobile.webOnly'),
                    key: const ValueKey<String>('cert-web-only'),
                    style: TextStyle(fontSize: 13.5, height: 1.45, color: context.ink)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: <Widget>[
              _stat('${s.eligible}', context.t('cert.stat.eligible')),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: null, child: Text(context.t('cert.mobile.send'))),
            ),
          ],
        ),
      );
    }

    final Map<String, Object?>? running = config['running'] is Map
        ? Map<String, Object?>.from(config['running'] as Map)
        : null;
    final bool isRunning = running != null &&
        DateTime.now().millisecondsSinceEpoch - ((running['startedAtMs'] as num?) ?? 0) < 15 * 60 * 1000;
    final Map<String, Object?>? runIssue = isRunning
        ? issues.cast<Map<String, Object?>?>().firstWhere((Map<String, Object?>? i) => i?['id'] == running['issueId'], orElse: () => null)
        : null;
    final bool locked = _busy.isNotEmpty || isRunning;
    final String sendLabel = s.sent > 0
        ? (s.pending > 0
            ? context.t('cert.panel.sendNew', <String, Object?>{'n': s.pending})
            : context.t('cert.panel.allSent'))
        : context.t('cert.panel.sendN', <String, Object?>{'n': s.pending});

    final List<Widget> children = <Widget>[];

    if (s.outdated > 0) {
      children.addAll(<Widget>[
        _box(
          color: const Color(0xFFFFF3DC),
          border: const Color(0xFFF2D9A6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(context.t('cert.panel.outdated', <String, Object?>{'n': s.outdated}),
                style: const TextStyle(color: Color(0xFF7A4E00), fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: locked || !gate.open ? null : () => _send(outdated: true),
              child: Text(context.t('cert.panel.reissue')),
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ]);
    }

    children.addAll(<Widget>[
      Row(children: <Widget>[
        _stat('${s.eligible}', context.t('cert.stat.eligible')),
        const SizedBox(width: 6),
        _stat('${s.sent}', context.t('cert.stat.sent'), accent: true),
        const SizedBox(width: 6),
        _stat('${s.pending}', context.t('cert.stat.pending')),
        const SizedBox(width: 6),
        _stat('${s.revoked}', context.t('cert.stat.revoked')),
      ]),
      const SizedBox(height: 10),
      _box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: gate.open ? BrandColors.successBg : const Color(0xFFFFF3DC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              gate.open ? context.t('cert.gate.open') : _reason(gate.reason ?? 'generic'),
              key: const ValueKey<String>('cert-gate'),
              style: TextStyle(fontSize: 13, color: gate.open ? BrandColors.success : const Color(0xFF7A4E00)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey<String>('cert-send'),
            onPressed: !gate.open || s.pending == 0 || locked ? null : _send,
            child: _busy == 'send'
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(sendLabel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey<String>('cert-revoke'),
            onPressed: s.sent == 0 || locked ? null : _revoke,
            style: OutlinedButton.styleFrom(foregroundColor: BrandColors.danger),
            child: Text(context.t('cert.panel.revokeAll')),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: locked ? null : _preview,
            icon: _busy == 'preview'
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.visibility_outlined, size: 18),
            label: Text(context.t('cert.mobile.preview')),
          ),
          if (isRunning) ...<Widget>[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: runIssue != null && ((runIssue['total'] as num?) ?? 0) > 0
                  ? ((runIssue['done'] as num?) ?? 0) / (runIssue['total'] as num)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              running['kind'] == 'revoke'
                  ? context.t('cert.panel.revoking')
                  : context.t('cert.panel.sending', <String, Object?>{
                      'done': (runIssue?['done'] as num?)?.toInt() ?? 0,
                      'total': (runIssue?['total'] as num?)?.toInt() ?? 0,
                    }),
              style: TextStyle(fontSize: 12, color: context.inkMuted),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.t('cert.mobile.editOnWeb'),
                style: TextStyle(fontSize: 12, color: context.inkMuted, height: 1.4)),
          ),
        ]),
      ),
    ]);

    // Yüzde eşiği (yalnızca yoklamalı modlar)
    if (event.isMultiSession) {
      final int value = threshold ?? 0;
      children.addAll(<Widget>[
        const SizedBox(height: 10),
        _box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(context.t('cert.threshold.title'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Slider.adaptive(
              value: value.toDouble(),
              max: 100,
              divisions: 20,
              label: '%$value',
              onChanged: locked
                  ? null
                  : (double v) => setState(() {
                        _threshold = v.round() == 0 ? null : v.round();
                        _thresholdDirty = true;
                      }),
            ),
            Text(
              threshold == null
                  ? context.t('cert.threshold.none', <String, Object?>{'n': s.eligible})
                  : context.t('cert.threshold.result', <String, Object?>{'p': threshold, 'n': s.eligible}),
              key: const ValueKey<String>('cert-threshold-result'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_thresholdDirty) ...<Widget>[
              const SizedBox(height: 8),
              Row(children: <Widget>[
                FilledButton(onPressed: locked ? null : _saveThreshold, child: Text(context.t('cert.threshold.save'))),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _thresholdDirty = false;
                    _threshold = null;
                  }),
                  child: Text(context.t('common.cancel')),
                ),
              ]),
            ],
          ]),
        ),
      ]);
    }

    // Gönderilenler (açılır liste)
    final List<MapEntry<String, Map<String, Object?>>> sentList = certs.entries
        .where((MapEntry<String, Map<String, Object?>> e) => e.value['status'] != null)
        .toList()
      ..sort((MapEntry<String, Map<String, Object?>> a, MapEntry<String, Map<String, Object?>> b) =>
          _certName(a.value).compareTo(_certName(b.value)));
    if (sentList.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: 10),
        _box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            InkWell(
              onTap: () => setState(() => _showList = !_showList),
              child: Row(children: <Widget>[
                Expanded(
                  child: Text(context.t('cert.list.title'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                StatusPill(label: '${sentList.length}'),
                Icon(_showList ? Icons.expand_less : Icons.expand_more),
              ]),
            ),
            if (_showList)
              for (final MapEntry<String, Map<String, Object?>> e in sentList)
                _CertRow(
                  name: _certName(e.value, fallback: _registrationName(e.key)),
                  status: '${e.value['status']}',
                  reason: '${e.value['reason'] ?? ''}',
                  busy: _busy == 'open:${e.key}',
                  onOpen: e.value['status'] == CertStatus.issued && !locked
                      ? () => _open(e.key, _certName(e.value, fallback: _registrationName(e.key)))
                      : null,
                  reasonText: _reason,
                ),
          ]),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  String _registrationName(String studentId) {
    for (final EventRegistration r in widget.registrations) {
      if (r.studentId == studentId) return _nameOf(r);
    }
    return '—';
  }

  static String _certName(Map<String, Object?> c, {String fallback = ''}) {
    final Object? printed = c['printed'];
    if (printed is Map && '${printed['studentName'] ?? ''}'.isNotEmpty) return '${printed['studentName']}';
    return fallback;
  }
}

class _CertRow extends StatelessWidget {
  const _CertRow({
    required this.name,
    required this.status,
    required this.reason,
    required this.busy,
    required this.onOpen,
    required this.reasonText,
  });

  final String name;
  final String status;
  final String reason;
  final bool busy;
  final VoidCallback? onOpen;
  final String Function(String) reasonText;

  @override
  Widget build(BuildContext context) {
    final (String label, FeedbackTone tone) = switch (status) {
      CertStatus.issued => (context.t('cert.status.sent'), FeedbackTone.success),
      CertStatus.revoked => (context.t('cert.status.revoked'), FeedbackTone.error),
      _ => ('${context.t('cert.status.failed')}: ${reasonText(reason)}', FeedbackTone.warning),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: <Widget>[
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Flexible(child: StatusPill(label: label, tone: tone)),
        if (onOpen != null || busy)
          IconButton(
            tooltip: context.t('cert.list.open'),
            onPressed: onOpen,
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
      ]),
    );
  }
}
