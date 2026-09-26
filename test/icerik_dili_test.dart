// Icerik dili cozumleme DENETIM testi (3 harfli locale <-> 2 harfli veri anahtari)
//
// Hatanin olcumu: uygulamanin locale'i ISO 639-2/3 (3 harfli), gomulu icerik
// verisi ise ISO 639-1 (2 harfli) kodlarla anahtarlanmis. Eslesme unutuldugu
// icin ayetler['tur'] null donuyor ve `?? ayetler['en']!` ile Turkce secili
// kullanici ICINCE metin goruyordu. Ayni hata ozel gunler sayfasinda da vardi.
//
// Testler gercek uygulama kodunu sinar: veri katmani ve katalog birlikte
// yuklenir (rootBundle flutter test'inde calisir), boylece hem katalog hem
// icerik yolu oldugu gibi sinanir.
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';
import 'package:namaz_vakitleri/data/ozel_gunler.dart';
import 'package:namaz_vakitleri/data/veri_havuzu.dart';
import 'package:namaz_vakitleri/utils/icerik_dili.dart';

void main() {
  // Katalog rootBundle ile okuyor; binding olmadan asset erisimi mümkün değil.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Katalog bir kez yuklenir; butun testler ayni onbelleği kullanir.
  setUpAll(() async {
    await DilKatalogu.yukle();
  });

  group('icerikDilKodu: 3 harfli locale 2 harfli veri anahtarina cevrilir', () {
    test('25 cevrili dilin tamami cozumleniyor', () {
      // Bu 25 kod, uygulamanin gercekten sundugu Locale'lerdir
      // (DilKatalogu.ornek.hazirDiller). Uygulama bu kodlarla acilir.
      final List<String> hazir = DilKatalogu.ornek.hazirDiller;
      expect(hazir.length, 25, reason: 'Cevirisi hazir 25 dil bekleniyor');

      final List<String> cozulemeyenler = <String>[];
      for (final String kod in hazir) {
        final String? iso1 = DilKatalogu.ornek.kodaGore(kod)?.iso1;
        if (iso1 == null || iso1.isEmpty || iso1.length != 2) {
          cozulemeyenler.add(kod);
        }
      }
      expect(cozulemeyenler, isEmpty,
          reason: 'Bu diller 2 harfli koda cevrilemiyor: $cozulemeyenler');
    });

    test(' Turkce tur -> tr olarak cozulur', () {
      expect(icerikDilKodu('tur'), 'tr');
    });

    test('Ingilizce eng -> en olarak cozulur', () {
      expect(icerikDilKodu('eng'), 'en');
    });

    test('Cinca zho -> zh olarak cozulur', () {
      expect(icerikDilKodu('zho'), 'zh');
    });

    test('zaten 2 harfli kod degistirilmez', () {
      expect(icerikDilKodu('tr'), 'tr');
      expect(icerikDilKodu('ar'), 'ar');
    });

    test('bosluk ve buyuk harf tolere edilir', () {
      expect(icerikDilKodu('  TUR '), 'tr');
    });

    test('katalogda olmayan kod oldugu gibi doner (cokmemeli)', () {
      expect(icerikDilKodu('zzz'), 'zzz');
    });
  });

  group('Ayetler ve hadisler artik Turkce geliyor', () {
    test('tur icin Turkce ayet doner, Ingilizce degil', () {
      final List<Map<String, String>> ayetler = VeriHavuzu.ayetleriGetir('tur');
      // Turkce metin, Ingilizce ceviriden tamamen farklidir. Ilk ayet
      // Turkce veride "Bakara Suresi, 152. Ayet" diye etiketlenmis.
      expect(ayetler.first['sure'], contains('Bakara'),
          reason: 'Turkce veri gelmedi, yedek olan Ingilizce icerik geldi');
    });

    test('tur icin Turkce hadis doner', () {
      final List<Map<String, String>> hadisler = VeriHavuzu.hadisleriGetir('tur');
      // Turkce hadis kaynaklari "Buhari" etc. icerir; Ingilizce veride
      // "Sahih al-Bukhari" yazar.
      final String ilkKaynak = hadisler.first['kaynak'] ?? '';
      expect(ilkKaynak, isNot(contains('Bukhari')),
          reason: 'Ingilizce icerik dondu');
    });

    test('zho icin Cince ayet doner', () {
      final List<Map<String, String>> ayetler = VeriHavuzu.ayetleriGetir('zho');
      expect(ayetler.first['meal'], contains(RegExp(r'[\u4e00-\u9fff]')),
          reason: 'Cince metin bekleniyordu');
    });

    test('icerigi olmayan dil (kor) Ingilizceye duser', () {
      // Korce ayet/hadis icerigi yok; yedek dogru davranis Ingilizce.
      final List<Map<String, String>> ayetler = VeriHavuzu.ayetleriGetir('kor');
      expect(ayetler.first['sure'], isNot(contains('Bakara')));
      expect(VeriHavuzu.ayetleriGetir('kor'),
          same(VeriHavuzu.ayetleriGetir('eng')),
          reason: 'Yedek, Ingilizce icerigin ayni listesi olmali');
    });
  });

  group('Ozel gunler sayfasi artik Turkce ve Cince gosteriyor', () {
    test('tur icin Turkce ozel gun doner', () {
      final List<Map<String, String>> gunler = OzelGunler.ozelGunleriGetir('tur');
      expect(gunler.first['isim'], 'Miraç Kandili');
    });

    test('zho icin Cince ozel gun doner', () {
      final List<Map<String, String>> gunler = OzelGunler.ozelGunleriGetir('zho');
      expect(gunler.first['isim'], contains(RegExp(r'[\u4e00-\u9fff]')));
    });

    test('eng icin Ingilizce ozel gun doner', () {
      final List<Map<String, String>> gunler = OzelGunler.ozelGunleriGetir('eng');
      expect(gunler.first['isim'], 'Miraj Night');
    });

    test('her dilde ayni 9 gun var (liste bosalmali)', () {
      for (final String kod in DilKatalogu.ornek.hazirDiller) {
        expect(OzelGunler.ozelGunleriGetir(kod).length, 9,
            reason: '$kod icin gun sayisi bozuldu');
      }
    });
  });
}
