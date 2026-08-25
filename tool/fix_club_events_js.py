"""club-events.js icindeki gomulu metinleri duzeltir.

Iki is birden:
  1. ASCII Turkce -> dogru Turkce (Gecmis -> Gecmis degil, Geçmiş).
  2. Sozlukte karsiligi olan metinleri t() cagrisina baglar; boylece dil
     degistirildiginde bu metinler de cevrilir.

Degistirmeler birebir dize esleme ile yapilir (regex yok), bulunamayan her
kalip ekrana yazilir — sessizce atlanmaz.
"""
import sys

TARGET = 'js/pages/club-events.js'

# (aranan, yerine) — birebir dize
REPLACEMENTS: list[tuple[str, str]] = [
    # ── i18n'e baglananlar (anahtarlar language.js'te mevcut) ────────
    ('"Ogrencileri Goruntule"', 't("clubEvents.modal.viewStudents")'),
    ('viewStudentsBtn.textContent = "Yukleniyor..."',
     'viewStudentsBtn.textContent = t("common.loading")'),
    ('const defaultLabel = "Excel Indir"',
     'const defaultLabel = t("clubEvents.modal.downloadExcel")'),

    # ── ASCII Turkce -> dogru Turkce ────────────────────────────────
    ('"Etkinligi Sil (Her Yerden)"', '"Etkinliği Sil (Her Yerden)"'),
    ('"Kulup Listesinden Kaldir"', '"Kulüp Listesinden Kaldır"'),
    ('>Duzenle<', '>Düzenle<'),
    ('deleteButton.textContent = "Isleniyor..."',
     'deleteButton.textContent = "İşleniyor..."'),
    ('setFeedback("Etkinlik tum kullanicilardan kaldirildi.")',
     'setFeedback("Etkinlik tüm kullanıcılardan kaldırıldı.")'),
    ('setFeedback("Gecmis etkinlik kulup listesinden kaldirildi.")',
     'setFeedback("Geçmiş etkinlik kulüp listesinden kaldırıldı.")'),
    ('setFeedback("Etkinlik silinemedi. Lutfen tekrar dene.", true)',
     'setFeedback("Etkinlik silinemedi. Lütfen tekrar dene.", true)'),
    ('setFeedback("Belge hakki kazanan ogrenciler hesaplaniyor...")',
     'setFeedback("Belge hakkı kazanan öğrenciler hesaplanıyor...")'),
    ('setFeedback("Belge hakki kazanan ogrenci bulunamadi.", true)',
     'setFeedback("Belge hakkı kazanan öğrenci bulunamadı.", true)'),
    ('setQrScannerStatus("Tarama durduruldu. Yeniden baslatmak icin QR Okut\'a tikla.")',
     'setQrScannerStatus("Tarama durduruldu. Yeniden başlatmak için QR Okut\'a tıkla.")'),
    ('setFeedback("Etkinlik kayitlari durduruldu.")',
     'setFeedback("Etkinlik kayıtları durduruldu.")'),
    ('setFeedback("Kayitlar durdurulamadi. Lutfen tekrar dene.", true)',
     'setFeedback("Kayıtlar durdurulamadı. Lütfen tekrar dene.", true)'),
    ('"Kayitlari Durdur"', '"Kayıtları Durdur"'),
    ('"Kayitlar Durduruldu"', '"Kayıtlar Durduruldu"'),
    ('"Gecmis Etkinlik"', '"Geçmiş Etkinlik"'),
    ('"Basvuru Kapali"', '"Başvuru Kapalı"'),
    ('"Basvuru Acik"', '"Başvuru Açık"'),
    ('"Bolum + Universite"', '"Bölüm + Üniversite"'),
    ('"Universiteye Ozel"', '"Üniversiteye Özel"'),
    ('"Herkese Acik"', '"Herkese Açık"'),
    ('"Tum Universiteler"', '"Tüm Üniversiteler"'),
    ('"Tum Bolumler"', '"Tüm Bölümler"'),
    ('"Ogrenci"', '"Öğrenci"'),
    ('"Kulup"', '"Kulüp"'),
    ('"Etkinlik"', '"Etkinlik"'),
    ('"Aciklama bulunmuyor."', '"Açıklama bulunmuyor."'),
    ('`Amac: ${', '`Amaç: ${'),
    ('"Aktif etkinlik bulunmuyor. Yeni etkinlik olusturabilirsin."',
     '"Aktif etkinlik bulunmuyor. Yeni etkinlik oluşturabilirsin."'),
    ('"Gecmis etkinlik bulunmuyor."', '"Geçmiş etkinlik bulunmuyor."'),
    ('"Bu etkinligi silmek istedigine emin misin?"',
     '"Bu etkinliği silmek istediğine emin misin?"'),
    ('"Etkinlikler yuklenirken bir hata olustu."',
     '"Etkinlikler yüklenirken bir hata oluştu."'),
    ('"Ogrenci listesi yuklenemedi. Lutfen tekrar dene."',
     '"Öğrenci listesi yüklenemedi. Lütfen tekrar dene."'),
    ('"Excel dosyasi olusturulamadi. Lutfen tekrar dene."',
     '"Excel dosyası oluşturulamadı. Lütfen tekrar dene."'),
    ('"Bu etkinlik icin indirilecek ogrenci kaydi bulunmuyor."',
     '"Bu etkinlik için indirilecek öğrenci kaydı bulunmuyor."'),
    ('"Ogrenci listesi genisletilmis sutunlarla Excel dosyasi olarak indirildi."',
     '"Öğrenci listesi genişletilmiş sütunlarla Excel dosyası olarak indirildi."'),
    ('"Bu etkinlik icin kayitlari durdurmak istiyor musun?"',
     '"Bu etkinlik için kayıtları durdurmak istiyor musun?"'),
    ('"QR okutma sadece devam eden/yaklasan etkinliklerde kullanilabilir."',
     '"QR okutma yalnızca devam eden/yaklaşan etkinliklerde kullanılabilir."'),
    ('"Kamera taramasi icin HTTPS veya localhost gereklidir."',
     '"Kamera taraması için HTTPS veya localhost gereklidir."'),
    ('"Kamera aciliyor..."', '"Kamera açılıyor..."'),
    ('"Kamerayi ogrencinin QR koduna tut."', '"Kamerayı öğrencinin QR koduna tut."'),
    ('"Kamerayi QR koda tut."', '"Kamerayı QR koda tut."'),
    ('"Sonraki ogrenci icin hazir."', '"Sonraki öğrenci için hazır."'),
    ('"Kamera acilamadi. Kamera iznini kontrol et veya kodu manuel yapistir."',
     '"Kamera açılamadı. Kamera iznini kontrol et veya kodu elle yapıştır."'),
    ('"Etkinlik secimi bulunamadi."', '"Etkinlik seçimi bulunamadı."'),
    ('"Bu QR kod baska bir etkinlige ait."', '"Bu QR kod başka bir etkinliğe ait."'),
    ('"Bu ogrencinin kaydi bu etkinlikte bulunamadi."',
     '"Bu öğrencinin kaydı bu etkinlikte bulunamadı."'),
    ('"Etkinlik oturumlari tamamlandi — QR girisi kapali."',
     '"Etkinlik oturumları tamamlandı — QR girişi kapalı."'),
    ('"Once oturumu baslatin (Oturumu Baslat butonu)."',
     '"Önce oturumu başlatın (Oturumu Başlat butonu)."'),
    ('"Yalnizca PDF veya gorsel belge yukleyebilirsin."',
     '"Yalnızca PDF veya görsel belge yükleyebilirsin."'),
    ('"Belge en fazla 10 MB olabilir."', '"Belge en fazla 10 MB olabilir."'),
    ('"Belge okunuyor, isim alani araniyor..."',
     '"Belge okunuyor, isim alanı aranıyor..."'),
    ('"Yetki hatasi: storage.rules ve firestore.rules dosyalarini deploy edin."',
     '"Yetki hatası: storage.rules ve firestore.rules dosyalarını yayınlayın."'),
    ('"Belge dagitimi sirasinda hata olustu. Lutfen tekrar dene."',
     '"Belge dağıtımı sırasında hata oluştu. Lütfen tekrar dene."'),
    ('"Oturum baslatilmadi"', '"Oturum başlatılmadı"'),
    ('`Oturumu Ilerlet (${', '`Oturumu İlerlet (${'),
    ('"Ogrenciler bu oturum icin QR okutabilir."',
     '"Öğrenciler bu oturum için QR okutabilir."'),
    ('. oturum girisi onaylandi', '. oturum girişi onaylandı'),
    ('zaten giris yapmis.', 'zaten giriş yapmış.'),
    ('zaten giris yapti.', 'zaten giriş yaptı.'),
    ('icin giris onaylandi.', 'için giriş onaylandı.'),
    ('Ogrenci etkinlik konumunun disinda', 'Öğrenci etkinlik konumunun dışında'),
    ('QR kodda konum bilgisi yok — ogrenci QR\'i yeniden olusturmali.',
     'QR kodda konum bilgisi yok — öğrenci QR\'ını yeniden oluşturmalı.'),
    ('| Giris Onayli', '| Giriş Onaylı'),
    ('| ✓ Belge Hakki', '| ✓ Belge Hakkı'),
    ('Tum oturumlar tamamlandi (', 'Tüm oturumlar tamamlandı ('),
    ('`Aktif oturum: ${', '`Aktif oturum: ${'),
    ('`Son oturum aktif: ${', '`Son oturum aktif: ${'),
    ('. Oturum QR`', '. Oturum QR\'ı`'),
    ('Son basvuru: ${deadlineLabel} | Ucret: ${feeInfo} | Kota: ${quota} | Hedef:',
     'Son başvuru: ${deadlineLabel} | Ücret: ${feeInfo} | Kota: ${quota} | Hedef:'),
    ('Ucret: ${event.feeInfo} | Kota: ${event.quota}',
     'Ücret: ${event.feeInfo} | Kota: ${event.quota}'),
]


def main() -> None:
    dry_run = '--dry-run' in sys.argv

    # newline='' : LF dosyayi CRLF'e cevirmemek icin.
    src = open(TARGET, encoding='utf-8-sig', newline='').read()
    original = src

    applied = 0
    not_found = []
    for needle, replacement in REPLACEMENTS:
        if needle not in src:
            not_found.append(needle)
            continue
        src = src.replace(needle, replacement)
        applied += 1

    print(f'uygulanan: {applied} / {len(REPLACEMENTS)}')
    if not_found:
        print(f'bulunamadi ({len(not_found)}):')
        for n in not_found:
            print('   ', n[:70])

    if dry_run:
        print('(dry-run — dosya yazilmadi)')
        return
    if src == original:
        print('degisiklik yok')
        return

    with open(TARGET, 'w', encoding='utf-8', newline='') as f:
        f.write(src)
    print(f'{TARGET} guncellendi')


if __name__ == '__main__':
    main()
