/// Kulüp engelleme kararlarının saf mantığı.
///
/// Web karşılığı: `js/modules/admin/ban-actions.js`. Engelleme tek yönlü
/// değil — yönetici yanlışlıkla engellediği ya da durumu düzelen bir kulübün
/// engelini geri alabilir.
library;

import '../core/constants.dart';
import '../models/profiles.dart';

/// Engel kaldırılınca kulüp hangi aşamaya döner?
///
/// Engelleme sırasında belgeler Storage'dan siliniyor (bkz.
/// `AdminRepository.blockClub`), bu yüzden kulüp normalde belge yükleme
/// aşamasına döner. Belgeleri hâlâ duruyorsa — engel belge silmeyen bir
/// yoldan konmuşsa — doğrudan inceleme kuyruğuna geri alınır; aksi hâlde
/// yönetici zaten elindeki belgeleri kulüpten bir kez daha isterdi.
String clubStatusAfterUnban(ClubProfile club) => club.documents.isNotEmpty
    ? ClubStatus.pendingReview
    : ClubStatus.documentsPending;
