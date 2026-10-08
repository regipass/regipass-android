import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/app_log.dart';
import '../../domain/event_feedback.dart';
import '../../domain/checkin_mode.dart';
import '../../domain/registration_capacity.dart';
import '../../domain/event_utils.dart';
import '../../domain/qr_signing.dart';
import '../../domain/paid_event_consent.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/door_gate.dart';
import '../../services/event_repository.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_link_widgets.dart';
import '../shared/event_widgets.dart';
import 'club_block_dialog.dart';
import 'club_providers.dart';
import 'event_feedback_summary_card.dart';
import 'event_notify_card.dart';
import 'certificate_panel_card.dart';
import 'event_report_card.dart';
import 'club_session_qr_screen.dart';
import 'club_shell.dart';
import 'registrations_export.dart';
import '../../domain/plans.dart';
import '../shared/plan_widgets.dart';
import '../../domain/session_names.dart';
import '../../domain/session_attendance.dart';
import '../../domain/ticket_code.dart';

/// Dağıtılabilecek belge türleri — storage.rules `certificates/` kuralıyla
/// (application/pdf veya image/*) birebir aynı olmalı.
const List<String> kCertificateExtensions = <String>[
  'pdf',
  'png',
  'jpg',
  'jpeg',
];

/// storage.rules sınırı: certificates/ altına en fazla 10 MB.
const int kMaxCertificateBytes = 10 * 1024 * 1024;

/// club-events.js içindeki etkinlik modalinin mobil karşılığı.
///
/// Web'de tek bir modal; mobilde içerik (oturum yönetimi + katılımcı listesi +
/// belge dağıtımı) bir alt sayfaya sığmayacak kadar çok olduğu için ayrı bir
/// ekran. Etkinlik ve kayıtlar canlı dinlenir: QR başka bir cihazdan
/// okutulduğunda sayılar kendiliğinden güncellenir.
class ClubEventDetailScreen extends ConsumerStatefulWidget {
  const ClubEventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<ClubEventDetailScreen> createState() =>
      _ClubEventDetailScreenState();
}

class _ClubEventDetailScreenState extends ConsumerState<ClubEventDetailScreen> {
  bool _busy = false;

  /// Çoklu seçim: toplu "Ödendi" ve toplu kayıt silme için seçilen öğrenciler.
  final Set<String> _selected = <String>{};
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Kontenjan parçaları bu ekran açıldığından beri kurulmaya çalışıldı mı?
  bool _shardBackfillTried = false;

  /// Kontenjan durumu ile kayıt bayrağını eşitleyen yazma uçuşta mı?
  ///
  /// Doluluk canlı dinleniyor; bayrağı yazınca etkinlik dokümanı da değişiyor
  /// ve build yeniden çalışıyor. Bu kilit olmadan aynı yazma arka arkaya
  /// tetiklenirdi.
  bool _syncingQuotaState = false;

