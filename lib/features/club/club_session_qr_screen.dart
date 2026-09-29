import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/qr_signing.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/attendance_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/qr_code_view.dart';
import '../shared/event_widgets.dart';
import 'club_providers.dart';
import 'club_shell.dart';

/// Oturum QR'ı üretme ekranı (club-events.js#showSessionQr karşılığı).
///
/// Web'de bu düğme yalnızca **çok oturumlu** etkinliklerde ve yalnızca aktif
/// bir oturum varken görünüyordu. Mobilde de aynı: liste yalnızca oturumlu
/// etkinlikleri gösterir, tek oturumlu etkinlikler için QR üretilmez (orada
/// giriş, öğrencinin kendi QR'ını kulübe okutmasıyla yapılır).
///
/// Liste podcast bölümleri gibi kurulur: solda kapak görseli, yanında başlık
/// ve oturum ilerleme çubuğu, sağda tek bir yuvarlak QR düğmesi.
///
/// İki ayrı iş, iki ayrı hedef: **karta** dokunmak etkinliğin yönetim
/// ekranına götürür (oturum ilerletme, geri alma, katılımcılar, belge),
/// **QR düğmesi** ise doğrudan o anki oturumun kodunu ekrana basar. Eskiden
/// kartın tamamı QR açıyordu; kulübün yönetim ekranına ulaşmak için listeden
/// çıkıp "Etkinliklerim"e gitmesi gerekiyordu.
class ClubSessionQrScreen extends ConsumerWidget {
  const ClubSessionQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppEvent>> events = ref.watch(clubEventsProvider);

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('dashboard.drawer.qrGenerate'),
        subtitle: context.t('clubSessionQr.subtitle'),
      ),
      body: events.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('clubEvents.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<AppEvent> all) {
          // Yalnızca oturumlu ve süresi geçmemiş etkinlikler.
          final List<AppEvent> sessionEvents =
              all
                  .where(
                    (AppEvent e) =>
                        e.isMultiSession &&
                        !e.hiddenFromClubList &&
                        !isPastEvent(e),
                  )
                  .toList()
                ..sort(
                  (AppEvent a, AppEvent b) =>
                      a.deadlineAtMs.compareTo(b.deadlineAtMs),
                );

          if (sessionEvents.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                EmptyState(
                  message: context.t('clubSessionQr.empty'),
                  icon: Icons.qr_code_2,
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: sessionEvents.length + 1,
            separatorBuilder: (_, int index) =>
                SizedBox(height: index == 0 ? 12 : 10),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Text(
                  context.t('clubSessionQr.hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              return _SessionEventTile(event: sessionEvents[index - 1]);
            },
          );
        },
      ),
    );
  }
}

