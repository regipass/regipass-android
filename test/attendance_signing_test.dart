import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/checkin_qr.dart';
import 'package:regipass/domain/qr_signing.dart';
import 'package:regipass/services/attendance_service.dart';

/// İP-Y: kapı/oturum QR imzası sunucu (functions/attendance.js) ve web
/// (attendance-api.js) ile birebir aynı olmalı. Aşağıdaki değerler Node'un
/// crypto.createHmac çıktısıdır; üç tarafın testlerinde aynı vektör var.
const String kKey = 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc';

void main() {
  group('QR imzası', () {
    test('sunucunun ürettiği imzayla aynı', () {
      expect(
        hmacQrSig(
          kKey,
          signedQrMessage(
            type: 'session-checkin',
            eventId: 'e1',
            session: 2,
            slot: 89500000,
          ),
        ),
        'FVmF75A0wUOVq5aAtjdm73',
      );
      expect(
        hmacQrSig(
          kKey,
          signedQrMessage(type: 'event-entry', eventId: 'e1', slot: 89500000),
        ),
        '3LMp1bg33QSMjJ7AphJM9l',
      );
    });

    test('imzalayıcı sunucu saatine göre dilim hesaplar ve yükü imzalar', () {
      final QrSigner signer = QrSigner(
        key: kKey,
        windowMs: 20000,
        offsetMs: 5000, // cihaz saati sunucudan 5 sn geride
        clock: () => 89500000 * 20000 - 5000 + 1000,
      );
      expect(signer.slot(), 89500000);
      expect(signer.msUntilNextSlot(), 19000);
      final Map<String, dynamic> p = signer.sign(
        type: 'session-checkin',
        eventId: 'e1',
        session: 2,
      );
      expect(p['v'], 2);
      expect(p['session'], 2);
      expect(p['slot'], 89500000);
      expect(p['sig'], 'FVmF75A0wUOVq5aAtjdm73');
      final Map<String, dynamic> door = signer.sign(
        type: 'event-entry',
        eventId: 'e1',
      );
      expect(door.containsKey('session'), isFalse);
      expect(door['sig'], '3LMp1bg33QSMjJ7AphJM9l');
      // Token içinden aynen geri okunur (web ve sunucu da aynı biçimi çözer).
      expect(
        parseCheckinQrToken(buildCheckinQrUrl(createCheckinQrToken(door))),
        door,
      );
    });
  });

  group('bilet kodu', () {
    test('bilete girer, kulüp okuttuğunda karşılaştırılır', () {
      final Map<String, dynamic> ticket = buildStudentCheckinPayload(
        registrationId: 'e1_u1',
        eventId: 'e1',
        studentId: 'u1',
        ticketCode: 'ABCDEFGHIJ',
      );
      expect(ticket['c'], 'ABCDEFGHIJ');
      expect(verifyTicketCode(given: 'ABCDEFGHIJ', expected: 'ABCDEFGHIJ'), (
        ok: true,
        legacy: false,
      ));
      expect(
        verifyTicketCode(given: 'SAHTE00000', expected: 'ABCDEFGHIJ').ok,
        isFalse,
      );
      expect(verifyTicketCode(given: 'ABCDEFGHIJ', expected: '').ok, isFalse);
    });

    test('eski sürümün kodsuz bileti aşama 1de uyarıyla geçer', () {
      expect(
        buildStudentCheckinPayload(
          registrationId: 'r',
          eventId: 'e',
          studentId: 's',
        ).containsKey('c'),
        isFalse,
      );
      expect(verifyTicketCode(given: null, expected: 'X'), (
        ok: true,
        legacy: true,
      ));
      expect(
        verifyTicketCode(given: '', expected: 'X', acceptLegacy: false).ok,
        isFalse,
      );
    });
  });

  group('şüpheli yoklama', () {
    test('sunucu işaretleri ve sunucudan geçmemiş girişler', () {
      final List<({int stage, String key})> out = attendanceSuspicions(
        flags: <String>[
          'door:edge',
          'session:2:unsigned-qr',
          'session:2:bilinmeyen',
        ],
        verified: <String, int>{'door': 1, 's2': 2},
        checkedInVia: 'self-qr',
        lastAttendedSession: 2,
      );
      expect(out, <({int stage, String key})>[
        (stage: 0, key: 'attendance.flag.edge'),
        (stage: 2, key: 'attendance.flag.unsignedQr'),
      ]);
      expect(
        attendanceSuspicions(
          flags: const <String>[],
          verified: const <String, int>{},
          checkedInVia: 'self-qr',
          lastAttendedSession: 1,
        ),
        <({int stage, String key})>[
          (stage: 0, key: 'attendance.flag.unverified'),
          (stage: 1, key: 'attendance.flag.unverified'),
        ],
      );
      // Kulübün kapıda okuttuğu giriş şüpheli değildir.
      expect(
        attendanceSuspicions(
          flags: const <String>[],
          verified: const <String, int>{},
          checkedInVia: '',
          lastAttendedSession: 0,
        ),
        isEmpty,
      );
    });
  });

  group('sunucu hataları', () {
    test('ret nedeni ayrıntıdan okunur; bağlantı sorunu "network"', () {
      final AttendanceFailure far = failureFromException(
        'failed-precondition',
        <String, Object?>{
          'reason': 'too-far',
          'distanceM': 420,
          'radiusM': 100,
        },
      );
      expect(far.reason, 'too-far');
      expect(far.distanceM, 420);
      expect(far.radiusM, 100);
      expect(failureFromException('unavailable', null).reason, 'network');
    });
  });
}
