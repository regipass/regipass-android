import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/ticket_code.dart';
import '../../app/theme.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_feedback.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/connectivity.dart';
import '../../state/providers.dart';
import '../shared/add_to_calendar_button.dart';
import '../shared/event_link_widgets.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import '../shared/qr_code_view.dart';
import '../shared/ticket_image.dart';
import '../shared/wallet_buttons.dart';
import 'event_extras_section.dart';
import 'event_feedback_card.dart';
import 'online_join_card.dart';
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
  bool focusFeedback = false,
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
    focusFeedback: focusFeedback,
  ),
);

class AppointmentDetailSheet extends ConsumerStatefulWidget {
  const AppointmentDetailSheet({
    required this.registrationId,
    this.autoGenerateQr = false,
    this.focusFeedback = false,
    super.key,
  });

  final String registrationId;
  final bool autoGenerateQr;

  /// İP-D: değerlendirme formu başta ve açık gelir.
  final bool focusFeedback;

  @override
  ConsumerState<AppointmentDetailSheet> createState() =>
      _AppointmentDetailSheetState();
}

class _AppointmentDetailSheetState
    extends ConsumerState<AppointmentDetailSheet> {
  bool _qrVisible = false;
  bool _qrLoading = false;
  String? _qrData;
  String _qrTicketCode = '';
  bool _ticketSaving = false;

  /// Bilet kodu sunucudan alınamadıysa (bağlantı / geçici hata) kod satırı
  /// yerine "Tekrar dene" gösterilir; bilet kodsuz kalmasın.
  bool _ticketCodeFailed = false;

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
      _qrData = null;
    });

    // Bilet STATİKTİR: içeriği kaydın kimliğinden ibarettir ve etkinlik
    // boyunca değişmez. Konum TAŞIMAZ — okutan taraf kapıdaki görevlidir,
    // öğrenci zaten karşısında durmaktadır (bkz. domain/checkin_qr.dart).
    //
    // Bilet ADRESE de sarılmaz (buildCheckinQrUrl kullanılmaz): bunu telefon
    // kamerası değil görevlinin uygulaması okur; ham token en küçük ve en
    // hızlı okunan biçimdir.
    // İP-Y: bilete sunucunun ürettiği kod girer; kapıda kayıtla
    // karşılaştırılır. Kod alınamazsa (bağlantı yok) bilet kodsuz çizilir;
    // aşama 1'de kulüp uyarıyla kabul eder.
    String ticketCode = item.registration.ticketCode;
    // İP-O: internet yokken sunucuyu 8 sn beklemeden bilet hemen çizilir
    // (kod önceden alınmışsa kayıtta zaten vardır; Firestore önbelleği).
    if (ticketCode.isEmpty && ref.read(onlineProvider)) {
      ticketCode = await _fetchTicketCode(item.registration.id);
      if (!mounted) return;
    }

    final String token = createCheckinQrToken(
      buildStudentCheckinPayload(
        registrationId: item.registration.id,
        eventId: item.registration.eventId,
        studentId: item.registration.studentId,
        ticketCode: ticketCode,
      ),
    );

    setState(() {
      _qrData = token;
      _qrTicketCode = ticketCode;
      _ticketCodeFailed = ticketCode.isEmpty;
      _qrLoading = false;
    });
  }

  /// Sunucudan bilet kodu: geçici hatalarda 3 kez dener (0 / 1 / 2 sn).
  Future<String> _fetchTicketCode(String registrationId) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: attempt));
        if (!mounted) return '';
      }
      try {
        final String code = await ref
            .read(attendanceServiceProvider)
            .ensureTicketCode(registrationId);
        if (code.isNotEmpty) return code;
      } catch (_) {
        // Bir sonraki denemeye geç.
      }
    }
    return '';
  }

  /// "Tekrar dene": kodu yeniden ister, bulunca QR'ı kodla yeniden çizer.
  Future<void> _retryTicketCode() async {
    final RegistrationWithEvent? item = _currentItem();
    if (item == null) return;
    setState(() => _ticketCodeFailed = false);
    final String code = await _fetchTicketCode(item.registration.id);
    if (!mounted) return;
    if (code.isEmpty) {
      setState(() => _ticketCodeFailed = true);
      return;
    }
    setState(() {
      _qrTicketCode = code;
      _qrData = createCheckinQrToken(
        buildStudentCheckinPayload(
          registrationId: item.registration.id,
          eventId: item.registration.eventId,
          studentId: item.registration.studentId,
          ticketCode: code,
        ),
      );
    });
  }

  Future<void> _saveTicketImage(
    BuildContext buttonContext,
    RegistrationWithEvent item,
  ) async {
    final AppEvent? event = item.event;
    if (event == null) return;
    final RenderBox? box = buttonContext.findRenderObject() as RenderBox?;
    final Rect? origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _ticketSaving = true);
    try {
      await shareTicketImage(
        event: event,
        registrationId: item.registration.id,
        studentId: item.registration.studentId,
        ticketCode: _qrTicketCode,
        studentName: ref.read(studentProfileProvider).value?.fullName ?? '',
        origin: origin,
        english: context.lang == 'en',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('postRegistration.ticketError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _ticketSaving = false);
    }
  }

  RegistrationWithEvent? _currentItem() {
    final List<RegistrationWithEvent> items =
        ref.read(appointmentsProvider).value ?? const <RegistrationWithEvent>[];

    for (final RegistrationWithEvent item in items) {
      if (item.registration.id == widget.registrationId) return item;
    }
    return null;
  }

  Widget _feedbackCard(
    RegistrationWithEvent item, {
    bool startEditing = false,
  }) => EventFeedbackCard(
    eventId: item.registration.eventId,
    window: feedbackWindowFor(
      item.event,
      item.registration,
      DateTime.now().millisecondsSinceEpoch,
    ),
    startEditing: startEditing,
  );

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
                  top: Radius.circular(BrandShape.sheetRadius),
                ),
                child: EventImage(url: item.imageUrl, height: 200),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    StatusPill(
                      label: context.t(item.statusBadge.key),
                      tone: switch (item.statusBadge.tone) {
                        -1 => FeedbackTone.error,
                        0 => FeedbackTone.warning,
                        _ => FeedbackTone.success,
                      },
                    ),
                    // İP-K: iptal notu ve ödeme uyarısı.
                    if (item.isCancelled) ...<Widget>[
                      const SizedBox(height: 12),
                      FeedbackBanner(
                        message: (item.event?.cancelReason ?? '').isNotEmpty
                            ? context.t(
                                'registration.club.cancelledBannerReason',
                                <String, Object?>{
                                  'reason': item.event!.cancelReason,
                                },
                              )
                            : context.t(
                                'registration.status.cancelledNoReason',
                              ),
                        tone: FeedbackTone.error,
                      ),
                    ] else if (item.paymentPending) ...<Widget>[
                      const SizedBox(height: 12),
                      FeedbackBanner(
                        message: context.t(
                          'registration.ticket.paymentPendingHint',
                        ),
                        tone: FeedbackTone.warning,
                      ),
                    ],
                    const SizedBox(height: 16),

                    EventMetaRow(
                      icon: Icons.groups_2_outlined,
                      text: item.clubName,
                    ),
                    EventMetaRow(
                      icon: Icons.event_available_outlined,
                      text: context.t(
                        'studentAppointments.card.deadline',
                        <String, Object?>{
                          'deadline': formatDeadline(
                            item.deadlineAtMs,
                            locale: context.lang,
                          ),
                        },
                      ),
                    ),
                    EventMetaRow(
                      icon: Icons.how_to_reg_outlined,
                      text: context.t(
                        'studentAppointments.card.registeredAt',
                        <String, Object?>{
                          'registeredAt': formatDateTime(
                            item.registration.registeredAtMs,
                            locale: context.lang,
                          ),
                        },
                      ),
                    ),
                    if (item.event?.locationName.isNotEmpty ?? false)
                      EventMetaRow(
                        icon: Icons.place_outlined,
                        text: item.event!.locationName,
                      ),

                    // İP-D: bildirimden gelindiyse değerlendirme en üstte.
                    if (widget.focusFeedback) ...<Widget>[
                      const SizedBox(height: 16),
                      _feedbackCard(item, startEditing: true),
                    ],

                    const SizedBox(height: 20),
                    _SessionProgress(item: item),
                    // İP-P1: program (✓ katıldın / Şu an).
                    if (item.event != null)
                      EventProgramSection(
                        event: item.event!,
                        registration: item.registration,
                      ),

                    if (!widget.focusFeedback) ...<Widget>[
                      const SizedBox(height: 16),
                      _feedbackCard(item),
                    ],

                    if (item.event != null) ...<Widget>[
                      const SizedBox(height: 24),
                      EventSectionTitle(context.t('eventModal.description')),
                      const SizedBox(height: 10),
                      Text(
                        item.event!.description.isNotEmpty
                            ? item.event!.description
                            : context.t('dashboard.modal.noDescription'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),

                      // Ücretli etkinlik: ödeme uygulama dışında konuşulduğu
                      // için kulübün iletişim bilgileri kayıt sonrasında da
                      // erişilebilir olmalı. Kayıt anındaki pencere kapandıktan
                      // sonra öğrencinin bakacağı yer burası.
                      const SizedBox(height: 20),
                      EventPaidContactBlock(event: item.event!),
                    ],

                    // İP-T: takvime ekle
                    if (item.event != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          AddToCalendarButton(event: item.event!),
                          ShareEventLinkButton(event: item.event!),
                        ],
                      ),
                    ],
                    // İP-B2: cüzdan düğmesi bilete bağlı değil — etkinlik günü
                    // bilet gizlense de (giriş yapıldı / yalnız yoklama)
                    // etkinlik bitene kadar burada durur.
                    // İP-FS/PS/SL/FT: Fişlerim, pasaport, programım, fotoğraflar.
                    if (item.event != null && !item.isCancelled)
                      EventExtrasSection(
                        event: item.event!,
                        registrationId: item.registration.id,
                        studentId: item.registration.studentId,
                        ticketCode: item.registration.ticketCode,
                        checkedIn: item.registration.isCheckedIn,
                      ),
                    if (item.event != null && !item.isClosed)
                      WalletButtons(
                        key: const Key('detailWallet'),
                        registrationId: item.registration.id,
                        cancelled: item.isCancelled,
                        paymentPending: item.paymentPending,
                      ),
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
                    // İP-ON: online etkinlik — Yayına katıl + anlık yoklama kodu.
                    if ((item.event?.isOnline ?? false) && !item.isClosed && !item.isCancelled)
                      OnlineJoinCard(event: item.event!)
                    else if ((item.event?.hasActiveDoorQr ?? false) &&
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
                        if (_qrLoading || _qrData == null) ...<Widget>[
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
                            // İP-O / O3: bilet cihazda çizilir; internet yokken de açılır.
                            child: QrCodeView(data: _qrData!, size: 260),
                          ),
                          // Kamera okumazsa görevli bu kodu elle girer.
                          if (_qrTicketCode.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              context.t('ticket.codeLabel'),
                              style: TextStyle(
                                color: BrandColors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                            SelectableText(
                              formatTicketCode(_qrTicketCode),
                              key: const Key('ticketCodeText'),
                              style: const TextStyle(
                                color: BrandColors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                          if (_qrTicketCode.isEmpty && _ticketCodeFailed)
                            TextButton.icon(
                              key: const Key('ticketCodeRetry'),
                              onPressed: _retryTicketCode,
                              style: TextButton.styleFrom(
                                foregroundColor: BrandColors.white,
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(context.t('ticket.codeRetry')),
                            ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              context.t(
                                item.paymentPending
                                    ? 'registration.ticket.paymentPendingHint'
                                    : 'studentAppointments.modal.qrHint',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: BrandColors.white),
                            ),
                          ),
                          // İP-T2: bilet resim olarak kaydedilebilir (QR sabit).
                          if (item.event != null) ...<Widget>[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (BuildContext b) => OutlinedButton.icon(
                                key: const Key('saveTicketImage'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BrandColors.white,
                                  // Temadaki dolu (beyaz) zemin koyu katmanda
                                  // yazıyı görünmez yapıyordu; saydam zeminde de
                                  // arkadaki metin sızıyordu → koyu dolu zemin.
                                  backgroundColor: BrandColors.blackDeep,
                                  side: const BorderSide(
                                    color: BrandColors.white,
                                  ),
                                ),
                                icon: const Icon(Icons.download_outlined),
                                label: Text(
                                  context.t('postRegistration.ticketSave'),
                                ),
                                onPressed: _ticketSaving
                                    ? null
                                    : () => _saveTicketImage(b, item),
                              ),
                            ),
                            // İP-W: cüzdana ekle (app_config/wallet kapalıyken görünmez).
                            WalletButtons(
                              registrationId: item.registration.id,
                              cancelled: item.isCancelled,
                              paymentPending: item.paymentPending,
                            ),
                          ],
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
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
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
