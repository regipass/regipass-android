import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/live_phone_field.dart';
import '../shared/phone_field.dart';

/// phone-change.html + js/pages/phone-change.js karşılığı.
///
/// Numara değiştiğinde `phoneVerified` false yapılır; router bu değişikliği
/// görünce kullanıcıyı otomatik olarak doğrulama ekranına geri alır.
class PhoneChangeScreen extends ConsumerStatefulWidget {
  const PhoneChangeScreen({super.key});

  @override
  ConsumerState<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends ConsumerState<PhoneChangeScreen> {
  final PhoneFieldController _phone = PhoneFieldController();

  bool _saving = false;

  /// Telefon alanının altında gösterilen sahiplik uyarısı.
  String? _phoneError;

  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _save() async {
    final Session session = ref.read(sessionProvider);
    final String? uid = session.user?.uid;
    if (uid == null) return;

    if (!_phone.isValid) {
      _setFeedback(
        context.t('phoneChange.feedback.invalidPhone'),
        FeedbackTone.error,
      );
      return;
    }

    final String newPhone = _phone.e164;
    final String currentPhone =
        session.user?.phoneNumber ??
        session.studentProfile?.phone ??
        session.clubProfile?.phone ??
        '';

    if (currentPhone == newPhone) {
      _setFeedback(
        context.t('phoneChange.feedback.samePhone'),
        FeedbackTone.error,
      );
      return;
    }

    setState(() {
      _saving = true;
      _phoneError = null;
    });
    _setFeedback(context.t('phoneChange.feedback.saving'));

    // Sahiplik sorgusu doğrulama adımından ÖNCE: numara başka bir hesaba
    // aitse kullanıcıyı boşuna SMS beklemeye göndermiyoruz. Sorgu yapılamazsa
    // akış durmaz — Firebase Auth telefon bağlarken ikinci kez kontrol eder.
    final PhoneOwnership ownership = await ref
        .read(phoneDirectoryRepositoryProvider)
        .lookup(phoneE164: newPhone, uid: uid);

    if (!mounted) return;
    final String? problem = phoneOwnershipError(context, ownership);
    if (problem != null) {
      setState(() {
        _saving = false;
        _phoneError = problem;
      });
      _setFeedback(problem, FeedbackTone.error);
      return;
    }

    try {
      final String role = session.resolvedRole ?? UserRole.student;
      await ref
          .read(profileRepositoryProvider)
          .changePhone(uid, role, newPhone);

      if (mounted && context.canPop()) context.pop();
    } catch (error) {
      if (!mounted) return;
      _setFeedback(
        context.t('phoneChange.feedback.saveError'),
        FeedbackTone.error,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    final String currentPhone =
        session.user?.phoneNumber ??
        session.studentProfile?.phone ??
        session.clubProfile?.phone ??
        '';

    return NarrowScaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t('phoneChange.title'),
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              context.t('phoneChange.subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            Text(
              context.t('phoneChange.currentLabel'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              currentPhone.isEmpty
                  ? context.t('phoneChange.noCurrentPhone')
                  : formatE164ForDisplay(currentPhone),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            FeedbackBanner(message: _feedback, tone: _tone),

            LivePhoneField(
              controller: _phone,
              label: context.t('phoneChange.newLabel'),
              enabled: !_saving,
              errorText: _phoneError,
              onChanged: () {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(context.t('phoneChange.save')),
            ),
          ],
        ),
      ),
    );
  }
}
