/// Kayıt ekranındaki zorunlu onay metinlerinin kaynağı.
///
/// Metinler, kullanıcının sağladığı iki sözleşme belgesinden
/// (Kullanıcı ve Kulüp Sözleşmesi, KVKK Aydınlatma Metni ve Açık Rıza Metni)
/// birebir alınmıştır. Elle düzenlenmemelidir — güncelleme gerektiğinde
/// kaynak belgeler yeniden bu dosyaya aktarılmalıdır.
library;

/// Onay kaydına yazılan belge sürümü.
///
/// KVKK Aydınlatma Metni madde 7, onay kaydında "onaylanan metin sürümü"nün
/// de saklanmasını istiyor: kullanıcının hangi metne onay verdiği sonradan
/// ispatlanabilmeli. Belgeler güncellendiğinde bu değer de güncellenmelidir.
const String kLegalDocsVersion = '2026-09-02';

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
  titleTr: 'Kullanıcı ve Kulüp Sözleşmesi',
  titleEn: 'User and Club Agreement',
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
REGİPASS KULLANICI VE KULÜP SÖZLEŞMESİ
Son güncelleme tarihi: 02.09.2026

1. Taraflar ve Tanımlar
1.1. İşbu Sözleşme ("Sözleşme"), bir yanda Arda Güler (Vergi durumu: Potansiyel Mükellef — Kale Vergi Dairesi Müdürlüğü, VKN: 4170596815; adres: Merkez Mahallesi, Kağıthane/İstanbul), "Regipass" markası altında hizmet sunan gerçek kişi ("Regipass", "biz") ile diğer yanda:
Platform'u indiren, kaydolan veya herhangi bir şekilde kullanan gerçek kişi ("Kullanıcı", "siz") ve/veya
Platform üzerinde kulüp/organizatör hesabı oluşturan topluluk, öğrenci kulübü veya organizasyon ("Kulüp")
arasında, ilgili tarafın Platform'a kaydolması ve işbu Sözleşme'yi elektronik ortamda onaylaması ile yürürlüğe girer. Aynı kişi hem bireysel Kullanıcı hem de bir Kulüp'ü temsil eden yetkili olabilir; bu durumda Sözleşme'nin hem Bölüm A hem Bölüm B hükümleri o kişi/kulüp için geçerli olur. Kulüp adına işlem yapan kişi, bu işlemi yapmaya yetkili olduğunu beyan ve taahhüt eder.
1.2. Tanımlar:
Platform: Regipass mobil uygulaması, web sitesi ve ilgili tüm dijital hizmetler.
Kulüp: Platform üzerinde etkinlik oluşturan, yöneten ve Kullanıcıların katılımını/yoklamasını takip eden üniversite kulübü, topluluğu veya organizasyonu.
Etkinlik: Bir Kulüp tarafından Platform üzerinden duyurulan/yönetilen her türlü faaliyet, toplantı, seminer, sosyal veya kültürel organizasyon.
İçerik: Kulüpler veya Kullanıcılar tarafından Platform'a yüklenen veya Platform aracılığıyla paylaşılan her türlü metin, görsel, açıklama, etkinlik detayı veya diğer materyal.
Sertifika: Kullanıcının bir Etkinliğe katılımını Kulüp tarafından belirlenen kriterlere göre gösteren, Platform tarafından otomatik olarak oluşturulan dijital belge.

2. Hizmetin Niteliği
2.1. Regipass, üniversite öğrencilerinin yakınlarındaki etkinlikleri keşfetmesini, bu etkinliklere kolayca kayıt olmasını, konum doğrulamalı check-in yapmasını ve uygun olduğunda otomatik olarak oluşturulan katılım sertifikalarına erişmesini sağlayan; Kulüplere de etkinlik yönetimi, yoklama takibi ve sertifika üretimi imkânı sunan bir aracı teknoloji platformudur.
2.2. Regipass, 6563 sayılı Elektronik Ticaretin Düzenlenmesi Hakkında Kanun ve 5651 sayılı İnternet Ortamında Yapılan Yayınların Düzenlenmesi ve Bu Yayınlar Yoluyla İşlenen Suçlarla Mücadele Edilmesi Hakkında Kanun kapsamında yer sağlayıcı ve aracı hizmet sağlayıcı sıfatıyla hareket eder. Regipass, Etkinlikleri düzenlemez, organize etmez, yönetmez veya bu Etkinliklerin bir tarafı değildir; Etkinlikler münhasıran ilgili Kulüplerin sorumluluğu ve inisiyatifindedir.
2.3. Regipass, hiçbir üniversite, öğrenci topluluğu veya kamu kurumu ile resmî bir bağlılık, ortaklık veya temsil ilişkisi içinde değildir; Platform bağımsız bir teknoloji hizmeti olarak sunulur.

3. Bu Sözleşmenin Kapsamı
3.1. İşbu Sözleşme üç bölümden oluşur:
Bölüm A (madde 4-10): Yalnızca bireysel Kullanıcılar için geçerlidir.
Bölüm B (madde 11-15): Yalnızca Kulüp/organizatör hesapları için geçerlidir.
Bölüm C (madde 16-23): Her iki taraf için de geçerli ortak hükümleri içerir.
3.2. Regipass, Platform'un Kullanıcılara veya Kulüplere sunduğu hizmetlerin kapsamını, özelliklerini ve ücretlendirme modelini önceden bildirimde bulunmak kaydıyla değiştirme, ücretli paketler/abonelikler oluşturma veya mevcut ücretsiz özellikleri ücretli hale getirme hakkını saklı tutar. Regipass, ne Kullanıcılara ne de Kulüplere süresiz/ömür boyu ücretsiz kullanım hakkı taahhüt etmemektedir.

BÖLÜM A — KULLANICILARA (ÖĞRENCİLERE) ÖZEL HÜKÜMLER

4. Üyelik ve Hesap Şartları
4.1. Platform'a kayıt olabilmek için 18 yaşını doldurmuş olmanız gerekir. 18 yaşından küçük kişilerin Platform'u kullanması yasaktır; bu şartın ihlal edildiğinin tespiti hâlinde ilgili hesap derhal askıya alınır veya kapatılır.
4.2. Kayıt sırasında verdiğiniz bilgilerin (ad-soyad, üniversite, bölüm, e-posta, telefon vb.) doğru, güncel ve eksiksiz olduğunu kabul, beyan ve taahhüt edersiniz. Yanlış veya yanıltıcı bilgi verilmesi, sertifikaların ve katılım kayıtlarının geçersiz sayılmasına ve/veya hesabın kapatılmasına yol açabilir.
4.3. Hesap bilgilerinizin (şifre dahil) gizliliğinden ve hesabınız üzerinden gerçekleştirilen tüm işlemlerden münhasıran siz sorumlusunuz. Hesabınızla ilgili yetkisiz kullanım şüphesi hâlinde derhal bize bildirmelisiniz.

