import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../core/geo.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/attendance_service.dart';
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
  const StudentQrCheckinScreen({
    this.expectedEventId,
    this.initialQrValue,
    super.key,
  });

  /// Etkinlik penceresindeki "QR Okut" düğmesinden gelindiyse o etkinliğin
  /// kimliği. Dolu olduğunda başka bir etkinliğin QR'ı kabul edilmez —
  /// öğrenci yanlış salondaki koda okutup "neden sayılmadı" demesin.
  final String? expectedEventId;

  /// Telefonun kendi kamerasının açtığı dış bağlantıdan gelen token. Doluysa
  /// tarayıcı arayüzü açılır ama işlem kamera algısı beklemeden otomatik
  /// çalışır; fiziksel konum ve mevcut Firestore güvenlik kontrolleri aynen
  /// uygulanır.
  final String? initialQrValue;

  @override
  ConsumerState<StudentQrCheckinScreen> createState() =>
      _StudentQrCheckinScreenState();
}

class _StudentQrCheckinScreenState
    extends ConsumerState<StudentQrCheckinScreen> {
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
  void initState() {
    super.initState();
    final String? initial = widget.initialQrValue;
    if (initial == null || initial.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _processRawValue(initial);
    });
  }

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
    final String? raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    await _processRawValue(raw);
  }

  Future<void> _processRawValue(String raw) async {
    if (_busy) return;

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

    final String dedupeKey =
        '${eventId}_${type == 'session-checkin' ? session : 'door'}';
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (dedupeKey == _lastProcessedKey &&
        now - _lastProcessedAtMs < _dedupeWindowMs) {
      return;
    }
    _lastProcessedKey = dedupeKey;
    _lastProcessedAtMs = now;

    // Sunucuya giden, okunan kodun kendisi (imzası ve dilimi orada denetlenir).
    final String token = extractCheckinQrToken(raw) ?? raw;

    setState(() => _busy = true);
    try {
      if (type == 'event-entry') {
        await _processDoor(eventId, token);
      } else {
        await _processSession(eventId, session!, token);
      }
    } catch (_) {
      if (mounted) _show(false, context.t('scan.checkinSaveFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bu etkinliğe hiç kaydı olmayan biri okuttuğunda gösterilecek metin.
  ///
  /// Kayıtlar hâlâ açıksa "kayıtlı değilsin" doğru ve eyleme dönüştürülebilir
  /// bir uyarıdır (öğrenci gidip kaydolabilir). Ama kayıtlar durdurulduysa
  /// artık kaydolmanın bir yolu yok — bu durumda kafa karıştıran "kayıtlı
  /// değilsin" yerine etkinliğin süresinin geçtiği söylenir.
  String _notRegisteredMessage(AppEvent event) => isRegistrationClosed(event)
      ? context.t('scan.eventClosedNotRegistered')
      : context.t('scan.notRegistered');

  Future<void> _processSession(
    String eventId,
    int session,
    String token,
  ) async {
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

    // Ekrandaki kod 20 saniyede bir yenilenir; imza ve tazelik artık
    // sunucuda denetlenir (İP-Y, checkInWithQr).

    final EventRegistration? registration = await repo.fetchRegistration(
      eventId,
      uid,
    );
    if (!mounted) return;

    if (registration == null) {
      _show(false, _notRegisteredMessage(event));
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

    final CheckInResult? result = await _submit(event, token);
    if (result == null || !mounted) return;
    _show(
      true,
      context.t('scan.sessionSuccess', <String, Object?>{
        'current': event.currentSession,
        'attended': result.sessionsAttended > 0
            ? result.sessionsAttended
            : registration.sessionsAttended + 1,
        'total': event.sessionCount,
      }),
    );
    _returnToAppointment(registration.id);
  }

  Future<void> _processDoor(String eventId, String token) async {
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

    final EventRegistration? registration = await repo.fetchRegistration(
      eventId,
      uid,
    );
    if (!mounted) return;
    if (registration == null) {
      _show(false, _notRegisteredMessage(event));
      return;
    }
    if (registration.isCheckedIn) {
      _show(
        false,
        context.t('clubScan.alreadyCheckedIn', <String, Object?>{
          'name': registration.displayName,
        }),
      );
      return;
    }

    final CheckInResult? result = await _submit(event, token);
    if (result == null || !mounted) return;
    _show(
      true,
      context.t(
        event.isMultiSession ? 'scan.doorSuccess' : 'scan.doorOnlySuccess',
      ),
    );
    _returnToAppointment(registration.id);
  }

  /// Kodu ve (etkinliğin konumu varsa) cihazın güncel konumunu sunucuya
  /// gönderir (İP-Y). İmza, 20 sn tazelik, mesafe ve kural koşulları
  /// sunucuda denetlenir, kaydı sunucu yazar. Hata olursa mesajı gösterip
  /// `null` döner.
  Future<CheckInResult?> _submit(AppEvent event, String token) async {
    ({double lat, double lng, double? accuracyM})? location;
    if (!event.hasNoLocationCheck) {
      final Position? position = await const GeoFenceService()
          .currentPosition();
      if (!mounted) return null;
      if (position == null ||
          !position.latitude.isFinite ||
          !position.longitude.isFinite) {
        _show(false, context.t('scan.locationRequired'));
        _lastProcessedKey = null; // izin verildikten sonra aynı kod denenebilsin
        return null;
      }
      location = (
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy.isFinite ? position.accuracy : null,
      );
    }

    try {
      return await ref
          .read(attendanceServiceProvider)
          .checkInWithQr(token: token, location: location);
    } on AttendanceFailure catch (failure) {
      if (!mounted) return null;
      if (failure.reason == 'too-far' ||
          failure.reason == 'location-required' ||
          failure.reason == 'network') {
        _lastProcessedKey = null;
      }
      _show(false, attendanceFailureMessage(context, failure, event));
      return null;
    } catch (_) {
      if (!mounted) return null;
      _lastProcessedKey = null;
      _show(false, context.t('scan.checkinSaveFailed'));
      return null;
    }
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
            errorBuilder:
                (BuildContext context, MobileScannerException error) => Center(
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
    final Color color = result.success
        ? BrandColors.success
        : BrandColors.danger;

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
                Text(
                  result.detail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
      _ref.read(eventRepositoryProvider).fetchEventFromServer(eventId);

  Future<EventRegistration?> fetchRegistration(
    String eventId,
    String studentId,
  ) => _ref.read(eventRepositoryProvider).fetchRegistration(eventId, studentId);
}

/// Sunucunun ret nedenini ekrandaki cümleye çevirir.
String attendanceFailureMessage(
  BuildContext context,
  AttendanceFailure failure,
  AppEvent event,
) => switch (failure.reason) {
  'expired' => context.t('scan.qrSlotExpired'),
  'bad-signature' ||
  'invalid-token' ||
  'unsigned' => context.t('scan.notRegipassQr'),
  'entry-closed' => context.t('scan.doorClosed'),
  // İP-K
  'payment-pending' => context.t('registration.errors.payment-pending'),
  'event-cancelled' => context.t('registration.errors.event-cancelled'),
  'already-checked-in' => context.t('attendance.error.alreadyCheckedIn'),
  'already-attended' => context.t(
    'scan.alreadyCheckedInSession',
    <String, Object?>{
      'current': failure.session ?? event.currentSession,
      'total': event.sessionCount,
    },
  ),
  'session-mismatch' => context.t('scan.qrExpired'),
  'session-not-started' => context.t('attendance.error.sessionNotStarted'),
  'sessions-completed' => context.t('scan.sessionsCompleted'),
  'needs-door-checkin' => context.t('scan.needsDoorCheckin'),
  'no-door-checkin' => context.t('scan.notDoorQr'),
  'no-sessions' => context.t('scan.notSessionBased'),
  'location-required' => context.t('scan.locationRequired'),
  'too-far' => context.t('scan.tooFar', <String, Object?>{
    'distance': formatDistance((failure.distanceM ?? 0).toDouble()),
    'radius': failure.radiusM ?? event.effectiveRadius,
  }),
  'not-registered' => context.t('scan.notRegistered'),
  'event-not-found' => context.t('scan.eventNotFound'),
  'banned' => context.t('attendance.error.banned'),
  _ => context.t('scan.checkinSaveFailed'),
};
