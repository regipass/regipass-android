/// Hesap ayarları alt sayfasının "Güvenlik" bölümü: şifre değiştirme ve
/// hesabı silme.
///
/// İkisi de Firebase'in **hassas işlem** grubundadır: son girişin üzerinden
/// birkaç dakikadan fazla geçtiyse doğrudan çağrıldıklarında
/// `requires-recent-login` ile düşerler. Bu yüzden ikisi de kullanıcıdan
/// mevcut şifresini ister ve işlemden hemen önce yeniden kimlik doğrular.
/// Şifreyi sormanın ikinci ve asıl nedeni güvenlik: açık kalmış bir telefonu
/// eline geçiren biri şifreyi bilmeden ne şifreyi değiştirebilmeli ne de
/// hesabı yok edebilmeli.
///
/// Eski şifresini hatırlamayan kullanıcı için ikinci kapı, hesabın Auth'a
/// bağlı numarasına gelen SMS kodudur — giriş ekranındaki "şifremi unuttum"
/// akışının (`forgot_password_screen.dart`) oturum içi eşi. Orada kullanıcı
/// numarasını elle yazmak zorundadır çünkü kimliğini henüz kanıtlamamıştır;
/// burada oturum zaten açık olduğu için numara doğrudan gösterilir.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../l10n/app_strings.dart';
import '../../services/account_mail_service.dart';
import '../../services/auth_repository.dart';
import '../../state/providers.dart';
import '../auth/phone_auth_errors.dart';
import 'common_widgets.dart';
import 'phone_field.dart';

/// Hesap ayarları alt sayfasının güvenlik bölümü (bkz.
/// `account_settings_sheet.dart`).
class AccountSecurityCard extends ConsumerWidget {
  const AccountSecurityCard({this.onAccountDeleted, super.key});

  /// Hesap gerçekten silindiğinde çağrılır.
  ///
  /// Silme oturumu kapatır ve router giriş ekranına döner; ama bu kart bir
  /// alt sayfanın içinde yaşıyorsa o sayfa kök gezginde durduğu için
  /// kendiliğinden kapanmaz ve giriş ekranının üstünde asılı kalırdı.
  final VoidCallback? onAccountDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: context.brandInk,
              ),
              const SizedBox(width: 8),
              Text(
                context.t('accountSecurity.title'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _SecurityTile(
            icon: Icons.lock_outline,
            label: context.t('accountSecurity.changePassword'),
            description: context.t('accountSecurity.changePasswordDesc'),
            onTap: () async {
              final bool changed = await showChangePasswordDialog(context);
              if (changed && context.mounted) {
                showTopFeedback(
                  context,
                  context.t('changePassword.feedback.success'),
                  tone: FeedbackTone.success,
                );
              }
            },
          ),
          Divider(color: context.hairline, height: 1),
          _SecurityTile(
            icon: Icons.delete_forever_outlined,
            label: context.t('accountSecurity.deleteAccount'),
            description: context.t('accountSecurity.deleteAccountDesc'),
            danger: true,
            // Silme başarılıysa router kullanıcıyı giriş ekranına alır ve
            // açıklamayı orada `signOutNoticeProvider` gösterir; burada
            // gösterilecek bir ekran kalmıyor — yalnızca bu kartı taşıyan
            // alt sayfa varsa o kapatılır.
            onTap: () async {
              final bool deleted = await showDeleteAccountDialog(context);
              if (deleted) onAccountDeleted?.call();
            },
          ),
        ],
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? BrandColors.danger : context.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: context.inkMuted),
          ],
        ),
      ),
    );
  }
}

// ── Şifre değiştirme ──────────────────────────────────────────────────

