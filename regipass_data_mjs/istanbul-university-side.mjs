// Istanbul universitelerinin Anadolu/Avrupa yakasi eslemesi.
// En iyi caba (gercek kampus konumuna gore) bir siniflandirmadir - cift kampuslu
// bazi universiteler icin yaklasik olabilir, kolayca duzeltilebilir tek dosya.
// location-data.js'deki CITY_UNIVERSITIES["İstanbul"] listesiyle birebir eslesir.
export const ISTANBUL_SIDE = Object.freeze({
  ANADOLU: "anadolu",
  AVRUPA: "avrupa"
});

const rawIstanbulUniversitySide = {
  // Devlet universiteleri
  "İstanbul Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Üniversitesi-Cerrahpaşa": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Teknik Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Boğaziçi Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Marmara Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Yıldız Teknik Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Galatasaray Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Mimar Sinan Güzel Sanatlar Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Medeniyet Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Türk-Alman Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Sağlık Bilimleri Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İstanbul Galata Üniversitesi": ISTANBUL_SIDE.AVRUPA,

  // Vakif universiteleri
  "Koç Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Sabancı Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Bahçeşehir Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Yeditepe Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İstanbul Bilgi Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Aydın Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Okan Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İbn Haldun Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstinye Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Maltepe Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Üsküdar Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Acıbadem Mehmet Ali Aydınlar Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Altınbaş Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Beykent Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Beykoz Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Bezm-i Âlem Vakıf Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Biruni Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Demiroğlu Bilim Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Doğuş Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Fatih Sultan Mehmet Vakıf Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Fenerbahçe Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Haliç Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Işık Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İstanbul Nişantaşı Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Sağlık ve Teknoloji Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul 29 Mayıs Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İstanbul Arel Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Atlas Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Esenyurt Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Gedik Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İstanbul Gelişim Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Kent Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Kültür Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Medipol Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "İstanbul Rumeli Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Sabahattin Zaim Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Ticaret Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Topkapı Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Yeni Yüzyıl Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Kadir Has Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Lokman Hekim Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Mef Üniversitesi": ISTANBUL_SIDE.AVRUPA,
  "Özyeğin Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Piri Reis Üniversitesi": ISTANBUL_SIDE.ANADOLU,
  "Torun Üniversitesi": ISTANBUL_SIDE.AVRUPA,

  // Vakif meslek yuksekokullari
  "Ataşehir Adıgüzel Meslek Yüksekokulu": ISTANBUL_SIDE.ANADOLU,
  "Avrupa Meslek Yüksekokulu": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Sağlık ve Sosyal Bilimler Meslek Yüksekokulu": ISTANBUL_SIDE.AVRUPA,
  "İstanbul Şişli Meslek Yüksekokulu": ISTANBUL_SIDE.AVRUPA
};

export const ISTANBUL_UNIVERSITY_SIDE = Object.freeze({ ...rawIstanbulUniversitySide });

// Eslemede olmayan bir universite adi icin null doner - cagiran taraf bunu
// "Istanbul (Diger)" gibi gorunur bir kovaya koymali, sessizce atmamali.
export function getIstanbulSide(universityName) {
  return ISTANBUL_UNIVERSITY_SIDE[universityName] || null;
}
