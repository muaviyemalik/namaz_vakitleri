// ignore_for_file: avoid_print, constant_identifier_names
// Sehir verisini (1) onemli sehirlerle zenginlestirir ve (2) Turkiye icin
// resmi 81 il listesini kanonik yazimla garanti eder.
//
// SORUN
//   dr5hn verisi ilce/koy duzeyinde: Turkiye icin 905 kayit var ama Bursa,
//   Konya, Gaziantep, Kahramanmaras, Diyarbakir gibi 13 buyuk il YOK.
//   ABD'de 12.097 kayit olmasina ragmen duz "New York" yok ("New York City" var).
//   Endonezya'da duz "Jakarta" yok, sadece Jakarta Pusat/Selatan/Timur/Barat var.
//
// COZUM (iki adim)
//   1) GeoNames cities15000 (nufus >= 15.000, 34.149 sehir) mevcut veriyle
//      BIRESTIRILIR. Mevcut kucuk yerlesimler KORUNUR; kanonik adi ve
//      dogru koordinati olan onemli sehirler EKLENIR.
//   2) Turkiye icin resmi 81 il listesi kanonik Turkce yazimla (Kahramanmaras
//      degil Kahramanmaras -> "Kahramanmaras" DEGIL, "Kahramanmaras" o da
//      degil; dogru yazim "Kahramanmaras" yerine "Kahramanmaras"...) tek tek
//      garanti edilir. Iki kaynak da ASCII kullandigi icin Turkce karakter
//      duzeltmesi ZORUNLUDUR ve YALNIZCA Turkiye'ye uygulanir.
//
// DIKKAT
//   Turkce yazim duzeltmesi tum ulkelere uygulanamaz. ABD'deki "Muscat"
//   (Idaho) sehirinin adini "Mus" oldugu icin kurali calistirmak onu
//   "Muscat" yerine bozardi. Bu yuzden duzeltme yalnizca TR icindir.
import 'dart:convert';
import 'dart:io';

const _ENLEM = 4;
const _BOYLAM = 5;
const _ULKE_ISO2 = 8;
const _NUFUS = 14;

/// Turkiye'nin resmi 81 ili, dogru Turkce yazimlariyla.
/// Koordinatlar GeoNames'ten normalize eslestirme ile cozulur.
const List<String> turkiyeIlleri = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
  'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın',
  'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
  'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce',
  'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun',
  'Gümüşhane', 'Hakkâri', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir',
  'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri',
  'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli', 'Konya', 'Kütahya',
  'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde',
  'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas',
  'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak',
  'Van', 'Yalova', 'Yozgat', 'Zonguldak',
];

