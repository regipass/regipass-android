/// Yönetici duyurularının okunması ve gönderilmesi.
///
/// Duyurular FCM kullanmaz: yönetici Firestore'a yazar, hedef kitledeki
/// istemciler dinleyiciden görür ve cihazda bildirime çevirir
/// (bkz. features/notifications/notification_sync.dart).
/// Bunun bilinen sınırı, uygulaması tamamen kapalı olan bir kullanıcının
/// duyuruyu ancak uygulamayı bir dahaki açışında almasıdır.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification_targets.dart';
import '../models/announcement.dart';
import 'firebase_refs.dart';

class AnnouncementRepository {
  const AnnouncementRepository({this.firestore});

  final FirebaseFirestore? firestore;
  Col get _collection => (firestore ?? fbDb).collection('notifications');

  /// Genel ve üniversite duyurularını aynı akışta okur. Eski mobil
  /// kayıtlarında recipients bulunmadığı için üniversite filtresi korunur.
  /// Sıralama istemcide yapılır; ek bir bileşik dizin gerekmez.
  Stream<List<Announcement>> watchForViewer({
    required String university,
    required String role,
    required int createdAfterMs,
  }) {
    final List<String> keys = notificationViewerKeys(
      university: university,
      role: role,
    );
    if (keys.isEmpty) {
      return Stream<List<Announcement>>.value(const <Announcement>[]);
    }
    final Filter targets = Filter.or(
      Filter('recipients', arrayContainsAny: keys),
      Filter('global', isEqualTo: true),
    );
    return _collection
        .where(
          university.trim().isEmpty
              ? targets
              : Filter.or(
                  targets,
                  Filter('university', isEqualTo: university.trim()),
                ),
        )
        .snapshots()
        .map(_mapSorted)
        .map(
          (List<Announcement> all) => all
              .where(
                (Announcement a) =>
                    a.reaches(asClub: role == 'club') &&
                    a.createdAtMs > createdAfterMs,
              )
              .toList(),
        );
  }

  /// Bir üniversiteye gönderilmiş duyurular — canlı.
  ///
  /// Sorgu yalnızca eşitlik içerir; sıralama bilerek istemcide yapılır.
  /// `orderBy` eklenseydi Firestore bileşik dizin ister ve dizin
  /// oluşturulana kadar ekran boş kalırdı.
  Stream<List<Announcement>> watchForUniversity(String university) {
    if (university.trim().isEmpty) {
      return Stream<List<Announcement>>.value(const <Announcement>[]);
    }

    return _collection
        .where('university', isEqualTo: university)
        .snapshots()
        .map(_mapSorted);
  }

  /// Yöneticinin gönderdiği son duyurular.
  Stream<List<Announcement>> watchRecent({int limit = 30}) => _collection
      .orderBy('createdAtMs', descending: true)
      .limit(limit)
      .snapshots()
      .map(_mapSorted);

  List<Announcement> _mapSorted(QSnap snap) {
    final List<Announcement> list = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Announcement.fromMap(d.id, d.data()),
        )
        .toList();

    list.sort(
      (Announcement a, Announcement b) =>
          b.createdAtMs.compareTo(a.createdAtMs),
    );
    return list;
  }

  /// Duyuruyu gönderir. Yalnızca yönetici hesabında yetkilidir.
  ///
  /// Yazılan şema web yöneticisiyle ortak (bkz. [Announcement]); `message`
  /// ve `audience` firestore.rules tarafından doğrulanıyor.
  ///
  /// `createdAtMs` sunucu zaman damgası değil, istemci saatidir: sıralama ve
  /// "bundan sonrakiler yeni" karşılaştırması dinleyicide anında yapılabilsin
  /// diye. Sunucu damgası kullanılsaydı belge ilk geldiğinde alan `null`
  /// olur, duyuru bir an tarihsiz görünürdü.
  Future<void> send({
    required String title,
    required String body,
    required String audience,
    required String university,
    required String city,
    required String senderUid,
  }) => _send(
    title: title,
    body: body,
    audience: audience,
    university: university,
    city: city,
    senderUid: senderUid,
    global: false,
  );

  Future<void> _send({
    required String title,
    required String body,
    required String audience,
    required String university,
    required String city,
    required String senderUid,
    required bool global,
  }) async {
    final String cleanTitle = title.trim();
    final String cleanBody = body.trim();
    final String cleanUniversity = university.trim();
    if (cleanTitle.isEmpty ||
        cleanTitle.length > 120 ||
        cleanBody.isEmpty ||
        cleanBody.length > 1000 ||
        cleanUniversity.isEmpty ||
        senderUid.trim().isEmpty ||
        !AnnouncementAudience.isValid(audience)) {
      throw ArgumentError('Invalid notification');
    }
    final List<String> recipients = notificationRecipientKeys(
      university: cleanUniversity,
      audience: audience,
      global: global,
    );
    if (recipients.isEmpty) {
      throw ArgumentError('Empty notification recipients');
    }

    await _collection.add(<String, dynamic>{
      'title': cleanTitle,
      'body': cleanBody,
      'message': cleanBody,
      'audience': audience,
      'global': global,
      'recipients': recipients,
      'university': cleanUniversity,
      'city': city.trim(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': senderUid.trim(),
    });
  }

  Future<void> delete(String id) => _collection.doc(id).delete();

  /// Web ile aynı tek genel kaydı yazar; üniversitesi olmayanlar da alır.
  Future<void> sendBroadcast({
    required String title,
    required String body,
    required String audience,
    required String senderUid,
  }) => _send(
    title: title,
    body: body,
    audience: audience,
    senderUid: senderUid,
    university: globalNotificationUniversity,
    city: '',
    global: true,
  );
}
