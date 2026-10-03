# Diyanet resmî vakit verisi — erişim ve kapsam araştırması (3 Ekim 2026)

Bu klasör, "Türkiye'de varsayılan kaynak Diyanet olsun ve dakika düzeyinde
birebir eşleşsin" hedefi için yapılan **ölçümlerin** kaydıdır. Üretim kodunda
bu iş için **hiçbir değişiklik yapılmadı**; çünkü erişim izni ve kapsam
kararı verilmeden veri toplanamaz (bkz. "Durulan yer").

---

## 1. Doğrulanan resmî kaynaklar

Tümü **T.C. Diyanet İşleri Başkanlığı** alan adındadır. Erişim tarihi:
**3 Ekim 2026**.

| Ne | Adres | Ölçülen |
| :--- | :--- | :--- |
| Ülke listesi | `namazvakitleri.diyanet.gov.tr/assets/locations/countries.json` | 204 ülke; `{"CountryID":2,"CountryName":"TURKEY"}` |
| **Türkiye yerleşim kataloğu** | `namazvakitleri.diyanet.gov.tr/assets/locations/TURKEY.json` | **865 kayıt, 81 il**, alanlar `Country,State,City,CityID`; CityID 9146..17920 |
| Yerleşim vakit tablosu | `namazvakitleri.diyanet.gov.tr/tr-TR/{CityID}/{slug}` | sayfa başına ~375 KB, 3 `<table>` |

Katalog bu klasörde `turkiye_yerlesim_katalogu.json` olarak saklanır (60.601
bayt, UTF-8 **BOM**'lu — `utf-8-sig` ile okunmalı).

Katalog ölçümü (`diyanet_kapsam_olcumu.py`):

```
kayit sayisi        : 865
il (State) sayisi   : 81
CityID araligi      : 9146 .. 17920
YINELENEN CityID    : 0        <- kimlikler tekil, anahtar olarak kullanilabilir
YINELENEN (il,yer)  : 2        <- ('DENIZLI','KALE') ve ('USAK','USAK')  !! asagida
en buyuk 5 il       : KONYA(32), IZMIR(21), KASTAMONU(20), BALIKESIR(19), DENIZLI(19)
```

**Yerleşimler resmî `CityID` ile eşleştirilmeli, isimle değil.** Aşağıdaki
iki bulgu bunun nedenini kanıtlıyor.

### 1.1 Aynı (il, yerleşim) iki kez geçiyor ve verileri FARKLI

| State | City | CityID | 2026-10-03 İmsak…Akşam (ilk satır) |
| :--- | :--- | ---: | :--- |
| USAK | USAK | 9919 | `05:32 06:53 12:57 16:14 18:50 20:06` |
| USAK | USAK | 17909 | `05:32 06:53 12:57 16:15 18:51 20:07` |

Aynı ad, aynı il, **farklı `CityID`, birer dakika farklı vakit**. İsimle
eşleştirme yapan bir içe aktarma bu iki kaydı birleştirir veya ilkini seçerek
ikinci yerleşimin vakitlerini sessizce 1 dakika kaydırır. 2027-12-31'de de
fark sürüyor (`15:36/17:57` ↔ `15:37/17:58`).

### 1.2 Katalogdaki bir kayıt ÖLÜ

`DENIZLI / KALE` için iki `CityID` var: **9394** ve **17899**.

- `17899` → HTTP 200, veri geliyor (`2026-10-03 05:35 06:55 12:59 16:17 18:53 20:08`)
- `9394` → **her slug'da HTTP 500** (`kale-icin-namaz-vakti`, `kale-namaz-vakitleri`,
  `x-icin-namaz-vakti` — üçü de denendi)

Yani **katalog 865 kayıt diyor ama en az 1 kayıt için veri yok.** "865
yerleşim eksiksiz" demek bu ölçüm yapılmadan doğru olmaz.

### 1.3 Slug yanlışsa 500 dönebiliyor

`/tr-TR/{CityID}/{slug}` adresinde slug yalnızca görsel bir yol değil:
`9394` için yanlış slug 500 verirken doğru slug da 500 verdi. `17899` ise
`x-icin-namaz-vakti` gibi **anlamsız** bir slug ile 200 döndü. İçe aktarma
slug'ı `City` adından türetmek zorunda; ayrıca her yanıt doğrulanmalı.

---

## 2. Ölçülen tarih kapsamı

