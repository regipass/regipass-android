/// Misafir (giriş yapmamış) kullanıcı için etkinlik vitrini sağlayıcıları.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/event_utils.dart';
import '../../models/event.dart';
import '../../services/firebase_refs.dart';

/// Vitrinin yüklenme sonucu.
///
/// Hata durumunu ayrı bir tip olarak taşıyoruz çünkü "yetki reddedildi"
/// kullanıcıya gösterilecek özel bir mesaj gerektiriyor: kurallar henüz
/// açılmamışsa ekran boş görünmemeli, sebebi anlaşılmalı.
sealed class ExploreResult {
  const ExploreResult();
}

class ExploreEvents extends ExploreResult {
  const ExploreEvents(this.events);

  final List<AppEvent> events;
}

/// firestore.rules etkinlik okumayı girişe bağlı tuttuğu için misafir
/// erişimi reddedilmiş demektir (bkz. README > Misafir vitrini).
class ExplorePermissionDenied extends ExploreResult {
  const ExplorePermissionDenied();
}

class ExploreFailed extends ExploreResult {
  const ExploreFailed(this.code);

  final String code;
}

/// Sayfa her açıldığında sıralamanın değişmesi için kullanılan tohum.
/// Değeri değişince [exploreEventsProvider] yeniden hesaplanır.
class ExploreShuffleNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().microsecondsSinceEpoch;

  /// Ekran her açıldığında ve "karıştır" düğmesinde çağrılır.
  void reshuffle() => state = DateTime.now().microsecondsSinceEpoch;
}

final NotifierProvider<ExploreShuffleNotifier, int> exploreShuffleProvider =
    NotifierProvider<ExploreShuffleNotifier, int>(ExploreShuffleNotifier.new);

/// Misafir vitrini — **süresi dolmuş etkinlikler dâhil**.
///
/// Bu liste giriş yapmamış ziyaretçiye "burada neler oluyor" hissini vermek
/// için var; kayıt olunacak bir liste değil. Bu yüzden algoritması giriş
/// sonrasındaki keşiften **bilerek ayrı**:
///
///   * hedef kitle filtresi yok (misafirin üniversitesi/bölümü bilinmiyor),
///   * öncelik/ağırlık sıralaması yok — kime göre sıralanacağı belli değil,
///   * her açılışta rastgele karışır ki vitrin hep aynı görünmesin,
///   * süresi geçmiş etkinlikler de görünür, ama **listenin sonunda**.
///
/// Giriş sonrası keşif (studentVisibleEventsProvider) bunun tersine: kapalı
/// etkinlikleri hiç göstermez ve üniversite/bölüm ağırlığına göre sıralar.
///
/// Yalnızca `hiddenGlobally` işaretli etkinlikler gizlenir — kulüp bir
/// etkinliği herkesten kaldırdıysa vitrinde de görünmemeli.
final FutureProvider<ExploreResult> exploreEventsProvider =
    FutureProvider<ExploreResult>((Ref ref) async {
      final int seed = ref.watch(exploreShuffleProvider);

      try {
        // Filtre ZORUNLU. Firestore'da sorgu izni sorgunun kendisine bakar:
        // misafir kuralı `resource.data.hiddenGlobally == false` olduğu için
        // sorgunun da aynı alanı filtrelemesi gerekiyor, yoksa Firestore tüm
        // sorguyu reddeder (istemcide filtrelemek yetmez).
        //
        // Yan etki: `hiddenGlobally` alanı hiç yazılmamış eski etkinlikler bu
        // sorguya düşmez. Uygulama üzerinden oluşturulan her etkinlikte alan
        // `false` olarak yazılıyor (club-create-event.js), dolayısıyla normalde
        // hepsi görünür.
        final QSnap snap = await eventsCol
            .where('hiddenGlobally', isEqualTo: false)
            .get();

        final List<AppEvent> events = snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  AppEvent.fromMap(d.id, d.data()),
            )
            .toList();

        events.shuffle(math.Random(seed));

        // Karıştırdıktan SONRA kapalı olanları sona alıyoruz: vitrin canlı
        // görünsün ama geçmiş etkinlikler de kaybolmasın. İki gruba ayırıp
        // birleştirmek, grup içindeki rastgele sırayı bozmadan bunu sağlar.
        final List<AppEvent> open = <AppEvent>[];
        final List<AppEvent> closed = <AppEvent>[];

        for (final AppEvent event in events) {
          // İP-EL: yalnızca linkle paylaşılan etkinlik vitrinde hiç görünmez.
          if (event.isLinkOnly) continue;
          (isDiscoverableEvent(event) ? open : closed).add(event);
        }

        return ExploreEvents(<AppEvent>[...open, ...closed]);
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          return const ExplorePermissionDenied();
        }
        return ExploreFailed(error.code);
      } catch (error) {
        return ExploreFailed('$error');
      }
    });
