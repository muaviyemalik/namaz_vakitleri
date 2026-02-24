# 🕌 Namaz Vakitleri & Kıble Pusulası (Prayer Times App)

Modern arayüzü, temiz kod mimarisi ve kapsamlı özellikleriyle Flutter kullanılarak geliştirilmiş çok dilli bir İslami yaşam uygulaması. Uygulama, kullanıcılara namaz vakitlerini takip etme, kıble yönünü bulma, günlük ayet/hadis okuma ve dini günleri takip etme imkanı sunar.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

## ✨ Öne Çıkan Özellikler

* 🌍 **Otomatik Konum ve GPS:** `geolocator` ve `geocoding` ile kullanıcının bulunduğu şehri otomatik tespit etme.
* 🕋 **Kıble Pusulası:** Cihazın donanımsal pusula sensörü (`flutter_compass`) ve özel trigonometrik hesaplamalar ile tam isabetli yön bulma. Hedefe ulaşıldığında titreşimli (`HapticFeedback`) geri bildirim.
* ⏱️ **Canlı Geri Sayım ve Vakitler:** Aladhan API entegrasyonu ile günlük namaz vakitlerinin çekilmesi ve sıradaki vakte kalan sürenin dinamik hesaplanması.
* 🔔 **Arka Plan Bildirimleri:** Uygulama kapalı olsa dahi ezan vakti girdiğinde `flutter_local_notifications` ile yerel bildirim (alarm) gönderme.
* 📱 **Ana Ekran Widget'ları (Home Widgets):** Android cihazlar için uygulamanın içine girmeden sıradaki vakti, "Günün Ayeti"ni ve "Günün Hadisi"ni gösteren ana ekran araçları.
* 🌐 **Çoklu Dil Desteği (i18n):** `easy_localization` ile anlık olarak Türkçe (TR) ve İngilizce (EN) dil geçişi.
* 🎨 **Dinamik Tema Motoru:** Kullanıcının seçtiği temanın (Zümrüt Yeşili, Okyanus Mavisi, Gece Moru vb.) `ValueNotifier` ile tüm uygulamaya anında yansıması ve `shared_preferences` ile hafızaya kaydedilmesi.
* 📅 **Dini Günler Ajandası:** 2026 (1447-1448 Hicri) yılına ait özel dini günlerin listelenmesi ve detaylı açıklamaları.
* 📤 **Paylaşım Özelliği:** Günün ayet ve hadislerini diğer uygulamalarda (`share_plus`) paylaşabilme.

## 🏗️ Mimari ve Klasör Yapısı (Layered Architecture)

Proje, Sorumlulukların Ayrılması (Separation of Concerns) prensibine uygun olarak katmanlı bir yapıda geliştirilmiştir. Bu sayede spagetti kod engellenmiş ve sürdürülebilirlik maksimize edilmiştir:

* 📂 **`lib/pages/` (View Katmanı):** Sadece arayüz (UI) çizimlerini barındıran modüler sayfalar (`ana_sayfa.dart`, `kible_sayfasi.dart`, `ozelGunler_sayfasi.dart`).
* 📂 **`lib/data/` (Repository Katmanı):** Uygulamanın statik verilerini (Ayetler, Hadisler, Özel Günler) ve DTO (Data Transfer Object) modellerini yöneten veri havuzu.
* 📂 **`lib/utils/` (Business Logic):** Matematiksel kıble hesaplamaları gibi arayüzden bağımsız çalışan yardımcı algoritmalar.
* 📄 **`lib/main.dart` (Entry Point):** Yalnızca bağımlılıkları başlatan, temayı ayarlayan ve rotaları çizen ana iskelet.

## 📦 Kullanılan Temel Paketler

| Paket Adı | Kullanım Amacı |
| :--- | :--- |
| `http` | API istekleri (REST) |
| `easy_localization` | Çoklu dil desteği (TR/EN) |
| `flutter_local_notifications` | Arka plan alarmları ve yerel bildirimler |
| `geolocator` & `geocoding` | GPS ve şehir tespiti |
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
