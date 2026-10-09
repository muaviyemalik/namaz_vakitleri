# 2026 Diyanet arşiv aktarımı — 4 Ekim 2026

2026'nın eksik günleri üçüncü taraf Diyanet veri arşivinden mevcut asset paketine
aktarıldı. Uygulamanın kaynak seçim davranışı değiştirilmedi; mevcut Diyanet asset
okuyucusu yeni günleri de okur. Bu çalışma otomatik internet güncellemesi değildir.

## Kaynak ve doğrulamanın sınırı

- Arşiv: https://github.com/karademirmustafa/ezanvakti-imsakiyem-api/releases/tag/v1.0.0
- Dosya: `prayer-times.2026.json`; 175.405.183 bayt, 321.200 kayıt, 880 Türkiye/KKTC yerleşimi.
- Arşiv üretim kaydı: 3 Ocak 2026. Verinin kaynak alanı Diyanet İşleri Başkanlığı.
- Yalnız mevcut paketteki 862 Türkiye CityID'si alındı; KKTC ve yeni kimlikler eklenmedi.
- 26.722 örtüşen yerleşim/gün kaydının altı vakti, önceki doğrudan Diyanet HTML
  paketinden gelen vakitlerle birebir eşleşti: **0 fark**.
- Bu örtüşme kontrolü, bütün eksik tarihler için bağımsız birincil kaynak doğrulaması
  değildir. Eksik günler bu oturumda Diyanet sunucusundan alınamadı. Aracı kaynak,
  dosya hash'i ve doğrulama kapsamı `paket.json` içinde açıkça saklanır.
- Hesaplanmış vakit, yıl kopyalama, dakika kaydırma veya ilçeye il merkezi kopyalama yok.
- Arşiv/kaynak veri yeniden dağıtım dayanağı mevcut yayın öncesi izin işinden ayrı
  tamamlanmış sayılmaz. Uygulama mağazaya gönderilmedi.

## Sonuç

| Ölçü | Değer |
| --- | --- |
| İl | 81 |
| Yerleşim | 862 (katalogdaki 3 eski problemli kayıt aynı durumda) |
| Kapsam | 1 Ocak 2026–31 Aralık 2027 |
| Gün / yerleşim | 730, kesintisiz |
| Eklenen satır | 287.908 |
| Değişmeden korunan eski satır | 341.352 |
| Toplam satır | 629.260 |
| Ham il parçaları | 35.277.414 bayt |
| zlib ile il parçaları | 6.348.064 bayt (APK ölçümü değildir) |

Mevcut il/yerleşim adları, kimlik eşlemeleri ve bütün eski satırlar korundu.
81 parçanın satır sayısı, altı vaktin biçimi/sırası, tekil tarihleri ve SHA-256
bütünlükleri bağımsız kontrol edildi. Eski boşluğu bekleyen Flutter regresyonları
yeni kapsamı ve 2025/2028 kapsam dışı davranışını kontrol edecek şekilde güncellendi.

## Yeniden üretim

```sh
python tool/diyanet_2026_arsiv_ekle.py /path/prayer-times.2026.json
flutter test test/diyanet_verisi_test.dart test/diyanet_cevrimdisi_test.dart test/diyanet_bellek_test.dart test/diyanet_kimlik_kayit_test.dart
```

İçe aktarım tüm kaynak/kapsam/örtüşme kontrollerinden sonra yazmaya başlar ve uyuşmazlıkta durur.
İlk 3 Ekim HTML üreticisi (`diyanet_verisi_uret.py`) yeniden çalıştırılırsa arşiv
aktarımı ardından tekrar yapılmalıdır; aksi hâlde eski kısıtlı paket geri üretilir.
Eski kapsam denetçisi ham indirme günlüğünü gerektirir; bu ham dosyalar Git'te yoktur.

Bu Work ortamında Flutter/Dart SDK bulunmadığı için Flutter testleri, APK derlemesi
ve POCO cihaz testi **çalıştırılmadı**. Veri denetimi ve `git diff --check` geçti.
Malik'in Windows çalışma kopyası veya telefon kurulumu bu değişiklikle otomatik güncellenmez.

## Windows yayın adayı doğrulaması — 5 Ekim 2026

İlk tam koşu 522 geçti / 11 atlandı / 6 başarısızdı. Beş hata Windows CRLF satır sonunun eşleme dosyası yoluna karışmasından, bir hata eski 3 Ekim başlangıç beklentisinden geldi. Eşleme ve il-parçası okuyucuları LineSplitter ile düzeltildi; LF/CRLF ve Kasım arşiv okuması regresyonu eklendi. Sonraki tam koşu **530 geçti / 11 canlı test atlandı / 0 başarısız**. Tam analiz: 0 hata, 0 uyarı, 40 info.

İlk POCO kurulumunda ikinci hata bulundu: kayıtlı CityID yeniden yüklenirken parça yolu geri bağlanmıyordu. Parça paket eşlemesinden yeniden bağlanır; kayıtlı ID farklı bir ID ile değiştirilmez. Gerçek yeniden açılışı temsil eden kayıt turu + Kasım verisi okuma regresyonu eklendi; ilgili 16 test geçti. Tam 530 koşusu bu son main.dart düzeltmesinden öncedir; son değişiklik ilgili testlerle doğrulandı.

Telefon bilgisayarın internet kaynağıdır; interneti kapatılmadı. Ağın engellendiği Flutter testleri çevrimdışı veri yolunu doğrular; fiziksel cihaz offline testi bağımsız bağlantı sağlanınca yapılmalıdır. Doze/reboot/ezan/widget uçtan uca testi bu veri adımıyla tamamlanmış sayılmaz. APK mevcut debug anahtarıyla imzalanan release modundadır; Play production signing değildir.

Arşiv kaynağı/hash, sınırlı birincil kaynak örtüşme doğrulaması ve açık yeniden dağıtım izni işi yukarıdaki haliyle korunur.
Son APK: **68.808.302 bayt (65,62 MiB)**; SHA-256 `56f7f937f104e21b00d08f575fb2ad8b36aa55592780f2c8246c86d6e1288fb5`. POCO'ya `adb install -r` başarılı; veriler silinmedi. Ankara mevcut seçim ekranından yeniden seçildiğinde resmî kaynak etiketi ve `diyanet-2026-10-04.1` sürümü görüldü. Ardından force-stop + cold launch sonrası aynı resmî kaynak ve çalışan sayaç korundu. İlk eski kurulum kaydı yeniden seçimden önce hesaplanmış kaynakta kaldı; eski kimlik/il bilgisi olmayan kayıtların otomatik geçişi bu turda tamamlanmadı ve konum adımında ele alınmalı. Mevcut seçimi Ankara bıraktık; internet ayarına dokunulmadı.

Son değişen dört Dart dosyasının analizi: 0 hata / 0 uyarı / 2 mevcut deprecated Color.value info. Yerel kanıtlar: `geri_donus/diyanet_yayin_adayi_20261005/`. Main birleşmedi; bu oturumun okuyucu/konum/test/rapor düzeltmeleri yerel çalışma ağacında, uygulama GitHub dalına gönderilmedi. Yayın adayı veri yolu online POCO + yeniden açılışta doğrulandı; gerçek offline POCO ve veri yeniden dağıtım izni açık kalır.