import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/online_rules.dart';

void main() {
  test('Yayına katıl penceresi (web ve sunucuyla aynı)', () {
    const int start = 1791400000000;
    final ({int opensAtMs, int closesAtMs}) w = joinWindowOf(startMs: start, endMs: start + 3600000);
    expect(w.opensAtMs, start - 15 * 60000);
    expect(w.closesAtMs, start + 3600000 + 3600000);
    final ({int opensAtMs, int closesAtMs}) w2 = joinWindowOf(startMs: start);
    expect(w2.closesAtMs, start + 3 * 3600000 + 3600000);
    // Saat yoksa İstanbul günü boyunca
    final int day = DateTime.utc(2026, 10, 12, 9).millisecondsSinceEpoch;
    final ({int opensAtMs, int closesAtMs}) w3 = joinWindowOf(dayMs: day);
    expect(w3.opensAtMs, DateTime.utc(2026, 10, 11, 21).millisecondsSinceEpoch);
    expect(w3.closesAtMs - w3.opensAtMs, 86400000);
  });

  test('kod ve hata metinleri', () {
    expect(cleanOnlineCode('123 456'), '123456');
    expect(cleanOnlineCode('12345'), isNull);
    expect(onlineCodeErrorKey('wrong-code'), 'online.code.wrong');
    expect(onlineJoinErrorKey('join-not-open'), 'online.join.notOpen');
    expect(onlineJoinErrorKey('x'), 'online.join.error');
  });
}
