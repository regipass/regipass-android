import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../domain/door_gate.dart';
import '../../l10n/app_strings.dart';
import '../../services/door_gate.dart';
import '../../state/connectivity.dart';
import '../shared/common_widgets.dart';
import 'club_providers.dart';
import 'club_shell.dart';

/// Kapı ekranı (İP-O) — club-qr-checkin.html + gate-view.js karşılığı.
///
/// Kamera HİÇ kapanmaz ve ekrandan çıkılmaz: görevli kartı kapatmadan
/// sıradaki öğrenciyi okutur (100 kişilik kapı). Her okutmada alttaki kart
/// yenisiyle değişir, ~4 sn sonra ince bir şeride küçülür. Sonucu renk + ses
/// + titreşim söyler; görevli isterse kartı sabitler. Sayaca dokununca
/// "Son okutulanlar" açılır (kamera arkada çalışmaya devam eder).
///
/// Sonuç cihazdaki bilet listesinden anında verilir; giriş önce cihaza, sonra
/// sunucuya yazılır. İnternet yoksa okumalar sırada bekler ve bağlantı gelince
/// gönderilir (lib/services/door_gate.dart).
///
/// [eventId] verilirse (etkinlik ekranından gelindiyse) yalnızca o etkinliğin
/// biletleri kabul edilir.
class ClubQrCheckinScreen extends ConsumerStatefulWidget {
  const ClubQrCheckinScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<ClubQrCheckinScreen> createState() =>
      _ClubQrCheckinScreenState();
}

const Duration _kCardVisible = Duration(seconds: 4);
const String _kSoundKey = 'regipass.gate.sound.v1';
const int _kRecentLimit = 60;

const Color _gateOk = Color(0xFF16A34A);
const Color _gateWarn = Color(0xFFD97706);
const Color _gateBad = Color(0xFFDC2626);
// İP-K: ödeme bekleyen bilet (web css/door-gate.css --gate-pay ile aynı).
const Color _gatePay = Color(0xFF7C3AED);

Color _toneColor(GateTone tone) => switch (tone) {
  GateTone.ok => _gateOk,
  GateTone.warn => _gateWarn,
  GateTone.pay => _gatePay,
  _ => _gateBad,
};

enum _SendStatus { pending, sent, conflict, rejected, none }

class _GateItem {
  _GateItem({required this.outcome, required this.nth})
    : key =
          '${outcome.registration?.id ?? outcome.result.code}@${outcome.scannedAtMs}',
      status = outcome.result == GateResult.checkedIn
          ? _SendStatus.pending
          : _SendStatus.none;

  final GateOutcome outcome;
  final int nth;
  final String key;
  _SendStatus status;
  int firstMs = 0;

  /// İP-K: bu okuma için "Ödendi" işaretlendi (düğme gizlenir).
  bool paidDone = false;

  GateTone get tone => switch (status) {
    _SendStatus.conflict => GateTone.warn,
    _SendStatus.rejected => GateTone.bad,
    _ => outcome.tone,
  };
}

String _hhmm(int ms) {
  if (ms <= 0) return '';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((String p) => p.characters.first.toUpperCase()).join();
}