/// Podcast bölümü düzeninde tek etkinlik satırı.
class _SessionEventTile extends ConsumerWidget {
  const _SessionEventTile({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool completed = event.sessionsCompleted;
    final bool started = event.currentSession >= 1;

    // İlerleme çubuğu "kaçıncı oturum" sorusunu zaten yanıtlıyor; metin
    // yalnızca durumu söyler, sayı taşımaz.
    final String status = completed
        ? context.t('clubEvents.session.stateAllDone')
        : started
        ? context.t('clubEvents.session.stateActive')
        : context.t('clubEvents.session.stateNotStarted');

    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: InkWell(
        // Kart yönetim ekranına götürür; QR düğmesi kodu basar.
        onTap: () => context.push(
          '${Routes.clubEventDetail}?eventId=${Uri.encodeComponent(event.id)}',
        ),
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            border: Border.all(color: context.hairline),
          ),
          child: Row(
            children: <Widget>[
              // Kapak görseli — podcast bölüm kapağı gibi kare.
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: EventImage(url: event.displayImageUrl, height: 62),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        Icon(
                          completed
                              ? Icons.check_circle_outline
                              : started
                              ? Icons.play_circle_outline
                              : Icons.schedule,
                          size: 14,
                          color: completed
                              ? BrandColors.success
                              : context.inkMuted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    SessionProgressBar(
                      total: event.sessionCount,
                      completed: completed
                          ? event.sessionCount
                          : event.currentSession,
                      done: completed,
                      height: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _QrPlayButton(
                enabled: !completed,
                onTap: () => openSessionQr(context, ref, event),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Podcast "oynat" düğmesinin QR karşılığı.
class _QrPlayButton extends StatelessWidget {
  const _QrPlayButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled ? BrandColors.gradient : null,
            color: enabled ? null : context.subtleFill,
          ),
          child: InkWell(
            onTap: onTap,
            child: Icon(
              enabled ? Icons.qr_code_2 : Icons.done_all,
              size: 21,
              color: enabled ? BrandColors.white : context.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Karta dokunulduğunda çalışan akış.
///
/// Sıra önemli: **önce** etkinlik penceresi açılır (arkada kalsın), hemen
/// ardından QR penceresi onun üstüne biner. Kulüp QR'ı kapattığında altında
/// etkinliğin kendisi durur; ayrıca listeye dönüp aramak gerekmez.
///
/// QR yalnızca **aktif** oturum için geçerlidir (öğrenci tarafı
/// `session != currentSession` gelen kodu reddeder), bu yüzden henüz
/// başlamamış etkinlikte önce oturumun başlatılması gerekir. Bu, öğrencilerin
/// yoklamasını etkileyen bir işlem olduğu için onay sorulur.
Future<void> openSessionQr(
  BuildContext context,
  WidgetRef ref,
  AppEvent event,
) async {
  if (event.sessionsCompleted) {
    showTopFeedback(
      context,
      context.t('clubEvents.session.allDone', <String, Object?>{
        'total': event.sessionCount,
      }),
      tone: FeedbackTone.info,
    );
    return;
  }

  // Bilerek beklenmiyor: pencere arkada açık kalacak, akış QR ile sürüyor.
  unawaited(showEventDetailSheet(context, event: event, forClub: true));

  if (event.currentSession >= 1) {
    await showSessionQrDialog(context, ref, event.id, event.currentSession);
    return;
  }

  final bool? start = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(dialogContext.t('clubEvents.session.advanceTitle')),
      content: Text(
        dialogContext.t('clubEvents.session.startConfirm', <String, Object?>{
          'total': event.sessionCount,
        }),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.t('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.t('clubEvents.session.start')),
        ),
      ],
    ),
  );

  if (start != true || !context.mounted) return;

  try {
    await ref.read(eventRepositoryProvider).advanceSession(event, 1);
  } catch (_) {
    if (context.mounted) {
      showTopFeedback(context, context.t('clubEvents.feedback.updateError'));
    }
    return;
  }

  if (!context.mounted) return;
  await showSessionQrDialog(context, ref, event.id, 1);
}

/// Kulübün ekrana bastığı, öğrencilerin kendi telefonlarından okuttuğu
/// paylaşılan oturum QR'ı. Öğrenciye özel değildir.
///
/// Kod **20 saniyede bir yenilenir**: içine üretildiği anın dilim numarası
/// yazılır, okuyan taraf kendi dilimiyle karşılaştırır. Amaç, ekranın
/// fotoğrafını çekip dışarıdaki arkadaşına gönderen öğrenciyi durdurmaktır
/// (bkz. domain/session_qr_window.dart).
Future<void> showSessionQrDialog(
  BuildContext context,
  WidgetRef ref,
  String eventId,
  int session,
) async {
  final AppEvent? event = await _publishQr(
    context,
    ref,
    eventId,
    session: session,
  );
  if (event == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(
        dialogContext.t('clubEvents.session.qrTitle', <String, Object?>{
          'session': session,
        }),
      ),
      content: _RotatingSignedQr(
        event: event,
        type: 'session-checkin',
        session: session,
        service: ref.read(attendanceServiceProvider),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t('common.close')),
        ),
      ],
    ),
  );
}

Future<AppEvent?> _publishQr(
  BuildContext context,
  WidgetRef ref,
  String eventId, {
  int? session,
}) async {
  try {
    return await ref
        .read(eventRepositoryProvider)
        .publishSharedQr(eventId, session: session);
  } catch (error) {
    if (context.mounted) {
      showTopFeedback(
        context,
        context.t(
          error is StateError
              ? error.message
              : 'clubEvents.feedback.updateError',
        ),
      );
    }
    return null;
  }
}

/// Kapı ve oturum QR'ı: **imzalı ve 20 saniyede bir yenilenir** (İP-Y).
///
/// Etkinliğin gizli anahtarı açılışta bir kez sunucudan alınır
/// (getCheckinQrKey); her dilimin imzası cihazda üretilir. Öğrencinin
/// okuttuğu kodu sunucu doğrular: ekran görüntüsü ~40 saniye sonra işe
/// yaramaz. Dilim sunucu saatine göre hesaplanır.
///
/// Yenileme dilim **sınırına** hizalıdır: ilk bekleme içinde bulunulan
/// dilimin bitişine kadar sürer (club-events.js#scheduleQrRotation ile aynı).
class _RotatingSignedQr extends StatefulWidget {
  const _RotatingSignedQr({
    required this.event,
    required this.type,
    required this.service,
    this.session = 0,
  });

  final AppEvent event;

  /// `session-checkin` ya da `event-entry`.
  final String type;
  final int session;
  final AttendanceService service;

  @override
  State<_RotatingSignedQr> createState() => _RotatingSignedQrState();
}

class _RotatingSignedQrState extends State<_RotatingSignedQr> {
  QrSigner? _signer;
  bool _failed = false;
  Timer? _rotation;
  Timer? _countdown;
  int _slot = 0;
  int _secondsLeft = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final QrSigner signer = await widget.service.fetchQrSigner(widget.event.id);
      if (!mounted) return;
      setState(() {
        _signer = signer;
        _failed = false;
        _slot = signer.slot();
        _secondsLeft = _remainingSeconds(signer);
      });
      // Saniye sayacı yalnızca ipucu satırını tazeler; kodu döndüren ayrı bir
      // zamanlayıcıdır ve dilim sınırına hizalıdır.
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secondsLeft = _remainingSeconds(signer));
      });
      _scheduleRotation(signer);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  int _remainingSeconds(QrSigner signer) => (signer.msUntilNextSlot() / 1000)
      .ceil()
      .clamp(1, signer.windowMs ~/ 1000);

  void _scheduleRotation(QrSigner signer) {
    _rotation?.cancel();
    _rotation = Timer(Duration(milliseconds: signer.msUntilNextSlot() + 50), () {
      if (!mounted) return;
      setState(() => _slot = signer.slot());
      _scheduleRotation(signer);
    });
  }

  @override
  void dispose() {
    _rotation?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QrSigner? signer = _signer;
    if (signer == null) {
      return SizedBox(
        width: 296,
        height: 296,
        child: Center(
          child: _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      context.t('attendance.qrKeyError'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        _load();
                      },
                      child: Text(context.t('common.retry')),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      ...signer.sign(
        type: widget.type,
        eventId: widget.event.id,
        session: widget.session,
        slotOverride: _slot,
      ),
      // Konum yalnızca bilgi; mesafe sunucuda etkinlik belgesinden hesaplanır.
      if (widget.event.locationLat != null && widget.event.locationLng != null) ...<String, dynamic>{
        'locationLat': widget.event.locationLat,
        'locationLng': widget.event.locationLng,
        'locationRadius': widget.event.effectiveRadius,
      },
    };
    final String token = createCheckinQrToken(payload);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // QR'ın içeriği bir ADRESTİR: öğrenci telefonunun kendi kamerasıyla
        // okuttuğunda link açılır; uygulama içi tarayıcı da aynı kodu okur
        // (bkz. domain/checkin_qr.dart#extractCheckinQrToken).
        _QrImage(data: buildCheckinQrUrl(token)),
        const SizedBox(height: 12),
        Text(
          context.t(
            widget.type == 'event-entry'
                ? 'attendance.entryRotatingHint'
                : 'clubEvents.session.qrRotatingHint',
            <String, Object?>{'seconds': _secondsLeft},
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Kapıda gösterilen ortak giriş QR'ı (İP-Y: o da imzalı ve döner).
///
/// Kapının sınırı kulübün girişi açık tutmasıdır (`events.entryOpen`); buna ek
/// olarak kod 20 saniyede bir değişir, kapının fotoğrafı evden işe yaramaz.
Future<void> showDoorCheckinQrDialog(
  BuildContext context,
  WidgetRef ref,
  String eventId,
) async {
  final AppEvent? event = await _publishQr(context, ref, eventId);
  if (event == null || !context.mounted) return;

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(dialogContext.t('clubEvents.entry.qrTitle')),
      content: _RotatingSignedQr(
        event: event,
        type: 'event-entry',
        service: ref.read(attendanceServiceProvider),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t('common.close')),
        ),
      ],
    ),
  );
}

/// QR her zaman beyaz zemin üzerinde: koyu modda okunabilirlik kamera için
/// kritik.
class _QrImage extends StatelessWidget {
  const _QrImage({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrandColors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        // İP-O / O3: QR cihazda çizilir; internet yokken de görünür.
        child: QrCodeView(data: data, size: 280),
      ),
    );
  }
}
