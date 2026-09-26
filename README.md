# 🕌 Namaz Vakitleri & Kıble Pusulası (Prayer Times App)

Modern arayüzü, temiz kod mimarisi ve kapsamlı özellikleriyle Flutter kullanılarak geliştirilmiş çok dilli bir İslami yaşam uygulaması. Uygulama, kullanıcılara namaz vakitlerini takip etme, kıble yönünü bulma, günlük ayet/hadis okuma ve dini günleri takip etme imkanı sunar.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

## ✨ Öne Çıkan Özellikler

* 🌍 **245 Ülke, 141.135 Şehir:** Avrupa, Amerika, Asya, Afrika ve Okyanusya kıtalarındaki 245 ülkenin **tüm şehirleri** uygulamada dahildir. Ülke seçimi **Ayarlar** menüsünden yapılır (kıta gruplarına ayrılmış, aramalı liste); şehir seçimi ana ekrandaki şehir düğmesiyle yapılır. Şehirler Türkçe karakterden bağımsız aranır ("suleyman" yazan kullanıcı "Süleyman" bulur).
* 🗺️ **GPS ile Konum Bulma:** `geolocator` ve `geocoding` ile kullanıcının bulunduğu ülkeyi ve şehri otomatik tespit etme. Vakitler tam GPS koordinatı üzerinden hesaplanır.
* 🕋 **Kıble Pusulası:** Cihazın donanımsal pusula sensörü (`flutter_compass`) ve özel trigonometrik hesaplamalar ile tam isabetli yön bulma. Hedefe ulaşıldığında titreşimli (`HapticFeedback`) geri bildirim.
* ⏱️ **Canlı Geri Sayım ve Vakitler:** Aladhan API entegrasyonu ile günlük namaz vakitlerinin çekilmesi ve sıradaki vakte kalan sürenin dinamik hesaplanması.
* 🧮 **Ülkeye Göre Hesaplama Yöntemi:** Hesaplama yöntemi vakitleri kaydırdığı için uygulama `method` parametresini göndermez; Aladhan ülkeye göre resmi yöntemi kendisi seçer (TR→Diyanet, US→ISNA, EG→Mısır, SA→Umm al-Qura, ID→KEMENAG, FR→UOIF, TN→Tunus, MY→JAKIM). Kullanıcı Ayarlar'dan 24 resmi yöntem arasından kendi camiyinin yöntemini seçebilir.
* 🔔 **Arka Plan Bildirimleri:** Uygulama kapalı olsa dahi ezan vakti girdiğinde `flutter_local_notifications` ile yerel bildirim (alarm) gönderme.
* 📱 **Ana Ekran Widget'ları (Home Widgets):** Android cihazlar için uygulamanın içine girmeden sıradaki vakti, "Günün Ayeti"ni ve "Günün Hadisi"ni gösteren ana ekran araçları.
* 🌐 **Çoklu Dil Desteği (i18n):** `easy_localization` ile anlık olarak Türkçe (TR) ve İngilizce (EN) dil geçişi.
* 🎨 **Dinamik Tema Motoru:** Kullanıcının seçtiği temanın (Zümrüt Yeşili, Okyanus Mavisi, Gece Moru vb.) `ValueNotifier` ile tüm uygulamaya anında yansıması ve `shared_preferences` ile hafızaya kaydedilmesi.
* 📅 **Dini Günler Ajandası:** 2026 (1447-1448 Hicri) yılına ait özel dini günlerin listelenmesi ve detaylı açıklamaları.
* 📤 **Paylaşım Özelliği:** Günün ayet ve hadislerini diğer uygulamalarda (`share_plus`) paylaşabilme.

## 🏗️ Mimari ve Klasör Yapısı (Layered Architecture)

Proje, Sorumlulukların Ayrılması (Separation of Concerns) prensibine uygun olarak katmanlı bir yapıda geliştirilmiştir. Bu sayede spagetti kod engellenmiş ve sürdürülebilirlik maksimize edilmiştir:

* 📂 **`lib/pages/` (View Katmanı):** Sadece arayüz (UI) çizimlerini barındıran modüler sayfalar (`anasayfa.dart`, `kible_sayfasi.dart`, `ozelGunler_sayfasi.dart`, `ayarlar_sayfasi.dart`).
* 📂 **`lib/widgets/` (UI Bileşenleri):** Yeniden kullanılabilir seçici diyalogları (`ulke_secici.dart`, `sehir_secici.dart`, `dil_secici.dart`).
* 📂 **`lib/data/` (Repository Katmanı):** Ayetler, Hadisler, Özel Günler veri havuzu (`veri_havuzu.dart`) ve ülke/şehir verisinin yüklenmesi (`ulke_verisi.dart`).
* 📂 **`lib/utils/` (Business Logic):** Matematiksel kıble hesaplamaları gibi arayüzden bağımsız çalışan yardımcı algoritmalar.
* 📄 **`lib/main.dart` (Entry Point):** Bağımlılıkları başlatan, temayı ayarlayan, seçili ülke/şehir durumunu yöneten ana iskelet.
* 🔧 **`tool/` (Veri Üretimi):** Ülke/şehir veri dosyalarını üreten `veri_uretici.dart` ve çeviri anahtarı güncelleyici `cevirileri_guncelle.dart`.

