# 4. adım — yüksek enlem parametresi, tercih ve cache geçişi

**Anlık, 2026-10-05:** HEAD `0f05a9b17531f05c13e382acd736f041860a1328`, `fix/diyanet-2026-archive` üzerinde yerel 1–4. adım değişiklikleri; commit/push/main birleşimi yok.

Hata: hem güncel ay hem önden indirilen ay `adjustmentMethod=NONE/MIDDLE/QUARTER/HALF` gönderiyordu. API bu yüksek enlem seçimini uygulamıyordu; menüdeki 1/7 ve 1/4 gölge ifadeleri de yüksek enlem hesabını doğru anlatmıyordu. Yeni seçenekler `latitudeAdjustmentMethod=1` gecenin yarısı, `2` gecenin yedide biri, `3` açı tabanlıdır. Düzeltme yok ve çeyrek seçenekleri kaldırıldı; desteklenmeyen hesaplama sunulmaz.

Kaynak: sağlayıcının resmî API'sinin canlı yanıtları ve https://aladhan.com/prayer-times-api . Londra 51.5074/-0.1278, hesaplama yöntemi 3, Asr 0, 15 Mayıs 2026 için üç farklı çağrı `meta.latitudeAdjustmentMethod` alanında sırasıyla MIDDLE_OF_THE_NIGHT, ONE_SEVENTH, ANGLE_BASED bildirdi. Sabah/Yatsı: 02:06/23:30, 03:57/21:58, 02:38/23:08. Bunlar Diyanet tablosu değil, Aladhan hesaplanmış sonuçlarıdır. Etki gün/enlem/yönteme bağlıdır; her şehirde her gün fark olması beklenmez.

Tercih geçişi: yeni kodlar `middle_v2`, `seventh_v2`, `angle_v2`. Eski `orta/ceyrek/yarim/yok` veya bilinmeyen değer güvenli varsayılan gecenin yarısına geçirilir, yeni kod kaydedilir. İlk açılışta bir bilgi mesajı ne olduğunu ve uygulamanın ne yaptığını açıklar; tekrar modal/seçim sorusu yok. Sonraki açılışta yeni seçim aynen korunur. Kullanıcının konumu, saati, Asr ve diğer tercihleri korunur.

Cache geçişi: yeni kodlar mevcut koordinat/yöntem/Asr/ay anahtarının parçasıdır; eski yanlış istekle üretilmiş kayıt yeni hesap diye okunmaz/kopyalanmaz. Üç doğru seçim birbirinden ayrıdır. Eski kayıtları topluca silme yok. Yeni hesap için ağ gerekirse standart hata/önbellek akışı işler; tarih veya saat uydurulmaz. Resmî gömülü/güncel Diyanet cache'i ve tabloları değişmez. Ayar sadece hesaplanmış kaynakta etkilidir.

Ayar kartında gerçek seçenek adları tam genişlikte sunulur; açıklama hesaplanmış/resmî ayrımını söyler. Geç cevap ve mevcut bildirim/sayaç kaynak zinciri korunur. Türkçe yeni metinlerin diğer dillere uyarlanması planın UI/çeviri turunda ele alınacaktır.

## Doğrulama

- Canlı resmî Aladhan API: üç sayısal parametrenin farklı metadata ve vakitlerle uygulandığı görüldü.
- Kaydedilmiş gerçek 15/16 Mayıs tabloları: `test/fixtures/aladhan_yuksek_enlem_londra.json`. Sabit uygulama saatinde üretim AnaSayfa, HTTP, validator ve VakitDepo yolundan geçer; seçimle Sabah/Yatsı ve sayaç 01:06:00 / 02:57:00 / 01:38:00 olur. Üç ayrı cache ve eski cache'in kullanılmaması doğrulanır. Eski tercihlerin geçişi ve yeni üç tercihin yeniden açılış turu test edilir.
- `flutter test` ilgili beş dosya (`yuksek_enlem`, `saat_dilimi_motoru`, `saat_dilimi_kesinlesmesi`, `kaynak_zinciri`, `diyanet_kimlik_kayit`): **54 geçti / 0 başarısız** (son kaynak/UI ve siyah ekran düzeltmelerinden önce). Tam paket bu adımda tekrar çalıştırılmadı.
- `dart analyze lib test`: **0 hata / 0 uyarı / 45 info**.
- Kanıt klasörü: `geri_donus/yuksek_enlem_20261005/`. APK/POCO sonucu aşağıdaki son doğrulama kaydında.
- Sıradaki kullanıcı planı: **5. adım gerçek vakitte OS seviyesinde ezan**; ses dağıtım hakkı, DND/sessiz ve Doze/reboot dahil.

