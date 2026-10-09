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

## Kalan AVD testleri tamamlandı — 9 Ekim, HEAD e48da78 üzerinde yerel düzeltme
- Derin Doze: mState=IDLE, forceIdle=true iken native ezan ve gerçek plugin erken uyarı aynı wakeup penceresinde kuruldu. Native hedef1791566020912/teslim1791566022172 (~1.3s), plugin hedef aynı/teslim1791566021546 (~0.6s). NamazEzan MediaSession PLAYING; erken_uyari_sicak_v1 kanalında deep-doze-plugin bildirimi var. Plugin, mevcut Flutter üretimi erken uyarı modelinin ID/metin/zamanı değiştirilmiş kopyasıdır; gerçek önbellek değiştirilmez. Bu native taşıma testi, dakika-offset üretimini yeniden test etmez.
- Sessiz/DND matrisi son APK ile 20 PASS: decode6, sistem silent/izin açık çalma/izin kapalı gate, DND kapalı ayarda sesi engelleme ve bildirim teslimi, DND açık+policy erişiminde çalma, ses kısma, sonraki alarm ve ekran geçişi, durdurma sonrası bildirim koruma. Sessiz durumu cmd audio ile kurulur; app API otomatik Zen kuralıyla karışmaz. Bildirim sorgusu sistem listesinden, yayımlanma için en çok5s beklenerek yapılır; her alarmın test kimliği ayrıdır.
- Seri koşular yeni hata gösterdi: stopForeground REMOVE hemen ardından aynı ID ile notify gönderildiğinde Android17 NotificationService Cannot find enqueued record ile sessiz bildirim kaybolabiliyor. DETACH denemesi çözmedi ve final değişiklikte kullanılmaz. EzanServisi final kodu REMOVE sonrası500ms bağımsız main-handler ile normal bildirimi gönderir; audio onDestroy temizliği bu gönderimi iptal etmez. Preview eski kaldırma yolunda kalır. Hata önce2FAIL, final seri20PASS ile doğrulandı; doğrudan adb ses kısma/ekran kapama tekli teslimleri de kanıtlı.
- WidgetKontrol14 PASS + gerçek geçici AppWidgetHost4 PASS: dört sağlayıcı, altı saat, tema/kompakt yerleşim, gün devri/boş gün/kapsam sonu ve Flutter olmadan receiver yenilemesi. Widgetlar launcher üzerine kalıcı eklenmedi.
- Final debug ve androidTest APK build/install PASS; yalnız AVD güncellendi. DND0/ringerNORMAL/forceIdlefalse/battery reset, native settings XML eşitliği doğrulandı. Test alarmları/bildirimleri ve test APK kaldırıldı; uygulama yeniden açıldı. POCO kullanılmadı.
- Son kanıt: C:/Users/malik/Documents/ChatGPT/second_brain_v2/.codex/outputs/avd-final-20261009/; silent-dnd-fixed-final.log20PASS, widget.log14PASS, widget-host.log4PASS, doze-notifications/media, direct-volume ve screen kayıtları, build-fix.log.
- Yeni native bildirim koruma düzeltmesi ve test araçları henüz commit/push değil. Doze/sessiz/DND alarm testleri bu ortamda tamamlandı. Doğal saatler/günler idle, OEM/fiziksel ses-titreşim/iOS ve tüm dil-boyut görsel matrisi ayrı sınırdır.
