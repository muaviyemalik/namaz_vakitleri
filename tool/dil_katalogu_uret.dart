// Ulke -> resmi dil iliskisini cikarir ve dil katalogunu uretir.
//
// KAYNAKLAR:
//   1) mledoze/countries (Unlicense) -> `languages` alani ISO 639-2/3 kodlari
//      verir (ornegin "tur", "ara", "eng").
//   2) haliaeetus/iso-639 -> her dilin OTOKTON adini ve 639-1 <-> 639-2
//      eslemesini verir. Diyalogda "Deutsch / Almanca" seklinde gosterebilmek
//      icin bu sarttir.
//
// CIKTI: assets/i18n/diller.json
//   Her dil icin: kod (639-2), iso1 (639-1), Ingilizce ad, otokton ad, dil
//   ailesi, yazim yonu (RTL/LTR) ve resmi olarak kullanan ulkeler.
//
// KULLANIM:
//   dart run tool/dil_katalogu_uret.dart <mledoze-json> <iso639-json>

import 'dart:convert';
import 'dart:io';

/// ISO 639-1 kodlari icin sagdan sola (right-to-left) yazilan diller.
/// Arayuzun Directionality karari bunlara baglidir; bu liste CLDR
/// "scripts" verisinden turetilmistir.
const Set<String> rtlDiller = {
  'ara', 'arb', 'arc', 'azb', 'bal', 'bqi', 'div', 'fas', 'heb', 'khw',
  'kur', 'lrc', 'mzn', 'nqo', 'pnb', 'per', 'pus', 'snd', 'syr', 'urd',
  'yid',
};

