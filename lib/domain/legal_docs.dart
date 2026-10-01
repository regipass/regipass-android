/// Kayıt ekranındaki zorunlu onay metinlerinin kaynağı.
///
/// Metinler Regipass-Web/docs/legal/*.txt dosyalarından
/// `python3 scripts/build-legal.py --dart <bu dosya>` ile üretilir.
/// Elle düzenlenmemelidir — kaynak metni değiştirip betiği çalıştırın.
library;

/// Onay kaydına yazılan belge sürümü.
///
/// KVKK Aydınlatma Metni madde 7, onay kaydında "onaylanan metin sürümü"nün
/// de saklanmasını istiyor: kullanıcının hangi metne onay verdiği sonradan
/// ispatlanabilmeli. Belgeler güncellendiğinde bu değer de güncellenmelidir.
const String kLegalDocsVersion = 'v1.1';

/// Bir hukuki belgenin dile göre başlık ve gövdesi.
class LegalDocument {
  const LegalDocument({
    required this.titleTr,
    required this.titleEn,
    required this.bodyTr,
    required this.bodyEn,
  });

  final String titleTr;
  final String titleEn;
  final String bodyTr;
  final String bodyEn;

  String title(String language) => language == 'en' ? titleEn : titleTr;
  String body(String language) => language == 'en' ? bodyEn : bodyTr;
}

const LegalDocument kUserClubAgreement = LegalDocument(
  titleTr: 'Kullanıcı ve Organizatör Sözleşmesi',
  titleEn: 'User and Organizer Agreement',
  bodyTr: _contractTr,
  bodyEn: _contractEn,
);

const LegalDocument kKvkkNotice = LegalDocument(
  titleTr: 'KVKK Aydınlatma Metni',
  titleEn: 'Data Protection Notice',
  bodyTr: _kvkkTr,
  bodyEn: _kvkkEn,
);

