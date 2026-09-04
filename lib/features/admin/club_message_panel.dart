/// Yöneticinin tek bir kulübe not yazdığı panel.
///
/// Web karşılığı: `admin-dashboard.html` ve `admin-clubs.html` içindeki
/// "Kulübe Mesaj Gönder" bölümü (`js/modules/admin/club-messages.js`).
///
/// Neden var: eksik belge ya da düzeltilmesi gereken bir durumda yönetici
/// kulübü onaylamak ya da engellemek zorunda kalmadan sebebi yazabilsin.
/// Başvuru `pending_review` durumunda kalır; kulüp notu onay bekleme
/// ekranında görür.
///
/// Onay kuyruğundaki "Belge Eksik" düğmesinden farkı: o, kulübü belge
/// yükleme aşamasına **geri gönderir**; buradaki not ise durumu hiç
/// değiştirmez — yalnızca konuşur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';
import '../shared/admin_message_log.dart';
import '../shared/common_widgets.dart';

class ClubMessagePanel extends ConsumerStatefulWidget {
  const ClubMessagePanel({required this.club, this.onSent, super.key});

  final ClubProfile club;

  /// Gönderim başarılı olduğunda çağrılır — çağıran ekran kendi kopyasındaki
  /// listeyi tazeleyebilsin diye (sunucudan yeni anlık görüntü beklemeden).
  final ValueChanged<AdminMessage>? onSent;

  @override
  ConsumerState<ClubMessagePanel> createState() => _ClubMessagePanelState();
}

class _ClubMessagePanelState extends ConsumerState<ClubMessagePanel> {
  final TextEditingController _controller = TextEditingController();

  /// Yerel liste: gönderilen not, sunucudan yeni veri gelmeden de görünsün.
  late List<AdminMessage> _messages = widget.club.adminMessages;

  bool _busy = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  @override
  void didUpdateWidget(ClubMessagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dışarıdan yeni profil geldiğinde (canlı akış) liste tazelensin; ancak
    // bizim eklediğimiz kayıt henüz sunucudan dönmediyse kaybolmasın.
    if (widget.club.adminMessages.length > _messages.length) {
      _messages = widget.club.adminMessages;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = sanitizeLongText(
      _controller.text,
      maxLength: InputLimits.adminMessage,
    );

    if (text.isEmpty) {
      setState(() {
        _feedback = context.t('admin.message.empty');
        _tone = FeedbackTone.error;
      });
      return;
    }

    setState(() {
      _busy = true;
      _feedback = context.t('admin.feedback.processing');
      _tone = FeedbackTone.info;
    });

    try {
      final AdminMessage entry = await ref
          .read(adminRepositoryProvider)
          .sendClubMessage(
            clubUid: widget.club.uid,
            message: text,
            adminUid: ref.read(sessionProvider).user?.uid ?? '',
          );
      if (!mounted) return;

      _controller.clear();
      setState(() {
        _messages = <AdminMessage>[entry, ..._messages];
        _feedback = context.t('admin.message.sent');
        _tone = FeedbackTone.success;
      });
      widget.onSent?.call(entry);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback = context.t('admin.message.error');
        _tone = FeedbackTone.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.t('admin.message.title'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: context.brandInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t('admin.message.hint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          enabled: !_busy,
          maxLines: 3,
          inputFormatters: guardedInput(
            InputLimits.adminMessage,
            multiline: true,
          ),
          decoration: InputDecoration(
            hintText: context.t('admin.message.placeholder'),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(context.t('admin.message.send')),
        ),
        if (_feedback != null) ...<Widget>[
          const SizedBox(height: 10),
          FeedbackBanner(message: _feedback, tone: _tone),
        ],
        const SizedBox(height: 8),
        AdminMessageLog(messages: _messages),
      ],
    );
  }
}
