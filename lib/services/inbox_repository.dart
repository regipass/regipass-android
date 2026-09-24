/// Kişiye özel gelen kutusu: `users/{uid}/inbox` (İP-6).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/inbox_entry.dart';
import 'firebase_refs.dart';

class InboxRepository {
  const InboxRepository({this.firestore});

  final FirebaseFirestore? firestore;

  static const int limit = 30;

  Col _inbox(String uid) => (firestore ?? fbDb)
      .collection(Collections.users)
      .doc(uid)
      .collection('inbox');

  /// En yeni [limit] kayıt, canlı. Tek alanlı sıralama; ek dizin gerekmez.
  Stream<List<InboxEntry>> watch(String uid) => _inbox(uid)
      .orderBy('createdAtMs', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  InboxEntry.fromMap(d.id, d.data()),
            )
            .toList(),
      );

  /// Kayıtları okundu işaretler. Kurallar yalnızca `readAtMs` alanına izin
  /// verir; başka alan eklenirse yazma reddedilir.
  Future<void> markRead(String uid, Iterable<String> ids, {int? atMs}) async {
    final List<String> unique = ids
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (unique.isEmpty) return;
    final int now = atMs ?? DateTime.now().millisecondsSinceEpoch;
    final WriteBatch batch = (firestore ?? fbDb).batch();
    for (final String id in unique) {
      batch.update(_inbox(uid).doc(id), <String, Object>{'readAtMs': now});
    }
    await batch.commit();
  }
}
