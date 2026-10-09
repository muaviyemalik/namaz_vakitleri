// lib/data/lisans_bilgileri.dart
//
// DIYANET KAYNAGI NEDEN `final`?
// `kaynak` alani baska girdilerde proper noun (veri seti adi, API adi) ve
// cevrilmez; Diyanet girdisinde ise Turkce bir cumledir. Once sabit metin
// idi ve 24 dilde Turkce kaliyordu; artik `lisans_diyanet_kaynak` ceviri
// anahtarindan gelir. Bu bir calisma zamani cagrisi oldugu icin liste
// `const` olamaz. `test/lisans_test.dart` yalnizca alanlarin DOLU oldugunu
// olcer, `const` oldugunu degil; bu yuzden test degismez.
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
import 'package:easy_localization/easy_localization.dart';

//   dr5hn/countries-states-cities-database -> ODbL-1.0   (kopyalaç)
//   mledoze/countries                       -> ODbL-1.0   (kopyalaç)
//   haliaeetus/iso-639                       -> MIT         (serbest)
//   GeoNames cities15000                     -> CC BY 4.0   (atif zorunlu)
//   Aladhan API                              -> ucretsiz, anahtar gerekmez

/// Tek bir atif girdisi.
///
/// ALANLARIN IKI KATMANLI OLUŞU:
///  - [baslik] / [aciklama] / [lisans]: Türkçe metin. Hem yasal testlerinin
///    ölçtüğü kaynak metin hem de çeviri dosyası yüklenemezse yedek.
///  - [ceviriEki] / [lisansAnahtari]: 25 dildeki karşılıkların anahtarları.
///    `assets/i18n/ceviri/<3-harfli>.json` içinde `<ceviriEki>_title`,
///    `<ceviriEki>_desc` (ve varsa `<lisansAnahtari>`) olarak dururlar.
///
/// NEDEN AYRI TUTUYORUZ?
/// ODbL-1.0 kopyalaç bir lisans; atıf metninin Türkçe hâli hukuki metindir
/// ve `test/lisans_test.dart` onun üzerinden ölçüm yapıyor. Modeli sadece
/// anahtarlarla değiştirmek o testi ve Türkçe yedeği ortadan kaldırırdı.
class LisansGirdisi {
  final String baslik;
  final String aciklama;
  final String lisans;

  /// Ekranda gösterilen kaynak adı.
  ///
  /// Diyanet satırı dışındaki kaynaklar kural olarak proper noun'dur
  /// (GeoNames cities15000, Aladhan Prayer Times API, AlQuran Cloud) ve
  /// çevrilmez. Diyanet satırı ise Türkçe bir cümledir, bu yüzden
  /// `lisans_diyanet_kaynak` anahtarından çevrilir.
  ///
  /// ÇEVİRİ ÇÖZÜLEMEZSE TÜRKÇE YEDEK DÖNER, ham anahtar adı DEĞİL.
  /// Çünkü bu sınıf veri katmanıdır; birim testlerde `rootBundle` yoktur ve
  /// çeviri dosyaları yüklenmez. Bu durumda arayüzde `lisans_diyanet_kaynak`
  /// yazmak, Türkçe metni göstermekten çok daha kötüdür.
  final String? kaynak;
  final String? url;
  final bool kopyalac;

  /// Çeviri anahtarı öneki. `'<ceviriEki>_title'` ve `'<ceviriEki>_desc'`
  /// her 25 dil dosyasında tanımlıdır.
  final String ceviriEki;

  /// Lisans metni dil bağımsız değilse tam anahtarı (örn.
  /// `license_aladhan_terms`). Proper noun ise (ODbL-1.0, CC BY 4.0, MIT)
  /// null bırakılır ve [lisans] olduğu gibi gösterilir.
  final String? lisansAnahtari;

  const LisansGirdisi({
    required this.baslik,
    required this.aciklama,
    required this.lisans,
    this.kaynak,
    this.url,
    this.kopyalac = false,
    required this.ceviriEki,
    this.lisansAnahtari,
  });
}

/// Diyanet kaynağının kullanıcı diline çevrilmiş hâli.
///
/// Çeviri çözülemezse Türkçe kaynak metin döner; arayüzde asla ham anahtar
/// adı (`lisans_diyanet_kaynak`) görünmez.
String _diyanetKaynagi() {
  const String anahtar = 'lisans_diyanet_kaynak';
  final String c = anahtar.tr();
  return c == anahtar
      ? 'T.C. Diyanet İşleri Başkanlığı — Namaz Vakitleri'
      : c;
}

