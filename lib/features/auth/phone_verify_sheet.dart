import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/phone_field.dart';
import '../shared/phone_guard.dart';
import 'phone_auth_errors.dart';

/// Hesap ekranından numara değiştirmenin doğrulama adımı — **pop-up**.
///
/// Neden ekran değil de pop-up: eski akışta numara önce Firestore'a yazılıp
/// `phoneVerified` false'a düşüyordu; router bunu görünce kullanıcıyı çıkışı
/// olmayan tam ekran doğrulama kapısına kilitliyordu (yanlış numara yazan ya
/// da vazgeçen kullanıcı geri dönemiyordu). Burada profile hiçbir şey
/// yazılmaz: numara ancak SMS kodu doğrulandıktan sonra tek yazımda kaydedilir,
/// çarpıya basıp çıkan kullanıcının profili hiç değişmemiş olur.
///
/// [phoneE164] doğrulanacak YENİ numara, [previousPhoneE164] sahiplik
/// dizininden düşürülecek eski numara. Doğrulama tamamlandıysa `true` döner.
Future<bool> showPhoneVerifyDialog(
  BuildContext context, {
  required String phoneE164,
  required String role,
  String? previousPhoneE164,
}) async {
  final bool? verified = await showDialog<bool>(
    context: context,
    // Dışına dokununca kapanmaz: kod girerken yanlışlıkla kapatmak, gönderilmiş
    // SMS'i çöpe atar. Kapatma yolu sağ üstteki çarpı (her adımda açık).
    barrierDismissible: false,
    builder: (BuildContext _) => _PhoneVerifyDialog(
      phoneE164: phoneE164,
      role: role,
      previousPhoneE164: previousPhoneE164,
    ),
  );
  return verified ?? false;
}

enum _Step { idle, sending, code, success }

class _PhoneVerifyDialog extends ConsumerStatefulWidget {
  const _PhoneVerifyDialog({
    required this.phoneE164,
    required this.role,
    this.previousPhoneE164,
  });

  final String phoneE164;
  final String role;
  final String? previousPhoneE164;

  @override
  ConsumerState<_PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends ConsumerState<_PhoneVerifyDialog> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  _Step _step = _Step.idle;
  String? _verificationId;
  bool _confirming = false;

  /// Bu doğrulama oturumundaki yanlış kod sayısı; yeni kod gelince sıfırlanır.
  int _wrongCodeAttempts = 0;
  int _resendIn = 0;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Pencere bir kez kapatıldıktan sonra ikinci bir pop çağrısı ALTTAKİ
  /// ekranı kapatır. Başarı animasyonunun gecikmeli kapanışı ile kullanıcının
  /// çarpıya basması yarışabildiği için kapanış tek noktadan yapılır.
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

    // Doğrulamadan vazgeçildiyse rezervasyonu bırak: numara 15 dakika
    // beklemeden yeniden serbest kalsın (kullanıcı yanlış numara yazıp
    // kapatmış olabilir).
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (!verified && uid != null) {
      unawaited(
        ref
            .read(phoneDirectoryRepositoryProvider)
            .release(phoneE164: widget.phoneE164, uid: uid),
      );
    }

    Navigator.of(context).pop(verified);
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  /// Yanlış kod denemelerini sayar: sınıra gelince "kodun süresi doldu"
  /// yerine "yeni kod iste" metni gösterilir.
  String _describeError(Object error) {
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

  Future<void> _sendCode() async {
    setState(() => _step = _Step.sending);
    _setFeedback(context.t('phoneVerify.feedback.sending'));

    // Ön kontrol: hane sayısı → operatör ön eki → sahiplik (bkz.
    // shared/phone_guard.dart). Pop-up'ı açan ekran da sorguluyor ama arada
    // zaman geçmiş olabilir — numarayı bu sırada başka bir hesap almış
    // olabileceği için kararı SMS'e en yakın nokta verir.
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final String? problem = await phoneSendPrecheck(
      context,
      ref,
      phoneE164: widget.phoneE164,
      uid: uid,
    );

    if (!mounted) return;
    if (problem != null) {
      setState(() => _step = _Step.idle);
      _setFeedback(problem, FeedbackTone.error);
      return;
    }

    // Numarayı SMS'ten hemen önce rezerve et: aynı numaraya aynı anda ikinci
    // bir hesap kod isteyemesin (en iyi çaba).
    if (uid != null) {
      await ref
          .read(phoneDirectoryRepositoryProvider)
          .reserve(phoneE164: widget.phoneE164, uid: uid);
      if (!mounted) return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneE164,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android otomatik doğrulaması: kod elle girilmeden tamamlanır.
          await _applyCredential(credential);
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;
          setState(() => _step = _Step.idle);
          _setFeedback(
            _describeError(error),
            FeedbackTone.error,
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _step = _Step.code;
            _wrongCodeAttempts = 0;
          });
          _setFeedback(
            context.t('phoneVerify.feedback.codeSent'),
            FeedbackTone.success,
          );
          // Cihazın SMS kodu önerisini bu alana bağla; kod alana düşünce
          // aşağıdaki onChanged otomatik onayı başlatır.
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
      setState(() => _step = _Step.idle);
      _setFeedback(_describeError(error), FeedbackTone.error);
    }
  }

