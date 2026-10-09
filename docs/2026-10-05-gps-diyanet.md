# 3. adım — GPS ve kanonik Diyanet yerleşimi

**Anlık, 2026-10-05:** `fix/diyanet-2026-archive`, HEAD `0f05a9b17531f05c13e382acd736f041860a1328` üzerinde yerel değişiklik. Commit/push/main birleşimi yok.

GPS artık yalnız il adını kaydetmez. `diyanet_konum.dart`, mevcut yerel TR koordinatlarını doğrulanmış il+yerleşim eşlemesiyle birleştirir; yalnız eşleme bulunan CityID'ler adaydır. Ankara için mevcut uygulamanın başlangıç koordinatı kullanılır; şehir dosyasındaki 36 km batıdaki nokta GPS merkezini temsil etmek için kullanılmaz. Yeni coğrafi veri indirilmedi, vakit asset'leri değiştirilmedi.

Geocoder yardımcıdır: 4 saniye sonunda veya hatasında yerel çözüm sürer. GPS 20 saniye ile sınırlıdır. En fazla 3 km yakın, ikinci adaydan hassasiyet payı dahil açıkça ayrışan yerleşim offline seçilebilir. Ülke/il ve kesin yerleşim adı koordinatla tutarlıysa geocoder destekli seçim yapılır (25 km üst sınır). İlçe kesinleşmezse geocoder ilini destekleyen yakındaki yerel aday ve tekil il merkeziyle merkez seçilir; kullanıcıya açık bilgi verilir. İl/ülke belirsizliği, kötü hassasiyet (>3 km), servis/izin/timeout hatasında mevcut konum korunur. Nokta kataloğu idarî sınır poligonu değildir; tüm 862 ID için koordinat yoktur. Belirsiz yerde otomatik ilçe garantisi verilmez.

Şehir seçicinin 1067 TR kaydı Diyanet eşlemesiyle aynı liste değildir. Ankara Gölbaşı için paket eşlemesinde ayrı ID yok, Adıyaman Gölbaşı için 9162 vardır. Ankara Gölbaşı manuel seçildiğinde hesaplanmış kaynak davranışı korunur; GPS güvenilir Ankara ili ile merkez seçtiğinde merkez kullanıldığı bildirilir. Bir ilçeye başka ilçenin ID'si takılmaz.

`konumSecimSurumu` yeni GPS, şehir seçici ve ülke seçimiyle önceki işlemi iptal eder. `konumAyarla` ülkeyi başta yakalar; async okuma sonrası ve kayıt öncesi sürümü/mounted guard'ı denetler. Geç GPS/manuel sonuç yeni manuel seçimi veya tercihi ezmez. İl+CityID+parça yolu tek `aktifKonum` ile kaynak zincirine gider; ekran/sayaç/bildirim/mevcut widget girdisi bu sonuçtan beslenir. Ezan altyapısı adım 5, widget arka plan dayanıklılığı adım 6 olarak açık kalır.

Eski il/ID eksik TR kayıtlarında yalnız aynı isim ve yakın koordinatla tekil eşleme bulunursa kimlik tamamlanıp kaydedilir; koordinat/ad/saat dilimi korunur. Belirsiz eski kayıt başka şehre taşınmaz. Yabancı GPS için kesin ülke kodu geldiğinde mevcut koordinatlı hesaplama akışı sürer; ülke bilinmiyorsa sessiz TR varsayımı yapılmaz.

## Doğrulama

- `flutter test test/diyanet_konum_test.dart test/diyanet_kimlik_kayit_test.dart test/kaynak_zinciri_test.dart test/bildirim_plan_yarisi_test.dart test/sayac_widget_test.dart`: **33 geçti, 0 başarısız**. Offline aynı adlı Ortaköy/Aksaray-Çorum, il merkezi, yabancı/çelişkili konum, eski kayıt, geç sonuç/state/persist ve kaynak/bildirim/sayaç regresyonları.
- `dart analyze lib test`: **0 hata, 0 uyarı, 45 info**. İlk yanlış kapsamlı `flutter analyze` yedek Dart dosyalarını da taradı; geçerli uygulama analizi lib/test kapsamındadır. Tam test paketi bu adımda tekrarlanmadı; geçmiş baseline handoff'ta.
- Release APK başarılı: **70.299.890 bayt**, SHA256 `dffb8e35652c5be909e5ff09fca474d3ab84a915c822c09fd86c91c731da1126`. Mevcut debug imzası; production signing değildir.
- POCO C65 üzerine `install -r`: veriler korundu. Gerçek GPS→Ankara resmî kaynak/sayaç görüldü. GPS başlatılıp şehir seçici açılarak Polatlı manuel seçildi; resmî kaynak ve force-stop/cold launch sonrası Polatlı korundu. Sonrasında yeni GPS isteğiyle Ankara'ya dönüldü. Geç sonuç yarışının deterministik kanıtı testtedir; gerçek GPS isteğinin ne zaman tamamlandığı fiziksel turda ölçülmedi.
- Telefon interneti kesilmedi. Gerçek offline, Doze/reboot/ezan/widget E2E adım 7 kapsamında açık.
- Kanıt: `geri_donus/gps_diyanet_20261005/`. Sonraki iş: **4. adım yüksek enlem parametresi/seçenek ve eski tercih/cache geçişi**.
