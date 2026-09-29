import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/system_ui.dart';
import '../../app/theme.dart';
import '../../core/app_log.dart';
import '../../services/account_mail_service.dart';
import '../../services/password_reset_auth_session.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../domain/masked_phone_match.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../services/phone_hint_repository.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/phone_field.dart';
import '../shared/phone_guard.dart';
import 'auth_widgets.dart';
import 'phone_auth_errors.dart';

/// E-postaya bağlı maskeli numara gösterilir; tam numara kullanıcıdan alınır.
/// SMS doğrulaması ayrı bir Firebase Auth oturumunda yapılır. Doğrulanan
/// hesabın e-postası eşleşmeden şifre değiştirilemez. Ana uygulama oturumu
/// yalnızca yeni şifre kaydedildikten sonra açılır.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Stage { enterPhone, sending, verifying, newPassword }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final PhoneFieldController _phone = PhoneFieldController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();

  _Stage _stage = _Stage.enterPhone;
  String? _maskedPhone;

  /// İpucu sorgusuna bir kaynak yanıt verdi mi? `false` ise maske denetimi
  /// yapılmaz — okuyamadığımız bir ipucu yüzünden kurtarma akışı kapanmaz.
  bool _hintResolved = false;

  /// Açılışta başlayan ipucu isteği. "Kod gönder"e ipucu gelmeden basılırsa
  /// denetim yapılabilsin diye beklenir; normalde çoktan tamamlanmıştır.
  Future<void>? _hintLoad;
  bool _obscure = true;
  bool _saving = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.error;

  PasswordResetAuthSession? _resetAuth;
  int _attempt = 0;
  bool _leaving = false;
  bool _applying = false;
  bool _codeDialogOpen = false;
  int? _resendToken;
  String? _lastPhone;
  Timer? _sendWatchdog;
  static const Duration _kSendTimeout = Duration(seconds: 75);
  static const Duration _kOperationTimeout = Duration(seconds: 30);

  /// "Doğrulama kodu gönder" düğmesi — klavye açıldığında görünür alana
  /// çekebilmek için.
  ///
  /// **Neden gerekiyor:** kart kaydırma görünümünün içinde ve Flutter klavye
  /// açılınca yalnızca ODAKTAKİ alanı görünür tutuyor. Telefon alanı düğmenin
  /// üstünde olduğu için alan görünür kalıyor, düğme klavyenin ALTINDA
  /// kalıyordu: kullanıcı numarayı yazıp düğmeye bastığında dokunuş düğmeye
  /// hiç ulaşmıyor, hiçbir şey olmuyordu — "kod gönderilmiyor" şikâyetinin
  /// kaynağı buydu (400x700 ekran + 320 px klavyede düğmenin merkezi y=418,
  /// görünür alan ise 380'de bitiyor).
  final GlobalKey _sendButtonKey = GlobalKey();

  /// Klavyenin son bilinen yüksekliği; yalnızca değiştiğinde iş yapılır.
  double _keyboardInset = 0;

  Timer? _ensureVisibleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _hintLoad = _loadMaskedPhone(),
    );
  }

  @override
  void dispose() {
    _attempt++;
    _sendWatchdog?.cancel();
    unawaited(_resetAuth?.close());
    _ensureVisibleTimer?.cancel();
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

    // Mesaj kartın EN ÜSTÜNDE çiziliyor; klavye açıkken kart oraya kadar
    // kaydırılmadığı için kullanıcı hatayı hiç göremiyordu. Klavyeyi kapatmak
    // kartı görünür alana sığdırır ve mesajı ortaya çıkarır — zaten hata
    // aldığında kullanıcının yapacağı ilk iş de okumaktır.
    if (message != null) FocusScope.of(context).unfocus();
  }

  /// Klavye açıldığında gönder düğmesini görünür alana çeker (bkz.
  /// [_sendButtonKey]). Gecikme, [AuthFixedBody] içindeki klavye payı
  /// animasyonu (160 ms) bitsin diye: düzen oturmadan kaydırılırsa hedef
  /// konum yanlış hesaplanıyor.
  void _ensureSendButtonVisible() {
    _ensureVisibleTimer?.cancel();
    _ensureVisibleTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final BuildContext? target = _sendButtonKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Doğrulama tamamlandıktan sonra gelen gecikmiş hatalar/geri çağrılar
  /// kullanıcıyı yeniden telefon adımına düşürmesin.
  bool get _verified => _stage == _Stage.newPassword;

  // İpucu yüklenmesi telefon girişini bekletmez; yalnızca "kod gönder"
  // anında sonucuna bakılır (bkz. [_sendCode]).
  Future<void> _loadMaskedPhone() async {
    try {
      final PasswordResetHint hint = await ref
          .read(phoneHintRepositoryProvider)
          .readHint(widget.email)
          .timeout(const Duration(seconds: 12));
      if (!mounted || _leaving) return;
      setState(() {
        _maskedPhone = hint.hasMask ? hint.maskedPhone : null;
        _hintResolved = hint.resolved;
      });
    } catch (error) {
      // Zaman aşımı/kural hatası: ipucu yok sayılır ama "telefon yok" diye
      // yorumlanmaz — `_hintResolved` false kalır, ön denetim atlanır.
      _logFailure('hint', error);
    }
  }

  /// SMS'ten **önce** çalışan maske denetimi.
  ///
  /// Elde karşılaştırılacak maske yoksa `null` döner ve akış eskisi gibi
  /// devam eder: nihai yetki hâlâ [_applyCredential] içindeki e-posta
  /// eşleşmesindedir, bu kapı yalnızca boşa giden SMS'i önler.
  String? _maskPrecheckError(String typedE164) {
    if (_hintResolved && _maskedPhone == null) {
      // Kaynak yanıt verdi ve hesapta doğrulanmış telefon yok: kod gönderilse
      // de doğrulama asla e-postayla eşleşemez.
      return context.t('forgotPassword.noPhoneOnRecord');
    }

    final MaskedPhoneMismatch? mismatch = matchHintPhone(
      hint: _maskedPhone,
      typedE164: typedE164,
    );
    if (mismatch == null) return null;

    final String hint = _maskedPhone ?? '';
    return switch (mismatch) {
      MaskedPhoneMismatch.exact => context.t(
        'forgotPassword.phoneNotOnAccount',
        <String, Object?>{'masked': hint},
      ),
      MaskedPhoneMismatch.country => context.t(
        'forgotPassword.maskCountryMismatch',
        <String, Object?>{'masked': hint},
      ),
      MaskedPhoneMismatch.length => context.t(
        'forgotPassword.maskLengthMismatch',
        <String, Object?>{'masked': hint},
      ),
      MaskedPhoneMismatch.suffix => context.t(
        'forgotPassword.maskSuffixMismatch',
        <String, Object?>{'masked': hint},
      ),
    };
  }

  bool _isCurrent(int attempt) => mounted && !_leaving && attempt == _attempt;
  bool get _busy => _stage == _Stage.sending || _stage == _Stage.verifying;

  void _logFailure(String step, Object error) {
    // E-posta, numara, kod, parola ve SDK'nın bunları içerebilen mesajı yazılmaz.
    AppLog.warn('passwordReset.failed', <String, Object?>{
      'step': step,
      'attempt': _attempt,
      'code': error is FirebaseException
          ? error.code
          : error.runtimeType.toString(),
    });
  }

  void _failAttempt(int attempt, Object error, String step) {
    if (!_isCurrent(attempt) || _verified) return;
    _logFailure(step, error);
    _attempt++; // Eski callback'ler yeni denemenin zamanlayıcısına dokunamaz.
    _stopSendWatchdog();
    _closeCodeDialog();
    unawaited(_resetAuth?.close());
    _resetAuth = null;
    _applying = false;
    setState(() => _stage = _Stage.enterPhone);
    _setFeedback(_describeError(error));
  }

  Future<void> _sendCode() async {
    if (_busy || _verified || _leaving || _codeDialogOpen) return;
    final String typed = _phone.e164;
    final String? structure = phoneStructureError(context, typed);
    if (structure != null) {
      _setFeedback(structure);
      return;
    }

    // Maske denetimi ağ isteği değil, ama ipucunun gelmiş olmasına bağlı.
    // Açılışta başlayan istek normalde kullanıcı numarayı yazana kadar
    // bitiyor; bitmediyse kısa süre beklenir. Bekleme başarısız olsa bile
    // `_hintResolved` false kaldığı için akış durmaz.
    if (_hintLoad != null && !_hintResolved) {
      setState(() => _stage = _Stage.sending);
      try {
        await _hintLoad!.timeout(const Duration(seconds: 6));
      } catch (_) {
        // Yok say: denetim atlanır, SMS yine gönderilir.
      }
      if (!mounted || _leaving) return;
      setState(() => _stage = _Stage.enterPhone);
    }

    final String? maskError = _maskPrecheckError(typed);
    if (maskError != null) {
      _setFeedback(maskError);
      return;
    }

    FocusScope.of(context).unfocus();
    // Maske yalnızca görünen haneleri denetler. SMS için tam numaranın
    // hesaba ait olduğunu web ile aynı sunucu API'si onaylamalıdır.
    final int checkAttempt = ++_attempt;
    setState(() => _stage = _Stage.sending);
    _setFeedback(null);
    try {
      final bool matches = await ref
          .read(phoneHintRepositoryProvider)
          .matchesAccountPhone(email: widget.email, phoneE164: typed)
          .timeout(const Duration(seconds: 9));
      if (!_isCurrent(checkAttempt)) return;
      if (!matches) {
        throw FirebaseAuthException(code: 'password-reset-phone-mismatch');
      }
    } catch (error) {
      _failAttempt(checkAttempt, error, 'checkPhone');
      return;
    }
    unawaited(_resetAuth?.close());
    final PasswordResetAuthSession auth = ref.read(
      passwordResetSessionFactoryProvider,
    )();
    _resetAuth = auth;
    final int attempt = ++_attempt;
    if (_lastPhone != typed) _resendToken = null;
    _lastPhone = typed;
    setState(() => _stage = _Stage.sending);
    _setFeedback(null);
    _sendWatchdog = Timer(_kSendTimeout, () {
      if (!_isCurrent(attempt) || _stage != _Stage.sending) return;
      _failAttempt(attempt, TimeoutException('sms-send'), 'send');
    });
    AppLog.info('passwordReset.sendStarted', <String, Object?>{
      'attempt': attempt,
    });

    void onCodeAvailable(String verificationId) {
      if (!_isCurrent(attempt) || _verified || _applying || _codeDialogOpen) {
        return;
      }
      _stopSendWatchdog();
      setState(() {
        _stage = _Stage.enterPhone;
      });
      AppLog.info('passwordReset.codeAvailable', <String, Object?>{
        'attempt': attempt,
      });
      unawaited(_openCodeDialog(typed, verificationId, attempt));
    }

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: typed,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          if (!_isCurrent(attempt) || _verified || _applying) return;
          _stopSendWatchdog();
          unawaited(_applyCredential(credential, attempt));
        },
        verificationFailed: (FirebaseAuthException error) {
          // Otomatik doğrulama ilerlerken SMS dinleyicisinden gelen hata
          // aynı doğrulamayı geri alamaz.
          if (_applying) return;
          _failAttempt(attempt, error, 'send');
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!_isCurrent(attempt)) return;
          _resendToken = resendToken;
          onCodeAvailable(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Bu olay SMS isteğinin başarısızlığı değil, otomatik okumanın
          // bitmesidir. Geçerli ID varsa kullanıcı kodu elle girebilir.
          if (verificationId.isNotEmpty) onCodeAvailable(verificationId);
        },
      );
    } catch (error) {
      if (!_applying) _failAttempt(attempt, error, 'send');
    }
  }

  void _stopSendWatchdog() {
    _sendWatchdog?.cancel();
    _sendWatchdog = null;
  }

  Future<void> _openCodeDialog(
    String phoneE164,
    String verificationId,
    int attempt,
  ) async {
    if (!_isCurrent(attempt) || _codeDialogOpen) return;
    _codeDialogOpen = true;
    final String? code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CodeDialog(phoneE164: phoneE164),
    );
    if (!_isCurrent(attempt)) return;
    _codeDialogOpen = false;
    if (code == null) {
      if (!_applying && !_verified) {
        _attempt++;
        unawaited(_resetAuth?.close());
        _resetAuth = null;
      }
      return;
    }
    await _applyCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ),
      attempt,
    );
  }

  void _closeCodeDialog() {
    if (!_codeDialogOpen || !mounted) return;
    _codeDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _applyCredential(
    PhoneAuthCredential credential,
    int attempt,
  ) async {
    if (!_isCurrent(attempt) || _applying || _verified) return;
    final PasswordResetAuthSession? auth = _resetAuth;
    if (auth == null) return;
    _applying = true;
    _closeCodeDialog();
    setState(() => _stage = _Stage.verifying);
    try {
      final UserCredential result = await auth
          .signIn(credential)
          .timeout(_kOperationTimeout);
      final User? user = result.user;
      final bool matchesEmail =
          (user?.email ?? '').trim().toLowerCase() ==
          widget.email.trim().toLowerCase();
      if (!matchesEmail) {
        // Yanlış numaraya SMS doğrulanınca oluşan yeni telefon-only hesabını kaldır.
        if ((user?.email ?? '').isEmpty &&
            result.additionalUserInfo?.isNewUser == true) {
          try {
            await user?.delete().timeout(const Duration(seconds: 5));
          } catch (error) {
            _logFailure('deleteUnusedPhoneAccount', error);
          }
        }
        throw FirebaseAuthException(code: 'password-reset-phone-mismatch');
      }
      if (!_isCurrent(attempt)) return;
      setState(() => _stage = _Stage.newPassword);
      _setFeedback(null);
    } catch (error) {
      _failAttempt(attempt, error, 'verify');
    } finally {
      if (_isCurrent(attempt)) _applying = false;
    }
  }

  Future<void> _savePassword() async {
    if (_saving || _leaving) return;
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

    final PasswordResetAuthSession? auth = _resetAuth;
    if (auth == null) return;
    final int attempt = _attempt;
    setState(() => _saving = true);
    bool passwordSaved = false;
    try {
      await auth.updatePassword(pw).timeout(_kOperationTimeout);
      passwordSaved = true;
      if (!_isCurrent(attempt)) return;
      // Şifre güncellenene kadar SMS oturumu ana uygulamaya giriş yaptıramaz.
      // Otomatik giriş takılırsa kullanıcı güncellenen şifreyle girişe döner.
      ref.read(passwordResetInProgressProvider.notifier).begin();
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(widget.email.trim(), pw)
          .timeout(_kOperationTimeout);
      if (!mounted || !_isCurrent(attempt)) return;
      ref.read(passwordResetInProgressProvider.notifier).end();
      // İP-E1: ana oturum açıldı; "şifren değişti" e-postası (beklenmez).
      unawaited(notifyPasswordChanged('reset'));
      unawaited(auth.close());
      _resetAuth = null;
      context.go(Routes.roleSelect);
    } catch (error) {
      _logFailure(passwordSaved ? 'signIn' : 'savePassword', error);
      if (!mounted || !_isCurrent(attempt)) return;
      ref.read(passwordResetInProgressProvider.notifier).end();
      _setFeedback(
        passwordSaved
            ? context.t('forgotPassword.savedSignInRequired')
            : _describeError(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Yalnızca bu ekrana özgü kodlar burada karşılanır; telefon doğrulamanın
  /// tüm hata evreni ortak eşleyicidedir ([describePhoneAuthError]). Eskiden
  /// bu liste kısaydı ve tanımadığı her şeyi "İşlem tamamlanamadı" diye
  /// gösteriyordu — cihaz doğrulaması (Play Integrity/reCAPTCHA) düştüğünde
  /// ya da numaraya kota sınırı geldiğinde kullanıcı nedeni hiç göremiyordu.
  String _describeError(Object error) {
    if (error is TimeoutException) {
      return context.t(
        error.message == 'sms-send'
            ? 'forgotPassword.sendTimeout'
            : 'forgotPassword.operationTimeout',
      );
    }
    final String code = switch (error) {
      FirebaseAuthException(:final String code) => code,
      FirebaseException(:final String code) => code,
      _ => '',
    };

    final String message = switch (code) {
      'password-reset-phone-mismatch' => context.t(
        'forgotPassword.phoneMismatch',
      ),
      'resource-exhausted' => context.t('forgotPassword.tooManyAttempts'),
      'weak-password' => context.t('auth.error.weakPassword'),
      'requires-recent-login' => context.t('auth.error.requiresRecentLogin'),
      _ => describePhoneAuthError(context, error),
    };

    // Ham kod da gösteriliyor. "Kod gelmiyor" şikâyeti tek başına hiçbir şey
    // söylemiyor: SMS'i engelleyen onlarca ayrı durum var (cihaz doğrulaması,
    // numaraya uygulanan kötüye kullanım sınırı, projenin SMS bölge
    // politikası...) ve hepsi kullanıcıya aynı cümleyi gösteriyordu. Kod
    // ekranda görününce hangi kapının kapalı olduğu tek bakışta anlaşılıyor.
    return code.isEmpty || code == 'password-reset-phone-mismatch'
        ? message
        : '$message\n(kod: $code)';
  }

  Future<void> _leave() async {
    if (_leaving || _saving) return;
    _leaving = true;
    _attempt++;
    _stopSendWatchdog();
    _closeCodeDialog();
    unawaited(_resetAuth?.close());
    _resetAuth = null;
    ref.read(passwordResetInProgressProvider.notifier).end();
    if (mounted) context.go(Routes.landing);
  }

  @override
  Widget build(BuildContext context) {
    // Klavye yeni açıldıysa gönder düğmesini görünür alana çek.
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _keyboardInset) {
      _keyboardInset = inset;
      if (inset > 0) _ensureSendButtonVisible();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leave();
      },
      child: DarkScreenSystemBars(
        child: Scaffold(
          backgroundColor: context.authColors.base,
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
                            // Klavye açıkken logo gizlenir: bu ekranın kartı
                            // uygulamanın en uzun kartı (maske + ipucu + alan
                            // + düğme) ve logo da yer kaplayınca kart görünür
                            // alana sığmıyor, kullanıcı yazarken içerik yukarı
                            // kayıyordu.
                            if (MediaQuery.viewInsetsOf(context).bottom <=
                                0) ...<Widget>[
                              const AuthBrandHero(compact: true),
                              const SizedBox(height: 22),
                            ],
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
            style: TextStyle(
              color: context.authColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.email,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.authColors.muted, fontSize: 13),
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
      case _Stage.enterPhone:
      case _Stage.sending:
      case _Stage.verifying:
        return <Widget>[
          // Maske tek satırda duruyor: eskiden bir paragraf + iri bir kutu
          // kaplıyordu ve klavye açıkken kart görünür alana sığmadığı için
          // kullanıcı numarayı yazarken maske yukarı kayıp gözden
          // kayboluyordu ("numara birden gitti"). Kısa satır kartı ~90 piksel
          // kısaltıyor, böylece maske alanla birlikte ekranda kalıyor.
          if (_maskedPhone != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.authColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.authColors.cardBorder),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.sms_outlined,
                    size: 18,
                    color: BrandColors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _maskedPhone!,
                      style: TextStyle(
                        color: context.authColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            context.t('forgotPassword.enterPhoneHint'),
            style: TextStyle(color: context.authColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          _FieldLabel(text: context.t('form.phone')),
          PhoneField(
            controller: _phone,
            label: context.t('form.phone'),
            // Başlık üstte ayrı duruyor; alanın içindeki etiket ekrandaki
            // diğer alanlarla uyuşmuyor, aşağı kaymış gibi görünüyordu.
            floatingLabel: false,
            enabled: !_busy,
            // Klavyenin "bitti" tuşu doğrudan kodu ister: düğme küçük
            // ekranlarda klavyenin altında kalabildiği için ikinci bir yol.
            onSubmitted: (_) {
              if (!_busy) _sendCode();
            },
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            key: _sendButtonKey,
            label: context.t(
              _stage == _Stage.verifying
                  ? 'forgotPassword.verifying'
                  : 'forgotPassword.sendCode',
            ),
            loading: _busy,
            onPressed: _sendCode,
          ),
        ];

      case _Stage.newPassword:
        final bool strong = isStrongPassword(_password.text);
        return <Widget>[
          Text(
            context.t('forgotPassword.newPasswordHint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.authColors.muted, fontSize: 13.5),
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
                color: context.authColors.muted,
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
              color: strong ? BrandColors.success : context.authColors.muted,
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
      style: TextStyle(
        color: context.authColors.muted,
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

  bool _submitted = false;

  void _submit() {
    if (!_complete || _submitted) return;
    _submitted = true;
    Navigator.of(context).pop(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return Dialog(
      backgroundColor: context.authColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.authColors.cardBorder),
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
                      style: TextStyle(
                        color: context.authColors.text,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('common.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: context.authColors.muted,
                      size: 22,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  context.t('phoneVerify.modalSubtitle'),
                  style: TextStyle(
                    color: context.authColors.muted,
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
                  color: context.authColors.field,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.authColors.cardBorder),
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
                        style: TextStyle(
                          color: context.authColors.text,
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
                  style: TextStyle(
                    color: context.authColors.text,
                    fontSize: 24,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  inputFormatters: digitsInput(InputLimits.verificationCode),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      color: context.authColors.muted,
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: context.authColors.field,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: border(context.authColors.cardBorder),
                    enabledBorder: border(context.authColors.cardBorder),
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
