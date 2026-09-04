/// Kulüp hesap ekranındaki "Onaylanan Belgeler" kartı.
///
/// Kulüp, kaydolurken yüklediği dört belgeyi onaydan sonra hiçbir yerde
/// göremiyordu: belge ekranı (`club_documents_screen.dart`) onay kapısının
/// dışında yaşıyor ve onaylanmış bir kulüp oraya girdiğinde yaptığı her
/// kayıt `clubStatus`'ü yeniden `pending_review`e düşürüyor. Yani o ekran
/// onaylanmış kulüp için bir "görüntüleme" yeri değil.
///
/// Bu kart o boşluğu doldurur: belgeler burada YALNIZCA gösterilir. Belge
/// adına dokunmak dosyayı uygulama içinde açar (PDF gömülü görüntüleyicide,
/// görsel tam ekran); değiştirme ya da silme düğmesi bilerek yoktur —
/// onaylanmış bir başvurunun belgesi kulüp tarafından tek taraflı
/// değiştirilememeli.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../shared/media_viewer.dart';

class ClubDocumentsCard extends StatelessWidget {
  const ClubDocumentsCard({required this.profile, super.key});

  final ClubProfile profile;

  @override
  Widget build(BuildContext context) {
    final bool approved = profile.clubStatus == ClubStatus.approved;
    final bool underReview = profile.clubStatus == ClubStatus.pendingReview;

    // Hiç belge yoksa kart hiç çizilmez: boş bir "onaylanan belgeler"
    // başlığı, kullanıcıya yapacak bir şey vermeden yer kaplar.
    final bool hasAny = kClubDocTypes.any(profile.documents.containsKey);
    if (!hasAny) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                approved ? Icons.verified_outlined : Icons.folder_outlined,
                size: 18,
                color: context.brandInk,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(
                    approved
                        ? 'clubAccount.documents.approvedTitle'
                        : 'clubAccount.documents.title',
                  ),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
              ),
              _StatusBadge(approved: approved, underReview: underReview),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.t('clubAccount.documents.hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),

          for (final String docType in kClubDocTypes)
            _DocumentRow(
              label: context.t('clubDocuments.doc.$docType.title'),
              document: profile.documents[docType],
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.approved, required this.underReview});

  final bool approved;
  final bool underReview;

  @override
  Widget build(BuildContext context) {
    // Koyu modda açık moddaki koyu yeşil/kırmızı, düşük opaklıklı zeminin
    // üstünde okunmuyor; tonların koyu karşılıkları kullanılır.
    final bool dark = context.isDarkMode;
    final Color tint = approved
        ? (dark ? BrandColors.successOnDark : BrandColors.success)
        : underReview
        ? (dark ? BrandColors.infoOnDark : BrandColors.info)
        : (dark ? BrandColors.dangerOnDark : BrandColors.danger);

    final String label = context.t(
      approved
          ? 'clubAccount.documents.badge.approved'
          : underReview
          ? 'clubAccount.documents.badge.review'
          : 'clubAccount.documents.badge.incomplete',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}

/// Tek belge satırı. Belge varsa adı bir bağlantıdır; yoksa satır yine
/// çizilir ki hangi belgenin eksik olduğu görünsün.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.label, required this.document});

  final String label;
  final Map<String, dynamic>? document;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? doc = document;
    final String url = '${doc?['url'] ?? ''}';
    final String name = '${doc?['name'] ?? ''}';
    final bool available = url.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            available ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 18,
            color: available
                ? (context.isDarkMode
                      ? BrandColors.successOnDark
                      : BrandColors.success)
                : context.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                if (available)
                  InkWell(
                    onTap: () => openMedia(
                      context,
                      source: url,
                      title: name.isNotEmpty ? name : label,
                      contentType: '${doc?['contentType'] ?? ''}',
                    ),
                    child: Text(
                      name.isNotEmpty
                          ? name
                          : context.t('clubAccount.documents.open'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.brandInk,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else
                  Text(
                    context.t('clubAccount.documents.missing'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (available)
            Icon(Icons.open_in_new, size: 16, color: context.inkMuted),
        ],
      ),
    );
  }
}
