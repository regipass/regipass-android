import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../shared/common_widgets.dart';
import 'club_providers.dart';
import 'club_shell.dart';

/// Katılımcıların web'deki tablo düzeniyle görünümü
/// (club-events.js#renderStudentsTable).
///
/// Etkinlik ekranındaki kart listesi telefonda okumak için daha rahat, ama
/// kulüpler listeyi web'de olduğu gibi sütun sütun karşılaştırmak istiyor.
/// Bu yüzden aynı veri iki biçimde de sunuluyor; buradaki tablo yatay
/// kaydırılır çünkü altı sütun hiçbir telefon genişliğine sığmaz.
///
/// Kayıtlar canlı dinlenir: QR başka bir cihazdan okutulduğunda tablo
/// kendiliğinden güncellenir.
class ClubRegistrationsTableScreen extends ConsumerWidget {
  const ClubRegistrationsTableScreen({required this.event, super.key});

  final AppEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EventRegistration>> registrations =
        ref.watch(eventRegistrationsProvider(event.id));

    final List<EventRegistration> list =
        registrations.value ?? const <EventRegistration>[];

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('clubEvents.students.title'),
        subtitle: event.title,
        showBack: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: StatusPill(label: '${list.length}')),
          ),
        ],
      ),
      body: registrations.isLoading && list.isEmpty
          ? const LoadingView()
          : list.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                EmptyState(
                  message: context.t('clubEvents.students.empty'),
                  icon: Icons.person_off_outlined,
                ),
              ],
            )
          : _Table(event: event, registrations: list),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.event, required this.registrations});

  final AppEvent event;
  final List<EventRegistration> registrations;

  @override
  Widget build(BuildContext context) {
    final int? threshold = event.certificateThresholdPercent;

    // Web'de tablo dikey akışın içinde; mobilde iki eksende de kaydırılabilir
    // olması gerekiyor, bu yüzden dikey kaydırıcının içine yatay bir kaydırıcı
    // yerleşiyor.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll<Color>(context.subtleFill),
          headingTextStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
          dataTextStyle: TextStyle(fontSize: 12.5, color: context.ink),
          columnSpacing: 26,
          headingRowHeight: 44,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 56,
          border: TableBorder(
            horizontalInside: BorderSide(color: context.hairline),
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          ),
          columns: <DataColumn>[
            DataColumn(label: Text(context.t('table.fullName'))),
            DataColumn(label: Text(context.t('table.email'))),
            DataColumn(label: Text(context.t('table.phone'))),
            DataColumn(label: Text(context.t('table.university'))),
            DataColumn(label: Text(context.t('table.department'))),
            DataColumn(label: Text(context.t('table.registrationDate'))),
            // Oturum sütunu web'de de yalnızca çok oturumlu etkinliklerde
            // görünür (sessionColumnHeader.hidden).
            if (event.isMultiSession)
              DataColumn(label: Text(context.t('table.sessions'))),
          ],
          rows: <DataRow>[
            for (final EventRegistration reg in registrations)
              DataRow(
                // Girişi onaylanan satır web'de de vurgulanıyor (.checked-in).
                color: reg.isCheckedIn
                    ? WidgetStatePropertyAll<Color>(
                        BrandColors.success.withValues(alpha: 0.08),
                      )
                    : null,
                cells: <DataCell>[
                  DataCell(Text(reg.displayName)),
                  DataCell(Text(_orDash(reg.studentEmail))),
                  DataCell(Text(_orDash(reg.studentPhone))),
                  DataCell(Text(_orDash(reg.studentUniversity))),
                  DataCell(Text(_orDash(reg.studentDepartment))),
                  DataCell(
                    Text(
                      <String>[
                        formatDateTime(
                          reg.registeredAtMs,
                          locale: context.lang,
                        ),
                        if (reg.isCheckedIn)
                          context.t('clubEvents.students.checkedIn'),
                      ].join(' | '),
                    ),
                  ),
                  if (event.isMultiSession)
                    DataCell(
                      Text(
                        <String>[
                          '${reg.sessionsAttended}/${event.sessionCount}',
                          if (threshold != null &&
                              (reg.sessionsAttended / event.sessionCount) *
                                      100 >=
                                  threshold)
                            '✓ ${context.t('clubEvents.students.certificateEarned')}',
                        ].join(' | '),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _orDash(String value) => value.isEmpty ? '-' : value;
}
