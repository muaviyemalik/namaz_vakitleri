// Şehir verisinin KAPSAM testi.
//
// BU DOSYA BİR REGRESYON TESTİDİR.
//
// Ne oldu
//   Uygulamaya 245 ülke / 141 bin şehir eklendiğinde, veri kaynağı ilçe ve
//   köy düzeyine odaklanmıştı. Türkiye için 905 kayıt vardı ama bunların
//   içinde Bursa, Konya, Gaziantep, Kahramanmaraş, Diyarbakır gibi 13 büyük
//   il YOKTU. Eski sürümde ana sayfada sabit duran 81 il listesinden yalnızca
//   13'ü bulunabiliyordu. Kullanıcı "Kahramanmaraş" aradığında sonuç çıkmıyordu.
//
// Nasıl düzeltildi
//   1) GeoNames cities15000 (nüfus >= 15.000) mevcut veriyle birleştirildi.
//      Küçük yerleşimler korundu, önemli şehirler eklendi.
//   2) Türkiye için resmî 81 il listesi kanonik Türkçe yazımla garanti edildi.
//   3) İl adı ile il merkezinin adı farklı olan iller için takma ad eklendi
//      (Kocaeli -> İzmit, Sakarya -> Adapazarı, Hatay -> Antakya).
//   4) normalize() artık şapkalı ve aksanlı harfleri de indiriyor; kullanıcı
//      "Hakkari" yazınca "Hakkâri" bulunabiliyor.
//
// Bu test, veri kaynağı yenilenirse aynı kaybın tekrar etmesini engeller.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

/// Türkiye'nin resmî 81 ili, resmî yazımlarıyla.
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

/// Geriye dönük uyum: bu il bir zamanlar veri setinde hiç yoktu.
const kaybolmusIller = [
  'Kahramanmaraş', 'Bursa', 'Konya', 'Gaziantep', 'Diyarbakır', 'Denizli',
  'Malatya', 'Samsun', 'Aydın', 'Manisa', 'Eskişehir', 'Tekirdağ', 'Adıyaman',
  'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ardahan', 'Artvin',
  'Balıkesir', 'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis',
  'Bolu', 'Burdur', 'Çanakkale', 'Çankırı', 'Çorum', 'Düzce', 'Edirne',
  'Elazığ', 'Erzincan', 'Erzurum', 'Giresun', 'Gümüşhane', 'Iğdır', 'Isparta',
  'Karabük', 'Kastamonu', 'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis',
  'Kütahya', 'Mardin', 'Mersin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu',
  'Osmaniye', 'Rize', 'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak',
  'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak',
];

