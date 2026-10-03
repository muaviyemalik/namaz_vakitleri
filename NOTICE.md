# ÜÇÜNCÜ TARAF VERİ VE LİSANS BİLGİSİ

Bu uygulama, aşağıdaki üçüncü taraf veri setlerini ve servisleri kullanır.
Lisans koşulları **atıf zorunlu** olanlar uygulama içinde de
(Ayarlar → Lisans ve Atıf) görüntülenmektedir.

---

## Kopyalaç lisanslı veri setleri (atıf zorunlu)

### Ülke ve Şehir Veritabanı
- **Kaynak:** [dr5hn/countries-states-cities-database](https://github.com/dr5hn/countries-states-cities-database)
- **Lisans:** ODbL-1.0 — [Open Data Commons Open Database License v1.0](https://opendatacommons.org/licenses/odbl/1-0/)
- **Kullanım:** 245 ülke, 160.869 yerleşimin adı, koordinatı ve **il bilgisi**
- **Üretim:** `dart run tool/sehir_verisi_uret.dart`

### Nüfus ve İl Adları (GeoNames)
- **Kaynaklar:**
  - [cities15000](https://download.geonames.org/export/dump/cities15000.zip),
    [cities5000](https://download.geonames.org/export/dump/cities5000.zip),
    [cities1000](https://download.geonames.org/export/dump/cities1000.zip),
    [cities500](https://download.geonames.org/export/dump/cities500.zip)
    — nüfus merdiveni (500'den küçük olmayan her yerleşim)
  - [admin1CodesASCII.txt](https://download.geonames.org/export/dump/admin1CodesASCII.txt)
    — il kodlarının yerel dilde adlara çevrilmesi
- **Lisans:** CC BY 4.0 — [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Atıf:** "GeoNames" — © GeoNames, [www.geonames.org](https://www.geonames.org/webservices/)
- **Kullanım:** dr5hn verisi ilçe/köy düzeyine odaklanır ve büyük şehirleri
  eksik bırakır (Türkiye'de Bursa, Konya, Kahramanmaraş gibi 13 il yoktu).
  GeoNames bu şehirlerin kanonik adlarını, nüfuslarını ve il adlarını sağlar.
- **Üretim:** `dart run tool/sehir_verisi_uret.dart`

> **CC BY 4.0 neden önemli?**
> Bu lisans kopyalaç değildir ancak atıf zorunludur ve **yapılan
> değişikliklerin** belirtilmesini şart koşar. Yapılan değişiklikler:
> - dr5hn'deki 152.970 küçük yerleşim kaydı korundu, nüfusları GeoNames
>   merdiven dosyalarından **yalnızca isim eşleşmesiyle** tamamlandı.
> - dr5hn'de olmayan 8.715 önemli şehir eklendi.
> - Türkiye'deki ASCII yazımlar resmî Türkçe yazıma çevrildi.
> - Aynı adı farklı illerde taşıyan kayıtlar **il bilgisiyle** ayrıldı
>   (Ankara/Gölbaşı ve Adıyaman/Gölbaşı artık iki ayrı kayıttır); bu
>   değişiklikle daha önce ad çakışması nedeniyle kaybolan 1.271 yer
>   geri kazandı.
> - Aynı koordinatı taşıyan mükerrer kayıtlar birleştirildi, diğer adları
>   takma ad olarak saklandı (1.404 takma ad).
> - İl adlarındaki tutarsız "Province" ekleri temizlendi.
>
> Atıf hem bu dosyada hem uygulama içinde (Ayarlar → Yasal Notlar) verilir.

### Türkiye İl Adları
- **Kaynak:** Türkiye'nin resmî 81 ili; yazımlar TDK ve İçişleri Bakanlığı
  kayıtlarıyla tutarlıdır.
- **Lisans:** Coğrafi isimler devlet verisidir; ayrı bir lisans gerektirmez.
- **Kullanım:** Kahramanmaraş, Kocaeli/İzmit, Sakarya/Adapazarı, Hatay/Antakya
  gibi il adlarının kanonik yazımı ve il merkezi eşlemesi.
- **Üretim:** `tool/sehir_verisi_uret.dart` içindeki `turkiyeIlleri` tablosu

### Ülke-Dil İlişkisi
- **Kaynak:** [mledoze/countries](https://github.com/mledoze/countries)
- **Lisans:** ODbL-1.0 — [Open Data Commons Open Database License v1.0](https://opendatacommons.org/licenses/odbl/1-0/)
- **Kullanım:** Hangi ülkenin hangi dilleri resmî olarak kullandığı
- **Üretim:** `dart run tool/dil_katalogu_uret.dart <countries-json> <iso639-json>`

> **ODbL-1.0 neden önemli?**
> Bu lisans kopyalaçtır. ODbL-1.0 ile lisanslanmış bir veri tabanından
> türetilen ve dağıtılan veri, kaynağı açıkça belirtmek zorundadır. Kaynak
> veri setlerinin lisans koşulları bu uygulamada aynen uygulanmıştır.

---

## Serbest lisanslı veri setleri

### Dil Adları (otokton adlar)
- **Kaynak:** [haliaeetus/iso-639](https://github.com/haliaeetus/iso-639)
- **Lisans:** MIT
- **Kullanım:** 152 dilin kendi dilindeki adı ve ISO 639-1/639-2 kod eşlemesi

---

## Servisler

### Resmî Diyanet Vakit Verisi (Türkiye)
- **Kaynak:** [T.C. Diyanet İşleri Başkanlığı — Namaz Vakitleri](https://namazvakitleri.diyanet.gov.tr/)
- **Alınan veri:**
  - `assets/locations/TURKEY.json` → 865 resmî yerleşim kaydı (il + yerleşim + `CityID`)
  - `https://namazvakitleri.diyanet.gov.tr/tr-TR/{CityID}/{slug}` → her yerleşimin
    vakit tablosu (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı + hicri tarih)
- **Kullanım:** Türkiye'de vakitler **bu tablolardan** okunur. Ağ gerekmez.
- **Kapsam:** Paket `assets/veri/diyanet/paket.json` içinde kayıtlıdır
  (kaynak adresi, edinme tarihi, kapsanan tarih aralığı, yerleşim sayısı,
  paket sürümü ve SHA-256 bütünlük damgası).
- **Üretim:**
  ```bash
  python tool/diyanet_verisi_indir.py --hiz 1.2
  python tool/diyanet_verisi_uret.py
  ```
- **Lisans / koşullar:** Diyanet resmî bir devlet kurumudur. Veri kamuya açıktır
  ve Diyanet'in `og:description` metni bu vakitlerin "Diyanet İşleri Başkanlığı'nın
  **resmi hesaplamalarına** dayandığını" belirtir. Ancak **yeniden dağıtım
  koşulları yazılı olarak alınmadan** ticari kullanım veya üçüncü tarafa
  dağıtım konusunda hukuki bir değerlendirme yapılmamıştır. Bu dosya
  atıf amaçlıdır; lisans değildir. Dağıtım öncesi Diyanet'ten yazılı izin
  alınması tavsiye edilir.

### Aladhan Prayer Times API (Türkiye dışı + hesaplanmış yedek)
- **Servis:** [Aladhan Prayer Times API](https://aladhan.com/prayer-times-api)
- **Kullanım:** Türkiye dışındaki 244 ülkenin vakitleri; ayrıca Türkiye'de
  resmî veri **bulunamayan** yerleşimlerde açıkça etiketlenmiş hesaplanmış saatler
- **Not:** API anahtarı veya üyelik gerektirmez
- **Önemli:** Aladhan `method=13` seçse bile resmî Diyanet verisi **değildir**;
  kendi hesabını yapar ve `(experimental)` etiketiyle döner. Bu yüzden
  Türkiye'de varsayılan kaynak Diyanet'in kendi tablosudur.

### Kur'an Çevirileri

- **Kullanılan servis:** YOK.
- **Planlanan servis:** [AlQuran Cloud](https://alquran.cloud) — *ileride, karara bağlıdır.*

**Gerçek durum:** Bu sürümde ayet metinleri **uygulamanın içine gömülüdür**
(`lib/data/veri_havuzu.dart`) ve yalnızca **TR / EN / ZH** dillerinde sunulur. Diğer
22 dilde İngilizce metin gösterilir (görünür biçimde; `icerik_dili.dart` bu eşlemeyi
yapar). AlQuran Cloud **hiçbir çalışma zamanı isteği yapılmaz** — yalnızca
`tool/quran_edisyon.dart` ve `tool/quran_kapsam.dart` betikleri, mevcut edisyonları
saymak için API'ye **keşif amaçlı** sorgu yapar.

**Eklendiği andan itibaren yapılacaklar:**

1. AlQuran Cloud kullanım koşulları ve lisansı incelenip uygunluk doğrulanmalı.
2. Aynı anda **kullanılan** servis olarak `NOTICE.md` ve uygulama içi lisans ekranına
   gerçek bir "kaynak" maddesi eklenmeli.
3. Her çevirinin kendi kaynağı vardır; atıflar ayet ekranında gösterilmelidir.
4. Çevirilerin insan gözüyle (terim ve edebiyat açısından) denetlenmesi gerekir.

Bu maddeler tamamlanana kadar AlQuran Cloud **"kullanılan servis" olarak sunulmaz**.

---

## Derleme yolundaki paket yamaları

### perfect_volume_control
- **Kaynak:** [JiangJuHong/FlutterPerfectVolumeControl](https://github.com/JiangJuHong/FlutterPerfectVolumeControl)
- **Lisans:** MIT
- **Durum:** Paket pub.dev'de terk edilmiş ve AGP 8+ ile derlenemiyordu.
  Kaynak kodu değiştirilmeden `third_party/perfect_volume_control` altına
  alınmış, yalnızca derlenebilir hâle getirilmiştir (namespace eklendi,
  `jcenter` → `mavenCentral`).

### home_widget
- **Kaynak:** [esantonborri/home_widget](https://github.com/esantonborri/home_widget)
- **Lisans:** MIT
- **Durum:** Dinamik sürüm bağımlılığı (`androidx.glance:glance-appwidget:1.+`)
  kullanıyordu ve yeni sürüm yayınlandığında derleme kırılıyordu. Sürüm
  Gradle `resolutionStrategy` ile sabitlenmiştir; paket kodu değiştirilmemiştir.

---

## Uygulamanın kendi kodu

Flutter/Dart uygulama kodu bu depoda bulunur. Kullanılan Flutter
paketlerinin lisansları `pubspec.lock` dosyasındaki paketlerin kendi
depolarında listelenmiştir.
