// Sehir verisini TEK aracla uretir: dr5hn + GeoNames birlestirilir, nufus ve
// il bilgisi eklenir, ayni adli farkli yerler ayirt edilir.
//
// NEDEN TEK ARAC?
// Onceki boru hatti uc aracdan olusuyordu (veri_uretici -> sehir_birlestir
// -> mukerrer_birlestir) ve biri digerinden bagimsiz calistiginda veri
// tutarsizlasiyordu. Ayrica sehir_birlestir kayitlari ISIMLE anahtarliyordu:
//
//     mevcut[normalize(ad)] = "lat|lon|ad";
//     if (mevcut.containsKey(n)) continue;
//
// Bir ulkede ayni adi tasiyan iki yer oldugunda ikincisi sessizce
// ATLANIRDI. Turkiye'de Ankara/Golbasi (165.201 kisi) ile
// Adiyaman/Golbasi cakistigi icin kayboldu; ABD'de kullanici "Dallas"
// yazdiginda listedeki kayit 1.118 km uzakta oldugu icin vakitler yanlis
// cikardi. Olcum: 1.271 yer (nufus >= 15.000) eksikti.
//
// COZUM
//   Ayirt etme anahtari (normalize ad, normalize il) CIFTIDIR. Ayni adda iki
//   farkli il varsa ikisi de tutulur; arayuz "Kahramanmaraş / Dulkadiroğlu"
//   biciminde etiketler. Cozum sadece veri katmaninda degil, il bilgisi
//   tasindigi icin KULLANICIYA da ayirt ettirir.
//
// VERI KAYNAKLARI
//   dr5hn/countries-states-cities-database  (ODbL-1.0)
//       Her yerlesimin IL bilgisi: states[].cities[]
//   GeoNames cities500/1000/5000/15000     (CC BY 4.0)
//       Nufus. Merdiven dosyalar birlestirilir; nufusu 500'den kucuk
//       olmayan her yerlesim icin nufus elde edilir.
//   GeoNames admin1CodesASCII.txt           (CC BY 4.0)
//       GeoNames il kodunu il adina cevirir. 2. kolon yerel dilde addir
//       ("Sanliurfa" degil "Şanlıurfa").
//
// CIKTI BICIMI
//   enlem|boylam|ad|il|nufus|takma1,takma2
//
// KULLANIM
//   dart run tool/sehir_verisi_uret.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _GEO_AD = 1;
const _GEO_ENLEM = 4;
const _GEO_BOYLAM = 5;
const _GEO_ULKE = 8;
const _GEO_ADMIN1 = 10;
const _GEO_NUFUS = 14;

/// Nufusu bu degerin ustundeki yerler "Sehirler" sekmesinde gosterilir.
const sehirEsigi = 15000;

/// Ayni yer sayilmasi icin esik (~2 km). Ayni sehrin iki farkli merkez
/// noktasi bu esigin altinda kalir.
const ayniYerKm = 2.0;

/// Turkiye'nin resmi 81 ili.
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

/// Il adi, il merkezinin adindan farkli olan iller.
const Map<String, String> ilTakmaAdlari = {
  'Kocaeli': 'İzmit',
  'Sakarya': 'Adapazarı',
  'Hatay': 'Antakya',
};

/// Buyuk sehirlerde yerel ad ana ad, uluslararasi ad takma ad olur.
const Map<String, List<List<String>>> birlestirilecekler = {
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
  'SA': [
    ['Makkah', 'Mecca'],
    ['Madinah', 'Medina'],
  ],
  'SE': [
    ['Göteborg', 'Gothenburg'],
  ],
};

/// ASCII -> dogru Turkce yazim. YALNIZCA TR verisi icin.
const Map<String, String> turkceSozluk = {
  'Adiyaman': 'Adıyaman',
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
  'Sanliurfa': 'Şanlıurfa',
  'Sirnak': 'Şırnak',
  'Tekirdag': 'Tekirdağ',
  'Usak': 'Uşak',
};

class GeoKayit {
  final String ad;
  final double enlem;
  final double boylam;
  final int nufus;
  final String il;
  GeoKayit(this.ad, this.enlem, this.boylam, this.nufus, this.il);
}

class Kayit {
  String ad;
  double enlem;
  double boylam;
  String il;
  int nufus;
  final List<String> takmaAdlar;

  Kayit(this.ad, this.enlem, this.boylam, this.il, this.nufus, this.takmaAdlar);

