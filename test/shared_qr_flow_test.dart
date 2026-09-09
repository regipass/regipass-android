import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:regipass/features/club/club_providers.dart';
import 'package:regipass/features/student/student_providers.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/services/event_repository.dart';
import 'package:regipass/services/geo_fence_service.dart';
import 'package:regipass/state/providers.dart';

AppEvent event([Map<String, dynamic> changes = const <String, dynamic>{}]) =>
    AppEvent.fromMap('e1', <String, dynamic>{
      'checkinMode': 'checkin_attendance',
      'sessionCount': 2,
      'locationLat': 41.0,
      'locationLng': 29.0,
      'locationRadius': 50,
      ...changes,
    });

class TestFence extends GeoFenceService {
  TestFence(this.position);
  final Position? position;
  int reads = 0;

  @override
  Future<Position?> currentPosition() async {
    reads++;
    return position;
  }
}

Position position(double latitude) => Position(
  latitude: latitude,
  longitude: 29,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class LiveEvents extends EventRepository {
  final StreamController<List<AppEvent>> controller =
      StreamController<List<AppEvent>>.broadcast();

  @override
  Stream<List<AppEvent>> watchAllEvents() => controller.stream;
}

void main() {
  test('opening the door alone does not publish a QR; stopping hides it', () {
    expect(
      event(<String, dynamic>{'entryOpen': true}).hasActiveDoorQr,
      isFalse,
    );
    expect(
      event(<String, dynamic>{
        'entryOpen': true,
        'doorQrPublished': true,
      }).hasActiveDoorQr,
      isTrue,
    );
    expect(
      event(<String, dynamic>{
        'entryOpen': false,
        'doorQrPublished': true,
      }).hasActiveDoorQr,
      isFalse,
    );
  });

  test('only a published current session enables scanning', () {
    RegistrationWithEvent item(Map<String, dynamic> changes) =>
        RegistrationWithEvent(
          event: event(changes),
          registration: EventRegistration.fromMap('e1_s1', <String, dynamic>{}),
        );
    expect(
      item(<String, dynamic>{'currentSession': 1}).sessionScanState,
      SessionScanState.unavailable,
    );
    expect(
      item(<String, dynamic>{
        'currentSession': 1,
        'sessionQrPublished': 1,
      }).sessionScanState,
      SessionScanState.ready,
    );
    expect(
      item(<String, dynamic>{
        'currentSession': 2,
        'sessionQrPublished': 1,
      }).event!.hasActiveSessionQr,
      isFalse,
    );
    expect(
      item(<String, dynamic>{
        'currentSession': 1,
        'sessionQrPublished': 1,
        'sessionsCompleted': true,
      }).event!.hasActiveSessionQr,
      isFalse,
    );
  });

  test('single attendance session uses the session flow', () {
    final RegistrationWithEvent item = RegistrationWithEvent(
      event: event(<String, dynamic>{
        'sessionCount': 1,
        'checkinMode': 'attendance_only',
      }),
      registration: EventRegistration.fromMap('r', <String, dynamic>{}),
    );
    expect(item.isMultiSession, isTrue);
  });

  test(
    'door and session geofence accept nearby and reject remote devices',
    () async {
      for (final String mode in <String>['checkin_only', 'attendance_only']) {
        final AppEvent target = event(<String, dynamic>{'checkinMode': mode});
        final TestFence inside = TestFence(position(41));
        expect((await inside.verify(target)).ok, isTrue);
        await inside.verify(target);
        expect(inside.reads, 2); // Each scan obtains a new device position.
        final GeoFenceResult far = await TestFence(
          position(41.01),
        ).verify(target);
        expect(far.outcome, GeoFenceOutcome.tooFar);
        expect(far.ok, isFalse);
        expect((await TestFence(null).verify(target)).ok, isFalse);
      }
    },
  );

  test('konumu olmayan etkinlik GPS istemeden QR kontrolünü geçirir', () async {
    final TestFence fence = TestFence(null);
    final GeoFenceResult result = await fence.verify(
      event(<String, dynamic>{'locationLat': null, 'locationLng': null}),
    );

    expect(result.outcome, GeoFenceOutcome.skipped);
    expect(result.ok, isTrue);
    expect(fence.reads, 0);
  });

  test('eksik veya geçersiz koordinatlar doğrulamayı atlamaz', () async {
    for (final Map<String, dynamic> coordinates in <Map<String, dynamic>>[
      <String, dynamic>{'locationLat': null},
      <String, dynamic>{'locationLat': double.nan},
      <String, dynamic>{'locationLat': 91},
    ]) {
      expect(
        (await TestFence(position(41)).verify(event(coordinates))).ok,
        isFalse,
      );
    }
  });

  test(
    'student and club discovery reflect registration changes live',
    () async {
      final LiveEvents repo = LiveEvents();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          eventRepositoryProvider.overrideWithValue(repo),
          studentProfileProvider.overrideWithValue(
            const AsyncData<StudentProfile?>(null),
          ),
          clubProfileProvider.overrideWithValue(
            const AsyncData<ClubProfile?>(null),
          ),
        ],
      );
      final List<List<String>> studentStates = <List<String>>[];
      final List<List<String>> clubStates = <List<String>>[];
      container.listen(studentVisibleEventsProvider, (
        _,
        AsyncValue<List<AppEvent>> next,
      ) {
        if (next.hasValue) {
          studentStates.add(next.value!.map((AppEvent e) => e.id).toList());
        }
      }, fireImmediately: true);
      container.listen(clubDiscoverEventsProvider, (
        _,
        AsyncValue<List<AppEvent>> next,
      ) {
        if (next.hasValue) {
          clubStates.add(next.value!.map((AppEvent e) => e.id).toList());
        }
      }, fireImmediately: true);
      await Future<void>.delayed(Duration.zero);
      for (final bool closed in <bool>[false, true, false]) {
        repo.controller.add(<AppEvent>[
          event(<String, dynamic>{'registrationClosed': closed}),
        ]);
        await Future<void>.delayed(Duration.zero);
      }
      expect(studentStates, <List<String>>[
        <String>['e1'],
        <String>[],
        <String>['e1'],
      ]);
      expect(clubStates, studentStates);
      container.dispose();
      await repo.controller.close();
    },
  );
}
