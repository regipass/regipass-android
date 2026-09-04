import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../services/phone_hint_repository.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/phone_field.dart';
import '../shared/phone_guard.dart';
import 'auth_widgets.dart';

/// Şifremi unuttum — giriş ekranıyla aynı sahnede tam sayfa.
/// (password-reset.html + js/pages/password-reset.js portu.)
///
/// Akış:
///   1. E-postaya bağlı hesabın telefon ipucu okunur.
///   2. Kullanıcı numarasını tam olarak yazar. Numara maskeyle tutuyorsa SMS
///      kodu gönderilir; tutmuyorsa SMS HİÇ gönderilmez (web ile aynı kontrol).
///   3. Kod **pop-up** içinde girilir; sayfa arkada kalır.
///   4. Doğrulanınca doğrudan yeni şifre + şifre tekrar alanları açılır.
///   5. Şifre güncellenince hesapla doğrudan giriş yapılır.
///
/// **Neden numara elle yazılıyor?**
/// Firebase Phone Auth doğrulamayı yalnızca istemci başlatabilir ve tam
/// numarayı ister; Admin SDK'da sunucudan SMS gönderen bir API yok. Tam
/// numarayı fonksiyondan döndürmek maskelemeyi anlamsız kılar ve e-postadan
/// telefon öğrenmeyi mümkün kılardı. Bu yüzden maske yalnızca ipucu olarak
/// gösterilir; SMS'i tetikleyen numarayı kullanıcının kendisi girer.
///
/// **Neden ekrandan çıkarken oturum kapatılıyor?**
/// Kodu doğrulamak kullanıcıyı Auth'a giriş yaptırır — şifre değiştirmek
/// oturum gerektiriyor. Router bu rotayı oturumlu kullanıcıya da açık tutar,
/// ama kullanıcı işlemi iptal edip ekrandan çıktığında oturum kapatılmazsa
/// router kullanıcıyı doğrudan panele fırlatır. Bu yüzden iptal/geri yolu
/// `_leave` üzerinden geçer.
///
/// **Rol seçim adımı neden yok?**
/// Bir e-postaya artık tek rol bağlanabiliyor (bkz. `AuthRepository`
/// kayıt akışı), dolayısıyla seçilecek bir şey kalmadı. Zaten tek Firebase
/// Auth hesabı = tek şifre olduğu için seçim şifreyi hiç bölmüyordu.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Stage { loadingPhone, enterPhone, sending, newPassword }

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

  /// SMS doğrulaması bu ekranda bir Auth oturumu açtı mı? Açtıysa ekrandan
  /// hangi yolla çıkılırsa çıkılsın oturum kapatılmalı (bkz. sınıf yorumu).
  bool _signedInHere = false;

  /// Aynı kimlik bilgisi iki kez işlenmesin. Android'in otomatik doğrulaması
  /// (`verificationCompleted`) ile kullanıcının elle girdiği kod yarışabiliyor;
  /// ikinci deneme "kod zaten kullanıldı" hatası verip başarılı adımı geri
  /// alıyordu.
  bool _applying = false;

  /// Kod penceresi açık mı — otomatik doğrulama tamamlandığında pencereyi
  /// kapatabilmek için.
  bool _codeDialogOpen = false;

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

  /// Doğrulama tamamlandıktan sonra gelen gecikmiş hatalar/geri çağrılar
  /// kullanıcıyı yeniden telefon adımına düşürmesin.
  bool get _verified => _stage == _Stage.newPassword;

  /// Maskeli ipucunu `phone_hints` koleksiyonundan okur.
  /// Bulunamazsa ekran maskesiz devam eder — ipucu görsel bir kolaylık,
  /// akışın çalışması ona bağlı değil.
  Future<void> _loadMaskedPhone() async {
    final PasswordResetHint hint = await ref
        .read(phoneHintRepositoryProvider)
        .readHint(widget.email);

    if (!mounted) return;
    setState(() {
      _maskedPhone = hint.maskedPhone.isEmpty ? null : hint.maskedPhone;
      _stage = _Stage.enterPhone;
    });

    if (hint.maskedPhone.isEmpty) {
      _setFeedback(context.t('forgotPassword.noPhone'), FeedbackTone.info);
    }
  }

  Future<void> _sendCode() async {
    final String typed = _phone.e164;

    // Ön kontrol (hane sayısı + operatör ön eki): kodu istemeden önce numara
    // gerçekten o ülkenin cep numarası mı? Sahiplik sorgusu burada yapılmaz —
    // oturum henüz açılmadığı için uid yok; numaranın bu hesaba ait olduğunu
    // aşağıdaki maske karşılaştırması doğruluyor.
    final String? structure = phoneStructureError(context, typed);
    if (structure != null) {
      _setFeedback(structure);
      return;
    }

    // İpucu varsa: girilen numara kayıtlı numarayla aynı mı? Karşılaştırma
    // MASKELER üzerinden yapılır, çünkü elimizde tam numara hiç yok. Böylece
    // yanlış numaraya boşuna SMS gitmez ve e-postayı bilen ama numarayı
    // bilmeyen biri kod isteyemez (js/pages/password-reset.js ile aynı kural).
    if (_maskedPhone != null && maskE164ForDisplay(typed) != _maskedPhone) {
      _setFeedback(context.t('forgotPassword.phoneMismatch'));
      return;
    }

    setState(() => _stage = _Stage.sending);
    _setFeedback(null);
    ref.read(passwordResetInProgressProvider.notifier).begin();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: typed,
      verificationCompleted: (PhoneAuthCredential credential) =>
          _applyCredential(credential),
      verificationFailed: (FirebaseAuthException error) {
        if (!mounted || _verified) return;
        setState(() => _stage = _Stage.enterPhone);
        _setFeedback(_describeError(error));
      },
      codeSent: (String verificationId, int? resendToken) {
        // `_applying`: otomatik doğrulama zaten başladıysa kod penceresini hiç
        // açma — kullanıcı boşuna kod girmesin.
        if (!mounted || _verified || _applying) return;
        setState(() {
          _verificationId = verificationId;
          _stage = _Stage.enterPhone;
        });
        _openCodeDialog(typed);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) setState(() => _verificationId = verificationId);
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _openCodeDialog(String phoneE164) async {
    _codeDialogOpen = true;
    final String? code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CodeDialog(phoneE164: phoneE164),
    );
    _codeDialogOpen = false;

    if (code == null || _verificationId == null) return;

    await _applyCredential(
      PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      ),
    );
  }

  /// Otomatik doğrulama (Android) kodu kullanıcı yazmadan tamamlarsa açık
  /// kalan pencereyi kapatır; aksi hâlde kullanıcı kodu bir kez daha girip
  /// "kod zaten kullanıldı" hatası alıyordu.
  void _closeCodeDialog() {
    if (!_codeDialogOpen || !mounted) return;
    _codeDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Kodu doğrular ve hesabın gerçekten bu e-postaya ait olduğunu teyit eder.
  ///
  /// Girilen numara hiçbir hesaba bağlı değilse Firebase telefon-only YENİ bir
  /// hesap açar. Bu hesabı bırakmak hem çöp kayıt üretir hem de kullanıcıyı
  /// profilsiz bir oturuma düşürür; o yüzden siliniyor.
  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    if (_applying || _verified) return;
    _applying = true;
    _closeCodeDialog();

    try {
      final UserCredential result = await ref
          .read(authRepositoryProvider)
          .signInWithPhoneCredential(credential);

      // Giriş sürerken pencere açılmış olabilir (otomatik doğrulama ile
      // `codeSent` yarışı); bu noktada kesinlikle kapanmalı.
      _closeCodeDialog();
      _signedInHere = true;

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
        _signedInHere = false;

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
    } finally {
      _applying = false;
    }
  }

  Future<void> _savePassword() async {
    final String pw = _password.text;

    if (pw.isEmpty || _passwordConfirm.text.isEmpty) {
      _setFeedback(context.t('auth.feedback.passwordRequired'));
      return;
    }
    if (!isStrongPassword(pw)) {
      _setFeedback(context.t('auth.error.weakPassword'));
      return;
    }
    if (pw != _passwordConfirm.text) {
      _setFeedback(context.t('auth.feedback.passwordMismatch'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(pw);
      if (!mounted) return;
      // SMS doğrulamasıyla açılan oturum korunur; kullanıcı yenilenmiş şifreli
      // hesabına doğrudan girer. Rol tek olduğu için seçim adımı yok.
      _signedInHere = false;
      ref.read(passwordResetInProgressProvider.notifier).end();
      final String? role = ref.read(sessionProvider).resolvedRole;
      context.go(
        role == UserRole.club
            ? Routes.clubHome
            : role == UserRole.student
            ? Routes.studentHome
            : Routes.roleSelect,
      );
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
      'code-expired' => context.t('phoneVerify.error.codeExpired'),
      'too-many-requests' => context.t('phoneVerify.error.tooManyRequests'),
      'invalid-phone-number' => context.t('phoneVerify.error.invalidPhone'),
      'weak-password' => context.t('auth.error.weakPassword'),
      'requires-recent-login' => context.t('auth.error.requiresRecentLogin'),
      _ => context.t('forgotPassword.genericError'),
    };
  }

  /// Ekrandan çıkarken SMS ile açılmış oturumu kapat: kullanıcı şifresini
  /// değiştirmeden panele girmiş olmasın.
  Future<void> _leave() async {
    if (_signedInHere) {
      _signedInHere = false;
      await ref.read(authRepositoryProvider).signOut();
    }
    ref.read(passwordResetInProgressProvider.notifier).end();
    if (mounted) context.go(Routes.landing);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Doğrulanmış oturum varken sistem "geri" hareketi ekranı kapatamaz;
      // önce oturumu kapatıp girişe döneriz, aksi hâlde router altta kalan
      // ekrandan kullanıcıyı panele fırlatır.
      canPop: !_signedInHere,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
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
      ),
    );
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
            child: Center(
              child: CircularProgressIndicator(color: BrandColors.red),
            ),
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
            style: const TextStyle(
              color: BrandColors.loginMuted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          _FieldLabel(text: context.t('form.phone')),
          PhoneField(
            controller: _phone,
            label: context.t('form.phone'),
            // Başlık üstte ayrı duruyor; alanın içindeki etiket ekrandaki
            // diğer alanlarla uyuşmuyor, aşağı kaymış gibi görünüyordu.
            floatingLabel: false,
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
        final bool strong = isStrongPassword(_password.text);
        return <Widget>[
          Text(
            context.t('forgotPassword.newPasswordHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.loginMuted,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel(text: context.t('passwordReset.newPasswordLabel')),
          AuthField(
            controller: _password,
            enabled: !_saving,
            hint: context.t('placeholder.passwordSet'),
            icon: Icons.lock_outline,
            obscure: _obscure,
            textInputAction: TextInputAction.next,
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
          _FieldLabel(text: context.t('form.passwordConfirm')),
          AuthField(
            controller: _passwordConfirm,
            enabled: !_saving,
            hint: context.t('placeholder.passwordConfirm'),
            icon: Icons.lock_outline,
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            inputFormatters: lengthOnlyInput(InputLimits.password),
            onChanged: (_) => setState(() {}),
            onSubmitted: (String _) {
              if (!_saving) _savePassword();
            },
          ),
          const SizedBox(height: 8),
          Text(
            strong
                ? context.t('auth.passwordPolicyValid')
                : context.t('auth.passwordPolicyHint'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: strong ? BrandColors.success : BrandColors.loginMuted,
            ),
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: context.t('forgotPassword.savePassword'),
            loading: _saving,
            onPressed: _savePassword,
          ),
        ];
    }
  }
}

/// Koyu giriş sahnesinde alan başlığı.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: BrandColors.loginMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// 6 haneli kod penceresi — sayfa arkada kalır.
///
/// **Renkler neden elle veriliyor?** Pencere, koyu giriş sahnesinin üstünde
/// duruyor ama içindeki `TextField` uygulama temasından besleniyordu: açık
/// temada dolgu beyaz, yazı ise beyaz olarak sabitlenmişti — girilen rakamlar
/// görünmüyordu. Burada zemin, dolgu, kenarlık, imleç ve yazı renkleri tek tek
/// veriliyor; böylece pencere hem açık hem koyu temada aynı ve okunur kalıyor.
/// Uygulama teması hiç değişmiyor.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.phoneE164});

  final String phoneE164;

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

  bool get _complete => _code.text.length == InputLimits.verificationCode;

  void _submit() {
    if (_complete) Navigator.of(context).pop(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return Dialog(
      backgroundColor: BrandColors.loginSurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: BrandColors.loginGlassBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.t('phoneVerify.modalTitle'),
                      style: const TextStyle(
                        color: BrandColors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('common.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: BrandColors.loginMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  context.t('phoneVerify.modalSubtitle'),
                  style: const TextStyle(
                    color: BrandColors.loginMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BrandColors.loginGlassBorder),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.sms_outlined,
                      size: 20,
                      color: BrandColors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formatE164ForDisplay(widget.phoneE164),
                        style: const TextStyle(
                          color: BrandColors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.oneTimeCode],
                  cursorColor: BrandColors.red,
                  style: const TextStyle(
                    color: BrandColors.white,
                    fontSize: 24,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  inputFormatters: digitsInput(InputLimits.verificationCode),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: const TextStyle(
                      color: BrandColors.loginMuted,
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: const Color(0x14FFFFFF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: border(BrandColors.loginGlassBorder),
                    enabledBorder: border(BrandColors.loginGlassBorder),
                    focusedBorder: border(BrandColors.red, 1.5),
                  ),
                  onChanged: (String value) {
                    setState(() {});
                    if (value.length == InputLimits.verificationCode) _submit();
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AuthPrimaryButton(
                  label: context.t('phoneVerify.confirmCode'),
                  loading: false,
                  onPressed: _complete ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
