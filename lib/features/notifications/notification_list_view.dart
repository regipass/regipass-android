/// Öğrenci ve kulüp bildirim sayfalarının ortak gövdesi.
///
/// İki rol de aynı listeyi görür; tek fark metinlerin kime göre yazıldığı
/// (bkz. `ReminderAudience`) ve üst çubuk. Ayrı iki liste yazmak, aynı
/// düzeltmeyi iki yerde yapmak demekti.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../services/notification_service.dart';
import '../shared/common_widgets.dart';
import 'notification_providers.dart';

class NotificationListView extends ConsumerStatefulWidget {
  const NotificationListView({super.key});

  @override
  ConsumerState<NotificationListView> createState() =>
      _NotificationListViewState();
}

class _NotificationListViewState extends ConsumerState<NotificationListView> {
  /// Sayfa açıldığı andaki okuma damgası.
  ///
  /// Okundu işareti hemen atılıyor ama vurgular bu damgaya göre çiziliyor:
  /// aksi hâlde kullanıcı sayfayı açar açmaz yeni bildirimlerin vurgusu
  /// gözünün önünde silinirdi.
  late final int _entrySeenAt = ref.read(notificationSeenProvider);

  /// Bildirimler sistem ayarlarından kapalı mı? (Uyarı şeridi için.)
  bool? _systemEnabled;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markSeen();
      _checkSystemSetting();
    });
  }

  void _markSeen() {
    final List<NotificationItem> feed = ref.read(notificationFeedProvider);
    if (feed.isEmpty) return;
    ref.read(notificationSeenProvider.notifier).markSeen(feed.first.atMs);
  }

  Future<void> _checkSystemSetting() async {
    final bool enabled = await NotificationService.instance.areEnabled();
    if (mounted) setState(() => _systemEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final List<NotificationItem> items = ref.watch(notificationFeedProvider);
    final Set<String> opened = ref.watch(notificationOpenedProvider);

    // Liste sonradan dolduysa (duyuru akışı geç geldi) damgayı ilerlet.
    if (items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markSeen();
      });
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          if (_systemEnabled == false) ...<Widget>[
            const _DisabledNotice(),
            const SizedBox(height: 16),
          ],
          EmptyState(
            message: context.t('student.notifications.empty'),
            icon: Icons.notifications_none_rounded,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: items.length + (_systemEnabled == false ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (_systemEnabled == false) {
          if (index == 0) return const _DisabledNotice();
          index -= 1;
        }

        final NotificationItem item = items[index];
        return _NotificationCard(
          item: item,
          // İşaret iki koşula birden bağlı: sayfa açılmadan önce gelmiş
          // olacak VE kullanıcı henüz o bildirime dokunmamış olacak.
          unread: item.atMs > _entrySeenAt && !opened.contains(item.id),
          onTap: () => _open(item),
        );
      },
    );
  }

  /// Bildirime dokunuldu: işareti söndür, hedefi varsa oraya git.
  ///
  /// Sıra önemli — işaret önce sönüyor. Yönlendirme sonrası geri dönüldüğünde
  /// liste yeniden kurulacağı için, işareti gidişe bağlamak "geri gelince
  /// hâlâ okunmamış" gibi görünmesine yol açardı.
  Future<void> _open(NotificationItem item) async {
    await ref.read(notificationOpenedProvider.notifier).markOpened(item.id);

    if (!mounted || !item.hasRoute) return;
    await context.push(item.route);
  }
}

/// Bildirimler cihaz ayarlarından kapatılmışsa gösterilen şerit.
class _DisabledNotice extends StatelessWidget {
  const _DisabledNotice();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      FeedbackBanner(
        message: context.t('notification.disabled'),
        tone: FeedbackTone.error,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: NotificationService.instance.openSystemSettings,
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: Text(context.t('notification.openSettings')),
      ),
    ],
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.unread,
    required this.onTap,
  });

  final NotificationItem item;
  final bool unread;
  final VoidCallback onTap;

  ({IconData icon, Color color}) get _visual => switch (item.kind) {
    NotificationItemKind.announcement => (
      icon: Icons.campaign_outlined,
      color: BrandColors.info,
    ),
    NotificationItemKind.upcoming => (
      icon: Icons.schedule_rounded,
      color: BrandColors.red,
    ),
    NotificationItemKind.started => (
      icon: Icons.play_circle_outline,
      color: BrandColors.success,
    ),
    NotificationItemKind.deadline => (
      icon: Icons.event_busy_outlined,
      color: BrandColors.muted,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final ({Color color, IconData icon}) visual = _visual;

    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? visual.color.withValues(alpha: 0.5)
                  : context.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icon, size: 20, color: visual.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: BrandColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            formatNotificationTime(item.atMs, context.lang),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.inkMuted,
                            ),
                          ),
                        ),
                        // Yalnızca bir yere götüren bildirimlerde: dokunanın
                        // ne bekleyeceği kartın kendisinden okunsun.
                        if (item.hasRoute)
                          Row(
                            children: <Widget>[
                              Text(
                                context.t('notification.openTarget'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.brandInk,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: context.brandInk,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "3 saat önce" / "12 Ağustos 14:30" biçimi.
///
/// Bir günden yeni bildirimlerde göreli süre daha okunaklı; eskilerde tam
/// tarih gerekiyor.
String formatNotificationTime(int atMs, String language) {
  if (atMs <= 0) return '';

  final DateTime at = DateTime.fromMillisecondsSinceEpoch(atMs);
  final Duration diff = DateTime.now().difference(at);
  final bool en = language == 'en';

  if (diff.isNegative) {
    // İleri tarihli (saat farkı / cihaz saati); tam tarih yazmak yeterli.
    return DateFormat('dd MMMM HH:mm', en ? 'en_US' : 'tr_TR').format(at);
  }
  if (diff.inMinutes < 1) return en ? 'Just now' : 'Az önce';
  if (diff.inMinutes < 60) {
    return en ? '${diff.inMinutes} min ago' : '${diff.inMinutes} dakika önce';
  }
  if (diff.inHours < 24) {
    return en ? '${diff.inHours} h ago' : '${diff.inHours} saat önce';
  }
  if (diff.inDays < 7) {
    return en ? '${diff.inDays} d ago' : '${diff.inDays} gün önce';
  }

  return DateFormat('dd MMMM HH:mm', en ? 'en_US' : 'tr_TR').format(at);
}
