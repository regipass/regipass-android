# Kayıt ve giriş yükü testleri

Regipass'in eşzamanlılık sınırlarını **ölçen** düzenek. Firestore emulator'e
karşı çalışır; her koşu `logs/` altına ham JSONL ve okunabilir özet bırakır.

Bulguların yorumu: [`docs/kayit-kapasitesi.md`](../../docs/kayit-kapasitesi.md)

## Kurulum

```bash
cd tool/loadtest
npm install
```

Emulator'ü ayrı bir terminalde başlat (ilk çalıştırmada .jar indirir):

```bash
cd tool/loadtest && firebase emulators:start --only firestore --project eventapp-604a5
```

`firestore.rules` buraya **kopyalanmıştır**; asıl dosya
`Desktop/REGİPASS/firestore.rules`. Kuralları değiştirdiğinde kopyala:

```bash
cp "$HOME/Desktop/REGİPASS/firestore.rules" tool/loadtest/firestore.rules
```

Emulator dosyayı izler ve kendiliğinden yeniden yükler.

## Testler

| Dosya | Ne ölçer |
|---|---|
| `01-baseline.mjs` | Mevcut kayıt akışı: kontenjan aşımı ve okuma çoğalması |
| `02-quota-contention.mjs` | Tek dokümanlı sayacın çekişme altında çöküşü |
| `03-sharded-queue.mjs` | Parça sayısı ve kuyruk genişliği taraması |
| `04-login.mjs` | Eşzamanlı giriş: giriş başına okuma, gecikme |
| `05-realistic.mjs` | N ayrı cihaz aynı anda — yeniden deneme stratejilerinin karşılaştırması |
| `06-rules.mjs` | `quota_shards` güvenlik kuralları (15 senaryo) |
| `11-onay-logu.mjs` | KVKK/sözleşme onayı DB'ye düşüyor mu (10 senaryo) |

```bash
node 01-baseline.mjs
node 05-realistic.mjs
```

`11-onay-logu.mjs` kuralları emulator'e yeniden yükler ve veriyi siler
(`clearFirestore`) — `06-rules.mjs` gibi, başka bir koşuyla aynı emulator'de
çalıştırma. Kuralları **asıl** dosyadan (`Desktop/REGİPASS/firestore.rules`)
okur, buradaki kopyadan değil. Başka porttaki bir emulator'e yönlendirmek için:

```bash
LOADTEST_RULES_PORT=8744 node 11-onay-logu.mjs
```

`02`, `03` ve `05` uzun sürer (çekişme testleri bilerek beklemeli).

### İkinci emulator

`06-rules.mjs` kuralları emulator'e yeniden yüklediği için uzun süren bir
testle aynı anda çalıştırılmamalı. `rules-env/` altında 8733 portunda ikinci
bir emulator yapılandırması var:

```bash
cd tool/loadtest/rules-env && firebase emulators:start --only firestore --project eventapp-604a5
```

Diğer testler de yönlendirilebilir:

```bash
LOADTEST_EMULATOR=127.0.0.1:8733 node 04-login.mjs
```

## Emulator neyi ölçer, neyi ölçmez

**Ölçer** — bunlar gerçek:

- transaction çekişmesi (optimistic concurrency, ABORTED, yeniden deneme)
- kontenjan aşımı / eksiği — algoritmanın **doğruluğu**
- işlem başına okuma-yazma sayısı
- güvenlik kurallarının davranışı

**Ölçmez** — üretimdeki tavanlar belgelenmiş limitlerdir:

- tek dokümana ~1 yazma/sn sürdürülebilir sınırı
- dar indeks anahtar aralığında ~500 yazma/sn sıcak nokta sınırı
- 500/50/5 rampası, ağ gecikmesi, bölgesel kota

Emulator tek süreçli ve bellek içi olduğu için **mutlak** işlem/sn değerleri
üretimi temsil etmez; anlamlı olan eğrinin şekli ve hata oranlarıdır.
