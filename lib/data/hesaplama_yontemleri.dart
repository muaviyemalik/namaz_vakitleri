// lib/data/hesaplama_yontemleri.dart
//
// Aladhan API'nin destekledigi resmi namaz vakti hesaplama yontemleri.
//
// NEDEN BU KADAR ONEMLI?
// Ayni konum icin hesaplama yontemi degistiginde vakitler kayar. Olculen
// degerler (Eylul 2026, method=13 Diyanet karsilastirmasiyla):
//   Paris   -> Fajr 38 dakika, Isha 31 dakika farkli
//   New York-> Fajr 16 dakika, Isha 11 dakika farkli
//   Suudi Arabistan -> Isha 19 dakika farkli
// Isha'daki 20-30 dakikalik sapma, camiye gidip namaz kilan kullanici icin
// ciddi sonuc degistirir.
//
import 'package:easy_localization/easy_localization.dart';

// NEDEN `ad` DEGIL DE `ceviriAdi`?
// Onceden yontem adi dogrudan `ad` alanindan gosteriliyordu; bu sabit bir
// Turkce metin oldugu icin 24 dilde Turkce kaliyordu. Artik her yontemin
// `yontem_<id>` anahtari 25 dil dosyasinda tanimlidir. `ad` alani KORUNUR:
// testler ve karsilastirmalar Turkce kaynak metni uzerinden calisir.
//
// Ayni sorun `parametreAciklama` icin de gecerliydi ("Fajr 18° · Isa 17°").
// O da artik ceviri anahtarlarindan kurulur.
//
// DIKKAT: Bu dosya veri KATMANIDIR; `easy_localization` bagimliligi
// eklendi. Ceviri dosyalari yuklenemedigi ortamda (unit test) `.tr()` ham
// anahtar adini dondurur. Bu yuzden `ad` ve `parametreAciklama` TRUNCATE
// edilmis Turkce yedek olarak durur ve ceviri cozulemedigi yerlerde
// gorunur; arayuzde ceviri COZULEMEDIGI icin anahtar adini gostermemek icin
// `ad` yedegi kullanilir.
//
// Bu yuzden uygulama iki sey yapar:
//   1) Varsayilan olarak method parametresini HIC GONDERMEZ. Aladhan
//      parametreyi almayinca ulkeye gore dogru varsayilani kendisi secer
//      (Turkiye->Diyanet, ABD->ISNA, Misir->Misir, Suudi->Umm al-Qura,
//      Endonezya->KEMENAG, Malezya->JAKIM, Fransa->UOIF, Tunus->Tunus ...).
//   2) Kullaniciya Ayarlar menusunden yontem secme hakki verir. Cunku
//      "dogru" yontem ulkeye gore degil, kullanicinin takip ettigi camiye
//      ve mezhebe gore degisir; bu yalnizca kullanici bilebilir.

/// Bir hesaplama yöntemi.
class HesaplamaYontemi {
  final int id;
  final String ad; // Türkçe ad
  final String adEn; // İngilizce ad (API'de görünen)
  final String? fajrAci;
  final String? ishaAci;
  final String? ishaAralik;

  const HesaplamaYontemi({
    required this.id,
    required this.ad,
    required this.adEn,
    this.fajrAci,
    this.ishaAci,
    this.ishaAralik,
  });

  /// Kullanıcı diline çevrilmiş yöntem adı.
  ///
  /// `yontem_<id>` anahtarı 25 dil dosyasının tamamında tanımlıdır. Çeviri
  /// çözülemezse (birim testi, asset yüklenmemiş ortam) Türkçe `ad`
  /// döner; arayüzde ham anahtar adı gösterilmez.
  String get ceviriAdi {
    final String c = 'yontem_$id'.tr();
    return c == 'yontem_$id' ? ad : c;
  }

  /// Menüde gösterilen açıklama: "Fajr 18° · İşâ 17°"
  ///
  /// Açı/aralık değerleri dil bağımsızdır (sayı ve derece), ancak "Fajr"
  /// ve "İşâ" kelimeleri çevrilir. Aralık zamanı (örn. "90 dk") `adEn`
  /// kalıbını izleyerek dakika olarak okunur.
  String get parametreAciklama {
    final parcalar = <String>[];
    if (fajrAci != null) parcalar.add('parametre_fajr'.tr(args: [fajrAci!]));
    if (ishaAci != null) {
      parcalar.add('parametre_isha'.tr(args: [ishaAci!]));
    } else if (ishaAralik != null) {
      parcalar.add('parametre_isha_aralik'.tr(args: [ishaAralik!]));
    }
    return parcalar.join(' · ');
  }
}