  /// Kontenjan dolunca etkinliği kendiliğinden **beklemeye alır**, yer
  /// açılınca geri açar.
  ///
  /// Bunu neden öğrenci değil kulüp tarafı yapıyor: `firestore.rules`
  /// etkinlik dokümanını yalnızca sahibi kulübe yazdırıyor. Öğrenciye izin
  /// vermek için kuralın "bütün parçalar dolu mu" diye bakması gerekirdi,
  /// kurallarda tek istekte en çok 10 doküman okunabildiği için 16–32 parçada
  /// bu mümkün değil.
  ///
  /// Kontenjanın kendisi zaten parça sayaçlarıyla korunuyor — öğrenci dolu
  /// etkinliğe kaydolamaz. Bu bayrak yalnızca **görünürlük** için: etkinlik
  /// kulüp listesinde "beklemede" görünsün, öğrencinin keşif listesinden
  /// düşsün.
  void _scheduleQuotaStateSync(AppEvent event, QuotaStatus status) {
    if (_syncingQuotaState) return;

    final QuotaGateAction action = quotaGateAction(
      status: status,
      registrationClosed: event.registrationClosed,
      closedReason: event.registrationClosedReason,
    );
    if (action == QuotaGateAction.none) return;

    _syncingQuotaState = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .syncRegistrationStateWithQuota(event: event, status: status);
        // Başarılıysa kilidi bırak: etkinlik dokümanı değişti, build yeniden
        // çalışacak ve `quotaGateAction` artık `none` diyecek. Sonraki gerçek
        // durum değişimi (iptal, kontenjan artışı) yine yakalanabilsin.
        if (mounted) _syncingQuotaState = false;
      } catch (error) {
        // BAŞARISIZLIKTA KİLİT AÇILMAZ. Doluluk canlı dinlendiği için build
        // sık sık yeniden çalışıyor; kilidi bırakmak, kuralca reddedilen bir
        // yazmayı her karede yeniden denemek olurdu. Ekran kapanıp
        // açıldığında tekrar denenir.
        AppLog.warn('event.quotaStateSyncFailed', <String, Object?>{
          'eventId': event.id,
          'error': error.toString(),
        });
      }
    });
  }

  /// Kontenjan parçaları eksik olan ESKİ etkinliklere onları kurar.
  ///
  /// `quotaShardCount` alanı eklenmeden önce oluşturulmuş etkinliklerde parça
  /// yok; o etkinliklerde kayıt kontenjansız eski yoldan geçiyor (davranış
  /// bozulmasın diye bilerek). Parçaları yalnızca etkinliğin sahibi kulüp
  /// kurabildiği için (bkz. firestore.rules) geri dolumun doğal yeri burası:
  /// kulüp kendi etkinliğine baktığı an.
  ///
  /// O ana kadar yapılmış kayıtlar sayaca işlenir — yoksa kontenjan sıfırdan
  /// sayılıp aşılırdı.
  void _scheduleQuotaShardBackfill(AppEvent event) {
    if (_shardBackfillTried || _busy) return;
    // İP-K: kontenjanı kurulamamış yeni etkinlik de ("quota-setup") burada
    // sunucuda yeniden kurulur.
    if (event.quota <= 0) return;
    if (event.quotaShardCount > 0 && !event.quotaSetupPending) return;
    if (event.cancelled) return;

    _shardBackfillTried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref
            .read(registrationServiceProvider)
            .setEventQuota(eventId: event.id, quota: event.quota);
      } catch (error) {
        // Sessiz: kontenjan koruması olmadan da kayıt çalışmaya devam eder,
        // kulübün ekranını bir hata mesajıyla bölmenin anlamı yok.
        AppLog.warn('event.quotaShardBackfillFailed', <String, Object?>{
          'eventId': event.id,
          'error': error.toString(),
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('common.continueAction')),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Tek düğmeli bilgi penceresi: seçim yok, yalnızca "neden olmadı" der.
  Future<void> _notice(String title, String message) => showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t('common.close')),
        ),
      ],
    ),
  );

  // ── Kayıt aç/kapa ──────────────────────────────────────────────────

  /// Kayıtları durdurur ya da yeniden açar.
  ///
  /// Etkinlik YÜRÜRKEN (kapı açık ya da bir oturum ilerletilmiş — bkz.
  /// [eventHasStarted]) kayıt yeniden AÇILAMAZ: başlamış bir etkinliğe yeni
  /// öğrenci alınması, kapıda okutulmamış ve yoklaması tutulmamış bir katılımcı
  /// üretirdi. Düğmeyi sessizce devre dışı bırakmak yerine sebebi ve çıkış
  /// yolunu söyleyen bir pencere gösteriyoruz: önce kapı check-in'ini bitir,
  /// sonra oturumları en başa (0) geri al — o noktada kayıt yeniden açılabilir
  /// hâle gelir (oturumlar 0'a inince zaten kendiliğinden açılır, bkz.
  /// [EventRepository.advanceSession]).
  ///
  /// Kayıtları DURDURMAK her zaman serbesttir; kısıt yalnızca açma yönünde.
  Future<void> _toggleRegistrations(AppEvent event) async {
    final bool reopening = event.registrationClosed;
    if (event.cancelled) return;

    // İP-K: kontenjanı kurulamamış yeni etkinlik elle açılmaz (kontenjansız
    // açılmış olurdu); kurulum sunucuda yeniden denenir, olursa açılır.
    if (reopening && event.quotaSetupPending) {
      final String ok = context.t('registration.club.quotaSetupDone');
      await _run(() async {
        try {
          await ref
              .read(registrationServiceProvider)
              .setEventQuota(eventId: event.id, quota: event.quota);
          _setFeedback(ok, FeedbackTone.success);
        } on RegistrationFailure catch (failure) {
          if (!mounted) return;
          _setFeedback(
            context.t('registration.errors.${failure.reason}'),
            FeedbackTone.error,
          );
        }
      });
      return;
    }

    if (reopening && lateRegistrationBlocked(event)) {
      await _notice(
        context.t('clubEvents.registrations.title'),
        context.t('clubEvents.registrations.blockedRunning'),
      );
      return;
    }

    final bool ok = await _confirm(
      context.t('clubEvents.registrations.title'),
      reopening
          ? context.t('clubEvents.registrations.confirmOpen')
          : context.t('clubEvents.registrations.confirmClose'),
    );
    if (!ok || !mounted) return;

    // Mesajlar await'ten önce çözülür: sonrasında `context` kullanmak
    // widget ağaçtan çıkmışsa geçersiz olur.
    final String successMessage = reopening
        ? context.t('clubEvents.registrations.opened')
        : context.t('clubEvents.registrations.closed');
    final String errorMessage = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .setRegistrationsClosed(event.id, !reopening);
        _setFeedback(successMessage, FeedbackTone.success);
      } catch (error) {
        if (error is StateError && mounted) {
          await _notice(
            context.t('clubEvents.registrations.title'),
            context.t(error.message),
          );
        } else {
          _setFeedback(errorMessage, FeedbackTone.error);
        }
      }
    });
  }

  // ── İP-K: ödeme, kayıt silme, "+5 yer aç" ───────────────────────────

  /// İP-B5: elle yoklama ekle / geri al.
  Future<void> _setSessionAttendance(
    AppEvent event,
    EventRegistration reg,
    int session,
    bool present,
  ) async {
    final String label = withSessionName(
      context.t('attendance.stage.session', <String, Object?>{'n': session}),
      event.sessionNames,
      session,
    );
    final bool ok = await _confirm(
      context.t('manualAttendance.title'),
      context.t(
        present
            ? 'manualAttendance.addConfirm'
            : 'manualAttendance.removeConfirm',
        <String, Object?>{'name': reg.displayName, 'session': label},
      ),
    );
    if (!ok || !mounted) return;
    await _run(() async {
      try {
        final ({String status, String name, int session}) out = await ref
            .read(registrationServiceProvider)
            .setSessionAttendance(
              eventId: event.id,
              studentId: reg.studentId,
              session: session,
              present: present,
            );
        if (!mounted) return;
        _setFeedback(
          context.t(
            out.status == 'already'
                ? 'manualAttendance.already'
                : present
                ? 'manualAttendance.added'
                : 'manualAttendance.removed',
            <String, Object?>{'name': reg.displayName, 'session': label},
          ),
          out.status == 'already' ? FeedbackTone.info : FeedbackTone.success,
        );
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(_manualAttendanceError(failure), FeedbackTone.error);
      }
    });
  }

  String _manualAttendanceError(RegistrationFailure failure) {
    final String key = 'manualAttendance.error.${failure.reason}';
    final String text = context.t(key);
    return text == key ? context.t('manualAttendance.error.generic') : text;
  }

  /// İP-B5: o anki oturuma bilet koduyla yoklama (görevli kodu yazar).
  Future<void> _sessionCodeEntry(AppEvent event) async {
    final TextEditingController code = TextEditingController();
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('manualAttendance.codeTitle')),
        content: TextField(
          key: const Key('sessionCodeInput'),
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: ctx.t('manualAttendance.codeHint'),
          ),
          onSubmitted: (String v) => Navigator.of(ctx).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.t('common.cancel')),
          ),
          TextButton(
            key: const Key('sessionCodeSubmit'),
            onPressed: () => Navigator.of(ctx).pop(code.text),
            child: Text(ctx.t('manualAttendance.codeSubmit')),
          ),
        ],
      ),
    );
    code.dispose();
    final String value = (typed ?? '').trim();
    if (value.isEmpty || !mounted) return;
    await _run(() async {
      try {
        final ({String status, String name, int session}) out = await ref
            .read(registrationServiceProvider)
            .setSessionAttendance(eventId: event.id, ticketCode: value);
        if (!mounted) return;
        final String label = withSessionName(
          context.t('attendance.stage.session', <String, Object?>{
            'n': out.session,
          }),
          event.sessionNames,
          out.session,
        );
        _setFeedback(
          context.t(
            out.status == 'already'
                ? 'manualAttendance.already'
                : 'manualAttendance.added',
            <String, Object?>{'name': out.name, 'session': label},
          ),
          out.status == 'already' ? FeedbackTone.info : FeedbackTone.success,
        );
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(_manualAttendanceError(failure), FeedbackTone.error);
      }
    });
  }

  Future<void> _setPayment(
    AppEvent event,
    EventRegistration reg,
    bool paid,
  ) async {
    if (!paid) {
      final bool ok = await _confirm(
        context.t('registration.club.paymentTitle'),
        context.t('registration.club.unmarkConfirm', <String, Object?>{
          'name': reg.displayName,
        }),
      );
      if (!ok || !mounted) return;
    }
    final String done = paid
        ? context.t('registration.club.markedPaid', <String, Object?>{
            'name': reg.displayName,
          })
        : context.t('registration.club.unmarkedPaid', <String, Object?>{
            'name': reg.displayName,
          });
    await _run(() async {
      try {
        await ref
            .read(registrationServiceProvider)
            .setPaymentStatus(
              eventId: event.id,
              studentId: reg.studentId,
              paid: paid,
            );
        _setFeedback(done, FeedbackTone.success);
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(
          failure.isNetwork
              ? context.t('clubEvents.feedback.updateError')
              : context.t('registration.errors.${failure.reason}'),
          FeedbackTone.error,
        );
      }
    });
  }

  /// Kayıt silme onayı + isteğe bağlı gerekçe. İptalde `null`.
  Future<String?> _askRemoveReason(String body) async {
    final TextEditingController reason = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.t('registration.club.removeTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(body),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 300,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: dialogContext.t('registration.club.reasonLabel'),
                hintText: dialogContext.t('registration.club.removeReasonHint'),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dialogContext.t('registration.club.removeAction'),
              style: const TextStyle(color: BrandColors.danger),
            ),
          ),
        ],
      ),
    );
    final String text = reason.text.trim();
    reason.dispose();
    return ok == true ? text : null;
  }

  Future<void> _removeRegistration(
    AppEvent event,
    EventRegistration reg,
  ) async {
    final String? text = await _askRemoveReason(
      context.t('registration.club.removeBody', <String, Object?>{
        'name': reg.displayName,
      }),
    );
    if (text == null || !mounted) return;
    final String done = context.t(
      'registration.club.removed',
      <String, Object?>{'name': reg.displayName},
    );
    await _run(() async {
      try {
        await ref
            .read(registrationServiceProvider)
            .clubRemoveRegistration(
              eventId: event.id,
              studentId: reg.studentId,
              reason: text,
            );
        ref.invalidate(eventWaitlistCountProvider(event.id));
        _setFeedback(done, FeedbackTone.success);
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(
          failure.isNetwork
              ? context.t('clubEvents.feedback.updateError')
              : context.t('registration.errors.${failure.reason}'),
          FeedbackTone.error,
        );
      }
    });
  }

  // ── İP-KB: kulüpten engelle ────────────────────────────────────────
  Future<void> _blockStudent(EventRegistration reg) async {
    final ClubBlockDecision? decision = await askClubBlock(
      context,
      reg.displayName,
    );
    if (decision == null || !mounted) return;
    await _run(() async {
      try {
        final int removed = await ref
            .read(registrationServiceProvider)
            .clubBlockStudent(
              studentId: reg.studentId,
              reason: decision.reason,
              removeFutureRegistrations: decision.removeFutureRegistrations,
            );
        if (!mounted) return;
        _setFeedback(
          context.t('clubBlock.done', <String, Object?>{
            'name': reg.displayName,
            'count': removed,
          }),
          FeedbackTone.success,
        );
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(
          failure.isNetwork
              ? context.t('clubEvents.feedback.updateError')
              : context.t('clubBlock.errors.${failure.reason}'),
          FeedbackTone.error,
        );
      }
    });
  }

  // ── Çoklu seçim ─────────────────────────────────────────────────────

  void _toggleSelected(String studentId, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(studentId);
      } else {
        _selected.remove(studentId);
      }
    });
  }

  void _replaceSelection(Iterable<String> ids) {
    setState(() {
      _selected
        ..clear()
        ..addAll(ids);
    });
  }

  /// Seçimden hâlâ listede olan kayıtlar (bu arada silinenler düşer).
  List<EventRegistration> _selectedRegistrations(AppEvent event) {
    final List<EventRegistration> regs =
        ref.read(eventRegistrationsProvider(event.id)).value ??
        const <EventRegistration>[];
    return regs
        .where((EventRegistration r) => _selected.contains(r.studentId))
        .toList(growable: false);
  }

  String _failureText(RegistrationFailure failure) => failure.isNetwork
      ? context.t('clubEvents.feedback.updateError')
      : context.t('registration.errors.${failure.reason}');

  Future<void> _bulkMarkPaid(AppEvent event) async {
    final List<String> ids = _selectedRegistrations(event)
        .where((EventRegistration r) => r.paymentPendingFor(event))
        .map((EventRegistration r) => r.studentId)
        .toList(growable: false);
    if (ids.isEmpty) {
      _setFeedback(context.t('registration.bulk.nonePending'));
      return;
    }
    if (ids.length > RegistrationService.maxBulk) {
      _setFeedback(
        context.t('registration.errors.too-many-students'),
        FeedbackTone.error,
      );
      return;
    }
    final bool ok = await _confirm(
      context.t('registration.bulk.markPaid'),
      context.t('registration.bulk.markPaidConfirm', <String, Object?>{
        'n': ids.length,
      }),
    );
    if (!ok || !mounted) return;
    await _run(() async {
      try {
        final BulkResult result = await ref
            .read(registrationServiceProvider)
            .setPaymentStatusBulk(
              eventId: event.id,
              studentIds: ids,
              paid: true,
            );
        if (!mounted) return;
        setState(_selected.clear);
        _setFeedback(
          context.t('registration.bulk.markedPaid', <String, Object?>{
            'n': result.count,
          }),
          FeedbackTone.success,
        );
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(_failureText(failure), FeedbackTone.error);
      }
    });
  }

  Future<void> _bulkRemove(AppEvent event) async {
    final List<String> ids = _selectedRegistrations(
      event,
    ).map((EventRegistration r) => r.studentId).toList(growable: false);
    if (ids.isEmpty) return;
    if (ids.length > RegistrationService.maxBulk) {
      _setFeedback(
        context.t('registration.errors.too-many-students'),
        FeedbackTone.error,
      );
      return;
    }
    final String? text = await _askRemoveReason(
      context.t('registration.bulk.removeBody', <String, Object?>{
        'n': ids.length,
      }),
    );
    if (text == null || !mounted) return;
    await _run(() async {
      try {
        final BulkResult result = await ref
            .read(registrationServiceProvider)
            .clubRemoveRegistrations(
              eventId: event.id,
              studentIds: ids,
              reason: text,
            );
        ref.invalidate(eventWaitlistCountProvider(event.id));
        if (!mounted) return;
        setState(_selected.clear);
        _setFeedback(
          context.t('registration.bulk.removed', <String, Object?>{
            'n': result.count,
          }),
          FeedbackTone.success,
        );
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(_failureText(failure), FeedbackTone.error);
      }
    });
  }

  Future<void> _addSeats(AppEvent event) async {
    const int step = 5;
    final bool ok = await _confirm(
      context.t('registration.club.addSeats', <String, Object?>{'n': step}),
      context.t('registration.club.addSeatsConfirm', <String, Object?>{
        'from': event.quota,
        'to': event.quota + step,
      }),
    );
    if (!ok || !mounted) return;
    await _run(() async {
      try {
        final ({int quota, String blockReason}) result = await ref
            .read(registrationServiceProvider)
            .setEventQuotaDetailed(
              eventId: event.id,
              quota: event.quota + step,
            );
        if (!mounted) return;
        // İP-B4: kontenjan arttı ama yeni kayıt alınamıyorsa nedenini söyle.
        final String blockedKey =
            'registration.club.quotaBlocked.${result.blockReason}';
        final bool blocked =
            result.blockReason.isNotEmpty &&
            context.t(blockedKey) != blockedKey;
        _setFeedback(
          context.t(
            blocked ? blockedKey : 'registration.club.quotaNowOpen',
            <String, Object?>{'n': result.quota},
          ),
          blocked ? FeedbackTone.warning : FeedbackTone.success,
        );
      } on RegistrationFailure catch (failure) {
        if (!mounted) return;
        _setFeedback(
          context.t('registration.errors.${failure.reason}'),
          FeedbackTone.error,
        );
      }
    });
  }

  // ── Oturum yönetimi ────────────────────────────────────────────────

  /// İlk oturumu ilerletmek (0 -> 1) etkinliği "başlatır" — bu anda kayıtlar
  /// da kendiliğinden durur (bkz. [EventRepository.advanceSession] >
  /// [sessionRegistrationGateAction]): kayıt kapanınca etkinlik keşiften
  /// düşer (bkz. [isDiscoverableEvent]), yani başlamış bir etkinliğe yeni
  /// öğrenci kaydolamaz.
  Future<void> _advanceSession(AppEvent event) async {
    final int next = event.currentSession + 1;

    // Son oturumdayken düğme "bitir" anlamına gelir: QR girişleri kapanır ve
    // belge dağıtımı açılır.
    if (event.currentSession >= event.sessionCount) {
      final bool ok = await _confirm(
        context.t('clubEvents.session.finishTitle'),
        context.t('clubEvents.session.finishConfirm'),
      );
      if (!ok || !mounted) return;

      final String done = context.t('clubEvents.session.finished');
      final String failed = context.t('clubEvents.feedback.updateError');

      await _run(() async {
        try {
          await ref.read(eventRepositoryProvider).finishSessions(event.id);
          _setFeedback(done, FeedbackTone.success);
        } catch (_) {
          _setFeedback(failed, FeedbackTone.error);
        }
      });
      return;
    }

    final bool ok = await _confirm(
      context.t('clubEvents.session.advanceTitle'),
      next == 1
          ? context.t('clubEvents.session.startConfirm', <String, Object?>{
              'total': event.sessionCount,
            })
          : context.t('clubEvents.session.advanceConfirm', <String, Object?>{
              'next': next,
            }),
    );
    if (!ok || !mounted) return;

    final String started = withSessionName(
      context.t('clubEvents.session.started', <String, Object?>{
        'session': next,
      }),
      event.sessionNames,
      next,
    );
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref.read(eventRepositoryProvider).advanceSession(event, next);
        if (!mounted) return;
        _setFeedback(started, FeedbackTone.success);
        // Oturum başlar başlamaz QR ekrana gelsin: öğrenciler bunu okutacak.
        await _showSessionQr(event.id, next);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  /// Aktif oturumu bir geri alır ve o oturumun QR'ını yeniden gösterir.
  ///
  /// "İlerlet" düğmesine yanlışlıkla basmak geri alınamaz bir işlemdi: QR
  /// değişiyor, bir önceki oturuma henüz girmemiş öğrenciler yoklamada
  /// görünemiyordu. Geri alınca eski oturumun QR'ı yeniden geçerli olur ve
  /// hemen ekrana gelir — kulübün ayrıca "QR'ı göster"e basması gerekmez.
  ///
  /// O oturuma kendi QR'ıyla girmiş öğrencilerin yoklaması da geri alınır
  /// (bkz. [EventRepository.revertSessionAttendance]) — yoksa öğrenci
  /// ekranında "giriş yapıldı" görünmeye devam eder ve oturum yeniden
  /// (doğru şekilde) başladığında okuma tarafındaki
  /// `lastAttendedSession >= currentSession` kontrolü onu tekrar giriş
  /// yapmaktan alıkoyardu.
  ///
  /// En başa (0'a) kadar geri alınırsa — yalnızca etkinlik başladığı için
  /// kendiliğinden kapanmışsa (bkz. [sessionRegistrationGateAction]) —
  /// kayıtlar da kendiliğinden yeniden açılır ve etkinlik, standartlara uyan
  /// öğrencilerin keşfinde tekrar görünür. Kulübün ELLE kapattığı ya da
  /// kontenjan yüzünden kapanan bir etkinliğe dokunulmaz.
  ///
  /// Kapı check-in'i olan etkinliklerde bu adım kapıyı da sıfırlar (bkz.
  /// [EventRepository.advanceSession]): oturumları yeniden başlatmak için
  /// check-in'in baştan Başlat→Bitir sırasıyla yeniden geçilmesi gerekir —
  /// bu yüzden onay/sonuç metni bu durumda ayrıca uyarır.
  Future<void> _undoSession(AppEvent event) async {
    final int previous = event.currentSession - 1;
    if (previous < 0) return;

    final bool resetsDoorCheckin = previous < 1 && event.hasDoorCheckin;

    final bool ok = await _confirm(
      context.t('clubEvents.session.undoTitle'),
      previous < 1
          ? context.t(
              resetsDoorCheckin
                  ? 'clubEvents.session.undoToStartConfirmWithCheckin'
                  : 'clubEvents.session.undoToStartConfirm',
            )
          : context.t('clubEvents.session.undoConfirm', <String, Object?>{
              'session': previous,
            }),
    );
    if (!ok || !mounted) return;

    final String done = previous < 1
        ? context.t(
            resetsDoorCheckin
                ? 'clubEvents.session.undoneToStartWithCheckin'
                : 'clubEvents.session.undoneToStart',
          )
        : context.t('clubEvents.session.undone', <String, Object?>{
            'session': previous,
          });
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        // ÖNCE öğrenci tarafı geri alınır: firestore.rules >
        // clubCanRevertSessionCheckIn, etkinliğin `currentSession`ı HÂLÂ eski
        // (geri alınmamış) değerdeyken yazılmayı şart koşuyor. En iyi çaba:
        // kural henüz üretime dağıtılmamışsa ya da tek bir kayıt reddedilirse
        // bile asıl geri alma işlemi (currentSession) yine de tamamlanır.
        try {
          await ref
              .read(eventRepositoryProvider)
              .revertSessionAttendance(
                eventId: event.id,
                undoneSession: event.currentSession,
              );
        } catch (_) {
          // Yoksay.
        }
        await ref.read(eventRepositoryProvider).advanceSession(event, previous);
        if (!mounted) return;
        _setFeedback(done, FeedbackTone.success);
        // Geri alınan oturumun QR'ı yeniden geçerli — hemen göster.
        if (previous >= 1) await _showSessionQr(event.id, previous);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  /// Bitirilmiş oturumları yeniden açar (web'deki modalde bulunan
  /// "Oturumları Tekrar Aç" düğmesinin karşılığı).
  ///
  /// Oturumları yanlışlıkla bitirmek geri alınamaz bir işlemdi: QR girişleri
  /// kapanıyor, geç gelen öğrenci yoklamaya giremiyordu. Aktif oturum
  /// numarası korunur, yalnızca "tamamlandı" işareti kalkar.
  Future<void> _reopenSessions(AppEvent event) async {
    final bool ok = await _confirm(
      context.t('clubEvents.session.reopenTitle'),
      context.t('clubEvents.session.reopenConfirm'),
    );
    if (!ok || !mounted) return;

    final String done = context.t('clubEvents.session.reopened');
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref.read(eventRepositoryProvider).reopenSessions(event.id);
        _setFeedback(done, FeedbackTone.success);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  Future<void> _showSessionQr(String eventId, int session) =>
      showSessionQrDialog(context, ref, eventId, session);

  /// Kapıyı açar/kapatır. Kapı açıkken öğrenciler kapıdaki ortak QR'ı kendi
  /// telefonlarından okutup girişlerini onaylar; kapalıyken o QR hiçbir işe
  /// yaramaz (firestore.rules > studentCanMarkOwnEventCheckIn `entryOpen`
  /// alanına bakar). Açar açmaz kamera ekrana gelir — görevli beklemeden
  /// öğrenci bileti okutmaya başlar. QR ekranı isteyen kulüpler için "Göster"
  /// düğmesiyle ayrıca, elle açılan bir seçenek olarak kalır.
  Future<void> _toggleDoorCheckin(AppEvent event) async {
    final bool opening = !event.entryOpen;
    // Metinler async iş BAŞLAMADAN çözülür (dosyadaki diğer eylemlerle aynı
    // kalıp): `context` await sonrası ağaçtan düşmüş olabilir.
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .setEntryOpen(
              event.id,
              opening,
              // Damga "Bitir" sonrası "Yeniden Başlat"ta korunur: aşama "hiç
              // başlamadı"ya dönmesin, etkinlik Aktif listesinden düşmesin.
              // (Oturumlar en başa kadar geri alınırsa sıfırlanır — bkz.
              // EventRepository.advanceSession.)
              alreadyStartedAtMs: event.entryStartedAtMs,
              // Kapı GERÇEKTEN ilk kez açılıyorsa kayıtları da kendiliğinden
              // durdurur — kulübün zaten kapattığı bir kayda dokunmaz.
              registrationClosed: event.registrationClosed,
            );
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
        return;
      }
      if (opening && mounted) {
        _openDoorScanner(event);
      }
    });
  }

  /// Görevlinin öğrenci biletini kamerayla okutacağı ekranı açar.
  ///
  /// Kapı check-in'inin varsayılan yolu budur; QR gösterimi bunun yerine
  /// değil, isteyen kulüpler için bunun yanında duran ikinci bir seçenektir.
  void _openDoorScanner(AppEvent event) => context.push(
    '${Routes.clubQrCheckin}?eventId=${Uri.encodeComponent(event.id)}',
  );

  /// Kapıda check-in'i kaçıranların oturum yoklamasına doğrudan katılmasına
  /// izin veren anahtar (PDF: "oturumları başlattıktan sonra bir switch").
  /// Kapalıyken yoklama için önce kapı girişi gerekir.
  Future<void> _setAllowSessionWithoutCheckin(
    AppEvent event,
    bool allow,
  ) async {
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .setAllowSessionWithoutCheckin(event.id, allow);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  // ── Katılımcı listesi ──────────────────────────────────────────────

  /// Katılımcıları web'dekiyle aynı Excel dosyasına yazıp paylaşım sayfasını
  /// açar (club-events.js#downloadStudentsBtn).
  Future<void> _downloadStudentsExcel(AppEvent event) async {
    // İP-P1: Excel / rapor dosyası Ücretsiz pakette yok.
    if (!planFeatureAllowed(event.planTier, 'reportFile')) {
      _setFeedback(
        context.t('plan.lock.text', <String, Object?>{'feature': context.t('plan.feature.reportFile')}),
        FeedbackTone.error,
      );
      return;
    }
    final List<EventRegistration> registrations =
        ref.read(eventRegistrationsProvider(event.id)).value ??
        const <EventRegistration>[];

    if (registrations.isEmpty) {
      _setFeedback(context.t('clubEvents.students.empty'), FeedbackTone.error);
      return;
    }

    final RegistrationsSheetLabels labels = RegistrationsSheetLabels(
      sheetName: context.t('clubEvents.excel.sheetName'),
      reportTitle: context.t('clubEvents.excel.reportTitle'),
      eventNameLabel: context.t('clubEvents.excel.eventName'),
      clubLabel: context.t('clubEvents.excel.club'),
      countLabel: context.t('clubEvents.excel.studentCount'),
      reportDateLabel: context.t('clubEvents.excel.reportDate'),
      headers: <String>[
        context.t('table.fullName'),
        context.t('table.email'),
        context.t('table.phone'),
        context.t('table.university'),
        context.t('table.department'),
        context.t('table.registrationDate'),
      ],
    );

    // Metinler await'ten önce çözülür: sonrasında `context` kullanmak widget
    // ağaçtan çıkmışsa geçersiz olur.
    final String locale = context.lang;
    final String subject = context.t(
      'clubEvents.excel.subject',
      <String, Object?>{'title': event.title},
    );
    final String preparing = context.t('clubEvents.excel.preparing');
    final String ready = context.t('clubEvents.excel.ready');
    final String failed = context.t('clubEvents.excel.error');

    // iPad'de paylaşım sayfası balon olarak açılıyor ve çıkış noktasını
    // istiyor; verilmezse uygulama çöker. Ekranın tamamını veriyoruz —
    // düğmenin kendi dikdörtgeni alt widget'ın içinde kalıyor ve iOS zaten
    // balonu bu alanın ortasına yerleştiriyor. Ölçüm await'ten ÖNCE
    // alınmalı: sonrasında widget ağaçtan çıkmış olabilir.
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? shareOrigin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await _run(() async {
      _setFeedback(preparing);
      try {
        await shareRegistrationsExcel(
          event: event,
          registrations: registrations,
          labels: labels,
          subject: subject,
          sharePositionOrigin: shareOrigin,
          locale: locale,
        );
        _setFeedback(ready, FeedbackTone.success);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  /// Kapı listesine en son yazılan kayıt listesi (aynı liste tekrar yazılmasın).
  List<EventRegistration>? _seededRegistrations;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppEvent?> eventAsync = ref.watch(
      clubEventProvider(widget.eventId),
    );

    final AppEvent? watched = eventAsync.value;

    // İP-O: etkinlik bir kez açıldıysa bilet listesi cihaza da yazılır;
    // kapıda internet olmasa da okutma çalışır.
    final DoorGate? doorGate = ref.watch(doorGateProvider).value;
    final List<EventRegistration>? liveRegs = ref
        .read(eventRegistrationsProvider(widget.eventId))
        .value;
    if (doorGate != null &&
        watched != null &&
        liveRegs != null &&
        !identical(liveRegs, _seededRegistrations)) {
      _seededRegistrations = liveRegs;
      doorGate.seedFromEvent(watched, liveRegs);
    }

    return ReadableScaffold(
      appBar: ClubAppBar(
        title: eventAsync.value?.title ?? context.t('clubEvents.title'),
        showBack: true,
      ),
      body: eventAsync.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('clubEvents.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (AppEvent? event) {
          if (event == null) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                EmptyState(
                  message: context.t('dashboard.alerts.eventNotFound'),
                ),
              ],
            );
          }
          _scheduleQuotaShardBackfill(event);

          // Kontenjan doluluğu canlı izlenir: dolduğu an etkinlik
          // kendiliğinden beklemeye alınır, yer açılınca geri açılır.
          final QuotaStatus quota =
              ref.watch(quotaStatusProvider(event.id)).value ??
              QuotaStatus.untracked;
          _scheduleQuotaStateSync(event, quota);

          return _Body(
            event: event,
            quota: quota,
            busy: _busy,
            feedback: _feedback,
            tone: _tone,
            onToggleRegistrations: () => _toggleRegistrations(event),
            onAdvanceSession: () => _advanceSession(event),
            onUndoSession: () => _undoSession(event),
            onReopenSessions: () => _reopenSessions(event),
            onShowSessionQr: () =>
                _showSessionQr(event.id, event.currentSession),
            onToggleDoorCheckin: () => _toggleDoorCheckin(event),
            onShowDoorQr: () => showDoorCheckinQrDialog(context, ref, event.id),
            onScanDoorCheckin: () => _openDoorScanner(event),
            onAllowSessionWithoutCheckin: (bool allow) =>
                _setAllowSessionWithoutCheckin(event, allow),
            onDownloadExcel: () => _downloadStudentsExcel(event),
            onSetPayment: (EventRegistration reg, bool paid) =>
                _setPayment(event, reg, paid),
            onRemoveRegistration: (EventRegistration reg) =>
                _removeRegistration(event, reg),
            onSetSessionAttendance:
                (EventRegistration reg, int session, bool present) =>
                    _setSessionAttendance(event, reg, session, present),
            onSessionCode: () => _sessionCodeEntry(event),
            onBlockStudent: _blockStudent,
            onAddSeats: () => _addSeats(event),
            selected: _selected,
            onToggleSelected: _toggleSelected,
            onReplaceSelection: _replaceSelection,
            onBulkMarkPaid: () => _bulkMarkPaid(event),
            onBulkRemove: () => _bulkRemove(event),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.event,
    required this.quota,
    required this.busy,
    required this.feedback,
    required this.tone,
    required this.onToggleRegistrations,
    required this.onAdvanceSession,
    required this.onUndoSession,
    required this.onReopenSessions,
    required this.onShowSessionQr,
    required this.onToggleDoorCheckin,
    required this.onShowDoorQr,
    required this.onScanDoorCheckin,
    required this.onAllowSessionWithoutCheckin,
    required this.onDownloadExcel,
    required this.onSetPayment,
    required this.onRemoveRegistration,
    required this.onSetSessionAttendance,
    required this.onSessionCode,
    required this.onBlockStudent,
    required this.onAddSeats,
    required this.selected,
    required this.onToggleSelected,
    required this.onReplaceSelection,
    required this.onBulkMarkPaid,
    required this.onBulkRemove,
  });

  final AppEvent event;

  /// Kontenjan doluluğu — parça sayaçlarından toplanır.
  final QuotaStatus quota;

  final bool busy;
  final String? feedback;
  final FeedbackTone tone;
  final VoidCallback onToggleRegistrations;
  final VoidCallback onAdvanceSession;
  final VoidCallback onUndoSession;
  final VoidCallback onReopenSessions;
  final VoidCallback onShowSessionQr;
  final VoidCallback onToggleDoorCheckin;
  final VoidCallback onShowDoorQr;
  final VoidCallback onScanDoorCheckin;
  final ValueChanged<bool> onAllowSessionWithoutCheckin;
  final VoidCallback onDownloadExcel;

  /// İP-K
  final void Function(EventRegistration reg, bool paid) onSetPayment;
  final ValueChanged<EventRegistration> onRemoveRegistration;

  /// İP-B5: elle yoklama + kodla oturum yoklaması.
  final void Function(EventRegistration reg, int session, bool present)
  onSetSessionAttendance;
  final VoidCallback onSessionCode;
  final ValueChanged<EventRegistration> onBlockStudent;
  final VoidCallback onAddSeats;

  /// Çoklu seçim
  final Set<String> selected;
  final void Function(String studentId, bool selected) onToggleSelected;
  final ValueChanged<Iterable<String>> onReplaceSelection;
  final VoidCallback onBulkMarkPaid;
  final VoidCallback onBulkRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EventRegistration>> registrations = ref.watch(
      eventRegistrationsProvider(event.id),
    );

    final List<EventRegistration> list =
        registrations.value ?? const <EventRegistration>[];

    final bool past = isPastEvent(event);

    // Belge kapısı: oturumlu etkinlikte "oturumlar bitti mi", tek oturumluda
    // "etkinlik bitti mi".

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        if (feedback != null) FeedbackBanner(message: feedback, tone: tone),
        // İP-K: iptal edilen etkinlik notu (gerekçeyle).
        if (event.cancelled) ...<Widget>[
          FeedbackBanner(
            message: event.cancelReason.isNotEmpty
                ? context.t(
                    'registration.club.cancelledBannerReason',
                    <String, Object?>{'reason': event.cancelReason},
                  )
                : context.t('registration.club.cancelledBanner'),
            tone: FeedbackTone.error,
          ),
          const SizedBox(height: 12),
        ],
        // İP-P2 / İP-KR: yönetici (1.000+) ya da kurum (SKS) onayı.
        if (!event.cancelled && (event.approvalStatus == 'pending' || event.approvalStatus == 'rejected')) ...<Widget>[
          FeedbackBanner(
            message: event.approvalStatus == 'rejected'
                ? context.t('approval.rejected', <String, Object?>{'reason': event.approvalRejectReason.isEmpty ? '-' : event.approvalRejectReason})
                : '${context.t('approval.title')}: ${context.t('approval.mobile.web')}',
            tone: FeedbackTone.warning,
          ),
          const SizedBox(height: 12),
        ] else if (!event.cancelled && (event.institutionApproval == 'pending' || event.institutionApproval == 'rejected')) ...<Widget>[
          FeedbackBanner(
            message: event.institutionApproval == 'rejected'
                ? context.t('approval.institutionRejected', <String, Object?>{'reason': event.institutionRejectReason.isEmpty ? '-' : event.institutionRejectReason})
                : context.t('approval.institutionPending'),
            tone: FeedbackTone.warning,
          ),
          const SizedBox(height: 12),
        ],

        ClipRRect(
          borderRadius: BorderRadius.circular(BrandShape.cardRadius),
          child: Stack(
            children: <Widget>[
              EventImage(url: event.displayImageUrl, height: 184),
              Positioned(
                left: 12,
                bottom: 12,
                child: EventDatePill(label: eventCardDate(context, event)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          event.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            StatusPill(
              label: eventStatus(context, event).label,
              tone: eventStatus(context, event).tone,
            ),
            StatusPill(
              label: eventScopeLabel(
                context,
                event.targetScope,
                linkOnly: event.isLinkOnly,
              ),
            ),
            StatusPill(label: eventFeeLabel(context, event)),
          ],
        ),
        const SizedBox(height: 20),

        SectionCard(
          title: context.t('eventModal.info'),
          icon: Icons.info_outline_rounded,
          child: EventInfoTable(rows: eventInfoRows(context, event)),
        ),
        // İP-P1: program + oturum başına katılan sayısı.
        if (event.isMultiSession) ...<Widget>[
          const SizedBox(height: 16),
          SectionCard(
            title: context.t('program.title'),
            icon: Icons.view_agenda_outlined,
            child: EventProgramSection(
              event: event,
              registrations: list,
              showTitle: false,
            ),
          ),
        ],

        // İP-EL: etkinlik linki (kopyala/paylaş/QR afişi/özel ad).
        if (!event.cancelled) ...<Widget>[
          const SizedBox(height: 16),
          SectionCard(
            title: context.t('eventLink.card.title'),
            icon: Icons.link_rounded,
            child: ClubEventLinkCard(event: event),
          ),
        ],

        // ── Kayıtlar ───────────────────────────────────────────────
        const SizedBox(height: 16),
        SectionCard(
          title: context.t('clubEvents.registrations.title'),
          icon: Icons.how_to_reg_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Kontenjan doluluğu. Kayıt kartının ÜSTÜNDE duruyor: kulüp
              // "kayıtları durdur" düğmesine bakmadan önce durdurulacak bir şey
              // kalıp kalmadığını görmeli.
              if (quota.isTracked) ...<Widget>[
                _QuotaMeter(quota: quota, event: event),
                const SizedBox(height: 12),
              ],
              // İP-K: bekleme listesi + "+5 yer aç".
              if (quota.isTracked && !past && !event.cancelled)
                _WaitlistRow(
                  eventId: event.id,
                  full: quota.isFull,
                  busy: busy,
                  onAddSeats: onAddSeats,
                ),
              _ActionCard(
                icon: past ? Icons.lock_outline : Icons.how_to_reg_outlined,
                title: past
                    ? context.t('clubEvents.registrations.pastLabel')
                    : event.registrationClosed
                    ? context.t('clubEvents.registrations.openAction')
                    : context.t('clubEvents.registrations.closeAction'),
                subtitle: context.t('clubEvents.registrations.subtitle'),
                // Sağdaki simge kartın ne yapacağını söyler: ">" her karta konan
                // "ileri git" işaretiydi, oysa bu kart bir yere götürmüyor —
                // kayıtları o anda durduruyor (ya da yeniden başlatıyor).
                trailingIcon: event.registrationClosed
                    ? Icons.play_circle_outline
                    : Icons.stop_circle_outlined,
                // Süresi geçmiş etkinlikte kayıtlar iki yönde de değiştirilemez.
                onPressed: past || busy ? null : onToggleRegistrations,
                danger: !event.registrationClosed,
              ),
            ],
          ),
        ),

        // ── Kapı check-in'i ────────────────────────────────────────
        // Ölçüt oturum sayısı değil MODDUR: "Check-in + Yoklama" modunda
        // etkinlik çok oturumlu olduğu hâlde kapıda bir check-in adımı vardır.
        // Eski kayıtlarda mod oturum sayısından türetilir, davranış değişmez.
        //
        // Öncelikli yol kamerayla okutmaktır: görevli öğrencinin biletini
        // tarar. QR ekranı (öğrencinin kendi telefonundan kapıdaki ortak kodu
        // okutması) isteyen kulüpler için burada "Göster" düğmesiyle elle
        // açılan, ikinci planda bir seçenek olarak durur — otomatik açılmaz.
        if (event.hasDoorCheckin) ...<Widget>[
          const SizedBox(height: 16),
          SectionCard(
            title: context.t('clubEvents.entry.title'),
            icon: Icons.door_front_door_outlined,
            child: _CheckinStageBar(
              event: event,
              // Kapı, son kayıt tarihi geçse de etkinlik günü boyunca açık
              // kalmalı (web ile aynı): yalnızca etkinlik günü bitince kilitlenir.
              busy: busy || getClubEventStage(event) == ClubEventStage.past,
              attended: list
                  .where((EventRegistration r) => r.isCheckedIn)
                  .length,
              total: list.length,
              onToggle: onToggleDoorCheckin,
              onShowQr: onShowDoorQr,
              onScan: onScanDoorCheckin,
            ),
          ),
        ],

        // ── Oturumlar ──────────────────────────────────────────────
        if (event.isMultiSession) ...<Widget>[
          const SizedBox(height: 16),
          SectionCard(
            title: context.t('clubEvents.session.title'),
            icon: Icons.fact_check_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SessionPanel(
                  event: event,
                  busy: busy,
                  // İLK oturum, kapı check-in'i bitirilene kadar başlatılamaz:
                  // kimin içeride olduğu henüz belli değildir ve erken başlatılan
                  // bir oturum, kapıda check-in yapmamış öğrencileri yoklamada
                  // reddeder (bkz. domain/checkin_mode.dart).
                  sessionsLockedByDoor: event.doorCheckinBlocksSessions,
                  onAdvance: onAdvanceSession,
                  onUndo: onUndoSession,
                  onReopen: onReopenSessions,
                  onShowQr: onShowSessionQr,
                ),
                // İP-B5: o anki oturuma bilet koduyla yoklama.
                if (event.currentSession >= 1 &&
                    !event.sessionsCompleted &&
                    !event.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: const Key('sessionCodeEntry'),
                      icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                      label: Text(context.t('manualAttendance.codeTitle')),
                      onPressed: busy ? null : onSessionCode,
                    ),
                  ),
                if (event.hasDoorCheckin)
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      context.t('clubEvents.session.allowWithoutCheckin'),
                    ),
                    subtitle: Text(
                      context.t('clubEvents.session.allowWithoutCheckinHint'),
                    ),
                    value: event.allowSessionWithoutCheckin,
                    onChanged: busy ? null : onAllowSessionWithoutCheckin,
                  ),
              ],
            ),
          ),
        ],

        // ── Belge ──────────────────────────────────────────────────
        // Bölüm oturum sayısından bağımsız: tek oturumlu etkinlikte de kulüp
        // belge dağıtır, algoritma birebir aynıdır. Değişen yalnızca kapının
        // ne zaman açıldığı — oturumluda kulüp oturumları bitirince, tek
        // oturumluda etkinlik bitince (bkz. `canDistributeCertificates`).
        // İP-B: otomatik bildirimlerin durumu + kulübün elle mesajı.
        const SizedBox(height: 16),
        SectionCard(
          title: context.t('eventNotify.title'),
          icon: Icons.notifications_active_outlined,
          // İP-P1: özel bildirim Ücretsiz pakette yok (otomatik hatırlatmalar sürer).
          child: planFeatureAllowed(event.planTier, 'messages')
              ? EventNotifyCard(event: event, compact: true)
              : PlanLockNote(feature: 'messages'),
        ),

        // İP-R: etkinlik raporu (PDF + Excel). İP-P1: Ücretsiz pakette yok.
        const SizedBox(height: 16),
        if (planFeatureAllowed(event.planTier, 'reportFile'))
          EventReportCard(event: event)
        else
          SectionCard(
            title: context.t('plan.feature.reportFile'),
            icon: Icons.description_outlined,
            child: PlanLockNote(feature: 'reportFile'),
          ),

        // İP-D: etkinlik bitince katılımcıların kimliksiz değerlendirmesi.
        if (!event.cancelled &&
            eventFeedbackEnded(
              event,
              DateTime.now().millisecondsSinceEpoch,
            )) ...<Widget>[
          const SizedBox(height: 16),
          EventFeedbackSummaryCard(event: event),
        ],

        // İP-8: yeni sertifika paneli. Belge webde ayarlanır (editör yalnızca
        // webde); burada gönder / geri al / eşik. Eski yükleme akışı kaldırıldı.
        const SizedBox(height: 16),
        SectionCard(
          title: context.t('cert.panel.title'),
          icon: Icons.workspace_premium_outlined,
          // İP-P1: Ücretsiz pakette isme özel belge yok; hazır belge webden paylaşılır.
          child: planFeatureAllowed(event.planTier, 'certificates')
              ? CertificatePanelCard(event: event, registrations: list)
              : Text(
                  context.t('plan.cert.freeHelp'),
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: context.inkMuted),
                ),
        ),

        // ── Ücretli etkinlik onay kaydı ────────────────────────────
        // Yalnızca ücretli etkinlikte görünür: kulübün oluşturma anında,
        // öğrencilerin kayıt anında onayladığı metnin işlem logu.
        if (event.isPaid) ...<Widget>[
          const SizedBox(height: 16),
          SectionCard(
            title: context.t('paidEventConsent.log.title'),
            icon: Icons.verified_user_outlined,
            child: _PaidEventConsentLogCard(event: event, registrations: list),
          ),
        ],

        // ── Katılımcılar ───────────────────────────────────────────
        const SizedBox(height: 28),
        Row(
          children: <Widget>[
            Expanded(
              child: EventSectionTitle(context.t('clubEvents.students.title')),
            ),
            StatusPill(label: '${list.length}'),
          ],
        ),
        const SizedBox(height: 12),

        // "Tabloda Gör" kaldırıldı: aynı kayıtlar zaten hemen aşağıda, tüm
        // bilgileriyle listeleniyordu — düğme kulübü aynı listenin ikinci bir
        // kopyasına götürmekten başka bir iş yapmıyordu. Excel dışa aktarma
        // kaldı, o listede olmayan bir şey veriyor.
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: list.isEmpty || busy ? null : onDownloadExcel,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(
              context.t('clubEvents.students.downloadExcel'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (registrations.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingView(),
          )
        else if (list.isEmpty)
          EmptyState(
            message: context.t('clubEvents.students.empty'),
            icon: Icons.person_off_outlined,
          )
        else ...<Widget>[
          if (!past && !event.cancelled)
            _BulkBar(
              event: event,
              registrations: list,
              selected: selected,
              busy: busy,
              onReplaceSelection: onReplaceSelection,
              onMarkPaid: onBulkMarkPaid,
              onRemove: onBulkRemove,
            ),
          for (final EventRegistration reg in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentTile(
                registration: reg,
                event: event,
                locked: past || event.cancelled || busy,
                selectable: !past && !event.cancelled,
                selected: selected.contains(reg.studentId),
                onSelected: (bool value) =>
                    onToggleSelected(reg.studentId, value),
                onSetPayment: (bool paid) => onSetPayment(reg, paid),
                onRemove: () => onRemoveRegistration(reg),
                onSetSessionAttendance: event.cancelled || busy
                    ? null
                    : (int session, bool present) =>
                          onSetSessionAttendance(reg, session, present),
                onBlock: busy ? null : () => onBlockStudent(reg),
              ),
            ),
        ],
      ],
    );
  }
}

