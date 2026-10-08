/// Yeni sertifika sistemi (İP-8 / İP-9) — mobil istemci.
///
/// Sunucu: Regipass-Web/functions/certificates/handlers.js (europe-west1).
/// Web karşılığı: js/modules/certificates/cert-api.js. Firestore'dan yalnızca
/// OKUNUR; bütün yazmalar fonksiyonlardan geçer (kurallar istemciye kapalı).
///
/// Mobilde editör ve şablon yükleme YOK (karar: Arda, 27 Eylül): kulüp webde
/// kaydettiği belgeyi buradan gönderir / geri alır.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_refs.dart';

class CertificateFile {
  const CertificateFile({required this.path, required this.fileName});
  final String path;
  final String fileName;
}

/// Sunucu hata gerekçesi ("already-running", "sessions-not-finished" …).
/// Sunucu gerekçeyi hata mesajında taşır (HttpsError(code, reason)).
String certificateErrorReason(Object error) {
  if (error is FirebaseFunctionsException) {
    final String message = error.message ?? '';
    if (RegExp(r'^[a-z0-9-]+$').hasMatch(message)) return message;
  }
  return 'generic';
}

class CertificateService {
  const CertificateService();

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> data, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
        .call(data);
    final Object? out = result.data;
    return out is Map ? Map<String, Object?>.from(out) : <String, Object?>{};
  }

  /// Büyük etkinlikte sunucu süre bütçesi dolunca `partial: true` döner;
  /// kalanlar için otomatik yeniden çağrılır, sayılar toplanır.
  Future<Map<String, Object?>> send(
    String eventId, {
    bool outdated = false,
  }) async {
    final Map<String, Object?> total = <String, Object?>{};
    Map<String, Object?> last = <String, Object?>{};
    int sum(String k) =>
        ((total[k] as num?) ?? 0).toInt() + ((last[k] as num?) ?? 0).toInt();
    for (int round = 0; round < 12; round++) {
      last = await _call('sendCertificates', <String, Object?>{
        'eventId': eventId,
        'scope': outdated ? 'outdated' : 'pending',
      }, timeout: const Duration(minutes: 9));
      if (round == 0) total['total'] = last['total'];
      for (final String k in <String>['done', 'sent', 'failed', 'skipped']) {
        total[k] = sum(k);
      }
      if (last['partial'] != true) break;
    }
    return <String, Object?>{...last, ...total};
  }

  Future<Map<String, Object?>> revoke(String eventId) => _call(
    'revokeCertificates',
    <String, Object?>{'eventId': eventId},
    timeout: const Duration(minutes: 5),
  );

  Future<void> setThreshold(String eventId, int? percent) => _call(
    'setCertificateThreshold',
    <String, Object?>{'eventId': eventId, 'thresholdPercent': percent ?? 0},
  );

  Future<void> setFullName(String eventId, bool allow) => _call(
    'setCertificateFullName',
    <String, Object?>{'eventId': eventId, 'allow': allow},
  );

  Future<CertificateFile> _writeTemp(String base64Text, String fileName) async {
    final Directory dir = await getTemporaryDirectory();
    final String safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    final File out = File('${dir.path}/$safe');
    await out.writeAsBytes(base64Decode(base64Text), flush: true);
    return CertificateFile(path: out.path, fileName: safe);
  }

  /// Belgeyi sunucu yeniden üretir; geçici dosyaya yazılır.
  Future<CertificateFile> download(String eventId, {String? studentId}) async {
    final Map<String, Object?> r = await _call(
      'downloadCertificate',
      <String, Object?>{'eventId': eventId, 'studentId': ?studentId},
    );
    return _writeTemp(
      '${r['pdfBase64'] ?? ''}',
      '${r['fileName'] ?? 'Regipass-belge.pdf'}',
    );
  }

  /// Kaydedilmiş yerleşimle örnek belge (kulüp).
  Future<CertificateFile> preview(String eventId, String sampleName) async {
    final Map<String, Object?> r = await _call(
      'renderCertificatePreview',
      <String, Object?>{'eventId': eventId, 'sampleName': sampleName},
      timeout: const Duration(minutes: 2),
    );
    return _writeTemp('${r['pdfBase64'] ?? ''}', 'Regipass-onizleme.pdf');
  }
}

final Provider<CertificateService> certificateServiceProvider =
    Provider<CertificateService>((Ref ref) => const CertificateService());

/// events/{e}/certificate/config — yoksa null.
// ignore: always_specify_types
final certificateConfigProvider =
    StreamProvider.family<Map<String, Object?>?, String>((
      Ref ref,
      String eventId,
    ) {
      return fbDb
          .collection('events')
          .doc(eventId)
          .collection('certificate')
          .doc('config')
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> s) => s.data());
    });

/// Son gönderim / geri alma kayıtları (yeniden eskiye).
// ignore: always_specify_types
final certificateIssuesProvider =
    StreamProvider.family<List<Map<String, Object?>>, String>((
      Ref ref,
      String eventId,
    ) {
      return fbDb
          .collection('events')
          .doc(eventId)
          .collection('certificate_issues')
          .orderBy('startedAtMs', descending: true)
          .limit(10)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      <String, Object?>{'id': d.id, ...d.data()},
                )
                .toList(),
          );
    });

/// Kulübün bir etkinlikteki belgeleri: öğrenci kimliği → kayıt.
/// Anahtar: "kulüpId|etkinlikId" (kurallar clubId filtresi ister).
// ignore: always_specify_types
final clubEventCertificatesProvider =
    StreamProvider.family<Map<String, Map<String, Object?>>, String>((
      Ref ref,
      String key,
    ) {
      final List<String> parts = key.split('|');
      return fbDb
          .collection('event_certificates')
          .where('clubId', isEqualTo: parts.first)
          .where('eventId', isEqualTo: parts.last)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> s) {
            final Map<String, Map<String, Object?>> out =
                <String, Map<String, Object?>>{};
            for (final QueryDocumentSnapshot<Map<String, dynamic>> d
                in s.docs) {
              final String id = '${d.data()['studentId'] ?? ''}';
              if (id.isNotEmpty) out[id] = d.data();
            }
            return out;
          });
    });

/// Öğrencinin yeni sistemdeki belgeleri (hata kayıtları gösterilmez).
// ignore: always_specify_types
final studentNewCertificatesProvider =
    StreamProvider.family<List<Map<String, Object?>>, String>((
      Ref ref,
      String uid,
    ) {
      return fbDb
          .collection('event_certificates')
          .where('studentId', isEqualTo: uid)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data(),
                )
                .where(
                  (Map<String, Object?> c) =>
                      c['status'] == 'issued' || c['status'] == 'revoked',
                )
                .toList(),
          );
    });
