/// Kulüp profil değişikliği onayı (İP-KP) — js/modules/club/profile-change.js.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile_change.dart';
import '../state/providers.dart';
import 'firebase_refs.dart';

class ClubProfileChangeService {
  const ClubProfileChangeService();

  /// Değişiklik ister; onay öncesi aşamadaki kulüpte sunucu doğrudan uygular.
  Future<String> request(Map<String, Object> changes) async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('clubRequestProfileChange')
        .call(<String, Object>{'changes': changes});
    final Object? data = result.data;
    return data is Map ? '${data['status'] ?? ''}' : '';
  }

  Future<void> cancel() async {
    await fbFunctions
        .httpsCallable('clubCancelProfileChange')
        .call(<String, Object>{});
  }
}

final Provider<ClubProfileChangeService> clubProfileChangeServiceProvider =
    Provider<ClubProfileChangeService>(
      (Ref ref) => const ClubProfileChangeService(),
    );

/// Kulübün son değişiklik isteği (canlı).
// ignore: always_specify_types
final clubProfileChangeProvider = StreamProvider<ClubProfileChange?>((Ref ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<ClubProfileChange?>.value(null);
  return fbDb
      .collection('club_profile_changes')
      .doc(uid)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, dynamic>> snap) =>
            snap.exists ? ClubProfileChange.fromMap(snap.data()!) : null,
      );
});
