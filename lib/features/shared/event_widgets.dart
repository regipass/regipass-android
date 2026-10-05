import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../domain/event_utils.dart';
import '../../domain/paid_event_consent.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../state/providers.dart';
import 'common_widgets.dart';

/// Etkinlik kartı ve detay penceresinin ortak parçaları.
///
/// Öğrenci ve kulüp tarafı aynı etkinlik verisini gösteriyor; tek fark alt
/// eylem çubuğu (öğrencide kayıt, kulüpte yönetim). Bu yüzden görsel yapı
/// burada bir kez kuruluyor, eylemler dışarıdan veriliyor.

/// dashboard.js#getScopeLabel
String eventScopeLabel(BuildContext context, String targetScope) =>
    switch (targetScope) {
      TargetScope.universityDepartment => context.t('dashboard.scope.department'),
      'department' => context.t('dashboard.scope.departmentOnly'),
      'university' => context.t('dashboard.scope.university'),
      _ => context.t('dashboard.scope.all'),
    };

/// dashboard.js#getPriorityLabel
String eventPriorityLabel(BuildContext context, int priority) =>
    switch (priority) {
      -1 => context.t('dashboard.priority.followed'),
      0 => context.t('dashboard.priority.departmentUniversity'),
      1 => context.t('dashboard.priority.university'),
      2 => context.t('dashboard.priority.departmentRelated'),
      _ => context.t('dashboard.priority.general'),
    };

/// club-events.js#getStatusLabel — üç durum: geçmiş / kapalı / açık.
({String label, FeedbackTone tone}) eventStatus(
  BuildContext context,
  AppEvent event,
) {
  // İP-K: iptal edildi / kontenjan kuruluyor / dolu (bekleme listesi).
  if (event.cancelled) {
    return (
      label: context.t('registration.status.cancelled'),
      tone: FeedbackTone.error,
    );
  }
  if (isPastEvent(event)) {
    return (
      label: context.t('dashboard.status.expired'),
      tone: FeedbackTone.error,
    );
  }
  if (event.quotaSetupPending) {
    return (
      label: context.t('registration.club.quotaSetupStatus'),
      tone: FeedbackTone.warning,
    );
  }
  if (event.seatsFull && !event.registrationClosed) {
    return (
      label: context.t('registration.status.fullWaitlist'),
      tone: FeedbackTone.warning,
    );
  }
  if (event.registrationClosed) {
    return (
      label: context.t('clubEvents.status.closed'),
      tone: FeedbackTone.info,
    );
  }
  return (
    label: context.t('dashboard.status.open'),
    tone: FeedbackTone.success,
  );
}

/// Ücret metni — `feeType`/`feeAmount`'tan üretilir.
///
/// `feeInfo` serbest metin olarak saklanıyor ve eski etkinliklerde Türkçe
/// karakter olmadan ("Ucretsiz") ya da yazıldığı dilde kalıyor. Ekranda her
/// zaman o anki dile göre gösterilsin diye ücretsiz etkinlikte çeviri, ücretli
/// etkinlikte tutar yazılır; tutar yoksa kulübün yazdığı metne düşülür.
String eventFeeLabel(BuildContext context, AppEvent event) {
  if (event.isPaid) {
    if (event.feeAmount > 0) return '${event.feeAmount} TL';
    final String info = event.feeInfo.trim();
    if (info.isNotEmpty) return info;
  }
  return context.t('eventModal.free');
}

/// Kartlarda gösterilecek tarih: etkinlik günü, yoksa son başvuru.
String eventCardDate(BuildContext context, AppEvent event) {
  final int? day = (event.eventDateAtMs ?? 0) > 0
      ? event.eventDateAtMs
      : event.deadlineAtMs;
  return formatDeadline(day, locale: context.lang);
}

/// Liste kartı (web `.event-card`): içe oturan yuvarlak kapak + tarih hapı,
/// Montserrat başlık, simgeli soluk bilgi satırları ve durum hapı.
class EventSummaryCard extends StatelessWidget {
  const EventSummaryCard({
    required this.event,
    required this.onTap,
    this.priority,
    this.statusOverride,
    this.footer,
    super.key,
  });

