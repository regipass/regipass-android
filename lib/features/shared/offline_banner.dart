import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../state/connectivity.dart';

/// Bağlantı koptuğunda ekranın üstünde beliren uyarı şeridi.
///
/// Uygulamanın tamamının üzerinde durur (bkz. `RegipassApp.builder`), böylece
/// hangi sayfada olursak olalım kullanıcı çevrimdışı olduğunu görür. Firestore
/// çevrimdışıyken hata vermeden önbellekten okuduğu için bu uyarı olmadan
/// kullanıcı eski veriye baktığını anlayamıyordu.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool online = ref.watch(onlineProvider);

    return Stack(
      children: <Widget>[
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: online ? const Offset(0, -1) : Offset.zero,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: online ? 0 : 1,
                duration: const Duration(milliseconds: 240),
                child: const _OfflineBar(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) {
    // Durum çubuğunun altına iniyoruz: aksi hâlde metin çentiğin altında kalır.
    final double topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: BrandColors.danger,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 10),
        child: Row(
          children: <Widget>[
            const Icon(Icons.wifi_off, size: 18, color: BrandColors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.t('offline.banner'),
                    style: const TextStyle(
                      color: BrandColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    context.t('offline.bannerDesc'),
                    style: const TextStyle(
                      color: BrandColors.white,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
