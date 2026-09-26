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

### Namaz Vakti Verisi
- **Servis:** [Aladhan Prayer Times API](https://aladhan.com/prayer-times-api)
- **Kullanım:** Namaz vakitleri, hicri takvim, hesaplama yöntemleri
- **Not:** API anahtarı veya üyelik gerektirmez

### Kur'an Çevirileri
- **Servis:** [AlQuran Cloud](https://alquran.cloud)
- **Kullanım:** Ayet metinleri ve çevirileri
- **Not:** Her çevirinin kendi kaynağı vardır; atıflar ayet ekranında gösterilir

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
