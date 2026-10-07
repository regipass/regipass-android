/// İP-GR (mobil 1.0.13): görevli olduğum etkinlikler (myStaffEvents).
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_refs.dart';

class StaffEvent {
  const StaffEvent({
    required this.eventId,
    required this.clubId,
    required this.title,
    this.clubName = '',
    this.role = 'gate',
    this.eventDateAtMs = 0,
    this.eventStartTime = '',
    this.online = false,
    this.locationName = '',
  });

  factory StaffEvent.fromMap(Map<String, dynamic> m) => StaffEvent(
        eventId: '${m['eventId'] ?? ''}',
        clubId: '${m['clubId'] ?? ''}',
        title: '${m['title'] ?? ''}',
        clubName: '${m['clubName'] ?? ''}',
        role: '${m['role'] ?? 'gate'}',
        eventDateAtMs: (m['eventDateAtMs'] as num?)?.toInt() ?? 0,
        eventStartTime: '${m['eventStartTime'] ?? ''}',
        online: m['eventFormat'] == 'online',
        locationName: '${m['locationName'] ?? ''}',
      );

  final String eventId;
  final String clubId;
  final String title;
  final String clubName;
  final String role;
  final int eventDateAtMs;
  final String eventStartTime;
  final bool online;
  final String locationName;
}

class StaffService {
  const StaffService({this.functions});

  final FirebaseFunctions? functions;

  Future<List<StaffEvent>> myStaffEvents() async {
    final HttpsCallableResult<Object?> result = await (functions ?? fbFunctions)
        .httpsCallable('myStaffEvents', options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call(<String, Object?>{});
    final Object? raw = result.data;
    final Object? list = raw is Map ? raw['events'] : null;
    if (list is! List) return const <StaffEvent>[];
    return <StaffEvent>[
      for (final Object? e in list)
        if (e is Map) StaffEvent.fromMap(Map<String, dynamic>.from(e)),
    ];
  }
}
