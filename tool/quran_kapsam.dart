// Secilen 25 dil ile AlQuran Cloud'un sundugu ceviri dillerini karsilastirir.
// Ayet metinlerinin hangi dillerde GERCEK kaynakli metinle
// doldurulabilecegini belirler.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Secilen diller ISO 639-2/3 (3 harfli), AlQuran Cloud ise ISO 639-1
/// (2 harfli) kullaniyor. Esleme sart.
const Map<String, String> ikiHarfli = {
  'amh': 'am', 'ara': 'ar', 'ben': 'bn', 'deu': 'de', 'eng': 'en',
  'fas': 'fa', 'fra': 'fr', 'ind': 'id', 'ita': 'it', 'jpn': 'ja',
  'kor': 'ko', 'mya': 'my', 'nep': 'ne', 'pol': 'pl', 'por': 'pt',
  'ron': 'ro', 'rus': 'ru', 'spa': 'es', 'tam': 'ta', 'tha': 'th',
  'tuk': 'tk', 'tur': 'tr', 'ukr': 'uk', 'vie': 'vi', 'zho': 'zh',
};

const secilenDiller = {
  'amh', 'ara', 'ben', 'deu', 'eng', 'fas', 'fra', 'ind', 'ita', 'jpn',
  'kor', 'mya', 'nep', 'pol', 'por', 'ron', 'rus', 'spa', 'tam', 'tha',
  'tuk', 'tur', 'ukr', 'vie', 'zho',
};

void main() async {
  final r = await http.get(Uri.parse('https://api.alquran.cloud/v1/edition'))
      .timeout(const Duration(seconds: 40));
  final g = json.decode(r.body);
  final edisyonlar = (g['data'] as List).cast<Map<String, dynamic>>();

  // dil -> ceviri edisyonlari
  final ceviriVar = <String, List<String>>{};
  for (final e in edisyonlar) {
    if ((e['type'] as String?) != 'translation') continue;
    final dil = e['language'] as String? ?? '';
    (ceviriVar[dil] ??= []).add(e['identifier'] as String);
  }

  final kapsananDiller = <String>[];
  final eksikDiller = <String>[];
  for (final d in secilenDiller.toList()..sort()) {
    final iki = ikiHarfli[d];
    if (iki != null && ceviriVar.containsKey(iki)) {
      kapsananDiller.add('$d/$iki  (${ceviriVar[iki]!.length} ceviri)');
    } else {
      eksikDiller.add('$d (sunucuda yok)');
    }
  }

  final sb = StringBuffer();
  sb.writeln('=== ALQURAN CLOUD KAPSAMI (25 secilen dil icinde) ===');
  sb.writeln('');
  sb.writeln('GERCEK AYET CEVIRISI OLAN (${kapsananDiller.length}/25):');
  for (final v in kapsananDiller) {
    sb.writeln('  $v');
  }
  sb.writeln('');
  sb.writeln('OLMAYAN (${eksikDiller.length}/25):');
  for (final o in eksikDiller) {
    sb.writeln('  $o');
  }
  sb.writeln('');
  sb.writeln('TOPLAM SUNUCU DIL SAYISI: ${ceviriVar.length}');

  File(r'C:\Users\malik\AppData\Local\Temp\opencode\quran_kapsam.txt')
      .writeAsStringSync(sb.toString(), encoding: utf8);

  print('Kapsanan: ${kapsananDiller.length}/25');
  print('Eksik   : ${eksikDiller.length} -> ${eksikDiller.join(", ")}');
}
