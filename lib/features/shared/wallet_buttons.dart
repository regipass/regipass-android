/// Bilet ekranında "Apple / Google Cüzdan'a ekle" (İP-W). Ayar kapalıyken
/// hiçbir şey çizmez.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/wallet.dart';
import '../../l10n/app_strings.dart';
import '../../services/wallet_service.dart';

class WalletButtons extends ConsumerStatefulWidget {
  const WalletButtons({
    required this.registrationId,
    required this.cancelled,
    required this.paymentPending,
    this.platformOverride,
    super.key,
  });

  final String registrationId;
  final bool cancelled;
  final bool paymentPending;

  /// Testler için cihaz türü.
  final TargetPlatform? platformOverride;

  @override
  ConsumerState<WalletButtons> createState() => _WalletButtonsState();
}

class _WalletButtonsState extends ConsumerState<WalletButtons> {
  WalletPlatform? _busy;

  Future<void> _add(WalletPlatform platform) async {
    if (_busy != null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String lang = context.lang;
    setState(() => _busy = platform);
    try {
      final String url = await ref
          .read(walletServiceProvider)
          .passUrl(widget.registrationId, platform, lang: lang);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t(walletErrorKey(walletErrorReason(error)))),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!walletAllowed(
      cancelled: widget.cancelled,
      paymentPending: widget.paymentPending,
    )) {
      return const SizedBox.shrink();
    }
    final Map<String, Object?>? config = ref.watch(walletConfigProvider).value;
    final TargetPlatform platform =
        widget.platformOverride ?? defaultTargetPlatform;
    final List<WalletPlatform> buttons = walletButtonsFor(
      config,
      isIos: platform == TargetPlatform.iOS,
      isAndroid: platform == TargetPlatform.android,
    );
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        for (final WalletPlatform p in buttons)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey<String>('wallet-${p.name}'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy == null ? () => _add(p) : null,
                icon: _busy == p
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  context.t(
                    p == WalletPlatform.apple
                        ? 'wallet.addApple'
                        : 'wallet.addGoogle',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
