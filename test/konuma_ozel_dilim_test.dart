import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  const cin = Konum(
    ad: 'Shanghai',
    ulkeIso2: 'CN',
    enlem: 31.23,
    boylam: 121.47,
    saatDilimi: 'Asia/Shanghai',
  );
  const ankara = Konum(
    ad: 'Ankara',
    ulkeIso2: 'TR',
    enlem: 39.9334,
    boylam: 32.8597,
    saatDilimi: 'Europe/Istanbul',
  );
  final depo = VakitDepo(saat: SabitSaat(DateTime.utc(2026, 10, 9)));
  Future<void> yaz(Konum k) async {
    await depo.kayitYaz(
      k,
      CevapGecerli(
        gunler: [
          VakitGunu(
            yil: 2026,
            ay: 10,
            gun: 9,
            hicriTarih: '',
            saatler: const {
              'fajr': '05:30',
              'sunrise': '07:00',
              'dhuhr': '12:00',
              'asr': '16:15',
              'maghrib': '18:00',
              'isha': '19:00',
            },
            saatDilimi: k.saatDilimi,
            cevapYontemId: 3,
          ),
        ],
        saatDilimi: k.saatDilimi,
        cevapYontemId: 3,
        cevapEnlem: k.enlem,
        cevapBoylam: k.boylam,
      ),
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Çin ve Ankara dilimleri birbirini ezmez; tekrar yüklemede korunur',
    () async {
      await yaz(cin);
      expect(await depo.kayitliSaatDilimi(ankara), isNull);
      await yaz(ankara);
      final yeniDepo = VakitDepo(saat: depo.saat);
      expect(await yeniDepo.kayitliSaatDilimi(cin), 'Asia/Shanghai');
      expect(await yeniDepo.kayitliSaatDilimi(ankara), 'Europe/Istanbul');
      expect(
        await yeniDepo.kayitliSaatDilimi(ankara.kopyala(boylam: 33)),
        isNull,
      );
    },
  );
  test(
    'Konumsuz eski dilim yeni şehre taşınmaz; aylık kayıt korunur',
    () async {
      await yaz(ankara);
      final h = await SharedPreferences.getInstance();
      for (final key in h.getKeys().where(
        (k) => k.startsWith('vakit_dilim_v2_'),
      )) {
        await h.remove(key);
      }
      await h.setString('vakit_dilim_${ankara.hesapAnahtari}', 'Asia/Shanghai');
      expect(await depo.kayitliSaatDilimi(ankara), isNull);
      expect(
        (await depo.kayitOku(ankara, yil: 2026, ay: 10))!.saatDilimi,
        'Europe/Istanbul',
      );
      expect(
        h.getString('vakit_dilim_${ankara.hesapAnahtari}'),
        'Asia/Shanghai',
      );
    },
  );
}