/// Şifre değiştirme pop-up'ı. Şifre gerçekten değiştiyse `true` döner.
Future<bool> showChangePasswordDialog(BuildContext context) async {
  final bool? changed = await showDialog<bool>(
    context: context,
    // Dışına dokununca kapanmaz: yarım doldurulmuş bir form ve gönderilmiş
    // bir SMS kodu yanlışlıkla çöpe gitmesin.
    barrierDismissible: false,
    builder: (BuildContext _) => const _ChangePasswordDialog(),
  );
  return changed ?? false;
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _saving = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// SMS ile yeniden kimlik doğrulandı mı? Doğrulandıysa mevcut şifre alanı
  /// kalkar — kullanıcı zaten şifreyi hatırlamadığı için bu yolu seçti.
  bool _verifiedByPhone = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Google/Apple ile açılmış ve henüz şifre bağlanmamış hesap (onboarding
  /// bunu şart koşuyor, yine de savunmada kalıyoruz): sorulacak eski şifre
  /// yok, yeni şifre `linkPassword` ile bağlanır.
  bool get _hasPassword {
    final User? user = ref.read(sessionProvider).user;
    return user != null &&
        ref.read(authRepositoryProvider).hasPasswordProvider(user);
  }

  bool get _needsCurrentPassword => _hasPassword && !_verifiedByPhone;

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.error]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _verifyByPhone() async {
    final String phone = accountPhoneE164(ref.read(sessionProvider));
    if (phone.isEmpty) {
      _setFeedback(context.t('accountSecurity.error.noPhone'));
      return;
    }

    final bool verified = await showPhoneReauthDialog(context, phoneE164: phone);
    if (!verified || !mounted) return;

    setState(() {
      _verifiedByPhone = true;
      _current.clear();
    });
    _setFeedback(
      context.t('changePassword.feedback.phoneVerified'),
      FeedbackTone.success,
    );
  }

  Future<void> _submit() async {
    final String current = _current.text;
    final String next = _next.text;

    if (_needsCurrentPassword && current.isEmpty) {
      _setFeedback(context.t('changePassword.feedback.currentRequired'));
      return;
    }
    if (next.isEmpty || _confirm.text.isEmpty) {
      _setFeedback(context.t('auth.feedback.passwordRequired'));
      return;
    }
    if (!isStrongPassword(next)) {
      _setFeedback(context.t('auth.error.weakPassword'));
      return;
    }
    if (next != _confirm.text) {
      _setFeedback(context.t('auth.feedback.passwordMismatch'));
      return;
    }
    if (_needsCurrentPassword && next == current) {
      _setFeedback(context.t('changePassword.feedback.sameAsCurrent'));
      return;
    }

    final AuthRepository auth = ref.read(authRepositoryProvider);
    final User? user = ref.read(sessionProvider).user;
    if (user == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    _setFeedback(null);

    try {
      // Eski şifreyi doğrulamanın tek yolu onunla yeniden giriş yapmak;
      // istemci elindeki şifrenin doğru olup olmadığını kendi başına bilemez.
      if (_needsCurrentPassword) {
        await auth.reauthenticateWithPassword(current);
      }

      if (_hasPassword) {
        await auth.updatePassword(next);
        unawaited(notifyPasswordChanged('change'));
      } else {
        await auth.linkPassword(user, next);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _setFeedback(describeSensitiveActionError(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: context.t(
        _hasPassword
            ? 'accountSecurity.changePassword'
            : 'accountSecurity.setPassword',
      ),
      subtitle: context.t(
        _needsCurrentPassword
            ? 'changePassword.subtitle'
            : 'changePassword.subtitleVerified',
      ),
      onClose: _saving ? null : () => Navigator.of(context).pop(false),
      children: <Widget>[
        FeedbackBanner(message: _feedback, tone: _tone),

        if (_needsCurrentPassword) ...<Widget>[
          _PasswordField(
            controller: _current,
            label: context.t('changePassword.currentPassword'),
            obscure: _obscureCurrent,
            enabled: !_saving,
            onToggleObscure: () =>
                setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving ? null : _verifyByPhone,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(context.t('changePassword.forgotCurrent')),
            ),
          ),
        ] else
          const SizedBox(height: 4),

        _PasswordField(
          controller: _next,
          label: context.t('changePassword.newPassword'),
          obscure: _obscureNext,
          enabled: !_saving,
          onToggleObscure: () => setState(() => _obscureNext = !_obscureNext),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _PasswordField(
          controller: _confirm,
          label: context.t('changePassword.newPasswordConfirm'),
          obscure: _obscureNext,
          enabled: !_saving,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Text(
          context.t(
            isStrongPassword(_next.text)
                ? 'auth.passwordPolicyValid'
                : 'auth.passwordPolicyHint',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const _ButtonSpinner()
              : Text(context.t('changePassword.submit')),
        ),
      ],
    );
  }
}

// ── Hesabı silme ──────────────────────────────────────────────────────

/// Hesap silme pop-up'ı. Hesap silindiyse `true` döner — ama o noktada
/// kullanıcı zaten giriş ekranına yönlendirilmiş olur.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final bool? deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext _) => const _DeleteAccountDialog(),
  );
  return deleted ?? false;
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _deleting = false;

  /// Şifresi olmayan (yalnız Google/Apple) hesabın kimliği SMS ile
  /// doğrulanır; doğrulanana kadar silme düğmesi çalışmaz.
  bool _verifiedByPhone = false;

  String? _feedback;
  FeedbackTone _tone = FeedbackTone.error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _hasPassword {
    final User? user = ref.read(sessionProvider).user;
    return user != null &&
        ref.read(authRepositoryProvider).hasPasswordProvider(user);
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.error]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _verifyByPhone() async {
    final String phone = accountPhoneE164(ref.read(sessionProvider));
    if (phone.isEmpty) {
      _setFeedback(context.t('accountSecurity.error.noPhone'));
      return;
    }

    final bool verified = await showPhoneReauthDialog(context, phoneE164: phone);
    if (!verified || !mounted) return;

    setState(() => _verifiedByPhone = true);
    _setFeedback(
      context.t('deleteAccount.feedback.phoneVerified'),
      FeedbackTone.success,
    );
  }

  Future<void> _delete() async {
    if (_hasPassword && _password.text.isEmpty) {
      _setFeedback(context.t('deleteAccount.feedback.passwordRequired'));
      return;
    }
    if (!_hasPassword && !_verifiedByPhone) {
      _setFeedback(context.t('deleteAccount.feedback.verifyFirst'));
      return;
    }

    final Session session = ref.read(sessionProvider);
    final User? user = session.user;
    if (user == null) return;

    // Silme sırasında oturum kapanacağı için router bu ekranı değiştirir;
    // `ref` ve `context` okumaları o âna kadar bitmiş olmalı.
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final cleanup = ref.read(accountCleanupRepositoryProvider);
    final roleSessionStore = ref.read(roleSessionStoreProvider);
    final notice = ref.read(signOutNoticeProvider.notifier);
    final pendingRole = ref.read(pendingOnboardingRoleProvider.notifier);

    FocusScope.of(context).unfocus();
    setState(() => _deleting = true);
    _setFeedback(null);

    try {
      if (_hasPassword) {
        await auth.reauthenticateWithPassword(_password.text);
      }

      await cleanup.deleteAccount(
        user: user,
        studentProfile: session.studentProfile,
        clubProfile: session.clubProfile,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _setFeedback(describeSensitiveActionError(context, error));
      return;
    }

    // Giriş ekranı hesabın neden yok olduğunu buradan öğrenir; aksi hâlde
    // kullanıcı kendini açıklamasız bir giriş formunda bulurdu.
    notice.show('deleteAccount.notice.done');
    if (mounted) Navigator.of(context).pop(true);

    // Cihazda kalan rol seçimi ve Google oturumu: hesap gitti, bunlar da
    // gitmeli ki bir sonraki giriş temiz başlasın.
    await roleSessionStore.clear();
    await auth.signOut();
    pendingRole.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: context.t('accountSecurity.deleteAccount'),
      subtitle: context.t('deleteAccount.subtitle'),
      onClose: _deleting ? null : () => Navigator.of(context).pop(false),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: BrandColors.dangerBg,
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_outlined,
                size: 20,
                color: BrandColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('deleteAccount.warning'),
                  style: const TextStyle(
                    color: BrandColors.danger,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FeedbackBanner(message: _feedback, tone: _tone),

        if (_hasPassword)
          _PasswordField(
            controller: _password,
            label: context.t('deleteAccount.passwordLabel'),
            obscure: _obscure,
            enabled: !_deleting,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onSubmitted: (_) => _delete(),
          )
        else
          OutlinedButton.icon(
            onPressed: _deleting || _verifiedByPhone ? null : _verifyByPhone,
            icon: Icon(
              _verifiedByPhone ? Icons.check_circle_outline : Icons.sms_outlined,
            ),
            label: Text(context.t('deleteAccount.verifyByPhone')),
          ),

        const SizedBox(height: 16),
        FilledButton(
          onPressed: _deleting ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: BrandColors.danger),
          child: _deleting
              ? const _ButtonSpinner()
              : Text(context.t('deleteAccount.submit')),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: Text(context.t('common.cancel')),
        ),
      ],
    );
  }
}

// ── SMS ile yeniden kimlik doğrulama ──────────────────────────────────

/// Oturumdaki hesabı, Auth'a bağlı numarasına gönderilen SMS koduyla yeniden
/// doğrular. Doğrulandıysa `true` döner.
///
/// Numara hesaba doğrulama sırasında bağlandığı için (bkz.
/// `phone_verify_sheet.dart`) Firebase bu kimlik bilgisini aynı hesapla
/// eşleştirir; başka bir numaranın kodu `user-mismatch` ile reddedilir.
Future<bool> showPhoneReauthDialog(
  BuildContext context, {
  required String phoneE164,
}) async {
  final bool? verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext _) => _PhoneReauthDialog(phoneE164: phoneE164),
  );
  return verified ?? false;
}

class _PhoneReauthDialog extends ConsumerStatefulWidget {
  const _PhoneReauthDialog({required this.phoneE164});

  final String phoneE164;

  @override
  ConsumerState<_PhoneReauthDialog> createState() => _PhoneReauthDialogState();
}

enum _ReauthStep { idle, sending, code }

class _PhoneReauthDialogState extends ConsumerState<_PhoneReauthDialog> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  _ReauthStep _step = _ReauthStep.idle;
  String? _verificationId;
  bool _applying = false;
  int _wrongCodeAttempts = 0;
  int _resendIn = 0;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Pencere bir kez kapandıktan sonraki ikinci pop çağrısı ALTTAKİ ekranı
  /// kapatır; Android'in otomatik doğrulaması ile kullanıcının elle onayı
  /// yarışabildiği için kapanış tek noktadan yapılır.
  bool _closing = false;

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _close(bool verified) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(verified);
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  void _startResendCooldown([int seconds = 60]) {
    setState(() => _resendIn = seconds);

    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendIn--);
      return _resendIn > 0;
    });
  }

  Future<void> _sendCode() async {
    setState(() => _step = _ReauthStep.sending);
    _setFeedback(context.t('phoneVerify.feedback.sending'));

    // Sahiplik dizinine dokunulmaz: numara zaten bu hesabın doğrulanmış
    // numarası, rezerve edilecek yeni bir şey yok.
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneE164,
        verificationCompleted: (PhoneAuthCredential credential) =>
            _applyCredential(credential),
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted || _applying) return;
          setState(() => _step = _ReauthStep.idle);
          _setFeedback(_describeError(error), FeedbackTone.error);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted || _applying) return;
          setState(() {
            _verificationId = verificationId;
            _step = _ReauthStep.code;
            _wrongCodeAttempts = 0;
          });
          _setFeedback(
            context.t('phoneVerify.feedback.codeSent'),
            FeedbackTone.success,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _codeFocus.requestFocus();
          });
          _startResendCooldown();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _verificationId = verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _step = _ReauthStep.idle);
      _setFeedback(_describeError(error), FeedbackTone.error);
    }
  }

  Future<void> _confirmCode() async {
    final String code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _setFeedback(context.t('phoneVerify.error.codeFormat'), FeedbackTone.error);
      return;
    }
    final String? verificationId = _verificationId;
    if (verificationId == null) return;

    await _applyCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ),
    );
  }

  /// Aynı kimlik bilgisi iki kez işlenmesin: Android'in otomatik doğrulaması
  /// ile elle girilen kod yarışabiliyor ve ikinci deneme "kod zaten
  /// kullanıldı" hatasıyla başarılı adımı geri alıyor.
  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    if (_applying) return;
    setState(() => _applying = true);
    _setFeedback(context.t('phoneVerify.feedback.confirming'));

    try {
      await ref
          .read(authRepositoryProvider)
          .reauthenticateWithPhoneCredential(credential);
      _close(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _step = _ReauthStep.code;
      });
      _setFeedback(_describeError(error), FeedbackTone.error);
    }
  }

  String _describeError(Object error) {
    if (isWrongCodeError(error)) _wrongCodeAttempts++;

    // Kod başka bir hesabın numarasına aitse Firebase bunu `user-mismatch`
    // ile döndürür; ortak çevirici bu kodu tanımıyor.
    final String code = error is FirebaseAuthException ? error.code : '';
    if (code == 'user-mismatch' || code == 'user-not-found') {
      return context.t('accountSecurity.error.phoneMismatch');
    }

    return describePhoneAuthError(
      context,
      error,
      wrongCodeAttempts: _wrongCodeAttempts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _step == _ReauthStep.sending || _applying;

    return _DialogShell(
      title: context.t('accountSecurity.phoneReauth.title'),
      subtitle: context.t('accountSecurity.phoneReauth.subtitle'),
      onClose: busy ? null : () => _close(false),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.subtleFill,
            border: Border.all(color: context.hairline),
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.sms_outlined, size: 20, color: BrandColors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formatE164ForDisplay(widget.phoneE164),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FeedbackBanner(message: _feedback, tone: _tone),

        if (_step == _ReauthStep.code) ...<Widget>[
          TextField(
            controller: _code,
            focusNode: _codeFocus,
            enabled: !_applying,
            keyboardType: TextInputType.number,
            autofillHints: const <String>[AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 10,
              fontWeight: FontWeight.w700,
            ),
            inputFormatters: digitsInput(InputLimits.verificationCode),
            decoration: const InputDecoration(hintText: '••••••'),
            onChanged: (String value) {
              if (value.length == 6 && !_applying) _confirmCode();
            },
            onSubmitted: (_) => _confirmCode(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _applying ? null : _confirmCode,
            child: _applying
                ? const _ButtonSpinner()
                : Text(context.t('accountSecurity.phoneReauth.confirm')),
          ),
          TextButton(
            onPressed: _resendIn > 0 || busy ? null : _sendCode,
            child: Text(
              _resendIn > 0
                  ? '${context.t('phoneVerify.resend')} ($_resendIn s)'
                  : context.t('phoneVerify.resend'),
            ),
          ),
        ] else
          FilledButton(
            onPressed: busy ? null : _sendCode,
            child: busy
                ? const _ButtonSpinner()
                : Text(context.t('phoneChange.sendCode')),
          ),
      ],
    );
  }
}

