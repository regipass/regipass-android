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
    // İP-P (1.0.13): mobile özel paket hattı metinleri
    'plan.mobile.companyWeb':
        'Firma hesabıyla etkinlik, etkinlik paketi seçilerek regipass.com\'dan açılır. Açtığın etkinliği burada yönetebilirsin.',
    // İP-8 / İP-9: yeni sertifika sistemi (web language.js ile aynı metinler)
    'cert.panel.title': 'Katılım Belgesi',
    'cert.editor.sampleName': 'Ad Soyad',
    'cert.gate.open': 'Hak kazanan ve henüz belge almamış herkese gönderebilirsin.',
    'cert.list.open': 'Aç',
    'cert.list.title': 'Liste',
    'cert.mobile.editOnWeb': 'Belgeyi düzenlemek için regipass.com web sitesini kullanın.',
    'cert.mobile.preview': 'Örnek belgeyi gör',
    'cert.mobile.send': 'Gönder',
    'cert.mobile.webOnly': 'Bu etkinlik için henüz belge ayarlanmadı. Örnek belgeyi yüklemek ve düzenlemek için regipass.com web sitesini kullanın.',
    'cert.panel.allSent': 'Herkese gönderildi',
    'cert.panel.loading': 'Katılım belgesi bilgileri yükleniyor…',
    'cert.panel.outdated': 'Şablon gönderimden sonra değişti. {{n}} belge eski sürümde.',
    'cert.panel.reissue': 'Güncel sürümü yeniden gönder',
    'cert.panel.revokeAll': 'Tüm gönderimi geri al',
    'cert.panel.revoking': 'Geri alınıyor…',
    'cert.panel.sendN': '{{n}} kişiye gönder',
    'cert.panel.sendNew': '{{n}} yeni kişiye gönder',
    'cert.panel.sending': 'Gönderiliyor… {{done}}/{{total}}',
    'cert.reason.already-running': 'Bu etkinlikte bir gönderim ya da geri alma işlemi sürüyor. Bitince tekrar dene.',
    'cert.reason.bad-color': 'Renk kodu geçersiz.',
    'cert.reason.bad-font': 'Yazı tipi geçersiz.',
    'cert.reason.bad-page': 'Bir alan, şablonda olmayan bir sayfada.',
    'cert.reason.bad-size': 'Punto 6 ile 96 arasında olmalı.',
    'cert.reason.bad-threshold': 'Eşik 0 ile 100 arasında olmalı.',
    'cert.reason.box-outside-page': 'Bir alan sayfanın dışına taşıyor; kutuyu sayfanın içine çek.',
    'cert.reason.box-too-small': 'Bir alan çok küçük; kutuyu biraz büyüt.',
    'cert.reason.certificate-not-found': 'Belge bulunamadı.',
    'cert.reason.certificate-not-issued': 'Bu belge henüz gönderilmedi.',
    'cert.reason.certificate-revoked': 'Bu belge geri alındı.',
    'cert.reason.checkin-not-started': 'Gönderim kilitli: önce kapı girişini başlat, etkinlik bitince “Kapı Girişini Bitir”e bas.',
    'cert.reason.checkin-open': 'Gönderim kilitli: kapı girişi hâlâ açık. “Kapı Girişini Bitir”e bastığında açılır.',
    'cert.reason.club-banned': 'Organizatör hesabın engelli olduğu için bu işlem yapılamıyor.',
    'cert.reason.code-collision': 'Belge kodu üretilemedi. Tekrar dene.',
    'cert.reason.config-not-saved': 'Önce belgeyi editörde ayarlayıp kaydet.',
    'cert.reason.empty-text': 'Serbest metin alanı boş olamaz.',
    'cert.reason.event-cancelled': 'Etkinlik iptal edildiği için belge gönderilemez.',
    'cert.reason.event-missing': 'Etkinlik bulunamadı.',
    'cert.reason.event-not-found': 'Etkinlik bulunamadı.',
    'cert.reason.generic': 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
    'cert.reason.missing-student-name': '“Katılımcı adı” alanı sayfada olmalı.',
    'cert.reason.name-missing': 'profilde ad yok',
    'cert.reason.not-allowed': 'Bu belgeyi açma yetkin yok.',
    'cert.reason.not-event-club': 'Bu etkinlik sana ait değil.',
    'cert.reason.render-failed': 'belge üretilemedi',
    'cert.reason.sessions-not-finished': 'Gönderim kilitli: önce etkinlik ekranında “Oturumları Bitir”e bas.',
    'cert.reason.student-name-missing': 'profilde ad yok',
    'cert.reason.template-empty': 'PDF\'te hiç sayfa yok.',
    'cert.reason.template-encrypted': 'Bu PDF şifreli. Şifresiz bir kopyasını yükle.',
    'cert.reason.template-missing': 'Şablon bulunamadı. Örnek belgeni yeniden yükle.',
    'cert.reason.template-too-large': 'Dosya çok büyük (en çok 10 MB).',
    'cert.reason.template-unreadable': 'Bu PDF okunamadı. Dosyayı farklı bir programdan yeniden dışa aktarıp tekrar dene.',
    'cert.reason.template-unsupported': 'Bu dosya türü desteklenmiyor. PDF, PNG ya da JPG yükle.',
    'cert.reason.too-many-fields': 'En çok 20 alan eklenebilir.',
    'cert.revoke.text': 'Belgeler katılımcıların ekranından kalkar ve doğrulama sayfasında “İptal edildi” olarak görünür. İstersen sonra yeniden gönderebilirsin; yeni belgeler yeni kodla üretilir.',
    'cert.revoke.title': 'Etkinliğin bütün belgeleri iptal edilsin mi?',
    'cert.revoke.yes': 'Evet, hepsini geri al',
    'cert.stat.eligible': 'Hak kazanan',
    'cert.stat.pending': 'Bekleyen',
    'cert.stat.revoked': 'Geri alınan',
    'cert.stat.sent': 'Gönderilen',
    'cert.status.failed': 'Hata',
    'cert.status.revoked': 'Geri alındı',
    'cert.status.sent': 'Gönderildi',
    'cert.threshold.none': 'Eşik yok (en az 1 oturum) → {{n}} kişi alacak',
    'cert.threshold.result': '%{{p}} → {{n}} kişi alacak',
    'cert.threshold.save': 'Eşiği kaydet',
    'cert.threshold.saved': 'Eşik kaydedildi.',
    'cert.threshold.title': 'Yüzde eşiği',
    'cert.toast.revoked': '{{n}} belge geri alındı.',
    'cert.toast.sent': '{{sent}} belge gönderildi.',
    'cert.toast.sentWithErrors': '{{sent}} belge gönderildi, {{failed}} hata. Hatalar listede.',
    'studentCertificates.copied': 'Doğrulama bağlantısı kopyalandı.',
    'studentCertificates.fallbackTitle': 'Katılım belgesi',
    'studentCertificates.fullNameOff': 'Doğrulama sayfasında adın yeniden kısaltıldı.',
    'studentCertificates.fullNameOn': 'Doğrulama sayfasında artık tam adın görünüyor.',
    'studentCertificates.menu.copyLink': 'Doğrulama bağlantısını kopyala',
    'studentCertificates.menu.fullName': 'Doğrulama sayfasında tam adım görünsün',
    'studentCertificates.menu.linkedin': 'LinkedIn profiline ekle',
    'studentCertificates.menuLabel': 'Belge seçenekleri',
    'studentCertificates.revoked': 'Organizatör tarafından iptal edildi',
    // İP-W: cüzdan
    'wallet.addApple': 'Apple Cüzdan\'a ekle',
    'wallet.addGoogle': 'Google Cüzdan\'a ekle',
    'wallet.preparing': 'Hazırlanıyor...',
    'wallet.error.disabled': 'Cüzdana ekleme şu an kullanılamıyor.',
    'wallet.error.paymentPending': 'Ödemen onaylanınca bileti cüzdana ekleyebilirsin.',
    'wallet.error.cancelled': 'İptal edilen etkinliğin bileti cüzdana eklenemez.',
    'wallet.error.past': 'Geçmiş etkinliğin bileti cüzdana eklenemez.',
    'wallet.error.generic': 'Bilet hazırlanamadı. İnternetini kontrol edip tekrar dene.',
    // İP-R: rapor
    'report.title': 'Etkinlik Raporu',
    'report.button': 'Raporu İndir',
    'report.pdf': 'PDF',
    'report.excel': 'Excel',
    'report.help': 'Katılım, yoklama ve değerlendirme özeti. Katılımcı listesi yalnızca Excel\'de.',
    'report.preparing': 'Rapor hazırlanıyor...',
    'report.done': 'Rapor indirildi.',
    'report.error': 'Rapor hazırlanamadı. İnternetini kontrol edip tekrar dene.',
    // İP-D: değerlendirme
    'feedback.locale': 'tr-TR',
    'feedback.decimal': ',',
    'feedback.title': 'Etkinliği değerlendir',
    'feedback.titleRated': 'Değerlendirmen',
    'feedback.help': 'Etkinlik nasıldı? Yıldız ver, istersen kısa bir yorum yaz.',
    'feedback.ratingAria': 'Puan (1–5 yıldız)',
    'feedback.starsAria': '{{n}} yıldız',
    'feedback.ratingLabel.1': 'Hiç beğenmedim',
    'feedback.ratingLabel.2': 'Beğenmedim',
    'feedback.ratingLabel.3': 'Fena değil',
    'feedback.ratingLabel.4': 'Beğendim',
    'feedback.ratingLabel.5': 'Çok beğendim',
    'feedback.commentLabel': 'Yorum (isteğe bağlı)',
    'feedback.commentPlaceholder': 'Neyi beğendin, ne daha iyi olabilirdi?',
    'feedback.submit': 'Gönder',
    'feedback.update': 'Güncelle',
    'feedback.sending': 'Gönderiliyor...',
    'feedback.edit': 'Değerlendirmeyi düzenle',
    'feedback.editUntil': '{{date}} tarihine kadar düzenleyebilirsin.',
    'feedback.thanks': 'Teşekkürler! Değerlendirmen organizatöre isimsiz iletildi.',
    'feedback.anonymousNote': 'Organizatör adını görmez; puanlar isimsiz paylaşılır.',
    'feedback.cardRate': 'Değerlendir',
    'feedback.error.notCheckedIn': 'Yalnızca etkinliğe giriş yapanlar değerlendirme yapabilir.',
    'feedback.error.notFinished': 'Etkinlik bitince değerlendirebilirsin.',
    'feedback.error.closed': 'Değerlendirme süresi (14 gün) doldu.',
    'feedback.error.cancelled': 'İptal edilen etkinlik değerlendirilemez.',
    'feedback.error.badRating': '1 ile 5 arasında yıldız seç.',
    'feedback.error.banned': 'Hesabın askıya alındığı için değerlendirme yapamazsın.',
    'feedback.error.notOwner': 'Bu etkinliğin değerlendirmelerini yalnızca düzenleyen organizatör görür.',
    'feedback.error.generic': 'Gönderilemedi. İnternetini kontrol edip tekrar dene.',
    'feedback.club.title': 'Değerlendirmeler',
    'feedback.club.empty': 'Henüz değerlendirme yok. Etkinlik bitince katılanlardan istenir.',
    'feedback.club.count': '{{n}} değerlendirme',
    'feedback.club.comments': 'Yorumlar',
    'feedback.club.commentsHidden': 'Yorumlar, kimin yazdığı tahmin edilmesin diye en az {{n}} değerlendirme olunca görünür.',
    'feedback.club.anonymous': 'Değerlendirmeler isimsizdir; kimin hangi puanı verdiği gösterilmez.',
    'feedback.club.loadError': 'Değerlendirmeler yüklenemedi. Pencereyi kapatıp yeniden aç.',
    // İP-TK: kulüp takip
    'follow.follow': 'Takip et',
    'follow.following': 'Takip ediliyor',
    'follow.unfollow': 'Takibi bırak',
    'follow.followHint': 'Organizatör yeni etkinlik yayınlayınca bildirim al',
    'follow.unfollowHint': 'Takibi bırakmak için dokun',
    'follow.toastFollowed': 'Organizatörü takip ediyorsun. Yeni etkinliklerde haber vereceğiz.',
    'follow.toastUnfollowed': 'Takibi bıraktın.',
    'follow.filterAria': 'Etkinlik filtresi',
    'follow.filterAll': 'Tümü',
    'follow.filterFollowing': 'Takip ettiklerim',
    'follow.empty.title': 'Takip ettiğin organizatörlerin açık etkinliği yok',
    'follow.empty.desc': 'Bir etkinlikte organizatörün yanındaki "Takip et"e dokun.',
    'follow.account.title': 'Takip ettiğim organizatörler',
    'follow.account.help': 'Takip ettiğin organizatörler yeni etkinlik açınca bildirim alırsın. Organizatörler kimin takip ettiğini göremez.',
    'follow.account.empty': 'Henüz organizatör takip etmiyorsun.',
    'follow.account.unavailable': 'Bu organizatör şu an etkinlik yayınlamıyor.',
    'follow.account.confirmUnfollow': '{{name}} takibi bırakılsın mı? Yeni etkinliklerinde bildirim almazsın.',
    'follow.account.unfollowed': '{{name}} takibini bıraktın.',
    'follow.club.followers': 'takipçi',
    'follow.error.clubUnavailable': 'Bu organizatör şu an takip edilemiyor.',
    'follow.error.tooMany': 'En fazla 300 organizatör takip edebilirsin. Önce birinin takibini bırak.',
    'follow.error.banned': 'Hesabın askıya alındığı için organizatör takip edemezsin.',
    'follow.error.studentOnly': 'Organizatörleri yalnızca katılımcı hesapları takip edebilir.',
    'follow.error.signIn': 'Takip etmek için giriş yapmalısın.',
    'follow.error.generic': 'İşlem yapılamadı. İnternetini kontrol edip tekrar dene.',
    // İP-B: etkinlik bildirimleri
    'autoNotify.title': 'Otomatik bildirimler',
    'profileChange.pendingTitle': 'Değişikliğin yönetici onayında',
    'profileChange.pendingHelp': 'Onaylanana kadar katılımcılar ve etkinliklerin eski bilgileri görür; hesabın çalışmaya devam eder.',
    'profileChange.rejectedTitle': 'Son değişikliğin onaylanmadı',
    'profileChange.rejectedNote': 'Gerekçe: {{note}}',
    'profileChange.withdraw': 'İsteği geri çek',
    'profileChange.withdrawConfirm': 'Onay bekleyen değişikliğin geri çekilsin mi?',
    'profileChange.sent': 'Değişikliğin yönetici onayına gönderildi. Onaylanınca etkinliklerine de yansır.',
    'profileChange.logoSent': 'Yeni logon yönetici onayına gönderildi. Onaylanana kadar mevcut logo görünür.',
    'profileChange.field.clubName': 'Organizatör adı',
    'profileChange.field.university': 'Üniversite',
    'profileChange.field.city': 'İl',
    'profileChange.field.clubPurpose': 'Organizatörün amacı',
    'profileChange.field.clubContents': 'Organizatörün içerikleri',
    'profileChange.field.clubFields': 'Alanlar',
    'profileChange.field.logoUrl': 'Logo',
    'autoNotify.needStart': 'Başlangıç saati gerekli',
    'autoNotify.needEnd': 'Bitiş saati gerekli',
    'autoNotify.warnStart': 'Başlangıç saati girmezsen “1 saat önce” ve “Başladığında” bildirimleri gitmez.',
    'autoNotify.warnEnd': 'Bitiş saati girmezsen “Teşekkür” bildirimi gitmez.',
    'autoNotify.warnBoth': 'Başlangıç ve bitiş saati girmezsen “1 saat önce”, “Başladığında” ve “Teşekkür” bildirimleri gitmez.',
    'autoNotify.help':
        'Kayıtlı katılımcılara Regipass kendiliğinden bildirim gönderir. Saat '
        'girilmezse yalnızca "1 gün önce" gider.',
    'autoNotify.dayBefore': '1 gün önce (19:00) hatırlatma',
    'autoNotify.hourBefore': 'Başlamadan 1 saat önce',
    'autoNotify.atStart': 'Başladığında (girişini yapmamış olanlara)',
    'autoNotify.afterEnd': 'Bittikten sonra teşekkür (katılanlara)',
    'eventNotify.title': 'Bildirimler',
    'eventNotify.status.planned': 'Planlandı',
    'eventNotify.status.noTime': 'Saat bilgisi yok',
    'eventNotify.autoHelpEditable':
        'Otomatik bildirimler: henüz gönderilmemiş olanları buradan açıp kapatabilirsin.',
    'eventNotify.openPage': 'Bildirim gönder ve ayarla',
    'eventNotify.toggleError': 'Ayar kaydedilemedi. Tekrar dene.',
    'clubNotify.title': 'Bildirimler',
    'clubNotify.subtitle':
        'Otomatik bildirimler ve mesajlar.',
    'clubNotify.tab.upcoming': 'Yaklaşan',
    'clubNotify.tab.active': 'Süren',
    'clubNotify.tab.recent': 'Biten',
    'clubNotify.search': 'Etkinlik ara',
    'clubNotify.empty.upcoming': 'Yaklaşan etkinliğin yok.',
    'clubNotify.empty.active': 'Şu an süren etkinlik yok.',
    'clubNotify.empty.recent': 'Son 7 günde biten etkinlik yok.',
    'clubNotify.windowNote': 'Biten etkinliklere bitişten sonraki 7 gün mesaj gönderilebilir.',
    'clubNotify.all': 'Tüm gönderimler',
    'clubNotify.allEmpty': 'Henüz gönderim yok.',
    'clubNotify.filter.all': 'Hepsi',
    'clubNotify.filter.manual': 'Elle',
    'clubNotify.filter.auto': 'Otomatik',
    'clubNotify.cancelled': 'İptal edildi',
    'clubNotify.notFound': 'Etkinlik bulunamadı.',
    'clubNotify.entryOpen': 'Giriş başladı',
    'clubNotify.sessionStarted': '{{n}}. oturum başladı',
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
        '{tarih}, {saat}, {yer}, {organizatör}.',
    'eventNotify.errors.fill': 'Şablondaki … yerini doldurmadın.',
    'eventNotify.audience.payment_pending': 'Ödemesi bekleyenler',
    'eventNotify.templateLabel': 'Hazır şablon',
    'eventNotify.templateNone': 'Boş mesaj',
    'eventNotify.tagsLabel': 'Akıllı etiket ekle',
    'eventNotify.previewLabel': 'Önizleme (örnek katılımcı)',
    'eventNotify.quota': 'Bugün kalan: {{left}}/{{limit}}',
    'eventNotify.nextIn': 'sonraki gönderim {{minutes}} dk sonra',
    'eventNotify.tag.ad': 'Katılımcının adı',
    'eventNotify.tag.etkinlik': 'Etkinlik adı',
    'eventNotify.tag.tarih': 'Tarih',
    'eventNotify.tag.saat': 'Saat',
    'eventNotify.tag.yer': 'Yer',
    'eventNotify.tag.kulup': 'Organizatörün adı',
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
        'Hesabın onaylanmadan mesaj gönderemezsin.',
    'eventNotify.errors.club-banned': 'Organizatör hesabın askıda.',
    'eventNotify.errors.not-event-club':
        'Bu etkinlik sana ait değil.',
    // İP-T: takvime ekle
    'calendar.add': 'Takvime ekle',
    'postRegistration.title': 'Kaydın tamam',
    'postRegistration.calendarAsk': 'Takvimine ekleyelim mi?',
    'postRegistration.calendarApp': 'Takvim uygulaması',
    'postRegistration.ticketTitle': 'Biletini telefonuna kaydet',
    'postRegistration.ticketSave': 'Bileti resim olarak kaydet',
    'postRegistration.ticketHint':
        'İnternetsiz de açılır; Biletim\'de her zaman bulursun.',
    'postRegistration.ticketPreparing': 'Bilet hazırlanıyor…',
    'postRegistration.ticketReady': 'Bilet hazır; açılan menüden kaydedebilirsin.',
    'postRegistration.ticketError': 'Bilet resmi hazırlanamadı. Biletim sayfasından gösterebilirsin.',
    'postRegistration.skip': 'Bundan sonra sorma',
    'postRegistration.done': 'Tamam',
    'calendar.google': 'Google Takvim',
    'calendar.ics': 'Takvim dosyası (.ics)',
    'calendar.icsHint': 'Apple Takvim, Outlook ve diğerleri',
    // İP-KB: kulübün öğrenci engeli
    'clubBlock.title': 'Etkinliklerimden engelle',
    'clubBlock.action': 'Etkinliklerimden engelle',
    'clubBlock.body':
        '{{name}} etkinliklerinden engellenecek: yeni etkinliklere '
        'kaydolamaz, bekleme listesine giremez.',
    'clubBlock.reasonLabel': 'Gerekçe',
    'clubBlock.reasonHelper':
        'Zorunlu. Katılımcıya gösterilmez; organizatörün ve Regipass yönetiminin '
        'kaydında durur.',
    'clubBlock.reasonRequired': 'En az 3 karakterlik bir gerekçe yaz.',
    'clubBlock.removeFuture':
        'Gelecek etkinliklerdeki kayıtlarını da sil (katılımcıya "kaydın '
        'iptal edildi" bildirimi gider)',
    'clubBlock.done':
        '{{name}} etkinliklerinden engellendi. Silinen gelecek '
        'kayıt: {{count}}.',
    'clubBlock.listTitle': 'Engellenen katılımcılar',
    'clubBlock.listHelp':
        'Bu katılımcılar etkinliklerine kaydolamaz.',
    'clubBlock.empty': 'Engellediğin katılımcı yok.',
    'clubBlock.unblock': 'Engeli kaldır',
    'clubBlock.unblockConfirm':
        '{{name}} için engel kaldırılsın mı? Etkinliklerine yeniden '
        'kaydolabilir.',
    'clubBlock.unblocked': '{{name}} için engel kaldırıldı.',
    'clubBlock.studentFallback': 'Katılımcı',
    'clubBlock.error': 'İşlem tamamlanamadı. Tekrar dene.',
    'clubBlock.errors.reason-required':
        'En az 3 karakterlik bir gerekçe yazmalısın.',
    'clubBlock.errors.student-not-related':
        'Yalnızca etkinliğine kaydolmuş katılımcıları engelleyebilirsin.',
    'clubBlock.errors.club-not-approved':
        'Hesabın onaylanmadan katılımcı engelleyemezsin.',
    'clubBlock.errors.club-banned': 'Organizatör hesabın askıda.',
    'clubBlock.errors.not-a-club': 'Bu işlem yalnızca organizatör hesabıyla yapılır.',
    'clubBlock.errors.invalid-student': 'Katılımcı bulunamadı.',
    'registration.errors.blocked-by-club':
        'Bu organizatörün etkinliklerine kaydolamıyorsun.',
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
        'Bu organizatörün gelecekteki {{events}} etkinliği İPTAL edilecek ve {{people}} kayıtlı kişiye bildirim gidecek. Organizatör hesabı giriş yapamayacak.',
    'admin.ban.reasonLabel': 'Gerekçe',
    'admin.ban.reasonHelper':
        'Zorunlu. İşlem kaydına yazılır; katılımcılara gösterilmez.',
    'admin.ban.reasonRequired': 'Engellemek için bir gerekçe yaz.',
    // register.js içinde sabit metin olarak duruyordu
    'auth.error.roleAlreadyExists':
        'Bu hesap türü zaten var. Lütfen giriş yap.',
    'auth.error.emailRegisteredWrongPassword':
        'Bu e-posta kayıtlı, şifre hatalı.',
    // Kayıt ekranındaki zorunlu KVKK/sözleşme onayı işaretlenmeden kayıt
    // düğmesi zaten pasif kalır; bu metin yalnızca Enter/gönder ile
    // tetiklenen kenar durumlar için (bkz. register_screen.dart).
    'auth.feedback.ageRequired':
        'Kayıt olmak için 18 yaşından büyük olduğunu onaylamalısın.',
    'auth.feedback.termsRequired':
        'Devam etmek için Kullanıcı ve Organizatör Sözleşmesi ile KVKK Aydınlatma '
        'Metni\'ni onaylamalısın.',
    // Onay özeti — bilgi formunun altında ve hesap kartlarında.
    'legal.consent.summaryTitle': 'Onayladığın metinler',
    'legal.consent.acceptedAt': 'Onay zamanı',
    'legal.consent.tileLabel': 'Sözleşme ve KVKK onayı',
    'legal.consent.notRecorded': 'Kayıt yok',
    'legal.consent.acceptedNoTime': 'Onaylandı (zaman kaydı yok)',
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
        'Bu telefon aynı e-postaya bağlı katılımcı ve organizatör hesaplarında ortak kullanılır ve zaten doğrulanmıştır. Bu formdan değiştirilemez.',
    'auth.error.networkFailed': 'Bağlantı kurulamadı. İnternetini kontrol et.',
    'explore.guestTitle': 'Misafir olarak geziyorsun',
    'explore.guestDesc':
        'Kaydolmak ve bilet almak için giriş yap.',
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
    'notification.event.student.deadline.title': 'Kayıtlar kapandı',
    'notification.event.student.deadline.body':
        '{{title}} için kayıt süresi doldu.',

    'notification.event.club.upcoming.title': 'Etkinliğin yaklaşıyor',
    'notification.event.club.upcoming.body':
        '{{title}} yarım saat sonra başlıyor. Katılımcı girişine hazır ol.',
    'notification.event.club.started.title': 'Etkinlik başladı',
    'notification.event.club.started.body': '{{title}} şimdi başladı.',
    'notification.event.club.deadline.title': 'Kayıtlar kapandı',
    'notification.event.club.deadline.body':
        '{{title}} için kayıtlar sona erdi, katılımcı listen kesinleşti.',

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
    'admin.notify.audience.students': 'Katılımcılar',
    'admin.notify.audience.clubs': 'Organizatörler',
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
    'clubAccount.title': 'Organizatör Hesabım',
    'clubAccount.edit': 'Bilgileri Düzenle',
    'clubAccount.section.manager': 'Yetkili Bilgileri',
    'clubAccount.section.club': 'Organizatör Bilgileri',
    'studentAppointments.title': 'Etkinliklerim',
    'studentAppointments.activeTitle': 'Yaklaşan',
    'studentAppointments.pastTitle': 'Geçmiş',

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
        'Yeni numarayı SMS ile doğrulaman gerekir.',
    'account.phoneNotChanged':
        'Numara doğrulanmadı; kayıtlı numaran olduğu gibi kaldı.',
    // Telefon doğrulama hataları (üretilen sözlükte karşılığı yok)
    'phoneVerify.error.browserCanceled':
        'Doğrulama yarıda kaldı. Kodu tekrar gönder.',
    'phoneVerify.error.browserAlreadyOpen':
        'Devam eden bir doğrulama var. Birkaç saniye sonra tekrar dene.',
    'phoneVerify.error.network':
        'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
    'phoneVerify.error.deviceCheckFailed':
        'SMS gönderilemedi. Lütfen daha sonra tekrar dene.',
    // Bir e-postaya artık tek rol bağlanabildiği için kayıt akışında çıkan
    // uyarı (bkz. AuthRepository kayıt akışı).
    'auth.error.emailAlreadyRegistered':
        'Bu e-posta ile bir hesap var. Giriş yap ya da şifreni yenile.',
    'phoneVerifySheet.title': 'Telefon Numarasını Doğrula',
    'phoneVerifySheet.subtitle':
        'Bu numaraya 6 haneli bir kod göndereceğiz.',

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
    'eventModal.club': 'Organizatör',
    'eventModal.eventDate': 'Etkinlik Tarihi',
    'eventModal.deadline': 'Son Kayıt',
    'eventModal.fee': 'Ücret',
    'eventModal.free': 'Ücretsiz',
    'eventModal.quota': 'Kontenjan',
    'eventModal.unlimited': 'Sınırsız',
    'eventModal.location': 'Konum',
    'eventModal.sessions': 'Oturum Sayısı',
    'eventModal.sessionsValue': '{{count}} oturum',
    'eventModal.clubContact': 'Organizatör İletişim',
    'eventModal.feeContactNote':
        'Bu etkinlik ücretlidir. Ücret ve ödeme için organizatörün iletişim '
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
        'Oturum henüz başlatılmadı. Organizatör oturumu başlattığında QR\'ı tekrar okut.',
    'attendance.error.banned': 'Hesabın kısıtlandığı için giriş yapılamıyor.',
    'attendance.qrKeyError':
        'QR oluşturulamadı. İnternet bağlantısını kontrol edip tekrar dene.',
    'attendance.entryRotatingHint':
        'Katılımcılar bu kodu kendi telefonlarıyla okutur. Kod {{seconds}} sn sonra yenilenecek.',
    'clubScan.ticketMismatch':
        'Bilet kodu kayıtla eşleşmiyor (eski ya da taklit bilet). Katılımcı bileti uygulamadan yeniden açsın.',
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
    'scan.pointCamera': 'Kamerayı QR koda tut.',
    'scan.ready': 'Sonraki katılımcı için hazır.',
    'scan.successTitle': 'Giriş Başarılı',
    'scan.failTitle': 'Giriş Başarısız',
    'scan.notRegipassQr': 'Bu QR Regipass giriş kodu değil.',
    'scan.missingEventInfo': 'QR kod eksik ya da bozuk.',
    'scan.notSessionQr': 'Bu QR bir oturum giriş kodu değil.',
    'clubScan.needsDoorCheckin':
        '{{name}} henüz kapı girişi yapmamış; önce kapı girişi gerekiyor.',
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
    'scan.permissionError': 'Bu giriş kaydedilemedi. Organizatör görevlisine bildir.',
    'scan.sessionSuccess':
        '{{current}}. oturumdasınız (katılım {{attended}}/{{total}}).',
    'scan.otherEventQr':
        'Bu QR başka bir etkinliğe ait. Girdiğiniz etkinliğin oturum QR\'ını okutun.',

    // Oturumlu etkinlikte öğrenci QR üretmez, kulübün oturum QR'ını okutur.
    'studentAppointments.modal.showTicket': 'Biletimi Göster',
    'studentAppointments.modal.scanQr': 'Oturum QR\'ını Okut',
    'studentAppointments.modal.scanReady':
        '{{current}}. oturum açık. Organizatörün ekranındaki QR\'ı okutarak giriş yap.',
    'studentAppointments.modal.scanNotStarted':
        'Organizatör henüz ilk oturumu başlatmadı. Oturum açıldığında bu düğme aktifleşir.',
    'studentAppointments.modal.scanAlreadyDone':
        '{{current}}. oturumun girişi yapıldı. Organizatör yeni oturumu açtığında düğme yeniden aktifleşir.',
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
        'Oturumlu etkinliğin yok. Oturum QR\'ı yalnızca birden çok oturumlu etkinliklerde var.',
    'clubSessionQr.manage': 'Etkinliği Yönet',
    'clubSessionQr.hint':
        'Bir etkinliğe dokun, oturum QR\'ı açılır.',
    'clubDashboard.empty':
        'Şu an etkinlik yok.',

    'clubEvents.title': 'Etkinlik',
    'clubEvents.edit': 'Düzenle',
    'clubEvents.status.closed': 'Kayıtlar Kapalı',
    'clubEvents.group.active': 'Aktif',
    'clubEvents.group.upcoming': 'Gelecek',
    'clubEvents.group.past': 'Geçmiş',
    'clubEvents.empty.active':
        'Aktif etkinliğin yok. + ile yeni etkinlik oluştur.',
    'clubEvents.empty.upcoming': 'Gelecek etkinlik bulunmuyor.',
    'clubEvents.empty.past': 'Geçmiş etkinlik bulunmuyor.',
    'clubEvents.feedback.loadError':
        'Etkinlikler yüklenemedi. Lütfen tekrar dene.',
    'clubEvents.feedback.updateError':
        'İşlem tamamlanamadı. Tekrar dene.',
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
        'Geçmiş etkinlik yalnızca kendi listenden kaldırılacak; katılımcıların kayıtları etkilenmez.',

    'clubEvents.registrations.title': 'Kayıtlar',
    'clubEvents.qr.locationRequired':
        'QR oluşturmak için etkinliği düzenleyip haritadan konum seç. Katılımcının güncel konumu bu konumla karşılaştırılacak.',
    'clubEvents.quota.title': 'Kontenjan',
    'clubEvents.quota.remaining': '{{count}} kişilik yer kaldı.',
    'clubEvents.quota.full': 'Kontenjan doldu.',
    'clubEvents.quota.autoPaused':
        'Kontenjan dolduğu için kayıtlar beklemeye alındı. Kontenjanı artırırsan kayıtlar kendiliğinden yeniden açılır.',
    'clubEvents.registrations.subtitle':
        'Kayıtları durdurursan yeni kayıt alınmaz.',
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
        'girişini bitir, sonra oturumları tek tek en başa (0) geri al. '
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
        'Önce kapı girişini bitir; oturum ancak sonra başlatılabilir.',
    'clubEvents.session.stateNotStarted': 'Oturumlar henüz başlamadı',
    'clubEvents.session.stateActive': 'Oturum devam ediyor',
    'form.sessionNames': 'Oturum adları ve saatleri (isteğe bağlı)',
    'form.sessionStart': 'Başlangıç',
    'form.sessionEnd': 'Bitiş',
    'placeholder.sessionNameN': '{{n}}. oturumun adı',
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
        'Kapı girişi de "başlatılmadı" durumuna döner ve etkinlik yeniden '
        'keşfette görünür; oturumları tekrar başlatmadan önce kapı girişini '
        'baştan başlatıp bitirmen gerekir.',
    'clubEvents.session.undone':
        '{{session}}. oturuma dönüldü. Bu oturumun QR\'ı yeniden geçerli.',
    'clubEvents.session.undoneToStart':
        'Oturumlar başlangıca alındı. QR girişleri şimdilik durdu.',
    'clubEvents.session.undoneToStartWithCheckin':
        'Oturumlar ve kapı girişi başlangıca alındı. Etkinlik, standartlara '
        'uyan katılımcıların keşfinde tekrar görünür.',
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
        '{{session}}. oturum başlatıldı. Katılımcılar bu oturum için QR okutabilir.',
    'clubEvents.session.finished':
        'Tüm oturumlar tamamlandı. Artık katılımcılara belge gönderebilirsin.',
    'clubEvents.session.qrTitle': '{{session}}. Oturum QR\'ı',
    'clubEvents.session.qrRotatingHint':
        'Katılımcılar bu QR\'ı telefon kamerasıyla okutsun. Kod {{seconds}} sn sonra yenilenecek.',
    'clubEvents.session.qrHint':
        'Bu kodu ekrana yansıt; katılımcılar kendi telefonlarından okutsun.',
    'clubEvents.session.qrError': 'QR görseli yüklenemedi.',
    'clubEvents.entry.stateNotStarted': 'Kapı girişi başlatılmadı',
    'clubEvents.entry.stateRunning': 'Kapı girişi açık',
    'clubEvents.entry.stateFinished': 'Kapı girişi bitti',
    'clubEvents.entry.tally': ' — {{attended}}/{{total}} katılımcı giriş yaptı',
    'clubEvents.entry.start': 'Kapı Girişini Başlat',
    'clubEvents.entry.finish': 'Kapı Girişini Bitir',
    'clubEvents.entry.restart': 'Kapı Girişini Yeniden Başlat',
    'clubEvents.entry.title': 'Kapı Girişi',
    'clubEvents.entry.subtitle':
        'Katılımcılar bu QR\'ı kendi telefonlarıyla okutur.',
    'clubEvents.entry.open': 'Kapı QR\'ını Aç',
    'clubEvents.entry.show': 'Kapıda Tek QR Giriş',
    'clubEvents.entry.close': 'Kapıyı Kapat',
    'clubEvents.entry.qrTitle': 'Kapı Girişi QR\'ı',
    'clubEvents.entry.qrHint':
        'Katılımcılar bu QR\'ı kendi telefonlarıyla okutur.',
    'clubEvents.session.allowWithoutCheckin':
        'Kapı girişi yapmayanlar da yoklamaya katılabilsin',
    'clubEvents.session.allowWithoutCheckinHint':
        'Kapıda girişi kaçıran katılımcılar da oturum yoklamalarına katılabilir.',

    'clubEvents.scan.action': 'Katılımcı QR\'ı Okut',
    'clubEvents.scan.subtitle':
        'Katılımcının telefonunda ürettiği giriş kodunu okut.',

    'clubEvents.certificate.title': 'Belge',
    'clubEvents.certificate.action': 'Belge Yükle ve Dağıt',
    'clubEvents.certificate.subtitle':
        'Belge, katılım şartını sağlayan katılımcılara gönderilir.',
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
        'Bu liste organizatörün arşividir; katılımcının belgelerinde en son dağıttığın '
        'belge görünür.',
    'clubEvents.certificate.delete': 'Belgeyi sil',
    'clubEvents.certificate.deleteTitle': 'Belgeyi sil',
    'clubEvents.certificate.deleteConfirm':
        'Bu belgeyi listeden kaldırmak istiyor musun? Katılımcılara daha önce '
        'gönderilmiş kopyalar bundan etkilenmez.',
    'clubEvents.certificate.deleted': 'Belge silindi.',
    'clubEvents.certificate.deleteError':
        'Belge silinemedi. Lütfen tekrar dene.',
    'clubEvents.certificate.storedOnly':
        'Belge sisteme yüklendi. Hak kazanan katılımcı olmadığı için henüz '
        'kimseye gönderilmedi; hak sahipleri belirlendiğinde kendiliğinden '
        'dağıtılır. Beklemek istemezsen belgenin üzerindeki gönder tuşuyla '
        'hemen dağıtabilirsin.',
    'clubEvents.certificate.uploading': 'Belge yükleniyor...',
    'clubEvents.certificate.autoSent':
        'Etkinlik bittiği için belge {{count}} katılımcıya otomatik gönderildi.',
    'clubEvents.certificate.partial':
        'Belge {{count}} katılımcıya gönderildi, {{failed}} katılımcıya ulaşmadı. '
        'Tekrar deneyebilirsin.',
    'clubEvents.certificate.redistribute': 'Bu belgeyi dağıt',
    'clubEvents.certificate.distributedCount': '{{count}} katılımcıya gönderildi',
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
    'clubEvents.certificate.sent': 'Belge {{count}} katılımcıya gönderildi.',
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

    'clubEvents.excel.sheetName': 'Kayıtlı Katılımcılar',
    'clubEvents.excel.reportTitle': 'Etkinlik Raporu',
    'clubEvents.excel.eventName': 'Etkinlik Adı',
    'clubEvents.excel.club': 'Organizatör',
    'clubEvents.excel.studentCount': 'Kayıtlı Katılımcı Sayısı',
    'clubEvents.excel.reportDate': 'Rapor Tarihi',
    'clubEvents.excel.subject': '{{title}} - kayıtlı katılımcılar',
    'clubEvents.excel.preparing': 'Excel dosyası hazırlanıyor...',
    'clubEvents.excel.ready':
        'Katılımcı listesi Excel dosyası olarak hazırlandı.',
    'clubEvents.excel.error':
        'Excel dosyası oluşturulamadı. Lütfen tekrar dene.',

    'clubCreateEvent.create': 'Etkinliği Oluştur',
    // Bölüm kartlarının başlık + açıklama çiftleri: web'deki
    // club-create-event.html hangi kartları hangi sırayla gösteriyorsa
    // mobil de aynısını gösteriyor (language.js ile birebir metin).
    'clubCreateEvent.eyebrow': 'Etkinlik Yönetimi',
    'clubCreateEvent.section.basics': 'Temel Bilgiler',
    'clubCreateEvent.section.basicsDesc':
        'Etkinliğin adı, içeriği ve hedefi.',
    'clubCreateEvent.section.participation': 'Katılım ve Ücret',
    'clubCreateEvent.section.participationDesc':
        'Kontenjan, ücret ve oturum ayarları.',
    'clubCreateEvent.section.schedule': 'Tarih ve Saat',
    'clubCreateEvent.section.scheduleDesc':
        'Etkinlik günü, saat aralığı ve son kayıt tarihi.',
    'clubCreateEvent.section.audience': 'Hedef Kitle',
    'clubCreateEvent.section.audienceDesc':
        'Kimlerin görüp kaydolabileceği.',
    'clubCreateEvent.section.location': 'Etkinlik Konumu',
    'clubCreateEvent.section.locationDesc':
        'QR ile giriş ve yoklamada konum kontrolü için.',
    'clubCreateEvent.section.media': 'Görsel',
    'clubCreateEvent.section.mediaDesc':
        'Etkinliğin kapak görseli.',
    'clubCreateEvent.scope.label': 'Kapsam',
    'clubCreateEvent.scope.departmentOnly': 'Sadece Bölüme Özel',
    'clubCreateEvent.scope.universityAndDepartment':
        'Üniversiteye + Bölüme Özel',
    'clubCreateEvent.target.universityHint':
        'Boş bırakırsan kendi üniversiten seçilir.',
    'clubCreateEvent.target.departmentHint':
        'Boş bırakırsan kendi alanın seçilir.',
    'clubCreateEvent.fee.paid': 'Ücretli',
    'clubCreateEvent.sessions.hint':
        '1 oturum: belgeler etkinlik bitince girişi onaylananlara '
        'kendiliğinden dağıtılır.\n'
        '2 ve üzeri: oturum takibi açılır, belge için gereken katılım '
        'yüzdesini sen belirlersin.',
    'clubCreateEvent.image.pick': 'Cihazdan Seç',
    'notification.openTarget': 'Görüntüle',
    'clubCreateEvent.location.nameHint':
        'Katılımcılar bu adı görür; konum kontrolü haritadaki noktaya göre yapılır.',
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
    'clubCreateEvent.feedback.invalidEventDate': 'Geçerli bir etkinlik tarihi seç.',
    'clubCreateEvent.feedback.deadlineAfterEventDate':
        'Son kayıt tarihi etkinlik tarihinden sonra olamaz.',
    'clubCreateEvent.feedback.invalidTimeRange':
        'Bitiş saati başlangıç saatinden sonra olmalı.',
    'clubCreateEvent.feedback.saving': 'Etkinlik kaydediliyor...',

    // Üretilen sözlükte "Etkinlik Adi" olarak kalmıştı.
    'form.eventTitle': 'Etkinlik Adı',
    'form.sessionCount': 'Oturum Sayısı',
    'form.checkinMode': 'Kapı Girişi / Yoklama Modu',
    'checkinMode.checkin_attendance': 'Kapı Girişi + Yoklama',
    'checkinMode.attendance_only': 'Sadece Yoklama',
    'checkinMode.checkin_only': 'Sadece Kapı Girişi',
    'checkinMode.checkin_attendanceDesc':
        'Katılımcılar kapıda giriş yapar; oturum yoklamalarına yalnızca giriş yapanlar katılabilir.',
    'checkinMode.attendance_onlyDesc':
        'Kapı girişi yok; oturum yoklamaları doğrudan başlar.',
    'checkinMode.checkin_onlyDesc':
        'Oturum yoklaması yok; kapı girişi yeterli.',
    'clubCreateEvent.feedback.sessionCountRequired':
        'Yoklamalı etkinlikte oturum sayısı en az 1 olmalı.',
    'clubCreateEvent.subtitle':
        '',
    'clubCreateEvent.editTitle': 'Etkinliği Düzenle',
    'form.eventDate': 'Etkinlik Tarihi',
    'form.deadline': 'Son Kayıt Tarihi',
    'form.startTime': 'Başlangıç',
    'form.endTime': 'Bitiş',
    'form.afterTimeHint': '{{time}} sonrası',
    'form.eventHours': 'Etkinlik Saati',

    // Üretilen sözlükte Türkçe karakterleri düşmüş örnek metinler
    // ("Ornek: ..."). Bu ekranda ipucu olarak göründükleri için düzeltiliyor.
    'placeholder.eventTitleExample': 'Örn. Yapay Zekâ Kariyer Buluşması',
    'placeholder.eventPurposeExample': 'Bu etkinlikle neyi hedefliyorsun?',
    'placeholder.quotaExample': 'Örn. 120',
    'placeholder.sessionCountExample': 'Örn. 5',
    'placeholder.certificateThresholdExample': 'Örn. 80',
    'clubCreateEvent.feedback.imageTooLargeDetail':
        'Görsel çok büyük ({{size}} KB). En fazla {{limit}} KB olabilir.',
    'form.imageUrl': 'Görsel Adresi',
    'form.locationName': 'Konum Adı',
    'form.locationRadius': 'Giriş Yarıçapı',

    // Çoklu seçim kutuları: kutu tek seçimlik göründüğü sürece kimse ikinci
    // bir seçim eklemeyi denemiyordu.
    'form.multiSelect.addHint': 'Seç ve ekle (birden fazla olabilir)',
    'form.clubFields.hint':
        'Birden fazla alanda çalışıyorsan hepsini ekleyebilirsin.',
    'dashboard.scope.departmentOnly': 'Bölüme Özel',

    'clubDocuments.subtitle':
        'Belgelerin incelenince organizatör panelin açılır.',
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
    'clubScan.notOwner': 'Bu etkinlik sana ait değil.',
    'clubScan.pastEvent':
        'QR okutma yalnızca devam eden/yaklaşan etkinliklerde kullanılabilir.',
    'clubScan.notRegistered': 'Bu katılımcının bu etkinlikte kaydı yok.',
    'clubScan.alreadyCheckedIn': '{{name}} zaten giriş yapmış.',
    'clubScan.sessionNotStarted': 'Önce oturumu başlat.',
    'clubScan.alreadyInSession':
        '{{name}} bu oturumda ({{current}}/{{total}}) zaten giriş yaptı.',
    'clubScan.missingLocation': 'QR kodda konum yok. Katılımcı kodu yenilemeli.',
    'clubScan.tooFar':
        'Katılımcı etkinlik konumunun dışında — {{distance}} uzakta (en fazla {{radius}} m).',
    'clubScan.success': '{{name}} için giriş onaylandı.',
    'clubScan.noDoorCheckin':
        'Bu etkinlikte kapı girişi yok; oturum QR\'ını göster, katılımcılar okutsun.',
    'clubScan.doorClosed':
        'Kapı kapalı. Önce etkinlik ekranından kapı girişini başlat.',
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
        'Organizatör belge yükleme ekranına geri gönderilir. Neyin eksik ya da '
        'hatalı olduğunu yaz — organizatör bu metni görecek.',
    'admin.needsDocuments.placeholder':
        'Örn: Danışman onay belgesi okunmuyor, yeniden yükleyin.',
    'admin.needsDocuments.send': 'Gönder',
    'admin.feedback.documentsRequested':
        'Organizatör belge yükleme aşamasına geri gönderildi.',
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
    'admin.nav.clubs': 'Organizatörler',
    'admin.nav.ban': 'Engelle',
    'admin.action.approve': 'Onayla',
    'admin.action.block': 'Engelle',
    'admin.confirm.approve':
        '{{club}} onaylansın mı? Organizatör panele erişebilir hâle gelecek.',
    'admin.confirm.block':
        '{{club}} engellensin mi? Yüklediği belgeler kalıcı olarak silinir.',
    'admin.documents': 'Belgeler ({{count}})',

    'admin.stats.students': 'Katılımcı',
    'admin.stats.clubs': 'Organizatör',
    'admin.stats.male': 'Erkek',
    'admin.stats.female': 'Kız',
    'admin.stats.byCity': 'Şehirlere Göre Katılımcı',
    'admin.stats.byUniversity': 'Üniversitelere Göre Katılımcı',
    'admin.stats.detail': 'Ayrıntılı Dağılım',
    'admin.stats.noData': 'Gösterilecek veri yok.',
    'admin.stats.cityCounts':
        '{{students}} katılımcı · {{clubs}} organizatör · {{male}}E / {{female}}K',
    'admin.stats.universityCounts':
        '{{students}} öğr. · {{clubs}} organizatör · {{male}}E/{{female}}K',

    // Kulüp listesi (admin_clubs_screen.dart)
    'admin.clubs.title': 'Organizatör Listesi',
    'admin.clubs.searchPlaceholder': 'Organizatör, şehir veya üniversite ara...',
    'admin.clubs.empty': 'Eşleşen organizatör bulunamadı.',
    'admin.clubs.cityCount': '{{count}} organizatör',
    'admin.clubs.unnamed': 'İsimsiz Organizatör',
    'admin.clubs.summaryCounts':
        '{{clubs}} organizatör · {{cities}} şehir · {{universities}} üniversite',
    'admin.clubs.summary': 'Organizatör Özeti',
    'admin.clubs.info': 'Organizatör Bilgileri',
    'admin.clubs.summaryText':
        '{{club}}, {{city}} şehrinde {{university}} bünyesinde açılmış bir '
        'organizatör. Çalışma alanı: {{fields}}. Yönetici kaydındaki durumu: '
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

    'admin.ban.searchPlaceholder': 'Katılımcı, üniversite, şehir ara...',
    'admin.ban.empty': 'Eşleşen katılımcı bulunamadı.',
    'admin.ban.studentCount': '{{count}} katılımcı',
    'admin.ban.banButton': 'Engelle',
    'admin.ban.unbanButton': 'Engeli Kaldır',
    'admin.ban.confirmBan':
        '{{name}} engellensin mi? Oturumu kapatılır ve giriş yapamaz; gelecek '
        'etkinliklerdeki kayıtları silinip yerleri boşalır.',
    'admin.ban.confirmUnban': '{{name}} için engel kaldırılsın mı?',
    'admin.ban.tab.students': 'Katılımcılar',
    'admin.ban.tab.clubs': 'Organizatörler',
    'admin.ban.searchPlaceholderClubs': 'Organizatör, üniversite, şehir ara...',
    'admin.ban.emptyClubs': 'Eşleşen organizatör bulunamadı.',
    'admin.ban.clubCount': '{{count}} organizatör',
    'admin.ban.filter.all': 'Tümü',
    'admin.ban.filter.active': 'Aktif',
    'admin.ban.filter.banned': 'Engelli',
    'admin.ban.bannedLabel': 'Engellendi',
    'admin.ban.confirmClubBan':
        '{{name}} engellensin mi? Organizatör giriş yapamaz; belgeleri silinmez.',
    'admin.ban.confirmClubUnban':
        '{{name}} için engel kaldırılsın mı? Organizatör, belgeleri duruyorsa '
        'inceleme kuyruğuna, durmuyorsa belge yükleme adımına döner.',
    'admin.ban.banSuccess': '{{name}} engellendi.',
    'admin.ban.unbanSuccess': '{{name}} için engel kaldırıldı.',
    'admin.ban.banError': 'Engelleme yapılamadı. Tekrar dene.',
    'admin.ban.unbanError': 'Engel kaldırılamadı. Tekrar dene.',

    // Kulübe yönetici notu (club_message_panel.dart)
    'admin.clubs.ban': 'Organizatörü Engelle',
    'admin.clubs.unban': 'Engeli Kaldır',
    'admin.message.title': 'Organizatöre Mesaj Gönder',
    'admin.message.hint':
        'Eksik belge ya da düzeltilmesi gereken bir durum varsa sebebini '
        'yaz; organizatör bu mesajı onay bekleme ekranında görecek. Başvuru '
        'kuyrukta kalır.',
    'admin.message.placeholder':
        'Örn. Akademik danışman onayı okunmuyor, lütfen yeniden yükleyin.',
    'admin.message.send': 'Mesajı Gönder',
    'admin.message.sent': 'Mesaj organizatöre iletildi.',
    'admin.message.empty': 'Göndermeden önce bir mesaj yaz.',
    'admin.message.error': 'Mesaj gönderilemedi. Tekrar dene.',
    'admin.message.none': 'Bu organizatöre henüz mesaj gönderilmedi.',
    'admin.message.logTitle': 'Gönderilen mesajlar',
    'clubPending.messages.title': 'Yöneticiden Mesaj',
    'clubPending.messages.hint':
        'Yönetici notları aşağıda. Eksik belgeyi yeniden yükleyebilirsin.',

    // Kulüp / yönetici tarafı (bu turda iskelet)
    // Bağlantı durumu
    'offline.banner': 'İnternet bağlantısı yok',
    'offline.bannerDesc':
        'Bağlantı gelince kaldığın yerden devam edersin.',
    'offline.loginBlocked':
        'İnternet bağlantısı yok. Giriş yapabilmek için bağlantını kontrol et.',
    'offline.actionBlocked': 'İnternet bağlantısı yok. Bağlanınca tekrar dene.',
    'offline.restored': 'İnternet bağlantısı geri geldi.',

    // Kulüp logosu (hesap ekranı + etkinlik penceresi rozeti)
    'clubAccount.logo': 'Organizatör Logosu',
    'clubAccount.feedback.logoUpdated': 'Organizatör logosu güncellendi.',
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
        'Başvuru belgelerin. Açmak için dokun.',
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
        'Hesabın 30 gün sonra kalıcı olarak silinir; bu sürede geri alabilirsin.',
    'accountSecurity.phoneReauth.title': 'Telefonunla Doğrula',
    'accountSecurity.phoneReauth.subtitle':
        'Hesabına kayıtlı numaraya bir doğrulama kodu göndereceğiz.',
    'accountSecurity.phoneReauth.confirm': 'Kodu Onayla',
    'accountSecurity.error.noPhone':
        'Hesabında doğrulanmış bir telefon numarası yok.',
    'accountSecurity.error.phoneMismatch': 'Bu numara hesabına ait değil.',
    'accountSecurity.error.wrongPassword': 'Mevcut şifren hatalı.',
    'accountSecurity.error.generic': 'İşlem tamamlanamadı. Tekrar dene.',

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

    'deleteAccount.subtitle':
        'Hesabın 30 gün sonra silinir; bu sürede giriş yaparsan geri alabilirsin.',
    'deleteAccount.warning':
        'Etkinlik kayıtların hemen bırakılır (yerin başkasına açılır). Hesabın, '
        'profilin ve belgelerin 30 gün sonra kalıcı olarak silinir.',
    'deleteAccount.passwordLabel': 'Şifren',
    'deleteAccount.verifyByPhone': 'Telefonumla doğrula',
    'deleteAccount.submit': 'Hesabımı Sil',
    'deleteAccount.feedback.passwordRequired':
        'Hesabını silmek için şifreni gir.',
    'deleteAccount.feedback.verifyFirst': 'Önce telefonunla kimliğini doğrula.',
    'deleteAccount.feedback.phoneVerified':
        'Kimliğin doğrulandı. Hesabını silebilirsin.',
    'deleteAccount.notice.done':
        'Silme talebin alındı. Hesabın 30 gün sonra silinecek; bu sürede '
        'giriş yaparsan geri alabilirsin.',
    'deleteAccount.error.clubHasEvents':
        'Hesabını silmeden önce oluşturduğun etkinlikleri kaldır.',
    'deleteAccount.error.banned':
        'Engellenmiş hesaplar silinemez. Yardım için product@regipass.com '
        'adresine yaz.',
    'deleteAccount.error.failed':
        'Silme talebin kaydedilemedi. İnternet bağlantını kontrol edip tekrar dene.',
    'pendingDeletion.title': 'Hesabın silinmek üzere',
    'pendingDeletion.lead':
        'Hesabını silmek istedin. Hesabın ve tüm verilerin {{date}} tarihinde '
        'kalıcı olarak silinecek.',
    'pendingDeletion.note':
        'Fikrini değiştirdiysen hesabını şimdi geri alabilirsin. Bırakılan '
        'etkinlik kayıtların geri gelmez; istersen yeniden kaydolabilirsin.',
    'pendingDeletion.restore': 'Hesabımı geri al',
    'pendingDeletion.signOut': 'Çıkış yap (silme devam etsin)',
    'pendingDeletion.error':
        'Hesap geri alınamadı. İnternet bağlantını kontrol edip tekrar dene.',
    'pendingDeletion.adminScheduled':
        'Bu hesap Regipass ekibi tarafından silinmek üzere. Yardım için '
        'product@regipass.com adresine yaz.',

    'screen.comingSoon': 'Bu bölüm hazırlanıyor.',
    'screen.comingSoonDesc':
        'Organizatör ve yönetici ekranları bir sonraki aşamada tamamlanacak.',
    // Ücretli etkinlik onay logu — yalnızca ücretli etkinliklerde, etkinlik
    // detayında gösterilir (bkz. domain/paid_event_consent.dart).
    'paidEventConsent.log.title': 'Ücretli Etkinlik Onay Kaydı',
    'paidEventConsent.log.club': 'Organizatör onayı — etkinlik oluşturma',
    'paidEventConsent.log.students': 'Katılımcı kayıt onayları',
    'paidEventConsent.log.missing': 'Onay kaydı bulunmuyor.',
    'paidEventConsent.log.studentsEmpty': 'Henüz onay veren katılımcı yok.',
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
    'gate.unknownStudent': 'Katılımcı',
    'gate.notSentYet': 'gönderilmedi',
    'gate.packInfo': 'Cihazdaki liste: {{n}} bilet · {{time}}',
    'gate.net.online': 'Çevrimiçi',
    'gate.net.offline': 'İnternet yok',
    'gate.net.pending': '{{n}} okuma bekliyor',
    'gate.net.sending': '{{n}} okuma gönderiliyor',
    'gate.result.in': 'GİRİŞ TAMAM',
    'gate.result.already': 'ZATEN GİRDİ',
    'gate.result.invalid-ticket': 'GEÇERSİZ BİLET',
    'gate.result.code-not-found': 'KOD BULUNAMADI',
    'gate.result.code-ambiguous': 'KODU TAM YAZ',
    'gate.hint.code-not-found': 'Bu etkinlikte böyle bir bilet kodu yok; kodu kontrol et.',
    'gate.hint.code-ambiguous': 'Büyük/küçük harfleri bilette göründüğü gibi yaz.',
    'gate.manual.open': 'Kodu elle gir',
    'gate.manual.title': 'Bilet kodunu elle gir',
    'gate.manual.body': 'Kamera okumuyorsa katılımcının biletindeki kodu yaz.',
    'gate.manual.placeholder': 'Bilet kodu',
    'gate.manual.submit': 'Giriş yap',
    'gate.manual.short': 'Kod eksik: biletin altındaki 10 karakteri yaz.',
    'gate.manual.locked': 'Çok fazla yanlış deneme. {{n}} sn sonra yeniden dene.',
    'gate.manual.needEvent': 'Önce etkinliğin bir biletini okut ya da etkinliği açıp oradan gir.',
    'ticket.codeLabel': 'Bilet kodu',
    'gate.result.not-registered': 'KAYITLI DEĞİL',
    'gate.result.other-event': 'BAŞKA ETKİNLİK',
    'gate.result.not-owner': 'BAŞKA ORGANİZATÖRÜN ETKİNLİĞİ',
    'gate.result.no-door': 'KAPI BİLETİ YOK',
    'gate.result.past-event': 'ETKİNLİK GEÇMİŞ',
    'gate.result.not-ticket': 'REGIPASS BİLETİ DEĞİL',
    'gate.result.unknown-event': 'ETKİNLİK BULUNAMADI',
    'gate.hint.in': 'Sıradakini okutabilirsin',
    'gate.hint.legacy': 'Eski uygulama bileti (kodsuz): kimliği kontrol et',
    'gate.hint.already': 'İlk giriş {{time}} · sayı değişmedi',
    'gate.hint.invalid-ticket': 'Bilet kodu eşleşmiyor; katılımcı bileti yeniden açmalı.',
    'gate.hint.not-registered': 'Bu katılımcının etkinliğe kaydı yok',
    'gate.hint.other-event': 'Bu bilet başka bir etkinliğe ait',
    'gate.hint.not-owner': 'Etkinlik bu organizatöre ait değil',
    'gate.hint.no-door': 'Sadece yoklama: oturum QR\'ını göster, katılımcılar okutsun',
    'gate.hint.past-event': 'Etkinliğin günü geçti',
    'gate.hint.not-ticket': 'Katılımcıdan Regipass biletini açmasını iste',
    'gate.hint.unknown-event': 'Etkinlik bulunamadı. İnternet yoksa bu etkinliğin bilet listesi cihaza henüz inmemiş olabilir.',
    'gate.hint.conflict': 'Başka cihazda {{time}} girmişti — ilk okuma geçerli',
    'gate.hint.rejected': 'Sunucu kabul etmedi — bu girişi kontrol et',
    'gate.conflictToast': '{{name}}: başka cihaz daha önce okutmuştu ({{time}}).',
    'gate.cameraHint': 'Bileti kameraya tut.',
    'gate.cameraError': 'Kamera açılamadı. Kamera iznini kontrol et.',
    // İP-K: kayıt, bekleme listesi, ödeme, etkinlik iptali (web language.js ile aynı anahtarlar)
    'gate.hint.event-cancelled': 'Etkinlik iptal edildi, biletler geçersiz',
    'gate.hint.paidAtGate': 'Ödeme kapıda onaylandı, giriş alındı',
    'gate.hint.payment-pending': 'Ödeme onaylanmamış; giriş yapılamaz',
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
    'registration.alerts.fullOfferWaitlist': 'Bu etkinliğin kontenjanı doldu. Bekleme listesine girmek ister misin? Yer açılırsa bildirim alırsın; ilk kaydolan yeri alır.',
    'registration.alerts.leaveWaitlistConfirm': 'Bekleme listesinden çıkmak istediğine emin misin?',
    'registration.alerts.paymentPendingNote': 'Ödemeyi organizatörle konuş. Organizatör onaylayınca kaydın kesinleşir; o zamana kadar kapıdan giriş yapılamaz.',
    'registration.alerts.seatsAvailableNow': 'Bu arada yer açıldı. Hemen kaydolabilirsin.',
    'registration.alerts.waitlistJoined': 'Bekleme listesine eklendin: {{position}}. sıradasın. Yer açılınca bildirim alırsın; ilk kaydolan yeri alır.',
    'registration.club.addSeats': '+{{n}} yer aç',
    'registration.club.addSeatsConfirm': 'Kontenjan {{from}} → {{to}} olacak. Bekleme listesindekilere "yer açıldı" bildirimi gider; ilk kayıt olan alır.',
    'registration.club.cancelEventAction': 'Etkinliği İptal Et',
    'registration.club.cancelEventBody': 'Kayıtlı katılımcılara ve bekleme listesindekilere bildirim gidecek; kayıtlar silinmez, etkinlik "İptal edildi" olarak görünür. Hiç kaydı yoksa etkinlik tamamen silinir.',
    'registration.club.cancelEventTitle': 'Etkinliği iptal et',
    'registration.club.cancelledBanner': 'Bu etkinlik iptal edildi. Kayıtlı katılımcılara bildirim gönderildi.',
    'registration.club.cancelledBannerReason': 'Bu etkinlik iptal edildi. Gerekçe: {{reason}}',
    'registration.club.eventCancelled': 'Etkinlik iptal edildi. {{n}} kişiye bildirim gönderildi.',
    'registration.club.eventDeleted': 'Etkinliğin kaydı yoktu; etkinlik tamamen silindi.',
    'registration.club.markPaid': 'Ödendi olarak işaretle',
    'registration.club.markedPaid': '{{name}}: ödeme onaylandı, katılımcıya bildirim gitti.',
    'registration.club.paid': 'Ödendi',
    'registration.club.paymentTitle': 'Ödeme',
    'registration.club.quotaNow': 'Kontenjan {{n}} oldu.',
    'registration.club.quotaNowOpen': 'Kontenjan {{n}} oldu. Kayıtlar açık.',
    'createEvent.lateRegistration': 'Etkinlik başladıktan sonra da kayıt al',
    'registration.scopeAsk.title': 'Bir bilgi eksik',
    'manualAttendance.title': 'Elle yoklama',
    'program.title': 'Program',
    'program.live': '● Şu an',
    'program.attended': '✓ Katıldın',
    'program.attendedManual': '✓ Katıldın (elle)',
    'program.people': '{{n}} kişi',
    'program.certNeeded':
        'Belge için {{total}} oturumdan en az {{needed}} oturuma katılman gerekiyor · şu an {{done}}',
    'manualAttendance.addConfirm':
        '{{name}} için {{session}} elle "var" olarak işaretlensin mi? Raporda "!" ile ayrı görünür.',
    'manualAttendance.removeConfirm':
        '{{name}} için {{session}} elle konan "var" işareti kaldırılsın mı?',
    'manualAttendance.added': '{{name}}: {{session}} yoklamasına eklendi.',
    'manualAttendance.removed': '{{name}}: {{session}} işareti kaldırıldı.',
    'manualAttendance.already': '{{name}} {{session}} için zaten yoklamada.',
    'manualAttendance.uncertain': 'Bazı oturumlar belirsiz (eski kayıt).',
    'manualAttendance.codeTitle': 'Bilet koduyla yoklama',
    'manualAttendance.codeHint': 'Biletteki kod (ör. K7P2Q X9A1B)',
    'manualAttendance.codeSubmit': 'Yoklamaya ekle',
    'manualAttendance.error.generic': 'Yoklama kaydedilemedi. Tekrar dene.',
    'manualAttendance.error.session-not-started':
        'Bu oturum henüz başlamadı; ancak başlamış oturumlara işaret konabilir.',
    'manualAttendance.error.not-manual':
        'Bu yoklama QR ile alınmış; elle geri alınamaz.',
    'manualAttendance.error.payment-pending':
        'Ödemesi onaylanmamış katılımcıya yoklama yazılmaz.',
    'manualAttendance.error.code-not-found':
        'Bu kodla kayıtlı katılımcı bulunamadı. Kodu kontrol et.',
    'manualAttendance.error.code-ambiguous':
        'Bu kod birden çok kayda uyuyor; tam yazımını dene.',
    'manualAttendance.error.code-short': 'Kod en az 6 karakter olmalı.',
    'manualAttendance.error.not-registered': 'Bu kişinin kaydı bulunamadı.',
    'clubCreateEvent.sessionTime.end-before-start':
        '{{n}}. oturumun bitiş saati başlangıçtan sonra olmalı.',
    'clubCreateEvent.sessionTime.overlap':
        '{{n}}. oturum, {{prev}}. oturum bitmeden başlıyor. Saatleri çakışmayacak şekilde düzelt.',
    'clubCreateEvent.sessionTime.order':
        '{{n}}. oturum, {{prev}}. oturumdan önce başlıyor. Oturumları saat sırasına göre yaz.',
    'clubCreateEvent.sessionTime.before-event':
        '{{n}}. oturum, etkinliğin başlangıç saatinden önce başlıyor.',
    'clubCreateEvent.sessionTime.after-event':
        '{{n}}. oturum, etkinliğin bitiş saatinden sonra bitiyor.',
    'registration.scopeAsk.body':
        'Bu etkinlik belirli üniversite/bölümlere açık. Bilgini seç; hesabına da kaydedilir.',
    'registration.scopeAsk.university': 'Üniversite',
    'registration.scopeAsk.department': 'Bölüm',
    'registration.scopeAsk.save': 'Kaydet ve devam et',
    'createEvent.lateRegistrationHint':
        'Kapı girişi ya da ilk oturum başlayınca kayıtlar kapanmaz; son kayıt tarihine kadar (yer varsa) kayıt sürer ve etkinlik Keşfet\'te kalır. Geç gelenler için son kayıt tarihini etkinlik günü yap.',
    'registration.club.quotaBlocked.event-started':
        'Kontenjan {{n}} oldu, ancak kapı girişi ya da oturum başladığı için yeni kayıt alınmıyor. Geç gelenler de kaydolsun istiyorsan etkinliği düzenleyip "Etkinlik başladıktan sonra da kayıt al"ı aç.',
    'registration.club.quotaBlocked.registration-closed':
        'Kontenjan {{n}} oldu, ancak kayıtları sen durdurmuştun. Yeni kayıt için "Kayıtları Yeniden Başlat"a bas.',
    'registration.club.quotaBlocked.deadline-passed':
        'Kontenjan {{n}} oldu, ancak son kayıt tarihi geçtiği için yeni kayıt alınmıyor. Etkinliği düzenleyip son kayıt tarihini uzatabilirsin.',
    'registration.club.quotaBlocked.event-past':
        'Kontenjan {{n}} oldu, ancak etkinliğin günü geçtiği için yeni kayıt alınmıyor.',
    'registration.club.quotaBlocked.event-hidden':
        'Kontenjan {{n}} oldu, ancak etkinlik yönetici tarafından gizlendiği için yeni kayıt alınmıyor.',
    'registration.club.quotaBlocked.quota-setup':
        'Kontenjan {{n}} oldu; kurulum sürüyor, birkaç saniye sonra kayıtlar açılır.',
    'registration.club.quotaSetupDone': 'Kontenjan kuruldu, kayıtlar açıldı.',
    'registration.club.quotaSetupFailed': 'Kontenjan ayarlanamadı, etkinlik şu an kayda kapalı. Etkinliği düzenleyip yeniden kaydet.',
    'registration.club.quotaSetupStatus': 'Kontenjan Kuruluyor',
    'registration.club.reasonLabel': 'Gerekçe (isteğe bağlı, katılımcılara gösterilir)',
    'registration.club.removeAction': 'Kaydı sil',
    'registration.club.removeBody': '{{name}} adlı katılımcının kaydı silinecek. Katılımcıya bildirim gidecek ve yeri bekleme listesine açılacak.',
    'registration.club.removeReasonHint': 'Örn. Ödeme yapılmadı',
    'registration.club.removeTitle': 'Kaydı sil',
    'registration.club.removed': '{{name}} adlı katılımcının kaydı silindi.',
    'registration.club.unmarkConfirm': '{{name}} için "Ödendi" işaretini geri almak istiyor musun? Katılımcı kapıda giriş yapamaz.',
    'registration.club.unmarkPaid': 'Geri al',
    'registration.club.unmarkedPaid': '{{name}}: ödeme işareti geri alındı.',
    'registration.club.waitlistCount': 'Bekleme listesinde {{count}} kişi var',
    'registration.club.waitlistEmpty': 'Kontenjan doldu. Bekleme listesi henüz boş.',
    'registration.errors.banned': 'Hesabın engellendiği için kayıt yapılamıyor.',
    'registration.errors.below-registered': 'Kontenjan, kayıtlı katılımcı sayısının ({{registered}}) altına indirilemez. Daha yüksek bir kontenjan gir.',
    'registration.errors.busy': 'Şu an yoğunluk var. Birkaç saniye sonra tekrar dene.',
    'registration.errors.cancel-locked': 'Oturumlar başladığı için kaydını artık kendin iptal edemezsin. Gerekirse organizatörle iletişime geç.',
    'registration.errors.club-banned': 'Bu organizatörün etkinliklerine şu anda kayıt alınmıyor.',
    'registration.errors.deadline-passed': 'Son kayıt tarihi geçti.',
    'registration.errors.event-cancelled': 'Bu etkinlik iptal edildi.',
    'registration.errors.event-hidden': 'Bu etkinlik artık yayında değil.',
    'registration.errors.event-not-found': 'Etkinlik bulunamadı.',
    'registration.errors.event-not-paid': 'Bu etkinlik ücretli değil.',
    'registration.errors.event-past': 'Etkinliğin tarihi geçti.',
    'registration.errors.event-started': 'Etkinlik başladı; yeni kayıt alınmıyor.',
    'registration.errors.generic': 'İşlem tamamlanamadı. Tekrar dene.',
    'registration.errors.invalid-quota': 'Geçerli bir kontenjan gir.',
    'registration.errors.not-eligible': 'Bu etkinlik belirli üniversite ya da bölümlere açık; profilin bu şartı karşılamıyor.',
    'registration.errors.not-event-club': 'Bu işlem yalnızca etkinliğin organizatörü tarafından yapılabilir.',
    'registration.errors.not-registered': 'Bu etkinliğe kayıt bulunamadı.',
    'registration.errors.offline': 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.',
    'registration.errors.paid-consent-required': 'Ücretli etkinliğe kaydolmak için ödeme bilgilendirmesini onayla.',
    'registration.errors.payment-pending': 'Ödemen henüz onaylanmadı; organizatör onaylayınca giriş yapabilirsin.',
    'registration.errors.phone-not-verified': 'Kaydolmak için önce telefon numaranı doğrula.',
    'registration.errors.profile-incomplete': 'Kaydolmak için önce katılımcı profilini tamamla.',
    'registration.errors.profile-missing': 'Kaydolmak için önce katılımcı profilini tamamla.',
    'registration.errors.quota-setup': 'Etkinliğin kontenjanı henüz hazır değil. Biraz sonra tekrar dene.',
    'registration.errors.registration-closed': 'Bu etkinliğin kayıtları kapandı.',
    'registration.errors.signIn': 'Oturumun kapanmış. Yeniden giriş yap.',
    'eventModal.contactTitle': 'İletişim Bilgileri',
    'eventModal.feeContactTitle': 'Ücret İçin İletişim Bilgileri',
    'eventModal.feeContactNoteClub': 'Ücret: {{fee}}. Ödeme Regipass dışında doğrudan organizatörle yapılır; katılımcılar ücret için aşağıdaki bilgilerle organizatöre ulaşır. Ödemeyi aldığında katılımcı listesinden "Ödendi" olarak işaretle; kayıt o zaman kesinleşir.',
    'eventModal.feeContactNoteWithFee': 'Ücret: {{fee}}. Ödeme Regipass dışında doğrudan organizatörle yapılır; ücret için aşağıdaki bilgilerden organizatörle iletişime geç. Organizatör ödemeyi aldığını işaretleyince kaydın kesinleşir.',
    'clubCreateEvent.contact.label': 'İletişim bilgisi gösterilsin mi?',
    'clubCreateEvent.contact.labelPaid': 'Ücret için iletişim bilgisi',
    'clubCreateEvent.contact.club': 'Hesabımdaki iletişim bilgileri',
    'clubCreateEvent.contact.custom': 'Yeni bilgi gir',
    'clubCreateEvent.contact.hidden': 'Gösterme',
    'clubCreateEvent.contact.clubPreview': 'Gösterilecek: {{contact}}',
    'clubCreateEvent.contact.clubEmpty': 'Organizatör profilinde iletişim bilgisi yok. Yeni bilgi girebilirsin.',
    'clubCreateEvent.contact.hiddenHint': 'Etkinlik detayında iletişim bilgisi gösterilmez.',
    'clubCreateEvent.contact.phone': 'İletişim telefonu',
    'clubCreateEvent.contact.email': 'İletişim e-postası',
    'clubCreateEvent.contact.customHint': 'En az birini doldur. Bu bilgiler yalnızca bu etkinlikte görünür.',
    'clubCreateEvent.contact.errorEmpty': 'Yeni bilgi seçtin: en az bir telefon ya da e-posta gir.',
    'clubCreateEvent.contact.errorEmail': 'E-posta adresi geçerli görünmüyor.',
    'clubCreateEvent.contact.errorPhone': 'Telefon numarası 11 haneli olmalı (ör. 0555 123 45 67 ya da 0212 123 45 67).',
    'registration.bulk.hint': 'Toplu işlem için katılımcıları seç.',
    'registration.bulk.selected': '{{n}} katılımcı seçildi',
    'registration.bulk.selectAll': 'Tümünü seç',
    'registration.bulk.clear': 'Seçimi temizle',
    'registration.bulk.selectPending': 'Ödeme bekleyenleri seç ({{n}})',
    'registration.bulk.markPaid': 'Toplu ödeme onayı',
    'registration.bulk.markPaidN': '"Ödendi" yap ({{n}})',
    'registration.bulk.markPaidConfirm': '{{n}} katılımcının ödemesi onaylanacak ve her birine bildirim gidecek.',
    'registration.bulk.markedPaid': '{{n}} katılımcının ödemesi onaylandı.',
    'registration.bulk.nonePending': 'Seçilenler arasında ödeme bekleyen yok.',
    'registration.bulk.removeN': 'Kaydı sil ({{n}})',
    'registration.bulk.removeBody': 'Seçilen {{n}} katılımcının kaydı silinecek. Her birine bildirim gidecek ve yerleri bekleme listesine açılacak.',
    'registration.bulk.removed': '{{n}} katılımcının kaydı silindi.',
    'registration.errors.too-many-students': 'Tek seferde en fazla 200 katılımcı seçebilirsin.',
    'registration.labels.cancelled': 'İptal',
    'registration.labels.payment': 'Ödeme',
    'registration.labels.registeredAt': 'Kayıt Tarihi',
    'registration.status.cancelled': 'İptal Edildi',
    'registration.status.cancelledNoReason': 'Organizatör etkinliği iptal etti.',
    'registration.status.fullWaitlist': 'Kontenjan Doldu · Bekleme Listesi',
    'registration.status.paymentConfirmed': 'Ödendi (organizatör onayladı)',
    'registration.status.paymentPending': 'Ödeme Bekleniyor',
    'registration.status.paymentPendingLong': 'Bekleniyor — organizatör ödemeyi onaylayınca kaydın kesinleşir',
    'registration.status.registeredPaymentPending': 'Kayıtlı · Ödeme Bekleniyor',
    'registration.status.waitlisted': 'Bekleme Listesindesin',
    'registration.ticket.paymentPendingHint': 'Ödemen onaylanınca bilet geçerli olur.',
    // İP-EL: etkinlik linki
    'eventLink.share': 'Paylaş',
    'eventLink.shareFailed': 'Link alınamadı. İnternet bağlantını kontrol edip tekrar dene.',
    'eventLink.close': 'Kapat',
    'eventLink.notFound': 'Etkinlik bulunamadı',
    'eventLink.notFoundHint': 'Bu bağlantı geçersiz ya da organizatör tarafından kaldırılmış.',
    'eventLink.toHome': 'Ana sayfaya dön',
    'eventLink.free': 'Ücretsiz',
    'eventLink.paid': 'Ücretli',
    'eventLink.login': 'Giriş yap ve kaydol',
    'eventLink.guest': 'Hesapsız kaydol',
    'eventLink.guestHint': 'Ad, e-posta ve telefon yeter; telefonuna SMS kodu gelir.',
    'eventLink.clubCannot': 'Organizatör hesabıyla etkinliğe kaydolunamaz. Kaydolmak için katılımcı hesabıyla giriş yap.',
    'eventLink.status.full': 'Kontenjan doldu.',
    'eventLink.status.closed': 'Kayıtlar kapandı.',
    'eventLink.status.started': 'Etkinlik başladı; yeni kayıt alınmıyor.',
    'eventLink.status.past': 'Bu etkinlik sona erdi.',
    'eventLink.status.cancelled': 'Bu etkinlik iptal edildi.',
    'eventLink.card.title': 'Etkinlik linki',
    'eventLink.card.hint': 'Bu linki paylaş: açan kişi hesabı olmasa da kaydolabilir.',
    'eventLink.card.hintLinkOnly': 'Bu etkinlik keşfette görünmez; yalnızca bu linki alanlar görür ve kaydolur.',
    'eventLink.card.copy': 'Kopyala',
    'eventLink.card.copied': 'Link kopyalandı.',
    'eventLink.card.poster': 'QR afişi',
    'eventLink.card.stats': '{{views}} ziyaret · linkten {{regs}} kayıt',
    'eventLink.card.slugAdd': 'Özel ad ver (ör. /e/bahar-konseri)',
    'eventLink.card.slugEdit': 'Özel adı değiştir',
    'eventLink.card.slugLabel': 'Özel ad',
    'eventLink.card.slugHint': 'Küçük harf, rakam ve tire; 3–40 karakter. Boş bırakırsan kaldırılır.',
    'eventLink.card.slugSave': 'Kaydet',
    'eventLink.card.slugSaved': 'Link güncellendi.',
    'eventLink.card.renew': 'Linki yenile (eskisini iptal et)',
    'eventLink.card.renewConfirm':
        'Şu anki link (özel adı dahil) hemen geçersiz olur; açan kişi "bağlantı geçersiz" görür. Yeni bir link verilir. Mevcut kayıtlar ve biletler etkilenmez; basılmış QR afişleri çalışmaz.',
    'eventLink.card.renewDo': 'Yenile',
    'eventLink.card.renewed': 'Yeni link oluşturuldu; eski link artık çalışmıyor.',
    'eventLink.card.cancel': 'Vazgeç',
    'eventLink.card.failed': 'Link bilgisi alınamadı.',
    'eventLink.card.retry': 'Tekrar dene',
    'eventLink.reason.slug-taken': 'Bu ad kullanılıyor; başka bir ad dene.',
    'eventLink.reason.slug-invalid': 'Yalnızca küçük harf, rakam ve tire kullan (3–40 karakter).',
    'eventLink.create.linkOnly': 'Yalnızca linki olanlar görsün',
    'eventLink.create.linkOnlyHint': 'Etkinlik keşfette ve listelerde görünmez; linki paylaştığın kişiler kaydolur.',
    // İP-ŞK: etkinlik şikâyeti + organizatör engelleme
    'complaint.report': 'Şikâyet et',
    'complaint.title': 'Etkinliği şikâyet et',
    'complaint.help': 'Bu etkinlikte bir sorun mu var? Sebebini seç; 24 saat içinde inceleriz. Organizatör kimin şikâyet ettiğini göremez.',
    'complaint.reason.inappropriate': 'Uygunsuz ya da rahatsız edici içerik',
    'complaint.reason.fake': 'Sahte / gerçek olmayan etkinlik',
    'complaint.reason.fraud': 'Dolandırıcılık şüphesi',
    'complaint.reason.spam': 'Spam ya da yanıltıcı',
    'complaint.reason.other': 'Diğer',
    'complaint.noteHint': 'Eklemek istediğin bir şey var mı? (isteğe bağlı)',
    'complaint.noteRequiredHint': 'Sorunu kısaca yaz',
    'complaint.send': 'Gönder',
    'complaint.sending': 'Gönderiliyor…',
    'complaint.sent': 'Şikâyetin bize ulaştı. Teşekkürler.',
    'complaint.block.button': 'Organizatörü engelle',
    'complaint.block.title': 'Organizatörü engelle',
    'complaint.block.confirm': '{{name}} engellensin mi? Etkinliklerini artık görmezsin ve takibin bırakılır. Hesabım sayfasından engeli kaldırabilirsin.',
    'complaint.block.action': 'Engelle',
    'complaint.block.done': '{{name}} engellendi. Etkinlikleri artık gösterilmeyecek.',
    'complaint.blocked.title': 'Engellediğim organizatörler',
    'complaint.blocked.help': 'Engellediğin organizatörlerin etkinlikleri sana gösterilmez.',
    'complaint.blocked.unblock': 'Engeli kaldır',
    'complaint.blocked.unblocked': '{{name}} engeli kaldırıldı.',
    'complaint.error.signIn': 'Bunun için giriş yapmalısın.',
    'complaint.error.studentOnly': 'Organizatörleri yalnızca katılımcı hesapları engelleyebilir.',
    'complaint.error.ownEvent': 'Kendi etkinliğini şikâyet edemezsin.',
    'complaint.error.notFound': 'Bu etkinlik artık yayında değil.',
    'complaint.error.noteRequired': 'Lütfen sorunu kısaca yaz.',
    'complaint.error.tooManyBlocks': 'En fazla 300 organizatör engelleyebilirsin.',
    'complaint.error.generic': 'İşlem yapılamadı. İnternetini kontrol edip tekrar dene.',
  },
  'en': <String, String>{
    // İP-P (1.0.13): mobile-only package line texts
    'plan.mobile.companyWeb':
        'Company accounts create events on regipass.com by choosing an event package. You can manage the event here.',
    // İP-8 / İP-9: yeni sertifika sistemi (web language.js ile aynı metinler)
    'cert.panel.title': 'Certificate of Attendance',
    'cert.editor.sampleName': 'First Last',
    'cert.gate.open': 'You can send to everyone who qualifies and has no certificate yet.',
    'cert.list.open': 'Open',
    'cert.list.title': 'List',
    'cert.mobile.editOnWeb': 'Use the regipass.com website to edit the certificate.',
    'cert.mobile.preview': 'View sample certificate',
    'cert.mobile.send': 'Send',
    'cert.mobile.webOnly': 'No certificate is set up for this event yet. Use the regipass.com website to upload and edit the sample certificate.',
    'cert.panel.allSent': 'Sent to everyone',
    'cert.panel.loading': 'Loading certificate details…',
    'cert.panel.outdated': 'The template changed after sending. {{n}} certificates are on the old version.',
    'cert.panel.reissue': 'Resend the current version',
    'cert.panel.revokeAll': 'Revoke all',
    'cert.panel.revoking': 'Revoking…',
    'cert.panel.sendN': 'Send to {{n}} people',
    'cert.panel.sendNew': 'Send to {{n}} new people',
    'cert.panel.sending': 'Sending… {{done}}/{{total}}',
    'cert.reason.already-running': 'A send or revoke is already running for this event. Try again when it finishes.',
    'cert.reason.bad-color': 'Invalid color code.',
    'cert.reason.bad-font': 'Invalid typeface.',
    'cert.reason.bad-page': 'A field is on a page that does not exist.',
    'cert.reason.bad-size': 'Size must be between 6 and 96.',
    'cert.reason.bad-threshold': 'Threshold must be between 0 and 100.',
    'cert.reason.box-outside-page': 'A field extends outside the page; drag it back inside.',
    'cert.reason.box-too-small': 'A field is too small; make the box a bit larger.',
    'cert.reason.certificate-not-found': 'Certificate not found.',
    'cert.reason.certificate-not-issued': 'This certificate has not been sent yet.',
    'cert.reason.certificate-revoked': 'This certificate was revoked.',
    'cert.reason.checkin-not-started': 'Sending is locked: start door check-in first, then press “Finish Check-in” when the event ends.',
    'cert.reason.checkin-open': 'Sending is locked: door check-in is still open. It unlocks when you press “Finish Check-in”.',
    'cert.reason.club-banned': 'Your organizer account is blocked, so this action is not available.',
    'cert.reason.code-collision': 'Could not create a certificate code. Try again.',
    'cert.reason.config-not-saved': 'Set up and save the certificate in the editor first.',
    'cert.reason.empty-text': 'A free text field cannot be empty.',
    'cert.reason.event-cancelled': 'The event was cancelled, certificates cannot be sent.',
    'cert.reason.event-missing': 'Event not found.',
    'cert.reason.event-not-found': 'Event not found.',
    'cert.reason.generic': 'Could not complete. Check your connection and try again.',
    'cert.reason.missing-student-name': 'The “Participant name” field must be on the page.',
    'cert.reason.name-missing': 'no name in profile',
    'cert.reason.not-allowed': 'You cannot open this certificate.',
    'cert.reason.not-event-club': 'This event does not belong to your team.',
    'cert.reason.render-failed': 'could not be generated',
    'cert.reason.sessions-not-finished': 'Send is locked: press “Finish sessions” on the event screen first.',
    'cert.reason.student-name-missing': 'no name in profile',
    'cert.reason.template-empty': 'The PDF has no pages.',
    'cert.reason.template-encrypted': 'This PDF is encrypted. Upload an unencrypted copy.',
    'cert.reason.template-missing': 'Template not found. Upload the sample certificate again.',
    'cert.reason.template-too-large': 'The file is too large (max 10 MB).',
    'cert.reason.template-unreadable': 'This PDF could not be read. Export it again from another program and retry.',
    'cert.reason.template-unsupported': 'This file type is not supported. Upload a PDF, PNG or JPG.',
    'cert.reason.too-many-fields': 'At most 20 fields can be added.',
    'cert.revoke.text': 'They disappear from participants\' screens and the verification page shows them as “Revoked”. You can send again later; new certificates get new codes.',
    'cert.revoke.title': 'Revoke every certificate of this event?',
    'cert.revoke.yes': 'Yes, revoke all',
    'cert.stat.eligible': 'Qualified',
    'cert.stat.pending': 'Pending',
    'cert.stat.revoked': 'Revoked',
    'cert.stat.sent': 'Sent',
    'cert.status.failed': 'Failed',
    'cert.status.revoked': 'Revoked',
    'cert.status.sent': 'Sent',
    'cert.threshold.none': 'No threshold (at least 1 session) → {{n}} people qualify',
    'cert.threshold.result': '{{p}}% → {{n}} people qualify',
    'cert.threshold.save': 'Save threshold',
    'cert.threshold.saved': 'Threshold saved.',
    'cert.threshold.title': 'Attendance threshold',
    'cert.toast.revoked': '{{n}} certificates revoked.',
    'cert.toast.sent': '{{sent}} certificates sent.',
    'cert.toast.sentWithErrors': '{{sent}} certificates sent, {{failed}} failed. See the list.',
    'studentCertificates.copied': 'Verification link copied.',
    'studentCertificates.fallbackTitle': 'Certificate of attendance',
    'studentCertificates.fullNameOff': 'Your name is shortened again on the verification page.',
    'studentCertificates.fullNameOn': 'Your full name is now shown on the verification page.',
    'studentCertificates.menu.copyLink': 'Copy verification link',
    'studentCertificates.menu.fullName': 'Show my full name on the verification page',
    'studentCertificates.menu.linkedin': 'Add to LinkedIn profile',
    'studentCertificates.menuLabel': 'Certificate options',
    'studentCertificates.revoked': 'Revoked by the organizer',
    // İP-W: cüzdan
    'wallet.addApple': 'Add to Apple Wallet',
    'wallet.addGoogle': 'Add to Google Wallet',
    'wallet.preparing': 'Preparing...',
    'wallet.error.disabled': 'Adding to wallet isn\'t available right now.',
    'wallet.error.paymentPending': 'You can add the ticket once your payment is confirmed.',
    'wallet.error.cancelled': 'Tickets for cancelled events can\'t be added.',
    'wallet.error.past': 'Tickets for past events can\'t be added.',
    'wallet.error.generic': 'Couldn\'t prepare the ticket. Check your connection and try again.',
    // İP-R: rapor
    'report.title': 'Event Report',
    'report.button': 'Download report',
    'report.pdf': 'PDF',
    'report.excel': 'Excel',
    'report.help': 'Attendance, sessions and feedback summary. The attendee list is only in Excel.',
    'report.preparing': 'Preparing report...',
    'report.done': 'Report downloaded.',
    'report.error': 'Couldn\'t prepare the report. Check your connection and try again.',
    // İP-D: değerlendirme
    'feedback.locale': 'en-GB',
    'feedback.decimal': '.',
    'feedback.title': 'Rate this event',
    'feedback.titleRated': 'Your rating',
    'feedback.help': 'How was the event? Give it stars and add a short comment if you like.',
    'feedback.ratingAria': 'Rating (1–5 stars)',
    'feedback.starsAria': '{{n}} stars',
    'feedback.ratingLabel.1': 'Didn\'t like it at all',
    'feedback.ratingLabel.2': 'Didn\'t like it',
    'feedback.ratingLabel.3': 'It was okay',
    'feedback.ratingLabel.4': 'Liked it',
    'feedback.ratingLabel.5': 'Loved it',
    'feedback.commentLabel': 'Comment (optional)',
    'feedback.commentPlaceholder': 'What did you like, what could be better?',
    'feedback.submit': 'Send',
    'feedback.update': 'Update',
    'feedback.sending': 'Sending...',
    'feedback.edit': 'Edit rating',
    'feedback.editUntil': 'You can edit it until {{date}}.',
    'feedback.thanks': 'Thanks! Your rating was sent to the organizer anonymously.',
    'feedback.anonymousNote': 'The organizer doesn\'t see your name; ratings are anonymous.',
    'feedback.cardRate': 'Rate',
    'feedback.error.notCheckedIn': 'Only attendees who checked in can rate this event.',
    'feedback.error.notFinished': 'You can rate the event once it\'s over.',
    'feedback.error.closed': 'The rating period (14 days) has ended.',
    'feedback.error.cancelled': 'Cancelled events can\'t be rated.',
    'feedback.error.badRating': 'Pick 1 to 5 stars.',
    'feedback.error.banned': 'Your account is suspended, so you can\'t rate events.',
    'feedback.error.notOwner': 'Only the organizing organizer can see this event\'s ratings.',
    'feedback.error.generic': 'Couldn\'t send. Check your connection and try again.',
    'feedback.club.title': 'Ratings',
    'feedback.club.empty': 'No feedback yet. Attendees are asked after the event.',
    'feedback.club.count': '{{n}} ratings',
    'feedback.club.comments': 'Comments',
    'feedback.club.commentsHidden': 'Comments appear once there are at least {{n}} ratings (so no one can guess who wrote them).',
    'feedback.club.anonymous': 'Ratings are anonymous; who gave which rating is never shown.',
    'feedback.club.loadError': 'Couldn\'t load ratings. Close and reopen the window.',
    // İP-TK: kulüp takip
    'follow.follow': 'Follow',
    'follow.following': 'Following',
    'follow.unfollow': 'Unfollow',
    'follow.followHint': 'Get notified when the organizer posts a new event',
    'follow.unfollowHint': 'Tap to unfollow',
    'follow.toastFollowed': 'You\'re following this organizer. We\'ll tell you about new events.',
    'follow.toastUnfollowed': 'You unfollowed the organizer.',
    'follow.filterAria': 'Event filter',
    'follow.filterAll': 'All',
    'follow.filterFollowing': 'Following',
    'follow.empty.title': 'No open events from organizers you follow',
    'follow.empty.desc': 'Tap "Follow" next to an organizer on any event.',
    'follow.account.title': 'Organizers I follow',
    'follow.account.help': 'You get notified when organizers you follow post events. Organizers can\'t see who follows them.',
    'follow.account.empty': 'You\'re not following any organizers yet.',
    'follow.account.unavailable': 'This organizer isn\'t posting events right now.',
    'follow.account.confirmUnfollow': 'Unfollow {{name}}? You won\'t be notified about its new events.',
    'follow.account.unfollowed': 'You unfollowed {{name}}.',
    'follow.club.followers': 'followers',
    'follow.error.clubUnavailable': 'This organizer can\'t be followed right now.',
    'follow.error.tooMany': 'You can follow up to 300 organizers. Unfollow one first.',
    'follow.error.banned': 'Your account is suspended, so you can\'t follow organizers.',
    'follow.error.studentOnly': 'Only participant accounts can follow organizers.',
    'follow.error.signIn': 'Sign in to follow organizers.',
    'follow.error.generic': 'Something went wrong. Check your connection and try again.',
    // İP-B: event notifications
    'autoNotify.title': 'Automatic notifications',
    'profileChange.pendingTitle': 'Your changes are waiting for approval',
    'profileChange.pendingHelp': 'Until approved, participants and your events show the current details; your account keeps working.',
    'profileChange.rejectedTitle': 'Your last change was not approved',
    'profileChange.rejectedNote': 'Reason: {{note}}',
    'profileChange.withdraw': 'Withdraw request',
    'profileChange.withdrawConfirm': 'Withdraw the pending change?',
    'profileChange.sent': 'Your changes were sent for approval. Once approved they apply to your events too.',
    'profileChange.logoSent': 'Your new logo was sent for approval. The current logo stays until then.',
    'profileChange.field.clubName': 'Organizer name',
    'profileChange.field.university': 'University',
    'profileChange.field.city': 'City',
    'profileChange.field.clubPurpose': 'Purpose',
    'profileChange.field.clubContents': 'Contents',
    'profileChange.field.clubFields': 'Fields',
    'profileChange.field.logoUrl': 'Logo',
    'autoNotify.needStart': 'Start time required',
    'autoNotify.needEnd': 'End time required',
    'autoNotify.warnStart': 'Without a start time, the “1 hour before” and “At start” notifications are not sent.',
    'autoNotify.warnEnd': 'Without an end time, the “Thank you” notification is not sent.',
    'autoNotify.warnBoth': 'Without start and end times, the “1 hour before”, “At start” and “Thank you” notifications are not sent.',
    'autoNotify.help':
        'Regipass notifies registered participants automatically. Without a start '
        'time only the "1 day before" reminder is sent.',
    'autoNotify.dayBefore': 'Reminder 1 day before (19:00)',
    'autoNotify.hourBefore': '1 hour before it starts',
    'autoNotify.atStart': 'When it starts (to those not checked in)',
    'autoNotify.afterEnd': 'Thank-you after it ends (to attendees)',
    'eventNotify.title': 'Notifications',
    'eventNotify.status.planned': 'Scheduled',
    'eventNotify.status.noTime': 'No time set',
    'eventNotify.autoHelpEditable':
        'Automatic notifications: turn the ones not sent yet on or off here.',
    'eventNotify.openPage': 'Send and manage notifications',
    'eventNotify.toggleError': 'Could not save. Try again.',
    'clubNotify.title': 'Notifications',
    'clubNotify.subtitle':
        'Automatic notifications and messages.',
    'clubNotify.tab.upcoming': 'Upcoming',
    'clubNotify.tab.active': 'Live',
    'clubNotify.tab.recent': 'Ended',
    'clubNotify.search': 'Search events',
    'clubNotify.empty.upcoming': 'No upcoming events.',
    'clubNotify.empty.active': 'No live events right now.',
    'clubNotify.empty.recent': 'No events ended in the last 7 days.',
    'clubNotify.windowNote': 'You can message attendees for 7 days after an event ends.',
    'clubNotify.all': 'All sends',
    'clubNotify.allEmpty': 'Nothing sent yet.',
    'clubNotify.filter.all': 'All',
    'clubNotify.filter.manual': 'Manual',
    'clubNotify.filter.auto': 'Automatic',
    'clubNotify.cancelled': 'Cancelled',
    'clubNotify.notFound': 'Event not found.',
    'clubNotify.entryOpen': 'Check-in opened',
    'clubNotify.sessionStarted': 'Session {{n}} started',
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
        '{organizatör}.',
    'eventNotify.errors.fill': 'Fill in the … placeholder in the template.',
    'eventNotify.audience.payment_pending': 'Payment pending',
    'eventNotify.templateLabel': 'Template',
    'eventNotify.templateNone': 'Blank message',
    'eventNotify.tagsLabel': 'Insert smart tag',
    'eventNotify.previewLabel': 'Preview (sample participant)',
    'eventNotify.quota': 'Left today: {{left}}/{{limit}}',
    'eventNotify.nextIn': 'next send in {{minutes}} min',
    'eventNotify.tag.ad': 'Participant first name',
    'eventNotify.tag.etkinlik': 'Event name',
    'eventNotify.tag.tarih': 'Date',
    'eventNotify.tag.saat': 'Time',
    'eventNotify.tag.yer': 'Place',
    'eventNotify.tag.kulup': 'Organizer name',
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
        'Your organizer must be approved to send messages.',
    'eventNotify.errors.club-banned': 'Your organizer account is suspended.',
    'eventNotify.errors.not-event-club': 'This event is not yours.',
    // İP-T: add to calendar
    'calendar.add': 'Add to calendar',
    'postRegistration.title': 'You are registered',
    'postRegistration.calendarAsk': 'Add it to your calendar?',
    'postRegistration.calendarApp': 'Calendar app',
    'postRegistration.ticketTitle': 'Save your ticket to your phone',
    'postRegistration.ticketSave': 'Save ticket as image',
    'postRegistration.ticketHint':
        'Works offline; you can always find it in My Tickets.',
    'postRegistration.ticketPreparing': 'Preparing your ticket…',
    'postRegistration.ticketReady': 'Ticket ready; save it from the share menu.',
    'postRegistration.ticketError': 'Could not create the ticket image. Show it from My Ticket instead.',
    'postRegistration.skip': "Don't ask again",
    'postRegistration.done': 'Done',
    'calendar.google': 'Google Calendar',
    'calendar.ics': 'Calendar file (.ics)',
    'calendar.icsHint': 'Apple Calendar, Outlook and others',
    // İP-KB: club's student block
    'clubBlock.title': 'Block from organizer',
    'clubBlock.action': 'Block from organizer',
    'clubBlock.body':
        '{{name}} will be blocked from your events: they cannot '
        'register for new events or join waitlists.',
    'clubBlock.reasonLabel': 'Reason',
    'clubBlock.reasonHelper':
        'Required. Not shown to the participant; kept for your team and '
        'Regipass staff.',
    'clubBlock.reasonRequired': 'Enter a reason of at least 3 characters.',
    'clubBlock.removeFuture':
        'Also remove their registrations for upcoming events (they get a '
        '"registration cancelled" notice)',
    'clubBlock.done':
        '{{name}} is blocked from your events. Upcoming registrations '
        'removed: {{count}}.',
    'clubBlock.listTitle': 'Blocked participants',
    'clubBlock.listHelp':
        'These participants can\'t register for your team\'s events.',
    'clubBlock.empty': 'You have not blocked anyone.',
    'clubBlock.unblock': 'Unblock',
    'clubBlock.unblockConfirm':
        'Unblock {{name}}? They will be able to register for your events again.',
    'clubBlock.unblocked': '{{name}} was unblocked.',
    'clubBlock.studentFallback': 'Participant',
    'clubBlock.error': 'Could not complete. Try again.',
    'clubBlock.errors.reason-required':
        'Enter a reason of at least 3 characters.',
    'clubBlock.errors.student-not-related':
        'You can only block participants who registered for your events.',
    'clubBlock.errors.club-not-approved':
        'Your organizer must be approved to block participants.',
    'clubBlock.errors.club-banned': 'Your organizer account is suspended.',
    'clubBlock.errors.not-a-club': 'Only organizer accounts can do this.',
    'clubBlock.errors.invalid-student': 'Student not found.',
    'registration.errors.blocked-by-club':
        'You can\'t register for this organizer\'s events.',
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
        '{{events}} upcoming events of this organizer will be CANCELLED; '
        '{{people}} registered people will be notified. The club account will '
        'not be able to sign in.',
    'admin.ban.reasonLabel': 'Reason',
    'admin.ban.reasonHelper':
        'Required. Saved to the audit log; not shown to participants.',
    'admin.ban.reasonRequired': 'Enter a reason to block.',
    'auth.error.roleAlreadyExists':
        'This account type already exists. Please sign in.',
    'auth.error.emailRegisteredWrongPassword':
        'This email is registered, but the password is wrong.',
    'auth.feedback.ageRequired': 'To sign up, confirm that you are over 18.',
    'auth.feedback.termsRequired':
        'To continue, you must approve the User and Organizer Agreement and the '
        'Data Protection Notice.',
    'legal.consent.summaryTitle': 'Documents you approved',
    'legal.consent.acceptedAt': 'Consent time',
    'legal.consent.tileLabel': 'Terms and privacy consent',
    'legal.consent.notRecorded': 'Not recorded',
    'legal.consent.acceptedNoTime': 'Accepted (time not recorded)',
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
        'This phone is shared by the participant and organizer accounts linked to the same email and is already verified. It cannot be changed here.',
    'auth.error.networkFailed': 'No connection. Check your internet.',
    'explore.guestTitle': "You're browsing as a guest",
    'explore.guestDesc':
        'Sign in to register and get tickets.',
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
    'admin.notify.audience.students': 'Participants',
    'admin.notify.audience.clubs': 'Organizers',
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
    'clubAccount.section.club': 'Organizer Details',

    'studentAppointments.title': 'My Events',
    'studentAppointments.activeTitle': 'Upcoming',
    'studentAppointments.pastTitle': 'Past',

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
    'eventModal.club': 'Organizer',
    'eventModal.eventDate': 'Event Date',
    'eventModal.deadline': 'Deadline',
    'eventModal.fee': 'Fee',
    'eventModal.free': 'Free',
    'eventModal.quota': 'Capacity',
    'eventModal.unlimited': 'Unlimited',
    'eventModal.location': 'Location',
    'eventModal.sessions': 'Sessions',
    'eventModal.sessionsValue': '{{count}} sessions',
    'eventModal.clubContact': 'Organizer Contact',
    'eventModal.feeContactNote':
        'This event has a fee. Contact the organizer by phone for the fee and '
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
        'The session has not started yet. Scan the QR again once the organizer starts it.',
    'attendance.error.banned': 'Your account is restricted, so you cannot check in.',
    'attendance.qrKeyError':
        'Could not create the QR. Check your internet connection and try again.',
    'attendance.entryRotatingHint':
        'Participants scan this code with their own phones. It refreshes in {{seconds}} s.',
    'clubScan.ticketMismatch':
        'The ticket code does not match the registration (old or forged ticket). Ask the participant to reopen the ticket in the app.',
    'clubScan.ticketLegacy':
        'Old app ticket (no code) — check their ID.',
    'common.loading': 'Loading...',
    'common.logout': 'Log out',
    'common.select': 'Select',
    'common.search': 'Search...',
    'common.done': 'Done',

    'scan.permissionDenied': 'Camera access is off. Turn it on in Settings.',
    'scan.pointCamera': 'Point the camera at the QR code.',
    'scan.ready': 'Ready for the next participant.',
    'scan.successTitle': 'Check-in Successful',
    'scan.failTitle': 'Check-in Failed',
    'scan.notRegipassQr': 'This is not a Regipass check-in code.',
    'scan.missingEventInfo': 'The QR code is incomplete or damaged.',
    'scan.notSessionQr': 'This is not a session check-in code.',
    'clubScan.needsDoorCheckin':
        '{{name}} hasn\'t checked in at the door yet; door check-in is required first.',
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
        'This check-in could not be saved. Tell the organizer staff.',
    'scan.sessionSuccess':
        'You are in session {{current}} (attendance {{attended}}/{{total}}).',
    'scan.otherEventQr':
        'This QR belongs to another event. Scan the session QR of the event you joined.',

    'studentAppointments.modal.showTicket': 'Show My Ticket',
    'studentAppointments.modal.scanQr': 'Scan Session QR',
    'studentAppointments.modal.scanReady':
        'Session {{current}} is open. Scan the QR on the organizer\'s screen to check in.',
    'studentAppointments.modal.scanNotStarted':
        'The organizer has not started the first session yet. This button turns on when a session opens.',
    'studentAppointments.modal.scanAlreadyDone':
        'You are checked in for session {{current}}. The button turns on again when the organizer opens the next session.',
    'studentAppointments.modal.scanCompleted':
        'All sessions for this event are completed; there is no new QR to scan.',
    'studentAppointments.modal.scanUnavailable':
        'The event was removed, so session check-in is not possible.',

    'location.permissionDenied':
        'Location access is off. Turn it on to check in.',
    'location.gettingLocation': 'Getting location...',

    // Account screen phone field + verification pop-up
    'account.phoneChangeHint':
        'You\'ll need to verify the new number by SMS.',
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
        'We\'ll send a 6-digit code to this number.',

    'club.nav.myEvents': 'My Events',
    'club.nav.newEvent': 'New Event',
    'clubSessionQr.subtitle': 'Session-based events',
    'clubSessionQr.empty':
        'No multi-session events. Session QR is only for events with more than one session.',
    'clubSessionQr.manage': 'Manage Event',
    'clubSessionQr.hint':
        'Tap an event to open its session QR.',
    'clubDashboard.empty':
        'No events right now.',

    'clubEvents.title': 'Event',
    'clubEvents.edit': 'Edit',
    'clubEvents.status.closed': 'Registration Closed',
    'clubEvents.group.active': 'Active',
    'clubEvents.group.upcoming': 'Upcoming',
    'clubEvents.group.past': 'Past',
    'clubEvents.empty.active':
        'No active events. Create one with +.',
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
        'The past event will only be removed from your own list; participant records are unaffected.',

    'clubEvents.registrations.title': 'Registrations',
    'clubEvents.qr.locationRequired':
        'Edit the event and select its location on the map before creating a QR code. Participants will be checked against this location.',
    'clubEvents.quota.title': 'Capacity',
    'clubEvents.quota.remaining': '{{count}} spots left.',
    'clubEvents.quota.full': 'Capacity is full.',
    'clubEvents.quota.autoPaused':
        'Registrations are on hold because capacity is full. Raise the capacity and they reopen automatically.',
    'clubEvents.registrations.subtitle':
        'If you pause registrations, no new sign-ups are accepted.',
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
    'form.sessionNames': 'Session names and times (optional)',
    'form.sessionStart': 'Start',
    'form.sessionEnd': 'End',
    'placeholder.sessionNameN': 'Name of session {{n}}',
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
        'Session {{session}} started. Participants can scan the QR for it.',
    'clubEvents.session.finished':
        'All sessions completed. You can now send certificates to participants.',
    'clubEvents.session.qrTitle': 'Session {{session}} QR',
    'clubEvents.session.qrRotatingHint':
        'Participants scan this QR with their phone camera. The code refreshes in {{seconds}} s.',
    'clubEvents.session.qrHint':
        'Project this code; participants scan it from their own phones.',
    'clubEvents.session.qrError': 'The QR image could not be loaded.',
    'clubEvents.entry.stateNotStarted': 'Check-in not started',
    'clubEvents.entry.stateRunning': 'Check-in open',
    'clubEvents.entry.stateFinished': 'Check-in finished',
    'clubEvents.entry.tally': ' — {{attended}}/{{total}} participants checked in',
    'clubEvents.entry.start': 'Start Check-in',
    'clubEvents.entry.finish': 'Finish Check-in',
    'clubEvents.entry.restart': 'Restart Check-in',
    'clubEvents.entry.title': 'Door Entry',
    'clubEvents.entry.subtitle':
        'Participants scan this QR with their own phones.',
    'clubEvents.entry.open': 'Open Door QR',
    'clubEvents.entry.show': 'Show Entry QR',
    'clubEvents.entry.close': 'Close Door',
    'clubEvents.entry.qrTitle': 'Door Check-in QR',
    'clubEvents.entry.qrHint':
        'Participants scan this QR with their own phones.',
    'clubEvents.session.allowWithoutCheckin':
        'Let participants without check-in join attendance',
    'clubEvents.session.allowWithoutCheckinHint':
        'Participants who missed door entry can scan the session QR directly.',

    'clubEvents.scan.action': 'Scan Participant QR',
    'clubEvents.scan.subtitle':
        'Scan the check-in code generated on the participant\'s phone.',

    'clubEvents.certificate.title': 'Certificate',
    'clubEvents.certificate.action': 'Upload and Distribute',
    'clubEvents.certificate.subtitle':
        'The certificate is sent to participants who meet the attendance requirement.',
    'clubEvents.certificate.beforeFinish':
        'You can send before the sessions end; recipients are decided from the '
        'attendance counts at that moment.',
    'clubEvents.certificate.storedOnly':
        'The document was uploaded. No participant is eligible yet, so it has not '
        'been sent to anyone; it is distributed automatically once recipients '
        'are known. To send it right away, use the send button on the '
        'document.',
    'clubEvents.certificate.uploading': 'Uploading the document...',
    'clubEvents.certificate.autoSent':
        'The event has ended, so the document was sent automatically to '
        '{{count}} students.',
    'clubEvents.certificate.partial':
        'Sent to {{count}} participants; {{failed}} did not receive it. You can '
        'try again.',
    'clubEvents.certificate.redistribute': 'Distribute this document',
    'clubEvents.certificate.distributedCount': 'Sent to {{count}} participants',
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
    'clubEvents.certificate.sent': 'Certificate sent to {{count}} participants.',
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
        'This list is the organizer\'s own archive; participants see the document you '
        'distributed most recently.',
    'clubEvents.certificate.delete': 'Delete document',
    'clubEvents.certificate.deleteTitle': 'Delete document',
    'clubEvents.certificate.deleteConfirm':
        'Remove this document from the list? Copies already sent to participants '
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

    'clubEvents.excel.sheetName': 'Registered Participants',
    'clubEvents.excel.reportTitle': 'Event Report',
    'clubEvents.excel.eventName': 'Event Name',
    'clubEvents.excel.club': 'Organizer',
    'clubEvents.excel.studentCount': 'Registered Participants',
    'clubEvents.excel.reportDate': 'Report Date',
    'clubEvents.excel.subject': '{{title}} - registered participants',
    'clubEvents.excel.preparing': 'Preparing the Excel file...',
    'clubEvents.excel.ready': 'The participant list is ready as an Excel file.',
    'clubEvents.excel.error':
        'The Excel file could not be created. Please try again.',

    'clubCreateEvent.create': 'Create Event',
    'clubCreateEvent.eyebrow': 'Event Management',
    'clubCreateEvent.section.basics': 'Basic Details',
    'clubCreateEvent.section.basicsDesc':
        'The event\'s name, content and goal.',
    'clubCreateEvent.section.participation': 'Attendance and Fee',
    'clubCreateEvent.section.participationDesc':
        'Capacity, fee and session settings.',
    'clubCreateEvent.section.schedule': 'Date and Time',
    'clubCreateEvent.section.scheduleDesc':
        'Event day, time range and registration deadline.',
    'clubCreateEvent.section.audience': 'Target Audience',
    'clubCreateEvent.section.audienceDesc':
        'Who can see and register.',
    'clubCreateEvent.section.location': 'Event Location',
    'clubCreateEvent.section.locationDesc':
        'Used for location checks on QR entry and attendance.',
    'clubCreateEvent.section.media': 'Image',
    'clubCreateEvent.section.mediaDesc':
        'The event\'s cover image.',
    'clubCreateEvent.scope.label': 'Scope',
    'clubCreateEvent.scope.departmentOnly': 'Department Only',
    'clubCreateEvent.scope.universityAndDepartment':
        'University + Department Only',
    'clubCreateEvent.target.universityHint':
        'Leave empty to target your own university.',
    'clubCreateEvent.target.departmentHint':
        'Leave empty to target your own field.',
    'clubCreateEvent.fee.paid': 'Paid',
    'clubCreateEvent.sessions.hint':
        '1 session: documents go out automatically to checked-in participants '
        'once the event ends.\n'
        '2 or more: session tracking opens and you set the attendance '
        'percentage required for a certificate.',
    'form.checkinMode': 'Check-in / Attendance Mode',
    'checkinMode.checkin_attendance': 'Check-in + Attendance',
    'checkinMode.attendance_only': 'Attendance Only',
    'checkinMode.checkin_only': 'Check-in Only',
    'checkinMode.checkin_attendanceDesc':
        'Participants check in at the door; only those who checked in can join session attendance.',
    'checkinMode.attendance_onlyDesc':
        'No door check-in; session attendance starts directly.',
    'checkinMode.checkin_onlyDesc':
        'No session attendance; door check-in is enough.',
    'clubCreateEvent.feedback.sessionCountRequired':
        'An event with attendance needs at least 1 session.',
    'clubCreateEvent.image.pick': 'Choose From Device',
    'notification.openTarget': 'View',
    'clubCreateEvent.location.nameHint':
        'Participants see this name; location checks use the map pin.',
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
        'If you work in more than one field, add all of them.',
    'dashboard.scope.departmentOnly': 'Department Only',

    'clubDocuments.subtitle':
        'Your organizer panel opens once your documents are reviewed.',
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
    'clubScan.notOwner': 'This event does not belong to your team.',
    'clubScan.pastEvent': 'QR check-in only works for ongoing/upcoming events.',
    'clubScan.notRegistered': 'This participant is not signed up for this event.',
    'clubScan.alreadyCheckedIn': '{{name}} has already checked in.',
    'clubScan.sessionNotStarted': 'Start the session first.',
    'clubScan.alreadyInSession':
        '{{name}} already checked in for this session ({{current}}/{{total}}).',
    'clubScan.missingLocation':
        'The QR code has no location. The participant should refresh it.',
    'clubScan.tooFar':
        'The participant is outside the event location — {{distance}} away (max {{radius}} m).',
    'clubScan.success': 'Check-in confirmed for {{name}}.',
    'clubScan.noDoorCheckin':
        'This event has no door check-in — show the session QR instead and let participants scan it.',
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
        'The organizer is sent back to the document upload screen. Describe what '
        'is missing or wrong — the club will see this text.',
    'admin.needsDocuments.placeholder':
        'e.g. The advisor approval is unreadable, please re-upload.',
    'admin.needsDocuments.send': 'Send',
    'admin.feedback.documentsRequested':
        'The organizer was sent back to the document upload stage.',
    'clubDocuments.alreadyUploaded': 'Uploaded',
    'clubDocuments.replace': 'Replace',
    'media.openError': 'The file could not be opened.',
    'media.documentTitle': 'Document',
    'common.close': 'Close',
    'common.info': 'Info',
    'common.continueAction': 'Continue',

    'admin.nav.pending': 'Approvals',
    'admin.nav.stats': 'Statistics',
    'admin.nav.clubs': 'Organizers',
    'admin.nav.ban': 'Block',
    'admin.action.approve': 'Approve',
    'admin.action.block': 'Block',
    'admin.confirm.approve':
        'Approve {{club}}? The organizer will gain access to its panel.',
    'admin.confirm.block':
        'Block {{club}}? The documents it uploaded will be deleted permanently.',
    'admin.documents': 'Documents ({{count}})',

    'admin.stats.students': 'Participants',
    'admin.stats.clubs': 'Organizers',
    'admin.stats.male': 'Male',
    'admin.stats.female': 'Female',
    'admin.stats.byCity': 'Participants By City',
    'admin.stats.byUniversity': 'Participants By University',
    'admin.stats.detail': 'Detailed Breakdown',
    'admin.stats.noData': 'No data to show.',
    'admin.stats.cityCounts':
        '{{students}} participants · {{clubs}} organizers · {{male}}M / {{female}}F',
    'admin.stats.universityCounts':
        '{{students}} std. · {{clubs}} organizers · {{male}}M/{{female}}F',

    // Club directory (admin_clubs_screen.dart)
    'admin.clubs.title': 'Organizer Directory',
    'admin.clubs.searchPlaceholder': 'Search organizer, city or university...',
    'admin.clubs.empty': 'No matching organizer found.',
    'admin.clubs.cityCount': '{{count}} organizers',
    'admin.clubs.unnamed': 'Unnamed Club',
    'admin.clubs.summaryCounts':
        '{{clubs}} organizers · {{cities}} cities · {{universities}} universities',
    'admin.clubs.summary': 'Organizer Summary',
    'admin.clubs.info': 'Organizer Details',
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

    'admin.ban.searchPlaceholder': 'Search participant, university, city...',
    'admin.ban.empty': 'No matching participant found.',
    'admin.ban.studentCount': '{{count}} participants',
    'admin.ban.banButton': 'Block',
    'admin.ban.unbanButton': 'Unblock',
    'admin.ban.confirmBan':
        'Block {{name}}? They will be signed out and cannot log in; their '
        'upcoming registrations are removed and the seats freed.',
    'admin.ban.confirmUnban': 'Remove the block for {{name}}?',
    'admin.ban.tab.students': 'Participants',
    'admin.ban.tab.clubs': 'Organizers',
    'admin.ban.searchPlaceholderClubs': 'Search organizer, university, city...',
    'admin.ban.emptyClubs': 'No matching organizer found.',
    'admin.ban.clubCount': '{{count}} organizers',
    'admin.ban.filter.all': 'All',
    'admin.ban.filter.active': 'Active',
    'admin.ban.filter.banned': 'Blocked',
    'admin.ban.bannedLabel': 'Blocked',
    'admin.ban.confirmClubBan':
        'Block {{name}}? The organizer loses access to its panel; its documents '
        'are kept.',
    'admin.ban.confirmClubUnban':
        'Remove the block for {{name}}? The organizer returns to the review queue '
        'if its documents are still there, otherwise to the upload step.',
    'admin.ban.banSuccess': '{{name}} has been blocked.',
    'admin.ban.unbanSuccess': 'The block on {{name}} has been lifted.',
    'admin.ban.banError': 'Blocking failed. Try again.',
    'admin.ban.unbanError': 'Unblocking failed. Try again.',

    // Admin note to a club (club_message_panel.dart)
    'admin.clubs.ban': 'Block Club',
    'admin.clubs.unban': 'Unblock',
    'admin.message.title': 'Send Message to Organizer',
    'admin.message.hint':
        'If a document is missing or something needs fixing, write the '
        'reason here; the club sees it on its approval screen and the '
        'application stays in the queue.',
    'admin.message.placeholder':
        'e.g. The advisor approval is unreadable, please upload it again.',
    'admin.message.send': 'Send Message',
    'admin.message.sent': 'Message delivered to the organizer.',
    'admin.message.empty': 'Write a message before sending.',
    'admin.message.error': 'The message could not be sent. Try again.',
    'admin.message.none': 'No message has been sent to this organizer yet.',
    'admin.message.logTitle': 'Sent messages',
    'clubPending.messages.title': 'Message From The Admin',
    'clubPending.messages.hint':
        'Admin notes are below. You can re-upload a missing document.',

    // Connectivity
    'offline.banner': 'No internet connection',
    'offline.bannerDesc':
        'You\'ll pick up where you left off when you\'re back online.',
    'offline.loginBlocked':
        'No internet connection. Check your connection to sign in.',
    'offline.actionBlocked':
        'You are offline. Try again once you are back online.',
    'offline.restored': 'Internet connection restored.',

    // Club logo (account screen + event window badge)
    'clubAccount.logo': 'Organizer Logo',
    'clubAccount.feedback.logoUpdated': 'Organizer logo updated.',
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
        'Your application documents. Tap to open.',
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
        'Your account is permanently deleted after 30 days; you can restore it in that time.',
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

    'deleteAccount.subtitle':
        'Your account is deleted after 30 days; sign in during that time to restore it.',
    'deleteAccount.warning':
        'Your event registrations are released right away (your seat opens '
        'for others). Your account, profile and certificates are permanently '
        'deleted after 30 days.',
    'deleteAccount.passwordLabel': 'Your password',
    'deleteAccount.verifyByPhone': 'Verify with my phone',
    'deleteAccount.submit': 'Delete My Account',
    'deleteAccount.feedback.passwordRequired':
        'Enter your password to delete your account.',
    'deleteAccount.feedback.verifyFirst':
        'Verify your identity with your phone first.',
    'deleteAccount.feedback.phoneVerified':
        'Your identity is verified. You can delete your account.',
    'deleteAccount.notice.done':
        'Deletion request received. Your account will be deleted in 30 days; '
        'sign in during that time to restore it.',
    'deleteAccount.error.clubHasEvents':
        'Remove the events you created before deleting your account.',
    'deleteAccount.error.banned':
        'Blocked accounts cannot be deleted. For help, email '
        'product@regipass.com.',
    'deleteAccount.error.failed':
        'Your deletion request could not be saved. Check your connection and try again.',
    'pendingDeletion.title': 'Your account is scheduled for deletion',
    'pendingDeletion.lead':
        'You asked to delete your account. Your account and all your data will '
        'be permanently deleted on {{date}}.',
    'pendingDeletion.note':
        'If you changed your mind, you can restore your account now. Released '
        'event registrations do not come back; you can register again.',
    'pendingDeletion.restore': 'Restore my account',
    'pendingDeletion.signOut': 'Sign out (keep the deletion)',
    'pendingDeletion.error':
        'Your account could not be restored. Check your connection and try again.',
    'pendingDeletion.adminScheduled':
        'This account is scheduled for deletion by the Regipass team. For '
        'help, email product@regipass.com.',

    'screen.comingSoon': 'This section is under construction.',
    'screen.comingSoonDesc':
        'Organizer and admin screens will be completed in the next stage.',
    'paidEventConsent.log.title': 'Paid Event Consent Record',
    'paidEventConsent.log.club': 'Organizer consent — event creation',
    'paidEventConsent.log.students': 'Participant registration consents',
    'paidEventConsent.log.missing': 'No consent record found.',
    'paidEventConsent.log.studentsEmpty': 'No participant has consented yet.',
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
    'gate.unknownStudent': 'Participant',
    'gate.notSentYet': 'not sent yet',
    'gate.packInfo': 'List on device: {{n}} tickets · {{time}}',
    'gate.net.online': 'Online',
    'gate.net.offline': 'No internet',
    'gate.net.pending': '{{n}} scans waiting',
    'gate.net.sending': 'sending {{n}} scans',
    'gate.result.in': 'CHECKED IN',
    'gate.result.already': 'ALREADY IN',
    'gate.result.invalid-ticket': 'INVALID TICKET',
    'gate.result.code-not-found': 'CODE NOT FOUND',
    'gate.result.code-ambiguous': 'TYPE THE EXACT CODE',
    'gate.hint.code-not-found': 'No ticket with this code for this event; check the code.',
    'gate.hint.code-ambiguous': 'Type upper/lower case exactly as shown on the ticket.',
    'gate.manual.open': 'Enter code',
    'gate.manual.title': 'Enter the ticket code',
    'gate.manual.body': 'If the camera can\'t read it, type the code on the ticket.',
    'gate.manual.placeholder': 'Ticket code',
    'gate.manual.submit': 'Check in',
    'gate.manual.short': 'Code incomplete: type the 10 characters under the ticket.',
    'gate.manual.locked': 'Too many wrong attempts. Try again in {{n}} s.',
    'gate.manual.needEvent': 'Scan one ticket of the event first, or open the event and enter it there.',
    'ticket.codeLabel': 'Ticket code',
    'gate.result.not-registered': 'NOT REGISTERED',
    'gate.result.other-event': 'OTHER EVENT',
    'gate.result.not-owner': 'ANOTHER ORGANIZER\'S EVENT',
    'gate.result.no-door': 'NO DOOR TICKET',
    'gate.result.past-event': 'EVENT IS OVER',
    'gate.result.not-ticket': 'NOT A REGIPASS TICKET',
    'gate.result.unknown-event': 'EVENT NOT FOUND',
    'gate.hint.in': 'Scan the next one',
    'gate.hint.legacy': 'Old app ticket (no code) — check their ID',
    'gate.hint.already': 'First entry {{time}} · count unchanged',
    'gate.hint.invalid-ticket': 'Ticket code doesn\'t match; the participant should reopen the ticket.',
    'gate.hint.not-registered': 'This participant is not registered',
    'gate.hint.other-event': 'This ticket belongs to another event',
    'gate.hint.not-owner': 'This event is not yours',
    'gate.hint.no-door': 'Attendance only: show the session QR, participants scan it',
    'gate.hint.past-event': 'The event day has passed',
    'gate.hint.not-ticket': 'Ask the participant to open their Regipass ticket',
    'gate.hint.unknown-event': 'Event not found. If offline, this event\'s ticket list may not have been downloaded to this device yet',
    'gate.hint.conflict': 'Another device checked them in at {{time}} — first scan wins',
    'gate.hint.rejected': 'Server rejected — check this entry',
    'gate.conflictToast': '{{name}}: another device scanned first ({{time}}).',
    'gate.cameraHint': 'Hold the ticket up to the camera.',
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
    'registration.alerts.paymentPendingNote': 'Arrange payment with the organizer. Your registration is confirmed once they approve it; until then you can\'t enter.',
    'registration.alerts.seatsAvailableNow': 'A spot just opened up. You can register now.',
    'registration.alerts.waitlistJoined': 'You joined the waitlist: you are #{{position}}. You will be notified when a spot opens; the first to register gets it.',
    'registration.club.addSeats': '+{{n}} spots',
    'registration.club.addSeatsConfirm': 'Capacity will go from {{from}} to {{to}}. People on the waitlist get a "spot opened" notification; the first to register gets it.',
    'registration.club.cancelEventAction': 'Cancel Event',
    'registration.club.cancelEventBody': 'Registered participants and the waitlist will be notified; registrations are kept and the event shows as "Cancelled". If it has no registrations it is deleted.',
    'registration.club.cancelEventTitle': 'Cancel event',
    'registration.club.cancelledBanner': 'This event was cancelled. Registered participants were notified.',
    'registration.club.cancelledBannerReason': 'This event was cancelled. Reason: {{reason}}',
    'registration.club.eventCancelled': 'Event cancelled. {{n}} people notified.',
    'registration.club.eventDeleted': 'The event had no registrations and was deleted.',
    'registration.club.markPaid': 'Mark as paid',
    'registration.club.markedPaid': '{{name}}: payment confirmed, the participant was notified.',
    'registration.club.paid': 'Paid',
    'registration.club.paymentTitle': 'Payment',
    'registration.club.quotaNow': 'Capacity is now {{n}}.',
    'registration.club.quotaNowOpen': 'Capacity is now {{n}}. Registration is open.',
    'createEvent.lateRegistration': 'Keep registration open after the event starts',
    'registration.scopeAsk.title': 'One detail is missing',
    'manualAttendance.title': 'Manual attendance',
    'program.title': 'Schedule',
    'program.live': '● Now',
    'program.attended': '✓ Attended',
    'program.attendedManual': '✓ Attended (manual)',
    'program.people': '{{n}} people',
    'program.certNeeded':
        'For the certificate attend at least {{needed}} of {{total}} sessions · so far {{done}}',
    'manualAttendance.addConfirm':
        'Mark {{name}} as present for {{session}} manually? It shows with "!" in the report.',
    'manualAttendance.removeConfirm':
        'Remove the manual mark for {{name}} in {{session}}?',
    'manualAttendance.added': '{{name}}: added to {{session}} attendance.',
    'manualAttendance.removed': '{{name}}: mark removed for {{session}}.',
    'manualAttendance.already': '{{name}} is already in {{session}} attendance.',
    'manualAttendance.uncertain': 'Some sessions are uncertain (old record).',
    'manualAttendance.codeTitle': 'Attendance by ticket code',
    'manualAttendance.codeHint': 'Code on the ticket (e.g. K7P2Q X9A1B)',
    'manualAttendance.codeSubmit': 'Add to attendance',
    'manualAttendance.error.generic': 'Could not save attendance. Try again.',
    'manualAttendance.error.session-not-started':
        'This session has not started; only started sessions can be marked.',
    'manualAttendance.error.not-manual':
        'This attendance was scanned by QR; it cannot be removed manually.',
    'manualAttendance.error.payment-pending':
        'Attendance is not recorded while payment is pending.',
    'manualAttendance.error.code-not-found':
        'No registration found for this code. Check the code.',
    'manualAttendance.error.code-ambiguous':
        'This code matches more than one registration; type it exactly.',
    'manualAttendance.error.code-short': 'The code must be at least 6 characters.',
    'manualAttendance.error.not-registered': 'Registration not found.',
    'clubCreateEvent.sessionTime.end-before-start':
        'Session {{n}} must end after it starts.',
    'clubCreateEvent.sessionTime.overlap':
        'Session {{n}} starts before session {{prev}} ends. Fix the times so they do not overlap.',
    'clubCreateEvent.sessionTime.order':
        'Session {{n}} starts before session {{prev}}. List sessions in time order.',
    'clubCreateEvent.sessionTime.before-event':
        'Session {{n}} starts before the event start time.',
    'clubCreateEvent.sessionTime.after-event':
        'Session {{n}} ends after the event end time.',
    'registration.scopeAsk.body':
        'This event is open to certain universities/departments. Pick yours; it is also saved to your account.',
    'registration.scopeAsk.university': 'University',
    'registration.scopeAsk.department': 'Department',
    'registration.scopeAsk.save': 'Save and continue',
    'createEvent.lateRegistrationHint':
        'Registration does not close when check-in or the first session starts; it stays open (if seats remain) until the registration deadline and the event stays in Discover. Set the deadline to the event day for latecomers.',
    'registration.club.quotaBlocked.event-started':
        'Capacity is now {{n}}, but check-in or a session has started, so no new registrations are accepted.',
    'registration.club.quotaBlocked.registration-closed':
        'Capacity is now {{n}}, but you paused registrations. Tap "Restart Registrations" to accept new ones.',
    'registration.club.quotaBlocked.deadline-passed':
        'Capacity is now {{n}}, but the registration deadline has passed. Edit the event to extend it.',
    'registration.club.quotaBlocked.event-past':
        'Capacity is now {{n}}, but the event day has passed.',
    'registration.club.quotaBlocked.event-hidden':
        'Capacity is now {{n}}, but the event was hidden by an admin.',
    'registration.club.quotaBlocked.quota-setup':
        'Capacity is now {{n}}; setup is still running, registration opens in a few seconds.',
    'registration.club.quotaSetupDone': 'Capacity set up; registration is open.',
    'registration.club.quotaSetupFailed': 'The capacity could not be set up; registration is closed. Edit and save the event to try again.',
    'registration.club.quotaSetupStatus': 'Setting Up Capacity',
    'registration.club.reasonLabel': 'Reason (optional, shown to participants)',
    'registration.club.removeAction': 'Remove registration',
    'registration.club.removeBody': '{{name}}\'s registration will be removed. The participant will be notified and the spot opens to the waitlist.',
    'registration.club.removeReasonHint': 'e.g. Payment not made',
    'registration.club.removeTitle': 'Remove registration',
    'registration.club.removed': '{{name}}\'s registration was removed.',
    'registration.club.unmarkConfirm': 'Undo the "Paid" mark for {{name}}? The participant will not be able to enter.',
    'registration.club.unmarkPaid': 'Undo',
    'registration.club.unmarkedPaid': '{{name}}: payment mark removed.',
    'registration.club.waitlistCount': '{{count}} people on the waitlist',
    'registration.club.waitlistEmpty': 'Fully booked. The waitlist is empty for now.',
    'registration.errors.banned': 'Your account is blocked, so you cannot register.',
    'registration.errors.below-registered': 'Capacity can\'t be lower than the number of registered participants ({{registered}}). Enter a higher capacity.',
    'registration.errors.busy': 'It\'s very busy right now. Try again in a few seconds.',
    'registration.errors.cancel-locked': 'Sessions have started, so you can no longer cancel your registration yourself. Contact the organizer if needed.',
    'registration.errors.club-banned': 'This organizer\'s events are not accepting registrations right now.',
    'registration.errors.deadline-passed': 'The registration deadline has passed.',
    'registration.errors.event-cancelled': 'This event was cancelled.',
    'registration.errors.event-hidden': 'This event is no longer published.',
    'registration.errors.event-not-found': 'Event not found.',
    'registration.errors.event-not-paid': 'This event is not paid.',
    'registration.errors.event-past': 'The event date has passed.',
    'registration.errors.event-started': 'The event has started; no new registrations.',
    'registration.errors.generic': 'The action could not be completed. Please try again.',
    'registration.errors.invalid-quota': 'Enter a valid capacity.',
    'registration.errors.not-eligible': 'This event is open to specific universities or departments; your profile doesn\'t meet the requirement.',
    'registration.errors.not-event-club': 'Only the event\'s organizer can do this.',
    'registration.errors.not-registered': 'No registration found for this event.',
    'registration.errors.offline': 'Could not reach the server. Check your connection and try again.',
    'registration.errors.paid-consent-required': 'Accept the payment notice to register for a paid event.',
    'registration.errors.payment-pending': 'Your payment is not confirmed yet; you can enter once the organizer confirms it.',
    'registration.errors.phone-not-verified': 'Verify your phone number before registering.',
    'registration.errors.profile-incomplete': 'Complete your participant profile to register.',
    'registration.errors.profile-missing': 'Complete your participant profile to register.',
    'registration.errors.quota-setup': 'The event\'s capacity is not ready yet. Try again shortly.',
    'registration.errors.registration-closed': 'Registration for this event is closed.',
    'registration.errors.signIn': 'Your session seems to have ended. Please sign in again.',
    'eventModal.contactTitle': 'Contact Information',
    'eventModal.feeContactTitle': 'Contact for Payment',
    'eventModal.feeContactNoteClub': 'Fee: {{fee}}. Payment is made directly with the organizer, outside Regipass; participants use the details below to reach the organizer. When you receive a payment, mark it "Paid" in the participant list; the registration is confirmed then.',
    'eventModal.feeContactNoteWithFee': 'Fee: {{fee}}. Payment is made directly with the organizer, outside Regipass; contact the organizer using the details below. Your registration is confirmed once the organizer marks your payment as received.',
    'clubCreateEvent.contact.label': 'Show contact information?',
    'clubCreateEvent.contact.labelPaid': 'Contact information for payment',
    'clubCreateEvent.contact.club': 'Organizer\'s saved details',
    'clubCreateEvent.contact.custom': 'Enter new details',
    'clubCreateEvent.contact.hidden': 'Don\'t show',
    'clubCreateEvent.contact.clubPreview': 'Will show: {{contact}}',
    'clubCreateEvent.contact.clubEmpty': 'No contact info on your profile. You can enter new details.',
    'clubCreateEvent.contact.hiddenHint': 'No contact information will be shown on the event.',
    'clubCreateEvent.contact.phone': 'Contact phone',
    'clubCreateEvent.contact.email': 'Contact email',
    'clubCreateEvent.contact.customHint': 'Fill in at least one. These details appear only on this event.',
    'clubCreateEvent.contact.errorEmpty': 'You chose new details: enter at least a phone or an email.',
    'clubCreateEvent.contact.errorEmail': 'The email address doesn\'t look valid.',
    'clubCreateEvent.contact.errorPhone': 'The phone number must have 11 digits (e.g. 0555 123 45 67 or 0212 123 45 67).',
    'registration.bulk.hint': 'Select participants for bulk actions.',
    'registration.bulk.selected': '{{n}} participants selected',
    'registration.bulk.selectAll': 'Select all',
    'registration.bulk.clear': 'Clear selection',
    'registration.bulk.selectPending': 'Select payment pending ({{n}})',
    'registration.bulk.markPaid': 'Bulk payment approval',
    'registration.bulk.markPaidN': 'Mark paid ({{n}})',
    'registration.bulk.markPaidConfirm': 'Payment will be confirmed for {{n}} participants and each will be notified.',
    'registration.bulk.markedPaid': 'Payment confirmed for {{n}} participants.',
    'registration.bulk.nonePending': 'None of the selected participants has a pending payment.',
    'registration.bulk.removeN': 'Remove ({{n}})',
    'registration.bulk.removeBody': 'The registrations of {{n}} selected participants will be removed. Each will be notified and their spots will open to the waitlist.',
    'registration.bulk.removed': 'Removed {{n}} registrations.',
    'registration.errors.too-many-students': 'You can select at most 200 participants at once.',
    'registration.labels.cancelled': 'Cancelled',
    'registration.labels.payment': 'Payment',
    'registration.labels.registeredAt': 'Registered',
    'registration.status.cancelled': 'Cancelled',
    'registration.status.cancelledNoReason': 'The organizer cancelled the event.',
    'registration.status.fullWaitlist': 'Fully Booked · Waitlist',
    'registration.status.paymentConfirmed': 'Paid (confirmed by the organizer)',
    'registration.status.paymentPending': 'Payment Pending',
    'registration.status.paymentPendingLong': 'Pending — confirmed once the organizer marks your payment',
    'registration.status.registeredPaymentPending': 'Registered · Payment Pending',
    'registration.status.waitlisted': 'On the Waitlist',
    'registration.ticket.paymentPendingHint': 'Your ticket becomes valid once your payment is confirmed.',
    // İP-EL: etkinlik linki
    'eventLink.share': 'Share',
    'eventLink.shareFailed': 'Couldn\'t get the link. Check your connection and try again.',
    'eventLink.close': 'Close',
    'eventLink.notFound': 'Event not found',
    'eventLink.notFoundHint': 'This link is invalid or was removed by the organizer.',
    'eventLink.toHome': 'Back to home',
    'eventLink.free': 'Free',
    'eventLink.paid': 'Paid',
    'eventLink.login': 'Sign in and register',
    'eventLink.guest': 'Register without an account',
    'eventLink.guestHint': 'Just your name, email and phone; we\'ll text you a code.',
    'eventLink.clubCannot': 'Organizer accounts can\'t register for events. Sign in with a participant account to register.',
    'eventLink.status.full': 'This event is full.',
    'eventLink.status.closed': 'Registration is closed.',
    'eventLink.status.started': 'The event has started; registration is closed.',
    'eventLink.status.past': 'This event has ended.',
    'eventLink.status.cancelled': 'This event was cancelled.',
    'eventLink.card.title': 'Event link',
    'eventLink.card.hint': 'Share this link: anyone who opens it can register, even without an account.',
    'eventLink.card.hintLinkOnly': 'This event is hidden from Explore; only people with this link can see it and register.',
    'eventLink.card.copy': 'Copy',
    'eventLink.card.copied': 'Link copied.',
    'eventLink.card.poster': 'QR poster',
    'eventLink.card.stats': '{{views}} visits · {{regs}} registrations via link',
    'eventLink.card.slugAdd': 'Add a custom name (e.g. /e/spring-concert)',
    'eventLink.card.slugEdit': 'Change custom name',
    'eventLink.card.slugLabel': 'Custom name',
    'eventLink.card.slugHint': 'Lowercase letters, digits and hyphens; 3–40 characters. Leave empty to remove.',
    'eventLink.card.slugSave': 'Save',
    'eventLink.card.slugSaved': 'Link updated.',
    'eventLink.card.renew': 'Renew link (revoke the old one)',
    'eventLink.card.renewConfirm':
        'The current link (including its custom name) stops working immediately; anyone opening it sees "invalid link". A new link is created. Existing registrations and tickets are not affected; printed QR posters stop working.',
    'eventLink.card.renewDo': 'Renew',
    'eventLink.card.renewed': 'New link created; the old link no longer works.',
    'eventLink.card.cancel': 'Cancel',
    'eventLink.card.failed': 'Couldn\'t load the link.',
    'eventLink.card.retry': 'Try again',
    'eventLink.reason.slug-taken': 'This name is taken; try another.',
    'eventLink.reason.slug-invalid': 'Use only lowercase letters, digits and hyphens (3–40 characters).',
    'eventLink.create.linkOnly': 'Only people with the link can see it',
    'eventLink.create.linkOnlyHint': 'The event won\'t appear in Explore or lists; people you share the link with can register.',
    // İP-ŞK: report an event + block an organizer
    'complaint.report': 'Report',
    'complaint.title': 'Report this event',
    'complaint.help': 'Is something wrong with this event? Pick a reason; we review reports within 24 hours. The organizer can\'t see who reported.',
    'complaint.reason.inappropriate': 'Inappropriate or offensive content',
    'complaint.reason.fake': 'Fake event',
    'complaint.reason.fraud': 'Suspected fraud',
    'complaint.reason.spam': 'Spam or misleading',
    'complaint.reason.other': 'Other',
    'complaint.noteHint': 'Anything to add? (optional)',
    'complaint.noteRequiredHint': 'Briefly describe the problem',
    'complaint.send': 'Send',
    'complaint.sending': 'Sending…',
    'complaint.sent': 'We got your report. Thank you.',
    'complaint.block.button': 'Block organizer',
    'complaint.block.title': 'Block organizer',
    'complaint.block.confirm': 'Block {{name}}? You won\'t see their events and you\'ll stop following them. You can unblock from your Account page.',
    'complaint.block.action': 'Block',
    'complaint.block.done': '{{name}} blocked. Their events won\'t be shown.',
    'complaint.blocked.title': 'Blocked organizers',
    'complaint.blocked.help': 'Events from organizers you blocked are not shown to you.',
    'complaint.blocked.unblock': 'Unblock',
    'complaint.blocked.unblocked': '{{name}} unblocked.',
    'complaint.error.signIn': 'You need to sign in for this.',
    'complaint.error.studentOnly': 'Only participant accounts can block organizers.',
    'complaint.error.ownEvent': 'You can\'t report your own event.',
    'complaint.error.notFound': 'This event is no longer available.',
    'complaint.error.noteRequired': 'Please describe the problem briefly.',
    'complaint.error.tooManyBlocks': 'You can block up to 300 organizers.',
    'complaint.error.generic': 'Something went wrong. Check your connection and try again.',
  },
};
