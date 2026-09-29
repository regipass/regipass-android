/// Kulüp listesi — hangi şehirde, hangi üniversitede hangi kulüp açılmış.
///
/// İstatistik ekranı sayıları veriyor; burası o sayıların arkasındaki
/// kulüplerin kendisini gösteriyor: şehir → üniversite ağacında kartlar,
/// karta dokununca kulübün bilgileri ve özeti bir pencerede açılıyor.
/// Web'deki karşılığı: admin-clubs.html + js/pages/admin-clubs.js.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/legal_consent.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';
import 'ban_decision_dialog.dart';
import 'club_message_panel.dart';

/// Durum süzgeci düğmeleri. `null` = tümü.
const List<({String? status, String labelKey})> _statusFilters =
    <({String? status, String labelKey})>[
      (status: null, labelKey: 'admin.clubs.filter.all'),
      (status: ClubStatus.approved, labelKey: 'admin.clubs.filter.approved'),
      (
        status: ClubStatus.pendingReview,
        labelKey: 'admin.clubs.filter.pending',
      ),
      (
        status: ClubStatus.documentsPending,
        labelKey: 'admin.clubs.filter.documents',
      ),
      (status: ClubStatus.banned, labelKey: 'admin.clubs.filter.banned'),
    ];

/// Kulüp durumunun etiketi ve rengi — kartta ve pencerede aynı görünüm.
({String labelKey, FeedbackTone tone}) clubStatusBadge(String status) =>
    switch (status) {
      ClubStatus.approved => (
        labelKey: 'admin.clubs.status.approved',
        tone: FeedbackTone.success,
      ),
      ClubStatus.pendingReview => (
        labelKey: 'admin.clubs.status.pending',
        tone: FeedbackTone.info,
      ),
      ClubStatus.banned => (
        labelKey: 'admin.clubs.status.banned',
        tone: FeedbackTone.error,
      ),
      _ => (labelKey: 'admin.clubs.status.documents', tone: FeedbackTone.info),
    };

class AdminClubsScreen extends ConsumerStatefulWidget {
  const AdminClubsScreen({super.key});

  @override
  ConsumerState<AdminClubsScreen> createState() => _AdminClubsScreenState();
}

class _AdminClubsScreenState extends ConsumerState<AdminClubsScreen> {
  String _query = '';
  String? _status;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ClubProfile>> clubs = ref.watch(allClubsProvider);

