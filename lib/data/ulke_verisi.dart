// lib/data/ulke_verisi.dart
//
// Ulke ve sehir verisinin yuklenmesinden sorumlu katman.
//
// VERI KAYNAGI
//   dr5hn/countries-states-cities-database (ODbL-1.0)
//   https://github.com/dr5hn/countries-states-cities-database
//   Uretim: tool/veri_uretici.dart
//
// NEDEN KOORDINAT SAKLANIYOR?
//   Aladhan'in calendarByCity uc noktasi dahili bir geocoder kullanir ve
//   kucuk sehirleri cozumleyemez (HTTP 503 "Geocoding is temporarily
//   unavailable"). calendar uc noktasi koordinat kabul eder ve bu kisitta
//   kalmaz. Ayrica meta.timezone de dogru dondugu icin vakit hesabinda
//   saat dilimi kaymalari onlenir.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Bir ulke. Ayarlar sayfasindaki ulke seciminde gosterilir.
class Ulke {
  final String iso2; // ISO 3166-1 alpha-2, orn. "TR"
  final String iso3;
  final String ad; // Ingilizce ad, orn. "Turkey"
  final String adTr; // Turkce ad, orn. "Turkiye"
  final String bolge; // Europe / Americas / Asia / Africa
  final String? altBolge;
  final String? baskent;
  final String? paraBirimi;
  final String? telefonKodu;
  final String? emoji;
  final int sehirSayisi;

  const Ulke({
    required this.iso2,
    required this.iso3,
    required this.ad,
    required this.adTr,
    required this.bolge,
    this.altBolge,
    this.baskent,
    this.paraBirimi,
    this.telefonKodu,
    this.emoji,
    required this.sehirSayisi,
  });

  factory Ulke.fromJson(Map<String, dynamic> j) => Ulke(
        iso2: j['iso2'] as String,
        iso3: (j['iso3'] as String?) ?? '',
        ad: j['ad'] as String,
        adTr: (j['adTr'] as String?) ?? j['ad'] as String,
        bolge: j['bolge'] as String,
        altBolge: j['altBolge'] as String?,
        baskent: j['baskent'] as String?,
        paraBirimi: j['paraBirimi'] as String?,
        telefonKodu: j['telefonKodu'] as String?,
        emoji: j['emoji'] as String?,
        sehirSayisi: (j['sehirSayisi'] as int?) ?? 0,
      );

  /// Ara yuzde Turkce gosterilecek ad. Ceviri yoksa Turkceye yakin bir
  /// yedek ad uretir.
  String gorunenAd(String dilKodu) {
    if (dilKodu == 'tr') return adTr;
    return ad;
  }

  /// Bolge adinin Turkce karsiligi.
  static String bolgeAdiTr(String bolge) => switch (bolge) {
        'Europe' => 'Avrupa',
        'Americas' => 'Amerika',
        'Asia' => 'Asya',
        'Africa' => 'Afrika',
        'Oceania' => 'Okyanusya',
        _ => bolge,
      };

  static String bolgeAdiEn(String bolge) => switch (bolge) {
        'Europe' => 'Europe',
        'Americas' => 'Americas',
        'Asia' => 'Asia',
        'Africa' => 'Africa',
        'Oceania' => 'Oceania',
        _ => bolge,
      };

  String bolgeAdi(String dilKodu) => bolgeAdiStatik(bolge, dilKodu);

  /// Bölge adını dile göre çevirir (statik kullanım için).
  static String bolgeAdiStatik(String bolge, String dilKodu) =>
      dilKodu == 'tr' ? bolgeAdiTr(bolge) : bolgeAdiEn(bolge);
}

/// Bir sehir. Aladhan'a sorgu yaparken KOORDINAT kullanilir.
class Sehir {
  final String ad;
  final double enlem;
  final double boylam;

  const Sehir({required this.ad, required this.enlem, required this.boylam});

  /// "41.9786|34.0110|Abana" satirini cozer.
  factory Sehir.satirdan(String satir) {
    final parca = satir.split('|');
    return Sehir(
      ad: parca.length > 2 ? parca[2] : '',
      enlem: double.parse(parca[0]),
      boylam: double.parse(parca[1]),
    );
  }

  /// Aladhan sorgusu icin gerekli parametreler.
  ///
  /// [method] null oldugunda parametre hic gonderilmez; Aladhan bunu
  /// ulkeye gore dogru varsayilanla doldurur (TR->Diyanet, US->ISNA,
  /// EG->Misir, SA->Umm al-Qura, ID->KEMENAG, FR->UOIF, TN->Tunus ...).
  /// 245 ulke icin elle yontem tablosu tutmaktan hem daha dogru hem daha
  /// surdurulebilirdir. Kullanici Ayarlar'dan yontem secerse [method] dolu
  /// gider ve o deger kullanilir.
  Map<String, String> aladhanParametreleri({
    required int yil,
    required int ay,
    int? method,
  }) {
    final p = <String, String>{
      'latitude': enlem.toStringAsFixed(4),
      'longitude': boylam.toStringAsFixed(4),
      'month': ay.toString(),
      'year': yil.toString(),
    };
    if (method != null) p['method'] = method.toString();
    return p;
  }

  @override
  String toString() => '$ad ($enlem, $boylam)';
}

/// Ulke ve sehir verisini yukleyen merkezi sinif.
///
/// - Ulke listesi bir kez okunur ve bellege tutulur.
/// - Sehir listesi yalnizca secilen ulke icin okunur, onbellege alinir.
///   Boylece uygulama acilista yalnizca 59 KB ulke verisi yuklenir; en
///   kalabalik ulke dosyasi (ABD) bile 334 KB'dir.
class UlkeVerisi {
  UlkeVerisi._();

