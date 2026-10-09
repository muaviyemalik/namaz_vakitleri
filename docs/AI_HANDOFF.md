# AI devir — güncel çalışma belleği
Son güncelleme: 9 Ekim 2026. Asıl mimari ARCHITECTURE.md; ayrıntı görev raporlarında.
- Son çeviri/AVD test araçları önce doğrulandı; kullanıcı talimatıyla fix/diyanet-2026-archive → main birleştirme kapsamındadır. Tarihsel commit/push yok kayıtları önceki oturumlara aittir.
## 9 Ekim AVD arka plan/UI doğrulaması
- HEAD4c839f7, Medium_Phone Android17: ekran kapalı ezan PLAYING/FGS; deep Doze bildirim; gerçek reboot sonrası Activity açmadan alarm teslimi PASS.
- Altı ses decode PASS. Eski runner ringer silent FAIL; sonraki DND/ses kısma koşulları bu tur doğrulanmadı.
- Font180% Türkçe/İngilizce ana ekran ve Arapça RTL zikir/ayar/bildirim ayarlarında görünür taşma yok; tüm dil/ekran matrisi değil. İngilizce sabit Türkçe başlık kaynak_diyanet çevirisine bağlandı; 7 kaynak+10 çeviri PASS, yeni APK AVD EN başlığı doğrulandı.
- Tercihler/şehir/sayaç/ezan ayarları korundu, font1.0/idle normal, test APK kaldırıldı; POCO kullanılmadı.
- Yalnız androidTest runner genişletildi; commit/push yok. Doze sesli ezan/plugin erken uyarı teslimi ve doğal uzun idle/OEM/iOS açık. Kanıt docs/2026-10-09-avd-arka-plan.md.
## 9 Ekim zikirmatik hedef düzeltmesi
- Hedef menüsünde {sayi} namedArgs ile doldurulur; altı sayı ve seçili hedef çevrilir.
- Dokunma/ses düğmesi aynı artış yolunda; yalnız açık panelde sayar ve panel anında güncellenir.
- Hedef geçişinde bir haptic + sessiz bildirim; devam sayımı tekrarlamaz, sıfırlama yeniden hazırlar. İzin ret sayacı engellemez.
- 25 dilde tamamlanma metinleri, dört widget regresyonu + 10 çeviri kontrolü. AVD altı hedef, 32→33 bildirim/haptic, 34 tekrar yok doğrulandı.
- Debug AVD güncellendi; önceki tercihler geri yüklendi. POCO kullanılmadı; 9 Ekim kullanıcı talimatıyla düzenleme fix/diyanet-2026-archive dalında commit/push kapsamındadır.
## 8 Ekim telefonda temiz kurulum — son doğrulama
- Aynı kaynak, haricî Gradle init/manifest ile ayrı kurulumtest paketinde debug
  derlendi. Ana uygulama/verileri korunarak POCO Android 15'te fiziksel test yapıldı.
- Şehir zorunluluğu, GPS izni ret → elle İstanbul, üç izin ret → vakit/sayaç,
  yeniden açılışta tekrar istememe; GPS kabul → Ankara, bildirim/exact kabul →
  doğru izin özeti ve yeniden açılış geçti. Ses için uyarı modu kapalı seçildi.
- Konum kapalı ilk kurulum diyaloğu/iptali geçti; global location_mode 3'e geri
  alındı. Test paketi kaldırıldı. Ezan/önizleme tetiklenmedi, internet/ses korunur.
- İlk kurulum hata metinleri olmayan kayıtlı şehirden söz ediyordu: ayrı 3 metin
  eklendi. UlkeVerisi tur/tr kodlarını birlikte tanır; Türkçe ülke/bölge düzeldi.
  İki regresyonla kurulum/çeviri 22 PASS; 3 dosya analizinde hiç sorun yok.
- Release/ana install-r başarılı; Ankara/sayaç korundu. Kanıt Codex2026-10-08 outputs/temiz-kurulum/rapor.md ve ekranlar; commit/push yok.
## 8 Ekim üç adımlı ilk kurulum — son durum
- Yeni kurulum şehir/GPS seçimi → ezan/bildirim/kapalı → açıklamalı izin ve
  durum özeti akışından geçer. Şehir/mod seçilmeden ilerlenmez, ret engel değildir.
  Eksik izin satırı sistem ayarlarına gider. Sessizde ezan yeni kurulumda kapalı;
  DND, erken uyarı ve güneş doğumu kapalı. Ayrıntılar sonradan ayarlanabilir.
