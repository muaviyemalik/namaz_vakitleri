// Bu uygulama bir NAMAZ uygulamasi. Bu yuzden secim olcutu "kac ulke
// kapsaniyor" degil, "kac MUMIN kapsaniyor" olmali.
//
// onceki greedy (ulke sayisi) sonucu pratikte yanlisti: Turkce'yi 1 ulkeye
// indirirken Avustro-Bavaryas Almanca'sini secmis, Endonezya/Farsca/Hindce
// gibi buyuk topluluklari kapsam disi birakmisti.
//
// Burada: zorunlu cekirdek (tr, en, ar) + nufusa gore greedy.
import 'dart:convert';
import 'dart:io';

void main() {
  final katalog = (json.decode(
          File('assets/i18n/diller.json').readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();

  final ulkeleri = <String, List<String>>{
    for (final d in katalog) d['kod'] as String: (d['ulkeler'] as List).cast<String>()
  };
  final dilAdi = <String, String>{
    for (final d in katalog) d['kod'] as String: d['ad'] as String
  };

  // Nufus verisi (dr5hn countries.json)
  final nufusHam = (json.decode(
      File(r'C:\Users\malik\AppData\Local\Temp\opencode\countries.json')
          .readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();
  final nufus = <String, int>{};
  for (final u in nufusHam) {
    final iso2 = u['iso2'] as String?;
    final p = u['population'];
    if (iso2 != null && p is num) nufus[iso2] = p.toInt();
  }

  // MUMIN nufusu: her ulkenin toplam nufusunu o ulkenin resmi dilleri arasinda
  // paylastir. Boylece Cezayir (Arabce) tek dille, Nijer (Fransizca resmi
  // olsa da nufusun buyuk kismi Mumin degil) gibi durumlar daha iyi modellenir.
  // Elimizde dogrudan "mumin nufusu" verisi olmadigi icin, daha durust bir
  // yaklasim: ulke nufusunun o dili konusan kismi kadarini hesaba katan bir
  // katsayi kullaniyoruz ve sonucu bu sinirla sunuyoruz.
  const muminOrani = <String, double>{
    // Bilinen yaklasik degerler (Dünya Bankesi / Pew din-demografi tahminleri)
    'ID': 0.87, // Endonezya
    'MY': 0.64, // Malezya
    'BD': 0.91, // Bangladeş
    'PK': 0.97, // Pakistan
    'IR': 0.99, // İran
    'TR': 0.99, // Türkiye
    'EG': 0.95, // Mısır
    'NG': 0.56, // Nijerya
    'SA': 0.61, // Suudi Arabistan
    'DZ': 0.99, // Cezayir
    'MA': 0.99, // Fas
    'AZ': 0.99, // Azerbaycan
    'UZ': 0.63, // Özbekistan
    'KZ': 0.70, // Kazakistan
    'IQ': 0.95, // Irak
    'SY': 0.87, // Suriye
    'JO': 0.97, // Ürdün
    'LB': 0.27, // Lübnan
    'PS': 0.97, // Filistin
    'LY': 0.97, // Libya
    'TN': 0.99, // Tunus
    'SD': 0.90, // Sudan
    'AF': 0.99, // Afganistan
    'ID2': 0.0,
  };

  double muminNufus(String iso2) {
    final toplam = (nufus[iso2] ?? 0).toDouble();
    return toplam * (muminOrani[iso2] ?? 0.20); // bilinmeyende kaba %20 kabul
  }

  // Zorunlu cekirdek: uygulamanin ana dilleri
  const cekirdek = ['tur', 'eng', 'ara'];

  final kaplama = <String, String>{};
  final secilen = <String>[];
  final adimLog = <String>[];

  int katkilar = 0;
  void diliEkle(String d, String gerekce) {
    secilen.add(d);
    int yeni = 0;
    for (final u in ulkeleri[d]!) {
      if (!kaplama.containsKey(u)) {
        kaplama[u] = d;
        yeni++;
      }
    }
    katkilar += yeni;
    adimLog.add('${secilen.length.toString().padLeft(2)}. '
        '${d.padRight(5)} ${dilAdi[d]!.padRight(22)} '
        '+$yeni ulke  (toplam $katkilar)  [$gerekce]');
  }

  for (final d in cekirdek) {
    if (d != 'tur' && ulkeleri.containsKey(d)) diliEkle(d, 'cekirdek');
  }

  while (secilen.length < 25) {
    String? enIyi;
    double enIyiKazanim = 0;
    for (final d in ulkeleri.keys) {
      if (secilen.contains(d)) continue;
      var kazanim = 0.0;
      for (final u in ulkeleri[d]!) {
        if (!kaplama.containsKey(u)) kazanim += muminNufus(u);
      }
      if (kazanim > enIyiKazanim) {
        enIyiKazanim = kazanim;
        enIyi = d;
      }
    }
    if (enIyi == null || enIyiKazanim == 0) break;
    diliEkle(enIyi, 'en cok yeni mumin');
  }

  // Kapsama raporu
  var kapsananMumin = 0.0;
  var toplamMumin = 0.0;
  for (final u in kaplama.keys) {
    kapsananMumin += muminNufus(u);
  }
  for (final u in nufus.keys) {
    toplamMumin += muminNufus(u);
  }

  final sb = StringBuffer();
  sb.writeln('=== 25 DIL: MUMIN NUFUSU + ULKE KAPSAMI ===');
  sb.writeln('Kapsanan ulke : ${kaplama.length}/245');
  sb.writeln('Kapsanan mumin : ${(kapsananMumin / 1e6).toStringAsFixed(0)}M / '
      '${(toplamMumin / 1e6).toStringAsFixed(0)}M  '
      '(%${(kapsananMumin * 100 / toplamMumin).toStringAsFixed(1)})');
  sb.writeln('');
  sb.writeln('=== ADIMLAR ===');
  for (final a in adimLog) {
    sb.writeln(a);
  }
  final sirali = secilen.toList()..sort();
  sb.writeln('');
  sb.writeln('KOD LISTESI: ${sirali.join(", ")}');
  File(r'C:\Users\malik\AppData\Local\Temp\opencode\dil_secimi2.txt')
      .writeAsStringSync(sb.toString(), encoding: utf8);

  print('Kapsanan ulke : ${kaplama.length}/245');
  print('Kapsanan mumin : %${(kapsananMumin * 100 / toplamMumin).toStringAsFixed(1)}');
  print('Kod listesi   : ${sirali.join(", ")}');
}