## 🗺️ Ülke ve Şehir Verisi

Uygulama, Aladhan API'nin şartlarından dolayı **koordinat tabanlı** çalışır:

Aladhan'in `calendarByCity` uç noktası dahili bir geocoder kullanır ve büyük veri setindeki küçük şehirlerin çoğunu çözemez; bu istekler `503 Geocoding is temporarily unavailable` ile başarısız olur. Bu nedenle uygulama, aynı aylık veriyi (30 gün) koordinatla döndüren `/v1/calendar` uç noktasını kullanır. **141.135 şehir** bu sayede sorunsuz çalışır.

Koordinat yaklaşımının ikinci bir faydası daha var: `meta.timezone` her zaman doğru geldiği için ezan alarmları seçilen şehrin saat diliminde doğru zamanlanır.

## 🧮 Hesaplama Yöntemi

Aladhan'ın `method` parametresi namaz vakitlerini doğrudan etkiler. Uygulama bu parametreyi **göndermez**; böylece Aladhan ülkeye göre resmi yöntemi kendisi seçer.

Neden otomatik? Aynı şehirde yöntem değişince vakitler kayıyor. `method=13` (Türkiye) her ülkede sabit kullanıldığında ölçülen sapmalar (Eylül 2026):

| Şehir | Doğru yöntem | `method=13` sapması |
| :--- | :--- | ---: |
| Paris | UOIF (12) | **Fajr 38 dk, İşâ 31 dk** |
| New York | ISNA (2) | **Fajr 16 dk, İşâ 11 dk** |
| Kahire | Mısır (5) | Fajr 7 dk |
| Suudi Arabistan | Umm al-Qura (4) | **İşâ 19 dk** |
| Endonezya | KEMENAG (20) | Fajr 8 dk |
| İstanbul | Diyanet (13) | — (zaten doğru) |

Otomatik moda geçildikten sonra Paris'te sapma **38 dakikadan 0'a** indi ve 12 ülke örneğinin tamamı doğru yöntemi aldı.

Kullanıcı **Ayarlar → Hesaplama Yöntemi** ekranından 24 resmi yöntem arasından seçebilir. Bu gereklidir çünkü "doğru" yöntem ülkeye göre değil, kullanıcının takip ettiği camiye ve mezhebe göre değişir. Yöntem listesi `https://api.aladhan.com/v1/methods` uç noktasından alınmıştır; açı değerleriyle birlikte gösterilir.