/// Oturum durumu ve ilerletme çubuğu (club-events.js#updateSessionControls).
///
/// İlerleme artık "2/4" gibi bir metinle değil, oturum sayısı kadar bölmesi
/// olan bir çubukla anlatılıyor: kulüp ekrana bir kez bakınca kaçıncı oturumda
/// olduğunu ve ne kadar kaldığını görüyor.
/// Kapı check-in'inin üç aşamalı kontrol çubuğu
/// (club-events.js#updateCheckinControls karşılığı).
///
/// Süreç bilerek üç adımdır ve sırası zorunludur:
///
///   1. **Check-in'i Başlat** → `entryOpen = true` (+ ilk kez `entryStartedAtMs`)
///   2. Öğrenciler kapıdaki QR'ı okutur ya da biletini görevliye gösterir
///   3. **Check-in'i Bitir** → `entryOpen = false`
///
/// Ancak 3. adımdan sonra oturumlar başlatılabilir; sebebi
/// `domain/checkin_mode.dart > doorCheckinBlocksSessionsFor` içinde yazıyor.
///
/// "Yeniden Başlat" **veriyi sıfırlamaz**: okunan girişler kayıtlarda durur
/// (`checkedInAtMs` bir kez yazılır), yeni okutulanlar üzerine eklenir.
///
/// Bu üç aşama yalnızca kulüp oturumları en başa (0'a) kadar geri alırsa
/// [CheckinStage.notStarted]'a döner — o zaman etkinlik gerçekten "hiç
/// başlamamış" sayılır ve keşfe geri düşer (bkz.
/// `EventRepository.advanceSession`, `domain/event_utils.dart >
/// eventHasStarted`).
class _CheckinStageBar extends StatelessWidget {
  const _CheckinStageBar({
    required this.event,
    required this.busy,
    required this.attended,
    required this.total,
    required this.onToggle,
    required this.onShowQr,
    required this.onScan,
  });

