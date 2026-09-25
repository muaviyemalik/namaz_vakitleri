// Bu dosya, `flutter create` ile gelen ve uygulamayla hiç ilgisi olmayan
// varsayılan "counter" testiydi; sayaç uygulaması olmadığı için zaten
// başarısızdı. Yerine uygulamanın gerçek, platform eklentisi gerektirmeyen
// iş mantığını sınayan testler yazıldı.
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/utils/kible_hesapla.dart';

void main() {
  group('KibleHesaplayici', () {
    test('Kuzey Kutbu yakininda kible yonu guneydoguya yakin olmali', () {
      // Enlem 89.9, boylam 0 noktasindan Kabe guneydogu yonunde yer alir;
      // bu nedenle beklenen aci 0 degil, yaklasik 140 derecedir.
      final double aci = KibleHesaplayici.hesapla(89.9, 0.0);
      expect(aci, closeTo(140.15, 0.5));
    });

    test('Istanbul icin kible yonu dogu-kuzeydogu tarafindadir', () {
      // Istanbul Kible acisi yaklasik 158 derece (guneydogu-kuzeydogu).
      final double aci = KibleHesaplayici.hesapla(41.0082, 28.9784);
      expect(aci, greaterThan(140));
      expect(aci, lessThan(175));
    });

    test('sonuc her zaman 0-360 araligindadir', () {
      // Kureyi oldukca cesitli noktalarla dolasp.
      for (double enlem = -80; enlem <= 80; enlem += 20) {
        for (double boylam = -180; boylam <= 180; boylam += 20) {
          final double aci = KibleHesaplayici.hesapla(enlem, boylam);
          expect(aci, greaterThanOrEqualTo(0), reason: 'enlem=$enlem boylam=$boylam');
          expect(aci, lessThan(360), reason: 'enlem=$enlem boylam=$boylam');
        }
      }
    });

    test('Kabe noktasindan kible aci sifirdir', () {
      final double aci = KibleHesaplayici.hesapla(
        KibleHesaplayici.kabeEnlem,
        KibleHesaplayici.kabeBoylam,
      );
      expect(aci, closeTo(0, 0.001));
    });
  });
}
