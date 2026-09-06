import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../core/sanitize.dart';
import '../../domain/legal_docs.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/auth_repository.dart';
import '../../state/connectivity.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/glowing_border.dart';
import '../shared/legal_consent.dart';
import 'auth_actions.dart';
import 'auth_widgets.dart';

/// register.html + js/pages/register.js karşılığı.
///
/// Giriş ekranıyla aynı sahneyi kullanır; farkı üstteki iki kare rol
/// düğmesi. Rol seçilmeden hiçbir kayıt yolu (e-posta, Google, Apple)
/// açılmaz — çünkü hesabın hangi profil koleksiyonuna yazılacağını rol
/// belirliyor.
///
/// Kayıt tamamlanınca yönlendirme yapılmaz: router, profili eksik kullanıcıyı
/// zaten bilgi formuna (info page) taşır.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  String _selectedRole = '';
  bool _loading = false;
  bool _obscure = true;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.error;

  // KVKK/sözleşme onayı — yalnızca birinci kutu zorunlu (bkz.
  // LegalConsentSection dokümantasyonu). İkincisi pazarlama izni, isteğe
  // bağlı kalmalı çünkü Açık Rıza Metni'nin kendisi bunu öyle tarif ediyor.
  bool _termsAccepted = false;
  bool _marketingConsent = false;

  bool get _hasRole => _selectedRole.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.error]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;

    // Çevrimdışıyken Firebase Auth uzun bir zaman aşımından sonra anlamsız bir
    // hata döndürüyordu; kullanıcıya sebebi hemen söylüyoruz.
    if (!ref.read(onlineProvider)) {
      _setFeedback(context.t('offline.loginBlocked'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    _setFeedback(null);

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final String message = friendlyAuthError(context, error);
      if (message.isNotEmpty) _setFeedback(message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Rolü yalnız geçici onboarding durumu olarak seçer.
  ///
  /// Auth çağrısından önce yapılır: Firebase oturum akışı yeni kullanıcıyı
  /// hemen yayınlasa bile router doğru bilgi formunda kalır. Kalıcı rol ve
  /// profil, formun sonundaki tek batch yazımına kadar oluşturulmaz.
  PendingOnboardingRoleNotifier _beginPendingSignUp() {
    final PendingOnboardingRoleNotifier pendingRole = ref.read(
      pendingOnboardingRoleProvider.notifier,
    );
    pendingRole.select(_selectedRole);
    // Onay anı burada damgalanır: aranan bilgi Firestore yazımının değil,
    // kullanıcının kaydol düğmesine bastığı ANIN zamanı (bkz. KVKK metni
    // madde 7). Profil belgesine, bilgi formu kaydedilirken kopyalanır.
    ref
        .read(pendingConsentProvider.notifier)
        .set(
          termsAccepted: _termsAccepted,
          marketingConsent: _marketingConsent,
        );
    return pendingRole;
  }

  /// Onayı hesap oluşur oluşmaz `users/{uid}` belgesine yazar.
  ///
  /// Profil belgesi bilgi formu bitene kadar oluşmadığı için onayın ilk ve
  /// (o ana kadar) tek kalıcı kopyası burasıdır — kullanıcı formu yarıda
  /// bırakıp uygulamayı kapatsa bile onay anı kaybolmaz.
  ///
  /// En iyi çaba: yazım başarısız olsa bile kayıt akışı sürer, çünkü onay
  /// bilgi formu kaydedilirken profil belgesine ikinci kez yazılır.
  Future<void> _persistConsent(String uid) async {
    final PendingConsent? consent = ref.read(pendingConsentProvider);
    if (consent == null) return;

    try {
      await ref
          .read(profileRepositoryProvider)
          .recordConsent(
            uid: uid,
            termsAccepted: consent.termsAccepted,
            marketingConsent: consent.marketingConsent,
            acceptedAtMs: consent.acceptedAtMs,
            termsVersion: kLegalDocsVersion,
          );
    } catch (_) {
      // Yoksay — bkz. yukarıdaki not.
    }
  }

  Future<void> _registerWithEmail() {
    if (!_hasRole) {
      _setFeedback(context.t('auth.feedback.selectRoleFirst'));
      return Future<void>.value();
    }
    if (!_termsAccepted) {
      _setFeedback(context.t('auth.feedback.termsRequired'));
      return Future<void>.value();
    }

    final String? email = sanitizeEmail(_emailController.text);
    final String password = _passwordController.text;

    if (email == null || password.isEmpty) {
      _setFeedback(context.t('auth.feedback.fillEmailPassword'));
      return Future<void>.value();
    }
    if (!isStrongPassword(password)) {
      _setFeedback(context.t('auth.error.weakPassword'));
      return Future<void>.value();
    }

    return _run(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final PendingOnboardingRoleNotifier pendingRole = _beginPendingSignUp();

      try {
        final UserCredential created = await authRepository.createWithEmail(
          email,
          password,
        );
        // Yeni hesap: router seçilen rolün bilgi formuna taşır.
        final String? uid = created.user?.uid;
        if (uid != null) await _persistConsent(uid);
      } on FirebaseAuthException catch (error) {
        pendingRole.clear();

        // BİR E-POSTAYA TEK HESAP. E-posta kullanımdaysa kayıt burada DURUR:
        // ne giriş yapılır ne de rol eklenir.
        //
        // Eskiden burası "aynı hesaba ikinci rol ekle" yoluna sapıyordu —
        // çift rollü hesapların kaynağı tam olarak burasıydı. O yol, rolün
        // zaten var olup olmadığını sormak için bir an oturum açmak zorunda
        // kaldığından (profil belgeleri yalnızca sahibine açık) kayıt ekranı
        // fiilen bir giriş ekranına dönüşebiliyordu. Artık ne yoklama
        // oturumu açılıyor ne de rol ekleniyor.
        if (error.code == 'email-already-in-use') {
          _setFeedbackKey('auth.error.emailAlreadyRegistered');
          return;
        }
        rethrow;
      } catch (_) {
        pendingRole.clear();
        rethrow;
      }
    });
  }

  void _setFeedbackKey(String key) {
    if (!mounted) return;
    _setFeedback(context.t(key));
  }

  /// Hesapta HERHANGİ bir tamamlanmış rol var mı?
  ///
  /// Bir e-postaya tek hesap bağlanabildiği için soru "seçilen rol var mı"
  /// değil "bu e-postada zaten bir hesap kurulmuş mu". Profil belgeleri
  /// yalnızca sahibine açık olduğundan (firestore.rules) bu ancak oturum
  /// açıldıktan sonra sorulabiliyor; Google/Apple akışında oturum zaten
  /// açılmak zorunda.
  Future<bool> _hasAnyCompletedRole(String uid) async {
    final profileRepository = ref.read(profileRepositoryProvider);
    final List<bool> completed = await Future.wait<bool>(<Future<bool>>[
      profileRepository
          .fetchStudentProfile(uid)
          .then((StudentProfile? p) => p?.onboardingCompleted == true),
      profileRepository
          .fetchClubProfile(uid)
          .then((ClubProfile? p) => p?.onboardingCompleted == true),
    ]);
    return completed.any((bool done) => done);
  }

  /// Yoklama bitti, oturum kapatılır.
  ///
  /// `logout()` değil düz `signOut()`: `logout` tamamlanmamış hesapların
  /// Firestore artıklarını siliyor ve burada silinecek olan, kullanıcının
  /// yalnızca varlığını doğruladığımız BAŞKA bir kaydı olurdu.
  Future<void> _closeProbeSession(AuthRepository authRepository) async {
    try {
      await authRepository.signOut();
    } catch (_) {
      // Çevrimdışıyken oturum kapanmayabilir. Bayrak kalkınca router hesabın
      // gerçek durumuna göre karar verir; uyarı da ekranda kalır.
    }
  }

  /// Sosyal kayıt. Rol burada zaten seçili olduğu için `completePostAuth`
  /// yerine doğrudan seçilen rol uygulanır — aksi hâlde rol seçim ekranına
  /// düşer ve kullanıcı aynı soruyu iki kez yanıtlardı.
  ///
  /// E-posta yolundaki kural burada da geçerli: e-postada zaten bir hesap
  /// varsa bu bir kayıt değildir, oturum açık bırakılmaz. Fark şu ki
  /// Google/Apple'da e-postanın kullanımda olduğunu önceden bilemiyoruz —
  /// sağlayıcı aynı hesaba giriş yaptırıyor — bu yüzden önce girip sonra
  /// sormak ve gerekirse oturumu kapatmak zorundayız.
  /// [authProbeProvider] bu aralıkta router'ı yerinde tutar.
  Future<void> _registerWithProvider(Future<UserCredential> Function() signIn) {
    if (!_hasRole) {
      _setFeedback(context.t('auth.feedback.selectRoleFirst'));
      return Future<void>.value();
    }
    if (!_termsAccepted) {
      _setFeedback(context.t('auth.feedback.termsRequired'));
      return Future<void>.value();
    }

    return _run(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final AuthProbeNotifier probe = ref.read(authProbeProvider.notifier);
      final PendingOnboardingRoleNotifier pendingRole = ref.read(
        pendingOnboardingRoleProvider.notifier,
      );
      final String selectedRole = _selectedRole;

      probe.begin();
      bool keepSession = false;
      try {
        final UserCredential result = await signIn();
        final User? user = result.user;
        if (user == null) return;

        if (await _hasAnyCompletedRole(user.uid)) {
          _setFeedbackKey('auth.error.emailAlreadyRegistered');
          return;
        }

        pendingRole.select(selectedRole);
        ref
            .read(pendingConsentProvider.notifier)
            .set(
              termsAccepted: _termsAccepted,
              marketingConsent: _marketingConsent,
            );
        await _persistConsent(user.uid);
        keepSession = true;
      } finally {
        if (!keepSession) await _closeProbeSession(authRepository);
        probe.end();
      }
    });
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
                        onPressed: _loading
                            ? null
                            : () => context.canPop() ? context.pop() : null,
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
                        const SizedBox(height: 14),
                        _SignInLink(enabled: !_loading),
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

  Widget _buildCard(BuildContext context) {
    return AuthGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.t('auth.roleStep.title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          // ── Yan yana kare rol düğmeleri ──────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: _RoleTile(
                  label: context.t('auth.role.student'),
                  icon: Icons.school_outlined,
                  selected: _selectedRole == UserRole.student,
                  enabled: !_loading,
                  onTap: () => setState(() => _selectedRole = UserRole.student),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleTile(
                  label: context.t('auth.role.club'),
                  icon: Icons.groups_outlined,
                  selected: _selectedRole == UserRole.club,
                  enabled: !_loading,
                  onTap: () => setState(() => _selectedRole = UserRole.club),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (_feedback != null) ...<Widget>[
            AuthFeedback(message: _feedback!, tone: _tone),
            const SizedBox(height: 14),
          ],

          AuthField(
            controller: _emailController,
            enabled: !_loading,
            hint: context.t('auth.emailPlaceholder'),
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            inputFormatters: guardedInput(InputLimits.email),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          AuthField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            enabled: !_loading,
            hint: context.t('auth.passwordPlaceholder'),
            icon: Icons.lock_outline,
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            inputFormatters: lengthOnlyInput(InputLimits.password),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _registerWithEmail(),
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
          const SizedBox(height: 8),
          _PasswordHint(password: _passwordController.text),

          const SizedBox(height: 16),
          LegalConsentSection(
            termsAccepted: _termsAccepted,
            marketingConsent: _marketingConsent,
            onTermsChanged: _loading
                ? null
                : (bool value) => setState(() => _termsAccepted = value),
            onMarketingChanged: _loading
                ? null
                : (bool value) => setState(() => _marketingConsent = value),
            // Giriş/kayıt sahnesi her modda kendi sabit koyu paletinde kalır
            // (bkz. app/theme.dart#BrandSurfaces) — context.ink/inkMuted
            // burada kullanılmaz.
            textColor: BrandColors.white,
            mutedColor: BrandColors.loginMuted,
          ),

          const SizedBox(height: 16),
          // Etiket giriş ekranıyla aynı ("Giriş Yap") — istenen buydu.
          // Butonun yaptığı iş kayıt: seçilen rolle hesap oluşturur, e-posta
          // zaten kayıtlıysa o hesaba ikinci rolü ekler. Onay kutusu
          // işaretlenmeden düğme pasif kalır (bkz. LegalConsentSection).
          AuthPrimaryButton(
            label: context.t('auth.emailLogin'),
            loading: _loading,
            onPressed: _termsAccepted ? _registerWithEmail : null,
          ),

          const SizedBox(height: 18),
          AuthOrDivider(label: context.t('auth.dividerOr')),
          const SizedBox(height: 16),

          GlowingBorder(
            child: AuthSocialButton(
              label: context.t('auth.googleContinue'),
              icon: Icons.g_mobiledata_rounded,
              leading: const GoogleMark(size: 25),
              enabled: !_loading && _termsAccepted,
              borderless: true,
              onPressed: () => _registerWithProvider(
                ref.read(authRepositoryProvider).signInWithGoogle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GlowingBorder(
            child: AuthSocialButton(
              label: context.t('auth.appleContinue'),
              icon: Icons.apple,
              enabled: !_loading && _termsAccepted,
              borderless: true,
              onPressed: () => _registerWithProvider(
                ref.read(authRepositoryProvider).signInWithApple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kare rol düğmesi.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? BrandColors.red.withValues(alpha: 0.16)
                : const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? BrandColors.red : BrandColors.loginGlassBorder,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: BrandColors.red.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 34,
                color: selected ? BrandColors.red : BrandColors.loginMuted,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? BrandColors.white
                        : BrandColors.loginMuted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şifre kuralı ipucu — kural sağlandığında yeşile döner.
class _PasswordHint extends StatelessWidget {
  const _PasswordHint({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final bool valid = password.isNotEmpty && isStrongPassword(password);

    return Text(
      valid
          ? context.t('auth.passwordPolicyValid')
          : context.t('auth.passwordPolicyHint'),
      style: TextStyle(
        fontSize: 11.5,
        height: 1.35,
        color: valid ? const Color(0xFF4ADE80) : BrandColors.loginMuted,
        fontWeight: valid ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _SignInLink extends StatelessWidget {
  const _SignInLink({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? () => context.canPop() ? context.pop() : null : null,
      style: TextButton.styleFrom(foregroundColor: BrandColors.white),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: BrandColors.loginMuted, fontSize: 13.5),
          children: <InlineSpan>[
            TextSpan(text: '${context.t('auth.haveAccount')} '),
            TextSpan(
              text: context.t('auth.emailLogin'),
              style: const TextStyle(
                color: BrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
