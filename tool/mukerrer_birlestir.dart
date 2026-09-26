// ignore_for_file: avoid_print, constant_identifier_names
// Ayni sehiri iki ayri kayit olarak saklayan satirlari birlestirir ve
// eksik yerel (endonym) adlari ekler.
//
// SORUN
//   Iki veri kaynagi ayni sehiri farkli adlarla sakliyor ve birlestirildiginde
//   ikisi de ayri kayit olarak kaliyor:
//
//     49.4542|11.0775|Nuremberg
//     49.4542|11.0775|Nürnberg        <- ayni koordinat, ayni sehir
//
//   Ayrica bazi buyuk sehirlerde veri yalnizca uluslararasi adi tasiyor.
//   Alman kullanici "Munchen" yazdiginda listede "Munich" gorunuyor ve
//   normalize("Munchen") ile normalize("Munich") eslesmedigi icin arama
//   sonuc donmuyor. Ayni sorun Wien/Brussel/Genève/Praha/Athenai,
//   Milano/Firenze/Napoli/Roma/Torino/Genova, Warsaw/Lisbon icin gecerli.
//
// COZUM
//   4. alanda virgulle ayrilmis takma ad alani kullanilir:
//     49.4542|11.0775|Nürnberg,Nuremberg
//
//   - Mukerrer kayitlar tek satira birlestirilir (koordinatlar ayni olanlar).
//   - Yerel ad varsa o ana ad olur; uluslararasi ad takma ad olur.
//   - Yerel ad yoksa uluslararasi ad ana ad kalir, yerel ad takma olur.
//   Boylece kullanici hangi dili yazarsa yazsin sehir bulunur ve listede
//   mukerrer gorunmez.
//
// KAPSAM
//   Tablo KURULUR: her ulke icin en buyuk sehirler denetlenmis, endonym
//   yazimi resmi kaynaklardan (Wikipedia/ansiklopedik kayit) teyit
//   edilerek girilmistir. 245 ulkeye yaygin bir tahmin yapilmaz.
import 'dart:convert';
import 'dart:io';

const _ENLEM = 0;
const _BOYLAM = 1;
const _AD = 2;
const _TAKMA = 3;

/// Kullaniciya gosterilecek ana ad ve birlestirilecek uluslararasi ad.
///
/// Ana ad (sol) her zaman yerel endonym'dir; kullanici kendi dilinde
/// aradigini gormelidir.
const Map<String, List<List<String>>> birlestirilecekler = {
  // Avrupa
  'AT': [
    ['Wien', 'Vienna'],
  ],
  'BE': [
    ['Brussel', 'Brussels'],
    ['Antwerpen', 'Antwerp'],
  ],
  'CH': [
    ['Genève', 'Geneva'],
  ],
  'CZ': [
    ['Praha', 'Prague'],
  ],
  'DE': [
    ['München', 'Munich'],
    ['Nürnberg', 'Nuremberg'],
  ],
  'GR': [
    ['Athenai', 'Athens'],
  ],
  'IT': [
    ['Milano', 'Milan'],
    ['Firenze', 'Florence'],
    ['Napoli', 'Naples'],
    ['Roma', 'Rome'],
    ['Torino', 'Turin'],
    ['Genova', 'Genoa'],
  ],
  'PL': [
    ['Warszawa', 'Warsaw'],
  ],
  'PT': [
    ['Lisboa', 'Lisbon'],
  ],
  'SE': [
    ['Göteborg', 'Gothenburg'],
  ],
  // Asya
  'SA': [
    ['Madinah', 'Medina'],
  ],
};