  static final UlkeVerisi instance = UlkeVerisi._();

  List<Ulke>? _ulkeler;
  final Map<String, List<Sehir>> _sehirOnbellegi = {};

  /// Tum ulkeler (bolge, sonra Turkce ada gore sirali).
  Future<List<Ulke>> ulkeler() async {
    if (_ulkeler != null) return _ulkeler!;
    final metin = await rootBundle.loadString('assets/veri/ulkeler.json');
    final liste = (json.decode(metin) as List).cast<Map<String, dynamic>>();
    _ulkeler = liste.map(Ulke.fromJson).toList(growable: false);
    return _ulkeler!;
  }

  /// Belirli bir ulkenin sehirlerini getirir (onbellekli).
  ///
  /// [onbellek] false ise dosyayi yeniden okur; bu, ulke degistiginde
  /// gecmise donuk veri kullanilmasini engeller.
  Future<List<Sehir>> sehirler(String iso2, {bool onbellek = true}) async {
    if (onbellek) {
      final varolan = _sehirOnbellegi[iso2];
      if (varolan != null) return varolan;
    }
    try {
      final metin = await rootBundle.loadString('assets/veri/sehirler/$iso2.txt');
      final liste = metin
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map(Sehir.satirdan)
          .toList(growable: false);
      _sehirOnbellegi[iso2] = liste;
      return liste;
    } catch (_) {
      // Veri dosyasi yoksa bos liste don; cagiran taraf bunu yonetmeli.
      return const [];
    }
  }

  /// Onbellekteki bir ulkenin sehirlerini anlik olarak verir.
  /// [sehirler] async oldugu icin bu, cift tarafsiz (dialog) ekranlarda
  /// senkron filtreleme yapabilmek icin kullanilir.
  List<Sehir>? onbellektekiSehirler(String iso2) => _sehirOnbellegi[iso2];

  /// Sehir adına göre arar. Türkçe karakterleri duyarsızlaştırır, böylece
  /// "suleyman" yazan kullanıcı "Süleyman" bulur.
  ///
  /// Çevrimdışı: nokta, tırnak ve tire gibi ayırıcı işaretler temizlenir;
  /// çünkü veri setinde "St. John's", "Côte d'Ivoire" gibi yazımlar var.
  static List<Sehir> ara(List<Sehir> kaynak, String sorgu, {int enFazla = 300}) {
    final temiz = normalize(sorgu);
    if (temiz.isEmpty) {
      return kaynak.take(enFazla).toList(growable: false);
    }
    final sonuc = <Sehir>[];
    for (final s in kaynak) {
      if (normalize(s.ad).contains(temiz)) {
        sonuc.add(s);
        if (sonuc.length >= enFazla) break;
      }
    }
    return sonuc;
  }

  /// Ülke adına göre arar. Hem Türkçe hem İngilizce ada ve ISO kodlarına
  /// bakar, böylece kullanıcı hangi dili tercih ederse etsin sonuç bulur.
  static List<Ulke> ulkeAra(List<Ulke> kaynak, String sorgu) {
    final temiz = normalize(sorgu);
    if (temiz.isEmpty) return kaynak;
    return kaynak
        .where((u) =>
            normalize(u.adTr).contains(temiz) ||
            normalize(u.ad).contains(temiz) ||
            u.iso2.toLowerCase() == temiz ||
            u.iso3.toLowerCase() == temiz)
        .toList(growable: false);
  }

  /// Türkçe/Latin karakterlerini duyarsızlaştırıp arama için sadeleştirir.
  static String normalize(String s) {
    final buf = StringBuffer();
    for (final rune in s.toLowerCase().runes) {
      // Latin-1/Latin Extended ek harflerini temel harflere indirge:
      // ş->s, ğ->g, ı->i, ö->o, ü->u, ç->c, â->a, é->e vb.
      var r = rune;
      const ceviri = <int, int>{
        0x015F: 0x73, // ş
        0x011F: 0x67, // ğ
        0x0131: 0x69, // ı
        0x0130: 0x69, // İ
        0x00F6: 0x6F, 0x00F8: 0x6F, 0x00FC: 0x75, 0x00E7: 0x63, // ö ü ç
        0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61, 0x00E5: 0x61,
        0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65,
        0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69,
        0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F,
        0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75,
        0x00C7: 0x63, // Ç
        0x00D1: 0x6E, 0x00F1: 0x6E, // Ñ ñ
        0x015E: 0x73, 0x015B: 0x73, // Ş ş
        0x0159: 0x72, 0x0158: 0x72, // Ř ř
        0x0107: 0x63, 0x010D: 0x63, // Č č
        0x0111: 0x64, 0x011B: 0x65, // ē ė
        0x0142: 0x6C, 0x0141: 0x6C, // Ł ł
        0x017E: 0x7A, 0x017A: 0x7A, 0x0179: 0x7A, // Ž ž Ź
        0x016F: 0x75, 0x0170: 0x75, 0x0171: 0x75, // ů ű ű
      };
      if (ceviri.containsKey(r)) r = ceviri[r]!;
      // Nokta, tirnak, kesme, tire gibi ayirici isaretleri at
      if (r == 0x2E || r == 0x2C || r == 0x27 || r == 0x2019 || r == 0x2D ||
          r == 0x20 || r == 0x2013 || r == 0x2014) {
        continue;
      }
      buf.writeCharCode(r);
    }
    return buf.toString();
  }
}
