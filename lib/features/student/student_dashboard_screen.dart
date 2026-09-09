import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_utils.dart';
import '../../domain/paid_event_consent.dart';
import '../../domain/registration_capacity.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import 'student_providers.dart';
import 'student_shell.dart';

/// dashboard.html + js/pages/dashboard.js karşılığı — etkinlik keşfi.
class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({
    this.openEventId,
    this.externalQrToken,
    super.key,
  });

  /// Dış QR rotası giriş/onboarding sonrasında bu etkinlik penceresini açar.
  final String? openEventId;

  /// Öğrenci zaten kayıtlıysa detay penceresi açıldıktan sonra bu QR token'ı
  /// kameraya yeniden okutulmadan işlenir.
  final String? externalQrToken;

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  String? _autoOpenedKey;

  void _openRequestedEvent(
    BuildContext context,
    List<AppEvent> events,
    AppEvent? directEvent,
  ) {
    final String? eventId = widget.openEventId;
    if (eventId == null || eventId.isEmpty) return;

    AppEvent? event = directEvent;
    for (final AppEvent item in events) {
      if (item.id == eventId) {
        event = item;
        break;
      }
    }
    final AppEvent? targetEvent = event;
    if (targetEvent == null) return;

    final String key = '$eventId:${widget.externalQrToken ?? ''}';
    if (_autoOpenedKey == key) return;
    _autoOpenedKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openEventSheet(
        context,
        ref,
        targetEvent,
        externalQrToken: widget.externalQrToken,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    final AsyncValue<List<AppEvent>> events = ref.watch(
      studentVisibleEventsProvider,
    );
    final Set<String> registeredIds = ref.watch(registeredEventIdsProvider);
    final String? requestedEventId = widget.openEventId;
    final AppEvent? directEvent =
        requestedEventId == null || requestedEventId.isEmpty
        ? null
        : ref.watch(eventByIdProvider(requestedEventId)).value;

    final String name = _welcomeName(context, session);

    return Scaffold(
      appBar: StudentAppBar(
        title: context.t('dashboard.welcome', <String, Object?>{'name': name}),
        subtitle: context.t('dashboard.drawer.events'),
      ),
      body: RefreshIndicator(
        color: BrandColors.red,
        onRefresh: () async => ref.invalidate(studentVisibleEventsProvider),
        child: events.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace _) => ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              FeedbackBanner(
                message: context.t('dashboard.errors.register.generic'),
                tone: FeedbackTone.error,
              ),
            ],
          ),
          data: (List<AppEvent> list) {
            // Hedef kitle listesinde görünmese bile kodu gerçekten okutmuş
            // giriş yapmış kullanıcı etkinliğin detayını görür; kayıt yetkisi
            // yine RegistrationService + Firestore kurallarıyla doğrulanır.
            _openRequestedEvent(context, list, directEvent);
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  EmptyState(
                    message:
                        '${context.t('dashboard.empty.title')}\n${context.t('dashboard.empty.desc')}',
                    icon: Icons.event_busy_outlined,
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (BuildContext context, int index) {
                final AppEvent event = list[index];
                return _EventCard(
                  event: event,
                  priority: getStudentEventPriority(
                    event,
                    session.studentProfile,
                  ),
                  isRegistered: registeredIds.contains(event.id),
                  onTap: () => _openEventSheet(context, ref, event),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _welcomeName(BuildContext context, Session session) {
    final String first = session.studentProfile?.firstName ?? '';
    if (first.isNotEmpty) return first;

    final String displayName = session.appUser?.displayName ?? '';
    if (displayName.isNotEmpty) return displayName.split(' ').first;

    final String email = session.user?.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;

    return context.t('dashboard.userFallback');
  }
}

/// dashboard.js#getPriorityLabel
String priorityLabel(BuildContext context, int priority) => switch (priority) {
  0 => context.t('dashboard.priority.departmentUniversity'),
  1 => context.t('dashboard.priority.university'),
  2 => context.t('dashboard.priority.departmentRelated'),
  _ => context.t('dashboard.priority.general'),
};

/// dashboard.js#getScopeLabel
String scopeLabel(BuildContext context, String targetScope) =>
    switch (targetScope) {
      'university_department' => context.t('dashboard.scope.department'),
      'department' => context.t('dashboard.scope.departmentOnly'),
      'university' => context.t('dashboard.scope.university'),
      _ => context.t('dashboard.scope.all'),
    };

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.priority,
    required this.isRegistered,
    required this.onTap,
  });

  final AppEvent event;
  final int priority;
  final bool isRegistered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool closed = isRegistrationClosed(event);

    final (String label, FeedbackTone tone) = closed
        ? (context.t('dashboard.status.expired'), FeedbackTone.error)
        : isRegistered
        ? (context.t('dashboard.status.registered'), FeedbackTone.success)
        : (context.t('dashboard.status.open'), FeedbackTone.info);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            EventImage(url: event.displayImageUrl),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(label: label, tone: tone),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.groups_outlined,
                    text: event.clubName.isNotEmpty
                        ? event.clubName
                        : context.t('dashboard.clubFallback'),
                  ),
                  _MetaRow(
                    icon: Icons.calendar_today_outlined,
                    text: formatDeadline(
                      event.deadlineAtMs,
                      locale: context.lang,
                    ),
                  ),
                  if (event.locationName.isNotEmpty)
                    _MetaRow(
                      icon: Icons.place_outlined,
                      text: event.locationName,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      StatusPill(label: scopeLabel(context, event.targetScope)),
                      StatusPill(label: priorityLabel(context, priority)),
                      if (event.isMultiSession)
                        StatusPill(
                          label: context.t(
                            'eventModal.sessionsValue',
                            <String, Object?>{'count': event.sessionCount},
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 14, color: context.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Detay penceresinin ekran kenarlarından payı ve köşe yarıçapı.
const double _kSheetSideInset = 10;
const double _kSheetRadius = 28;

/// Sabit eylem şeridinin listeden ayırması gereken dikey alan.
const double _kActionBarSpace = 96;

/// Etkinlik detay penceresi + kayıt/kayıt iptali
/// (dashboard.js#openEventModal, registerToSelectedEvent, unregisterFromSelectedEvent).
void _openEventSheet(
  BuildContext context,
  WidgetRef ref,
  AppEvent event, {
  String? externalQrToken,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Yüzey/köşe pencerenin kendi kartında: kart alt çubuğun QR düğmesinin
    // üstünde bittiği için sayfanın zemini ekranın en altına yapışmamalı.
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) =>
        _EventDetailSheet(event: event, externalQrToken: externalQrToken),
  );
}

class _EventDetailSheet extends ConsumerStatefulWidget {
  const _EventDetailSheet({required this.event, this.externalQrToken});

  final AppEvent event;
  final String? externalQrToken;

  @override
  ConsumerState<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<_EventDetailSheet> {
  bool _busy = false;

  bool _externalCheckinQueued = false;

  /// Kayıt çekişmeye takılıp beklemeye geçti mi?
  ///
  /// Kontenjanı korumak için kayıtlar bölük bölük alınıyor: sırası gelmeyen
  /// istek kısa bir süre bekleyip yeniden deniyor. Bu süre birkaç saniyeyi
  /// bulabildiği için düğmenin sessizce donması yanlış olurdu — kullanıcı
  /// işlemin sürdüğünü görmeli.
  bool _queued = false;

  /// Dış QR açıldığında etkinlik penceresi önce görünür. Öğrenci zaten
  /// kayıtlıysa güvenlik kontrollerini tek yerde tutmak için mevcut tarama
  /// ekranını token'la açar; MobileScanner yeni kamera verisi beklemez.
  void _queueExternalQrCheckin(AppEvent event, bool isRegistered) {
    final String? token = widget.externalQrToken;
    if (_externalCheckinQueued || !isRegistered || token == null) return;

    final Map<String, dynamic>? payload = parseCheckinQrToken(token);
    final String type = '${payload?['type'] ?? ''}';
    if (payload == null ||
        '${payload['eventId'] ?? ''}' != event.id ||
        (type != 'event-entry' && type != 'session-checkin')) {
      return;
    }
    _externalCheckinQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Pencerenin açıldığını kullanıcı görsün; sonra aynı doğrulama yoluna
      // geçilir. Bu bekleme güvenlik penceresi değildir, yalnızca UX içindir.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;

      final GoRouter router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go(
        Uri(
          path: Routes.studentQrCheckin,
          queryParameters: <String, String>{
            'eventId': event.id,
            'payload': token,
          },
        ).toString(),
      );
    });
  }

  Future<void> _register() async {
    if (_busy) return;
    final Session session = ref.read(sessionProvider);
    final String? uid = session.user?.uid;
    if (uid == null) return;

    setState(() => _busy = true);

    try {
      // Kayıt öncesi etkinliği SUNUCUDAN tazele: önbellekteki "kayıt açık"
      // durumuna güvenilmez (dashboard.js `getDocFromServer` kullanıyordu).
      final AppEvent? latest = await ref
          .read(eventRepositoryProvider)
          .fetchEventFromServer(widget.event.id);

      if (!mounted) return;

      if (latest == null) {
        _toast(context.t('dashboard.alerts.eventNotFound'));
        Navigator.of(context).pop();
        return;
      }
      if (latest.hiddenGlobally) {
        _toast(context.t('dashboard.alerts.eventHidden'));
        return;
      }
      if (latest.clubId.isEmpty) {
        _toast(context.t('dashboard.alerts.missingClubId'));
        return;
      }
      if (isRegistrationClosed(latest)) {
        ref.invalidate(studentVisibleEventsProvider);
        _toast(context.t('dashboard.alerts.registrationClosed'));
        return;
      }

      // Ücretli etkinlikte onay, kayıt Firestore'a yazılmadan hemen önce
      // alınır. Pencere kapatılır ya da kutu işaretlenmezse kayıt yapılmaz.
      final PaidEventConsentAcceptance? paidEventConsent = latest.isPaid
          ? await showPaidEventStudentRegistrationConsentDialog(context)
          : null;
      if ((latest.isPaid && paidEventConsent == null) || !mounted) return;

      final StudentProfile? profile = session.studentProfile;

      // Kontenjanı koruyan yol: kayıt ile sayaç aynı transaction'da yazılır,
      // çekişme olursa jitter'lı bekleyişle yeniden denenir. Bu yüzden çağrı
      // saniyeler sürebilir — düğme `_busy` ile zaten kilitli.
      final RegistrationResult result = await ref
          .read(registrationServiceProvider)
          .register(
            event: latest,
            studentId: uid,
            studentEmail: session.user?.email ?? '',
            profile: profile,
            displayName: _displayName(session),
            eventFallbackTitle: context.t('dashboard.eventFallback'),
            clubFallbackName: context.t('dashboard.clubFallback'),
            paidEventConsent: paidEventConsent,
            onWaiting: (int round) {
              if (!mounted || _queued) return;
              setState(() => _queued = true);
              _toast(context.t('dashboard.alerts.registerBusy'));
            },
          );

      if (!mounted) return;
      if (_queued) setState(() => _queued = false);

      // Kayıt olmayan sonuçlarda da listeyi tazeliyoruz: kontenjan dolduysa
      // etkinliğin kartı bunu göstermeli.
      ref.invalidate(studentVisibleEventsProvider);

      _toast(switch (result.outcome) {
        RegistrationOutcome.registered => context.t(
          'dashboard.alerts.registerSuccess',
        ),
        RegistrationOutcome.alreadyRegistered => context.t(
          'dashboard.alerts.alreadyRegistered',
        ),
        RegistrationOutcome.quotaFull => context.t(
          'dashboard.alerts.quotaFull',
        ),
        RegistrationOutcome.closed => context.t(
          'dashboard.alerts.registrationClosed',
        ),
        RegistrationOutcome.notFound => context.t(
          'dashboard.alerts.eventNotFound',
        ),
        RegistrationOutcome.notEligible => context.t(
          'dashboard.errors.register.permissionDenied',
        ),
        RegistrationOutcome.retryExhausted => context.t(
          'dashboard.errors.register.retryExhausted',
        ),
        RegistrationOutcome.unavailable => context.t(
          'dashboard.errors.register.unavailable',
        ),
      });

      // Ücretli etkinlikte ödeme uygulama dışında: kayıt alındıktan sonra
      // öğrenciye kulübün iletişim bilgilerini ve "ücret için kulüple
      // görüşün" notunu bir kez daha gösteriyoruz. Zaten kayıtlıysa da
      // gösteriyoruz; bilgiye tekrar ulaşmak isteyen için tek yol bu.
      if (latest.isPaid &&
          (result.outcome == RegistrationOutcome.registered ||
              result.outcome == RegistrationOutcome.alreadyRegistered)) {
        await showPaidEventContactDialog(context, latest);
      }
    } catch (error) {
      if (!mounted) return;
      _toast(_registerError(error));
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _queued = false;
        });
    }
  }

  Future<void> _unregister() async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;

    setState(() => _busy = true);

    try {
      // Kaydı silmek kontenjanda yer AÇAR: silme ile sayaç azaltması aynı
      // transaction'da olmalı, yoksa kontenjan sızar.
      await ref
          .read(registrationServiceProvider)
          .unregister(eventId: widget.event.id, studentId: uid);

      if (!mounted) return;
      ref.invalidate(studentVisibleEventsProvider);
      _toast(context.t('dashboard.alerts.unregisterSuccess'));
    } catch (error) {
      if (!mounted) return;
      _toast(context.t('dashboard.errors.unregister.generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _displayName(Session session) {
    final String full = session.studentProfile?.fullName ?? '';
    if (full.isNotEmpty) return full;

    final String displayName = session.user?.displayName ?? '';
    if (displayName.isNotEmpty) return displayName;

    final String email = session.user?.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;

    return context.t('dashboard.studentFallback');
  }

  /// dashboard.js#getRegisterErrorMessage
  String _registerError(Object error) {
    final String code = error is Exception ? _firestoreCode(error) : '';

    return switch (code) {
      'permission-denied' => context.t(
        'dashboard.errors.register.permissionDenied',
      ),
      'failed-precondition' => context.t(
        'dashboard.errors.register.failedPrecondition',
      ),
      'unavailable' => context.t('dashboard.errors.register.unavailable'),
      'not-found' => context.t('dashboard.errors.register.notFound'),
      '' => context.t('dashboard.errors.register.generic'),
      _ => context.t('dashboard.errors.register.generic'),
    };
  }

  String _firestoreCode(Object error) {
    final String text = '$error';
    final Match? match = RegExp(
      r'\[cloud_firestore/([\w-]+)\]',
    ).firstMatch(text);
    return match?.group(1) ?? '';
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// Hedef kitle satırı: kapsam etiketi + varsa üniversite/bölüm kırılımı.
  String _audience(BuildContext context, AppEvent event) {
    // Bölüm hedeflenmemişse alan olarak kulübün kendi alanları yazılır.
    final List<String> parts = <String>[
      scopeLabel(context, event.targetScope),
      ...event.targetUniversities,
      ...eventAudienceFields(event),
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    // Liste tek seferlik okunmuş olabilir. Detay penceresi açıkken etkinlik
    // veya etkinliğe kopyalanan kulüp bilgileri değişirse canlı dokümanı
    // kullan; dinleyicinin ilk karesine kadar mevcut nesne geri dönüş olsun.
    final AppEvent event =
        ref.watch(eventByIdProvider(widget.event.id)).value ?? widget.event;
    final Session session = ref.watch(sessionProvider);
    final bool isRegistered = ref
        .watch(registeredEventIdsProvider)
        .contains(event.id);
    final bool closed = isRegistrationClosed(event);
    final int priority = getStudentEventPriority(event, session.studentProfile);

    _queueExternalQrCheckin(event, isRegistered);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) => Padding(
        // Alt çubuğun QR düğmesi gövdenin üzerine taştığı için pencere ekranın
        // en altına değil, QR'ın hemen üstünde biten yüzen bir kart olarak
        // oturur; yoksa "Kaydol" düğmesi QR'ın altında kalıyordu.
        padding: const EdgeInsets.fromLTRB(
          _kSheetSideInset,
          0,
          _kSheetSideInset,
          kStudentQrOverhang + 14,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(_kSheetRadius),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x38000000),
                blurRadius: 30,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kSheetRadius),
            // Liste düğmenin ARKASINDAN akar: düğme sabit dursun diye ayrı bir
            // bölme açmak, onu pencereden kopuk gösteriyordu.
            child: Stack(
              children: <Widget>[
                ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: _kActionBarSpace),
                  children: <Widget>[
                    // ── Başlık görseli + kapatma ────────────────────────────
                    Stack(
                      children: <Widget>[
                        EventImage(url: event.displayImageUrl, height: 200),
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: BrandColors.white.withValues(
                                  alpha: 0.75,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: const Color(0x8C000000),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(
                                  Icons.close,
                                  size: 19,
                                  color: BrandColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),

                          // Kulüp kimliği: adın hemen altında, kulübü kısa kısa
                          // anlatan baloncuklar (alan, üniversite, şehir).
                          const SizedBox(height: 14),
                          _ClubHeader(event: event),

                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              StatusPill(
                                label: closed
                                    ? context.t('dashboard.status.expired')
                                    : isRegistered
                                    ? context.t('dashboard.status.registered')
                                    : context.t('dashboard.status.open'),
                                tone: closed
                                    ? FeedbackTone.error
                                    : isRegistered
                                    ? FeedbackTone.success
                                    : FeedbackTone.info,
                              ),
                              StatusPill(
                                label: scopeLabel(context, event.targetScope),
                              ),
                              StatusPill(
                                label: priorityLabel(context, priority),
                              ),
                            ],
                          ),

                          // ── Etkinlik bilgileri (web'deki etiketli bilgi bloğu) ──
                          const SizedBox(height: 22),
                          _SectionTitle(context.t('eventModal.info')),
                          const SizedBox(height: 10),
                          _InfoTable(
                            rows:
                                <({IconData icon, String label, String value})>[
                                  (
                                    icon: Icons.calendar_today_outlined,
                                    label: context.t('eventModal.deadline'),
                                    value: formatDeadline(
                                      event.deadlineAtMs,
                                      locale: context.lang,
                                    ),
                                  ),
                                  (
                                    icon: Icons.payments_outlined,
                                    label: context.t('eventModal.fee'),
                                    value: event.feeInfo.isNotEmpty
                                        ? event.feeInfo
                                        : context.t('eventModal.free'),
                                  ),
                                  (
                                    icon: Icons.event_seat_outlined,
                                    label: context.t('eventModal.quota'),
                                    value: event.quota > 0
                                        ? '${event.quota}'
                                        : context.t('eventModal.unlimited'),
                                  ),
                                  if (event.locationName.isNotEmpty)
                                    (
                                      icon: Icons.place_outlined,
                                      label: context.t('eventModal.location'),
                                      value: event.locationName,
                                    ),
                                  if (event.isMultiSession)
                                    (
                                      icon: Icons.repeat,
                                      label: context.t('eventModal.sessions'),
                                      value: context.t(
                                        'eventModal.sessionsValue',
                                        <String, Object?>{
                                          'count': event.sessionCount,
                                        },
                                      ),
                                    ),
                                  (
                                    icon: Icons.public_outlined,
                                    label: context.t('eventModal.audience'),
                                    value: _audience(context, event),
                                  ),
                                ],
                          ),

                          // Ücretli etkinlik: pop-up kapandıktan sonra da
                          // kulüp iletişim bilgileri kaybolmasın diye burada
                          // kalıcı olarak da gösteriliyor.
                          if (event.isPaid) ...<Widget>[
                            const SizedBox(height: 22),
                            EventPaidContactBlock(event: event),
                          ],

                          // ── Açıklama ────────────────────────────────────────
                          const SizedBox(height: 22),
                          _SectionTitle(context.t('eventModal.description')),
                          const SizedBox(height: 8),
                          Text(
                            event.description.isNotEmpty
                                ? event.description
                                : context.t('dashboard.modal.noDescription'),
                            style: const TextStyle(height: 1.55),
                          ),

                          if (event.purpose.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 22),
                            _SectionTitle(context.t('eventModal.purpose')),
                            const SizedBox(height: 8),
                            Text(
                              event.purpose,
                              style: const TextStyle(height: 1.55),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Sabit eylem şeridi ───────────────────
                // Kaydırmayla yer değiştirmez; içerik altından geçerken yumuşak
                // bir geçişle silinir, böylece pencereden kopuk ayrı bir bölme
                // gibi durmaz.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _SheetActionBar(
                    busy: _busy,
                    queued: _queued,
                    closed: closed,
                    registered: isRegistered,
                    onRegister: _register,
                    onUnregister: _unregister,
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

/// Pencerenin dibinde duran eylem şeridi.
///
/// Zemini üstte saydamdan yüzey rengine akan bir gradyan: liste düğmenin
/// altından geçerken görünürlüğünü yitirir, keskin bir ayraç çizgisine gerek
/// kalmaz.
class _SheetActionBar extends StatelessWidget {
  const _SheetActionBar({
    required this.busy,
    required this.queued,
    required this.closed,
    required this.registered,
    required this.onRegister,
    required this.onUnregister,
  });

  final bool busy;
  final bool queued;
  final bool closed;
  final bool registered;
  final VoidCallback onRegister;
  final VoidCallback onUnregister;

  @override
  Widget build(BuildContext context) {
    final Color surface = context.surface;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            surface.withValues(alpha: 0),
            surface.withValues(alpha: 0.94),
            surface,
          ],
          stops: const <double>[0, 0.45, 0.72],
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _PrimaryAction(
              busy: busy,
              queued: queued,
              closed: closed,
              registered: registered,
              onPressed: onRegister,
            ),
          ),
          if (registered) ...<Widget>[
            const SizedBox(width: 10),
            // Expanded şart: temadaki `Size.fromHeight(48)` sonsuz genişlik
            // demek; Row'da esnek olmayan çocuk olarak bırakılırsa düzen
            // çöküyor (bkz. kulüp hesap ekranı).
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.danger,
                    side: const BorderSide(color: BrandColors.danger),
                    shape: const StadiumBorder(),
                    backgroundColor: surface,
                  ),
                  onPressed: busy ? null : onUnregister,
                  child: Text(
                    context.t('dashboard.actions.unregister'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kayıt düğmesi: kayıt açıkken marka gradyanı, kayıtlıyken yeşil onay,
/// süresi geçmişte sönük bir bilgi yüzeyi.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.busy,
    required this.queued,
    required this.closed,
    required this.registered,
    required this.onPressed,
  });

  final bool busy;

  /// Kayıt sıraya girdi: kontenjan sayacında çekişme var, kısa bir
  /// bekleyişten sonra yeniden denenecek.
  final bool queued;

  final bool closed;
  final bool registered;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !busy && !closed && !registered;

    final IconData icon = closed
        ? Icons.event_busy_outlined
        : registered
        ? Icons.verified_outlined
        : Icons.how_to_reg_outlined;

    final String label = closed
        ? context.t('dashboard.status.expired')
        : registered
        ? context.t('dashboard.actions.registered')
        : context.t('dashboard.actions.register');

    final Color foreground = closed
        ? context.inkMuted
        : registered
        ? BrandColors.success
        : BrandColors.white;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: enabled ? BrandColors.gradient : null,
            color: closed
                ? context.subtleFill
                : registered
                ? BrandColors.success.withValues(
                    alpha: context.isDarkMode ? 0.20 : 0.12,
                  )
                : null,
            borderRadius: BorderRadius.circular(BrandShape.pillRadius),
            border: registered
                ? Border.all(color: BrandColors.success.withValues(alpha: 0.45))
                : null,
            boxShadow: enabled ? BrandShape.raised : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(BrandShape.pillRadius),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BrandColors.white,
                          ),
                        ),
                        // Kayıtlar yoğunlukta bölük bölük alınıyor; sıra
                        // beklerken dönen çember tek başına "takıldı"
                        // izlenimi veriyordu.
                        if (queued) ...<Widget>[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              context.t('dashboard.status.inQueue'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(icon, size: 19, color: foreground),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etkinliği düzenleyen kulübün kimlik kartı.
///
/// Ad tek başına kulübün ne yaptığını anlatmıyor; adın hemen altındaki
/// baloncuklar (alan, üniversite) öğrencinin kulübü bir bakışta
/// tanımasını sağlıyor.
class _ClubHeader extends StatelessWidget {
  const _ClubHeader({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final String name = event.clubName.isNotEmpty
        ? event.clubName
        : context.t('dashboard.clubFallback');

    // Kulübün TÜM alanları gösterilir: çok alanlı bir kulüpte yalnızca ilk
    // alanı yazmak kulübü olduğundan dar gösteriyordu.
    final List<String> facts = <String>[
      ...eventClubFields(event),
      if (event.clubUniversity.isNotEmpty) event.clubUniversity,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: BrandColors.gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.groups_outlined,
            color: BrandColors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
              if (facts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final String fact in facts) _ClubBubble(text: fact),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kulüp bilgisi baloncuğu — kırmızının en soluk tonunda, kısa metin.
class _ClubBubble extends StatelessWidget {
  const _ClubBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.red.withValues(
          alpha: context.isDarkMode ? 0.18 : 0.09,
        ),
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: context.brandInk,
        ),
      ),
    );
  }
}

/// Modal içindeki bölüm başlığı — solunda kısa bir marka çubuğu.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Container(
        width: 3,
        height: 15,
        decoration: BoxDecoration(
          color: BrandColors.red,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: context.ink,
        ),
      ),
    ],
  );
}

/// Etiket/değer çiftlerinden oluşan bilgi bloğu (web'deki detay tablosu).
class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final List<({IconData icon, String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.hairline.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(rows[i].icon, size: 16, color: context.inkMuted),
                  const SizedBox(width: 9),
                  Text(
                    rows[i].label,
                    style: TextStyle(fontSize: 13, color: context.inkMuted),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