## Malik’in Türkiye varsayılanı düzeltmesi ve ayar sorunları

Türkiye varsayılanı resmî Diyanet açık olarak korundu. Diyanet’in resmî yerleşim tablosu birincil kaynaktır (https://namazvakitleri.diyanet.gov.tr/tr-TR/9206/ankara-icin-namaz-vakti). Gömülü/güncel resmî tabloda uygulama yüksek enlem hesabı yapmaz; bu tabloyu değiştirmeden kullanır. Ayarlar artık ana ekranın doğrulanmış `aktifVakitDurumu` kaynağını izler; resmî kaynaktayken yüksek enlem seçici devre dışı ve “Kapalı — resmî Diyanet verisi” görünür. Kaynak hesaplanmışa düşerse ayrı seçenek kullanılabilir ve sonuç resmî diye etiketlenmez. Kullanıcının ülke/yöntem tercihi değişince yüksek enlem tercihi kendiliğinden başka bir seçeneğe çevrilmez; bu ayrı tercihtir.

POCO turunda bu adımın ilk APK’sında Asr satırına yanlışlıkla uzun dropdown etiketi konduğu için dar ekran yerleşimi harf harf taşmıştı; kısa eski etiket geri getirildi. Malik ayrıca resmî Diyanet anahtarında siyah ekran bildirdi. Anahtar mevcut `Navigator.pop()` ile ana route’u kapatıyordu; kapatma kaldırıldı, kaynak tercihi yerinde değişir. Dar ekran/gerçek seçici, resmî kaynakta devre dışı kontrol ve Diyanet açık/kapalı/tekrar açık handler’ının ana route’u koruması aynı regresyonda ölçülür.

## Son APK ve cihaz sonucu

Son UI/siyah ekran düzeltmesinden sonra `yuksek_enlem_test.dart` ve `kaynak_zinciri_test.dart`: **6 geçti / 0 başarısız**. Son `dart analyze lib test`: **0 hata / 0 uyarı / 45 info**. Tam paket tekrar edilmedi. Release APK **70.299.890 bayt**, SHA256 `8909fc1bec0eac9f04021cb0355c27f84dbaf0b6758f56e4e2f1181f1e745428`; mevcut debug imzası, production değil.

Son APK POCO’ya `install -r` ile kuruldu. Diyanet açık→kapalı→açık fiziksel düğmeyle denendi: Ayarlar yerinde kaldı, siyah ekran yok; yüksek enlem alanı resmî kaynaktayken “Kapalı — resmî Diyanet verisi”, hesaplanmışta seçilebilir. Hesaplama yöntemi düğmesi menüsünü açtı; seçim değiştirmeden kapatıldı. Son durumda Ankara, resmî gömülü kaynak/sayaç, Diyanet açık, yüksek enlem kayıtlı tercih gecenin yarısı (resmîde uygulanmaz); telefon interneti korunur. Kanıt XML/logları ilgili klasördedir.

UI turunda ayrıca hesaplama yöntemi açıklamasının resmî kaynakta etkisiz oluşunu diyalog metninde daha açık söyleme işi adım 8’de ele alınabilir; mevcut tablolara bu ayarlar uygulanmıyor.

## Asr takip düzeltmesi

Malik’in düzeltmesiyle Asr seçici de aynı kanonik resmî kaynak kontrolüyle devre dışı bırakıldı; tam genişlikte kapalı etiketi ve ikindi vakti resmî tablodan açıklaması var. Hesaplanmış kaynakta eski Asr tercihi korunur ve seçici etkinleşir. İlgili dört test geçti; dar ekran resmi/hesaplanmış ve tercihin silinmemesi regresyona eklendi. Çalışma sırasında eşzamanlı çeviri değişikliklerinin oluşturduğu etiket() çağrısı ve string birleştirme derleme hataları minimal düzeltildi.