/// Tüm resmi yöntemler. Kaynak: https://api.aladhan.com/v1/methods
const List<HesaplamaYontemi> hesaplamaYontemleri = [
  HesaplamaYontemi(
      id: 3,
      ad: 'İslam Dünya Birliği (MWL)',
      adEn: 'Muslim World League',
      fajrAci: '18',
      ishaAci: '17'),
  HesaplamaYontemi(
      id: 2,
      ad: 'Kuzey Amerika İslam Toplumu (ISNA)',
      adEn: 'Islamic Society of North America',
      fajrAci: '15',
      ishaAci: '15'),
  HesaplamaYontemi(
      id: 5,
      ad: 'Mısır Genel Harita Otoritesi',
      adEn: 'Egyptian General Authority of Survey',
      fajrAci: '19.5',
      ishaAci: '17.5'),
  HesaplamaYontemi(
      id: 4,
      ad: 'Umm al-Qura Üniversitesi (Mekke)',
      adEn: 'Umm Al-Qura University, Makkah',
      fajrAci: '18.5',
      ishaAralik: '90 dk'),
  HesaplamaYontemi(
      id: 1,
      ad: 'İslam Bilimleri Üniversitesi (Karaçi)',
      adEn: 'University of Islamic Sciences, Karachi',
      fajrAci: '18',
      ishaAci: '18'),
  HesaplamaYontemi(
      id: 7,
      ad: 'Tahran Üniversitesi Jeofizik Enstitüsü',
      adEn: 'Institute of Geophysics, University of Tehran',
      fajrAci: '17.7',
      ishaAci: '14'),
  HesaplamaYontemi(
      id: 0,
      ad: 'Şiî İsnâcî (Kum Leva Enstitüsü)',
      adEn: 'Shia Ithna-Ashari, Leva Institute, Qum',
      fajrAci: '16',
      ishaAci: '14'),
  HesaplamaYontemi(
      id: 8,
      ad: 'Körfez Bölgesi',
      adEn: 'Gulf Region',
      fajrAci: '19.5',
      ishaAralik: '90 dk'),
  HesaplamaYontemi(
      id: 9, ad: 'Kuveyt', adEn: 'Kuwait', fajrAci: '18', ishaAci: '17.5'),
  HesaplamaYontemi(
      id: 10, ad: 'Katar', adEn: 'Qatar', fajrAci: '18', ishaAralik: '90 dk'),
  HesaplamaYontemi(
      id: 11,
      ad: 'Singapur İslam Kurumu (MUI)',
      adEn: 'Majlis Ugama Islam Singapura, Singapore',
      fajrAci: '20',
      ishaAci: '18'),
  HesaplamaYontemi(
      id: 12,
      ad: 'Fransa İslam Birliği (UOIF)',
      adEn: 'Union Organization Islamic de France',
      fajrAci: '12',
      ishaAci: '12'),
  HesaplamaYontemi(
      id: 13,
      ad: 'Diyanet İşleri Başkanlığı (Türkiye)',
      adEn: 'Diyanet Isleri Baskanligi, Turkey',
      fajrAci: '18',
      ishaAci: '17'),
  HesaplamaYontemi(
      id: 14,
      ad: 'Rusya Müslüman İşleri İdaresi',
      adEn: 'Spiritual Administration of Muslims of Russia',
      fajrAci: '16',
      ishaAci: '15'),
  HesaplamaYontemi(
      id: 16,
      ad: 'Dubai',
      adEn: 'Dubai (experimental)',
      fajrAci: '18.2',
      ishaAci: '18.2'),
  HesaplamaYontemi(
      id: 17,
      ad: 'Malezya İslam Gelişim Dairesi (JAKIM)',
      adEn: 'Jabatan Kemajuan Islam Malaysia (JAKIM)',
      fajrAci: '20',
      ishaAci: '18'),
  HesaplamaYontemi(
      id: 18, ad: 'Tunus', adEn: 'Tunisia', fajrAci: '18', ishaAci: '18'),
  HesaplamaYontemi(
      id: 19, ad: 'Cezayir', adEn: 'Algeria', fajrAci: '18', ishaAci: '17'),
  HesaplamaYontemi(
      id: 20,
      ad: 'Endonezya İslam Dairesi (KEMENAG)',
      adEn: 'Kementerian Agama Republik Indonesia',
      fajrAci: '20',
      ishaAci: '18'),
  HesaplamaYontemi(
      id: 21, ad: 'Fas', adEn: 'Morocco', fajrAci: '19', ishaAci: '17'),
  HesaplamaYontemi(
      id: 22,
      ad: 'Lizbon İslam Topluluğu',
      adEn: 'Comunidade Islamica de Lisboa',
      fajrAci: '18',
      ishaAralik: '77 dk'),
  HesaplamaYontemi(
      id: 23,
      ad: 'Ürdün Vakıflar Bakanlığı',
      adEn: 'Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan',
      fajrAci: '18',
      ishaAci: '18'),
];

/// Belirli bir kimliğe sahip yöntemi döndürür, yoksa null.
HesaplamaYontemi? yontemBul(int id) {
  for (final y in hesaplamaYontemleri) {
    if (y.id == id) return y;
  }
  return null;
}