- Ankara fallback kaldırıldı. AnaMenu/sensör/alarm akışı kurulum tamamlanınca açılır.
  Kayıtlı şehirli eski kullanıcılar atlanır; şehir/bildirim tercihleri korunur.
  Başlandı/bitti kayıtları kesintiyi göçten ayırır; kaydetme hatası ekranı kapatmaz.
- İlk kurulum metinleri Türkçe/İngilizce; diğer 23 çeviri dosyasında İngilizce
  karşılıklar kullanılır. Mevcut metinler korundu, yeni anahtarlar zorunlu testte.
- 8 hedefli dosyada 59 PASS: yeni kurulum 10, önceki izin 4 ve kaynak/bildirim/
  kimlik/yüksek enlem/çeviri kontrolleri. 360x640 %180 yazı taşma regresyonu geçti.
  Dört dosya analiz: 0 hata/uyarı, main.dart'ta 2 mevcut info.
- Kanıt: Codex 2026-10-08 outputs/ilk-kurulum-raporu.md. Temiz kurulumun gerçek
  Android izin kabul/ret matrisi bu turda denenmedi; cihaz verileri silinmez.
- Release POCO install -r başarılı; mevcut Ankara/sayaç korundu ve eski kullanıcı
  kuruluma zorlanmadı. Ses/internet korunur; uygulama commit/push/merge yok.
## 8 Ekim ilk açılış izinleri
- Kalıcı sıralı istem/kesintiden devam ve GPS Ayarlar dönüşü önceki turda eklendi.
  19 PASS, önceki analiz 0 hata/uyarı/17 info. Ayrıntı Codex2026-10-08
  outputs/ilk-acilis-izinleri-raporu.md. Güncel akış yukarıdaki üç adımlı kurulumdur.
## 8 Ekim cihaz arayüz kontrolü — son durum
- Malik cihaz arayüz testini onayladı; derste olduğu için ses/önizleme tetiklenmedi.
- Ana kaynak şeridinde `{surum}/{tarih}` namedArgs ile düzeldi; aralık tarihleri
  saat bileşeni olmadan gösterilir. Resmî web edinme metni de namedArgs kullanır.
- Ayarlar'daki hesaplanmış kaynak fark notu, kanonik resmî tabloda gizlenir;
  hesaplanmış kaynağa geçişte görünür. Kaynak önceliği/tercihler değişmedi.
- kaynak_zinciri/yuksek_enlem/bildirim_ayarlari_ui: 12 PASS. Üç Dart dosyası
  analiz: 0 hata/uyarı, 19 mevcut info. Whitespace temiz.
- Son release 103.959.099 bayt; SHA256
  49b4cf47b64644742b6d10894148262d60027ed6230e05e20c836bce154650f7.
  POCO install -r başarılı: veri silinmedi, önceki sayaç/bildirim düzeltmeleri de kuruldu.
- Yeni sürümde gerçek kaynak metni, ilerleyen sayaç ve bugünün vakitleri görüldü.
  Açık tema normal/%130 font: ayet/hadis, altı vakit, ayarlar, özel günler ve
  zikirmatik paneli incelendi; görünür taşma yok. Zikir 32/hedef1000 korundu.
- Bildirim Ayarları ve kıble çizimi de görüldü; ses oynatılmadı, fiziksel yön doğruluğu
  ölçülmedi. Font ölçeği 1.0'a geri alındı; şehir/dil/ezan ayarı/internet korundu.
- Telefonun alarm listesinde bugün ikindi 15:54 ve erken uyarı 15:39 kayıtları var;
  teslim/Doze/reboot testi yapılmış sayılmaz. Widget boyut matrisi/landscape/dil
  matrisi bu UI turunda yeniden koşulmadı. Uygulama commit/push/merge yok.
- Kanıt: Codex 2026-10-08 outputs/arayuz-kontrolu/; önceki bölümlerdeki
  "yeni APK kurulmadı" ifadeleri bu son kurulumdan önceki turların durumudur.
## 8 Ekim gömülü sayaç düzeltmesi
- Bildirim devam kontrolü: dilim eksikliği `_alarmlariKur` erken çıkışına da
  yol açıyordu. İlk düzeltme bunu giderir. Ayrı hata: Diyanet ileri günleri bugünü
  içermediğinden plan yalnız yarından başlıyordu. `_alarmlariKur` bugün + ileri
  günleri tarih bazında tekilleştirir; bugünün kalan alarmları artık kurulur.
- Gerçek AnaSayfa→motor→sahte platform regresyonları (boş/bozuk/gece yarısı/geçerli
  dilim) ilk alarmın bugün doğru UTC'de, kayıtların ileri zamanda ve kalıcı dizinde
  olmasını ölçer. Bildirim/kaynak/yarış/yenileme/ezan/gün devri/hata kapsamı 56 PASS.
