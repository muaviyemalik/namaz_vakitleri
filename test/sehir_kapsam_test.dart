// Sehir verisinin KAPSAM ve BUTUNLUK testi.
//
// BU DOSYA REGRESYON TESTIDIR. Iki ayri hatanin tekrarini engeller:
//
// 1) BUYUK SEHIR KAYBI
//    Ulkeler eklendiginde veri kaynagi (dr5hn) ilce/koy duzeyine odaklanir.
//    Turkiye icin 905 kayit vardi ama 81 ilden yalnizca 13'u bulunabildi;
//    Bursa, Konya, Gaziantep, Kahramanmaras, Diyarbakir gibi 13 buyuk il
//    YOKTU. Kullanici "Kahramanmaras" aradiginda sonuc cikmiyordu.
//
// 2) AD CARGISMESI NEDENIYLE SESSIZ KAYIP
//    Birlestirme kayitlari ISIMLE anahtarliyordu:
//        if (mevcut.containsKey(normalize(ad))) continue;
//    Ayni ulkede ayni adi tasiyan iki yer oldugunda ikincisi atlaniyordu.
//    Turkiye'de Ankara/Golbasi (165.201 kisi) ile Adiyaman/Golbasi
//    cakistigi icin Ankara/Golbasi kayboldu; ABD'de kullanici "Dallas"
//    yazdiginda listedeki kayit 1.118 km uzaktaydi, yani vakitler yanlisti.
//    Olcum: 1.271 yer (nufus >= 15.000) eksikti.
//
// COZUM
//    Ayirt etme anahtari (normalize ad, normalize il) ciftidir. Il bilgisi
//    veri dosyasinda tasinir ("Kahramanmaras|Dulkadiroğlu") ve arayuzde
//    "Kahramanmaras / Dulkadiroğlu" olarak gosterilir.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

