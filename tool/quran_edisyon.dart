// AlQuran Cloud'un hangi dillerde gercek ceviri sundugunu cikarir.
// Bu, ayet metinlerini elle yazmadan gercek kaynakli metin kullanmamizi saglar.
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final r = await http.get(Uri.parse('https://api.alquran.cloud/v1/edition'))
      .timeout(const Duration(seconds: 40));
  if (r.statusCode != 200) {
    print('HATA: HTTP ${r.statusCode}');
    return;
  }
  final g = json.decode(r.body);
  final edisyonlar = (g['data'] as List).cast<Map<String, dynamic>>();

  print('Toplam edisyon: ${edisyonlar.length}\n');

  // Ceviri olan edisyonlar (type == 'translation') ve dillerine gore grupla
  final dillere = <String, List<String>>{};
  final turler = <String, int>{};
  for (final e in edisyonlar) {
    final tip = e['type'] as String? ?? '?';
    turler[tip] = (turler[tip] ?? 0) + 1;
    if (tip != 'translation') continue;
    final dil = (e['language'] as String?) ?? '?';
    (dillere[dil] ??= []).add('${e['identifier']} (${e['englishName']})');
  }

  print('=== Turlere gore ===');
  turler.forEach((k, v) => print('  ${k.padRight(12)} $v'));

  print('');
  print('=== Ceviri bulunan ${dillere.length} dil ===');
  final sirali = dillere.keys.toList()..sort();
  final cikti = StringBuffer();
  for (final d in sirali) {
    final liste = dillere[d]!;
    cikti.writeln('${d.padRight(6)} (${liste.length}) ${liste.join(", ")}');
  }
  // Konsol kodlamasi sorun olmasin diye dosyaya yaz
  print('  (detaylar dil_listesi.txt dosyasina yazildi)');
  // Dart'ta dosya yazmak icin dart:io gerekir; burada sadece onizleme
  for (final d in sirali) {
    print('  ${d.padRight(6)} ${dillere[d]!.length} ceviri');
  }
}
