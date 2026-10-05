import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../domain/checkin_qr.dart';
import '../../domain/event_utils.dart';
import '../../domain/paid_event_consent.dart';
import '../../domain/registration_capacity.dart';
import '../../domain/registration_state.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../../domain/club_follow.dart';
import '../../domain/event_complaint.dart';
import '../../services/club_follow_service.dart';
import '../../services/event_complaint_service.dart';
import '../shared/add_to_calendar_button.dart';
import '../shared/club_follow_button.dart';
import '../shared/common_widgets.dart';
import '../shared/event_complaint_section.dart';
import '../shared/event_link_widgets.dart';
import '../shared/event_widgets.dart';
import 'post_registration_sheet.dart';
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
    final Map<String, EventRegistration> registrationsByEvent = ref.watch(
      registrationByEventProvider,
    );
    final Set<String> waitlistedIds =
        ref.watch(waitlistedEventIdsProvider).value ?? const <String>{};
    final String? requestedEventId = widget.openEventId;
    final AppEvent? directEvent =
        requestedEventId == null || requestedEventId.isEmpty
        ? null
        : ref.watch(eventByIdProvider(requestedEventId)).value;

    final String name = _welcomeName(context, session);
    final FollowFilter followFilter = ref.watch(followFilterProvider);
    final Set<String> followedIds =
        ref.watch(followedClubIdsProvider).value ?? const <String>{};
    // İP-ŞK: engellenen organizatörlerin etkinlikleri gösterilmez.
    final Set<String> blockedIds =
        ref.watch(blockedOrganizerIdsProvider).value ?? const <String>{};

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
          data: (List<AppEvent> all) {
            // Hedef kitle listesinde görünmese bile kodu gerçekten okutmuş
            // giriş yapmış kullanıcı etkinliğin detayını görür; kayıt yetkisi
            // yine RegistrationService + Firestore kurallarıyla doğrulanır.
            _openRequestedEvent(context, all, directEvent);
            // İP-TK: "Tümü | Takip ettiklerim".
            // Takip edilen kulüplerin etkinlikleri +60 puanla yeniden sıralanır
            // (web ile aynı keşif puanı; bkz. getStudentEventScore).
            final List<AppEvent> list = sortEventsForStudent(
              filterByFollow<AppEvent>(
                hideBlockedOrganizers<AppEvent>(
                  all,
                  blockedIds,
                  (AppEvent e) => e.clubId,
                ),
                followFilter,
                followedIds,
                (AppEvent e) => e.clubId,
              ),
              session.studentProfile,
              followedClubIds: followedIds,
            );
            final Widget filterBar = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PageHeader(
                  title: context.t('dashboard.hero.title'),
                  subtitle: context.t('dashboard.hero.subtitle'),
                  center: true,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                ),
                _FollowFilterBar(
                  value: followFilter,
                  onChanged: (FollowFilter f) =>
                      ref.read(followFilterProvider.notifier).select(f),
                ),
              ],
            );
            if (list.isEmpty) {
              final bool following = followFilter == FollowFilter.following;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  filterBar,
                  const SizedBox(height: 14),
                  EmptyState(
                    message: following
                        ? '${context.t('follow.empty.title')}\n${context.t('follow.empty.desc')}'
                        : '${context.t('dashboard.empty.title')}\n${context.t('dashboard.empty.desc')}',
                    icon: following
                        ? Icons.group_add_outlined
                        : Icons.event_busy_outlined,
                  ),
                ],
              );
            }

            // İP-T2: tablette 2–3 sütun.
            return AdaptiveCardList(
              header: filterBar,
              itemCount: list.length,
              itemBuilder: (BuildContext context, int index) {
                final AppEvent event = list[index];
                return _EventCard(
                  event: event,
                  // -1: takip edilen kulüp (kartta "Takip ettiğin kulüp").
                  priority: followedIds.contains(event.clubId)
                      ? -1
                      : getStudentEventPriority(event, session.studentProfile),
                  view: studentRegistrationView(
                    event: event,
                    registered: registeredIds.contains(event.id),
                    paymentPending:
                        registrationsByEvent[event.id]?.paymentPendingFor(
                          event,
                        ) ??
                        false,
                    waitlisted: waitlistedIds.contains(event.id),
                  ),
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

/// Keşfet filtresi (İP-TK) — web: dashboard.html #discoverFilter.
class _FollowFilterBar extends StatelessWidget {
  const _FollowFilterBar({required this.value, required this.onChanged});

  final FollowFilter value;
  final ValueChanged<FollowFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<FollowFilter>(
        key: const ValueKey<String>('follow-filter'),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: context.brandTint,
          selectedForegroundColor: context.brandInk,
        ),
        segments: <ButtonSegment<FollowFilter>>[
          ButtonSegment<FollowFilter>(
            value: FollowFilter.all,
            label: Text(context.t('follow.filterAll')),
          ),
          ButtonSegment<FollowFilter>(
            value: FollowFilter.following,
            icon: const Icon(Icons.favorite_border, size: 16),
            label: Text(context.t('follow.filterFollowing')),
          ),
        ],
        selected: <FollowFilter>{value},
        onSelectionChanged: (Set<FollowFilter> s) => onChanged(s.first),
      ),
    );
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
      TargetScope.universityDepartment => context.t('dashboard.scope.department'),
      'department' => context.t('dashboard.scope.departmentOnly'),
      'university' => context.t('dashboard.scope.university'),
      _ => context.t('dashboard.scope.all'),
    };

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.priority,
    required this.view,
    required this.onTap,
  });

  final AppEvent event;
  final int priority;

  /// İP-K: kayıtlı / ödeme bekleniyor / bekleme listesi / dolu / açık.
  final StudentRegistrationView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => EventSummaryCard(
    event: event,
    priority: priority,
    statusOverride: (
      label: context.t(view.statusKey),
      tone: feedbackToneFor(view.statusTone),
    ),
    onTap: onTap,
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

      // İP-B4b: üniversite/bölüme özel etkinlikte profilde bu bilgi yoksa
      // (ör. linkten hesap açan kişi) reddetmek yerine sorulur ve profile
      // yazılır. Web: event-link.js; sunucu yine kendi denetler.
      if (!await _fillScopeFieldsIfMissing(latest) || !mounted) return;

      // Ücretli etkinlikte onay, kayıt Firestore'a yazılmadan hemen önce
      // alınır. Pencere kapatılır ya da kutu işaretlenmezse kayıt yapılmaz.
      final PaidEventConsentAcceptance? paidEventConsent = latest.isPaid
          ? await showPaidEventStudentRegistrationConsentDialog(context)
          : null;
      if ((latest.isPaid && paidEventConsent == null) || !mounted) return;

      // İP-K: kayıt sunucuda (registerForEvent). Kontenjan, son başvuru,
      // engel ve hedef kitle orada denetlenir; sunucu yoğunsa servis kısa
      // bekleyişlerle yeniden dener.
      final RegistrationResult result = await ref
          .read(registrationServiceProvider)
          .register(
            event: latest,
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

      // Kontenjan doldu: bekleme listesi önerilir.
      if (result.outcome == RegistrationOutcome.quotaFull) {
        final bool join = await _confirm(
          context.t('registration.alerts.fullOfferWaitlist'),
          confirmKey: 'registration.actions.joinWaitlist',
        );
        if (join && mounted) await _joinWaitlist(skipBusy: true);
        return;
      }

      // İP-T2: başarılı kayıtta "takvime ekleyelim mi / bileti kaydet".
      if (result.outcome == RegistrationOutcome.registered &&
          !await postRegistrationSkipped() &&
          mounted) {
        await showPostRegistrationSheet(
          context,
          event: latest,
          message: result.paymentPending
              ? '${context.t('dashboard.alerts.registerSuccess')}\n${context.t('registration.alerts.paymentPendingNote')}'
              : context.t('dashboard.alerts.registerSuccess'),
          paymentPending: result.paymentPending,
        );
        return;
      }
      if (!mounted) return;

      _toast(switch (result.outcome) {
        RegistrationOutcome.registered =>
          result.paymentPending
              ? '${context.t('dashboard.alerts.registerSuccess')}\n${context.t('registration.alerts.paymentPendingNote')}'
              : context.t('dashboard.alerts.registerSuccess'),
        RegistrationOutcome.alreadyRegistered => context.t(
          'dashboard.alerts.alreadyRegistered',
        ),
        RegistrationOutcome.quotaFull => context.t(
          'dashboard.alerts.quotaFull',
        ),
        RegistrationOutcome.closed =>
          result.reason.isNotEmpty
              ? context.t('registration.errors.${result.reason}')
              : context.t('dashboard.alerts.registrationClosed'),
        RegistrationOutcome.notFound => context.t(
          'dashboard.alerts.eventNotFound',
        ),
        RegistrationOutcome.notEligible =>
          result.reason.isNotEmpty
              ? context.t('registration.errors.${result.reason}')
              : context.t('dashboard.errors.register.permissionDenied'),
        RegistrationOutcome.retryExhausted => context.t(
          'dashboard.errors.register.retryExhausted',
        ),
        RegistrationOutcome.unavailable =>
          result.reason.isNotEmpty && result.reason != 'network'
              ? context.t('registration.errors.${result.reason}')
              : context.t('dashboard.errors.register.unavailable'),
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
      if (mounted) {
        setState(() {
          _busy = false;
          _queued = false;
        });
      }
    }
  }

  Future<void> _unregister() async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;

    setState(() => _busy = true);

    try {
      // İP-K: iptal sunucuda; kontenjan yeri aynı işlemde geri verilir ve
      // bekleme listesindekilere haber gider.
      await ref
          .read(registrationServiceProvider)
          .unregister(eventId: widget.event.id);

      if (!mounted) return;
      ref.invalidate(studentVisibleEventsProvider);
      _toast(context.t('dashboard.alerts.unregisterSuccess'));
    } on RegistrationFailure catch (failure) {
      if (!mounted) return;
      _toast(
        failure.isNetwork
            ? context.t('dashboard.errors.unregister.generic')
            : context.t('registration.errors.${failure.reason}'),
      );
    } catch (error) {
      if (!mounted) return;
      _toast(context.t('dashboard.errors.unregister.generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// İP-K: bekleme listesindeki sıra (pencere açılınca sunucudan).
  int? _position;
  bool _positionRequested = false;

  void _refreshPosition(bool waitlisted) {
    if (!waitlisted || _positionRequested) return;
    _positionRequested = true;
    ref
        .read(registrationServiceProvider)
        .waitlistPosition(widget.event.id)
        .then((WaitlistResult r) {
          if (mounted && r.waiting) setState(() => _position = r.position);
        })
        .catchError((Object _) {});
  }

  Future<void> _joinWaitlist({bool skipBusy = false}) async {
    if (_busy && !skipBusy) return;
    setState(() => _busy = true);
    try {
      final WaitlistResult r = await ref
          .read(registrationServiceProvider)
          .joinWaitlist(widget.event.id);
      if (!mounted) return;
      if (r.status == 'seats-available') {
        _toast(context.t('registration.alerts.seatsAvailableNow'));
      } else if (r.waiting) {
        setState(() {
          _position = r.position;
          _positionRequested = true;
        });
        _toast(
          context.t('registration.alerts.waitlistJoined', <String, Object?>{
            'position': r.position,
          }),
        );
      }
    } on RegistrationFailure catch (failure) {
      if (!mounted) return;
      _toast(
        failure.isNetwork
            ? context.t('dashboard.errors.register.unavailable')
            : context.t('registration.errors.${failure.reason}'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveWaitlist() async {
    final bool ok = await _confirm(
      context.t('registration.alerts.leaveWaitlistConfirm'),
      confirmKey: 'registration.actions.leaveWaitlist',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(registrationServiceProvider)
          .leaveWaitlist(widget.event.id);
      if (mounted) setState(() => _position = null);
    } on RegistrationFailure catch (_) {
      if (!mounted) return;
      _toast(context.t('registration.errors.generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// İP-B4b: eksik üniversite/bölüm sorulur. false: vazgeçildi / yazılamadı.
  Future<bool> _fillScopeFieldsIfMissing(AppEvent event) async {
    final String? uid = ref.read(currentUidProvider);
    final StudentProfile? me = ref.read(studentProfileProvider).value;
    if (uid == null || me == null) return true;
    final String scope = TargetScope.normalize(event.targetScope);
    final bool askUni =
        TargetScope.needsUniversity(scope) &&
        me.university.trim().isEmpty &&
        event.targetUniversities.isNotEmpty;
    final bool askDept =
        TargetScope.needsDepartment(scope) &&
        me.department.trim().isEmpty &&
        event.targetDepartments.isNotEmpty;
    if (!askUni && !askDept) return true;

    String? uni = askUni && event.targetUniversities.length == 1
        ? event.targetUniversities.first
        : null;
    String? dept;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: Text(ctx.t('registration.scopeAsk.title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(ctx.t('registration.scopeAsk.body')),
              if (askUni) ...<Widget>[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('scopeAskUniversity'),
                  initialValue: uni,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: ctx.t('registration.scopeAsk.university'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String u in event.targetUniversities)
                      DropdownMenuItem<String>(value: u, child: Text(u)),
                  ],
                  onChanged: (String? v) => setLocal(() => uni = v),
                ),
              ],
              if (askDept) ...<Widget>[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('scopeAskDepartment'),
                  initialValue: dept,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: ctx.t('registration.scopeAsk.department'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String d in event.targetDepartments)
                      DropdownMenuItem<String>(value: d, child: Text(d)),
                  ],
                  onChanged: (String? v) => setLocal(() => dept = v),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.t('common.cancel')),
            ),
            TextButton(
              onPressed: (askUni && uni == null) || (askDept && dept == null)
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: Text(ctx.t('registration.scopeAsk.save')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return false;
    try {
      await ref
          .read(profileRepositoryProvider)
          .fillStudentScopeFields(
            uid: uid,
            university: askUni ? uni : null,
            department: askDept ? dept : null,
          );
      return true;
    } catch (_) {
      if (mounted) _toast(context.t('registration.errors.generic'));
      return false;
    }
  }

  Future<bool> _confirm(String message, {required String confirmKey}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t(confirmKey)),
          ),
        ],
      ),
    );
    return ok ?? false;
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
    final EventRegistration? registration = ref.watch(
      registrationByEventProvider,
    )[event.id];
    final bool waitlisted =
        ref.watch(waitlistedEventIdsProvider).value?.contains(event.id) ??
        false;
    final StudentRegistrationView view = studentRegistrationView(
      event: event,
      registered: isRegistered,
      paymentPending: registration?.paymentPendingFor(event) ?? false,
      waitlisted: waitlisted,
    );
    final int priority = getStudentEventPriority(event, session.studentProfile);

    _queueExternalQrCheckin(event, isRegistered);
    _refreshPosition(waitlisted);

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
                        EventImage(url: event.displayImageUrl, height: 210),
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: BrandColors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 14,
                          child: EventDatePill(
                            label: eventCardDate(context, event),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: context.surface.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            elevation: 1,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: context.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),

                          // Kulüp kimliği: adın hemen altında, kulübü kısa kısa
                          // anlatan baloncuklar (alan, üniversite, şehir).
                          const SizedBox(height: 16),
                          _ClubHeader(event: event),

                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              StatusPill(
                                label: context.t(view.statusKey),
                                tone: feedbackToneFor(view.statusTone),
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
                          const SizedBox(height: 26),
                          _SectionTitle(context.t('eventModal.info')),
                          const SizedBox(height: 12),
                          _InfoTable(
                            rows:
                                <({IconData icon, String label, String value})>[
                                  if ((event.eventDateAtMs ?? 0) > 0)
                                    (
                                      icon: Icons.event_outlined,
                                      label: context.t('eventModal.eventDate'),
                                      value:
                                          formatDeadline(
                                            event.eventDateAtMs,
                                            locale: context.lang,
                                          ) +
                                          (event.timeRangeLabel.isEmpty
                                              ? ''
                                              : ' · ${event.timeRangeLabel}'),
                                    ),
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
                                    value: eventFeeLabel(context, event),
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
                          const SizedBox(height: 26),
                          EventPaidContactBlock(event: event),

                          // İP-T: takvime ekle
                          const SizedBox(height: 14),
                          // İP-EL: etkinliğin linkini paylaş.
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              AddToCalendarButton(event: event),
                              ShareEventLinkButton(event: event),
                            ],
                          ),

                          // ── Açıklama ────────────────────────────────────────
                          const SizedBox(height: 26),
                          _SectionTitle(context.t('eventModal.description')),
                          const SizedBox(height: 10),
                          Text(
                            event.description.isNotEmpty
                                ? event.description
                                : context.t('dashboard.modal.noDescription'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),

                          if (event.purpose.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 26),
                            _SectionTitle(context.t('eventModal.purpose')),
                            const SizedBox(height: 10),
                            Text(
                              event.purpose,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],

                          // İP-ŞK: şikâyet et / organizatörü engelle.
                          const SizedBox(height: 26),
                          EventComplaintSection(
                            event: event,
                            onBlocked: () => Navigator.of(context).maybePop(),
                          ),
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
                    view: view,
                    position: _position,
                    onPrimary: switch (view.primaryAction) {
                      StudentPrimaryAction.register => _register,
                      StudentPrimaryAction.joinWaitlist =>
                        () => _joinWaitlist(),
                      StudentPrimaryAction.none => () {},
                    },
                    onSecondary: switch (view.secondary) {
                      StudentSecondaryAction.unregister => _unregister,
                      StudentSecondaryAction.leaveWaitlist => _leaveWaitlist,
                      StudentSecondaryAction.none => () {},
                    },
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
    required this.view,
    required this.position,
    required this.onPrimary,
    required this.onSecondary,
  });

  final bool busy;
  final bool queued;
  final StudentRegistrationView view;

  /// Bekleme listesindeki sıra (biliniyorsa).
  final int? position;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final Color surface = context.surface;
    final bool hasSecondary = view.secondary != StudentSecondaryAction.none;

    // Bekleme listesindeyken sıra numarası düğmenin üzerinde yazar.
    final String primaryLabel =
        view.waitlisted &&
            view.primaryAction == StudentPrimaryAction.none &&
            position != null &&
            position! > 0
        ? context.t('registration.actions.waitlistPosition', <String, Object?>{
            'position': position,
          })
        : context.t(view.primaryKey);

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
              closed:
                  !view.primaryEnabled && !view.registered && !view.waitlisted,
              registered: view.registered,
              // Bekleme listesi kayıttan ayrı renkte (mavi): yer garantisi yok.
              waitlisted:
                  !view.registered && view.waitlisted && !view.primaryEnabled,
              enabled: view.primaryEnabled,
              label: primaryLabel,
              onPressed: onPrimary,
            ),
          ),
          if (hasSecondary) ...<Widget>[
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
                    foregroundColor: context.brandInk,
                    side: BorderSide(color: context.brandInk),
                    shape: const StadiumBorder(),
                    backgroundColor: surface,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: busy ? null : onSecondary,
                  child: Text(
                    context.t(
                      view.secondary == StudentSecondaryAction.leaveWaitlist
                          ? 'registration.actions.leaveWaitlist'
                          : 'dashboard.actions.unregister',
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.2),
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
    required this.enabled,
    required this.label,
    required this.onPressed,
    this.waitlisted = false,
  });

  final bool busy;

  /// Kayıt sıraya girdi: kontenjan sayacında çekişme var, kısa bir
  /// bekleyişten sonra yeniden denenecek.
  final bool queued;

  final bool closed;
  final bool registered;

  /// Bekleme listesinde (düğme pasif): mavi, kum saati.
  final bool waitlisted;

  /// İP-K: düğme etkin mi (kayıt / bekleme listesine gir / yer açıldı).
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !busy && this.enabled;

    final IconData icon = closed
        ? Icons.event_busy_outlined
        : waitlisted
        ? Icons.hourglass_top_rounded
        : registered
        ? Icons.verified_outlined
        : Icons.how_to_reg_outlined;

    // Bekleme listesi ve kayıt aynı "sakin hap" biçiminde, farklı renkte.
    final Color? calm = waitlisted
        ? BrandColors.info
        : registered
        ? BrandColors.success
        : null;

    final Color foreground = closed
        ? context.inkMuted
        : calm ?? BrandColors.white;

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
                : calm?.withValues(alpha: context.isDarkMode ? 0.20 : 0.12),
            borderRadius: BorderRadius.circular(BrandShape.pillRadius),
            border: calm != null
                ? Border.all(color: calm.withValues(alpha: 0.45))
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
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
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
/// tanımasını sağlıyor. Takip düğmesi dar ekranda adı sıkıştırmasın diye
/// bilgilerin altında, kendi satırında durur.
class _ClubHeader extends StatelessWidget {
  const _ClubHeader({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.canvas,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EventClubHeader(event: event),
          // İP-TK: kulübü takip et / bırak.
          if (event.clubId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ClubFollowButton(clubId: event.clubId),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal içindeki bölüm başlığı — solunda kısa bir marka çubuğu.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => EventSectionTitle(text);
}

/// Etiket/değer çiftlerinden oluşan bilgi bloğu (web'deki detay tablosu).
class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final List<({IconData icon, String label, String value})> rows;

  @override
  Widget build(BuildContext context) => EventInfoTable(rows: rows);
}

/// İP-K: saf durum tonu → ekrandaki ton.
FeedbackTone feedbackToneFor(StudentStatusTone tone) => switch (tone) {
  StudentStatusTone.info => FeedbackTone.info,
  StudentStatusTone.success => FeedbackTone.success,
  StudentStatusTone.warning => FeedbackTone.warning,
  StudentStatusTone.error => FeedbackTone.error,
};
