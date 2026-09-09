import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_utils.dart';
import '../../domain/routing.dart';
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
  bool _leavingForEvent = false;

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
      await _process(eventId, studentId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _process(String eventId, String studentId) async {
    final String? clubId = ref.read(sessionProvider).user?.uid;
    if (clubId == null) return;

    final AppEvent? event = await ref
        .read(eventRepositoryProvider)
        .fetchEvent(eventId);
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
    // Kapıda check-in adımı olmayan etkinlik ("Sadece Yoklama") burada
    // okutulmaz: o modda tek QR salondaki oturum kodudur ve yönü terstir —
    // kulüp ekrana basar, öğrenciler kendi telefonlarından okutur.
    // (club-qr-checkin.js ile aynı ölçüt: `eventHasDoorCheckin`.)
    if (!event.hasDoorCheckin) {
      _show(false, context.t('clubScan.noDoorCheckin'));
      return;
    }
    // Burada `entryOpen` ARANMAZ. Yazan taraf kulübün kendisidir ve
    // firestore.rules > clubCanMarkCheckIn de kapının açık olmasını şart
    // koşmaz; web tarafı da koşmuyor. Şart konsaydı check-in'i bitirdikten
    // sonra kapıya gelen geç öğrenci mobilde alınamaz, web'de alınabilirdi.
    // `entryOpen`, ÖĞRENCİNİN kendi girişini yazdığı yolun sınırıdır
    // (studentCanMarkOwnEventCheckIn) — görevlinin okuttuğu yolun değil.

    final EventRegistration? registration = await ref
        .read(eventRepositoryProvider)
        .fetchRegistration(eventId, studentId);
    if (!mounted) return;

    if (registration == null) {
      _show(false, context.t('clubScan.notRegistered'));
      return;
    }

    // ── Zaten giriş yapmış öğrenci ──────────────────────────────────
    // Bu bir HATA değildir: görevli aynı kişiyi ikinci kez okutmuş ya da
    // öğrenci dışarı çıkıp geri girmiş olabilir. Kimlik kartı yine gösterilir,
    // sayım değişmez (club-qr-checkin.js ile aynı).
    if (registration.isCheckedIn) {
      _show(
        false,
        context.t('clubScan.alreadyCheckedIn', <String, Object?>{
          'name': registration.displayName,
        }),
      );
      return;
    }

    // ── Konum ────────────────────────────────────────────────────────
    // Kapıda konum DOĞRULANMAZ: QR'ı okutan kişi kulüp görevlisidir, öğrenci
    // fiziksel olarak kapıda durmaktadır. Bu yüzden bilet yükü de koordinat
    // taşımaz (bkz. domain/checkin_qr.dart#buildStudentCheckinPayload).
    // Konum yalnızca salondaki oturum QR'ında anlamlıdır.

    try {
      // Bilet okuma yalnızca KAPI DAMGASI yazar; oturum yoklaması saymaz.
      // "Check-in + Yoklama" modunda gün içindeki yoklamalar ayrı bir adımdır
      // ve öğrencinin salondaki oturum QR'ını okutmasıyla işler.
      await ref
          .read(eventRepositoryProvider)
          .markCheckInByClub(registration: registration, clubId: clubId);
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
      context.t('clubScan.success', <String, Object?>{
        'name': registration.displayName,
      }),
    );
    _returnToEvent(event);
  }

  /// Başarılı girişte QR ekranını açık bırakmak, görevliyi yeniden aynı
  /// öğrenciyi okutmaya davet ediyordu. Kamerayı hemen durdurup ilgili
  /// etkinliğin penceresi açık olan "Etkinliklerim" ekranına dönüyoruz.
  void _returnToEvent(AppEvent event) {
    if (_leavingForEvent) return;
    _leavingForEvent = true;

    // Aynı karede yeniden tetiklenebilecek kamera algılamasını kes.
    unawaited(_controller.stop());

    // Başarı kartı fark edilecek kadar görünür; ardından QR ekranı kapanır.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      context.go(
        '${Routes.clubEvents}'
        '?openEventId=${Uri.encodeComponent(event.id)}',
      );
    });
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