/// Uygulamanin kullandigi tum ucuncu taraf veri ve servisler.
///
/// `final` (const degil) cunku Diyanet girdisinin `kaynak` alani
/// `lisans_diyanet_kaynak` anahtarindan cevrilir; bu bir calisma zamani
/// cagrisidir ve const liste icinde yer alamaz.
final List<LisansGirdisi> lisansGirdileri = [
  // --- Kopyalaç lisanslı veri setleri (atıf zorunlu) ---
  LisansGirdisi(
    baslik: 'Ülke ve Şehir Veritabanı',
    aciklama: '245 ülke ve 141.135 şehrin adı, koordinatı ve ülke-dil '
        'ilişkisi bu veri setinden alınmıştır.',
    lisans: 'ODbL-1.0 (Open Data Commons Open Database License)',
    kaynak: 'dr5hn/countries-states-cities-database',
    url: 'https://github.com/dr5hn/countries-states-cities-database',
    kopyalac: true,
    ceviriEki: 'license_city_db',
  ),
  LisansGirdisi(
    baslik: 'Ülke-Dil İlişkisi',
    aciklama: 'Hangi ülkenin hangi dilleri resmî olarak kullandığı bilgisi '
        'bu veri setinden alınmıştır.',
    lisans: 'ODbL-1.0 (Open Data Commons Open Database License)',
    kaynak: 'mledoze/countries',
    url: 'https://github.com/mledoze/countries',
    kopyalac: true,
    ceviriEki: 'license_country_lang',
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
    ceviriEki: 'license_geonames',
  ),
  LisansGirdisi(
    baslik: 'Dil Adları (otokton adlar)',
    aciklama: '152 dilin kendi dilindeki adı ve ISO 639 kod eşlemesi bu veri '
        'setinden alınmıştır.',
    lisans: 'MIT',
    kaynak: 'haliaeetus/iso-639',
    url: 'https://github.com/haliaeetus/iso-639',
    ceviriEki: 'license_iso639',
  ),

  // --- Servisler ---
  LisansGirdisi(
    baslik: 'Resmî Diyanet Vakit Verisi (Türkiye)',
    aciklama: 'Türkiye\'de gösterilen vakitler Diyanet İşleri Başkanlığı\'nın '
        'kendi yayımladığı tablolardan alınmıştır ve uygulamanın içine '
        'gömülüdür; internet gerekmez. Diyanet bu vakitlerin kendi resmî '
        'hesaplamalarına dayandığını belirtir.',
    lisans: 'Resmî devlet verisi',
    kaynak: _diyanetKaynagi(),
    url: 'https://namazvakitleri.diyanet.gov.tr/',
    ceviriEki: 'license_diyanet',
    lisansAnahtari: 'license_diyanet_terms',
  ),
  LisansGirdisi(
    baslik: 'Namaz Vakti Verisi (Türkiye dışı)',
    aciklama: 'Türkiye dışındaki ülkelerin vakitleri, hicri takvimi ve '
        'hesaplama yöntemleri bu servisten alınır. Türkiye\'de yalnızca resmî '
        'Diyanet verisi bulunmayan yerleşimlerde, açıkça etiketlenmiş '
        'hesaplanmış saatler için kullanılır. API anahtarı veya üyelik '
        'gerektirmez.',
    lisans: 'Ücretsiz kullanım',
    kaynak: 'Aladhan Prayer Times API',
    url: 'https://aladhan.com/prayer-times-api',
    ceviriEki: 'license_aladhan',
    lisansAnahtari: 'license_aladhan_terms',
  ),
  LisansGirdisi(
    baslik: 'Kur’an Çevirileri',
    aciklama: 'Ayet metinleri ve çevirileri bu servisten alınır. Her '
        'çevirinin kendi kaynağı vardır.',
    lisans: 'Çeviri başına kaynaklı',
    kaynak: 'AlQuran Cloud',
    url: 'https://alquran.cloud',
    ceviriEki: 'license_quran',
    lisansAnahtari: 'license_quran_terms',
  ),
];

/// ODbL-1.0 kopyalaç lisansı nedeniyle uygulanması gereken açıklama.
///
/// ODbL, veritabanı türevlerinin kaynağını belirtmeyi zorunlu kılar. Bu
/// metin uygulama içinde de görünmelidir; README'deki atıf tek başına
/// yeterli değildir.
///
/// NOT: Bu sabit Türkçe kaynak metindir ve `test/lisans_test.dart` bunun
/// üzerinden ölçüm yapar. Ekranda 25 dilde gösterilen hâli
/// `license_odbl_notice` çeviri anahtarından gelir; çeviri dosyası
/// yüklenemezse bu sabit yedek olarak kalır.
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
///
/// NOT: Ekranda 25 dilde gösterilen hâli `license_geonames_notice` çeviri
/// anahtarından gelir; bu sabit Türkçe kaynak metindir.
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