const String _contractTr = '''
REGİPASS KULLANICI VE ORGANİZATÖR SÖZLEŞMESİ
Son güncelleme tarihi: 02.10.2026 · Sürüm v1.1

ÖNEMLİ: Lütfen bu Sözleşme'yi dikkatle okuyun. Platform'u kullanarak, hesap oluşturarak veya hesap oluşturmadan bir Etkinliğe kaydolarak bu Sözleşme'yi kabul etmiş olursunuz. Özellikle 6, 7, 9, 10, 16-19, 23, 24 ve 25. maddeler Regipass'in sorumluluğunu sınırlayan ve size yükümlülük getiren hükümler içerir; bu hükümler okunması kolay olsun diye ayrıca vurgulanmıştır.

1. Taraflar ve Tanımlar
1.1. İşbu Sözleşme ("Sözleşme"), bir yanda Regipass (iletişim: product@regipass.com) ("Regipass", "biz") ile diğer yanda:
— Platform'u indiren, kaydolan, hesap oluşturmadan bir Etkinliğe kaydolan veya Platform'u herhangi bir şekilde kullanan gerçek kişi ("Kullanıcı", "Katılımcı", "siz") ve/veya
— Platform üzerinde organizatör hesabı oluşturan öğrenci kulübü, topluluk, kuruluş veya bunlar adına hareket eden yetkili kişi ("Organizatör")
arasında, ilgili tarafın Sözleşme'yi elektronik ortamda onaylaması veya Platform'u kullanmaya başlaması ile yürürlüğe girer. Aynı kişi hem Katılımcı hem de bir Organizatör'ü temsil eden yetkili olabilir; bu durumda Sözleşme'nin hem Bölüm A hem Bölüm B hükümleri o kişi için geçerlidir. Organizatör adına işlem yapan kişi, bu işlemi yapmaya yetkili olduğunu; yetkisiz olması hâlinde doğacak her türlü sonuçtan Organizatör ile birlikte müteselsilen sorumlu olduğunu kabul, beyan ve taahhüt eder.
1.2. Tanımlar:
Platform: Regipass mobil uygulamaları (iOS ve Android), regipass.com ve alt alan adlarındaki web siteleri (demo.regipass.com dahil), Etkinlik Linki sayfaları ve ilgili tüm dijital hizmetler.
Katılımcı: Platform'da Etkinlikleri keşfeden, Etkinliklere kaydolan ve katılan gerçek kişi. Hesap oluşturmadan Etkinlik Linki üzerinden kaydolan kişi ("Misafir Katılımcı") da bu Sözleşme'de Katılımcı sayılır.
Organizatör: Platform üzerinde Etkinlik oluşturan, yayınlayan, yöneten ve Katılımcıların kaydını, girişini ve yoklamasını takip eden kulüp, topluluk, kuruluş ya da bunların yetkilisi.
Etkinlik: Bir Organizatör tarafından Platform üzerinden duyurulan veya yönetilen her türlü faaliyet, toplantı, seminer, konser, gezi, sosyal, kültürel, sportif veya eğitsel organizasyon.
Etkinlik Linki: Bir Etkinliğe özel, Platform tarafından üretilen veya Organizatör'ün belirlediği özel adla oluşturulan bağlantı (ör. regipass.com/e/K7P2QX), bu bağlantıya ait QR afişi ve kayıt sayfası.
Yalnızca Linkle Etkinlik: Keşfet ekranında listelenmeyen, yalnızca Etkinlik Linki'ne sahip kişilerin görüp kaydolabildiği Etkinlik.
Bilet: Katılımcıya kayıt sonrasında verilen, QR kod içeren dijital giriş belgesi (Apple Wallet / Google Wallet kartları dahil).
Katılım Belgesi: Katılımcının bir Etkinliğe katılımını, Organizatör'ün belirlediği koşullara göre gösteren ve Platform üzerinden oluşturulan dijital belge (önceki sürümlerde "Sertifika").
İçerik: Organizatörler veya Katılımcılar tarafından Platform'a yüklenen veya Platform aracılığıyla paylaşılan her türlü metin, görsel, logo, belge, etkinlik detayı, değerlendirme, mesaj ve diğer materyal.
Demo: demo.regipass.com adresinde ve "Regipass Demo" uygulamasında sunulan, uydurma verilerle çalışan ve düzenli olarak sıfırlanan tanıtım ortamı.

2. Hizmetin Niteliği
2.1. Regipass; Katılımcıların Etkinlikleri keşfetmesini, Etkinliklere hesap oluşturarak veya hesap oluşturmadan kaydolmasını, QR bilet ve konum doğrulaması ile giriş/yoklama yapmasını ve Katılım Belgelerine erişmesini; Organizatörlerin de Etkinlik oluşturma, duyurma, kayıt toplama, kapı ve yoklama yönetimi, bildirim gönderme ve Katılım Belgesi üretme işlemlerini yapmasını sağlayan bir aracı teknoloji platformudur.
2.2. Regipass, 6563 sayılı Elektronik Ticaretin Düzenlenmesi Hakkında Kanun ve 5651 sayılı Kanun kapsamında yer sağlayıcı ve aracı hizmet sağlayıcı sıfatıyla hareket eder. Regipass Etkinlikleri düzenlemez, organize etmez, yönetmez, denetlemez ve Etkinliklerin, Organizatör ile Katılımcı arasındaki ilişkinin veya bu ilişkiden doğan herhangi bir sözleşmenin tarafı değildir. Etkinlikler münhasıran Organizatör'ün sorumluluğunda ve inisiyatifindedir.
2.3. Regipass; hiçbir üniversite, öğrenci topluluğu, kamu kurumu veya Organizatör ile resmî bir bağlılık, ortaklık, temsil, acentelik, işçi-işveren veya iş ortaklığı ilişkisi içinde değildir. Bir Organizatör'ün Platform'da yer alması, Regipass tarafından desteklendiği, onaylandığı veya güvenilir bulunduğu anlamına gelmez.
2.4. Platform, bir ödeme kuruluşu, emanet (escrow) hizmeti, bilet satış acentesi, organizasyon firması, sigorta veya güvenlik hizmeti değildir.

3. Sözleşmenin Kapsamı ve Kullanım Şartları
3.1. Sözleşme üç bölümden oluşur: Bölüm A (madde 4-12) Katılımcılar için, Bölüm B (madde 13-19) Organizatörler için, Bölüm C (madde 20-34) herkes için geçerlidir.
3.2. Platform'u yalnızca 18 yaşını doldurmuş kişiler kullanabilir. Platform, 18 yaşını doldurmuş herkese açıktır; Organizatör bir Etkinliği yalnızca belirli üniversite, bölüm veya gruplara açabilir. 18 yaşından küçük olduğu anlaşılan kişilerin hesapları ve kayıtları bildirimde bulunulmaksızın kapatılır veya silinir. Yaşınızı yanlış beyan etmenizden doğan her türlü sonuçtan siz sorumlusunuz.
3.3. Regipass, Platform'un kapsamını, özelliklerini, arayüzünü, kapasitesini ve ücretlendirme modelini değiştirme; yeni özellikler ekleme veya mevcut özellikleri kaldırma; ücretli paket veya abonelik oluşturma ya da ücretsiz özellikleri ücretli hâle getirme hakkını saklı tutar. Ücretlendirmeye ilişkin değişiklikler yürürlüğe girmeden önce Platform üzerinden duyurulur. Regipass, hiç kimseye süresiz veya ömür boyu ücretsiz kullanım hakkı taahhüt etmez.

BÖLÜM A — KATILIMCILARA ÖZEL HÜKÜMLER

4. Hesap ve Doğru Bilgi
4.1. Kayıt sırasında ve sonrasında verdiğiniz bilgilerin (ad-soyad, e-posta, telefon, şehir, üniversite, bölüm, sınıf, öğrenci numarası, cinsiyet, profil fotoğrafı vb.) doğru, güncel, eksiksiz ve size ait olduğunu kabul, beyan ve taahhüt edersiniz. Başkasının adına, başkasının telefon numarası veya e-postasıyla hesap açmak ya da kayıt yapmak yasaktır.
4.2. Profil fotoğrafınız, kapıda kimlik doğrulama amacıyla kaydolduğunuz Etkinliğin Organizatör'üne gösterilir; size ait olmayan, yanıltıcı veya uygunsuz fotoğraf yükleyemezsiniz.
4.3. Hesap bilgilerinizin (şifre, telefonunuza gelen doğrulama kodları, Bilet QR kodunuz dahil) gizliliğinden ve hesabınız ya da Biletiniz üzerinden yapılan tüm işlemlerden münhasıran siz sorumlusunuz. QR kodunuzun veya Biletinizin ekran görüntüsünü başkasıyla paylaşmanız hâlinde doğacak sonuçlardan Regipass sorumlu değildir. Yetkisiz kullanım şüphesini derhal bize bildirmelisiniz.
4.4. Yanlış, eksik veya başkasına ait bilgi verilmesi; kayıtların, yoklamaların ve Katılım Belgelerinin geçersiz sayılmasına ve hesabın kapatılmasına yol açabilir.

5. Hesap Oluşturmadan (Misafir) Kayıt ve Etkinlik Linkleri
5.1. Bazı Etkinliklere, Etkinlik Linki üzerinden hesap oluşturmadan kaydolabilirsiniz. Bu durumda telefon numaranız SMS ile doğrulanır; ad-soyad, telefon, e-posta ve (istenirse) üniversite/bölüm bilgileriniz alınır ve kaydolduğunuz Etkinliğin Organizatör'ü ile paylaşılır. Misafir kaydında da bu Sözleşme ve KVKK Aydınlatma Metni geçerlidir.
5.2. Kayıt formunda "Hesabım da oluşturulsun" seçeneğini işaretli bırakırsanız, verdiğiniz bilgilerle sizin adınıza bir Regipass hesabı açılır; bu seçeneği kaldırabilirsiniz. Misafir kayıtlarınız, aynı telefon numarasıyla daha sonra hesap açmanız hâlinde hesabınıza aktarılabilir.
5.3. Misafir Katılımcı'nın kişisel verileri, Etkinliğin bitiminden itibaren yaklaşık 30 gün sonra anonimleştirilir veya silinir; bu süreden sonra Bilet, kayıt ve Katılım Belgesi bilgilerine erişilemeyebilir. Katılım Belgenizi bu süre içinde indirmek sizin sorumluluğunuzdadır.
5.4. Etkinlik Linki'ne sahip olan herkes, Etkinliği (Yalnızca Linkle Etkinlikler dahil) görebilir ve kayıt koşullarını sağlıyorsa kaydolabilir. Bir linkin kimlerle paylaşıldığını, yeniden paylaşıldığını, sosyal medyada yayıldığını veya bir QR afişinin nereye asıldığını Regipass denetleyemez; linkin istenmeyen kişilere ulaşmasından doğan sonuçlardan Regipass sorumlu değildir.
5.5. SMS doğrulama kodları üçüncü taraf altyapılar üzerinden gönderilir. SMS'in gecikmesi, hiç ulaşmaması, operatör kaynaklı engeller veya numaranızın başka biri tarafından kullanılması gibi durumlardan Regipass sorumlu tutulamaz.

6. Etkinlikler ve İçeriklerden Sorumluluğun Reddi
6.1. Etkinlik bilgileri, açıklamaları, görselleri, tarih ve saatleri, yeri, kontenjanı, ücreti, katılım koşulları ve diğer tüm İçerikler Organizatör tarafından oluşturulur; bunların doğruluğundan, hukuka uygunluğundan ve güncelliğinden münhasıran Organizatör sorumludur.
6.2. Regipass; bir Etkinliğin gerçek olup olmadığını, gerçekleşip gerçekleşmeyeceğini, ertelenip iptal edilip edilmeyeceğini, duyurulduğu gibi yapılıp yapılmayacağını, içeriğinin doğruluğunu, güvenliğini, sağlık ve hijyen koşullarını, yasal izinlerinin bulunup bulunmadığını veya Organizatör'ün taahhütlerini yerine getirip getirmeyeceğini garanti etmez ve bunları önceden doğrulama yükümlülüğü altında değildir. Bir Etkinliğin sahte, yanıltıcı veya hiç var olmayan bir etkinlik ("naylon etkinlik") olması hâlinde dahi, Regipass bu Etkinliğe güvenerek hareket etmenizden (yol, konaklama, ücret, zaman kaybı dahil) doğabilecek maddi veya manevi zarardan sorumlu tutulamaz.
6.3. Bir Etkinliğe katılım kararı tamamen size aittir. Etkinlik sırasında veya Etkinlik nedeniyle meydana gelebilecek kaza, yaralanma, sağlık sorunu, hırsızlık, kayıp, taciz, kavga, gıda zehirlenmesi, ulaşım sorunu veya her türlü kişisel ya da maddi zarar bakımından muhatabınız Organizatör ve varsa olaya sebep olan kişilerdir; Regipass Etkinliğin fiziksel olarak yürütülmesine hiçbir surette karışmadığından bu zararlardan sorumlu değildir.
6.4. Organizatörün Platform'a kabul edilmeden önce Regipass tarafından bazı belgelerinin istenmesi veya incelenmesi, Organizatör'ün güvenilir, yetkili, dürüst veya hukuka uygun hareket edeceğine dair bir garanti, tasdik veya onay niteliği taşımaz.

7. Etkinlik Ücretleri ve Ödeme — Katılımcı Açısından
7.1. Bazı Etkinlikler ücretli olabilir. Ücretin belirlenmesi, tahsili, iadesi ve yönetimi münhasıran Organizatör'ün sorumluluğundadır. Regipass bu ödemelerde ödeme kuruluşu, aracı ödeme hizmeti sağlayıcısı, emanetçi (escrow) veya taraf değildir; Platform üzerinden ödeme alınmaz.
7.2. Ücretli bir Etkinliğe kaydolduğunuzda, Organizatör'ün Platform'a kendisinin girdiği yetkili temsilcisinin iletişim bilgileri (telefon ve/veya e-posta) gösterilir ve ödemeyi bu kişiyle doğrudan organize etmeniz istenir. Ödeme tamamen Regipass'in sistemleri dışında, sizinle Organizatör arasında gerçekleşir.
7.3. Regipass; gösterilen iletişim bilgisinin doğruluğundan, iletişime geçtiğiniz kişinin gerçekten yetkili olup olmadığından, ödemenin yapılıp yapılmadığından veya Organizatör tarafından "Ödendi" olarak işaretlenip işaretlenmediğinden, ücretin iadesinden, kullanım amacından, dolandırıcılık veya güven ilişkisi sorunlarından hiçbir şekilde sorumlu değildir. Ödeme yapmadan önce muhatabınızı ve ödeme koşullarını teyit etmeniz önerilir. Bu konudaki tüm uyuşmazlıklarda muhatabınız Organizatör'dür; Regipass arabuluculuk yapma yükümlülüğü altında değildir.
7.4. ZORUNLU ONAY — KAYIT ALTINA ALINIR. Ücretli bir Etkinliğe kaydı tamamlamadan önce aşağıdaki onayı ayrıca ve açıkça vermeniz istenir ve bu onay kayıt altına alınır:
"Ödeme sürecinin, Organizatör'ün Platform'a kendisinin girdiği yetkili temsilci iletişim bilgileri (telefon/e-posta) üzerinden ve Regipass'in dışında, doğrudan Organizatör ile gerçekleştiğini; bu iletişim bilgisinin Organizatör tarafından girildiğini ve doğruluğunun Regipass tarafından teyit edilmediğini; karşı tarafın gerçekten yetkili olmayabileceğini, dolandırıcılık veya ödemenin karşılıksız kalması dahil hiçbir sonucun garanti edilmediğini; ve bu sürecin hiçbir aşamasında Regipass'in sorumlu olmadığını anladım."
Bu onay verilmeden ücretli Etkinlik kaydı tamamlanamaz.

8. Kayıt, Kontenjan, Bekleme Listesi ve İptal
8.1. Kayıt, kontenjan, son başvuru tarihi, bekleme listesi ve kayıt iptali kuralları Organizatör tarafından belirlenir ve Platform tarafından otomatik olarak uygulanır. Teknik nedenlerle (yoğunluk, eşzamanlı başvurular, bağlantı sorunları) bir kaydın oluşmaması, kontenjanın beklenenden önce dolması, bekleme listesindeki sıranın değişmesi veya size yer açıldığına dair bildirimin gecikmesi gibi durumlardan Regipass sorumlu değildir.
8.2. Organizatör; Etkinliği iptal edebilir, değiştirebilir, kaydınızı kaldırabilir veya sizi kendi Etkinliklerine katılmaktan engelleyebilir. Bu kararlar Organizatör'e aittir.

9. Bilet, Kapıda Giriş, Konum Doğrulama ve Yoklama
9.1. Girişte ve oturum yoklamalarında QR kod okutma ve, Organizatör tarafından açıldıysa, konum doğrulaması kullanılır. Konumunuz yalnızca okutma anında ve tek seferlik alınır; arka planda konum takibi yapılmaz. Konumunuzun kendisi saklanmaz; yalnızca Etkinlik noktasına olan uzaklık ve konum doğruluğu bilgisi kayıt altına alınır.
9.2. Cihazınızın konum servislerinin hatalı veya kapalı olması, GPS sapması, kamera ya da internet sorunları, QR kodun okunamaması, Organizatör'ün internetsiz kapı modunu kullanması, eşitleme gecikmeleri veya Organizatör'ün yanlış işlem yapması nedeniyle girişinizin veya yoklamanızın kaydedilmemesi ya da hatalı kaydedilmesi mümkündür. Bu durumlar ve bunların sonucunda Etkinliğe alınmamanız veya Katılım Belgesi alamamanız nedeniyle Regipass sorumlu tutulamaz; bu konudaki başvurularınızı Organizatör'e yapmalısınız.
9.3. Sahte konum, başkasının yerine okutma, QR kodu kopyalama veya yoklama sistemini atlatmaya yönelik her türlü girişim yasaktır.

10. Katılım Belgeleri
10.1. Katılım Belgeleri, Organizatör'ün belirlediği koşullara (ör. yoklama sayısı), Organizatör'ün yüklediği şablona ve giriş/yoklama verilerine göre Platform tarafından oluşturulur. Belgenin içeriğinden, kime verileceğinden, verilmemesinden veya geri alınmasından Organizatör sorumludur.
10.2. Katılım Belgeleri resmî bir kurum, üniversite veya devlet tarafından onaylanmış belge değildir; yalnızca Organizatör'ün kendi koşullarına göre düzenlediği bir katılım belgesidir. Bir belgenin üçüncü kişilerce (işveren, okul, kurum vb.) kabul edilip edilmeyeceğini Regipass garanti etmez.
10.3. Her Katılım Belgesi üzerinde bir doğrulama kodu bulunur. Bu kodu bilen herkes, regipass.com üzerindeki doğrulama sayfasında belgenin geçerli olup olmadığını ve belge sahibinin adını, Etkinliğin adını ve tarihini görebilir. Belgenizi paylaştığınızda bu bilgilerin görülebileceğini kabul edersiniz.

11. Bildirimler, Değerlendirmeler ve Takip
11.1. Regipass ve Organizatörler; hesabınız, kayıtlarınız, Etkinlik değişiklikleri, hatırlatmalar, Katılım Belgeleri ve güvenlik konularında size uygulama içi bildirim, anlık bildirim, e-posta ve/veya SMS gönderebilir. Bildirimlerin zamanında ulaşacağı, hiç ulaşmayacağı veya spam klasörüne düşmeyeceği garanti edilmez; önemli bilgileri Platform'dan kontrol etmek sizin sorumluluğunuzdadır.
11.2. Ticari elektronik iletiler (kampanya bildirimleri) yalnızca 6563 sayılı Kanun uyarınca ayrıca alınan onayınızla gönderilir; bu onay varsayılan olarak kapalıdır ve Hesap ayarlarından dilediğiniz zaman ücretsiz olarak açıp kapatabilirsiniz.
11.2a. Organizatörlerin Etkinlikleri hakkında size gönderdiği mesajların içeriğinden ilgili Organizatör sorumludur; bu mesajlar Regipass tarafından önceden denetlenmez ve yalnızca iletilir. Uygunsuz bir mesajı product@regipass.com adresine bildirebilirsiniz.
11.3. Etkinlikler hakkında yaptığınız değerlendirmeler ve yorumlar ilgili Organizatör tarafından görülebilir. Değerlendirmelerinizin doğru, saygılı ve hukuka uygun olmasından siz sorumlusunuz.
11.4. Bir Organizatörü takip ettiğinizde, o Organizatör'ün yeni Etkinliklerine ilişkin bildirim alırsınız; takibi dilediğiniz zaman bırakabilirsiniz.

12. Katılımcının Yükümlülükleri ve Yasak Davranışlar
Madde 21'de sayılan yasak davranışlara ek olarak; Etkinliklere kaydolup gelmemeyi alışkanlık hâline getirmek, kontenjanı engellemek amacıyla toplu veya sahte kayıt yapmak, Organizatörleri veya diğer Katılımcıları taciz etmek, Etkinlik kurallarına ve Organizatör'ün makul talimatlarına uymamak yasaktır.

BÖLÜM B — ORGANİZATÖRLERE ÖZEL HÜKÜMLER

13. Organizatör Hesabı ve Onay Süreci
13.1. Organizatör hesabı, Regipass'in istediği belgelerin (ör. Kulüp Kuruluş Onay Belgesi, Yetkili Öğrenci Belgesi veya Regipass'in uygun gördüğü diğer belgeler) yüklenmesi ve Regipass'in onayı ile açılır. Regipass, bir başvuruyu gerekçe göstermeksizin reddetme, ek belge isteme veya onaylanmış bir hesabı sonradan askıya alma hakkına sahiptir.
13.2. Yüklenen belgelerin gerçek, geçerli ve güncel olduğundan, belgelerde adı geçen kişilerin onayının alındığından ve belge içeriğindeki kişisel verilerin hukuka uygun şekilde paylaşıldığından Organizatör sorumludur. Regipass'in belgeleri incelemesi, belgelerin gerçekliğini veya Organizatör'ün yetkisini tasdik ettiği anlamına gelmez.
13.3. Organizatör hesabını kullanan kişilerin değişmesi, kulübün kapanması, yetkili kişinin görevinin sona ermesi gibi durumlarda Regipass'e bildirimde bulunmak ve hesap erişimini güncellemek Organizatör'ün yükümlülüğüdür. Bildirim yapılana kadar hesap üzerinden yapılan tüm işlemlerden Organizatör sorumludur.

14. Organizatöre Sunulan Hizmet
14.1. Regipass, Organizatör'e; Etkinlik oluşturma ve duyurma, Etkinlik Linki ve QR afişi oluşturma, Yalnızca Linkle Etkinlik yayınlama, hesaplı ve hesapsız kayıt toplama, kontenjan ve bekleme listesi yönetimi, kapıda bilet okutma (internetsiz mod dahil), oturum yoklaması, katılımcılara mesaj ve bildirim gönderme, katılımcı listesini görüntüleme ve indirme, Etkinlik raporları, değerlendirmeler ve Katılım Belgesi üretme imkânları sunar.
14.2. Bu hizmetler "olduğu gibi" ve "mevcut olduğu ölçüde" sunulur. Regipass, özelliklerin her zaman çalışacağını, kesintisiz olacağını veya belirli bir Etkinlik için yeterli olacağını garanti etmez. Organizatör, Platform'da yaşanabilecek bir arıza veya kesintiye karşı (ör. yedek katılımcı listesi, kâğıt yoklama, alternatif giriş yöntemi) kendi önlemlerini almakla yükümlüdür.

15. Ücretlendirme — Organizatörler İçin
15.1. Regipass hizmetleri, Regipass'in belirlediği ve zaman zaman güncelleyebileceği paket/abonelik modeline tabidir. Mevcut ücretsiz kullanım imkânları (varsa deneme süresi dahil) Regipass'in takdirinde olup önceden duyurularak değiştirilebilir, sınırlandırılabilir veya sona erdirilebilir.
15.2. Ücretli bir pakete geçiş hâlinde güncel fiyat ve ödeme koşulları ayrıca bildirilir. Regipass, ödemesini zamanında yapmayan Organizatör'ün hesabını veya belirli özelliklerini askıya alabilir.

16. Organizatör'ün Yükümlülükleri
Organizatör aşağıdakileri kabul, beyan ve taahhüt eder:
16.1. Platform'a girdiği tüm Etkinlik bilgilerinin, katılım koşullarının, ücretlerin ve Katılım Belgesi koşullarının doğru, güncel ve yanıltıcı olmadığını; değişiklikleri zamanında güncelleyeceğini ve gerektiğinde Katılımcıları bilgilendireceğini;
16.2. Etkinliklerin ve tüm İçeriklerin yürürlükteki mevzuata, kamu düzenine ve genel ahlaka uygun olduğunu; madde 21'de sayılan hiçbir İçerik veya Etkinlik oluşturmayacağını;
16.3. Etkinliğin güvenli bir şekilde yürütülmesinden; mekân, kapasite, yangın, ilk yardım, güvenlik, sigorta, alkol, gıda, ses ve benzeri konulardaki tüm izin, ruhsat ve tedbirlerden; üniversite veya mekân yönetiminin kurallarına uyulmasından; katılımcıların can ve mal güvenliğinden ve Etkinlik sırasında doğabilecek her türlü zarardan bizzat ve münhasıran sorumlu olduğunu;
16.4. Etkinlik Linklerini, QR afişlerini ve Yalnızca Linkle Etkinlikleri kimlerle paylaşacağına kendisinin karar verdiğini ve linkin yayılmasından doğan sonuçlardan sorumlu olduğunu;
16.5. Katılımcılara gönderdiği mesaj ve bildirimlerin yalnızca ilgili Etkinlikle ilgili olacağını; reklam, siyasi propaganda, spam veya rahatsız edici içerik göndermeyeceğini; Platform üzerinden gönderdiği her mesaj ve bildirimin içeriğinden münhasıran kendisinin sorumlu olduğunu, Regipass'in bu içerikleri önceden denetlemediğini, onaylamadığını ve yalnızca teknik olarak ilettiğini; bu sorumluluğu her gönderimde ayrıca onayladığını ve bu onayın kayıt altına alındığını;
16.6. Kapıda bilet okutma, yoklama, kayıt kaldırma, engelleme, "Ödendi" işaretleme ve Katılım Belgesi gönderme/geri alma işlemlerini doğru ve dürüst şekilde yapacağını; bu işlemlerin sonuçlarından kendisinin sorumlu olduğunu;
16.7. Regipass marka, logo ve materyallerini yalnızca Regipass'in önceden yazılı onayı ile kullanacağını;
16.8. Ücretli Etkinliklerde, ödemeyi organize edecek yetkili temsilcisinin güncel telefon ve/veya e-posta bilgisini doğru şekilde gireceğini ve bu bilgilerin ilgili Etkinliğe kaydolan Katılımcılara gösterilmesine onay verdiğini.

17. Katılımcı Verileri — Organizatör'ün Sorumluluğu
17.1. Organizatör, Etkinliğine kaydolan Katılımcıların Platform'da kendisine gösterilen kişisel verilerine (ad-soyad, e-posta, telefon, üniversite, bölüm, sınıf, profil fotoğrafı, kayıt, giriş, yoklama, ödeme durumu, değerlendirmeler vb.) yalnızca ilgili Etkinliğin yönetimi amacıyla erişir. Organizatör bu veriler bakımından 6698 sayılı KVKK kapsamında kendi başına veri sorumlusudur.
17.2. Organizatör; bu verileri yalnızca ilgili Etkinliğin yürütülmesi, Katılımcılarla Etkinlikle ilgili iletişim ve Katılım Belgesi süreçleri için kullanacağını; başka amaçla işlemeyeceğini, satmayacağını, üçüncü kişilerle paylaşmayacağını, pazarlama veya siyasi amaçla kullanmayacağını; indirdiği listeleri (Excel/CSV dosyaları, ekran görüntüleri dahil) güvenli şekilde saklayacağını, amaç ortadan kalktığında sileceğini ve KVKK'dan doğan tüm yükümlülükleri (aydınlatma, veri güvenliği, ilgili kişi başvurularına cevap verme dahil) kendisinin yerine getireceğini kabul eder.
17.3. Katılımcı verilerinin Organizatör tarafından veya Organizatör'ün hesabına erişen kişiler tarafından hukuka aykırı şekilde işlenmesi, sızdırılması veya kötüye kullanılmasından doğan her türlü sorumluluk Organizatör'e aittir.

18. İçerik Kaldırma ve Tazminat
18.1. Regipass, Organizatörlerin oluşturduğu Etkinlik ve İçerikleri önceden denetleme yükümlülüğü altında değildir. Regipass, bir İçeriğin veya Etkinliğin bu Sözleşme'ye ya da mevzuata aykırı olduğunu tespit ettiğinde veya bu yönde bir bildirim aldığında; İçeriği veya Etkinliği önceden bildirimde bulunmaksızın kaldırma, Etkinliği iptal etme, Katılımcıları bilgilendirme ve Organizatör hesabını askıya alma veya kapatma hakkına sahiptir.
18.2. Organizatör; bu Sözleşme'ye, mevzuata veya üçüncü kişilerin haklarına aykırı davranışı, Etkinlikleri, İçerikleri, Katılımcı verilerini işlemesi veya ödeme süreçleri nedeniyle Regipass'e yöneltilebilecek her türlü talep, dava, şikâyet, idari para cezası, soruşturma, tazminat ve masrafı (makul avukatlık ücretleri dahil) karşılamayı ve Regipass'i bunlardan ari tutmayı kabul eder. Regipass'in bu nedenle ödemek zorunda kaldığı tutarlar, ödeme tarihinden itibaren işleyecek yasal faiziyle birlikte Organizatör'e rücu edilir.

19. Etkinlik Ücretleri ve Ödeme — Organizatör Açısından
19.1. Ücretli Etkinliklerde ücretin belirlenmesi, duyurulması, tahsili, iadesi ve kullanımı münhasıran Organizatör'ün sorumluluğundadır. Regipass bu süreçte ödeme kuruluşu, aracı hizmet sağlayıcı, emanetçi veya taraf değildir.
19.2. Regipass'in ödemeye ilişkin tek teknik rolü, Organizatör'ün girdiği yetkili temsilci iletişim bilgisini Katılımcılara göstermek ve Organizatör'ün "Ödendi" işaretlemesini kaydetmektir. Hatalı veya yanıltıcı bilgi paylaşılmasından doğacak her türlü sonuçtan Organizatör sorumludur.
19.3. Organizatör, topladığı ücretlere ilişkin vergisel, ticari ve hukuki tüm yükümlülüklerden (fatura/makbuz düzenleme, bağış ve yardım toplama mevzuatı dahil) bizzat sorumludur.
19.4. ZORUNLU ONAY — KAYIT ALTINA ALINIR. Organizatör, ücretli bir Etkinlik oluştururken aşağıdaki onayı ayrıca ve açıkça vermelidir; bu onay her ücretli Etkinlik için kayıt altına alınır:
"Platform'a girdiğim tüm bilgilerin doğru ve güncel olduğunu; bu bilgilerin katılımcılara gösterilmesini onayladığımı; ücretli Etkinlikte tahsil edilecek paranın toplanması, transferi, kullanımı ve harcanması dahil ödeme sürecinin her aşamasının ve bu süreçten doğabilecek her türlü sonucun tamamen Organizatör olarak bizim sorumluluğumuzda olduğunu, Regipass'in bu konuların hiçbirinde herhangi bir sorumluluğu bulunmadığını kabul ve beyan ederim."
Bu onay verilmeden ücretli Etkinlik yayınlanamaz.

BÖLÜM C — ORTAK HÜKÜMLER

20. Kişisel Verilerin İşlenmesi
20.1. Kişisel verilerin hangi amaçlarla ve hangi hukuki sebeplerle işlendiği, kimlere aktarıldığı, yurt dışına aktarımı (Google ve diğer hizmet sağlayıcıların ABD ve Avrupa Birliği'ndeki sunucuları dahil), saklama süreleri ve haklarınız ayrıca sunulan KVKK Aydınlatma Metni'nde yer alır.
20.2. Bir Etkinliğe kaydolduğunuz anda temel katılımcı bilgileriniz, Etkinliğin yürütülmesi amacıyla otomatik olarak yalnızca o Etkinliğin Organizatör'ü ile paylaşılır.

21. Yasak İçerik ve Davranışlar (Herkes İçin)
Aşağıdakiler kesinlikle yasaktır; tespit edildiğinde İçerik kaldırılır, hesap süresiz kapatılabilir, gerekirse yetkili mercilere bildirim yapılır:
— Terör örgütü propagandası, terörü veya şiddeti öven, teşvik eden ya da meşrulaştıran içerik;
— Nefret söylemi, ayrımcılık, ırkçılık, cinsiyetçilik veya herhangi bir gruba düşmanlık;
— Suç teşkil eden veya suçu teşvik eden faaliyetler; yasa dışı silah, uyuşturucu, kumar, bahis, piramit/saadet zinciri ya da dolandırıcılık amaçlı Etkinlikler;
— Müstehcen içerik, cinsel istismar ve reşit olmayanları hedef alan her türlü içerik (yetkili mercilere derhal bildirilir);
— Sahte, yanıltıcı veya var olmayan Etkinlikler; başkasının kimliğine, kulübüne veya kurumuna bürünmek;
— Kişilik haklarını, fikri mülkiyet haklarını, gizliliği ve kişisel verileri ihlal eden içerik; başkalarının kişisel verilerini izinsiz paylaşmak;
— Spam, istenmeyen toplu ileti, reklam veya siyasi propaganda amaçlı mesaj gönderimi;
— Platform'un altyapısına zarar verecek, işleyişini bozacak veya yetkisiz erişim sağlayacak faaliyetler (kötü amaçlı yazılım, bot, otomatik kayıt, kazıma/scraping, tersine mühendislik, güvenlik açığı istismarı, sahte konum, yoklamayı atlatma vb.);
— Platform'u veya Demo'yu, Platform'a rakip bir ürün geliştirmek ya da Platform'u kötüleyici biçimde kopyalamak amacıyla kullanmak.

22. Bildirim Üzerine Kaldırma
22.1. Regipass, Platform'daki İçerikleri önceden denetleme yükümlülüğü altında değildir ve teknik olarak her İçeriği önceden inceleyemez. Hukuka aykırı bir İçerik bize bildirildiğinde veya tarafımızca fark edildiğinde, 5651 sayılı Kanun kapsamındaki yükümlülüklerimiz doğrultusunda İçerik makul süre içinde kaldırılır.
22.2. Bildirim ve şikâyetler için: product@regipass.com

23. Hizmetin Sunumu, Kesintiler ve Üçüncü Taraf Hizmetler
23.1. Platform "olduğu gibi" ve "mevcut olduğu ölçüde" sunulur. Regipass, Platform'un kesintisiz, hatasız, virüssüz veya her cihazda çalışacağını; belirli bir amaca uygun olacağını garanti etmez. Bakım, güncelleme, güvenlik önlemleri veya Regipass'in kontrolü dışındaki nedenlerle Platform'a erişim geçici olarak durdurulabilir.
23.2. Platform; Google (Firebase: barındırma, veritabanı, kimlik doğrulama, depolama, sunucu işlemleri, anlık bildirim, SMS doğrulama), Apple (Apple ile giriş, anlık bildirim, Wallet), e-posta gönderim sağlayıcıları ve mobil işletim sistemleri gibi üçüncü taraf hizmetlere dayanır. Bu hizmetlerdeki kesinti, hata, politika değişikliği, hesap kapatma veya veri kaybından kaynaklanan sonuçlardan Regipass sorumlu değildir.
23.3. Regipass makul güvenlik önlemlerini alır ve düzenli yedekleme yapmaya çalışır; ancak teknik arıza, siber saldırı veya üçüncü taraf kaynaklı nedenlerle veri kaybı yaşanmayacağını garanti etmez. Katılımcı listeleri, Katılım Belgeleri ve Etkinlik için önemli diğer bilgilerin kendi kopyalarını saklamak kullanıcıların sorumluluğundadır.
23.4. Uygulamanın güncel sürümünü kullanmak sizin sorumluluğunuzdadır; eski sürümlerde bazı özellikler çalışmayabilir.

24. Sorumluluğun Sınırlandırılması
24.1. Yürürlükteki mevzuatın izin verdiği azami ölçüde Regipass; Organizatörlerin veya diğer kullanıcıların Etkinlikleri, İçerikleri, davranışları, ödeme uyuşmazlıkları ve veri işleme faaliyetleri; Etkinlik sırasında meydana gelen olaylar; giriş, yoklama veya Katılım Belgesi süreçlerindeki hatalar; bildirimlerin ulaşmaması; Platform'daki kesinti, hata veya veri kaybı; üçüncü taraf hizmetler nedeniyle doğan doğrudan veya dolaylı, kâr kaybı, itibar kaybı, fırsat kaybı dahil hiçbir maddi veya manevi zarardan sorumlu tutulamaz.
24.2. Platform Katılımcılara ücretsiz olarak sunulmaktadır. Bu nedenle ve 6098 sayılı Türk Borçlar Kanunu'nun 115. maddesinin izin verdiği ölçüde, Regipass'in hafif kusurundan doğan zararlardan sorumluluğu bulunmamaktadır; Regipass yalnızca kendi kastı veya ağır kusuruyla sebep olduğu zararlardan sorumludur. Organizatörlere ücretli hizmet sunulması hâlinde Regipass'in Organizatör'e karşı toplam sorumluluğu, olayın gerçekleştiği tarihten önceki 12 (on iki) ay içinde o Organizatör'ün Regipass'e ödediği toplam ücretle sınırlıdır.
24.3. Bu maddedeki sınırlamalar; Regipass'in kastı veya ağır kusurundan doğan zararlar, kişilerin hayatına veya vücut bütünlüğüne gelen zararlardan Regipass'in kendi kusuruyla sebep olduğu zararlar ile emredici mevzuatın (6502 sayılı Tüketicinin Korunması Hakkında Kanun ve 6698 sayılı KVKK dahil) sınırlanmasına izin vermediği hâller için uygulanmaz. Bu Sözleşme'nin hiçbir hükmü, tüketicilerin emredici hükümlerden doğan haklarını ortadan kaldırmaz.

25. Kullanıcının Tazmin Yükümlülüğü
Katılımcılar ve Organizatörler; bu Sözleşme'yi veya mevzuatı ihlal etmeleri, yanlış bilgi vermeleri, paylaştıkları İçerikler ya da üçüncü kişilerin haklarını ihlal etmeleri nedeniyle Regipass'e yöneltilen her türlü talep, dava, ceza ve masraftan (makul avukatlık ücretleri dahil) doğan zararı karşılamayı kabul eder.

26. Fikri Mülkiyet
26.1. Regipass markası, logosu, arayüz tasarımı, yazılımı, metinleri ve Platform'a ait tüm fikri ve sınai mülkiyet hakları Regipass'e veya lisans verenlerine aittir. Platform'u kopyalamak, tersine mühendislik yapmak, çoğaltmak veya izinsiz ticari amaçla kullanmak yasaktır.
26.2. Platform'a yüklenen İçerikler üzerindeki haklar yükleyen tarafa aittir. İçerik yükleyerek, bu İçeriği Platform'un işletilmesi, Etkinliğin duyurulması (Etkinlik Linki önizlemeleri, paylaşım görselleri ve QR afişleri dahil) ve Platform'un tanıtımı amacıyla kullanmak, çoğaltmak, uyarlamak ve göstermek üzere Regipass'e dünya çapında, münhasır olmayan, ücretsiz ve alt lisans verilebilir bir lisans vermiş olursunuz. Yüklediğiniz İçerik üzerinde gerekli tüm haklara sahip olduğunuzu taahhüt edersiniz.

27. Demo Ortamı
Demo; uydurma kişi, kulüp ve Etkinliklerle çalışan, herkese açık ve düzenli olarak sıfırlanan bir tanıtım ortamıdır. Demo'ya gerçek kişisel veri girmemeniz gerekir; girdiğiniz bilgiler diğer ziyaretçiler tarafından görülebilir ve bildirimde bulunulmaksızın silinir. Demo'da yapılan işlemler gerçek bir kayıt, bilet veya Katılım Belgesi doğurmaz ve Demo hiçbir garanti olmaksızın sunulur.

28. Askıya Alma, Fesih ve Hesap Silme
28.1. Regipass; bu Sözleşme'nin ihlali, yasa dışı faaliyet şüphesi, güvenlik riski, uzun süreli kullanılmama, yetkili mercilerin talebi veya Platform'un korunması için gerekli gördüğü diğer hâllerde, önceden bildirimde bulunmaksızın bir hesabı askıya alabilir, kısıtlayabilir veya kapatabilir; Etkinlikleri ve İçerikleri kaldırabilir.
28.2. Hesabınızı dilediğiniz zaman Platform üzerinden veya product@regipass.com adresine başvurarak kapatabilirsiniz. Hesap silme talebinden sonra hesabınız kapatılır ve kişisel verileriniz KVKK Aydınlatma Metni'nde belirtilen süreler sonunda silinir veya anonimleştirilir. Organizatör hesabının kapatılması hâlinde ileri tarihli Etkinlikler iptal edilebilir.
28.3. Sözleşme'nin sona ermesi; sona ermeden önce doğmuş hak ve yükümlülükleri, tazmin, sorumluluk sınırlaması, fikri mülkiyet, delil ve uyuşmazlık çözümüne ilişkin hükümleri etkilemez.

29. Mücbir Sebep
Doğal afet, salgın, savaş, terör, grev, yangın, enerji veya internet kesintileri, siber saldırılar, üçüncü taraf altyapı arızaları, yasal düzenlemeler veya resmî makam kararları gibi Regipass'in makul kontrolü dışındaki olaylar nedeniyle yükümlülüklerin yerine getirilememesinden Regipass sorumlu değildir.

30. Delil Sözleşmesi
Taraflar, bu Sözleşme'den doğabilecek uyuşmazlıklarda Regipass'in elektronik kayıtlarının, sunucu ve işlem kayıtlarının, onay kayıtlarının ve yazışmalarının, 6100 sayılı Hukuk Muhakemeleri Kanunu'nun 193. maddesi uyarınca geçerli delil teşkil edeceğini kabul eder; bu hüküm karşı delil sunma hakkını ortadan kaldırmaz.

31. Değişiklikler
Regipass bu Sözleşme'yi güncelleyebilir. Güncel metin Platform'da yayınlanır. Haklarınızı veya yükümlülüklerinizi önemli ölçüde etkileyen değişiklikler Platform üzerinden duyurulur ve yeniden onayınız istenir; onay vermemeniz hâlinde Platform'u kullanmaya devam edemez ve hesabınızı kapatabilirsiniz.

32. Devir
Regipass, bu Sözleşme'den doğan hak ve yükümlülüklerini, Platform'u devralacak veya işletecek bir şirkete ya da üçüncü kişiye devredebilir; bu durum Platform üzerinden duyurulur. Kullanıcılar ve Organizatörler, Regipass'in yazılı onayı olmadan bu Sözleşme'den doğan haklarını devredemez.

33. Çeşitli Hükümler
33.1. Bu Sözleşme'nin herhangi bir hükmünün geçersiz sayılması, diğer hükümlerin geçerliliğini etkilemez; geçersiz hüküm, amacına en yakın geçerli hükümle yer değiştirmiş sayılır.
33.2. Regipass'in bir hakkını kullanmaması veya geç kullanması, o haktan feragat ettiği anlamına gelmez.
33.3. Bu Sözleşme; KVKK Aydınlatma Metni, ücretli Etkinlik onay metinleri ve Platform'da ayrıca kabul edilen diğer metinlerle birlikte taraflar arasındaki anlaşmanın tamamını oluşturur.
33.4. Sözleşme Türkçe ve İngilizce olarak hazırlanmıştır; iki metin arasında çelişki olması hâlinde Türkçe metin esas alınır.

34. Uygulanacak Hukuk, Yetkili Mahkeme ve İletişim
34.1. Bu Sözleşme Türkiye Cumhuriyeti kanunlarına tabidir. Uyuşmazlıklarda İstanbul (Çağlayan) Mahkemeleri ve İcra Daireleri yetkilidir. Tüketici sıfatını taşıyan Katılımcıların, 6502 sayılı Kanun uyarınca Tüketici Hakem Heyetlerine ve kendi yerleşim yerlerindeki Tüketici Mahkemelerine başvurma hakları saklıdır.
34.2. İletişim: product@regipass.com · 0850 888 35 58 · Kağıthane/İstanbul
''';