- Cihazda yalnız dumpsys alarm okundu: ezan/erken uyarı/widget sınır kayıtları var.
  Ses/ayar/internet değişmedi, receiver tetiklenmedi, yeni APK kurulmadı.
  Bu kayıtlar kurulu eski sürüme aittir; yeni düzeltmenin cihaz teslim kanıtı değildir.
- `_resmiDiyanetYukle` boş/geçersiz konum dilimini mevcut yarış korumalı
  `_saatDiliminiIsle` ile Europe/Istanbul olarak kesinleştirir. Geçerli dilim korunur;
  tahmini gün farklıysa sorgu tarihi ve `_denenenTarih` birlikte düzelir.
- Canlı yol bu adımı zaten yapıyordu; gömülü yol atladığı için tablo görünürken
  sayaç duruyor, widget gün listesi boş kalıyordu. Kaynak/veri saatleri değişmedi.
- Aynı HEAD ve geniş önceki diff üzerinde hedefli 37 PASS; boş/bozuk/gece yarısı
  kapsamı eklenince kaynak zinciri 5 PASS (toplam 39 benzersiz test).
- İki değişen Dart dosyası analiz: 0 hata/uyarı, 17 mevcut info. Whitespace temiz.
- POCO bağlı; mevcut release run-as okumayı reddediyor. Yeni APK kurulmadı;
  düzeltmenin fiziksel cihazda doğrulaması bekliyor. İnternet/cihaz tercihleri korundu.
- Bu turun uygulama değişiklikleri: anasayfa.dart (+9 satır), kaynak_zinciri_test.dart
  (3 regresyon ve test timezone başlangıcı), bu handoff. Commit/push/merge yok.
## Çalışma durumu
- Aktif kopya C:/Users/malik/Desktop/namaz_vakitleri_kod; Documents kopyası geride.
- Repo muaviyemalik/namaz_vakitleri, dal fix/diyanet-2026-archive.
- Checkpoint öncesi HEAD 0f05a9b17531f05c13e382acd736f041860a1328; sürüm 1.1.0+2. Güncel commit için git rev-parse HEAD kullan.
- 9 Ekim checkpoint: mevcut kaynak/asset/test/belgeler bu dalda commit ve push kapsamındadır; main birleşmesi yok. Yerel geri_donus kanıtları yükleme dışıdır.
- 81 il/862 veri bulunan CityID/865 katalog, 2026–2027 kesintisiz 730 gün.
- Kaynak/cache/tarih/saat dilimi/PlanSirasi yarış guard'ları korunur.
- VakitDurumu ekran/sayaç/bildirim/widget için tek kaynak; vakit uydurulmaz.
- POCO C65 Android 15 NJKBA6CIOZXOLVDY internetini KAPATMA; PC onu kullanıyor.
## 7 Ekim ezan ve bildirim ayarları
- Malik beş MP3 eklemesini onayladı: Sabah Sabâ/Öğle Uşşak/İkindi Hicaz/
  Akşam Segâh/Yatsı Rast. Güneş ezan değildir.
- Sessiz mod varsayılan açık; DND varsayılan kapalı ve ayrı ayar/sistem izni.
- Ses kısma veya ekran/güç geçişi yalnız mevcut ezanı bitirir; bildirim kalır.
- Ayarlar → Bildirim Ayarları: beş vakit ezan/bildirim/kapalı, sessiz/DND,
  tek ortak erken uyarı 0/15/30/45/60, güneş ve sistem izinleri.
- Kullanıcı hatırlatma sesi 3/Sıcak yükseliş seçti; özgün sinüs sentezi.
- Kanonik plan Android AlarmManager → EzanAlarmReceiver → EzanServisi.
  Eski plugin vakit ID iptal; güneş/hatırlatma plugin'de. Exact reddi fallback korunur.
- Native kayıtlar boot/update/time change'de yalnız ileri zamanlara kurulur.
  120s'den fazla gecikmiş teslimde bildirim var, geç ezan yok. Max ses 6 dakika.
- Foreground mediaPlayback/audio focus/wake lock/MediaSession temizliği var.
  Android 15 focus FGS yayılımı için 250ms sonra alınır; durdurma bekleyen sesi de iptal eder.
