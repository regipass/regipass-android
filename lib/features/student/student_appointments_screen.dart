import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../domain/event_feedback.dart';
import '../../domain/event_utils.dart';
import '../../l10n/app_strings.dart';
import '../../services/event_feedback_service.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart' show EventMetaRow;
import 'appointment_detail_sheet.dart';
import 'student_providers.dart';
import 'student_shell.dart';

/// student-appointments.html + js/pages/student-appointments.js karşılığı.
///
/// Aktif ve geçmiş kayıtlar iki bölüme ayrılır. Seçim, üst çubuğun parçası
/// olan bir sekme şeridi yerine listenin üstünde duran iki yuvarlak düğmeyle
/// yapılır: böylece üst çubuk her ekranda aynı kalır ve seçim marka rengiyle
/// içerik alanında vurgulanır.
class StudentAppointmentsScreen extends ConsumerStatefulWidget {
  const StudentAppointmentsScreen({
    this.openRegistrationId,
    this.feedbackEventId,
    super.key,
  });

  /// Açılır açılmaz detay penceresi gösterilecek kaydın kimliği
  /// (`/student/appointments?open=...`). QR okutma ekranı, giriş onaylandıktan
  /// sonra öğrenciyi buraya bu parametreyle döndürür.
  final String? openRegistrationId;

  /// İP-D: değerlendirme bildiriminden gelindi (`?feedbackEventId=...`):
  /// o etkinliğin penceresi değerlendirme formu açık gelir.
  final String? feedbackEventId;

  @override
  ConsumerState<StudentAppointmentsScreen> createState() =>
      _StudentAppointmentsScreenState();
}

