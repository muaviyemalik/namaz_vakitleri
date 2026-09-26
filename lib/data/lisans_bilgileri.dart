// lib/data/lisans_bilgileri.dart
//
// Uygulama icinde gosterilen lisans ve atif bilgileri.
//
// NEDEN BU KADAR KAPSAMLI?
// Uygulama ucuncu taraf veri setleri kullanir ve bunlarin cogu KOPYALAC
// lisanslidir. Ozellikle ODbL-1.0: bu lisansla dagitilan bir veritabani
// turetilmis veriyle birlikte dagitildiginda kaynagi belirtme YUKUMMLULUGU
// getirir. Bu yuzden atif sadece README'de degil, UYGULAMA ICINDE de
// gorunmelidir.
//
// Lisanslar (GitHub API ile dogrulandi):
//   dr5hn/countries-states-cities-database -> ODbL-1.0   (kopyalaç)
//   mledoze/countries                       -> ODbL-1.0   (kopyalaç)
//   haliaeetus/iso-639                       -> MIT         (serbest)
//   GeoNames cities15000                     -> CC BY 4.0   (atif zorunlu)
//   Aladhan API                              -> ucretsiz, anahtar gerekmez

/// Tek bir atif girdisi.
class LisansGirdisi {
  final String baslik;
  final String aciklama;
  final String lisans;
  final String? kaynak;
  final String? url;
  final bool kopyalac;

  const LisansGirdisi({
    required this.baslik,
    required this.aciklama,
    required this.lisans,
    this.kaynak,
    this.url,
    this.kopyalac = false,
  });
}

/// Uygulamanin kullandigi tum ucuncu taraf veri ve servisler.
const List<LisansGirdisi> lisansGirdileri = [
  // --- Kopyalaç lisanslı veri setleri (atıf zorunlu) ---
  LisansGirdisi(
    baslik: 'Ülke ve Şehir Veritabanı',
    aciklama: '245 ülke ve 141.135 şehrin adı, koordinatı ve ülke-dil '
        'ilişkisi bu veri setinden alınmıştır.',
    lisans: 'ODbL-1.0 (Open Data Commons Open Database License)',
    kaynak: 'dr5hn/countries-states-cities-database',
    url: 'https://github.com/dr5hn/countries-states-cities-database',
    kopyalac: true,
  ),
  LisansGirdisi(
    baslik: 'Ülke-Dil İlişkisi',
    aciklama: 'Hangi ülkenin hangi dilleri resmî olarak kullandığı bilgisi '
        'bu veri setinden alınmıştır.',
    lisans: 'ODbL-1.0 (Open Data Commons Open Database License)',
    kaynak: 'mledoze/countries',
    url: 'https://github.com/mledoze/countries',
    kopyalac: true,
  ),

  // --- Serbest lisanslı veri ---
  LisansGirdisi(
    baslik: 'Önemli Şehir Takviyesi (GeoNames)',
    aciklama: 'Büyük şehirlerin kanonik adları ve koordinatları bu veri '
        'setinden alınmıştır. Ana veri seti ilçe ve köy düzeyine odaklandığı '
        'için bazı büyük şehirler (örn. Kahramanmaraş, Konya) onda bulunmuyordu.',
    lisans: 'CC BY 4.0 (Creative Commons Attribution)',
    kaynak: 'GeoNames cities15000',
    url: 'https://www.geonames.org/webservices/',
  ),
  LisansGirdisi(
    baslik: 'Dil Adları (otokton adlar)',
    aciklama: '152 dilin kendi dilindeki adı ve ISO 639 kod eşlemesi bu veri '
        'setinden alınmıştır.',
    lisans: 'MIT',
    kaynak: 'haliaeetus/iso-639',
    url: 'https://github.com/haliaeetus/iso-639',
  ),

  // --- Servisler ---
  LisansGirdisi(
    baslik: 'Namaz Vakti Verisi',
    aciklama: 'Namaz vakitleri, hicri takvim ve hesaplama yöntemleri bu '
        'servisten alınır. API anahtarı veya üyelik gerektirmez.',
    lisans: 'Ücretsiz kullanım',
    kaynak: 'Aladhan Prayer Times API',
    url: 'https://aladhan.com/prayer-times-api',
  ),
  LisansGirdisi(
    baslik: 'Kur’an Çevirileri',
    aciklama: 'Ayet metinleri ve çevirileri bu servisten alınır. Her '
        'çevirinin kendi kaynağı vardır.',
    lisans: 'Çeviri başına kaynaklı',
    kaynak: 'AlQuran Cloud',
    url: 'https://alquran.cloud',
  ),
];

/// ODbL-1.0 kopyalaç lisansı nedeniyle uygulanması gereken açıklama.
///
/// ODbL, veritabanı türevlerinin kaynağını belirtmeyi zorunlu kılar. Bu
/// metin uygulama içinde de görünmelidir; README'deki atıf tek başına
/// yeterli değildir.
const String odblAciklamasi =
    'Bu uygulama, Open Database Commons Open Database License (ODbL-1.0) '
    'lisanslı veri setlerinden alınan verileri içerir. ODbL-1.0 kopyalaç bir '
    'lisans olduğu için, bu verileri kullanan ve dağıtan uygulamalar verinin '
    'kaynağını açıkça belirtmek zorundadır. Kaynak veri setlerinin lisans '
    'koşulları aynen uygulanmaktadır.';

/// GeoNames (CC BY 4.0) için gereken atıf açıklaması.
///
/// CC BY 4.0 da atıf zorunludur; kaynak, lisans ve değişiklik (blendirilen
/// veri) belirtilmelidir.
const String geoNamesAciklamasi =
    'Bu uygulama, GeoNames cities15000 veri setini kullanır '
    '(© GeoNames, CC BY 4.0). GeoNames verisi, uygulamanın kendi şehir '
    'veri tabanıyla birleştirilmiştir: veri kaynağının küçük yerleşim '
    'kayıtları korunmuş, büyük şehirlerin kanonik adları ve koordinatları '
    'eklenmiş, aynı koordinatı taşıyan mükerrer kayıtlar birleştirilmiştir. '
    'Değişiklikler bu depodaki tool/sehir_birlestir.dart ve '
    'tool/mukerrer_birlestir.dart araçlarıyla yapılmıştır.';

/// Uygulamanın kendi durumu.
const String uygulamaSurumu = '1.0.0';
const String uygulamaAdi = 'Namaz Vakitleri';
