// Dil katalogu ve yonlendirme altyapisinin testleri.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show TextDirection;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';

/// Katalogu dosyadan dogrudan yukler. `flutter test` rootBundle saglamadigi
/// icin production'daki rootBundle yolu testte kullanilamaz.
DilKatalogu kataloguYukle() {
  final g = json.decode(
          File('assets/i18n/diller.json').readAsStringSync(encoding: utf8))
      as Map<String, dynamic>;
  return DilKatalogu.testIcin(
    (g['diller'] as List).cast<Map<String, dynamic>>(),
    (g['hazirDiller'] as List?)?.cast<String>() ?? const [],
  );
}

void main() {
  // NOT: `late` degisken group tanim aninda degil, setUpAll sonrasinda hazir
  // olur. Bu yuzden asagidaki gruplarda `katalog` YALNIZCA test govdesi
  // icinde okunur.
  late DilKatalogu katalog;

  setUpAll(() {
    katalog = kataloguYukle();
  });

  group('Katalog butunlugu', () {
    test('152 resmi dil iceriyor', () {
      expect(katalog.diller.length, 152);
    });

    test('her dilin kodu, adi ve ulke listesi dolu', () {
      for (final d in katalog.diller) {
        expect(d.kod, isNotEmpty, reason: 'kod bos');
        expect(d.ad, isNotEmpty, reason: '${d.kod} adi bos');
        expect(d.ulkeler, isNotEmpty, reason: '${d.kod} ulke listesi bos');
        expect(d.ulkeSayisi, d.ulkeler.length,
            reason: '${d.kod}: ulkeSayisi ulkelerle eslesmiyor');
      }
    });

    test('tum ISO2 kodlari 2 karakter', () {
      for (final d in katalog.diller) {
        for (final u in d.ulkeler) {
          expect(u.length, 2, reason: '${d.kod} -> $u gecersiz ISO2');
        }
      }
    });

    test('hazir ceviriler diskteki dosyalarla tutarli', () {
      // Katalog, ceviri dosyasi olan dilleri "hazirDiller" olarak listeler.
      // Bu liste yanlislarsa kullanici olmayan bir dili secebilir.
      final diskteki = Directory('assets/i18n/ceviri')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
          .toSet();
      expect(katalog.hazirDiller.toSet(), diskteki,
          reason: 'hazirDiller listesi diskteki dosyalarla uyusmuyor');
      expect(katalog.hazirDiller, containsAll(['tur', 'eng']));
    });

    test('ceviriler 3 harfli kodla adlandirilmis', () {
      // Dosya adi = katalog kodu = Locale.languageCode olmali. Aksi halde
      // easy_localization dosyayi bulamaz (tr.json vs 'tur' kodu cevisimi
      // bu hatayi yakalayan bir regresyondur).
      for (final kod in katalog.hazirDiller) {
        expect(kod.length, 3, reason: '$kod 3 harfli olmali');
        expect(katalog.kodaGore(kod), isNotNull,
            reason: '$kod katalogda tanimsiz');
      }
    });
  });

  group('Yazim yonu (RTL)', () {
    test('sagdan sola diller dogru isaretli', () {
      const rtlOlmasiGereken = ['ara', 'fas', 'urd', 'heb', 'pus', 'div', 'arc'];
      for (final kod in rtlOlmasiGereken) {
        expect(katalog.rtlMi(kod), isTrue, reason: '$kod RTL olmali');
      }
    });

    test('soldan saga diller yanlis isaretlenmemis', () {
      for (final kod in ['tur', 'eng', 'deu', 'fra', 'spa', 'rus', 'zho']) {
        expect(katalog.rtlMi(kod), isFalse, reason: '$kod LTR olmali');
      }
    });

    test('bilinmeyen kod guvenli sekilde LTR donuyor', () {
      expect(katalog.rtlMi('zzz'), isFalse);
    });

    test('yon cevirisi dogru deger donuyor', () {
      expect(katalog.yon(const Locale('ara')), TextDirection.rtl);
      expect(katalog.yon(const Locale('tur')), TextDirection.ltr);
    });
  });

  group('Locale eslemesi', () {
    test('Locale 3 harfli kodu kullanir', () {
      expect(katalog.kodaGore('tur')!.locale().languageCode, 'tur');
      expect(katalog.kodaGore('ara')!.locale().languageCode, 'ara');
    });

    test('iso1 kodu ile de bulunabiliyor', () {
      expect(katalog.kodaGore('tr')?.kod, 'tur');
      expect(katalog.kodaGore('en')?.kod, 'eng');
      expect(katalog.kodaGore('ar')?.kod, 'ara');
    });

    test('desteklenen yereller yalnizca cevirisi olanlar', () {
      final yereller = katalog.desteklenenYereller;
      for (final l in yereller) {
        expect(katalog.hazirDiller, contains(l.languageCode));
      }
      expect(yereller.length, katalog.hazirDiller.length);
    });
  });

  group('Otokton adlar', () {
    test('ana dillerde otokton ad dogru', () {
      const beklenen = <String, String>{
        'tur': 'Türkçe',
        'eng': 'English',
        'deu': 'Deutsch',
        'fra': 'français',
        'spa': 'Español',
        'ara': 'العربية',
        'rus': 'Русский',
        'fas': 'فارسی',
        'urd': 'اردو',
        'ita': 'Italiano',
        'zho': '中文',
      };
      beklenen.forEach((kod, otokton) {
        final d = katalog.kodaGore(kod);
        expect(d, isNotNull, reason: '$kod katalogda yok');
        expect(d!.otoktonAd, otokton, reason: '$kod otokton adi hatali');
      });
    });

    test('otokton ad tek parca (virgul/parantez icermez)', () {
      // ISO 639 bazi dillerde "français, langue française" gibi birden fazla
      // isim veriyor. Secicide okunmaz oldugu icin uretici ilk parca alir.
      for (final d in katalog.diller) {
        final o = d.otoktonAd;
        if (o == null || o.isEmpty) continue;
        expect(o.contains(','), isFalse, reason: '${d.kod} otokton adinda virgul var');
        expect(o.contains('('), isFalse, reason: '${d.kod} otokton adinda parantez var');
      }
    });

    test('gorunen ad otokton varsa onu donuyor', () {
      expect(katalog.kodaGore('tur')!.gorunenAd(), 'Türkçe');
      expect(katalog.kodaGore('deu')!.gorunenAd(), 'Deutsch');
    });

    test('otokton ad olmayan dilde Ingilizce ada dusuyor', () {
      final otoktonsuz = katalog.diller.where((d) => d.otoktonAd == null).toList();
      for (final d in otoktonsuz) {
        expect(d.gorunenAd(), d.ad, reason: '${d.kod} bos olmamali');
      }
    });
  });

  group('Arama', () {
    test('Turkce karakterden bagimsiz arama', () {
      final s = DilKatalogu.ara(katalog.ceviriliDiller, 'turkce');
      expect(s.map((d) => d.kod), contains('tur'),
          reason: '"turkce" yazisi "Türkçe"yi bulmali');
    });

    test('otokton adla arama', () {
      final s = DilKatalogu.ara(katalog.ceviriliDiller, 'Türkçe');
      expect(s.map((d) => d.kod), contains('tur'));
    });

    test('Ingilizce adla arama', () {
      final s = DilKatalogu.ara(katalog.ceviriliDiller, 'chinese');
      expect(s.map((d) => d.kod), contains('zho'));
    });

    test('ISO koduyla arama', () {
      final s = DilKatalogu.ara(katalog.ceviriliDiller, 'en');
      expect(s.map((d) => d.kod), contains('eng'));
    });

    test('bos sorgu tum listeyi donuyor', () {
      final l = katalog.ceviriliDiller;
      expect(DilKatalogu.ara(l, '').length, l.length);
    });

    test('bulunmayan sorgu bos donuyor', () {
      expect(DilKatalogu.ara(katalog.ceviriliDiller, 'qwertyuiop'), isEmpty);
    });
  });

  group('Ulke -> dil onerisi', () {
    test('Turkiye Turkce oneriyor', () {
      expect(katalog.ulkeninDilleri('TR').map((d) => d.kod), contains('tur'));
    });

    test('oneride ceviri dosyasi olmayan dil yok', () {
      // Oneri yalnizca cevirisi hazir diller icin uretilir; aksi halde
      // kullanici ulkesinin dilini gorse bile metinler bos kalirdi.
      for (final ulke in ['TR', 'EG', 'ID', 'FR', 'DE', 'US', 'SA', 'MY', 'PK']) {
        for (final d in katalog.ulkeninDilleri(ulke)) {
          expect(katalog.hazirDiller, contains(d.kod),
              reason: '$ulke icin ${d.kod} onerildi ama cevirisi yok');
        }
      }
    });

    test('Misir resmi dili Arapca ve katalogda mevcut', () {
      // Arapca henuz cevrilmediği icin oneri bos doner; ancak Arapca Misir'in
      // resmi dili olarak katalogda ve uygun ceviri kaynagina baglanabilir
      // sekilde durmali.
      final misirDilleri = katalog.diller
          .where((d) => d.ulkeler.contains('EG'))
          .map((d) => d.kod)
          .toList();
      expect(misirDilleri, contains('ara'));
    });

    test('Endonezya resmi dili Endonezce ve katalogda mevcut', () {
      final endonezyaDilleri = katalog.diller
          .where((d) => d.ulkeler.contains('ID'))
          .map((d) => d.kod)
          .toList();
      expect(endonezyaDilleri, contains('ind'));
    });

    test('bilinmeyen ulke bos liste donuyor', () {
      expect(katalog.ulkeninDilleri('ZZ'), isEmpty);
    });
  });

  group('Veri butunlugu: 245 ulke kapsami', () {
    test('katalog tum uygulama ulkelerini kapsiyor', () {
      final ulkeler = (json.decode(
              File('assets/veri/ulkeler.json').readAsStringSync(encoding: utf8))
              as List)
          .cast<Map<String, dynamic>>();
      expect(ulkeler.length, 245);

      final kapsanan = katalog.diller.expand((d) => d.ulkeler).toSet();
      final eksikler = ulkeler
          .map((u) => u['iso2'] as String)
          .where((u) => !kapsanan.contains(u))
          .toList();
      expect(eksikler, isEmpty, reason: 'Dili olmayan ulkeler: $eksikler');
    });
  });
}
