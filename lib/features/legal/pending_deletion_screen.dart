import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../services/account_deletion_service.dart';
import '../../state/providers.dart';

/// İP-G2: kullanıcı hesabını silmek istedi, 30 günlük süre dolmadı.
/// (web: js/modules/auth/reconsent-gate.js → showPendingDeletionGate)
/// "Hesabımı geri al" talebi iptal eder; kullanıcı belgesi akışı güncellenince
/// yönlendirme kendiliğinden panele döner.
class PendingDeletionScreen extends ConsumerStatefulWidget {
  const PendingDeletionScreen({super.key, this.service = const AccountDeletionService()});

  final AccountDeletionService service;

  @override
  ConsumerState<PendingDeletionScreen> createState() => _PendingDeletionScreenState();
}

class _PendingDeletionScreenState extends ConsumerState<PendingDeletionScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _restore() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.cancelMyDeletion();
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.t(error.reason == 'admin-scheduled'
            ? 'pendingDeletion.adminScheduled'
            : 'pendingDeletion.error');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.t('pendingDeletion.error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? purgeAfterMs = ref.watch(sessionProvider).appUser?.pendingDeletionPurgeAfterMs;
    final String date = formatDeadline(purgeAfterMs, locale: context.lang);
    return ReadableScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.schedule_rounded, color: BrandColors.red, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              context.t('pendingDeletion.title'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.ink, height: 1.2),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('pendingDeletion.lead', <String, Object?>{'date': date}),
              style: TextStyle(fontSize: 15, color: context.inkBody, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              context.t('pendingDeletion.note'),
              style: TextStyle(fontSize: 14, color: context.inkMuted, height: 1.45),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.red,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: _saving ? null : _restore,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        context.t('pendingDeletion.restore'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: BrandColors.redDark, fontSize: 13.5)),
            ],
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => ref.read(authRepositoryProvider).signOut(),
                child: Text(
                  context.t('pendingDeletion.signOut'),
                  style: TextStyle(color: context.inkMuted, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
