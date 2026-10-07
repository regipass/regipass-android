/// İP-P1 (mobil 1.0.13): paket kilidi notu ve "Paketim" kartı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/plans.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import 'common_widgets.dart';

/// "… Kulüp Pro paketinde" notu (özellik pakete kapalıysa).
class PlanLockNote extends StatelessWidget {
  const PlanLockNote({super.key, required this.feature});

  final String feature;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline, size: 18, color: context.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t('plan.lock.text', <String, Object?>{
                'feature': context.t('plan.feature.$feature'),
              }),
              style: TextStyle(fontSize: 13.5, height: 1.4, color: context.inkMuted),
            ),
          ),
        ],
      );
}

String _date(BuildContext context, int ms) {
  if (ms <= 0) return '';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Organizatör hesabında "Paketim" kartı (paket sistemi kapalıysa görünmez).
class PlanSummaryCard extends ConsumerWidget {
  const PlanSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlanSummary? s = ref.watch(myPlanProvider).value;
    if (s == null || !s.enabled) return const SizedBox.shrink();
    final List<String> lines = <String>[];
    if (s.isCompany) {
      lines.add(context.t(s.usableCredits > 0 ? 'plan.company.hasCredits' : 'plan.company.noCredits',
          <String, Object?>{'n': s.usableCredits}));
    } else if (s.isStarter) {
      lines.add(context.t(s.canCreateEvent ? 'plan.card.freeHelp' : 'plan.card.freeUsed', <String, Object?>{
        'left': s.freeLeft,
        'date': _date(context, s.resetAtMs),
      }));
    } else {
      if (s.institutionName.isNotEmpty) {
        lines.add(context.t('plan.card.institution', <String, Object?>{'name': s.institutionName}));
      }
      lines.add(s.endsAtMs > 0
          ? context.t('plan.card.ends', <String, Object?>{'date': _date(context, s.endsAtMs)})
          : context.t('plan.card.noEnd'));
      lines.add(context.t('plan.card.eventsUnlimited'));
    }
    if (s.maxCapacity > 0) {
      lines.add(context.t('plan.card.capacity', <String, Object?>{'n': s.maxCapacity}));
    }
    final String badge = s.isCompany ? context.t('plan.company.badge') : context.t('plan.name.${s.tier}');
    return SectionCard(
      title: context.t('plan.card.title'),
      icon: Icons.workspace_premium_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1D3557).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D3557))),
          ),
          const SizedBox(height: 8),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line, style: TextStyle(fontSize: 13.5, height: 1.4, color: context.inkMuted)),
            ),
          if (s.isStarter || s.isCompany) ...<Widget>[
            const SizedBox(height: 8),
            Text('${context.t('plan.card.upgrade')} product@regipass.com',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
