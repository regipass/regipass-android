/// Kulüp > etkinlik detayı: "Rapor indir (PDF / Excel)" (İP-R).
/// Web: js/modules/report/report-download.js#mountReportBlock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/event_report_service.dart';

class EventReportCard extends ConsumerStatefulWidget {
  const EventReportCard({required this.event, super.key});

  final AppEvent event;

  @override
  ConsumerState<EventReportCard> createState() => _EventReportCardState();
}

class _EventReportCardState extends ConsumerState<EventReportCard> {
  ReportFormat? _busy;

  Future<void> _download(ReportFormat format) async {
    if (_busy != null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String lang = context.lang;
    final String subject =
        '${context.t('report.title')} — ${widget.event.title}';
    final String done = context.t('report.done');
    final String failed = context.t('report.error');
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() => _busy = format);
    try {
      final EventReportService service = ref.read(eventReportServiceProvider);
      final ReportFile file = await service.fetch(
        widget.event.id,
        format,
        lang: lang,
      );
      await service.share(file, subject: subject, sharePositionOrigin: origin);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget button(ReportFormat format, IconData icon, String label) => Expanded(
      child: OutlinedButton.icon(
        key: ValueKey<String>('report-${format.name}'),
        onPressed: _busy == null ? () => _download(format) : null,
        icon: _busy == format
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );

    return Container(
      key: const ValueKey<String>('event-report-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t('report.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('report.help'),
            style: TextStyle(
              fontSize: 12.5,
              color: context.inkMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              button(
                ReportFormat.pdf,
                Icons.picture_as_pdf_outlined,
                context.t('report.pdf'),
              ),
              const SizedBox(width: 10),
              button(
                ReportFormat.xls,
                Icons.table_chart_outlined,
                context.t('report.excel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