const String _contractEn = '''
REGIPASS USER AND ORGANIZER AGREEMENT
Last updated: 02.10.2026 · Version v1.1

IMPORTANT: Please read this Agreement carefully. By using the Platform, creating an account or registering for an Event without an account, you accept this Agreement. In particular, Sections 6, 7, 9, 10, 16-19, 23, 24 and 25 contain provisions that limit Regipass's liability and impose obligations on you; they are highlighted so that they are easy to read.

1. Parties and Definitions
1.1. This Agreement (the "Agreement") is entered into between Regipass (contact: product@regipass.com) ("Regipass", "we"), on the one hand, and on the other hand:
— any natural person who downloads, signs up for, registers for an Event without an account or otherwise uses the Platform ("User", "Participant", "you"), and/or
— any student club, community, organization or authorized person acting on their behalf who creates an organizer account on the Platform ("Organizer"),
and enters into force when the relevant party accepts this Agreement electronically or starts using the Platform. The same person may be both a Participant and an authorized representative of an Organizer; in that case both Part A and Part B apply to that person. A person acting on behalf of an Organizer represents and warrants that they are authorized to do so and agrees to be jointly and severally liable with the Organizer for all consequences if they are not.
1.2. Definitions:
Platform: The Regipass mobile apps (iOS and Android), the websites at regipass.com and its subdomains (including demo.regipass.com), Event Link pages and all related digital services.
Participant: A natural person who discovers, registers for and attends Events on the Platform. A person who registers through an Event Link without creating an account ("Guest Participant") is also a Participant under this Agreement.
Organizer: A club, community, organization or its authorized person that creates, publishes and manages Events on the Platform and tracks Participants' registrations, entry and attendance.
Event: Any activity, meeting, seminar, concert, trip, social, cultural, sports or educational organization announced or managed by an Organizer through the Platform.
Event Link: A link specific to an Event, generated by the Platform or created with a custom name chosen by the Organizer (e.g. regipass.com/e/K7P2QX), together with its QR poster and registration page.
Link-only Event: An Event not listed in Discover that only people who have the Event Link can see and register for.
Ticket: The digital entry pass containing a QR code given to a Participant after registration (including Apple Wallet / Google Wallet passes).
Participation Certificate: A digital document generated through the Platform showing a Participant's attendance at an Event according to the conditions set by the Organizer (called "Certificate" in earlier versions).
Content: Any text, image, logo, document, event detail, review, message or other material uploaded to or shared through the Platform by Organizers or Participants.
Demo: The showcase environment at demo.regipass.com and in the "Regipass Demo" app, which runs on fictional data and is reset regularly.

2. Nature of the Service
2.1. Regipass is an intermediary technology platform that allows Participants to discover Events, register for them with or without an account, check in and take attendance with a QR ticket and location verification, and access Participation Certificates; and allows Organizers to create and announce Events, collect registrations, manage the door and attendance, send notifications and generate Participation Certificates.
2.2. Regipass acts as a hosting provider and intermediary service provider under Turkish Law No. 6563 on the Regulation of Electronic Commerce and Law No. 5651. Regipass does not organize, run, manage or supervise Events and is not a party to Events, to the relationship between Organizer and Participant, or to any contract arising from that relationship. Events are solely the responsibility and initiative of the Organizer.
2.3. Regipass has no official affiliation, partnership, representation, agency, employment or joint-venture relationship with any university, student community, public institution or Organizer. An Organizer's presence on the Platform does not mean that it is supported, approved or considered trustworthy by Regipass.
2.4. The Platform is not a payment institution, escrow service, ticketing agency, event organization company, insurance or security service.

3. Scope and Conditions of Use
3.1. The Agreement has three parts: Part A (Sections 4-12) applies to Participants, Part B (Sections 13-19) to Organizers, and Part C (Sections 20-34) to everyone.
3.2. Only persons aged 18 or over may use the Platform. The Platform is open to everyone aged 18 or over; an Organizer may restrict an Event to certain universities, departments or groups. Accounts and registrations of persons found to be under 18 are closed or deleted without notice. You are responsible for all consequences of misstating your age.
3.3. Regipass reserves the right to change the scope, features, interface, capacity and pricing model of the Platform; to add new features or remove existing ones; to create paid packages or subscriptions or to make free features paid. Pricing changes are announced on the Platform before they take effect. Regipass does not promise anyone indefinite or lifetime free use.

PART A — PROVISIONS FOR PARTICIPANTS

4. Account and Accurate Information
4.1. You accept, represent and warrant that the information you provide during and after sign-up (name, email, phone, city, university, department, year, student number, gender, profile photo, etc.) is accurate, current, complete and your own. Creating an account or registering in someone else's name or with someone else's phone number or email is prohibited.
4.2. Your profile photo is shown to the Organizer of an Event you register for, for identity checks at the door; you may not upload a photo that is not of you, misleading or inappropriate.
4.3. You are solely responsible for keeping your account information (including your password, verification codes sent to your phone and your Ticket QR code) confidential and for all actions taken through your account or Ticket. Regipass is not responsible for the consequences of sharing a screenshot of your QR code or Ticket with others. You must notify us immediately of any suspected unauthorized use.
4.4. Providing false, incomplete or someone else's information may result in registrations, attendance records and Participation Certificates being invalidated and the account being closed.

5. Registration Without an Account (Guest) and Event Links
5.1. You may register for some Events through an Event Link without creating an account. In that case your phone number is verified by SMS; your name, phone, email and (if requested) university/department are collected and shared with the Organizer of the Event you register for. This Agreement and the Data Protection Notice also apply to guest registrations.
5.2. If you leave the "Also create my account" option checked on the registration form, a Regipass account is created in your name with the information you provide; you may uncheck this option. Your guest registrations may be transferred to your account if you later create an account with the same phone number.
5.3. A Guest Participant's personal data is anonymized or deleted approximately 30 days after the end of the Event; after that, Ticket, registration and Participation Certificate information may no longer be accessible. You are responsible for downloading your Participation Certificate within this period.
5.4. Anyone who has an Event Link can see the Event (including Link-only Events) and register if they meet the registration conditions. Regipass cannot control with whom a link is shared or re-shared, whether it spreads on social media, or where a QR poster is posted; Regipass is not responsible for the consequences of a link reaching unintended people.
5.5. SMS verification codes are sent through third-party infrastructure. Regipass cannot be held responsible for SMS delays or non-delivery, operator blocks, or your number being used by someone else.

6. Disclaimer for Events and Content
6.1. Event information, descriptions, images, dates and times, venue, capacity, fee, participation conditions and all other Content are created by the Organizer, who is solely responsible for their accuracy, lawfulness and timeliness.
6.2. Regipass does not guarantee, and has no obligation to verify in advance, whether an Event is real, whether it will take place, be postponed or cancelled, whether it will be held as announced, the accuracy of its content, its safety, health and hygiene conditions, whether it has legal permits, or whether the Organizer will fulfil its commitments. Even if an Event is fake, misleading or does not exist at all (a "phantom event"), Regipass cannot be held liable for any material or non-material damage arising from your reliance on that Event (including travel, accommodation, fees and loss of time).
6.3. The decision to attend an Event is entirely yours. For any accident, injury, health issue, theft, loss, harassment, fight, food poisoning, transport issue or any personal or material damage that may occur during or because of an Event, your counterparty is the Organizer and, where applicable, the persons who caused it; since Regipass is in no way involved in the physical running of Events, it is not liable for such damage.
6.4. The fact that Regipass requests or reviews certain documents from an Organizer before accepting it on the Platform does not constitute any guarantee, certification or approval that the Organizer is trustworthy, authorized, honest or will act lawfully.

7. Event Fees and Payment — For Participants
7.1. Some Events may be paid. Setting, collecting, refunding and managing the fee is solely the Organizer's responsibility. Regipass is not a payment institution, intermediary payment service provider, escrow agent or party to these payments; no payment is taken through the Platform.
7.2. When you register for a paid Event, the contact details (phone and/or email) of the Organizer's authorized representative, entered by the Organizer itself, are shown to you and you are asked to arrange payment directly with that person. Payment takes place entirely outside Regipass's systems, between you and the Organizer.
7.3. Regipass is in no way responsible for the accuracy of the contact details shown, whether the person you contact is actually authorized, whether payment was made or marked as "Paid" by the Organizer, refunds, the use of fees, fraud or trust issues. You are advised to verify your counterparty and the payment terms before paying. In all disputes on this matter your counterparty is the Organizer; Regipass has no obligation to mediate.
7.4. MANDATORY ACKNOWLEDGMENT — RECORDED. Before completing registration for a paid Event, you are asked to give the following acknowledgment separately and expressly, and it is recorded:
"I understand that the payment process takes place outside Regipass, directly with the Organizer, through the contact details (phone/email) of the authorized representative that the Organizer itself entered on the Platform; that these contact details were entered by the Organizer and their accuracy has not been verified by Regipass; that the other party may not actually be authorized and that no outcome is guaranteed, including fraud or the payment going unanswered; and that Regipass is not responsible at any stage of this process."
Registration for a paid Event cannot be completed without this acknowledgment.

8. Registration, Capacity, Waitlist and Cancellation
8.1. Rules on registration, capacity, registration deadline, waitlist and cancellation are set by the Organizer and applied automatically by the Platform. Regipass is not responsible if, for technical reasons (load, simultaneous applications, connection issues), a registration is not created, capacity fills earlier than expected, your waitlist position changes, or a notification that a spot has opened for you is delayed.
8.2. The Organizer may cancel or change an Event, remove your registration or block you from its Events. These decisions belong to the Organizer.

9. Tickets, Door Entry, Location Verification and Attendance
9.1. QR scanning and, if enabled by the Organizer, location verification are used at entry and for session attendance. Your location is collected only at the moment of scanning and only once; there is no background location tracking. Your location itself is not stored; only the distance to the Event point and the location accuracy are recorded.
9.2. Your entry or attendance may not be recorded, or may be recorded incorrectly, due to faulty or disabled location services on your device, GPS drift, camera or internet problems, an unreadable QR code, the Organizer's use of offline door mode, sync delays or the Organizer's mistakes. Regipass cannot be held liable for these situations or for you being refused entry to an Event or not receiving a Participation Certificate as a result; you should direct such requests to the Organizer.
9.3. Spoofed location, scanning on behalf of someone else, copying QR codes or any attempt to circumvent the attendance system is prohibited.

10. Participation Certificates
10.1. Participation Certificates are generated by the Platform according to the conditions set by the Organizer (e.g. number of attended sessions), the template uploaded by the Organizer and entry/attendance data. The Organizer is responsible for the content of a certificate and for issuing, withholding or revoking it.
10.2. Participation Certificates are not documents approved by an official institution, university or the state; they are participation documents issued by the Organizer according to its own conditions. Regipass does not guarantee that a certificate will be accepted by third parties (employers, schools, institutions, etc.).
10.3. Each Participation Certificate carries a verification code. Anyone who knows this code can see on the verification page at regipass.com whether the certificate is valid, as well as the holder's name and the Event's name and date. You accept that this information can be seen when you share your certificate.

11. Notifications, Reviews and Following
11.1. Regipass and Organizers may send you in-app notifications, push notifications, emails and/or SMS about your account, registrations, Event changes, reminders, Participation Certificates and security. It is not guaranteed that notifications will arrive on time, arrive at all or not end up in spam; it is your responsibility to check important information on the Platform.
11.2. Commercial electronic messages (campaign notifications) are sent only with your separate consent under Law No. 6563; this consent is off by default and you can turn it on or off free of charge at any time in Account settings.
11.2a. The relevant Organizer is responsible for the content of messages it sends you about its Events; Regipass does not review these messages in advance and only delivers them. You can report an inappropriate message to product@regipass.com.
11.3. Your reviews and comments about Events can be seen by the relevant Organizer. You are responsible for your reviews being accurate, respectful and lawful.
11.4. When you follow an Organizer, you receive notifications about its new Events; you may unfollow at any time.

12. Participant Obligations and Prohibited Conduct
In addition to the prohibited conduct listed in Section 21, it is prohibited to habitually register for Events and not attend, to make bulk or fake registrations in order to block capacity, to harass Organizers or other Participants, or to disregard Event rules and the Organizer's reasonable instructions.

PART B — PROVISIONS FOR ORGANIZERS

13. Organizer Account and Approval Process
13.1. An Organizer account is opened upon uploading the documents requested by Regipass (e.g. Club Establishment Approval Document, Authorized Student Document or other documents Regipass deems appropriate) and Regipass's approval. Regipass may reject an application without giving reasons, request additional documents, or later suspend an approved account.
13.2. The Organizer is responsible for the uploaded documents being genuine, valid and current, for obtaining the consent of the persons named in them, and for sharing the personal data in them lawfully. Regipass's review of documents does not certify their authenticity or the Organizer's authority.
13.3. When the persons using the Organizer account change, the club closes or an authorized person's role ends, the Organizer must notify Regipass and update account access. The Organizer is responsible for all actions taken through the account until such notice is given.

14. Service Provided to Organizers
14.1. Regipass offers Organizers the ability to create and announce Events, create Event Links and QR posters, publish Link-only Events, collect registrations with and without accounts, manage capacity and waitlists, scan tickets at the door (including offline mode), take session attendance, send messages and notifications to participants, view and download participant lists, view Event reports and reviews, and generate Participation Certificates.
14.2. These services are provided "as is" and "as available". Regipass does not guarantee that features will always work, be uninterrupted or be sufficient for a particular Event. The Organizer must take its own precautions against a possible failure or outage of the Platform (e.g. a backup participant list, paper attendance, an alternative entry method).

15. Pricing — For Organizers
15.1. Regipass services are subject to the package/subscription model set and updated from time to time by Regipass. Existing free use (including any trial period) is at Regipass's discretion and may be changed, limited or ended with prior notice.
15.2. In the event of a move to a paid package, current prices and payment terms will be communicated separately. Regipass may suspend the account or certain features of an Organizer that does not pay on time.

16. Organizer Obligations
The Organizer accepts, represents and warrants:
16.1. that all Event information, participation conditions, fees and Participation Certificate conditions it enters on the Platform are accurate, current and not misleading; that it will update changes in time and inform Participants where necessary;
16.2. that Events and all Content comply with applicable law, public order and morals, and that it will not create any Content or Event listed in Section 21;
16.3. that it is personally and solely responsible for running the Event safely; for all permits, licences and measures regarding venue, capacity, fire, first aid, security, insurance, alcohol, food, noise and similar matters; for complying with university or venue rules; for the safety of participants' lives and property; and for any damage arising during the Event;
16.4. that it decides with whom it shares Event Links, QR posters and Link-only Events and is responsible for the consequences of a link spreading;
16.5. that the messages and notifications it sends to Participants will relate only to the relevant Event, and that it will not send advertising, political propaganda, spam or disturbing content; that it is solely responsible for the content of every message and notification it sends through the Platform, that Regipass does not review or approve such content in advance and only delivers it technically; and that it confirms this responsibility separately at each sending and that this confirmation is recorded;
16.6. that it will perform door scanning, attendance, removing registrations, blocking, marking as "Paid" and sending/revoking Participation Certificates accurately and honestly, and that it is responsible for the results of these actions;
16.7. that it will use Regipass's brand, logo and materials only with Regipass's prior written consent;
16.8. that for paid Events it will correctly enter the current phone and/or email of the authorized representative who will arrange payment, and that it consents to these details being shown to Participants registering for the Event.

17. Participant Data — Organizer's Responsibility
17.1. The Organizer accesses the personal data of Participants registered for its Events shown on the Platform (name, email, phone, university, department, year, profile photo, registration, entry, attendance, payment status, reviews, etc.) only for the purpose of managing the relevant Event. The Organizer is an independent data controller for this data under Turkish Personal Data Protection Law No. 6698 ("KVKK").
17.2. The Organizer agrees to use this data only for running the relevant Event, communicating with Participants about the Event and Participation Certificate processes; not to process it for any other purpose, sell it, share it with third parties or use it for marketing or political purposes; to store downloaded lists (including Excel/CSV files and screenshots) securely and delete them when the purpose ends; and to fulfil all obligations under KVKK itself (including notice, data security and responding to data subject requests).
17.3. All liability arising from the unlawful processing, leakage or misuse of Participant data by the Organizer or by persons accessing the Organizer's account belongs to the Organizer.

18. Content Removal and Indemnity
18.1. Regipass has no obligation to review in advance Events and Content created by Organizers. Where Regipass determines, or receives a notice, that Content or an Event violates this Agreement or the law, it may remove the Content or Event without prior notice, cancel the Event, inform Participants and suspend or close the Organizer account.
18.2. The Organizer agrees to cover, and to hold Regipass harmless from, all claims, lawsuits, complaints, administrative fines, investigations, damages and costs (including reasonable attorney fees) that may be brought against Regipass because of its conduct contrary to this Agreement, the law or third-party rights, its Events, its Content, its processing of Participant data or its payment processes. Amounts Regipass has to pay for these reasons are recoverable from the Organizer together with statutory interest from the date of payment.

19. Event Fees and Payment — For Organizers
19.1. In paid Events, setting, announcing, collecting, refunding and using the fee is solely the Organizer's responsibility. Regipass is not a payment institution, intermediary service provider, escrow agent or party in this process.
19.2. Regipass's only technical role regarding payment is to show Participants the contact details of the authorized representative entered by the Organizer and to record the Organizer's "Paid" marking. The Organizer is responsible for all consequences of sharing incorrect or misleading information.
19.3. The Organizer is personally responsible for all tax, commercial and legal obligations regarding the fees it collects (including issuing invoices/receipts and complying with donation and fundraising rules).
19.4. MANDATORY ACKNOWLEDGMENT — RECORDED. When creating a paid Event, the Organizer must give the following acknowledgment separately and expressly; it is recorded for each paid Event:
"I accept and declare that all information I have entered on the Platform is accurate and current; that I consent to this information being shown to participants; that every stage of the payment process for the paid Event, including the collection, transfer, use and spending of the money, and any consequence arising from it, is entirely our responsibility as the Organizer; and that Regipass bears no responsibility for any of these matters."
A paid Event cannot be published without this acknowledgment.

PART C — COMMON PROVISIONS

20. Processing of Personal Data
20.1. The purposes and legal grounds for processing personal data, the recipients, transfers abroad (including to servers of Google and other service providers in the United States and the European Union), retention periods and your rights are set out in the separately provided Data Protection Notice.
20.2. As soon as you register for an Event, your basic participant information is automatically shared only with that Event's Organizer for the purpose of running the Event.

21. Prohibited Content and Conduct (For Everyone)
The following are strictly prohibited; when detected, the Content is removed, the account may be closed indefinitely and, where necessary, the competent authorities are notified:
— propaganda for terrorist organizations, or content praising, encouraging or legitimizing terrorism or violence;
— hate speech, discrimination, racism, sexism or hostility toward any group;
— activities that constitute or encourage crimes; Events for illegal weapons, drugs, gambling, betting, pyramid/Ponzi schemes or fraud;
— obscene content, sexual abuse and any content targeting minors (reported immediately to the competent authorities);
— fake, misleading or non-existent Events; impersonating another person, club or institution;
— content violating personality rights, intellectual property rights, privacy or personal data; sharing others' personal data without permission;
— spam, unsolicited bulk messages, advertising or political propaganda messages;
— activities that harm the Platform's infrastructure, disrupt its operation or gain unauthorized access (malware, bots, automated registration, scraping, reverse engineering, exploiting vulnerabilities, spoofed location, circumventing attendance, etc.);
— using the Platform or the Demo to develop a competing product or to copy the Platform.

22. Notice and Takedown
22.1. Regipass has no obligation to review Content on the Platform in advance and technically cannot review all Content in advance. When unlawful Content is reported to us or noticed by us, it is removed within a reasonable time in line with our obligations under Law No. 5651.
22.2. For notices and complaints: product@regipass.com

23. Provision of the Service, Interruptions and Third-Party Services
23.1. The Platform is provided "as is" and "as available". Regipass does not guarantee that the Platform will be uninterrupted, error-free, virus-free, work on every device or be fit for a particular purpose. Access may be temporarily suspended for maintenance, updates, security measures or reasons beyond Regipass's control.
23.2. The Platform relies on third-party services such as Google (Firebase: hosting, database, authentication, storage, server functions, push notifications, SMS verification), Apple (Sign in with Apple, push notifications, Wallet), email delivery providers and mobile operating systems. Regipass is not responsible for consequences arising from outages, errors, policy changes, account closures or data loss in these services.
23.3. Regipass takes reasonable security measures and strives to make regular backups; however, it does not guarantee that no data loss will occur due to technical failures, cyber attacks or third-party causes. Users are responsible for keeping their own copies of participant lists, Participation Certificates and other information important for an Event.
23.4. You are responsible for using the latest version of the app; some features may not work in older versions.

24. Limitation of Liability
24.1. To the maximum extent permitted by applicable law, Regipass cannot be held liable for any direct or indirect material or non-material damage, including loss of profit, reputation or opportunity, arising from the Events, Content, conduct, payment disputes and data processing activities of Organizers or other users; incidents during Events; errors in entry, attendance or Participation Certificate processes; notifications not arriving; outages, errors or data loss on the Platform; or third-party services.
24.2. The Platform is provided free of charge to Participants. Therefore, and to the extent permitted by Article 115 of Turkish Code of Obligations No. 6098, Regipass is not liable for damage arising from its slight negligence; Regipass is liable only for damage it causes through its own intent or gross negligence. If paid services are provided to Organizers, Regipass's total liability to an Organizer is limited to the total fees paid by that Organizer to Regipass in the 12 (twelve) months before the event giving rise to the claim.
24.3. The limitations in this Section do not apply to damage arising from Regipass's intent or gross negligence, to damage to life or bodily integrity caused by Regipass's own fault, or to cases where mandatory law (including Consumer Protection Law No. 6502 and KVKK No. 6698) does not permit limitation. No provision of this Agreement removes consumers' rights under mandatory provisions.

25. User's Indemnity Obligation
Participants and Organizers agree to cover the damage arising from all claims, lawsuits, penalties and costs (including reasonable attorney fees) brought against Regipass because they violated this Agreement or the law, provided false information, shared Content or infringed third-party rights.

26. Intellectual Property
26.1. The Regipass brand, logo, interface design, software, texts and all intellectual and industrial property rights of the Platform belong to Regipass or its licensors. Copying, reverse engineering, reproducing or using the Platform commercially without permission is prohibited.
26.2. Rights in Content uploaded to the Platform belong to the uploading party. By uploading Content, you grant Regipass a worldwide, non-exclusive, royalty-free and sub-licensable licence to use, reproduce, adapt and display that Content for operating the Platform, promoting the Event (including Event Link previews, share images and QR posters) and promoting the Platform. You warrant that you have all necessary rights to the Content you upload.

27. Demo Environment
The Demo is a public showcase environment that runs on fictional people, clubs and Events and is reset regularly. You must not enter real personal data in the Demo; the information you enter may be seen by other visitors and is deleted without notice. Actions in the Demo do not create any real registration, ticket or Participation Certificate, and the Demo is provided without any warranty.

28. Suspension, Termination and Account Deletion
28.1. Regipass may suspend, restrict or close an account and remove Events and Content without prior notice in case of a breach of this Agreement, suspected illegal activity, security risk, long-term inactivity, a request from the competent authorities or other cases it deems necessary to protect the Platform.
28.2. You may close your account at any time through the Platform or by applying to product@regipass.com. After an account deletion request, your account is closed and your personal data is deleted or anonymized at the end of the periods stated in the Data Protection Notice. If an Organizer account is closed, future Events may be cancelled.
28.3. Termination does not affect rights and obligations that arose before termination, or the provisions on indemnity, limitation of liability, intellectual property, evidence and dispute resolution.

29. Force Majeure
Regipass is not liable for failure to perform its obligations due to events beyond its reasonable control, such as natural disasters, epidemics, war, terrorism, strikes, fire, power or internet outages, cyber attacks, third-party infrastructure failures, legal regulations or decisions of official authorities.

30. Evidence Agreement
The parties agree that in disputes arising from this Agreement, Regipass's electronic records, server and transaction logs, consent records and correspondence constitute valid evidence under Article 193 of Turkish Code of Civil Procedure No. 6100; this does not remove the right to submit counter-evidence.

31. Amendments
Regipass may update this Agreement. The current text is published on the Platform. Changes that materially affect your rights or obligations are announced on the Platform and your renewed acceptance is requested; if you do not accept, you cannot continue to use the Platform and you may close your account.

32. Assignment
Regipass may transfer its rights and obligations under this Agreement to a company or third party that takes over or operates the Platform; this will be announced on the Platform. Users and Organizers may not transfer their rights under this Agreement without Regipass's written consent.

33. Miscellaneous
33.1. If any provision of this Agreement is held invalid, the validity of the other provisions is not affected; the invalid provision is deemed replaced by the valid provision closest to its purpose.
33.2. Regipass's failure to exercise or delay in exercising a right does not mean it waives that right.
33.3. This Agreement, together with the Data Protection Notice, the paid Event acknowledgment texts and other texts separately accepted on the Platform, constitutes the entire agreement between the parties.
33.4. The Agreement is prepared in Turkish and English; in case of conflict between the two texts, the Turkish text prevails.

34. Governing Law, Jurisdiction and Contact
34.1. This Agreement is governed by the laws of the Republic of Türkiye. Istanbul (Çağlayan) Courts and Enforcement Offices have jurisdiction over disputes. The right of Participants who are consumers to apply to Consumer Arbitration Committees and the Consumer Courts at their place of residence under Law No. 6502 is reserved.
34.2. Contact: product@regipass.com · 0850 888 35 58 · Kağıthane/Istanbul
''';