| | |
| :--- | :--- |
| **Kapsam** | Avrupa (53), Amerika (56), Asya (50), Afrika (60), Okyanusya (26) → **245 ülke** |
| **Şehir sayısı** | **141.135** |
| **Kaynak** | [dr5hn/countries-states-cities-database](https://github.com/dr5hn/countries-states-cities-database) (ODbL-1.0) |
| **Üretim** | `dart run tool/veri_uretici.dart <kaynak-json>` |

**Dosya düzeni:** `assets/data/ulkeler.json` (ülke listesi, 65 KB) uygulama açılışında yüklenir. Şehirler ülke başına ayrı dosyalarda tutulur (`assets/data/sehirler/TR.txt`) ve **yalnızca seçilen ülke açıldığında** okunup önbelleğe alınır. En kalabalık ülke dosyası (ABD, 12.097 şehir) 334 KB'dir; uygulama açılışında 3.8 MB'lık şehir verisinin tamamı yüklenmez.

**Kapsam dışı bırakılanlar:** Kutup bölgeleri (Polar) ve şehir/koordinat verisi bulunmayan iki yerleşim — `United States Minor Outlying Islands` (kalıcı nüfusu yok) ve `Tokelau`.

## 📦 Kullanılan Temel Paketler

| Paket Adı | Kullanım Amacı |
| :--- | :--- |
| `http` | Aladhan API istekleri (koordinat tabanlı `/v1/calendar`) |
| `easy_localization` | Çoklu dil desteği (TR/EN/ZH) |
| `flutter_local_notifications` | Arka plan alarmları ve yerel bildirimler |
| `geolocator` & `geocoding` | GPS ile ülke/şehir tespiti |
| `timezone` | Alarmların seçilen şehrin saat diliminde zamanlanması |
| `flutter_compass` | Donanımsal yön (heading) verisi |
| `home_widget` | İşletim sistemine entegre ana ekran araçları |
| `shared_preferences` | Kullanıcı tercihleri (Şehir, Tema vb.) önbellekleme |

## 🚀 Kurulum ve Çalıştırma

Projeyi kendi bilgisayarınızda çalıştırmak için aşağıdaki adımları izleyebilirsiniz:

1. Repoyu klonlayın:
   ```bash
   git clone [https://github.com/KULLANICI_ADIN/namaz_vakitleri.git](https://github.com/KULLANICI_ADIN/namaz_vakitleri.git)
2. Proje dizinine gidin ve bağımlılıkları indirin:
   ```bash
   cd namaz_vakitleri
   flutter pub get
3. Uygulamayı derleyin ve çalıştırın:
   ```bash
   flutter run
(Not: Widget ve arka plan bildirim özelliklerinin tam çalışması için gerçek bir Android/iOS cihazda test edilmesi önerilir.)

4. Ülke/şehir verisini yeniden üretmek isterseniz (isteğe bağlı — veriler depoda gelir):
   ```bash
   # Kaynak: https://github.com/dr5hn/countries-states-cities-database
   #         -> json/countries+states+cities.json dosyasını indirin
   dart run tool/veri_uretici.dart /path/to/countries+states+cities.json

   # Yeni arayüz metinlerini çeviri dosyalarına eklemek için:
   dart run tool/cevirileri_guncelle.dart
   ```

## 🌐 Diller

Uygulama 245 ülkenin **152 resmî dilini** tanır. Dil listesi elle yazılmamıştır; `mledoze/countries` (ulke→dil) ve `haliaeetus/iso-639` (otokton adlar) veri setlerinden üretilir:

```bash
dart run tool/dil_katalogu_uret.dart <countries-json> <iso639-json>
```

| Özellik | Durum |
| :--- | :--- |
| Katalogdaki resmî dil | 152 |
| Otokton adı bulunan | 111 |
| Sağdan sola (RTL) yazan | 7 (Arapça, Farsça, Urduca, İbranice, Aramice, Dhivehi, Peştuca) |
| Şu an çevirisi hazır | 3 (Türkçe, İngilizce, Çince) |

**Çeviri dosyası adı = dil kodu = `Locale` kodu.** `tur.json` ↔ `tur` ↔ `Locale('tur')`. Bu eşleme bozulursa easy_localization dosyayı bulamaz; `hazirDiller` listesi diskteki dosyalarla karşılaştırılarak testte doğrulanır. Yeni bir çeviri dosyası eklemek yeterlidir — `supportedLocales` katalogdan gelir, kodda güncelleme gerekmez.

**Hangi 25 dil?** Ülke sayısı ölçütüyle seçim pratikte yanlıştı (Türkçe'yi 1 ülkeye indirip "Austro-Bavarian German" seçiyordu). Müslüman nüfusuyla ağırlıklandırıldığında **207/245 ülke ve Müslüman nüfusunun %98,8'i** kapsanıyor:

`amh ara ben deu eng fas fra ind ita jpn kor mya nep pol por ron rus spa tam tha tuk tur ukr vie zho`

**Arayüzde üç ayrıntı:**
- Kullanıcının seçili ülkesinin resmî dilleri en üstte önerilir.
- Arama hem otokton adı hem İngilizce adı hem ISO kodunu kapsar ve Türkçe karakterden bağımsızdır.
- RTL dillerde `MaterialApp.builder` ile `Directionality` uygulanır; aksi hâlde menüler ve listeler okunmaz hâle gelir.

**İçerik çevrileri:** Ayetler için [AlQuran Cloud](https://alquran.cloud) kullanılacaktır (21/25 dilde kaynaklı çeviri mevcut; kalan 4 dilde İngilizceye düşülür). Hadis metinlerinin güvenilir bir çok dilli kaynağı bulunmadığından yalnızca TR/EN/ZH dillerinde gösterilecektir.

## 📝 Lisans ve Atıf

**Dil verisi** [mledoze/countries](https://github.com/mledoze/countries) (Unlicense) ve [haliaeetus/iso-639](https://github.com/haliaeetus/iso-639) projelerinden alınmıştır.

**Ülke/şehir verisi** [dr5hn/countries-states-cities-database](https://github.com/dr5hn/countries-states-cities-database) projesinden alınmıştır ve **ODbL-1.0** (Open Data Commons Open Database License) lisansıyla dağıtılmaktadır. ODbL kopyalaç bir lisans olduğu için, bu veriyi kullanan ve dağıtan uygulamalar verinin kaynağını belirtmek zorundadır.

**Vakit verisi** [Aladhan API](https://aladhan.com/prayer-times-api) tarafından ücretsiz olarak sağlanmaktadır; API anahtarı veya kayıt gerektirmez.

**Derleme yolundaki yamalar:** `perfect_volume_control` paketi (zikir sayacı için) pub.dev'de terk edilmiş durumdadır ve AGP 8+ ile derlenemiyordu. Kaynak kodu değiştirilmeden `third_party/perfect_volume_control` altına alınıp yalnızca derlenebilir hale getirilmiştir. `home_widget` paketi ise dinamik sürüm (`androidx.glance:glance-appwidget:1.+`) kullandığı için derleme sırasında sabitlenmiştir.
