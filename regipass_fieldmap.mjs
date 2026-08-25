function foldTr(value) {
  return (value || "")
    .replace(/I/g, "i")
    .replace(/ı/g, "i")
    .toLocaleLowerCase("tr")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function includesKeyword(foldedText, foldedKeyword) {
  // Plain substring match (not word-boundary): Turkish suffixes attach
  // directly to word stems (e.g. "edebiyat" + "i" -> "edebiyati", "tarih" + "i"
  // -> "tarihi"), so a boundary check would miss most real department names.
  return foldedText.includes(foldedKeyword);
}

// Keyword -> weight (0..1) per club field. A department can match keywords
// across several fields at once (e.g. "Gıda Mühendisliği" matches both
// "Mühendislik ve Mimarlık" and "Gıda Mühendisliği ve Teknolojisi").
const RAW_FIELD_KEYWORDS = {
  "Mühendislik ve Mimarlık": [
    ["mühendisliği", 0.6], ["mühendislik", 0.6],
    ["mimarlık", 1], ["mimari", 0.9], ["peyzaj mimarlığı", 1],
    ["şehir ve bölge planlama", 0.9], ["endüstriyel tasarım", 0.8], ["endüstri ürünleri tasarımı", 0.8],
    ["elektrik", 0.9], ["elektronik", 0.9], ["makine", 0.9], ["inşaat", 0.9],
    ["endüstri mühendisliği", 0.9], ["metalurji", 0.9], ["malzeme", 0.85], ["maden mühendisliği", 0.9],
    ["petrol", 0.85], ["mekatronik", 0.9], ["otomotiv mühendisliği", 0.9], ["biyomedikal mühendisliği", 0.85],
    ["nanoteknoloji mühendisliği", 0.85], ["çevre mühendisliği", 0.85], ["harita mühendisliği", 0.85],
    ["jeofizik", 0.85], ["jeoloji mühendisliği", 0.85], ["tekstil mühendisliği", 0.8], ["polimer", 0.8],
    ["nükleer enerji mühendisliği", 0.85], ["cevher hazırlama", 0.8], ["uzay mühendisliği", 0.85]
  ],
  "Bilgisayar ve Yazılım": [
    ["bilgisayar", 1], ["yazılım", 1], ["bilişim", 0.9], ["yapay zeka", 1],
    ["siber güvenlik", 1], ["veri bilimi", 0.9], ["veri mühendisliği", 0.9], ["ağ teknolojileri", 0.7],
    ["internet ve ağ", 0.8], ["oyun geliştirme", 0.8], ["oyun tasarımı", 0.8], ["web tasarımı", 0.8],
    ["dijital oyun", 0.8], ["kurumsal bilişim", 0.8], ["bulut bilişim", 0.8], ["arka-yüz", 0.8], ["ön-yüz", 0.8],
    ["robotik ve yapay zeka", 0.8], ["robotik", 0.6]
  ],
  "Tıp ve Sağlık Bilimleri": [
    ["tıp", 1], ["tıbbi", 0.9], ["sağlık", 0.85], ["hemşirelik", 1], ["ebelik", 1],
    ["fizyoterapi", 1], ["beslenme ve diyetetik", 1], ["dil ve konuşma terapisi", 0.9], ["ergoterapi", 0.9],
    ["odyoloji", 0.9], ["odyometri", 0.9], ["paramedik", 0.9], ["anestezi", 0.9], ["ameliyathane", 0.9],
    ["perfüzyon", 0.9], ["radyoterapi", 0.9], ["diyaliz", 0.9], ["patoloji", 0.85], ["ortez ve protez", 0.85],
    ["ortopedik protez", 0.85], ["podoloji", 0.85], ["hasta bakımı", 0.8], ["yaşlı bakımı", 0.7],
    ["gerontoloji", 0.7], ["biyomedikal cihaz teknolojisi", 0.7], ["dezenfeksiyon", 0.7],
    ["elektronörofizyoloji", 0.85], ["engelli bakımı", 0.7], ["nükleer tıp", 0.9], ["çevre sağlığı", 0.7]
  ],
  "Diş Hekimliği": [
    ["diş hekimliği", 1], ["ağız ve diş sağlığı", 1], ["diş protez teknolojisi", 0.9]
  ],
  "Eczacılık": [
    ["eczacılık", 1], ["eczane hizmetleri", 0.9]
  ],
  "Hukuk": [
    ["hukuk", 1], ["adli bilimler", 0.9], ["adli bilişim", 0.6], ["ceza infaz", 0.8],
    ["mahkeme büro hizmetleri", 0.8], ["tapu kadastro", 0.5], ["tapu ve kadastro", 0.5]
  ],
  "İktisadi ve İdari Bilimler": [
    ["iktisat", 1], ["ekonomi", 0.9], ["finans", 0.8], ["bankacılık", 0.9], ["sigortacılık", 0.9],
    ["aktüerya", 0.9], ["sermaye piyasası", 0.85], ["ekonometri", 0.9], ["gümrük işletme", 0.8],
    ["dış ticaret", 0.8], ["uluslararası ticaret", 0.8], ["kamu yönetimi", 0.8], ["maliye", 0.9]
  ],
  "İşletme": [
    ["işletme", 1], ["muhasebe", 0.9], ["pazarlama", 0.9], ["insan kaynakları", 0.9],
    ["büro yönetimi ve yönetici asistanlığı", 0.8], ["lojistik", 0.8], ["perakende satış", 0.8],
    ["e-ticaret", 0.8], ["elektronik ticaret", 0.8], ["yönetim bilişim sistemleri", 0.6]
  ],
  "Eğitim": [
    ["öğretmenliği", 1], ["eğitim bilimleri", 0.9], ["rehberlik", 0.6], ["psikolojik danışmanlık", 0.6],
    ["özel eğitim", 0.9], ["çocuk gelişimi", 0.6]
  ],
  "Fen-Edebiyat": [
    ["edebiyat", 0.9], ["dilbilimi", 0.9], ["dili ve kültürü", 0.8], ["matematik", 0.85], ["fizik", 0.85],
    ["kimya", 0.85], ["biyoloji", 0.85], ["istatistik", 0.85], ["moleküler biyoloji", 0.85],
    ["biyokimya", 0.85], ["biyoteknoloji", 0.8], ["genetik", 0.8], ["felsefe", 0.85]
  ],
  "İletişim": [
    ["iletişim", 1], ["gazetecilik", 1], ["halkla ilişkiler", 0.9], ["radyo ve televizyon", 0.9],
    ["radyo, televizyon ve sinema", 0.85], ["yeni medya", 0.9], ["medya", 0.8], ["reklamcılık", 0.9],
    ["reklam tasarımı", 0.85], ["görsel iletişim tasarımı", 0.85], ["sosyal medya yöneticiliği", 0.85],
    ["kurgu, ses ve görüntü yönetimi", 0.8]
  ],
  "Güzel Sanatlar ve Tasarım": [
    ["resim", 0.9], ["heykel", 0.9], ["grafik", 0.85], ["seramik", 0.85], ["çini sanatı", 0.85],
    ["görsel sanatlar", 0.9], ["çizgi film ve animasyon", 0.85], ["fotoğraf", 0.85], ["el sanatları", 0.8],
    ["geleneksel türk sanatları", 0.8], ["tekstil tasarımı", 0.8], ["moda tasarımı", 0.85],
    ["moda yönetimi", 0.7], ["kuyumculuk", 0.8], ["takı tasarımı", 0.8], ["sanat ve kültür yönetimi", 0.7]
  ],
  "Müzik ve Sahne Sanatları": [
    ["müzik", 1], ["sahne", 0.85], ["tiyatro", 1], ["sinema ve dijital medya", 0.8], ["dans", 0.9],
    ["opera", 0.9], ["bale", 0.9], ["sinema ve televizyon", 0.8]
  ],
  "İlahiyat": [
    ["ilahiyat", 1], ["islami ilimler", 1], ["islam iktisadı", 0.7], ["din kültürü", 0.7]
  ],
  "Spor Bilimleri": [
    ["spor", 1], ["antrenörlük", 0.9], ["beden eğitimi", 0.9], ["rekreasyon", 0.85],
    ["egzersiz ve spor bilimleri", 0.9]
  ],
  "Tarım ve Ziraat": [
    ["tarım", 1], ["ziraat", 1], ["orman", 0.9], ["bahçe bitkileri", 0.9], ["bitki koruma", 0.9],
    ["zootekni", 0.9], ["hayvansal üretim", 0.85], ["arıcılık", 0.85], ["bağcılık", 0.85],
    ["seracılık", 0.85], ["tohumculuk", 0.85], ["sulama teknolojisi", 0.8], ["peyzaj ve süs bitkileri", 0.8],
    ["kanatlı hayvan", 0.8], ["yaban hayatı", 0.7], ["biyosistem mühendisliği", 0.75], ["toprak bilimi", 0.85]
  ],
  "Veterinerlik": [
    ["veteriner", 1], ["laborant ve veteriner sağlık", 0.9]
  ],
  "Turizm": [
    ["turizm", 1], ["otel", 0.9], ["gastronomi", 0.9], ["aşçılık", 0.9], ["pastacılık", 0.85],
    ["konaklama işletmeciliği", 0.9], ["seyahat işletmeciliği", 0.9], ["turist rehberliği", 0.9]
  ],
  "Havacılık ve Uzay": [
    ["havacılık", 1], ["uçak", 1], ["uzay", 0.9], ["pilotaj", 1], ["astronomi ve uzay bilimleri", 0.7]
  ],
  "Denizcilik": [
    ["denizcilik", 1], ["gemi", 0.9], ["su ürünleri", 0.85], ["balıkçılık", 0.85],
    ["deniz ulaştırma", 0.9], ["liman işletmeciliği", 0.85], ["yat kaptanlığı", 0.9], ["su altı", 0.75]
  ],
  "Psikoloji": [
    ["psikoloji", 1], ["psikolojik danışmanlık", 0.8]
  ],
  "Sosyoloji ve Antropoloji": [
    ["sosyoloji", 1], ["antropoloji", 1], ["halkbilimi", 0.8], ["kültürel miras", 0.7]
  ],
  "Tarih ve Arkeoloji": [
    ["tarih", 0.9], ["arkeoloji", 1], ["hititoloji", 0.9], ["sümeroloji", 0.9], ["sinoloji", 0.7],
    ["bilim tarihi", 0.85]
  ],
  "Uluslararası İlişkiler ve Siyaset Bilimi": [
    ["uluslararası ilişkiler", 1], ["siyaset bilimi", 1], ["kamu yönetimi", 0.7],
    ["küresel siyaset", 0.9], ["yerel yönetimler", 0.7]
  ],
  "Mütercim Tercümanlık ve Çeviribilim": [
    ["mütercim", 1], ["tercümanlık", 1], ["çeviribilim", 1]
  ],
  "Gıda Mühendisliği ve Teknolojisi": [
    ["gıda", 1]
  ]
};

const FIELD_KEYWORD_RULES = Object.fromEntries(
  Object.entries(RAW_FIELD_KEYWORDS).map(([field, entries]) => [
    field,
    entries.map(([keyword, weight]) => ({ keyword: foldTr(keyword), weight }))
  ])
);

// Minimum weight for a department<->field keyword match to count as
// "related" for discovery-priority purposes (see event-utils.js).
export const FIELD_RELATION_THRESHOLD = 0.5;

export function getFieldRelationWeight(departmentName, clubField) {
  const rules = FIELD_KEYWORD_RULES[clubField];
  if (!rules || !rules.length) return 0;

  const folded = foldTr(departmentName);
  if (!folded) return 0;

  let best = 0;
  rules.forEach(({ keyword, weight }) => {
    if (keyword && includesKeyword(folded, keyword) && weight > best) best = weight;
  });

  return best;
}

export { RAW_FIELD_KEYWORDS };
