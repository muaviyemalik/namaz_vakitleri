# Namaz Vakitleri — mimari haritası

Bu dosya katman ve dosya ilişkilerini gösterir. Dal/sürüm/test durumu AI_HANDOFF'tadır.
Harita yerel kaynak-zinciri değişikliklerini de kapsar; yalnız HEAD içeriği değildir.

## Başlangıç ve ayarlar

- `lib/pages/ilk_kurulum_sayfasi.dart`: başlangıç kapısı ve üç adımlı şehir →
  uyarı tercihi → açıklamalı izin kurulumu. AnaMenu kurulum tamamlanmadan kurulmaz.
- `lib/core/ilk_kurulum.dart`: eski kullanıcı göçü, manuel/GPS şehir seçimi,
  izin durumları ve tamamlanma kaydı. Yeni kullanıcıya varsayılan şehir atanmaz;
  seçim bitene kadar konum taslağı bellektedir, alarm planı başlatılmaz.
  Tercihler şehirden önce kaydedilir; tamamlanma kaydı en son yazılır.
- `lib/core/ilk_acilis_izinleri.dart`: kurulum ve AnaSayfa'da bildirim → tam alarm
  → konum istemlerini sıraya koyar; SharedPreferences adım kayıtları ret halinde
  de tekrar istemeyi önler. Konum servisini açma yönlendirmesi yalnız kullanıcının
  otomatik konum eyleminde yapılır; seçili şehir ilk izin isteminde değiştirilmez.
- `lib/main.dart`: Flutter/yerelleştirme/saat dilimi/bildirim başlangıcı, uygulama
  ve menü, ortak ValueNotifier'lar, SharedPreferences yükleme/kaydetme işlevleri.
  `aktifVakitDurumu` son doğrulanmış kanonik kaynağı Ayarlar’a da taşır; resmî
  kaynakta yüksek enlem kontrolü kapalı, hesaplanmışta ayrı tercihtir.
- `lib/pages/ayarlar_sayfasi.dart`: ülke/dil/tema, resmî Diyanet tercihi,
  hesaplama yöntemi, Asr/yüksek enlem ve Bildirim Ayarları alt ekranına giriş.
- `lib/pages/bildirim_ayarlari_sayfasi.dart`: vakit başına ezan/bildirim/kapalı,
  sessiz/DND, ortak 0/15/30/45/60 dakika hatırlatma, ses önizleme ve sistem izinleri.
- `lib/core/bildirim_ayarlari.dart`: kalıcı bildirim tercihleri; native katmana
  çalma anında okunacak kopyayı yazar. Sessizde açık, DND kapalı varsayılan.
- `lib/core/ezan_platformu.dart`: MethodChannel köprüsü; vakit hesaplamaz.
- `lib/data/hesaplama_yontemleri.dart` yöntem kataloğudur. Otomatik seçimde
  Aladhan'a method gönderilmez; Aladhan method=13 tek başına resmî tablo değildir.
- `assets/i18n/diller.json`, `lib/data/dil_katalogu.dart` ve
  `lib/widgets/dil_secici.dart` dil kataloğunu/seçimini sağlar.
- Widget ve launcher etiketi uygulama açılmadan önce göründüğü için Android
  tarafında ikinci bir çeviri katmanı vardır: `res/values/strings.xml` (Türkçe
  varsayılan) + 25 `res/values-<xx>/strings.xml`. Bu kaynaklar
  `assets/i18n/ceviri/<dil>.json` ile eşleme tablosundan üretilir ve
  `test/ceviriler_test.dart` eşitliğini denetler; iki katman ayrı değişirse
  widget metni ile uygulama metni ayrışır.
- Veri modelleri (`HesaplamaYontemi`, `AsrYontemi`, `YuksekEnlemAyaru`) hem
  Türkçe kaynak `ad` hem `ceviriAnahtari` taşır. Arayüz `ceviriAdi` getter'ını
  kullanır; çeviri çözülemezse Türkçe `ad` döner, ham anahtar adı gösterilmez.
  `assets/i18n/ceviri/` üç harfli kod kullanır; `lib/utils/iso1_yerellestirme.dart`
  Flutter delegelerine iki harfli kod köprüsüdür. İçerik için ayrı köprü
  `lib/utils/icerik_dili.dart`; üç harfli UI kodunu içerik anahtarı olarak kullanma.

## Konum / yerleşim / saat

- `lib/data/ulke_verisi.dart` ve `assets/veri/ulkeler.json`,
  `assets/veri/sehirler/`: ülke ve ülke bazında tembel yüklenen şehir/yerleşim verisi.
- `lib/widgets/ulke_secici.dart`, `lib/widgets/sehir_secici.dart`: seçiciler;
  aynı adlı yerleşimlerde il ve koordinat ayrımı önemlidir.