// ── Ortak parçalar ────────────────────────────────────────────────────

/// Hesabın SMS gönderilebilecek numarası.
///
/// Auth'a bağlı numara önce gelir: sahiplik dizini ve `reauthenticate` o
/// numaraya göre çalışır. Numarayı Auth'a bağlamadan önceki sürümlerden kalan
/// hesaplarda boş olabildiği için profildeki numaraya düşülür.
String accountPhoneE164(Session session) {
  final String linked = (session.user?.phoneNumber ?? '').trim();
  if (linked.isNotEmpty) return linked;

  final String student = session.studentProfile?.phone.trim() ?? '';
  if (student.isNotEmpty) return student;

  return session.clubProfile?.phone.trim() ?? '';
}

/// Şifre değiştirme ve hesap silme sırasında çıkabilecek hataların metni.
///
/// `invalid-credential` burada "mevcut şifren hatalı" demektir: her iki akış
/// da yeniden kimlik doğrulamayı yalnızca kullanıcının yazdığı şifreyle
/// yapar, başka bir kimlik bilgisi devrede değildir.
String describeSensitiveActionError(BuildContext context, Object error) {
  final String code = switch (error) {
    FirebaseAuthException(:final String code) => code,
    FirebaseException(:final String code) => code,
    _ => '',
  };

  return switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'invalid-login-credentials' => context.t(
      'accountSecurity.error.wrongPassword',
    ),
    'weak-password' => context.t('auth.error.weakPassword'),
    'requires-recent-login' => context.t('auth.error.requiresRecentLogin'),
    'too-many-requests' => context.t('auth.error.tooManyRequests'),
    'network-request-failed' => context.t('auth.error.networkFailed'),
    'credential-already-in-use' ||
    'email-already-in-use' => context.t('auth.error.emailInUse'),
    _ => context.t('accountSecurity.error.generic'),
  };
}

/// Bu dosyadaki üç pop-up'ın ortak iskeleti: başlık, kapatma çarpısı, alt alta
/// içerik. Kart ölçüleri `phone_verify_sheet.dart` ile aynı tutuldu.
class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.children,
  });

  final String title;
  final String subtitle;

  /// `null` ise işlem sürüyor demektir; kapatma çarpısı pasifleşir.
  final VoidCallback? onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('common.cancel'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.enabled,
    this.onToggleObscure,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    obscureText: obscure,
    autocorrect: false,
    enableSuggestions: false,
    inputFormatters: lengthOnlyInput(InputLimits.password),
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: onToggleObscure == null
          ? null
          : IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
    ),
  );
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.white),
  );
}