  final AppEvent event;
  final bool busy;

  /// Kapıda girişi alınmış öğrenci sayısı / toplam kayıt.
  final int attended;
  final int total;

  final VoidCallback onToggle;
  final VoidCallback onShowQr;

  /// Görevlinin öğrenci biletini kamerayla okutacağı ekranı açar — kapı
  /// check-in'inin varsayılan, birincil yolu.
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final CheckinStage? stage = event.checkinStage;
    // Kapı check-in'i olmayan modda çubuk hiç çizilmez (çağıran zaten
    // `hasDoorCheckin` ile koruyor; bu yalnızca güvenli varsayılan).
    if (stage == null) return const SizedBox.shrink();

    final String tally = total > 0
        ? context.t('clubEvents.entry.tally', <String, Object?>{
            'attended': attended,
            'total': total,
          })
        : '';

    final (IconData icon, String info, String action) = switch (stage) {
      CheckinStage.notStarted => (
        Icons.door_front_door_outlined,
        context.t('clubEvents.entry.stateNotStarted'),
        context.t('clubEvents.entry.start'),
      ),
      CheckinStage.running => (
        Icons.sensor_door_outlined,
        '${context.t('clubEvents.entry.stateRunning')}$tally',
        context.t('clubEvents.entry.finish'),
      ),
      CheckinStage.finished => (
        Icons.check_circle_outline,
        '${context.t('clubEvents.entry.stateFinished')}$tally',
        context.t('clubEvents.entry.restart'),
      ),
    };

