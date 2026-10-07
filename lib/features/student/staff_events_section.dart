/// İP-GR (mobil 1.0.13): Profilim > "Görevli olduğum etkinlikler".
/// Organizatör bu hesabı görevli eklediyse görünür; "Kapıda okut" kapı
/// ekranını görevli modunda açar (giriş organizatör adına, görevlinin uid'iyle).
/// Web: gorevli.html (js/pages/staff-events.js).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../services/staff_service.dart';
import '../../state/providers.dart';

final FutureProvider<List<StaffEvent>> myStaffEventsProvider =
    FutureProvider.autoDispose<List<StaffEvent>>((Ref ref) async {
  if (ref.watch(currentUidProvider) == null) return const <StaffEvent>[];
  try {
    return await const StaffService().myStaffEvents();
  } catch (_) {
    return const <StaffEvent>[];
  }
});

class StaffEventsSection extends ConsumerWidget {
  const StaffEventsSection({super.key});

  String _day(BuildContext context, int ms) {
    if (ms <= 0) return '';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<StaffEvent> events = ref.watch(myStaffEventsProvider).value ?? const <StaffEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        key: const Key('staffEventsSection'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(context.t('staff.page.heading'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(context.t('staff.page.help'), style: TextStyle(fontSize: 13, height: 1.4, color: context.inkMuted)),
          const SizedBox(height: 10),
          for (final StaffEvent e in events)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(context.t('staff.role.${e.role}'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BrandColors.red)),
                    const SizedBox(height: 2),
                    Text(e.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        e.clubName,
                        _day(context, e.eventDateAtMs),
                        if (e.eventStartTime.isNotEmpty) e.eventStartTime,
                        if (e.online) 'Online' else if (e.locationName.isNotEmpty) e.locationName,
                      ].where((String x) => x.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 13, color: context.inkMuted),
                    ),
                    if (!e.online) ...<Widget>[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push(
                          '${Routes.studentStaffScan}?eventId=${Uri.encodeComponent(e.eventId)}&clubId=${Uri.encodeComponent(e.clubId)}',
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(context.t('staff.scan')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
