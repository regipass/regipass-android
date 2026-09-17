import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/constants.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/phone_field.dart';
import '../shared/phone_guard.dart';
import 'auth_actions.dart';
import 'phone_auth_errors.dart';

/// phone-verify.html + js/pages/phone-verify.js karşılığı.
///
/// Mobilde web'deki görünmez reCAPTCHA adımı yoktur — Firebase Auth cihaz
/// doğrulamasını (SafetyNet / APNs) kendisi yapar. Bu yüzden `RecaptchaVerifier`
/// ile ilgili tüm kod kaldırıldı; geri kalan akış (bağla vs. güncelle,
/// tekrar gönderme sayacı, token tazeleme) birebir korundu.
class PhoneVerifyScreen extends ConsumerStatefulWidget {
  const PhoneVerifyScreen({super.key});

  @override
  ConsumerState<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends ConsumerState<PhoneVerifyScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  String? _verificationId;

  /// Ön kontrolün elediği numara (başkasına ait, hane sayısı ya da operatör
  /// ön eki tutmuyor). Kullanıcı numarasını değiştirene kadar bu numaraya
  /// SMS gönderilmez; "Numarayı değiştir" düğmesi öne çıkar.
  String? _blockedPhone;

  bool _sending = false;
  bool _confirming = false;

