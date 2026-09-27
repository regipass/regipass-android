/// Kulüp profil değişikliği onayı (İP-KP) — js/modules/club/profile-change-diff.js.
///
/// Onaylı kulübün adı, üniversitesi / ili, amaç / içerik metinleri, alanları
/// ve logosu doğrudan değişmez; değişiklik yöneticinin onayına gider
/// (functions/clubProfileChanges.js). Liste firestore.rules ile AYNI.
library;

const List<String> kGatedClubKeys = <String>[
  'clubName',
  'university',
  'city',
  'clubPurpose',
  'clubContents',
  'clubFields',
];

String _norm(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Formdaki değerlerden mevcut profile göre DEĞİŞENLER (yalnızca onaya bağlı alanlar).
Map<String, Object> gatedClubChanges({
  required Map<String, String> current,
  required List<String> currentFields,
  required Map<String, String> next,
  required List<String> nextFields,
}) {
  final Map<String, Object> out = <String, Object>{};
  for (final String key in kGatedClubKeys) {
    if (key == 'clubFields') continue;
    final String value = _norm(next[key] ?? '');
    if (value.isNotEmpty && value != _norm(current[key] ?? '')) {
      out[key] = next[key]!;
    }
  }
  final List<String> a = nextFields
      .map(_norm)
      .where((String v) => v.isNotEmpty)
      .toList();
  final List<String> b = currentFields.map(_norm).toList();
  final bool same =
      a.length == b.length &&
      List<bool>.generate(
        a.length,
        (int i) => a[i] == b[i],
      ).every((bool x) => x);
  if (a.isNotEmpty && !same) out['clubFields'] = a;
  return out;
}

/// Bekleyen / sonuçlanmış istek (club_profile_changes/{uid}).
class ClubProfileChange {
  const ClubProfileChange({
    required this.status,
    required this.after,
    required this.before,
    required this.note,
    required this.requestedAtMs,
    required this.reviewedAtMs,
  });

  factory ClubProfileChange.fromMap(Map<String, dynamic> data) {
    Map<String, Object?> map(Object? raw) => raw is Map
        ? raw.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v))
        : <String, Object?>{};
    return ClubProfileChange(
      status: '${data['status'] ?? ''}',
      after: map(data['after']),
      before: map(data['before']),
      note: '${data['note'] ?? ''}',
      requestedAtMs: (data['requestedAtMs'] as num?)?.toInt() ?? 0,
      reviewedAtMs: (data['reviewedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  final String status;
  final Map<String, Object?> after;
  final Map<String, Object?> before;
  final String note;
  final int requestedAtMs;
  final int reviewedAtMs;

  bool get isPending => status == 'pending';

  /// Son 14 günde reddedildiyse kulübe gösterilir.
  bool recentlyRejected(int nowMs) =>
      status == 'rejected' && nowMs - reviewedAtMs < 14 * 24 * 3600 * 1000;

  static String _text(Object? v) => v is List
      ? v.map((Object? e) => '$e').join(', ')
      : (v == null ? '' : '$v');

  /// Okunur satırlar: (alan anahtarı, eski, yeni). Logo yolu atlanır.
  List<({String key, String before, String after})> rows() => after.keys
      .where((String k) => k != 'logoPath')
      .map(
        (String k) =>
            (key: k, before: _text(before[k]), after: _text(after[k])),
      )
      .toList();
}
