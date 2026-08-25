import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/phone_field.dart';
import 'auth_widgets.dart';

/// Şifremi unuttum — giriş ekranıyla aynı sahnede tam sayfa.
///
/// Akış:
///   1. E-postaya bağlı telefonun maskeli hâli sunucudan alınır ve gösterilir
///      (ör. "+90 xxx xxx xx 67") — kullanıcı hangi numara olduğunu hatırlar.
///   2. Kullanıcı numarasını tam olarak yazar, SMS kodu gönderilir.
///   3. Kod **pop-up** içinde girilir; sayfa arkada kalır.
///   4. Doğrulanınca sayfada yeni şifre alanları açılır ve şifre güncellenir.
///
/// **Neden numara elle yazılıyor?**
/// Firebase Phone Auth doğrulamayı yalnızca istemci başlatabilir ve tam
/// numarayı ister; Admin SDK'da sunucudan SMS gönderen bir API yok. Tam
/// numarayı fonksiyondan döndürmek maskelemeyi anlamsız kılar ve e-postadan
/// telefon öğrenmeyi mümkün kılardı. Bu yüzden maske yalnızca ipucu olarak
/// gösterilir; SMS'i tetikleyen numarayı kullanıcının kendisi girer.
///
/// Kodu doğrulamak kullanıcıyı Auth'a giriş yaptırır — şifre değiştirmek
/// oturum gerektirir. Router bu rotayı oturumlu kullanıcıya da açık tutar,
/// aksi hâlde kullanıcı yeni şifresini giremeden panele fırlatılırdı.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Stage { loadingPhone, enterPhone, sending, newPassword, done }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final PhoneFieldController _phone = PhoneFieldController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();

  _Stage _stage = _Stage.loadingPhone;
  String? _maskedPhone;
  String? _verificationId;
  bool _obscure = true;
  bool _saving = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMaskedPhone());
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.error]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  /// Maskeli ipucunu `phone_hints` koleksiyonundan okur.
  /// Bulunamazsa ekran maskesiz devam eder — ipucu görsel bir kolaylık,
  /// akışın çalışması ona bağlı değil.
  Future<void> _loadMaskedPhone() async {
    final String masked =
        await ref.read(phoneHintRepositoryProvider).read(widget.email);

    if (!mounted) return;
    setState(() {
      _maskedPhone = masked.isEmpty ? null : masked;
      _stage = _Stage.enterPhone;
    });

    if (masked.isEmpty) {
      _setFeedback(context.t('forgotPassword.noPhone'), FeedbackTone.info);
    }
  }

  Future<void> _sendCode() async {
    if (!_phone.isValid) {
      _setFeedback(context.t('studentInfo.feedback.invalidPhone'));
      return;
    }

    setState(() => _stage = _Stage.sending);
    _setFeedback(null);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phone.e164,
      verificationCompleted: (PhoneAuthCredential credential) =>
          _applyCredential(credential),
      verificationFailed: (FirebaseAuthException error) {
        if (!mounted) return;
        setState(() => _stage = _Stage.enterPhone);
        _setFeedback(_describeError(error));
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _stage = _Stage.enterPhone;
        });
        _openCodeDialog();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) setState(() => _verificationId = verificationId);
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _openCodeDialog() async {
    final String? code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CodeDialog(),
    );
    if (code == null || _verificationId == null) return;

    await _applyCredential(
      PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      ),
    );
  }

  /// Kodu doğrular ve hesabın gerçekten bu e-postaya ait olduğunu teyit eder.
  ///
  /// Girilen numara hiçbir hesaba bağlı değilse Firebase telefon-only YENİ bir
  /// hesap açar. Bu hesabı bırakmak hem çöp kayıt üretir hem de kullanıcıyı
  /// profilsiz bir oturuma düşürür; o yüzden siliniyor.
  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential result = await ref
          .read(authRepositoryProvider)
          .signInWithPhoneCredential(credential);

      final User? user = result.user;
      final bool matchesEmail =
          (user?.email ?? '').toLowerCase() == widget.email.toLowerCase();

      if (!matchesEmail) {
        // Yanlış numara: bu hesap istenen e-postaya ait değil.
        final bool isFreshPhoneOnly =
            (user?.email ?? '').isEmpty &&
            result.additionalUserInfo?.isNewUser == true;
        try {
          if (isFreshPhoneOnly) {
            await user?.delete();
          } else {
            await ref.read(authRepositoryProvider).signOut();
          }
        } catch (_) {
          await ref.read(authRepositoryProvider).signOut();
        }

        if (!mounted) return;
        setState(() => _stage = _Stage.enterPhone);
        _setFeedback(context.t('forgotPassword.phoneMismatch'));
        return;
      }

      if (!mounted) return;
      setState(() => _stage = _Stage.newPassword);
      _setFeedback(null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _stage = _Stage.enterPhone);
      _setFeedback(_describeError(error));
    }
  }

  Future<void> _savePassword() async {
    final String pw = _password.text;

    if (pw.isEmpty || _passwordConfirm.text.isEmpty) {
      _setFeedback(context.t('auth.feedback.passwordRequired'));
      return;
    }
    if (pw != _passwordConfirm.text) {
      _setFeedback(context.t('auth.feedback.passwordMismatch'));
      return;
    }
    if (!isStrongPassword(pw)) {
      _setFeedback(context.t('auth.error.weakPassword'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(pw);
      if (!mounted) return;
      setState(() => _stage = _Stage.done);
      _setFeedback(context.t('forgotPassword.success'), FeedbackTone.success);
    } catch (error) {
      if (!mounted) return;
      _setFeedback(_describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _describeError(Object error) {
    final String code = switch (error) {
      FirebaseAuthException(:final String code) => code,
      FirebaseException(:final String code) => code,
      _ => '',
    };

    return switch (code) {
      'not-found' => context.t('forgotPassword.noPhone'),
      'resource-exhausted' => context.t('forgotPassword.tooManyAttempts'),
      'invalid-verification-code' => context.t('phoneVerify.error.invalidCode'),
      'session-expired' ||
      'code-expired' =>
        context.t('phoneVerify.error.codeExpired'),
      'too-many-requests' => context.t('phoneVerify.error.tooManyRequests'),
      'invalid-phone-number' => context.t('phoneVerify.error.invalidPhone'),
      'weak-password' => context.t('auth.error.weakPassword'),
      'requires-recent-login' => context.t('auth.error.requiresRecentLogin'),
      _ => context.t('forgotPassword.genericError'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.loginBase,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const AuthBackground(),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      AuthGhostButton(
                        label: context.t('common.back'),
                        icon: Icons.arrow_back,
                        onPressed: _leave,
                      ),
                      const LanguageToggleDark(),
                    ],
                  ),
                ),
                Expanded(
                  child: AuthFixedBody(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const AuthBrandHero(compact: true),
                        const SizedBox(height: 22),
                        _buildCard(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Yarıda bırakırken oturum açılmışsa kapat: kullanıcı şifresini
  /// değiştirmeden panele girmiş olmasın.
  Future<void> _leave() async {
    if (_stage == _Stage.newPassword) {
      await ref.read(authRepositoryProvider).signOut();
    }
    if (mounted) context.go(Routes.landing);
  }

  Widget _buildCard(BuildContext context) {
    return AuthGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.t('forgotPassword.title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.loginMuted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (_feedback != null) ...<Widget>[
            AuthFeedback(message: _feedback!, tone: _tone),
            const SizedBox(height: 14),
          ],
          ..._buildStageContent(context),
        ],
      ),
    );
  }

  List<Widget> _buildStageContent(BuildContext context) {
    switch (_stage) {
      case _Stage.loadingPhone:
        return const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: BrandColors.red)),
          ),
        ];

      case _Stage.enterPhone:
      case _Stage.sending:
        return <Widget>[
          if (_maskedPhone != null) ...<Widget>[
            Text(
              context.t('forgotPassword.phoneQuestion'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.loginMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BrandColors.loginGlassBorder),
              ),
              child: Text(
                _maskedPhone!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrandColors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            context.t('forgotPassword.enterPhoneHint'),
            style: const TextStyle(color: BrandColors.loginMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          PhoneField(
            controller: _phone,
            label: context.t('form.phone'),
            enabled: _stage != _Stage.sending,
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: context.t('forgotPassword.sendCode'),
            loading: _stage == _Stage.sending,
            onPressed: _sendCode,
          ),
        ];

      case _Stage.newPassword:
        return <Widget>[
          Text(
            context.t('forgotPassword.newPasswordHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.loginMuted, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _password,
            enabled: !_saving,
            hint: context.t('form.password'),
            icon: Icons.lock_outline,
            obscure: _obscure,
            inputFormatters: lengthOnlyInput(InputLimits.password),
            onChanged: (_) => setState(() {}),
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: BrandColors.loginMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 12),
          AuthField(
            controller: _passwordConfirm,
            enabled: !_saving,
            hint: context.t('form.passwordConfirm'),
            icon: Icons.lock_outline,
            obscure: _obscure,
            inputFormatters: lengthOnlyInput(InputLimits.password),
          ),
          const SizedBox(height: 8),
          Text(
            isStrongPassword(_password.text)
                ? context.t('auth.passwordPolicyValid')
                : context.t('auth.passwordPolicyHint'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: isStrongPassword(_password.text)
                  ? const Color(0xFF4ADE80)
                  : BrandColors.loginMuted,
            ),
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: context.t('forgotPassword.savePassword'),
            loading: _saving,
            onPressed: _savePassword,
          ),
        ];

      case _Stage.done:
        return <Widget>[
          const Icon(Icons.check_circle_outline,
              size: 46, color: Color(0xFF4ADE80)),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: context.t('forgotPassword.continue'),
            loading: false,
            onPressed: () => context.go(Routes.landing),
          ),
        ];
    }
  }
}

/// 6 haneli kod penceresi — sayfa arkada kalır.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandColors.loginSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        context.t('phoneVerify.modalTitle'),
        style: const TextStyle(color: BrandColors.white, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            context.t('phoneVerify.codeLabel'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.loginMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.white,
              fontSize: 24,
              letterSpacing: 10,
              fontWeight: FontWeight.w700,
            ),
            inputFormatters: digitsInput(InputLimits.verificationCode),
            decoration:
                const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (String value) {
              setState(() {});
              if (value.length == 6) Navigator.of(context).pop(value);
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.red),
          onPressed: _code.text.length == 6
              ? () => Navigator.of(context).pop(_code.text)
              : null,
          child: Text(context.t('phoneVerify.confirmCode')),
        ),
      ],
    );
  }
}
