# Dinamik görünüm kontrolü — 9 Ekim 2026

Başlangıç: main/444ebdf; aşağıdaki UI/native/test değişiklikleri bu HEAD üzerine uygulanmıştır.

## Düzeltmeler
- Zikirmatik hedef etiketi esnek genişlikte satıra geçer; sayı, alana sığacak şekilde ölçeklenir.
- Ana sayaç tek satır kalır; uzun açıklama ortalanıp satıra geçer ve kartın yüksekliği içeriğe uyar.
- Ayet/hadis kartlarının başlıkları esnek genişlikte satıra geçer; paylaşım düğmesi görünür kalır.
- Veri yükleme hata ekranı uzun çeviriler/büyük yazı/yatay ekranda kaydırılabilir.
- Günlük widget kısa olduğunda altı vakte öncelik verir. Yeterli yükseklik varsa sonraki vakit/sayaç alanları görünür. Bu karar sistem yazı boyutunu da dikkate alır.
- Günlük widget saatleri hücre genişliği/yüksekliğine göre otomatik boyutlanır; satır kırılmaz ve saat kırpılmaz.
- Kısa ayet/hadis widgetında büyük yazıyla boşluklar azalır, şehir/tarih başlığı gizlenir; içerik ve kaynak alanına yer ayrılır. Geniş ölçüde başlık korunur. Uzun widget metninde mevcut kısaltma davranışı korunur; tam ekran uygulama widgeta dokunularak açılır.

## Doğrulama
- `flutter test test/gorunum_matrisi_test.dart test/zikirmatik_test.dart --no-pub`: **79 PASS** (75 görünüm + 4 mevcut zikirmatik regresyonu).
- 25 gerçek çeviri dosyası ve üretimin ISO-1 yerelleştirme delegeleri kullanıldı; Arapça/Farsça RTL. Koşullar: 320×640 / %200 yazı, 640×360 / %140 yazı, 800×1280 / %100 yazı.
- Ana ekranın veri yok/hata hâli ve üç günlük kontrollü cache verisiyle yüklenmiş vakit kartları, zikirmatik panel/hedef menüsü, ayarlar ve bildirim ayarları çizildi. Yüklenmiş ana ekran ve ayarlar listeleri sonuna kadar kaydırıldı; son vakit görünürlüğü ve render hataları denetlendi. Bu veri fixture'ı canlı saat/API doğrulaması değildir.
- Android17 AVD WidgetKontrol: font1.0 **26 PASS**, font2.0 **26 PASS**. Günlük 250×220/320×250/500×320; küçük vakit 150×150/240×200/400×260; ayet/hadis 200×140/320×200/500×320 dp. Alt alanların görünürlüğü, günlük widgetın altı saatinin tamamı/kırpılmaması ve mevcut timeline kontrolleri geçti. Auto-size için gerçek host gibi ikinci layout geçişi kullanılır.
- Debug APK ve androidTest derlendi. AVD ekran görüntüsünde 320dp genişlik/%200 yazıyla ana sayaç ve esnek kartlar incelendi. İlk hızlı locale görüntüleri splash aşamasında yakalandı; başarılı ekran doğrulaması olarak sayılmaz.
- `dart analyze` ilgili ana ekran/test dosyalarında error/warning yok; 17 mevcut deprecation info. Son test genişletmesi Flutter tarafından derlenip çalıştırıldı.
- AVD font1.0, fiziksel ekran/density varsayılanları ve önceki Türkçe tercihleri geri alındı; test APK kaldırıldı. Bu tur POCO ayarları/interneti değiştirilmedi.

## Kanıt ve sınırlar
Yerel kanıt: `C:/Users/malik/Documents/ChatGPT/second_brain_v2/.codex/outputs/` altında `gorunum-final.log`, `gorunum-build-final.log`, `gorunum-analyze.log`, `widget-large-final.log`, `widget-normal-final.log`, `layout-final-20261009/tur-home-final.png`, `tur-cards-final.png`.

Bu tur yerleşim/ölçü kontrolüdür; 25 dilin anadili doğrulaması, her OEM/launcher ve font ailesinin estetik değerlendirmesi değildir. Önceki ezan/GPS testleri davranış değişmediği için tekrar koşulmadı. Malik uzun bekleme testini istemedi; bugünkü doğru saatli ezan/bildirim kullanımını bildirdi. Bu test zorunlu açık iş olarak tutulmaz. Diyanet/ses lisansları ve production signing/mağaza hazırlığı ayrı açık işlerdir.
