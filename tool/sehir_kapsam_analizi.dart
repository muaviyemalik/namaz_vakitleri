// ignore_for_file: avoid_print, constant_identifier_names
// Buyuk sehirler veri setinde var mi? Sorun Turkceye mi ozgu, yoksa genel mi?
import 'dart:convert';
import 'dart:io';

/// Her ulkenin buyuk/merkez sehirleri. Bunlar kullanici tarafindan kesin
/// olarak aranir; veri setinde olmamalari ciddi bir kalite sorunudur.
const kontrolSehirleri = <String, List<String>>{
  'TR': [
    'Istanbul', 'Ankara', 'Izmir', 'Bursa', 'Antalya', 'Adana', 'Konya',
    'Gaziantep', 'Kahramanmaras', 'Diyarbakir', 'Denizli', 'Malatya',
    'Samsun', 'Aydin', 'Manisa', 'Eskisehir', 'Sakarya', 'Tekirdag',
  ],
  'US': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
  'DE': ['Berlin', 'Munich', 'Hamburg', 'Cologne', 'Frankfurt'],
  'FR': ['Paris', 'Marseille', 'Lyon', 'Toulouse'],
  'EG': ['Cairo', 'Alexandria', 'Giza'],
  'SA': ['Riyadh', 'Jeddah', 'Makkah', 'Madinah'],
  'NG': ['Lagos', 'Kano', 'Abuja', 'Ibadan'],
  'ID': ['Jakarta', 'Surabaya', 'Bandung', 'Medan'],
  'MY': ['Kuala Lumpur', 'George Town', 'Johor Bahru'],
  'GB': ['London', 'Manchester', 'Birmingham', 'Glasgow'],
};

void main() {
  final sb = StringBuffer();
  sb.writeln('=== BUYUK SEHIR KAPSAM DOGRULAMASI ===');
  sb.writeln('');
  var toplamBulunan = 0;
  var toplamKontrol = 0;
  final eksikler = <String, List<String>>{};

  kontrolSehirleri.forEach((iso, sehirler) {
    final f = File('assets/veri/sehirler/$iso.txt');
    if (!f.existsSync()) {
      sb.writeln('$iso: DOSYA YOK');
      return;
    }
    final satirlar = f
        .readAsLinesSync(encoding: utf8)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final adlar = <String, String>{};
    for (final s in satirlar) {
      final p = s.split('|');
      if (p.length > 2) adlar[p[2].toLowerCase()] = p[2];
    }

    sb.writeln('--- $iso  (${satirlar.length} kayit) ---');
    final eksik = <String>[];
    for (final s in sehirler) {
      toplamKontrol++;
      if (adlar.containsKey(s.toLowerCase())) {
        toplamBulunan++;
        sb.writeln('   VAR  $s');
      } else {
        eksik.add(s);
        sb.writeln('   YOK  $s');
      }
    }
    if (eksik.isNotEmpty) eksikler[iso] = eksik;
    sb.writeln('');
  });

  sb.writeln('=== OZET ===');
  sb.writeln('Kontrol edilen sehir : $toplamKontrol');
  sb.writeln('Bulunan              : $toplamBulunan');
  sb.writeln(
      'Eksik                : ${toplamKontrol - toplamBulunan} ('
      '${(100 - toplamBulunan * 100 / toplamKontrol).toStringAsFixed(0)}% kayip)');
  sb.writeln('');
  sb.writeln('Eksik olan ulkeler: ${eksikler.keys.join(", ")}');

  File(r'C:\Users\malik\AppData\Local\Temp\opencode\sehir_kapsam.txt')
      .writeAsStringSync(sb.toString(), encoding: utf8);

  print('Kontrol : $toplamKontrol');
  print('Bulunan : $toplamBulunan');
  print('Eksik   : ${eksikler.length} ulke -> ${eksikler.keys.join(", ")}');
  print('');
  print('Detay: sehir_kapsam.txt');
}
