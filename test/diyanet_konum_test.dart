import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/diyanet_konum.dart';
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cozucu = DiyanetKonumCozucu(DiyanetDepo());
  test(
    'Offline GPS aynı adlı iki Ortaköy yerleşimini doğru il/ID ile ayırır',
    () async {
      for (final (lat, lon, il) in [
        (38.7373, 34.0387, 'Aksaray'),
        (40.2735, 35.2518, 'Çorum'),
      ]) {
        final s = await cozucu.coz(enlem: lat, boylam: lon, hassasiyet: 30);
        expect(s, isNotNull);
        expect(s!.sehir.ad, 'Ortaköy');
        expect(s.sehir.il, il);
        final e = await diyanetDepo.eslemeBul(il: il, ad: 'Ortaköy');
        expect(e, isNotNull);
        expect(e!.parca, il == 'Aksaray' ? 'TR/aksaray.txt' : 'TR/corum.txt');
      }
    },
  );
  test('İlçe belirsiz, güvenilir il varsa açık il merkezi sonucu', () async {
    final s = await cozucu.coz(
      enlem: 39.89,
      boylam: 32.86,
      hassasiyet: 100,
      ulke: 'TR',
      il: 'ANKARA',
      adlar: ['Çankaya'],
    );
    expect(s!.sehir.ad, 'Ankara');
    expect(s.ilMerkezi, isTrue);
  });
  test(
    'Yabancı ülke, kötü hassasiyet, uzak/çelişkili geocoder tahmin edilmez',
    () async {
      expect(
        await cozucu.coz(
          enlem: 39.7904,
          boylam: 32.809,
          hassasiyet: 30,
          ulke: 'DE',
        ),
        isNull,
      );
      expect(
        await cozucu.coz(
          enlem: 39.7904,
          boylam: 32.809,
          hassasiyet: 5000,
          ulke: 'TR',
        ),
        isNull,
      );
      expect(
        await cozucu.coz(
          enlem: 48.85,
          boylam: 2.35,
          hassasiyet: 30,
          ulke: 'TR',
          il: 'Ankara',
          adlar: ['Gölbaşı'],
        ),
        isNull,
      );
      expect(
        await cozucu.coz(
          enlem: 39.7904,
          boylam: 32.809,
          hassasiyet: 30,
          ulke: 'TR',
          il: 'Adıyaman',
          adlar: ['Gölbaşı'],
        ),
        isNull,
      );
    },
  );
  test('Eski kayıt yalnız aynı isim ve yakın koordinatla taşınır', () async {
    expect((await cozucu.eskiKayit('ANKARA', 39.9334, 32.8597))!.il, 'Ankara');
    expect(
      (await cozucu.eskiKayit('Gölbaşı', 37.7836, 37.6367))!.il,
      'Adıyaman',
    );
    expect(await cozucu.eskiKayit('Gölbaşı', 39.9334, 32.8597), isNull);
    expect(await cozucu.eskiKayit('Paris', 48.85, 2.35), isNull);
  });
  test(
    'Geç GPS ve eski manuel işlem son manuel seçimi/state/kaydı ezmez',
    () async {
      SharedPreferences.setMockInitialValues({});
      aktifUlkeKodu.value = 'TR';
      final gps = konumSecimiBaslat();
      final bekleyen = konumAyarla(
        const Sehir(
          ad: 'Ankara',
          il: 'Ankara',
          enlem: 39.9334,
          boylam: 32.8597,
        ),
        secimSurumu: gps,
        ulke: 'TR',
      );
      await konumAyarla(
        const Sehir(
          ad: 'Polatlı',
          il: 'Ankara',
          enlem: 39.5772,
          boylam: 32.1413,
        ),
      );
      await bekleyen;
      await konumAyarla(
        const Sehir(
          ad: 'Ankara',
          il: 'Ankara',
          enlem: 39.9334,
          boylam: 32.8597,
        ),
        secimSurumu: gps,
      );
      expect(aktifKonum.value!.ad, 'Polatlı');
      expect(aktifKonum.value!.diyanetCityId, isNotNull);
      expect(aktifKonum.value!.diyanetParca, 'TR/ankara.txt');
      final h = await SharedPreferences.getInstance();
      expect(h.getString(kayitliKonumAnahtari), startsWith('Polatlı|TR|'));
    },
  );
}
