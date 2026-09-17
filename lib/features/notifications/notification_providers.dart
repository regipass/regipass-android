/// Bildirim akışının kaynakları.
///
/// İki kaynak birleştirilir:
///   1. Yönetici duyuruları (Firestore `notifications`),
///   2. Kullanıcının etkinliklerinden türeyen ve zamanı gelmiş hatırlatmalar
///      (yaklaşıyor / başladı / başvurular kapandı).
///
/// İkincisi Firestore'da tutulmaz: aynı bilgi zaten etkinlik dokümanında var,
/// her kullanıcı için ayrıca bildirim belgesi yazmak veriyi kopyalamak olurdu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../domain/event_reminders.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/announcement.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';
import '../club/club_providers.dart';
import '../student/student_providers.dart';

/// Bu oturum bildirimleri hangi gözle görüyor?
///
/// Yönetici için `null`: yöneticinin kendi etkinliği ya da kayıtlı olduğu
/// bir etkinlik yok, o yalnızca duyuru gönderir.
final Provider<ReminderAudience?> notificationAudienceProvider =
    Provider<ReminderAudience?>((Ref ref) {
      final Session session = ref.watch(sessionProvider);
      if (session.isAdmin || !session.isSignedIn) return null;

      return switch (session.resolvedRole) {
        UserRole.club => ReminderAudience.club,
        UserRole.student => ReminderAudience.student,
        _ => null,
      };
    });

/// Duyuruların hedeflendiği üniversite — kullanıcının kendi üniversitesi.
final Provider<String> notificationUniversityProvider = Provider<String>((
  Ref ref,
) {
  final ReminderAudience? audience = ref.watch(notificationAudienceProvider);
  if (audience == null) return '';

  if (audience == ReminderAudience.club) {
    final ClubProfile? club = ref.watch(clubProfileProvider).value;
    return club?.university ?? '';
  }

  final StudentProfile? student = ref.watch(studentProfileProvider).value;
  return student?.university ?? '';
});

/// Kullanıcıya ulaşan duyurular — canlı.
final StreamProvider<List<Announcement>> myAnnouncementsProvider =
    StreamProvider<List<Announcement>>((Ref ref) {
      final ReminderAudience? audience = ref.watch(notificationAudienceProvider);
      final String university = ref.watch(notificationUniversityProvider);

      if (audience == null) {
        return Stream<List<Announcement>>.value(const <Announcement>[]);
      }

      final bool asClub = audience == ReminderAudience.club;

      return ref
          .watch(announcementRepositoryProvider)
          .watchForViewer(
            university: university,
            role: asClub ? 'club' : 'student',
          );
    });

/// Hatırlatmaların üretileceği etkinlikler.
///
///   • Öğrenci: **kayıt olduğu** etkinlikler. Keşfetteki her etkinlik için
///     bildirim kurmak, ilgilenmediği yüzlerce etkinlik için alarm demekti.
///   • Kulüp: kendi düzenlediği etkinlikler.
final Provider<List<AppEvent>> reminderSourceEventsProvider =
    Provider<List<AppEvent>>((Ref ref) {
      final ReminderAudience? audience = ref.watch(notificationAudienceProvider);
      if (audience == null) return const <AppEvent>[];

      if (audience == ReminderAudience.club) {
        return ref.watch(clubEventsProvider).value ?? const <AppEvent>[];
      }

      final List<RegistrationWithEvent> items =
          ref.watch(appointmentsProvider).value ??
          const <RegistrationWithEvent>[];

      return items
          .map((RegistrationWithEvent item) => item.event)
          .whereType<AppEvent>()
          .toList();
    });

// ── Bildirim listesi ──────────────────────────────────────────────────

enum NotificationItemKind { announcement, upcoming, started, deadline }

/// Listede çizilecek tek satır. Metinler burada çözülür; ekran yalnızca
/// gösterir.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.atMs,
    this.route = '',
  });

  final String id;
  final NotificationItemKind kind;
  final String title;
  final String body;
  final int atMs;

  /// Bildirime dokununca gidilecek tam rota (sorgu parametreleriyle).
  ///
  /// Rol burada çözülür, ekranda değil: kulüp etkinliğin yönetim sayfasına,
  /// öğrenci ise kendi kaydının detay penceresine gider ve bu ayrım yalnızca
  /// bu sağlayıcının bildiği bilgiye (kitle + kayıt eşleşmesi) dayanır.
  /// Duyurularda gidilecek bir sayfa yok; orada boş kalır.
  final String route;

  bool get hasRoute => route.isNotEmpty;

  bool get isAnnouncement => kind == NotificationItemKind.announcement;
}

NotificationItemKind _kindOf(EventReminderKind kind) => switch (kind) {
  EventReminderKind.upcoming => NotificationItemKind.upcoming,
  EventReminderKind.started => NotificationItemKind.started,
  EventReminderKind.deadline => NotificationItemKind.deadline,
};