  final AppEvent event;
  final VoidCallback onTap;

  /// Verilirse öncelik etiketi de gösterilir (keşif akışları).
  final int? priority;

  /// Kayıt durumu gibi çağırana özel bir rozet.
  final ({String label, FeedbackTone tone})? statusOverride;

  /// Kartın altına eklenen eylem satırı (kulüp tarafında düzenle/sil).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final ({String label, FeedbackTone tone}) status =
        statusOverride ?? eventStatus(context, event);

    final List<String> tags = <String>[
      eventScopeLabel(context, event.targetScope),
      if (priority != null) eventPriorityLabel(context, priority!),
      if (event.isMultiSession)
        context.t('eventModal.sessionsValue', <String, Object?>{
          'count': event.sessionCount,
        }),
    ];

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(BrandShape.controlRadius),
                child: Stack(
                  children: <Widget>[
                    EventImage(url: event.displayImageUrl, height: 172),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: EventDatePill(
                        label: eventCardDate(context, event),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 17),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    EventMetaRow(
                      icon: Icons.groups_2_outlined,
                      text: event.clubName.isNotEmpty
                          ? event.clubName
                          : context.t('dashboard.clubFallback'),
                    ),
                    if (event.locationName.isNotEmpty)
                      EventMetaRow(
                        icon: Icons.place_outlined,
                        text: event.locationName,
                      ),
                    EventMetaRow(
                      icon: Icons.event_available_outlined,
                      text:
                          '${context.t('eventModal.deadline')}: '
                          '${formatDeadline(event.deadlineAtMs, locale: context.lang)}',
                    ),
                    EventMetaRow(
                      icon: Icons.sell_outlined,
                      text: tags.join(' · '),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        StatusPill(label: status.label, tone: status.tone),
                        StatusPill(label: eventFeeLabel(context, event)),
                      ],
                    ),
                    if (footer != null) ...<Widget>[
                      const SizedBox(height: 12),
                      footer!,
                    ],
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

class EventMetaRow extends StatelessWidget {
  const EventMetaRow({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: context.inkMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: context.inkMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Modal içindeki bölüm başlığı — solunda kısa bir marka çubuğu.
class EventSectionTitle extends StatelessWidget {
  const EventSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          gradient: BrandColors.gradient,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: BrandFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: context.ink,
          ),
        ),
      ),
    ],
  );
}

/// Etkinliği düzenleyen kulübün kimlik kartı: ad + kısa bilgi baloncukları.
class EventClubHeader extends StatelessWidget {
  const EventClubHeader({required this.event, super.key});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final String name = event.clubName.isNotEmpty
        ? event.clubName
        : context.t('dashboard.clubFallback');

    final List<String> facts = <String>[
      ...eventClubFields(event).where((String f) => f.isNotEmpty),
      if (event.clubUniversity.isNotEmpty) event.clubUniversity,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Kulübün kimliği başta logosuyla temsil edilir; logo yüklememiş
        // kulüplerde ClubLogoBox marka gradyanlı grup simgesine düşer.
        ClubLogoBox(logoUrl: event.clubLogoUrl, size: 48, radius: 14),
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
                  fontFamily: BrandFonts.heading,
                  fontSize: 15.5,
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
                    for (final String fact in facts) EventBubble(text: fact),
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

/// Kırmızının en soluk tonunda küçük bilgi baloncuğu.
class EventBubble extends StatelessWidget {
  const EventBubble({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.brandTint,
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.brandInk,
        ),
      ),
    );
  }
}

/// Etiket/değer çiftlerinden oluşan bilgi bloğu.
class EventInfoTable extends StatelessWidget {
  const EventInfoTable({required this.rows, super.key});

  final List<({IconData icon, String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.hairline.withValues(alpha: 0.7),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: context.brandTint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      rows[i].icon,
                      size: 16,
                      color: context.brandInk,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          rows[i].label,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: context.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rows[i].value,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: context.ink,
                          ),
                        ),
                      ],
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

