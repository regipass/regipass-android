// İP-KB: kulübün öğrenci engeli (lib/models/club_block.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/models/club_block.dart';

void main() {
  test('gerekçe en az 3 karakter, boşluklar tekilleşir, 300 ile kırpılır', () {
    expect(cleanClubBlockReason('  Etkinlikte   taciz \n'), 'Etkinlikte taciz');
    expect(cleanClubBlockReason('ab'), '');
    expect(cleanClubBlockReason(null), '');
    expect(cleanClubBlockReason('x' * 400).length, 300);
  });

  test('engel kaydı okunur', () {
    final ClubBlock b = ClubBlock.fromMap(<String, dynamic>{
      'studentId': 'stu1',
      'studentName': 'Ayşe Yılmaz',
      'studentUniversity': 'Ege',
      'reason': 'Taciz',
      'createdAtMs': 1790000000000,
    });
    expect(b.studentId, 'stu1');
    expect(b.createdAtMs, 1790000000000);
    expect(ClubBlock.fromMap(<String, dynamic>{}).studentName, '');
  });
}
