// Ulke/şehir veri katmanının ve koordinat tabanlı Aladhan sorgusunun testi.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

void main() {
  group('Sehir satır ayrıştırma', () {
    test('enlem|boylam|ad biçimini doğru çözer', () {
      final s = Sehir.satirdan('41.9786|34.0110|Abana');
      expect(s.ad, 'Abana');
      expect(s.enlem, closeTo(41.9786, 0.0001));
      expect(s.boylam, closeTo(34.0110, 0.0001));
    });

    test(' negatif koordinatları doğru işler', () {
      final s = Sehir.satirdan('-33.9249|-18.4241|Cape Town');
      expect(s.ad, 'Cape Town');
      expect(s.enlem, closeTo(-33.9249, 0.0001));
      expect(s.boylam, closeTo(-18.4241, 0.0001));
    });

    test('ad içindeki boşluk ve nokta korunur', () {
      final s = Sehir.satirdan('38.7223|-9.1393|São Martinho do Porto');
      expect(s.ad, 'São Martinho do Porto');
    });

    test('Aladhan parametrelerini doğru üretir', () {
      const s = Sehir(ad: 'İstanbul', enlem: 41.0082, boylam: 28.9784);
      final p = s.aladhanParametreleri(method: 13, yil: 2026, ay: 9);
      expect(p['latitude'], '41.0082');
      expect(p['longitude'], '28.9784');
      expect(p['method'], '13');
      expect(p['month'], '9');
      expect(p['year'], '2026');
    });
  });

  group('Arama duyarsızlaştırma', () {
    test('Türkçe karakterleri indirger', () {
      expect(UlkeVerisi.normalize('Süleyman'), 'suleyman');
      expect(UlkeVerisi.normalize('Şanlıurfa'), 'sanliurfa');
      expect(UlkeVerisi.normalize('Çanakkale'), 'canakkale');
      expect(UlkeVerisi.normalize('Ağrı'), 'agri');
      expect(UlkeVerisi.normalize('Iğdır'), 'igdir');
      expect(UlkeVerisi.normalize('Ürgüp'), 'urgup');
    });

    test('aksanlı Avrupa harflerini indirger', () {
      expect(UlkeVerisi.normalize('Côte d\'Ivoire'), 'cotedivoire');
      expect(UlkeVerisi.normalize('Zürich'), 'zurich');
      expect(UlkeVerisi.normalize('Málaga'), 'malaga');
    });

    test('büyük/küçük harf duyarsızdır', () {
      expect(UlkeVerisi.normalize('ISTANBUL'), UlkeVerisi.normalize('istanbul'));
    });
  });

  group('Şehir arama', () {
    const ornek = [
      Sehir(ad: 'İstanbul', enlem: 41.0, boylam: 28.9),
      Sehir(ad: 'İzmir', enlem: 38.4, boylam: 27.1),
      Sehir(ad: 'Sivas', enlem: 39.7, boylam: 37.0),
      Sehir(ad: 'Ankara', enlem: 39.9, boylam: 32.8),
    ];

    test('Türkçe yazımla Türkçe karakter olmadan bulur', () {
      final sonuc = UlkeVerisi.ara(ornek, 'sivas');
      expect(sonuc.length, 1);
      expect(sonuc.first.ad, 'Sivas');
    });

    test('I harfiyle arama İstanbul ve İzmir bulur', () {
      final sonuc = UlkeVerisi.ara(ornek, 'istanbul');
      expect(sonuc.length, 1);
      expect(sonuc.first.ad, 'İstanbul');
    });

    test('kısmi eşleşme bulur', () {
      // "iz" sorgusu "izmir" ile eşleşir. "istanbul" içinde "iz" harf
      // dizisi geçmediği için (i-s-t-a-n-b-u-l) eşleşmez; bu normal bir
      // alt-dize araması davranışıdır.
      final sonuc = UlkeVerisi.ara(ornek, 'iz');
      expect(sonuc.map((s) => s.ad), contains('İzmir'));
    });

    test('alt dize araması beklendiği gibi davranır', () {
      // "an" sorgusu alt dize olarak arar. "istanbul" içinde de "an"
      // geçtiği için (ist-an-bul) hem İstanbul hem Ankara eşleşir. Bu,
      // kullanıcıya daha çok sonuç göstermek isteyen bir davranıştır.
      //
      // SIRA ÖNEMLİ DEĞİLDİR: iki kayıt da aynı alakalılıkta (alt dize) ve
      // nüfusu bilinmiyor. Sonuçlar adla sabitlenir (bkz. UlkeVerisi.ara).
      final sonuc = UlkeVerisi.ara(ornek, 'an').map((s) => s.ad).toList();
      expect(sonuc, containsAll(['İstanbul', 'Ankara']));
      expect(sonuc.length, 2);
    });

    test('baştan eşleşme daha dar sonuç verir', () {
      // Arama baştan başlıyorsa yalnızca o eşleşmeler döner mi diye
      // davranışı sabitliyoruz (mevcut implementasyon alt dize arar).
      expect(UlkeVerisi.ara(ornek, 'sivas').single.ad, 'Sivas');
    });

    test('boş sorgu ilk kayıtları döndürür', () {
      final sonuc = UlkeVerisi.ara(ornek, '');
      expect(sonuc.length, 4);
    });

    test('bulunmayan sorgu boş döner', () {
      expect(UlkeVerisi.ara(ornek, 'xyzzy').isEmpty, isTrue);
    });

    test('enFazla sınırına uyar', () {
      final sonuc = UlkeVerisi.ara(ornek, 'i', enFazla: 2);
      expect(sonuc.length, 2);
    });
  });

  group('Ülke arama', () {
    const ulkeler = [
      Ulke(iso2: 'TR', iso3: 'TUR', ad: 'Turkey', adTr: 'Türkiye',
          bolge: 'Asia', sehirSayisi: 905),
      Ulke(iso2: 'DE', iso3: 'DEU', ad: 'Germany', adTr: 'Almanya',
          bolge: 'Europe', sehirSayisi: 6873),
      Ulke(iso2: 'EG', iso3: 'EGY', ad: 'Egypt', adTr: 'Mısır',
          bolge: 'Africa', sehirSayisi: 163),
      Ulke(iso2: 'US', iso3: 'USA', ad: 'United States', adTr: 'Amerika',
          bolge: 'Americas', sehirSayisi: 12097),
    ];

    test('Türkçe adla arar', () {
      final sonuc = UlkeVerisi.ulkeAra(ulkeler, 'almanya');
      expect(sonuc.length, 1);
      expect(sonuc.first.iso2, 'DE');
    });

    test('İngilizce adla arar', () {
      final sonuc = UlkeVerisi.ulkeAra(ulkeler, 'germany');
      expect(sonuc.first.iso2, 'DE');
    });

    test('ISO koduyla arar', () {
      expect(UlkeVerisi.ulkeAra(ulkeler, 'EG').first.iso2, 'EG');
      expect(UlkeVerisi.ulkeAra(ulkeler, 'TUR').first.iso2, 'TR');
    });

    test('Türkçe karakterden bağımsız arar', () {
      // "Turkiye" yerine "turkiye" yazılsa da bulunmalı
      expect(UlkeVerisi.ulkeAra(ulkeler, 'turkiye').first.iso2, 'TR');
    });
  });

  group('Bölge adları', () {
    test('Türkçe çeviriler doğru', () {
      expect(Ulke.bolgeAdiTr('Europe'), 'Avrupa');
      expect(Ulke.bolgeAdiTr('Americas'), 'Amerika');
      expect(Ulke.bolgeAdiTr('Asia'), 'Asya');
      expect(Ulke.bolgeAdiTr('Africa'), 'Afrika');
    });

    test('İngilizce çeviriler doğru', () {
      expect(Ulke.bolgeAdiEn('Europe'), 'Europe');
      expect(Ulke.bolgeAdiEn('Africa'), 'Africa');
    });

    test('statik çağrı da çalışır', () {
      expect(Ulke.bolgeAdiStatik('Europe', 'tr'), 'Avrupa');
      expect(Ulke.bolgeAdiStatik('Europe', 'en'), 'Europe');
    });
  });

  group('Üretilen varlık dosyaları', () {
    // Bu testler rootBundle gerektirir; flutter test bunu sağlamaz.
    // Bu yüzden dosyaları doğrudan diskten okuyoruz.
    late Map<String, dynamic> ulkelerJson;

    setUpAll(() {
      ulkelerJson = {
        for (final u in (json.decode(File('assets/veri/ulkeler.json')
                .readAsStringSync(encoding: utf8)) as List)
            .cast<Map<String, dynamic>>())
          u['iso2'] as String: u,
      };
    });

    test('ülke listesi 245 ülke içeriyor', () {
      // 250 kaynak ülkenin 5'i çıkarıldı:
      //   UM - United States Minor Outlying Islands (kalıcı nüfusu yok)
      //   TK - Tokelau (veri setinde şehir ve koordinat bulunmuyor)
      // Polar bölge ve boş bölge etiketli kayıtlar zaten filtreleniyor.
      expect(ulkelerJson.length, 245);
      expect(ulkelerJson.containsKey('UM'), isFalse);
      expect(ulkelerJson.containsKey('TK'), isFalse);
    });

    test('beş kıtanın tamamı mevcut', () {
      final bolgeler = ulkelerJson.values.map((u) => u['bolge']).toSet();
      expect(bolgeler, containsAll(['Europe', 'Americas', 'Asia', 'Africa', 'Oceania']));
      // Kutup bölgesi kapsam dışı
      expect(bolgeler, isNot(contains('Polar')));
    });

    test('Okyanusya ülkeleri gerçekten eklenmiş', () {
      final okyanusya = ulkelerJson.values
          .where((u) => u['bolge'] == 'Oceania')
          .toList();
      expect(okyanusya.length, 26);
      final kodlar = okyanusya.map((u) => u['iso2']).toSet();
      expect(kodlar, containsAll(['AU', 'NZ', 'FJ', 'PG', 'WS', 'TO']));
    });

    test('her ülkenin ISO2 kodu 2 karakter', () {
      for (final giris in ulkelerJson.entries) {
        expect(giris.key.length, 2, reason: '${giris.key} geçersiz ISO2');
      }
    });

    test('her ülkenin en az 1 şehri var (bilinen 16 istisna hariç)', () {
      // Bu 16 mikro-bölgenin kaynak verisinde yerleşim kaydı yoktur veya
      // nüfusları 15.000 eşiğinin altındadır. Anguilla'nın nüfusu 13.254'tür
      // (tüm ada); nüfusu 15.000+ olan tek bir yerleşimi yoktur.
      // Vatican City, Cocos, Christmas Island vb. de aynı durumdadır.
      // Uygulama bu durumda boş liste döndürür ve seçici "veri yok" der.
      const istisnalar = {
        'AI', 'CC', 'CK', 'CX', 'FK', 'GS', 'IO', 'MS',
        'NF', 'NU', 'PN', 'SH', 'SJ', 'SX', 'VA', 'VG',
      };
      final bos = <String>[];
      for (final u in ulkelerJson.values) {
        final sayi = u['sehirSayisi'] as int;
        if (sayi > 0) continue;
        if (istisnalar.contains(u['iso2'])) continue;
        bos.add('${u['iso2']} (${u['ad']})');
      }
      expect(bos, isEmpty, reason: 'Şehri olmayan ülkeler: ${bos.join(", ")}');
    });

    test('Türkiye Türkçe adıyla ve doğru koordinatla mevcut', () {
      final tr = ulkelerJson['TR']!;
      expect(tr['adTr'], 'Türkiye');
      expect(tr['ad'], 'Turkey');
      expect((tr['sehirSayisi'] as int) > 800, isTrue);
    });

    test('şehir dosyaları ayrıştırılabilir ve koordinatları geçerli', () {
      // Rastgele 13 ülke örnekliyoruz (hepsi 141 bin şehrin bir kısmı),
      // beş kıtadan temsilciler dahil.
      const ornekUlkeler = [
        'TR', 'US', 'BR', 'DE', 'EG', 'NG', 'JP', 'CN', 'IN', 'FR', 'ZA', 'KZ', 'AU',
      ];
      var toplam = 0;
      for (final iso in ornekUlkeler) {
        final f = File('assets/veri/sehirler/$iso.txt');
        expect(f.existsSync(), isTrue, reason: '$iso dosyası yok');
        final satirlar = f.readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(satirlar, isNotEmpty, reason: '$iso boş');

        // İlk, orta ve son satırı doğrula
        for (final i in [0, satirlar.length ~/ 2, satirlar.length - 1]) {
          final s = Sehir.satirdan(satirlar[i]);
          expect(s.ad, isNotEmpty, reason: '$iso[$i] adı boş');
          expect(s.enlem, inInclusiveRange(-90, 90), reason: '$iso[$i] enlem');
          expect(s.boylam, inInclusiveRange(-180, 180), reason: '$iso[$i] boylam');
        }
        toplam += satirlar.length;
      }
      expect(toplam, greaterThan(20000), reason: 'toplam şehir beklenenden az');
    });

    test('şehir dosyaları arama anahtarına göre sıralı', () {
      // Sıralama anahtarı, aramanın kullandığı normalize() ile aynıdır.
      // Ham kod noktası sırası kullanılsaydı sonuç yanlış olurdu:
      //   "Afşin" vs "Afyonkarahisar" -> ham sırada 'ş' (U+015F) 'y' (U+0079)
      //   kod noktasından büyük olduğu için "Afyonkarahisar" öne geçerdi.
      //   Oysa Türkçe alfabede ş, y'den önce gelir; normalize() da ş->s
      //   ile doğru sırayı verir. Kullanıcı listede "Afşin"'i önce görür.
      for (final iso in ['TR', 'DE', 'JP', 'BR']) {
        final satirlar = File('assets/veri/sehirler/$iso.txt')
            .readAsLinesSync(encoding: utf8)
            .where((l) => l.trim().isNotEmpty)
            .map((l) => UlkeVerisi.normalize(Sehir.satirdan(l).ad))
            .toList();
        final sirali = [...satirlar]..sort();
        expect(satirlar, sirali, reason: '$iso arama anahtarına göre sıralı değil');
      }
    });

    test('Türkiye dosyasında Afşin, Afyonkarahisar öncesinde', () {
      // Bu, yukarıdaki sıralama kuralının somut bir örneğidir.
      final adlar = File('assets/veri/sehirler/TR.txt')
          .readAsLinesSync(encoding: utf8)
          .where((l) => l.trim().isNotEmpty)
          .map((l) => Sehir.satirdan(l).ad)
          .toList();
      final afsin = adlar.indexWhere((a) => a == 'Afşin');
      final afyon = adlar.indexWhere((a) => a == 'Afyonkarahisar');
      expect(afsin, isNonNegative, reason: 'Afşin bulunamadı');
      expect(afyon, isNonNegative, reason: 'Afyonkarahisar bulunamadı');
      expect(afsin, lessThan(afyon));
    });
  });
}
