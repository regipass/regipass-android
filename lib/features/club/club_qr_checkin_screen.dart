import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../core/geo.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import 'club_shell.dart';

/// club-qr-checkin.html + club-events.js#processScannedQrToken karşılığı.
///
/// Kulüp, öğrencinin kendi telefonunda ürettiği QR'ı okutur ve o öğrencinin
/// kaydına giriş damgası yazar. [eventId] verilirse yalnızca o etkinliğin
/// QR'ları kabul edilir (etkinlik detayından gelindiğinde böyle).
class ClubQrCheckinScreen extends ConsumerStatefulWidget {
  const ClubQrCheckinScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<ClubQrCheckinScreen> createState() =>
      _ClubQrCheckinScreenState();
}

class _ClubQrCheckinScreenState extends ConsumerState<ClubQrCheckinScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;

  /// Aynı QR telefon çekilirken tekrar okunabiliyor; kısa süre içinde gelen
  /// aynı kod hata gibi gösterilmeden yok sayılır.
  String? _lastKey;
  int _lastAtMs = 0;
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

    Future<void>.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _result = null);
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    final String? raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final Map<String, dynamic>? payload = parseCheckinQrToken(raw);
    if (payload == null || payload['type'] != 'event-checkin') {
      _show(false, context.t('scan.notRegipassQr'));
      return;
    }

    final String eventId = '${payload['eventId'] ?? ''}';
    final String studentId = '${payload['studentId'] ?? ''}';
    if (eventId.isEmpty || studentId.isEmpty) {
      _show(false, context.t('scan.missingEventInfo'));
      return;
    }

    // Etkinlik detayından gelindiyse başka etkinliğin QR'ı kabul edilmez.
    if ((widget.eventId ?? '').isNotEmpty && widget.eventId != eventId) {
      _show(false, context.t('clubScan.otherEvent'));
      return;
    }

    final String key = '${eventId}_$studentId';
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (key == _lastKey && now - _lastAtMs < _dedupeWindowMs) return;
    _lastKey = key;
    _lastAtMs = now;

    setState(() => _busy = true);
    try {
      await _process(eventId, studentId, payload);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _process(
    String eventId,
    String studentId,
    Map<String, dynamic> payload,
  ) async {
    final String? clubId = ref.read(sessionProvider).user?.uid;
    if (clubId == null) return;

    final AppEvent? event =
        await ref.read(eventRepositoryProvider).fetchEvent(eventId);
    if (!mounted) return;

    if (event == null) {
      _show(false, context.t('scan.eventNotFound'));
      return;
    }
    if (event.clubId != clubId) {
      _show(false, context.t('clubScan.notOwner'));
      return;
    }
    if (isPastEvent(event)) {
      _show(false, context.t('clubScan.pastEvent'));
      return;
    }

    final EventRegistration? registration = await ref
        .read(eventRepositoryProvider)
        .fetchRegistration(eventId, studentId);
    if (!mounted) return;

    if (registration == null) {
      _show(false, context.t('clubScan.notRegistered'));
      return;
    }

    // ── Oturum kuralları ────────────────────────────────────────────
    if (!event.isMultiSession && registration.isCheckedIn) {
      _show(
        false,
        context.t('clubScan.alreadyCheckedIn', <String, Object?>{
          'name': registration.displayName,
        }),
      );
      return;
    }

    if (event.isMultiSession) {
      if (event.sessionsCompleted) {
        _show(false, context.t('scan.sessionsCompleted'));
        return;
      }
      if (event.currentSession < 1) {
        _show(false, context.t('clubScan.sessionNotStarted'));
        return;
      }
      if (registration.lastAttendedSession >= event.currentSession) {
        _show(
          false,
          context.t('clubScan.alreadyInSession', <String, Object?>{
            'name': registration.displayName,
            'current': event.currentSession,
            'total': event.sessionCount,
          }),
        );
        return;
      }
    }

    // ── Konum doğrulama ─────────────────────────────────────────────
    if (event.hasLocationCheck) {
      final double? lat = (payload['lat'] as num?)?.toDouble();
      final double? lng = (payload['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        _show(false, context.t('clubScan.missingLocation'));
        return;
      }

      final double distance = haversineDistanceM(
        lat,
        lng,
        event.locationLat!,
        event.locationLng!,
      );

      if (distance > event.effectiveRadius) {
        _show(
          false,
          context.t('clubScan.tooFar', <String, Object?>{
            'distance': distance < 1000
                ? '${distance.round()} m'
                : '${(distance / 1000).toStringAsFixed(1)} km',
            'radius': event.effectiveRadius,
          }),
        );
        return;
      }
    }

    try {
      await ref.read(eventRepositoryProvider).markCheckInByClub(
            registration: registration,
            clubId: clubId,
            isMultiSession: event.isMultiSession,
            currentSession: event.currentSession,
          );
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
      event.isMultiSession
          ? context.t('clubScan.sessionSuccess', <String, Object?>{
              'name': registration.displayName,
              'current': event.currentSession,
              'attended': registration.sessionsAttended + 1,
              'total': event.sessionCount,
            })
          : context.t('clubScan.success', <String, Object?>{
              'name': registration.displayName,
            }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('dashboard.drawer.qrCheckin'),
        subtitle: context.t('scan.pointCamera'),
        showBack: (widget.eventId ?? '').isNotEmpty,
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

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.result});

  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    final Color color =
        result.success ? BrandColors.success : BrandColors.danger;

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