5. Kullanıcı Yükümlülükleri ve Yasak Kullanım
5.1. Platform'u yalnızca hukuka, ahlaka ve işbu Sözleşme'ye uygun amaçlarla kullanacağınızı kabul edersiniz. Aşağıdaki davranışlar kesinlikle yasaktır ve tespiti hâlinde hesabınızın süresiz olarak askıya alınmasına, yetkili mercilere bildirimde bulunulmasına ve hukuki/cezai sorumluluğunuza yol açabilir:
— Terör örgütü propagandası yapmak, terör örgütlerini veya şiddeti öven, teşvik eden ya da meşrulaştıran içerik paylaşmak;
— Nefret söylemi, ayrımcılık, ırkçılık, cinsiyetçilik veya herhangi bir gruba yönelik düşmanlık içeren içerik paylaşmak;
— Şiddeti, yasa dışı silah/uyuşturucu ticaretini, dolandırıcılığı veya başka bir suçu teşvik eden ya da bu amaçla kullanılan Etkinlikler/İçerikler oluşturmak;
— Kişilik haklarını, fikri mülkiyet haklarını veya üçüncü kişilerin gizlilik haklarını ihlal eden içerik paylaşmak;
— Cinsel istismar, çocukların cinsel istismarı veya reşit olmayanları hedef alan her türlü içerik (bu tür içerikler tespit edildiği anda yetkili mercilere bildirilir);
— Sahte, yanıltıcı veya kullanıcıları/kulüpleri dolandırma amacı taşıyan Etkinlikler oluşturmak;
— Platform'un teknik altyapısına zarar verecek, işleyişini bozacak veya yetkisiz erişim sağlayacak faaliyetlerde bulunmak (kötü amaçlı yazılım, bot, kazıma/scraping, sahte konum/check-in bilgisi ile sertifika elde etme vb.);
— Başka bir kişinin kimliğine bürünmek veya sahte hesap oluşturmak.
5.2. Regipass, Platform üzerinde paylaşılan İçerikleri önceden denetleme yükümlülüğü altında değildir ve teknik olarak her Etkinlik/İçeriği önceden inceleme imkânına sahip değildir — tıpkı bir sosyal medya platformunun kullanıcı paylaşımlarını önceden denetleyememesi gibi. Ancak, bir İçeriğin yukarıdaki maddeleri ihlal ettiğine dair bize (aşağıdaki iletişim kanallarından) bildirim yapılması veya bu durumun tarafımızca fark edilmesi hâlinde, 5651 sayılı Kanun kapsamındaki "bildirim üzerine kaldırma" yükümlülüğümüz doğrultusunda ilgili İçeriği makul süre içinde kaldırır, ilgili hesabı askıya alabilir ve gerektiğinde yetkili adli/idari mercilere bildirimde bulunabiliriz.
5.3. İhbar için: regipass.product@gmail.com

6. İçerik ve Etkinliklerden Sorumluluğun Reddi
6.1. Platform üzerinde yayınlanan tüm Etkinlik bilgileri, açıklamaları, görseller, katılım koşulları ve diğer İçerikler ilgili Kulüp tarafından oluşturulur ve bunların doğruluğundan, hukuka uygunluğundan ve içeriğinden münhasıran ilgili Kulüp sorumludur.
6.2. Regipass, bir Etkinliğin gerçek olup olmadığını, gerçekleşip gerçekleşmeyeceğini, iptal edilip edilmeyeceğini, içeriğinin doğruluğunu, güvenliğini veya Kulüp tarafından verilen taahhütlerin yerine getirilip getirilmeyeceğini garanti etmez ve bu hususları önceden doğrulama yükümlülüğü altında değildir. Bir Etkinliğin sahte, yanıltıcı veya gerçekte var olmayan bir etkinlik ("naylon etkinlik") olması hâlinde dahi, Regipass bu Etkinliğe güvenerek hareket etmenizden doğabilecek hiçbir maddi veya manevi zarardan sorumlu tutulamaz. Bir Etkinliğe katılım kararı tamamen Kullanıcının kendi sorumluluğundadır.
6.3. Regipass, herhangi bir Kulüp'ün veya Kullanıcının Platform üzerinden paylaştığı İçerik veya gerçekleştirdiği Etkinlik nedeniyle üçüncü kişilere veya diğer Kullanıcılara verilen doğrudan veya dolaylı hiçbir maddi veya manevi zarardan sorumlu tutulamaz. Bu tür uyuşmazlıklarda taraf, ilgili İçeriği paylaşan veya Etkinliği düzenleyen Kulüp/Kullanıcı'dır.

7. Etkinlik Ücretleri ve Ödeme Toplama — Kullanıcı Açısından
7.1. Bazı Etkinlikler ücretli olabilir. Bu tür Etkinliklerde ücretin belirlenmesi, tahsili ve yönetimi münhasıran ilgili Kulüp'ün sorumluluğundadır. Regipass, bu ödemelerde bir ödeme kuruluşu, aracı ödeme hizmeti sağlayıcısı, emanetçi (escrow) veya taraf değildir; ödemeler Kulüp'ün kendi belirlediği yöntemlerle (banka hesabı, nakit, üçüncü taraf ödeme uygulamaları vb.) doğrudan Kulüp tarafından tahsil edilir.
7.2. Regipass, Kulüpler tarafından toplanan ücretlerin iadesi, kullanım amacı, şeffaflığı veya Kulüp'ün mali güvenilirliği konusunda hiçbir garanti veya taahhütte bulunmaz ve bu hususlarda herhangi bir sorumluluk kabul etmez. Ödeme yaptığınız Kulüp ile aranızda çıkabilecek her türlü uyuşmazlıkta muhatabınız ilgili Kulüp'tür; Regipass bu uyuşmazlıklara taraf olmayacak ve arabuluculuk yapma yükümlülüğü bulunmayacaktır.
7.3. Ücretli bir Etkinliğe kayıt olmanız hâlinde, Platform ödeme işlemini kendisi gerçekleştirmez; bunun yerine, ilgili Kulüp'ün Platform'a kendisinin girdiği yetkili temsilcisinin iletişim bilgileri (telefon numarası ve/veya e-posta adresi) ekranda tarafınıza gösterilir ve ödemeyi organize edebilmeniz için bu kişiyle doğrudan iletişime geçmeniz istenir. Bu ekranda ve/veya bu aşamadan sonra kurduğunuz iletişimde ödeme, Regipass'ın sistemleri dışında, tamamen sizinle Kulüp yetkilisi arasında gerçekleşir; Regipass, gösterilen iletişim bilgisinin güncelliğinden veya doğruluğundan, iletişime geçtiğiniz kişinin gerçekten Kulüp'ün yetkilisi olup olmadığından, ödemenin yapılıp yapılmadığından, tahsil edilen tutarın kullanım amacına uygunluğundan veya olası dolandırıcılık/güven ilişkisi sorunlarından hiçbir şekilde sorumlu tutulamaz. Ödeme yapmadan önce, muhatabınızın gerçekten ilgili Kulüp'ün yetkilisi olduğunu ve ödeme koşullarını teyit etmeniz önerilir.
7.4. ZORUNLU ONAY — LOGLANIR. Ücretli bir Etkinliğe kayıt işlemini tamamlamadan hemen önce, aşağıdaki onayı ayrıca ve açıkça vermeniz istenir; bu onay madde 7.3'te açıklanan sorumluluk reddini tek tek her ücretli etkinlik kaydında teyit etmenizi sağlar ve ayrıca kayıt altına alınır (loglanır):
"Ödeme sürecinin, Kulüp'ün Platform'a kendisinin girdiği yetkili temsilci iletişim bilgileri (telefon/e-posta) üzerinden ve Regipass'ın dışında, doğrudan Kulüp ile gerçekleştiğini; bu iletişim bilgisinin Kulüp tarafından girildiğini ve doğruluğunun Regipass tarafından teyit edilmediğini; karşı tarafın gerçekten yetkili olmayabileceğini, dolandırıcılık veya ödemenin karşılıksız kalması dahil hiçbir sonucun garanti edilmediğini; ve bu sürecin hiçbir aşamasında Regipass'ın sorumlu olmadığını anladım."
Bu onay verilmeden ücretli etkinlik kaydı tamamlanamaz.