    return Scaffold(
      appBar: AdminAppBar(title: context.t('admin.clubs.title')),
      body: RefreshIndicator(
        color: BrandColors.red,
        onRefresh: () async => ref.invalidate(allClubsProvider),
        child: clubs.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace _) => ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              FeedbackBanner(
                message: context.t('admin.feedback.error'),
                tone: FeedbackTone.error,
              ),
            ],
          ),
          data: (List<ClubProfile> all) {
            final List<ClubCityGroup> groups = groupClubsByLocation(
              all,
              query: _query,
              status: _status,
            );

            return Column(
              children: <Widget>[
                _Filters(
                  query: _query,
                  status: _status,
                  onQuery: (String value) => setState(() => _query = value),
                  onStatus: (String? value) => setState(() => _status = value),
                ),
                Expanded(
                  child: ListView(
                    // Liste boşken bile aşağı çekip yenilenebilsin.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: <Widget>[
                      if (groups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: EmptyState(
                            message: context.t('admin.clubs.empty'),
                            icon: Icons.groups_outlined,
                          ),
                        )
                      else ...<Widget>[
                        _DirectorySummary(groups: groups),
                        const SizedBox(height: 14),
                        for (final ClubCityGroup city in groups)
                          _CitySection(group: city),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.status,
    required this.onQuery,
    required this.onStatus,
  });

  final String query;
  final String? status;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            onChanged: onQuery,
            inputFormatters: guardedInput(InputLimits.search),
            decoration: InputDecoration(
              hintText: context.t('admin.clubs.searchPlaceholder'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              for (final ({String? status, String labelKey}) filter
                  in _statusFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(context.t(filter.labelKey)),
                    selected: status == filter.status,
                    onSelected: (_) => onStatus(filter.status),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "12 kulüp · 4 şehir · 7 üniversite" özeti.
class _DirectorySummary extends StatelessWidget {
  const _DirectorySummary({required this.groups});

  final List<ClubCityGroup> groups;

  @override
  Widget build(BuildContext context) {
    final int clubs = groups.fold<int>(
      0,
      (int sum, ClubCityGroup g) => sum + g.clubCount,
    );
    final Set<String> universities = <String>{
      for (final ClubCityGroup city in groups)
        for (final ClubUniversityGroup u in city.universities)
          '${city.city}|${u.university}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.travel_explore_outlined,
            size: 20,
            color: context.brandInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t('admin.clubs.summaryCounts', <String, Object?>{
                'clubs': clubs,
                'cities': groups.length,
                'universities': universities.length,
              }),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitySection extends StatelessWidget {
  const _CitySection({required this.group});

  final ClubCityGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: BrandColors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: context.t('admin.clubs.cityCount', <String, Object?>{
                  'count': group.clubCount,
                }),
              ),
            ],
          ),
          for (final ClubUniversityGroup university in group.universities)
            _UniversitySection(group: university),
        ],
      ),
    );
  }
}

class _UniversitySection extends StatelessWidget {
  const _UniversitySection({required this.group});

  final ClubUniversityGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.account_balance_outlined,
                size: 14,
                color: context.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  group.university,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Kart genişliği ekrana göre: dar telefonda iki sütun, tablette
          // daha fazla. Sabit sütun sayısı geniş ekranda kartları şişiriyor.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = (constraints.maxWidth / 160).floor().clamp(
                1,
                4,
              );
              const double gap = 10;
              final double width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (final ClubProfile club in group.clubs)
                    SizedBox(
                      width: width,
                      child: _ClubCard(club: club),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});

  final ClubProfile club;

  @override
  Widget build(BuildContext context) {
    final ({String labelKey, FeedbackTone tone}) badge = clubStatusBadge(
      club.clubStatus,
    );

    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(BrandShape.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showClubDetailDialog(context, club),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.cardRadius),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Kulüp fotoğrafı: logo yüklenmediyse ClubLogoBox marka
              // gradyanlı simgeye düşer, kart hiçbir zaman boş kalmaz.
              Container(
                height: 92,
                width: double.infinity,
                color: context.subtleFill,
                alignment: Alignment.center,
                child: ClubLogoBox(logoUrl: club.logoUrl, size: 58, radius: 14),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      club.clubName.isNotEmpty
                          ? club.clubName
                          : context.t('admin.clubs.unnamed'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      club.clubFields.isNotEmpty
                          ? club.clubFields.join(', ')
                          : '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      label: context.t(badge.labelKey),
                      tone: badge.tone,
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

// ═══════════════════════════════════════════════════════════════════════
// Kulüp detay penceresi
// ═══════════════════════════════════════════════════════════════════════

Future<void> showClubDetailDialog(BuildContext context, ClubProfile club) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _ClubDetailDialog(club: club),
    );

/// Kulübün tek cümlelik özeti: nerede açıldı, ne iş yapıyor, durumu ne.
///
/// Metin çeviri sözlüğünden gelir; eksik alanlar "Bilgisi eksik" ile
/// doldurulur ki cümle hiçbir zaman yarım kalmasın.
String clubSummaryText(BuildContext context, ClubProfile club) {
  String orMissing(String value) =>
      value.trim().isEmpty ? kMissingLocationLabel : value.trim();

  return context.t('admin.clubs.summaryText', <String, Object?>{
    'club': club.clubName.isNotEmpty
        ? club.clubName
        : context.t('admin.clubs.unnamed'),
    'city': orMissing(club.city),
    'university': orMissing(club.university),
    'fields': club.clubFields.isNotEmpty
        ? club.clubFields.join(', ')
        : orMissing(club.clubField),
    'status': context.t(clubStatusBadge(club.clubStatus).labelKey),
  });
}

class _ClubDetailDialog extends ConsumerStatefulWidget {
  const _ClubDetailDialog({required this.club});

  final ClubProfile club;

  @override
  ConsumerState<_ClubDetailDialog> createState() => _ClubDetailDialogState();
}

class _ClubDetailDialogState extends ConsumerState<_ClubDetailDialog> {
  /// Pencere açıkken durum değişebiliyor (engelle / engeli kaldır). Liste
  /// sağlayıcısı tazelenene kadar rozet ve düğme yerel kopyayı okur.
  late ClubProfile _club = widget.club;

  bool _busy = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Kulübü engeller ya da engelini kaldırır.
  ///
  /// Onay kuyruğundaki "Engelle"den farkı: burada belgeler silinmez, işlem
  /// geri alınabilir. Engel kalkınca kulüp belgeleri duruyorsa inceleme
  /// kuyruğuna, durmuyorsa belge yükleme adımına döner
  /// (bkz. `domain/club_moderation.dart`).
  Future<void> _toggleBan() async {
    final ClubProfile club = _club;
    final bool banning = !club.isBanned;
    final String name = club.clubName.isNotEmpty
        ? club.clubName
        : context.t('admin.clubs.unnamed');

    final String? reason = await askBanDecision(
      context,
      ref,
      uid: club.uid,
      title: context.t(banning ? 'admin.clubs.ban' : 'admin.clubs.unban'),
      message: context.t(
        banning ? 'admin.ban.confirmClubBan' : 'admin.ban.confirmClubUnban',
        <String, Object?>{'name': name},
      ),
      banning: banning,
      isClub: true,
    );

    if (reason == null || !mounted) return;

    setState(() {
      _busy = true;
      _feedback = context.t('admin.feedback.processing');
      _tone = FeedbackTone.info;
    });

    try {
      final String nextStatus = await ref
          .read(adminRepositoryProvider)
          .setClubBanned(club, banning, reason: reason);
      if (!mounted) return;

      setState(() {
        _club = club.withBanState(clubStatus: nextStatus, banned: banning);
        _feedback = context.t(
          banning ? 'admin.ban.banSuccess' : 'admin.ban.unbanSuccess',
          <String, Object?>{'name': name},
        );
        _tone = FeedbackTone.success;
      });

      // Arkadaki liste kartı da yeni durumu göstersin.
      ref.invalidate(allClubsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback = context.t(
          banning ? 'admin.ban.banError' : 'admin.ban.unbanError',
        );
        _tone = FeedbackTone.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClubProfile club = _club;
    final ({String labelKey, FeedbackTone tone}) badge = clubStatusBadge(
      club.clubStatus,
    );
    final String name = club.clubName.isNotEmpty
        ? club.clubName
        : context.t('admin.clubs.unnamed');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Başlık: fotoğraf + ad + durum ─────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
                decoration: const BoxDecoration(gradient: BrandColors.gradient),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClubLogoBox(logoUrl: club.logoUrl, size: 62, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: BrandColors.white,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            <String>[
                              if (club.city.trim().isNotEmpty) club.city.trim(),
                              if (club.university.trim().isNotEmpty)
                                club.university.trim(),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: BrandColors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: BrandColors.white),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        StatusPill(
                          label: context.t(badge.labelKey),
                          tone: badge.tone,
                        ),
                        for (final String field in club.clubFields)
                          StatusPill(label: field),
                      ],
                    ),

                    // ── Kulüp özeti ──────────────────────────────
                    const SizedBox(height: 14),
                    _DialogSection(title: context.t('admin.clubs.summary')),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.subtleFill,
                        borderRadius: BorderRadius.circular(
                          BrandShape.controlRadius,
                        ),
                      ),
                      child: Text(
                        clubSummaryText(context, club),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: context.ink,
                        ),
                      ),
                    ),

                    // ── Bilgiler ─────────────────────────────────
                    const SizedBox(height: 16),
                    _DialogSection(title: context.t('admin.clubs.info')),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: context.t('admin.modal.founder'),
                      value: '${club.firstName} ${club.lastName}'.trim(),
                    ),
                    _DetailRow(
                      label: context.t('admin.modal.email'),
                      value: club.email,
                      selectable: true,
                    ),
                    _DetailRow(
                      label: context.t('admin.modal.phone'),
                      value: club.phone,
                      selectable: true,
                    ),
                    _DetailRow(
                      label: context.t('admin.modal.city'),
                      value: club.city,
                    ),
                    _DetailRow(
                      label: context.t('admin.modal.university'),
                      value: club.university,
                    ),
                    _DetailRow(
                      label: context.t('admin.modal.field'),
                      value: club.clubFields.join(', '),
                    ),
                    // Sözleşme/KVKK onayının tam anı — gün, saat, dakika,
                    // saniye (bkz. KVKK Aydınlatma Metni madde 7).
                    _DetailRow(
                      label: context.t('legal.consent.tileLabel'),
                      value: consentTileValue(
                        context,
                        termsAccepted: club.termsAccepted,
                        acceptedAtMs: club.termsAcceptedAtMs,
                        marketingConsent: club.marketingConsent,
                      ),
                    ),

                    // ── Ne iş yapıyor ────────────────────────────
                    if (club.clubPurpose.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      _DialogSection(title: context.t('admin.modal.purpose')),
                      const SizedBox(height: 6),
                      _Paragraph(text: club.clubPurpose),
                    ],
                    if (club.clubContents.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _DialogSection(title: context.t('admin.modal.contents')),
                      const SizedBox(height: 6),
                      _Paragraph(text: club.clubContents),
                    ],

                    // ── Kulübe not ───────────────────────────────
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    ClubMessagePanel(club: club),

                    // ── Engelle / engeli kaldır ──────────────────
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    if (_feedback != null)
                      FeedbackBanner(message: _feedback, tone: _tone),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: club.isBanned
                              ? BrandColors.success
                              : BrandColors.danger,
                          side: BorderSide(
                            color: club.isBanned
                                ? BrandColors.success
                                : BrandColors.danger,
                          ),
                          minimumSize: const Size(0, 46),
                        ),
                        onPressed:
                            _busy || !ref.watch(sessionProvider).canAdminWrite
                            ? null
                            : _toggleBan,
                        icon: Icon(
                          club.isBanned
                              ? Icons.lock_open_outlined
                              : Icons.block_outlined,
                          size: 18,
                        ),
                        label: Text(
                          context.t(
                            club.isBanned
                                ? 'admin.clubs.unban'
                                : 'admin.clubs.ban',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('common.close')),
                      ),
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

class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
      color: context.brandInk,
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;

  /// E-posta ve telefon kopyalanabilir olmalı: yönetici çoğu zaman kulüple
  /// bu ekranın dışında iletişime geçiyor.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final String text = value.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: selectable && text.isNotEmpty
                ? SelectableText(
                    text,
                    style: TextStyle(fontSize: 13, color: context.ink),
                  )
                : Text(
                    text.isEmpty ? '-' : text,
                    style: TextStyle(fontSize: 13, color: context.ink),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 13, height: 1.55, color: context.inkMuted),
  );
}
