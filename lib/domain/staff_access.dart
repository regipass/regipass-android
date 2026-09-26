/// Yönetim oturumu (İP-M1) — js/modules/admin/staff-session.js karşılığı.
///
/// Yönetici yetkisi artık e-posta adresinden (eski "a" / a@regipass.app)
/// DEĞİL, sunucunun verdiği rol etiketinden (custom claim) gelir:
///   role: 'admin'   → tam yetki
///   role: 'support' → yalnızca görür
/// Ayrıca oturum doğrulayıcı uygulama koduyla (TOTP) açılmış olmalıdır.
/// firestore.rules#isAdmin / isStaff ve functions/adminAccounts.js aynı iki
/// şartı arar; buradaki kontrol yalnızca doğru ekranı göstermek içindir.
library;

const List<String> kStaffRoles = <String>['admin', 'support'];

enum StaffAccessState {
  /// Rol var + oturum kodla açılmış.
  ready,

  /// Rol var ama oturum kodsuz (doğrulayıcı henüz kurulmamış).
  needsSetup,

  /// Yönetim hesabı değil.
  notStaff,
}

class StaffAccess {
  const StaffAccess({this.role, this.hasTotp = false});

  static const StaffAccess none = StaffAccess();

  /// ID token iddialarından (`IdTokenResult.claims`) okur.
  factory StaffAccess.fromClaims(Map<String, dynamic>? claims) {
    final Object? rawRole = claims?['role'];
    final String? role = rawRole is String && kStaffRoles.contains(rawRole)
        ? rawRole
        : null;
    final Object? firebase = claims?['firebase'];
    final bool totp =
        firebase is Map && firebase['sign_in_second_factor'] == 'totp';
    return StaffAccess(role: role, hasTotp: totp);
  }

  final String? role;
  final bool hasTotp;

  StaffAccessState get state {
    if (role == null) return StaffAccessState.notStaff;
    return hasTotp ? StaffAccessState.ready : StaffAccessState.needsSetup;
  }

  /// Yönetim paneline girebilir (yönetici ya da destek, kodla açılmış oturum).
  bool get isStaff => state == StaffAccessState.ready;

  /// Yazma işlemleri (engelle, onayla, duyuru) yalnızca yönetici.
  bool get canWrite => isStaff && role == 'admin';

  @override
  bool operator ==(Object other) =>
      other is StaffAccess && other.role == role && other.hasTotp == hasTotp;

  @override
  int get hashCode => Object.hash(role, hasTotp);
}

/// 6 haneli kod: boşluklar atılır, yalnızca rakam kabul edilir. Değilse ''.
String normalizeTotpCode(String? value) {
  final String digits = (value ?? '').replaceAll(RegExp(r'\s+'), '');
  return RegExp(r'^\d{6}$').hasMatch(digits) ? digits : '';
}
