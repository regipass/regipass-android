/// Yönetici duyurularının okunması ve gönderilmesi.
///
/// Uygulamanın sunucu tarafı olmadığı için duyuru "push" değildir: yönetici
/// Firestore'a yazar, hedef kitledeki istemciler dinleyiciden görür ve
/// cihazda bildirime çevirir (bkz. lib/state/notification_providers.dart).
/// Bunun bilinen sınırı, uygulaması tamamen kapalı olan bir kullanıcının
/// duyuruyu ancak uygulamayı bir dahaki açışında almasıdır.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';
import 'firebase_refs.dart';

class AnnouncementRepository {
  const AnnouncementRepository();

  /// Bir üniversiteye gönderilmiş duyurular — canlı.
  ///
  /// Sorgu yalnızca eşitlik içerir; sıralama bilerek istemcide yapılır.
  /// `orderBy` eklenseydi Firestore bileşik dizin ister ve dizin
  /// oluşturulana kadar ekran boş kalırdı.
  Stream<List<Announcement>> watchForUniversity(String university) {
    if (university.trim().isEmpty) {
      return Stream<List<Announcement>>.value(const <Announcement>[]);
    }

    return announcementsCol
        .where('university', isEqualTo: university)
        .snapshots()
        .map(_mapSorted);
  }

  /// Yöneticinin gönderdiği son duyurular.
  Stream<List<Announcement>> watchRecent({int limit = 30}) => announcementsCol
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
  }) async {
    final String cleanTitle = title.trim();
    final String cleanBody = body.trim();

    // `message` firestore.rules'un ZORUNLU tuttuğu alan (boş olamaz, en çok
    // 1000 karakter) ve web yöneticisinin tek metin alanı. Mobilin başlık +
    // gövde ayrımı `title`/`body` içinde ayrıca korunur; web'den bakan
    // yönetici yine tek parça metni görür.
    final String message = <String>[
      if (cleanTitle.isNotEmpty) cleanTitle,
      if (cleanBody.isNotEmpty) cleanBody,
    ].join('\n');

    await announcementsCol.add(<String, dynamic>{
      'title': cleanTitle,
      'body': cleanBody,
      'message': message.length > 1000 ? message.substring(0, 1000) : message,
      'audience': AnnouncementAudience.isValid(audience)
          ? audience
          : AnnouncementAudience.all,
      'university': university,
      'city': city,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': senderUid,
    });
  }

  Future<void> delete(String id) => announcementsCol.doc(id).delete();
}
