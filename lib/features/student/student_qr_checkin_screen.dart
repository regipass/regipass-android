import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../core/geo.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/routing.dart';
import '../../domain/session_qr_window.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/geo_fence_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import 'student_shell.dart';

/// student-qr-checkin.html + js/pages/student-qr-checkin.js karşılığı.
///
/// Kulübün ekrana bastığı **paylaşılan oturum QR'ını** okutur. Kod öğrenciye
/// özel değildir; okuyan öğrencinin KENDİ kaydı güncellenir.
///
/// Web'de BarcodeDetector/jsQR ikilisi vardı; mobilde `mobile_scanner`
/// (ML Kit / AVFoundation) kullanılır.
///
/// Giriş onaylandıktan sonra öğrenci etkinliğin detay penceresine döndürülür:
/// katılım çubuğu güncellenmiş, okutma düğmesi bir sonraki oturuma kadar
/// pasifleşmiş olarak görünür. Böylece "okuttum da ne oldu?" sorusu kalmaz.
class StudentQrCheckinScreen extends ConsumerStatefulWidget {
  const StudentQrCheckinScreen({this.expectedEventId, super.key});

  /// Etkinlik penceresindeki "QR Okut" düğmesinden gelindiyse o etkinliğin
  /// kimliği. Dolu olduğunda başka bir etkinliğin QR'ı kabul edilmez —
  /// öğrenci yanlış salondaki koda okutup "neden sayılmadı" demesin.
  final String? expectedEventId;

  @override
  ConsumerState<StudentQrCheckinScreen> createState() =>
      _StudentQrCheckinScreenState();
}

