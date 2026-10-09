# AI çalışma kuralları

Bu kurallar Namaz Vakitleri deposunun tamamında geçerlidir.

## Yeni sohbet başlangıcı

1. Önce `docs/AI_HANDOFF.md`, ardından `docs/ARCHITECTURE.md` oku.
2. `git remote -v`, `git branch --show-current`, `git rev-parse HEAD` ve
   `git status --short --branch` ile doğru repo/dal ve çalışma ağacını doğrula.
3. Handoff'taki HEAD ve yerel değişiklik kapsamını karşılaştır. Aynı HEAD,
   değişmemiş çalışma ağacı demek değildir; ilgili diff'i gerektiğinde oku.
4. Görev için mimari haritadan dosyaları seç; önce yalnız ilgili 2–5 dosyayı aç.
   Somut bir eksik/çelişki varsa aramayı o bağımlılığa doğru genişlet.

## Bağlam ve doğrulama bütçesi

- Her yeni sohbette tüm repoyu tarama, mimariyi yeniden çıkarma veya tüm testleri
  sırf başlangıç kontrolü için çalıştırma. Asset, yedek ve logları topluca okuma.
- Kapanmış işleri yeni hata kanıtı, değişen gereksinim veya kullanıcı talebi
  olmadıkça yeniden açma. Eski raporları güncel mimariden üstün tutma.
- HEAD, ilgili kod/veri/bağımlılıklar ve test ortamı değişmediyse kayıtlı baseline'ı
  kullan. HEAD aynı olsa bile ilgili yerel değişiklik varsa hedefli doğrulama yap.
- Değişen davranışın mevcut testlerini çalıştır. Tam paket/analiz yalnız geniş
  etki, ilgili başarısızlık, bağımlılık/ortam değişikliği veya açık talep gerektirirse.
- Belge değişikliğinde yolları, içerik tutarlılığını ve whitespace'i kontrol etmek
  yeterlidir. Çalıştırılmayan testleri başarılı diye yazma; geçmiş kanıtı ayır.

## Değişiklik disiplini

- Mevcut kullanıcı değişikliklerini, izlenmeyen dosyaları ve cihaz verilerini koru.
  Reset/clean/stash, dal değiştirme, geniş refactor veya veri üretimi kendiliğinden yapma.
- Resmî/hesaplanmış kaynak ayrımını, CityID/il kimliğini, seçili şehir saat dilimini,
  kaynak önceliğini ve bildirim planı yarış korumalarını koru.
- Asset kapsamı için `assets/veri/diyanet/paket.json` esas alınır; README'deki eski
  sayıları güncel durum diye aktarma. Kaynak/hash/izin açıklamalarını kaldırma.
- Commit/push, merge, yayın veya cihaz kurulumu ancak kullanıcının yetkilendirdiği
  kapsamda yapılır. Bu belgeyi oluşturma görevi commit/push içermez.

## Devir dosyalarının bakımı

- Görev sonunda `docs/AI_HANDOFF.md` içindeki son durumu yerinde güncelle:
  HEAD/dal, yerel değişiklikler, doğrulama kapsamı, açık işler ve sonraki adım.
- Handoff günlük değildir; hedef 100 satırın altı, üst sınır 200 satır.
  Eski oturumları biriktirme; ayrıntılı kanıta dosya yolu ver.
- Baseline kaydına tarih, komut/kapsam, sonuç, HEAD ve yerel değişiklik durumunu
  yaz; tam koşudan sonraki hedefli kontrolleri ayrı belirt.
- `docs/ARCHITECTURE.md` yalnız katman/veri akışı veya temel dosya ilişkisi
  değiştiğinde güncellenir. Oturum sonuçları ve sürüm bilgisi handoff'a aittir.
