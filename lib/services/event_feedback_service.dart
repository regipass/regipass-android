/// Etkinlik değerlendirmesi (İP-D) — js/modules/feedback/feedback-api.js karşılığı.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/event_feedback.dart';
import '../state/providers.dart';
import 'firebase_refs.dart';

class EventFeedbackService {
  const EventFeedbackService();

  Future<MyFeedback> submit(String eventId, int rating, String comment) async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('submitEventFeedback')
        .call(<String, Object>{
          'eventId': eventId,
          'rating': rating,
          'comment': comment,
        });
    final Object? data = result.data;
    final Map<Object?, Object?> map = data is Map
        ? Map<Object?, Object?>.from(data)
        : <Object?, Object?>{};
    return MyFeedback(
      eventId: eventId,
      rating: map['rating'] is num ? (map['rating'] as num).toInt() : rating,
      comment: map['comment'] is String ? map['comment'] as String : comment,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, MyFeedback>> listMine() async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('listMyFeedback')
        .call(<String, Object>{});
    final Object? data = result.data;
    final Object? items = data is Map ? data['items'] : null;
    final Map<String, MyFeedback> out = <String, MyFeedback>{};
    if (items is List) {
      for (final Map<Object?, Object?> item
          in items.whereType<Map<Object?, Object?>>()) {
        final MyFeedback f = MyFeedback.fromMap(item);
        if (f.eventId.isNotEmpty) out[f.eventId] = f;
      }
    }
    return out;
  }

  Future<FeedbackSummary> clubSummary(String eventId) async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('clubEventFeedback')
        .call(<String, Object>{'eventId': eventId});
    final Object? data = result.data;
    return FeedbackSummary.fromMap(
      data is Map ? Map<Object?, Object?>.from(data) : <Object?, Object?>{},
    );
  }
}

/// Sunucunun döndürdüğü hata nedeni (details.reason).
String feedbackErrorReason(Object error) {
  if (error is FirebaseFunctionsException) {
    final Object? details = error.details;
    if (details is Map && details['reason'] is String) {
      return details['reason'] as String;
    }
  }
  return '';
}

final Provider<EventFeedbackService> eventFeedbackServiceProvider =
    Provider<EventFeedbackService>((Ref ref) => const EventFeedbackService());

/// Öğrencinin verdiği puanlar (Etkinliklerim rozetleri ve form).
final FutureProvider<Map<String, MyFeedback>> myFeedbackProvider =
    FutureProvider<Map<String, MyFeedback>>((Ref ref) {
      ref.watch(currentUidProvider);
      return ref.watch(eventFeedbackServiceProvider).listMine();
    });

/// Kulübün etkinlik değerlendirme özeti.
// ignore: always_specify_types
final clubEventFeedbackProvider =
    FutureProvider.family<FeedbackSummary, String>(
      (Ref ref, String eventId) =>
          ref.watch(eventFeedbackServiceProvider).clubSummary(eventId),
    );