/// Etkinliğin bilgi satırları (kulüp satırı hariç — o başlıkta gösteriliyor).
List<({IconData icon, String label, String value})> eventInfoRows(
  BuildContext context,
  AppEvent event,
) {
  // Bölüm hedeflenmemişse (herkese açık ya da yalnızca üniversite kısıtlı)
  // alan olarak kulübün kendi alanları yazılır: satır boş kalmasın, öğrenci
  // etkinliğin hangi alana dokunduğunu görsün.
  final List<String> audience = <String>[
    eventScopeLabel(context, event.targetScope),
    ...event.targetUniversities,
    ...eventAudienceFields(event),
  ];

  return <({IconData icon, String label, String value})>[
    if ((event.eventDateAtMs ?? 0) > 0)
      (
        icon: Icons.event_outlined,
        label: context.t('eventModal.eventDate'),
        value:
            formatDeadline(event.eventDateAtMs, locale: context.lang) +
            (event.timeRangeLabel.isEmpty ? '' : ' · ${event.timeRangeLabel}'),
      ),
    (
      icon: Icons.calendar_today_outlined,
      label: context.t('eventModal.deadline'),
      value: formatDeadline(event.deadlineAtMs, locale: context.lang),
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
        value: context.t('eventModal.sessionsValue', <String, Object?>{
          'count': event.sessionCount,
        }),
      ),
    (
      icon: Icons.public_outlined,
      label: context.t('eventModal.audience'),
      value: audience.join(' • '),
    ),
  ];
}

/// Kulübün iletişim bilgileri — TÜM etkinliklerde (İP-K).
///
///   • Ücretsiz: "İletişim Bilgileri" (kulüp gizlemeyi seçtiyse ya da bilgi
///     yoksa blok görünmez)
///   • Ücretli : "Ücret İçin İletişim Bilgileri" + ücret ve ödeme notu
///
/// Hangi bilginin gösterileceğini kulüp etkinliği oluştururken seçer
/// ([AppEvent.shownContact]).
class EventPaidContactBlock extends StatelessWidget {
  const EventPaidContactBlock({
    required this.event,
    this.forClub = false,
    super.key,
  });

  final AppEvent event;

  /// Kulüp ekranı: ücret notu öğrenciye değil kulübe göre yazılır.
  final bool forClub;

  @override
  Widget build(BuildContext context) {
    final ({String phone, String email, bool hidden}) contact =
        event.shownContact;
    if (contact.hidden) return const SizedBox.shrink();
    if (!event.isPaid && contact.phone.isEmpty && contact.email.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EventSectionTitle(
          context.t(
            event.isPaid
                ? 'eventModal.feeContactTitle'
                : 'eventModal.contactTitle',
          ),
        ),
        const SizedBox(height: 10),
        _PaidContactCard(event: event, forClub: forClub),
      ],
    );
  }
}

/// Ücret notu + tıklanabilir telefon/e-posta satırları.
///
/// Hem detay penceresindeki blokta hem de kayıt sonrası açılan pencerede
/// aynısı gösteriliyor; iki yerde ayrı ayrı kurmamak için tek parça.
class _PaidContactCard extends StatelessWidget {
  const _PaidContactCard({required this.event, this.forClub = false});

  final AppEvent event;
  final bool forClub;

  /// Satıra dokunmak bilgiyi panoya alır.
  ///
  /// Eskiden `tel:`/`mailto:` bağlantısı açılıyordu. Ücretli etkinlikte
  /// öğrencinin yapacağı iş genelde hemen aramak değil — numarayı ya da
  /// adresi ödeme yazışmasına, bankacılık uygulamasına veya bir nota
  /// taşımak. Üstelik cihazda arama/e-posta uygulaması yoksa dokunuş hiçbir
  /// şey yapmadan yutuluyordu; kopyalama her cihazda çalışır.
  Future<void> _copy(
    BuildContext context,
    String value,
    String feedbackKey,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showFloatingToast(context, context.t(feedbackKey));
  }

