/// Kapı denetleyicisi (İP-O) — js/modules/events/door-gate.js karşılığı.
///
///   1. Bilet listesi ("kapı paketi"): etkinliğin kayıtları cihazda
///      (SharedPreferences) tutulur, internet varken canlı güncellenir. Sonuç
///      bu listeden ANINDA verilir; her öğrenci için sunucuya gidilmez.
///   2. Bekleyen okumalar: giriş önce cihaza yazılır, sonra gönderilir.
///      İnternet yoksa sırada bekler; bağlantı gelince toplu gönderilir.
///   3. İki cihaz aynı bileti okursa İLK OKUMA geçerli: okuma saati cihazda
///      alınır; kurallar mevcut girişten sonraki saati reddeder.
///
/// Ayrı görevli hesabı yok: kulüp hesabı birkaç cihazda açık olabilir.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/checkin_qr.dart';
import '../domain/door_gate.dart';
import '../models/event.dart';
import 'firebase_refs.dart';

const String kGatePackPrefix = 'regipass.gate.pack.v1';
const String kGatePendingPrefix = 'regipass.gate.pending.v1';
const Duration kGatePackTtlAfterEvent = Duration(days: 2);

/// Cihazdaki bilet listesi.
class GatePack {
  GatePack({
    required this.event,
    required this.registrations,
    required this.savedAtMs,
    required this.fromServer,
  });

  factory GatePack.fromJson(Map<String, dynamic> json) => GatePack(
    event: GateEvent.fromMap(
      '${(json['event'] as Map<String, dynamic>)['id']}',
      json['event'] as Map<String, dynamic>,
    ),
    registrations: <GateRegistration>[
      for (final Object? r
          in (json['registrations'] as List<dynamic>? ?? <dynamic>[]))
        if (r is Map<String, dynamic>)
          GateRegistration.fromMap('${r['id']}', r),
    ],
    savedAtMs: (json['savedAtMs'] as num?)?.toInt() ?? 0,
    fromServer: false,
  );

  final GateEvent event;
  List<GateRegistration> registrations;
  int savedAtMs;
  bool fromServer;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'event': event.toJson(),
    'registrations': <Map<String, dynamic>>[
      for (final GateRegistration r in registrations) r.toJson(),
    ],
    'savedAtMs': savedAtMs,
  };
}

/// Sırada bekleyen okuma.
class GatePending {
  const GatePending({
    required this.regId,
    required this.eventId,
    required this.checkedInAtMs,
    required this.name,
  });

  factory GatePending.fromJson(Map<String, dynamic> j) => GatePending(
    regId: '${j['regId']}',
    eventId: '${j['eventId']}',
    checkedInAtMs: (j['checkedInAtMs'] as num).toInt(),
    name: '${j['name'] ?? ''}',
  );

  final String regId;
  final String eventId;
  final int checkedInAtMs;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'regId': regId,
    'eventId': eventId,
    'checkedInAtMs': checkedInAtMs,
    'name': name,
  };
}

/// Okutma sonucu (kart için gereken her şey).
class GateOutcome {
  const GateOutcome({
    required this.result,
    required this.scannedAtMs,
    this.legacy = false,
    this.event,
    this.registration,
    this.queued = false,
    this.paidAtGate = false,
  });

  final GateResult result;
  final int scannedAtMs;
  final bool legacy;
  final GateEvent? event;
  final GateRegistration? registration;
  final bool queued;

  /// İP-K: ödeme kapıda "Ödendi" işaretlenerek alındı.
  final bool paidAtGate;

  GateTone get tone => toneForResult(result);
}

enum GateChangeType { pack, pending, sent, conflict, rejected }

class GateChange {
  const GateChange(this.type, {this.item, this.firstMs = 0});
  final GateChangeType type;
  final GatePending? item;
  final int firstMs;
}

class GateStats {
  const GateStats({
    required this.total,
    required this.checkedIn,
    required this.pending,
    required this.savedAtMs,
  });
  final int total;
  final int checkedIn;
  final int pending;
  final int savedAtMs;
}