const String _kvkkTr = '''
REGİPASS KİŞİSEL VERİLERİN KORUNMASI KANUNU (KVKK) AYDINLATMA METNİ VE AÇIK RIZA METNİ
Son güncelleme tarihi: 02.10.2026 · Sürüm v1.1

1. Veri Sorumlusu
6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca kişisel verileriniz, veri sorumlusu sıfatıyla Regipass tarafından aşağıda açıklanan kapsamda işlenmektedir.
E-posta: product@regipass.com · Telefon: 0850 888 35 58
Bu metin; Platform'u hesap oluşturarak kullanan Katılımcılar ve Organizatör yetkilileri, hesap oluşturmadan Etkinlik Linki üzerinden kaydolan Misafir Katılımcılar, web sitesi ziyaretçileri ve iletişim formunu kullanan kişiler için geçerlidir. Terimler, Regipass Kullanıcı ve Organizatör Sözleşmesi'ndeki anlamlarıyla kullanılmıştır.

2. İşlenen Kişisel Veri Kategorileri
— Kimlik: Ad, soyad; (isteğe bağlı) cinsiyet; Organizatör yetkilisinin adı-soyadı.
— İletişim: E-posta adresi, telefon numarası, şehir.
— Eğitim: Üniversite, bölüm, sınıf, öğrenci numarası.
— Görsel: Profil fotoğrafı (yüklediyseniz), Organizatör logosu.
— Organizatör belgeleri: Kulüp Kuruluş Onay Belgesi, Yetkili Öğrenci Belgesi ve Organizatör başvurusunda yüklenen diğer belgeler ile bu belgelerde yer alan bilgiler.
— Etkinlik ve katılım işlemleri: Etkinlik kayıtları, bekleme listesi, kayıt iptalleri, Bilet ve QR kodu, kapıda giriş ve oturum yoklama kayıtları, ödeme durumu ("Ödendi" işareti), Katılım Belgeleri ve doğrulama kodları, Etkinlik değerlendirmeleri, takip edilen Organizatörler, Organizatör'ün sizi engelleme kaydı.
— Konum: Giriş veya yoklama anında tek seferlik alınan konum. Konumunuzun kendisi saklanmaz; yalnızca Etkinlik noktasına uzaklık ve konum doğruluğu bilgisi kaydedilir.
— Hukuki işlem ve onay: Sözleşme ve KVKK onaylarınız, ücretli Etkinlik onayları, ticari ileti ve veri paylaşım tercihleriniz (onay zamanı ve metin sürümüyle birlikte).
— İşlem güvenliği: Şifre (yalnızca şifrelenmiş olarak, kimlik doğrulama sağlayıcısında), oturum ve giriş kayıtları, IP adresi, cihaz ve tarayıcı bilgisi, anlık bildirim cihaz kimliği, SMS doğrulama işlemleri, yönetim işlem kayıtları.
— Bildirim ve iletişim: Size gönderilen uygulama içi bildirimler, e-postalar ve SMS'ler; iletişim formu üzerinden ilettiğiniz mesajlar.
— Misafir Katılımcı verileri: Ad, soyad, telefon (SMS ile doğrulanmış), e-posta, (istenirse) üniversite ve bölüm, kayıt ve Bilet bilgileri.

3. Kişisel Verilerin İşlenme Amaçları
— Hesap oluşturma, kimlik ve telefon doğrulama, giriş ve şifre sıfırlama işlemlerinin yürütülmesi;
— Etkinliklerin keşfedilmesi, size uygun Etkinliklerin önerilmesi (üniversite, bölüm ve takip ettiğiniz Organizatörlere göre sıralama);
— Etkinlik kaydı, hesapsız kayıt, kontenjan ve bekleme listesi, Bilet, kapıda giriş, oturum yoklaması ve konum doğrulamasının yapılması;
— Kapıda kimlik kontrolü için profil fotoğrafınızın Organizatör'e gösterilmesi;
— Katılım Belgelerinin oluşturulması, gönderilmesi ve doğrulanabilmesi;
— Organizatör başvurularının incelenmesi ve Organizatör hesaplarının yönetilmesi;
— Etkinlik değişikliği, hatırlatma, iptal, Katılım Belgesi ve güvenlik konularında bildirim (uygulama içi, anlık bildirim, e-posta, SMS) gönderilmesi;
— Ücretli Etkinliklerde Organizatör iletişim bilgisinin gösterilmesi ve onayların kayıt altına alınması;
— Platform güvenliğinin sağlanması, kötüye kullanım, sahte hesap ve dolandırıcılığın önlenmesi, engelleme ve hesap kapatma işlemlerinin yürütülmesi;
— Hukuki yükümlülüklerin yerine getirilmesi, yetkili mercilere bilgi verilmesi, uyuşmazlıklarda delil olarak kullanılması;
— Anonim veya toplu istatistiklerin üretilmesi, hizmet kalitesinin ölçülmesi ve geliştirilmesi;
— Talep, öneri ve şikâyetlerinizin yanıtlanması;
— (Ayrıca vereceğiniz açık rızaya bağlı olarak) ticari elektronik ileti gönderilmesi ve verilerinizin iş ortağı olmayan üçüncü kurum ve kuruluşlarla paylaşılması.

4. Hukuki Sebepler (KVKK m.5)
— Sözleşmenin kurulması ve ifası (m.5/2-c): Hesap, Etkinlik kaydı, hesapsız kayıt, Bilet, giriş, yoklama, Katılım Belgesi, bildirimler ve Organizatör ile paylaşım.
— Hukuki yükümlülük (m.5/2-ç): Mevzuattan doğan saklama, bildirim ve ibraz yükümlülükleri.
— Bir hakkın tesisi, kullanılması veya korunması (m.5/2-e): Onay kayıtları, işlem ve yönetim kayıtlarının saklanması.
— Meşru menfaat (m.5/2-f): Güvenlik, kötüye kullanımın önlenmesi, Etkinlik önerileri, anonim istatistikler.
— İlgili kişinin kendisi tarafından alenileştirilmesi (m.5/2-d): Organizatörlerin herkese açık profil ve Etkinlik bilgileri.
— Açık rıza (m.5/1): Ticari elektronik iletiler ve üçüncü kurumlarla paylaşım (Açık Rıza Metni'ndeki tercihler).
Platform özel nitelikli kişisel veri (sağlık, din, siyasi görüş vb.) toplamayı amaçlamaz; bu tür verileri Platform'a girmemeniz gerekir. Organizatör belgelerinde veya İçeriklerde bu tür veri bulunursa sorumluluk belgeyi veya İçeriği yükleyene aittir.

5. Kişisel Verilerin Aktarıldığı Taraflar
5.1. Etkinliğin Organizatörü. Bir Etkinliğe kaydolduğunuzda (hesapla veya hesapsız) ad-soyad, e-posta, telefon, üniversite, bölüm, sınıf, profil fotoğrafı, kayıt, Bilet, giriş, yoklama, ödeme durumu, Katılım Belgesi ve değerlendirme bilgileriniz, Etkinliğin yürütülmesi amacıyla yalnızca o Etkinliğin Organizatörü ile paylaşılır. Organizatör bu verileri görüntüleyebilir ve liste olarak indirebilir; Organizatör bu veriler bakımından kendisi ayrı bir veri sorumlusudur ve verileri yalnızca Etkinlik amacıyla kullanmakla yükümlüdür.
5.2. Ücretli Etkinliklerde Organizatör yetkilisinin iletişim bilgisi, ödemeyi organize edebilmeniz için size gösterilir.
5.3. Katılım Belgesi doğrulaması. Katılım Belgenizdeki doğrulama kodunu bilen herkes, doğrulama sayfasında belgenin geçerliliğini, adınızı, Etkinliğin adını ve tarihini görebilir.
5.4. Hizmet sağlayıcılar (veri işleyenler). Platform'un çalışması için verileriniz aşağıdaki hizmet sağlayıcılara aktarılır veya bunların sunucularında barındırılır:
— Google LLC / Google Ireland Ltd. (Firebase ve Google Cloud): veritabanı, dosya depolama, kimlik doğrulama, Google ile giriş, sunucu işlemleri, web barındırma, anlık bildirim, SMS doğrulama, web yazı tipleri;
— Apple Inc.: Apple ile giriş, iOS anlık bildirimleri, Apple Wallet;
— E-posta gönderim hizmeti sağlayıcısı (Brevo / Sendinblue SAS, Fransa) ve Regipass'in kurumsal e-posta altyapısı;
— Uygulama mağazaları (Apple App Store, Google Play) ve, kullanıyorsanız, Google Wallet.
5.5. Yetkili kamu kurum ve kuruluşları, mahkemeler, savcılıklar ve kolluk: Hukuki yükümlülük kapsamında ve usulüne uygun talep hâlinde.
5.6. Regipass'in hizmetlerini devralacak veya işletecek bir şirket: Platform'un bir şirkete devri hâlinde, aynı amaçlarla sınırlı olarak.
5.7. (Açık rızanıza bağlı olarak) iş ortağı olmayan üçüncü kurum ve kuruluşlar: Yalnızca Açık Rıza Metni'ndeki ilgili tercihi işaretlemeniz hâlinde ve rızanızı geri çekene kadar.

6. Kişisel Verilerin Yurt Dışına Aktarılması
6.1. Platform'un teknik altyapısı gereği kişisel verileriniz yurt dışında bulunan sunucularda barındırılır ve işlenir: ana veritabanı, dosya depolama (us-east1) ve kimlik doğrulama hizmetleri Amerika Birleşik Devletleri'ndeki; sunucu işlemleri ABD'deki ve Avrupa Birliği'ndeki (Belçika) Google veri merkezlerinde; e-postalar Avrupa Birliği'ndeki (Fransa) sağlayıcı aracılığıyla işlenir. Apple ve uygulama mağazası hizmetleri bu şirketlerin kendi altyapılarında, ağırlıklı olarak ABD'de işlenir.
6.2. Bu aktarımlar, KVKK m.9 uyarınca Kişisel Verileri Koruma Kurulu tarafından ilan edilen standart sözleşmeler başta olmak üzere kanunda öngörülen uygun güvencelerden birine dayanılarak yapılır. Uygun güvencenin sağlanamadığı arızi hâllerde aktarım, KVKK m.9/6'da sayılan istisnalara (sözleşmenin ifası için zorunlu olması veya açık rızanız) dayanılarak gerçekleştirilir.
6.3. Platform şu anda Türkiye'de barındırma seçeneği sunmamaktadır. Verilerinizin yurt dışında işlenmesini istemiyorsanız Platform'u kullanmamanız gerekir.

7. Saklama Süreleri
— Hesap verileri: Hesabınız açık olduğu sürece. Hesap silme talebinden sonra hesap kapatılır ve veriler 30 gün içinde silinir; bu sürede talep geri alınabilir.
— Misafir Katılımcı verileri: Etkinliğin bitiminden itibaren yaklaşık 30 gün; sonra silinir veya anonimleştirilir.
— Etkinlik, kayıt, yoklama ve Katılım Belgesi kayıtları: Hesabınız açık olduğu sürece; hesap silindiğinde silinir. Organizatör'ün kendi cihazına indirdiği listeler Organizatör'ün sorumluluğundadır.
— Konum: Konumun kendisi saklanmaz; uzaklık/doğruluk bilgisi ilgili yoklama kaydıyla birlikte saklanır.
— Onay kayıtları (sözleşme, KVKK, ücretli Etkinlik ve ticari ileti onayları): Olası uyuşmazlıklarda ispat için, ilişkinin sona ermesinden itibaren 10 yıla kadar.
— Güvenlik, işlem ve yönetim kayıtları: İlgili mevzuattaki süreler ve zamanaşımı süreleri boyunca, en fazla 10 yıl.
— Demo ortamına girilen veriler: Demo düzenli olarak (en geç her gece) sıfırlanır.
Süre sonunda veriler silinir, yok edilir veya anonim hâle getirilir.

8. Ticari Elektronik İletiler
Kampanya, tanıtım veya üçüncü taraf teklifleri içeren iletiler (SMS, e-posta, anlık bildirim), 6563 sayılı Kanun ve İleti Yönetim Sistemi (İYS) mevzuatı uyarınca yalnızca ayrıca vereceğiniz onayla gönderilir. Onayınızı dilediğiniz zaman ayarlardan, İYS üzerinden veya iletideki bağlantıyla ücretsiz olarak geri alabilirsiniz. Hesap, güvenlik, Etkinlik ve Katılım Belgesi bildirimleri bu onaya tabi değildir.

9. Haklarınız (KVKK m.11)
Veri sorumlusuna başvurarak; kişisel verinizin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, işlenme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenme, yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme, eksik veya yanlış işlenmişse düzeltilmesini isteme, KVKK m.7 çerçevesinde silinmesini veya yok edilmesini isteme, düzeltme ve silme işlemlerinin aktarıldığı üçüncü kişilere bildirilmesini isteme, münhasıran otomatik sistemlerle analiz sonucu aleyhinize bir sonuç çıkmasına itiraz etme ve kanuna aykırı işleme nedeniyle zarara uğramanız hâlinde zararın giderilmesini talep etme haklarına sahipsiniz.
Organizatör'ün kendi cihazına indirdiği veya Platform dışında işlediği verilerle ilgili başvurularınızı doğrudan Organizatör'e de yapabilirsiniz.

10. Başvuru Yöntemi
Taleplerinizi, kimliğinizi tevsik eden bilgilerle birlikte product@regipass.com adresine kayıtlı e-posta adresinizden iletebilirsiniz. Yazılı başvuru için posta adresini bu e-posta üzerinden talep edebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz sonuçlandırılır; işlemin ayrıca bir maliyet gerektirmesi hâlinde Kurul'un belirlediği tarife uygulanabilir.

AÇIK RIZA METNİ
Aşağıdaki tercihler isteğe bağlıdır, ayrı ayrı sunulur ve varsayılan olarak işaretsizdir. İşaretlememeniz Platform'un temel işlevlerinden (hesap, Etkinlik kaydı, Bilet, giriş, yoklama, Katılım Belgesi) yararlanmanızı engellemez.
Yukarıdaki REGİPASS KVKK Aydınlatma Metni'ni okuduğumu ve anladığımı beyan ederim. Bu kapsamda:
— Kişisel verilerimin, işbu metnin 5.7. maddesinde açıklandığı üzere, reklam, pazarlama, araştırma ve iş geliştirme amacıyla iş ortağı olmayan üçüncü kurum ve kuruluşlarla paylaşılmasına (bu kurumların yurt dışında bulunması hâlinde yurt dışına aktarılmasına) açık rızam vardır.
— Tarafıma ticari elektronik ileti (kampanya, duyuru, indirim, üçüncü taraf teklifleri) SMS, e-posta ve/veya anlık bildirim yoluyla gönderilmesine onay veriyorum.
Not: Her bir tercih, ayarlar menüsünden veya product@regipass.com adresine başvurarak dilediğiniz zaman, geçmişe etkili olmaksızın geri çekilebilir.
''';

