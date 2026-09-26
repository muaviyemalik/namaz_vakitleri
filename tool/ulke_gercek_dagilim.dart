// "245 ulke" ifadesi dogru mu? Gercekten bagimsiz ulke mi, yoksa
// bagimli ulke/bölge mi? mledoze verisinde `independent` ve `unMember`
// alanlari var; kullandigimiz veri setiyle karsilastirip hesaplayalim.
import 'dart:convert';
import 'dart:io';

void main() {
  final kaynak = (json.decode(
      File(r'C:\Users\malik\AppData\Local\Temp\opencode\mledoze_countries.json')
          .readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();

  final bizim = (json.decode(
          File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8))
          as List)
      .cast<Map<String, dynamic>>();
  final bizimKodlar = bizim.map((u) => u['iso2'] as String).toSet();

  // dr5hn tarafiyla da karsilastir
  final dr5hn = (json.decode(
      File(r'C:\Users\malik\AppData\Local\Temp\opencode\countries.json')
          .readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();

  const istenen = {'Europe', 'Americas', 'Asia', 'Africa', 'Oceania'};

  var bagimsiz = 0;
  var bagimli = 0;
  var unUyesi = 0;
  final bagimlilar = <String>[];

  for (final u in kaynak) {
    final cca2 = u['cca2'] as String?;
    if (cca2 == null || !bizimKodlar.contains(cca2)) continue;
    final bolge = u['region'] as String?;
    if (bolge == null || !istenen.contains(bolge)) continue;

    final ind = u['independent'] as bool? ?? false;
    final un = u['unMember'] as bool? ?? false;
    if (ind) {
      bagimsiz++;
    } else {
      bagimli++;
      bagimlilar.add('${cca2} ${u['name']} (${u['subregion']})');
    }
    if (un) unUyesi++;
  }

  final sb = StringBuffer();
  sb.writeln('=== "245 ULKE" DEGISIKLIGININ GERCEGI ===');
  sb.writeln('');
  sb.writeln('Toplam kayit           : ${bizimKodlar.length}');
  sb.writeln('Bagimsiz ulke          : $bagimsiz');
  sb.writeln('Bagimli ulke / bolge   : $bagimli');
  sb.writeln('BM Genel Kurul uyesi   : $unUyesi');
  sb.writeln('');
  sb.writeln('=== BAGIMLI OLANLAR ($bagimli) ===');
  bagimlilar.sort();
  for (final b in bagimlilar) {
    sb.writeln('  $b');
  }
  File(r'C:\Users\malik\AppData\Local\Temp\opencode\ulke_gercek.txt')
      .writeAsStringSync(sb.toString(), encoding: utf8);

  print('Toplam      : ${bizimKodlar.length}');
  print('Bagimsiz    : $bagimsiz');
  print('Bagimli     : $bagimli');
  print('BM uyesi    : $unUyesi');
  print('');
  print('Detay: ulke_gercek.txt');
}
