// Ceviri dosyalarindaki yeni sekme anahtarlarini dogrular. Konsol kod
// sayfasinda bozuk gorunebilir (PowerShell encoding), bu yuzden dosya
// icerigini Dart ile okuyup yaziyoruz.
import 'dart:convert';
import 'dart:io';

void main() {
  final dizin = Directory('assets/i18n/ceviri');
  var eksik = 0;
  var toplam = 0;
  final satirlar = <String>[];

  for (final dosya in dizin.listSync().whereType<File>()) {
    if (!dosya.path.endsWith('.json')) continue;
    final kod = dosya.uri.pathSegments.last.replaceAll('.json', '');
    toplam++;
    final metin = dosya.readAsStringSync(encoding: utf8);
    final harita = (json.decode(metin) as Map<String, dynamic>);
    for (final anahtar in const ['cities_tab', 'villages_tab']) {
      final deger = harita[anahtar];
      if (deger is! String || deger.trim().isEmpty) {
        satirlar.add('  $kod: $anahtar EKSİK');
        eksik++;
        continue;
      }
      // Latin olmayan betiklerde harf olup olmadigini kontrol et.
      if (deger.contains('?')) {
        satirlar.add('  $kod: $anahtar bozuk gorunuyor -> "$deger"');
        eksik++;
      }
    }
  }

  print('Ceviri dosyasi: $toplam');
  print('Eksik/bozuk     : $eksik');
  print('');
  for (final s in satirlar) {
    print(s);
  }

  // Ornek: birkac dilin gercek degerini yazdir
  print('');
  print('--- ornek degerler ---');
  for (final kod in const ['tur', 'eng', 'ara', 'zho', 'amh', 'rus']) {
    final f = File('assets/i18n/ceviri/$kod.json');
    if (!f.existsSync()) continue;
    final harita = (json.decode(f.readAsStringSync(encoding: utf8))
        as Map<String, dynamic>);
    print('  $kod: cities="${harita['cities_tab']}" '
        'villages="${harita['villages_tab']}"');
  }
}
