import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/plans.dart';

void main() {
  test('paket özellikleri sunucuyla aynı', () {
    expect(planFeatureAllowed('starter', 'sessions'), isFalse);
    expect(planFeatureAllowed('starter', 'certificateUpload'), isTrue);
    expect(planFeatureAllowed('pro', 'halls'), isFalse);
    expect(planFeatureAllowed('campus', 'halls'), isTrue);
    expect(planFeatureAllowed('event_standard', 'vouchers'), isFalse);
    expect(planFeatureAllowed('event_plus', 'photos'), isFalse);
    expect(planFeatureAllowed('event_premium', 'photos'), isTrue);
    expect(planFeatureAllowed('', 'sessions'), isTrue);
  });

  test('form sınırları', () {
    expect(planFormLimits(null).canCreate, isTrue);
    final PlanSummary starter = PlanSummary.fromMap(<String, dynamic>{
      'enabled': true, 'tier': 'starter', 'canCreateEvent': true, 'maxCapacity': 100, 'maxEvents': 3, 'usedThisYear': 1,
      'features': <String, bool>{'sessions': false, 'paidEvents': false},
    });
    final PlanFormLimits l = planFormLimits(starter);
    expect(l.allowSessions, isFalse);
    expect(l.allowPaid, isFalse);
    expect(l.maxCapacity, 100);
    expect(starter.freeLeft, 2);
    final PlanSummary used = PlanSummary.fromMap(<String, dynamic>{'enabled': true, 'tier': 'starter', 'canCreateEvent': false, 'blockReason': 'plan-year-limit'});
    expect(planFormLimits(used).blockKey, 'plan.error.yearLimit');
    final PlanSummary company = PlanSummary.fromMap(<String, dynamic>{'enabled': true, 'tier': 'none', 'organizerType': 'company'});
    expect(planFormLimits(company).webOnly, isTrue);
    expect(planFormLimits(starter, planTier: 'pro').allowSessions, isTrue);
    expect(PlanSummary.fromMap(<String, dynamic>{'enabled': false}).enabled, isFalse);
    expect(planErrorKey('plan-capacity'), 'plan.error.capacity');
    expect(planErrorKey('x'), '');
  });
}
