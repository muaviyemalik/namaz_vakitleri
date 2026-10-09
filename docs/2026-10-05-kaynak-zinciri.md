# Kaynak zinciri — 5 Ekim 2026

Malik'in yayın planının 2. adımı: Türkiye'de resmî mod açıkken gömülü
Diyanet → aynı CityID için erişilebilir güncel resmî Diyanet → doğrulanmış
hesaplanmış Aladhan ağ/önbellek verisi. Kullanıcıya kaynak seçimi modalı çıkmaz.
Gömülü veri önceliklidir; resmî veri yokken hesaplanmış vakitler açıkça etiketlenir.
Hiçbir güvenilir kaynak yoksa vakit uydurulmaz ve gösterilmez. Bu adım yeni bir
yerel astronomik hesaplama motoru içermez; hesaplanmış kaynak mevcut doğrulama
katmanından geçen Aladhan verisidir.

## Güncel resmî kaynak

Awqat Salah API erişimi beklenirken resmî HTTPS web tablosu kullanılır:
https://namazvakitleri.diyanet.gov.tr/tr-TR/9206/ankara-icin-namaz-vakti
Yalnız aynı HTTPS hostu ve CityID içinde en fazla iki yönlendirme kabul edilir.
İstek toplam 8 saniyeyle ve cevap 2 MB ile sınırlıdır. Sayfanın canonical URL'si
ve ilceId'si seçilen CityID ile eşleşmeli; gerçek tarih, altı sıralı/geçerli saat
ve tekrar eden tarihlerde aynı saatler zorunludur. Başka ilçe, HTML hata sayfası,
00:00, yanlış tarih/saat ve çelişkili tekrar reddedilir.

Resmî web önbelleği hesaplanmış vakit önbelleğinden ayrı anahtarlardadır.
En çok dört yerleşim tutulur. Kayıt bir saatten sonra ağdan tazelenir; ağ yoksa
en çok yedi günlük, yalnız istenen gerçek tarihi kapsayan resmî kayıt okunur.
Eski günü bugüne taşıma/yıl kopyalama yoktur. Hatalı cevap sağlam kaydı ezmez.
Gömülü kaynaktan düşüldüğünde açık ekranda ve resumed akışında beş dakikalık
kontrollü yeniden deneme vardır. Resmî veri geri gelince kullanıcı kararı beklenmeden
resmî kaynağa dönülür. Uygulama kapalıyken arka plan yenilemesi bu adımda eklenmedi.

## Tek uygulama sonucu

Kaynak, bugünün vakitleri ve gelecek günler birlikte VakitDurumu üzerinden
uygulanır. Sayaç, bildirim planı ve mevcut widget'a yazılan sıradaki vakit
aynı uygulanan kayıttan gelir. Resmî gelecek günlere hesaplanmış ay önbelleği
karıştırılmaz. Geç ağ cevabı seçim jetonu/mounted/tarih korumasından geçmeden
ekrana uygulanmaz. Widget'ın kapalı uygulama/gün devri/şehir ve kaynak etiketi
iyileştirmeleri yayın planının 6. adımında kalır; ezan teslimi 5. adımda.

Uyarılar “ne oldu + uygulama hangi kaynağı kullandı” bilgisidir. Hesaplanmış
veri gerçekten bulunmadan “gösteriliyor” denmez. Resmî mod kullanıcı tarafından
kapatıldıysa tercih korunur. Türkiye dışındaki hesaplanmış akış korunur.

## Doğrulama

- Tam paket: **536 geçti / 11 canlı test atlandı / 0 başarısız**.
- Ardından resmî yönlendirme koruması eklendi; 5 resmî kaynak birim testi ve
  2 gerçek AnaSayfa kaynak zinciri testi geçti. İndirilen gerçek HTML okuyucu
  kontrolü geçti; gerçek HTTPS çağrısı bir geçici başarısızlığın ardından yeniden
  denendi ve aynı CityID yönlendirmesi dahil geçti. Bu canlı çağrı normal test
  paketinin parçası değildir.
- Gömülü kaynağın ağdan/hesaplanmış önbellekten önceliği, hesaplanmış fallback,
  beş dakika sonra resmî veriye otomatik dönüş ve saatlerin değişimi ölçüldü.
- Analiz: **0 hata / 0 uyarı / 45 info** (bilgi düzeyinde lint).
- Veri arşiv kaynak/hash/bağımsız doğrulama sınırı ve yeniden dağıtım izin işi
  korunur. Main birleşmedi; bu oturumdaki kod commit/push edilmedi.

## Yayın öncesi veri farkı

5 Ekim 2026 Ankara için gömülü satır: 05:18, 06:41, 12:41, 15:56, 18:32, 19:50.
Aynı gün erişilen resmî web satırı: 05:19, 06:41, 12:42, 15:57, 18:33, 19:50.
Dört vakitte +1 dakika fark vardır. Kaynak önceliği kullanıcı kararına uygun
olarak gömülüde kaldı; snapshot sessizce ezilmedi. Bu fark, yayın öncesi veri
doğrulamasında ayrıca çözülmelidir; geçmiş arşiv örtüşme ölçümü bunu kapatmaz.

## APK ve POCO sonucu

Son release mod APK: 70.267.122 bayt (67,01 MiB), SHA-256
`9cb9c56dc1dc81b91c410bde45548d38cf274ecce2f19df73ce0438019f32baf`.
POCO C65'e mevcut veriler korunarak kuruldu; cold launch sonrası Ankara,
gömülü resmî kaynak etiketi ve çalışan sayaç görüldü. Resmî kaynakta yanıltıcı
“Aladhan otomatik yöntemi” satırı yerine “Resmî Diyanet tablosu” gösteriliyor.
Bu fiziksel cihaz turu gömülü normal akışı doğrular; fallback/otomatik geri dönüş
kontrollü AnaSayfa testinde, gerçek resmî web ise Windows HTTPS canlı kontrolünde
ölçüldü. Telefonun internet ayarları değiştirilmedi. Fiziksel offline/Doze/reboot
ve widget dayanıklılık turu tamamlanmış sayılmaz. Kanıtlar:
`geri_donus/diyanet_fallback_20261005/`. İmza hâlâ debug keystore; production değildir.