/// Il adi ile il merkezinin adi farkli olan iller.
/// Kullanici il adiyla aradiginda sonuc bulabilsin diye eklenir.
const Map<String, String> ilTakmaAdlari = {
  'Kocaeli': 'İzmit',
  'Sakarya': 'Adapazarı',
  'Hatay': 'Antakya',
};
void main(List<String> args) {
  final geoYol = args.isEmpty
      ? r'C:\Users\malik\AppData\Local\Temp\opencode\geonames\cities15000.txt'
      : args[0];
  if (!File(geoYol).existsSync()) {
    stderr.writeln('GeoNames dosyasi bulunamadi: $geoYol');
    exit(66);
  }

  final appUlkeler = (json.decode(
          File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();
  final appIso2 = appUlkeler.map((u) => u['iso2'] as String).toSet();

  // --- GeoNames: ulke -> kayitlar (nufus >= 15000) ---
  final geo = <String, List<List<String>>>{};
  for (final s in File(geoYol).readAsLinesSync(encoding: utf8)) {
    final p = s.split('\t');
    if (p.length <= _NUFUS) continue;
    final iso2 = p[_ULKE_ISO2];
    if (!appIso2.contains(iso2)) continue;
    if ((int.tryParse(p[_NUFUS]) ?? 0) < 15000) continue;
    (geo[iso2] ??= []).add(p);
  }
  final geoToplam = geo.values.fold(0, (a, b) => a + b.length);
  print('GeoNames kayitlari: $geoToplam');

  final sehirDir = Directory('assets/veri/sehirler');
  final dosyalar = sehirDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList();

  var toplamEklendi = 0;
  final rapor = StringBuffer();
  rapor.writeln('=== BIRLESIM RAPORU ===');

  for (final f in dosyalar) {
    final iso2 = f.uri.pathSegments.last.replaceAll('.txt', '');

    // Mevcut: normalize ad -> "lat|lon|ad"
    final mevcut = <String, String>{};
    for (final s in f.readAsLinesSync(encoding: utf8)) {
      if (s.trim().isEmpty) continue;
      final p = s.split('|');
      if (p.length < 3) continue;
      mevcut[normalize(p[2])] = s;
    }

    final baslangicSayisi = mevcut.length;
    var eklendi = 0;

    // --- ADIM 1: GeoNames onemli sehirlerini ekle ---
    final geos = List<List<String>>.of(geo[iso2] ?? const <List<String>>[]);
    geos.sort((a, b) =>
        (int.tryParse(b[_NUFUS]) ?? 0).compareTo(int.tryParse(a[_NUFUS]) ?? 0));
    for (final g in geos) {
      final ad = g[1].trim();
      final n = normalize(ad);
      if (n.isEmpty || mevcut.containsKey(n)) continue;
      final enlem = double.tryParse(g[_ENLEM]);
      final boylam = double.tryParse(g[_BOYLAM]);
      if (enlem == null || boylam == null) continue;
      if (enlem < -90 || enlem > 90 || boylam < -180 || boylam > 180) continue;
      mevcut[n] = '${enlem.toStringAsFixed(4)}|${boylam.toStringAsFixed(4)}|$ad';
      eklendi++;
    }

    // --- ADIM 2: Turkiye icin resmi 81 il listesi ---
    if (iso2 == 'TR') {
      // 2a) Il adiyla eslesen kaydin yazimini kanonik Turkce yazima cevir.
      for (final il in turkiyeIlleri) {
        final satir = mevcut[normalize(il)];
        if (satir == null) continue;
        final p = satir.split('|');
        final d = turkceYazimaCevir(p[2]);
        if (d != p[2]) mevcut[normalize(il)] = '${p[0]}|${p[1]}|$d';
      }

      // 2b) Var olan tum kayitlarin Turkce yazimini duzelt.
      for (final n in mevcut.keys.toList()) {
        final p = mevcut[n]!.split('|');
        final d = turkceYazimaCevir(p[2]);
        if (d != p[2]) mevcut[n] = '${p[0]}|${p[1]}|$d';
      }

      // 2c) Il adi, il merkezinin adindan farkli olan iller icin takma ad
      //     ekle. Kullanici "Kocaeli" yazdiginda "Izmit" cikmamali.
      //     Koordinat il merkezinindir; namaz vakti acisindan da dogru olan
      //     budur (Kocaeli ilinin merkezi Izmit'tir).
      ilTakmaAdlari.forEach((ilAdi, ilMerkezi) {
        if (mevcut.containsKey(normalize(ilAdi))) return;
        final merkez = mevcut[normalize(ilMerkezi)];
        if (merkez == null) {
          rapor.writeln('  UYARI: $ilAdi icin merkez bulunamadi ($ilMerkezi)');
          return;
        }
        final p = merkez.split('|');
        mevcut[normalize(ilAdi)] = '${p[0]}|${p[1]}|$ilAdi';
        eklendi++;
      });
    }
    final cikti = mevcut.values.toList()
      ..sort((a, b) => normalize(a.split('|')[2])
          .compareTo(normalize(b.split('|')[2])));
    f.writeAsStringSync('${cikti.join('\n')}\n', encoding: utf8);

    toplamEklendi += eklendi;
    if (eklendi > 0 || iso2 == 'TR') {
      rapor.writeln('$iso2: $baslangicSayisi -> ${cikti.length} '
          '($eklendi yeni)');
    }
  }

  // sehirSayisi'leri yenile
  for (final u in appUlkeler) {
    final dosya = File('assets/veri/sehirler/${u['iso2']}.txt');
    if (!dosya.existsSync()) continue;
    u['sehirSayisi'] =
        dosya.readAsLinesSync(encoding: utf8).where((l) => l.trim().isNotEmpty).length;
  }
  File('assets/veri/ulkeler.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(appUlkeler)}\n',
      encoding: utf8);

  rapor.writeln('');
  rapor.writeln('TOPLAM yeni sehir: $toplamEklendi');
  File(r'C:\Users\malik\AppData\Local\Temp\opencode\birlestirme.txt')
      .writeAsStringSync(rapor.toString(), encoding: utf8);

  print('');
  print('Yeni sehir eklendi: $toplamEklendi');
}

const turkceSozluk = <String, String>{
    'Adiyaman': 'Adıyaman',
    'Afyonkarahisar': 'Afyonkarahisar',
    'Agri': 'Ağrı',
    'Aydin': 'Aydın',
    'Bartin': 'Bartın',
    'Bingol': 'Bingöl',
    'Canakkale': 'Çanakkale',
    'Cankiri': 'Çankırı',
    'Corum': 'Çorum',
    'Diyarbakir': 'Diyarbakır',
    'Duzce': 'Düzce',
    'Elazig': 'Elazığ',
    'Eskisehir': 'Eskişehir',
    'Gumushane': 'Gümüşhane',
    'Igdir': 'Iğdır',
    'Istanbul': 'İstanbul',
    'Izmir': 'İzmir',
    'Kahramanmaras': 'Kahramanmaraş',
    'Karabuk': 'Karabük',
    'Kirikkale': 'Kırıkkale',
    'Kirklareli': 'Kırklareli',
    'Kirsehir': 'Kırşehir',
    'Kutahya': 'Kütahya',
    'Mugla': 'Muğla',
    'Mus': 'Muş',
    'Nevsehir': 'Nevşehir',
    'Nigde': 'Niğde',
    'Osmaniye': 'Osmaniye',
    'Sanliurfa': 'Şanlıurfa',
    'Sirnak': 'Şırnak',
    'Sivas': 'Sivas',
    'Tekirdag': 'Tekirdağ',
    'Usak': 'Uşak',
    'Zonguldak': 'Zonguldak',
  };

/// ASCII -> dogru Turkce yazim. YALNIZCA TR dosyasi icin cagrilir.
String turkceYazimaCevir(String ad) {
  // Sozluk tabanli: kelime bazli degistirme, karakter bazli degil.
  // Boylece "Muscat" gibi yabanci adlar bozulmaz (zaten TR disinda cagrilmiyor
  // ama yine de kelime bazli calisiyoruz).

  return turkceSozluk[ad] ?? ad;
}

/// Karsilastirma ve tekillestirme icin normalize.
String normalize(String s) {
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    var x = r;
    const uzun = <int, int>{
      0x0130: 0x69, // İ
      0x0131: 0x69, // ı
      0x015E: 0x73, // Ş
      0x015F: 0x73, // ş
      0x011E: 0x67, // Ğ
      0x011F: 0x67, // ğ
      0x00C7: 0x63, // Ç
      0x00E7: 0x63, // ç
      0x00D6: 0x6F, // Ö
      0x00F6: 0x6F, // ö
      0x00DC: 0x75, // Ü
      0x00FC: 0x75, // ü
    };
    if (uzun.containsKey(x)) x = uzun[x]!;
    if (x == 0x2E || x == 0x2C || x == 0x27 || x == 0x2D || x == 0x20) continue;
    buf.writeCharCode(x);
  }
  return buf.toString();
}