/// Otokton adi dil secicide okunabilir hale getirir.
///
/// ISO 639 verisi bazi dillerde birden fazla isim veriyor:
///   Fransizca: "français, langue française"
///   Cinece   : "中文 (Zhongwěn), ??, ??"
/// Bunlar listede cok yer kaplar ve kullaniciyi yormamali; yalnizca birincil
/// adi (virgul veya parantezden onceki kisim) yeterlidir.
String _otoktonuTemizle(String s) {
  var sonuc = s.trim();
  final kes = <int>[sonuc.indexOf(','), sonuc.indexOf('('), sonuc.indexOf(';')];
  final ilk = kes.where((i) => i > 0).fold<int>(0, (a, b) => a == 0 ? b : (a < b ? a : b));
  if (ilk > 0) sonuc = sonuc.substring(0, ilk);
  return sonuc.trim();
}
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Kullanim: dart run tool/dil_katalogu_uret.dart '
        '<countries-json> <iso639-json>');
    exit(64);
  }
  final kaynak = File(args[0]);
  final isoKaynak = File(args[1]);
  if (!kaynak.existsSync() || !isoKaynak.existsSync()) {
    stderr.writeln('Kaynak dosya bulunamadi.');
    exit(66);
  }

  // --- ISO 639: otokton adlar ve 639-1 <-> 639-2 eslemesi ---
  final isoHam = (json.decode(isoKaynak.readAsStringSync(encoding: utf8)) as Map)
      .cast<String, dynamic>();
  final otoktonAd = <String, String>{}; // 639-2 -> nativeName
  final iso1Esleme = <String, String>{}; // 639-2 -> 639-1
  final aile = <String, String>{}; // 639-2 -> family
  for (final g in isoHam.values) {
    final kayit = (g as Map).cast<String, dynamic>();
    final iki = kayit['639-1'] as String?;
    final uc = kayit['639-2'] as String?;
    if (iki == null) continue;
    if (uc != null) {
      otoktonAd[uc] = _otoktonuTemizle((kayit['nativeName'] as String?) ?? '');
      aile[uc] = (kayit['family'] as String?) ?? '';
      iso1Esleme[uc] = iki;
    }
  }

  // Uygulamada olan ulkeler (assets/veri/ulkeler.json)
  final ulkeDosyasi = File('assets/veri/ulkeler.json');
  final bizimKodlar = <String>{};
  if (ulkeDosyasi.existsSync()) {
    final u = (json.decode(ulkeDosyasi.readAsStringSync(encoding: utf8)) as List)
        .cast<Map<String, dynamic>>();
    bizimKodlar.addAll(u.map((x) => x['iso2'] as String));
  } else {
    stderr.writeln('UYARI: assets/veri/ulkeler.json bulunamadi, tum ulkeler alindi.');
  }

  final kaynakVeri = (json.decode(kaynak.readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();

  // dil kodu -> {ingilizce adlar, ulkeler}
  final adlar = <String, Set<String>>{};
  final ulkeler = <String, List<String>>{};

  for (final u in kaynakVeri) {
    final cca2 = u['cca2'] as String?;
    if (cca2 == null || !bizimKodlar.contains(cca2)) continue;
    final langs = u['languages'];
    if (langs is! Map) continue;
    for (final e in langs.entries) {
      final kod = e.key as String;
      (adlar[kod] ??= <String>{}).add(e.value as String);
      (ulkeler[kod] ??= <String>[]).add(cca2);
    }
  }

  // Katalogu olustur
  final kodlar = ulkeler.keys.toList()..sort();
  final katalog = <Map<String, dynamic>>[];
  for (final k in kodlar) {
    final ulkeListesi = ulkeler[k]!..sort();
    final iso1 = iso1Esleme[k];
    katalog.add({
      'kod': k,
      'iso1': iso1,
      'ad': (adlar[k]!.toList()..sort()).first,
      // Otokton ad yoksa Ingilizce ada dusuyoruz; dil secicide okunabilir
      // kalmasi icin bos birim tercih ediyoruz.
      'otoktonAd': (otoktonAd[k]?.isNotEmpty ?? false) ? otoktonAd[k] : null,
      'aile': aile[k]?.isNotEmpty ?? false ? aile[k] : null,
      'rtl': rtlDiller.contains(k),
      'ulkeSayisi': ulkeListesi.length,
      'ulkeler': ulkeListesi,
    });
  }

  // Once en yaygin dillere gore sirala: dil secicide en faydali siralama bu.
  katalog.sort((a, b) {
    final f = (b['ulkeSayisi'] as int).compareTo(a['ulkeSayisi'] as int);
    if (f != 0) return f;
    return (a['kod'] as String).compareTo(b['kod'] as String);
  });

  final cikti = File('assets/i18n/diller.json');
  cikti.parent.createSync(recursive: true);

  // Ceviri dosyasi gercekten mevcut olan diller. Dil secici yalnizca bunlari
  // gosterir; boylece kullanici cevirisi olmayan bir dili secip bos ekranla
  // karsilasmaz. Listeyi kaynak kodda elle tutmak yerine dosya sisteminden
  // okuyoruz, boylece yeni ceviri eklendiginde liste kendiliginden guncellenir.
  final ceviriDir = Directory('assets/i18n/ceviri');
  final hazir = <String>[];
  if (ceviriDir.existsSync()) {
    for (final f in ceviriDir.listSync()) {
      if (f is File && f.path.endsWith('.json')) {
        hazir.add(f.uri.pathSegments.last.replaceAll('.json', ''));
      }
    }
  }
  hazir.sort();

  cikti.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'hazirDiller': hazir,
        'diller': katalog,
      })}\n',
      encoding: utf8);

  final rtlDizi = katalog.where((d) => d['rtl'] as bool).toList();

  stdout.writeln('SONUC');
  stdout.writeln('  resmi dil sayisi : ${katalog.length}');
  stdout.writeln('  RTL dil sayisi   : ${rtlDizi.length}');
  final otoktonlu = katalog.where((d) => d['otoktonAd'] != null).length;
  stdout.writeln('  otokton adi olan: $otoktonlu / ${katalog.length}');
  stdout.writeln('  cevirisi hazir  : ${hazir.length} (${hazir.join(", ")})');
  stdout.writeln('  cikti            : ${cikti.path} '
      '(${(cikti.lengthSync() / 1024).toStringAsFixed(0)} KB)');
  stdout.writeln('');
  stdout.writeln('En yaygin 15 dil:');
  for (final d in katalog.take(15)) {
    stdout.writeln('  ${(d['kod'] as String).padRight(5)} '
        '${(d['ad'] as String).padRight(22)} ${d['ulkeSayisi']} ulke');
  }
  stdout.writeln('');
  stdout.writeln('RTL diller:');
  for (final d in rtlDizi) {
    stdout.writeln('  ${(d['kod'] as String).padRight(5)} '
        '${(d['ad'] as String).padRight(22)} ${d['ulkeSayisi']} ulke');
  }
}