    final bool running = stage == CheckinStage.running;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 19,
                color: stage == CheckinStage.finished
                    ? BrandColors.success
                    : context.brandInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kapı açıkken asıl iş görevlinin öğrenci biletini kamerayla
          // okutmasıdır. QR'ı ekranda göstermek — öğrencinin kendi
          // telefonundan kapıdaki ortak kodu okutması — isteyen kulüpler
          // için ikinci planda, elle açılan bir seçenek olarak kalır; "Bitir"
          // ise en geride durur ki yanlışlıkla basılmasın.
          if (running) ...<Widget>[
            FilledButton.icon(
              onPressed: busy ? null : onScan,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(context.t('clubEvents.scan.action')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onShowQr,
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: Text(context.t('clubEvents.entry.show')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onToggle,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(action),
            ),
          ] else ...<Widget>[
            FilledButton.icon(
              onPressed: busy ? null : onToggle,
              icon: Icon(
                stage == CheckinStage.finished
                    ? Icons.restart_alt
                    : Icons.play_circle_outline,
                size: 18,
              ),
              label: Text(action),
            ),
            // Bitmiş kapıda da görevli geç gelen öğrenciyi kamerayla
            // okutabilsin diye seçenek burada da durur.
            if (stage == CheckinStage.finished) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onScan,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(context.t('clubEvents.scan.action')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({
    required this.event,
    required this.busy,
    required this.sessionsLockedByDoor,
    required this.onAdvance,
    required this.onUndo,
    required this.onReopen,
    required this.onShowQr,
  });

  final AppEvent event;
  final bool busy;
  final bool sessionsLockedByDoor;
  final VoidCallback onAdvance;
  final VoidCallback onUndo;
  final VoidCallback onReopen;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final int current = event.currentSession;
    final int total = event.sessionCount;
    final bool done = event.sessionsCompleted;

    final String info;
    final String? actionLabel;

    if (done) {
      info = context.t('clubEvents.session.stateAllDone');
      actionLabel = null;
    } else if (current < 1) {
      info = sessionsLockedByDoor
          ? context.t('clubEvents.session.blockedByCheckin')
          : context.t('clubEvents.session.stateNotStarted');
      actionLabel = context.t('clubEvents.session.start');
    } else if (current < total) {
      info = context.t('clubEvents.session.stateActive');
      actionLabel = context.t('clubEvents.session.advanceNext');
    } else {
      info = context.t('clubEvents.session.stateLastActive');
      actionLabel = context.t('clubEvents.session.finish');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                done ? Icons.check_circle_outline : Icons.repeat,
                size: 19,
                color: done ? BrandColors.success : context.brandInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SessionProgressBar(
            total: total,
            completed: done ? total : current,
            done: done,
          ),
          const SizedBox(height: 14),
          if (actionLabel != null)
            FilledButton.icon(
              // Kilit yalnızca YENİ oturum başlatmayı kapatır; başlamış bir
              // etkinliği ilerletmek hiçbir zaman kilitlenmez.
              onPressed: busy || sessionsLockedByDoor ? null : onAdvance,
              icon: Icon(
                current >= total ? Icons.flag_outlined : Icons.skip_next,
                size: 18,
              ),
              label: Text(actionLabel),
            ),
          // Yanlışlıkla ilerletilen oturumun tek çıkış yolu. Geri alınca eski
          // oturumun QR'ı yeniden geçerli olur ve kendiliğinden ekrana gelir.
          if (current >= 1 && !done) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onUndo,
              icon: const Icon(Icons.undo, size: 18),
              label: Text(context.t('clubEvents.session.undo')),
            ),
          ],
          // Oturumlar bitirildikten sonra tek çıkış yolu: yanlışlıkla
          // bitirildiğinde ya da geç gelen öğrenci yoklamaya alınacağında
          // kulüp oturumları geri açabilsin.
          if (done)
            OutlinedButton.icon(
              onPressed: busy ? null : onReopen,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(context.t('clubEvents.session.reopen')),
            ),
          // Aktif oturum varken QR tekrar gösterilebilir.
          if (current >= 1 && !done) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onShowQr,
              icon: const Icon(Icons.qr_code_2),
              label: Text(context.t('clubEvents.session.showQr')),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kontenjan doluluk göstergesi.
///
/// Kulübün "kaç kişi kaldı" sorusunun tek yanıtı burası: kayıt sayısını
/// katılımcı listesini açıp saymak gerekiyordu. Dolduğunda etkinliğin
/// kendiliğinden beklemeye alındığı da burada söylenir — aksi hâlde kulüp,
/// kayıtları kendisinin durdurmadığı hâlde neden kapalı olduğunu anlamaz.
class _QuotaMeter extends StatelessWidget {
  const _QuotaMeter({required this.quota, required this.event});

  final QuotaStatus quota;
  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final bool full = quota.isFull;
    final bool autoPaused =
        event.registrationClosed &&
        event.registrationClosedReason == ClosedReason.quotaFull;

    // Dolmaya yaklaşırken markanın kırmızısı, dolunca koyu kırmızı: ayrı bir
    // "uyarı sarısı" temada yok ve tek bir etkinlik kartı için palet
    // genişletmeye değmez.
    final Color accent = full
        ? BrandColors.danger
        : quota.percent >= 80
        ? BrandColors.red
        : BrandColors.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                full ? Icons.pause_circle_outline : Icons.groups_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('clubEvents.quota.title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${quota.used} / ${quota.capacity}',
                style: TextStyle(fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: quota.percent / 100,
              minHeight: 7,
              backgroundColor: context.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            autoPaused
                ? context.t('clubEvents.quota.autoPaused')
                : full
                ? context.t('clubEvents.quota.full')
                : context.t('clubEvents.quota.remaining', <String, Object?>{
                    'count': quota.remaining,
                  }),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: full ? accent : context.inkMuted,
              fontWeight: full ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.trailingIcon = Icons.chevron_right,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  /// Sağ uçtaki simge. Varsayılan ">" yalnızca başka bir ekrana götüren
  /// kartlar için doğru; yerinde iş yapan kartlar kendi simgesini verir.
  final IconData trailingIcon;

  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color accent = danger ? BrandColors.danger : context.brandInk;

    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            border: Border.all(color: context.hairline),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 21, color: enabled ? accent : context.inkMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: enabled ? context.ink : context.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Kapalı kartlarda da simge çizilir (soluk): kilit simgesi
              // kartın neden tepki vermediğini söyleyen tek işaret.
              if (enabled || trailingIcon != Icons.chevron_right)
                Icon(
                  trailingIcon,
                  color: !enabled
                      ? context.inkMuted
                      : trailingIcon == Icons.chevron_right
                      ? context.inkMuted
                      : accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Katılımcı satırı (club-events.js#renderStudentsTable).

/// Ücretli etkinliğin onay işlem logu — YALNIZCA ücretli etkinlikte çizilir.
///
/// İki kayıt bir arada gösterilir:
///   • kulübün etkinliği oluştururken onayladığı metin (etkinlik belgesinde),
///   • kaydolan her öğrencinin onayladığı metin (kaydın kendi belgesinde).
///
/// Damga `formatPaidEventConsentStamp` ile yazıldığı gibi gösterilir:
/// gün.ay.yıl saat:dakika:saniye. Metinler uzun olduğu için katlanır durur;
/// dokununca açılır.
class _PaidEventConsentLogCard extends StatefulWidget {
  const _PaidEventConsentLogCard({
    required this.event,
    required this.registrations,
  });

  final AppEvent event;
  final List<EventRegistration> registrations;

  @override
  State<_PaidEventConsentLogCard> createState() =>
      _PaidEventConsentLogCardState();
}

class _PaidEventConsentLogCardState extends State<_PaidEventConsentLogCard> {
  /// Metni açılmış kayıtlar. Kulüp onayı için `club`, öğrenciler için kayıt
  /// kimliği tutulur.
  final Set<String> _expanded = <String>{};

  void _toggle(String key) => setState(
    () => _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key),
  );

  @override
  Widget build(BuildContext context) {
    final PaidEventConsentLog? clubLog = widget.event.clubConsentLog;

    // Onay veren öğrenciler: onaysız (ücretli etkinlik alanları eklenmeden
    // önce yapılmış) kayıtlar listede yer almaz, sayı da onları saymaz.
    final List<EventRegistration> consented =
        widget.registrations
            .where((EventRegistration r) => r.studentConsentLog != null)
            .toList()
          ..sort(
            (EventRegistration a, EventRegistration b) =>
                b.studentConsentLog!.atMs.compareTo(a.studentConsentLog!.atMs),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t('paidEventConsent.log.club'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          if (clubLog == null)
            Text(
              context.t('paidEventConsent.log.missing'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            _ConsentLogRow(
              log: clubLog,
              label: widget.event.clubName,
              expanded: _expanded.contains('club'),
              onToggle: () => _toggle('club'),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.t('paidEventConsent.log.students'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              StatusPill(label: '${consented.length}'),
            ],
          ),
          const SizedBox(height: 6),
          if (consented.isEmpty)
            Text(
              context.t('paidEventConsent.log.studentsEmpty'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final EventRegistration reg in consented)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ConsentLogRow(
                  log: reg.studentConsentLog!,
                  label: reg.displayName,
                  expanded: _expanded.contains(reg.id),
                  onToggle: () => _toggle(reg.id),
                ),
              ),
          const SizedBox(height: 10),
          Text(
            context.t('paidEventConsent.log.note'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: context.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir onay satırı: kim, ne zaman — ve istenirse metnin tamamı.
class _ConsentLogRow extends StatelessWidget {
  const _ConsentLogRow({
    required this.log,
    required this.label,
    required this.expanded,
    required this.onToggle,
  });

  final PaidEventConsentLog log;
  final String label;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String who = label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.verified_outlined, size: 15, color: context.inkMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                who,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  context.t(
                    expanded
                        ? 'paidEventConsent.log.hideText'
                        : 'paidEventConsent.log.showText',
                  ),
                  style: TextStyle(fontSize: 11.5, color: context.inkMuted),
                ),
              ),
            ),
          ],
        ),
        _Line(icon: Icons.schedule, text: log.stamp),
        if (expanded) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.isDarkMode
                  ? BrandColors.infoBgDark
                  : BrandColors.infoBg,
              borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  log.text.isNotEmpty
                      ? log.text
                      : context.t('paidEventConsent.log.legacyText'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.registration,
    required this.event,
    required this.locked,
    required this.onSetPayment,
    required this.onRemove,
    this.onBlock,
    this.onSetSessionAttendance,
    this.selectable = false,
    this.selected = false,
    this.onSelected,
  });

  final EventRegistration registration;
  final AppEvent event;

  /// Çoklu seçim kutusu (geçmiş/iptal etkinlikte yok).
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  /// İP-K: geçmiş/iptal edilmiş etkinlikte ödeme ve silme düğmeleri gizli.
  final bool locked;
  final ValueChanged<bool> onSetPayment;
  final VoidCallback onRemove;

  /// İP-KB: kulüpten engelle (geçmiş etkinlikte de; null = meşgul).
  final VoidCallback? onBlock;

  /// İP-B5: oturuma elle "var" / geri al (null = kapalı).
  final void Function(int session, bool present)? onSetSessionAttendance;

  @override
  Widget build(BuildContext context) {
    final bool checkedIn = registration.isCheckedIn;

    // İP-Y: şüpheli yoklama (sunucu işaretleri + eski sürümden, sunucudan
    // geçmeden yazılmış giriş/yoklama).
    final String suspicious =
        attendanceSuspicions(
              flags: registration.attendanceFlags,
              verified: registration.attendanceVerified,
              checkedInVia: registration.checkedInVia,
              lastAttendedSession: registration.lastAttendedSession,
            )
            .map(
              (({int stage, String key}) s) =>
                  '${s.stage == 0 ? context.t('attendance.stage.door') : context.t('attendance.stage.session', <String, Object?>{'n': s.stage})}: ${context.t(s.key)}',
            )
            .join(' · ');

    final bool hasCertificate =
        event.isMultiSession &&
        event.certificateThresholdPercent != null &&
        (registration.sessionsAttended / event.sessionCount) * 100 >=
            event.certificateThresholdPercent!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: selected
            ? Border.all(color: BrandColors.red, width: 1.5)
            : Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (selectable)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: selected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: locked
                          ? null
                          : (bool? value) => onSelected?.call(value ?? false),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  registration.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (event.isMultiSession)
                StatusPill(
                  label:
                      '${registration.sessionsAttended}/${event.sessionCount}',
                  tone: hasCertificate
                      ? FeedbackTone.success
                      : FeedbackTone.info,
                )
              else
                StatusPill(
                  label: checkedIn
                      ? context.t('clubEvents.students.checkedIn')
                      : context.t('clubEvents.students.registered'),
                  tone: checkedIn ? FeedbackTone.success : FeedbackTone.info,
                ),
            ],
          ),
          if (event.isMultiSession)
            _SessionChips(
              registration: registration,
              event: event,
              onSet: onSetSessionAttendance,
            ),
          const SizedBox(height: 6),
          _Line(icon: Icons.mail_outline, text: registration.studentEmail),
          // Kapıda telefonu çalışmayan katılımcı için: görevli kodu listeden
          // bulup "Kodu elle gir" ile içeri alabilir.
          if (registration.ticketCode.isNotEmpty)
            _Line(
              icon: Icons.confirmation_number_outlined,
              text:
                  '${context.t('ticket.codeLabel')}: '
                  '${formatTicketCode(registration.ticketCode)}',
            ),
          if (registration.studentPhone.isNotEmpty)
            _Line(icon: Icons.phone_outlined, text: registration.studentPhone),
          _Line(
            icon: Icons.account_balance_outlined,
            text: <String>[
              if (registration.studentUniversity.isNotEmpty)
                registration.studentUniversity,
              if (registration.studentDepartment.isNotEmpty)
                registration.studentDepartment,
              if (registration.studentClassYear.isNotEmpty)
                registration.studentClassYear,
            ].join(' • '),
          ),
          _Line(
            icon: Icons.schedule,
            text: formatDateTime(
              registration.registeredAtMs,
              locale: context.lang,
            ),
          ),
          // İP-K: ödeme durumu + "Ödendi" anahtarı (ücretli etkinlik).
          if (event.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    registration.paymentPendingFor(event)
                        ? Icons.hourglass_top_outlined
                        : Icons.check_circle_outline,
                    size: 16,
                    color: registration.paymentPendingFor(event)
                        ? const Color(0xFF9A5B00)
                        : BrandColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      registration.paymentPendingFor(event)
                          ? context.t('registration.status.paymentPending')
                          : context.t('registration.club.paid'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!locked)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          onSetPayment(registration.paymentPendingFor(event)),
                      child: Text(
                        registration.paymentPendingFor(event)
                            ? context.t('registration.club.markPaid')
                            : context.t('registration.club.unmarkPaid'),
                      ),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: <Widget>[
                if (!locked)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.danger,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onRemove,
                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                    label: Text(context.t('registration.club.removeAction')),
                  ),
                TextButton.icon(
                  key: const Key('clubBlockStudentButton'),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onBlock,
                  icon: const Icon(Icons.block_outlined, size: 18),
                  label: Text(context.t('clubBlock.action')),
                ),
              ],
            ),
          ),
          if (suspicious.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: BrandColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${context.t('attendance.suspicious.title')}: $suspicious',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Çoklu seçim çubuğu: tümünü seç / temizle, ödeme bekleyenleri seç,
/// seçilenleri "Ödendi" yap, seçilenlerin kaydını sil.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.event,
    required this.registrations,
    required this.selected,
    required this.busy,
    required this.onReplaceSelection,
    required this.onMarkPaid,
    required this.onRemove,
  });

  final AppEvent event;
  final List<EventRegistration> registrations;
  final Set<String> selected;
  final bool busy;
  final ValueChanged<Iterable<String>> onReplaceSelection;
  final VoidCallback onMarkPaid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final List<EventRegistration> chosen = registrations
        .where((EventRegistration r) => selected.contains(r.studentId))
        .toList(growable: false);
    final List<String> pendingIds = event.isPaid
        ? registrations
              .where((EventRegistration r) => r.paymentPendingFor(event))
              .map((EventRegistration r) => r.studentId)
              .toList(growable: false)
        : const <String>[];
    final int chosenPending = chosen
        .where((EventRegistration r) => r.paymentPendingFor(event))
        .length;
    final bool allSelected =
        chosen.length == registrations.length && registrations.isNotEmpty;
    final ButtonStyle compact = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            chosen.isEmpty
                ? context.t('registration.bulk.hint')
                : context.t('registration.bulk.selected', <String, Object?>{
                    'n': chosen.length,
                  }),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                style: compact,
                onPressed: busy
                    ? null
                    : () => onReplaceSelection(
                        allSelected
                            ? const <String>[]
                            : registrations.map(
                                (EventRegistration r) => r.studentId,
                              ),
                      ),
                child: Text(
                  context.t(
                    allSelected
                        ? 'registration.bulk.clear'
                        : 'registration.bulk.selectAll',
                  ),
                ),
              ),
              if (event.isPaid)
                OutlinedButton(
                  style: compact,
                  onPressed: busy || pendingIds.isEmpty
                      ? null
                      : () => onReplaceSelection(pendingIds),
                  child: Text(
                    context.t(
                      'registration.bulk.selectPending',
                      <String, Object?>{'n': pendingIds.length},
                    ),
                  ),
                ),
              if (event.isPaid)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: busy || chosenPending == 0 ? null : onMarkPaid,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    context.t('registration.bulk.markPaidN', <String, Object?>{
                      'n': chosenPending,
                    }),
                  ),
                ),
              OutlinedButton.icon(
                style: compact.copyWith(
                  foregroundColor: const WidgetStatePropertyAll<Color>(
                    BrandColors.danger,
                  ),
                ),
                onPressed: busy || chosen.isEmpty ? null : onRemove,
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: Text(
                  context.t('registration.bulk.removeN', <String, Object?>{
                    'n': chosen.length,
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: context.inkMuted),
          const SizedBox(width: 7),
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
}

/// İP-K: bekleme listesi satırı ve "+5 yer aç".
/// Kontenjan doluysa ya da bekleyen varsa görünür.
class _WaitlistRow extends ConsumerWidget {
  const _WaitlistRow({
    required this.eventId,
    required this.full,
    required this.busy,
    required this.onAddSeats,
  });

  final String eventId;
  final bool full;
  final bool busy;
  final VoidCallback onAddSeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(eventWaitlistCountProvider(eventId)).value ?? 0;
    if (!full && count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          border: Border.all(color: context.hairline),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.hourglass_empty_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count > 0
                    ? context.t(
                        'registration.club.waitlistCount',
                        <String, Object?>{'count': count},
                      )
                    : context.t('registration.club.waitlistEmpty'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton(
              // Temadaki `Size.fromHeight(48)` Row içinde sonsuz genişlik ister.
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: busy ? null : onAddSeats,
              child: Text(
                context.t('registration.club.addSeats', <String, Object?>{
                  'n': 5,
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// İP-B5: oturum oturum katılım. ✓ = QR, ! = elle; boşa dokununca elle "var",
/// elle işarete dokununca geri al. Henüz başlamamış oturum soluk.
class _SessionChips extends StatelessWidget {
  const _SessionChips({
    required this.registration,
    required this.event,
    required this.onSet,
  });

  final EventRegistration registration;
  final AppEvent event;
  final void Function(int session, bool present)? onSet;

  @override
  Widget build(BuildContext context) {
    final int count = event.sessionCount < 1 ? 1 : event.sessionCount;
    final ({List<int> sessions, List<int> manual, bool exact}) att =
        resolveAttendedSessions(registration, count);
    final int reached = lastReachedSession(event);
    Widget chip(int n) {
      final bool manual = att.manual.contains(n);
      final bool inn = att.sessions.contains(n);
      final bool future = n > reached;
      final Color border = manual
          ? const Color(0xFFF0B65A)
          : inn
          ? const Color(0xFF9FD5B4)
          : context.hairline;
      final Color fg = manual
          ? const Color(0xFF8A5300)
          : inn
          ? BrandColors.success
          : context.inkMuted;
      final VoidCallback? tap = onSet == null || future || (inn && !manual)
          ? null
          : () => onSet!(n, !manual);
      return Opacity(
        opacity: future ? 0.45 : 1,
        child: InkWell(
          key: Key('att-${registration.studentId}-$n'),
          borderRadius: BorderRadius.circular(999),
          onTap: tap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 30),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Text(
              manual ? '$n!' : (inn ? '$n✓' : '$n'),
              style: TextStyle(fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[for (int n = 1; n <= count; n++) chip(n)],
          ),
          if (!att.exact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.t('manualAttendance.uncertain'),
                style: TextStyle(fontSize: 12, color: context.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
