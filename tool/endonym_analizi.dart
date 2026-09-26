// ignore_for_file: avoid_print, constant_identifier_names
// GeoNames'in kanalonik adi yerel endonym yerine Ingilizce/internasyonel
// ad olarak sakladigi durumlari tespit eder.
//
// SORUN
//   GeoNames "name" kolonu bazen yerel adi degil uluslararasi adi tutar:
//     Almanya/Muenih -> "Munich" (dogru yazim: "Munchen")
//     Yunanistan/Athina -> "Athens" (dogru yazim: "Athina")
//     Macaristan/Budapest -> "Budapest"
//   Bu durumda yerel dili konusan kullanici kendi dilinde yazip sehiri
//   bulamaz. Ornegin Almanca "Munchen" yazan kullanici "Munich" kaydini
//   bulamaz; cunku normalize "munchen" ile "munich"i eslestirmez.
//
// KAPSAM
//   Asagidaki esleme tablosu resmi kaynak DEGILDIR; kullanicinin hangi
//   bicimde yazmayi alistigi sehirleri temsil eder. Analiz yalnizca bu
//   tablo uzerinden calisir ve resmi olmayan bir cikarim yapmaz.
import 'dart:convert';
import 'dart:io';

const _AD = 1;
const _ULKE = 8;
const _NUFUS = 14;

/// ulke -> {GeoNames'teki uluslararasi ad : kullaniciya gore yerel ad}
const Map<String, Map<String, String>> endonymler = {
  'DE': {
    'Munich': 'München',
    'Cologne': 'Köln',
    'Hanover': 'Hannover',
    'Nuremberg': 'Nürnberg',
  },
  'IT': {
    'Milan': 'Milano',
    'Venice': 'Venezia',
    'Florence': 'Firenze',
    'Naples': 'Napoli',
    'Rome': 'Roma',
    'Turin': 'Torino',
    'Genoa': 'Genova',
  },
  'ES': {
    'Seville': 'Sevilla',
    'Gijon': 'Gijón',
    'Saragossa': 'Zaragoza',
    'Cordoba': 'Córdoba',
  },
  'PT': {'Lisbon': 'Lisboa'},
  'GR': {
    'Athens': 'Athenai',
    'Thessaloniki': 'Thessaloniki',
  },
  'AT': {'Vienna': 'Wien'},
  'CZ': {
    'Prague': 'Praha',
    'Ostrava': 'Ostrava',
  },
  'CH': {
    'Zurich': 'Zürich',
    'Geneva': 'Genève',
  },
  'BE': {
    'Brussels': 'Brussel',
    'Antwerp': 'Antwerpen',
    'Ghent': 'Gent',
  },
  'PL': {
    'Warsaw': 'Warszawa',
    'Krakow': 'Kraków',
    'Gdansk': 'Gdańsk',
    'Wroclaw': 'Wrocław',
    'Poznan': 'Poznań',
  },
  'SE': {
    'Gothenburg': 'Göteborg',
    'Malmo': 'Malmö',
  },
  'TR': {
    'Istanbul': 'İstanbul',
    'Izmir': 'İzmir',
  },
  'MY': {'Penang': 'Pulau Pinang'},
  'EG': {
    'Alexandria': 'Al Iskandariyah',
    'Giza': 'Al Jizah',
  },
  'SA': {
    'Mecca': 'Makkah',
    'Medina': 'Madinah',
    'Jeddah': 'Jiddah',
  },
  'IR': {
    'Esfahan': 'Isfahan',
    'Mashhad': 'Mashhad',
  },
  'BD': {'Chittagong': 'Chattogram'},
};

void main() {
  final appUlkeler = (json.decode(
          File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();
  final appIso2 = appUlkeler.map((u) => u['iso2'] as String).toSet();

  final geo = <String, List<List<String>>>{};
  for (final s in File(
          r'C:\Users\malik\AppData\Local\Temp\opencode\geonames\cities15000.txt')
      .readAsLinesSync(encoding: utf8)) {
    final p = s.split('\t');
    if (p.length <= _NUFUS) continue;
    if (!appIso2.contains(p[_ULKE])) continue;
    (geo[p[_ULKE]] ??= []).add(p);
  }
  print('GeoNames uygulama ulkelerinde: ${geo.length} ulke');
  print('');

  var toplamSorun = 0;
  for (final e in geo.entries) {
    final liste = List<List<String>>.of(e.value)
      ..sort((a, b) => (int.tryParse(b[_NUFUS]) ?? 0)
          .compareTo(int.tryParse(a[_NUFUS]) ?? 0));
    final geoAdlar = liste.take(30).map((g) => g[_AD].toLowerCase()).toSet();
    final ciftler = endonymler[e.key];
    if (ciftler == null) continue;

    final sorunlu = <String>[];
    ciftler.forEach((uluslararasi, yerel) {
      final uluslararasiVar = geoAdlar.contains(uluslararasi.toLowerCase());
      final yerelVar = geoAdlar.contains(yerel.toLowerCase());
      if (uluslararasiVar && !yerelVar) {
        sorunlu.add('$yerel  (GeoNames: $uluslararasi)');
      }
    });

    if (sorunlu.isNotEmpty) {
      print('${e.key} (${e.value.length} kayit, en buyuk 30 incelendi):');
      for (final s in sorunlu) {
        print('   $s');
      }
      toplamSorun += sorunlu.length;
    }
  }
  print('');
  print('TOPLAM: $toplamSorun sehir icin veride yalnizca uluslararasi ad var');
}
