# Kulüp logosu ve kapaksız etkinlikler

İki ayrı iş, tek dosyada: kulüplerin logo yüklemesi ve kapak görseli olmayan
etkinliklerin nasıl göründüğü.

## 1. Kulüp logosu

Kulüpler hesap ekranından logo yükleyebiliyor. Logo **etkinlik penceresinde
kulüp adının sağında küçük bir rozet** olarak görünür (`EventClubHeader`).
Kapak görseliyle ilgisi yok.

| Adım | Yer |
| --- | --- |
| Fotoğraf seçimi (galeri/kamera) | `pickProfilePhoto` — öğrenci fotoğrafıyla aynı |
| Storage'a yükleme | `uploadClubLogo` → `club_logos/{uid}/logo.{uzantı}` |
| Profile yazma | `ProfileRepository.updateClubLogo` → `club_profiles/{uid}.logoUrl`, `.logoPath` |
| Yeni etkinlik | `EventRepository.createEvent` logoyu `clubLogoUrl` olarak kopyalar |
| Logo değişince | `EventRepository.syncClubLogo` kulübün tüm etkinliklerinde `clubLogoUrl` alanını tazeler |

Logo etkinlik dokümanına **kopyalanır**: öğrenci `club_profiles` dokümanlarını
okuyamıyor, kulübün logosuna ancak etkinliğin içinden ulaşabilir. Logo
yüklememiş kulüplerde rozet hiç çizilmez.

### Gereken Storage kuralı

`club_logos/` yolu için kural yoksa yükleme `storage/unauthorized` ile düşer.
Logo herkese açık okunabilir olmalı: etkinliği gören her öğrenci (ve misafir
vitrinindeki ziyaretçi) o adresi çözebilmeli.

```javascript
// Desktop/REGİPASS/storage.rules
match /club_logos/{uid}/{fileName} {
  allow read: if true;
  allow write: if request.auth != null
               && request.auth.uid == uid
               && request.resource.size < 3 * 1024 * 1024
               && request.resource.contentType.matches('image/.*');
}
```

Üst sınır uygulamada da aynı: `kMaxProfilePhotoBytes` (3 MB).

### Firestore tarafı

Yeni alanlar mevcut kuralların kapsamında; **kural değişikliği gerekmiyor**:

- `club_profiles/{uid}` — `logoUrl`, `logoPath`. Kulüp kendi dokümanını zaten
  güncelleyebiliyor.
- `events/{eventId}` — `clubLogoUrl`. Yazan taraf etkinliğin sahibi kulüp
  (`resource.data.clubId == request.auth.uid`).

`syncClubLogo` etkinlikleri 400'lük gruplar hâlinde günceller (Firestore tek
batch'te en fazla 500 yazım kabul eder).

## 2. Kapak görseli olmayan etkinlikler

Kulüp etkinliğe görsel eklemediğinde artık **hiçbir şey atanmıyor**:
`events.imageUrl` boş kaydediliyor ve uygulama kapağın yerine gri bir Regipass
perdesi çiziyor (`EventCoverPlaceholder` — marka logosu tek renge boyanmış
hâliyle, `context.subtleFill` zemin üzerinde).

Eskiden bu noktada `kNatureImagePool` havuzundan rastgele bir doğa fotoğrafı
atanıyordu. Havuz sabiti duruyor ama artık yalnızca **tanımak** için:
`isAutoCoverUrl` boş adresi, eski `placehold.co` yer tutucusunu ve havuzdaki
fotoğrafları aynı kefeye koyar; hepsinde gri perde çizilir. Böylece web'in
atadığı ya da eskiden mobilde atanmış doğa fotoğrafları da yeni görünüme
düşer — bunun için hiçbir doküman yeniden yazılmaz, karar okuma anında verilir.

Düzenleme ekranı da aynı kuralı izler: otomatik bir kapak forma taşınmaz,
kulüp yalnızca başlığı değiştirip kaydettiğinde `imageUrl` boş kalır.