İki farklı yerleşimde (Adana 9146, Ankara 9206) ve Denizli/Kale 17899,
Uşak 9919/17909'da **aynı** sonuç çıktı:

```
<table> sayisi : 3
  tablo 1 "Haftalık" :   7 satır   2026-10-03 .. 2026-10-09
  tablo 2 "Aylık"    :  31 satır   2026-10-03 .. 2026-11-02
  tablo 3 "Yıllık"   : 365 satır   2027-01-01 .. 2027-12-31   (tam, eksiksiz)

<tr> toplam      : 403
BENZERSIZ tarih  : 396
ilk / son        : 2026-10-03 / 2027-12-31
TEKRAR eden tarih: 7   (haftalık tablonun 7 günü aylık tabloda da var — normal)
aralik/eksik gun : 455 / 59
eksik ay         : 2026-10 29/31, 2026-11 2/30, 2026-12 0/31
```

### Kapsamın başı ve sonu açıkça

- **Başlangıç: 2026-10-03** (ölçüm günü — yani "bugünden itibaren", geçmiş veri yok)
- **Bitiş: 2027-12-31**
- **İç boşluk: 2026-11-03 → 2026-12-31 arası 59 gün hiç yok.**
- **2028 yılı tamamen yok.**

Sayfada ay/yıl seçici bağlantısı yoktur; aylık tablo " içinde bulunulan ay",
yıllık tablo "bir sonraki yıl" anlamına gelir. Kasım ve Aralık 2026 bu
yüzden atlanmaktadır.

### İstenen "iki ileri yıl" karşılanamıyor

Bugünden iki ileri yıl **2026-10-03 → 2028-10-03** olurdu. Resmî kaynak
**2027-12-31**'de bitiyor. Eksik olan **2028 yılının tamamı + 2026'nın son
59 günü**. Talimat gereği bu boşluk hesaplanarak, başka yıldan kopyalanarak
veya uydurularak doldurulmadı ve kapsam onaysız daraltılmadı.

---

## 3. Erişim engelleri

### 3.1 Veri hostunun `robots.txt`'i okunamıyor

```
https://namazvakitleri.diyanet.gov.tr/robots.txt
  → HTTP 200 ama içerik WAF sayfası:
    "İsteğiniz güvenlik kurallarına takılmıştır"
    Transaction ID = 7647865-PPE1
    Transaction ID = 8014402-PPE6     (iki ayrı denemede iki ayrı ID)
```

Aynı anda `https://www.diyanet.gov.tr/robots.txt` **normal** okunuyor
(`User-agent: * / Allow: /`, yönetim yolları hariç) — yani engel verinin
bulunduğu hosta özgü. **Veri hostunun tarama politikası okunamadığı için
"serbest" de denemez, "izinli" de denemez.** Bilinmiyor.

### 3.2 WAF zaten bir kez engelledi

Hafif yoklamada (6 istek) bir istek WAF sayfasıyla kesildi. Ardından
tekil, aralıklı istekler geçti. Yani engel hız tabanlı.

### 3.3 Toplam yük

Tam almak için: **865 sayfa × ~375 KB ≈ 324 MB**, 865 istek. WAF'i zorlamamak
için aralıklı gidilse bile bu, izin belgesi olmadan yapılacak bir toplu
taramadır.

### 3.4 Diğer resmî yollar kapalı veya üye-gated

- `vakithesaplama.diyanet.gov.tr` → **üye girişi** istiyor
  (`uyegiris.php`, `kayitol.php`). Hesap açmadım; kullanıcı adına kayıt
  yapmak kullanıcının kararıdır.
- Ana sitede `https://www.diyanet.gov.tr/tr-TR/kible`, `vakithesaplama.../dinigunler.php`
  var; bunlar veri dökümü değil.
- Diyanet aylık vakit tablolarını PDF olarak da yayımlar
  (`webdosya.diyanet.gov.tr`). Kasım/Aralık 2026'yı oradan kapatmak
  mümkün olabilir, ama **2028'i kapatmaz** ve PDF ayrıştırma ek işi ister.

### 3.5 Toplu JSON görünen, ama tuzak olan bir uç nokta

`/tr-TR/PrayerTimes/GetPrayerTimesByCityId?cityID=X` JSON gibi görünüyor ve
toplu veri kaynağı gibi davranıyor. **Değil: `cityID` yok sayılıyor.**