  /// Bu doğrulama oturumunda kaç kez yanlış kod girildi. Yeni kod istenince
  /// sıfırlanır; sınıra ulaşınca hata metni "yeni kod iste"ye döner.
  int _wrongCodeAttempts = 0;
  int _resendIn = 0;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  String _describePhoneError(Object error) {
    if (isWrongCodeError(error)) _wrongCodeAttempts++;
    return describePhoneAuthError(
      context,
      error,
      wrongCodeAttempts: _wrongCodeAttempts,
    );
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

  Future<void> _sendCode(String phoneE164) async {
    setState(() => _sending = true);
    _setFeedback(context.t('phoneVerify.feedback.sending'));

    // Ön kontrol SMS'ten ÖNCE: hane sayısı → operatör ön eki → sahiplik.
    // Numara başka bir hesaba aitse ya da o ülkenin cep numarası değilse
    // kullanıcı bunu kod isteyip beklemeden burada öğrenir; eskiden uyarı
    // ancak 6 haneli kod girildikten sonra Firebase Auth telefon bağlama
    // adımında çıkıyordu. Sahiplik sorgusu yapılamazsa (kural yayınlanmamış,
    // çevrimdışı) akış durmaz — Auth aynı kontrolü bağlarken yine yapar.
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final String? problem = await phoneSendPrecheck(
      context,
      ref,
      phoneE164: phoneE164,
      uid: uid,
    );

    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _sending = false;
        _blockedPhone = phoneE164;
      });
      _setFeedback(problem, FeedbackTone.error);
      return;
    }

    // Numarayı SMS'ten hemen önce rezerve et: aynı numaraya aynı anda ikinci
    // bir hesap kod isteyemesin. Rezervasyon kanıt taşımadığı için kural onu
    // 15 dakika sonra düşürür.
    if (uid != null) {
      await ref
          .read(phoneDirectoryRepositoryProvider)
          .reserve(phoneE164: phoneE164, uid: uid);
      if (!mounted) return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneE164,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android otomatik doğrulama: kod elle girilmeden tamamlanır.
          await _applyCredential(credential);
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;
          setState(() => _sending = false);
          _setFeedback(_describePhoneError(error), FeedbackTone.error);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _sending = false;
            _wrongCodeAttempts = 0;
          });
          _setFeedback(
            context.t('phoneVerify.feedback.codeSent'),
            FeedbackTone.success,
          );
          // Android/iOS'nin SMS kodu önerisini bu alana bağla. Kod alana
          // düştüğünde aşağıdaki onChanged otomatik onayı başlatır.
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
      setState(() => _sending = false);
      _setFeedback(_describePhoneError(error), FeedbackTone.error);
    }
  }

  Future<void> _confirmCode() async {
    final String code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _setFeedback(
        context.t('phoneVerify.error.codeFormat'),
        FeedbackTone.error,
      );
      return;
    }
    if (_verificationId == null) return;

    setState(() => _confirming = true);
    _setFeedback(context.t('phoneVerify.feedback.confirming'));

    await _applyCredential(
      PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      ),
    );
  }

  /// Hesapta zaten bir telefon sağlayıcısı varsa GÜNCELLE, yoksa BAĞLA.
  /// (Bir hesap aynı türden ikinci bir sağlayıcı bağlayamaz.)
  Future<void> _applyCredential(PhoneAuthCredential credential) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        await user.updatePhoneNumber(credential);
      } else {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (error) {
          // Yarış durumu: hesap tazelenmesine rağmen sağlayıcı zaten bağlıysa
          // güncelleme yoluna düş.
          if (error.code == 'provider-already-linked') {
            await user.updatePhoneNumber(credential);
          } else {
            rethrow;
          }
        }
      }

      await _markVerified(user);
    } on FirebaseAuthException catch (error) {
      // Önceki denemede telefon zaten bağlanmış olabilir — hata vermek yerine
      // doğrulanmış say ve devam et.
      if (error.code == 'provider-already-linked') {
        await _markVerified(user);
        return;
      }
      if (!mounted) return;
      setState(() => _confirming = false);
      _setFeedback(_describePhoneError(error), FeedbackTone.error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _setFeedback(_describePhoneError(error), FeedbackTone.error);
    }
  }

  /// firestore.rules `request.auth.token.phone_number` iddiasını kontrol eder;
  /// bu iddia yalnızca YENİ alınan bir token'da bulunur — bu yüzden yazmadan
  /// önce token zorla tazelenir.
  Future<void> _markVerified(User user) async {
    try {
      await user.getIdToken(true);

      final Session session = ref.read(sessionProvider);
      final String role =
          session.resolvedRole ?? session.pendingRole ?? UserRole.student;
      final String verifiedPhone =
          user.phoneNumber ??
          session.studentProfile?.phone ??
          session.clubProfile?.phone ??
          '';
      if (verifiedPhone.isEmpty) {
        throw StateError('Firebase Auth doğrulanmış telefonu döndürmedi.');
      }
      await ref
          .read(profileRepositoryProvider)
          .setVerifiedPhone(
            uid: user.uid,
            role: role,
            phoneE164: verifiedPhone,
          );

      // Şifre sıfırlama ekranının gösterdiği maskeli ipucunu tazele.
      // En iyi çaba: yazılamazsa doğrulama akışı bozulmaz, yalnızca o ekran
      // maskesiz açılır.
      if ((user.email ?? '').isNotEmpty) {
        final List<String> roles = <String>[
          if (session.hasStudentRole) UserRole.student,
          if (session.hasClubRole) UserRole.club,
          if (!session.hasAnyRole) role,
        ];
        await ref
            .read(phoneHintRepositoryProvider)
            .write(
              email: user.email!,
              maskedPhone: passwordResetHintPhone(verifiedPhone),
              roles: roles,
            );
      }

      if (!mounted) return;
      _setFeedback(
        context.t('phoneVerify.feedback.success'),
        FeedbackTone.success,
      );
      // Yönlendirmeyi router yapar: profil akışı phoneVerified=true görünce
      // öğrenci paneline düşer.
    } catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _setFeedback(_describePhoneError(error), FeedbackTone.error);
    }
  }

  Future<void> _logout() async {
    await logout(ref);
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    final String role =
        session.resolvedRole ?? session.pendingRole ?? UserRole.student;
    final String phone = role == UserRole.club
        ? (session.clubProfile?.phone ?? session.studentProfile?.phone ?? '')
        : (session.studentProfile?.phone ?? session.clubProfile?.phone ?? '');

    if (phone.isEmpty) {
      return const Scaffold(body: LoadingView());
    }

    final bool codeSent = _verificationId != null;
    // Numara değiştirilince kilit kendiliğinden kalkar.
    final bool numberBlocked = _blockedPhone == phone;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t('phoneVerify.title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _logout,
            child: Text(context.t('common.logout')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const SizedBox(height: 8),
            const Icon(Icons.sms_outlined, size: 48, color: BrandColors.red),
            const SizedBox(height: 20),
            Text(
              context.t('phoneVerify.subtitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                formatE164ForDisplay(phone),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Süre uyarısı: doğrulanmayan kayıt kPhoneVerifyGrace dolunca
            // silinir (bkz. domain/account_expiry.dart). Metindeki süre o
            // sabitle aynı tutulmalı.
            FeedbackBanner(
              message: context.t('phoneVerify.deleteWarning'),
              tone: FeedbackTone.error,
            ),
            const SizedBox(height: 12),

            FeedbackBanner(message: _feedback, tone: _tone),

            if (!codeSent) ...<Widget>[
              FilledButton(
                onPressed: _sending || numberBlocked
                    ? null
                    : () => _sendCode(phone),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrandColors.white,
                        ),
                      )
                    : Text(context.t('phoneVerify.sendCode')),
              ),
              const SizedBox(height: 8),
              // Numara başkasına aitse tek çıkış yolu bu düğme; o yüzden
              // ikinci plandaki metin düğmesinden öne çıkarılır.
              numberBlocked
                  ? FilledButton.tonal(
                      onPressed: () => context.push(Routes.phoneChange),
                      child: Text(context.t('phoneVerify.changeNumber')),
                    )
                  : TextButton(
                      onPressed: () => context.push(Routes.phoneChange),
                      child: Text(context.t('phoneVerify.changeNumber')),
                    ),
            ] else ...<Widget>[
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                enableSuggestions: true,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w700,
                ),
                inputFormatters: digitsInput(InputLimits.verificationCode),
                decoration: const InputDecoration(hintText: '••••••'),
                onChanged: (String value) {
                  if (value.length == 6 && !_confirming) _confirmCode();
                },
                onSubmitted: (_) => _confirmCode(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _confirming ? null : _confirmCode,
                child: _confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrandColors.white,
                        ),
                      )
                    : Text(context.t('phoneVerify.confirmCode')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resendIn > 0 || _sending
                    ? null
                    : () => _sendCode(phone),
                child: Text(
                  _resendIn > 0
                      ? '${context.t('phoneVerify.resend')} ($_resendIn s)'
                      : context.t('phoneVerify.resend'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