  @override
  Widget build(BuildContext context) {
    final String phone = event.shownContact.phone;
    final String email = event.shownContact.email;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (event.isPaid)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 16, color: context.brandInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(
                      forClub
                          ? 'eventModal.feeContactNoteClub'
                          : 'eventModal.feeContactNoteWithFee',
                      <String, Object?>{'fee': eventFeeLabel(context, event)},
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: context.brandInk,
                    ),
                  ),
                ),
              ],
            ),
          if (phone.isNotEmpty || email.isNotEmpty) ...<Widget>[
            if (event.isPaid) const SizedBox(height: 12),
            if (phone.isNotEmpty)
              _ContactRow(
                icon: Icons.phone_outlined,
                value: phone,
                onTap: () => _copy(context, phone, 'eventModal.phoneCopied'),
              ),
            if (email.isNotEmpty)
              _ContactRow(
                icon: Icons.mail_outline,
                value: email,
                onTap: () => _copy(context, email, 'eventModal.emailCopied'),
              ),
          ],
        ],
      ),
    );
  }
}

/// Ücretli etkinlik işlemlerinde, işleme devam etmeden önce açık onay alır.
///
/// Onay düğmesi kutu işaretlenene kadar pasiftir. Pencere kapatılır ya da
/// "Vazgeç" seçilirse `null` döner; çağıran taraf yazma işlemini başlatmaz.
///
/// Dönen kayıt, ekranda GÖSTERİLEN metnin kendisini taşır: onay logu
/// kaydedilirken metin yeniden çevrilmez, kabul anındaki hâli yazılır.
Future<PaidEventConsentAcceptance?> _showPaidEventConsentDialog(
  BuildContext context, {
  required String role,
  required String titleKey,
  required String consentTextKey,
  required String confirmKey,
}) async {
  final String title = context.t(titleKey);
  final String consentText = context.t(consentTextKey);
  final String checkboxLabel = context.t('paidEventConsent.checkbox');
  final String language = context.lang;

  final bool? accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      bool checked = false;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              backgroundColor: context.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandShape.cardRadius),
              ),
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      consentText,
                      style: TextStyle(height: 1.5, color: context.ink),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: checked,
                      onChanged: (bool? value) =>
                          setDialogState(() => checked = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(checkboxLabel),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: checked
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: Text(context.t(confirmKey)),
                ),
              ],
            ),
      );
    },
  );

  if (accepted != true) return null;

  return PaidEventConsentAcceptance(
    role: role,
    title: title,
    text: consentText,
    checkboxLabel: checkboxLabel,
    language: language,
    // Onay anı, yazma anı değil: kabul ile Firestore yazımı arasında görsel
    // yüklemesi gibi saniyeler sürebilen adımlar var.
    acceptedAt: DateTime.now(),
  );
}

/// Kulüp, ücretli etkinliği yayımlamadan önce ödeme sorumluluğunu onaylar.
Future<PaidEventConsentAcceptance?> showPaidEventClubCreationConsentDialog(
  BuildContext context,
) => _showPaidEventConsentDialog(
  context,
  role: PaidEventConsentRole.club,
  titleKey: 'paidEventConsent.club.title',
  consentTextKey: 'paidEventConsent.club.text',
  confirmKey: 'paidEventConsent.club.confirm',
);

/// Öğrenci, ücretli etkinlik kaydından hemen önce ödeme risklerini onaylar.
Future<PaidEventConsentAcceptance?>
showPaidEventStudentRegistrationConsentDialog(BuildContext context) =>
    _showPaidEventConsentDialog(
      context,
      role: PaidEventConsentRole.student,
      titleKey: 'paidEventConsent.student.title',
      consentTextKey: 'paidEventConsent.student.text',
      confirmKey: 'paidEventConsent.student.confirm',
    );