/// Turkiye'nin resmi 81 ili.
const turkiyeIlleri = [
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

/// Her ulkede bulunmasi beklenen baslica sehirler.
const ondekiSehirler = <String, List<String>>{
  'TR': [
    'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana', 'Konya',
    'Gaziantep', 'Kahramanmaraş', 'Diyarbakır', 'Denizli', 'Malatya', 'Samsun',
    'Aydın', 'Manisa', 'Eskişehir', 'Tekirdağ', 'İzmit', 'Adapazarı', 'Antakya',
    'Dulkadiroğlu',
  ],
  'US': ['New York City', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
  'DE': ['Berlin', 'Hamburg', 'München', 'Köln', 'Frankfurt am Main'],
  'FR': ['Paris', 'Marseille', 'Lyon', 'Toulouse'],
  'EG': ['Cairo', 'Alexandria'],
  'SA': ['Riyadh', 'Makkah', 'Madinah'],
  'NG': ['Lagos', 'Abuja', 'Kano', 'Ibadan'],
  'ID': ['Jakarta', 'Surabaya', 'Bandung', 'Medan'],
  'MY': ['Kuala Lumpur', 'George Town', 'Johor Bahru'],
  'GB': ['London', 'Manchester', 'Birmingham', 'Glasgow'],
  'PK': ['Karachi', 'Lahore', 'Islamabad'],
  'IR': ['Tehran', 'Mashhad', 'Isfahan'],
  'DZ': ['Algiers', 'Oran', 'Constantine'],
  'RU': ['Moscow', 'Saint Petersburg', 'Kazan'],
  'CN': ['Beijing', 'Shanghai', 'Guangzhou'],
  'JP': ['Tokyo', 'Osaka', 'Kyoto'],
  'IN': ['Mumbai', 'Delhi', 'Hyderabad'],
  'BR': ['São Paulo', 'Rio de Janeiro', 'Brasília'],
  'CA': ['Toronto', 'Montreal', 'Vancouver'],
  'AU': ['Sydney', 'Melbourne', 'Brisbane'],
};

/// Yerel ad -> uluslararasi ad. Tek kayitta birlestirilir.
const endonymCiftleri = <String, List<List<String>>>{
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
    ['Madinah', 'Medina'],
  ],
  'SE': [
    ['Göteborg', 'Gothenburg'],
  ],
};

List<Sehir> sehirleriOku(String iso2) {
  final f = File('assets/veri/sehirler/$iso2.txt');
  if (!f.existsSync()) throw StateError('$iso2 şehir dosyası yok');
  return f
      .readAsLinesSync(encoding: utf8)
      .where((l) => l.trim().isNotEmpty)
      .map(Sehir.satirdan)
      .toList(growable: false);
}

String n(String s) => UlkeVerisi.normalize(s);

void main() {
  group('Kayıt biçimi', () {
    test('altı alanlı yeni biçim doğru çözülüyor', () {
      final s = Sehir.satirdan(
          '37.5825|36.9197|Dulkadiroğlu|Kahramanmaraş|118046|Turkey');
      expect(s.ad, 'Dulkadiroğlu');
      expect(s.enlem, closeTo(37.5825, 0.0001));
      expect(s.boylam, closeTo(36.9197, 0.0001));
      expect(s.il, 'Kahramanmaraş');
      expect(s.nufus, 118046);
      expect(s.takmaAdlar, ['Turkey']);
    });

    test('üç alanlı eski biçim hâlâ okunuyor', () {
      final s = Sehir.satirdan('41.9786|34.0110|Abana');
      expect(s.ad, 'Abana');
      expect(s.il, isEmpty);
      expect(s.nufus, 0);
      expect(s.takmaAdlar, isEmpty);
    });

    test('dört alanlı eski takma ad biçimi hâlâ okunuyor', () {
      // Eski kayitlar: enlem|boylam|ad|takma1,takma2
      final s = Sehir.satirdan('48.1374|11.5755|München|Munich');
      expect(s.ad, 'München');
      expect(s.takmaAdlar, ['Munich']);
      expect(s.il, isEmpty, reason: '4. alan sayı değil, takma ad olmalı');
      expect(s.nufus, 0);
    });

    test('satira ve satirdan birbirinin tersi', () {
      const kaynak = '37.5825|36.9197|Dulkadiroğlu|Kahramanmaraş|118046|a,b';
      expect(Sehir.satirdan(kaynak).satira(), kaynak);
    });

    test('negatif koordinatlar doğru işleniyor', () {
      final s = Sehir.satirdan('-33.9249|-18.4241|Cape Town|Western Cape|0|');
      expect(s.enlem, closeTo(-33.9249, 0.0001));
      expect(s.boylam, closeTo(-18.4241, 0.0001));
    });

    test('virgüllü şehir adı bozulmadan kalıyor', () {
      final s = Sehir.satirdan('38.9072|-77.0369|Washington, D.C.|District of Columbia|0|');
      expect(s.ad, 'Washington, D.C.');
      expect(s.il, 'District of Columbia');
    });
  });

  group('Şehir / köy ayrımı', () {
    test('eşik değeri 15000', () {
      expect(Sehir.sehirEsigi, 15000);
      const buyuk = Sehir(ad: 'X', enlem: 0, boylam: 0, nufus: 15000);
      const kucuk = Sehir(ad: 'Y', enlem: 0, boylam: 0, nufus: 14999);
      const bilinmeyen = Sehir(ad: 'Z', enlem: 0, boylam: 0);
      expect(buyuk.sehirMi, isTrue);
      expect(kucuk.sehirMi, isFalse);
      expect(bilinmeyen.sehirMi, isFalse,
          reason: 'nüfusu bilinmeyen küçük yerleşim köy sayılır');
    });

    test('bölme: şehirler nüfusa göre büyükten küçüğe', () {
      // Kullanıcının şikayet ettiği durum: alfabetik sırada liste "Abana,
      // Acıgül, Adaklı" ile başlıyor, Adana ancak 6. sırada.
      const liste = [
        Sehir(ad: 'Abana', enlem: 0, boylam: 0, nufus: 3956, il: 'Kastamonu'),
        Sehir(ad: 'Adana', enlem: 0, boylam: 0, nufus: 1816750, il: 'Adana'),
        Sehir(ad: 'Acıgül', enlem: 0, boylam: 0, nufus: 6749, il: 'Nevşehir'),
        Sehir(ad: 'İstanbul', enlem: 0, boylam: 0, nufus: 14851000, il: 'İstanbul'),
        Sehir(ad: 'Köy', enlem: 0, boylam: 0, nufus: 0),
      ];
      final (sehirler, koyler) = UlkeVerisi.bol(liste);

      // Şehirler sekmesi: yalnızca 15.000+ ve nüfusa göre sıralı
      expect(sehirler.map((s) => s.ad), ['İstanbul', 'Adana']);

      // Köyler sekmesi: geri kalanlar, dosya sırası korunur
      expect(koyler.map((s) => s.ad), ['Abana', 'Acıgül', 'Köy']);
    });

    test('bölme: aynı nüfuste adla sıralanır (kararlı sıra)', () {
      const liste = [
        Sehir(ad: 'B', enlem: 0, boylam: 0, nufus: 20000),
        Sehir(ad: 'A', enlem: 0, boylam: 0, nufus: 20000),
      ];
      for (var i = 0; i < 5; i++) {
        final (sehirler, _) = UlkeVerisi.bol(liste);
        expect(sehirler.map((s) => s.ad), ['A', 'B'],
            reason: 'her çağrıda aynı sıra olmalı');
      }
    });

    test('bölme: boş listede iki boş liste döner', () {
      final (sehirler, koyler) = UlkeVerisi.bol(const []);
      expect(sehirler, isEmpty);
      expect(koyler, isEmpty);
    });

    test('etiket "İl / İlçe" biçiminde', () {
      const s = Sehir(ad: 'Dulkadiroğlu', enlem: 0, boylam: 0, il: 'Kahramanmaraş');
      expect(s.etiket(), 'Kahramanmaraş / Dulkadiroğlu');
    });

    test('il bilgisi yoksa etiket sadece ad', () {
      const s = Sehir(ad: 'Dulkadiroğlu', enlem: 0, boylam: 0);
      expect(s.etiket(), 'Dulkadiroğlu');
    });

    test('şehrin adı il adıyla aynıysa tekrar etmiyor', () {
      // Kahramanmaraş ili Kahramanmaraş: "Kahramanmaraş / Kahramanmaraş" olmaz.
      const s = Sehir(ad: 'Kahramanmaraş', enlem: 0, boylam: 0, il: 'Kahramanmaraş');
      expect(s.etiket(), 'Kahramanmaraş');
    });

    test('Türkiye verisinde hem şehir hem köy kaydı var', () {
      final sehirler = sehirleriOku('TR');
      final sehir = sehirler.where((s) => s.sehirMi).length;
      final koy = sehirler.where((s) => !s.sehirMi).length;
      expect(sehir, greaterThan(350), reason: 'şehir sekmesi boş kalmamalı');
      expect(koy, greaterThan(300), reason: 'köy sekmesi boş kalmamalı');
    });
  });

  group('Türkiye: 81 ilin tamamı', () {
    late List<Sehir> sehirler;

    setUpAll(() => sehirler = sehirleriOku('TR'));

    test('TR.txt yeterli kayıt içeriyor', () {
      expect(sehirler.length, greaterThanOrEqualTo(1000));
    });

    test('81 ilin her biri kayıtlarda geçiyor', () {
      // İl adı ya bir kaydın "il" alanı ya da bir kaydın adı olabilir.
      final ilAdlari = sehirler.map((s) => s.il).toSet();
      final tumAdlar = sehirler.map((s) => s.ad).toSet();
      final eksikler = turkiyeIlleri
          .where((il) =>
              !ilAdlari.any((x) => n(x) == n(il)) &&
              !tumAdlar.any((x) => n(x) == n(il)))
          .toList();
      expect(eksikler, isEmpty,
          reason: 'Bu iller veri setinde yok: ${eksikler.join(", ")}');
    });

    test('asıl şikayet edilen şehir Kahramanmaraş mevcut', () {
      final km = sehirler.firstWhere(
        (s) => n(s.ad) == 'kahramanmaras',
        orElse: () => throw StateError('Kahramanmaraş bulunamadı'),
      );
      expect(km.ad, 'Kahramanmaraş');
      expect(km.il, 'Kahramanmaraş');
      expect(km.nufus, greaterThan(300000));
      expect(km.enlem, closeTo(37.5, 1.0));
      expect(km.boylam, closeTo(36.9, 1.0));
    });

    test('ilçe adıyla il bilgisi taşınıyor (Dulkadiroğlu)', () {
      final d = sehirler.firstWhere(
        (s) => s.ad == 'Dulkadiroğlu',
        orElse: () => throw StateError('Dulkadiroğlu bulunamadı'),
      );
      expect(d.il, 'Kahramanmaraş');
      expect(d.etiket(), 'Kahramanmaraş / Dulkadiroğlu');
    });

    test('ASCII yazılan adlar resmî Türkçe yazıma çevrilmiş', () {
      final adlar = sehirler.map((s) => s.ad).toList();
      for (final yanlis in [
        'Istanbul', 'Izmir', 'Diyarbakir', 'Agri', 'Sirnak', 'Sanliurfa',
        'Nevsehir', 'Kutahya', 'Canakkale', 'Mus', 'Nigde', 'Usak'
      ]) {
        expect(adlar, isNot(contains(yanlis)), reason: '"$yanlis" kalmış');
      }
    });

    test('il adlarında İngilizce "Province" kelimesi yok', () {
      // GeoNames il adlarının bir kısmı "Nigde Province" biçiminde geliyordu.
      for (final s in sehirler) {
        expect(s.il, isNot(contains('Province')),
            reason: '"${s.il}" içinde Province var');
      }
    });
  });

  group('Aynı adlı farklı yerler ayırt edilebiliyor', () {
    // Bu, "Gölbaşı hangisi?" sorusunun cevabıdır.
    test('Gölbaşı: hem Ankara hem Adıyaman kaydı var', () {
      final sehirler = sehirleriOku('TR');
      final golbasilar = sehirler.where((s) => n(s.ad) == 'golbasi').toList();
      final iller = golbasilar.map((s) => s.il).toSet();
      expect(iller, containsAll(['Ankara', 'Adıyaman']),
          reason: 'Gölbaşı kayıtları: $iller');

      // Ankara'nın Gölbaşı'sı 165.201 kişilik bir ilçe; kaybolmamalı.
      final ankara = golbasilar.firstWhere((s) => s.il == 'Ankara');
      expect(ankara.nufus, greaterThan(150000));
      expect(ankara.enlem, closeTo(39.79, 0.1));

      // Adıyaman'ın Gölbaşı'sı
      final adiyaman = golbasilar.firstWhere((s) => s.il == 'Adıyaman');
      expect(adiyaman.enlem, closeTo(37.78, 0.1));
    });

    test('Gölbaşı araması iki kaydı da buluyor', () {
      final sehirler = sehirleriOku('TR');
      final sonuc = UlkeVerisi.ara(sehirler, 'Gölbaşı');
      expect(sonuc.length, greaterThanOrEqualTo(2));
      // Kullanıcı hangisini seçtiğini etiketten anlar.
      expect(sonuc.map((s) => s.etiket()), contains('Ankara / Gölbaşı'));
      expect(sonuc.map((s) => s.etiket()), contains('Adıyaman / Gölbaşı'));
    });

    test('Dallas: eyaletle birlikte ayrışıyor (ABD)', () {
      // Daha önce listedeki Dallas kaydı Texas'tan 1.118 km uzaktaydı.
      final sehirler = sehirleriOku('US');
      final dallas = sehirler.where((s) => n(s.ad) == 'dallas').toList();
      expect(dallas.length, greaterThan(1),
          reason: 'ABD\'de birden fazla Dallas var');
      final texas = dallas.firstWhere((s) => s.il == 'Texas');
      expect(texas.nufus, greaterThan(1000000));
      expect(texas.etiket(), 'Texas / Dallas');
    });

    test('Ereğli: Zonguldak ve Konya ayrı kayıt', () {
      final sehirler = sehirleriOku('TR');
      final eregli = sehirler.where((s) => n(s.ad) == 'eregli').toList();
      final iller = eregli.map((s) => s.il).toSet();
      expect(iller, containsAll(['Zonguldak', 'Konya']));
    });

    test('hiçbir ülkede aynı (ad, il) çifti iki kez geçmiyor', () {
      // Anahtar (ad, il) olduğu için mükerrer kayıt oluşmamalı.
      for (final iso in ['TR', 'US', 'DE', 'IT', 'IN', 'CN']) {
        final ciftler = sehirleriOku(iso)
            .map((s) => '${n(s.ad)}|${n(s.il)}')
            .toList();
        expect(ciftler.toSet().length, ciftler.length,
            reason: '$iso: mükerrer (ad, il) kaydı');
      }
    });
  });

  group('İl adıyla arama', () {
    test('il adı yazınca o ilin ilçeleri bulunuyor', () {
      final sehirler = sehirleriOku('TR');
      final sonuc = UlkeVerisi.ara(sehirler, 'Kahramanmaraş');
      expect(sonuc, isNotEmpty);
      // İl adı, ilçe adlarında da geçtiği için hepsi eşleşmeli.
      expect(sonuc.map((s) => s.ad), contains('Dulkadiroğlu'));
    });

    test('alakalılık sıralaması: tam eşleşme önce gelir', () {
      // "Kahramanmaras" yazan kullanici once ilin merkezini gormeli;
      // alt dize eslesmesi olan ilceler sonra gelmeli.
      final sonuc = UlkeVerisi.ara(sehirleriOku('TR'), 'Kahramanmaraş');
      expect(sonuc.first.ad, 'Kahramanmaraş');
    });

    test('sonuç sınırı gerçek şehri kesmiyor', () {
      // ABD'de "New York" eyaletinin yüzlerce köyü var. 300 sonuçluk sınır
      // eskiden New York City'yi kesiyordu; alakalılık sıralaması düzeltti.
      final sonuc = UlkeVerisi.ara(sehirleriOku('US'), 'New York');
      expect(sonuc.map((s) => s.ad), contains('New York City'));
      expect(sonuc.first.nufus, greaterThan(1000000),
          reason: 'en büyük eşleşme başta olmalı');
    });

    test('şapkalı ve aksanlı harflerden bağımsız', () {
      final sehirler = sehirleriOku('TR');
      expect(UlkeVerisi.ara(sehirler, 'Hakkari'), isNotEmpty,
          reason: '"Hakkari" yazınca "Hakkâri" bulunmalı');
      expect(UlkeVerisi.ara(sehirler, 'Ağrı'), isNotEmpty);
      expect(UlkeVerisi.ara(sehirler, 'agri'), isNotEmpty);
      expect(UlkeVerisi.ara(sehirler, 'Sanliurfa'), isNotEmpty);
    });
  });

  group('Takma adlar', () {
    endonymCiftleri.forEach((iso, ciftler) {
      for (final cift in ciftler) {
        final anaAd = cift[0];
        final takmaAd = cift[1];
        test('$iso: $anaAd kaydı $takmaAd takma adını taşıyor', () {
          final kayit = sehirleriOku(iso).firstWhere(
            (s) => n(s.ad) == n(anaAd),
            orElse: () => throw StateError('$iso: $anaAd yok'),
          );
          expect(kayit.takmaAdlar, contains(takmaAd));
        });

        test('$iso: $takmaAd araması $anaAd kaydını buluyor', () {
          final sonuc = UlkeVerisi.ara(sehirleriOku(iso), takmaAd);
          expect(sonuc.map((s) => s.ad), contains(anaAd));
        });

        test('$iso: $anaAd ve $takmaAd tek kayıt', () {
          final adlar = sehirleriOku(iso).map((s) => n(s.ad)).toList();
          expect(adlar.where((a) => a == n(anaAd)).length, 1);
          expect(adlar.where((a) => a == n(takmaAd)).length, 0);
        });
      }
    });

    test('aynı takma ad iki kez yazılmıyor', () {
      for (final satir
          in File('assets/veri/sehirler/AT.txt').readAsLinesSync(encoding: utf8)) {
        final p = satir.split('|');
        if (p.length < 6 || p[5].trim().isEmpty) continue;
        final takmalar = p[5].split(',');
        expect(takmalar.toSet().length, takmalar.length,
            reason: 'mükerrer takma ad: $satir');
      }
    });
  });

  group('Öndeki şehirler mevcut', () {
    ondekiSehirler.forEach((iso, beklenen) {
      test('$iso için ${beklenen.length} şehir bulunabiliyor', () {
        final sehirler = sehirleriOku(iso);
        final adlar = sehirler
            .expand((s) => [s.ad, ...s.takmaAdlar])
            .map(n)
            .toSet();
        final eksikler =
            beklenen.where((ad) => !adlar.contains(n(ad))).toList();
        expect(eksikler, isEmpty,
            reason: '$iso eksik şehirler: ${eksikler.join(", ")}');
      });
    });

    test('alt dize araması "New York" yazanı New York City ile eşleştiriyor', () {
      final sonuc = UlkeVerisi.ara(sehirleriOku('US'), 'New York');
      expect(sonuc.map((s) => s.ad), contains('New York City'));
    });
  });

  group('Veri bütünlüğü (tüm ülkeler)', () {
    late List<String> isoKodlari;

    setUpAll(() {
      isoKodlari = Directory('assets/veri/sehirler')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.replaceAll('.txt', ''))
          .toList()
        ..sort();
    });

    test('şehir dosyası olan 245 ülke var', () {
      expect(isoKodlari.length, 245);
    });

    test('her satır "enlem|boylam|ad|il|nüfus|takma" biçiminde', () {
      for (final iso in isoKodlari) {
        for (final satir in File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)) {
          final p = satir.split('|');
          expect(p.length, 6, reason: '$iso: "$satir"');
          final enlem = double.parse(p[0]);
          final boylam = double.parse(p[1]);
          final nufus = int.parse(p[4]);
          expect(enlem, inInclusiveRange(-90, 90), reason: '$iso: "$satir"');
          expect(boylam, inInclusiveRange(-180, 180), reason: '$iso: "$satir"');
          expect(nufus, greaterThanOrEqualTo(0), reason: '$iso: "$satir"');
          expect(p[2].trim(), isNotEmpty, reason: '$iso: "$satir" ad boş');
        }
      }
    });

    test('hiçbir ülkede aynı koordinat iki kez geçmiyor', () {
      for (final iso in isoKodlari) {
        final koordinatlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .map((l) => '${l.split('|')[0]}|${l.split('|')[1]}')
            .toList();
        expect(koordinatlar.toSet().length, koordinatlar.length,
            reason: '$iso: mükerrer koordinat');
      }
    });

    test('takma ad, başka bir kaydın ana adıyla çakışmıyor', () {
      for (final iso in isoKodlari) {
        final satirlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final anaAdlar = satirlar.map((l) => n(l.split('|')[2])).toSet();
        for (final s in satirlar) {
          final p = s.split('|');
          if (p[5].trim().isEmpty) continue;
          for (final t in p[5].split(',')) {
            expect(anaAdlar, isNot(contains(n(t))),
                reason: '$iso: takma ad "$t" ayrıca ana ad olarak geçiyor');
            expect(t.trim(), isNot(p[2].trim()),
                reason: '$iso: takma ad ana adla aynı -> "$s"');
          }
        }
      }
    });

    test('toplam kayıt 155 binin üzerinde', () {
      var toplam = 0;
      for (final iso in isoKodlari) {
        toplam += File('assets/veri/sehirler/$iso.txt')
                .readAsLinesSync(encoding: utf8)
                .where((l) => l.trim().isNotEmpty)
                .length;
      }
      // 148.967 -> 159.783: ad çakışması nedeniyle kaybolan yerler geri geldi.
      expect(toplam, greaterThan(155000));
    });

    test('en az 30 bin kayıtın nüfusu biliniyor', () {
      // "Şehirler" sekmesi bu kayıtlardan beslenir; yeterli olmalı.
      var nufuslu = 0;
      for (final iso in isoKodlari) {
        for (final satir in File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)) {
          if ((int.tryParse(satir.split('|')[4]) ?? 0) > 0) nufuslu++;
        }
      }
      expect(nufuslu, greaterThan(30000));
    });

    test('ülkeler.json şehirSayisi alanları dosyalarla tutarlı', () {
      final ham = File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8);
      final uyumsuz = <String>[];
      for (final satir in ham.split('\n')) {
        final iso = RegExp(r'"iso2":\s*"([A-Z]{2})"').firstMatch(satir)?.group(1);
        final sayi = RegExp(r'"sehirSayisi":\s*(\d+)').firstMatch(satir)?.group(1);
        if (iso == null || sayi == null) continue;
        final f = File('assets/veri/sehirler/$iso.txt');
        if (!f.existsSync()) continue;
        final gercek = f
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .length;
        if (gercek != int.parse(sayi)) {
          uyumsuz.add('$iso: json=$sayi gerçek=$gercek');
        }
      }
      expect(uyumsuz, isEmpty, reason: 'Sayaç uyuşmazlığı: ${uyumsuz.join(", ")}');
    });
  });
}