const String _kvkkEn = '''
REGIPASS PERSONAL DATA PROTECTION LAW (KVKK) DATA PROTECTION NOTICE AND EXPLICIT CONSENT FORM
Last updated: 02.10.2026 · Version v1.1

1. Data Controller
Under Turkish Personal Data Protection Law No. 6698 ("KVKK"), your personal data is processed, as data controller, by Regipass within the scope described below.
Email: product@regipass.com · Phone: 0850 888 35 58
This notice applies to Participants and Organizer representatives who use the Platform with an account, Guest Participants who register through an Event Link without an account, website visitors and people who use the contact form. Terms have the meanings given in the Regipass User and Organizer Agreement.

2. Categories of Personal Data Processed
— Identity: First name, last name; (optional) gender; name of the Organizer's representative.
— Contact: Email address, phone number, city.
— Education: University, department, year, student number.
— Visual: Profile photo (if uploaded), Organizer logo.
— Organizer documents: Club Establishment Approval Document, Authorized Student Document and other documents uploaded in an Organizer application, and the information they contain.
— Event and participation transactions: Event registrations, waitlist, cancellations, Ticket and QR code, door entry and session attendance records, payment status ("Paid" mark), Participation Certificates and verification codes, Event reviews, followed Organizers, records of an Organizer blocking you.
— Location: Location collected once at the moment of entry or attendance. Your location itself is not stored; only the distance to the Event point and the location accuracy are recorded.
— Legal transaction and consent: Your Agreement and KVKK acceptances, paid Event acknowledgments, commercial message and data sharing preferences (with time of consent and text version).
— Transaction security: Password (only in encrypted form, at the authentication provider), session and login records, IP address, device and browser information, push notification device identifier, SMS verification transactions, administrative action logs.
— Notifications and communication: In-app notifications, emails and SMS sent to you; messages you send through the contact form.
— Guest Participant data: First name, last name, phone (verified by SMS), email, (if requested) university and department, registration and Ticket information.

3. Purposes of Processing
— Creating accounts, verifying identity and phone, running sign-in and password reset;
— Discovering Events and recommending Events suited to you (sorting by university, department and Organizers you follow);
— Event registration, guest registration, capacity and waitlist, Tickets, door entry, session attendance and location verification;
— Showing your profile photo to the Organizer for identity checks at the door;
— Generating, sending and enabling verification of Participation Certificates;
— Reviewing Organizer applications and managing Organizer accounts;
— Sending notifications (in-app, push, email, SMS) about Event changes, reminders, cancellations, Participation Certificates and security;
— Showing Organizer contact details for paid Events and recording acknowledgments;
— Ensuring Platform security, preventing misuse, fake accounts and fraud, and carrying out blocking and account closure;
— Fulfilling legal obligations, providing information to competent authorities and use as evidence in disputes;
— Producing anonymous or aggregate statistics and measuring and improving service quality;
— Responding to your requests, suggestions and complaints;
— (Subject to your separate explicit consent) sending commercial electronic messages and sharing your data with third-party institutions that are not business partners.

4. Legal Grounds (KVKK Art. 5)
— Establishment and performance of a contract (Art. 5/2-c): Account, Event registration, guest registration, Ticket, entry, attendance, Participation Certificate, notifications and sharing with the Organizer.
— Legal obligation (Art. 5/2-ç): Retention, notification and disclosure obligations arising from legislation.
— Establishment, exercise or protection of a right (Art. 5/2-e): Retention of consent records, transaction and administrative logs.
— Legitimate interest (Art. 5/2-f): Security, prevention of misuse, Event recommendations, anonymous statistics.
— Data made public by the data subject (Art. 5/2-d): Public profile and Event information of Organizers.
— Explicit consent (Art. 5/1): Commercial electronic messages and sharing with third-party institutions (preferences in the Explicit Consent Form).
The Platform does not aim to collect special categories of personal data (health, religion, political opinion, etc.); you must not enter such data on the Platform. If such data appears in Organizer documents or Content, the person who uploaded it is responsible.

5. Recipients of Personal Data
5.1. The Event's Organizer. When you register for an Event (with or without an account), your name, email, phone, university, department, year, profile photo, registration, Ticket, entry, attendance, payment status, Participation Certificate and review information is shared only with that Event's Organizer for the purpose of running the Event. The Organizer can view this data and download it as a list; the Organizer is an independent data controller for this data and is obliged to use it only for the Event.
5.2. For paid Events, the contact details of the Organizer's representative are shown to you so that you can arrange payment.
5.3. Participation Certificate verification. Anyone who knows the verification code on your Participation Certificate can see on the verification page whether the certificate is valid, your name and the Event's name and date.
5.4. Service providers (data processors). For the Platform to work, your data is transferred to or hosted on the servers of the following service providers:
— Google LLC / Google Ireland Ltd. (Firebase and Google Cloud): database, file storage, authentication, Sign in with Google, server functions, web hosting, push notifications, SMS verification, web fonts;
— Apple Inc.: Sign in with Apple, iOS push notifications, Apple Wallet;
— Email delivery provider (Brevo / Sendinblue SAS, France) and Regipass's business email infrastructure;
— App stores (Apple App Store, Google Play) and, if you use it, Google Wallet.
5.5. Competent public institutions, courts, prosecutors and law enforcement: Within the scope of legal obligations and upon a duly made request.
5.6. A company that takes over or operates Regipass's services: In case of a transfer of the Platform to a company, limited to the same purposes.
5.7. (Subject to your explicit consent) third-party institutions that are not business partners: Only if you tick the relevant preference in the Explicit Consent Form and until you withdraw your consent.

6. Transfer of Personal Data Abroad
6.1. Due to the Platform's technical infrastructure, your personal data is hosted and processed on servers located abroad: the main database, file storage (us-east1) and authentication services in Google data centers in the United States; server functions in Google data centers in the United States and the European Union (Belgium); emails through a provider in the European Union (France). Apple and app store services are processed on these companies' own infrastructure, mainly in the United States.
6.2. These transfers are made under KVKK Art. 9 on the basis of one of the appropriate safeguards provided by law, primarily the standard contracts announced by the Personal Data Protection Board. In occasional cases where an appropriate safeguard cannot be provided, the transfer is made on the basis of the exceptions listed in KVKK Art. 9/6 (necessity for the performance of a contract or your explicit consent).
6.3. The Platform currently does not offer hosting in Türkiye. If you do not want your data processed abroad, you should not use the Platform.

7. Retention Periods
— Account data: As long as your account is open. After an account deletion request, the account is closed and the data is deleted within 30 days; the request can be withdrawn during this period.
— Guest Participant data: Approximately 30 days from the end of the Event; then deleted or anonymized.
— Event, registration, attendance and Participation Certificate records: As long as your account is open; deleted when the account is deleted. Lists downloaded by the Organizer to its own device are the Organizer's responsibility.
— Location: The location itself is not stored; distance/accuracy information is kept with the relevant attendance record.
— Consent records (Agreement, KVKK, paid Event and commercial message consents): Up to 10 years from the end of the relationship, as proof in possible disputes.
— Security, transaction and administrative logs: For the periods in the relevant legislation and limitation periods, at most 10 years.
— Data entered in the Demo environment: The Demo is reset regularly (at the latest every night).
At the end of the period, data is deleted, destroyed or anonymized.

8. Commercial Electronic Messages
Messages containing campaigns, promotions or third-party offers (SMS, email, push notification) are sent only with your separate consent under Law No. 6563 and the Message Management System (İYS) legislation. You can withdraw your consent free of charge at any time from settings, through İYS or via the link in the message. Account, security, Event and Participation Certificate notifications are not subject to this consent.

9. Your Rights (KVKK Art. 11)
By applying to the data controller, you have the right to learn whether your personal data is processed; to request information if it has been processed; to learn the purpose of processing and whether it is used for that purpose; to know the third parties to whom it is transferred in Türkiye or abroad; to request correction if it is incomplete or inaccurate; to request deletion or destruction under KVKK Art. 7; to request that correction and deletion be notified to the third parties to whom it was transferred; to object to a result against you arising solely from analysis by automated systems; and to claim compensation if you suffer damage due to unlawful processing.
You may also apply directly to the Organizer regarding data the Organizer downloaded to its own device or processes outside the Platform.

10. How to Apply
You can send your requests, together with information verifying your identity, from your registered email address to product@regipass.com. For a written application you can request the postal address through this email. Applications are concluded free of charge within 30 days at the latest; if the process requires an additional cost, the fee schedule set by the Board may apply.

EXPLICIT CONSENT FORM
The preferences below are optional, presented separately and unticked by default. Not ticking them does not prevent you from using the core functions of the Platform (account, Event registration, Ticket, entry, attendance, Participation Certificate).
I declare that I have read and understood the REGIPASS KVKK Data Protection Notice above. Accordingly:
— I give my explicit consent to my personal data being shared with third-party institutions that are not business partners for advertising, marketing, research and business development purposes, as explained in Section 5.7 of this notice (and to its transfer abroad if these institutions are located abroad).
— I consent to receiving commercial electronic messages (campaigns, announcements, discounts, third-party offers) via SMS, email and/or push notification.
Note: Each preference can be withdrawn at any time, without retroactive effect, from the settings menu or by applying to product@regipass.com.
''';
