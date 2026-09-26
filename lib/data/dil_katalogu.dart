// lib/data/dil_katalogu.dart
//
// 245 ulkenin resmi dillerine ait dil katalogu ve arayuz yonlendirmesi.
//
// URETIM: tool/dil_katalogu_uret.dart
//   - ulke -> dil iliskisi: mledoze/countries (Unlicense)
//   - otokton adlar + 639-1/639-2 eslemesi: haliaeetus/iso-639
//   CIKTI: assets/i18n/diller.json
//
// NEDEN BU KADAR CIFT KATMANLI?
//   - 152 resmi dil var; uygulamanin destekledigi bunlarin hepsi degil.
//     Sadece ceviri dosyasi olan diller secicide gorunur (hazirDiller).
//   - Arapca, Farsca, Urduca, Ibranice, Arapca (Aramice), Dhivehi, Pestuca
//     sagdan sola yazilir. Flutter varsayilan olarak hep soldan saga
//     kurar; bu dillerde arayuz okunamaz hale gelir. Bu yuzden yon
//     bilgisi katalogda tasinir ve MaterialApp cevresinde uygulanir.

import 'dart:convert';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart' show rootBundle;
// TextDirection `dart:ui` tarafindadir; material.dart uzerinden gelmez.
import 'dart:ui' show TextDirection;

/// Bir dil.
class Dil {
  final String kod; // ISO 639-2/3 (katalog ve ceviri dosyalari bu kodla eslesir)
  final String? iso1; // ISO 639-1 (2 harf)
  final String ad; // Ingilizce ad
  final String? otoktonAd; // Kendi dilindeki adi (yoksa null)
  final String? aile; // Dil ailesi (Hint-Avrupa, Afro-Asiatik...)
  final bool rtl; // Soldan saga mi, sagdan sola mi
  final int ulkeSayisi;
  final List<String> ulkeler; // Bu dili resmi olarak kullanan ISO2 kodlari

  const Dil({
    required this.kod,
    this.iso1,
    required this.ad,
    this.otoktonAd,
    this.aile,
    required this.rtl,
    required this.ulkeSayisi,
    required this.ulkeler,
  });

  factory Dil.fromJson(Map<String, dynamic> j) => Dil(
        kod: j['kod'] as String,
        iso1: j['iso1'] as String?,
        ad: j['ad'] as String,
        otoktonAd: j['otoktonAd'] as String?,
        aile: j['aile'] as String?,
        rtl: j['rtl'] as bool? ?? false,
        ulkeSayisi: (j['ulkeSayisi'] as int?) ?? 0,
        ulkeler: (j['ulkeler'] as List?)?.cast<String>() ?? const [],
      );

  /// Dil secicide gosterilen ad. Oncelik otokton ad (kullanici kendi
  /// dilini tanir), yoksa Ingilizce ad.
  String gorunenAd() => otoktonAd ?? ad;

  /// easy_localization'in bekledigi Locale.
  ///
  /// ONEMLI: Ceviri dosyalari 3 harfli kodla adlandirilmis (tur.json, ara.json)
  /// ama easy_localization Locale.languageCode'u dosya adindan turetir. Bu
  /// yuzden iki harfli ISO kodu olan diller icin 3 harfli kod tercih edilir.
  /// Boylece hem dosya adi hem katalog kodu ayni kalir.
  Locale locale() => Locale(kod);

  TextDirection get yon => rtl ? TextDirection.rtl : TextDirection.ltr;
}

/// Dil katalogu. Uygulama acilisinda bir kez yuklenir.
class DilKatalogu {
  DilKatalogu._(this.diller, this.hazirDiller);

  final List<Dil> diller;

  /// Ceviri dosyasi olan dillerin kodlari. Dil secici yalnizca bunlari gosterir.
  final List<String> hazirDiller;

  /// Testler icin: katalogu dogrudan veriyle kurar. Uygulama kodunda
  /// kullanilmaz; `flutter test` rootBundle saglamadigi icin gereklidir.
  factory DilKatalogu.testIcin(
    List<Map<String, dynamic>> diller,
    List<String> hazirDiller,
  ) =>
      DilKatalogu._(diller.map(Dil.fromJson).toList(growable: false), hazirDiller);

  static DilKatalogu? _onbellek;

