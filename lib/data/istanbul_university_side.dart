// GENERATED — düzenlemeyin.
// Kaynak: js/data/istanbul-university-side.js
// Yeniden üretmek için: node tool/convert_data.mjs

/// İstanbul üniversitelerinin yaka bilgisi (admin istatistiklerinde kullanılır).
class IstanbulSide {
  static const String anadolu = 'anadolu';
  static const String avrupa = 'avrupa';
}

const Map<String, String> kIstanbulUniversitySide = <String, String>{
  'İstanbul Üniversitesi': 'avrupa',
  'İstanbul Üniversitesi-Cerrahpaşa': 'avrupa',
  'İstanbul Teknik Üniversitesi': 'avrupa',
  'Boğaziçi Üniversitesi': 'avrupa',
  'Marmara Üniversitesi': 'anadolu',
  'Yıldız Teknik Üniversitesi': 'avrupa',
  'Galatasaray Üniversitesi': 'avrupa',
  'Mimar Sinan Güzel Sanatlar Üniversitesi': 'avrupa',
  'İstanbul Medeniyet Üniversitesi': 'anadolu',
  'Türk-Alman Üniversitesi': 'anadolu',
  'Sağlık Bilimleri Üniversitesi': 'anadolu',
  'İstanbul Galata Üniversitesi': 'avrupa',
  'Koç Üniversitesi': 'avrupa',
  'Sabancı Üniversitesi': 'anadolu',
  'Bahçeşehir Üniversitesi': 'avrupa',
  'Yeditepe Üniversitesi': 'anadolu',
  'İstanbul Bilgi Üniversitesi': 'avrupa',
  'İstanbul Aydın Üniversitesi': 'avrupa',
  'İstanbul Okan Üniversitesi': 'anadolu',
  'İbn Haldun Üniversitesi': 'avrupa',
  'İstinye Üniversitesi': 'avrupa',
  'Maltepe Üniversitesi': 'anadolu',
  'Üsküdar Üniversitesi': 'anadolu',
  'Acıbadem Mehmet Ali Aydınlar Üniversitesi': 'anadolu',
  'Altınbaş Üniversitesi': 'avrupa',
  'Beykent Üniversitesi': 'avrupa',
  'Beykoz Üniversitesi': 'anadolu',
  'Bezm-i Âlem Vakıf Üniversitesi': 'avrupa',
  'Biruni Üniversitesi': 'avrupa',
  'Demiroğlu Bilim Üniversitesi': 'avrupa',
  'Doğuş Üniversitesi': 'anadolu',
  'Fatih Sultan Mehmet Vakıf Üniversitesi': 'avrupa',
  'Fenerbahçe Üniversitesi': 'anadolu',
  'Haliç Üniversitesi': 'avrupa',
  'Işık Üniversitesi': 'anadolu',
  'İstanbul Nişantaşı Üniversitesi': 'avrupa',
  'İstanbul Sağlık ve Teknoloji Üniversitesi': 'avrupa',
  'İstanbul 29 Mayıs Üniversitesi': 'anadolu',
  'İstanbul Arel Üniversitesi': 'avrupa',
  'İstanbul Atlas Üniversitesi': 'avrupa',
  'İstanbul Esenyurt Üniversitesi': 'avrupa',
  'İstanbul Gedik Üniversitesi': 'anadolu',
  'İstanbul Gelişim Üniversitesi': 'avrupa',
  'İstanbul Kent Üniversitesi': 'avrupa',
  'İstanbul Kültür Üniversitesi': 'avrupa',
  'İstanbul Medipol Üniversitesi': 'anadolu',
  'İstanbul Rumeli Üniversitesi': 'avrupa',
  'İstanbul Sabahattin Zaim Üniversitesi': 'avrupa',
  'İstanbul Ticaret Üniversitesi': 'avrupa',
  'İstanbul Topkapı Üniversitesi': 'avrupa',
  'İstanbul Yeni Yüzyıl Üniversitesi': 'avrupa',
  'Kadir Has Üniversitesi': 'avrupa',
  'Lokman Hekim Üniversitesi': 'avrupa',
  'Mef Üniversitesi': 'avrupa',
  'Özyeğin Üniversitesi': 'anadolu',
  'Piri Reis Üniversitesi': 'anadolu',
  'Torun Üniversitesi': 'avrupa',
  'Ataşehir Adıgüzel Meslek Yüksekokulu': 'anadolu',
  'Avrupa Meslek Yüksekokulu': 'avrupa',
  'İstanbul Sağlık ve Sosyal Bilimler Meslek Yüksekokulu': 'avrupa',
  'İstanbul Şişli Meslek Yüksekokulu': 'avrupa',
};

/// Eşlemede olmayan üniversite için null döner — çağıran taraf bunu
/// "İstanbul (Diğer)" kovasına koymalı, sessizce atmamalı.
String? istanbulSideOf(String universityName) =>
    kIstanbulUniversitySide[universityName];
