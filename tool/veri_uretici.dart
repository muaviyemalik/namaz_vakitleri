// Uygulamanin kullandigi ulke/sehir verisini uretir.
//
// KAYNAK: dr5hn/countries-states-cities-database (ODbL-1.0)
//   https://github.com/dr5hn/countries-states-cities-database
//   -> json/countries+states+cities.json  (ulke -> eyalet -> sehir + koordinat)
//
// CIKTILAR:
//   assets/veri/ulkeler.json          -> ulke metadata'si (ayarlar sayfasindaki
//                                         ulke secimi icin)
//   assets/veri/sehirler/<ISO2>.txt   -> ulke basina sehir listesi + koordinat
//                                         (satir basina: enlem|boylam|sehirAdi)
//
// NEDEN KOORDINAT?
// Aladhan API'nin calendarByCity uc noktasi dahili bir geocoder kullanir ve
// 148 binlik veri setindeki kucuk sehirlerin cogunu cozumleyemez; boyle
// istekler HTTP 503 "Geocoding is temporarily unavailable" doner.calendar
// uc noktasi koordinatla sorguladigi icin bu kisitta kalmaz. Ayrica
// meta.timezone de dogru geldigi icin vakit hesabinda saat dilimi
// kaymalari da ortadan kalkar.
//
// KULLANIM:
//   dart run tool/veri_uretici.dart <kaynak-json-yolu>

import 'dart:convert';
import 'dart:io';

