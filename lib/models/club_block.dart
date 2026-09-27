/// Kulübün kendi etkinliklerinden engellediği öğrenci (İP-KB).
///
/// `club_student_blocks/{clubId}_{studentId}` belgesi; yalnızca sunucu yazar
/// (functions/registrations.js#clubBlockStudent). Öğrenci bu belgeyi okuyamaz.
library;

class ClubBlock {
  const ClubBlock({
    required this.studentId,
    required this.studentName,
    required this.studentUniversity,
    required this.reason,
    required this.createdAtMs,
  });

  factory ClubBlock.fromMap(Map<String, dynamic> map) => ClubBlock(
    studentId: '${map['studentId'] ?? ''}',
    studentName: '${map['studentName'] ?? ''}',
    studentUniversity: '${map['studentUniversity'] ?? ''}',
    reason: '${map['reason'] ?? ''}',
    createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
  );

  final String studentId;
  final String studentName;
  final String studentUniversity;
  final String reason;
  final int createdAtMs;
}

/// Gerekçe en az 3, en fazla 300 karakter (sunucuyla aynı). Geçersizse ''.
String cleanClubBlockReason(String? value) {
  String text = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > 300) text = text.substring(0, 300);
  return text.length >= 3 ? text : '';
}