class _StudentQrCheckinScreenState extends ConsumerState<StudentQrCheckinScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;

  /// Aynı oturum QR'ı kısa süre önce işlendiyse (telefon çekilirken tekrar
  /// okunmuş olabilir) sessizce yok sayılır — hata gösterilmez.
  String? _lastProcessedKey;
  int _lastProcessedAtMs = 0;
  static const int _dedupeWindowMs = 10000;

  _ScanResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _show(bool success, String detail) {
    if (!mounted) return;
    setState(() => _result = _ScanResult(success: success, detail: detail));

    // 2.5 sn sonra sonucu gizle ve bir sonraki okumaya hazırlan.
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _result = null);
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    final String? raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final Map<String, dynamic>? payload = parseCheckinQrToken(raw);

    if (payload == null) {
      _show(false, context.t('scan.notSessionQr'));
      return;
    }

    final String type = '${payload['type'] ?? ''}';
    if (type != 'session-checkin' && type != 'event-entry') {
      _show(false, context.t('scan.notRegipassQr'));
      return;
    }

    final String eventId = '${payload['eventId'] ?? ''}';
    final int? session = payload['session'] is int
        ? payload['session'] as int
        : int.tryParse('${payload['session']}');

    if (eventId.isEmpty || (type == 'session-checkin' && session == null)) {
      _show(false, context.t('scan.missingSessionInfo'));
      return;
    }

    final String? expected = widget.expectedEventId;
    if (expected != null && expected.isNotEmpty && expected != eventId) {
      _show(false, context.t('scan.otherEventQr'));
      return;
    }

    final String dedupeKey = '${eventId}_${type == 'session-checkin' ? session : 'door'}';
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (dedupeKey == _lastProcessedKey && now - _lastProcessedAtMs < _dedupeWindowMs) {
      return;
    }
    _lastProcessedKey = dedupeKey;
    _lastProcessedAtMs = now;

    setState(() => _busy = true);
    try {
      if (type == 'event-entry') {
        await _processDoor(eventId);
      } else {
        await _processSession(eventId, session!, payload['slot']);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _processSession(String eventId, int session, Object? slot) async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;

    final EventRepositoryAccess repo = EventRepositoryAccess(ref);

    final AppEvent? event = await repo.fetchEvent(eventId);
    if (!mounted) return;

    if (event == null) {
      _show(false, context.t('scan.eventNotFound'));
      return;
    }
    if (!event.isMultiSession) {
      _show(false, context.t('scan.notSessionBased'));
      return;
    }
    if (event.sessionsCompleted) {
      _show(false, context.t('scan.sessionsCompleted'));
      return;
    }
    // Eski/gelecek bir QR kabul edilmez — kod yalnızca AKTİF oturum için geçerli.
    if (session != event.currentSession) {
      _show(false, context.t('scan.qrExpired'));
      return;
    }

    // Ekrandaki kod 20 saniyede bir yenilenir; başkasının gönderdiği ekran
    // görüntüsü buraya ulaştığında dilim çoktan değişmiş olur.
    //
    // Web'de bu kontrol yalnızca `tokenCameFromScan` iken yapılır: orada token
    // giriş/kayıt adımlarından sonra beklemeden de gelebiliyor ve o adımlar
    // dakikalar sürebiliyordu. Mobilde bu ekrandaki her token DOĞRUDAN
    // kameradan gelir, yani koşul her zaman sağlanır ve kontrol her okumada
    // uygulanır (bkz. domain/session_qr_window.dart).
    if (!isSessionQrSlotFresh(slot)) {
      _show(false, context.t('scan.qrSlotExpired'));
      return;
    }

    final EventRegistration? registration = await repo.fetchRegistration(eventId, uid);
    if (!mounted) return;

    if (registration == null) {
      _show(false, context.t('scan.notRegistered'));
      return;
    }

    if (event.requiresDoorCheckinForSession && !registration.isCheckedIn) {
      _show(false, context.t('scan.needsDoorCheckin'));
      return;
    }

    // Aynı oturumda ikinci kez okutma: artış yok, giriş reddedilir.
    if (registration.lastAttendedSession >= event.currentSession) {
      _show(
        false,
        context.t('scan.alreadyCheckedInSession', <String, Object?>{
          'current': event.currentSession,
          'total': event.sessionCount,
        }),
      );
      return;
    }

    // Öğrenci ekrandaki QR'ı KENDİ telefonuyla okuttuğu için salonda olup
    // olmadığını yalnızca konum söyleyebilir. Etkinliğin tanımlı bir konumu
    // yoksa bu adım atlanır — izin bile istenmez (geo-fence.js ile aynı).
    if (event.hasLocationCheck) {
      final GeoFenceResult fence = await const GeoFenceService().verify(event);
      if (!mounted) return;
      if (!fence.ok) {
        _show(
          false,
          fence.outcome == GeoFenceOutcome.tooFar
              ? context.t('scan.tooFar', <String, Object?>{
                  'distance': formatDistance(fence.distanceM!),
                  'radius': event.effectiveRadius,
                })
              : context.t('scan.locationRequired'),
        );
        return;
      }
    }

    try {
      await repo.markOwnSessionCheckIn(
        eventId: eventId,
        studentId: uid,
        registration: registration,
        currentSession: event.currentSession,
      );
    } catch (error) {
      if (!mounted) return;
      final bool denied = '$error'.contains('permission-denied');
      _show(
        false,
        denied
            ? context.t('scan.permissionError')
            : context.t('scan.checkinSaveFailed'),
      );
      return;
    }

    if (!mounted) return;
    _show(
      true,
      context.t('scan.sessionSuccess', <String, Object?>{
        'current': event.currentSession,
        'attended': registration.sessionsAttended + 1,
        'total': event.sessionCount,
      }),
    );
    _returnToAppointment(registration.id);
  }

  Future<void> _processDoor(String eventId) async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;

    final EventRepositoryAccess repo = EventRepositoryAccess(ref);
    final AppEvent? event = await repo.fetchEvent(eventId);
    if (!mounted) return;

    if (event == null) {
      _show(false, context.t('scan.eventNotFound'));
      return;
    }
    // Ölçüt etkinliğin MODUDUR (checkinMode alanı yazılı olsun ya da olmasın;
    // eski kayıtlarda oturum sayısından türetilir). Web tarafı da bu QR'ı
    // `eventHasDoorCheckin` ile kabul ediyor — iki platform aynı kodu okuduğu
    // için ölçüt de aynı olmak zorunda.
    if (!event.hasDoorCheckin) {
      _show(false, context.t('scan.notDoorQr'));
      return;
    }
    if (!event.entryOpen) {
      _show(false, context.t('scan.doorClosed'));
      return;
    }

    final EventRegistration? registration = await repo.fetchRegistration(eventId, uid);
    if (!mounted) return;
    if (registration == null) {
      _show(false, context.t('scan.notRegistered'));
      return;
    }
    if (registration.isCheckedIn) {
      _show(false, context.t('clubScan.alreadyCheckedIn', <String, Object?>{
        'name': registration.displayName,
      }));
      return;
    }

    // KAPIDA KONUM SORULMAZ. Check-in fiziksel olarak kapıda yapılan bir
    // işlemdir: öğrenci ya görevlinin okuttuğu bilettedir ya da görevlinin
    // açtığı kapı QR'ının önündedir. Konum izni istemek hem gereksiz bir adım
    // hem de her öğrenci için saniyeler süren bir gecikmedir.
    //
    // Buradaki sınır konumun yerine KULÜBÜN KAPIYI AÇIK TUTMASIDIR
    // (yukarıdaki `entryOpen` kontrolü): görevli girişi bitirince QR'ın ekran
    // görüntüsü de dahil hiçbir kod işe yaramaz. Aynı koşul
    // firestore.rules > studentCanMarkOwnEventCheckIn içinde de duruyor.
    //
    // Konum YALNIZCA salondaki oturum yoklamasında çalışır
    // (bkz. [_processSession]) — orada QR'ı öğrenci kendi telefonuyla okuttuğu
    // için gerçekten içeride olup olmadığı başka türlü anlaşılamaz.
    try {
      await repo.markOwnDoorCheckin(eventId: eventId, studentId: uid);
    } catch (error) {
      if (!mounted) return;
      _show(
        false,
        '$error'.contains('permission-denied')
            ? context.t('scan.permissionError')
            : context.t('scan.checkinSaveFailed'),
      );
      return;
    }
    if (!mounted) return;
    _show(
      true,
      context.t(event.isMultiSession ? 'scan.doorSuccess' : 'scan.doorOnlySuccess'),
    );
    _returnToAppointment(registration.id);
  }

  /// Onaydan sonra etkinlik penceresine dönüş.
  ///
  /// Pencere buradan açılmaz; randevular sekmesine `open` parametresiyle
  /// gidilir ve pencereyi o ekran açar. Bu ekran yönlendirmeden hemen sonra
  /// ağaçtan düştüğü için pencereyi buradan açmak dayanıksız olurdu.
  void _returnToAppointment(String registrationId) {
    final GoRouter router = GoRouter.of(context);

    // Başarı kartı okunacak kadar ekranda kalsın, sonra geçiş yapılsın.
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      router.go(
        '${Routes.studentAppointments}'
        '?open=${Uri.encodeComponent(registrationId)}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(
        title: context.t('dashboard.drawer.qrCheckin'),
        subtitle: context.t('scan.pointCamera'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FeedbackBanner(
                  message: context.t('scan.permissionDenied'),
                  tone: FeedbackTone.error,
                ),
              ),
            ),
          ),

          // Hedef çerçevesi
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: BrandColors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          if (_busy)
            const Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(color: BrandColors.white),
              ),
            ),

          if (_result != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 32,
              child: _ScanResultCard(result: _result!),
            ),
        ],
      ),
    );
  }
}

