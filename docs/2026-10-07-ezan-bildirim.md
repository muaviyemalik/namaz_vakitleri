# Ezan ve bildirim ayarları — 7 Ekim 2026

## Kullanıcının onayladığı davranış

- Sabah Sabâ, Öğle Uşşak, İkindi Hicaz, Akşam Segâh, Yatsı Rast. Güneş ezan değil.
- Sessiz modda ezan açık; kullanıcı kapatabilir. DND varsayılan kapalı, ayrı ayar.
- Ses kısma/güç tuşu ile o anki sesi durdur; vakit bildirimi kalır, sonraki vakit kapanmaz.
- Tüm bildirim ayarları tek alt ekranda. Hatırlatma süresi bütün vakitlerde ortak:
  kapalı/15/30/45/60 dakika. Ses 3 numaralı özgün Sıcak yükseliş.
- Kullanıcı beş kaydın indirilmesini ve sonra bu davranışların uygulanmasını istedi.

## Uygulama

Mevcut yedi gün planlayıcı ve canonical kaynak korunur. Vakit alarmları Android
AlarmManager'a MethodChannel ile aynı UTC/ID/metinle taşınır. Plugin'in eski ID'si
iptal edilir; hatırlatma ve güneş türü plugin'de kalır. Native ayarlar çalma anında
okunur; telefonun alarm ses seviyesi kullanılır, global sesi yükseltme/geri değiştirme yok.
Foreground mediaPlayback + partial wake lock, audio focus kaybında durma, en fazla
6 dakika, bildirimde durdurma ve süre sonunda kaynak temizliği. Boot/uygulama
güncelleme receiver yalnız ileri alarmları kurar. Alarm iki dakikadan fazla gecikmişse
geç ezan yerine yalnız vakit bildirimi. Exact yoksa mevcut yaklaşık mod uyarısı korunur;
Android background servis başlangıcını reddederse vakit bildirimi kalır.

Ses kısma foreground Activity ve aktif MediaSession/VolumeProvider yoluyla ele alınır.
Güç tuşu doğrudan yakalanmaz; SCREEN_ON/OFF geçişi o anki sesi bitirir. Android
fiziksel tuşları her OEM'de aynı teslim etmez; cihaz sonucu ayrı kayıtlanır. DND açma
izni ayarlardan kullanıcıya bırakılır; global DND politikasını değiştirmez, sistemin
alarm kuralları ayrıca geçerlidir. Hatırlatma kanalı yenidir (eski Android kanalının
sesi değiştirilemediği için); notification usage ile sessiz/DND ayarlarına uyar.

## Kaynaklar ve kapsam

Beş MP3 kaynak/hash: assets/audio_sources.json. Kayıtların dağıtım lisansı bağımsız
doğrulanmadı; kullanıcı onayı bunu CC0 yapmaz. NOTICE'da açık kayıt var. Hatırlatma
matematiksel sinüs dalgalarından özgün sentez; harici sample yok.
Yeni 21 anahtar 25 dilde; AI çevirisi, native speaker kontrolü yapılmadı. Android
durdurma etiketi de bu dillere eklendi. Yeni native ses davranışı Android kapsamındadır.

## Doğrulama

- İlk hedefli sekiz dosya: 86 geçti; iki dar ekran/ayar testi: 2 geçti.
- Transport düzeltmesi sonrası ilgili beş dosya: 35 geçti.
- Son dart analyze lib test: 0 hata / 0 uyarı / 45 info.
- Release APK 104.492.931 bayt (99,7 MiB) derlendi. POCO Android 15 cihaz testleri: 18 PASS,
  `geri_donus/ezan-poco-tests.log`. Altı dosya decode, sessiz ezan,
  ses kısma susturma/bildirim kalma, sessiz seçeneği kapalı gate, DND sessiz
  teslim, sonraki alarm ve SCREEN_ON/OFF susturma doğrulandı.
- İlk test aracının ringer/DND izin hatası yalnız testte düzeltildi; geçici policy
  erişimi test sonunda geri alındı. Native ses odağı FGS durum yayılımından sonra
  istenir (250 ms); Android 15 erken focus reddi gerçek cihazda giderildi.
  Test sabit kısa sleep yerine bounded teslim bekler.
- Test APK kaldırıldı. Telefonun ses seviyesi/ringer/DND ayarları geri yüklenir;
  internetine dokunulmadı. Release install -r başarılı; Ayarlar → Bildirim Ayarları gerçek cihazda açıldı. Beş makam, sessiz açık/DND kapalı ve tek ortak 15 dakika mevcut tercihi korunmuş olarak görüldü. UI kanıtı ezan-release-notifications.xml ve ezan-release-reminder.xml.
- Derin Doze/reboot ve günler boyu kapalı uygulama davranışı bu koşuda denenmedi.
  iOS native ezan teslimi bu işin kapsamında uygulanmadı. Commit/push/main merge yok.

Son native kaynak kontrolü: assembleRelease BUILD SUCCESSFUL; son APK SHA256 177ECD743D0CFE151A2DD18C71B5A1565A5C21AC03D9FA28DA6903D5D6135377. Son APK install -r başarılı, Ankara ana ekranında bırakıldı.
