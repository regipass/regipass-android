import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import 'student_providers.dart';

/// student-appointments.js / student-qr-generate.js içindeki detay
/// penceresinin karşılığı: etkinlik bilgisi + oturum ilerlemesi + QR üretimi.
///
/// [autoGenerateQr] true ise (QR Oluştur sekmesinden gelindiğinde) pencere
/// açılır açılmaz QR üretimi başlar — web'deki `openAndGenerate` davranışı.
/// Yalnızca TEK oturumlu etkinlikler için geçerlidir: oturumlu etkinliklerde
/// öğrenci QR üretmez, kulübün ekrandaki oturum QR'ını okutur.
Future<void> showAppointmentSheet(
  BuildContext context, {
  required String registrationId,
  bool autoGenerateQr = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => AppointmentDetailSheet(
    registrationId: registrationId,
    autoGenerateQr: autoGenerateQr,
  ),
);

class AppointmentDetailSheet extends ConsumerStatefulWidget {
  const AppointmentDetailSheet({
    required this.registrationId,
    this.autoGenerateQr = false,
    super.key,
  });

  final String registrationId;
  final bool autoGenerateQr;

  @override
  ConsumerState<AppointmentDetailSheet> createState() =>
      _AppointmentDetailSheetState();
}

class _AppointmentDetailSheetState
    extends ConsumerState<AppointmentDetailSheet> {
  bool _qrVisible = false;
  bool _qrLoading = false;
  String? _qrImageUrl;

  /// Giriş onaylandığı anda açık QR'ı kapatmak için önceki katılım sayısı.
  int? _lastSeenAttendance;

  @override
  void initState() {
    super.initState();
    if (widget.autoGenerateQr) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateQr());
    }
  }

  /// Oturumlu etkinlikte tek eylem QR OKUTMAKTIR. Pencere kapatılıp tarayıcı
  /// ekranına gidilir; okuma onaylanınca tarayıcı bizi yine bu pencereye
  /// döndürür (bkz. StudentQrCheckinScreen).
  void _openSessionScanner(RegistrationWithEvent item) {
    // Yönlendirici pop'tan ÖNCE alınır: pencere kapandıktan sonra bu
    // `context` ağaçtan düşmüş olur ve `context.go` çalışmaz.
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(
      '${Routes.studentQrCheckin}'
      '?eventId=${Uri.encodeComponent(item.registration.eventId)}',
    );
  }

  Future<void> _generateQr() async {
    final RegistrationWithEvent? item = _currentItem();
    // Bilet yalnızca kapı check-in'i olan etkinlikte ve giriş alınmadan önce
    // gösterilir (student-ticket.js#canShowStudentTicket ile aynı ölçüt).
    if (item == null || item.isClosed || !item.canShowTicket) return;

    setState(() {
      _qrVisible = true;
      _qrLoading = true;
      _qrImageUrl = null;
    });

    // Bilet STATİKTİR: içeriği kaydın kimliğinden ibarettir ve etkinlik
    // boyunca değişmez. Konum TAŞIMAZ — okutan taraf kapıdaki görevlidir,
    // öğrenci zaten karşısında durmaktadır (bkz. domain/checkin_qr.dart).
    //
    // Bilet ADRESE de sarılmaz (buildCheckinQrUrl kullanılmaz): bunu telefon
    // kamerası değil görevlinin uygulaması okur; ham token en küçük ve en
    // hızlı okunan biçimdir.
    final String token = createCheckinQrToken(
      buildStudentCheckinPayload(
        registrationId: item.registration.id,
        eventId: item.registration.eventId,
        studentId: item.registration.studentId,
      ),
    );

    setState(() {
      _qrImageUrl = buildCheckinQrImageUrl(token, size: 400);
      _qrLoading = false;
    });
  }

  RegistrationWithEvent? _currentItem() {
    final List<RegistrationWithEvent> items =
        ref.read(appointmentsProvider).value ?? const <RegistrationWithEvent>[];

    for (final RegistrationWithEvent item in items) {
      if (item.registration.id == widget.registrationId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<RegistrationWithEvent> items =
        ref.watch(appointmentsProvider).value ??
        const <RegistrationWithEvent>[];

    RegistrationWithEvent? match;
    for (final RegistrationWithEvent candidate in items) {
      if (candidate.registration.id == widget.registrationId) match = candidate;
    }

    if (match == null) {
      return const SizedBox(height: 240, child: LoadingView());
    }

    // Kapanışlarda tür yükseltmesi korunsun diye final bir kopyaya alınır.
    // Etkinlik ayrıca CANLI dinlenir: kulüp yeni oturumu başlattığı anda
    // "QR Okut" düğmesi pencere açıkken kendiliğinden aktifleşsin
    // (`appointmentsProvider` etkinlikleri yalnızca bir kez okur).
    final RegistrationWithEvent item = match.withLiveEvent(
      ref.watch(liveEventProvider(match.registration.eventId)).value,
    );

    // Kulüp QR'ı okuttuğu anda (canlı güncelleme) açık QR'ı kapat.
    final int attendance = item.registration.sessionsAttended;
    final bool checkedIn = item.registration.isCheckedIn;
    if (_lastSeenAttendance != null &&
        (attendance > _lastSeenAttendance! ||
            (checkedIn && !item.canGenerateQr)) &&
        _qrVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _qrVisible = false);
      });
    }
    _lastSeenAttendance = attendance;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) => Stack(
        children: <Widget>[
          ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: EventImage(url: item.imageUrl, height: 180),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    StatusPill(
                      label: item.isClosed
                          ? context.t('dashboard.status.expired')
                          : context.t('dashboard.status.registered'),
                      tone: item.isClosed
                          ? FeedbackTone.error
                          : FeedbackTone.success,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      context.t(
                        'studentAppointments.card.club',
                        <String, Object?>{'clubName': item.clubName},
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      context.t(
                        'studentAppointments.card.deadline',
                        <String, Object?>{
                          'deadline': formatDeadline(
                            item.deadlineAtMs,
                            locale: context.lang,
                          ),
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      context.t(
                        'studentAppointments.card.registeredAt',
                        <String, Object?>{
                          'registeredAt': formatDateTime(
                            item.registration.registeredAtMs,
                            locale: context.lang,
                          ),
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    const SizedBox(height: 20),
                    _SessionProgress(item: item),

                    if (item.event != null) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        item.event!.description.isNotEmpty
                            ? item.event!.description
                            : context.t('dashboard.modal.noDescription'),
                        style: const TextStyle(height: 1.55),
                      ),
                      if (item.event!.locationName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: context.inkMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(item.event!.locationName)),
                          ],
                        ),
                      ],

                      // Ücretli etkinlik: ödeme uygulama dışında konuşulduğu
                      // için kulübün iletişim bilgileri kayıt sonrasında da
                      // erişilebilir olmalı. Kayıt anındaki pencere kapandıktan
                      // sonra öğrencinin bakacağı yer burası.
                      if (item.event!.isPaid) ...<Widget>[
                        const SizedBox(height: 20),
                        EventPaidContactBlock(event: item.event!),
                      ],
                    ],

                    const SizedBox(height: 24),
                    // Oturumlu etkinlik: okutma düğmesi kulüp QR'ı açana
                    // kadar gizlidir, açılınca belirir. Tek oturumlu: eskisi
                    // gibi QR üretilir.
                    // Kapı check-in'i olan etkinlikte İKİ yol da açıktır ve
                    // ikisi de aynı damgayı yazar; hangisinin kullanılacağını
                    // kulüp kapıda seçer:
                    //   • kulübün ekrandaki kodunu okut  → _DoorScanAction
                    //   • biletini görevliye göster      → "QR Oluştur"
                    // Web de ikisini birlikte sunuyor (qr-entry.js +
                    // student-ticket.js); iki platform aynı veriyi okuduğu için
                    // mobilde birini kapatmak, o kapıda takılan öğrenci demekti.
                    if ((item.event?.hasActiveDoorQr ?? false) &&
                        !item.registration.isCheckedIn)
                      _DoorScanAction(
                        open: true,
                        onScan: () => _openSessionScanner(item),
                      )
                    else if (item.event?.isMultiSession ?? false)
                      _SessionScanAction(
                        item: item,
                        onScan: () => _openSessionScanner(item),
                      ),
                    if (item.canShowTicket) ...<Widget>[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _qrLoading ? null : _generateQr,
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(
                          context.t('studentAppointments.modal.showTicket'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),

          // ── QR katmanı ────────────────────────────────────────────
          if (_qrVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _qrVisible = false),
                child: ColoredBox(
                  color: BrandColors.blackDeep.withValues(alpha: 0.92),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_qrLoading || _qrImageUrl == null) ...<Widget>[
                          const SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              color: BrandColors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.t('studentAppointments.modal.qrPreparing'),
                            style: const TextStyle(color: BrandColors.white),
                          ),
                        ] else ...<Widget>[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: BrandColors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Image.network(
                              _qrImageUrl!,
                              width: 260,
                              height: 260,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 260,
                                height: 260,
                                child: Center(child: Icon(Icons.wifi_off)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              context.t('studentAppointments.modal.qrHint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: BrandColors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Oturumlu etkinliğin "QR Okut" düğmesi ve durum açıklaması.
///
/// Kulüp ilk oturumu başlatana kadar okutulacak bir QR yoktur; düğme bu
/// süre boyunca gizlidir ve kulüp oturumu açtığı anda (canlı etkinlik
/// dinleyicisi sayesinde) kendiliğinden belirir.
class _SessionScanAction extends StatelessWidget {
  const _SessionScanAction({required this.item, required this.onScan});

  final RegistrationWithEvent item;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final SessionScanState state = item.sessionScanState;

    if (!(item.event?.hasActiveSessionQr ?? false)) {
      return const SizedBox.shrink();
    }

    if (state == SessionScanState.notStarted ||
        state == SessionScanState.unavailable) {
      return const SizedBox.shrink();
    }

    final bool ready = state == SessionScanState.ready;

    final String note = switch (state) {
      SessionScanState.ready => context.t(
        'studentAppointments.modal.scanReady',
        <String, Object?>{'current': item.currentSession},
      ),
      SessionScanState.notStarted => context.t(
        'studentAppointments.modal.scanNotStarted',
      ),
      SessionScanState.alreadyScanned => context.t(
        'studentAppointments.modal.scanAlreadyDone',
        <String, Object?>{'current': item.currentSession},
      ),
      SessionScanState.completed => context.t(
        'studentAppointments.modal.scanCompleted',
      ),
      SessionScanState.unavailable => context.t(
        'studentAppointments.modal.scanUnavailable',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: ready ? onScan : null,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(context.t('studentAppointments.modal.scanQr')),
        ),
        const SizedBox(height: 8),
        Text(
          note,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: ready ? context.brandInk : context.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Kapı QR'ı hem yalnızca Check-in hem de Check-in + Yoklama modunun ortak
/// ilk adımıdır. Kulüp kapı QR'ını açana kadar düğme gizlidir.
class _DoorScanAction extends StatelessWidget {
  const _DoorScanAction({required this.open, required this.onScan});

  final bool open;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: onScan,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(context.t('studentAppointments.modal.scanQr')),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('clubEvents.entry.subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.brandInk),
        ),
      ],
    );
  }
}

/// student-appointments.js#renderSessionProgress karşılığı.
class _SessionProgress extends StatelessWidget {
  const _SessionProgress({required this.item});

  final RegistrationWithEvent item;

  @override
  Widget build(BuildContext context) {
    // Çok oturumlu: mavi ilerleme çubuğu + belge eşiği notu.
    if (item.isMultiSession) {
      final int attended = item.registration.sessionsAttended;
      final int percent = item.attendancePercent;

      String note = '';
      final int? threshold = item.certificateThresholdPercent;
      if (threshold != null) {
        note = percent >= threshold
            ? context.t('studentAppointments.modal.certificateEarned')
            : context.t(
                'studentAppointments.modal.certificateNeeded',
                <String, Object?>{'percent': threshold},
              );
      }

      return _ProgressBox(
        title: context.t('studentAppointments.modal.sessionProgressTitle'),
        percent: percent / 100,
        color: BrandColors.info,
        text:
            context.t(
              'studentAppointments.modal.sessionProgressText',
              <String, Object?>{
                'attended': attended,
                'total': item.sessionCount,
              },
            ) +
            note,
      );
    }

    // Tek oturumlu: giriş yapıldıysa tam yeşil "katılım sağlandı" çubuğu.
    if (item.registration.isCheckedIn) {
      return _ProgressBox(
        title: context.t('studentAppointments.modal.attendanceTitle'),
        percent: 1,
        color: BrandColors.success,
        text: context.t('studentAppointments.modal.singleSessionSuccess'),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ProgressBox extends StatelessWidget {
  const _ProgressBox({
    required this.title,
    required this.percent,
    required this.color,
    required this.text,
  });

  final String title;
  final double percent;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: context.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
