/// İP-P1 / İP-P2 (mobil 1.0.13): paket kuralları — saf.
///
/// Web: js/modules/plans/plan-rules.js, sunucu: functions/plans.js#TIERS.
/// Karar her zaman sunucudadır (setEventQuota / kurallar); bu dosya formu
/// kilitlemek ve kullanıcıya nedenini söylemek içindir.
library;

const List<String> kPlanFeatures = <String>[
  'discover', 'discoverBoost', 'certificates', 'certificateUpload', 'gateQr',
  'sessions', 'messages', 'autoReminders', 'feedbackDetails', 'reportFile',
  'paidEvents', 'team', 'vouchers', 'passport', 'halls', 'photos',
];

Map<String, bool> _all({Set<String> off = const <String>{}}) =>
    <String, bool>{for (final String f in kPlanFeatures) f: !off.contains(f)};

/// Paket → özellikler (sunucuyla aynı).
final Map<String, Map<String, bool>> kPlanTierFeatures = <String, Map<String, bool>>{
  'starter': _all(off: <String>{
    'discoverBoost', 'certificates', 'gateQr', 'sessions', 'messages',
    'feedbackDetails', 'reportFile', 'paidEvents', 'team', 'vouchers',
    'passport', 'halls', 'photos',
  }),
  'pro': _all(off: <String>{'halls'}),
  'campus': _all(),
  'event_standard': _all(off: <String>{
    'sessions', 'messages', 'paidEvents', 'vouchers', 'passport', 'halls',
    'photos',
  }),
  // Fotoğraf galerisi Premium ve üstünde (Arda, 7 Eki).
  'event_plus': _all(off: <String>{'halls', 'photos'}),
  'event_premium': _all(off: <String>{'halls'}),
  'event_kongre': _all(),
  'none': _all(off: kPlanFeatures.toSet()),
};

/// Etkinliğin damgasına (planTier) göre özellik açık mı. Damga yoksa
/// (eski etkinlik ya da paket sistemi kapalı) her şey açık.
bool planFeatureAllowed(String planTier, String feature) {
  final Map<String, bool>? features = kPlanTierFeatures[planTier];
  if (features == null) return true;
  return features[feature] != false;
}

/// getMyPlan yanıtı.
class PlanSummary {
  const PlanSummary({
    required this.enabled,
    this.tier = 'starter',
    this.organizerType = 'club',
    this.canCreateEvent = true,
    this.blockReason = '',
    this.maxCapacity = 0,
    this.maxEvents,
    this.usedThisYear = 0,
    this.resetAtMs = 0,
    this.endsAtMs = 0,
    this.expired = false,
    this.usableCredits = 0,
    this.institutionName = '',
    this.features = const <String, bool>{},
  });

  factory PlanSummary.fromMap(Map<String, dynamic> m) {
    if (m['enabled'] != true) return const PlanSummary(enabled: false);
    final Object? f = m['features'];
    return PlanSummary(
      enabled: true,
      tier: '${m['tier'] ?? 'starter'}',
      organizerType: '${m['organizerType'] ?? 'club'}',
      canCreateEvent: m['canCreateEvent'] != false,
      blockReason: '${m['blockReason'] ?? ''}' == 'null' ? '' : '${m['blockReason'] ?? ''}',
      maxCapacity: (m['maxCapacity'] as num?)?.toInt() ?? 0,
      maxEvents: (m['maxEvents'] as num?)?.toInt(),
      usedThisYear: (m['usedThisYear'] as num?)?.toInt() ?? 0,
      resetAtMs: (m['resetAtMs'] as num?)?.toInt() ?? 0,
      endsAtMs: (m['endsAtMs'] as num?)?.toInt() ?? 0,
      expired: m['expired'] == true,
      usableCredits: (m['usableCredits'] as num?)?.toInt() ?? 0,
      institutionName: '${m['institutionName'] ?? ''}',
      features: f is Map
          ? <String, bool>{for (final MapEntry<Object?, Object?> e in f.entries) '${e.key}': e.value == true}
          : const <String, bool>{},
    );
  }

  final bool enabled;
  final String tier;
  final String organizerType;
  final bool canCreateEvent;
  final String blockReason;
  final int maxCapacity;
  final int? maxEvents;
  final int usedThisYear;
  final int resetAtMs;
  final int endsAtMs;
  final bool expired;
  final int usableCredits;
  final String institutionName;
  final Map<String, bool> features;

  bool get isCompany => organizerType == 'company';
  bool get isStarter => tier == 'starter';
  int get freeLeft => ((maxEvents ?? 3) - usedThisYear).clamp(0, 99);
  bool has(String feature) => !enabled || features[feature] != false;
}

/// Yeni etkinlik formunun sınırları.
class PlanFormLimits {
  const PlanFormLimits({
    this.allowSessions = true,
    this.allowPaid = true,
    this.maxCapacity,
    this.canCreate = true,
    this.blockKey = '',
    this.webOnly = false,
  });

  final bool allowSessions;
  final bool allowPaid;
  final int? maxCapacity;
  final bool canCreate;

  /// Açılamıyorsa ekranda gösterilecek metin anahtarı.
  final String blockKey;

  /// Firma: etkinlik hakkıyla açılış şimdilik yalnız web'de.
  final bool webOnly;
}

/// Paket özeti → yeni etkinlik formu. Düzenlemede [planTier] (etkinliğin
/// damgası) kullanılır; kapasiteyi sunucu denetler.
PlanFormLimits planFormLimits(PlanSummary? s, {String planTier = ''}) {
  if (planTier.isNotEmpty) {
    return PlanFormLimits(
      allowSessions: planFeatureAllowed(planTier, 'sessions'),
      allowPaid: planFeatureAllowed(planTier, 'paidEvents'),
    );
  }
  if (s == null || !s.enabled) return const PlanFormLimits();
  if (s.isCompany) {
    return const PlanFormLimits(
      canCreate: false,
      webOnly: true,
      blockKey: 'plan.mobile.companyWeb',
    );
  }
  if (!s.canCreateEvent) {
    return PlanFormLimits(
      canCreate: false,
      blockKey: s.blockReason == 'plan-year-limit' ? 'plan.error.yearLimit' : 'plan.error.expired',
    );
  }
  return PlanFormLimits(
    allowSessions: s.has('sessions'),
    allowPaid: s.has('paidEvents'),
    maxCapacity: s.maxCapacity > 0 ? s.maxCapacity : null,
  );
}

/// Sunucu hata nedeni (`details.reason`) → metin anahtarı.
String planErrorKey(String reason) => switch (reason) {
  'plan-year-limit' => 'plan.error.yearLimit',
  'plan-expired' => 'plan.error.expired',
  'plan-capacity' => 'plan.error.capacity',
  'plan-feature' => 'plan.error.feature',
  'plan-credit-required' => 'plan.error.creditRequired',
  'plan-credit-used' || 'plan-credit-invalid' => 'plan.error.creditUsed',
  'plan-credit-expired' => 'plan.error.creditExpired',
  _ => '',
};