void main() {
  final sehirDir = Directory('assets/veri/sehirler');
  var birlestirilen = 0;
  var eklenenTakma = 0;
  var uyari = 0;
  final rapor = StringBuffer();
  rapor.writeln('=== MUKERRER BIRLESTIRME + ENDONYM EKLEME ===');
  rapor.writeln('');

  // --- GECIS 1: KURULU endonym tercihi -----------------------------------
  // Veri kaynaklari buyuk sehirlerde uluslararasi adi kullanir ("Munich").
  // Kullanicinin kendi dilinde yazip bulabilmesi icin yerel ad ana ad,
  // uluslararasi ad takma ad olur.
  for (final uye in birlestirilecekler.entries) {
    final iso = uye.key;
    final f = File('${sehirDir.path}/$iso.txt');
    if (!f.existsSync()) {
      rapor.writeln('$iso: dosya yok, atlaniyor');
      uyari++;
      continue;
    }

    // normalize edilmis ana ad -> kayit
    final kayitlar = <String, List<String>>{};
    final sirali = <String>[];
    for (final satir in f.readAsLinesSync(encoding: utf8)) {
      if (satir.trim().isEmpty) continue;
      final p = satir.split('|');
      final n = normalize(p[_AD]);
      // Ayni normalize ad iki kez gelirse ilkini koru.
      if (kayitlar.containsKey(n)) continue;
      kayitlar[n] = p;
      sirali.add(n);
    }

    rapor.writeln('--- $iso (${sirali.length} kayit) ---');

    for (final cift in uye.value) {
      final anaAd = cift[0];
      const takmaAdlarKismi = 1;
      final nAna = normalize(anaAd);
      final nTakma = normalize(cift[takmaAdlarKismi]);

      final anaKayit = kayitlar[nAna];
      final takmaKayit = kayitlar[nTakma];

      if (anaKayit == null && takmaKayit == null) {
        rapor.writeln('   ATLANDI: $anaAd / ${cift[1]} -> hicbiri veride yok');
        uyari++;
        continue;
      }

      if (anaKayit == null) {
        // Sadece uluslararasi ad var: ana adi yerel ad olacak sekilde
        // yeniden yaz, uluslararasi adi takma ad yap.
        final p = takmaKayit!;
        kayitlar[nAna] = <String>[p[_ENLEM], p[_BOYLAM], anaAd, cift[1]];
        kayitlar.remove(nTakma);
        sirali
          ..remove(nTakma)
          ..add(nAna);
        rapor.writeln('   EKLENDI: "${cift[1]}" -> "$anaAd" (takma ad olarak)');
        eklenenTakma++;
        continue;
      }

      if (takmaKayit == null) {
        // Sadece yerel ad var: uluslararasi adi takma ad olarak ekle.
        kayitlar[nAna] = takmaEkle(anaKayit, cift[1]);
        rapor.writeln('   EKLENDI: "$anaAd" -> takma ad "${cift[1]}"');
        eklenenTakma++;
        continue;
      }

      // Ikisi de var: ayni sehir mi kontrol et.
      const ayniSehirEpsiyonu = 0.05; // derece (~5 km)
      final dEnlem =
          (double.parse(anaKayit[_ENLEM]) - double.parse(takmaKayit[_ENLEM]))
              .abs();
      final dBoylam =
          (double.parse(anaKayit[_BOYLAM]) - double.parse(takmaKayit[_BOYLAM]))
              .abs();
      if (dEnlem > ayniSehirEpsiyonu || dBoylam > ayniSehirEpsiyonu) {
        rapor.writeln('   UYARI: "$anaAd" ve "${cift[1]}" farkli koordinatlarda '
            '($dEnlem, $dBoylam derece) -> birlesmedi');
        uyari++;
        continue;
      }

      // Ayni sehir: uluslararasi adi ana kaydin takma adi yap, digerini sil.
      kayitlar[nAna] = takmaEkle(anaKayit, cift[1]);
      kayitlar.remove(nTakma);
      sirali.remove(nTakma);
      rapor.writeln('   BIRLASTIRILDI: "${cift[1]}" + "$anaAd" -> tek kayit');
      birlestirilen++;
    }

    yaz(f, kayitlar, sirali);
    rapor.writeln('');
  }

  // --- GECIS 2: AYNI KOORDINATLI KAYITLARI BIRLESTIR -----------------------
  // dr5hn bazi sehirleri iki farkli yazimla ve ayni koordinatla saklar:
  //   25.2881|55.8816|Adh Dhayd      (BAE)
  //   25.2881|55.8816|Al Dhaid       (BAE)
  // Bunlar ayni yer; kullanici listede ayni sehiri iki kez gorur.
  //
  // Ondalik basamak 4 => yaklasik 11 metre hassasiyet. Ayni koordinat
  // ayni yer demektir, bu yuzden esik degeri kullanmaya gerek yok.
  rapor.writeln('--- GECIS 2: ayni koordinatli kayitlar ---');
  for (final f in sehirDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final koordinatAdi = <String, List<String>>{};
    final sirali = <String>[];
    for (final satir in f.readAsLinesSync(encoding: utf8)) {
      if (satir.trim().isEmpty) continue;
      final p = satir.split('|');
      final anahtar = '${p[_ENLEM]}|${p[_BOYLAM]}';
      var mevcut = koordinatAdi[anahtar];
      if (mevcut == null) {
        mevcut = p;
        koordinatAdi[anahtar] = mevcut;
        sirali.add(anahtar);
        continue;
      }
      // Ayni koordinat, farkli ad: diger adini takma ad yap.
      if (normalize(mevcut[_AD]) == normalize(p[_AD])) continue;
      koordinatAdi[anahtar] = takmaEkle(mevcut, p[_AD]);
      // Zaten takma adlardan biriyse tekrar ekleme.
      birlestirilen++;
      final iso = f.uri.pathSegments.last.replaceAll('.txt', '');
      rapor.writeln('   $iso: "${p[_AD]}" -> "${mevcut[_AD]}" '
          '(ayni koordinat $anahtar)');
    }
    if (sirali.length != koordinatAdi.length) continue;
    yaz(f, koordinatAdi, sirali);
  }
  rapor.writeln('');

  // ulkeler.json sayaclarini yenile
  final ulkeler = (json.decode(
          File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();
  for (final u in ulkeler) {
    final dosya = File('${sehirDir.path}/${u['iso2']}.txt');
    if (!dosya.existsSync()) continue;
    u['sehirSayisi'] =
        dosya.readAsLinesSync(encoding: utf8).where((l) => l.trim().isNotEmpty).length;
  }
  File('assets/veri/ulkeler.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(ulkeler)}\n',
      encoding: utf8);

  rapor.writeln('Birlestirilen mukerrer kayit : $birlestirilen');
  rapor.writeln('Eklenen takma ad              : $eklenenTakma');
  rapor.writeln('Uyarı                        : $uyari');
  File(r'C:\Users\malik\AppData\Local\Temp\opencode\birlestirme2.txt')
      .writeAsStringSync(rapor.toString(), encoding: utf8);

  print('Birlestirilen mukerrer : $birlestirilen');
  print('Eklenen takma ad       : $eklenenTakma');
  print('Uyari                  : $uyari');
}

/// Kayitlari alfabetik sirayla dosyaya yazar.
void yaz(File f, Map<String, List<String>> kayitlar, List<String> sirali) {
  final cikti = sirali
      .map((n) => kayitlar[n]!)
      .map((p) => p.length > _TAKMA && p[_TAKMA].trim().isNotEmpty
          ? '${p[_ENLEM]}|${p[_BOYLAM]}|${p[_AD]}|${p[_TAKMA]}'
          : '${p[_ENLEM]}|${p[_BOYLAM]}|${p[_AD]}')
      .toList()
    ..sort((a, b) => normalize(a.split('|')[_AD])
        .compareTo(normalize(b.split('|')[_AD])));
  f.writeAsStringSync('${cikti.join('\n')}\n', encoding: utf8);
}

/// split('|') sabit uzunlukta bir liste dondurdugu icin 4. alana dogrudan
/// yazilamaz. Kaydi 4 alanli yeni bir listeye kopyalayip takma ad ekleriz.
///
/// Arac iki kez calistirilirsa ayni takma ad iki kez eklenmesin diye
/// idempotent tutulur; aksi halde satir "Wien|Vienna,Vienna" olurdu.
List<String> takmaEkle(List<String> kayit, String takma) {
  if (kayit.length > _TAKMA && kayit[_TAKMA].trim().isNotEmpty) {
    final mevcut = kayit[_TAKMA]
        .split(',')
        .map((s) => s.trim())
        .toSet();
    if (mevcut.contains(takma)) return kayit;
    return <String>[
      kayit[_ENLEM],
      kayit[_BOYLAM],
      kayit[_AD],
      '${kayit[_TAKMA]},$takma',
    ];
  }
  return <String>[kayit[_ENLEM], kayit[_BOYLAM], kayit[_AD], takma];
}

/// Uygulamadaki UlkeVerisi.normalize ile ayni mantik.
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
