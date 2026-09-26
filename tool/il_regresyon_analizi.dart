// ignore_for_file: avoid_print, constant_identifier_names
// REGRESYON ANALIZI: eski sabit 81 il listesi ile yeni veri setindeki
// sehirler karsilastirilir. Hangi iller kaybolmus?
import 'dart:convert';
import 'dart:io';

/// Onceki surumde ana sayfada sabit olarak duran 81 il listesi.
const eskiIller = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
  'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın',
  'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
  'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce',
  'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun',
  'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir',
  'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri',
  'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli', 'Konya', 'Kütahya',
  'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde',
  'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas',
  'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak',
  'Van', 'Yalova', 'Yozgat', 'Zonguldak',
];

/// Turkce karakterleri indirger ve noktasiz/noktali i ayrimini yapar.
/// "İstanbul" -> "istanbul", "istanbul" -> "istanbul"  (aynı)
///
/// DIKKAT: I/ı ve İ/i farkini da cozmek gerekiyor; "Iğdır" ile "Igdir"
/// esit olmali.
String normalize(String s) {
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    var x = r;
    // Uzun uyeler
    const uzun = <int, int>{
      0x0130: 0x69, // İ -> i
      0x0131: 0x69, // ı -> i
      0x015E: 0x73, // Ş -> s
      0x015F: 0x73, // ş -> s
      0x011E: 0x67, // Ğ -> g
      0x011F: 0x67, // ğ -> g
      0x00C7: 0x63, // Ç -> c
      0x00E7: 0x63, // ç -> c
      0x00D6: 0x6F, // Ö -> o
      0x00F6: 0x6F, // ö -> o
      0x00DC: 0x75, // Ü -> u
      0x00FC: 0x75, // ü -> u
      0x00F1: 0x6E, // ñ
    };
    if (uzun.containsKey(x)) x = uzun[x]!;
    if (x == 0x2E || x == 0x2C || x == 0x27 || x == 0x2D || x == 0x20) continue;
    buf.writeCharCode(x);
  }
  return buf.toString();
}

void main() {
  final satirlar = File('assets/veri/sehirler/TR.txt')
      .readAsLinesSync(encoding: utf8)
      .where((l) => l.trim().isNotEmpty)
      .toList();

  final adlar = <String>[]; // normalize edilmis ad -> gercek ad
  for (final s in satirlar) {
    final p = s.split('|');
    if (p.length > 2) adlar.add(p[2]);
  }
  final normAdlar = adlar.map(normalize).toSet();
  final gercekAdlar = <String, String>{}; // normalize -> orijinal
  for (final a in adlar) {
    gercekAdlar.putIfAbsent(normalize(a), () => a);
  }

  final sb = StringBuffer();
  sb.writeln('=== ESKI 81 IL LISTESI vs YENI VERI SETI ===');
  sb.writeln('Eski il sayisi      : ${eskiIller.length}');
  sb.writeln('Yeni sehir sayisi   : ${adlar.length}');
  sb.writeln('');

  final bulunanlar = <String>[];
  final kayiplar = <String>[];

  for (final il in eskiIller) {
    // Tam eslesme
    if (normAdlar.contains(normalize(il))) {
      bulunanlar.add(il);
      continue;
    }
    // Onek eslesme: veri seti ilce/koy kaydi olabilir
    // (orn. "Kahramanmaras" yerine "Kahramankazan")
    final n = normalize(il);
    final onek = gercekAdlar.keys.where((a) => a.startsWith(n)).toList()..sort();
    if (onek.isNotEmpty) {
      bulunanlar.add(il);
      sb.writeln('  KABUK: $il -> veride: ${onek.take(3).join(", ")}');
    } else {
      kayiplar.add(il);
    }
  }

  sb.writeln('');
  sb.writeln('BULUNAN : ${bulunanlar.length}/${eskiIller.length}');
  sb.writeln('KAYIP   : ${kayiplar.length}');
  sb.writeln('');
  sb.writeln('=== KAYBOLAN ILLER (eski listede var, yeni veride YOK) ===');
  for (final k in kayiplar) {
    sb.writeln('  $k');
  }

  File(r'C:\Users\malik\AppData\Local\Temp\opencode\il_regresyon.txt')
      .writeAsStringSync(sb.toString(), encoding: utf8);

  print('BULUNAN: ${bulunanlar.length}/${eskiIller.length}');
  print('KAYIP  : ${kayiplar.length} -> ${kayiplar.join(", ")}');
  print('');
  print('Detay: il_regresyon.txt');
}
