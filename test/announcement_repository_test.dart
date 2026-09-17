// Mutable SDK fakes record requests without a platform channel. Their emitted
// payloads and filters are also exercised against the real Firestore emulator.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/notification_targets.dart';
import 'package:regipass/services/announcement_repository.dart';

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class _SnapshotDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _SnapshotDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final List<Map<String, dynamic>> writes = [];
  final StreamController<QuerySnapshot<Map<String, dynamic>>> controller =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  Filter? filter;
  Object? error;

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    if (error != null) throw error!;
    writes.add(data);
    return _Document();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      filter = invocation.positionalArguments.single as Filter;
      return this;
    }
    if (invocation.memberName == #snapshots) return controller.stream;
    return super.noSuchMethod(invocation);
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  final _Collection notifications = _Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'notifications');
    return notifications;
  }
}

Object? _jsonValue(Object? value) {
  if (value is FieldPath) return value.components.join('.');
  if (value is FieldValue) return 'SERVER_TIMESTAMP';
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _jsonValue(item)));
  }
  if (value is Iterable) return value.map(_jsonValue).toList();
  return value;
}

void main() {
  final List<Object?> exported = [];
  tearDownAll(() {
    final String? path =
        Platform.environment['REGIPASS_MOBILE_NOTIFICATION_FIXTURES'];
    if (path != null) File(path).writeAsStringSync(jsonEncode(exported));
  });

  for (final String audience in ['student', 'club', 'both']) {
    test(
      'broadcast $audience writes one web-compatible notification',
      () async {
        final db = _Firestore();
        addTearDown(db.notifications.controller.close);
        final repository = AnnouncementRepository(firestore: db);
        await repository.sendBroadcast(
          title: ' Duyuru ',
          body: ' Metin ',
          audience: audience,
          senderUid: 'AY1gi7Zi9AcqhjZinEkR1baB9T72',
        );
        expect(db.notifications.writes, hasLength(1));
        final data = db.notifications.writes.single;
        expect(data['title'], 'Duyuru');
        expect(data['message'], 'Metin');
        expect(data['body'], 'Metin');
        expect(data['global'], true);
        expect(data['university'], globalNotificationUniversity);
        expect(
          data['recipients'],
          audience == 'both' ? ['all:student', 'all:club'] : ['all:$audience'],
        );
        exported.add({'kind': 'broadcast', 'data': _jsonValue(data)});
      },
    );
  }

  test('university send uses the normalized web keys', () async {
    final db = _Firestore();
    addTearDown(db.notifications.controller.close);
    await AnnouncementRepository(firestore: db).send(
      title: 'Duyuru',
      body: 'Metin',
      audience: 'both',
      university: 'ÇUKUROVA ÜNİVERSİTESİ',
      city: 'Adana',
      senderUid: 'AY1gi7Zi9AcqhjZinEkR1baB9T72',
    );
    final data = db.notifications.writes.single;
    expect(data['recipients'], [
      'uni:cukurova universitesi:student',
      'uni:cukurova universitesi:club',
    ]);
    expect(data['global'], false);
    exported.add({'kind': 'university', 'data': _jsonValue(data)});
  });

  test('permission failure propagates to the admin screen', () async {
    final db = _Firestore();
    addTearDown(db.notifications.controller.close);
    db.notifications.error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await expectLater(
      AnnouncementRepository(firestore: db).sendBroadcast(
        title: 'Duyuru',
        body: 'Metin',
        audience: 'both',
        senderUid: 'other',
      ),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    expect(db.notifications.writes, isEmpty);
  });

  test(
    'invalid audiences and oversized messages do not start writes',
    () async {
      final db = _Firestore();
      addTearDown(db.notifications.controller.close);
      final repository = AnnouncementRepository(firestore: db);
      for (final input in [
        (title: '', body: 'Metin', audience: 'both'),
        (title: 'Duyuru', body: 'x' * 1001, audience: 'both'),
        (title: 'Duyuru', body: 'Metin', audience: 'admin'),
      ]) {
        await expectLater(
          repository.sendBroadcast(
            title: input.title,
            body: input.body,
            audience: input.audience,
            senderUid: 'admin',
          ),
          throwsArgumentError,
        );
      }
      expect(db.notifications.writes, isEmpty);
    },
  );

  for (final role in ['student', 'club']) {
    for (final university in ['', 'ÇUKUROVA ÜNİVERSİTESİ']) {
      test(
        '$role with university "$university" listens for global notifications',
        () async {
          final db = _Firestore();
          addTearDown(db.notifications.controller.close);
          final stream = AnnouncementRepository(
            firestore: db,
          ).watchForViewer(university: university, role: role);
          final future = stream.first;
          exported.add({
            'kind': 'query',
            'role': role,
            'university': university,
            'filter': _jsonValue(db.notifications.filter!.toJson()),
          });
          db.notifications.controller.add(
            _Snapshot([
              _SnapshotDocument('both', {
                'audience': 'both',
                'message': 'Global',
                'createdAtMs': 2,
              }),
              _SnapshotDocument('student', {
                'audience': 'student',
                'message': 'Student',
                'createdAtMs': 3,
              }),
              _SnapshotDocument('club', {
                'audience': 'club',
                'message': 'Club',
                'createdAtMs': 1,
              }),
            ]),
          );
          final list = await future;
          expect(
            list.map((a) => a.id).toList(),
            role == 'student' ? ['student', 'both'] : ['both', 'club'],
          );
        },
      );
    }
  }
}
