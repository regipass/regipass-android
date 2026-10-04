/// Etkinlik şikâyeti + organizatör engelleme (İP-ŞK).
///
/// Yazma yalnızca sunucu çağrılarıyla (`reportEvent`, `blockOrganizer`).
/// Katılımcı kendi engel kayıtlarını (`organizer_blocks`, uid == kendisi)
/// canlı dinler; Keşfet engellenen organizatörün etkinliklerini göstermez.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/event_complaint.dart';
import '../state/providers.dart';
import 'firebase_refs.dart';

class EventComplaintService {
  const EventComplaintService();

  Future<void> reportEvent({
    required String eventId,
    required ComplaintReason reason,
    String note = '',
  }) async {
    await fbFunctions.httpsCallable('reportEvent').call(<String, Object>{
      'eventId': eventId,
      'reason': reason.wire,
      'note': note.trim(),
    });
  }

  Future<void> setBlocked(String clubId, {required bool block}) async {
    await fbFunctions.httpsCallable('blockOrganizer').call(<String, Object>{
      'clubId': clubId,
      'block': block,
    });
  }

  Future<List<BlockedOrganizer>> listBlocked() async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('listBlockedOrganizers')
        .call(<String, Object>{});
    final Object? data = result.data;
    final Object? list = data is Map ? data['organizers'] : null;
    if (list is! List) return const <BlockedOrganizer>[];
    return list
        .whereType<Map<Object?, Object?>>()
        .map(BlockedOrganizer.fromMap)
        .toList(growable: false);
  }
}

/// Sunucunun döndürdüğü hata nedeni (details.reason).
String complaintErrorReason(Object error) {
  if (error is FirebaseFunctionsException) {
    final Object? details = error.details;
    if (details is Map && details['reason'] is String) {
      return details['reason'] as String;
    }
    return error.message ?? '';
  }
  return '';
}

final Provider<EventComplaintService> eventComplaintServiceProvider =
    Provider<EventComplaintService>(
      (Ref ref) => const EventComplaintService(),
    );

/// Katılımcının engellediği organizatör kimlikleri (canlı).
final StreamProvider<Set<String>> blockedOrganizerIdsProvider =
    StreamProvider<Set<String>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream<Set<String>>.value(const <String>{});
      return fbDb
          .collection('organizer_blocks')
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

/// Hesabım > Engellediğim organizatörler (ad / logo ile).
final FutureProvider<List<BlockedOrganizer>> blockedOrganizersProvider =
    FutureProvider<List<BlockedOrganizer>>((Ref ref) {
      ref.watch(currentUidProvider);
      // Engel listesi değişince yeniden yüklenir.
      ref.watch(blockedOrganizerIdsProvider);
      return ref.watch(eventComplaintServiceProvider).listBlocked();
    });