class _StudentAppointmentsScreenState
    extends ConsumerState<StudentAppointmentsScreen> {
  bool _showPast = false;

  /// Pencerenin aynı parametre için ikinci kez açılmasını engeller: kullanıcı
  /// pencereyi kapattığında ekran yeniden kurulur ve parametre hâlâ URL'de
  /// durur.
  String? _autoOpened;

  /// Kayıtlar geldiğinde istenen pencereyi bir kez açar.
  ///
  /// `initState` yeterli değil: kayıt listesi asenkron gelir ve pencere,
  /// içeriğini bu listeden okur.
  void _openRequestedSheet(List<RegistrationWithEvent> items) {
    final String? feedbackEventId = widget.feedbackEventId;
    final bool forFeedback =
        feedbackEventId != null && feedbackEventId.isNotEmpty;
    final String? target = forFeedback
        ? 'feedback:$feedbackEventId'
        : widget.openRegistrationId;
    if (target == null || target.isEmpty || _autoOpened == target) return;

    RegistrationWithEvent? match;
    for (final RegistrationWithEvent item in items) {
      if (forFeedback
          ? item.registration.eventId == feedbackEventId
          : item.registration.id == target) {
        match = item;
      }
    }
    if (match == null) return;
    final String registrationId = match.registration.id;

    _autoOpened = target;
    final bool closed = match.isClosed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Pencere kapanınca kaydın durduğu sekme açık kalsın.
      if (_showPast != closed) setState(() => _showPast = closed);
      showAppointmentSheet(
        context,
        registrationId: registrationId,
        focusFeedback: forFeedback,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RegistrationWithEvent>> items = ref.watch(
      appointmentsProvider,
    );

    return ReadableScaffold(
      appBar: StudentAppBar(title: context.t('studentAppointments.title')),
      body: items.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('studentAppointments.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<RegistrationWithEvent> list) {
          _openRequestedSheet(list);

          final List<RegistrationWithEvent> active = list
              .where((RegistrationWithEvent item) => !item.isClosed)
              .toList();
          final List<RegistrationWithEvent> past = list
              .where((RegistrationWithEvent item) => item.isClosed)
              .toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  context.t('studentAppointments.hero.subtitle'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.inkMuted,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.subtleFill,
                  borderRadius: BorderRadius.circular(BrandShape.pillRadius),
                  border: Border.all(color: context.hairline),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _SegmentButton(
                        label: context.t('studentAppointments.activeTitle'),
                        count: active.length,
                        selected: !_showPast,
                        onTap: () => setState(() => _showPast = false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _SegmentButton(
                        label: context.t('studentAppointments.pastTitle'),
                        count: past.length,
                        selected: _showPast,
                        onTap: () => setState(() => _showPast = true),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _showPast
                    ? _AppointmentList(
                        items: past,
                        emptyMessage: context.t(
                          'studentAppointments.empty.past',
                        ),
                      )
                    : _AppointmentList(
                        items: active,
                        emptyMessage: context.t(
                          'studentAppointments.empty.active',
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Aktif / geçmiş seçimi (web'deki bölümlü seçici): seçili bölüm beyaz
/// hapla öne çıkar, sayaç kırmızı rozette durur.
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      elevation: selected ? 1 : 0,
      shadowColor: const Color(0x330F172A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? context.ink : context.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? BrandColors.red : context.hairline,
                    borderRadius: BorderRadius.circular(BrandShape.pillRadius),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? BrandColors.white : context.inkBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({required this.items, required this.emptyMessage});

  final List<RegistrationWithEvent> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[EmptyState(message: emptyMessage)],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) =>
          AppointmentCard(item: items[index]),
    );
  }
}

/// student-appointments.js#createAppointmentCard karşılığı.
/// [autoGenerateQr] QR Oluştur sekmesinde true verilir.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    required this.item,
    this.autoGenerateQr = false,
    super.key,
  });

  final RegistrationWithEvent item;
  final bool autoGenerateQr;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAppointmentSheet(
          context,
          registrationId: item.registration.id,
          autoGenerateQr: autoGenerateQr,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                child: SizedBox(
                  width: 104,
                  child: _PodcastEventCover(
                    imageUrl: item.imageUrl,
                    closed: item.isClosed,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      EventMetaRow(
                        icon: Icons.groups_2_outlined,
                        text: item.clubName,
                      ),
                      EventMetaRow(
                        icon: Icons.event_available_outlined,
                        text: context.t(
                          'studentAppointments.card.deadline',
                          <String, Object?>{
                            'deadline': formatDeadline(
                              item.deadlineAtMs,
                              locale: context.lang,
                            ),
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          StatusPill(
                            label: context.t(item.statusBadge.key),
                            tone: switch (item.statusBadge.tone) {
                              -1 => FeedbackTone.error,
                              0 => FeedbackTone.warning,
                              _ => FeedbackTone.success,
                            },
                          ),
                          if (item.isMultiSession)
                            StatusPill(
                              label:
                                  '${item.registration.sessionsAttended}/${item.sessionCount}',
                              tone: item.hasEarnedCertificate
                                  ? FeedbackTone.success
                                  : FeedbackTone.info,
                            ),
                          // İP-D: "Değerlendir" ya da verilen yıldızlar.
                          _FeedbackBadge(item: item),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartta değerlendirme durumu (İP-D).
class _FeedbackBadge extends ConsumerWidget {
  const _FeedbackBadge({required this.item});

  final RegistrationWithEvent item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MyFeedback? mine = ref
        .watch(myFeedbackProvider)
        .value?[item.registration.eventId];
    final FeedbackWindow window = feedbackWindowFor(
      item.event,
      item.registration,
      DateTime.now().millisecondsSinceEpoch,
    );
    return switch (feedbackBadge(window, mine)) {
      FeedbackBadge.rate => StatusPill(
        label: '★ ${context.t('feedback.cardRate')}',
        tone: FeedbackTone.warning,
      ),
      FeedbackBadge.rated => Text(
        starText(mine!.rating),
        style: const TextStyle(color: Color(0xFFF59E0B), letterSpacing: 1.5),
      ),
      FeedbackBadge.none => const SizedBox.shrink(),
    };
  }
}

/// Podcast kapaklarını andıran etkinlik görseli.
///
/// Kenarlar düzgün yuvarlatılmış bir kare: önceki dalgalı kesim yolu üst
/// kenarın ortasını içeri çekiyordu ve fotoğrafta göçük varmış gibi
/// duruyordu. Üstteki ince renk katmanı farklı fotoğrafları ortak bir görsel
/// ritimde tutar; rengi etkinliğin durumunu söyler — devam edenlerde yeşil,
/// süresi geçenlerde kırmızı.
class _PodcastEventCover extends StatelessWidget {
  const _PodcastEventCover({required this.imageUrl, required this.closed});

  final String imageUrl;

  /// Süresi geçmiş / kaydı kapanmış etkinlik.
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final Color tint = closed ? BrandColors.maroon : BrandColors.success;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Görsel, kart metni uzadığında da sol çerçevenin tamamını
            // `cover` ile doldurur; sabit 108 px yüksekliği boşluk bırakmaz.
            Positioned.fill(child: EventImage(url: imageUrl, height: 108)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    BrandColors.black.withValues(alpha: 0.07),
                    tint.withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                margin: const EdgeInsets.all(9),
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: BrandColors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 15,
                  color: closed ? BrandColors.redDark : BrandColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
