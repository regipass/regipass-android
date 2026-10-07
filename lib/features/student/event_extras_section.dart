/// İP-FS / İP-PS / İP-SL / İP-FT (mobil 1.0.13): bilet penceresinde
/// Fişlerim, Stant pasaportum, Programım ve Etkinlik fotoğrafları.
/// Web: voucher-participant.js, passport-card.js, hall-card.js, photo-gallery.js.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_extras.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/firebase_refs.dart';
import '../shared/qr_code_view.dart';

typedef _Extras = ({
  Map<String, dynamic>? vouchers,
  Map<String, dynamic>? redemption,
  Map<String, dynamic>? passport,
  Map<String, dynamic>? stamps,
  Map<String, dynamic>? halls,
  Map<String, dynamic>? attendance,
});

Future<Map<String, dynamic>?> _read(String col, String id) async {
  try {
    final Snap snap = await fbDb.collection(col).doc(id).get();
    return snap.exists ? snap.data() : null;
  } catch (_) {
    return null;
  }
}

/// Anahtar: "eventId|studentId".
// ignore: always_specify_types
final eventExtrasProvider = FutureProvider.autoDispose.family<_Extras, String>((Ref ref, String key) async {
  final List<String> parts = key.split('|');
  final String eventId = parts.first;
  final String uid = parts.length > 1 ? parts[1] : '';
  final List<Map<String, dynamic>?> r = await Future.wait(<Future<Map<String, dynamic>?>>[
    _read('event_vouchers', eventId),
    _read('voucher_redemptions', '${eventId}_$uid'),
    _read('event_passport', eventId),
    _read('passport_stamps', '${eventId}_$uid'),
    _read('event_halls', eventId),
    _read('hall_attendance', '${eventId}_$uid'),
  ]);
  return (vouchers: r[0], redemption: r[1], passport: r[2], stamps: r[3], halls: r[4], attendance: r[5]);
});

class EventExtrasSection extends ConsumerStatefulWidget {
  const EventExtrasSection({
    super.key,
    required this.event,
    required this.registrationId,
    required this.studentId,
    required this.ticketCode,
    required this.checkedIn,
  });

  final AppEvent event;
  final String registrationId;
  final String studentId;
  final String ticketCode;
  final bool checkedIn;

  @override
  ConsumerState<EventExtrasSection> createState() => _EventExtrasSectionState();
}

class _EventExtrasSectionState extends ConsumerState<EventExtrasSection> {
  bool _showQr = false;

  Widget _card(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.inkMuted.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      );

  String _hm(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppEvent e = widget.event;
    if (e.cancelled || e.isOnline) return const SizedBox.shrink();
    final _Extras? x = ref.watch(eventExtrasProvider('${e.id}|${widget.studentId}')).value;
    final List<Widget> out = <Widget>[];

    // ── Fişlerim ──
    final List<VoucherState> vouchers = x == null ? const <VoucherState>[] : participantVouchers(x.vouchers, x.redemption);
    if (vouchers.isNotEmpty) {
      final bool needsDoor = vouchers.any((VoucherState v) => v.needsDoor && v.state != 'used') && !widget.checkedIn;
      out.add(_card(context.t('voucher.mine.title'), <Widget>[
        for (final VoucherState v in vouchers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: <Widget>[
              Text(voucherIcon(v.icon), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              switch (v.state) {
                'used' => _pill(context.t('voucher.state.used'), context.inkMuted),
                'partial' => _pill(context.t('voucher.state.left', <String, Object?>{'n': v.remaining}), const Color(0xFF8A5300)),
                _ => _pill(
                    v.perPerson > 1 ? context.t('voucher.state.availableN', <String, Object?>{'n': v.perPerson}) : context.t('voucher.state.available'),
                    const Color(0xFF1F7A45)),
              },
            ]),
          ),
        if (needsDoor)
          Text(context.t('voucher.mine.needsDoor'), style: TextStyle(fontSize: 12.5, color: context.inkMuted)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showQr = !_showQr),
          icon: const Icon(Icons.qr_code_2),
          label: Text(context.t(_showQr ? 'voucher.mine.hideQr' : 'voucher.mine.showQr')),
        ),
        if (_showQr) ...<Widget>[
          const SizedBox(height: 10),
          Center(
            child: QrCodeView(
              size: 220,
              data: createCheckinQrToken(buildStudentCheckinPayload(
                registrationId: widget.registrationId,
                eventId: e.id,
                studentId: widget.studentId,
                ticketCode: widget.ticketCode,
              )),
            ),
          ),
          const SizedBox(height: 6),
          Text(context.t('voucher.mine.qrHint'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: context.inkMuted)),
        ],
      ]));
    }

    // ── Stant pasaportum ──
    final PassportState? p = x == null ? null : passportProgress(x.passport, x.stamps);
    if (p != null) {
      final String reward = p.rewardName.isEmpty ? context.t('passport.noReward') : p.rewardName;
      out.add(_card('${context.t('passport.card.title')}  ${p.count}/${p.goal}', <Widget>[
        LinearProgressIndicator(value: p.progress, minHeight: 6, borderRadius: BorderRadius.circular(99), color: BrandColors.red),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final ({String id, String name, bool stamped}) s in p.stops)
            Chip(
              avatar: Icon(s.stamped ? Icons.verified : Icons.radio_button_unchecked, size: 18, color: s.stamped ? BrandColors.red : context.inkMuted),
              label: Text(s.name),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
          '🎁 ${p.rewardGiven ? context.t('passport.card.rewardGiven', <String, Object?>{'reward': reward}) : p.complete ? context.t('passport.card.rewardReady', <String, Object?>{'reward': reward}) : context.t('passport.card.rewardLeft', <String, Object?>{'n': p.goal - p.count, 'reward': reward})}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(context.t('passport.card.hint'), style: TextStyle(fontSize: 12.5, color: context.inkMuted)),
      ]));
    }

