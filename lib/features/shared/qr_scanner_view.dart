import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';

/// QR okutma kamerası + kamera izni akışı (App Store 2.1(a) düzeltmesi).
///
/// Önceki hâlde kamera izni uygulama açılır açılmaz soruluyordu; kullanıcı
/// "İzin Verme" dediyse QR ekranı yalnızca "Kamera izni kapalı" yazısı
/// gösteriyor, izni yeniden isteyecek ya da Ayarlar'a götürecek bir yol
/// sunmuyordu (Apple incelemesi bu yüzden QR okutmayı kullanamadı).
///
/// Bu görünüm:
/// * izni ekran açılınca, bağlamı içinde ister;
/// * izin kapalıysa açıklama + "İzin ver" (yeniden sorulabiliyorsa) ya da
///   "Ayarları Aç" düğmesi gösterir; Ayarlar'dan dönünce kendiliğinden
///   yeniden bakar ve kamerayı açar;
/// * izin dışındaki kamera hatalarında ayrı mesaj + "Tekrar dene" gösterir;
/// * [overlay] (okuma çerçevesi) yalnızca kamera sorunsuz çalışırken çizilir,
///   böylece hata kartının üstüne binmez.
class QrScannerView extends StatefulWidget {
  const QrScannerView({
    required this.controller,
    required this.onDetect,
    this.overlay,
    this.messageAlignment = Alignment.center,
    super.key,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;

  /// Kamera çalışırken üstte gösterilecek katman (okuma çerçevesi).
  final Widget? overlay;

  /// İzin/hata kartının ekrandaki yeri (kapı ekranında alttaki "Kodu elle
  /// gir" düğmesiyle çakışmasın diye yukarı alınır).
  final AlignmentGeometry messageAlignment;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

enum _CameraAccess {
  /// İzin durumu okunuyor / sistem penceresi açık.
  checking,

  /// İzin verildi (ya da izin eklentisi yok: test/masaüstü) → kamera açılır.
  granted,

  /// Reddedildi ama yeniden sorulabilir (Android ilk ret).
  denied,

  /// Kalıcı ret / kısıtlı → yalnız Ayarlar'dan açılabilir.
  blocked,
}

class _QrScannerViewState extends State<QrScannerView>
    with WidgetsBindingObserver {
  _CameraAccess _access = _CameraAccess.checking;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_resolveAccess(askIfNeeded: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_access == _CameraAccess.granted) {
      // Kamera açıkken hata kalmışsa (ör. arka plandan dönüş) yeniden dene.
      if (widget.controller.value.error != null) unawaited(_retryCamera());
      return;
    }
    // Ayarlar'dan dönüş: izin açıldıysa kamera kendiliğinden gelir.
    unawaited(_resolveAccess(askIfNeeded: false));
  }

  Future<void> _resolveAccess({required bool askIfNeeded}) async {
    _CameraAccess next;
    try {
      // Durum okuma takılırsa ekran beklemede kalmasın: kamera eklentisi
      // kendi izin akışıyla devam eder.
      PermissionStatus status = await Permission.camera.status.timeout(
        const Duration(seconds: 4),
      );
      if (status.isDenied && askIfNeeded) {
        if (mounted) setState(() => _access = _CameraAccess.checking);
        status = await Permission.camera.request();
      }
      next = _accessFor(status);
    } catch (_) {
      // İzin eklentisi yoksa (test, masaüstü) kamera eklentisinin kendi
      // akışına bırakılır; hata olursa errorBuilder gösterir.
      next = _CameraAccess.granted;
    }
    if (!mounted) return;
    setState(() => _access = next);
  }

  static _CameraAccess _accessFor(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return _CameraAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return _CameraAccess.blocked;
    }
    return _CameraAccess.denied;
  }

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      // Ayarlar açılamazsa kart yerinde kalır; kullanıcı elle açabilir.
    }
  }

  Future<void> _retryCamera() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.controller.stop();
    } catch (_) {}
    try {
      await widget.controller.start();
    } catch (_) {
      // Hata controller.value.error üzerinden errorBuilder'a düşer.
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    switch (_access) {
      case _CameraAccess.checking:
        return const Center(child: CircularProgressIndicator());
      case _CameraAccess.denied:
        return _placed(
          _CameraMessageCard(
            key: const Key('qrScanner.permission'),
            icon: Icons.no_photography_outlined,
            title: context.t('scan.camera.offTitle'),
            body: context.t('scan.camera.offBody'),
            actionLabel: context.t('scan.camera.allow'),
            onAction: () => _resolveAccess(askIfNeeded: true),
          ),
        );
      case _CameraAccess.blocked:
        return _placed(_blockedCard(context));
      case _CameraAccess.granted:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MobileScanner(
              controller: widget.controller,
              onDetect: widget.onDetect,
              errorBuilder: _errorBuilder,
            ),
            if (widget.overlay != null)
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: widget.controller,
                builder:
                    (
                      BuildContext context,
                      MobileScannerState value,
                      Widget? _,
                    ) => value.error == null
                    ? widget.overlay!
                    : const SizedBox.shrink(),
              ),
          ],
        );
    }
  }

  Widget _placed(Widget card) => Align(
    alignment: widget.messageAlignment,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: card,
      ),
    ),
  );

  Widget _blockedCard(BuildContext context) => _CameraMessageCard(
    key: const Key('qrScanner.settings'),
    icon: Icons.no_photography_outlined,
    title: context.t('scan.camera.offTitle'),
    body: context.t('scan.camera.blockedBody'),
    actionLabel: context.t('scan.camera.openSettings'),
    actionIcon: Icons.settings_outlined,
    onAction: _openSettings,
  );

  Widget _errorBuilder(BuildContext context, MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return _placed(_blockedCard(context));
      case MobileScannerErrorCode.unsupported:
        return _placed(
          _CameraMessageCard(
            key: const Key('qrScanner.unsupported'),
            icon: Icons.videocam_off_outlined,
            title: context.t('scan.camera.unavailableTitle'),
            body: context.t('scan.camera.noCameraBody'),
          ),
        );
      default:
        return _placed(
          _CameraMessageCard(
            key: const Key('qrScanner.error'),
            icon: Icons.videocam_off_outlined,
            title: context.t('scan.camera.unavailableTitle'),
            body: context.t('scan.camera.errorBody'),
            actionLabel: context.t('scan.camera.retry'),
            actionIcon: Icons.refresh,
            busy: _retrying,
            onAction: _retryCamera,
            detail: error.errorCode.name,
          ),
        );
    }
  }
}

class _CameraMessageCard extends StatelessWidget {
  const _CameraMessageCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.busy = false,
    this.detail,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool busy;

  /// Küçük teknik kod (destek için); kullanıcıya anlam taşımaz.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: context.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: context.brandInk),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.inkMuted,
              height: 1.5,
              fontSize: 14.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onAction,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(actionIcon ?? Icons.photo_camera_outlined),
                label: Text(actionLabel!),
              ),
            ),
          ],
          if (detail != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              detail!,
              style: TextStyle(color: context.inkMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
