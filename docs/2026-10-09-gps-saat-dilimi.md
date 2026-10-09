# GPS saat dilimi düzeltmesi — 9 Ekim 2026

Başlangıç HEAD: db5c053, dal fix/diyanet-2026-archive; sürüm 1.1.0+2.

## Değişiklik
- Dilim önbelleği v2 anahtarı ülke + 4 ondalık koordinat + hesap ayarlarını içerir. Konumsuz eski dilim okunmaz/taşınmaz; mevcut aylık veri ve diğer tercihler silinmez.
- konumAyarla, resmî Türkiye kimliği için Europe/Istanbul seçer. AnaSayfa, daha önce kalıcı kaydedilmiş geçerli ama yanlış dilimi de düzeltir; mevcut seçim/istek yarış korumaları korunur.
- KayanVakitKaynak resmî TR saat dilimini gün seçmeden önce düzeltir. Headless alarm/widget tüketicileri dönen kanonik konumu kullanır.

## Kontroller
- 18 PASS: konuma_ozel_dilim (2), diyanet_kimlik_kayit (16).
- 25 PASS: kaynak_zinciri, plan_yenileme, saat_dilimi_kesinlesmesi, gecikmis_cevap_saat_dilimi. Toplam 43 benzersiz hedefli test. İlk yeni cache fixture'ında altı saat yerine yalnız Asr verilmesi test hatası yarattı; fixture düzeltildi, son koşular geçti.
- Değişen ana kod ve yeni cache testi analizinde 0 hata/uyarı; main'de 2 mevcut deprecated info. Diğer hedefli analizde yalnız mevcut info. Whitespace geçti. Tam paket tekrarlanmadı.
- Debug APK derlendi ve yalnız emulator-5554 / Medium_Phone Android 16 x86_64 üzerine install-r ile kuruldu. SHA256 AAAF05AF533B3D6CF676387120C1CAEA8B0603339D8A71C3EADEC0DA2889D741.

## Sanal telefon
- Çin/Shanghai aktif kayıt + eski ortak Asia/Shanghai cache + konuma özel Çin cache hazırlandı. Uygulama gerçek Çin hesaplanmış/cache ekranını gösterdi.
- Android test GPS sağlayıcısına Ankara 39.9334,32.8597 verildi ve gerçek Konumumu Bul düğmesine basıldı. Kalıcı kayıt Ankara|TR|39.9334|32.8597|Europe/Istanbul|Ankara|9206; resmî ekran/tarih/sayaç doğru.
- Widget timeline Europe/Istanbul; sekiz gün. 31 native vakit alarmının tamamı timeline'daki kanonik UTC anıyla eşleşti; Çin alarmı kalmadı.
- Kalıcı Ankara kaydına tekrar Asia/Shanghai enjekte edildi, uygulama kapatılıp açıldı. Europe/Istanbul otomatik kalıcı düzeldi. 31 erken uyarının tamamı doğru vakitten 30dk önce / Europe/Istanbul: örneğin 19:44 yatsı → 19:14. 31 native vakit alarmı da doğru UTC.
- Ekran sayaçları 00:39:10 → 00:37:55; yatsı 19:44, cihaz UTC saatinden hesaplanan İstanbul anıyla uyumlu. Gerçek sesli teslim bu testin kapsamı değildir.
- AVD 16KB uyumluluk diyaloğu ve grafik/arayüz beklemeleri test sırasında giderildi; soğuk açılış SwiftShader/2 çekirdek/2048 MB ile sürdürüldü. Bu bir production 16KB uyumluluk onayı değildir.
- Başlangıç emulator SharedPreferences yedeği korundu; önceki kayıtlardan eksik dört giriş son dosyaya geri birleştirildi. Fiziksel POCO'ya dokunulmadı.

Kanıt: C:/Users/malik/Documents/ChatGPT/second_brain_v2/.codex/outputs/gps-20261009/ (PNG, UI XML, önce/sonra tercihler, alarm ve widget kayıtları); hedefli test logları TEMP/namaz-gps-tests.txt ve namaz-gps-regression.txt.

Düzeltmeler Malik talimatıyla 9 Ekim mevcut dalda açıklamalı Git checkpoint kapsamına alındı; main birleşmesi yok. Sonraki yayın kontrolleri fiziksel POCO, Doze/reboot ve diğer önceden açık sınırlardır.