    // ── Programım ──
    final ({List<ProgramSlot> slots, int count, int? minSessions})? prog = x == null ? null : myProgram(x.halls, x.attendance);
    if (prog != null) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int? min = prog.minSessions;
      out.add(_card('${context.t('hall.card.title')} · ${context.t('hall.card.count', <String, Object?>{'n': prog.count})}', <Widget>[
        if (min != null)
          Text(
            context.t(prog.count >= min ? 'hall.card.minDone' : 'hall.card.minLeft', <String, Object?>{'n': (min - prog.count).clamp(0, min), 'min': min}),
            style: TextStyle(fontWeight: FontWeight.w600, color: prog.count >= min ? const Color(0xFF1F7A45) : const Color(0xFF8A5300)),
          ),
        for (final ProgramSlot s in prog.slots)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(_hm(s.startMs), style: const TextStyle(fontWeight: FontWeight.w700)),
            title: Text(s.title),
            subtitle: Text(<String>[s.hallName, if (s.speaker.isNotEmpty) s.speaker].join(' · ')),
            trailing: s.attended
                ? const Icon(Icons.check_circle, color: Color(0xFF1F7A45))
                : s.liveAt(now)
                    ? const Icon(Icons.circle, size: 12, color: BrandColors.red)
                    : null,
          ),
        Text(context.t('hall.card.hint'), style: TextStyle(fontSize: 12.5, color: context.inkMuted)),
      ]));
    }

    // ── Fotoğraflar ──
    if (e.photosNotifiedAtMs > 0) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 14),
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => EventPhotosScreen(eventId: e.id, title: e.title),
          )),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.t('photos.title')),
        ),
      ));
    }

    if (out.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}

/// İP-FT: etkinlik fotoğrafları (sunucu bağlantıları verir; yalnız kayıtlı katılımcı).
class EventPhotosScreen extends StatefulWidget {
  const EventPhotosScreen({super.key, required this.eventId, required this.title});

  final String eventId;
  final String title;

  @override
  State<EventPhotosScreen> createState() => _EventPhotosScreenState();
}

class _EventPhotosScreenState extends State<EventPhotosScreen> {
  List<Map<String, dynamic>>? _photos;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final HttpsCallableResult<Object?> r = await fbFunctions
          .httpsCallable('listEventPhotos', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
          .call(<String, Object?>{'eventId': widget.eventId});
      final Object? raw = r.data;
      final Object? list = raw is Map ? raw['photos'] : null;
      if (!mounted) return;
      setState(() => _photos = <Map<String, dynamic>>[
            if (list is List)
              for (final Object? p in list)
                if (p is Map) Map<String, dynamic>.from(p),
          ]);
    } on FirebaseFunctionsException catch (error) {
      final Object? details = error.details;
      final bool notRegistered = details is Map && details['reason'] == 'not-registered';
      if (mounted) setState(() => _error = notRegistered ? 'photos.notRegistered' : 'voucher.err.generic');
    } catch (_) {
      if (mounted) setState(() => _error = 'voucher.err.generic');
    }
  }

  void _open(int index) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _PhotoViewer(eventId: widget.eventId, photos: _photos!, initial: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>>? photos = _photos;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title.isEmpty ? context.t('photos.title') : widget.title)),
      body: _error.isNotEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(context.t(_error), textAlign: TextAlign.center)))
          : photos == null
              ? const Center(child: CircularProgressIndicator())
              : photos.isEmpty
                  ? Center(child: Text(context.t('photos.noneYet')))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisSpacing: 6, crossAxisSpacing: 6),
                      itemCount: photos.length,
                      itemBuilder: (BuildContext context, int i) => GestureDetector(
                        onTap: () => _open(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(imageUrl: '${photos[i]['thumbUrl']}', fit: BoxFit.cover),
                        ),
                      ),
                    ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.eventId, required this.photos, required this.initial});

  final String eventId;
  final List<Map<String, dynamic>> photos;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  final Set<String> _requested = <String>{};

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _removeMe() async {
    final String id = '${widget.photos[_index]['id']}';
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String sent = context.t('photos.removeSent');
    final String failed = context.t('voucher.err.generic');
    try {
      await fbFunctions.httpsCallable('requestPhotoRemoval').call(<String, Object?>{'eventId': widget.eventId, 'photoId': id, 'note': ''});
      setState(() => _requested.add(id));
      messenger.showSnackBar(SnackBar(content: Text(sent)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String id = '${widget.photos[_index]['id']}';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}'),
        actions: <Widget>[
          IconButton(
            tooltip: context.t('photos.download'),
            icon: const Icon(Icons.download_outlined),
            onPressed: () => launchUrl(Uri.parse('${widget.photos[_index]['fullUrl']}'), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (_, int i) => InteractiveViewer(
                child: CachedNetworkImage(imageUrl: '${widget.photos[i]['fullUrl']}', fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: _requested.contains(id) ? null : _removeMe,
                child: Text(
                  context.t(_requested.contains(id) ? 'photos.removeSent' : 'photos.removeMe'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