/// Firestore bağlantıları (testlerde sahteleri verilir).
class GateBackend {
  const GateBackend({
    required this.fetchEvent,
    required this.fetchRegistrations,
    required this.fetchRegistration,
    required this.writeCheckIn,
    this.watchRegistrations,
    this.fillPhotos,
    this.markPaid,
  });

  /// Gerçek Firestore bağlantıları.
  factory GateBackend.firestore(String clubId) => GateBackend(
    fetchEvent: (String eventId) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await eventDoc(
        eventId,
      ).get(const GetOptions(source: Source.server));
      return snap.exists ? GateEvent.fromMap(snap.id, snap.data()!) : null;
    },
    fetchRegistrations: (String eventId) async {
      final QSnap snap = await registrationsCol
          .where('eventId', isEqualTo: eventId)
          .get(const GetOptions(source: Source.server));
      return <GateRegistration>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs)
          GateRegistration.fromMap(d.id, d.data()),
      ];
    },
    fetchRegistration: (String regId) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await registrationsCol
          .doc(regId)
          .get(const GetOptions(source: Source.server));
      return snap.exists
          ? GateRegistration.fromMap(snap.id, snap.data()!)
          : null;
    },
    // Okuma saati CİHAZDA alınmıştır; kurallar sonraki saati reddeder.
    writeCheckIn: (String regId, int checkedInAtMs) =>
        registrationsCol.doc(regId).update(<String, dynamic>{
          'checkedInAtMs': checkedInAtMs,
          'checkedInAt': FieldValue.serverTimestamp(),
          'checkedInByClubId': clubId,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
    // İP-K: kapıda "Ödendi olarak işaretle" (sunucu yazar).
    markPaid: (String eventId, String studentId) async {
      await fbFunctions
          .httpsCallable(
            'setPaymentStatus',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call(<String, Object?>{
            'eventId': eventId,
            'studentId': studentId,
            'paid': true,
          });
    },
    fillPhotos: (String eventId) async {
      await fbFunctions
          .httpsCallable(
            'fillEventStudentPhotos',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call(<String, Object?>{'eventId': eventId});
    },
    watchRegistrations: (String eventId) => registrationsCol
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .where((QSnap s) => !s.metadata.isFromCache)
        .map(
          (QSnap s) => <GateRegistration>[
            for (final QueryDocumentSnapshot<Map<String, dynamic>> d in s.docs)
              GateRegistration.fromMap(d.id, d.data()),
          ],
        ),
  );

  final Future<GateEvent?> Function(String eventId) fetchEvent;
  final Future<List<GateRegistration>> Function(String eventId)
  fetchRegistrations;
  final Future<GateRegistration?> Function(String regId) fetchRegistration;
  final Future<void> Function(String regId, int checkedInAtMs) writeCheckIn;
  final Stream<List<GateRegistration>> Function(String eventId)?
  watchRegistrations;

  /// Fotoğrafı eksik kayıtları sunucu profilden doldurur (kulüp profilleri
  /// okuyamaz); sonuç canlı listeyle gelir.
  final Future<void> Function(String eventId)? fillPhotos;

  /// İP-K: kapıda "Ödendi" işareti.
  final Future<void> Function(String eventId, String studentId)? markPaid;
}

bool _isPermissionError(Object error) =>
    (error is FirebaseException && error.code == 'permission-denied') ||
    '$error'.contains('permission-denied');

class DoorGate {
  DoorGate({
    required this.clubId,
    required this.prefs,
    required this.backend,
    required this.isOnline,
    DateTime Function()? now,
    this.networkTimeout = const Duration(seconds: 6),
    this.dedupeWindow = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now {
    _pending = _loadPending();
    _prune();
  }

  final String clubId;
  final SharedPreferences prefs;
  final GateBackend backend;
  final bool Function() isOnline;
  final DateTime Function() _now;
  final Duration networkTimeout;
  final Duration dedupeWindow;

  final Map<String, GatePack> _packs = <String, GatePack>{};
  final Map<String, StreamSubscription<List<GateRegistration>>> _subs =
      <String, StreamSubscription<List<GateRegistration>>>{};
  final Map<String, int> _recent = <String, int>{};
  final StreamController<GateChange> _changes =
      StreamController<GateChange>.broadcast();
  late List<GatePending> _pending;
  Future<({int sent, int left})>? _flushing;
  final Set<String> _photoRequested = <String>{};

  /// Kartta fotoğraf çıksın: eksik fotoğraflar için sunucudan etkinlik
  /// başına bir kez doldurma istenir; sonuç canlı listeyle gelir.
  void _requestPhotos(String eventId, List<GateRegistration> regs) {
    final Future<void> Function(String)? fill = backend.fillPhotos;
    if (fill == null || _photoRequested.contains(eventId) || !isOnline()) {
      return;
    }
    if (!regs.any((GateRegistration r) => r.studentPhotoUrl.trim().isEmpty)) {
      return;
    }
    _photoRequested.add(eventId);
    unawaited(fill(eventId).catchError((Object _) {}));
  }

  Stream<GateChange> get changes => _changes.stream;
  int get pendingCount => _pending.length;
  GatePack? packFor(String eventId) => _packs[eventId];

  String _packKey(String eventId) => '$kGatePackPrefix.$clubId.$eventId';
  String get _pendingKey => '$kGatePendingPrefix.$clubId';

  void _emit(GateChange c) {
    if (!_changes.isClosed) _changes.add(c);
  }

  List<GatePending> _loadPending() {
    try {
      final String? raw = prefs.getString(_pendingKey);
      if (raw == null) return <GatePending>[];
      return <GatePending>[
        for (final Object? j in jsonDecode(raw) as List<dynamic>)
          if (j is Map<String, dynamic>) GatePending.fromJson(j),
      ];
    } catch (_) {
      return <GatePending>[];
    }
  }

  void _savePending() => unawaited(
    prefs.setString(
      _pendingKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final GatePending p in _pending) p.toJson(),
      ]),
    ),
  );

  void _savePack(GatePack pack) => unawaited(
    prefs.setString(_packKey(pack.event.id), jsonEncode(pack.toJson())),
  );

  GatePack? _loadPack(String eventId) {
    try {
      final String? raw = prefs.getString(_packKey(eventId));
      if (raw == null) return null;
      return GatePack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Etkinliği geçmiş listeleri siler (öğrenci listesi cihazda birikmesin).
  void _prune() {
    final int nowMs = _now().millisecondsSinceEpoch;
    final Set<String> pendingEvents = <String>{
      for (final GatePending p in _pending) p.eventId,
    };
    for (final String key in prefs.getKeys()) {
      if (!key.startsWith('$kGatePackPrefix.$clubId.')) continue;
      final GatePack? pack = _loadPack(
        key.substring('$kGatePackPrefix.$clubId.'.length),
      );
      final int ref = pack == null
          ? 0
          : (pack.event.eventDateAtMs > 0
                ? pack.event.eventDateAtMs
                : pack.event.deadlineAtMs);
      final bool expired =
          pack == null ||
          (ref > 0 && nowMs - ref > kGatePackTtlAfterEvent.inMilliseconds);
      if (expired && !pendingEvents.contains(pack?.event.id)) {
        unawaited(prefs.remove(key));
      }
    }
  }

  GatePending? _pendingFor(String regId) {
    for (final GatePending p in _pending) {
      if (p.regId == regId) return p;
    }
    return null;
  }

  /// Sunucudan gelen kayıt, cihazda henüz gönderilmemiş girişi SİLMESİN.
  GateRegistration _merge(GateRegistration r) {
    final GatePending? mine = _pendingFor(r.id);
    if (mine != null && !r.isCheckedIn) r.checkedInAtMs = mine.checkedInAtMs;
    return r;
  }

  GatePack _store(
    GateEvent event,
    List<GateRegistration> regs, {
    required bool fromServer,
  }) {
    final GatePack pack = GatePack(
      event: event,
      registrations: regs.map(_merge).toList(),
      savedAtMs: _now().millisecondsSinceEpoch,
      fromServer: fromServer,
    );
    _packs[event.id] = pack;
    _savePack(pack);
    _emit(const GateChange(GateChangeType.pack));
    return pack;
  }

  void _listen(String eventId) {
    final Stream<List<GateRegistration>> Function(String)? watch =
        backend.watchRegistrations;
    if (watch == null || _subs.containsKey(eventId)) return;
    _subs[eventId] = watch(eventId).listen((List<GateRegistration> regs) {
      final GatePack? pack = _packs[eventId];
      if (pack == null) return;
      pack
        ..registrations = regs.map(_merge).toList()
        ..savedAtMs = _now().millisecondsSinceEpoch;
      _savePack(pack);
      _emit(const GateChange(GateChangeType.pack));
    }, onError: (Object _) {});
  }

  /// Etkinlik ekranı kayıtları zaten dinliyorsa ayrıca indirmeden cihaza
  /// yazılır; kulübün etkinliği bir kez açmış olması yeterlidir.
  void seedFromEvent(AppEvent event, List<EventRegistration> registrations) {
    if (!event.hasDoorCheckin) return;
    final GatePack pack = _store(
      GateEvent(
        id: event.id,
        title: event.title,
        clubId: event.clubId,
        checkinMode: event.checkinMode.isEmpty ? null : event.checkinMode,
        sessionCount: event.sessionCount,
        eventDateAtMs: event.eventDateAtMs ?? 0,
        deadlineAtMs: event.deadlineAtMs,
        feeType: event.feeType,
        cancelled: event.cancelled,
      ),
      <GateRegistration>[
        for (final EventRegistration r in registrations)
          GateRegistration.fromMap(r.id, <String, dynamic>{
            'eventId': r.eventId,
            'studentId': r.studentId,
            'studentName': r.displayName,
            'studentPhotoUrl': r.studentPhotoUrl,
            'studentDepartment': r.studentDepartment,
            'studentUniversity': r.studentUniversity,
            'studentClassYear': r.studentClassYear,
            'ticketCode': r.ticketCode,
            'checkedInAtMs': r.checkedInAtMs ?? 0,
            'paymentStatus': r.paymentStatus,
          }),
      ],
      fromServer: true,
    );
    _requestPhotos(event.id, pack.registrations);
  }

  /// Bilet listesini hazırlar: internet varsa indirir, yoksa cihazdakini
  /// kullanır.
  Future<GatePack?> preparePack(String eventId, {bool force = false}) async {
    if (eventId.isEmpty) return null;
    if (!force && _packs.containsKey(eventId)) return _packs[eventId];

    if (isOnline()) {
      try {
        final (GateEvent?, List<GateRegistration>) got = await (
          backend.fetchEvent(eventId),
          backend.fetchRegistrations(eventId),
        ).wait.timeout(networkTimeout * 2);
        if (got.$1 == null) return null;
        final GatePack pack = _store(got.$1!, got.$2, fromServer: true);
        _listen(eventId);
        _requestPhotos(eventId, pack.registrations);
        return pack;
      } catch (_) {
        // Cihazdaki listeye düşülür.
      }
    }

    final GatePack? saved = _loadPack(eventId);
    if (saved == null) return null;
    saved.registrations = saved.registrations.map(_merge).toList();
    _packs[eventId] = saved;
    if (isOnline()) _listen(eventId);
    _emit(const GateChange(GateChangeType.pack));
    return saved;
  }

  Future<GateRegistration?> _refreshOne(String regId) async {
    if (!isOnline() || regId.isEmpty) return null;
    try {
      return await backend.fetchRegistration(regId).timeout(networkTimeout);
    } catch (_) {
      return null;
    }
  }

  void _upsert(String eventId, GateRegistration r) {
    final GatePack? pack = _packs[eventId];
    if (pack == null) return;
    final GateRegistration merged = _merge(r);
    final int i = pack.registrations.indexWhere(
      (GateRegistration x) => x.id == merged.id,
    );
    if (i >= 0) {
      pack.registrations[i] = merged;
    } else {
      pack.registrations.add(merged);
    }
    _savePack(pack);
  }

  /// Okunan QR'ı işler.
  Future<GateOutcome> processToken(
    String raw, {
    String expectedEventId = '',
  }) async {
    final DateTime scannedAt = _now();
    final int scannedAtMs = scannedAt.millisecondsSinceEpoch;
    final Map<String, dynamic>? payload = parseCheckinQrToken(raw);
    final bool isTicket = payload != null && payload['type'] == 'event-checkin';

    // Kamera açık kaldığı için aynı kod art arda karelerde okunur.
    final String key = isTicket
        ? ('${payload['registrationId'] ?? ''}'.isNotEmpty
              ? '${payload['registrationId']}'
              : '${payload['eventId']}_${payload['studentId'] ?? ''}')
        : 'raw:${raw.length > 200 ? raw.substring(0, 200) : raw}';
    final int last = _recent[key] ?? 0;
    if (scannedAtMs - last < dedupeWindow.inMilliseconds) {
      return GateOutcome(
        result: GateResult.duplicate,
        scannedAtMs: scannedAtMs,
      );
    }
    _recent[key] = scannedAtMs;
    if (_recent.length > 500) _recent.clear();

    if (!isTicket) {
      return GateOutcome(
        result: GateResult.notTicket,
        scannedAtMs: scannedAtMs,
      );
    }
    final String eventId = '${payload['eventId'] ?? ''}';
    if (expectedEventId.isNotEmpty && eventId != expectedEventId) {
      return GateOutcome(
        result: GateResult.otherEvent,
        scannedAtMs: scannedAtMs,
      );
    }

    final GatePack? pack = await preparePack(eventId);
    final GateEvent? event = pack?.event;
    GateRegistration? reg = pack == null
        ? null
        : findGateRegistration(pack.registrations, payload);

    ({GateResult result, bool legacy}) verdict = evaluateGateTicket(
      payload: payload,
      event: event,
      registration: reg,
      clubId: clubId,
      now: scannedAt,
      expectedEventId: expectedEventId,
    );

    // Liste eski olabilir (yeni kayıt / bilet kodu az önce üretildi).
    // Ödeme de az önce onaylanmış olabilir (liste eski).
    if (event != null &&
        (verdict.result == GateResult.notRegistered ||
            verdict.result == GateResult.invalidTicket ||
            verdict.result == GateResult.paymentPending)) {
      final String regId =
          reg?.id ??
          ('${payload['registrationId'] ?? ''}'.isNotEmpty
              ? '${payload['registrationId']}'
              : '${eventId}_${payload['studentId'] ?? ''}');
      final GateRegistration? fresh = await _refreshOne(regId);
      if (fresh != null && fresh.eventId == eventId) {
        _upsert(eventId, fresh);
        reg = findGateRegistration(_packs[eventId]!.registrations, payload);
        verdict = evaluateGateTicket(
          payload: payload,
          event: event,
          registration: reg,
          clubId: clubId,
          now: scannedAt,
          expectedEventId: expectedEventId,
        );
      }
    }

    if (verdict.result != GateResult.checkedIn || reg == null) {
      return GateOutcome(
        result: verdict.result,
        scannedAtMs: scannedAtMs,
        event: event,
        registration: reg,
      );
    }

    _admit(reg, eventId, scannedAtMs);
    return GateOutcome(
      result: GateResult.checkedIn,
      scannedAtMs: scannedAtMs,
      legacy: verdict.legacy,
      event: event,
      registration: reg,
      queued: true,
    );
  }

  /// Giriş: önce cihaza, sonra sunucuya.
  void _admit(GateRegistration reg, String eventId, int scannedAtMs) {
    reg.checkedInAtMs = scannedAtMs;
    final GateRegistration entered = reg;
    _pending = <GatePending>[
      ..._pending.where((GatePending p) => p.regId != entered.id),
      GatePending(
        regId: entered.id,
        eventId: eventId,
        checkedInAtMs: scannedAtMs,
        name: entered.studentName,
      ),
    ];
    _savePending();
    final GatePack? pack = _packs[eventId];
    if (pack != null) _savePack(pack);
    _emit(const GateChange(GateChangeType.pending));
    unawaited(flush());
  }

  /// İP-K: kapıdan "Ödendi" işareti mümkün mü?
  bool get canMarkPaid => backend.markPaid != null;

  /// İP-K: kapıda "Ödendi olarak işaretle": sunucuya yazılır (internet şart),
  /// sonra aynı öğrenci için giriş alınır. Hata olursa fırlatır.
  Future<GateOutcome> markPaidAndAdmit(GateOutcome outcome) async {
    final GateRegistration? reg = outcome.registration;
    final String eventId = outcome.event?.id ?? reg?.eventId ?? '';
    final Future<void> Function(String, String)? mark = backend.markPaid;
    if (mark == null || reg == null || eventId.isEmpty) {
      throw StateError('mark-paid-unsupported');
    }
    if (!isOnline()) throw StateError('offline');
    await mark(eventId, reg.studentId).timeout(networkTimeout * 2);
    reg.paymentStatus = 'paid';
    final int scannedAtMs = _now().millisecondsSinceEpoch;
    _admit(reg, eventId, scannedAtMs);
    return GateOutcome(
      result: GateResult.checkedIn,
      scannedAtMs: scannedAtMs,
      event: outcome.event,
      registration: reg,
      queued: true,
      paidAtGate: true,
    );
  }

  /// Bekleyen okumaları gönderir.
  Future<({int sent, int left})> flush() {
    final Future<({int sent, int left})>? running = _flushing;
    if (running != null) return running;
    if (_pending.isEmpty || !isOnline()) {
      return Future<({int sent, int left})>.value((
        sent: 0,
        left: _pending.length,
      ));
    }
    final Future<({int sent, int left})> f = _flushLoop();
    _flushing = f;
    return f.whenComplete(() => _flushing = null);
  }

  Future<({int sent, int left})> _flushLoop() async {
    int sent = 0;
    final Set<String> tried = <String>{};
    while (isOnline()) {
      GatePending? item;
      for (final GatePending p in _pending) {
        if (!tried.contains('${p.regId}@${p.checkedInAtMs}')) {
          item = p;
          break;
        }
      }
      if (item == null) break;
      tried.add('${item.regId}@${item.checkedInAtMs}');

      bool done = false;
      try {
        await backend
            .writeCheckIn(item.regId, item.checkedInAtMs)
            .timeout(networkTimeout);
        done = true;
        sent += 1;
        _emit(GateChange(GateChangeType.sent, item: item));
      } catch (error) {
        if (_isPermissionError(error)) {
          // Kural reddetti: büyük olasılıkla başka bir cihaz DAHA ÖNCE okuttu.
          final GateRegistration? fresh = await _refreshOne(item.regId);
          final int firstMs = fresh?.checkedInAtMs ?? 0;
          done = true;
          if (fresh != null) _upsert(item.eventId, fresh);
          _emit(
            GateChange(
              firstMs > 0 && firstMs < item.checkedInAtMs
                  ? GateChangeType.conflict
                  : GateChangeType.rejected,
              item: item,
              firstMs: firstMs,
            ),
          );
        } else {
          break; // Ağ sorunu: sırada kalır.
        }
      }
      if (done) {
        final GatePending finished = item;
        _pending = _pending
            .where(
              (GatePending p) =>
                  !(p.regId == finished.regId &&
                      p.checkedInAtMs == finished.checkedInAtMs),
            )
            .toList();
        _savePending();
        _emit(const GateChange(GateChangeType.pending));
      }
    }
    return (sent: sent, left: _pending.length);
  }

  GateStats stats(String eventId) {
    final List<GateRegistration> regs =
        _packs[eventId]?.registrations ?? const <GateRegistration>[];
    return GateStats(
      total: regs.length,
      checkedIn: regs.where((GateRegistration r) => r.isCheckedIn).length,
      pending: _pending
          .where((GatePending p) => eventId.isEmpty || p.eventId == eventId)
          .length,
      savedAtMs: _packs[eventId]?.savedAtMs ?? 0,
    );
  }

  Future<void> dispose() async {
    for (final StreamSubscription<List<GateRegistration>> s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
    await _changes.close();
  }
}
