/// Mobile'a özgü ek çeviriler.
///
/// `translations.dart` üretilen bir dosyadır (kaynak: language.js) ve
/// elle düzenlenmemelidir. Web'de i18n sözlüğüne hiç girmemiş, doğrudan
/// koda gömülü Türkçe metinler (ör. register.js#friendlyError) ile mobilde
/// yeni ihtiyaç duyulan metinler burada tutulur.
///
/// Arama sırası: ek sözlük -> üretilen sözlük -> varsayılan dil -> anahtar.
library;

const Map<String, Map<String, String>>
kExtraTranslations = <String, Map<String, String>>{
  'tr': <String, String>{
    // İP-B: etkinlik bildirimleri
    'autoNotify.title': 'Otomatik bildirimler',
    'autoNotify.help':
        'Kayıtlı öğrencilere Regipass kendiliğinden bildirim gönderir. Saat '
        'girilmezse yalnızca "1 gün önce" gider.',
    'autoNotify.dayBefore': '1 gün önce (19:00) hatırlatma',
    'autoNotify.hourBefore': 'Başlamadan 1 saat önce',
    'autoNotify.atStart': 'Başladığında (girişini yapmamış olanlara)',
    'autoNotify.afterEnd': 'Bittikten sonra teşekkür (katılanlara)',
    'eventNotify.title': 'Bildirimler',
    'eventNotify.autoHelp':
        'Otomatik bildirimleri etkinliği düzenleyerek açıp kapatabilirsin.',
    'eventNotify.status.sent': 'Gönderildi',
    'eventNotify.status.pending': 'Bekliyor',
    'eventNotify.status.missed': 'Zamanı geçti',
    'eventNotify.status.off': 'Kapalı',
    'eventNotify.send': 'Bildirim gönder',
    'eventNotify.submit': 'Gönder',
    'eventNotify.audienceLabel': 'Kime',
    'eventNotify.audience.registered': 'Tüm kayıtlılar',
    'eventNotify.audience.checked_in': 'Giriş yapanlar',
    'eventNotify.audience.not_checked_in': 'Giriş yapmayanlar',
    'eventNotify.audience.waitlist': 'Bekleme listesi',
    'eventNotify.titleLabel': 'Başlık',
    'eventNotify.messageLabel': 'Mesaj',
    'eventNotify.counting': 'Alıcılar hesaplanıyor…',
    'eventNotify.willReach': '{{count}} kişiye gidecek.',
    'eventNotify.sent': 'Bildirim gönderildi: {{count}} kişi.',
    'eventNotify.historyTitle': 'Gönderilen mesajlar',
    'eventNotify.historyEmpty': 'Henüz mesaj gönderilmedi.',
    'eventNotify.historyError': 'Geçmiş yüklenemedi.',
    'eventNotify.errors.required': 'Başlık ve mesaj yaz.',
    'eventNotify.errors.unknown-tag':
        'Tanınmayan etiket var. Kullanılabilenler: {ad}, {etkinlik}, '
        '{tarih}, {saat}, {yer}, {kulüp}.',
    'eventNotify.errors.fill': 'Şablondaki … yerini doldurmadın.',
    'eventNotify.audience.payment_pending': 'Ödemesi bekleyenler',
    'eventNotify.templateLabel': 'Hazır şablon',
    'eventNotify.templateNone': 'Boş mesaj',
    'eventNotify.tagsLabel': 'Akıllı etiket ekle',
    'eventNotify.previewLabel': 'Önizleme (örnek öğrenci)',
    'eventNotify.quota': 'Bugün kalan: {{left}}/{{limit}}',
    'eventNotify.nextIn': 'sonraki gönderim {{minutes}} dk sonra',
    'eventNotify.tag.ad': 'Öğrencinin adı',
    'eventNotify.tag.etkinlik': 'Etkinlik adı',
    'eventNotify.tag.tarih': 'Tarih',
    'eventNotify.tag.saat': 'Saat',
    'eventNotify.tag.yer': 'Yer',
    'eventNotify.tag.kulup': 'Kulübün adı',
    'eventNotify.errors.title-required': 'Başlık yaz.',
    'eventNotify.errors.message-required': 'Mesaj yaz.',
    'eventNotify.errors.too-soon':
        'Aynı etkinlikte iki mesaj arasında en az 10 dakika olmalı.',
    'eventNotify.errors.daily-limit':
        'Bu etkinlik için bugünkü mesaj sınırına (5) ulaştın.',
    'eventNotify.errors.messaging-closed':
        'Etkinliğin üzerinden 7 gün geçti; mesaj gönderilemez.',
    'eventNotify.errors.no-recipients': 'Bu grupta kimse yok.',
    'eventNotify.errors.event-cancelled':
        'İptal edilen etkinliğe mesaj gönderilemez.',
    'eventNotify.errors.club-not-approved':
        'Kulübün onaylanmadan mesaj gönderemezsin.',
    'eventNotify.errors.club-banned': 'Kulüp hesabın askıda.',
    'eventNotify.errors.not-event-club':
        'Bu etkinlik senin kulübüne ait değil.',
    // İP-T: takvime ekle
    'calendar.add': 'Takvime ekle',
    'calendar.google': 'Google Takvim',
    'calendar.ics': 'Takvim dosyası (.ics)',
    'calendar.icsHint': 'Apple Takvim, Outlook ve diğerleri',
    // İP-KB: kulübün öğrenci engeli
    'clubBlock.title': 'Kulüpten engelle',
    'clubBlock.action': 'Kulüpten engelle',
    'clubBlock.body':
        '{{name}} kulübünün etkinliklerinden engellenecek: yeni etkinliklere '
        'kaydolamaz, bekleme listesine giremez.',
    'clubBlock.reasonLabel': 'Gerekçe',
    'clubBlock.reasonHelper':
        'Zorunlu. Öğrenciye gösterilmez; kulübün ve Regipass yönetiminin '
        'kaydında durur.',
    'clubBlock.reasonRequired': 'En az 3 karakterlik bir gerekçe yaz.',
    'clubBlock.removeFuture':
        'Gelecek etkinliklerdeki kayıtlarını da sil (öğrenciye "kaydın '
        'iptal edildi" bildirimi gider)',
    'clubBlock.done':
        '{{name}} kulübünün etkinliklerinden engellendi. Silinen gelecek '
        'kayıt: {{count}}.',
    'clubBlock.listTitle': 'Engellenen öğrenciler',
    'clubBlock.listHelp':
        'Buradaki öğrenciler kulübünün yeni etkinliklerine kaydolamaz. '
        'Öğrenciyi etkinliğin kayıt listesindeki "Kulüpten engelle" ile '
        'ekleyebilirsin.',
    'clubBlock.empty': 'Engellediğin öğrenci yok.',
    'clubBlock.unblock': 'Engeli kaldır',
    'clubBlock.unblockConfirm':
        '{{name}} için engel kaldırılsın mı? Kulübünün etkinliklerine yeniden '
        'kaydolabilir.',
    'clubBlock.unblocked': '{{name}} için engel kaldırıldı.',
    'clubBlock.studentFallback': 'Öğrenci',
    'clubBlock.error': 'İşlem tamamlanamadı. Tekrar dene.',
    'clubBlock.errors.reason-required':
        'En az 3 karakterlik bir gerekçe yazmalısın.',
    'clubBlock.errors.student-not-related':
        'Yalnızca etkinliğine kaydolmuş öğrencileri engelleyebilirsin.',
    'clubBlock.errors.club-not-approved':
        'Kulübün onaylanmadan öğrenci engelleyemezsin.',
    'clubBlock.errors.club-banned': 'Kulüp hesabın askıda.',
    'clubBlock.errors.not-a-club': 'Bu işlem yalnızca kulüp hesabıyla yapılır.',
    'clubBlock.errors.invalid-student': 'Öğrenci bulunamadı.',
    'registration.errors.blocked-by-club':
        'Bu kulübün etkinliklerine kaydolamıyorsun.',
    // İP-M1: yönetim hesabı (rol etiketi + doğrulayıcı uygulama)
    'auth.error.userDisabled':
        'Bu hesap askıya alındı ya da silinmek üzere. Bir yanlışlık olduğunu '
        'düşünüyorsan product@regipass.com adresine yaz.',
    'auth.error.staffSetupRequired':
        'Yönetim hesabında iki aşamalı doğrulama henüz kurulmamış. Kurulumu '
        'bilgisayardan regipass.com/admin-login.html adresinde yap.',
    'auth.totp.title': 'Doğrulama kodu',
    'auth.totp.body':
        'Doğrulayıcı uygulamadaki (Google Authenticator vb.) Regipass '
        'satırındaki 6 haneli kodu yaz.',
    'auth.totp.label': 'Kod',
    'auth.totp.format': '6 haneli kodu yaz.',
    'auth.totp.submit': 'Giriş yap',
    'auth.totp.invalid':
        'Kod hatalı ya da süresi geçti. Uygulamadaki güncel kodu yaz.',
    'auth.totp.unsupported': 'Bu hesapta doğrulayıcı uygulama kayıtlı değil.',
    'admin.ban.clubImpact':
        'Bu kulübün {{events}} gelecek etkinliği İPTAL edilecek; {{people}} '
        'kayıtlı kişiye bildirim gidecek. Kulüp hesabı giriş yapamayacak.',
    'admin.ban.reasonLabel': 'Gerekçe',
    'admin.ban.reasonHelper':
        'Zorunlu. İşlem kaydına yazılır; öğrencilere gösterilmez.',
    'admin.ban.reasonRequired': 'Engellemek için gerekçe yazmalısın.',
    // register.js içinde sabit metin olarak duruyordu
    'auth.error.roleAlreadyExists':
        'Bu hesap türü zaten var. Lütfen giriş yap.',
    'auth.error.emailRegisteredWrongPassword':
        'Bu e-posta kayıtlı, şifre hatalı.',
    // Kayıt ekranındaki zorunlu KVKK/sözleşme onayı işaretlenmeden kayıt
    // düğmesi zaten pasif kalır; bu metin yalnızca Enter/gönder ile
    // tetiklenen kenar durumlar için (bkz. register_screen.dart).
    'auth.feedback.termsRequired':
        'Devam etmek için Kullanıcı ve Kulüp Sözleşmesi ile KVKK Aydınlatma '
        'Metni\'ni onaylamalısın.',
    // Onay özeti — bilgi formunun altında ve hesap kartlarında.
    'legal.consent.summaryTitle': 'Onayladığın metinler',
    'legal.consent.acceptedAt': 'Onay zamanı',
    'legal.consent.tileLabel': 'Metin onayı',
    'legal.consent.notRecorded': 'Kayıt yok',
    'legal.consent.marketingOn': 'pazarlama izni verildi',
    'legal.consent.marketingOff': 'pazarlama izni verilmedi',

    // Telefonu doğrulanmadığı için silinen kayıt (bkz. domain/account_expiry.dart)
    'auth.notice.unverifiedPhoneRemoved':
        'Belirtilen süre içerisinde hesabın doğrulanmadığı için '
        'silinmiştir. Dilersen yeniden hesap oluşturabilirsin.',
    // Doğrulama ekranındaki süre uyarısı — süre domain/account_expiry.dart
    // içindeki kPhoneVerifyGrace ile aynı olmalı.
    'phoneVerify.deleteWarning':
        'Telefon numaranı 15 dakika içinde doğrulamazsan hesabın silinir.',

    // Giriş ekranı (yeniden tasarım) ve Keşfet
    'nav.explore': 'Keşfet',
    'auth.noAccount': 'Hesabın yok mu?',
    'auth.haveAccount': 'Zaten hesabın var mı?',
    'common.back': 'Geri',

    // Şifremi unuttum
    'forgotPassword.title': 'Şifreni Sıfırla',
    'forgotPassword.emailRequired': 'Önce e-posta adresini gir.',
    'forgotPassword.savedNumber': 'Kayıtlı numaran:',
    'forgotPassword.enterPhoneHint':
        'Kodu gönderebilmemiz için numaranı tam olarak yaz:',
    'forgotPassword.sendCode': 'Doğrulama kodu gönder',
    'forgotPassword.phoneMismatch':
        'Girdiğin telefon numarası bu e-posta adresine kayıtlı değil. '
        'Lütfen hesabına kayıtlı telefon numarasını gir.',
    // SMS gönderilmeden önceki maske denetimi. Üç mesaj da kayıtlı maskeyi
    // tekrar gösteriyor: kullanıcı hatayı okurken numarayı yeniden
    // görebilsin diye (maske kartı klavye açıkken ekranda kalmayabiliyor).
    'forgotPassword.phoneNotOnAccount':
        'Girdiğin numara bu hesaba ait değil. Kayıtlı numara: {{masked}}',
    'forgotPassword.maskCountryMismatch':
        'Ülke kodu kayıtlı numaranla uyuşmuyor. Kayıtlı numara: {{masked}}',
    'forgotPassword.maskLengthMismatch':
        'Numaranın hane sayısı kayıtlı numaranla uyuşmuyor. '
        'Kayıtlı numara: {{masked}}',
    'forgotPassword.maskSuffixMismatch':
        'Girdiğin numara kayıtlı numaranla uyuşmuyor. Kayıtlı numara: {{masked}}',
    'forgotPassword.noPhoneOnRecord':
        'Bu e-postaya bağlı doğrulanmış bir telefon numarası yok, bu yüzden '
        'SMS ile kurtarma yapılamıyor. Destek ile iletişime geç.',
    'forgotPassword.tooManyAttempts':
        'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.',
    'forgotPassword.newPasswordHint': 'Doğrulandı. Yeni şifreni belirle.',
    'forgotPassword.savePassword': 'Şifreyi Kaydet',
    'forgotPassword.success': 'Şifren güncellendi.',
    'forgotPassword.continue': 'Girişe dön',
    'forgotPassword.genericError': 'İşlem tamamlanamadı. Lütfen tekrar dene.',
    'forgotPassword.sendTimeout':
        'SMS isteği zamanında yanıtlanmadı. Bağlantını kontrol edip tekrar dene.',
    'forgotPassword.operationTimeout':
        'İşlem zamanında yanıtlanmadı. Bağlantını kontrol edip tekrar dene.',
    'forgotPassword.verifying': 'Kod doğrulanıyor',
    'forgotPassword.savedSignInRequired':
        'Şifren kaydedildi. Giriş ekranından yeni şifrenle giriş yapabilirsin.',
    'account.sharedPhoneNotice':
        'Bu telefon aynı e-postaya bağlı öğrenci ve kulüp hesaplarında ortak kullanılır ve zaten doğrulanmıştır. Bu formdan değiştirilemez.',
    'auth.error.networkFailed': 'Bağlantı kurulamadı. İnternetini kontrol et.',
    'explore.guestTitle': 'Misafir olarak geziyorsun',
    'explore.guestDesc':
        'Etkinliklere göz atabilirsin. Kayıt olmak, QR oluşturmak ve belge almak için giriş yapmalısın.',
    'explore.signInToJoin': 'Katılmak için giriş yap',
    'explore.empty': 'Şu anda gösterilecek etkinlik yok.',
    'explore.loadError': 'Etkinlikler yüklenemedi. Lütfen tekrar dene.',
    'explore.permissionDenied':
        'Etkinlikleri görmek için giriş yapman gerekiyor.',

    // Öğrenci alt çubuğu / üst çubuğu
    'student.nav.account': 'Hesabım',
    'student.notifications.title': 'Bildirimler',
    'notifications.announcement': 'Duyuru',
    'student.notifications.empty': 'Şimdilik yeni bir bildirimin yok.',

    // ── Bildirimler ───────────────────────────────────────────────
    // Etkinlik hatırlatmaları. Anahtar şeması:
    //   notification.event.<kitle>.<tür>.<title|body>
    // (bkz. lib/domain/event_reminders.dart#reminderTitleKey)
    'notification.event.student.upcoming.title': 'Etkinlik yaklaşıyor',
    'notification.event.student.upcoming.body':
        '{{title}} yarım saat sonra başlıyor.',
    'notification.event.student.started.title': 'Etkinlik başladı',
    'notification.event.student.started.body': '{{title}} şimdi başladı.',
    'notification.event.student.deadline.title': 'Başvurular kapandı',
    'notification.event.student.deadline.body':
        '{{title}} için başvuru süresi doldu.',

    'notification.event.club.upcoming.title': 'Etkinliğin yaklaşıyor',
    'notification.event.club.upcoming.body':
        '{{title}} yarım saat sonra başlıyor. Katılımcı girişine hazır ol.',
    'notification.event.club.started.title': 'Etkinlik başladı',
    'notification.event.club.started.body': '{{title}} şimdi başladı.',
    'notification.event.club.deadline.title': 'Başvurular kapandı',
    'notification.event.club.deadline.body':
        '{{title}} için başvurular sona erdi, katılımcı listen kesinleşti.',

    'notification.disabled':
        'Bildirimler cihaz ayarlarından kapalı. Etkinlik hatırlatmaları ve '
        'duyurular telefonuna ulaşmayacak.',
    'notification.openSettings': 'Bildirim ayarlarını aç',

    // ── Yönetici: duyuru gönderme ─────────────────────────────────
    'admin.notify.searchPlaceholder': 'Şehir veya üniversite ara',
    'admin.notify.hint':
        'Duyuru göndermek için bir şehri açıp üniversiteye dokun.',
    'admin.notify.noResults': 'Aramana uyan şehir veya üniversite yok.',
    'admin.notify.universityCount': '{{count}} üniversite',
    'admin.notify.audience': 'Kime gönderilsin?',
    'admin.notify.audience.students': 'Öğrenciler',
    'admin.notify.audience.clubs': 'Kulüpler',
    'admin.notify.audience.all': 'Her ikisi',
    'admin.notify.titleLabel': 'Bildirim başlığı',
    'admin.notify.bodyLabel': 'Bildirim metni',
    'admin.notify.required': 'Bu alan boş bırakılamaz.',
    'admin.notify.send': 'Gönder',
    'admin.notify.sent': '{{university}} için duyuru gönderildi.',
    'admin.notify.sendError': 'Duyuru gönderilemedi. Lütfen tekrar dene.',
    'admin.notify.sendDenied': 'Duyuru gönderme yetkin yok.',
    'admin.notify.broadcastButton': 'Genel Duyuru',
    'admin.notify.broadcastSubtitle':
        'Tüm şehirlerdeki üniversitelere aynı anda gönderilir.',
    'admin.notify.broadcastHeader': 'Tüm Üniversiteler',
    'admin.notify.broadcastConfirmTitle': 'Genel duyuru gönderilsin mi?',
    'admin.notify.broadcastConfirmBody':
        'Bu duyuru {{count}} üniversitedeki tüm hedef kitleye tek seferde '
        'gönderilecek. Bu işlem geri alınamaz.',
    'admin.notify.broadcastSent': 'Genel duyuru tüm üniversitelere gönderildi.',

    // Üretilen sözlükte diakritiksiz kalmış öğrenci metinleri
    'studentAccount.title': 'Hesabım',
    'studentAccount.edit': 'Bilgileri Düzenle',
    // Kulüp hesabının üst çubuğu da aynı sözlükten okuyor; oradaki
    // "Hesabim"/"Duzenle" yazımları burada düzeltiliyor.
    'clubAccount.title': 'Hesabım',
    'clubAccount.edit': 'Bilgileri Düzenle',
    'clubAccount.section.manager': 'Yetkili Bilgileri',
    'clubAccount.section.club': 'Kulüp Bilgileri',
    'studentAppointments.title': 'Etkinliklerim',
    'studentAppointments.activeTitle': 'Aktif Etkinliklerim',
    'studentAppointments.pastTitle': 'Geçmiş Etkinliklerim',

    // Hesap ayarları
    'settings.appearance': 'Görünüm',
    'settings.appearance.light': 'Açık mod',
    'settings.appearance.dark': 'Koyu mod',
    'settings.language': 'Dil',
    // NOT: 'account.switchRole' kaldırıldı. Bir e-postaya tek rol bağlandığı
    // için rol değiştirme diye bir işlem yok; düğmesi de silindi (web'de zaten
    // hiç yoktu).

    // Hesap ekranındaki telefon alanı + doğrulama pop-up'ı
    'account.phoneChangeHint':
        'Numarayı değiştirirsen kaydettikten sonra açılan pencerede SMS ile '
        'doğrulaman gerekir. Doğrulanmadan numara değişmez.',
    'account.phoneNotChanged':
        'Numara doğrulanmadı; kayıtlı numaran olduğu gibi kaldı.',
    // Telefon doğrulama hataları (üretilen sözlükte karşılığı yok)
    'phoneVerify.error.browserCanceled':
        'Doğrulama yarıda kaldı. Kodu tekrar gönder.',
    'phoneVerify.error.browserAlreadyOpen':
        'Devam eden bir doğrulama var. Birkaç saniye sonra tekrar dene.',
    'phoneVerify.error.network':
        'İnternet bağlantını kontrol edip tekrar dene.',
    'phoneVerify.error.deviceCheckFailed':
        'SMS gönderilemedi. Lütfen daha sonra tekrar dene.',
    // Bir e-postaya artık tek rol bağlanabildiği için kayıt akışında çıkan
    // uyarı (bkz. AuthRepository kayıt akışı).
    'auth.error.emailAlreadyRegistered':
        'Bu e-posta ile bir hesap var. Giriş yap ya da şifreni yenile.',
    'phoneVerifySheet.title': 'Telefon Numarasını Doğrula',
    'phoneVerifySheet.subtitle':
        'Bu numaraya 6 haneli bir doğrulama kodu göndereceğiz. Vazgeçmek '
        'istersen sağ üstteki düğmeden işlemi iptal edebilirsin.',

    // Fotoğraf seçimi (mobilde galeri/kamera ayrımı web'de yoktu)
    'form.photoFromGallery': 'Galeriden Seç',
    'form.photoFromCamera': 'Fotoğraf Çek',
    // Operatör ön eki denetimi (bkz. data/mobile_prefixes.dart): ülkenin cep
    // ön eklerine uymayan numara — sabit hat ya da yanlış ülke.
    'form.phoneOperatorPrefix':
        '{{country}} cep numaraları {{prefixes}} ile başlamalı.',
    'form.phoneDigits': '{{digits}} haneli olmalı',
    // Aynı denetimin SMS gönderimi öncesi hâli: alanın altında değil, geri
    // bildirim şeridinde gösterildiği için ülke adıyla birlikte yazılır.
    'form.phoneCountryDigits':
        '{{country}} numaraları {{digits}} haneli olmalı.',
    // Alanın altında gösterilen kısa uyarı; pop-up içindeki uzun açıklama
    // 'phoneVerify.error.numberInUse' anahtarında.
    'form.phoneTaken': 'Bu numara başka bir hesaba ait. Farklı bir numara gir.',
    // Numaraya başka bir hesap kod istedi ama henüz doğrulamadı; rezervasyon
    // 15 dakika sonra kendiliğinden düşer (bkz. phone_directory_repository).
    'form.phonePending':
        'Bu numara için doğrulama sürüyor. 15 dakika sonra tekrar dene.',
    // Alanın altındaki canlı sorgu satırı (bkz. shared/live_phone_field.dart).
    'form.phoneChecking': 'Numara kontrol ediliyor…',
    'form.phoneAvailable': 'Bu numara kullanılabilir.',

    // Etkinlik detay penceresi
    'eventModal.info': 'Etkinlik Bilgileri',
    'eventModal.club': 'Kulüp',
    'eventModal.eventDate': 'Etkinlik Tarihi',
    'eventModal.deadline': 'Son Başvuru',
    'eventModal.fee': 'Ücret',
    'eventModal.free': 'Ücretsiz',
    'eventModal.quota': 'Kontenjan',
    'eventModal.unlimited': 'Sınırsız',
    'eventModal.location': 'Konum',
    'eventModal.sessions': 'Oturum Sayısı',
    'eventModal.sessionsValue': '{{count}} oturum',
    'eventModal.clubContact': 'Kulüp İletişim',
    'eventModal.feeContactNote':
        'Bu etkinlik ücretlidir. Ücret ve ödeme için kulübün iletişim '
        'numarasıyla iletişime geçin.',
    'eventModal.audience': 'Hedef Kitle',
    'eventModal.description': 'Açıklama',
    'eventModal.purpose': 'Amaç',

    // Ortak eylemler
    'common.save': 'Kaydet',
    'common.cancel': 'İptal',
    'common.retry': 'Tekrar dene',
    // İP-Y: yoklama ve giriş sunucuda
    'attendance.flag.edge': 'alanın kenarında',
    'attendance.flag.lowAccuracy': 'konum doğruluğu düşük',
    'attendance.flag.unsignedQr': 'eski uygulama QR\'ı',
    'attendance.flag.delayed': 'gecikmeli işlendi',
    'attendance.flag.unverified': 'sunucuda doğrulanmadı',
    'attendance.stage.door': 'Kapı',
    'attendance.stage.session': '{{n}}. oturum',
    'attendance.suspicious.title': 'Şüpheli',
    'attendance.error.alreadyCheckedIn':
        'Bu etkinlik için girişin daha önce onaylandı.',
    'attendance.error.sessionNotStarted':
        'Oturum henüz başlatılmadı. Kulüp oturumu başlattığında QR\'ı tekrar okut.',
    'attendance.error.banned': 'Hesabın kısıtlandığı için giriş yapılamıyor.',
    'attendance.qrKeyError':
        'QR oluşturulamadı. İnternet bağlantısını kontrol edip tekrar dene.',
    'attendance.entryRotatingHint':
        'Öğrenciler bu kodu kendi telefonlarıyla okutur. Kod {{seconds}} sn sonra yenilenecek.',
    'clubScan.ticketMismatch':
        'Bilet kodu kayıtla eşleşmiyor (eski ya da taklit bilet). Öğrenci bileti uygulamadan yeniden açsın.',
    'clubScan.ticketLegacy':
        'Eski uygulama bileti (kodsuz) — kimliği kontrol edin.',
    'common.loading': 'Yükleniyor...',
    'common.logout': 'Çıkış Yap',
    'common.select': 'Seçiniz',
    'common.search': 'Ara...',
    // Çok satırlı alanlarda klavyenin üstünde çıkan çubuk
    // (bkz. lib/core/keyboard.dart).
    'common.done': 'Bitti',

    // Kamera / QR (mobilde web'den farklı izin akışı var)
    'scan.permissionDenied': 'Kamera izni kapalı. Ayarlardan aç.',
    'scan.pointCamera': 'Kamerayı QR koda tutun.',
    'scan.ready': 'Sonraki öğrenci için hazır.',
    'scan.successTitle': 'Giriş Başarılı',
    'scan.failTitle': 'Giriş Başarısız',
    'scan.notRegipassQr': 'Bu QR Regipass giriş kodu değil.',
    'scan.missingEventInfo': 'QR kod eksik ya da bozuk.',
    'scan.notSessionQr': 'Bu QR bir oturum giriş kodu değil.',
    'clubScan.needsDoorCheckin':
        '{{name}} kapıda giriş yapmamış — yoklama için önce check-in gerekiyor.',
    'scan.notDoorQr': 'Bu QR bir kapı giriş kodu değil.',
    'scan.doorClosed': 'Kapı girişi henüz açık değil.',
    'scan.needsDoorCheckin': 'Önce kapıdaki giriş QR\'ını okutman gerekiyor.',
    'scan.doorSuccess':
        'Kapı girişin kaydedildi. Oturum yoklamasına katılabilirsin.',
    'scan.doorOnlySuccess': 'Etkinlik girişin kaydedildi. İyi etkinlikler!',
    'scan.locationRequired':
        'Bu giriş için konum gerekiyor. Konumu açıp tekrar dene.',
    'scan.tooFar':
        'Etkinlik konumundan uzaktasın ({{distance}}; en fazla {{radius}} m).',
    'scan.missingSessionInfo': 'QR kod eksik ya da bozuk.',
    'scan.eventNotFound': 'Etkinlik bulunamadı.',
    'scan.notSessionBased': 'Bu etkinlik oturum bazlı değil.',
    'scan.sessionsCompleted': 'Etkinlik oturumları tamamlandı.',
    'scan.qrExpired': 'Bu QR artık geçerli değil — oturum ilerledi.',
    // Ekrandaki oturum kodu 20 saniyede bir yenilenir; ekran görüntüsüyle
    // paylaşılan kod bu adımda düşer (bkz. domain/session_qr_window.dart).
    'scan.qrSlotExpired':
        'Bu kod artık geçerli değil — ekrandaki QR 20 saniyede bir yenileniyor. Güncel kodu okut.',
    'scan.notRegistered': 'Bu etkinliğe kayıtlı değilsiniz.',
    'scan.eventClosedNotRegistered': 'Bu etkinliğin süresi geçmiştir.',
    'scan.alreadyCheckedInSession':
        'Bu oturumda ({{current}}/{{total}}) zaten giriş yaptınız.',
    'scan.checkinSaveFailed': 'Giriş kaydedilemedi. Tekrar dene.',
    'scan.permissionError': 'Bu giriş kaydedilemedi. Kulüp görevlisine bildir.',
    'scan.sessionSuccess':
        '{{current}}. oturumdasınız (katılım {{attended}}/{{total}}).',
    'scan.otherEventQr':
        'Bu QR başka bir etkinliğe ait. Girdiğiniz etkinliğin oturum QR\'ını okutun.',

    // Oturumlu etkinlikte öğrenci QR üretmez, kulübün oturum QR'ını okutur.
    'studentAppointments.modal.showTicket': 'Biletimi Göster',
    'studentAppointments.modal.scanQr': 'Oturum QR\'ını Okut',
    'studentAppointments.modal.scanReady':
        '{{current}}. oturum açık. Kulübün ekranındaki QR\'ı okutarak giriş yap.',
    'studentAppointments.modal.scanNotStarted':
        'Kulüp henüz ilk oturumu başlatmadı. Oturum açıldığında bu düğme aktifleşir.',
    'studentAppointments.modal.scanAlreadyDone':
        '{{current}}. oturumun girişi yapıldı. Kulüp yeni oturumu açtığında düğme yeniden aktifleşir.',
    'studentAppointments.modal.scanCompleted':
        'Etkinliğin tüm oturumları tamamlandı; okutulacak yeni QR yok.',
    'studentAppointments.modal.scanUnavailable':
        'Etkinlik kaldırıldığı için oturum girişi yapılamıyor.',

    // Konum
    'location.permissionDenied': 'Konum izni kapalı. Giriş için konumu aç.',
    'location.gettingLocation': 'Konum alınıyor...',

    // ── Kulüp tarafı ────────────────────────────────────────────────
    'club.nav.myEvents': 'Etkinliklerim',
    'club.nav.newEvent': 'Yeni Etkinlik',
    'clubSessionQr.subtitle': 'Oturumlu etkinlikler',
    'clubSessionQr.empty':
        'Oturumlu etkinliğin yok. QR yalnızca birden fazla oturumu olan '
        'etkinlikler için üretilir; tek oturumlu etkinliklerde girişi '
        'öğrencinin QR\'ını okutarak alırsın.',
    'clubSessionQr.manage': 'Etkinliği Yönet',
    'clubSessionQr.hint':
        'Bir etkinliğe dokun: oturum QR\'ı ekrana gelir, etkinliğin kendisi '
        'de arkasında açılır.',
    'clubDashboard.empty':
        'Şu anda gösterilecek etkinlik yok. Kendi etkinliklerini "Etkinliklerim" sekmesinden yönetebilirsin.',

    'clubEvents.title': 'Etkinlik',
    'clubEvents.edit': 'Düzenle',
    'clubEvents.status.closed': 'Başvuru Kapalı',
    'clubEvents.group.active': 'Aktif',
    'clubEvents.group.upcoming': 'Gelecek',
    'clubEvents.group.past': 'Geçmiş',
    'clubEvents.empty.active':
        'Aktif etkinlik bulunmuyor. Alttaki + düğmesinden yeni etkinlik oluşturabilirsin.',
    'clubEvents.empty.upcoming': 'Gelecek etkinlik bulunmuyor.',
    'clubEvents.empty.past': 'Geçmiş etkinlik bulunmuyor.',
    'clubEvents.feedback.loadError':
        'Etkinlikler yüklenemedi. Lütfen tekrar dene.',
    'clubEvents.feedback.updateError':
        'İşlem tamamlanamadı. Lütfen tekrar dene.',
    'clubEvents.feedback.deleted': 'Etkinlik kaldırıldı.',
    'clubEvents.feedback.deleteError':
        'Etkinlik silinemedi. Lütfen tekrar dene.',
    'clubEvents.delete.title': 'Etkinliği sil',
    'clubEvents.delete.global': 'Her Yerden Sil',
    'clubEvents.delete.local': 'Listemden Kaldır',
    'clubEvents.delete.action': 'Sil',
    'clubEvents.delete.confirmGlobal':
        'Bu etkinlik tüm kullanıcılardan kaldırılacak. Devam etmek istiyor musun?',
    'clubEvents.delete.confirmLocal':
        'Geçmiş etkinlik yalnızca kendi listenden kaldırılacak; öğrencilerin kayıtları etkilenmez.',

    'clubEvents.registrations.title': 'Kayıtlar',
    'clubEvents.qr.locationRequired':
        'QR oluşturmak için etkinliği düzenleyip haritadan konum seç. Öğrencinin güncel konumu bu konumla karşılaştırılacak.',
    'clubEvents.quota.title': 'Kontenjan',
    'clubEvents.quota.remaining': '{{count}} kişilik yer kaldı.',
    'clubEvents.quota.full': 'Kontenjan doldu.',
    'clubEvents.quota.autoPaused':
        'Kontenjan dolduğu için kayıtlar beklemeye alındı. Kontenjanı artırırsan kayıtlar kendiliğinden yeniden açılır.',
    'clubEvents.registrations.subtitle':
        'Kayıtları durdurduğunda öğrenciler bu etkinliğe başvuramaz.',
    'clubEvents.registrations.closeAction': 'Kayıtları Durdur',
    'clubEvents.registrations.openAction': 'Kayıtları Yeniden Başlat',
    'clubEvents.registrations.pastLabel': 'Kayıtlar kapandı',
    'clubEvents.registrations.confirmClose':
        'Bu etkinlik için kayıtları durdurmak istiyor musun?',
    'clubEvents.registrations.confirmOpen':
        'Bu etkinlik için kayıtları yeniden başlatmak istiyor musun?',
    'clubEvents.registrations.closed': 'Etkinlik kayıtları durduruldu.',
    'clubEvents.registrations.opened': 'Etkinlik kayıtları yeniden başlatıldı.',
    'clubEvents.registrations.blockedRunning':
        'Etkinlik başladığı için kayıtlar durduruldu ve şu anda yeniden açılamaz.\n\n'
        'Yeniden açmak için etkinliği en başa döndürmen gerekiyor: önce kapı '
        'check-in\'ini bitir, sonra oturumları tek tek en başa (0) geri al. '
        'Etkinlik başa döndüğünde kayıtlar yeniden açılabilir olur.',

    'clubEvents.session.title': 'Oturumlar',
    'clubEvents.session.notStarted': 'Oturum başlatılmadı (0/{{total}})',
    'clubEvents.session.active': 'Aktif oturum: {{current}}/{{total}}',
    'clubEvents.session.lastActive': 'Son oturum aktif: {{total}}/{{total}}',
    'clubEvents.session.allDone':
        'Tüm oturumlar tamamlandı ({{total}}/{{total}})',
    // İlerleme artık çubukla anlatılıyor; bu metinler yalnızca durumu söyler,
    // "2/4" gibi bir sayı taşımaz.
    'clubEvents.session.blockedByCheckin':
        'Önce kapı check-in\'ini bitir — oturum başlatılamaz',
    'clubEvents.session.stateNotStarted': 'Oturumlar henüz başlamadı',
    'clubEvents.session.stateActive': 'Oturum devam ediyor',
    'clubEvents.session.stateLastActive': 'Son oturum devam ediyor',
    'clubEvents.session.stateAllDone': 'Tüm oturumlar tamamlandı',
    'clubEvents.session.start': 'Oturumu Başlat',
    'clubEvents.session.advance': 'Oturumu İlerlet ({{next}}. oturum)',
    'clubEvents.session.advanceNext': 'Sonraki Oturuma Geç',
    'clubEvents.session.undo': 'Oturumu Geri Al',
    'clubEvents.session.undoTitle': 'Oturumu geri al',
    'clubEvents.session.undoConfirm':
        'Bir önceki oturuma dönmek istiyor musun? {{session}}. oturumun QR\'ı '
        'yeniden geçerli olur ve ekrana gelir.',
    'clubEvents.session.undoToStartConfirm':
        'Etkinliği "oturum başlatılmadı" durumuna döndürmek istiyor musun? '
        'QR girişleri, sen yeniden başlatana kadar durur.',
    'clubEvents.session.undoToStartConfirmWithCheckin':
        'Etkinliği "oturum başlatılmadı" durumuna döndürmek istiyor musun? '
        'Check-in de "başlatılmadı" durumuna döner ve etkinlik yeniden '
        'keşfette görünür; oturumları tekrar başlatmadan önce check-in\'i '
        'baştan başlatıp bitirmen gerekir.',
    'clubEvents.session.undone':
        '{{session}}. oturuma dönüldü. Bu oturumun QR\'ı yeniden geçerli.',
    'clubEvents.session.undoneToStart':
        'Oturumlar başlangıca alındı. QR girişleri şimdilik durdu.',
    'clubEvents.session.undoneToStartWithCheckin':
        'Oturumlar ve check-in başlangıca alındı. Etkinlik, standartlara '
        'uyan öğrencilerin keşfinde tekrar görünür.',
    'clubEvents.session.finish': 'Oturumları Bitir',
    'clubEvents.session.reopen': 'Oturumları Tekrar Aç',
    'clubEvents.session.reopenTitle': 'Oturumları tekrar aç',
    'clubEvents.session.reopenConfirm':
        'Oturumları yeniden açmak istiyor musun? Son oturumun QR girişleri '
        'tekrar çalışır.',
    'clubEvents.session.reopened':
        'Oturumlar yeniden açıldı. QR girişleri tekrar alınabilir.',
    'clubEvents.session.showQr': 'Oturum QR\'ını Göster',
    'clubEvents.session.advanceTitle': 'Oturum',
    'clubEvents.session.startConfirm':
        '1. oturumu başlatmak istiyor musun? ({{total}} oturumluk etkinlik)',
    'clubEvents.session.advanceConfirm':
        '{{next}}. oturuma geçmek istiyor musun? Önceki oturum kapanacak.',
    'clubEvents.session.finishTitle': 'Oturumları bitir',
    'clubEvents.session.finishConfirm':
        'Tüm oturumları bitirmek istiyor musun? QR girişleri kapanacak ve belge yükleyebileceksin.',
    'clubEvents.session.started':
        '{{session}}. oturum başlatıldı. Öğrenciler bu oturum için QR okutabilir.',
    'clubEvents.session.finished':
        'Tüm oturumlar tamamlandı. Artık katılımcılara belge gönderebilirsin.',
    'clubEvents.session.qrTitle': '{{session}}. Oturum QR\'ı',
    'clubEvents.session.qrRotatingHint':
        'Öğrenciler bu QR\'ı telefon kamerasıyla okutsun. Kod {{seconds}} sn sonra yenilenecek.',
    'clubEvents.session.qrHint':
        'Bu kodu ekrana yansıt; öğrenciler kendi telefonlarından okutsun.',
    'clubEvents.session.qrError': 'QR görseli yüklenemedi.',
    'clubEvents.entry.stateNotStarted': 'Check-in başlatılmadı',
    'clubEvents.entry.stateRunning': 'Check-in açık',
    'clubEvents.entry.stateFinished': 'Check-in bitti',
    'clubEvents.entry.tally': ' — {{attended}}/{{total}} öğrenci giriş yaptı',
    'clubEvents.entry.start': 'Check-in\'i Başlat',
    'clubEvents.entry.finish': 'Check-in\'i Bitir',
    'clubEvents.entry.restart': 'Check-in\'i Yeniden Başlat',
    'clubEvents.entry.title': 'Kapı Girişi',
    'clubEvents.entry.subtitle':
        'Kapıda gösterilen QR. Öğrenciler kendi telefonlarından okutur.',
    'clubEvents.entry.open': 'Giriş QR\'ını Aç',
    'clubEvents.entry.show': 'Kapıda Tek QR Giriş',
    'clubEvents.entry.close': 'Girişi Kapat',
    'clubEvents.entry.qrTitle': 'Etkinlik Giriş QR\'ı',
    'clubEvents.entry.qrHint':
        'Öğrenciler bu kodu kendi telefonlarıyla okutur. Giriş açık kaldığı sürece kayıtları onaylanır.',
    'clubEvents.session.allowWithoutCheckin':
        'Check-in yapmayanlar da yoklamaya katılsın',
    'clubEvents.session.allowWithoutCheckinHint':
        'Kapı girişini kaçıran öğrenciler oturum QR\'ını doğrudan okutabilir.',

    'clubEvents.scan.action': 'Öğrenci QR\'ı Okut',
    'clubEvents.scan.subtitle':
        'Öğrencinin telefonunda ürettiği giriş kodunu okut.',

    'clubEvents.certificate.title': 'Belge',
    'clubEvents.certificate.action': 'Belge Yükle ve Dağıt',
    'clubEvents.certificate.subtitle':
        'Belge, katılım şartını sağlayan öğrencilere gönderilir.',
    'clubEvents.certificate.beforeFinish':
        'Oturumlar bitmeden de gönderebilirsin; hak sahipleri o anki katılım '
        'sayılarına göre belirlenir.',
    'clubEvents.certificate.lockedSubtitle': 'Tüm oturumlar bitince açılır.',
    'clubEvents.certificate.lockedSubtitleSingle':
        'Etkinlik bittikten sonra açılır.',
    'clubEvents.certificate.finishSessionsFirst':
        'Belge yükleyebilmek için önce oturumları bitirmelisin. Oturumlar '
        'sürerken yüklenen belge, yoklaması tamamlanmamış katılımcılara '
        'ulaşmaz.',
    'clubEvents.certificate.finishEventFirst':
        'Belge dağıtımı etkinlik bittikten sonra açılır. Etkinlik sürerken '
        'yüklenen belge, henüz giriş yapmamış katılımcılara ulaşmaz.',
    'clubEvents.certificate.uploadedTitle': 'Yüklenen Belgeler',
    'clubEvents.certificate.uploadedHint':
        'Bu liste kulübün arşividir; öğrencinin belgelerinde en son dağıttığın '
        'belge görünür.',
    'clubEvents.certificate.delete': 'Belgeyi sil',
    'clubEvents.certificate.deleteTitle': 'Belgeyi sil',
    'clubEvents.certificate.deleteConfirm':
        'Bu belgeyi listeden kaldırmak istiyor musun? Öğrencilere daha önce '
        'gönderilmiş kopyalar bundan etkilenmez.',
    'clubEvents.certificate.deleted': 'Belge silindi.',
    'clubEvents.certificate.deleteError':
        'Belge silinemedi. Lütfen tekrar dene.',
    'clubEvents.certificate.storedOnly':
        'Belge sisteme yüklendi. Hak kazanan öğrenci olmadığı için henüz '
        'kimseye gönderilmedi; hak sahipleri belirlendiğinde kendiliğinden '
        'dağıtılır. Beklemek istemezsen belgenin üzerindeki gönder tuşuyla '
        'hemen dağıtabilirsin.',
    'clubEvents.certificate.uploading': 'Belge yükleniyor...',
    'clubEvents.certificate.autoSent':
        'Etkinlik bittiği için belge {{count}} öğrenciye otomatik gönderildi.',
    'clubEvents.certificate.partial':
        'Belge {{count}} öğrenciye gönderildi, {{failed}} öğrenciye ulaşmadı. '
        'Tekrar deneyebilirsin.',
    'clubEvents.certificate.redistribute': 'Bu belgeyi dağıt',
    'clubEvents.certificate.distributedCount': '{{count}} öğrenciye gönderildi',
    'clubEvents.certificate.notDistributed': 'Henüz kimseye gönderilmedi',
    'clubEvents.certificate.sourceMissing':
        'Belge okunamadı. Silip yeniden yükle.',
    'clubEvents.certificate.linkLabel': 'Belge adresi veya dosya yolu',
    'clubEvents.certificate.linkHint':
        'Belgeyi kopyaladıysan buraya yapıştır (https://... bağlantısı ya da '
        'cihazdaki dosya yolu). Dosya seçici açılmazsa bu yol da çalışır.',
    'clubEvents.certificate.linkAction': 'Yapıştırılanı Yükle ve Dağıt',
    'clubEvents.certificate.paste': 'Panodan yapıştır',
    'clubEvents.certificate.linkEmpty':
        'Önce belgenin adresini ya da dosya yolunu yapıştır.',
    'clubEvents.certificate.fetching': 'Belge indiriliyor...',
    'clubEvents.certificate.linkError':
        'Belge bu adresten indirilemedi. Bağlantıyı kontrol et.',
    'clubEvents.certificate.linkInvalid': 'Bu bir belge adresi değil.',
    'clubEvents.certificate.tooLarge': 'Belge en fazla 10 MB olabilir.',
    'clubEvents.certificate.invalidType':
        'Yalnızca PDF, JPG veya PNG yükleyebilirsin.',
    'clubEvents.certificate.pickerError':
        'Dosya seçici açılamadı. Dosya iznini kontrol et.',
    'clubEvents.certificate.readError':
        'Dosya okunamadı. Başka bir dosya dene.',
    'clubEvents.certificate.sending':
        'Belgeler gönderiliyor ({{done}}/{{total}})...',
    'clubEvents.certificate.sent': 'Belge {{count}} öğrenciye gönderildi.',
    'clubEvents.certificate.error': 'Belge gönderilemedi. Lütfen tekrar dene.',
    'clubEvents.certificate.permissionError': 'Belge gönderme yetkin yok.',
    'clubEvents.certificate.authError':
        'Oturumun sona ermiş. Tekrar giriş yap.',
    'clubEvents.certificate.quotaError': 'Depolama alanı dolu.',
    'clubEvents.certificate.storageError':
        'Belgelere şu anda ulaşılamıyor. Lütfen tekrar dene.',
    'clubEvents.certificate.uploaded': 'Yüklenen belge',
    'clubEvents.certificate.view': 'Görüntülemek için dokun',

    'clubEvents.students.title': 'Katılımcılar',
    'clubEvents.students.empty': 'Bu etkinliğe henüz kayıt yok.',
    'clubEvents.students.checkedIn': 'Giriş Onaylı',
    'clubEvents.students.registered': 'Kayıtlı',
    'clubEvents.students.certificateEarned': 'Belge Hakkı',
    'clubEvents.students.downloadExcel': 'Excel İndir',

    'clubEvents.excel.sheetName': 'Kayıtlı Öğrenciler',
    'clubEvents.excel.reportTitle': 'Etkinlik Raporu',
    'clubEvents.excel.eventName': 'Etkinlik Adı',
    'clubEvents.excel.club': 'Kulüp',
    'clubEvents.excel.studentCount': 'Kayıtlı Öğrenci Sayısı',
    'clubEvents.excel.reportDate': 'Rapor Tarihi',
    'clubEvents.excel.subject': '{{title}} - kayıtlı öğrenciler',
    'clubEvents.excel.preparing': 'Excel dosyası hazırlanıyor...',
    'clubEvents.excel.ready':
        'Öğrenci listesi Excel dosyası olarak hazırlandı.',
    'clubEvents.excel.error':
        'Excel dosyası oluşturulamadı. Lütfen tekrar dene.',

    'clubCreateEvent.create': 'Etkinliği Oluştur',
    // Bölüm kartlarının başlık + açıklama çiftleri: web'deki
    // club-create-event.html hangi kartları hangi sırayla gösteriyorsa
    // mobil de aynısını gösteriyor (language.js ile birebir metin).
    'clubCreateEvent.eyebrow': 'Etkinlik Yönetimi',
    'clubCreateEvent.section.basics': 'Temel Bilgiler',
    'clubCreateEvent.section.basicsDesc':
        'Etkinliğin adı, ne anlattığı ve neyi hedeflediği.',
    'clubCreateEvent.section.participation': 'Katılım ve Ücret',
    'clubCreateEvent.section.participationDesc':
        'Kontenjan, ücret ve oturum ayarları.',
    'clubCreateEvent.section.schedule': 'Tarih ve Saat',
    'clubCreateEvent.section.scheduleDesc':
        'Etkinlik günü, saat aralığı ve son başvuru tarihi.',
    'clubCreateEvent.section.audience': 'Hedef Kitle',
    'clubCreateEvent.section.audienceDesc':
        'Etkinliği kimlerin göreceğini ve kaydolabileceğini belirler.',
    'clubCreateEvent.section.location': 'Etkinlik Konumu',
    'clubCreateEvent.section.locationDesc':
        'Haritadan seçilen konum, QR ile giriş kontrolünde kullanılır.',
    'clubCreateEvent.section.media': 'Görsel',
    'clubCreateEvent.section.mediaDesc':
        'Etkinliğe tek bir kapak görseli eklenir.',
    'clubCreateEvent.scope.label': 'Kapsam',
    'clubCreateEvent.scope.departmentOnly': 'Sadece Bölüme Özel',
    'clubCreateEvent.scope.universityAndDepartment':
        'Üniversiteye + Bölüme Özel',
    'clubCreateEvent.target.universityHint':
        'Birden fazla üniversite ekleyebilirsin. Boş bırakırsan kulübünün '
        'üniversitesi hedeflenir.',
    'clubCreateEvent.target.departmentHint':
        'Birden fazla bölüm ekleyebilirsin. Boş bırakırsan kulübünün ilk '
        'alanı hedeflenir.',
    'clubCreateEvent.fee.paid': 'Ücretli',
    'clubCreateEvent.sessions.hint':
        '1 oturum: belgeler etkinlik bitince girişi onaylananlara '
        'kendiliğinden dağıtılır.\n'
        '2 ve üzeri: oturum takibi açılır, belge için gereken katılım '
        'yüzdesini sen belirlersin.',
    'clubCreateEvent.image.pick': 'Cihazdan Seç',
    'notification.openTarget': 'Görüntüle',
    'clubCreateEvent.location.nameHint':
        'Bu ad öğrencilere gösterilir. Giriş doğrulaması haritadan seçtiğin '
        'noktaya göre yapılır.',
    'clubCreateEvent.location.clear': 'Konumu kaldır',
    'clubCreateEvent.location.search': 'Adres ara',
    'clubCreateEvent.location.pickOnMap': 'Haritadan Konum Seç',
    'clubCreateEvent.location.pickTitle': 'Konum Seç',
    'clubCreateEvent.location.moveHint':
        'Haritayı kaydırarak iğneyi konuma getir.',
    'clubCreateEvent.location.confirm': 'Bu Konumu Kullan',
    'clubCreateEvent.location.openExternal': 'Harita uygulamasında aç',
    'clubCreateEvent.location.mapError': 'Harita uygulaması açılamadı.',
    'clubCreateEvent.location.notSet': 'Belirlenmedi',
    'clubCreateEvent.location.captured': 'Konum alındı.',
    'clubCreateEvent.location.error': 'Konum alınamadı.',
    'clubCreateEvent.location.missingCoordinates': 'Konumu haritadan da seç.',
    'clubCreateEvent.feedback.invalidEventDate': 'Etkinlik tarihini seç.',
    'clubCreateEvent.feedback.deadlineAfterEventDate':
        'Son başvuru tarihi etkinlik tarihinden sonra olamaz.',
    'clubCreateEvent.feedback.invalidTimeRange':
        'Bitiş saati başlangıç saatinden sonra olmalı.',
    'clubCreateEvent.feedback.saving': 'Etkinlik kaydediliyor...',

    // Üretilen sözlükte "Etkinlik Adi" olarak kalmıştı.
    'form.eventTitle': 'Etkinlik Adı',
    'form.sessionCount': 'Oturum Sayısı',
    'form.checkinMode': 'Check-in / Yoklama Modu',
    'checkinMode.checkin_attendance': 'Check-in + Yoklama',
    'checkinMode.attendance_only': 'Sadece Yoklama',
    'checkinMode.checkin_only': 'Sadece Check-in',
    'checkinMode.checkin_attendanceDesc':
        'Kapıda konum doğrulamalı QR ile giriş yapılır; yoklama için önce bu giriş gerekir.',
    'checkinMode.attendance_onlyDesc':
        'Kapı girişi yoktur; oturum QR\'ları doğrudan çalışır.',
    'checkinMode.checkin_onlyDesc':
        'Oturum yoklaması yoktur; kapıda QR okutulunca giriş tamamlanır.',
    'clubCreateEvent.feedback.sessionCountRequired':
        'Yoklamalı etkinlikte oturum sayısı en az 2 olmalı.',
    'clubCreateEvent.subtitle':
        'Etkinlik bilgilerini doldur, hemen yayınlayalım.',
    'clubCreateEvent.editTitle': 'Etkinliği Düzenle',
    'form.eventDate': 'Etkinlik Tarihi',
    'form.deadline': 'Son Başvuru Tarihi',
    'form.startTime': 'Başlangıç',
    'form.endTime': 'Bitiş',
    'form.afterTimeHint': '{{time}} sonrası',
    'form.eventHours': 'Etkinlik Saati',

    // Üretilen sözlükte Türkçe karakterleri düşmüş örnek metinler
    // ("Ornek: ..."). Bu ekranda ipucu olarak göründükleri için düzeltiliyor.
    'placeholder.eventTitleExample': 'Örnek: AI Kariyer Buluşması',
    'placeholder.eventPurposeExample': 'Bu etkinliğin temel hedefi nedir?',
    'placeholder.quotaExample': 'Örnek: 120',
    'placeholder.sessionCountExample': 'Örnek: 5',
    'placeholder.certificateThresholdExample': 'Örnek: 80',
    'clubCreateEvent.feedback.imageTooLargeDetail':
        'Görsel çok büyük ({{size}} KB). En fazla {{limit}} KB olabilir.',
    'form.imageUrl': 'Görsel Adresi',
    'form.locationName': 'Konum Adı',
    'form.locationRadius': 'Giriş Yarıçapı',

    // Çoklu seçim kutuları: kutu tek seçimlik göründüğü sürece kimse ikinci
    // bir seçim eklemeyi denemiyordu.
    'form.multiSelect.addHint': 'Seç ve ekle (birden fazla olabilir)',
    'form.clubFields.hint':
        'Kulübün birden fazla alanda çalışıyorsa hepsini ekleyebilirsin.',
    'dashboard.scope.departmentOnly': 'Bölüme Özel',

    'clubDocuments.subtitle':
        'Kulübünün onaylanması için dört belgeyi de yüklemen gerekiyor.',
    'clubDocuments.establishment': 'Kuruluş Belgesi',
    'clubDocuments.advisor': 'Danışman Onay Belgesi',
    'clubDocuments.studentCerts': 'Öğrenci Belgeleri',
    'clubDocuments.boardList': 'Yönetim Kurulu Listesi',
    'clubDocuments.pick': 'Seç',
    'clubDocuments.pickHint': 'Henüz belge seçilmedi',
    'clubDocuments.submit': 'Belgeleri Gönder',
    'clubDocuments.formatHint':
        'Desteklenen formatlar: PDF, JPEG, PNG — her belge en fazla 5 MB.',
    'clubDocuments.feedback.permissionError': 'Belge yükleme yetkin yok.',

    'clubScan.otherEvent': 'Bu QR kod başka bir etkinliğe ait.',
    'clubScan.notOwner': 'Bu etkinlik senin kulübüne ait değil.',
    'clubScan.pastEvent':
        'QR okutma yalnızca devam eden/yaklaşan etkinliklerde kullanılabilir.',
    'clubScan.notRegistered': 'Bu öğrencinin bu etkinlikte kaydı yok.',
    'clubScan.alreadyCheckedIn': '{{name}} zaten giriş yapmış.',
    'clubScan.sessionNotStarted': 'Önce oturumu başlat.',
    'clubScan.alreadyInSession':
        '{{name}} bu oturumda ({{current}}/{{total}}) zaten giriş yaptı.',
    'clubScan.missingLocation': 'QR kodda konum yok. Öğrenci kodu yenilemeli.',
    'clubScan.tooFar':
        'Öğrenci etkinlik konumunun dışında — {{distance}} uzakta (en fazla {{radius}} m).',
    'clubScan.success': '{{name}} için giriş onaylandı.',
    'clubScan.noDoorCheckin':
        'Bu etkinlikte kapı check-in\'i yok — oturum QR\'ını gösterin, öğrenciler okutsun.',
    'clubScan.doorClosed':
        'Kapı kapalı. Önce etkinlik ekranından check-in\'i başlat.',
    'clubScan.sessionSuccess':
        '{{name}} için {{current}}. oturum girişi onaylandı (katılım {{attended}}/{{total}}).',

    'clubPending.notApprovedYet':
        'Onay henüz gelmedi. Yönetici belgelerini incelediğinde burası '
        'kendiliğinden güncellenir.',
    // Onay beklerken hatalı belgeyi düzeltme yolu (bkz. club_pending_screen).
    'clubPending.editDocuments': 'Belgeleri Düzenle',
    'clubPending.editDocumentsHint':
        'Yanlış belge yüklediysen inceleme sürerken değiştirebilirsin.',
    'clubDocuments.backToPending': 'Onay ekranına dön',
    'clubDocuments.issueTitle': 'Yönetici belgelerde eksik buldu',

    'admin.action.needsDocuments': 'Belge Eksik',
    'admin.needsDocuments.hint':
        'Kulüp belge yükleme ekranına geri gönderilir. Neyin eksik ya da '
        'hatalı olduğunu yaz — kulüp bu metni görecek.',
    'admin.needsDocuments.placeholder':
        'Örn: Danışman onay belgesi okunmuyor, yeniden yükleyin.',
    'admin.needsDocuments.send': 'Gönder',
    'admin.feedback.documentsRequested':
        'Kulüp belge yükleme aşamasına geri gönderildi.',
    'clubDocuments.alreadyUploaded': 'Yüklü',
    'clubDocuments.replace': 'Değiştir',
    'media.openError': 'Dosya açılamadı.',
    'media.documentTitle': 'Belge',
    'common.close': 'Kapat',
    'common.info': 'Bilgi',
    'common.continueAction': 'Devam Et',

    // ── Yönetici ────────────────────────────────────────────────────
    // Üretilen sözlükteki kısa/diakritiksiz sekme adları alt çubukta
    // okunaklı olsun diye burada güncelleniyor.
    'admin.nav.pending': 'Onaylar',
    'admin.nav.stats': 'İstatistik',
    'admin.nav.clubs': 'Kulüpler',
    'admin.nav.ban': 'Engelle',
    'admin.action.approve': 'Onayla',
    'admin.action.block': 'Engelle',
    'admin.confirm.approve':
        '{{club}} onaylansın mı? Kulüp panele erişebilir hâle gelecek.',
    'admin.confirm.block':
        '{{club}} engellensin mi? Yüklediği belgeler kalıcı olarak silinir.',
    'admin.documents': 'Belgeler ({{count}})',

    'admin.stats.students': 'Öğrenci',
    'admin.stats.clubs': 'Kulüp',
    'admin.stats.male': 'Erkek',
    'admin.stats.female': 'Kız',
    'admin.stats.byCity': 'Şehirlere Göre Öğrenci',
    'admin.stats.byUniversity': 'Üniversitelere Göre Öğrenci',
    'admin.stats.detail': 'Ayrıntılı Dağılım',
    'admin.stats.noData': 'Gösterilecek veri yok.',
    'admin.stats.cityCounts':
        '{{students}} öğrenci · {{clubs}} kulüp · {{male}}E / {{female}}K',
    'admin.stats.universityCounts':
        '{{students}} öğr. · {{clubs}} kulüp · {{male}}E/{{female}}K',

    // Kulüp listesi (admin_clubs_screen.dart)
    'admin.clubs.title': 'Kulüp Listesi',
    'admin.clubs.searchPlaceholder': 'Kulüp, şehir veya üniversite ara...',
    'admin.clubs.empty': 'Eşleşen kulüp bulunamadı.',
    'admin.clubs.cityCount': '{{count}} kulüp',
    'admin.clubs.unnamed': 'İsimsiz Kulüp',
    'admin.clubs.summaryCounts':
        '{{clubs}} kulüp · {{cities}} şehir · {{universities}} üniversite',
    'admin.clubs.summary': 'Kulüp Özeti',
    'admin.clubs.info': 'Kulüp Bilgileri',
    'admin.clubs.summaryText':
        '{{club}}, {{city}} şehrinde {{university}} bünyesinde açılmış bir '
        'kulüp. Çalışma alanı: {{fields}}. Yönetici kaydındaki durumu: '
        '{{status}}.',
    'admin.clubs.filter.all': 'Tümü',
    'admin.clubs.filter.approved': 'Onaylı',
    'admin.clubs.filter.pending': 'Onay bekleyen',
    'admin.clubs.filter.documents': 'Belge bekleyen',
    'admin.clubs.filter.banned': 'Engelli',
    'admin.clubs.status.approved': 'Onaylı',
    'admin.clubs.status.pending': 'Onay bekliyor',
    'admin.clubs.status.documents': 'Belge bekleniyor',
    'admin.clubs.status.banned': 'Engelli',

    'admin.ban.searchPlaceholder': 'Öğrenci, üniversite, şehir ara...',
    'admin.ban.empty': 'Eşleşen öğrenci bulunamadı.',
    'admin.ban.studentCount': '{{count}} öğrenci',
    'admin.ban.banButton': 'Engelle',
    'admin.ban.unbanButton': 'Engeli Kaldır',
    'admin.ban.confirmBan':
        '{{name}} engellensin mi? Oturumu kapatılır ve giriş yapamaz; gelecek '
        'etkinliklerdeki kayıtları silinip yerleri boşalır.',
    'admin.ban.confirmUnban': '{{name}} için engel kaldırılsın mı?',
    'admin.ban.tab.students': 'Öğrenciler',
    'admin.ban.tab.clubs': 'Kulüpler',
    'admin.ban.searchPlaceholderClubs': 'Kulüp, üniversite, şehir ara...',
    'admin.ban.emptyClubs': 'Eşleşen kulüp bulunamadı.',
    'admin.ban.clubCount': '{{count}} kulüp',
    'admin.ban.filter.all': 'Tümü',
    'admin.ban.filter.active': 'Aktif',
    'admin.ban.filter.banned': 'Engelli',
    'admin.ban.bannedLabel': 'Engelli',
    'admin.ban.confirmClubBan':
        '{{name}} engellensin mi? Kulüp giriş yapamaz; belgeleri silinmez.',
    'admin.ban.confirmClubUnban':
        '{{name}} için engel kaldırılsın mı? Kulüp, belgeleri duruyorsa '
        'inceleme kuyruğuna, durmuyorsa belge yükleme adımına döner.',
    'admin.ban.banSuccess': '{{name}} engellendi.',
    'admin.ban.unbanSuccess': '{{name}} için engel kaldırıldı.',
    'admin.ban.banError': 'Engelleme tamamlanamadı. Lütfen tekrar dene.',
    'admin.ban.unbanError': 'Engel kaldırılamadı. Lütfen tekrar dene.',

    // Kulübe yönetici notu (club_message_panel.dart)
    'admin.clubs.ban': 'Kulübü Engelle',
    'admin.clubs.unban': 'Engeli Kaldır',
    'admin.message.title': 'Kulübe Mesaj Gönder',
    'admin.message.hint':
        'Eksik belge ya da düzeltilmesi gereken bir durum varsa sebebini '
        'yaz; kulüp bu mesajı onay bekleme ekranında görecek. Başvuru '
        'kuyrukta kalır.',
    'admin.message.placeholder':
        'Örn: Akademik danışman onayı okunmuyor, tekrar yükleyin.',
    'admin.message.send': 'Mesajı Gönder',
    'admin.message.sent': 'Mesaj kulübe iletildi.',
    'admin.message.empty': 'Göndermeden önce bir mesaj yaz.',
    'admin.message.error': 'Mesaj gönderilemedi. Lütfen tekrar dene.',
    'admin.message.none': 'Bu kulübe henüz mesaj gönderilmedi.',
    'admin.message.logTitle': 'Gönderilen mesajlar',
    'clubPending.messages.title': 'Yöneticiden Mesaj',
    'clubPending.messages.hint':
        'Başvurunla ilgili yöneticinin ilettiği notlar aşağıda. Eksik bir '
        'belge belirtildiyse düzeltip yeniden yükleyebilirsin.',

    // Kulüp / yönetici tarafı (bu turda iskelet)
    // Bağlantı durumu
    'offline.banner': 'İnternet bağlantısı yok',
    'offline.bannerDesc':
        'Bağlantın geri geldiğinde kaldığın yerden devam edebilirsin.',
    'offline.loginBlocked':
        'İnternet bağlantısı yok. Giriş yapabilmek için bağlantını kontrol et.',
    'offline.actionBlocked': 'İnternet bağlantısı yok. Bağlanınca tekrar dene.',
    'offline.restored': 'İnternet bağlantısı geri geldi.',

    // Kulüp logosu (hesap ekranı + etkinlik penceresi rozeti)
    'clubAccount.logo': 'Kulüp Logosu',
    'clubAccount.feedback.logoUpdated': 'Kulüp logosu güncellendi.',
    'clubCreateEvent.image.autoShort':
        'Görsel eklemezsen kapakta gri Regipass logosu görünür.',

    // Hesap sayfasının sağ üstündeki iki simge ve arkalarındaki alt sayfalar
    // (bkz. lib/features/shared/account_settings_sheet.dart)
    'account.settings': 'Hesap Ayarlarım',
    'account.contact': 'İletişim',
    'support.title': 'Regipass Destek Hattı',
    'support.callPrompt': 'Bu numara aransın mı?',
    'support.call': 'Ara',
    'support.callFailed': 'Arama başlatılamadı; numara panoya kopyalandı.',

    // Ücretli etkinlik iletişim satırları (bkz. event_widgets.dart)
    'eventModal.phoneCopied': 'Numara kopyalandı',
    'eventModal.emailCopied': 'E-posta kopyalandı',

    // Kulüp hesap ekranındaki belge kartı (bkz.
    // lib/features/club/club_documents_card.dart)
    'clubAccount.documents.approvedTitle': 'Onaylanan Belgeler',
    'clubAccount.documents.title': 'Belgelerim',
    'clubAccount.documents.hint':
        'Başvurunda gönderdiğin belgeler. Adına dokunarak açabilirsin.',
    'clubAccount.documents.badge.approved': 'Onaylandı',
    'clubAccount.documents.badge.review': 'İncelemede',
    'clubAccount.documents.badge.incomplete': 'Eksik',
    'clubAccount.documents.missing': 'Yüklenmedi',
    'clubAccount.documents.open': 'Belgeyi aç',

    // Hesap ekranındaki hesap ayarları bölümü (bkz.
    // lib/features/shared/account_security.dart)
    'accountSecurity.title': 'Güvenlik',
    'accountSecurity.changePassword': 'Şifreyi Değiştir',
    'accountSecurity.changePasswordDesc':
        'Mevcut şifreni girerek yeni bir şifre belirle.',
    'accountSecurity.setPassword': 'Şifre Belirle',
    'accountSecurity.deleteAccount': 'Hesabımı Sil',
    'accountSecurity.deleteAccountDesc':
        'Hesabın ve tüm kayıtların kalıcı olarak silinir.',
    'accountSecurity.phoneReauth.title': 'Telefonunla Doğrula',
    'accountSecurity.phoneReauth.subtitle':
        'Hesabına kayıtlı numaraya bir doğrulama kodu göndereceğiz.',
    'accountSecurity.phoneReauth.confirm': 'Kodu Onayla',
    'accountSecurity.error.noPhone':
        'Hesabında doğrulanmış bir telefon numarası yok.',
    'accountSecurity.error.phoneMismatch': 'Bu numara hesabına ait değil.',
    'accountSecurity.error.wrongPassword': 'Mevcut şifren hatalı.',
    'accountSecurity.error.generic': 'İşlem tamamlanamadı. Lütfen tekrar dene.',

    'changePassword.subtitle': 'Güvenliğin için önce mevcut şifreni gir.',
    'changePassword.subtitleVerified':
        'Kimliğin doğrulandı. Şimdi yeni şifreni belirle.',
    'changePassword.currentPassword': 'Mevcut Şifre',
    'changePassword.newPassword': 'Yeni Şifre',
    'changePassword.newPasswordConfirm': 'Yeni Şifre (Tekrar)',
    'changePassword.forgotCurrent':
        'Şifremi hatırlamıyorum, telefonumla doğrula',
    'changePassword.submit': 'Şifreyi Güncelle',
    'changePassword.feedback.success': 'Şifren güncellendi.',
    'changePassword.feedback.currentRequired': 'Mevcut şifreni gir.',
    'changePassword.feedback.sameAsCurrent':
        'Yeni şifren eskisiyle aynı olamaz.',
    'changePassword.feedback.phoneVerified':
        'Telefonun doğrulandı. Yeni şifreni belirleyebilirsin.',

    'deleteAccount.subtitle': 'Bu işlem geri alınamaz.',
    'deleteAccount.warning':
        'Hesabın, profilin ve etkinlik kayıtların kalıcı olarak silinir. Aynı '
        'e-postayla yeniden kaydolabilirsin ama eski kayıtların geri gelmez.',
    'deleteAccount.passwordLabel': 'Şifren',
    'deleteAccount.verifyByPhone': 'Telefonumla doğrula',
    'deleteAccount.submit': 'Hesabımı Kalıcı Olarak Sil',
    'deleteAccount.feedback.passwordRequired':
        'Hesabını silmek için şifreni gir.',
    'deleteAccount.feedback.verifyFirst': 'Önce telefonunla kimliğini doğrula.',
    'deleteAccount.feedback.phoneVerified':
        'Kimliğin doğrulandı. Hesabını silebilirsin.',
    'deleteAccount.notice.done': 'Hesabın kalıcı olarak silindi.',

    'screen.comingSoon': 'Bu bölüm hazırlanıyor.',
    'screen.comingSoonDesc':
        'Kulüp ve yönetici ekranları bir sonraki aşamada tamamlanacak.',
    // Ücretli etkinlik onay logu — yalnızca ücretli etkinliklerde, etkinlik
    // detayında gösterilir (bkz. domain/paid_event_consent.dart).
    'paidEventConsent.log.title': 'Ücretli Etkinlik Onay Kaydı',
    'paidEventConsent.log.club': 'Kulüp onayı — etkinlik oluşturma',
    'paidEventConsent.log.students': 'Öğrenci kayıt onayları',
    'paidEventConsent.log.missing': 'Onay kaydı bulunmuyor.',
    'paidEventConsent.log.studentsEmpty': 'Henüz onay veren öğrenci yok.',
    'paidEventConsent.log.showText': 'Onaylanan metni göster',
    'paidEventConsent.log.hideText': 'Metni gizle',
    'paidEventConsent.log.legacyText':
        'Bu onayın metni kaydedilmemiş (metin kaydı eklenmeden önce alınmış onay).',
    'paidEventConsent.log.tileLabel': 'Ödeme onayı',
    'paidEventConsent.log.note':
        'Bu kayıtlar etkinlik verisinde saklanır; onay metni ve '
        'gün/saat/dakika/saniye damgası kayıt anında dondurulur.',
    // İP-O: kapı ekranı (web ile aynı anahtarlar: gate.*)
    'gate.defaultTitle': 'Kapı · bilet okutma',
    'gate.counter': '✓ {{n}} giriş',
    'gate.openRecent': 'Son okutulanları aç',
    'gate.recentTitle': 'Son okutulanlar',
    'gate.sessionCount': 'Bu oturum: {{n}}',
    'gate.recentEmpty': 'Henüz okutma yok.',
    'gate.close': 'Kapat',
    'gate.pin': 'Sabitle',
    'gate.unpin': 'Kaldır',
    'gate.pinned': 'sabit',
    'gate.soundOn': 'Sesi aç',
    'gate.soundOff': 'Sesi kapat',
    'gate.nth': '{{n}}.',
    'gate.unknownStudent': 'Öğrenci',
    'gate.notSentYet': 'gönderilmedi',
    'gate.packInfo': 'Cihazdaki liste: {{n}} bilet · {{time}}',
    'gate.net.online': 'Çevrimiçi',
    'gate.net.offline': 'İnternet yok',
    'gate.net.pending': '{{n}} okuma bekliyor',
    'gate.net.sending': '{{n}} okuma gönderiliyor',
    'gate.result.in': 'GİRİŞ TAMAM',
    'gate.result.already': 'ZATEN GİRDİ',
    'gate.result.invalid-ticket': 'GEÇERSİZ BİLET',
    'gate.result.not-registered': 'KAYITLI DEĞİL',
    'gate.result.other-event': 'BAŞKA ETKİNLİK',
    'gate.result.not-owner': 'BAŞKA KULÜBÜN ETKİNLİĞİ',
    'gate.result.no-door': 'KAPI BİLETİ YOK',
    'gate.result.past-event': 'ETKİNLİK GEÇMİŞ',
    'gate.result.not-ticket': 'REGIPASS BİLETİ DEĞİL',
    'gate.result.unknown-event': 'ETKİNLİK BULUNAMADI',
    'gate.hint.in': 'Sıradakini okutabilirsin',
    'gate.hint.legacy': 'Eski uygulama bileti (kodsuz) — kimliği kontrol et',
    'gate.hint.already': 'İlk giriş {{time}} · sayı değişmedi',
    'gate.hint.invalid-ticket': 'Bilet kodu uyuşmuyor — öğrenci bileti uygulamadan yeniden açsın',
    'gate.hint.not-registered': 'Bu öğrencinin etkinliğe kaydı yok',
    'gate.hint.other-event': 'Bu bilet başka bir etkinliğe ait',
    'gate.hint.not-owner': 'Etkinlik bu kulübe ait değil',
    'gate.hint.no-door': 'Sadece yoklama: oturum QR\'ını göster, öğrenciler okutsun',
    'gate.hint.past-event': 'Etkinliğin günü geçti',
    'gate.hint.not-ticket': 'Öğrenciden Regipass biletini açmasını iste',
    'gate.hint.unknown-event': 'Etkinlik bulunamadı. İnternet yoksa: bu etkinliğin listesi cihaza hiç inmemiş',
    'gate.hint.conflict': 'Başka cihazda {{time}} girmişti — ilk okuma geçerli',
    'gate.hint.rejected': 'Sunucu kabul etmedi — bu girişi kontrol et',
    'gate.conflictToast': '{{name}}: başka cihaz daha önce okutmuştu ({{time}}).',
    'gate.cameraHint': 'Bileti kameraya tut. Kamera açık kalır; sıradakini hemen okutabilirsin.',
    'gate.cameraError': 'Kamera açılamadı. Kamera iznini kontrol et.',
    // İP-K: kayıt, bekleme listesi, ödeme, etkinlik iptali (web language.js ile aynı anahtarlar)
    'gate.hint.event-cancelled': 'Etkinlik iptal edildi, biletler geçersiz',
    'gate.hint.paidAtGate': 'Ödeme kapıda onaylandı, giriş alındı',
    'gate.hint.payment-pending': 'Ödeme onaylanmamış — giriş yapılamaz',
    'gate.markPaid': 'Ödendi olarak işaretle ve içeri al',
    'gate.markPaidFailed': 'İşaretlenemedi (internet gerekli). Tekrar dene.',
    'gate.markingPaid': 'İşaretleniyor...',
    'gate.result.event-cancelled': 'ETKİNLİK İPTAL',
    'gate.result.payment-pending': 'ÖDEME ONAYLANMAMIŞ',
    'registration.actions.joinWaitlist': 'Bekleme Listesine Gir',
    'registration.actions.joiningWaitlist': 'Listeye ekleniyor...',
    'registration.actions.leaveWaitlist': 'Bekleme Listesinden Çık',
    'registration.actions.registerSeatOpen': 'Yer Açıldı — Hemen Kaydol',
    'registration.actions.registeredPaymentPending': 'Kayıtlısın · Ödeme Bekleniyor',
    'registration.actions.waitlistPosition': 'Bekleme listesinde {{position}}. sıradasın',
    'registration.alerts.fullOfferWaitlist': 'Bu etkinliğin kontenjanı doldu. Bekleme listesine girmek ister misin? Yer açılırsa bildirim gelir; ilk kayıt olan yeri alır.',
    'registration.alerts.leaveWaitlistConfirm': 'Bekleme listesinden çıkmak istediğine emin misin?',
    'registration.alerts.paymentPendingNote': 'Kaydın "Ödeme bekleniyor" durumunda. Kulüp ödemeni aldığını işaretleyince kaydın kesinleşir ve bildirim alırsın. Ödeme onaylanmadan kapıda giriş yapılamaz.',
    'registration.alerts.seatsAvailableNow': 'Bu arada yer açıldı. Hemen kayıt olabilirsin.',
    'registration.alerts.waitlistJoined': 'Bekleme listesine eklendin: {{position}}. sıradasın. Yer açılınca bildirim gelir; ilk kayıt olan yeri alır.',
    'registration.club.addSeats': '+{{n}} yer aç',
    'registration.club.addSeatsConfirm': 'Kontenjan {{from}} → {{to}} olacak. Bekleme listesindekilere "yer açıldı" bildirimi gider; ilk kayıt olan alır.',
    'registration.club.cancelEventAction': 'Etkinliği İptal Et',
    'registration.club.cancelEventBody': 'Kayıtlı öğrencilere ve bekleme listesindekilere bildirim gidecek; kayıtlar silinmez, etkinlik "İptal edildi" olarak görünür. Hiç kaydı yoksa etkinlik tamamen silinir.',
    'registration.club.cancelEventTitle': 'Etkinliği iptal et',
    'registration.club.cancelledBanner': 'Bu etkinlik iptal edildi. Kayıtlı öğrencilere bildirim gönderildi.',
    'registration.club.cancelledBannerReason': 'Bu etkinlik iptal edildi. Gerekçe: {{reason}}',
    'registration.club.eventCancelled': 'Etkinlik iptal edildi. {{n}} kişiye bildirim gönderildi.',
    'registration.club.eventDeleted': 'Etkinliğin kaydı yoktu; etkinlik tamamen silindi.',
    'registration.club.markPaid': 'Ödendi olarak işaretle',
    'registration.club.markedPaid': '{{name}}: ödeme onaylandı, öğrenciye bildirim gitti.',
    'registration.club.paid': 'Ödendi',
    'registration.club.paymentTitle': 'Ödeme',
    'registration.club.quotaNow': 'Kontenjan {{n}} oldu.',
    'registration.club.quotaSetupDone': 'Kontenjan kuruldu, kayıtlar açıldı.',
    'registration.club.quotaSetupFailed': 'Kontenjan kurulamadı; etkinlik kayda kapalı. Etkinliği düzenleyip yeniden kaydederek tekrar deneyebilirsin.',
    'registration.club.quotaSetupStatus': 'Kontenjan Kuruluyor',
    'registration.club.reasonLabel': 'Gerekçe (isteğe bağlı, öğrencilere gösterilir)',
    'registration.club.removeAction': 'Kaydı sil',
    'registration.club.removeBody': '{{name}} adlı öğrencinin kaydı silinecek. Öğrenciye bildirim gidecek ve yeri bekleme listesine açılacak.',
    'registration.club.removeReasonHint': 'Örn. Ödeme yapılmadı',
    'registration.club.removeTitle': 'Kaydı sil',
    'registration.club.removed': '{{name}} adlı öğrencinin kaydı silindi.',
    'registration.club.unmarkConfirm': '{{name}} için "Ödendi" işaretini geri almak istiyor musun? Öğrenci kapıda giriş yapamaz.',
    'registration.club.unmarkPaid': 'Geri al',
    'registration.club.unmarkedPaid': '{{name}}: ödeme işareti geri alındı.',
    'registration.club.waitlistCount': 'Bekleme listesinde {{count}} kişi var',
    'registration.club.waitlistEmpty': 'Kontenjan doldu. Bekleme listesi henüz boş.',
    'registration.errors.banned': 'Hesabın engellendiği için kayıt yapılamıyor.',
    'registration.errors.below-registered': 'Kontenjan kayıtlı öğrenci sayısının ({{registered}}) altına indirilemez. Önce kayıtları azaltmalı ya da daha yüksek bir kontenjan girmelisin.',
    'registration.errors.busy': 'Şu anda çok yoğun. Birkaç saniye sonra tekrar dene.',
    'registration.errors.cancel-locked': 'Oturumlar başladığı için kaydını artık kendin silemezsin; kulüple iletişime geç.',
    'registration.errors.club-banned': 'Bu kulübün etkinliklerine şu anda kayıt alınmıyor.',
    'registration.errors.deadline-passed': 'Son başvuru tarihi geçti.',
    'registration.errors.event-cancelled': 'Bu etkinlik iptal edildi.',
    'registration.errors.event-hidden': 'Bu etkinlik artık yayında değil.',
    'registration.errors.event-not-found': 'Etkinlik bulunamadı.',
    'registration.errors.event-not-paid': 'Bu etkinlik ücretli değil.',
    'registration.errors.event-past': 'Etkinliğin tarihi geçti.',
    'registration.errors.event-started': 'Etkinlik başladı; yeni kayıt alınmıyor.',
    'registration.errors.generic': 'İşlem tamamlanamadı. Lütfen tekrar dene.',
    'registration.errors.invalid-quota': 'Geçerli bir kontenjan gir.',
    'registration.errors.not-eligible': 'Bu etkinlik senin üniversiten ya da bölümün için değil.',
    'registration.errors.not-event-club': 'Bu işlem yalnızca etkinliğin kulübü tarafından yapılabilir.',
    'registration.errors.not-registered': 'Bu etkinliğe kayıt bulunamadı.',
    'registration.errors.offline': 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.',
    'registration.errors.paid-consent-required': 'Ücretli etkinlikte ödeme koşullarını onaylaman gerekiyor.',
    'registration.errors.payment-pending': 'Ödemen henüz onaylanmadı; kulüp onaylayınca giriş yapabilirsin.',
    'registration.errors.phone-not-verified': 'Kayıt olmak için önce telefon numaranı doğrulamalısın.',
    'registration.errors.profile-incomplete': 'Önce öğrenci profilini tamamlamalısın.',
    'registration.errors.profile-missing': 'Önce öğrenci profilini tamamlamalısın.',
    'registration.errors.quota-setup': 'Etkinliğin kontenjanı henüz hazır değil. Biraz sonra tekrar dene.',
    'registration.errors.registration-closed': 'Bu etkinliğin kayıtları kapandı.',
    'registration.errors.signIn': 'Oturumun kapanmış görünüyor. Lütfen yeniden giriş yap.',
    'eventModal.contactTitle': 'İletişim Bilgileri',
    'eventModal.feeContactTitle': 'Ücret İçin İletişim Bilgileri',
    'eventModal.feeContactNoteClub': 'Ücret: {{fee}}. Ödeme Regipass dışında doğrudan kulüple yapılır; öğrenciler ücret için aşağıdaki bilgilerle kulübe ulaşır. Ödemeyi aldığında öğrenci listesinden "Ödendi" olarak işaretle; kayıt o zaman kesinleşir.',
    'eventModal.feeContactNoteWithFee': 'Ücret: {{fee}}. Ödeme Regipass dışında doğrudan kulüple yapılır; ücret için aşağıdaki bilgilerden kulüple iletişime geç. Kulüp ödemeyi aldığını işaretleyince kaydın kesinleşir.',
    'clubCreateEvent.contact.label': 'İletişim bilgisi gösterilsin mi?',
    'clubCreateEvent.contact.labelPaid': 'Ücret için iletişim bilgisi',
    'clubCreateEvent.contact.club': 'Kulübün sistem bilgileri',
    'clubCreateEvent.contact.custom': 'Yeni bilgi gir',
    'clubCreateEvent.contact.hidden': 'Gösterme',
    'clubCreateEvent.contact.clubPreview': 'Gösterilecek: {{contact}}',
    'clubCreateEvent.contact.clubEmpty': 'Kulüp profilinde telefon/e-posta yok. Kulüp Bilgileri sayfasından ekleyebilir ya da yeni bilgi girebilirsin.',
    'clubCreateEvent.contact.hiddenHint': 'Etkinlik detayında iletişim bilgisi gösterilmez.',
    'clubCreateEvent.contact.phone': 'İletişim telefonu',
    'clubCreateEvent.contact.email': 'İletişim e-postası',
    'clubCreateEvent.contact.customHint': 'En az birini doldur. Bu bilgiler yalnızca bu etkinlikte görünür.',
    'clubCreateEvent.contact.errorEmpty': 'Yeni bilgi seçtin: en az bir telefon ya da e-posta gir.',
    'clubCreateEvent.contact.errorEmail': 'E-posta adresi geçerli görünmüyor.',
    'clubCreateEvent.contact.errorPhone': 'Telefon numarası 11 haneli olmalı (ör. 0555 123 45 67 ya da 0212 123 45 67).',
    'registration.bulk.hint': 'Toplu işlem için öğrencileri seç.',
    'registration.bulk.selected': '{{n}} öğrenci seçildi',
    'registration.bulk.selectAll': 'Tümünü seç',
    'registration.bulk.clear': 'Seçimi temizle',
    'registration.bulk.selectPending': 'Ödeme bekleyenleri seç ({{n}})',
    'registration.bulk.markPaid': 'Toplu ödeme onayı',
    'registration.bulk.markPaidN': '"Ödendi" yap ({{n}})',
    'registration.bulk.markPaidConfirm': '{{n}} öğrencinin ödemesi onaylanacak ve her birine bildirim gidecek.',
    'registration.bulk.markedPaid': '{{n}} öğrencinin ödemesi onaylandı.',
    'registration.bulk.nonePending': 'Seçilenler arasında ödeme bekleyen yok.',
    'registration.bulk.removeN': 'Kaydı sil ({{n}})',
    'registration.bulk.removeBody': 'Seçilen {{n}} öğrencinin kaydı silinecek. Her birine bildirim gidecek ve yerleri bekleme listesine açılacak.',
    'registration.bulk.removed': '{{n}} öğrencinin kaydı silindi.',
    'registration.errors.too-many-students': 'Tek seferde en fazla 200 öğrenci seçebilirsin.',
    'registration.labels.cancelled': 'İptal',
    'registration.labels.payment': 'Ödeme',
    'registration.labels.registeredAt': 'Kayıt Tarihi',
    'registration.status.cancelled': 'İptal Edildi',
    'registration.status.cancelledNoReason': 'Kulüp etkinliği iptal etti.',
    'registration.status.fullWaitlist': 'Kontenjan Doldu · Bekleme Listesi',
    'registration.status.paymentConfirmed': 'Ödendi (kulüp onayladı)',
    'registration.status.paymentPending': 'Ödeme Bekleniyor',
    'registration.status.paymentPendingLong': 'Bekleniyor — kulüp ödemeyi onaylayınca kaydın kesinleşir',
    'registration.status.registeredPaymentPending': 'Kayıtlı · Ödeme Bekleniyor',
    'registration.status.waitlisted': 'Bekleme Listesindesin',
    'registration.ticket.paymentPendingHint': 'Ödemen henüz onaylanmadı: kapıda giriş yapılamaz. Kulüp ödemeni onaylayınca bilet geçerli olur.',
  },
  'en': <String, String>{
    // İP-B: event notifications
    'autoNotify.title': 'Automatic notifications',
    'autoNotify.help':
        'Regipass notifies registered students automatically. Without a start '
        'time only the "1 day before" reminder is sent.',
    'autoNotify.dayBefore': 'Reminder 1 day before (19:00)',
    'autoNotify.hourBefore': '1 hour before it starts',
    'autoNotify.atStart': 'When it starts (to those not checked in)',
    'autoNotify.afterEnd': 'Thank-you after it ends (to attendees)',
    'eventNotify.title': 'Notifications',
    'eventNotify.autoHelp':
        'Turn automatic notifications on or off by editing the event.',
    'eventNotify.status.sent': 'Sent',
    'eventNotify.status.pending': 'Scheduled',
    'eventNotify.status.missed': 'Missed',
    'eventNotify.status.off': 'Off',
    'eventNotify.send': 'Send notification',
    'eventNotify.submit': 'Send',
    'eventNotify.audienceLabel': 'To',
    'eventNotify.audience.registered': 'All registered',
    'eventNotify.audience.checked_in': 'Checked in',
    'eventNotify.audience.not_checked_in': 'Not checked in',
    'eventNotify.audience.waitlist': 'Waitlist',
    'eventNotify.titleLabel': 'Title',
    'eventNotify.messageLabel': 'Message',
    'eventNotify.counting': 'Counting recipients…',
    'eventNotify.willReach': 'Will reach {{count}} people.',
    'eventNotify.sent': 'Notification sent to {{count}} people.',
    'eventNotify.historyTitle': 'Sent messages',
    'eventNotify.historyEmpty': 'No messages sent yet.',
    'eventNotify.historyError': 'Could not load history.',
    'eventNotify.errors.required': 'Enter a title and a message.',
    'eventNotify.errors.unknown-tag':
        'Unknown tag. Available: {ad}, {etkinlik}, {tarih}, {saat}, {yer}, '
        '{kulüp}.',
    'eventNotify.errors.fill': 'Fill in the … placeholder in the template.',
    'eventNotify.audience.payment_pending': 'Payment pending',
    'eventNotify.templateLabel': 'Template',
    'eventNotify.templateNone': 'Blank message',
    'eventNotify.tagsLabel': 'Insert smart tag',
    'eventNotify.previewLabel': 'Preview (sample student)',
    'eventNotify.quota': 'Left today: {{left}}/{{limit}}',
    'eventNotify.nextIn': 'next send in {{minutes}} min',
    'eventNotify.tag.ad': 'Student first name',
    'eventNotify.tag.etkinlik': 'Event name',
    'eventNotify.tag.tarih': 'Date',
    'eventNotify.tag.saat': 'Time',
    'eventNotify.tag.yer': 'Place',
    'eventNotify.tag.kulup': 'Club name',
    'eventNotify.errors.title-required': 'Enter a title.',
    'eventNotify.errors.message-required': 'Enter a message.',
    'eventNotify.errors.too-soon':
        'Wait at least 10 minutes between two messages for the same event.',
    'eventNotify.errors.daily-limit':
        'You reached today\'s message limit (5) for this event.',
    'eventNotify.errors.messaging-closed':
        'More than 7 days passed since the event; messaging is closed.',
    'eventNotify.errors.no-recipients': 'Nobody is in this group.',
    'eventNotify.errors.event-cancelled':
        'You cannot message a cancelled event.',
    'eventNotify.errors.club-not-approved':
        'Your club must be approved to send messages.',
    'eventNotify.errors.club-banned': 'Your club account is suspended.',
    'eventNotify.errors.not-event-club': 'This event is not your club\'s.',
    // İP-T: add to calendar
    'calendar.add': 'Add to calendar',
    'calendar.google': 'Google Calendar',
    'calendar.ics': 'Calendar file (.ics)',
    'calendar.icsHint': 'Apple Calendar, Outlook and others',
    // İP-KB: club's student block
    'clubBlock.title': 'Block from club',
    'clubBlock.action': 'Block from club',
    'clubBlock.body':
        '{{name}} will be blocked from your club\'s events: they cannot '
        'register for new events or join waitlists.',
    'clubBlock.reasonLabel': 'Reason',
    'clubBlock.reasonHelper':
        'Required. Not shown to the student; kept for your club and '
        'Regipass staff.',
    'clubBlock.reasonRequired': 'Enter a reason of at least 3 characters.',
    'clubBlock.removeFuture':
        'Also remove their registrations for upcoming events (they get a '
        '"registration cancelled" notice)',
    'clubBlock.done':
        '{{name}} is blocked from your club\'s events. Upcoming registrations '
        'removed: {{count}}.',
    'clubBlock.listTitle': 'Blocked students',
    'clubBlock.listHelp':
        'These students cannot register for your club\'s new events. Add a '
        'student with "Block from club" on an event\'s registration list.',
    'clubBlock.empty': 'You have not blocked anyone.',
    'clubBlock.unblock': 'Unblock',
    'clubBlock.unblockConfirm':
        'Unblock {{name}}? They will be able to register for your events again.',
    'clubBlock.unblocked': '{{name}} was unblocked.',
    'clubBlock.studentFallback': 'Student',
    'clubBlock.error': 'Could not complete. Try again.',
    'clubBlock.errors.reason-required':
        'Enter a reason of at least 3 characters.',
    'clubBlock.errors.student-not-related':
        'You can only block students who registered for your events.',
    'clubBlock.errors.club-not-approved':
        'Your club must be approved to block students.',
    'clubBlock.errors.club-banned': 'Your club account is suspended.',
    'clubBlock.errors.not-a-club': 'Only club accounts can do this.',
    'clubBlock.errors.invalid-student': 'Student not found.',
    'registration.errors.blocked-by-club':
        'You can\'t register for this club\'s events.',
    // İP-M1: staff account (role claim + authenticator app)
    'auth.error.userDisabled':
        'This account has been suspended or is scheduled for deletion. If you '
        'think this is a mistake, write to product@regipass.com.',
    'auth.error.staffSetupRequired':
        'Two-step verification is not set up for this staff account yet. '
        'Set it up on a computer at regipass.com/admin-login.html.',
    'auth.totp.title': 'Verification code',
    'auth.totp.body':
        'Enter the 6-digit code shown for Regipass in your authenticator app.',
    'auth.totp.label': 'Code',
    'auth.totp.format': 'Enter the 6-digit code.',
    'auth.totp.submit': 'Sign in',
    'auth.totp.invalid':
        'The code is wrong or expired. Enter the current code from the app.',
    'auth.totp.unsupported': 'No authenticator app is enrolled on this account.',
    'admin.ban.clubImpact':
        '{{events}} upcoming events of this club will be CANCELLED; '
        '{{people}} registered people will be notified. The club account will '
        'not be able to sign in.',
    'admin.ban.reasonLabel': 'Reason',
    'admin.ban.reasonHelper':
        'Required. Saved to the audit log; not shown to students.',
    'admin.ban.reasonRequired': 'You must enter a reason to ban.',
    'auth.error.roleAlreadyExists':
        'This account type already exists. Please sign in.',
    'auth.error.emailRegisteredWrongPassword':
        'This email is registered, but the password is wrong.',
    'auth.feedback.termsRequired':
        'To continue, you must approve the User and Club Agreement and the '
        'Data Protection Notice.',
    'legal.consent.summaryTitle': 'Documents you approved',
    'legal.consent.acceptedAt': 'Consent time',
    'legal.consent.tileLabel': 'Document consent',
    'legal.consent.notRecorded': 'Not recorded',
    'legal.consent.marketingOn': 'marketing consent given',
    'legal.consent.marketingOff': 'marketing consent not given',

    'auth.notice.unverifiedPhoneRemoved':
        'Your account was deleted because it was not verified within the '
        'given time. You can sign up again.',
    'phoneVerify.deleteWarning':
        'If you do not verify your phone number within 15 minutes, your '
        'account will be deleted.',

    'nav.explore': 'Explore',
    'auth.noAccount': "Don't have an account?",
    'auth.haveAccount': 'Already have an account?',
    'common.back': 'Back',

    'forgotPassword.title': 'Reset your password',
    'forgotPassword.emailRequired': 'Enter your email address first.',
    'forgotPassword.savedNumber': 'Your saved number:',
    'forgotPassword.enterPhoneHint':
        'Type your number in full so we can send the code:',
    'forgotPassword.sendCode': 'Send verification code',
    'forgotPassword.phoneMismatch':
        'This phone number is not registered to that email address. '
        'Please enter the phone number registered to your account.',
    'forgotPassword.phoneNotOnAccount':
        'That number does not belong to this account. Saved: {{masked}}',
    'forgotPassword.maskCountryMismatch':
        'The country code does not match your saved number. Saved: {{masked}}',
    'forgotPassword.maskLengthMismatch':
        'That number has a different number of digits than your saved one. '
        'Saved: {{masked}}',
    'forgotPassword.maskSuffixMismatch':
        'That number does not match your saved one. Saved: {{masked}}',
    'forgotPassword.noPhoneOnRecord':
        'There is no verified phone number linked to this email, so SMS '
        'recovery is unavailable. Please contact support.',
    'forgotPassword.tooManyAttempts':
        'Too many attempts. Please try again later.',
    'forgotPassword.newPasswordHint': 'Verified. Choose your new password.',
    'forgotPassword.savePassword': 'Save password',
    'forgotPassword.success': 'Your password has been updated.',
    'forgotPassword.continue': 'Back to sign in',
    'forgotPassword.genericError': 'Something went wrong. Please try again.',
    'forgotPassword.sendTimeout':
        'The SMS request timed out. Check your connection and try again.',
    'forgotPassword.operationTimeout':
        'The request timed out. Check your connection and try again.',
    'forgotPassword.verifying': 'Verifying code',
    'forgotPassword.savedSignInRequired':
        'Your password was saved. Return to sign in with your new password.',
    'account.sharedPhoneNotice':
        'This phone is shared by the student and club accounts linked to the same email and is already verified. It cannot be changed here.',
    'auth.error.networkFailed': 'No connection. Check your internet.',
    'explore.guestTitle': "You're browsing as a guest",
    'explore.guestDesc':
        'You can browse events. Sign in to register, generate a QR code and receive certificates.',
    'explore.signInToJoin': 'Sign in to join',
    'explore.empty': 'There are no events to show right now.',
    'explore.loadError': 'Events could not load. Please try again.',
    'explore.permissionDenied': 'Sign in to see the events.',

    'student.nav.account': 'My Account',
    'student.notifications.title': 'Notifications',
    'notifications.announcement': 'Notice',
    'student.notifications.empty': 'You have no new notifications yet.',

    'notification.event.student.upcoming.title': 'Event starting soon',
    'notification.event.student.upcoming.body':
        '{{title}} starts in half an hour.',
    'notification.event.student.started.title': 'Event started',
    'notification.event.student.started.body': '{{title}} has just started.',
    'notification.event.student.deadline.title': 'Registrations closed',
    'notification.event.student.deadline.body':
        'The registration period for {{title}} has ended.',

    'notification.event.club.upcoming.title': 'Your event starts soon',
    'notification.event.club.upcoming.body':
        '{{title}} starts in half an hour. Get ready for check-ins.',
    'notification.event.club.started.title': 'Event started',
    'notification.event.club.started.body': '{{title}} has just started.',
    'notification.event.club.deadline.title': 'Registrations closed',
    'notification.event.club.deadline.body':
        'Registrations for {{title}} are closed; your attendee list is final.',

    'notification.disabled':
        'Notifications are turned off in your device settings. Event '
        'reminders and announcements will not reach your phone.',
    'notification.openSettings': 'Open notification settings',

    'admin.notify.searchPlaceholder': 'Search city or university',
    'admin.notify.hint': 'Open a city and tap a university to send a notice.',
    'admin.notify.noResults': 'No city or university matches your search.',
    'admin.notify.universityCount': '{{count}} universities',
    'admin.notify.audience': 'Who should receive it?',
    'admin.notify.audience.students': 'Students',
    'admin.notify.audience.clubs': 'Clubs',
    'admin.notify.audience.all': 'Both',
    'admin.notify.titleLabel': 'Notification title',
    'admin.notify.bodyLabel': 'Notification text',
    'admin.notify.required': 'This field cannot be empty.',
    'admin.notify.send': 'Send',
    'admin.notify.sent': 'Notice sent to {{university}}.',
    'admin.notify.broadcastButton': 'Broadcast to Everyone',
    'admin.notify.broadcastSubtitle':
        'Sent to universities in every city at once.',
    'admin.notify.broadcastHeader': 'All Universities',
    'admin.notify.broadcastConfirmTitle': 'Send this broadcast?',
    'admin.notify.broadcastConfirmBody':
        'This will be sent at once to every target audience in {{count}} '
        'universities. This action cannot be undone.',
    'admin.notify.broadcastSent': 'Broadcast sent to all universities.',
    'admin.notify.sendError':
        'The announcement could not be sent. Please try again.',
    'admin.notify.sendDenied':
        'You do not have permission to send announcements.',

    'clubAccount.section.manager': 'Representative Details',
    'clubAccount.section.club': 'Club Details',

    'studentAppointments.title': 'My Events',
    'studentAppointments.activeTitle': 'Active Events',
    'studentAppointments.pastTitle': 'Past Events',

    'settings.appearance': 'Appearance',
    'settings.appearance.light': 'Light mode',
    'settings.appearance.dark': 'Dark mode',
    'settings.language': 'Language',

    'form.photoFromGallery': 'Choose from gallery',
    'form.photoFromCamera': 'Take a photo',
    'form.phoneOperatorPrefix':
        '{{country}} mobile numbers must start with {{prefixes}}.',
    'form.phoneDigits': 'Must be {{digits}} digits',
    'form.phoneCountryDigits':
        '{{country}} numbers must be {{digits}} digits long.',
    'form.phoneTaken':
        'This number belongs to another account. Enter a different one.',
    // Another account requested a code for this number but has not verified
    // it yet; the reservation expires by itself after 15 minutes.
    'form.phonePending':
        'This number is being verified. Try again in 15 minutes.',
    'form.phoneChecking': 'Checking this number…',
    'form.phoneAvailable': 'This number is available.',

    'eventModal.info': 'Event Details',
    'eventModal.club': 'Club',
    'eventModal.eventDate': 'Event Date',
    'eventModal.deadline': 'Deadline',
    'eventModal.fee': 'Fee',
    'eventModal.free': 'Free',
    'eventModal.quota': 'Capacity',
    'eventModal.unlimited': 'Unlimited',
    'eventModal.location': 'Location',
    'eventModal.sessions': 'Sessions',
    'eventModal.sessionsValue': '{{count}} sessions',
    'eventModal.clubContact': 'Club Contact',
    'eventModal.feeContactNote':
        'This event has a fee. Contact the club by phone for the fee and '
        'payment details.',
    'eventModal.audience': 'Target Audience',
    'eventModal.description': 'Description',
    'eventModal.purpose': 'Purpose',

    'common.save': 'Save',
    'common.cancel': 'Cancel',
    'common.retry': 'Retry',
    // İP-Y: attendance on the server
    'attendance.flag.edge': 'at the edge of the area',
    'attendance.flag.lowAccuracy': 'low location accuracy',
    'attendance.flag.unsignedQr': 'old app QR',
    'attendance.flag.delayed': 'processed late',
    'attendance.flag.unverified': 'not verified by the server',
    'attendance.stage.door': 'Door',
    'attendance.stage.session': 'Session {{n}}',
    'attendance.suspicious.title': 'Suspicious',
    'attendance.error.alreadyCheckedIn':
        'Your entry for this event was already confirmed.',
    'attendance.error.sessionNotStarted':
        'The session has not started yet. Scan the QR again once the club starts it.',
    'attendance.error.banned': 'Your account is restricted, so you cannot check in.',
    'attendance.qrKeyError':
        'Could not create the QR. Check your internet connection and try again.',
    'attendance.entryRotatingHint':
        'Students scan this code with their own phones. It refreshes in {{seconds}} s.',
    'clubScan.ticketMismatch':
        'The ticket code does not match the registration (old or forged ticket). Ask the student to reopen the ticket in the app.',
    'clubScan.ticketLegacy':
        'Old app ticket (no code) — check their ID.',
    'common.loading': 'Loading...',
    'common.logout': 'Log out',
    'common.select': 'Select',
    'common.search': 'Search...',
    'common.done': 'Done',

    'scan.permissionDenied': 'Camera access is off. Turn it on in Settings.',
    'scan.pointCamera': 'Point the camera at the QR code.',
    'scan.ready': 'Ready for the next student.',
    'scan.successTitle': 'Check-in Successful',
    'scan.failTitle': 'Check-in Failed',
    'scan.notRegipassQr': 'This is not a Regipass check-in code.',
    'scan.missingEventInfo': 'The QR code is incomplete or damaged.',
    'scan.notSessionQr': 'This is not a session check-in code.',
    'clubScan.needsDoorCheckin':
        '{{name}} has not checked in at the door - check-in is required first.',
    'scan.notDoorQr': 'This is not a door entry code.',
    'scan.doorClosed': 'Door entry is not open yet.',
    'scan.needsDoorCheckin': 'You need to scan the door entry QR first.',
    'scan.doorSuccess':
        'Your door entry was recorded. You can now join session attendance.',
    'scan.doorOnlySuccess': 'Your event entry was recorded. Enjoy the event!',
    'scan.locationRequired':
        'This check-in needs your location. Turn it on and try again.',
    'scan.tooFar':
        'You are outside the event location ({{distance}}; maximum {{radius}} m).',
    'scan.missingSessionInfo': 'The QR code is incomplete or damaged.',
    'scan.eventNotFound': 'Event not found.',
    'scan.notSessionBased': 'This event is not session-based.',
    'scan.sessionsCompleted': 'All sessions for this event are completed.',
    'scan.qrExpired': 'This QR is no longer valid — the session has advanced.',
    'scan.qrSlotExpired':
        'This code has expired — the on-screen QR refreshes every 20 seconds. Scan the current one.',
    'scan.notRegistered': 'You are not registered for this event.',
    'scan.eventClosedNotRegistered': 'This event has expired.',
    'scan.alreadyCheckedInSession':
        'You already checked in for this session ({{current}}/{{total}}).',
    'scan.checkinSaveFailed': 'The check-in could not be saved. Try again.',
    'scan.permissionError':
        'This check-in could not be saved. Tell the club staff.',
    'scan.sessionSuccess':
        'You are in session {{current}} (attendance {{attended}}/{{total}}).',
    'scan.otherEventQr':
        'This QR belongs to another event. Scan the session QR of the event you joined.',

    'studentAppointments.modal.showTicket': 'Show My Ticket',
    'studentAppointments.modal.scanQr': 'Scan Session QR',
    'studentAppointments.modal.scanReady':
        'Session {{current}} is open. Scan the QR on the club\'s screen to check in.',
    'studentAppointments.modal.scanNotStarted':
        'The club has not started the first session yet. This button turns on when a session opens.',
    'studentAppointments.modal.scanAlreadyDone':
        'You are checked in for session {{current}}. The button turns on again when the club opens the next session.',
    'studentAppointments.modal.scanCompleted':
        'All sessions for this event are completed; there is no new QR to scan.',
    'studentAppointments.modal.scanUnavailable':
        'The event was removed, so session check-in is not possible.',

    'location.permissionDenied':
        'Location access is off. Turn it on to check in.',
    'location.gettingLocation': 'Getting location...',

    // Account screen phone field + verification pop-up
    'account.phoneChangeHint':
        'If you change the number, you will have to verify it by SMS in the '
        'pop-up that opens after you save. The number does not change until it '
        'is verified.',
    'account.phoneNotChanged':
        'The number was not verified; your saved number is unchanged.',
    // Phone verification errors (not present in the generated dictionary)
    'phoneVerify.error.browserCanceled':
        'Verification was interrupted. Send the code again.',
    'phoneVerify.error.browserAlreadyOpen':
        'A verification is already in progress. Try again in a few seconds.',
    'phoneVerify.error.network':
        'Check your internet connection and try again.',
    'phoneVerify.error.deviceCheckFailed':
        'The SMS could not be sent. Please try again later.',
    'auth.error.emailAlreadyRegistered':
        'An account with this email exists. Sign in or reset your password.',
    'phoneVerifySheet.title': 'Verify Phone Number',
    'phoneVerifySheet.subtitle':
        'We will send a 6-digit verification code to this number. You can close '
        'this window any time with the X in the corner.',

    'club.nav.myEvents': 'My Events',
    'club.nav.newEvent': 'New Event',
    'clubSessionQr.subtitle': 'Session-based events',
    'clubSessionQr.empty':
        'You have no session-based events. QR codes are only generated for '
        'events with multiple sessions; for single-session events you scan '
        'the student\'s own QR instead.',
    'clubSessionQr.manage': 'Manage Event',
    'clubSessionQr.hint':
        'Tap an event: its session QR appears on screen and the event itself '
        'opens behind it.',
    'clubDashboard.empty':
        'No events to show right now. Manage your own from the "My Events" tab.',

    'clubEvents.title': 'Event',
    'clubEvents.edit': 'Edit',
    'clubEvents.status.closed': 'Registration Closed',
    'clubEvents.group.active': 'Active',
    'clubEvents.group.upcoming': 'Upcoming',
    'clubEvents.group.past': 'Past',
    'clubEvents.empty.active':
        'No active events. Use the + button below to create one.',
    'clubEvents.empty.upcoming': 'No upcoming events.',
    'clubEvents.empty.past': 'No past events.',
    'clubEvents.feedback.loadError': 'Events could not load. Please try again.',
    'clubEvents.feedback.updateError':
        'The action could not be completed. Please try again.',
    'clubEvents.feedback.deleted': 'Event removed.',
    'clubEvents.feedback.deleteError':
        'The event could not be deleted. Please try again.',
    'clubEvents.delete.title': 'Delete event',
    'clubEvents.delete.global': 'Delete Everywhere',
    'clubEvents.delete.local': 'Remove From My List',
    'clubEvents.delete.action': 'Delete',
    'clubEvents.delete.confirmGlobal':
        'This event will be removed for everyone. Do you want to continue?',
    'clubEvents.delete.confirmLocal':
        'The past event will only be removed from your own list; student records are unaffected.',

    'clubEvents.registrations.title': 'Registrations',
    'clubEvents.qr.locationRequired':
        'Edit the event and select its location on the map before creating a QR code. Students will be checked against this location.',
    'clubEvents.quota.title': 'Capacity',
    'clubEvents.quota.remaining': '{{count}} spots left.',
    'clubEvents.quota.full': 'Capacity is full.',
    'clubEvents.quota.autoPaused':
        'Registrations are on hold because capacity is full. Raise the capacity and they reopen automatically.',
    'clubEvents.registrations.subtitle':
        'While registrations are stopped, students cannot apply to this event.',
    'clubEvents.registrations.closeAction': 'Stop Registrations',
    'clubEvents.registrations.openAction': 'Reopen Registrations',
    'clubEvents.registrations.pastLabel': 'Registrations closed',
    'clubEvents.registrations.confirmClose':
        'Do you want to stop registrations for this event?',
    'clubEvents.registrations.confirmOpen':
        'Do you want to reopen registrations for this event?',
    'clubEvents.registrations.closed': 'Registrations stopped.',
    'clubEvents.registrations.opened': 'Registrations reopened.',
    'clubEvents.registrations.blockedRunning':
        'Registrations stopped because the event has started, and they cannot be '
        'reopened right now.\n\n'
        'To reopen them, take the event back to the start: first finish the door '
        'check-in, then roll the sessions back to the start (0). Once the event is '
        'back at the start, registrations can be reopened.',

    'clubEvents.session.title': 'Sessions',
    'clubEvents.session.notStarted': 'No session started (0/{{total}})',
    'clubEvents.session.active': 'Active session: {{current}}/{{total}}',
    'clubEvents.session.lastActive': 'Last session active: {{total}}/{{total}}',
    'clubEvents.session.allDone':
        'All sessions completed ({{total}}/{{total}})',
    'clubEvents.session.start': 'Start Session',
    'clubEvents.session.advance': 'Advance Session (session {{next}})',
    // Progress is shown by the bar now; these lines carry no counters.
    'clubEvents.session.blockedByCheckin':
        'Finish door check-in first — sessions cannot start yet',
    'clubEvents.session.stateNotStarted': 'Sessions have not started yet',
    'clubEvents.session.stateActive': 'A session is running',
    'clubEvents.session.stateLastActive': 'The last session is running',
    'clubEvents.session.stateAllDone': 'All sessions are complete',
    'clubEvents.session.advanceNext': 'Move to Next Session',
    'clubEvents.session.undo': 'Undo Session',
    'clubEvents.session.undoTitle': 'Undo session',
    'clubEvents.session.undoConfirm':
        'Go back to the previous session? The QR for session {{session}} '
        'becomes valid again and opens on screen.',
    'clubEvents.session.undoToStartConfirm':
        'Reset the event to "not started"? QR check-ins stop until you start '
        'a session again.',
    'clubEvents.session.undoToStartConfirmWithCheckin':
        'Reset the event to "not started"? Check-in also resets to "not '
        'started" and the event becomes visible in discover again; you\'ll '
        'need to start and finish check-in again before sessions can '
        'restart.',
    'clubEvents.session.undone':
        'Back on session {{session}}. Its QR is valid again.',
    'clubEvents.session.undoneToStart':
        'Sessions reset to the start. QR check-ins are paused for now.',
    'clubEvents.session.undoneToStartWithCheckin':
        'Sessions and check-in reset to the start. The event is visible '
        'again in discover for eligible students.',
    'clubEvents.session.finish': 'Finish Sessions',
    'clubEvents.session.reopen': 'Reopen Sessions',
    'clubEvents.session.reopenTitle': 'Reopen sessions',
    'clubEvents.session.reopenConfirm':
        'Do you want to reopen the sessions? QR check-ins for the last '
        'session start working again.',
    'clubEvents.session.reopened':
        'Sessions reopened. QR check-ins are accepted again.',
    'clubEvents.session.showQr': 'Show Session QR',
    'clubEvents.session.advanceTitle': 'Session',
    'clubEvents.session.startConfirm':
        'Start session 1? ({{total}} sessions in total)',
    'clubEvents.session.advanceConfirm':
        'Move to session {{next}}? The previous session will close.',
    'clubEvents.session.finishTitle': 'Finish sessions',
    'clubEvents.session.finishConfirm':
        'Finish all sessions? QR check-ins will close and you can upload certificates.',
    'clubEvents.session.started':
        'Session {{session}} started. Students can scan the QR for it.',
    'clubEvents.session.finished':
        'All sessions completed. You can now send certificates to participants.',
    'clubEvents.session.qrTitle': 'Session {{session}} QR',
    'clubEvents.session.qrRotatingHint':
        'Students scan this QR with their phone camera. The code refreshes in {{seconds}} s.',
    'clubEvents.session.qrHint':
        'Project this code; students scan it from their own phones.',
    'clubEvents.session.qrError': 'The QR image could not be loaded.',
    'clubEvents.entry.stateNotStarted': 'Check-in not started',
    'clubEvents.entry.stateRunning': 'Check-in open',
    'clubEvents.entry.stateFinished': 'Check-in finished',
    'clubEvents.entry.tally': ' — {{attended}}/{{total}} students checked in',
    'clubEvents.entry.start': 'Start Check-in',
    'clubEvents.entry.finish': 'Finish Check-in',
    'clubEvents.entry.restart': 'Restart Check-in',
    'clubEvents.entry.title': 'Door Entry',
    'clubEvents.entry.subtitle':
        'The QR shown at the door. Students scan it with their own phones.',
    'clubEvents.entry.open': 'Open Entry QR',
    'clubEvents.entry.show': 'Show Entry QR',
    'clubEvents.entry.close': 'Close Entry',
    'clubEvents.entry.qrTitle': 'Event Entry QR',
    'clubEvents.entry.qrHint':
        'Students scan this code with their own phones. Entries are confirmed while it stays open.',
    'clubEvents.session.allowWithoutCheckin':
        'Let students without check-in join attendance',
    'clubEvents.session.allowWithoutCheckinHint':
        'Students who missed door entry can scan the session QR directly.',

    'clubEvents.scan.action': 'Scan Student QR',
    'clubEvents.scan.subtitle':
        'Scan the check-in code generated on the student\'s phone.',

    'clubEvents.certificate.title': 'Certificate',
    'clubEvents.certificate.action': 'Upload and Distribute',
    'clubEvents.certificate.subtitle':
        'The certificate is sent to students who meet the attendance requirement.',
    'clubEvents.certificate.beforeFinish':
        'You can send before the sessions end; recipients are decided from the '
        'attendance counts at that moment.',
    'clubEvents.certificate.storedOnly':
        'The document was uploaded. No student is eligible yet, so it has not '
        'been sent to anyone; it is distributed automatically once recipients '
        'are known. To send it right away, use the send button on the '
        'document.',
    'clubEvents.certificate.uploading': 'Uploading the document...',
    'clubEvents.certificate.autoSent':
        'The event has ended, so the document was sent automatically to '
        '{{count}} students.',
    'clubEvents.certificate.partial':
        'Sent to {{count}} students; {{failed}} did not receive it. You can '
        'try again.',
    'clubEvents.certificate.redistribute': 'Distribute this document',
    'clubEvents.certificate.distributedCount': 'Sent to {{count}} students',
    'clubEvents.certificate.notDistributed': 'Not sent to anyone yet',
    'clubEvents.certificate.sourceMissing':
        'The document could not be read. Delete it and upload again.',
    'clubEvents.certificate.linkLabel': 'Document link or file path',
    'clubEvents.certificate.linkHint':
        'If you copied the document, paste it here (an https://... link or a '
        'file path on the device). This also works when the file picker does '
        'not open.',
    'clubEvents.certificate.linkAction': 'Upload and Distribute Pasted File',
    'clubEvents.certificate.paste': 'Paste from clipboard',
    'clubEvents.certificate.linkEmpty':
        'Paste the document link or file path first.',
    'clubEvents.certificate.fetching': 'Downloading the document...',
    'clubEvents.certificate.linkError':
        'The document could not be downloaded. Check the link.',
    'clubEvents.certificate.linkInvalid': 'That is not a document link.',
    'clubEvents.certificate.tooLarge': 'The file can be at most 10 MB.',
    'clubEvents.certificate.invalidType':
        'You can upload only PDF, JPG or PNG files.',
    'clubEvents.certificate.pickerError':
        'The file picker could not open. Check the file permission.',
    'clubEvents.certificate.readError':
        'The file could not be read. Try another file.',
    'clubEvents.certificate.sending':
        'Sending certificates ({{done}}/{{total}})...',
    'clubEvents.certificate.sent': 'Certificate sent to {{count}} students.',
    'clubEvents.certificate.error':
        'The document could not be sent. Please try again.',
    'clubEvents.certificate.permissionError':
        'You do not have permission to send documents.',
    'clubEvents.certificate.authError':
        'Your session has ended. Please sign in again.',
    'clubEvents.certificate.quotaError': 'Storage is full.',
    'clubEvents.certificate.storageError':
        'Documents are unreachable right now. Please try again.',
    'clubEvents.certificate.uploaded': 'Uploaded document',
    'clubEvents.certificate.view': 'Tap to view',
    'clubEvents.certificate.lockedSubtitle':
        'Unlocks once every session is finished.',
    'clubEvents.certificate.lockedSubtitleSingle':
        'Unlocks once the event has ended.',
    'clubEvents.certificate.finishSessionsFirst':
        'Finish the sessions before uploading a document. A document uploaded '
        'while sessions are still running never reaches the participants whose '
        'attendance is not complete yet.',
    'clubEvents.certificate.finishEventFirst':
        'Document distribution unlocks once the event has ended. A document '
        'uploaded while the event is still running never reaches participants '
        'who have not checked in yet.',
    'clubEvents.certificate.uploadedTitle': 'Uploaded Documents',
    'clubEvents.certificate.uploadedHint':
        'This list is the club\'s own archive; students see the document you '
        'distributed most recently.',
    'clubEvents.certificate.delete': 'Delete document',
    'clubEvents.certificate.deleteTitle': 'Delete document',
    'clubEvents.certificate.deleteConfirm':
        'Remove this document from the list? Copies already sent to students '
        'are not affected.',
    'clubEvents.certificate.deleted': 'Document deleted.',
    'clubEvents.certificate.deleteError':
        'The document could not be deleted. Please try again.',

    'clubEvents.students.title': 'Participants',
    'clubEvents.students.empty': 'No registrations yet.',
    'clubEvents.students.checkedIn': 'Checked In',
    'clubEvents.students.registered': 'Registered',
    'clubEvents.students.certificateEarned': 'Certificate',
    'clubEvents.students.downloadExcel': 'Excel',

    'clubEvents.excel.sheetName': 'Registered Students',
    'clubEvents.excel.reportTitle': 'Event Report',
    'clubEvents.excel.eventName': 'Event Name',
    'clubEvents.excel.club': 'Club',
    'clubEvents.excel.studentCount': 'Registered Students',
    'clubEvents.excel.reportDate': 'Report Date',
    'clubEvents.excel.subject': '{{title}} - registered students',
    'clubEvents.excel.preparing': 'Preparing the Excel file...',
    'clubEvents.excel.ready': 'The student list is ready as an Excel file.',
    'clubEvents.excel.error':
        'The Excel file could not be created. Please try again.',

    'clubCreateEvent.create': 'Create Event',
    'clubCreateEvent.eyebrow': 'Event Management',
    'clubCreateEvent.section.basics': 'Basic Details',
    'clubCreateEvent.section.basicsDesc':
        'The event name, what it covers and what it aims for.',
    'clubCreateEvent.section.participation': 'Attendance and Fee',
    'clubCreateEvent.section.participationDesc':
        'Quota, fee and session settings.',
    'clubCreateEvent.section.schedule': 'Date and Time',
    'clubCreateEvent.section.scheduleDesc':
        'Event day, time range and application deadline.',
    'clubCreateEvent.section.audience': 'Target Audience',
    'clubCreateEvent.section.audienceDesc':
        'Decides who can see and register for the event.',
    'clubCreateEvent.section.location': 'Event Location',
    'clubCreateEvent.section.locationDesc':
        'The location picked on the map is used for QR check-in control.',
    'clubCreateEvent.section.media': 'Image',
    'clubCreateEvent.section.mediaDesc':
        'A single cover image is added to the event.',
    'clubCreateEvent.scope.label': 'Scope',
    'clubCreateEvent.scope.departmentOnly': 'Department Only',
    'clubCreateEvent.scope.universityAndDepartment':
        'University + Department Only',
    'clubCreateEvent.target.universityHint':
        'You can add more than one university. Left empty, your club\'s own '
        'university is targeted.',
    'clubCreateEvent.target.departmentHint':
        'You can add more than one department. Left empty, your club\'s first '
        'field is targeted.',
    'clubCreateEvent.fee.paid': 'Paid',
    'clubCreateEvent.sessions.hint':
        '1 session: documents go out automatically to checked-in students '
        'once the event ends.\n'
        '2 or more: session tracking opens and you set the attendance '
        'percentage required for a certificate.',
    'form.checkinMode': 'Check-in / Attendance Mode',
    'checkinMode.checkin_attendance': 'Check-in + Attendance',
    'checkinMode.attendance_only': 'Attendance Only',
    'checkinMode.checkin_only': 'Check-in Only',
    'checkinMode.checkin_attendanceDesc':
        'Students check in through a location-verified door QR before session attendance.',
    'checkinMode.attendance_onlyDesc':
        'There is no door entry; session QR codes work directly.',
    'checkinMode.checkin_onlyDesc':
        'There is no session attendance; scanning the door QR completes entry.',
    'clubCreateEvent.feedback.sessionCountRequired':
        'An event with attendance needs at least 2 sessions.',
    'clubCreateEvent.image.pick': 'Choose From Device',
    'notification.openTarget': 'View',
    'clubCreateEvent.location.nameHint':
        'Students see this name. Check-in is validated against the point you '
        'picked on the map.',
    'clubCreateEvent.location.clear': 'Remove location',
    'clubCreateEvent.location.search': 'Search address',
    'clubCreateEvent.location.pickOnMap': 'Pick Location On Map',
    'clubCreateEvent.location.pickTitle': 'Pick Location',
    'clubCreateEvent.location.moveHint': 'Drag the map to place the pin.',
    'clubCreateEvent.location.confirm': 'Use This Location',
    'clubCreateEvent.location.openExternal': 'Open in maps app',
    'clubCreateEvent.location.mapError': 'The maps app could not be opened.',
    'clubCreateEvent.location.notSet': 'Not set',
    'clubCreateEvent.location.captured': 'Location captured.',
    'clubCreateEvent.location.error': 'Location could not be read.',
    'clubCreateEvent.location.missingCoordinates':
        'Pick the spot on the map too.',
    'clubCreateEvent.feedback.invalidEventDate': 'Choose the event date.',
    'clubCreateEvent.feedback.deadlineAfterEventDate':
        'The deadline cannot be after the event date.',
    'clubCreateEvent.feedback.invalidTimeRange':
        'The end time must be after the start time.',
    'clubCreateEvent.feedback.saving': 'Saving the event...',

    'form.eventDate': 'Event Date',
    'form.deadline': 'Application Deadline',
    'form.startTime': 'Start',
    'form.endTime': 'End',
    'form.afterTimeHint': 'after {{time}}',
    'form.eventHours': 'Event Time',
    'clubCreateEvent.feedback.imageTooLargeDetail':
        'The image is too large ({{size}} KB). The limit is {{limit}} KB.',
    'form.imageUrl': 'Image Address',
    'form.locationName': 'Location Name',
    'form.locationRadius': 'Check-in Radius',

    'form.multiSelect.addHint': 'Pick and add (more than one allowed)',
    'form.clubFields.hint':
        'If your club works in more than one field, add all of them.',
    'dashboard.scope.departmentOnly': 'Department Only',

    'clubDocuments.subtitle':
        'All four documents must be uploaded before your club can be approved.',
    'clubDocuments.establishment': 'Establishment Document',
    'clubDocuments.advisor': 'Advisor Approval',
    'clubDocuments.studentCerts': 'Student Certificates',
    'clubDocuments.boardList': 'Board Member List',
    'clubDocuments.pick': 'Choose',
    'clubDocuments.pickHint': 'No document selected yet',
    'clubDocuments.submit': 'Submit Documents',
    'clubDocuments.formatHint':
        'Supported formats: PDF, JPEG, PNG — up to 5 MB each.',
    'clubDocuments.feedback.permissionError':
        'You do not have permission to upload documents.',

    'clubScan.otherEvent': 'This QR belongs to a different event.',
    'clubScan.notOwner': 'This event does not belong to your club.',
    'clubScan.pastEvent': 'QR check-in only works for ongoing/upcoming events.',
    'clubScan.notRegistered': 'This student is not signed up for this event.',
    'clubScan.alreadyCheckedIn': '{{name}} has already checked in.',
    'clubScan.sessionNotStarted': 'Start the session first.',
    'clubScan.alreadyInSession':
        '{{name}} already checked in for this session ({{current}}/{{total}}).',
    'clubScan.missingLocation':
        'The QR code has no location. The student should refresh it.',
    'clubScan.tooFar':
        'The student is outside the event location — {{distance}} away (max {{radius}} m).',
    'clubScan.success': 'Check-in confirmed for {{name}}.',
    'clubScan.noDoorCheckin':
        'This event has no door check-in — show the session QR instead and let students scan it.',
    'clubScan.doorClosed':
        'Entry is closed. Start check-in from the event screen first.',
    'clubScan.sessionSuccess':
        'Session {{current}} confirmed for {{name}} (attendance {{attended}}/{{total}}).',

    'clubPending.notApprovedYet':
        'Approval has not arrived yet. This page updates itself once an '
        'administrator reviews your documents.',
    'clubPending.editDocuments': 'Edit Documents',
    'clubPending.editDocumentsHint':
        'Uploaded the wrong file? You can replace it while the review is '
        'still pending.',
    'clubDocuments.backToPending': 'Back to approval screen',
    'clubDocuments.issueTitle': 'An administrator found the documents lacking',

    'admin.action.needsDocuments': 'Documents Missing',
    'admin.needsDocuments.hint':
        'The club is sent back to the document upload screen. Describe what '
        'is missing or wrong — the club will see this text.',
    'admin.needsDocuments.placeholder':
        'e.g. The advisor approval is unreadable, please re-upload.',
    'admin.needsDocuments.send': 'Send',
    'admin.feedback.documentsRequested':
        'The club was sent back to the document upload stage.',
    'clubDocuments.alreadyUploaded': 'Uploaded',
    'clubDocuments.replace': 'Replace',
    'media.openError': 'The file could not be opened.',
    'media.documentTitle': 'Document',
    'common.close': 'Close',
    'common.info': 'Info',
    'common.continueAction': 'Continue',

    'admin.nav.pending': 'Approvals',
    'admin.nav.stats': 'Statistics',
    'admin.nav.clubs': 'Clubs',
    'admin.nav.ban': 'Block',
    'admin.action.approve': 'Approve',
    'admin.action.block': 'Block',
    'admin.confirm.approve':
        'Approve {{club}}? The club will gain access to its panel.',
    'admin.confirm.block':
        'Block {{club}}? The documents it uploaded will be deleted permanently.',
    'admin.documents': 'Documents ({{count}})',

    'admin.stats.students': 'Students',
    'admin.stats.clubs': 'Clubs',
    'admin.stats.male': 'Male',
    'admin.stats.female': 'Female',
    'admin.stats.byCity': 'Students By City',
    'admin.stats.byUniversity': 'Students By University',
    'admin.stats.detail': 'Detailed Breakdown',
    'admin.stats.noData': 'No data to show.',
    'admin.stats.cityCounts':
        '{{students}} students · {{clubs}} clubs · {{male}}M / {{female}}F',
    'admin.stats.universityCounts':
        '{{students}} std. · {{clubs}} clubs · {{male}}M/{{female}}F',

    // Club directory (admin_clubs_screen.dart)
    'admin.clubs.title': 'Club Directory',
    'admin.clubs.searchPlaceholder': 'Search club, city or university...',
    'admin.clubs.empty': 'No matching club found.',
    'admin.clubs.cityCount': '{{count}} clubs',
    'admin.clubs.unnamed': 'Unnamed Club',
    'admin.clubs.summaryCounts':
        '{{clubs}} clubs · {{cities}} cities · {{universities}} universities',
    'admin.clubs.summary': 'Club Summary',
    'admin.clubs.info': 'Club Details',
    'admin.clubs.summaryText':
        '{{club}} was founded at {{university}} in {{city}}. Field of work: '
        '{{fields}}. Status on record: {{status}}.',
    'admin.clubs.filter.all': 'All',
    'admin.clubs.filter.approved': 'Approved',
    'admin.clubs.filter.pending': 'Pending approval',
    'admin.clubs.filter.documents': 'Awaiting documents',
    'admin.clubs.filter.banned': 'Blocked',
    'admin.clubs.status.approved': 'Approved',
    'admin.clubs.status.pending': 'Pending approval',
    'admin.clubs.status.documents': 'Awaiting documents',
    'admin.clubs.status.banned': 'Blocked',

    'admin.ban.searchPlaceholder': 'Search student, university, city...',
    'admin.ban.empty': 'No matching student found.',
    'admin.ban.studentCount': '{{count}} students',
    'admin.ban.banButton': 'Block',
    'admin.ban.unbanButton': 'Unblock',
    'admin.ban.confirmBan':
        'Block {{name}}? They will be signed out and cannot log in; their '
        'upcoming registrations are removed and the seats freed.',
    'admin.ban.confirmUnban': 'Remove the block for {{name}}?',
    'admin.ban.tab.students': 'Students',
    'admin.ban.tab.clubs': 'Clubs',
    'admin.ban.searchPlaceholderClubs': 'Search club, university, city...',
    'admin.ban.emptyClubs': 'No matching club found.',
    'admin.ban.clubCount': '{{count}} clubs',
    'admin.ban.filter.all': 'All',
    'admin.ban.filter.active': 'Active',
    'admin.ban.filter.banned': 'Blocked',
    'admin.ban.bannedLabel': 'Blocked',
    'admin.ban.confirmClubBan':
        'Block {{name}}? The club loses access to its panel; its documents '
        'are kept.',
    'admin.ban.confirmClubUnban':
        'Remove the block for {{name}}? The club returns to the review queue '
        'if its documents are still there, otherwise to the upload step.',
    'admin.ban.banSuccess': '{{name}} has been blocked.',
    'admin.ban.unbanSuccess': 'The block on {{name}} has been lifted.',
    'admin.ban.banError': 'The block could not be applied. Please try again.',
    'admin.ban.unbanError': 'The block could not be removed. Please try again.',

    // Admin note to a club (club_message_panel.dart)
    'admin.clubs.ban': 'Block Club',
    'admin.clubs.unban': 'Unblock',
    'admin.message.title': 'Send Message to Club',
    'admin.message.hint':
        'If a document is missing or something needs fixing, write the '
        'reason here; the club sees it on its approval screen and the '
        'application stays in the queue.',
    'admin.message.placeholder':
        'e.g. The advisor approval is unreadable, please upload it again.',
    'admin.message.send': 'Send Message',
    'admin.message.sent': 'Message delivered to the club.',
    'admin.message.empty': 'Write a message before sending.',
    'admin.message.error': 'The message could not be sent. Please try again.',
    'admin.message.none': 'No message has been sent to this club yet.',
    'admin.message.logTitle': 'Sent messages',
    'clubPending.messages.title': 'Message From The Admin',
    'clubPending.messages.hint':
        'Notes the admin sent about your application are below. If a '
        'document is missing, fix it and upload it again.',

    // Connectivity
    'offline.banner': 'No internet connection',
    'offline.bannerDesc':
        'You can continue where you left off once you are back online.',
    'offline.loginBlocked':
        'No internet connection. Check your connection to sign in.',
    'offline.actionBlocked':
        'You are offline. Try again once you are back online.',
    'offline.restored': 'Internet connection restored.',

    // Club logo (account screen + event window badge)
    'clubAccount.logo': 'Club Logo',
    'clubAccount.feedback.logoUpdated': 'Club logo updated.',
    'clubCreateEvent.image.autoShort':
        'With no image, the cover shows a gray Regipass logo.',

    // Account screen top-right icons and their sheets
    'account.settings': 'My Account Settings',
    'account.contact': 'Contact',
    'support.title': 'Regipass Support Line',
    'support.callPrompt': 'Call this number?',
    'support.call': 'Call',
    'support.callFailed':
        'The call could not be started; the number was copied instead.',

    // Paid event contact rows
    'eventModal.phoneCopied': 'Number copied',
    'eventModal.emailCopied': 'Email copied',

    // Club account screen document card
    'clubAccount.documents.approvedTitle': 'Approved Documents',
    'clubAccount.documents.title': 'My Documents',
    'clubAccount.documents.hint':
        'The documents you submitted with your application. Tap a name to '
        'open it.',
    'clubAccount.documents.badge.approved': 'Approved',
    'clubAccount.documents.badge.review': 'In review',
    'clubAccount.documents.badge.incomplete': 'Incomplete',
    'clubAccount.documents.missing': 'Not uploaded',
    'clubAccount.documents.open': 'Open document',

    // Account screen settings section
    'accountSecurity.title': 'Security',
    'accountSecurity.changePassword': 'Change Password',
    'accountSecurity.changePasswordDesc':
        'Enter your current password to set a new one.',
    'accountSecurity.setPassword': 'Set a Password',
    'accountSecurity.deleteAccount': 'Delete My Account',
    'accountSecurity.deleteAccountDesc':
        'Your account and all of your records are permanently deleted.',
    'accountSecurity.phoneReauth.title': 'Verify with your phone',
    'accountSecurity.phoneReauth.subtitle':
        'We will send a verification code to the number registered to your '
        'account.',
    'accountSecurity.phoneReauth.confirm': 'Confirm Code',
    'accountSecurity.error.noPhone':
        'There is no verified phone number on your account.',
    'accountSecurity.error.phoneMismatch':
        'This number does not belong to your account.',
    'accountSecurity.error.wrongPassword': 'Your current password is wrong.',
    'accountSecurity.error.generic':
        'The action could not be completed. Please try again.',

    'changePassword.subtitle':
        'For your security, enter your current password.',
    'changePassword.subtitleVerified':
        'Your identity is verified. Now set your new password.',
    'changePassword.currentPassword': 'Current Password',
    'changePassword.newPassword': 'New Password',
    'changePassword.newPasswordConfirm': 'New Password (Repeat)',
    'changePassword.forgotCurrent':
        "I don't remember my password, verify with my phone",
    'changePassword.submit': 'Update Password',
    'changePassword.feedback.success': 'Your password has been updated.',
    'changePassword.feedback.currentRequired': 'Enter your current password.',
    'changePassword.feedback.sameAsCurrent':
        'Your new password cannot be the same as the old one.',
    'changePassword.feedback.phoneVerified':
        'Your phone is verified. You can set your new password.',

    'deleteAccount.subtitle': 'This action cannot be undone.',
    'deleteAccount.warning':
        'Your account, profile and event registrations are deleted '
        'permanently. You can sign up again with the same email, but your old '
        'records will not come back.',
    'deleteAccount.passwordLabel': 'Your password',
    'deleteAccount.verifyByPhone': 'Verify with my phone',
    'deleteAccount.submit': 'Permanently Delete My Account',
    'deleteAccount.feedback.passwordRequired':
        'Enter your password to delete your account.',
    'deleteAccount.feedback.verifyFirst':
        'Verify your identity with your phone first.',
    'deleteAccount.feedback.phoneVerified':
        'Your identity is verified. You can delete your account.',
    'deleteAccount.notice.done': 'Your account has been permanently deleted.',

    'screen.comingSoon': 'This section is under construction.',
    'screen.comingSoonDesc':
        'Club and admin screens will be completed in the next stage.',
    'paidEventConsent.log.title': 'Paid Event Consent Record',
    'paidEventConsent.log.club': 'Club consent — event creation',
    'paidEventConsent.log.students': 'Student registration consents',
    'paidEventConsent.log.missing': 'No consent record found.',
    'paidEventConsent.log.studentsEmpty': 'No student has consented yet.',
    'paidEventConsent.log.showText': 'Show the accepted text',
    'paidEventConsent.log.hideText': 'Hide the text',
    'paidEventConsent.log.legacyText':
        'The text of this consent was not stored (recorded before text logging was added).',
    'paidEventConsent.log.tileLabel': 'Payment consent',
    'paidEventConsent.log.note':
        'These records live in the event data; the consent text and the '
        'day/hour/minute/second stamp are frozen at the moment of consent.',
    // İP-O: kapı ekranı (web ile aynı anahtarlar: gate.*)
    'gate.defaultTitle': 'Door · ticket scanning',
    'gate.counter': '✓ {{n}} in',
    'gate.openRecent': 'Open recent scans',
    'gate.recentTitle': 'Recent scans',
    'gate.sessionCount': 'This session: {{n}}',
    'gate.recentEmpty': 'No scans yet.',
    'gate.close': 'Close',
    'gate.pin': 'Pin',
    'gate.unpin': 'Unpin',
    'gate.pinned': 'pinned',
    'gate.soundOn': 'Turn sound on',
    'gate.soundOff': 'Turn sound off',
    'gate.nth': '#{{n}}',
    'gate.unknownStudent': 'Student',
    'gate.notSentYet': 'not sent yet',
    'gate.packInfo': 'List on device: {{n}} tickets · {{time}}',
    'gate.net.online': 'Online',
    'gate.net.offline': 'No internet',
    'gate.net.pending': '{{n}} scans waiting',
    'gate.net.sending': 'sending {{n}} scans',
    'gate.result.in': 'CHECKED IN',
    'gate.result.already': 'ALREADY IN',
    'gate.result.invalid-ticket': 'INVALID TICKET',
    'gate.result.not-registered': 'NOT REGISTERED',
    'gate.result.other-event': 'OTHER EVENT',
    'gate.result.not-owner': 'ANOTHER CLUB\'S EVENT',
    'gate.result.no-door': 'NO DOOR TICKET',
    'gate.result.past-event': 'EVENT IS OVER',
    'gate.result.not-ticket': 'NOT A REGIPASS TICKET',
    'gate.result.unknown-event': 'EVENT NOT FOUND',
    'gate.hint.in': 'Scan the next one',
    'gate.hint.legacy': 'Old app ticket (no code) — check their ID',
    'gate.hint.already': 'First entry {{time}} · count unchanged',
    'gate.hint.invalid-ticket': 'Ticket code mismatch — ask them to reopen the ticket in the app',
    'gate.hint.not-registered': 'This student is not registered',
    'gate.hint.other-event': 'This ticket belongs to another event',
    'gate.hint.not-owner': 'This event is not your club\'s',
    'gate.hint.no-door': 'Attendance only: show the session QR, students scan it',
    'gate.hint.past-event': 'The event day has passed',
    'gate.hint.not-ticket': 'Ask the student to open their Regipass ticket',
    'gate.hint.unknown-event': 'Event not found. If offline: this event\'s list was never downloaded to this device',
    'gate.hint.conflict': 'Another device checked them in at {{time}} — first scan wins',
    'gate.hint.rejected': 'Server rejected — check this entry',
    'gate.conflictToast': '{{name}}: another device scanned first ({{time}}).',
    'gate.cameraHint': 'Hold the ticket up to the camera. It stays on; scan the next one right away.',
    'gate.cameraError': 'Camera could not start. Check the camera permission.',
    // İP-K: kayıt, bekleme listesi, ödeme, etkinlik iptali (web language.js ile aynı anahtarlar)
    'gate.hint.event-cancelled': 'The event was cancelled; tickets are invalid',
    'gate.hint.paidAtGate': 'Payment confirmed at the door, entry recorded',
    'gate.hint.payment-pending': 'Payment not confirmed — cannot enter',
    'gate.markPaid': 'Mark as paid and let in',
    'gate.markPaidFailed': 'Could not mark (internet required). Try again.',
    'gate.markingPaid': 'Marking...',
    'gate.result.event-cancelled': 'EVENT CANCELLED',
    'gate.result.payment-pending': 'PAYMENT NOT CONFIRMED',
    'registration.actions.joinWaitlist': 'Join Waitlist',
    'registration.actions.joiningWaitlist': 'Joining...',
    'registration.actions.leaveWaitlist': 'Leave Waitlist',
    'registration.actions.registerSeatOpen': 'Spot Open — Register Now',
    'registration.actions.registeredPaymentPending': 'Registered · Payment Pending',
    'registration.actions.waitlistPosition': 'You are #{{position}} on the waitlist',
    'registration.alerts.fullOfferWaitlist': 'This event is fully booked. Would you like to join the waitlist? You will be notified if a spot opens; the first to register gets it.',
    'registration.alerts.leaveWaitlistConfirm': 'Are you sure you want to leave the waitlist?',
    'registration.alerts.paymentPendingNote': 'Your registration is "payment pending". It is confirmed once the club marks your payment as received, and you will be notified. You cannot enter until the payment is confirmed.',
    'registration.alerts.seatsAvailableNow': 'A spot just opened up. You can register now.',
    'registration.alerts.waitlistJoined': 'You joined the waitlist: you are #{{position}}. You will be notified when a spot opens; the first to register gets it.',
    'registration.club.addSeats': '+{{n}} spots',
    'registration.club.addSeatsConfirm': 'Capacity will go from {{from}} to {{to}}. People on the waitlist get a "spot opened" notification; the first to register gets it.',
    'registration.club.cancelEventAction': 'Cancel Event',
    'registration.club.cancelEventBody': 'Registered students and the waitlist will be notified; registrations are kept and the event shows as "Cancelled". If it has no registrations it is deleted.',
    'registration.club.cancelEventTitle': 'Cancel event',
    'registration.club.cancelledBanner': 'This event was cancelled. Registered students were notified.',
    'registration.club.cancelledBannerReason': 'This event was cancelled. Reason: {{reason}}',
    'registration.club.eventCancelled': 'Event cancelled. {{n}} people notified.',
    'registration.club.eventDeleted': 'The event had no registrations and was deleted.',
    'registration.club.markPaid': 'Mark as paid',
    'registration.club.markedPaid': '{{name}}: payment confirmed, the student was notified.',
    'registration.club.paid': 'Paid',
    'registration.club.paymentTitle': 'Payment',
    'registration.club.quotaNow': 'Capacity is now {{n}}.',
    'registration.club.quotaSetupDone': 'Capacity set up; registration is open.',
    'registration.club.quotaSetupFailed': 'The capacity could not be set up; registration is closed. Edit and save the event to try again.',
    'registration.club.quotaSetupStatus': 'Setting Up Capacity',
    'registration.club.reasonLabel': 'Reason (optional, shown to students)',
    'registration.club.removeAction': 'Remove registration',
    'registration.club.removeBody': '{{name}}\'s registration will be removed. The student will be notified and the spot opens to the waitlist.',
    'registration.club.removeReasonHint': 'e.g. Payment not made',
    'registration.club.removeTitle': 'Remove registration',
    'registration.club.removed': '{{name}}\'s registration was removed.',
    'registration.club.unmarkConfirm': 'Undo the "Paid" mark for {{name}}? The student will not be able to enter.',
    'registration.club.unmarkPaid': 'Undo',
    'registration.club.unmarkedPaid': '{{name}}: payment mark removed.',
    'registration.club.waitlistCount': '{{count}} people on the waitlist',
    'registration.club.waitlistEmpty': 'Fully booked. The waitlist is empty for now.',
    'registration.errors.banned': 'Your account is blocked, so you cannot register.',
    'registration.errors.below-registered': 'Capacity cannot be lower than the number of registered students ({{registered}}).',
    'registration.errors.busy': 'It\'s very busy right now. Try again in a few seconds.',
    'registration.errors.cancel-locked': 'Sessions have started, so you can no longer delete your registration; contact the club.',
    'registration.errors.club-banned': 'This club\'s events are not accepting registrations right now.',
    'registration.errors.deadline-passed': 'The registration deadline has passed.',
    'registration.errors.event-cancelled': 'This event was cancelled.',
    'registration.errors.event-hidden': 'This event is no longer published.',
    'registration.errors.event-not-found': 'Event not found.',
    'registration.errors.event-not-paid': 'This event is not paid.',
    'registration.errors.event-past': 'The event date has passed.',
    'registration.errors.event-started': 'The event has started; no new registrations.',
    'registration.errors.generic': 'The action could not be completed. Please try again.',
    'registration.errors.invalid-quota': 'Enter a valid capacity.',
    'registration.errors.not-eligible': 'This event is not open to your university or department.',
    'registration.errors.not-event-club': 'Only the event\'s club can do this.',
    'registration.errors.not-registered': 'No registration found for this event.',
    'registration.errors.offline': 'Could not reach the server. Check your connection and try again.',
    'registration.errors.paid-consent-required': 'You need to accept the payment terms for paid events.',
    'registration.errors.payment-pending': 'Your payment is not confirmed yet; you can enter once the club confirms it.',
    'registration.errors.phone-not-verified': 'Verify your phone number before registering.',
    'registration.errors.profile-incomplete': 'Complete your student profile first.',
    'registration.errors.profile-missing': 'Complete your student profile first.',
    'registration.errors.quota-setup': 'The event\'s capacity is not ready yet. Try again shortly.',
    'registration.errors.registration-closed': 'Registration for this event is closed.',
    'registration.errors.signIn': 'Your session seems to have ended. Please sign in again.',
    'eventModal.contactTitle': 'Contact Information',
    'eventModal.feeContactTitle': 'Contact for Payment',
    'eventModal.feeContactNoteClub': 'Fee: {{fee}}. Payment is made directly with the club, outside Regipass; students use the details below to reach the club. When you receive a payment, mark it "Paid" in the student list; the registration is confirmed then.',
    'eventModal.feeContactNoteWithFee': 'Fee: {{fee}}. Payment is made directly with the club, outside Regipass; contact the club using the details below. Your registration is confirmed once the club marks your payment as received.',
    'clubCreateEvent.contact.label': 'Show contact information?',
    'clubCreateEvent.contact.labelPaid': 'Contact information for payment',
    'clubCreateEvent.contact.club': 'Club\'s saved details',
    'clubCreateEvent.contact.custom': 'Enter new details',
    'clubCreateEvent.contact.hidden': 'Don\'t show',
    'clubCreateEvent.contact.clubPreview': 'Will show: {{contact}}',
    'clubCreateEvent.contact.clubEmpty': 'The club profile has no phone/email. Add them on the Club Info page or enter new details.',
    'clubCreateEvent.contact.hiddenHint': 'No contact information will be shown on the event.',
    'clubCreateEvent.contact.phone': 'Contact phone',
    'clubCreateEvent.contact.email': 'Contact email',
    'clubCreateEvent.contact.customHint': 'Fill in at least one. These details appear only on this event.',
    'clubCreateEvent.contact.errorEmpty': 'You chose new details: enter at least a phone or an email.',
    'clubCreateEvent.contact.errorEmail': 'The email address doesn\'t look valid.',
    'clubCreateEvent.contact.errorPhone': 'The phone number must have 11 digits (e.g. 0555 123 45 67 or 0212 123 45 67).',
    'registration.bulk.hint': 'Select students for bulk actions.',
    'registration.bulk.selected': '{{n}} students selected',
    'registration.bulk.selectAll': 'Select all',
    'registration.bulk.clear': 'Clear selection',
    'registration.bulk.selectPending': 'Select payment pending ({{n}})',
    'registration.bulk.markPaid': 'Bulk payment approval',
    'registration.bulk.markPaidN': 'Mark paid ({{n}})',
    'registration.bulk.markPaidConfirm': 'Payment will be confirmed for {{n}} students and each will be notified.',
    'registration.bulk.markedPaid': 'Payment confirmed for {{n}} students.',
    'registration.bulk.nonePending': 'None of the selected students has a pending payment.',
    'registration.bulk.removeN': 'Remove ({{n}})',
    'registration.bulk.removeBody': 'The registrations of {{n}} selected students will be removed. Each will be notified and their spots will open to the waitlist.',
    'registration.bulk.removed': 'Removed {{n}} registrations.',
    'registration.errors.too-many-students': 'You can select at most 200 students at once.',
    'registration.labels.cancelled': 'Cancelled',
    'registration.labels.payment': 'Payment',
    'registration.labels.registeredAt': 'Registered',
    'registration.status.cancelled': 'Cancelled',
    'registration.status.cancelledNoReason': 'The club cancelled the event.',
    'registration.status.fullWaitlist': 'Fully Booked · Waitlist',
    'registration.status.paymentConfirmed': 'Paid (confirmed by the club)',
    'registration.status.paymentPending': 'Payment Pending',
    'registration.status.paymentPendingLong': 'Pending — confirmed once the club marks your payment',
    'registration.status.registeredPaymentPending': 'Registered · Payment Pending',
    'registration.status.waitlisted': 'On the Waitlist',
    'registration.ticket.paymentPendingHint': 'Your payment is not confirmed yet: you cannot enter. The ticket becomes valid once the club confirms your payment.',
  },
};
