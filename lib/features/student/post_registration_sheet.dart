/// Kayıttan sonra: takvim ve bilet (İP-T2) — js/modules/events/post-registration.js.
///
/// Kayıt başarıyla bitince eski kısa uyarı yerine bu pencere açılır ve SORAR;
/// hiçbir şey kendiliğinden takvime yazılmaz:
///   - Google Takvim ya da takvim uygulaması (.ics) — telefonun takvim ekranı
///     dolu açılır, kişi tek dokunuşla kaydeder.
///   - Bileti resim olarak kaydet (kapı girişi olan etkinlikte).
///   - Apple / Google Cüzdan'a ekle (İP-B2; ödeme bekleyende görünmez).
///   - "Bundan sonra sorma": cihazda hatırlanır; pencere yerine kısa uyarı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/providers.dart';
import '../shared/add_to_calendar_button.dart';
import '../shared/ticket_image.dart';
import '../shared/wallet_buttons.dart';

const String kPostRegistrationSkipKey = 'regipass.postRegistration.skip';

Future<bool> postRegistrationSkipped() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPostRegistrationSkipKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _setSkipped(bool value) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPostRegistrationSkipKey, value);
  } catch (_) {
    // Hatırlanmazsa bir dahaki kayıtta yine sorulur.
  }
}

/// Pencereyi açar. [message] başarı metni (ücretlide ödeme notu dahil).
Future<void> showPostRegistrationSheet(
  BuildContext context, {
  required AppEvent event,
  required String message,
  bool paymentPending = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PostRegistrationSheet(
      event: event,
      message: message,
      paymentPending: paymentPending,
    ),
  );
}

class _PostRegistrationSheet extends ConsumerStatefulWidget {
  const _PostRegistrationSheet({
    required this.event,
    required this.message,
    this.paymentPending = false,
  });

  final AppEvent event;
  final String message;
  final bool paymentPending;

  @override
  ConsumerState<_PostRegistrationSheet> createState() =>
      _PostRegistrationSheetState();
}

class _PostRegistrationSheetState
    extends ConsumerState<_PostRegistrationSheet> {
  bool _skip = false;
  bool _ticketBusy = false;
  String? _feedback;

  Rect? _originOf(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _saveTicket(BuildContext buttonContext) async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final Rect? origin = _originOf(buttonContext);
    setState(() {
      _ticketBusy = true;
      _feedback = context.t('postRegistration.ticketPreparing');
    });
    final String registrationId = '${widget.event.id}_$uid';
    String code = '';
    try {
      code = await ref
          .read(attendanceServiceProvider)
          .ensureTicketCode(registrationId);
    } catch (_) {
      code = '';
    }
    final String name = ref.read(studentProfileProvider).value?.fullName ?? '';
    if (!mounted) return;
    final bool english = context.lang == 'en';
    try {
      await shareTicketImage(
        event: widget.event,
        registrationId: registrationId,
        studentId: uid,
        ticketCode: code,
        studentName: name,
        origin: origin,
        english: english,
      );
      if (mounted) {
        setState(() => _feedback = context.t('postRegistration.ticketReady'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = context.t('postRegistration.ticketError'));
      }
    } finally {
      if (mounted) setState(() => _ticketBusy = false);
    }
  }

  Future<void> _close() async {
    if (_skip) await _setSkipped(true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppEvent event = widget.event;
    final bool calendar = canAddToCalendar(event);
    final bool ticket = event.hasDoorCheckin;
    final String? uid = ref.watch(currentUidProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: BrandColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: BrandColors.success,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('postRegistration.title'),
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            event.title,
            textAlign: TextAlign.center,
            style: text.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          if (calendar) ...<Widget>[
            const Divider(height: 28),
            Text(
              context.t('postRegistration.calendarAsk'),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                // Tek dokunuşla cihazın takvim ekranı (iPhone: Apple Takvim).
                FilledButton.icon(
                  key: const Key('postRegCalendar'),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(context.t('calendar.add')),
                  onPressed: () => addToDeviceCalendar(event),
                ),
                OutlinedButton.icon(
                  key: const Key('postRegGoogle'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(context.t('calendar.google')),
                  onPressed: () => openGoogleCalendar(event),
                ),
              ],
            ),
          ],
          if (ticket) ...<Widget>[
            const Divider(height: 28),
            Text(
              context.t('postRegistration.ticketTitle'),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (BuildContext b) => OutlinedButton.icon(
                key: const Key('postRegTicket'),
                icon: const Icon(Icons.qr_code_2),
                label: Text(context.t('postRegistration.ticketSave')),
                onPressed: _ticketBusy ? null : () => _saveTicket(b),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('postRegistration.ticketHint'),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
          // İP-B2: cüzdana ekle (ayar kapalıyken / ödeme bekleyende boş).
          if (uid != null)
            WalletButtons(
              key: const Key('postRegWallet'),
              registrationId: '${event.id}_$uid',
              cancelled: event.cancelled,
              paymentPending: widget.paymentPending,
            ),
          if (_feedback != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _feedback!,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: BrandColors.success),
            ),
          ],
          const SizedBox(height: 10),
          CheckboxListTile(
            key: const Key('postRegSkip'),
            value: _skip,
            onChanged: (bool? v) => setState(() => _skip = v ?? false),
            title: Text(
              context.t('postRegistration.skip'),
              style: text.bodySmall,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('postRegClose'),
              onPressed: _close,
              child: Text(context.t('postRegistration.done')),
            ),
          ),
        ],
      ),
    );
  }
}