- `lib/pages/anasayfa.dart`: süre sınırlı GPS ve isteğe bağlı geocoder; geç sonuç sürüm/mounted kontrolü.
- `lib/core/diyanet_konum.dart`: yerel koordinat + doğrulanmış Diyanet eşlemesi, güvenli ilçe/il merkezi ve eski kayıt çözümlemesi.
- `lib/main.dart`: seçim sürümü, konumKaydet/konumYukle,
  diyanetKimligiCoz ve konumSaatDilimiKesinlestir. CityID ve il parçası yeniden
  yüklemede birlikte bağlanır; kimlik başka yerleşimin ID'siyle değiştirilmez.
- `lib/core/saat.dart`: Saat/GercekSaat/SabitSaat, Konum ve SehirSaati;
  yüksek enlem `latitudeAdjustmentMethod` 1/2/3 ve yeni v2 tercih/cache kodları.
  seçili şehrin IANA diliminde gün/duvar saati, sayaç ve cache anahtarlarının temeli.
  Şehrin gününü cihazın günüyle eşitleme; saat dilimi çözülemezse sessizce tahmin etme.

## Vakit kaynakları ve cache

Akış: konum/tercihler → `lib/pages/anasayfa.dart` kaynak seçimi → VakitDurumu
→ ekran + geri sayım + bildirim planı + widget için doğrulanmış günlük timeline.

- Türkiye'de resmî tercih açık: gömülü Diyanet → aynı CityID güncel resmî Diyanet
  → doğrulanmış hesaplanmış Aladhan ağ/cache. Güvenilir gün yoksa saat gösterilmez.
  Türkiye dışı veya resmî tercih kapalıysa hesaplanmış akış kullanılır.
- `lib/core/aladhan_cevap.dart`: aylık API cevabı, gerçek tarih/altı vakit/metadata
  doğrulaması; VakitGunu ve geçerli/reddedilmiş cevap modelleri.
- `lib/core/vakit_verisi.dart`: VakitDepo, VakitDurumu, VakitKaynagi;
  doğrulanmış aylık Aladhan cache'i SharedPreferences'tadır. Anahtar koordinat,
  yöntem, Asr/yüksek enlem ve yıl/ayı kapsar. Bozuk kayıt karantinaya alınır;
  hatalı cevap sağlam kaydı ezmez. Cache önce gösterilir, ardından ağ denenir.
- `lib/core/diyanet_verisi.dart`: DiyanetDepo paket/kimlik/parça okuyucusu.
  `assets/veri/diyanet/paket.json` kaynak, kapsam, hash ve doğrulama sınırıdır;
  `esleme.txt` il/ad → CityID/parça; `TR/*.txt` il bazında gerçek günlük vakitler.
  Açılışta yalnız paket metadata'sı, ihtiyaçta eşleme ve seçilen il yüklenir;
  bellekte en çok iki il parçası. Asset verisi Aladhan cache'ine yazılmaz.
- `lib/core/diyanet_guncel.dart`: DiyanetGuncelDepo aynı HTTPS host/CityID tablosunu
  doğrular (canonical/ilceId, gerçek tarih, altı saat, çelişen tekrar).
  8 saniye/2 MB sınırı ve en çok iki yönlendirme. Ayrı
  `diyanet_resmi_web_v1_` cache'i en çok dört yerleşim tutar: bir saatte tazeleme,
  ağ yoksa en çok yedi günlük kayıt, istenen gerçek tarih zorunlu.
- `anasayfa.dart` geç cevapları seçim jetonu/mounted/tarih ile eler; resmî fallback
  durumunda açık/resumed ekranda beş dakikalık kontrollü yeniden deneme yapar.
  Resmî gelecek günlerle hesaplanmış aylık veriyi karıştırmaz.

## Sayaç, bildirim ve ezan

- `anasayfa.dart`: sayaciBaslat saniyelik Timer'ı yönetir; hedef vakit seçili
  şehir saatinden gelir. Gün devri/resumed akışı kaynak ve planı günceller.
- Zikirmatik aynı sayfada ayrı sayaçtır: kayitli_zikir/kayitli_hedef tercihleri,
  ses düğmesi aboneliği ve hedef titreşimi; vakit geri sayımıyla karıştırma.
- `lib/core/bildirim_motoru.dart`: BildirimPlanlayici saf plan üretir;
  BildirimMotoru platforma zonedSchedule ile uygular. PlanSirasi, seçim numarası
  ve kalıcı kimlik dizini eski seçimlerin alarmı ezmesini engeller.
- Vakit/erken uyarı/güneş doğuşu ayrı kanallardır; izin ve gerçek planlama sonucu
  dikkate alınır. `lib/utils/erken_uyari_zamani.dart` erken uyarı zamanını sağlar.
- Android vakit türü artık `EzanAlarmlari.kt` içindeki AlarmManager/receiver'a
  aynı kimlik ve UTC anıyla taşınır. Eski plugin alarmı yalnız o ID için iptal edilir;
  motorun sahiplik/yazma sırası korunur. Hatırlatma ve güneş plugin'de kalır.
