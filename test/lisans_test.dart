// Lisans/atif bilgilerinin dogrulugu. ODbL-1.0 kopyalaç bir lisans oldugu
// icin kaynak gosterimi ZORUNLUDUR; bu test eksik kalan bir atfi yakalar.
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/lisans_bilgileri.dart';

void main() {
  group('Lisans girdileri', () {
    test('en az bir veri seti atfi var', () {
      expect(lisansGirdileri, isNotEmpty);
    });

    test('her girdi baslik, aciklama ve lisans iceriyor', () {
      for (final g in lisansGirdileri) {
        expect(g.baslik.trim(), isNotEmpty, reason: 'baslik bos');
        expect(g.aciklama.trim(), isNotEmpty, reason: '${g.baslik}: aciklama bos');
        expect(g.lisans.trim(), isNotEmpty, reason: '${g.baslik}: lisans bos');
      }
    });

    test('kopyalaç lisansli girdilerde kaynak ve adres zorunlu', () {
      // ODbL gibi kopyalaç lisanslarda kaynak gosterimi yasal zorunluluktur.
      final kopyalaclar =
          lisansGirdileri.where((g) => g.kopyalac).toList(growable: false);
      expect(kopyalaclar, isNotEmpty, reason: 'kopyalac kaynak bekleniyor');
      for (final g in kopyalaclar) {
        expect(g.kaynak, isNotNull, reason: '${g.baslik}: kaynak eksik');
        expect(g.url, isNotNull, reason: '${g.baslik}: adres eksik');
        expect(g.url, startsWith('https://'),
            reason: '${g.baslik}: adres https olmali');
      }
    });

    test('ODbL kopyalaç kaynaklari isaretli', () {
      // Iki veri seti ODbL-1.0: ulke/sehir ve ulke-dil.
      final odbl = lisansGirdileri
          .where((g) => g.lisans.contains('ODbL'))
          .toList(growable: false);
      expect(odbl.length, 2,
          reason: 'ODbL lisansli kaynak sayisi degisti, kontrol et');
      for (final g in odbl) {
        expect(g.kopyalac, isTrue, reason: '${g.baslik} kopyalac isaretlenmeli');
      }
    });

    test('ODbL aciklamasi kopyalaç yukumlulugunu belirtiyor', () {
      // Bu metin uygulama icinde gosteriliyor; yasal zeminde anlamli olmasi
      // icin kaynak gosterme zorunlulugunu acikca belirtmeli.
      //
      // NOT: Turkce yazim nedeniyle olcumler KOK ile yapilir:
      //   "zorunludur" / "zorundadir" -> kok: "zorun"
      //   "kaynagini" / "kaynağını"    -> kok: "kayna"
      // Tam kelime aramak biri gecer biri gecerse test kirilir.
      final kucuk = odblAciklamasi.toLowerCase();
      expect(odblAciklamasi, contains('ODbL-1.0'));
      expect(kucuk, contains('zorun'), reason: 'zorunluluk belirtilmeli');
      expect(kucuk, contains('kayna'), reason: 'kaynak kavrami gecmeli');
      expect(kucuk, contains('kopyala'), reason: 'kopyalac niteligi belirtilmeli');
    });

    test('MIT lisansli kaynak kopyalac olarak isaretlenmemis', () {
      // iso-639 MIT lisanslidir; ODbL gibi atif zorunlulugu getirmez ama
      // yine de dogru siniflandirilmis olmali.
      final mit = lisansGirdileri.firstWhere((g) => g.lisans == 'MIT');
      expect(mit.kopyalac, isFalse);
    });

    test('servisler API anahtari gerektirmiyor', () {
      final aladhan =
          lisansGirdileri.firstWhere((g) => g.kaynak!.contains('Aladhan'));
      expect(aladhan.aciklama.toLowerCase(), contains('anahtar'));
    });

    test('adresler benzersiz', () {
      final adresler =
          lisansGirdileri.map((g) => g.url).whereType<String>().toList();
      expect(adresler.toSet().length, adresler.length,
          reason: 'ayni adres iki kez geciyor');
    });
  });

  group('Uygulama bilgisi', () {
    test('surum bicimi dogru', () {
      expect(uygulamaSurumu, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });

    test('pubspec ile uyumlu surum', () {
      // pubspec.yaml'daki surum ile ayni olmali; aksi halde kullanicilar
      // ekranda gormeye devam eder.
      const pubspecSurumu = '1.0.0';
      expect(uygulamaSurumu, pubspecSurumu);
    });

    test('uygulama adi bos degil', () {
      expect(uygulamaAdi.trim(), isNotEmpty);
    });
  });
}
