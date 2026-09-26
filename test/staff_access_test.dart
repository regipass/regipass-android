// İP-M1: yönetim oturumu (lib/domain/staff_access.dart) ve engelleme gerekçesi.
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/staff_access.dart';
import 'package:regipass/features/admin/ban_decision_dialog.dart';

const Map<String, dynamic> _totp = <String, dynamic>{
  'sign_in_provider': 'password',
  'sign_in_second_factor': 'totp',
};

void main() {
  test('yetki yalnızca rol etiketinden okunur', () {
    expect(
      StaffAccess.fromClaims(<String, dynamic>{
        'role': 'admin',
        'firebase': _totp,
      }).state,
      StaffAccessState.ready,
    );
    expect(
      StaffAccess.fromClaims(<String, dynamic>{
        'role': 'root',
        'firebase': _totp,
      }).state,
      StaffAccessState.notStaff,
    );
    expect(
      StaffAccess.fromClaims(<String, dynamic>{
        'email': 'a@regipass.app',
      }).isStaff,
      isFalse,
      reason: 'e-posta artık yetki vermez',
    );
    expect(StaffAccess.fromClaims(null), StaffAccess.none);
  });

  test('kodsuz oturum panele giremez; destek yazamaz', () {
    final StaffAccess noCode = StaffAccess.fromClaims(<String, dynamic>{
      'role': 'admin',
      'firebase': <String, dynamic>{'sign_in_provider': 'password'},
    });
    expect(noCode.state, StaffAccessState.needsSetup);
    expect(noCode.isStaff, isFalse);
    expect(noCode.canWrite, isFalse);

    final StaffAccess sms = StaffAccess.fromClaims(<String, dynamic>{
      'role': 'admin',
      'firebase': <String, dynamic>{'sign_in_second_factor': 'phone'},
    });
    expect(sms.isStaff, isFalse);

    final StaffAccess support = StaffAccess.fromClaims(<String, dynamic>{
      'role': 'support',
      'firebase': _totp,
    });
    expect(support.isStaff, isTrue);
    expect(support.canWrite, isFalse);

    final StaffAccess admin = StaffAccess.fromClaims(<String, dynamic>{
      'role': 'admin',
      'firebase': _totp,
    });
    expect(admin.canWrite, isTrue);
  });

  test('TOTP kodu biçimi', () {
    expect(normalizeTotpCode(' 123 456 '), '123456');
    expect(normalizeTotpCode('12345'), '');
    expect(normalizeTotpCode('12a456'), '');
    expect(normalizeTotpCode(null), '');
  });

  test('engelleme gerekçesi temizlenir ve kırpılır', () {
    expect(cleanBanReason('  Sahte   hesap \n'), 'Sahte hesap');
    expect(cleanBanReason(''), '');
    expect(cleanBanReason('x' * 400).length, kBanReasonMaxLength);
  });
}
