// ignore_for_file: avoid_print, constant_identifier_names
// Uygulamanin GUNCEL sehir verisinde bu 20 sehrin hangi yazimlarla
// bulundugunu denetler. endonym_analizi.dart yalnizca GeoNames'e bakar;
// asil soru, dr5hn birlesimi sonrasi uygulamada endonym var mi.
import 'dart:convert';
import 'dart:io';

const Map<String, Map<String, String>> denetlenecekler = {
  'AT': {'Vienna': 'Wien'},
  'BE': {'Brussels': 'Brussel', 'Antwerp': 'Antwerpen'},
  'CH': {'Geneva': 'Genève'},
  'CZ': {'Prague': 'Praha'},
  'DE': {'Munich': 'München', 'Nuremberg': 'Nürnberg'},
  'EG': {'Alexandria': 'Alexandria', 'Giza': 'Giza'},
  'GR': {'Athens': 'Athenai'},
  'IT': {
    'Milan': 'Milano',
    'Florence': 'Firenze',
    'Naples': 'Napoli',
    'Rome': 'Roma',
    'Turin': 'Torino',
    'Genoa': 'Genova',
  },
  'PL': {'Warsaw': 'Warszawa'},
  'PT': {'Lisbon': 'Lisboa'},
  'SA': {'Jeddah': 'Jeddah', 'Medina': 'Medinah', 'Mecca': 'Makkah'},
  'SE': {'Gothenburg': 'Göteborg'},
  'TR': {'Istanbul': 'İstanbul', 'Izmir': 'İzmir'},
};

void main() {
  var eksikEndonym = 0;
  var ciftKayit = 0;

  for (final uye in denetlenecekler.entries) {
    final iso = uye.key;
    final f = File('assets/veri/sehirler/$iso.txt');
    if (!f.existsSync()) {
      print('$iso: dosya yok');
      continue;
    }
    final adlar = f
        .readAsLinesSync(encoding: utf8)
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.split('|')[2])
        .toList();
    final normalizeEdilmis = adlar.map(normalize).toSet();

    print('--- $iso (${adlar.length} kayit) ---');
    uye.value.forEach((uluslararasi, yerel) {
      final nUluslararasi = normalize(uluslararasi);
      final nYerel = normalize(yerel);
      final uluslararasiVar = normalizeEdilmis.contains(nUluslararasi);
      final yerelVar = normalizeEdilmis.contains(nYerel);

      // Ayni sehir iki ayri kayit olarak mi var, yoksa tek kayit mi?
      final ayriKayit = uluslararasiVar && yerelVar;

      String durum;
      if (!uluslararasiVar && !yerelVar) {
        durum = 'HIKAYESIZ';
      } else if (ayriKayit) {
        durum = 'IKISI DE VAR (mukerrer riski)';
        ciftKayit++;
      } else if (yerelVar) {
        durum = 'endonym var';
      } else {
        durum = '>>> EKSIK: sadece uluslararasi ad';
        eksikEndonym++;
      }
      print('   ${yerel.padRight(14)} / ${uluslararasi.padRight(14)} : $durum');
    });
  }

  print('');
  print('Eksik endonym sayisi : $eksikEndonym');
  print('Cift kayit sayisi    : $ciftKayit');
}

/// Uygulamadaki UlkeVerisi.normalize ile ayni mantik. Araclardan
/// package:namaz_vakitleri yuklenemedigi icin burada tekrarlaniyor.
String normalize(String s) {
  final buf = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    var r = rune;
    const ceviri = <int, int>{
      0x015F: 0x73, 0x011E: 0x67, 0x011F: 0x67, 0x0131: 0x69, 0x0130: 0x69,
      0x015E: 0x73, 0x00F6: 0x6F, 0x00D6: 0x6F, 0x00FC: 0x75, 0x00DC: 0x75,
      0x00E7: 0x63, 0x00C7: 0x63, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61,
      0x00E5: 0x61, 0x00E0: 0x61, 0x00E1: 0x61, 0x00EE: 0x69, 0x00EF: 0x69,
      0x00EC: 0x69, 0x00ED: 0x69, 0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F,
      0x00F8: 0x6F, 0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75, 0x00E8: 0x65,
      0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65, 0x00D1: 0x6E, 0x00F1: 0x6E,
      0x0159: 0x72, 0x0158: 0x72, 0x0161: 0x73, 0x0165: 0x73, 0x0107: 0x63,
      0x010D: 0x63, 0x0111: 0x64, 0x011B: 0x65, 0x0142: 0x6C, 0x0141: 0x6C,
      0x017E: 0x7A, 0x017A: 0x7A, 0x0179: 0x7A, 0x017D: 0x7A, 0x016F: 0x75,
      0x0170: 0x75, 0x0171: 0x75, 0x0105: 0x61,
    };
    if (ceviri.containsKey(r)) r = ceviri[r]!;
    if (r == 0x2E || r == 0x2C || r == 0x27 || r == 0x2019 || r == 0x2D ||
        r == 0x20 || r == 0x2013 || r == 0x2014) {
      continue;
    }
    buf.writeCharCode(r);
  }
  return buf.toString();
}