/// Ücretli etkinliğe kayıt alındıktan sonra açılan bilgilendirme penceresi.
///
/// Ücret uygulama içinde tahsil edilmediği için kayıt tek başına yeterli
/// değil: öğrencinin ödemeyi konuşmak üzere kulübe ulaşması gerekiyor.
/// Detaydaki blok kolayca gözden kaçtığından kayıt anında bir kez daha
/// önüne çıkarıyoruz. Ücretsiz etkinliklerde hiç açılmaz.
Future<void> showPaidEventContactDialog(BuildContext context, AppEvent event) {
  if (!event.isPaid) return Future<void>.value();

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      backgroundColor: dialogContext.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
      ),
      title: Text(dialogContext.t('eventModal.feeContactTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              event.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: dialogContext.ink,
              ),
            ),
            const SizedBox(height: 12),
            _PaidContactCard(event: event),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t('common.close')),
        ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: context.inkMuted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.ink,
                ),
              ),
            ),
            // Simge eylemi anlatır: satır artık başka bir uygulamaya
            // yönlendirmiyor, değeri panoya alıyor.
            Icon(Icons.content_copy, size: 15, color: context.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Web'deki etkinlik modalinin mobil karşılığı.
///
/// [actionBar] verilirse pencerenin altına sabitlenir; verilmezse pencere
/// salt görüntülemedir (kulübün keşif akışı böyle).
Future<void> showEventDetailSheet(
  BuildContext context, {
  required AppEvent event,
  int? priority,
  Widget? extraContent,
  Widget? actionBar,
  bool forClub = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(BrandShape.sheetRadius),
      ),
    ),
    builder: (_) => EventDetailSheet(
      event: event,
      priority: priority,
      extraContent: extraContent,
      actionBar: actionBar,
      forClub: forClub,
    ),
  );
}

class EventDetailSheet extends ConsumerWidget {
  const EventDetailSheet({
    required this.event,
    this.priority,
    this.extraContent,
    this.actionBar,
    this.forClub = false,
    super.key,
  });

  final AppEvent event;
  final int? priority;
  final Widget? extraContent;
  final Widget? actionBar;

  /// Kulüp ekranından açıldı: ücret notu kulübe göre.
  final bool forClub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kart/listeden gelen nesne pencerenin ilk karesini gecikmesiz çizer.
    // Firestore dinleyicisi veri getirince etkinlik ve kulüp kimliği canlı
    // kopyaya geçer; profil kaydının eski etkinliklere yaptığı senkronizasyon
    // pencere açıkken de görünür.
    final AppEvent event =
        ref.watch(eventByIdProvider(this.event.id)).value ?? this.event;
    final ({String label, FeedbackTone tone}) status = eventStatus(
      context,
      event,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) =>
          Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Stack(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(BrandShape.sheetRadius),
                          ),
                          child: EventImage(
                            url: event.displayImageUrl,
                            height: 220,
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
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          EventClubHeader(event: event),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              StatusPill(
                                label: status.label,
                                tone: status.tone,
                              ),
                              StatusPill(
                                label: eventScopeLabel(
                                  context,
                                  event.targetScope,
                                ),
                              ),
                              if (priority != null)
                                StatusPill(
                                  label: eventPriorityLabel(context, priority!),
                                ),
                            ],
                          ),

                          const SizedBox(height: 26),
                          EventSectionTitle(context.t('eventModal.info')),
                          const SizedBox(height: 12),
                          EventInfoTable(rows: eventInfoRows(context, event)),

                          // İletişim: ücretsizde "İletişim Bilgileri", ücretlide
                          // "Ücret İçin İletişim Bilgileri" (blok kendisi karar
                          // verir; gösterilecek bilgi yoksa hiç çizilmez).
                          const SizedBox(height: 22),
                          EventPaidContactBlock(event: event, forClub: forClub),

                          const SizedBox(height: 26),
                          EventSectionTitle(
                            context.t('eventModal.description'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            event.description.isNotEmpty
                                ? event.description
                                : context.t('dashboard.modal.noDescription'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),

                          if (event.purpose.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 26),
                            EventSectionTitle(context.t('eventModal.purpose')),
                            const SizedBox(height: 10),
                            Text(
                              event.purpose,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],

                          if (extraContent != null) ...<Widget>[
                            const SizedBox(height: 22),
                            extraContent!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (actionBar != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surface,
                    border: Border(top: BorderSide(color: context.hairline)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: actionBar,
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}
