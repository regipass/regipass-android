import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import 'club_shell.dart';
import '../shared/admin_message_log.dart';
import '../shared/common_widgets.dart';

/// club-pending.html — yönetici onayı bekleme ekranı.
///
/// Kabuğun (alt çubuğun) dışındadır: bu aşamada gezilecek bir panel yok.
class ClubPendingScreen extends ConsumerStatefulWidget {
  const ClubPendingScreen({super.key});

  @override
  ConsumerState<ClubPendingScreen> createState() => _ClubPendingScreenState();
}

class _ClubPendingScreenState extends ConsumerState<ClubPendingScreen> {
  bool _refreshing = false;
  bool _approved = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  Future<void> _refreshStatus() async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null || _refreshing) return;

    setState(() {
      _refreshing = true;
      _feedback = null;
    });
    try {
      final ClubProfile? profile = await ref
          .read(profileRepositoryProvider)
          .refreshClubProfile(uid);
      if (!mounted) return;

      if (profile?.clubStatus == ClubStatus.approved) {
        // Stream'i yeniden kurup ilk değeri bekliyoruz: router'ın yönlendirme
        // kararı `sessionProvider` üzerinden hâlâ eski (bekleyen) profili
        // görürse bizi anında geri bu ekrana atar. Bu bekleme, panele
        // düşmeden önce geçiş kapısının da onaylı durumu görmesini sağlar.
        ref.invalidate(clubProfileProvider);
        await ref.read(clubProfileProvider.future);
        if (!mounted) return;
        setState(() {
          _refreshing = false;
          _approved = true;
        });
        context.go(Routes.clubHome);
        return;
      }

      setState(() {
        _feedback = context.t('clubPending.stillPending');
        _tone = FeedbackTone.info;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = context.t('clubPending.error');
          _tone = FeedbackTone.error;
        });
      }
    } finally {
      if (mounted && !_approved) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminMessage> messages =
        ref.watch(sessionProvider).clubProfile?.adminMessages ??
        const <AdminMessage>[];

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('clubPending.title'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await logout(ref);
            },
            child: Text(context.t('common.logout')),
          ),
        ],
      ),
      // Yönetici notları uzun olabildiği için gövde kaydırılabilir; içerik
      // kısa kaldığında dikey ortalama korunur.
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.hourglass_top_outlined,
                      size: 56,
                      color: BrandColors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.t('clubPending.title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    // Kulüp "bir şey mi unuttum" diye beklemesin: onayın henüz
                    // gelmediği açıkça yazılıyor.
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: BrandColors.red.withValues(
                          alpha: context.isDarkMode ? 0.16 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(
                          BrandShape.controlRadius,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: context.brandInk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.t('clubPending.notApprovedYet'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.brandInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Yöneticiden gelen notlar ──────────────────────
                    // Eksik belge gibi durumlarda yönetici başvuruyu reddetmeden
                    // sebebi buraya yazıyor (bkz. admin/club_message_panel.dart).
                    if (messages.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.t('clubPending.messages.title'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.brandInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('clubPending.messages.hint'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      AdminMessageLog(
                        messages: messages,
                        titleKey: '',
                        emptyLabelKey: '',
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Durum canlı dinlendiği için onay geldiğinde router kullanıcıyı
                    // kendiliğinden panele alır; bu düğme web'deki "Durumu Yenile"
                    // bağlantısının karşılığı.
                    OutlinedButton.icon(
                      onPressed: (_refreshing || _approved)
                          ? null
                          : _refreshStatus,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _approved ? Icons.check_circle : Icons.refresh,
                            ),
                      label: Text(
                        context.t(
                          _approved
                              ? 'clubPending.approved'
                              : _refreshing
                              ? 'clubPending.checking'
                              : 'clubPending.refresh',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Yanlış belge yüklendiyse buradan çıkış yolu yoktu: kulüp
                    // inceleme sürerken belge ekranına dönüp dosyayı değiştirebilir.
                    // Kapının bu geçişe izin vermesi için router'da ayrı bir istisna
                    // var (bkz. lib/app/router.dart).
                    TextButton.icon(
                      onPressed: (_refreshing || _approved)
                          ? null
                          : () => context.push(Routes.clubDocuments),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(context.t('clubPending.editDocuments')),
                    ),
                    Text(
                      context.t('clubPending.editDocumentsHint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: context.inkMuted,
                      ),
                    ),
                    // Onaylandığında bilgi zaten düğmenin üzerinde gösteriliyor;
                    // aynı anda altta ayrı bir metin görünürse ikisi arasındaki
                    // ifade farkı kafa karıştırır. Bu yüzden banner yalnızca
                    // onaysız/hatalı durumlarda gösterilir.
                    if (!_approved && _feedback != null) ...<Widget>[
                      const SizedBox(height: 12),
                      FeedbackBanner(message: _feedback, tone: _tone),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
