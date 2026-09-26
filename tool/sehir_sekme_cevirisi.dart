// Sehir secici icin gereken iki yeni ceviri anahtarini tum ceviri
// dosyalarina ekler.
//
// NEDEN?
// Sekmeler "Sehirler" ve "Koyler" basligi kullanir. Anahtar dosyalarda
// yoksa easy_localization anahtarin kendisini ekrana basar ("cities_tab"),
// bu da kullaniciya kirli bir goruntu verir.
//
// DIKKAT
//   Bu arac yalnizca EKLEME yapar; mevcut cevirilere dokunmaz. Anahtar
//   zaten varsa degerini guncellemez (baska bir oturumun calismasini ezmemek
//   icin). Eklenen anahtarlar en sona yazilir.
//
// KULLANIM
//   dart run tool/sehir_sekme_cevirisi.dart
import 'dart:convert';
import 'dart:io';

/// 25 dilin resmi secimimize dahil listesi ve ceviriler.
const Map<String, Map<String, String>> ceviriler = {
  'amh': {'cities_tab': 'ከተማዎች', 'villages_tab': 'ጥሞቶች'},
  'tur': {'cities_tab': 'Şehirler', 'villages_tab': 'Köyler'},
  'eng': {'cities_tab': 'Cities', 'villages_tab': 'Villages'},
  'ara': {'cities_tab': 'مدن', 'villages_tab': 'قرى'},
  'ben': {'cities_tab': 'শহর', 'villages_tab': 'গ্রাম'},
  'deu': {'cities_tab': 'Städte', 'villages_tab': 'Dörfer'},
  'fas': {'cities_tab': 'شهرها', 'villages_tab': 'روستاها'},
  'fra': {'cities_tab': 'Villes', 'villages_tab': 'Villages'},
  'ind': {'cities_tab': 'Kota', 'villages_tab': 'Desa'},
  'ita': {'cities_tab': 'Città', 'villages_tab': 'Villaggi'},
  'jpn': {'cities_tab': '都市', 'villages_tab': '村'},
  'kor': {'cities_tab': '도시', 'villages_tab': '마을'},
  'mya': {'cities_tab': 'မြို့မား', 'villages_tab': 'ရွှေ'},
  'nep': {'cities_tab': 'शहर', 'villages_tab': 'गाउँ'},
  'pol': {'cities_tab': 'Miasta', 'villages_tab': 'Wsie'},
  'por': {'cities_tab': 'Cidades', 'villages_tab': 'Aldeias'},
  'ron': {'cities_tab': 'Orașe', 'villages_tab': 'Sate'},
  'rus': {'cities_tab': 'Города', 'villages_tab': 'Деревни'},
  'spa': {'cities_tab': 'Ciudades', 'villages_tab': 'Pueblos'},
  'tam': {'cities_tab': 'நகரங்கள்', 'villages_tab': 'கிராமங்கள்'},
  'tha': {'cities_tab': 'เมือง', 'villages_tab': 'หมู่บ้าน'},
  'tuk': {'cities_tab': 'Şäherler', 'villages_tab': 'Ýeşlikler'},
  'ukr': {'cities_tab': 'Міста', 'villages_tab': 'Села'},
  'vie': {'cities_tab': 'Thành phố', 'villages_tab': 'Làng'},
  'zho': {'cities_tab': '城市', 'villages_tab': '村庄'},
};

void main() {
  final dizin = Directory('assets/i18n/ceviri');
  if (!dizin.existsSync()) {
    stderr.writeln('Ceviri dizini yok: ${dizin.path}');
    exit(66);
  }

  var eklendi = 0;
  var atlandi = 0;
  final eksikler = <String>[];

  for (final dosya in dizin.listSync().whereType<File>()) {
    if (!dosya.path.endsWith('.json')) continue;
    final kod = dosya.uri.pathSegments.last.replaceAll('.json', '');
    final ceviri = ceviriler[kod];
    if (ceviri == null) {
      eksikler.add(kod);
      continue;
    }

    final metin = dosya.readAsStringSync(encoding: utf8);
    final harita = (json.decode(mutf8DUzelt(metin)) as Map<String, dynamic>);

    var degisti = false;
    ceviri.forEach((anahtar, deger) {
      if (harita.containsKey(anahtar)) return; // baska bir calisma ezilmesin
      harita[anahtar] = deger;
      degisti = true;
    });

    if (!degisti) {
      atlandi++;
      continue;
    }
    dosya.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(harita)}\n',
        encoding: utf8);
    eklendi++;
    print('  $kod: anahtarlar eklendi');
  }

  print('');
  print('Guncellenen dosya : $eklendi');
  print('Zaten mevcut      : $atlandi');
  if (eksikler.isNotEmpty) {
    print('Cevirisi olmayan kodlar: ${eksikler.join(", ")}');
  }
}

/// JSON govdesinin basinda BOM varsa temizler; aksi halde decode hata verir.
String mutf8DUzelt(String s) =>
    s.startsWith('﻿') ? s.substring(1) : s;
