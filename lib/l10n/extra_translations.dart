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
    // register.js içinde sabit metin olarak duruyordu
    'auth.error.roleAlreadyExists':
        'Bu hesapta bu rol zaten mevcut. Lütfen giriş yapın.',
    'auth.error.emailRegisteredWrongPassword':
        'Bu e-posta zaten kayıtlı fakat şifre yanlış.',

    // Telefonu doğrulanmadığı için silinen kayıt (bkz. domain/account_expiry.dart)
    'auth.notice.unverifiedPhoneRemoved':
        'Telefon numaran 3 gün içinde doğrulanmadığı için kaydın silindi. '
        'Dilersen yeniden hesap oluşturabilirsin.',

    // Giriş ekranı (yeniden tasarım) ve Keşfet
    'nav.explore': 'Keşfet',
    'auth.noAccount': 'Hesabın yok mu?',
    'auth.haveAccount': 'Zaten hesabın var mı?',
    'common.back': 'Geri',

    // Şifremi unuttum
    'forgotPassword.title': 'Şifreni Sıfırla',
    'forgotPassword.emailRequired':
        'Önce e-posta adresini gir, sonra "Şifremi unuttum"a bas.',
    'forgotPassword.phoneQuestion':
        'Bu hesaba kayıtlı telefon numarası aşağıdaki gibi. Doğrulama kodu bu numaraya gönderilecek.',
    'forgotPassword.enterPhoneHint':
        'Kodu gönderebilmemiz için numaranı tam olarak yaz:',
    'forgotPassword.sendCode': 'Doğrulama kodu gönder',
    'forgotPassword.phoneMismatch':
        'Bu numara girdiğin e-postaya ait hesapla eşleşmiyor. Numaranı kontrol et.',
    'forgotPassword.noPhone':
        'Bu e-postaya bağlı doğrulanmış bir telefon bulunamadı. Numaranı yazıp yine de deneyebilirsin.',
    'forgotPassword.tooManyAttempts':
        'Çok fazla deneme yapıldı. Lütfen bir süre sonra tekrar dene.',
    'forgotPassword.newPasswordHint': 'Doğrulandı. Yeni şifreni belirle.',
    'forgotPassword.savePassword': 'Şifreyi Kaydet',
    'forgotPassword.success': 'Şifren güncellendi.',
    'forgotPassword.continue': 'Girişe dön',
    'forgotPassword.genericError': 'İşlem tamamlanamadı. Lütfen tekrar dene.',
    'auth.error.networkFailed':
        'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
    'explore.guestTitle': 'Misafir olarak geziyorsun',
    'explore.guestDesc':
        'Etkinliklere göz atabilirsin. Kayıt olmak, QR oluşturmak ve belge almak için giriş yapmalısın.',
    'explore.signInToJoin': 'Katılmak için giriş yap',
    'explore.empty': 'Şu anda gösterilecek etkinlik yok.',
    'explore.loadError': 'Etkinlikler yüklenemedi.',
    'explore.permissionDenied':
        'Etkinlikler misafir kullanıcılara henüz açık değil.\n'
        'Yöneticinin firestore.rules dosyasındaki etkinlik okuma kuralını '
        'yayınlaması gerekiyor.',

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
    'admin.notify.sendDenied':
        'Duyuru gönderilemedi: bu hesabın yazma yetkisi yok. '
        'Firestore kuralları güncel değilse yeniden yayınla.',

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
    'account.switchRole': 'Hesap değiştir',

    // Hesap ekranındaki telefon alanı + doğrulama pop-up'ı
    'account.phoneChangeHint':
        'Numarayı değiştirirsen kaydettikten sonra açılan pencerede SMS ile '
        'doğrulaman gerekir. Doğrulanmadan numara değişmez.',
    'account.phoneNotChanged':
        'Numara doğrulanmadı; kayıtlı numaran olduğu gibi kaldı.',
    // Telefon doğrulama hataları (üretilen sözlükte karşılığı yok)
    'phoneVerify.error.browserCanceled':
        'Güvenlik doğrulaması tamamlanmadı: açılan tarayıcı penceresi '
        'kapatıldı. Lütfen "Kodu Gönder"e tekrar basın ve pencere kendi '
        'kapanana kadar bekleyin.',
    'phoneVerify.error.browserAlreadyOpen':
        'Devam eden bir doğrulama var. Lütfen açık olan doğrulama penceresini '
        'tamamlayın ya da birkaç saniye sonra tekrar deneyin.',
    'phoneVerify.error.network':
        'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edip tekrar '
        'deneyin.',
    'phoneVerify.error.deviceCheckFailed':
        'Cihaz doğrulaması tamamlanamadı, bu yüzden SMS gönderilemedi. '
        'Google Play Hizmetleri olan bir cihazda tekrar deneyin; sorun '
        'sürerse uygulamayı güncelleyin.',
    'phoneVerifySheet.title': 'Telefon Numarasını Doğrula',
    'phoneVerifySheet.subtitle':
        'Bu numaraya 6 haneli bir doğrulama kodu göndereceğiz. Vazgeçmek '
        'istersen sağ üstteki çarpıya basabilirsin.',

    // Fotoğraf seçimi (mobilde galeri/kamera ayrımı web'de yoktu)
    'form.photoFromGallery': 'Galeriden Seç',
    'form.photoFromCamera': 'Fotoğraf Çek',
    'form.phoneOperatorPrefix': 'Türkiye cep telefonu 5 ile başlamalı.',
    // Alanın altında gösterilen kısa uyarı; pop-up içindeki uzun açıklama
    // 'phoneVerify.error.numberInUse' anahtarında.
    'form.phoneTaken':
        'Bu numara başka bir hesaba ait. Lütfen farklı bir numara gir.',
    // Numaraya başka bir hesap kod istedi ama henüz doğrulamadı; rezervasyon
    // 15 dakika sonra kendiliğinden düşer (bkz. phone_directory_repository).
    'form.phonePending':
        'Bu numara için az önce başka bir hesap doğrulama kodu istedi. '
        'Numara senin ise 15 dakika sonra tekrar dene.',

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
    'common.loading': 'Yükleniyor...',
    'common.logout': 'Çıkış Yap',
    'common.select': 'Seçiniz',
    'common.search': 'Ara...',

    // Kamera / QR (mobilde web'den farklı izin akışı var)
    'scan.permissionDenied':
        'Kamera izni verilmedi. Ayarlardan kamera iznini açın.',
    'scan.pointCamera': 'Kamerayı QR koda tutun.',
    'scan.ready': 'Sonraki öğrenci için hazır.',
    'scan.successTitle': 'Giriş Başarılı',
    'scan.failTitle': 'Giriş Başarısız',
    'scan.notRegipassQr': 'Bu QR Regipass giriş kodu değil.',
    'scan.missingEventInfo': 'QR kodda etkinlik bilgisi eksik.',
    'scan.notSessionQr': 'Bu QR bir oturum giriş kodu değil.',
    'scan.missingSessionInfo': 'QR kodda oturum bilgisi eksik.',
    'scan.eventNotFound': 'Etkinlik bulunamadı.',
    'scan.notSessionBased': 'Bu etkinlik oturum bazlı değil.',
    'scan.sessionsCompleted': 'Etkinlik oturumları tamamlandı.',
    'scan.qrExpired': 'Bu QR artık geçerli değil — oturum ilerledi.',
    'scan.notRegistered': 'Bu etkinliğe kayıtlı değilsiniz.',
    'scan.alreadyCheckedInSession':
        'Bu oturumda ({{current}}/{{total}}) zaten giriş yaptınız.',
    'scan.checkinSaveFailed': 'Giriş kaydedilemedi, tekrar deneyin.',
    'scan.permissionError':
        'Yetki hatası — bu oturum için giriş kaydedilemedi.',
    'scan.sessionSuccess':
        '{{current}}. oturumdasınız (katılım {{attended}}/{{total}}).',
    'scan.otherEventQr':
        'Bu QR başka bir etkinliğe ait. Girdiğiniz etkinliğin oturum QR\'ını okutun.',

    // Oturumlu etkinlikte öğrenci QR üretmez, kulübün oturum QR'ını okutur.
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
    'location.permissionDenied':
        'Konum izni verilmedi. Etkinlik konum doğrulaması yapıyorsa giriş reddedilebilir.',
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
    'clubEvents.group.pending': 'Beklemede',
    'clubEvents.group.past': 'Geçmiş',
    'clubEvents.empty.active':
        'Aktif etkinlik bulunmuyor. Alttaki + düğmesinden yeni etkinlik oluşturabilirsin.',
    'clubEvents.empty.pending': 'Beklemede olan etkinlik bulunmuyor.',
    'clubEvents.empty.past': 'Geçmiş etkinlik bulunmuyor.',
    'clubEvents.feedback.loadError': 'Etkinlikler yüklenirken bir hata oluştu.',
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

    'clubEvents.session.title': 'Oturumlar',
    'clubEvents.session.notStarted': 'Oturum başlatılmadı (0/{{total}})',
    'clubEvents.session.active': 'Aktif oturum: {{current}}/{{total}}',
    'clubEvents.session.lastActive': 'Son oturum aktif: {{total}}/{{total}}',
    'clubEvents.session.allDone':
        'Tüm oturumlar tamamlandı ({{total}}/{{total}})',
    // İlerleme artık çubukla anlatılıyor; bu metinler yalnızca durumu söyler,
    // "2/4" gibi bir sayı taşımaz.
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
    'clubEvents.session.undone':
        '{{session}}. oturuma dönüldü. Bu oturumun QR\'ı yeniden geçerli.',
    'clubEvents.session.undoneToStart':
        'Oturumlar başlangıca alındı. QR girişleri şimdilik durdu.',
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
    'clubEvents.session.qrHint':
        'Bu kodu ekrana yansıt; öğrenciler kendi telefonlarından okutsun.',
    'clubEvents.session.qrError': 'QR görseli yüklenemedi.',

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
        'Belge {{count}} öğrenciye gönderildi, {{failed}} öğrencide hata '
        'alındı. Belgenin üzerindeki gönder tuşuyla tekrar deneyebilirsin.',
    'clubEvents.certificate.redistribute': 'Bu belgeyi dağıt',
    'clubEvents.certificate.distributedCount': '{{count}} öğrenciye gönderildi',
    'clubEvents.certificate.notDistributed': 'Henüz kimseye gönderilmedi',
    'clubEvents.certificate.sourceMissing':
        'Belge dosyası okunamadı. Belgeyi silip yeniden yüklemen gerekiyor.',
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
        'Belge bu adresten indirilemedi. Bağlantının herkese açık olduğundan '
        'emin ol.',
    'clubEvents.certificate.linkInvalid':
        'Yapıştırılan metin bir belge adresi ya da cihazdaki bir dosya yolu '
        'değil.',
    'clubEvents.certificate.tooLarge': 'Belge en fazla 10 MB olabilir.',
    'clubEvents.certificate.invalidType':
        'Yalnızca PDF, JPG veya PNG belge yükleyebilirsin.',
    'clubEvents.certificate.pickerError':
        'Dosya seçici açılamadı. Uygulamanın dosya erişim iznini kontrol et.',
    'clubEvents.certificate.readError':
        'Seçilen dosya okunamadı. Dosyayı önce telefonuna indirip tekrar dene.',
    'clubEvents.certificate.sending':
        'Belgeler gönderiliyor ({{done}}/{{total}})...',
    'clubEvents.certificate.sent': 'Belge {{count}} öğrenciye gönderildi.',
    'clubEvents.certificate.error':
        'Belge dağıtımı sırasında hata oluştu. Lütfen tekrar dene.',
    'clubEvents.certificate.permissionError':
        'Yetki hatası: storage.rules ve firestore.rules dosyalarını yayınla.',
    'clubEvents.certificate.authError':
        'Oturum doğrulanamadı. Lütfen tekrar giriş yap.',
    'clubEvents.certificate.quotaError': 'Storage kotası dolu.',
    'clubEvents.certificate.storageError':
        'Storage\'a ulaşılamadı. Firebase Console\'da Storage etkin mi ve '
        'kova adı doğru mu kontrol et.',
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
    'clubCreateEvent.location.missingCoordinates':
        'Konum adı girdin ama koordinat seçmedin.',
    'clubCreateEvent.feedback.invalidEventDate': 'Etkinlik tarihini seç.',
    'clubCreateEvent.feedback.deadlineAfterEventDate':
        'Son başvuru tarihi etkinlik tarihinden sonra olamaz.',
    'clubCreateEvent.feedback.invalidTimeRange':
        'Bitiş saati başlangıç saatinden sonra olmalı.',
    'clubCreateEvent.feedback.saving': 'Etkinlik kaydediliyor...',

    // Üretilen sözlükte "Etkinlik Adi" olarak kalmıştı.
    'form.eventTitle': 'Etkinlik Adı',
    'form.sessionCount': 'Oturum Sayısı',
    'form.targetSector': 'Hedef Sektör / Alan',
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
        'Görsel {{size}} KB — en fazla {{limit}} KB olabilir. Daha küçük bir '
        'görsel seç ya da adresini yapıştır.',
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
    'clubDocuments.feedback.permissionError':
        'Yetki hatası: Storage kuralları belge yüklemeye izin vermiyor.',

    'clubScan.otherEvent': 'Bu QR kod başka bir etkinliğe ait.',
    'clubScan.notOwner': 'Bu etkinlik senin kulübüne ait değil.',
    'clubScan.pastEvent':
        'QR okutma yalnızca devam eden/yaklaşan etkinliklerde kullanılabilir.',
    'clubScan.notRegistered': 'Bu öğrencinin kaydı bu etkinlikte bulunamadı.',
    'clubScan.alreadyCheckedIn': '{{name}} zaten giriş yapmış.',
    'clubScan.sessionNotStarted': 'Önce oturumu başlat.',
    'clubScan.alreadyInSession':
        '{{name}} bu oturumda ({{current}}/{{total}}) zaten giriş yaptı.',
    'clubScan.missingLocation':
        'QR kodda konum bilgisi yok — öğrenci QR\'ını yeniden oluşturmalı.',
    'clubScan.tooFar':
        'Öğrenci etkinlik konumunun dışında — {{distance}} uzakta (en fazla {{radius}} m).',
    'clubScan.success': '{{name}} için giriş onaylandı.',
    'clubScan.sessionSuccess':
        '{{name}} için {{current}}. oturum girişi onaylandı (katılım {{attended}}/{{total}}).',

    'clubPending.notApprovedYet':
        'Onay henüz gelmedi. Yönetici belgelerini incelediğinde burası '
        'kendiliğinden güncellenir.',
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

    'admin.ban.searchPlaceholder': 'Öğrenci, üniversite, şehir ara...',
    'admin.ban.empty': 'Eşleşen öğrenci bulunamadı.',
    'admin.ban.studentCount': '{{count}} öğrenci',
    'admin.ban.banButton': 'Engelle',
    'admin.ban.unbanButton': 'Engeli Kaldır',
    'admin.ban.confirmBan':
        '{{name}} engellensin mi? Oturumu kapatılır ve giriş yapamaz.',
    'admin.ban.confirmUnban': '{{name}} için engel kaldırılsın mı?',

    // Kulüp / yönetici tarafı (bu turda iskelet)
    // Bağlantı durumu
    'offline.banner': 'İnternet bağlantısı yok',
    'offline.bannerDesc':
        'Bağlantın geri geldiğinde kaldığın yerden devam edebilirsin.',
    'offline.loginBlocked':
        'İnternet bağlantısı yok. Giriş yapabilmek için bağlantını kontrol et.',
    'offline.actionBlocked':
        'İnternet bağlantısı kesildi. Bağlantın geri geldiğinde tekrar dene.',
    'offline.restored': 'İnternet bağlantısı geri geldi.',

    // Kulüp logosu (hesap ekranı + etkinlik penceresi rozeti)
    'clubAccount.logo': 'Kulüp Logosu',
    'clubAccount.feedback.logoUpdated': 'Kulüp logosu güncellendi.',
    'clubCreateEvent.image.autoShort':
        'Görsel eklemezsen kapakta gri Regipass logosu görünür.',

    'screen.comingSoon': 'Bu bölüm hazırlanıyor.',
    'screen.comingSoonDesc':
        'Kulüp ve yönetici ekranları bir sonraki aşamada tamamlanacak.',
  },
  'en': <String, String>{
    'auth.error.roleAlreadyExists':
        'This account already has that role. Please sign in instead.',
    'auth.error.emailRegisteredWrongPassword':
        'This email is already registered but the password is wrong.',

    'auth.notice.unverifiedPhoneRemoved':
        'Your record was deleted because your phone number was not verified '
        'within 3 days. You can create a new account if you like.',

    'nav.explore': 'Explore',
    'auth.noAccount': "Don't have an account?",
    'auth.haveAccount': 'Already have an account?',
    'common.back': 'Back',

    'forgotPassword.title': 'Reset your password',
    'forgotPassword.emailRequired':
        'Enter your email address first, then tap "Forgot my password".',
    'forgotPassword.phoneQuestion':
        'The phone number registered to this account is shown below. The verification code will be sent to it.',
    'forgotPassword.enterPhoneHint':
        'Type your number in full so we can send the code:',
    'forgotPassword.sendCode': 'Send verification code',
    'forgotPassword.phoneMismatch':
        "This number doesn't match the account for that email. Please check it.",
    'forgotPassword.noPhone':
        'No verified phone was found for this email. You can still enter your number and try.',
    'forgotPassword.tooManyAttempts':
        'Too many attempts. Please try again later.',
    'forgotPassword.newPasswordHint': 'Verified. Choose your new password.',
    'forgotPassword.savePassword': 'Save password',
    'forgotPassword.success': 'Your password has been updated.',
    'forgotPassword.continue': 'Back to sign in',
    'forgotPassword.genericError':
        'Could not complete the request. Please try again.',
    'auth.error.networkFailed':
        'Could not connect. Check your internet connection.',
    'explore.guestTitle': "You're browsing as a guest",
    'explore.guestDesc':
        'You can browse events. Sign in to register, generate a QR code and receive certificates.',
    'explore.signInToJoin': 'Sign in to join',
    'explore.empty': 'There are no events to show right now.',
    'explore.loadError': 'Events could not be loaded.',
    'explore.permissionDenied':
        'Events are not open to guest users yet.\n'
        'An administrator needs to publish the event read rule in firestore.rules.',

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
    'admin.notify.sendError': 'The notice could not be sent. Please try again.',
    'admin.notify.sendDenied':
        'The notice could not be sent: this account is not allowed to write. '
        'Re-deploy the Firestore rules if they are out of date.',

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
    'form.phoneOperatorPrefix': 'Turkish mobile numbers must start with 5.',
    'form.phoneTaken':
        'This number belongs to another account. Please enter a different one.',
    // Another account requested a code for this number but has not verified
    // it yet; the reservation expires by itself after 15 minutes.
    'form.phonePending':
        'Another account just requested a verification code for this number. '
        'If the number is yours, try again in 15 minutes.',

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
    'common.loading': 'Loading...',
    'common.logout': 'Log out',
    'common.select': 'Select',
    'common.search': 'Search...',

    'scan.permissionDenied':
        'Camera permission denied. Enable camera access in settings.',
    'scan.pointCamera': 'Point the camera at the QR code.',
    'scan.ready': 'Ready for the next student.',
    'scan.successTitle': 'Check-in Successful',
    'scan.failTitle': 'Check-in Failed',
    'scan.notRegipassQr': 'This is not a Regipass check-in code.',
    'scan.missingEventInfo': 'The QR code is missing event information.',
    'scan.notSessionQr': 'This is not a session check-in code.',
    'scan.missingSessionInfo': 'The QR code is missing session information.',
    'scan.eventNotFound': 'Event not found.',
    'scan.notSessionBased': 'This event is not session-based.',
    'scan.sessionsCompleted': 'All sessions for this event are completed.',
    'scan.qrExpired': 'This QR is no longer valid — the session has advanced.',
    'scan.notRegistered': 'You are not registered for this event.',
    'scan.alreadyCheckedInSession':
        'You already checked in for this session ({{current}}/{{total}}).',
    'scan.checkinSaveFailed': 'Could not save the check-in, please try again.',
    'scan.permissionError':
        'Permission error — the check-in could not be saved for this session.',
    'scan.sessionSuccess':
        'You are in session {{current}} (attendance {{attended}}/{{total}}).',
    'scan.otherEventQr':
        'This QR belongs to another event. Scan the session QR of the event you joined.',

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
        'Location permission denied. Check-in may be rejected if the event verifies location.',
    'location.gettingLocation': 'Getting location...',
    'account.switchRole': 'Switch account',

    // Account screen phone field + verification pop-up
    'account.phoneChangeHint':
        'If you change the number, you will have to verify it by SMS in the '
        'pop-up that opens after you save. The number does not change until it '
        'is verified.',
    'account.phoneNotChanged':
        'The number was not verified; your saved number is unchanged.',
    // Phone verification errors (not present in the generated dictionary)
    'phoneVerify.error.browserCanceled':
        'Security check was not completed: the browser window that opened was '
        'closed. Please tap "Send Code" again and wait until the window '
        'closes by itself.',
    'phoneVerify.error.browserAlreadyOpen':
        'A verification is already in progress. Please finish the open '
        'verification window, or try again in a few seconds.',
    'phoneVerify.error.network':
        'Could not reach the network. Check your connection and try again.',
    'phoneVerify.error.deviceCheckFailed':
        'Device verification could not be completed, so the SMS was not sent. '
        'Try again on a device with Google Play Services; if the problem '
        'persists, update the app.',
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
    'clubEvents.group.pending': 'On Hold',
    'clubEvents.group.past': 'Past',
    'clubEvents.empty.active':
        'No active events. Use the + button below to create one.',
    'clubEvents.empty.pending': 'No events on hold.',
    'clubEvents.empty.past': 'No past events.',
    'clubEvents.feedback.loadError': 'Events could not be loaded.',
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

    'clubEvents.session.title': 'Sessions',
    'clubEvents.session.notStarted': 'No session started (0/{{total}})',
    'clubEvents.session.active': 'Active session: {{current}}/{{total}}',
    'clubEvents.session.lastActive': 'Last session active: {{total}}/{{total}}',
    'clubEvents.session.allDone':
        'All sessions completed ({{total}}/{{total}})',
    'clubEvents.session.start': 'Start Session',
    'clubEvents.session.advance': 'Advance Session (session {{next}})',
    // Progress is shown by the bar now; these lines carry no counters.
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
    'clubEvents.session.undone':
        'Back on session {{session}}. Its QR is valid again.',
    'clubEvents.session.undoneToStart':
        'Sessions reset to the start. QR check-ins are paused for now.',
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
    'clubEvents.session.qrHint':
        'Project this code; students scan it from their own phones.',
    'clubEvents.session.qrError': 'The QR image could not be loaded.',

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
        'The document reached {{count}} students; {{failed}} failed. Use the '
        'send button on the document to try again.',
    'clubEvents.certificate.redistribute': 'Distribute this document',
    'clubEvents.certificate.distributedCount': 'Sent to {{count}} students',
    'clubEvents.certificate.notDistributed': 'Not sent to anyone yet',
    'clubEvents.certificate.sourceMissing':
        'The document file could not be read. Delete it and upload it again.',
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
        'The document could not be downloaded from this link. Make sure the '
        'link is publicly accessible.',
    'clubEvents.certificate.linkInvalid':
        'The pasted text is neither a document link nor a file path on this '
        'device.',
    'clubEvents.certificate.tooLarge': 'The file can be at most 10 MB.',
    'clubEvents.certificate.invalidType':
        'Only PDF, JPG or PNG files can be uploaded.',
    'clubEvents.certificate.pickerError':
        'The file picker could not be opened. Check the app\'s file access '
        'permission.',
    'clubEvents.certificate.readError':
        'The selected file could not be read. Download it to your phone first, '
        'then try again.',
    'clubEvents.certificate.sending':
        'Sending certificates ({{done}}/{{total}})...',
    'clubEvents.certificate.sent': 'Certificate sent to {{count}} students.',
    'clubEvents.certificate.error':
        'Something went wrong while distributing. Please try again.',
    'clubEvents.certificate.permissionError':
        'Permission error: publish storage.rules and firestore.rules.',
    'clubEvents.certificate.authError':
        'Your session could not be verified. Please sign in again.',
    'clubEvents.certificate.quotaError': 'The Storage quota is full.',
    'clubEvents.certificate.storageError':
        'Storage could not be reached. Check that Storage is enabled and the '
        'bucket name is correct in the Firebase Console.',
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
        'You entered a location name but no coordinates.',
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
        'The image is {{size}} KB — the limit is {{limit}} KB. Pick a smaller '
        'one or paste an image address instead.',
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
        'Permission error: storage rules do not allow document upload.',

    'clubScan.otherEvent': 'This QR belongs to a different event.',
    'clubScan.notOwner': 'This event does not belong to your club.',
    'clubScan.pastEvent': 'QR check-in only works for ongoing/upcoming events.',
    'clubScan.notRegistered':
        'This student has no registration for this event.',
    'clubScan.alreadyCheckedIn': '{{name}} has already checked in.',
    'clubScan.sessionNotStarted': 'Start the session first.',
    'clubScan.alreadyInSession':
        '{{name}} already checked in for this session ({{current}}/{{total}}).',
    'clubScan.missingLocation':
        'The QR has no location data — the student must regenerate it.',
    'clubScan.tooFar':
        'The student is outside the event location — {{distance}} away (max {{radius}} m).',
    'clubScan.success': 'Check-in confirmed for {{name}}.',
    'clubScan.sessionSuccess':
        'Session {{current}} confirmed for {{name}} (attendance {{attended}}/{{total}}).',

    'clubPending.notApprovedYet':
        'Approval has not arrived yet. This page updates itself once an '
        'administrator reviews your documents.',
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

    'admin.ban.searchPlaceholder': 'Search student, university, city...',
    'admin.ban.empty': 'No matching student found.',
    'admin.ban.studentCount': '{{count}} students',
    'admin.ban.banButton': 'Block',
    'admin.ban.unbanButton': 'Unblock',
    'admin.ban.confirmBan':
        'Block {{name}}? They will be signed out and cannot log in.',
    'admin.ban.confirmUnban': 'Remove the block for {{name}}?',

    // Connectivity
    'offline.banner': 'No internet connection',
    'offline.bannerDesc':
        'You can continue where you left off once you are back online.',
    'offline.loginBlocked':
        'No internet connection. Check your connection to sign in.',
    'offline.actionBlocked':
        'The internet connection was lost. Try again once you are back online.',
    'offline.restored': 'Internet connection restored.',

    // Club logo (account screen + event window badge)
    'clubAccount.logo': 'Club Logo',
    'clubAccount.feedback.logoUpdated': 'Club logo updated.',
    'clubCreateEvent.image.autoShort':
        'With no image, the cover shows a gray Regipass logo.',

    'screen.comingSoon': 'This section is under construction.',
    'screen.comingSoonDesc':
        'Club and admin screens will be completed in the next stage.',
  },
};
