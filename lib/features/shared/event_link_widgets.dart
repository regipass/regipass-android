/// İP-EL: katılımcının "Paylaş" düğmesi ve organizatörün link kartı.
/// Web karşılığı: js/modules/events/event-link-panel.js.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/event_link_service.dart';

Rect? _originOf(BuildContext context) {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<void> _shareText(BuildContext context, String title, String url) =>
    SharePlus.instance.share(
      ShareParams(
        text: title.isEmpty ? url : '$title\n$url',
        subject: title,
        sharePositionOrigin: _originOf(context),
      ),
    );

/// Etkinlik penceresindeki "Paylaş" düğmesi (katılımcı).
class ShareEventLinkButton extends StatefulWidget {
  const ShareEventLinkButton({super.key, required this.event});

  final AppEvent event;

  @override
  State<ShareEventLinkButton> createState() => _ShareEventLinkButtonState();
}

class _ShareEventLinkButtonState extends State<ShareEventLinkButton> {
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final String url = await const EventLinkService().shareUrl(
        widget.event.id,
      );
      if (!mounted) return;
      await _shareText(context, widget.event.title, url);
    } catch (_) {
      if (mounted) _toast(context, context.t('eventLink.shareFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.cancelled) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('shareEventLink'),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_outlined),
      label: Text(context.t('eventLink.share')),
      onPressed: _busy ? null : _share,
    );
  }
}

/// Organizatörün etkinlik detayındaki link kartı: kopyala, paylaş, QR afişi,
/// özel ad, ziyaret/kayıt sayıları.
class ClubEventLinkCard extends StatefulWidget {
  const ClubEventLinkCard({super.key, required this.event});

  final AppEvent event;

  @override
  State<ClubEventLinkCard> createState() => _ClubEventLinkCardState();
}

class _ClubEventLinkCardState extends State<ClubEventLinkCard> {
  final TextEditingController _slug = TextEditingController();
  ClubEventLink? _link;
  String _error = '';
  bool _saving = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ClubEventLink link = await const EventLinkService().clubLink(
        widget.event.id,
      );
      if (!mounted) return;
      setState(() {
        _link = link;
        _slug.text = link.slug;
        _error = '';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'load');
    }
  }

  Future<void> _saveSlug() async {
    setState(() => _saving = true);
    try {
      await const EventLinkService().setSlug(
        widget.event.id,
        _slug.text.trim(),
      );
      await _load();
      if (!mounted) return;
      setState(() => _editing = false);
      _toast(context, context.t('eventLink.card.slugSaved'));
    } catch (error) {
      if (!mounted) return;
      final String reason = eventLinkErrorReason(error);
      _toast(
        context,
        context.t(
          reason == 'slug-taken' || reason == 'slug-invalid'
              ? 'eventLink.reason.$reason'
              : 'eventLink.card.failed',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// İP-B3: "Linki yenile" — eski link hemen kapanır.
  Future<void> _renew() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('eventLink.card.renew')),
        content: Text(ctx.t('eventLink.card.renewConfirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('eventLink.card.cancel')),
          ),
          TextButton(
            key: const Key('eventLinkRenewConfirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t('eventLink.card.renewDo')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await const EventLinkService().renew(widget.event.id);
      await _load();
      if (!mounted) return;
      setState(() => _editing = false);
      _toast(context, context.t('eventLink.card.renewed'));
    } catch (_) {
      if (mounted) _toast(context, context.t('eventLink.card.failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClubEventLink? link = _link;
    final TextStyle muted = TextStyle(fontSize: 12.5, color: context.inkMuted);
    if (link == null) {
      return _error.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: Text(context.t('eventLink.card.failed'), style: muted),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _error = '');
                    _load();
                  },
                  child: Text(context.t('eventLink.card.retry')),
                ),
              ],
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.t(
            widget.event.isLinkOnly
                ? 'eventLink.card.hintLinkOnly'
                : 'eventLink.card.hint',
          ),
          style: muted,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.inkMuted.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            link.url,
            key: const Key('eventLinkUrl'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(context.t('eventLink.card.copy')),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link.url));
                if (context.mounted) {
                  _toast(context, context.t('eventLink.card.copied'));
                }
              },
            ),
            Builder(
              builder: (BuildContext b) => OutlinedButton.icon(
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: Text(context.t('eventLink.share')),
                onPressed: () => _shareText(b, widget.event.title, link.url),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: Text(context.t('eventLink.card.poster')),
              onPressed: () => launchUrl(
                Uri.parse(eventPosterUrl(link.key)),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.t('eventLink.card.stats', <String, Object?>{
            'views': link.views,
            'regs': link.registrations,
          }),
          style: muted,
        ),
        const SizedBox(height: 6),
        if (!_editing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _editing = true),
              child: Text(
                context.t(
                  link.slug.isEmpty
                      ? 'eventLink.card.slugAdd'
                      : 'eventLink.card.slugEdit',
                ),
              ),
            ),
          )
        else ...<Widget>[
          TextField(
            controller: _slug,
            enabled: !_saving,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveSlug(),
            decoration: InputDecoration(
              prefixText: '/e/',
              labelText: context.t('eventLink.card.slugLabel'),
              helperText: context.t('eventLink.card.slugHint'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: _saving ? null : _saveSlug,
                child: Text(context.t('eventLink.card.slugSave')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _editing = false;
                        _slug.text = link.slug;
                      }),
                child: Text(context.t('eventLink.card.cancel')),
              ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('eventLinkRenew'),
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: Text(context.t('eventLink.card.renew')),
            onPressed: _saving ? null : _renew,
          ),
        ),
      ],
    );
  }
}