- `EzanServisi.kt`: mediaPlayback foreground servis, alarm ses kanalı, tek çalma,
  ses kısma için MediaSession/VolumeProvider, screen on/off ve bildirimde durdurma.
  Bitişte vakit bildirimi sessiz olarak kalır; sonraki vakit etkilenmez.
  Boot receiver yalnız ileri alarmları geri kurar; boot anında ezan başlatmaz.
  İki dakikadan fazla gecikmiş teslimde geç ezan çalmaz, vakit bildirimi kalır.
- Native raw beş makam + özgün hatırlatma; `assets/audio_sources.json` kaynak/hash
  ve doğrulanmamış dağıtım lisansını kaydeder. Test runner androidTest'tedir,
  normal APK'ya dahil edilmez. iOS için bu native ezan davranışı uygulanmadı.
- Başlangıç ve platform yapılandırması: `main.dart`,
  `android/app/src/main/AndroidManifest.xml` ve Android kaynakları.
  Birim testinin geçmesi fiziksel ezan teslimi/Doze/reboot desteği kanıtı değildir.

## Android widget ve diğer ekranlar

- `anasayfa.dart` kaynak/şehir/dil/tema değişiminde `lib/utils/widget_paketi.dart`
  ile tek JSON snapshot yayımlar. Tema doğrudan aktif Material ColorScheme'den
  gelir; açık/koyu mod ve iki modun seçilmiş renkleri widget'a da yansır.
- Günlük snapshot bugün + doğrulanmış en çok yedi ileri günün altı vakti,
  seçili şehir/UTC anı/gün başlangıcı-bitişi/kaynak ve günlük ayet/hadis içeriklerini
  taşır. Şehir gün sınırı DST'de 23/25 saat olabilir; 24 saat eklenmez.
- Native `WidgetMotoru.kt` bir SharedPreferences commit'i ile timeline'ı saklar;
  ağ/Flutter engine/ikinci namaz hesaplaması yok. `TemaliWidget` dört sağlayıcıyı
  yönetir: VakitWidget, GunlukVakitWidget, AyetWidget, HadisWidget.
- Büyük kart altı vakit + sıradaki vakit vurgusu + native Chronometer geri sayımı;
  küçük kart sıradaki vakit + sayaç; içerik kartlarında ayrı atıf satırı.
  Yuvarlatılmış kartlar aktif paletle çizilir, uygulamaya dokunarak açılır.
- `WidgetGuncelleReceiver`: sıradaki vakit/gece yarısı RTC alarmı, boot/update/
  saat/timezone değişimi. Widget silinince artık gerekmeyen alarm temizlenir.
  Yalnız gerçek widget varken sınır alarmı kurulur; telefon uyurken ekran için
  gereksiz wakeup yok. Sistem 30 dakikalık güncellemesi ek güvencedir.
- Exact izin yoksa canlı sayaç yerine hedef saat ve izin/güncelleme açıklaması;
  snapshot tarih kapsamı yoksa eski saat/sayaç gizlenir ve uygulamayı açma metni.
  Kapsamı kendi kendine uzatan arka plan ağ yenilemesi yok; en çok sekiz gün.
- Ayet/hadis günlük indeksleri widget ve uygulamada aynı seçili şehir takviminde.
  Android yerleşimleri `res/layout/widget_*.xml`, sağlayıcı metadata'sı `res/xml/`.
  25 native dilde yeni günlük başlık mevcut today_times çevirisine eşlenir.
- `lib/pages/kible_sayfasi.dart` → `lib/utils/kible_hesapla.dart` + pusula;
  `lib/pages/ozelGunler_sayfasi.dart` → `lib/data/ozel_gunler.dart`.
  Ayet/hadis havuzu `lib/data/veri_havuzu.dart`; atıflar NOTICE ve lisans ekranında.
- `third_party/perfect_volume_control/` Android derleme uyumu için yerel override;
  dependency override'ını gerekçesiz kaldırma.

## Göreve göre hedefli doğrulama

- Kaynak/cache: `test/kaynak_zinciri_test.dart`, `test/diyanet_guncel_test.dart`,
  `test/diyanet_*_test.dart`, `test/cevrimdisi_acilis_test.dart`, Aladhan testleri.
- Konum/zaman: `test/diyanet_kimlik_kayit_test.dart`, saat dilimi testleri,
  `test/gun_devri_test.dart`, `test/ay_sonu_imsak_test.dart`, şehir kapsam testleri.
- Plan: `test/bildirim_*_test.dart`, `test/gun_devri_bildirim_test.dart`,
  erken uyarı testleri. Widget girdisi: `test/sayac_widget_test.dart`.
- Çeviri/içerik: `test/ceviriler_test.dart`, `test/icerik_dili_test.dart`.
- `tool/` veri üretim/denetim araçlarıdır; sıradan oturum başlangıcında çalıştırılmaz.
  `geri_donus/` geçmiş yerel kanıttır, uygulama katmanı değildir.
