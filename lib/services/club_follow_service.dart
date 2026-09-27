/// Kulüp takip (İP-TK) — js/modules/clubs/follow.js karşılığı.
///
/// Takip et / bırak yalnızca `followClub` çağrısıyla (sayaç sunucuda).
/// Öğrenci kendi takip kayıtlarını (`club_follows`, uid == kendisi) canlı
/// dinler; ad / logo gereken liste `listFollowedClubs` ile gelir (öğrenci
/// club_profiles'ı okuyamaz). Kulüp yalnızca takipçi SAYISINI görür.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/club_follow.dart';
import '../state/providers.dart';
import 'firebase_refs.dart';

class ClubFollowService {
  const ClubFollowService();

  Future<void> setFollow(String clubId, {required bool follow}) async {
    await fbFunctions.httpsCallable('followClub').call(<String, Object>{
      'clubId': clubId,
      'follow': follow,
    });
  }

  Future<List<FollowedClub>> listFollowedClubs() async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('listFollowedClubs')
        .call(<String, Object>{});
    final Object? data = result.data;
    final Object? clubs = data is Map ? data['clubs'] : null;
    if (clubs is! List) return const <FollowedClub>[];
    return clubs
        .whereType<Map<Object?, Object?>>()
        .map(FollowedClub.fromMap)
        .toList(growable: false);
  }
}

/// Sunucunun döndürdüğü hata nedeni (details.reason).
String followErrorReason(Object error) {
  if (error is FirebaseFunctionsException) {
    final Object? details = error.details;
    if (details is Map && details['reason'] is String) {
      return details['reason'] as String;
    }
    return error.message ?? '';
  }
  return '';
}

final Provider<ClubFollowService> clubFollowServiceProvider =
    Provider<ClubFollowService>((Ref ref) => const ClubFollowService());

/// Öğrencinin takip ettiği kulüp kimlikleri (canlı).
final StreamProvider<Set<String>> followedClubIdsProvider =
    StreamProvider<Set<String>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream<Set<String>>.value(const <String>{});
      return fbDb
          .collection('club_follows')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      '${d.data()['clubId'] ?? ''}',
                )
                .where((String id) => id.isNotEmpty)
                .toSet(),
          );
    });

/// Profilim > Takip ettiğim kulüpler (ad / logo ile).
final FutureProvider<List<FollowedClub>> followedClubsProvider =
    FutureProvider<List<FollowedClub>>((Ref ref) {
      ref.watch(currentUidProvider);
      return ref.watch(clubFollowServiceProvider).listFollowedClubs();
    });

/// Kulübün takipçi sayısı (yalnızca kulübün kendisi okur).
final StreamProvider<int> clubFollowerCountProvider = StreamProvider<int>((
  Ref ref,
) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<int>.value(0);
  return fbDb.collection('club_stats').doc(uid).snapshots().map((
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final Object? count = snap.data()?['followerCount'];
    return count is num && count > 0 ? count.toInt() : 0;
  });
});

/// Keşfet filtresi seçimi (oturum boyunca).
class FollowFilterNotifier extends Notifier<FollowFilter> {
  @override
  FollowFilter build() => FollowFilter.all;

  void select(FollowFilter filter) => state = filter;
}

final NotifierProvider<FollowFilterNotifier, FollowFilter>
followFilterProvider = NotifierProvider<FollowFilterNotifier, FollowFilter>(
  FollowFilterNotifier.new,
);
