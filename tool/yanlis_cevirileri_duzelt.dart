// tool/yanlis_cevirileri_duzelt.dart
//
// Bazı anahtarlar ilk çalıştırmada YANLIŞ değerle yazıldı (fallback
// haritası anahtar yerine dil bazlı çalıştığı için `deu`/`ind` için
// Türkçe/Endonezce metinler yazılmıştı). Bu araç o değerleri düzeltir.
//
// KULLANIM:
//     dart run tool/yanlis_cevirileri_duzelt.dart
//
// DİKKAT: Bu araç YALNIZCA yanlış yazılmış değerleri düzeltir. Doğru
// çevirilerin insan gözüyle denetlenmesi ayrı ve zorunlu bir iştir.
import 'dart:convert';
import 'dart:io';

import 'yeni_anahtar_cevirileri.dart';

void main() {
  final dizin = Directory('assets/i18n/ceviri');
  for (final f in dizin.listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final kod = f.uri.pathSegments.last.replaceAll('.json', '');
    final ceviriler = dilCevirileri[kod];
    if (ceviriler == null) continue;

    final harita = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
    var duzeltilen = 0;
    for (final e in ceviriler.entries) {
      if (harita[e.key] != e.value) {
        harita[e.key] = e.value;
        duzeltilen++;
      }
    }
    if (duzeltilen == 0) continue;
    final sirali = Map<String, dynamic>.fromEntries(
      harita.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    f.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(sirali) + '\n',
        flush: true);
    // ignore: avoid_print
    print('$kod: $duzeltilen deger duzeltildi');
  }
  // ignore: avoid_print
  print('Tamamlandi.');
}
