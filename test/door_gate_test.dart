// İP-O: kapı denetleyicisi (lib/services/door_gate.dart) —
// tests/unit/door-gate.test.mjs ile aynı senaryolar.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/checkin_qr.dart';
import 'package:regipass/domain/door_gate.dart';
import 'package:regipass/services/door_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime t0 = DateTime(2026, 10, 1, 9);

Map<String, dynamic> reg(String s, {int checkedInAtMs = 0, String? code}) =>
    <String, dynamic>{
      'eventId': 'e1',
      'studentId': s,
      'studentName': 'Ogrenci $s',
      'studentPhone': '+905551112233',
      'studentEmail': '$s@x.com',
      'ticketCode': code ?? 'CODE_$s',
      'checkedInAtMs': checkedInAtMs,
    };

String ticket(String s, {String? code = '', String eventId = 'e1'}) =>
    createCheckinQrToken(<String, dynamic>{
      'v': 1,
      'type': 'event-checkin',
      'registrationId': '${eventId}_$s',
      'eventId': eventId,
      'studentId': s,
      if (code != null) 'c': code.isEmpty ? 'CODE_$s' : code,
    });

class FakeServer {
  bool online = true;
  DateTime clock = t0;
  final List<(String, int)> writes = <(String, int)>[];
  bool hangWrites = false;
  final Map<String, Map<String, dynamic>> regs = <String, Map<String, dynamic>>{
    'e1_s1': reg('s1'),
    'e1_s2': reg('s2'),
    'e1_s3': reg('s3'),
  };
  final Map<String, dynamic> event = <String, dynamic>{
    'title': 'Bahar',
    'clubId': 'clubA',
    'checkinMode': 'checkin_only',
    'eventDateAtMs': t0.add(const Duration(hours: 1)).millisecondsSinceEpoch,
  };

  Never offline() =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  GateBackend backend() => GateBackend(
    fetchEvent: (String id) async {
      if (!online) offline();
      return id == 'e1' ? GateEvent.fromMap(id, event) : null;
    },
    fetchRegistrations: (String id) async {
      if (!online) offline();
      return <GateRegistration>[
        for (final MapEntry<String, Map<String, dynamic>> e in regs.entries)
          if (e.value['eventId'] == id)
            GateRegistration.fromMap(e.key, e.value),
      ];
    },
    fetchRegistration: (String id) async {
      if (!online) offline();
      final Map<String, dynamic>? r = regs[id];
      return r == null ? null : GateRegistration.fromMap(id, r);
    },
    writeCheckIn: (String id, int ms) async {
      if (hangWrites) return Completer<void>().future;
      if (!online) offline();
      writes.add((id, ms));
      final int prev = (regs[id]!['checkedInAtMs'] as int?) ?? 0;
      if (prev > 0 && ms > prev) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
      regs[id]!['checkedInAtMs'] = ms;
    },
  );