class _ScanResult {
  const _ScanResult({required this.success, required this.detail});

  final bool success;
  final String detail;
}

/// club-qr-checkin.js#showResult karşılığı: kameranın altında beliren
/// başarı/hata kartı.
class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.result});

  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    final Color color = result.success ? BrandColors.success : BrandColors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        boxShadow: BrandShape.raised,
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            result.success ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.success
                      ? context.t('scan.successTitle')
                      : context.t('scan.failTitle'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(result.detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Repository'e widget içinden kısa erişim sarmalayıcısı.
class EventRepositoryAccess {
  const EventRepositoryAccess(this._ref);

  final WidgetRef _ref;

  Future<AppEvent?> fetchEvent(String eventId) =>
      _ref.read(eventRepositoryProvider).fetchEvent(eventId);

  Future<EventRegistration?> fetchRegistration(String eventId, String studentId) =>
      _ref.read(eventRepositoryProvider).fetchRegistration(eventId, studentId);

  Future<void> markOwnSessionCheckIn({
    required String eventId,
    required String studentId,
    required EventRegistration registration,
    required int currentSession,
  }) =>
      _ref.read(eventRepositoryProvider).markOwnSessionCheckIn(
            eventId: eventId,
            studentId: studentId,
            registration: registration,
            currentSession: currentSession,
          );

  Future<void> markOwnDoorCheckin({
    required String eventId,
    required String studentId,
  }) =>
      _ref.read(eventRepositoryProvider).markOwnDoorCheckin(
            eventId: eventId,
            studentId: studentId,
          );
}
