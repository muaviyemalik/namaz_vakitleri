# Android Studio AVD doğrulaması — 9 Ekim 2026

HEAD: 4c839f7b7104109727a1b1211d3eac5d77bb1efa, fix/diyanet-2026-archive. Medium_Phone / emulator-5554; cihaz ro.build.version.release=17. Bu oturum üretim davranışını değiştirmedi; yalnız androidTest runner genişletildi. Test APK uygulamaya dahil edilmez.

## Doğrulanan teslimler
- Ekran kapalı native exact alarm: hedef UTCms1791564444098, Android bildirim güncellemesi1791564446770 (~2.7s). EzanServisi foreground=true, NamazEzan MediaSession PLAYING; ses oynatma yolu doğrulandı, hoparlör ses kalitesi/insan işitmesi ölçülmedi.
- Gerçek zorlanmış deep Doze: mForceIdle=true, mState=IDLE. Native bildirim alarmı hedef1791564503302, teslim1791564504360 (~1.1s). Sadece bildirim modu; Doze içinde sesli ezan ve plugin erken uyarı teslimi bu tur ölçülmedi.
- Gerçek adb reboot: hedef1791564706121, teslim1791564706864 (~0.7s). Uygulama Activity açılmadan BOOT_COMPLETED ile alarmlar yeniden kuruldu, etiketli after-real-reboot bildirimi geldi. Normal native vakit ve plugin erken uyarı alarm kayıtları geri döndü. Açılışta ilk sorguda boot tamamlanmamıştı; sonraki gerçek teslim esas alındı.
- Beş ezan ve hatırlatıcı olmak üzere altı ses dosyasının Android decode kontrolü PASS.

## UI örneklemesi
- Sistem font_scale=1.8: Türkçe ve İngilizce ana ekran, Arapça RTL ana ekran/zikirmatik/ayarlar/bildirim ayarları. Ekran görüntüleri incelendi; örneklenen görünür alanlarda taşma yok. Ayarlarda aşağı kaydırma ve hedef/reset kontrol erişimi görüldü. Tüm 25 dil/tüm ekran/tüm widget boyut matrisi değildir.
- Bulgu: İngilizce ekranda hesap kaynağı başlığı Resmî Diyanet tablosu Türkçe kalıyor. lib/pages/anasayfa.dart:2029 sabit metin; ekran görüntüsü eng-large-home.png. Küçük çeviri kusuru açık, bu test oturumunda düzeltilmedi.

## Başarısız test / sınırlar
- Eski EzanKontrolRunner 6 decode sonrası FAIL ringer silent; emülatörde AudioManager sessiz moda geçiş koşulu sağlanmadı. Bu testin kalan DND/ses kısma bölümleri bu oturumda PASS sayılmaz; önceki POCO kanıtı ayrı.
- Önce Android Studio Java25 ile test build başarısız; mevcut Flutter Temurin17 ile assembleDebugAndroidTest PASS.
- Uzun saatler/günler süren doğal idle, OEM pil kısıtlaması, gerçek titreşim hissi, iOS ve üretim imzası doğrulanmadı. Diyanet izin/API ve mağaza işleri bu test kapsamında değil.

## Temizlik ve kanıt
- Test ID2147483644 iptal edildi; bildirim ve test APK kaldırıldı. Native settings, locale, kayıtlı sayaç/hedef/şehir önceki XML ile karşılaştırılarak korundu. Font1.0, force-idle=false, battery reset; uygulama Türkçe yeniden açıldı. POCO bağlı değildi ve kullanılmadı.
- Kanıt: C:/Users/malik/Documents/ChatGPT/second_brain_v2/.codex/outputs/avd-20261009/ (hazırlama logları, dumpsys notification/media/service/alarm/broadcast, öncesi-sonrası tercihler ve PNG/XML).
- Yeni androidTest EmulatorKontrol.kt ve runner yönlendirmesi yerelde; commit/push yok.

## Çeviri bulgusu kapatıldı — 9 Ekim
Sabit Türkçe yöntem başlığı kaynak_diyanet.tr() ile mevcut 25 dil çevirisine bağlandı. Kaynak zinciri 7 ve çeviri 10 kontrol PASS; debug APK build/install başarılı. AVD İngilizce kısa başlık Official Diyanet prayer times olarak XML üzerinden doğrulandı; tercihler geri yüklendi. Üretim hesap/plan akışı değişmedi. Commit/push yok.
