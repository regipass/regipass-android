/// İP-P1 (mobil): paket bilgisi — getMyPlan.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../domain/plans.dart';
import 'firebase_refs.dart';

class PlanService {
  const PlanService({this.functions});

  final FirebaseFunctions? functions;

  /// Organizatörün paket özeti. Sistem kapalıysa `enabled: false`.
  Future<PlanSummary> getMyPlan() async {
    final HttpsCallableResult<Object?> result = await (functions ?? fbFunctions)
        .httpsCallable(
          'getMyPlan',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        )
        .call(<String, Object?>{});
    final Object? raw = result.data;
    return PlanSummary.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }
}
