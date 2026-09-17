/// Yönetici bildirim ekranı — kitlelere duyuru gönderme.
///
/// Akış: arama çubuğundan üniversite/şehir bul → üniversiteye dokun →
/// açılan pencerede hedef kitleyi (kulüpler / öğrenciler / her ikisi) seç,
/// metni yaz, gönder. Duyuru Firestore'a yazılır; hedef kitledeki cihazlar
/// bunu bildirime çevirir (bkz. features/notifications/notification_sync.dart).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/app_log.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../core/text_utils.dart';
import '../../data/location_data.dart';
import '../../l10n/app_strings.dart';
import '../../models/announcement.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import 'admin_shell.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  String _query = '';

  /// Aramaya uyan şehirler ve o şehrin görünen üniversiteleri.
  ///
  /// Şehir adı eşleşirse şehrin TÜM üniversiteleri görünür ("Ankara" yazan
  /// biri Ankara'daki hepsini bekler); yalnızca üniversite adı eşleşiyorsa
  /// o şehirden sadece eşleşenler listelenir.
  List<({String city, List<String> universities})> get _sections {
    final String needle = foldTr(_query);

    return <({String city, List<String> universities})>[
      for (final MapEntry<String, List<String>> entry
          in kCityUniversities.entries)
        if (needle.isEmpty)
          (city: entry.key, universities: entry.value)
        else if (foldTr(entry.key).contains(needle))
          (city: entry.key, universities: entry.value)
        else
          (
            city: entry.key,
            universities: entry.value
                .where(
                  (String u) => foldTr(u).contains(needle),
                )
                .toList(),
          ),
    ].where((({String city, List<String> universities}) s) =>
        s.universities.isNotEmpty).toList();
  }

  /// Gönderim hatasının ekranda görünecek metni.
  ///
  /// `permission-denied` iki AYRI nedenden gelebiliyor ve ikisi istemciden
  /// ayırt edilemiyor (emulator'de ikisi de aynı kodu üretiyor):
  ///
  ///   1. Yayındaki firestore.rules'ta `notifications` bloğu yok — dosyanın
  ///      sonundaki `match /{document=**}` her yazmayı reddediyor.
  ///   2. Kuraldaki sabit yönetici UID'si bu oturumunkinden farklı. Panele
  ///      giriş E-POSTAYA bakıyor (`isAdminEmail`, state/providers.dart),
  ///      Firestore izni ise UID'ye: aynı e-postayla açılmış BAŞKA bir hesap
  ///      panele girebiliyor ama hiçbir şey yazamıyor.
  ///
  /// İkisini ayırmanın tek yolu oturumun UID'sini kuraldakiyle karşılaştırmak,
  /// o yüzden UID mesaja ekleniyor. Bu metni yalnızca yönetici görür ve
  /// gördüğü kendi UID'sidir.
  String _sendErrorMessage(FirebaseException error, String uid) =>
      error.code == 'permission-denied'
      ? '${context.t('admin.notify.sendDenied')} (uid: $uid)'
      : '${context.t('admin.notify.sendError')} (${error.code})';

  Future<void> _openComposer(String city, String university) async {
    final _ComposedAnnouncement? result =
        await showDialog<_ComposedAnnouncement>(
          context: context,
          builder: (BuildContext _) => _AnnouncementDialog(
            city: city,
            university: university,
          ),
        );

    if (result == null || !mounted) return;

    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

    try {
      await ref
          .read(announcementRepositoryProvider)
          .send(
            title: result.title,
            body: result.body,
            audience: result.audience,
            university: university,
            city: city,
            senderUid: uid,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('admin.notify.sent', <String, Object?>{
              'university': university,
            }),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      // Hatanın sebebini yutmak pahalıya mal oldu: kurallar yayınlanmadığı
      // için gelen `permission-denied` aylarca genel "gönderilemedi"
      // uyarısının arkasında kaldı. Kod artık mesajda görünüyor.
      AppLog.error('announcement.send', error: error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sendErrorMessage(error, uid))),
      );
    } catch (error) {
      if (!mounted) return;
      AppLog.error('announcement.send', error: error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.notify.sendError'))),
      );
    }
  }

  /// Tek bir üniversite yerine ÜLKEDEKİ TÜMÜNE gönderilen genel duyuru.
  ///
  /// Geniş etkisi yüzünden (potansiyel olarak binlerce cihaz) önce sayıyla
  /// birlikte bir onay adımı var — yanlışlıkla dokunup geri alınamaz bir
  /// gönderim yapmasın diye.
  Future<void> _openBroadcast() async {
    final _ComposedAnnouncement? result =
        await showDialog<_ComposedAnnouncement>(
          context: context,
          builder: (BuildContext _) => const _AnnouncementDialog(
            city: null,
            university: null,
          ),
        );

    if (result == null || !mounted) return;

    final int universityCount = kCityUniversities.values.fold<int>(
      0,
      (int sum, List<String> list) => sum + list.length,
    );

    // DİKKAT: Pencerenin kendi context'i (`dialogContext`) kullanılmak
    // zorunda. Ekranın context'i yönetici kabuğunun (ShellRoute) KENDİ
    // Navigator'ının altında kalıyor; `showDialog` ise pencereyi kök
    // Navigator'a itiyor. Buraya ekranın context'i yazıldığında
    // `Navigator.of(context).pop(...)` pencereyi değil kabuğun sayfasını
    // açıyordu: onay penceresi ekranda kalıyor, arkasındaki bildirim ekranı
    // kayboluyor ve duyuru hiç gönderilmiyordu.
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(dialogContext.t('admin.notify.broadcastConfirmTitle')),
            // Onay penceresi eskiden yalnızca "197 üniversiteye gidecek"
            // diyordu; gönderilecek metnin kendisi görünmüyordu. Geri
            // alınamayan bir gönderimden önce yöneticinin başlığı, metni ve
            // hedef kitleyi son bir kez görmesi gerekiyor.
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  dialogContext.t('admin.notify.broadcastConfirmBody',
                      <String, Object?>{'count': universityCount}),
                ),
                const SizedBox(height: 14),
                _BroadcastPreview(announcement: result),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.t('common.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.t('admin.notify.send')),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

    try {
      await ref
          .read(announcementRepositoryProvider)
          .sendBroadcast(
            title: result.title,
            body: result.body,
            audience: result.audience,
            senderUid: uid,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.notify.broadcastSent'))),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      AppLog.error('announcement.sendBroadcast', error: error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_sendErrorMessage(error, uid))),
      );
    } catch (error) {
      if (!mounted) return;
      AppLog.error('announcement.sendBroadcast', error: error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.notify.sendError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<({String city, List<String> universities})> sections =
        _sections;
    final bool searching = _query.trim().isNotEmpty;

    return Scaffold(
      appBar: AdminAppBar(title: context.t('student.notifications.title')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _BroadcastCard(onTap: _openBroadcast),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              onChanged: (String value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              inputFormatters: guardedInput(InputLimits.search),
              decoration: InputDecoration(
                hintText: context.t('admin.notify.searchPlaceholder'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.t('admin.notify.hint'),
                style: TextStyle(fontSize: 11.5, color: context.inkMuted),
              ),
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      EmptyState(
                        message: context.t('admin.notify.noResults'),
                        icon: Icons.search_off_rounded,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: sections.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ({String city, List<String> universities}) section =
                          sections[index];

                      return _CitySection(
                        city: section.city,
                        universities: section.universities,
                        // Arama sırasında bölümler açık gelir: kullanıcı
                        // aradığı üniversiteyi bir de elle açmak zorunda
                        // kalmasın.
                        initiallyExpanded: searching,
                        onSelect: (String university) =>
                            _openComposer(section.city, university),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Arama listesinin üstündeki "genel duyuru" girişi — tek bir üniversite
/// yerine ülkedeki tüm üniversitelere (dolayısıyla tüm öğrenci/kulüplere)
/// gönderim başlatır.
class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.brandInk;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.campaign_rounded, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.t('admin.notify.broadcastButton'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.t('admin.notify.broadcastSubtitle'),
                    style: TextStyle(fontSize: 11.5, color: context.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

/// Bir şehir başlığı ve altındaki üniversiteler.
class _CitySection extends StatelessWidget {
  const _CitySection({
    required this.city,
    required this.universities,
    required this.initiallyExpanded,
    required this.onSelect,
  });

  final String city;
  final List<String> universities;
  final bool initiallyExpanded;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Arama değişince bölümlerin açık/kapalı durumu yeniden kurulmalı;
        // ExpansionTile başlangıç değerini yalnızca ilk kurulumda okuyor.
        key: PageStorageKey<String>('$city:$initiallyExpanded'),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.location_city_outlined, color: context.brandInk),
        title: Text(
          city,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          context.t('admin.notify.universityCount', <String, Object?>{
            'count': universities.length,
          }),
          style: TextStyle(fontSize: 11.5, color: context.inkMuted),
        ),
        children: <Widget>[
          for (final String university in universities)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 20, right: 12),
              leading: Icon(
                Icons.account_balance_outlined,
                size: 18,
                color: context.inkMuted,
              ),
              title: Text(university, style: const TextStyle(fontSize: 13)),
              trailing: Icon(
                Icons.send_rounded,
                size: 17,
                color: context.brandInk,
              ),
              onTap: () => onSelect(university),
            ),
        ],
      ),
    );
  }
}

/// Pencereden dönen sonuç.
class _ComposedAnnouncement {
  const _ComposedAnnouncement({
    required this.title,
    required this.body,
    required this.audience,
  });

  final String title;
  final String body;
  final String audience;
}

/// Hedef kitle değerinin ekranda görünen adı.
String _audienceLabel(BuildContext context, String audience) =>
    context.t(switch (audience) {
      AnnouncementAudience.students => 'admin.notify.audience.students',
      AnnouncementAudience.clubs => 'admin.notify.audience.clubs',
      _ => 'admin.notify.audience.all',
    });

/// Onay penceresindeki "ne gönderilecek" özeti — hedef kitle, başlık, metin.
class _BroadcastPreview extends StatelessWidget {
  const _BroadcastPreview({required this.announcement});

  final _ComposedAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.people_alt_outlined,
                size: 14,
                color: context.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _audienceLabel(context, announcement.audience),
                  style: TextStyle(fontSize: 11.5, color: context.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            announcement.title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            announcement.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: context.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Üniversiteye dokununca açılan metin penceresi.
class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.city, required this.university});

  /// `null` ise bu bir genel duyuru (tüm üniversiteler) penceresidir.
  final String? city;
  final String? university;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  /// Varsayılan olarak iki kitleye birden gönderilir; yönetici duyurularının
  /// çoğu üniversitenin tamamını ilgilendiriyor.
  String _audience = AnnouncementAudience.all;

  bool _showErrors = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  void _submit() {
    // Alanlar yazarken zaten eleniyor (core/input_guard.dart); buradaki
    // temizlik ikinci katman: duyuru metni web istemcisinde de gösteriliyor
    // ve oraya HTML olarak düşen bir kalıntı XSS'e dönüşür.
    final String title = sanitizeText(_title.text, maxLength: InputLimits.title);
    final String body =
        sanitizeLongText(_body.text, maxLength: InputLimits.paragraph);

    if (!_isValid || title.isEmpty || body.isEmpty) {
      setState(() => _showErrors = true);
      return;
    }

    Navigator.of(context).pop(
      _ComposedAnnouncement(title: title, body: body, audience: _audience),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.university ?? context.t('admin.notify.broadcastHeader'),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            widget.city ?? context.t('admin.notify.broadcastSubtitle'),
            style: TextStyle(fontSize: 12, color: context.inkMuted),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Hedef kitle ────────────────────────────────────────
            Text(
              context.t('admin.notify.audience'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _AudienceSelector(
              value: _audience,
              onChanged: (String value) => setState(() => _audience = value),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: guardedInput(InputLimits.title),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.t('admin.notify.titleLabel'),
                errorText: _showErrors && _title.text.trim().isEmpty
                    ? context.t('admin.notify.required')
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _body,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5,
              inputFormatters: guardedInput(
                InputLimits.paragraph,
                multiline: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.t('admin.notify.bodyLabel'),
                alignLabelWithHint: true,
                errorText: _showErrors && _body.text.trim().isEmpty
                    ? context.t('admin.notify.required')
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _isValid ? _submit : null,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(context.t('admin.notify.send')),
        ),
      ],
    );
  }
}

/// Üç seçenekli hedef kitle anahtarı.
class _AudienceSelector extends StatelessWidget {
  const _AudienceSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const List<({String value, IconData icon, String labelKey})> _options =
      <({String value, IconData icon, String labelKey})>[
        (
          value: AnnouncementAudience.students,
          icon: Icons.school_outlined,
          labelKey: 'admin.notify.audience.students',
        ),
        (
          value: AnnouncementAudience.clubs,
          icon: Icons.groups_outlined,
          labelKey: 'admin.notify.audience.clubs',
        ),
        (
          value: AnnouncementAudience.all,
          icon: Icons.public,
          labelKey: 'admin.notify.audience.all',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final ({IconData icon, String labelKey, String value}) option
            in _options) ...<Widget>[
          Expanded(
            child: _AudienceChip(
              icon: option.icon,
              label: context.t(option.labelKey),
              selected: option.value == value,
              onTap: () => onChanged(option.value),
            ),
          ),
          if (option != _options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.brandInk;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : context.subtleFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : context.hairline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 19,
              color: selected ? accent : context.inkMuted,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : context.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