  Kayit.kopya(Kayit k)
      : ad = k.ad,
        enlem = k.enlem,
        boylam = k.boylam,
        il = k.il,
        nufus = k.nufus,
        takmaAdlar = List<String>.from(k.takmaAdlar);

  String get satir {
    // Ic ice tirnak kullanmamak icin takma adlari once birlestirilir.
    final takmalar = takmaAdlar.join(',');
    return '${enlem.toStringAsFixed(4)}|'
        '${boylam.toStringAsFixed(4)}|'
        '$ad|$il|$nufus|$takmalar';
  }
  String get koordinat =>
      '${enlem.toStringAsFixed(4)}|${boylam.toStringAsFixed(4)}';
}

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

double kmUzaklik(double e1, double b1, double e2, double b2) {
  const yaricap = 6371.0;
  const pi = 3.14159265358979;
  final dEnlem = (e2 - e1) * pi / 180.0;
  final dBoylam = (b2 - b1) * pi / 180.0;
  final a = pow(sin(dEnlem / 2), 2) +
      cos(e1 * pi / 180.0) * cos(e2 * pi / 180.0) * pow(sin(dBoylam / 2), 2);
  return yaricap * 2 * atan2(sqrt(a), sqrt(1 - a));
}

void main() {
  const gecici = r'C:\Users\malik\AppData\Local\Temp\opencode';
  final dr5hnDosya = File('$gecici\\csc_full.json');
  if (!dr5hnDosya.existsSync()) {
    stderr.writeln('dr5hn kaynak dosyasi yok: ${dr5hnDosya.path}');
    exit(66);
  }

  // --- 1) admin1 kodu -> il adi -----------------------------------------
  // GeoNames il adlarinda tutarsiz sekilde "Province" kelimesi ekli gelir:
  // 3.865 il kodunun 163'unda var. Turkiye'de bir kismi "Niğde Province",
  //   digerleri sadece "Niğde" seklinde. Bu, ekranda "Niğde Province / Niğde"
  //   gibi karisik ciktilar uretir.
  // Cozum: sonundaki genel nitelik kelimesini at. Boylece etiket her yerde
  //   ayni bicimde olur ("Kahramanmaraş / Dulkadiroğlu").
  final ilAdlari = <String, String>{};
  final admin1Dosya = File('$gecici\\geonames\\admin1CodesASCII.txt');
  if (admin1Dosya.existsSync()) {
    for (final satir in admin1Dosya.readAsLinesSync(encoding: utf8)) {
      final p = satir.split('\t');
      if (p.length < 2) continue;
      ilAdlari[p[0]] = _nitelikKaldir(p[1]);
    }
  }
  print('admin1 il kodu: ${ilAdlari.length}');

  // --- 2) GeoNames nufus merdiveni --------------------------------------
  final geo = <String, List<GeoKayit>>{};
  for (final dosyaAdi in const [
    'cities500',
    'cities1000',
    'cities5000',
    'cities15000'
  ]) {
    final f = File('$gecici\\geonames\\$dosyaAdi.txt');
    if (!f.existsSync()) {
      stderr.writeln('UYARI: $dosyaAdi.txt yok, atlaniyor');
      continue;
    }
    var sayac = 0;
    for (final satir in f.readAsLinesSync(encoding: utf8)) {
      final p = satir.split('\t');
      if (p.length <= _GEO_NUFUS) continue;
      final ulke = p[_GEO_ULKE];
      final nufus = int.tryParse(p[_GEO_NUFUS]) ?? 0;
      if (nufus <= 0) continue;
      (geo[ulke] ??= []).add(GeoKayit(
        p[_GEO_AD],
        double.parse(p[_GEO_ENLEM]),
        double.parse(p[_GEO_BOYLAM]),
        nufus,
        ilAdlari['$ulke.${p[_GEO_ADMIN1]}'] ?? '',
      ));
      sayac++;
    }
    print('$dosyaAdi: $sayac kayit');
  }
  print('GeoNames ulke: ${geo.length}');

  // --- 3) dr5hn: il bilgili yerlesimler ---------------------------------
  final ham = json.decode(dr5hnDosya.readAsStringSync(encoding: utf8)) as List;
  final dr5hn = <String, List<Kayit>>{};
  for (final u in ham.cast<Map<String, dynamic>>()) {
    final iso2 = u['iso2'] as String? ?? '';
    if (iso2.length != 2) continue;
    final liste = <Kayit>[];
    for (final il in (u['states'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final ilAdi = (il['name'] as String? ?? '').trim();
      for (final sehir
          in (il['cities'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final ad = (sehir['name'] as String? ?? '').trim();
        if (ad.isEmpty) continue;
        final enlem = double.tryParse(sehir['latitude'] as String? ?? '');
        final boylam = double.tryParse(sehir['longitude'] as String? ?? '');
        if (enlem == null || boylam == null) continue;
        if (enlem < -90 || enlem > 90 || boylam < -180 || boylam > 180) {
          continue;
        }
        liste.add(Kayit(ad, enlem, boylam, ilAdi, 0, []));
      }
    }
    if (liste.isNotEmpty) dr5hn[iso2] = liste;
  }
  var dr5hnToplam = 0;
  for (final e in dr5hn.values) {
    dr5hnToplam += e.length;
  }
  print('dr5hn: ${dr5hn.length} ulke, $dr5hnToplam yerlesim');

  // --- 4) ulke listesi ---------------------------------------------------
  final appUlkeler = (json.decode(
          File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8)) as List)
      .cast<Map<String, dynamic>>();
  final appIso2 = appUlkeler.map((u) => u['iso2'] as String).toSet();

  final sehirDir = Directory('assets/veri/sehirler');
  if (sehirDir.existsSync()) sehirDir.deleteSync(recursive: true);
  sehirDir.createSync(recursive: true);

  var toplamKayit = 0;
  var toplamNufuslu = 0;
  var toplamSehir = 0;
  var eklenenGeo = 0;
  var mukerrerBirlestir = 0;
  var takmaEklenen = 0;
  var nufusAtanan = 0;
  var cakisanTakmaToplam = 0;

  for (final iso in appIso2) {
    final kayitlar = <Kayit>[];

    // (ad, il) ve konum indeksleri
    final adIl = <String, Kayit>{};
    final koordinat = <String, Kayit>{};

    void ekle(Kayit k) {
      final a = '${normalize(k.ad)}|${normalize(k.il)}';
      if (adIl.containsKey(a)) return;
      if (koordinat.containsKey(k.koordinat)) return;
      adIl[a] = k;
      koordinat[k.koordinat] = k;
      kayitlar.add(k);
    }

    // 4a) dr5hn taban (il bilgisi buradan gelir)
    for (final k in dr5hn[iso] ?? const <Kayit>[]) {
      ekle(Kayit.kopya(k));
    }

    final geoListe = geo[iso] ?? const <GeoKayit>[];

    // 4b) Nufus zenginlestirme -- SADECE ISIM ESLESMESIYLE.
    //
    //    Onceki surum nufusu YAKINLIKLA eslestiriyordu ("en yakin 2 km icindeki
    //    kayit"). Bu yanlisti: Kahramanmaras veryusunun nufusu (384.953) 700 m
    //    uzaktaki Dulkadiroglu ve 1,9 km uzaktaki Oniki Subat kayitlarina
    //    yazildi; kullanici 400 binden kucuk bir kasabayi buyuk sehir sanirdi.
    //    Nufus bir yere ait oldugundan, ayni ada sahip kayitlar eslesir.
    final geoAd = <String, List<GeoKayit>>{};
    for (final g in geoListe) {
      (geoAd[normalize(g.ad)] ??= []).add(g);
    }
    for (final k in kayitlar) {
      final adaylar = geoAd[normalize(k.ad)];
      if (adaylar == null || adaylar.isEmpty) continue;
      // Ayni ad birden fazla yerde varsa (Turkiye'de iki "Golbasi"),
      // ayni ildekini ya da en yakini seç.
      GeoKayit? secilen;
      final nIl = normalize(k.il);
      if (nIl.isNotEmpty) {
        for (final g in adaylar) {
          if (normalize(g.il) == nIl) {
            secilen = g;
            break;
          }
        }
      }
      secilen ??= _enYakin(k.enlem, k.boylam, adaylar, esikKm: 30.0);
      if (secilen == null) continue;
      if (secilen.nufus > k.nufus) k.nufus = secilen.nufus;
      nufusAtanan++;
    }

    // 4c) dr5hn'de olmayan onemli GeoNames sehirlerini ekle.
    //
    //    Kural: ayni adla bir kayit varsa YAKINLIK belirleyici.
    //      - 25 km icindeyse ayni sehir: nufusunu tamamla, ili doldur.
    //      - 25 km disindaysa FARKLI bir yerdir: kaydi ekle.
    //    Bu kural olmadan ayni adda iki yerce kaybolurdu (Ankara/Golbasi ile
    //    Adiyaman/Golbasi gibi) veya yer degistirilirdi.
    const ayniSehirKm = 25.0;
    final adIndeksi = <String, List<Kayit>>{};
    for (final k in kayitlar) {
      (adIndeksi[normalize(k.ad)] ??= []).add(k);
    }

    for (final g in geoListe) {
      if (g.nufus < sehirEsigi) continue;
      final ayniAd = adIndeksi[normalize(g.ad)] ?? const <Kayit>[];

      if (ayniAd.isNotEmpty) {
        // Ayni ildeki karsiligi varsa onu kullan, yoksa en yakini.
        Kayit? hedef;
        final nIl = normalize(g.il);
        if (nIl.isNotEmpty) {
          for (final k in ayniAd) {
            if (normalize(k.il) == nIl) {
              hedef = k;
              break;
            }
          }
        }
        hedef ??= _enYakinKayit(g.enlem, g.boylam, ayniAd, esikKm: ayniSehirKm);
        if (hedef != null) {
          // Ayni sehir: nufusu tamamla, il bilgisi bossa doldur.
          if (g.nufus > hedef.nufus) hedef.nufus = g.nufus;
          if (hedef.il.isEmpty && g.il.isNotEmpty) hedef.il = g.il;
          continue;
        }
        // Ayni ad ama uzak -> baska bir yer, yeni kayit ac.
      }

      final anahtar = '${normalize(g.ad)}|${normalize(g.il)}';
      if (adIl.containsKey(anahtar)) continue;

      // Ayni koordinatta baska bir kayit varsa bu AYNI SEHIR'in farkli
      // yazimidir (orn. dr5hn "Mecca", GeoNames "Makkah"). Nufusu ona aktar
      // ve adini takma ad olarak ekle. Nufusu aktarmazsak sehir "0 nufuslu"
      // kalir ve "Sehirler" sekmesine giremez.
      final ayniKoordinat = koordinat[
          '${g.enlem.toStringAsFixed(4)}|${g.boylam.toStringAsFixed(4)}'];
      if (ayniKoordinat != null) {
        if (g.nufus > ayniKoordinat.nufus) ayniKoordinat.nufus = g.nufus;
        // Takma ad ana adla ayni olamaz ("Wien|Vienna,Vienna" gibi bozuk
        // bir satir olurdu).
        if (normalize(ayniKoordinat.ad) != normalize(g.ad) &&
            !ayniKoordinat.takmaAdlar.contains(g.ad)) {
          ayniKoordinat.takmaAdlar.add(g.ad);
          takmaEklenen++;
        }
        continue;
      }

      final yeni = Kayit(g.ad, g.enlem, g.boylam, g.il, g.nufus, []);
      adIl[anahtar] = yeni;
      koordinat[yeni.koordinat] = yeni;
      (adIndeksi[normalize(yeni.ad)] ??= []).add(yeni);
      kayitlar.add(yeni);
      eklenenGeo++;
    }

    // 4d) Turkiye'ye ozgu islemler
    if (iso == 'TR') {
      _turkiyeYazim(kayitlar, adIl, koordinat);
      _turkiyeIlDuzelt(kayitlar);
    }

    // 4e) Buyuk sehirlerde yerel adi ana ad yap
    for (final cift in birlestirilecekler[iso] ?? const <List<String>>[]) {
      if (_endonymBirlestir(kayitlar, adIl, koordinat, cift)) {
        takmaEklenen++;
      }
    }

    // 4f) Ayni koordinatli / yakin konumlu mükerrer kayitlari birlestir
    mukerrerBirlestir += _mukerrerleriBirlestir(kayitlar, koordinat);

    // Yazmadan once: takma adlarin baska bir kaydin ANA ADIYLA cakismadigini
    // garanti et. Birlestirme sirasinda ayni ad iki yerde tutulmus olabilir
    // (orn. Cin'de "Fengcheng" bir kayitta ana ad, baska bir kayitta takma ad).
    // Ayni ad iki kayitta birden gorunmemeli; o kayit zaten o adi iceriyor.
    final anaAdlar = kayitlar.map((k) => normalize(k.ad)).toSet();
    var cakisanTakma = 0;
    for (final k in kayitlar) {
      final onceki = k.takmaAdlar.length;
      k.takmaAdlar.removeWhere((t) => anaAdlar.contains(normalize(t)));
      cakisanTakma += onceki - k.takmaAdlar.length;
    }
    if (cakisanTakma > 0) cakisanTakmaToplam += cakisanTakma;

    // Yaz: alfabetik (normalize ad, sonra il) -- "Köyler" sekmesi icin.
    kayitlar.sort((a, b) {
      final na = normalize(a.ad);
      final nb = normalize(b.ad);
      if (na != nb) return na.compareTo(nb);
      return normalize(a.il).compareTo(normalize(b.il));
    });
    File('${sehirDir.path}/$iso.txt').writeAsStringSync(
        '${kayitlar.map((k) => k.satir).join('\n')}\n',
        encoding: utf8);

    toplamKayit += kayitlar.length;
    for (final k in kayitlar) {
      if (k.nufus <= 0) continue;
      toplamNufuslu++;
      if (k.nufus >= sehirEsigi) toplamSehir++;
    }
  }

  // ulkeler.json sayaclarini yenile
  for (final u in appUlkeler) {
    final f = File('${sehirDir.path}/${u['iso2']}.txt');
    if (!f.existsSync()) continue;
    u['sehirSayisi'] = f
        .readAsLinesSync(encoding: utf8)
        .where((l) => l.trim().isNotEmpty)
        .length;
  }
  File('assets/veri/ulkeler.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(appUlkeler)}\n',
      encoding: utf8);

  print('');
  print('Toplam kayit            : $toplamKayit');
  print('Nufusu bilinen kayit    : $toplamNufuslu');
  print('Sehirler (>= $sehirEsigi) : $toplamSehir');
  print('Koyler                  : ${toplamKayit - toplamSehir}');
  print('GeoNames\'ten eklenen     : $eklenenGeo');
  print('Nufus atanan            : $nufusAtanan');
  print('Mukerrer birlestirilen  : $mukerrerBirlestir');
  print('Takma ad eklenen        : $takmaEklenen');
  print('Cakisan takma ad kaldirilan: $cakisanTakmaToplam');
}

/// Il adinin sonundaki genel nitelik kelimesini atar.
///
/// GeoNames'te ayni il bazen "Nigde", bazen "Niğde Province" olarak yaziliyor.
/// Ekranda "Niğde Province / Niğde" gibi karisik ciktilar olmasin diye
/// temizlenir. Yalnizca bu turden turden-gunel nitelikler temizlenir; adi
/// olusturan kelimelere (ornegin "Kuzey Bati" onceki bolge) dokunulmaz.
String _nitelikKaldir(String ad) {
  var sonuc = ad.trim();
  // Sondaki " Province" / " province" ve yakin surumler
  for (final nitelik in const [
    ' Province',
    ' province',
    ' Prefettura',
    ' prefettura',
    ' Gouvernorat',
  ]) {
    if (sonuc.endsWith(nitelik) && sonuc.length > nitelik.length) {
      sonuc = sonuc.substring(0, sonuc.length - nitelik.length).trim();
    }
  }
  return sonuc;
}

/// [ilKisitli] verilirse yalnizca o ilde arar.
GeoKayit? _enYakin(double enlem, double boylam, List<GeoKayit> liste,
    {String? ilKisitli, double esikKm = ayniYerKm}) {
  GeoKayit? enIyi;
  double enKisa = esikKm;
  for (final g in liste) {
    if (ilKisitli != null && normalize(g.il) != ilKisitli) continue;
    final km = kmUzaklik(enlem, boylam, g.enlem, g.boylam);
    if (km < enKisa) {
      enKisa = km;
      enIyi = g;
    }
  }
  return enIyi;
}

/// Uygulama kayitlari arasinda [esikKm] icinde olan en yakin kayit.
Kayit? _enYakinKayit(
    double enlem, double boylam, List<Kayit> liste, {required double esikKm}) {
  Kayit? enIyi;
  double enKisa = esikKm;
  for (final k in liste) {
    final km = kmUzaklik(enlem, boylam, k.enlem, k.boylam);
    if (km < enKisa) {
      enKisa = km;
      enIyi = k;
    }
  }
  return enIyi;
}

/// ASCII yazimlari resmi Turkce yazima cevirir ve indeksleri gunceller.
void _turkiyeYazim(
    List<Kayit> kayitlar, Map<String, Kayit> adIl, Map<String, Kayit> koordinat) {
  adIl.clear();
  koordinat.clear();
  for (final k in kayitlar) {
    k.ad = turkceSozluk[k.ad] ?? k.ad;
    k.il = turkceSozluk[k.il] ?? k.il;
    adIl['${normalize(k.ad)}|${normalize(k.il)}'] = k;
    koordinat[k.koordinat] = k;
  }
}

/// Turkiye'de il ile il merkezi adinin farkli oldugu durumlari duzeltir ve
/// resmi 81 ilin yazimini garanti eder.
void _turkiyeIlDuzelt(List<Kayit> kayitlar) {
  // a) Il adi, il merkezinin adindan farkli olan iller
  ilTakmaAdlari.forEach((ilAdi, merkezAdi) {
    for (final k in kayitlar) {
      if (normalize(k.ad) != normalize(merkezAdi)) continue;
      k.il = ilAdi;
      return;
    }
  });

  // b) 81 ilin her biri veride var mi? Eksikse UYDURMA. Yanlis koordinat
  //    namaz vaktinde hata verir; dogru olan eksik oldugunu bildirmek.
  //    (GeoNames il bilgisi geldigi icin bu bir guvenlik agidir.)
  final eksiller = <String>[];
  for (final il in turkiyeIlleri) {
    final nIl = normalize(il);
    var varMi = false;
    for (final k in kayitlar) {
      if (normalize(k.il) == nIl || normalize(k.ad) == nIl) {
        varMi = true;
        break;
      }
    }
    if (!varMi) eksiller.add(il);
  }
  if (eksiller.isNotEmpty) {
    stderr.writeln('TURKIYE: bu iller veride bulunamadi (elle eklenmeli): '
        '${eksiller.join(", ")}');
  }
}

/// Yerel adi ana ad yapar, uluslararasi adi takma ad olarak ekler.
bool _endonymBirlestir(
    List<Kayit> kayitlar, Map<String, Kayit> adIl, Map<String, Kayit> koordinat,
    List<String> cift) {
  final anaAd = cift[0];
  final takmaAd = cift[1];
  final nAna = normalize(anaAd);
  final nTakma = normalize(takmaAd);

  // 1) Ana ad olarak duran kayit
  for (final k in kayitlar) {
    if (normalize(k.ad) != nAna) continue;
    // Takma ad ana adla ayni olamaz.
    if (normalize(takmaAd) != nAna && !k.takmaAdlar.contains(takmaAd)) {
      k.takmaAdlar.add(takmaAd);
    }
    // Ayni yerde duran uluslararasi adli ayri kayit varsa birlestir
    for (final d in kayitlar.toList()) {
      if (identical(d, k)) continue;
      if (normalize(d.ad) != nTakma) continue;
      if (kmUzaklik(k.enlem, k.boylam, d.enlem, d.boylam) > 60) continue;
      if (!k.takmaAdlar.contains(d.ad)) k.takmaAdlar.add(d.ad);
      if (d.nufus > k.nufus) k.nufus = d.nufus;
      kayitlar.remove(d);
      adIl.remove('${normalize(d.ad)}|${normalize(d.il)}');
      koordinat.remove(d.koordinat);
    }
    return true;
  }

  // 2) Ana ad yok, uluslararasi ad var: yeniden adlandir
  for (final k in kayitlar) {
    if (normalize(k.ad) != nTakma) continue;
    k.ad = anaAd;
    // Onceki ad (ululasarasi ad) takma ad olarak eklenir. Ancak koordinat
    // birlestirmesi sirasinda ana ad zaten takma adlara yazilmis olabilir
    // (orn.once "Mecca" idi, birlestirmede "Makkah" takma ad oldu; simdi
    // ana ad "Makkah" oluyor). Ayni ad iki kez yazilmamali.
    k.takmaAdlar.removeWhere((t) => normalize(t) == nAna);
    if (!k.takmaAdlar.contains(takmaAd)) k.takmaAdlar.add(takmaAd);
    return true;
  }

  return false;
}

/// Ayni koordinatli kayitlari birlestirir: ayni sehir, iki farkli yazim.
int _mukerrerleriBirlestir(
    List<Kayit> kayitlar, Map<String, Kayit> koordinat) {
  final gorulen = <String, Kayit>{};
  final silinecek = <Kayit>[];
  for (final k in kayitlar) {
    final mevcut = gorulen[k.koordinat];
    if (mevcut == null) {
      gorulen[k.koordinat] = k;
      continue;
    }
    if (normalize(mevcut.ad) == normalize(k.ad)) continue;
    if (!mevcut.takmaAdlar.contains(k.ad)) mevcut.takmaAdlar.add(k.ad);
    if (k.nufus > mevcut.nufus) mevcut.nufus = k.nufus;
    silinecek.add(k);
  }
  for (final k in silinecek) {
    kayitlar.remove(k);
    koordinat.remove(k.koordinat);
  }
  return silinecek.length;
}
