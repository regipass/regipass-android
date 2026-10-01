import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/legal_docs.dart';
import 'package:regipass/domain/legal_reconsent.dart';
import 'package:regipass/models/profiles.dart';

AppUser _user(Map<String, dynamic> data) => AppUser.fromMap('u1', data);

void main() {
  test('sürüm v1.1', () {
    expect(kLegalDocsVersion, 'v1.1');
  });

  test('onayı hiç olmayan hesap yeniden onaya düşmez', () {
    expect(needsLegalReconsent(_user(<String, dynamic>{})), isFalse);
    expect(needsLegalReconsent(null), isFalse);
  });

  test('eski mobil onay → yeniden onay', () {
    expect(
      needsLegalReconsent(_user(<String, dynamic>{
        'termsAccepted': true,
        'termsVersion': '2026-09-02',
      })),
      isTrue,
    );
  });

  test('eski web onayı → yeniden onay', () {
    expect(
      needsLegalReconsent(_user(<String, dynamic>{
        'consent': <String, dynamic>{
          'tosAndKvkk': <String, dynamic>{'given': true, 'version': 'v1.0'},
        },
      })),
      isTrue,
    );
  });

  test('web ya da mobilde güncel sürüm onaylıysa ekran çıkmaz', () {
    expect(
      needsLegalReconsent(_user(<String, dynamic>{
        'consent': <String, dynamic>{
          'tosAndKvkk': <String, dynamic>{'given': true, 'version': 'v1.1'},
        },
        'termsAccepted': true,
        'termsVersion': '2026-09-02',
      })),
      isFalse,
    );
    expect(
      needsLegalReconsent(_user(<String, dynamic>{
        'termsAccepted': true,
        'termsVersion': 'v1.1',
      })),
      isFalse,
    );
  });
}
