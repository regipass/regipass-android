/// İP-ON (mobil 1.0.13): online etkinlikte "Yayına katıl" + anlık yoklama kodu.
/// Web: js/modules/events/online-join.js.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../domain/online_rules.dart';
import '../../domain/plans.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';

class OnlineJoinCard extends ConsumerStatefulWidget {
  const OnlineJoinCard({super.key, required this.event});

  final AppEvent event;

  @override
  ConsumerState<OnlineJoinCard> createState() => _OnlineJoinCardState();
}

class _OnlineJoinCardState extends ConsumerState<OnlineJoinCard> {
  final TextEditingController _code = TextEditingController();
  Timer? _tick;
  bool _busy = false;
  String _note = '';
  String _codeFeedback = '';
  bool _codeOk = false;

  @override
  void initState() {
    super.initState();
    // Pencere ve yoklama durumu dakikalar içinde değişir; ekran tazelenir.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  String _time(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final String url = await ref.read(onlineServiceProvider).join(widget.event.id);
      final Uri? uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) setState(() => _note = url);
      }
    } on RegistrationFailure catch (error) {
      if (!mounted) return;
      final Object? opens = error.details['opensAtMs'];
      setState(() => _note = context.t(onlineJoinErrorKey(error.reason), <String, Object?>{
            'time': opens is num ? _time(opens.toInt()) : '',
          }));
    } catch (_) {
      if (mounted) setState(() => _note = context.t('online.join.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCode() async {
    final String? code = cleanOnlineCode(_code.text);
    if (code == null) {
      setState(() {
        _codeOk = false;
        _codeFeedback = context.t('online.code.prompt');
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final ({int attended, int total, bool already}) r =
          await ref.read(onlineServiceProvider).checkIn(widget.event.id, code);
      if (!mounted) return;
      setState(() {
        _codeOk = true;
        _codeFeedback = r.already
            ? context.t('online.code.already')
            : context.t('online.code.ok', <String, Object?>{'attended': r.attended, 'total': r.total});
        _code.clear();
      });
    } on RegistrationFailure catch (error) {
      if (mounted) {
        setState(() {
          _codeOk = false;
          _codeFeedback = context.t(onlineCodeErrorKey(error.reason));
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppEvent e = widget.event;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ({int opensAtMs, int closesAtMs}) w = eventJoinWindow(e);
    final bool notYet = now < w.opensAtMs;
    final bool over = now > w.closesAtMs;
    final String status = _note.isNotEmpty
        ? _note
        : notYet
            ? context.t('online.join.opensAt', <String, Object?>{'time': _time(w.opensAtMs)})
            : over
                ? context.t('online.join.closed')
                : context.t('online.join.readyMobile');
    final bool codeOpen = onlineCheckpointOpen(e, now) > 0 && planFeatureAllowed(e.planTier, 'gateQr');
    return Container(
      key: const Key('onlineJoinCard'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D3557).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1D3557).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('💻 ${context.t('online.format.online')}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          SelectableText(status, style: TextStyle(fontSize: 13.5, height: 1.4, color: context.inkMuted)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy || notYet || over ? null : _join,
            icon: const Icon(Icons.videocam_outlined),
            label: Text(context.t('online.join.button')),
          ),
          if (codeOpen) ...<Widget>[
            const SizedBox(height: 14),
            Text(context.t('online.code.title'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    decoration: InputDecoration(hintText: '000000', labelText: context.t('online.code.prompt')),
                    onSubmitted: (_) => _submitCode(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _submitCode, child: Text(context.t('online.code.submit'))),
              ],
            ),
            if (_codeFeedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _codeFeedback,
                  style: TextStyle(fontSize: 13, color: _codeOk ? const Color(0xFF1F7A45) : const Color(0xFFC0292B)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