8. Konum Verisi ve Check-in
8.1. Etkinliğe katılımınızın doğrulanması amacıyla, check-in işlemi sırasında konumunuz tek seferlik ve anlık olarak alınır. Regipass, arka planda sürekli veya Etkinlik dışı zamanlarda konum takibi yapmaz.
8.2. Konum verisinin işlenmesine ilişkin detaylar, ayrı olarak sunulan KVKK Aydınlatma Metni ve Açık Rıza Metni'nde yer almaktadır.

9. Sertifikalar
9.1. Sertifikalar, ilgili Kulüp tarafından Platform'a girilen katılım kriterlerine ve check-in verilerine dayanılarak otomatik olarak oluşturulur. Regipass, sertifika üzerindeki bilgilerin doğruluğunu garanti etmez; bu bilgilerin doğruluğundan ilgili Kulüp sorumludur.
9.2. Sertifikaların resmî bir kurum, üniversite veya devlet tarafından onaylanmış belge niteliği taşımadığını, yalnızca ilgili Kulüp'ün kendi kriterlerine göre düzenlediği bir katılım belgesi olduğunu kabul edersiniz.

10. Bildirimler
10.1. Regipass, hesabınızla, Etkinliklerle, sertifikalarla, güvenlikle veya Platform güncellemeleriyle ilgili bilgilendirme yapmak amacıyla kayıt sırasında verdiğiniz e-posta adresine ve/veya telefon numaranıza (SMS dahil) bildirim gönderebilir.
10.2. Ticari elektronik ileti niteliğindeki bildirimler (kampanya, tanıtım, üçüncü taraf teklifleri vb.) yalnızca 6563 sayılı Kanun uyarınca açık onayınız alındıktan sonra gönderilir ve dilediğiniz zaman ücretsiz olarak vazgeçme (opt-out) hakkına sahipsiniz.

BÖLÜM B — KULÜPLERE/ORGANİZATÖRLERE ÖZEL HÜKÜMLER

11. Kulüplere Sunulan Hizmetin Kapsamı
11.1. Regipass, Kulübe; etkinlik oluşturma ve duyurma, katılımcı kaydı toplama, konum doğrulamalı check-in ile yoklama takibi, katılım kriterlerine göre otomatik sertifika oluşturma ve temel katılımcı istatistiklerine erişim imkânı sunan bir Platform hizmeti sağlar.
11.2. Regipass, sunulan özellikleri, arayüzü ve kapasiteyi zaman içinde geliştirme, değiştirme veya bazı özellikleri kaldırma hakkını saklı tutar.

12. Ücretlendirme — Kulüpler İçin
12.1. Regipass hizmetleri, Regipass tarafından belirlenen ve zaman zaman güncellenebilen paket/abonelik modeline tabidir. Regipass, hiçbir Kulübe süresiz, ömür boyu veya değiştirilemez şekilde ücretsiz kullanım hakkı taahhüt etmemektedir; sunulan mevcut ücretsiz kullanım imkânları (varsa deneme süresi dahil) Regipass'ın tek taraflı takdirinde olup önceden bildirimde bulunmak kaydıyla değiştirilebilir, sınırlandırılabilir veya sona erdirilebilir.
12.2. Ücretli bir pakete geçiş söz konusu olduğunda, güncel fiyatlandırma ve ödeme koşulları Kulübe ayrıca bildirilir.
12.3. Regipass, ödemelerini zamanında yapmayan Kulüplerin hesabına erişimi askıya alma hakkını saklı tutar.

13. Kulübün Yükümlülükleri
Kulüp, aşağıdaki hususları kabul, beyan ve taahhüt eder:
13.1. Platform'a girdiği tüm Etkinlik bilgilerinin, katılım kriterlerinin ve sertifika şartlarının doğru, güncel ve yanıltıcı olmayan bilgiler olduğunu;
13.2. Düzenlediği Etkinliklerin ve bu Etkinliklere ilişkin tüm İçeriklerin yürürlükteki mevzuata, kamu düzenine ve genel ahlaka uygun olduğunu; özellikle terör propagandası, terör örgütü övgüsü, nefret söylemi, ayrımcılık, şiddet teşviki, yasa dışı faaliyetlerin tanıtımı veya teşviki niteliğinde hiçbir İçerik veya Etkinlik oluşturmayacağını;
13.3. Etkinliğin güvenli bir şekilde yürütülmesinden, gerekli izin/ruhsatların alınmasından ve katılımcıların güvenliğinden bizzat sorumlu olduğunu; Regipass'ın Etkinliğin fiziksel/organizasyonel yürütülmesine hiçbir surette karışmadığını ve bu konuda sorumluluk üstlenmediğini;
13.4. Platform üzerinden erişim sağladığı katılımcı kişisel verilerini yalnızca ilgili Etkinliğin yönetimi amacıyla kullanacağını; bu verileri KVKK ve ilgili mevzuata aykırı şekilde işlemeyeceğini, saklamayacağını, üçüncü kişilerle paylaşmayacağını veya pazarlama amacıyla kullanmayacağını; bu kapsamda katılımcıların kişisel verilerinin işlenmesinden Kulüp'ün de KVKK anlamında müstakil olarak sorumlu olabileceğini bildiğini;
13.5. Regipass marka, logo ve materyallerini yalnızca Regipass'ın önceden yazılı onayı ile ve Regipass'ın belirlediği marka kullanım kurallarına uygun şekilde kullanacağını.
13.6. Ücretli Etkinliklerde Yetkili İletişim Bilgisi. Ücretli bir Etkinlik oluşturması hâlinde, Kulüp; ödemeyi organize edecek yetkili bir temsilcisinin güncel telefon numarası ve/veya e-posta adresini Platform'a doğru şekilde gireceğini, bu bilginin güncelliğinden ve doğruluğundan bizzat sorumlu olduğunu ve bu bilginin, ödemeyi organize edebilmeleri amacıyla ilgili Etkinliğe kayıt olan katılımcılara Platform aracılığıyla gösterilmesine ayrıca onay verdiğini kabul eder.

14. Etkinlik İçeriği Sorumluluğu ve Tazminat
14.1. Regipass, Kulüpler tarafından oluşturulan Etkinlik ve İçerikleri önceden denetleme yükümlülüğü altında değildir. Regipass, bir İçeriğin madde 13.2'yi ihlal ettiğini tespit ettiğinde veya bu yönde bir bildirim aldığında, ilgili İçeriği önceden bildirimde bulunmaksızın kaldırma, ilgili Etkinliği yayından kaldırma ve/veya Kulüp hesabını askıya alma/feshetme hakkına sahiptir.
14.2. Kulüp, işbu madde 13'te yer alan taahhütlerin ihlali nedeniyle Regipass'ın üçüncü kişilerden, kamu kurumlarından veya diğer Kullanıcılardan gelebilecek her türlü talep, dava, şikayet, idari/adli soruşturma, ceza veya zarar ile karşı karşıya kalması hâlinde, Regipass'ı bu taleplerden doğan her türlü zarar, masraf (avukatlık ücretleri dahil) ve yükümlülüğe karşı tazmin edeceğini (indemnification) kabul eder.

