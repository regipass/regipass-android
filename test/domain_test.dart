import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/core/password_policy.dart';
import 'package:regipass/core/sanitize.dart';
import 'package:regipass/core/text_utils.dart';
import 'package:regipass/domain/account_expiry.dart';
import 'package:regipass/domain/checkin_qr.dart';
import 'package:regipass/domain/department_field_map.dart';
import 'package:regipass/domain/event_utils.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/profiles.dart';

/// Web'den taşınan iş mantığının davranış eşitliği testleri.
///
/// Bu kurallar iki istemcinin paylaştığı Firestore verisini etkiliyor
/// (QR formatı, hedefleme, onboarding kapıları) — sapma olursa web ve mobil
/// birbirinin kaydını yanlış yorumlar.
void main() {
  group('etkinlik son basvuru tarihi', () {
    AppEvent eventWithDeadline(Object? deadline) => AppEvent.fromMap(
      'event-1',
      <String, dynamic>{'deadlineAtMs': deadline, 'hiddenGlobally': false},
    );

    test('gecmis etkinlik son basvuru aninda kesfetten cikar', () {
      final AppEvent event = eventWithDeadline(
        DateTime(2026, 8, 3, 23, 59, 59).millisecondsSinceEpoch,
      );

      expect(
        isPastEvent(event, now: DateTime(2026, 8, 3, 23, 59, 58)),
        isFalse,
      );
      expect(
        isDiscoverableEvent(event, now: DateTime(2026, 8, 3, 23, 59, 59)),
        isFalse,
      );
    });

    test('eski epoch saniyesi tarihleri de gecmis olarak okunur', () {
      const int deadlineSeconds = 1785679200;
      final AppEvent event = eventWithDeadline(deadlineSeconds);

      expect(event.deadlineAtMs, deadlineSeconds * 1000);
      expect(isDiscoverableEvent(event, now: DateTime(2026, 8, 3)), isFalse);
    });

    test('eski deadlineAt alani ISO tarihini destekler', () {
      final AppEvent event = AppEvent.fromMap('event-2', <String, dynamic>{
        'deadlineAt': '2026-08-02T23:59:59',
        'hiddenGlobally': false,
      });

      expect(event.deadlineAtMs, greaterThan(0));
      expect(isDiscoverableEvent(event, now: DateTime(2026, 8, 3)), isFalse);
    });
  });

  group('sadece bölüme özel etkinlik', () {
    AppEvent departmentOnlyEvent({
      String university = 'İstanbul Üniversitesi',
      String department = 'Bilgisayar Mühendisliği',
    }) => AppEvent.fromMap('department-event', <String, dynamic>{
      'targetScope': TargetScope.department,
      'targetUniversity': university,
      'targetDepartment': department,
    });

    StudentProfile student({
      required String university,
      required String department,
    }) => StudentProfile.fromMap('student-1', <String, dynamic>{
      'university': university,
      'department': department,
    });

    test('yalnızca aynı üniversite ve bölümdeki öğrenci görür', () {
      final AppEvent event = departmentOnlyEvent();

      expect(
        canStudentSeeEvent(
          event,
          student(
            university: 'İSTANBUL üniversitesi',
            department: 'bilgisayar mühendisliği',
          ),
        ),
        isTrue,
      );
    });

    test('farklı bölüm veya üniversite öğrencisi göremez', () {
      final AppEvent event = departmentOnlyEvent();

      expect(
        canStudentSeeEvent(
          event,
          student(university: 'İstanbul Üniversitesi', department: 'Hukuk'),
        ),
        isFalse,
      );
      expect(
        canStudentSeeEvent(
          event,
          student(
            university: 'Ankara Üniversitesi',
            department: 'Bilgisayar Mühendisliği',
          ),
        ),
        isFalse,
      );
    });
  });

  group('çoklu hedefli etkinlik', () {
    StudentProfile student({
      required String university,
      required String department,
    }) => StudentProfile.fromMap('student-1', <String, dynamic>{
      'university': university,
      'department': department,
    });

    test('yalnızca bölüme özel etkinlikte üniversite aranmaz', () {
      final AppEvent event = AppEvent.fromMap('e1', <String, dynamic>{
        'targetScope': TargetScope.department,
        'targetDepartments': <String>['Bilgisayar Mühendisliği'],
      });

      expect(
        canStudentSeeEvent(
          event,
          student(
            university: 'Ankara Üniversitesi',
            department: 'Bilgisayar Mühendisliği',
          ),
        ),
        isTrue,
      );
      expect(
        canStudentSeeEvent(
          event,
          student(university: 'Ankara Üniversitesi', department: 'Hukuk'),
        ),
        isFalse,
      );
    });

    test('birden fazla bölüm hedeflenebilir', () {
      final AppEvent event = AppEvent.fromMap('e2', <String, dynamic>{
        'targetScope': TargetScope.department,
        'targetDepartments': <String>['Hukuk', 'Siyaset Bilimi'],
      });

      for (final String department in <String>['hukuk', 'Siyaset Bilimi']) {
        expect(
          canStudentSeeEvent(
            event,
            student(university: 'İstanbul Üniversitesi', department: department),
          ),
          isTrue,
          reason: department,
        );
      }
    });

    test('üniversite + bölüm kapsamında ikisi de tutmalı', () {
      final AppEvent event = AppEvent.fromMap('e3', <String, dynamic>{
        'targetScope': TargetScope.universityDepartment,
        'targetUniversities': <String>[
          'İstanbul Üniversitesi',
          'Ankara Üniversitesi',
        ],
        'targetDepartments': <String>['Hukuk'],
      });

      expect(
        canStudentSeeEvent(
          event,
          student(university: 'Ankara Üniversitesi', department: 'Hukuk'),
        ),
        isTrue,
      );
      expect(
        canStudentSeeEvent(
          event,
          student(university: 'Ege Üniversitesi', department: 'Hukuk'),
        ),
        isFalse,
      );
    });

    test('kulüp alanıyla hedeflenen etkinliği ilgili bölüm görür', () {
      // Kulüp bölüm seçmezse hedef, kendi alanı olur.
      final AppEvent event = AppEvent.fromMap('e4', <String, dynamic>{
        'targetScope': TargetScope.department,
        'targetDepartments': <String>['Bilgisayar ve Yazılım'],
      });

      expect(
        canStudentSeeEvent(
          event,
          student(
            university: 'İstanbul Üniversitesi',
            department: 'Bilgisayar Mühendisliği',
          ),
        ),
        isTrue,
      );
      expect(
        canStudentSeeEvent(
          event,
          student(university: 'İstanbul Üniversitesi', department: 'Hukuk'),
        ),
        isFalse,
      );
    });

    test('hedef bölüm yoksa kulübün alanları gösterilir', () {
      final AppEvent event = AppEvent.fromMap('e5', <String, dynamic>{
        'targetScope': TargetScope.public,
        'clubFields': <String>['Hukuk', 'İletişim'],
      });

      expect(eventAudienceFields(event), <String>['Hukuk', 'İletişim']);
    });
  });

  group('foldTr — Türkçe normalizasyon', () {
    test('Türkçe karakterleri ASCII karşılığına indirger', () {
      expect(foldTr('İstanbul Üniversitesi'), 'istanbul universitesi');
      expect(foldTr('Gıda Mühendisliği'), 'gida muhendisligi');
      expect(foldTr('ÇOMÜ'), 'comu');
    });

    test('büyük I ve küçük ı aynı harfe iner', () {
      expect(foldTr('IŞIK'), foldTr('ışık'));
    });

    test('noktalama ve fazla boşluk temizlenir', () {
      expect(foldTr('  Fen-Edebiyat  Fakültesi '), 'fenedebiyat fakultesi');
    });
  });

  group('checkin QR — token codec', () {
    test('üretilen token geri çözülür', () {
      final Map<String, dynamic> payload = buildStudentCheckinPayload(
        registrationId: 'evt1_stu1',
        eventId: 'evt1',
        studentId: 'stu1',
        lat: 41.0102345,
        lng: 28.9644567,
      );

      final String token = createCheckinQrToken(payload);
      expect(token.startsWith(kCheckinQrPrefix), isTrue);

      final Map<String, dynamic>? parsed = parseCheckinQrToken(token);
      expect(parsed, isNotNull);
      expect(parsed!['type'], 'event-checkin');
      expect(parsed['eventId'], 'evt1');
      // Koordinatlar 5 ondalığa yuvarlanır (~1 m hassasiyet).
      expect(parsed['lat'], 41.01023);
      expect(parsed['lng'], 28.96446);
    });

    test('Regipass olmayan QR reddedilir', () {
      expect(parseCheckinQrToken('https://example.com'), isNull);
      expect(parseCheckinQrToken(null), isNull);
      expect(parseCheckinQrToken('EVAPPQR1:bozuk!!!'), isNull);
    });

    test('Türkçe karakter içeren yük bozulmadan taşınır', () {
      final String token = createCheckinQrToken(<String, dynamic>{
        'ad': 'Şeyma Çağrı',
      });
      expect(parseCheckinQrToken(token)!['ad'], 'Şeyma Çağrı');
    });

    test('oturum QR yükü kulübün ürettiği biçimde', () {
      final String token = createCheckinQrToken(
        buildSessionCheckinPayload(eventId: 'e1', session: 3),
      );
      final Map<String, dynamic> parsed = parseCheckinQrToken(token)!;
      expect(parsed['type'], 'session-checkin');
      expect(parsed['session'], 3);
    });
  });

  group('bölüm <-> kulüp alanı ağırlığı', () {
    test('tam eşleşen anahtar kelime en yüksek ağırlığı verir', () {
      expect(
        getFieldRelationWeight(
          'Bilgisayar Mühendisliği',
          'Bilgisayar ve Yazılım',
        ),
        1.0,
      );
    });

    test('bir bölüm birden fazla alanla eşleşebilir', () {
      expect(
        getFieldRelationWeight(
          'Gıda Mühendisliği',
          'Gıda Mühendisliği ve Teknolojisi',
        ),
        1.0,
      );
      expect(
        getFieldRelationWeight('Gıda Mühendisliği', 'Mühendislik ve Mimarlık'),
        greaterThan(0),
      );
    });

    test('ilgisiz eşleşme sıfır döner', () {
      expect(getFieldRelationWeight('Hukuk', 'Denizcilik'), 0);
    });

    test('Türkçe ek almış bölüm adı yakalanır', () {
      // "edebiyat" + "ı" -> "edebiyatı"; kelime sınırı kontrolü bunu kaçırırdı.
      expect(
        getFieldRelationWeight('Türk Dili ve Edebiyatı', 'Fen-Edebiyat'),
        greaterThan(0),
      );
    });
  });

  group('şifre politikası', () {
    test('kural: 6+ karakter, büyük, küçük, rakam', () {
      expect(isStrongPassword('Abc123'), isTrue);
      expect(isStrongPassword('abc123'), isFalse, reason: 'büyük harf yok');
      expect(isStrongPassword('ABC123'), isFalse, reason: 'küçük harf yok');
      expect(isStrongPassword('Abcdef'), isFalse, reason: 'rakam yok');
      expect(isStrongPassword('Ab1'), isFalse, reason: 'çok kısa');
    });

    test('Türkçe harfler de harf sayılır', () {
      expect(isStrongPassword('Çağrı1'), isTrue);
    });
  });

  group('sanitize', () {
    test('HTML etiketleri ve olay yakalayıcıları sökülür', () {
      expect(
        sanitizeText('<script>alert(1)</script>Merhaba'),
        'alert(1)Merhaba',
      );
      expect(sanitizeUrl('javascript:alert(1)'), '');
      expect(sanitizeUrl('https://ornek.com'), 'https://ornek.com');
    });

    test('isim alanı Türkçe harfleri korur, sembolleri atar', () {
      expect(sanitizeName('Ayşe Gül<>#'), 'Ayşe Gül');
    });

    test('zararlı girdi kaydetmeden önce yakalanır', () {
      expect(detectHarmfulInput('<img onerror=x>'), isTrue);
      expect(detectHarmfulInput('normal metin'), isFalse);
    });

    test('e-posta biçimi doğrulanır', () {
      expect(sanitizeEmail('  Test@Ornek.COM '), 'test@ornek.com');
      expect(sanitizeEmail('bozuk@'), isNull);
    });
  });

  group('yönlendirme kapıları', () {
    StudentProfile student({
      bool onboarded = true,
      bool phoneVerified = true,
      bool banned = false,
    }) => StudentProfile.fromMap('u1', <String, dynamic>{
      'onboardingCompleted': onboarded,
      'phoneVerified': phoneVerified,
      'banned': banned,
    });

    test('öğrenci: onboarding -> telefon -> panel sırası', () {
      expect(getStudentRouteByStatus(null), Routes.studentOnboarding);
      expect(
        getStudentRouteByStatus(student(onboarded: false)),
        Routes.studentOnboarding,
      );
      expect(
        getStudentRouteByStatus(student(phoneVerified: false)),
        Routes.phoneVerify,
      );
      expect(getStudentRouteByStatus(student()), Routes.studentHome);
    });

    test('engellenmiş öğrenci hiçbir sayfaya giremez', () {
      expect(getStudentRouteByStatus(student(banned: true)), Routes.banned);
    });

    ClubProfile club({bool onboarded = true, String? status}) =>
        ClubProfile.fromMap('c1', <String, dynamic>{
          'onboardingCompleted': onboarded,
          // Alan hiç yazılmamışsa varsayılanın uygulandığını da doğrulamak için
          // null geçildiğinde anahtar eklenmez.
          'clubStatus': ?status,
        });

    test('kulüp: bilgi -> belge -> inceleme -> panel sırası', () {
      expect(getClubRouteByStatus(null), Routes.clubOnboarding);
      expect(
        getClubRouteByStatus(club(onboarded: false)),
        Routes.clubOnboarding,
      );
      // clubStatus yoksa varsayılan belge bekleme aşamasıdır.
      expect(getClubRouteByStatus(club()), Routes.clubDocuments);
      expect(
        getClubRouteByStatus(club(status: 'pending_review')),
        Routes.clubPending,
      );
      expect(getClubRouteByStatus(club(status: 'approved')), Routes.clubHome);
      expect(getClubRouteByStatus(club(status: 'banned')), Routes.banned);
    });
  });

  group('doğrulanmamış telefon — kayıt ömrü', () {
    final DateTime signedUpAt = DateTime(2026, 8, 1, 12);

    bool expiredAt(
      DateTime now, {
      bool phoneVerified = false,
      int? createdAtMs,
    }) => isPhoneVerifyGraceExpired(
      phoneVerified: phoneVerified,
      createdAtMs: createdAtMs ?? signedUpAt.millisecondsSinceEpoch,
      now: now,
    );

    test('süre dolmadan silinmez, dolduktan sonra silinir', () {
      expect(expiredAt(signedUpAt.add(const Duration(days: 3))), isFalse);
      expect(
        expiredAt(signedUpAt.add(const Duration(days: 3, seconds: 1))),
        isTrue,
      );
    });

    test('doğrulanmış numara ne kadar eski olursa olsun silinmez', () {
      expect(
        expiredAt(
          signedUpAt.add(const Duration(days: 400)),
          phoneVerified: true,
        ),
        isFalse,
      );
    });

    test('createdAt okunamıyorsa silinmez', () {
      // Sunucu damgası onaylanana kadar yerel anlık görüntüde null görünür;
      // o anda silmek yeni açılmış hesabı yok ederdi.
      expect(
        isPhoneVerifyGraceExpired(
          phoneVerified: false,
          createdAtMs: null,
          now: signedUpAt.add(const Duration(days: 400)),
        ),
        isFalse,
      );
      expect(
        expiredAt(signedUpAt.add(const Duration(days: 400)), createdAtMs: 0),
        isFalse,
      );
    });

    test('profil createdAt alanını Timestamp olarak okur', () {
      final StudentProfile profile = StudentProfile.fromMap(
        'u1',
        <String, dynamic>{
          'createdAt': Timestamp.fromDate(signedUpAt),
          'phoneVerified': false,
        },
      );

      expect(profile.createdAtMs, signedUpAt.millisecondsSinceEpoch);
      expect(
        isPhoneVerifyGraceExpired(
          phoneVerified: profile.phoneVerified,
          createdAtMs: profile.createdAtMs,
          now: signedUpAt.add(const Duration(days: 4)),
        ),
        isTrue,
      );
    });
  });
}