  Future<void> _confirmCode() async {
    final String code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _setFeedback(
        context.t('phoneVerify.error.codeFormat'),
        FeedbackTone.error,
      );
      return;
    }
    final String? verificationId = _verificationId;
    if (verificationId == null) return;

    setState(() => _confirming = true);
    _setFeedback(context.t('phoneVerify.feedback.confirming'));

    await _applyCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
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
      if ((user.phoneNumber ?? '').isNotEmpty) {
        await user.updatePhoneNumber(credential);
      } else {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (error) {
          // Yarış durumu: sağlayıcı zaten bağlıysa güncelleme yoluna düş.
          if (error.code == 'provider-already-linked') {
            await user.updatePhoneNumber(credential);
          } else {
            rethrow;
          }
        }
      }

      await _persist(user);
    } catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _setFeedback(_describeError(error), FeedbackTone.error);
    }
  }

  /// Auth tarafı tamamlandı; şimdi Firestore.
  ///
  /// firestore.rules `request.auth.token.phone_number` iddiasını profildeki
  /// `phone` ile karşılaştırır ve bu iddia yalnızca YENİ alınan bir token'da
  /// bulunur — bu yüzden yazmadan önce token zorla tazelenir.
  Future<void> _persist(User user) async {
    try {
      await user.getIdToken(true);

      await ref
          .read(profileRepositoryProvider)
          .setVerifiedPhone(
            uid: user.uid,
            role: widget.role,
            phoneE164: widget.phoneE164,
          );

      // Sahiplik dizini: bundan sonra bu numarayı başka hesap alamaz.
      await ref
          .read(phoneDirectoryRepositoryProvider)
          .claim(
            phoneE164: widget.phoneE164,
            uid: user.uid,
            previousPhoneE164: widget.previousPhoneE164,
          );

      // Şifre sıfırlama ekranının gösterdiği maskeli ipucunu tazele.
      // En iyi çaba: yazılamazsa doğrulama akışı bozulmaz.
      final String email = user.email ?? '';
      if (email.isNotEmpty) {
        final Session session = ref.read(sessionProvider);
        await ref
            .read(phoneHintRepositoryProvider)
            .write(
              email: email,
              maskedPhone: maskE164ForDisplay(widget.phoneE164),
              roles: <String>[
                if (session.hasStudentRole) UserRole.student,
                if (session.hasClubRole) UserRole.club,
                if (!session.hasAnyRole) widget.role,
              ],
            );
      }

      if (!mounted) return;
      setState(() {
        _step = _Step.success;
        _confirming = false;
      });
      _setFeedback(
        context.t('phoneChange.feedback.success'),
        FeedbackTone.success,
      );

      // Başarı işaretini kullanıcı görsün, sonra pencere kendi kapanır.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      _close(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _setFeedback(_describeError(error), FeedbackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _step == _Step.sending || _confirming;

    return PopScope(
      // Geri hareketiyle kapanmayı engellemiyoruz; yalnızca kapanışı işaretliyoruz
      // ki gecikmeli başarı kapanışı ikinci bir pop denemesin.
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) _closing = true;
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.t('phoneVerifySheet.title'),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Her adımda açık: kullanıcı doğrulamadan vazgeçebilir.
                    IconButton(
                      tooltip: context.t('common.cancel'),
                      onPressed: () => _close(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    context.t('phoneVerifySheet.subtitle'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: context.surface,
                    border: Border.all(color: context.hairline),
                    borderRadius: BorderRadius.circular(
                      BrandShape.controlRadius,
                    ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FeedbackBanner(message: _feedback, tone: _tone),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildStep(context, busy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep(BuildContext context, bool busy) {
    switch (_step) {
      case _Step.idle:
      case _Step.sending:
        return <Widget>[
          FilledButton(
            onPressed: busy ? null : _sendCode,
            child: busy
                ? const _ButtonSpinner()
                : Text(context.t('phoneChange.sendCode')),
          ),
        ];

      case _Step.code:
        return <Widget>[
          TextField(
            controller: _code,
            focusNode: _codeFocus,
            enabled: !_confirming,
            keyboardType: TextInputType.number,
            autofillHints: const <String>[AutofillHints.oneTimeCode],
            enableSuggestions: true,
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
              if (value.length == 6 && !_confirming) _confirmCode();
            },
            onSubmitted: (_) => _confirmCode(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirming ? null : _confirmCode,
            child: _confirming
                ? const _ButtonSpinner()
                : Text(context.t('phoneChange.confirmAndSave')),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _resendIn > 0 || _confirming ? null : _sendCode,
            child: Text(
              _resendIn > 0
                  ? '${context.t('phoneVerify.resend')} ($_resendIn s)'
                  : context.t('phoneVerify.resend'),
            ),
          ),
        ];

      case _Step.success:
        return const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(
              Icons.check_circle_outline,
              size: 42,
              color: BrandColors.success,
            ),
          ),
        ];
    }
  }
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
