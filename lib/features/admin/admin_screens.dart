/// Yönetici ekranları — js/pages/admin-*.js karşılığı.
///
/// Yetkilendirme router'da: `a@regipass.app` ile giren kullanıcı buraya
/// alınır, diğer herkes bu rotalardan dışlanır (admin-guard.js karşılığı,
/// bkz. lib/app/router.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../domain/admin_stats.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';

// ═══════════════════════════════════════════════════════════════════════
// Onay bekleyen kulüpler (admin-dashboard.js)
// ═══════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ClubProfile>> clubs = ref.watch(pendingClubsProvider);

    return Scaffold(
      appBar: AdminAppBar(title: context.t('admin.nav.pending')),
      body: clubs.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('admin.feedback.error'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<ClubProfile> all) {
          final String needle = _query.trim().toLowerCase();
          final List<ClubProfile> visible = needle.isEmpty
              ? all
              : all
                  .where((ClubProfile c) => <String>[
                        c.clubName,
                        c.university,
                        c.city,
                        c.email,
                      ].any((String f) => f.toLowerCase().contains(needle)))
                  .toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  onChanged: (String value) => setState(() => _query = value),
                  inputFormatters: guardedInput(InputLimits.search),
                  decoration: InputDecoration(
                    hintText: context.t('admin.searchPlaceholder'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: <Widget>[
                          EmptyState(
                            message: context.t('admin.empty'),
                            icon: Icons.inbox_outlined,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) =>
                            _PendingClubCard(club: visible[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class _PendingClubCard extends ConsumerStatefulWidget {
  const _PendingClubCard({required this.club});

  final ClubProfile club;

  @override
  ConsumerState<_PendingClubCard> createState() => _PendingClubCardState();
}

class _PendingClubCardState extends ConsumerState<_PendingClubCard> {
  bool _busy = false;
  bool _showDocuments = false;

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

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

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _toast(success);
    } catch (_) {
      if (mounted) _toast(context.t('admin.feedback.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final bool ok = await _confirm(
      context.t('admin.action.approve'),
      context.t('admin.confirm.approve', <String, Object?>{
        'club': widget.club.clubName,
      }),
    );
    if (!ok || !mounted) return;

    final String message = context.t('admin.feedback.approved');
    await _run(
      () => ref.read(adminRepositoryProvider).approveClub(widget.club.uid),
      message,
    );
  }

  /// "Belge eksik": kulübü reddetmeden yükleme aşamasına geri gönderir.
  ///
  /// Açıklama zorunlu — kulübün neyi düzelteceğini bilmesi gerekiyor, yoksa
  /// aynı belgeleri tekrar yükleyip döngüye giriyor.
  Future<void> _requestFix() async {
    final TextEditingController reason = TextEditingController();

    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.t('admin.action.needsDocuments')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              dialogContext.t('admin.needsDocuments.hint'),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              autofocus: true,
              maxLines: 4,
              inputFormatters: guardedInput(
                InputLimits.paragraph,
                multiline: true,
              ),
              decoration: InputDecoration(
                hintText: dialogContext.t('admin.needsDocuments.placeholder'),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              // Not kulüp profiline yazılıp hem mobilde hem webde okunuyor.
              final String value = sanitizeLongText(
                reason.text,
                maxLength: InputLimits.paragraph,
              );
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: Text(dialogContext.t('admin.needsDocuments.send')),
          ),
        ],
      ),
    );

    reason.dispose();
    if (text == null || !mounted) return;

    final String message = context.t('admin.feedback.documentsRequested');
    await _run(
      () => ref
          .read(adminRepositoryProvider)
          .requestDocumentFix(widget.club.uid, text),
      message,
    );
  }

  Future<void> _block() async {
    final bool ok = await _confirm(
      context.t('admin.action.block'),
      context.t('admin.confirm.block', <String, Object?>{
        'club': widget.club.clubName,
      }),
    );
    if (!ok || !mounted) return;

    final String message = context.t('admin.feedback.blocked');
    await _run(
      () => ref.read(adminRepositoryProvider).blockClub(widget.club),
      message,
    );
  }

  Future<void> _openDocument(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Onay kararı çoğu zaman kulüple konuşmayı gerektiriyor; numara ve
  /// e-posta doğrudan aranabilir/yazılabilir olsun.
  Future<void> _openContact(String scheme, String value) async {
    if (value.trim().isEmpty) return;
    try {
      await launchUrl(
        Uri(scheme: scheme, path: value.trim()),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Cihazda arama/e-posta uygulaması yoksa yok say; bilgi zaten yazılı.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClubProfile club = widget.club;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: BrandColors.gradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: BrandColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      club.clubName.isNotEmpty
                          ? club.clubName
                          : context.t('dashboard.clubFallback'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final String field in club.clubFields)
                          StatusPill(label: field),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _InfoLine(
            icon: Icons.person_outline,
            text: '${club.firstName} ${club.lastName}'.trim(),
          ),
          _InfoLine(
            icon: Icons.mail_outline,
            text: club.email,
            onTap: () => _openContact('mailto', club.email),
          ),
          _InfoLine(
            icon: Icons.phone_outlined,
            text: club.phone,
            onTap: () => _openContact('tel', club.phone),
          ),
          _InfoLine(
            icon: Icons.account_balance_outlined,
            text: <String>[
              if (club.city.isNotEmpty) club.city,
              if (club.university.isNotEmpty) club.university,
            ].join(' · '),
          ),

          if (club.clubPurpose.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              club.clubPurpose,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Belgeler ────────────────────────────────────────────
          if (club.documents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showDocuments = !_showDocuments),
              icon: Icon(
                _showDocuments ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(
                context.t('admin.documents', <String, Object?>{
                  'count': club.documents.length,
                }),
              ),
            ),
            if (_showDocuments)
              for (final MapEntry<String, Map<String, dynamic>> entry
                  in club.documents.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.description_outlined,
                    color: context.brandInk,
                  ),
                  title: Text(
                    context.t('clubDocuments.doc.${entry.key}.title'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.value['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openDocument('${entry.value['url'] ?? ''}'),
                ),
          ],

          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandColors.success,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _busy ? null : _approve,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(context.t('admin.action.approve')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.danger,
                    side: const BorderSide(color: BrandColors.danger),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _busy ? null : _block,
                  icon: const Icon(Icons.block, size: 18),
                  label: Text(context.t('admin.action.block')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reddetmeden geri gönderme: kulüp eksiği tamamlayıp yeniden
          // yükleyebilsin diye ayrı bir yol.
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _busy ? null : _requestFix,
            icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
            label: Text(context.t('admin.action.needsDocuments')),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;

  /// Verilirse satır dokunulabilir olur (arama / e-posta).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    // İletişim satırları kırpılmamalı: uzun bir e-posta adresinin sonu
    // görünmezse yönetici kulübe ulaşamaz.
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: context.inkMuted),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: onTap == null
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
            maxLines: 2,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: row,
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// İstatistikler (admin-stats.js)
// ═══════════════════════════════════════════════════════════════════════

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminStats> stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AdminAppBar(title: context.t('admin.nav.stats')),
      body: stats.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('admin.feedback.error'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (AdminStats data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            // ── Sistem toplamları ────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: _TotalCard(
                    icon: Icons.school_outlined,
                    label: context.t('admin.stats.students'),
                    value: data.totals.students,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TotalCard(
                    icon: Icons.groups_outlined,
                    label: context.t('admin.stats.clubs'),
                    value: data.totals.clubs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TotalCard(
                    icon: Icons.male,
                    label: context.t('admin.stats.male'),
                    value: data.totals.male,
                    accent: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TotalCard(
                    icon: Icons.female,
                    label: context.t('admin.stats.female'),
                    value: data.totals.female,
                    accent: const Color(0xFFDB2777),
                  ),
                ),
              ],
            ),

            // ── Şehir bazlı dağılım ──────────────────────────────
            const SizedBox(height: 22),
            _StatsSection(context.t('admin.stats.byCity')),
            const SizedBox(height: 10),
            _BarList(buckets: data.cityStudents),

            const SizedBox(height: 22),
            _StatsSection(context.t('admin.stats.byUniversity')),
            const SizedBox(height: 10),
            _BarList(buckets: data.universityStudents),

            // ── Ayrıntılı tablo ──────────────────────────────────
            const SizedBox(height: 22),
            _StatsSection(context.t('admin.stats.detail')),
            const SizedBox(height: 10),
            for (final CityTable table in data.cityTables)
              _CityCard(table: table),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? BrandColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.ink,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection(this.title);

  final String title;

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
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
        ],
      );
}

/// Pasta yerine yatay çubuk: küçük ekranda oran okumak için daha isabetli
/// ve ek bir grafik kütüphanesi gerektirmiyor.
class _BarList extends StatelessWidget {
  const _BarList({required this.buckets});

  final PieBuckets buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return EmptyState(message: context.t('admin.stats.noData'));
    }

    final int max = buckets.values.reduce((int a, int b) => a > b ? a : b);
    final int total = buckets.total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < buckets.labels.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            _Bar(
              label: buckets.labels[i],
              value: buckets.values[i],
              ratio: max == 0 ? 0 : buckets.values[i] / max,
              percent: total == 0 ? 0 : buckets.values[i] * 100 ~/ total,
              // "Diğer" dilimi nötr renk: gerçek bir kategori değil.
              muted: buckets.labels[i] == kOtherSliceLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.percent,
    required this.muted,
  });

  final String label;
  final int value;
  final double ratio;
  final int percent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value  ·  %$percent',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: context.subtleFill,
            valueColor: AlwaysStoppedAnimation<Color>(
              muted ? context.hairline : BrandColors.red,
            ),
          ),
        ),
      ],
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.table});

  final CityTable table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          boxShadow: BrandShape.card,
        ),
        child: Theme(
          // ExpansionTile'ın varsayılan ayraçları kartın kenarlarıyla
          // çakışıyor; kapatıp kendi düzenimizi kullanıyoruz.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Text(
              table.cityKey,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              context.t('admin.stats.cityCounts', <String, Object?>{
                'students': table.students,
                'clubs': table.clubs,
                'male': table.male,
                'female': table.female,
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: <Widget>[
              for (final UniversityRow row in table.universities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          row.university,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.t(
                          'admin.stats.universityCounts',
                          <String, Object?>{
                            'students': row.students,
                            'clubs': row.clubs,
                            'male': row.male,
                            'female': row.female,
                          },
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.inkMuted,
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

// ═══════════════════════════════════════════════════════════════════════
// Öğrenci engelleme (admin-ban.js)
// ═══════════════════════════════════════════════════════════════════════

class AdminBanScreen extends ConsumerStatefulWidget {
  const AdminBanScreen({super.key});

  @override
  ConsumerState<AdminBanScreen> createState() => _AdminBanScreenState();
}

class _AdminBanScreenState extends ConsumerState<AdminBanScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StudentProfile>> students =
        ref.watch(allStudentsProvider);

    return Scaffold(
      appBar: AdminAppBar(title: context.t('admin.nav.ban')),
      body: students.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('admin.feedback.error'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (List<StudentProfile> all) {
          final List<StudentGroup> groups = groupStudents(all, _query);

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  onChanged: (String value) => setState(() => _query = value),
                  inputFormatters: guardedInput(InputLimits.search),
                  decoration: InputDecoration(
                    hintText: context.t('admin.ban.searchPlaceholder'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: <Widget>[
                          EmptyState(
                            message: context.t('admin.ban.empty'),
                            icon: Icons.person_off_outlined,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: groups.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _StudentGroupCard(group: groups[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentGroupCard extends StatelessWidget {
  const _StudentGroupCard({required this.group});

  final StudentGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          boxShadow: BrandShape.card,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            title: Text(
              group.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              context.t('admin.ban.studentCount', <String, Object?>{
                'count': group.students.length,
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: <Widget>[
              for (final StudentProfile student in group.students)
                _StudentRow(student: student),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends ConsumerStatefulWidget {
  const _StudentRow({required this.student});

  final StudentProfile student;

  @override
  ConsumerState<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends ConsumerState<_StudentRow> {
  bool _busy = false;

  Future<void> _toggleBan() async {
    final StudentProfile student = widget.student;
    final bool banning = !student.banned;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          banning
              ? dialogContext.t('admin.ban.banButton')
              : dialogContext.t('admin.ban.unbanButton'),
        ),
        content: Text(
          dialogContext.t(
            banning ? 'admin.ban.confirmBan' : 'admin.ban.confirmUnban',
            <String, Object?>{'name': student.fullName},
          ),
        ),
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

    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setStudentBanned(student.uid, banning);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('admin.feedback.error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentProfile student = widget.student;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  student.fullName.isNotEmpty
                      ? student.fullName
                      : student.email,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    // Engellenmiş öğrenci listede hemen ayırt edilsin.
                    decoration:
                        student.banned ? TextDecoration.lineThrough : null,
                    color: student.banned ? context.inkMuted : context.ink,
                  ),
                ),
                Text(
                  <String>[
                    if (student.department.isNotEmpty) student.department,
                    if (student.studentNumber.isNotEmpty) student.studentNumber,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _toggleBan,
              style: TextButton.styleFrom(
                foregroundColor:
                    student.banned ? BrandColors.success : BrandColors.danger,
                minimumSize: const Size(0, 34),
              ),
              child: Text(
                student.banned
                    ? context.t('admin.ban.unbanButton')
                    : context.t('admin.ban.banButton'),
              ),
            ),
        ],
      ),
    );
  }
}