  /// Katalogu yukler. Uygulama acilisinda cagrilir; sonra [ornek] uzerinden
  /// senkron erisim saglanir.
  static Future<DilKatalogu> yukle() async {
    if (_onbellek != null) return _onbellek!;
    final metin = await rootBundle.loadString('assets/i18n/diller.json');
    final g = json.decode(metin) as Map<String, dynamic>;
    final liste = (g['diller'] as List).cast<Map<String, dynamic>>();
    final hazir = (g['hazirDiller'] as List?)?.cast<String>() ?? const [];
    _onbellek = DilKatalogu._(
      liste.map(Dil.fromJson).toList(growable: false),
      hazir,
    );
    return _onbellek!;
  }

  static DilKatalogu get ornek {
    final k = _onbellek;
    if (k == null) {
      throw StateError(
          'DilKatalogu.yukle() cagrilmadan once katalog kullanilamaz. '
          'main() icinde await DilKatalogu.yukle() yapin.');
    }
    return k;
  }

  // NOT: Statik uyede `get` anahtarı ZORUNLUDUR. `static bool yuklendiMi => ...`
  // yazılırsa Dart bunu parametre listesi olmayan bir metot bildirimi olarak
  // yorumlar ve "missing_method_parameters" hatası verir. Instance getter'da
  // `get` opsiyoneldir, statik getter'da değildir.
  static bool get yuklendiMi => _onbellek != null;

  /// Cevirisi hazir diller (katalog sirasinda: en yaygin ulke sayisi).
  List<Dil> get ceviriliDiller =>
      diller.where((d) => hazirDiller.contains(d.kod)).toList(growable: false);

  /// easy_localization'a verilecek Locale listesi. Cevirisi olmayan diller
  /// buraya girmez; aksi halde o dilde tum metinler bos gorunur.
  List<Locale> get desteklenenYereller =>
      ceviriliDiller.map((d) => d.locale()).toList(growable: false);

  Dil? kodaGore(String kod) {
    for (final d in diller) {
      if (d.kod == kod || d.iso1 == kod) return d;
    }
    return null;
  }

  /// Verilen ulkenin resmi dillerinden cevirisi hazir olanlar.
  /// Kullanicinin secili ulkeye uygun dil onerisi uretmek icin kullanilir.
  List<Dil> ulkeninDilleri(String iso2) => diller
      .where((d) => d.ulkeler.contains(iso2) && hazirDiller.contains(d.kod))
      .toList(growable: false);

  /// Bu kod sagdan sola mi yaziliyor?
  bool rtlMi(String kod) => kodaGore(kod)?.rtl ?? false;

  /// Locale icin yon.
  TextDirection yon(Locale locale) {
    final d = kodaGore(locale.languageCode);
    return (d?.rtl ?? false) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Arama: otokton ad, Ingilizce ad veya ISO koduna gore.
  /// Turkce karakterleri indirger, boylece "turkce" yazan da Turkce'yi bulur.
  static List<Dil> ara(List<Dil> kaynak, String sorgu) {
    final q = _normalize(sorgu);
    if (q.isEmpty) return kaynak;
    return kaynak.where((d) {
      return _normalize(d.ad).contains(q) ||
          (d.otoktonAd != null && _normalize(d.otoktonAd!).contains(q)) ||
          d.kod.toLowerCase() == q ||
          (d.iso1?.toLowerCase() == q);
    }).toList(growable: false);
  }

  static String _normalize(String s) {
    final buf = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      const ceviri = <int, int>{
        0x015F: 0x73, 0x011F: 0x67, 0x0131: 0x69, 0x0130: 0x69, // s g i I
        0x00F6: 0x6F, 0x00F8: 0x6F, 0x00FC: 0x75, 0x00E7: 0x63, // o u c
        0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61, 0x00E5: 0x61,
        0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65,
        0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69,
        0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F,
        0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75,
        0x00C7: 0x63, 0x00D1: 0x6E, 0x00F1: 0x6E,
        0x015E: 0x73, 0x015B: 0x73, 0x0159: 0x72, 0x0158: 0x72,
        0x0107: 0x63, 0x010D: 0x63, 0x0111: 0x64, 0x0142: 0x6C,
        0x017E: 0x7A, 0x017A: 0x7A, 0x0179: 0x7A,
        0x016F: 0x75, 0x0170: 0x75, 0x0171: 0x75,
      };
      var x = r;
      if (ceviri.containsKey(x)) x = ceviri[x]!;
      if (x == 0x2E || x == 0x2C || x == 0x27 || x == 0x2D || x == 0x20) {
        continue;
      }
      buf.writeCharCode(x);
    }
    return buf.toString();
  }
}
