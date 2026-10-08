import 'dart:ui' show FlutterView, PlatformDispatcher;

import 'package:flutter/widgets.dart';

/// iPad'de paylaşım penceresi (popover) için güvenli kaynak dikdörtgeni.
///
/// share_plus iPad'de `sharePositionOrigin` boşsa, sıfır boyutluysa ya da
/// ekranın dışına taşıyorsa paylaşımı HİÇ açmaz (hata döner). Düğmenin
/// konumu bazen ölçülemiyor (ağaçtan düşmüş bağlam, alttan açılan pencere
/// animasyonu, kaydırılmış liste). Bu yardımcı verilen dikdörtgeni ekranla
/// sınırlar; kullanılamıyorsa ekranın ortasında küçük bir nokta döndürür.
/// iPhone ve Android'de değer yok sayılır, zararsızdır.
Rect safeShareOrigin(Rect? origin) {
  final FlutterView? view =
      PlatformDispatcher.instance.implicitView ??
      PlatformDispatcher.instance.views.firstOrNull;
  if (view == null) return origin ?? const Rect.fromLTWH(0, 0, 1, 1);
  final Size size = view.physicalSize / view.devicePixelRatio;
  if (size.isEmpty) return origin ?? const Rect.fromLTWH(0, 0, 1, 1);
  final Rect screen = (Offset.zero & size).deflate(1);
  if (origin != null &&
      origin.isFinite &&
      origin.width > 0 &&
      origin.height > 0) {
    final Rect clipped = origin.intersect(screen);
    if (clipped.width >= 1 && clipped.height >= 1) return clipped;
  }
  return Rect.fromCenter(center: screen.center, width: 2, height: 2);
}
