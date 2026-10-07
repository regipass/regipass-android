/// İP-ON (mobil): "Yayına katıl" ve anlık yoklama kodu.
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_refs.dart';
import 'registration_service.dart';

class OnlineService {
  const OnlineService({this.functions});

  final FirebaseFunctions? functions;

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> data) async {
    try {
      final HttpsCallableResult<Object?> result = await (functions ?? fbFunctions)
          .httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
          .call(data);
      final Object? raw = result.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      throw registrationFailureFrom(error.code, error.details);
    }
  }

  /// Toplantı bağlantısı (kayıt + zaman sunucuda denetlenir).
  Future<String> join(String eventId) async =>
      '${(await _call('joinOnlineEvent', <String, Object?>{'eventId': eventId}))['url'] ?? ''}';

  /// Anlık yoklama kodu. Dönen: (attended, total, already).
  Future<({int attended, int total, bool already})> checkIn(String eventId, String code) async {
    final Map<String, dynamic> out = await _call('checkInOnline', <String, Object?>{'eventId': eventId, 'code': code});
    return (
      attended: (out['attended'] as num?)?.toInt() ?? 0,
      total: (out['total'] as num?)?.toInt() ?? 0,
      already: out['already'] == true,
    );
  }
}
