/// Giriş ekranının arka planında akan içerik havuzu.
///
/// Giriş ekranı oturum açmadan gösterildiği için Firestore'dan gerçek kulüp
/// veya etkinlik adı çekilemez (firestore.rules okuma için giriş şart koşuyor).
/// Bu yüzden temsilî ama gerçekçi bir havuz kullanılır — amaç bilgi vermek
/// değil, ekrana kampüs hissi katmak.
library;

/// Kulüp adları.
const List<String> kMarqueeClubs = <String>[
  'Bilgisayar Kulübü',
  'Robotik Topluluğu',
  'Girişimcilik Kulübü',
  'Fotoğrafçılık Topluluğu',
  'Tiyatro Kulübü',
  'Müzik Topluluğu',
  'Dağcılık Kulübü',
  'Yapay Zekâ Topluluğu',
  'Siber Güvenlik Kulübü',
  'Havacılık Topluluğu',
  'Psikoloji Kulübü',
  'Münazara Topluluğu',
  'Gastronomi Kulübü',
  'Sinema Topluluğu',
  'Astronomi Kulübü',
  'Sürdürülebilirlik Topluluğu',
  'Kariyer Kulübü',
  'Satranç Topluluğu',
  'Kızılay Topluluğu',
  'IEEE Öğrenci Kolu',
];

/// Etkinlik adları.
const List<String> kMarqueeEvents = <String>[
  'Kariyer Günleri',
  'Hackathon',
  'Bahar Şenliği',
  'Tanışma Toplantısı',
  'Teknoloji Zirvesi',
  'Kısa Film Gösterimi',
  'Kamp Buluşması',
  'Atölye: Figma',
  'Söyleşi: Girişimcilik',
  'Mezunlar Buluşması',
  'Kod Maratonu',
  'Fotoğraf Yarışması',
  'Doğa Yürüyüşü',
  'Panel: Yapay Zekâ',
  'Konser Gecesi',
  'Kitap Kulübü',
  'Staj Fuarı',
  'Sunum Atölyesi',
  'Bisiklet Turu',
  'Yıl Sonu Galası',
];

/// Aralara serpiştirilen emojiler. Karmaşık ZWJ dizileri (👨‍💻 gibi) bazı
/// cihazlarda tofu kutusuna düşebildiği için tek kod noktalı, yaygın
/// desteklenen emojiler seçildi.
const List<String> kMarqueeEmojis = <String>[
  '🎓', '🎉', '🎬', '🎤', '📸', '🚀', '💡', '🎯', '🏆', '🎨',
  '⚽', '🎸', '📚', '🧠', '🌱', '⭐', '🔥', '🎪', '🛠', '🧭',
];