/// Duyurular + zamanı gelmiş etkinlik hatırlatmaları, yeniden eskiye.
final Provider<List<NotificationItem>> notificationFeedProvider =
    Provider<List<NotificationItem>>((Ref ref) {
      final ReminderAudience? audience = ref.watch(notificationAudienceProvider);
      if (audience == null) return const <NotificationItem>[];

      final String language = ref.watch(languageProvider);

      final List<Announcement> announcements =
          ref.watch(myAnnouncementsProvider).value ?? const <Announcement>[];

      final List<EventReminder> fired = firedRemindersForEvents(
        ref.watch(reminderSourceEventsProvider),
      );

      // Öğrenci tarafında hedef, etkinliğin kendisi değil öğrencinin O
      // etkinliğe ait KAYDI: detay penceresi kayıt kimliğiyle açılıyor
      // (bkz. StudentAppointmentsScreen.openRegistrationId).
      final Map<String, String> registrationByEvent = <String, String>{};
      if (audience == ReminderAudience.student) {
        final List<RegistrationWithEvent> appointments =
            ref.watch(appointmentsProvider).value ??
            const <RegistrationWithEvent>[];
        for (final RegistrationWithEvent item in appointments) {
          registrationByEvent[item.registration.eventId] = item.registration.id;
        }
      }

      String routeFor(String eventId) {
        if (eventId.isEmpty) return '';

        if (audience == ReminderAudience.club) {
          return '${Routes.clubEventDetail}'
              '?eventId=${Uri.encodeComponent(eventId)}';
        }

        // Kayıt bulunamadıysa (kayıt silinmiş, liste henüz gelmemiş)
        // yönlendirme yok — boş bir pencere açmaktansa bildirim düz kalsın.
        final String? registrationId = registrationByEvent[eventId];
        if (registrationId == null || registrationId.isEmpty) return '';

        return '${Routes.studentAppointments}'
            '?open=${Uri.encodeComponent(registrationId)}';
      }

      final List<NotificationItem> items = <NotificationItem>[
        for (final Announcement a in announcements)
          NotificationItem(
            id: 'announcement:${a.id}',
            kind: NotificationItemKind.announcement,
            // Web yöneticisinden gelen duyuruların başlığı yok (tek bir
            // `message` alanı yazılıyor); kart başlıksız kalmasın.
            title: a.title.isNotEmpty
                ? a.title
                : translate('notifications.announcement', language: language),
            body: a.body,
            atMs: a.createdAtMs,
          ),
        for (final EventReminder r in fired)
          NotificationItem(
            id: '${r.kind.name}:${r.eventId}',
            kind: _kindOf(r.kind),
            title: translate(
              reminderTitleKey(r.kind, audience),
              language: language,
            ),
            body: translate(
              reminderBodyKey(r.kind, audience),
              params: <String, Object?>{'title': r.eventTitle},
              language: language,
            ),
            atMs: r.at.millisecondsSinceEpoch,
            route: routeFor(r.eventId),
          ),
      ]..sort(
        (NotificationItem a, NotificationItem b) => b.atMs.compareTo(a.atMs),
      );

      return items;
    });

// ── Okundu durumu ─────────────────────────────────────────────────────

/// Kullanıcının bildirimler sayfasını son açtığı an (epoch ms).
///
/// Cihazda tutulur; hesap değişince sıfırdan okunur.
class NotificationSeenNotifier extends Notifier<int> {
  @override
  int build() {
    final String? uid = ref.watch(currentUidProvider);
    if (uid == null) return 0;
    return ref.read(notificationReadStoreProvider).lastSeenAtMs(uid);
  }

  /// Sayfa açıldığında çağrılır. Zaman damgası "şimdi" değil, listedeki en
  /// yeni öğenin anıdır: aradaki farkta gelen bir duyuru okunmuş sayılmasın.
  Future<void> markSeen(int atMs) async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null || atMs <= state) return;

    state = atMs;
    await ref.read(notificationReadStoreProvider).markSeen(uid, atMs);
  }
}

final NotifierProvider<NotificationSeenNotifier, int>
notificationSeenProvider = NotifierProvider<NotificationSeenNotifier, int>(
  NotificationSeenNotifier.new,
);

/// Kullanıcının tek tek dokunduğu bildirimlerin kimlikleri.
///
/// Sayfa damgasından ([notificationSeenProvider]) ayrı tutulur: damga
/// "listeye şu ana kadar baktım" der ve sayfa açılır açılmaz ilerler; bu
/// küme ise yalnızca gerçekten dokunulan bildirimi işaretler. İşaretin
/// sönmesi kullanıcının o bildirimle ilgilendiğini gösterir.
class NotificationOpenedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final String? uid = ref.watch(currentUidProvider);
    if (uid == null) return const <String>{};
    return ref.read(notificationReadStoreProvider).openedIds(uid);
  }

  Future<void> markOpened(String id) async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null || id.isEmpty || state.contains(id)) return;

    // Önce ekranda söner, yazma arkada tamamlanır: dokunuşun karşılığı
    // beklemesiz görünsün.
    state = <String>{...state, id};
    state = await ref.read(notificationReadStoreProvider).markOpened(uid, id);
  }
}

final NotifierProvider<NotificationOpenedNotifier, Set<String>>
notificationOpenedProvider =
    NotifierProvider<NotificationOpenedNotifier, Set<String>>(
      NotificationOpenedNotifier.new,
    );

/// Zil düğmesindeki rozet için okunmamış sayısı.
final Provider<int> unreadNotificationCountProvider = Provider<int>((Ref ref) {
  final int lastSeen = ref.watch(notificationSeenProvider);
  final Set<String> opened = ref.watch(notificationOpenedProvider);

  return ref
      .watch(notificationFeedProvider)
      .where(
        (NotificationItem item) =>
            item.atMs > lastSeen && !opened.contains(item.id),
      )
      .length;
});
