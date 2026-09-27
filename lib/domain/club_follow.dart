/// Kulüp takip (İP-TK) — saf yardımcılar. Web: js/modules/clubs/follow-core.js.
library;

/// Keşfet filtresi: "Tümü" ya da "Takip ettiklerim".
enum FollowFilter { all, following }

/// "Takip ettiklerim" seçiliyse yalnızca takip edilen kulüplerin etkinlikleri.
List<T> filterByFollow<T>(
  List<T> items,
  FollowFilter filter,
  Set<String> followedClubIds,
  String Function(T item) clubIdOf,
) {
  if (filter == FollowFilter.all) return items;
  return items
      .where((T item) => followedClubIds.contains(clubIdOf(item)))
      .toList(growable: false);
}

/// Sunucu hata nedeni → çeviri anahtarı.
String followErrorKey(String reason) => switch (reason) {
  'club-unavailable' => 'follow.error.clubUnavailable',
  'too-many-follows' => 'follow.error.tooMany',
  'account-banned' => 'follow.error.banned',
  'student-only' => 'follow.error.studentOnly',
  'sign-in-required' => 'follow.error.signIn',
  _ => 'follow.error.generic',
};

/// listFollowedClubs sonucundaki tek kulüp.
class FollowedClub {
  const FollowedClub({
    required this.clubId,
    required this.clubName,
    required this.university,
    required this.city,
    required this.logoUrl,
    required this.available,
    required this.followedAtMs,
  });

  factory FollowedClub.fromMap(Map<Object?, Object?> map) {
    String str(Object? v) => v is String ? v : '';
    final Object? at = map['followedAtMs'];
    return FollowedClub(
      clubId: str(map['clubId']),
      clubName: str(map['clubName']),
      university: str(map['university']),
      city: str(map['city']),
      logoUrl: str(map['logoUrl']),
      available: map['available'] == true,
      followedAtMs: at is num ? at.toInt() : 0,
    );
  }

  final String clubId;
  final String clubName;
  final String university;
  final String city;
  final String logoUrl;
  final bool available;
  final int followedAtMs;
}