  Future<DoorGate> gate({SharedPreferences? prefs}) async => DoorGate(
    clubId: 'clubA',
    prefs: prefs ?? await SharedPreferences.getInstance(),
    backend: backend(),
    isOnline: () => online,
    now: () => clock,
    networkTimeout: const Duration(milliseconds: 50),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('saf karar tablosu', () {
    final GateEvent ev = GateEvent.fromMap('e1', FakeServer().event);
    final Map<String, dynamic> p = <String, dynamic>{
      'type': 'event-checkin',
      'eventId': 'e1',
      'studentId': 's1',
      'registrationId': 'e1_s1',
      'c': 'CODE_s1',
    };
    GateResult r({
      Map<String, dynamic>? payload,
      GateEvent? event,
      GateRegistration? registration,
      bool noReg = false,
      String club = 'clubA',
      DateTime? now,
      String expected = '',
    }) => evaluateGateTicket(
      payload: payload ?? p,
      event: event ?? ev,
      registration: noReg
          ? null
          : (registration ?? GateRegistration.fromMap('e1_s1', reg('s1'))),
      clubId: club,
      now: now ?? t0,
      expectedEventId: expected,
    ).result;

    expect(r(), GateResult.checkedIn);
    expect(
      r(
        registration: GateRegistration.fromMap(
          'e1_s1',
          reg('s1', checkedInAtMs: 5),
        ),
      ),
      GateResult.already,
    );
    expect(
      r(payload: <String, dynamic>{...p, 'c': 'BASKA'}),
      GateResult.invalidTicket,
    );
    expect(r(noReg: true), GateResult.notRegistered);
    expect(r(expected: 'e2'), GateResult.otherEvent);
    expect(r(club: 'clubB'), GateResult.notOwner);
    expect(
      r(
        event: GateEvent.fromMap('e1', <String, dynamic>{
          ...FakeServer().event,
          'checkinMode': 'attendance_only',
        }),
      ),
      GateResult.noDoor,
    );
    expect(r(now: t0.add(const Duration(days: 3))), GateResult.pastEvent);
    expect(
      r(payload: <String, dynamic>{'type': 'session-checkin', 'eventId': 'e1'}),
      GateResult.notTicket,
    );
    // Aşama 1: kodsuz eski bilet uyarıyla kabul.
    final ({GateResult result, bool legacy}) legacy = evaluateGateTicket(
      payload: <String, dynamic>{...p}..remove('c'),
      event: ev,
      registration: GateRegistration.fromMap('e1_s1', reg('s1')),
      clubId: 'clubA',
      now: t0,
    );
    expect(legacy.result, GateResult.checkedIn);
    expect(legacy.legacy, isTrue);
  });

  test(
    'kesintisiz okutma: arka arkaya, 10 sn içinde sessiz, sonra zaten girdi',
    () async {
      final FakeServer server = FakeServer();
      final DoorGate gate = await server.gate();
      expect(
        (await gate.processToken(ticket('s1'))).result,
        GateResult.checkedIn,
      );
      expect(
        (await gate.processToken(ticket('s2'))).result,
        GateResult.checkedIn,
      );
      await gate.flush();
      expect(server.writes.map(((String, int) w) => w.$1), <String>[
        'e1_s1',
        'e1_s2',
      ]);
      expect(gate.pendingCount, 0);

      server.clock = t0.add(const Duration(seconds: 3));
      expect(
        (await gate.processToken(ticket('s1'))).result,
        GateResult.duplicate,
      );
      server.clock = t0.add(const Duration(seconds: 14));
      final GateOutcome again = await gate.processToken(ticket('s1'));
      expect(again.result, GateResult.already);
      expect(again.tone, GateTone.warn);
      expect(server.writes.length, 2);
      expect(gate.stats('e1').checkedIn, 2);
    },
  );

  test('liste telefon/e-posta tutmaz', () async {
    final FakeServer server = FakeServer();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DoorGate gate = await server.gate(prefs: prefs);
    await gate.preparePack('e1');
    await Future<void>.delayed(Duration.zero);
    final String saved = prefs.getString('$kGatePackPrefix.clubA.e1')!;
    expect(saved, isNot(contains('905551112233')));
    expect(saved, isNot(contains('@x.com')));
    expect(saved, contains('CODE_s1'));
  });

  test(
    'internetsiz kapı: önceden inen liste, sıra, bağlantı gelince gönderim',
    () async {
      final FakeServer server = FakeServer();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await (await server.gate(prefs: prefs)).preparePack('e1');
      await Future<void>.delayed(Duration.zero);

      server.online = false;
      final DoorGate gate = await server.gate(
        prefs: prefs,
      ); // uygulama yeniden açıldı
      server.clock = t0.add(const Duration(minutes: 1));
      final GateOutcome r = await gate.processToken(ticket('s2'));
      expect(r.result, GateResult.checkedIn);
      expect(r.queued, isTrue);
      expect(gate.pendingCount, 1);
      expect(server.writes, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('$kGatePendingPrefix.clubA'), contains('e1_s2'));

      server.clock = server.clock.add(const Duration(seconds: 20));
      expect(
        (await gate.processToken(ticket('s2'))).result,
        GateResult.already,
      );
      expect(
        (await gate.processToken(ticket('s3', code: 'SAHTE'))).result,
        GateResult.invalidTicket,
      );

      server.online = true;
      final ({int sent, int left}) out = await gate.flush();
      expect(out.sent, 1);
      expect(out.left, 0);
      expect(server.writes.single, (
        'e1_s2',
        t0.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      ));
    },
  );

  test('internetsiz ve listesi olmayan etkinlik: bilinmiyor', () async {
    final FakeServer server = FakeServer()..online = false;
    final DoorGate gate = await server.gate();
    expect(
      (await gate.processToken(ticket('s1'))).result,
      GateResult.unknownEvent,
    );
  });

  test(
    'iki cihaz: ilk okuma geçerli, sonraki cihaz conflict bildirir',
    () async {
      final FakeServer server = FakeServer();
      final DoorGate gate = await server.gate();
      final List<GateChange> changes = <GateChange>[];
      gate.changes.listen(changes.add);
      await gate.preparePack('e1');
      server
        ..online = false
        ..clock = t0.add(const Duration(minutes: 2));
      await gate.processToken(ticket('s1'));
      server.regs['e1_s1']!['checkedInAtMs'] = t0
          .add(const Duration(minutes: 1))
          .millisecondsSinceEpoch;
      server.online = true;
      await gate.flush();
      await Future<void>.delayed(Duration.zero);
      expect(gate.pendingCount, 0);
      final GateChange conflict = changes.firstWhere(
        (GateChange c) => c.type == GateChangeType.conflict,
      );
      expect(
        conflict.firstMs,
        t0.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );
    },
  );

  test('ağ zaman aşımı: okuma sırada kalır, sonra gönderilir', () async {
    final FakeServer server = FakeServer()..hangWrites = true;
    final DoorGate gate = await server.gate();
    await gate.processToken(ticket('s1'));
    await gate.flush();
    expect(gate.pendingCount, 1);
    server.hangWrites = false;
    await gate.flush();
    expect(gate.pendingCount, 0);
    expect(server.writes.length, 1);
  });

  test('liste eskiyse tek kayıt tazelenir (yeni kod / yeni kayıt)', () async {
    final FakeServer server = FakeServer();
    final DoorGate gate = await server.gate();
    await gate.preparePack('e1');
    server.regs['e1_s3']!['ticketCode'] = 'YENIKOD';
    server.regs['e1_s9'] = reg('s9');
    expect(
      (await gate.processToken(ticket('s3', code: 'YENIKOD'))).result,
      GateResult.checkedIn,
    );
    expect(
      (await gate.processToken(ticket('s9'))).result,
      GateResult.checkedIn,
    );
    expect(
      (await gate.processToken(ticket('s4'))).result,
      GateResult.notRegistered,
    );
  });

  test('etkinliği geçmiş listeler silinir, başka kulübünkine dokunulmaz', () async {
    const String oldPack =
        '{"event":{"id":"eOld","clubId":"clubA","eventDateAtMs":1},"registrations":[]}';
    SharedPreferences.setMockInitialValues(<String, Object>{
      '$kGatePackPrefix.clubA.eOld': oldPack.replaceFirst(
        '"eventDateAtMs":1',
        '"eventDateAtMs":${t0.subtract(const Duration(days: 10)).millisecondsSinceEpoch}',
      ),
      '$kGatePackPrefix.clubB.eOld': oldPack,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await FakeServer().gate(prefs: prefs);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.containsKey('$kGatePackPrefix.clubA.eOld'), isFalse);
    expect(prefs.containsKey('$kGatePackPrefix.clubB.eOld'), isTrue);
  });

  test(
    'etkinlik ekranından açılan kapı başka etkinliğin biletini reddeder',
    () async {
      final DoorGate gate = await FakeServer().gate();
      expect(
        (await gate.processToken(
          ticket('s1', eventId: 'e2'),
          expectedEventId: 'e1',
        )).result,
        GateResult.otherEvent,
      );
    },
  );

  test(
    'liste hazırlanırken eksik fotoğraflar için sunucuya bir kez istek gider',
    () async {
      final FakeServer server = FakeServer();
      final List<String> calls = <String>[];
      final GateBackend base = server.backend();
      final DoorGate gate = DoorGate(
        clubId: 'clubA',
        prefs: await SharedPreferences.getInstance(),
        isOnline: () => true,
        now: () => server.clock,
        networkTimeout: const Duration(milliseconds: 50),
        backend: GateBackend(
          fetchEvent: base.fetchEvent,
          fetchRegistrations: base.fetchRegistrations,
          fetchRegistration: base.fetchRegistration,
          writeCheckIn: base.writeCheckIn,
          fillPhotos: (String eventId) async => calls.add(eventId),
        ),
      );
      await gate.preparePack('e1', force: true);
      await gate.preparePack('e1', force: true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, <String>['e1']);
    },
  );
}
