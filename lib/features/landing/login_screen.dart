import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/system_ui.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../state/connectivity.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../auth/auth_widgets.dart';
import '../shared/common_widgets.dart';
import '../shared/glowing_border.dart';
import 'splash_screen.dart';

/// Uygulamanın giriş ekranı — index.html + login-modal.js karşılığı.
///
/// Tek ekranda sabit yerleşim: kaydırılabilir tanıtım bölümleri kaldırıldı,
/// yerine odağı tek bir eyleme (giriş) toplayan koyu bir sahne kuruldu.
/// Tanıtım içeriği artık "Keşfet" ekranında.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _loading = false;
  bool _obscure = true;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.error;

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

  /// Ortak yükleniyor/hata sarmalayıcı. Yönlendirmeyi router'ın redirect'i
  /// yapar; burada başarı durumunda ekstra bir şey yapmaya gerek yok.
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
    // Kullanıcı bir şey denediği anda önceki oturumun kapanma açıklaması
    // geçerliliğini yitirir; ekranda asılı kalmasın.
    ref.read(signOutNoticeProvider.notifier).clear();

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final String message = friendlyAuthError(context, error);
      // Boş mesaj = kullanıcı pencereyi kendisi kapattı, uyarmaya gerek yok.
      if (message.isNotEmpty) _setFeedback(message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithEmail() {
    final String rawEmail = _emailController.text.trim();
    final String password = _passwordController.text;

    // ── Yönetici girişi ── "a" veya a@regipass.app + şifre
    if (isAdminLogin(rawEmail)) {
      if (password.isEmpty) {
        _setFeedback(context.t('auth.feedback.fillEmailPassword'));
        return Future<void>.value();
      }
      return _run(() async {
        await ref
            .read(authRepositoryProvider)
            .signInWithEmail(kAdminEmail, password);
      });
    }

    final String? email = sanitizeEmail(rawEmail);
    if (email == null || password.isEmpty) {
      _setFeedback(context.t('auth.feedback.fillEmailPassword'));
      return Future<void>.value();
    }

    return _run(() async {
      final UserCredential result = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email, password);
      if (result.user != null) await completePostAuth(ref, result.user!);
    });
  }

  Future<void> _signInWithGoogle() => _run(() async {
    final UserCredential result = await ref
        .read(authRepositoryProvider)
        .signInWithGoogle();
    if (result.user != null) await completePostAuth(ref, result.user!);
  });

  Future<void> _signInWithApple() => _run(() async {
    final UserCredential result = await ref
        .read(authRepositoryProvider)
        .signInWithApple();
    if (result.user != null) await completePostAuth(ref, result.user!);
  });

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);

    // Oturum açıkken profil dokümanları yüklenene kadar yönlendirme kararı
    // verilemez; bu arada giriş formunu göstermek yanıltıcı olurdu.
    //
    // Beklenen ekran açılış perdesinin KENDİSİ: burası açılışla giriş formu
    // arasındaki tek karelik bir ara durak ve daha önce koyu bir zemine
    // (loginBase) yerleştirilmiş bir çark gösteriyordu. Açık temada perde
    // beyazken bu, arada bir anlık siyah ekrana — dolayısıyla saydam
    // çubukların da bir anlığına siyaha dönmesine — yol açıyordu. Perde
    // sürdürüldüğünde zemin kesintisiz kalır; koyu giriş ekranına geçiş
    // yalnızca bir kez, perde silinirken yaşanır.
    if (session.isSignedIn && session.isLoading) {
      return const SplashScreen();
    }

    return DarkScreenSystemBars(
      child: Scaffold(
        backgroundColor: BrandColors.loginBase,
        // Klavye açılınca zemin ve akan katman yerinde kalsın; içerik
        // AuthFixedBody ile kendini ayarlıyor.
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
                          label: context.t('nav.explore'),
                          icon: Icons.explore_outlined,
                          onPressed: _loading
                              ? null
                              : () => context.push(Routes.explore),
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
                          const AuthBrandHero(),
                          const SizedBox(height: 28),
                          _buildCard(context),
                          const SizedBox(height: 18),
                          _RegisterLink(enabled: !_loading),
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
    // Oturum kendiliğinden kapatıldıysa (ör. telefonu doğrulanmadığı için
    // silinen kayıt) sebebi burada yazar; aksi hâlde kullanıcı hesabının
    // neden kaybolduğunu hiç öğrenemezdi. İlk giriş denemesinde temizlenir.
    final String? noticeKey = ref.watch(signOutNoticeProvider);

    return AuthGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (noticeKey != null) ...<Widget>[
            AuthFeedback(
              message: context.t(noticeKey),
              tone: FeedbackTone.error,
            ),
            const SizedBox(height: 14),
          ],

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
            onSubmitted: (_) => _signInWithEmail(),
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
          const SizedBox(height: 18),

          AuthPrimaryButton(
            label: context.t('auth.emailLogin'),
            loading: _loading,
            onPressed: _signInWithEmail,
          ),

          const SizedBox(height: 18),
          AuthOrDivider(label: context.t('auth.dividerOr')),
          const SizedBox(height: 16),

          // Google butonunun çevresinde dolanan kırmızı ışık — sosyal
          // girişler arasında birincil olanı işaret eder.
          GlowingBorder(
            child: AuthSocialButton(
              label: context.t('auth.googleContinue'),
              icon: Icons.g_mobiledata_rounded,
              leading: const GoogleMark(size: 25),
              enabled: !_loading,
              onPressed: _signInWithGoogle,
              borderless: true,
            ),
          ),
          const SizedBox(height: 10),
          GlowingBorder(
            child: AuthSocialButton(
              label: context.t('auth.appleContinue'),
              icon: Icons.apple,
              enabled: !_loading,
              onPressed: _signInWithApple,
              borderless: true,
            ),
          ),

          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : _goToForgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: BrandColors.loginMuted,
            ),
            child: Text(
              context.t('auth.forgotPassword'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Şifre sıfırlama e-postasız başlatılamaz: sıfırlama ekranı numarayı
  /// e-postadan buluyor, boş e-posta ile gösterecek bir şey olmazdı.
  void _goToForgotPassword() {
    final String? email = sanitizeEmail(_emailController.text);
    if (email == null) {
      _setFeedback(context.t('forgotPassword.emailRequired'));
      return;
    }
    context.push(
      '${Routes.forgotPassword}?email=${Uri.encodeComponent(email)}',
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled
          ? () {
              final String? continuation = GoRouterState.of(
                context,
              ).uri.queryParameters[kExternalQrContinueParam];
              context.push(
                Uri(
                  path: Routes.register,
                  queryParameters: continuation == null
                      ? const <String, String>{}
                      : <String, String>{
                          kExternalQrContinueParam: continuation,
                        },
                ).toString(),
              );
            }
          : null,
      style: TextButton.styleFrom(foregroundColor: BrandColors.white),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: BrandColors.loginMuted, fontSize: 13.5),
          children: <InlineSpan>[
            TextSpan(text: '${context.t('auth.noAccount')} '),
            TextSpan(
              text: context.t('auth.emailRegister'),
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