| istek | dönen ilk satır (2026-10-03) |
| :--- | :--- |
| `cityID=9146` | `05:17 06:39 12:43 15:59 18:36 19:54` |
| `cityID=10332` | `05:17 06:39 12:43 15:59 18:36 19:54` |

İkisi de **Ankara**'nın verisi (Ankara sayfasıyla birebir aynı). Bu, ana
sayfanın AJAX parçası; sunucu durumu taşıyor, parametreden okumuyor. Böyle
bir uç noktaya bağlanan bir içe aktarma **865 yerleşimin 864'üne yanlış
vakit yazardı ve bunu sessizce yapardı.**

---

## 4. Aladhan tarafında doğrulanan (bilinen) hata

`lib/pages/anasayfa.dart:923` ve `:1096`:

```dart
p['adjustmentMethod'] = konum.yuksekEnlemAyaru.apiParametresi;
```

Canlı ölçüm (`api.aladhan.com/v1/calendar`, `meta` alan listesi:
`latitude, longitude, timezone, method, latitudeAdjustmentMethod,
midnightMode, school, offset`):

1. **Parametre adı yanlış.** Sağlayıcı `latitudeAdjustmentMethod`
   kullanıyor, `adjustmentMethod` değil.
2. **Değerler de yanlış.** `meta.latitudeAdjustmentMethod` şu girdilerin
   hepsinde `ANGLE_BASED` döndü: `ANGLE_BASED`, `MIDDLE_OF_THE_NIGHT`,
   `ONE_SEVENTH`, `QUARTER`, `NONE`, `MIDDLE`, `HALF`.
3. **Çıktı hiç değişmiyor.** Reykjavik (64.15N) 2026-06-21, beş farklı
   girdi: `02:04 | 02:55 | 13:30 | 18:22 | 00:04 | 00:52` — birebir aynı.

Sonuç: uygulamadaki 4 yüksek enlem seçeneğinin **hiçbiri Aladhan isteğini
etkilemiyor.** Ada etiketleri de ("Orta (1/7 gölge)", "Çeyrek (1/4 gölge)",
"Yarım") sağlayıcının sözlüğüyle örtüşmüyor. Bu, bildirilen açık hatanın
canlı kanıtıdır. **Düzeltilmedi** — anlam eşlemesi bir ürün kararıdır ve
Türkiye dışı akışın davranışını değiştirir.

**Asr tarafı doğru çalışıyor** (ayrıca doğrulandı):
`school=0 → meta.school=STANDARD, Asr 16:00` / `school=1 → HANAFI, Asr 16:48`.

---

## 5. Resmî veri neden gerekli (somut ölçüm)

Ankara, 2026-10-03. Aladhan `method` parametresi **gönderilmeden**
(ülkeye göre otomatik → `Diyanet İşleri Başkanlığı, Turkey (experimental)`)
resmî Diyanet tablosuyla karşılaştırıldı:

| Vakit | Diyanet (resmî) | Aladhan (method=13) | fark |
| :--- | :--- | :--- | ---: |
| İmsak | 05:17 | 05:17 | 0 |
| Güneş | 06:39 | 06:40 | +1 |
| Öğle | 12:43 | 12:43 | 0 |
| İkindi | 15:59 | 16:00 | +1 |
| Akşam | 18:36 | 18:35 | −1 |
| Yatsı | 19:54 | 19:53 | −1 |

**6 vaktin 4'ü yanlış, ortalama sapma 0,67 dk.** "Dakika düzeyinde birebir"
hedefi mevcut kaynakla karşılanamıyor; resmî tabloyla karşılanıyor.

---

## 6. Paket boyutu tahmini (veri toplanmadan)

Günlük kayıt `20261003,0517,0639,1243,1559,1836,1954` biçiminde ≈ 45 bayt.

```
396 gün × 45 B  = 17,8 KB / yerleşim
865 yerleşim    = ~15,4 MB (ham, sıkıştırılmamış)
```

Sıkıştırma ile belirgin biçimde düşer (saatler çok tekrarlı), ancak bu
**tahmindir; ölçülmüş değildir** — çünkü veri henüz toplanmadı. Bugünkü APK
57,6 MB. ~15 MB ham ek yük, "her açılışta belleğe yükleme" yapılmayacak
şekilde ilçe bazlı şardlanarak çözülebilir; bu, karar verildikten sonra
ölçülmesi gereken ayrı bir iş.

---

