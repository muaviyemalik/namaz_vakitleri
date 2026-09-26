# ÜÇÜNCÜ TARAF VERİ VE LİSANS BİLGİSİ

Bu uygulama, aşağıdaki üçüncü taraf veri setlerini ve servisleri kullanır.
Lisans koşulları **atıf zorunlu** olanlar uygulama içinde de
(Ayarlar → Lisans ve Atıf) görüntülenmektedir.

---

## Kopyalaç lisanslı veri setleri (atıf zorunlu)

### Ülke ve Şehir Veritabanı
- **Kaynak:** [dr5hn/countries-states-cities-database](https://github.com/dr5hn/countries-states-cities-database)
- **Lisans:** ODbL-1.0 — [Open Data Commons Open Database License v1.0](https://opendatacommons.org/licenses/odbl/1-0/)
- **Kullanım:** 245 ülke ve 141.135 şehrin adı, koordinatı, eyalet bilgisi
- **Üretim:** `dart run tool/veri_uretici.dart <kaynak-json>`

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
