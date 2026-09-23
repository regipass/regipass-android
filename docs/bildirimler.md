# Bildirimler

Uygulamada iki tür bildirim var ve ikisi de **cihazda** üretiliyor:

| Tür | Kaynak | Uygulama kapalıyken |
|---|---|---|
| Etkinlik hatırlatmaları | Cihaza kurulan alarm (`zonedSchedule`) | **Çalışır** |
| Yönetici duyuruları | Firestore dinleyicisi + anlık bildirim | Çalışmaz (bkz. [Bilinen sınır](#bilinen-sınır)) |

FCM henüz kullanılmıyor. Projede artık Cloud Functions var (`europe-west1`,
bkz. `functions/`), ama bildirim gönderen bir fonksiyon yazılmadı. Konuya
(topic) push göndermek sunucu anahtarı ister ve o anahtar istemci paketine
konulamaz; bu yüzden anlık bildirimler bir Cloud Function ile yapılacak
(bildirim iş paketi).

## Etkinlik hatırlatmaları

Üç an için alarm kurulur (`lib/domain/event_reminders.dart`):

1. **Başlangıçtan yarım saat önce** — "Etkinlik yaklaşıyor"
2. **Başlangıç anı** — "Etkinlik başladı"
3. **Son başvuru anı** — "Başvurular kapandı"

Başlangıç anı `eventDateAtMs` (gün) + `eventStartTime` (`HH:mm`) alanlarından
hesaplanır. Saat girilmemiş etkinliklerde ilk iki hatırlatma **kurulmaz**;
son başvuru hatırlatması kurulmaya devam eder.

Kimin ne aldığı:

- **Öğrenci**: kayıt olduğu etkinlikler için. Keşfetteki her etkinlik için
  alarm kurmak, ilgilenmediği yüzlerce etkinlik demekti.
- **Kulüp**: kendi düzenlediği etkinlikler için; metinler düzenleyici gözüyle
  yazılır ("katılımcı girişine hazır ol").

Alarm kimliği etkinlik kimliği + hatırlatma türünden **deterministik** olarak
üretilir (FNV-1a). Liste her tazelendiğinde bildirimler yeniden kurulur ve
eski kayıt aynı kimlikle üzerine yazılır — kopya bildirim oluşmaz.

iOS aynı anda en fazla 64 bekleyen bildirim tutar; bu yüzden en yakın 48
hatırlatma kurulur (`remindersForEvents` içindeki `limit`).

## Yönetici duyuruları

Yönetici → Bildirimler ekranında şehirler listelenir, şehrin altında o
şehrin üniversiteleri durur. Üniversiteye dokununca açılan pencerede hedef
kitle (**öğrenciler / kulüpler / her ikisi**), başlık ve metin girilip
gönderilir. En üstteki arama çubuğu hem şehir hem üniversite adında arar
(Türkçe karakter duyarsız).

Gönderilen kayıt `notifications/{id}` belgesine yazılır — **web yöneticisiyle
aynı koleksiyon ve aynı şema** (`js/modules/notifications/notifications.js`):

```json
{
  "message": "Kayıt haftası\nKulüp tanıtım günleri 12 Eylül'de başlıyor.",
  "title": "Kayıt haftası",
  "body": "Kulüp tanıtım günleri 12 Eylül'de başlıyor.",
  "audience": "both",           // student | club | both
  "university": "Ankara Üniversitesi",
  "city": "Ankara",
  "createdAtMs": 1757000000000,
  "createdAt": "<serverTimestamp>",
  "createdBy": "<yönetici uid>"
}
```

`message` zorunlu alandır; `firestore.rules` boş olmamasını ve 1000 karakteri
aşmamasını şart koşuyor. `title`/`body` yalnızca mobilin eklediği ek
alanlardır — web'den gönderilen duyurularda bulunmazlar, o yüzden mobil
okurken gövde `message` alanına düşer ve başlık yerine "Duyuru" yazar.

İstemci kendi üniversitesinin duyurularını dinler, rolüne uymayanları eler ve
yeni geleni cihaz bildirimine çevirir. Hesap açılmadan önce gönderilmiş
duyurular, Firebase Auth hesap oluşturma zamanı esas alınarak öğrenci ve kulüp
bildirim akışından çıkarılır; bildirim listesinde ve zil rozetinde görünmez.

## Koleksiyon adı: neden `notifications`

Mobil taraf bir dönem `announcements` adına yazıyordu. `firestore.rules`
içinde o adla bir blok yok; dosyanın sonundaki `match /{document=**}` her şeyi
reddettiği için **her gönderim `permission-denied` ile düşüyor**, yönetici
yalnızca "Duyuru gönderilemedi" uyarısını görüyordu. Hata `catch (_)` ile
yutulduğu için sebebi de görünmüyordu.

İki sonuç:

1. Koleksiyon adı ve hedef kitle kelimeleri web ile eşitlendi
   (`student` / `club` / `both`). Zaten yayında olan `notifications` kuralı
   mobil gönderimi de kabul ediyor ve iki panel aynı duyuruları görüyor.
2. Gönderim hatası artık yutulmuyor: `permission-denied` ayrı bir mesaj
   gösteriyor, diğer hatalarda Firestore hata kodu mesaja ekleniyor.

Kurallar yayınlanmamışsa gönderim yine reddedilir:

```bash
firebase deploy --only firestore:rules
```

Sorgu, `where('university', isEqualTo: ...)` dışında sıralama içermiyor;
bu yüzden **bileşik dizin gerekmiyor**. Sıralama istemcide yapılıyor
(`AnnouncementRepository._mapSorted`) — `orderBy` eklenirse Firestore dizin
ister ve dizin oluşana kadar ekran boş kalır.

## Platform kurulumu

**Android** (`android/app/src/main/AndroidManifest.xml`):

| İzin | Neden |
|---|---|
| `POST_NOTIFICATIONS` | Android 13+ çalışma zamanı izni |
| `VIBRATE` | Titreşim deseni |
| `RECEIVE_BOOT_COMPLETED` | Cihaz yeniden başlarken alarmların geri kurulması |
| `SCHEDULE_EXACT_ALARM` | Dakika hassasiyetli hatırlatma |

Ayrıca eklentinin iki alıcısı (`ScheduledNotificationReceiver`,
`ScheduledNotificationBootReceiver`) `<application>` içinde tanımlı; bunlar
olmadan zamanlanmış bildirim sessizce hiç görünmez.

`android/app/build.gradle.kts` içinde **core library desugaring** açık
(`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs`); eklenti
`java.time` kullandığı için bu olmadan derleme başarısız olur.

`SCHEDULE_EXACT_ALARM` Android 14'ten itibaren kullanıcı onayı ister. Onay
yoksa servis `inexactAllowWhileIdle` moduna düşer: bildirim kaybolmaz ama
birkaç dakika gecikebilir. `USE_EXACT_ALARM` bilerek kullanılmadı — o izin
alarm/takvim uygulamalarına özel ve Play incelemesinde gerekçe ister.

**Android simgesi**: `drawable/ic_notification.xml`. Uygulama simgesi
(`@mipmap/ic_launcher`) bilerek kullanılmadı — Android 5'ten beri bildirim
simgesinin yalnızca alfa kanalı kullanılıyor, renk atılıyor. Kenardan kenara
opak olan launcher simgesi bu işlemden dolu beyaz bir kare olarak çıkıyor ve
durum çubuğunda anlamsız bir blok görünüyordu.

**iOS**: `AppDelegate.swift` içinde `UNUserNotificationCenter.current().delegate`
atanıyor. Bu satır olmadan uygulama ön plandayken bildirim iOS tarafından
yutulur. Info.plist'e ek anahtar gerekmiyor.

Bildirim izni açılışta değil, kullanıcı panele girdiğinde bir kez isteniyor
(`NotificationSync`) — ilk karede çıkan bağlamsız izin kutusu daha sık
reddediliyor. İzin sistem ayarlarından kapalıysa bildirimler sayfasının
üstünde uyarı şeridi ve ayarları açan bir düğme görünür.

## Bilinen sınır

Duyurular ancak uygulama **çalışırken** (ön planda ya da arka planda canlı)
cihaz bildirimine dönüşür. Uygulaması tamamen kapalı olan kullanıcı duyuruyu
bir dahaki açılışta bildirimler sayfasında görür, ama o an telefonu titremez.

Bunu tam çözmek için sunucu tarafı gerekiyor: `notifications` koleksiyonuna
yazıldığında tetiklenen bir Cloud Function + FCM topic push
(`university_<ad>_students` gibi). Etkinlik hatırlatmaları bu sınırdan
etkilenmez, onlar işletim sistemi alarmı olarak kurulu.
