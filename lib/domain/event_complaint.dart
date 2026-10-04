/// Etkinlik şikâyeti + organizatör engelleme (İP-ŞK) — saf yardımcılar.
/// Sunucu: functions/eventComplaints.js.
library;

/// Şikâyet sebepleri (sunucudaki REASONS ile aynı sıra ve adlar).
enum ComplaintReason {
  inappropriate('inappropriate'),
  fake('fake'),
  fraud('fraud'),
  spam('spam'),
  other('other');

  const ComplaintReason(this.wire);

  /// Sunucuya giden değer.
  final String wire;

  String get labelKey => 'complaint.reason.$wire';
}

const int kComplaintNoteMax = 500;

/// Gönder düğmesi açık mı? "Diğer"de kısa bir açıklama şart.
bool complaintReady(ComplaintReason? reason, String note) {
  if (reason == null) return false;
  final String trimmed = note.trim();
  if (trimmed.length > kComplaintNoteMax) return false;
  if (reason == ComplaintReason.other && trimmed.length < 3) return false;
  return true;
}

/// Engellenen organizatörlerin etkinlikleri listeden çıkar.
List<T> hideBlockedOrganizers<T>(
  List<T> items,
  Set<String> blockedClubIds,
  String Function(T item) clubIdOf,
) {
  if (blockedClubIds.isEmpty) return items;
  return items
      .where((T item) => !blockedClubIds.contains(clubIdOf(item)))
      .toList(growable: false);
}

/// Sunucu hata nedeni → çeviri anahtarı.
String complaintErrorKey(String reason) => switch (reason) {
  'sign-in-required' => 'complaint.error.signIn',
  'student-only' => 'complaint.error.studentOnly',
  'own-event' => 'complaint.error.ownEvent',
  'event-not-found' => 'complaint.error.notFound',
  'note-required' => 'complaint.error.noteRequired',
  'too-many-blocks' => 'complaint.error.tooManyBlocks',
  _ => 'complaint.error.generic',
};

/// listBlockedOrganizers sonucundaki tek organizatör.
class BlockedOrganizer {
  const BlockedOrganizer({
    required this.clubId,
    required this.clubName,
    required this.logoUrl,
  });

  factory BlockedOrganizer.fromMap(Map<Object?, Object?> map) {
    String str(Object? v) => v is String ? v : '';
    return BlockedOrganizer(
      clubId: str(map['clubId']),
      clubName: str(map['clubName']),
      logoUrl: str(map['logoUrl']),
    );
  }

  final String clubId;
  final String clubName;
  final String logoUrl;
}