> **Güncelleme (final turu):** 1–8. bölümler ilk ölçüm turunun tarihsel
> kaydıdır; kapsam kararı **verilmeden önce** yazılmıştır. Karar sonrası
> ölçümler ve final sonuçları **10–14. bölümlerdedir**.

## 7. Durulan yer — iki karar gerekli

**Bu iş, bu noktada durduruldu.** İki bağımsız engel var ve ikisi de
kullanıcının kararı.

### Engel A — yetki / yeniden dağıtım

865 resmî sayfayı WAF korumalı bir devlet hostundan toplamak, hostun
tarama politikası okunamadığı ve toplu kullanım/yeniden dağıtım izni
olmadığı durumda yapılacak bir toplu taramadır. Kullanıcının Diyanet API
anahtarı başvurusu **beklemede**; talimat "anahtar varmış gibi davranma"
diyor. Bu yüzden:

- toplu indirme **yapılmadı**,
- WAF'a erişim kısıtı **aşılmadı**, robots.txt `robots.txt` sayfasıyla
  geçilmedi, istek sayısı bilerek düşük tutuldu (toplam ~18 istek),
- `vakithesaplama` için **hesap açılmadı**.

**Soru:** Diyanet anahtarı gelene kadar resmî veri
(a) hiç alınmadan beklensin, (b) kullanıcıdan açık izin alınarak alınsın,
(c) daraltılmış kapsamla mı alınsın?

### Engel B — kapsam

Resmî kaynak bugün **2027-12-31**'de bitiyor ve içinde **59 günlük boşluk**
var. "En az iki ileri yıl" **karşılanamıyor**; fark hesaplanarak,
kopyalanarak veya uydurularak doldurulmadı.

**Soru:**
1. Kullanılabilir kapsam `2026-10-03 → 2027-12-31` (396 gün, içinde 59 gün
   boşluk) olarak kabul edilsin mi?
2. O 59 gün için uygulama ne göstersin — resmî veri yokken başka kaynağa
   düşmesin mi (görevde yasak), yoksa o tarihlerde vakit gösterilmesin mi?
3. Kasım/Aralık 2026 resmî aylık **PDF** tablolarından alınarak kapatılsın mı?

Onay verilmeden kapsam daraltılmayacak, resmî veri başlığı başka kaynağa
sessizce bağlanmayacak ve üretim kodu değiştirilmeyecek.

---

## 8. Yapılmayanlar (bilerek)

- 865 sayfanın toplu indirilmesi.
- Eksik tarihlerin hesaplanması / kopyalanması / uydurulması.
- `lib/` altında tek satır değişiklik.
- `vakithesaplama.diyanet.gov.tr` için hesap açılması.
- Ölçülmemiş paket boyutunun kesin rakam gibi yazılması.
- 3 Ekim 2026 tarihli son test/analyze raporunun (479 test, 11 atlandı, 0 hata)
  **güncel doğrulama gibi sunulması** — bu turda test çalıştırılmadı,
  çünkü üretim koduna dokunulmadı.

---

## 9. Tekrar üretilebilirlik

Bu klasördeki ölçümü tekrarlamak için:

```bash
# 1) Resmî katalog (BOM'lu, utf-8-sig)
curl -o turkiye_yerlesim_katalogu.json \
  https://namazvakitleri.diyanet.gov.tr/assets/locations/TURKEY.json

# 2) İstediğiniz yerleşimin resmî sayfası (slug City adından türetilir)
curl -o adana.html \
  https://namazvakitleri.diyanet.gov.tr/tr-TR/9146/adana-icin-namaz-vakti

# 3) Kapsam + bütünlük ölçümü (veri İNDİRMEZ, yalnızca denetler)
python diyanet_kapsam_olcumu.py turkiye_yerlesim_katalogu.json adana.html
```

Araç, "eksik/tekrar/bosluk" ölçümünü ve katalog kimlik denetimini yapar; ay
adlarındaki noktasız-noktalı i farkını (`Kasım`/`Kasim`) çözdüğü için
sayfa satırlarını yanlışlıkla elemesi gerekmez. Çıktı bu dosyadaki
sayılarla birebir aynıdır.

**Bütünlük notu:** katalog ölçümü **tüm 865 kaydı** kapsar. Sayfa ölçümü
yalnızca indirilmiş olan dosyalar için çalışır; 865 sayfanın tamamı
inşa edildiğinde aynı araç eksiksizlik/tekrar denetimini toplu yapabilir.