/// Kullanıcının her ülkede araması beklenen başlıca şehirler.
///
/// Bunlar veri kaynağından bağımsız olarak doğrulanır; bir veri
/// güncellemesi bunları düşürürse test kızar.
const ondekiSehirler = <String, List<String>>{
  'TR': [
    'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana', 'Konya',
    'Gaziantep', 'Kahramanmaraş', 'Diyarbakır', 'Denizli', 'Malatya', 'Samsun',
    'Aydın', 'Manisa', 'Eskişehir', 'Tekirdağ', 'İzmit', 'Adapazarı', 'Antakya',
  ],
  'US': ['New York City', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
  'DE': ['Berlin', 'Hamburg', 'München', 'Köln', 'Frankfurt am Main'],
  'FR': ['Paris', 'Marseille', 'Lyon', 'Toulouse'],
  'EG': ['Cairo', 'Alexandria'],
  'SA': ['Riyadh', 'Makkah', 'Madinah'],
  'EGY': [],
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

/// Veriyi dosyadan okuyup [Sehir] listesine çevirir.
List<Sehir> sehirleriOku(String iso2) {
  final f = File('assets/veri/sehirler/$iso2.txt');
  if (!f.existsSync()) {
    throw StateError('$iso2 şehir dosyası yok');
  }
  return f
      .readAsLinesSync(encoding: utf8)
      .where((l) => l.trim().isNotEmpty)
      .map(Sehir.satirdan)
      .toList(growable: false);
}

/// Ada karşılaştırması için kısayol.
String normalizeAd(String ad) => UlkeVerisi.normalize(ad);

/// Bir kaydın kullanıcıya görünen tüm adları (ana ad + takma adlar).
Iterable<String> tumAdlar(Sehir s) => [s.ad, ...s.takmaAdlar];

void main() {
  group('Türkiye: 81 ilin tamamı veri setinde', () {
    late List<Sehir> sehirler;

    setUpAll(() {
      sehirler = sehirleriOku('TR');
    });

    test('TR.txt en az 1000 kayıt içeriyor', () {
      // 905 küçük yerleşim + 81 il + GeoNames ekleri
      expect(sehirler.length, greaterThanOrEqualTo(1000));
    });

    test('81 ilin her biri normalize edilmiş tam eşleşmeyle bulunuyor', () {
      // İl adı ya ana ad ya da takma ad olarak geçer. "Kocaeli" ilinin
      // merkezi İzmit olduğu için kayıt "İzmit|Kocaeli" biçiminde durur;
      // kullanıcı "Kocaeli" yazınca da bulur.
      final normalizeEdilmisler = sehirler
          .expand(tumAdlar)
          .map(UlkeVerisi.normalize)
          .toSet();
      final eksikler = <String>[];
      for (final il in turkiyeIlleri) {
        if (!normalizeEdilmisler.contains(UlkeVerisi.normalize(il))) {
          eksikler.add(il);
        }
      }
      expect(eksikler, isEmpty,
          reason: 'Bu iller veri setinde yok: ${eksikler.join(", ")}');
    });

    test('kaybolmuş illerin tamamı geri geldi', () {
      // Bu liste, ilk veri güncellemesinden sonra kaybolan illerdir.
      // Kullanıcı raporundan sonra eklendi; tekrar kaybolmamalı.
      final normalizeEdilmisler = sehirler
          .expand(tumAdlar)
          .map(UlkeVerisi.normalize)
          .toSet();
      final eksikler = kaybolmusIller
          .where((il) => !normalizeEdilmisler.contains(UlkeVerisi.normalize(il)))
          .toList();
      expect(eksikler, isEmpty,
          reason: 'Eski listedeki il eksik: ${eksikler.join(", ")}');
    });

    test('asıl şikayet edilen şehir Kahramanmaraş mevcut ve doğru yazımlı', () {
      final km = sehirler.firstWhere(
        (s) => UlkeVerisi.normalize(s.ad) == 'kahramanmaras',
        orElse: () => throw StateError('Kahramanmaraş bulunamadı'),
      );
      expect(km.ad, 'Kahramanmaraş'); // ASCII değil, resmî Türkçe yazım
      // Kahramanmaraş merkezi: 37.58 N, 36.93 E civarı
      expect(km.enlem, closeTo(37.5, 1.0));
      expect(km.boylam, closeTo(36.9, 1.0));
    });

    test('ASCII yazılan şehir adları Türkçe yazıma çevrilmiş', () {
      // Veri kaynağı her iki kaynakta da ASCII kullanıyordu: "Istanbul",
      // "Diyarbakir", "Agri". Bunlar kullanıcıya yanlış gösterilmemeli.
      final hamAdlar = sehirler.map((s) => s.ad).toList();
      for (final yanlis in ['Istanbul', 'Izmir', 'Diyarbakir', 'Agri',
        'Sirnak', 'Sanliurfa', 'Mus', 'Nevsehir', 'Kutahya', 'Canakkale']) {
        expect(hamAdlar, isNot(contains(yanlis)),
            reason: '"$yanlis" ASCII biçimde kalmış');
      }
    });
  });

  group('Türkiye: kullanıcının yazdığı biçim bulunabiliyor', () {
    late List<Sehir> sehirler;

    setUpAll(() {
      sehirler = sehirleriOku('TR');
    });

    test('şapkalı a yazmadan Hakkâri bulunuyor', () {
      // Kullanıcı "Hakkari" yazar; veride "Hakkâri" yazıyor.
      final sonuc = UlkeVerisi.ara(sehirler, 'Hakkari');
      expect(sonuc, isNotEmpty);
      expect(sonuc.first.ad, 'Hakkâri');
    });

    test('şapkalı i/noktasız ı yazımından bağımsız buluyor', () {
      expect(UlkeVerisi.ara(sehirler, 'suleymanahmet'), isEmpty);
      expect(UlkeVerisi.ara(sehirler, 'Ağrı'), isNotEmpty);
      expect(UlkeVerisi.ara(sehirler, 'agri'), isNotEmpty);
      expect(UlkeVerisi.ara(sehirler, 'Sanliurfa'), isNotEmpty);
      expect(UlkeVerisi.ara(sehirler, 'Şanlıurfa'), isNotEmpty);
    });

    test('il adı yazınca il merkezi bulunuyor (Kocaeli -> İzmit)', () {
      // Bu üç ilde il adı, il merkezinin adından farklıdır. Kullanıcı
      // "Kocaeli" yazınca o ilin koordinatlarını almalı; kayıt
      // "İzmit|Kocaeli" biçiminde tek satırda durur.
      for (final il in ['Kocaeli', 'Sakarya', 'Hatay']) {
        final n = UlkeVerisi.normalize(il);
        final dogrudan = sehirler
            .where((s) => s.takmaAdlar.any((t) => UlkeVerisi.normalize(t) == n))
            .toList();
        expect(dogrudan, isNotEmpty, reason: '$il için kayıt yok');
        expect(UlkeVerisi.ara(sehirler, il), isNotEmpty,
            reason: '"$il" araması sonuç vermedi');
      }
    });

    test('il adı, il merkezinin kaydında takma ad olarak duruyor', () {
      // Ayrı kayıt olsaydı listede aynı yer iki kez görünürdü.
      // Ana ad = il merkezi, takma ad = il adı.
      const beklenen = {
        // il merkezi -> il adı
        'izmit': 'Kocaeli',
        'adapazari': 'Sakarya',
        'antakya': 'Hatay',
      };
      for (final giris in beklenen.entries) {
        final merkezAdi = giris.key;
        final ilAdi = giris.value;
        final kayit = sehirler.firstWhere(
          (s) => UlkeVerisi.normalize(s.ad) == merkezAdi,
          orElse: () => throw StateError('$merkezAdi bulunamadı'),
        );
        expect(kayit.takmaAdlar.map(UlkeVerisi.normalize),
            contains(UlkeVerisi.normalize(ilAdi)),
            reason: '${kayit.ad} kaydında $ilAdi takma adı yok');
        // İl adı ayrı bir kayıt olarak da geçmemeli.
        expect(
          sehirler.where(
              (s) => UlkeVerisi.normalize(s.ad) == UlkeVerisi.normalize(ilAdi)),
          isEmpty,
          reason: '$ilAdi ayrı kayıt olarak duruyor',
        );
      }
    });

    test('Kocaeli takma adı doğrudan aramada İzmit kaydını buluyor', () {
      final sonuc = UlkeVerisi.ara(sehirler, 'Kocaeli');
      expect(sonuc, isNotEmpty);
      expect(sonuc.first.ad, 'İzmit');
      // Kocaeli'nin merkezi İzmit olduğu için koordinatlar İzmit'inkidir.
      final izmit = sehirler
          .firstWhere((s) => UlkeVerisi.normalize(s.ad) == 'izmit');
      expect(sonuc.first.enlem, closeTo(izmit.enlem, 0.0001));
      expect(sonuc.first.boylam, closeTo(izmit.boylam, 0.0001));
    });
  });

  group('Öndeki şehirler her ülkede mevcut', () {
    ondekiSehirler.forEach((iso2, beklenen) {
      if (beklenen.isEmpty) return; // ISO2 değil, ISO3 kaydı
      test('$iso2 için ${beklenen.length} şehir bulunabiliyor', () {
        final sehirler = sehirleriOku(iso2);
        // Ana adlar ve takma adlar birlikte geçerli sayılır: "Medina"
        // artık "Madinah" kaydının takma adıdır.
        final normalizeEdilmisler = sehirler
            .expand((s) => [s.ad, ...s.takmaAdlar])
            .map(UlkeVerisi.normalize)
            .toSet();
        final eksikler = beklenen
            .where((ad) => !normalizeEdilmisler.contains(UlkeVerisi.normalize(ad)))
            .toList();
        expect(eksikler, isEmpty,
            reason: '$iso2 eksik şehirler: ${eksikler.join(", ")}');
      });
    });

    test('alt dize araması "New York" yazanı New York City ile eşleştiriyor', () {
      // ABD'de düz "New York" kaydı yok; kanonik ad "New York City".
      // Arama alt dize tabanlı olduğu için kullanıcı yine de bulur.
      final sehirler = sehirleriOku('US');
      final sonuc = UlkeVerisi.ara(sehirler, 'New York');
      expect(sonuc.map((s) => s.ad), contains('New York City'));
    });
  });

  group('Takma adlar: kullanıcı hangi dili yazarsa yazsın bulur', () {
    // Veri kaynakları aynı şehri farklı adlarla saklıyordu. GeoNames
    // Almanca şehirlerde uluslararası adı kullanıyor ("Munich"), dr5hn
    // ise yerel adı ("Nürnberg"); ikisi de ayrı kayıt olarak duruyordu.
    // Şimdi tek kayıtta birleşiyor: yerel ad ana ad, uluslararası ad takma ad.
    const birlestirilen = <String, List<List<String>>>{
      // ulke -> [ana ad (yerel), takma ad (uluslararası)]
      'AT': [
        <String>['Wien', 'Vienna'],
      ],
      'BE': [
        <String>['Brussel', 'Brussels'],
        <String>['Antwerpen', 'Antwerp'],
      ],
      'CH': [
        <String>['Genève', 'Geneva'],
      ],
      'CZ': [
        <String>['Praha', 'Prague'],
      ],
      'DE': [
        <String>['München', 'Munich'],
        <String>['Nürnberg', 'Nuremberg'],
      ],
      'GR': [
        <String>['Athenai', 'Athens'],
      ],
      'IT': [
        <String>['Milano', 'Milan'],
        <String>['Firenze', 'Florence'],
        <String>['Napoli', 'Naples'],
        <String>['Roma', 'Rome'],
        <String>['Torino', 'Turin'],
        <String>['Genova', 'Genoa'],
      ],
      'PL': [
        <String>['Warszawa', 'Warsaw'],
      ],
      'PT': [
        <String>['Lisboa', 'Lisbon'],
      ],
      'SA': [
        <String>['Madinah', 'Medina'],
      ],
      'SE': [
        <String>['Göteborg', 'Gothenburg'],
      ],
    };

    birlestirilen.forEach((iso2, ciftler) {
      for (final cift in ciftler) {
        final anaAd = cift[0];
        final takmaAd = cift[1];

        test('$iso2: $anaAd kaydı $takmaAd takma adını da taşıyor', () {
          final sehirler = sehirleriOku(iso2);
          final kayit = sehirler.firstWhere(
            (s) => UlkeVerisi.normalize(s.ad) == UlkeVerisi.normalize(anaAd),
            orElse: () => throw StateError('$iso2: $anaAd bulunamadı'),
          );
          expect(kayit.takmaAdlar, contains(takmaAd),
              reason: '$anaAd kaydında $takmaAd takma adı yok');
        });

        test('$iso2: $takmaAd araması $anaAd kaydını buluyor', () {
          final sehirler = sehirleriOku(iso2);
          final sonuc = UlkeVerisi.ara(sehirler, takmaAd);
          expect(sonuc.map((s) => s.ad), contains(anaAd),
              reason: '"$takmaAd" araması $anaAd kaydını bulamadı');
        });

        test('$iso2: $anaAd ve $takmaAd tek kayıt olarak duruyor', () {
          // Ayrı kayıt olsaydı kullanıcı aynı şehri listede iki kez görürdü.
          final sehirler = sehirleriOku(iso2);
          final adlar = sehirler.map((s) => UlkeVerisi.normalize(s.ad)).toList();
          final anaAdet =
              adlar.where((a) => a == UlkeVerisi.normalize(anaAd)).length;
          final takmaAdet =
              adlar.where((a) => a == UlkeVerisi.normalize(takmaAd)).length;
          expect(anaAdet, 1, reason: '$anaAd $anaAdet kez geçiyor');
          expect(takmaAdet, 0,
              reason: '$takmaAd ayrı kayıt olarak duruyor ($takmaAdet kez)');
        });
      }
    });

    test('takma ad dosya biçiminde de doğru saklanıyor', () {
      // Biçim: enlem|boylam|ad|takma1,takma2
      // Yani 3. ve 4. alan '|' ile, 4. alanın içindeki adlar virgülle
      // ayrılır.
      final s = Sehir.satirdan('48.1374|11.5755|München|Munich');
      expect(s.ad, 'München');
      expect(s.enlem, closeTo(48.1374, 0.0001));
      expect(s.boylam, closeTo(11.5755, 0.0001));
      expect(s.takmaAdlar, ['Munich']);
      expect(s.satira(), '48.1374|11.5755|München|Munich');
    });

    test('birden çok takma ad virgülle ayrılıyor', () {
      final s = Sehir.satirdan('41.8919|12.5113|Roma|Rome, Roma Capitale');
      expect(s.ad, 'Roma');
      expect(s.takmaAdlar, ['Rome', 'Roma Capitale']);
    });

    test('takma adı olmayan kayıtta alan boş kalıyor', () {
      final s = Sehir.satirdan('37.5847|36.9264|Kahramanmaraş');
      expect(s.takmaAdlar, isEmpty);
      expect(s.satira(), '37.5847|36.9264|Kahramanmaraş');
    });

    test('virgüllü şehir adı 3. alanda bozulmadan kalıyor', () {
      // "Washington, D.C." gibi adlarda virgül olabilir; bu 3. alanda
      // olduğu için takma ad ayırıcısıyla karışmaz.
      final s = Sehir.satirdan('38.9072|-77.0369|Washington, D.C.');
      expect(s.ad, 'Washington, D.C.');
      expect(s.takmaAdlar, isEmpty);
      expect(s.satira(), '38.9072|-77.0369|Washington, D.C.');
    });

    test('aynı takma ad iki kez yazılmıyor', () {
      // Arac iki kez calistirilirsa "Wien|Vienna,Vienna" gibi bozuk bir
      // satir olusurdu. Bu, idempotans regresyonudur.
      for (final satir in File('assets/veri/sehirler/AT.txt')
          .readAsLinesSync(encoding: utf8)
          .where((l) => l.split('|').length == 4)) {
        final takmalar = satir.split('|')[3].split(',');
        expect(takmalar.toSet().length, takmalar.length,
            reason: 'mükerrer takma ad: $satir');
      }
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

    test('her dosya "enlem|boylam|ad[|takma,ad]" biçiminde ve dolu', () {
      for (final iso in isoKodlari) {
        final satirlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(satirlar, isNotEmpty, reason: '$iso boş');
        for (final s in satirlar) {
          final parcalar = s.split('|');
          expect(parcalar.length, inInclusiveRange(3, 4),
              reason: '$iso: hatalı satır "$s"');
          final enlem = double.parse(parcalar[0]);
          final boylam = double.parse(parcalar[1]);
          expect(enlem, inInclusiveRange(-90, 90), reason: '$iso: "$s" enlem');
          expect(boylam, inInclusiveRange(-180, 180),
              reason: '$iso: "$s" boylam');
          expect(parcalar[2].trim(), isNotEmpty, reason: '$iso: "$s" ad boş');
          if (parcalar.length == 4) {
            expect(parcalar[3].trim(), isNotEmpty,
                reason: '$iso: "$s" takma ad alanı boş ama ayırıcı var');
            for (final t in parcalar[3].split(',')) {
              expect(t.trim(), isNotEmpty, reason: '$iso: "$s" boş takma ad');
              expect(t.trim(), isNot(parcalar[2].trim()),
                  reason: '$iso: "$s" takma ad ana adla aynı');
            }
          }
        }
      }
    });

    test('hiçbir ülkede aynı ad iki kez geçmiyor', () {
      // Birleştirme sırasında mükerrer kayıt oluşursa arama sonuçları
      // kirlenir ve aynı şehir listede iki kez görünür.
      for (final iso in isoKodlari) {
        final adlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .map((l) => l.split('|')[2])
            .toList();
        final benzersiz = adlar.toSet();
        expect(benzersiz.length, adlar.length,
            reason: '$iso: ${adlar.length - benzersiz.length} mükerrer ad');
      }
    });

    test('hiçbir ülkede aynı koordinat iki kez geçmiyor', () {
      // Ayni koordinat, ayni sehirin iki kopyasi demektir. Iki veri
      // kaynagi farkli adlarla ayni sehiri verirse (Nurnberg/Nuremberg)
      // bu olur ve kullanici listede ayni yeri iki kez gorur.
      for (final iso in isoKodlari) {
        final koordinatlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .map((l) => '${l.split('|')[0]}|${l.split('|')[1]}')
            .toList();
        final benzersiz = koordinatlar.toSet();
        expect(benzersiz.length, koordinatlar.length,
            reason: '$iso: ${koordinatlar.length - benzersiz.length} '
                'mükerrer koordinat (örn. aynı şehir iki adla)');
      }
    });

    test('takma ad başka bir kaydın ana adıyla çakışmıyor', () {
      // "Wien|Vienna" kaydı varken ayrıca "Vienna" diye bir kayıt varsa
      // arama sonuçlarında aynı şehir iki kez çıkar.
      for (final iso in isoKodlari) {
        final satirlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final anaAdlar =
            satirlar.map((l) => normalizeAd(l.split('|')[2])).toSet();
        for (final s in satirlar) {
          final parcalar = s.split('|');
          if (parcalar.length < 4) continue;
          for (final t in parcalar[3].split(',')) {
            expect(anaAdlar, isNot(contains(normalizeAd(t))),
                reason: '$iso: takma ad "$t" ayrıca ana ad olarak geçiyor');
          }
        }
      }
    });

    test('toplam şehir sayısı 148 binin üzerinde', () {
      // Ham veri 150.309 kayıttı. 1.342'si aynı koordinatlı mükerrer
      // kayıttı (örn. BAE'de "Adh Dhayd"/"Al Dhaid") ve tek satıra
      // birleştirildi; diğer adları takma ad olarak korundu.
      var toplam = 0;
      for (final iso in isoKodlari) {
        toplam += File('assets/veri/sehirler/$iso.txt')
                .readAsLinesSync(encoding: utf8)
                .where((l) => l.trim().isNotEmpty)
                .length;
      }
      expect(toplam, greaterThan(148000));
    });

    test('ülkeler.json şehirSayisi alanları dosyalarla tutarlı', () {
      // Geçersiz kalmış bir sayaç, ülke listesinde yanlış bilgi gösterir.
      final ham = File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8);
      final uyumsuz = <String>[];
      for (final satir in ham.split('\n')) {
        final iso = RegExp(r'"iso2":\s*"([A-Z]{2})"').firstMatch(satir)?.group(1);
        final sayi =
            RegExp(r'"sehirSayisi":\s*(\d+)').firstMatch(satir)?.group(1);
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