15. Etkinlik Ücretleri ve Ödeme Toplama — Kulüp Açısından
15.1. Kulüp'ün düzenlediği ücretli Etkinliklerde katılım ücretinin belirlenmesi, duyurulması ve tahsili münhasıran Kulüp'ün sorumluluğundadır. Regipass, bu tahsilat sürecinde bir ödeme kuruluşu, aracı hizmet sağlayıcı, emanetçi (escrow) veya taraf olarak yer almaz.
15.2. Regipass'ın ödemeye ilişkin teknik rolü, madde 13.6 uyarınca Kulüp tarafından girilen yetkili temsilci iletişim bilgisinin, ödemeyi organize edebilmeleri amacıyla katılımcılara gösterilmesinden ibarettir. Regipass, bu bilginin doğruluğunu ayrıca doğrulama yükümlülüğü altında değildir; hatalı, güncel olmayan veya yanıltıcı iletişim bilgisi paylaşılmasından doğacak her türlü sonuçtan Kulüp sorumludur.
15.3. Regipass, Kulüp tarafından toplanan ücretlerin toplanması, transferi, kullanım amacına uygunluğu, harcanması, şeffaflığı, iadesi veya katılımcılara karşı Kulüp'ün mali güvenilirliği konusunda hiçbir denetim, garanti veya taahhütte bulunmaz.
15.4. Kulüp, katılımcılardan topladığı ücretlere ilişkin her türlü vergisel, ticari ve hukuki yükümlülükten (fatura/makbuz düzenleme dahil) bizzat sorumlu olduğunu kabul eder.
15.5. ZORUNLU ONAY — LOGLANIR. Kulüp, ücretli bir Etkinlik oluştururken, ilgili tüm bilgileri girdikten hemen sonra aşağıdaki onayı ayrıca ve açıkça vermelidir; bu onay her ücretli etkinlik oluşturma işleminde ayrıca ve kayıt altına alınarak (loglanarak) teyit edilir:
"Platform'a girdiğim tüm bilgilerin doğru ve güncel olduğunu; bu bilgilerin katılımcılara gösterilmesini onayladığımı; ücretli Etkinlikte tahsil edilecek paranın toplanması, transferi, kullanımı ve harcanması dahil ödeme sürecinin her aşamasının ve bu süreçten doğabilecek her türlü sonucun tamamen Kulübümüzün sorumluluğunda olduğunu, Regipass'ın bu konuların hiçbirinde herhangi bir sorumluluğu bulunmadığını kabul ve beyan ederim."
Bu onay verilmeden ücretli Etkinlik yayınlanamaz.

BÖLÜM C — ORTAK HÜKÜMLER

