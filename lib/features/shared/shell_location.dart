import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Alt çubuğun hangi sekmeyi vurgulayacağını belirleyen **canlı** konum.
///
/// `ShellRoute`'un builder'ına gelen `state.matchedLocation`, bir sayfa `push`
/// ile açıldığında güncellenmiyor: yalnızca `go` ile yapılan geçişlerde
/// tazeleniyor. Bu yüzden "Yeni Etkinlik" formu (push ile açılıyor) ekranda
/// dururken alt çubukta hâlâ "Etkinliklerim" kırmızı yanıyordu — aynı sorun
/// öğrenci tarafında bildirimler sayfası için de vardı.
///
/// Router'ın kendi durumu (`GoRouter.state`) her zaman **en üstteki** rotayı
/// bildirdiği için doğru sekmeyi veriyor; `routerDelegate` bir [Listenable]
/// olduğundan gezinme değiştiğinde çubuk kendiliğinden yeniden çiziliyor.
class ShellLocationBuilder extends StatelessWidget {
  const ShellLocationBuilder({
    required this.fallback,
    required this.builder,
    super.key,
  });

  /// Router bulunamazsa kullanılacak konum (ShellRoute'un verdiği).
  final String fallback;

  final Widget Function(BuildContext context, String location) builder;

  @override
  Widget build(BuildContext context) {
    final GoRouter? router = GoRouter.maybeOf(context);

    // Router yoksa (kabuğu tek başına çizen widget testleri) verilen konumla
    // yetiniriz; dinlenecek bir gezinme de yok.
    if (router == null) return builder(context, fallback);

    return AnimatedBuilder(
      animation: router.routerDelegate,
      builder: (BuildContext context, _) =>
          builder(context, _locationOf(router, fallback)),
    );
  }
}

/// Router'ın en üstteki rotasının yolu.
///
/// Router yoksa ya da yönlendirme henüz oturmadıysa [fallback] döner; bu
/// durumda çubuk yanlış vurgulamak yerine önceki hâlini korur.
String liveLocation(BuildContext context, String fallback) {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router == null) return fallback;
  return _locationOf(router, fallback);
}

String _locationOf(GoRouter router, String fallback) {
  try {
    return router.state.matchedLocation;
  } catch (_) {
    return fallback;
  }
}