class _ClubQrCheckinScreenState extends ConsumerState<ClubQrCheckinScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: <BarcodeFormat>[BarcodeFormat.qrCode],
    // Aynı kodun tekrarını denetleyici süzer (10 sn); farklı öğrenci hemen
    // işlenir. noDuplicates, aynı öğrencinin ikinci gelişini ("zaten girdi")
    // hiç göstermezdi.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 250,
  );

  DoorGate? _gate;
  StreamSubscription<GateChange>? _changesSub;
  Timer? _flushTimer;
  Timer? _collapseTimer;
  bool _busy = false;
  bool _soundOn = true;
  bool _collapsed = false;
  String _activeEventId = '';
  String _title = '';
  int _flashSeq = 0;
  GateTone _flashTone = GateTone.none;
  final List<_GateItem> _recent = <_GateItem>[];
  String? _pinnedKey;
  int _sessionCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeEventId = widget.eventId ?? '';
    unawaited(_init());
  }

  Future<void> _init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DoorGate? gate = await ref.read(doorGateProvider.future);
    if (!mounted || gate == null) return;
    setState(() {
      _gate = gate;
      _soundOn = prefs.getString(_kSoundKey) != 'off';
    });
    _changesSub = gate.changes.listen(_onGateChange);
    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (gate.pendingCount > 0) unawaited(gate.flush());
    });
    unawaited(gate.flush());
    if (_activeEventId.isNotEmpty) {
      // Etkinlikten gelindiyse liste hemen hazırlanır (internet varsa tazelenir).
      final GatePack? pack = await gate.preparePack(
        _activeEventId,
        force: ref.read(onlineProvider),
      );
      if (mounted && pack != null) setState(() => _title = pack.event.title);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_gate?.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_changesSub?.cancel());
    _flushTimer?.cancel();
    _collapseTimer?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onGateChange(GateChange change) {
    if (!mounted) return;
    final GatePending? item = change.item;
    if (item != null) {
      for (final _GateItem g in _recent) {
        if (g.outcome.registration?.id == item.regId &&
            g.outcome.scannedAtMs == item.checkedInAtMs) {
          g.status = switch (change.type) {
            GateChangeType.sent => _SendStatus.sent,
            GateChangeType.conflict => _SendStatus.conflict,
            GateChangeType.rejected => _SendStatus.rejected,
            _ => g.status,
          };
          g.firstMs = change.firstMs;
        }
      }
    }
    setState(() {});
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final DoorGate? gate = _gate;
    if (_busy || gate == null) return;
    final String? raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _busy = true;
    try {
      final GateOutcome outcome = await gate.processToken(
        raw,
        expectedEventId: widget.eventId ?? '',
      );
      if (!mounted || outcome.result == GateResult.duplicate) return;
      _show(outcome);
    } finally {
      _busy = false;
    }
  }

  void _show(GateOutcome outcome) {
    final int inCount = _recent
        .where((_GateItem g) => g.outcome.result == GateResult.checkedIn)
        .length;
    final _GateItem item = _GateItem(
      outcome: outcome,
      nth: outcome.result == GateResult.checkedIn ? inCount + 1 : 0,
    );
    setState(() {
      _recent.insert(0, item);
      if (_recent.length > _kRecentLimit) _recent.removeLast();
      _sessionCount += 1;
      _collapsed = false;
      _flashTone = outcome.tone;
      _flashSeq += 1;
      if (outcome.event != null) {
        _activeEventId = outcome.event!.id;
        _title = outcome.event!.title;
      }
    });
    _feedback(outcome.tone);
    _collapseTimer?.cancel();
    // İP-K: ödeme bekleyen kart, görevli karar verene kadar küçülmez.
    if (outcome.result == GateResult.paymentPending &&
        (_gate?.canMarkPaid ?? false)) {
      return;
    }
    _collapseTimer = Timer(_kCardVisible, () {
      if (mounted) setState(() => _collapsed = true);
    });
  }

  /// İP-K: kapıda "Ödendi olarak işaretle ve içeri al".
  bool _markingPaid = false;

  Future<void> _markPaid(_GateItem item) async {
    final DoorGate? gate = _gate;
    if (gate == null || _markingPaid) return;
    setState(() => _markingPaid = true);
    try {
      final GateOutcome next = await gate.markPaidAndAdmit(item.outcome);
      if (!mounted) return;
      item.paidDone = true;
      _show(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('gate.markPaidFailed'))),
      );
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  void _feedback(GateTone tone) {
    switch (tone) {
      case GateTone.ok:
        unawaited(HapticFeedback.mediumImpact());
        if (_soundOn) unawaited(SystemSound.play(SystemSoundType.click));
      case GateTone.warn:
      case GateTone.pay:
        unawaited(HapticFeedback.mediumImpact());
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 140),
            HapticFeedback.mediumImpact,
          ),
        );
        if (_soundOn) unawaited(SystemSound.play(SystemSoundType.click));
      case GateTone.bad:
        unawaited(HapticFeedback.heavyImpact());
        unawaited(HapticFeedback.vibrate());
        if (_soundOn) unawaited(SystemSound.play(SystemSoundType.alert));
      case GateTone.none:
        break;
    }
  }

  Future<void> _toggleSound() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _soundOn = !_soundOn);
    await prefs.setString(_kSoundKey, _soundOn ? 'on' : 'off');
  }

  void _pin(String key) => setState(() => _pinnedKey = key);
  void _unpin() => setState(() => _pinnedKey = null);

  void _expand() {
    setState(() => _collapsed = false);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_kCardVisible * 2, () {
      if (mounted) setState(() => _collapsed = true);
    });
  }

  String _hint(_GateItem item) {
    final GateOutcome o = item.outcome;
    if (item.status == _SendStatus.conflict) {
      return context.t('gate.hint.conflict', <String, Object?>{
        'time': _hhmm(item.firstMs),
      });
    }
    if (item.status == _SendStatus.rejected) {
      return context.t('gate.hint.rejected');
    }
    if (o.result == GateResult.checkedIn) {
      if (o.paidAtGate) return context.t('gate.hint.paidAtGate');
      return o.legacy
          ? context.t('gate.hint.legacy')
          : context.t('gate.hint.in');
    }
    if (o.result == GateResult.already) {
      return context.t('gate.hint.already', <String, Object?>{
        'time': _hhmm(o.registration?.checkedInAtMs ?? 0),
      });
    }
    return context.t('gate.hint.${o.result.code}');
  }

  void _openRecent() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: BrandColors.white,
        builder: (BuildContext sheetContext) => _RecentSheet(
          items: List<_GateItem>.of(_recent),
          pinnedKey: _pinnedKey,
          sessionCount: _sessionCount,
          stats: _gate?.stats(_activeEventId),
          hint: _hint,
          onPick: (String key) {
            Navigator.of(sheetContext).pop();
            _pin(key);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool online = ref.watch(onlineProvider);
    ref.listen<bool>(onlineProvider, (bool? was, bool now) {
      if (now && was != true) unawaited(_gate?.flush());
    });

    final DoorGate? gate = _gate;
    final GateStats? stats = gate?.stats(_activeEventId);
    final int pending = gate?.pendingCount ?? 0;
    final _GateItem? current = _recent.isEmpty ? null : _recent.first;
    _GateItem? pinned;
    for (final _GateItem g in _recent) {
      if (g.key == _pinnedKey) pinned = g;
    }

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('dashboard.drawer.qrCheckin'),
        subtitle: context.t('gate.cameraHint'),
        showBack: (widget.eventId ?? '').isNotEmpty,
      ),
      backgroundColor: BrandColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder:
                (BuildContext context, MobileScannerException error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FeedbackBanner(
                      message: context.t('scan.permissionDenied'),
                      tone: FeedbackTone.error,
                    ),
                  ),
                ),
          ),

          // Okuma çerçevesi
          Align(
            alignment: const Alignment(0, -0.25),
            child: IgnorePointer(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: BrandColors.white.withValues(alpha: 0.9),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          // Renkli çerçeve: sonucu bakmadan anlatır.
          if (_flashTone != GateTone.none)
            IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_flashSeq),
                tween: Tween<double>(begin: 1, end: 0),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeIn,
                builder: (BuildContext context, double v, Widget? _) =>
                    Container(
                      decoration: BoxDecoration(
                        color: _toneColor(
                          _flashTone,
                        ).withValues(alpha: 0.2 * v),
                        border: Border.all(
                          color: _toneColor(_flashTone).withValues(alpha: v),
                          width: 10,
                        ),
                      ),
                    ),
              ),
            ),

          // Üst şerit: başlık, ses, sayaç
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x99000000), Color(0x00000000)],
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _title.isEmpty ? context.t('gate.defaultTitle') : _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BrandColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _Pill(
                    onTap: _toggleSound,
                    semanticLabel: _soundOn
                        ? context.t('gate.soundOff')
                        : context.t('gate.soundOn'),
                    child: Icon(
                      _soundOn ? Icons.volume_up : Icons.volume_off,
                      size: 18,
                      color: BrandColors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    onTap: _openRecent,
                    semanticLabel: context.t('gate.openRecent'),
                    child: Text(
                      context.t('gate.counter', <String, Object?>{
                        'n': stats?.checkedIn ?? 0,
                      }),
                      style: const TextStyle(
                        color: BrandColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // İnternet / bekleyen okumalar
          Positioned(
            top: 48,
            left: 12,
            child: _NetChip(online: online, pending: pending),
          ),

          // Kartlar
          Positioned(
            left: 10,
            right: 10,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (current != null && current.key != _pinnedKey)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _GateCard(
                      key: ValueKey<String>(
                        '${current.key}-${_collapsed ? 'c' : 'o'}-${current.status}',
                      ),
                      item: current,
                      hint: _hint(current),
                      collapsed: _collapsed,
                      pinned: false,
                      onTap: _collapsed ? _expand : null,
                      onPinToggle: () => _pin(current.key),
                      onMarkPaid: _gate?.canMarkPaid ?? false
                          ? () => _markPaid(current)
                          : null,
                      markingPaid: _markingPaid,
                    ),
                  ),
                if (pinned != null) ...<Widget>[
                  const SizedBox(height: 8),
                  _GateCard(
                    key: ValueKey<String>('pin-${pinned.key}-${pinned.status}'),
                    item: pinned,
                    hint: _hint(pinned),
                    collapsed: false,
                    pinned: true,
                    onPinToggle: _unpin,
                    onMarkPaid: _gate?.canMarkPaid ?? false
                        ? () => _markPaid(pinned!)
                        : null,
                    markingPaid: _markingPaid,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: const Color(0x33FFFFFF),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NetChip extends StatelessWidget {
  const _NetChip({required this.online, required this.pending});

  final bool online;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (!online) {
      final String waiting = pending > 0
          ? ' · ${context.t('gate.net.pending', <String, Object?>{'n': pending})}'
          : '';
      text = '⚠ ${context.t('gate.net.offline')}$waiting';
      color = _gateWarn;
    } else if (pending > 0) {
      text =
          '⟳ ${context.t('gate.net.sending', <String, Object?>{'n': pending})}';
      color = const Color(0xFF2563EB);
    } else {
      text = '● ${context.t('gate.net.online')}';
      color = _gateOk;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: BrandColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.item,
    required this.hint,
    required this.collapsed,
    required this.pinned,
    required this.onPinToggle,
    this.onTap,
    this.onMarkPaid,
    this.markingPaid = false,
    super.key,
  });

  final _GateItem item;
  final String hint;
  final bool collapsed;
  final bool pinned;
  final VoidCallback onPinToggle;
  final VoidCallback? onTap;

  /// İP-K: ödeme bekleyen bilette kapıdan onay.
  final VoidCallback? onMarkPaid;
  final bool markingPaid;

  @override
  Widget build(BuildContext context) {
    final GateOutcome o = item.outcome;
    final GateRegistration? reg = o.registration;
    final GateTone tone = item.tone;
    final Color c = _toneColor(tone);
    final String label = context.t('gate.result.${o.result.code}');
    final String icon = switch (tone) {
      GateTone.ok => '✓',
      GateTone.warn => '↺',
      GateTone.pay => '₺',
      _ => '✕',
    };
    final String meta = o.result == GateResult.checkedIn
        ? context.t('gate.nth', <String, Object?>{'n': item.nth})
        : _hhmm(o.scannedAtMs);
    final String name = reg == null
        ? label
        : (reg.studentName.isEmpty
              ? context.t('gate.unknownStudent')
              : reg.studentName);
    final String line = <String>[
      if (reg != null && reg.studentDepartment.isNotEmpty)
        reg.studentDepartment,
      if (reg != null && reg.studentClassYear.isNotEmpty) reg.studentClassYear,
    ].join(' · ');

    final Widget band = Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: collapsed ? 4 : 6),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              collapsed && reg != null
                  ? '$icon $label · $name'
                  : '$icon $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: BrandColors.white,
                fontWeight: FontWeight.w800,
                fontSize: collapsed ? 13 : 15,
              ),
            ),
          ),
          Text(
            meta,
            style: const TextStyle(
              color: BrandColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(collapsed ? 6 : 10),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(16),
          border: pinned
              ? Border.all(color: const Color(0xFF4338CA), width: 2)
              : null,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: collapsed
            ? band
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  band,
                  const SizedBox(height: 9),
                  Row(
                    children: <Widget>[
                      _Avatar(
                        name: reg?.studentName ?? '',
                        photoUrl: reg?.studentPhotoUrl ?? '',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF1C1F24),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (line.isNotEmpty)
                              Text(
                                line,
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13,
                                ),
                              ),
                            if (reg != null && reg.studentUniversity.isNotEmpty)
                              Text(
                                reg.studentUniversity,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!pinned) ...<Widget>[
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1, end: 0),
                        duration: _kCardVisible,
                        builder: (BuildContext context, double v, Widget? _) =>
                            LinearProgressIndicator(
                              value: v,
                              minHeight: 3,
                              color: c,
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: hint,
                            children: <InlineSpan>[
                              if (item.status == _SendStatus.pending &&
                                  o.result == GateResult.checkedIn)
                                TextSpan(
                                  text: ' ⏳ ${context.t('gate.notSentYet')}',
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                            ],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onPinToggle,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2FF),
                          foregroundColor: const Color(0xFF3730A3),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          pinned
                              ? context.t('gate.unpin')
                              : '📌 ${context.t('gate.pin')}',
                        ),
                      ),
                    ],
                  ),
                  if (o.result == GateResult.paymentPending &&
                      onMarkPaid != null &&
                      !item.paidDone) ...<Widget>[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gatePay,
                          foregroundColor: BrandColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: markingPaid ? null : onMarkPaid,
                        child: Text(
                          markingPaid
                              ? context.t('gate.markingPaid')
                              : context.t('gate.markPaid'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Center(
      child: Text(
        name.isEmpty ? '?' : _initials(name),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFDBE2EA),
        shape: BoxShape.circle,
      ),
      child: photoUrl.isEmpty
          ? fallback
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _RecentSheet extends StatelessWidget {
  const _RecentSheet({
    required this.items,
    required this.pinnedKey,
    required this.sessionCount,
    required this.stats,
    required this.hint,
    required this.onPick,
  });

  final List<_GateItem> items;
  final String? pinnedKey;
  final int sessionCount;
  final GateStats? stats;
  final String Function(_GateItem) hint;
  final void Function(String key) onPick;

  @override
  Widget build(BuildContext context) {
    final GateStats? s = stats;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.t('gate.recentTitle'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF1C1F24),
                    ),
                  ),
                ),
                Text(
                  context.t('gate.sessionCount', <String, Object?>{
                    'n': sessionCount,
                  }),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
            if (s != null && (s.total > 0 || s.savedAtMs > 0))
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  context.t('gate.packInfo', <String, Object?>{
                    'n': s.total,
                    'time': _hhmm(s.savedAtMs),
                  }),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.t('gate.recentEmpty'),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEEF0F3)),
                  itemBuilder: (BuildContext context, int i) {
                    final _GateItem item = items[i];
                    final GateOutcome o = item.outcome;
                    final String name = o.registration?.studentName ?? '';
                    final bool problem =
                        item.status == _SendStatus.conflict ||
                        item.status == _SendStatus.rejected;
                    final bool plainIn =
                        o.result == GateResult.checkedIn && !problem;
                    final String status = problem
                        ? hint(item)
                        : context.t('gate.result.${o.result.code}');
                    final String label = plainIn
                        ? name
                        : <String>[
                            name,
                            status,
                          ].where((String x) => x.isNotEmpty).join(' · ');
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: () => onPick(item.key),
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _toneColor(item.tone),
                          shape: BoxShape.circle,
                        ),
                      ),
                      minLeadingWidth: 10,
                      title: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF1C1F24)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (item.status == _SendStatus.pending &&
                              o.result == GateResult.checkedIn)
                            const Text('⏳ '),
                          if (item.key == pinnedKey)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                context.t('gate.pinned'),
                                style: const TextStyle(
                                  color: Color(0xFF4338CA),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          Text(
                            _hhmm(o.scannedAtMs),
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