16. Kişisel Verilerin İşlenmesi
16.1. Kişisel verilerin hangi amaçlarla, hangi hukuki sebeplere dayanarak işlendiği, yurt dışına aktarımı (Frankfurt, Almanya'daki sunucular dahil) ve üçüncü kurumlarla paylaşımına ilişkin detaylı bilgi ile ilgili kişi hakları, ayrı olarak sunulan KVKK Aydınlatma Metni ve Açık Rıza Metni'nde yer almaktadır. Bir Etkinliğe kayıt olduğunuz anda, ad-soyad, üniversite/bölüm ve iletişim bilgileriniz gibi temel katılımcı bilgileriniz, yoklama ve sertifika süreçlerinin yürütülmesi amacıyla otomatik olarak ilgili Kulüp ile paylaşılır.
16.2. Regipass, katılımcı kişisel verilerini Kulüp'e yalnızca ilgili Etkinliğin yönetimi amacıyla ve Kullanıcıların işbu Sözleşme ve KVKK Aydınlatma Metni kapsamında onayladığı ölçüde aktarır.

17. Fikri Mülkiyet ve Marka Kullanımı
17.1. Regipass markası, logosu, arayüz tasarımı, yazılımı ve Platform'a ait tüm fikri ve sınai mülkiyet hakları Regipass'a veya lisans verenlerine aittir.
17.2. Kulüpler ve Kullanıcılar tarafından Platform'a yüklenen İçerikler üzerindeki mülkiyet hakları içeriği yükleyen tarafa aittir; ancak İçeriği yükleyerek, Regipass'a bu İçeriği Platform'un işletilmesi amacıyla kullanma konusunda dünya çapında, münhasır olmayan, ücretsiz bir lisans vermiş olursunuz.

18. Askıya Alma ve Fesih
18.1. Regipass, işbu Sözleşme'nin ihlali, yasa dışı faaliyet şüphesi, madde 5'te veya madde 13'te sayılan hâllerin tespiti veya yetkili mercilerin talebi üzerine, önceden bildirimde bulunmaksızın ilgili hesabı askıya alma veya kapatma hakkını saklı tutar.
18.2. Kullanıcı veya Kulüp, hesabını dilediği zaman kapatabilir; hesap kapatma talepleri regipass.product@gmail.com adresine iletilebilir.

19. Sorumluluğun Sınırlandırılması
19.1. Regipass, Platform'un kesintisiz, hatasız veya güvenlik açığı bulunmayan bir şekilde çalışacağını garanti etmez. Platform "olduğu gibi" (as-is) sunulmaktadır.
19.2. Yürürlükteki mevzuatın izin verdiği azami ölçüde, Regipass; Kulüplerin veya diğer Kullanıcıların İçerikleri, Etkinlikleri, ödeme uyuşmazlıkları veya davranışları nedeniyle doğan hiçbir doğrudan, dolaylı, arızi veya sonuç niteliğindeki maddi veya manevi zarardan sorumlu tutulamaz.
19.3. Kulüplere özel olarak: Regipass'ın işbu Sözleşme'den doğan bir Kulüp'e karşı toplam sorumluluğu, ilgili olayın gerçekleştiği tarihten önceki 12 (on iki) ay içinde o Kulüp tarafından Regipass'a ödenen toplam ücret tutarını aşmaz.
19.4. İşbu maddedeki sınırlamalar, Regipass'ın kendi ağır kusuru veya kastından doğan zararlar ile yürürlükteki mevzuatın sınırlanmasına izin vermediği sorumluluk hâlleri için geçerli değildir.

20. Gizlilik
Taraflar, işbu Sözleşme kapsamında birbirlerinden edindikleri ticari sır niteliğindeki bilgileri gizli tutmayı ve yalnızca Sözleşme'nin ifası amacıyla kullanmayı taahhüt eder.

21. Değişiklikler
Regipass, işbu Sözleşme'yi dilediği zaman güncelleyebilir. Önemli değişiklikler Platform üzerinden veya e-posta yoluyla duyurulur. Değişiklik sonrası Platform'u kullanmaya devam etmeniz, güncel Sözleşme'yi kabul ettiğiniz anlamına gelir.

22. Uygulanacak Hukuk ve Yetkili Mahkeme
İşbu Sözleşme, Türkiye Cumhuriyeti kanunlarına tabidir. Sözleşme'den doğabilecek her türlü uyuşmazlıkta İstanbul (Çağlayan) Mahkemeleri ve İcra Daireleri yetkilidir.

23. İletişim
Sorularınız için: regipass.product@gmail.com
Adres: Merkez Mahallesi, Kağıthane/İstanbul
''';

const String _contractEn = '''
REGIPASS USER AND CLUB AGREEMENT
Last updated: 02.09.2026

1. Parties and Definitions
1.1. This Agreement ("Agreement") is entered into between Arda Güler (tax status: Potential Taxpayer — Kale Tax Office, Tax ID: 4170596815; address: Merkez Mahallesi, Kağıthane/Istanbul, Turkey), an individual operating the service under the "Regipass" brand ("Regipass", "we") and, on the other side:
the individual who downloads, registers for, or otherwise uses the Platform ("User", "you"); and/or
the society, student club, or organization that creates a club/organizer account on the Platform ("Club"),
and takes effect when the relevant party registers on the Platform and accepts this Agreement electronically. The same person may be both an individual User and an authorized representative of a Club; in that case, both Part A and Part B of this Agreement apply to that person/Club as relevant. The person acting on behalf of the Club represents and warrants that they are duly authorized to do so.
1.2. Definitions:
Platform: The Regipass mobile application, website, and related digital services.
Club: A university club, society, or organization that creates and manages events and tracks user participation/attendance through the Platform.
Event: Any activity, meeting, seminar, or social or cultural gathering announced or managed by a Club through the Platform.
Content: Any text, image, description, event detail, or other material uploaded or shared by Clubs or Users through the Platform.
Certificate: A digital document automatically generated by the Platform reflecting a User's participation in an Event, based on criteria set by the relevant Club.

2. Nature of the Service
2.1. Regipass is an intermediary technology platform that allows university students to discover nearby events, register for them easily, check in with location verification, and, where applicable, access automatically generated participation certificates; it also provides Clubs with event management, attendance tracking, and certificate generation.
2.2. Regipass acts as a hosting provider and intermediary service provider under applicable Turkish law (including Law No. 6563 on the Regulation of Electronic Commerce and Law No. 5651 on the Regulation of Publications on the Internet). Regipass does not organize, run, or manage Events and is not a party to any Event; Events remain the sole responsibility and initiative of the relevant Clubs.
2.3. Regipass has no official affiliation, partnership, or representative relationship with any university, student organization, or public institution; the Platform is provided as an independent technology service.

3. Scope of This Agreement
3.1. This Agreement consists of three parts:
Part A (Sections 4-10): Applies only to individual Users.
Part B (Sections 11-15): Applies only to Club/organizer accounts.
Part C (Sections 16-23): Contains common provisions applicable to both.
3.2. Regipass reserves the right to change, upon prior notice, the scope, features, and pricing model of the services offered to Users or Clubs, including introducing paid tiers/subscriptions or converting previously free features to paid ones. Regipass does not commit to providing either Users or Clubs with free, lifetime use of the Platform.

PART A — PROVISIONS SPECIFIC TO USERS (STUDENTS)

4. Membership and Account Terms
4.1. You must be at least 18 years old to register for the Platform. Use of the Platform by persons under 18 is prohibited; any account found to violate this requirement will be immediately suspended or terminated.
4.2. You represent and warrant that the information you provide upon registration is accurate, current, and complete. Providing false or misleading information may render certificates and attendance records invalid and/or result in account termination.
4.3. You are solely responsible for the confidentiality of your account credentials and for all activity conducted through your account. You must notify us immediately of any suspected unauthorized use of your account.

5. User Obligations and Prohibited Use
5.1. You agree to use the Platform only for purposes consistent with applicable law, public morals, and this Agreement. The following conduct is strictly prohibited and, if detected, may result in permanent suspension of your account, referral to competent authorities, and civil/criminal liability:
— Producing or disseminating terrorist propaganda, or content that praises, incites, or legitimizes terrorist organizations or violence;
— Hate speech, discrimination, racism, sexism, or content expressing hostility toward any group;
— Creating Events or Content that promotes violence, illegal weapons or drug trafficking, fraud, or any other crime;
— Sharing content that infringes personality rights, intellectual property rights, or the privacy rights of third parties;
— Any content related to child sexual abuse or exploitation, or content targeting minors;
— Creating fake, misleading, or fraudulent Events intended to deceive Users or Clubs;
— Activities that damage the Platform's technical infrastructure, disrupt its operation, or gain unauthorized access;
— Impersonating another person or creating fake accounts.
5.2. Regipass is not obligated to pre-screen Content shared on the Platform and does not have the technical ability to review every Event/Content item in advance. However, upon receiving a report that Content violates the above, or upon becoming aware of such a violation ourselves, we will remove the relevant Content within a reasonable time, may suspend the relevant account, and may notify competent authorities where required, consistent with Law No. 5651.
5.3. To report violations: regipass.product@gmail.com

6. Disclaimer Regarding Content and Events
6.1. All Event information, descriptions, images, participation conditions, and other Content published on the Platform are created by the relevant Club, and that Club is solely responsible for their accuracy, legality, and content.
6.2. Regipass does not warrant whether an Event is genuine, whether it will take place, whether it will be cancelled, the accuracy of its content, its safety, or whether commitments made by the Club will be fulfilled. Even where an Event turns out to be fake, misleading, or one that does not actually exist, Regipass bears no responsibility whatsoever for any damage arising from your having relied on that Event. The decision to attend any Event is entirely your own responsibility.
6.3. Regipass cannot be held responsible for any direct or indirect damage caused to third parties or other Users as a result of Content shared or an Event held by any Club or User on the Platform.

7. Event Fees and Payment Collection — From the User's Perspective
7.1. Some Events may charge a fee. The determination, collection, and management of such fees is solely the responsibility of the relevant Club. Regipass is not a payment institution, intermediary payment service provider, escrow agent, or party to these payments.
7.2. Regipass makes no guarantee or representation whatsoever regarding refunds, the intended use of fees collected by Clubs, or a Club's financial reliability, and accepts no liability in this respect.
7.3. When you register for a paid Event, the Platform does not process the payment itself; instead, the contact details of the Club's authorized representative, as entered by the Club itself, are displayed to you, and you are asked to contact that person directly to arrange payment. Payment takes place entirely between you and the Club's representative, outside of Regipass's systems; Regipass bears no responsibility whatsoever for the accuracy of the contact information shown, for whether payment is actually made, or for any fraud or trust issue that may arise.
7.4. MANDATORY ACKNOWLEDGMENT — LOGGED. Immediately before completing registration for a paid Event, you will be asked to give the following acknowledgment separately and explicitly; this is separately recorded (logged):
"I understand that the payment process takes place directly with the Club, outside of Regipass, through the authorized representative's contact information that the Club itself entered into the Platform; that Regipass has not verified the accuracy of that contact information; that the person I contact may not actually be authorized, and that no outcome is guaranteed; and that Regipass bears no responsibility whatsoever at any stage of this process."
Registration for the paid Event cannot be completed without this acknowledgment.

8. Location Data and Check-in
8.1. To verify your attendance at an Event, your location is collected on a single, momentary basis at the time of check-in. Regipass does not track your location continuously in the background or outside of Event check-in.
8.2. Further details on the processing of location data are set out in the separate Data Protection Notice and Explicit Consent Form.

9. Certificates
9.1. Certificates are generated automatically based on participation criteria entered by the relevant Club and check-in data. Regipass does not guarantee the accuracy of the information appearing on a certificate; the relevant Club is responsible for the accuracy of this information.
9.2. You acknowledge that certificates do not constitute an official document approved by any institution, university, or government body, and are merely a record of participation issued according to the relevant Club's own criteria.

10. Notifications
10.1. Regipass may send you notifications, including by email and/or SMS, to the contact details you provided upon registration, regarding your account, Events, certificates, security, or Platform updates.
10.2. Notifications constituting commercial electronic communications will only be sent after obtaining your explicit prior consent as required by Law No. 6563, and you may opt out free of charge at any time.

PART B — PROVISIONS SPECIFIC TO CLUBS/ORGANIZERS

11. Scope of Service Provided to Clubs
11.1. Regipass provides the Club with a Platform service enabling it to create and announce events, collect participant registrations, track attendance via location-verified check-in, automatically generate certificates based on eligibility criteria, and access basic participant statistics.
11.2. Regipass reserves the right to develop, modify, or discontinue features, the interface, and capacity over time.

12. Pricing — For Clubs
12.1. Regipass services are subject to a package/subscription model set by Regipass, which may be updated from time to time. Regipass does not commit to providing any Club with free, lifetime, or unchangeable use of the Platform.
12.2. Where a Club moves to a paid plan, current pricing and payment terms will be separately communicated to the Club.
12.3. Regipass reserves the right to suspend access for Clubs that fail to make timely payment.

13. Club's Obligations
The Club represents, warrants, and undertakes that:
13.1. All Event information, eligibility criteria, and certificate requirements it enters on the Platform are accurate, up to date, and not misleading;
13.2. All Events it organizes and all related Content comply with applicable law, public order, and public morals; in particular, the Club will not create any Content or Event that constitutes terrorist propaganda, hate speech, discrimination, incitement to violence, or promotion of illegal activity;
13.3. The Club is solely responsible for the safe conduct of the Event, for obtaining any required permits or licenses, and for participant safety; Regipass has no involvement whatsoever in the physical or organizational conduct of the Event;
13.4. The Club will use participant personal data accessed through the Platform solely for the purpose of managing the relevant Event; it will not process, retain, share with third parties, or use for marketing purposes such data in violation of KVKK or applicable law;
13.5. It will use the Regipass brand, logo, and materials only with Regipass's prior written approval.
13.6. Authorized Contact Details for Paid Events. Where the Club creates a paid Event, the Club will accurately enter on the Platform the current contact details of an authorized representative who will arrange payment, and separately consents to that contact information being displayed to participants.

14. Responsibility for Event Content and Indemnification
14.1. Regipass is not obligated to pre-screen Events and Content created by Clubs. Where Regipass determines, or receives a report, that Content violates Section 13.2, Regipass may remove the relevant Content, take the Event offline, and/or suspend or terminate the Club's account, without prior notice.
14.2. The Club agrees to indemnify and hold Regipass harmless from and against any claims, lawsuits, complaints, investigations, penalties, or damages brought by third parties, public authorities, or other Users, arising from a breach of the undertakings in Section 13.

15. Event Fees and Payment Collection — From the Club's Perspective
15.1. The determination, announcement, and collection of participation fees for paid Events organized by the Club is solely the Club's responsibility. Regipass does not act as a payment institution, intermediary service provider, escrow agent, or party in this collection process.
15.2. Regipass's technical role with respect to payment consists solely of displaying the authorized representative's contact information to participants. Regipass is under no obligation to independently verify the accuracy of this information; the Club is responsible for any consequence arising from sharing incorrect, outdated, or misleading contact information.
15.3. Regipass makes no oversight, guarantee, or representation whatsoever regarding the collection, transfer, appropriate use, spending, transparency, or refund of fees collected by the Club.
15.4. The Club acknowledges that it is solely responsible for all tax, commercial, and legal obligations relating to fees it collects from participants.
15.5. MANDATORY ACKNOWLEDGMENT — LOGGED. When creating a paid Event, the Club must give the following acknowledgment separately and explicitly; this is confirmed separately and recorded (logged) for each paid-event creation:
"I confirm that all information I have entered into the Platform is accurate and current; that I approve of this information being shown to participants; that every stage of the payment process for the paid Event is entirely the responsibility of our Club; and that Regipass bears no responsibility whatsoever in any of these respects."
The paid Event cannot be published without this acknowledgment.

PART C — COMMON PROVISIONS

16. Processing of Personal Data
16.1. Detailed information on the purposes and legal grounds for processing personal data, its transfer abroad (including to servers located in Frankfurt, Germany), and its sharing with third-party institutions, as well as data subject rights, are set out in the separate Data Protection Notice and Explicit Consent Form. The moment you register for an Event, core participant information is automatically shared with the relevant Club to carry out attendance and certificate processes.
16.2. Regipass transfers participant personal data to the Club solely for the purpose of managing the relevant Event and only to the extent Users have consented under this Agreement and the Data Protection Notice.

17. Intellectual Property and Brand Use
17.1. All rights in the Regipass brand, logo, interface, and software belong to Regipass or its licensors.
17.2. Ownership of Content uploaded by Clubs and Users remains with the uploading party; however, by uploading Content, you grant Regipass a worldwide, non-exclusive, royalty-free license to use that Content for the purpose of operating the Platform.

18. Suspension and Termination
18.1. Regipass reserves the right to suspend or terminate an account without prior notice in the event of a breach of this Agreement, suspected illegal activity, or conduct described in Section 5 or Section 13.
18.2. A User or Club may close their account at any time; requests to close an account may be sent to regipass.product@gmail.com.

19. Limitation of Liability
19.1. Regipass does not warrant that the Platform will operate uninterrupted, error-free, or free of security vulnerabilities. The Platform is provided "as-is."
19.2. To the maximum extent permitted by applicable law, Regipass shall not be liable for any direct, indirect, incidental, or consequential damage arising from the Content, Events, payment disputes, or conduct of Clubs or other Users.
19.3. Specifically for Clubs: Regipass's total liability to a Club arising under this Agreement shall not exceed the total fees paid by that Club to Regipass in the 12 months preceding the date of the relevant event.
19.4. The limitations in this Section do not apply to damages arising from Regipass's own gross negligence or intentional misconduct, or to liability that applicable law does not permit to be limited.

20. Confidentiality
The parties agree to keep confidential any trade-secret information obtained from each other under this Agreement.

21. Changes
Regipass may update this Agreement at any time. Material changes will be announced through the Platform or by email. Continuing to use the Platform after such changes constitutes acceptance of the updated Agreement.

22. Governing Law and Jurisdiction
This Agreement is governed by the laws of the Republic of Turkey. The courts and execution offices of Istanbul (Çağlayan), Turkey, have exclusive jurisdiction over any dispute arising from this Agreement.

23. Contact
For questions: regipass.product@gmail.com
Address: Merkez Mahallesi, Kağıthane/Istanbul, Turkey
''';

const String _kvkkTr = '''
REGİPASS KİŞİSEL VERİLERİN KORUNMASI KANUNU (KVKK) AYDINLATMA METNİ VE AÇIK RIZA METNİ
Son güncelleme tarihi: 02.09.2026

1. Veri Sorumlusunun Kimliği
6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, kişisel verileriniz veri sorumlusu sıfatıyla, "Regipass" markası altında ve aşağıda açıklanan kapsamda işlenmektedir.
E-posta: regipass.product@gmail.com
Telefon: 0850 888 35 58

2. İşlenen Kişisel Veri Kategorileri
— Kimlik: Ad, soyad
— İletişim: E-posta adresi, telefon numarası
— Eğitim/Mesleki: Üniversite, fakülte/bölüm, sınıf/dönem bilgisi
— Müşteri işlem: Etkinlik kayıt geçmişi, katılım/check-in kayıtları
— Konum: Check-in anındaki anlık konum verisi (tek seferlik)
— İşlem güvenliği: IP adresi, cihaz bilgisi, oturum/log kayıtları, şifre (şifrelenmiş)
— Görsel/İşitsel (varsa): Profil fotoğrafı (Kullanıcı tarafından yüklenmişse)
— Diğer: Sertifika verileri (katılım kriterleri, tarih, unvan bilgisi)

3. Kişisel Verilerin İşlenme Amaçları
Kişisel verileriniz aşağıdaki amaçlarla işlenmektedir:
— Üyelik/hesap oluşturma ve kimlik doğrulama;
— Etkinlik keşfi, kayıt ve check-in hizmetlerinin sunulması;
— Check-in anında konum doğrulaması yapılması;
— Katılım sertifikalarının otomatik olarak oluşturulması ve Kullanıcıya sunulması;
— İlgili Kulübe, düzenlediği Etkinliğe kayıt olan/katılan Kullanıcıların listesinin ve katılım verilerinin sağlanması;
— Kullanıcıya hesap, etkinlik, güvenlik ve hizmet güncellemelerine ilişkin bildirim (e-posta/SMS) gönderilmesi;
— Platform güvenliğinin sağlanması, kötüye kullanımın önlenmesi, hukuki yükümlülüklerin yerine getirilmesi;
— İstatistiksel analiz, hizmet kalitesinin ve kullanıcı deneyiminin iyileştirilmesi;
— (Açık rızanıza bağlı olarak) ticari elektronik ileti (kampanya, duyuru, üçüncü taraf teklifleri) gönderilmesi;
— (Açık rızanıza bağlı olarak) kişisel verilerinizin iş ortağı olmayan üçüncü kurum ve kuruluşlarla ticari/pazarlama amaçlı paylaşılması.

4. Kişisel Verilerin İşlenmesinin Hukuki Sebepleri
Kişisel verileriniz, KVKK m.5/2 kapsamında aşağıdaki hukuki sebeplere dayanılarak işlenmektedir:
— Sözleşmenin kurulması/ifası: Üyelik, etkinlik kaydı, check-in ve sertifika hizmetlerinin sunulabilmesi için gerekli olması;
— Hukuki yükümlülük: Mevzuattan doğan saklama, bildirim ve ibraz yükümlülüklerinin yerine getirilmesi;
— Meşru menfaat: Platform güvenliğinin sağlanması, dolandırıcılık ve kötüye kullanımın önlenmesi, temel istatistiksel analiz;
— Açık rıza: Yukarıdaki hukuki sebeplerin kapsamadığı, aşağıda 6. ve 8. maddelerde belirtilen işleme faaliyetleri için ayrıca ve açıkça alınan rızanız.

5. Kişisel Verilerin Aktarıldığı Taraflar ve Amaçları
5.1. İlgili Kulüpler. Bir Etkinliğe kayıt olduğunuz anda, ad-soyad, üniversite/bölüm bilgisi, iletişim bilgisi ve (katılım sağladığınızda) check-in verileriniz, yoklama takibi ve sertifika süreçlerinin yürütülmesi amacıyla yalnızca o Etkinliği düzenleyen Kulüp ile paylaşılır; başka bir Kulübe veya genel olarak tüm Kulüplere ayrıca bir paylaşım yapılmaz. Bu paylaşım, Platform'un temel işlevini yerine getirebilmesi için gereklidir ve ayrıca bir açık rıza gerektirmez.
5.2. Hizmet Sağlayıcılar (Veri İşleyenler). Verileriniz, Platform'un teknik altyapısını sağlayan hizmet sağlayıcılarla (barındırma, bulut depolama, bildirim/SMS-e-posta gönderim altyapısı sağlayıcıları) hizmetin ifası amacıyla paylaşılabilir. Bu kapsamda verileriniz Google Firebase altyapısı üzerinden Frankfurt, Almanya'da bulunan sunucularda barındırılmaktadır.
5.3. Yetkili Kamu Kurum ve Kuruluşları. Hukuki yükümlülüklerimiz kapsamında, yetkili mahkeme, savcılık, kolluk kuvvetleri ve diğer kamu kurumlarının usulüne uygun talepleri doğrultusunda.
5.4. (Açık rızanıza bağlı olarak) Üçüncü Kurum ve Kuruluşlar. Reklam, pazarlama, araştırma veya iş geliştirme amacıyla iş ortağı olmayan üçüncü kurum ve kuruluşlarla paylaşım, yalnızca ayrı olarak alınan açık rızanız bulunması hâlinde yapılır. Bu rızanızı dilediğiniz zaman geri çekebilirsiniz; rızanızı geri çekmeniz hâlinde bu kapsamdaki paylaşım derhal durdurulur.
5.5. Ücretli Etkinliklerde Kulüp İletişim Bilgisinin Gösterilmesi. Ücretli bir Etkinliğe kayıt olmanız hâlinde, ödemeyi organize edebilmeniz amacıyla ilgili Kulüp yetkilisinin Platform'a girdiği iletişim bilgileri (telefon/e-posta) tarafınıza gösterilir.

6. Kişisel Verilerin Yurt Dışına Aktarılması
6.1. Platform'un teknik altyapısı gereği kişisel verileriniz, Google'ın Frankfurt, Almanya'daki veri merkezlerinde (Avrupa Birliği sınırları içinde) barındırılmaktadır. Bu, KVKK m.9 kapsamında bir yurt dışına veri aktarımı teşkil eder.
6.2. Bu aktarım, Platform'un teknik altyapısının ayrılmaz bir parçasıdır; Platform şu an başka bir sunucu konumu sunmamaktadır. Bu nedenle bu aktarım, madde 4'te belirtilen açık rızaya bağlı olmayan temel hizmetlerin bir parçası olarak, Platform'a kaydolurken işbu Aydınlatma Metni'ni onaylamanızla birlikte gerçekleşir. Bu onay, aşağıdaki Açık Rıza Metni'ndeki maddelerden farklı olarak, hizmetin sunulabilmesi için zorunlu olduğundan ayrıca ve bağımsız olarak geri çekilebilir bir tercih olarak sunulmamaktadır; verilerinizin yurt dışında barındırılmasını kabul etmek istemiyorsanız, Platform'u kullanmamanız gerekir.

7. Kişisel Verilerin Saklanma Süresi
Kişisel verileriniz, ilgili amaç için gerekli olan süre boyunca ve her hâlükârda ilgili mevzuatta öngörülen zamanaşımı süreleri saklı kalmak kaydıyla, hesabınızın aktif olduğu süre boyunca ve hesap kapatıldıktan sonra makul bir süre saklanır; bu sürenin sonunda silinir, yok edilir veya anonim hale getirilir. Özellikle, işbu metni ve ilgili açık rıza kutucuklarını onayladığınıza ilişkin onay kayıtları (onay zamanı, onaylanan metin sürümü, IP/cihaz bilgisi), olası bir uyuşmazlıkta onayın varlığını ispat edebilmek amacıyla, hesap kapatıldıktan sonra da 10 yıla kadar ayrıca saklanabilir.

8. Ticari Elektronik İletiler
Kampanya, duyuru veya üçüncü taraf teklifleri niteliğindeki ticari elektronik iletiler (SMS, e-posta, anlık bildirim), 6563 sayılı Kanun ve İleti Yönetim Sistemi (İYS) mevzuatı uyarınca yalnızca ayrıca alınan onayınıza istinaden gönderilir. Onayınızı dilediğiniz zaman İYS üzerinden veya iletideki "vazgeç" bağlantısı yoluyla ücretsiz olarak geri alabilirsiniz. Hesap işlemleri, güvenlik uyarıları ve etkinlik/sertifika bildirimleri gibi hizmetin ifası için zorunlu bilgilendirme iletileri bu onaya tabi değildir.

9. Veri Sahibinin Hakları (KVKK m.11)
KVKK'nın 11. maddesi uyarınca, Veri Sorumlusuna başvurarak:
— Kişisel verinizin işlenip işlenmediğini öğrenme,
— İşlenmişse buna ilişkin bilgi talep etme,
— İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,
— Yurt içinde/dışında aktarıldığı üçüncü kişileri bilme,
— Eksik veya yanlış işlenmişse düzeltilmesini isteme,
— KVKK m.7'de öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme,
— Düzeltme/silme işlemlerinin, verilerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
— İşlenen verilerin münhasıran otomatik sistemler ile analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme,
— Kanuna aykırı işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme
haklarına sahipsiniz.

10. Başvuru Yöntemi
Yukarıdaki haklarınızı kullanmak için taleplerinizi, kimliğinizi tevsik edici belgelerle birlikte regipass.product@gmail.com adresine e-posta ile veya Merkez Mahallesi, Kağıthane/İstanbul adresine yazılı olarak iletebilirsiniz. Başvurularınız, niteliğine göre en kısa sürede ve en geç 30 (otuz) gün içinde ücretsiz olarak sonuçlandırılır.

AÇIK RIZA METNİ
Aşağıdaki maddeler, işbu KVKK Aydınlatma Metni'ni kabul etmenizle zaten alınmış olan zorunlu onaydan (madde 6 — yurt dışında barındırma) farklı ve bağımsızdır. Aşağıdaki her bir madde ayrı ayrı onayınıza sunulur ve varsayılan olarak işaretsizdir. Bir maddeyi onaylamamanız, Platform'un temel işlevlerinden (üyelik, etkinlik kaydı, check-in, sertifika) yararlanmanızı engellemez; yalnızca ilgili ek işleme faaliyetine katılmamış olursunuz.

Yukarıda yer alan REGİPASS KVKK Aydınlatma Metni'ni okuduğumu ve anladığımı beyan ederim. Bu kapsamda:
— Kişisel verilerimin, işbu metnin 5.4. maddesinde açıklandığı üzere, reklam/pazarlama/iş geliştirme amacıyla iş ortağı olmayan üçüncü kurum ve kuruluşlarla paylaşılmasına açık rızam vardır.
— Tarafıma ticari elektronik ileti (kampanya, duyuru, indirim, üçüncü taraf teklifleri) SMS ve/veya e-posta yoluyla gönderilmesine açık rızam vardır.

Not: Yukarıdaki her bir onay, ilgili ayarlar menüsünden veya regipass.product@gmail.com adresine yazılı başvuru ile dilediğiniz zaman, geriye dönük etkisi olmaksızın geri çekilebilir.
''';

const String _kvkkEn = '''
REGIPASS DATA PROTECTION NOTICE AND EXPLICIT CONSENT FORM
Last updated: 02.09.2026

1. Identity of the Data Controller
Under Law No. 6698 ("KVKK"), your personal data is processed by, not a company but an individual, under the "Regipass" brand, as described below.
Email: regipass.product@gmail.com
Phone: +90 850 888 35 58

2. Categories of Personal Data Processed
— Identity: Full name
— Contact: Email address, phone number
— Education/Occupation: University, faculty/department, class year
— Transaction: Event registration history, attendance/check-in records
— Location: Momentary, single-instance location data at check-in
— Security: IP address, device information, session/log records, password (encrypted)
— Visual (if provided): Profile photo (if uploaded by the User)
— Other: Certificate data (eligibility criteria, date, title information)

3. Purposes of Processing
Your personal data is processed for the following purposes:
— Account creation and identity verification;
— Providing event discovery, registration, and check-in services;
— Verifying your location at the moment of check-in;
— Automatically generating and providing participation certificates;
— Providing the relevant Club with the list of Users registered for/attending its Event, and related attendance data;
— Sending you notifications (email/SMS) regarding your account, events, security, and service updates;
— Ensuring Platform security, preventing misuse, and fulfilling legal obligations;
— Statistical analysis and improving service quality and user experience;
— (Subject to your explicit consent) sending commercial electronic messages (campaigns, announcements, third-party offers);
— (Subject to your explicit consent) sharing your personal data with third-party institutions, unaffiliated with Regipass, for commercial/marketing purposes.

4. Legal Grounds for Processing
Your personal data is processed on the following legal grounds under KVKK Article 5(2):
— Performance of a contract: Necessary to provide membership, event registration, check-in, and certificate services;
— Legal obligation: To fulfill retention, notification, and disclosure obligations arising from applicable law;
— Legitimate interest: Ensuring Platform security, preventing fraud and misuse, and basic statistical analysis;
— Explicit consent: For processing activities not covered by the above grounds, as described in Sections 6 and 8 below, based on your separately and explicitly given consent.

5. Recipients of Personal Data
5.1. Relevant Clubs. The moment you register for an Event, your name, university/department information, contact details, and (if you attend) check-in data are shared only with the Club organizing that Event, for attendance tracking and certificate purposes; no separate sharing is made with any other Club or with Clubs generally.
5.2. Service Providers (Data Processors). Your data may be shared with service providers that support the Platform's technical infrastructure. In this context, your data is hosted on servers located in Frankfurt, Germany, via Google Firebase infrastructure.
5.3. Competent Public Authorities. In fulfillment of our legal obligations, in response to duly issued requests from competent courts, prosecutors, law enforcement, or other public authorities.
5.4. (Subject to your explicit consent) Third-Party Institutions. Sharing with third-party institutions unaffiliated with Regipass for advertising, marketing, research, or business development purposes takes place only where you have given separate explicit consent. You may withdraw this consent at any time, in which case such sharing will cease immediately.
5.5. Display of Club Contact Details for Paid Events. When you register for a paid Event, to allow you to arrange payment, the contact details that the relevant Club's representative entered on the Platform are displayed to you.

6. International Data Transfers
6.1. Due to the Platform's technical infrastructure, your personal data is hosted at Google's data centers in Frankfurt, Germany (within the European Union). This constitutes a transfer of data abroad under KVKK Article 9.
6.2. This transfer is an inseparable part of the Platform's technical infrastructure; the Platform does not currently offer any other server location. It is therefore carried out as part of the core services described in Section 4, which are not contingent on explicit consent, and takes place when you accept this Notice upon registering for the Platform. Unlike the items in the Explicit Consent Form below, this is not offered as a separately, independently withdrawable option, because it is necessary to provide the service; if you do not wish to accept your data being hosted abroad, you should not use the Platform.

7. Retention Period
Your personal data is retained for as long as necessary for the relevant purpose and, in any event, subject to statutory limitation periods, for as long as your account remains active and for a reasonable period after account closure, after which it is deleted, destroyed, or anonymized. In particular, consent records relating to your acceptance of this notice and the related explicit consent checkboxes may be separately retained for up to 10 years after account closure.

8. Commercial Electronic Messages
Commercial electronic messages constituting campaigns, announcements, or third-party offers are sent only based on your separately obtained consent, in accordance with Law No. 6563 and the İYS (Turkish Message Management System) regulations. You may withdraw your consent at any time, free of charge, via İYS or the "unsubscribe" link included in the message. Messages necessary to perform the service are not subject to this consent requirement.

9. Your Rights as a Data Subject (KVKK Art. 11)
Under KVKK Article 11, you have the right to apply to the Data Controller to:
— Learn whether your personal data is being processed,
— Request information if it has been processed,
— Learn the purpose of processing and whether it is used in accordance with that purpose,
— Know the third parties to whom your data is transferred, domestically or abroad,
— Request correction of incomplete or inaccurate data,
— Request deletion or destruction of your data under the conditions set out in KVKK Article 7,
— Request that any correction or deletion be notified to third parties to whom your data has been transferred,
— Object to a result that is to your detriment arising from the analysis of your data exclusively through automated systems,
— Claim compensation for damages arising from unlawful processing of your data.

10. How to Submit a Request
To exercise the rights above, you may submit your request, together with documents verifying your identity, by email to regipass.product@gmail.com or in writing to Merkez Mahallesi, Kağıthane/Istanbul, Turkey. Requests will be concluded free of charge, as soon as possible and, in any case, within 30 (thirty) days.

EXPLICIT CONSENT FORM
The items below are separate and independent from the mandatory consent already given by accepting this Data Protection Notice (Section 6 — hosting abroad). Each item below is presented for separate approval and is unchecked by default. Declining any one item does not prevent you from using the Platform's core functions; it only means you have not opted into that particular additional processing activity.

I declare that I have read and understood the REGIPASS Data Protection Notice above. Accordingly:
— I give my explicit consent to my personal data being shared with third-party institutions unaffiliated with Regipass for advertising/marketing/business development purposes, as described in Section 5.4 of this notice.
— I give my explicit consent to receiving commercial electronic messages (campaigns, announcements, discounts, third-party offers) via SMS and/or email.

Note: Each of the consents above can be withdrawn at any time, without retroactive effect, from the relevant settings menu or by written request to regipass.product@gmail.com.
''';
