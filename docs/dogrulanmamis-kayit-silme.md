# Telefonu doğrulanmayan kaydın silinmesi (3 gün)

Hesap açıldıktan sonra **3 gün** içinde SMS doğrulaması tamamlanmazsa öğrenci
kaydı veritabanında tutulmaz, silinir.

| Parça | Yer |
| --- | --- |
| Süre ve karar | `lib/domain/account_expiry.dart` (`kPhoneVerifyGrace`, `isPhoneVerifyGraceExpired`) |
| Silme işlemi | `lib/services/account_cleanup_repository.dart` |
| Tetikleyici | `lib/app/app.dart` → `_purgeUnverifiedStudent` (oturum dinleyicisi) |
| Kullanıcıya açıklama | `signOutNoticeProvider` → giriş ekranındaki uyarı |

## Yalnızca öğrenciler

Kural **kulüplere uygulanmaz.** Kulüp akışında SMS doğrulaması hiç istenmiyor
(bkz. `getClubRouteByStatus`); doğrulanmamış bir kulüp kaydını silmek, onay
bekleyen bütün kulüpleri yok ederdi. Kulüpler numaralarını yalnızca hesap
ekranından değiştirirken doğrular (`showPhoneVerifyDialog`).

## Süre nereden sayılıyor

`student_profiles/{uid}.createdAt` — hesap açılırken
`AuthRepository.upsertBaseUser` iskelet profili yazarken koyar,
`saveStudentProfile` onboarding kaydında korur.

Alan `FieldValue.serverTimestamp()` ile yazılıyor: sunucu damgayı onaylayana
kadar **yerel anlık görüntüde `null` görünür.** Bu yüzden `createdAt`
okunamayan kayıt asla silinmez — aksi hâlde yeni açılmış hesap, ilk karede
kendini yok ederdi.

## Silme neyi kapsar

1. Storage'daki profil fotoğrafı (`photoPath`) — en iyi çaba.
2. `phone_owners` üzerindeki bekleyen rezervasyon (`release`).
3. `student_profiles/{uid}`.
4. `users/{uid}` **ve** Firebase Auth hesabı — hesapta ayrıca kulüp rolü
   varsa bu ikisi silinmez, yalnızca `roles.student` düşürülür.

Sıra önemli: Firestore yazımları Auth hesabı silinmeden ÖNCE yapılır, aksi
hâlde kurallar sahipliği doğrulayamaz.

`user.delete()` "en iyi çaba"dır: son girişin üzerinden uzun süre geçmişse
Firebase `requires-recent-login` atar. O durumda veritabanı kaydı yine de
silinmiştir; kullanıcı aynı e-postayla girerse sistem onu sıfırdan kaydolan
biri gibi karşılar.

Yayındaki `firestore.rules` bu silmelere zaten izin veriyor
(`student_profiles`: `allow delete: if isOwner(userId)`, `users`:
`allow read, write: if isOwner(userId)`) — yeni kural yayınlamak gerekmez.

## Bilinen sınır — istemci tarafı temizlik

Silme, hesabın sahibi uygulamayı bir daha açtığında çalışır. Süresi dolmuş
hesap zaten telefon doğrulama kapısının arkasında kilitli olduğu için
(`getStudentRouteByStatus` → `Routes.phoneVerify`) uygulamayı açmadan hiçbir
şey yapamaz; yani kural **erişim açısından** eksiksiz işler.

Ama uygulamayı hiç açmayan hesabın belgesi Firestore'da kalır. Bunu da
temizlemek için zamanlanmış bir Cloud Function gerekir — proje şu an
`functions/` içermiyor ve bu Blaze planı ister.

## Geriye dönük etki

Kural mevcut kayıtlara da uygulanır: `phoneVerified` alanı false olan ve 3
günden eski her öğrenci kaydı, sahibi uygulamayı açtığı ilk seferde silinir.