- Menüden çıkma yalnız önizlemeyi durdurur, gerçek vakit sesine dokunmaz.
- Yeni 21 anahtar bütün 25 dile ve durdurma etiketi native kaynaklara eklendi.
- assets/audio_sources.json/NOTICE kaynak hash ve lisans sınırını kaydeder:
  beş kaydın dağıtım lisansı doğrulanmadı, telifsiz diye nitelendirme.
- Ayrıntı docs/2026-10-07-ezan-bildirim.md; native runner yalnız androidTest içinde.
## Doğrulama
- Ezan hedefli ilk 86 + UI 2; transport son düzeltmesi ardından ilgili 35 PASS.
- dart analyze lib test: 0 hata/0 uyarı/45 info (önceki baseline).
- POCO 18 cihaz kontrolü geçti: decode6, sessiz çalma/kapalı gate, ses kısma,
  DND sessiz teslim, bildirim kalma, sonraki alarm, ekran geçişi susturma.
- Kanıt geri_donus/ezan-poco-tests.log. Test paketi cihazdan kaldırıldı.
- Son release 104.492.931 bayt (99,7 MiB) derlendi ve install -r başarılı. Gerçek Bildirim Ayarları menüsünde beş makam/sessiz açık/DND kapalı/tek ortak 15dk mevcut tercih görüldü.
- Tam paket yeniden koşulmadı; geçmiş 536/11skip ezan öncesi baseline'dır.
- 5 Ekim çeviri 198/4skip, GPS33, yüksek enlem54 +son6 +Asr UI4 geçmiş kanıt.
## 7 Ekim widget tasarımı ve güncellemesi
- Malik mevcut app temasına uyumlu yeni geniş widget + üç eski widget yenilemesini onayladı.
- Yeni GunlukVakitWidget: altı saat, sıradaki vakit vurgusu, native geri sayım, şehir/tarih/kaynak.
- Vakit/Ayet/Hadis aynı component adlarını korur; tema ColorScheme, açık/koyu ve seçili renklerden.
- Tek atomik JSON timeline bugün + doğrulanmış yedi ileri gün; native seçili şehir UTC/gün sınırları.
- Vakit/gece yarısı RTC sınır alarmı, boot/update/time değişimi, 30dk sistem güncellemesi.
- Kapsam bittiğinde veya gün boşsa eski saat/sayaç gösterilmez. Exact yoksa hedef saat/açıklama.
- Aynı şehir takviminde uygulama/widget ayet-hadis seçimi; ayrı kaynak satırları.
- İlk ilgili 45/son packet-çeviri 15/son içerik-packet 20 Flutter PASS; analiz 0 hata/uyarı/45 info.
- POCO 14 render/timeline + gerçek AppWidgetHost 4 PASS; açık modda native renk değişimi doğrulandı,
  eski koyu mod geri yüklendi. Geçici host/ID kaldırıldı; launcher yerleşimi değiştirilmedi.
- Ayrıntı docs/2026-10-07-widget.md, geri_donus/widget-*.log/PNG. Final release 103.926.331 bayt POCO'ya install -r ile kuruldu; test APK kaldırıldı.
- Widget Android kapsamı; ilk sekiz günlük snapshot aşağıdaki otomatik kayan planla yenilenir.
- Derin Doze/reboot/büyük font/OEM boyut matrisi açık. Sonraki adım uzun süreli cihaz/E2E ve UI kontrolü.
## 7 Ekim ekran kapalıyken otomatik plan yenileme
- lib/core/plan_yenileme.dart: KayanVakitKaynak 30 günlük pencere; yeni hesaplayıcı yok,
  mevcut kaynak zinciri (gömülü resmî Diyanet → aynı CityID resmî HTTPS → Aladhan
  ağ/önbellek) kullanılır. Eksik/ara gün asla başka günün vaktiyle doldurulmaz.
- arkaPlanYenile() başsız Flutter girişi: Activity/runApp/GPS/izin UI yok. Seçili dil,
  tema, ayar ve erken uyarı native bağlamdan gelir.
- android PlanYenileme.kt: WorkManager 6 saatlik tek periyodik + tek seferlik NOW iş;
  FlutterEngine main thread'de açılır, tamamlanma/preempt/timeout'ta yok edilir.
- foreground() lease ile UI planı arka plan yazıcısını dışlar; şehir/yöntem/bildirim
  değişimi bağlamı ve lastSuccess'i sıfırlar, tekrar eden iş oluşmaz.
- Doğrulama: yerel test/plan_yenileme_test.dart 7 PASS. POCO PlanKontrol 16 PASS:
  kısa 8 günlük snapshot 30 güne uzadı, tema/dil/bağlam korundu, 145+ gerçek native
  ezan alarmı yalnız ileri zamanlarda, son gün alarmı widget UTC'siyle birebir aynı,
  tek periyodik iş, geçersiz saat dilimi reddedildi ve mevcut alarmlar silinmedi.
