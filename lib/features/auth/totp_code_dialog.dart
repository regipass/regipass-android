/// Doğrulayıcı uygulama kodu (İP-M1) — admin-login.html "Doğrulama kodu"
/// adımının karşılığı. Yalnızca yönetim ekibinin hesaplarında iki aşamalı
/// doğrulama var; şifre doğruysa Firebase `FirebaseAuthMultiFactorException`
/// döner ve 6 haneli kod burada istenir.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/staff_access.dart';
import '../../l10n/app_strings.dart';

/// Kodu sorar. Vazgeçilirse null.
Future<String?> askTotpCode(BuildContext context) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext dialogContext) => const _TotpCodeDialog(),
);

/// Şifreden sonra ikinci adım: kodu sorar ve oturumu tamamlar.
///
/// Vazgeçilirse `null`; hesapta doğrulayıcı uygulama yoksa
/// `multi-factor-unsupported` kodlu hata fırlatır.
Future<UserCredential?> resolveTotpSignIn(
  BuildContext context,
  MultiFactorResolver resolver,
) async {
  final MultiFactorInfo? hint = resolver.hints
      .where((MultiFactorInfo h) => h.factorId == 'totp')
      .firstOrNull;
  if (hint == null) {
    throw FirebaseAuthException(code: 'multi-factor-unsupported');
  }
  final String? code = await askTotpCode(context);
  if (code == null) return null;
  final MultiFactorAssertion assertion =
      await TotpMultiFactorGenerator.getAssertionForSignIn(hint.uid, code);
  return resolver.resolveSignIn(assertion);
}

class _TotpCodeDialog extends StatefulWidget {
  const _TotpCodeDialog();

  @override
  State<_TotpCodeDialog> createState() => _TotpCodeDialogState();
}

class _TotpCodeDialogState extends State<_TotpCodeDialog> {
  final TextEditingController _code = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final String code = normalizeTotpCode(_code.text);
    if (code.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('auth.totp.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.t('auth.totp.body')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('totpCodeField'),
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const <String>[AutofillHints.oneTimeCode],
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(7),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 6),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.t('auth.totp.label'),
              errorText: _showError ? context.t('auth.totp.format') : null,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        TextButton(
          key: const Key('totpCodeSubmit'),
          onPressed: _submit,
          child: Text(context.t('auth.totp.submit')),
        ),
      ],
    );
  }
}
