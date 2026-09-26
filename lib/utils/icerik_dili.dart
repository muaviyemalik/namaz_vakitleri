// lib/utils/icerik_dili.dart
//
// İÇERİK DİLİNİN ÇÖZÜMLENMESİ (3 harfli locale ↔ 2 harfli veri anahtarı)
//
// Uygulamanın dili ISO 639-2/3 (3 harfli) kodla temsil edilir: çeviri dosyasının
// adı `Locale.languageCode`'dan türetilir (tur.json, eng.json, zho.json) ve
// `supportedLocales` dil kataloğundan gelir. Bkz. lib/data/dil_katalogu.dart.
//
// Gömülü içerik verisi ise ISO 639-1 (2 harfli) kodlarla anahtarlanmıştır:
//   lib/data/veri_havuzu.dart  →  ayetler['tr'], hadisler['en']
//   lib/data/ozel_gunler.dart  →  ozelGunler['zh']
//
// Bu iki kod dünyası birebir aynı değildir: tur→tr, eng→en, zho→zh.
// Eşleme unutulduğu için her içerik çağrısı şu sonuca varıyordu:
//
//   ayetler['tur']            → null
//   ?? ayetler['en']!         → İngilizce
//
// Yani uygulama 25 dilde çalışmasına rağmen Türkçe seçili kullanıcı ayet,
// hadis ve özel gün metinlerini **İngilizce** görüyordu. Sayaç, iki ana ekran
// widget'ı, paylaşım metni ve özel günler sayfasının hepsi bu hattan etkileniyordu.
//
// Çözüm: veri anahtarlarını değiştirmek değil (çok dilli içerik setleri ve
// AlQuran Cloud gibi kaynaklar 2 harfli kod veriyor), giren 3 harfli kodu
// ISO-1'e çevirmek. Eşlemenin tek kaynağı dil katalogudur: 152 dilin her
// birinde `kod` (3 harfli) ve `iso1` (2 harfli) alanları vardır. Yeni bir içerik
// dili eklendiğinde burada hiçbir şey değişmesi gerekmez.
//
// Katalog yüklenmemişse (unit testler, `rootBundle` yok) kod aynen döner ve
// çağıran taraf yedek dile (İngilizce) düşer; yani davranış eskisi gibi güvenli
// kalır, uygulama çökmez.
import '../data/dil_katalogu.dart';

/// [dilKodu]'nun içerik verisinde karşılık geldiği anahtarı döner.
///
/// Girdi 3 harfliyse ISO 639-1'e çevrilir (`tur` → `tr`), 2 harfliyse olduğu
/// gibi döner. Eşleme bulunamazsa kod değiştirilmeden döner; veri çağıran
/// tarafta yedek içerik seçilir.
String icerikDilKodu(String dilKodu) {
  final String kod = dilKodu.trim().toLowerCase();
  if (kod.length == 2) return kod; // Zaten ISO 639-1.

  if (DilKatalogu.yuklendiMi) {
    final String? iso1 = DilKatalogu.ornek.kodaGore(kod)?.iso1;
    if (iso1 != null && iso1.isNotEmpty) return iso1;
  }
  return kod;
}