- Release 103.959.099 bayt (99,1 MiB) derlendi ve POCO'ya kuruldu; test APK kaldırıldı.
- Yenileme yolu ekran kapalıyken gerçek WorkManager + headless Dart ile çalıştı. Elle
  `cmd jobscheduler run` denemeleri cihazın "Restricted due to: thermal" (Thermal
  Status 2) kısıtı nedeniyle başlatılmadı; bu cihaz kararı, kod kusuru değil.
- Zorla durdur (force-stop) işleri de temizler; kullanıcı bilgilendirildi. Commit/push yok.
## 9 Ekim GPS saat dilimi — düzeltildi, AVD doğrulandı
- GPS düzeltmesi 9 Ekim Git checkpoint kapsamında; dal fix/diyanet-2026-archive. Güncel HEAD için git rev-parse HEAD kullan; önceki checkpoint db5c053.
- v2 dilim anahtarı ülke/koordinat/hesap; eski ortak dilim taşınmaz, aylık cache korunur.
- Resmî TR seçim/ekran/kayan plan Europe/Istanbul; headless tüketiciler kanonik dönen konumu kullanır.
- 43 hedefli PASS; analiz 0 hata/uyarı, main'de 2 mevcut info. Debug APK emulator-5554'e kuruldu.
- Çin→gerçek GPS Ankara ve kalıcı yanlış Ankara dilimi→yeniden açılış geçti. Widget İstanbul;
  31 native alarm ve 31 erken uyarı kanonik UTC/vakit−30dk ile birebir. POCO'ya dokunulmadı.
- Ayrıntı docs/2026-10-09-gps-saat-dilimi.md; fiziksel POCO/Doze/reboot/sesli teslim sonraki kapsam.
## Önceki işler ve açık sınırlar
- Türkiye varsayılan gömülü resmî → aynı CityID güncel resmî HTTPS → doğrulanmış
  Aladhan ağ/cache; hesaplanmış etiketli. Resmî dönünce açık/resumed ekranda geri dönüş.
- GPS güvenilir ilçe/il merkezi fallback; manuel seçim geç GPS ile ezilmez.
  Tüm 862 ID için koordinat/sınır yok; belirsiz seçim korunur.
- latitudeAdjustmentMethod 1/2/3 + eski tercih göçü + cache v2 uygulandı.
  Resmîde Asr/yüksek enlem kapalı. Diyanet anahtarı root pop/siyah ekran düzeldi.
- 25 dil AI çevirisi; yöntem/lisans metinleri native speaker doğrulaması bekler.
- Malik 7 Ekim mevcut vakit verisini kontrol etti ve sorun olmadığını bildirdi;
  önceki Ankara +1 dakika gözlemi açık hata listesinden çıkarıldı, veri değiştirilmedi.
- Cihaz ana ekranda kaynak ayrıntısında {surum}/{tarih} literal kalması görüldü;
  önceki çeviri kapsamındaki placeholder konusu sonraki UI kontrolüne açık.
- Arşivde 26.722 örtüşen günün altı vakti 0 fark; eksik günlerin tamamı bağımsız
  birincil kaynakla doğrulanmış sayılmaz. Diyanet dağıtım izni/2028 kapsamı açık.
- Widget kapalı uygulama/gün devri/şehir/kaynak snapshot akışı uygulandı; derin Doze/reboot açık.
- Derin Doze/reboot/fiziksel offline yalnız PC bağımsız bağlantısıyla; bu tur denenmedi.
- iOS native ezan/fiziksel bildirim/widget doğrulanmadı.
- APK debug keystore imzalı; production signing/Play yayını tamamlanmadı.
- Kullanıcı yeni görev vermeden açık yayın işlerinden birini kendiliğinden başlatma.
## Başlangıç ve korunacaklar
- AGENTS → AI_HANDOFF → ARCHITECTURE → HEAD/status → ilgili kaynaklar.
- Önceki kullanıcı diff'i, geri_donus, CityID/il/parça/tercihler korunur.
- Eski HTML veri üreticisini rastgele çalıştırma; arşiv kapsamını geri alabilir.
- İlgili kod değişmediyse tam keşif/test döngüsünü tekrarlama.
- Ayrıntılar docs/2026-diyanet-arsiv-kapsami.md, docs/2026-10-05-gps-diyanet.md,
  docs/2026-10-05-kaynak-zinciri.md, docs/2026-10-05-yuksek-enlem.md, NOTICE.md.
