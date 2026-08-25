/// js/core/firebase.js karşılığı — tek noktadan Firebase erişimi.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants.dart';

FirebaseAuth get fbAuth => FirebaseAuth.instance;
FirebaseFirestore get fbDb => FirebaseFirestore.instance;
FirebaseStorage get fbStorage => FirebaseStorage.instance;

typedef Doc = DocumentReference<Map<String, dynamic>>;
typedef Col = CollectionReference<Map<String, dynamic>>;
typedef Snap = DocumentSnapshot<Map<String, dynamic>>;
typedef QSnap = QuerySnapshot<Map<String, dynamic>>;

Col get usersCol => fbDb.collection(Collections.users);
Col get studentProfilesCol => fbDb.collection(Collections.studentProfiles);
Col get clubProfilesCol => fbDb.collection(Collections.clubProfiles);
Col get eventsCol => fbDb.collection(Collections.events);
Col get registrationsCol => fbDb.collection(Collections.eventRegistrations);
Col get certificatesCol => fbDb.collection(Collections.studentCertificates);
Col get announcementsCol => fbDb.collection(Collections.announcements);

Doc userDoc(String uid) => usersCol.doc(uid);
Doc studentProfileDoc(String uid) => studentProfilesCol.doc(uid);
Doc clubProfileDoc(String uid) => clubProfilesCol.doc(uid);
Doc eventDoc(String eventId) => eventsCol.doc(eventId);

/// Kontenjan sayacının parçaları: `events/{eventId}/quota_shards/{index}`.
///
/// Sayaç neden tek dokümanda değil: Firestore'da tek bir dokümana
/// sürdürülebilir yazma hızı saniyede ~1'dir; kontenjanı tek satırda tutmak
/// bütün etkinliği o hıza mahkûm ederdi (yük testinde 100 eşzamanlı kayıtta
/// %99 hata). Kapasiteler parçalara bölünür, toplamları tam olarak
/// kontenjandır. Bkz. `lib/domain/registration_capacity.dart`.
Col quotaShardsCol(String eventId) =>
    eventDoc(eventId).collection('quota_shards');

Doc quotaShardDoc(String eventId, int shard) =>
    quotaShardsCol(eventId).doc('$shard');

/// Kayıt doküman kimliği deterministiktir; firestore.rules bunu şart koşar:
///   registrationId == eventId + "_" + auth.uid
String registrationIdFor(String eventId, String studentId) =>
    '${eventId}_$studentId';

Doc registrationDoc(String eventId, String studentId) =>
    registrationsCol.doc(registrationIdFor(eventId, studentId));

/// Sertifika kimliği de deterministiktir — aynı öğrenciye tekrar dağıtım
/// üstüne yazar, kopya oluşturmaz.
Doc certificateDoc(String eventId, String studentId) =>
    certificatesCol.doc('${eventId}_$studentId');
