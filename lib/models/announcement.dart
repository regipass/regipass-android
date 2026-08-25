/// `notifications/{id}` — yöneticinin bir üniversiteye gönderdiği duyuru.
///
/// Şema web yöneticisiyle ORTAK (js/modules/notifications/notifications.js):
/// zorunlu alan `message`, hedef kitle `student` | `club` | `both`.
/// firestore.rules bu alanları doğruluyor; başka bir kelime dağarcığıyla
/// yazılan belge reddedilir. `title`/`body` yalnızca mobilin eklediği ek
/// alanlardır — web'den gelen duyurularda bulunmaz, o yüzden okurken
/// `message` yedeğe düşer.
///
/// Gönderim yalnızca yönetici hesabına açıktır, okuma hedef kitledeki
/// herkese.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'profiles.dart';

/// Duyurunun kime gittiği (`notifications.audience`).
///
/// Değerler firestore.rules'taki `audience in ["student", "club", "both"]`
/// listesiyle birebir aynı olmak zorunda.
class AnnouncementAudience {
  static const String students = 'student';
  static const String clubs = 'club';
  static const String all = 'both';

  static const List<String> values = <String>[students, clubs, all];

  static bool isValid(String? value) => values.contains(value);

  /// Duyuru, verilen role sahip bir kullanıcıya görünür mü?
  static bool reaches(String audience, {required bool asClub}) =>
      audience == all || audience == (asClub ? clubs : students);
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.university,
    required this.city,
    required this.createdAtMs,
    required this.createdBy,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final String audience = asString(data['audience']);
    return Announcement(
      id: id,
      title: asString(data['title']),
      // Web yöneticisi tek bir `message` alanı yazıyor; başlıksız gelen
      // duyurunun metni kaybolmasın diye gövde oraya düşer.
      body: asString(data['body']).isNotEmpty
          ? asString(data['body'])
          : asString(data['message']),
      audience: AnnouncementAudience.isValid(audience)
          ? audience
          : AnnouncementAudience.all,
      university: asString(data['university']),
      city: asString(data['city']),
      createdAtMs: asEpochMilliseconds(data['createdAtMs']) ?? 0,
      createdBy: asString(data['createdBy']),
    );
  }

  static Announcement? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.exists ? Announcement.fromMap(doc.id, doc.data()!) : null;

  final String id;
  final String title;
  final String body;

  /// [AnnouncementAudience] değerlerinden biri.
  final String audience;

  /// Hedef üniversite. Duyurular her zaman tek bir üniversiteye gönderilir —
  /// yönetici ekranındaki liste üniversite üzerinden kuruluyor.
  final String university;

  /// Üniversitenin şehri; yalnızca gösterim için tutulur.
  final String city;

  final int createdAtMs;
  final String createdBy;

  bool reaches({required bool asClub}) =>
      AnnouncementAudience.reaches(audience, asClub: asClub);
}