/// Uygulamanin destekledigi bolgeler: Avrupa, Amerika, Asya, Afrika ve
/// Okyanusya. Kutup bolgeleri (Polar) ve Antarktika kapsam disarida.
const Set<String> istenenBolgeler = {
  'Europe',
  'Americas',
  'Asia',
  'Africa',
  'Oceania',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Kullanim: dart run tool/veri_uretici.dart <kaynak-json>');
    exit(64);
  }
  final kaynak = File(args[0]);
  if (!kaynak.existsSync()) {
    stderr.writeln('Kaynak dosya bulunamadi: ${kaynak.path}');
    exit(66);
  }

  final veriDir = Directory('assets/veri');
  final sehirDir = Directory('assets/veri/sehirler');
  if (sehirDir.existsSync()) sehirDir.deleteSync(recursive: true);
  sehirDir.createSync(recursive: true);

  stdout.writeln('Kaynak okunuyor: ${kaynak.path}');
  final ham = kaynak.readAsStringSync(encoding: utf8);
  final tum = (json.decode(ham) as List).cast<Map<String, dynamic>>();
  stdout.writeln('  ${tum.length} ulke, ${(ham.length / 1048576).toStringAsFixed(1)} MB');

  final ulkeler = <Map<String, dynamic>>[];
  final atlananlar = <String>[];
  var toplamSehir = 0;
  var dosyaBayt = 0;

  for (final u in tum) {
    final bolge = u['region'] as String?;
    if (bolge == null || !istenenBolgeler.contains(bolge)) continue;

    final iso2 = u['iso2'] as String?;
    if (iso2 == null || iso2.isEmpty || iso2.length != 2) continue;

    // --- Sehirleri topla (eyalet -> sehir duzeyine ac) ---
    final satirlar = <String>[];
    for (final s in (u['states'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      for (final c in (s['cities'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final ad = (c['name'] as String?)?.trim();
        if (ad == null || ad.isEmpty) continue;

        // DIKKAT: Bu dosyada koordinatlar JSON metni olarak saklaniyor, yani
        // degerler "36.99757530" gibi String geliyor (sayi degil). Onceki surum
        // `lat is! num` diye kontrol ettigi icin TUM sehirleri eliyordu ve
        // uretilen dosyalar tamamen bos kaliyordu.
        final lat = _sayiyaCevir(c['latitude']);
        final lon = _sayiyaCevir(c['longitude']);
        if (lat == null || lon == null) continue;
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        satirlar.add('${_koord(lat)}|${_koord(lon)}|$ad');
      }
    }

    // Sehir verisi olmayan kucuk yerlesimler (Vatikan, Gibraltar, vb.):
    // baskentinin adini ve ulke merkez koordinatini kullanarak bosluk birakma.
    if (satirlar.isEmpty) {
      final baskent = (u['capital'] as String?)?.trim();
      final lat = _sayiyaCevir(u['latitude']);
      final lon = _sayiyaCevir(u['longitude']);
      if (baskent != null && baskent.isNotEmpty && lat != null && lon != null) {
        satirlar.add('${_koord(lat)}|${_koord(lon)}|$baskent');
      }
    }

    // Hicbir sehir ve baskenti olmayan yerlesimler (ornegin "United States
    // Minor Outlying Islands" - kalici nufusu olmayan ABD bolgesi). Boyle bir
    // kayit secici menusunde anlamsiz gorunecegi icin tamamen cikariliyor.
    if (satirlar.isEmpty) {
      atlananlar.add('${u['name']} (${iso2})');
      continue;
    }

    // Ayni isimli sehirler icin enlem/boylam ayniysa tekillestir
    final tekil = <String, String>{};
    for (final s in satirlar) {
      final parca = s.split('|');
      final anahtar = parca[2];
      tekil.putIfAbsent(anahtar, () => s);
    }
    final sirali = tekil.values.toList()
      ..sort((a, b) => a.split('|')[2].toLowerCase().compareTo(b.split('|')[2].toLowerCase()));

    final icerik = '${sirali.join('\n')}\n';
    final dosya = File('${sehirDir.path}/$iso2.txt');
    dosya.writeAsStringSync(icerik, encoding: utf8);
    dosyaBayt += icerik.length;
    toplamSehir += sirali.length;

    // --- Ulke metadata'si ---
    final ceviriler = (u['translations'] as Map?)?.cast<String, dynamic>() ?? const {};
    ulkeler.add({
      'iso2': iso2,
      'iso3': u['iso3'],
      'ad': u['name'],
      'adTr': ceviriler['tr'] ?? u['name'],
      'bolge': bolge,
      'altBolge': u['subregion'],
      'baskent': u['capital'],
      'paraBirimi': u['currency'],
      'telefonKodu': u['phonecode'],
      'emoji': u['emoji'],
      'sehirSayisi': sirali.length,
    });
  }

  // Bolgeye, sonra ada gore sirala
  ulkeler.sort((a, b) {
    final r = (a['bolge'] as String).compareTo(b['bolge'] as String);
    if (r != 0) return r;
    return (a['adTr'] as String).toLowerCase().compareTo((b['adTr'] as String).toLowerCase());
  });

  final ulkelerJson = '${const JsonEncoder.withIndent('  ').convert(ulkeler)}\n';
  File('${veriDir.path}/ulkeler.json').writeAsStringSync(ulkelerJson, encoding: utf8);

  stdout.writeln('');
  stdout.writeln('SONUC');
  stdout.writeln('  ulke           : ${ulkeler.length}');
  stdout.writeln('  sehir          : $toplamSehir');
  stdout.writeln('  ulkeler.json   : ${(ulkelerJson.length / 1024).toStringAsFixed(0)} KB');
  stdout.writeln('  sehirler/      : ${(dosyaBayt / 1048576).toStringAsFixed(2)} MB '
      '(${sehirDir.listSync().length} dosya)');
  if (atlananlar.isNotEmpty) {
    stdout.writeln('  atlanan        : ${atlananlar.join(", ")}');
  }

  // Bolge bazinda ozet
  stdout.writeln('');
  stdout.writeln('  bolge bazinda:');
  final bolgeToplam = <String, ({int ulke, int sehir})>{};
  for (final u in ulkeler) {
    final b = u['bolge'] as String;
    final mevcut = bolgeToplam[b] ?? (ulke: 0, sehir: 0);
    bolgeToplam[b] = (ulke: mevcut.ulke + 1, sehir: mevcut.sehir + (u['sehirSayisi'] as int));
  }
  for (final e in bolgeToplam.entries) {
    stdout.writeln('    ${e.key.padRight(10)} ${e.value.ulke.toString().padLeft(4)} ulke  '
        '${e.value.sehir.toString().padLeft(7)} sehir');
  }
}

/// Koordinati 4 ondaliga yuvarlar (~11 metre hassasiyet). Namaz vakitleri
/// icin bu fazlasiyla yeterli ve dosya boyutunu belirgin azaltir.
String _koord(num v) => v.toStringAsFixed(4);

/// Kaynak JSON'da koordinatlar metin olarak saklandigi icin guvenli sekilde
/// sayiya ceviriyoruz. Hatali veya bos degerler null doner.
double? _sayiyaCevir(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}
