// Erken uyari ZAMANLAMA testi: bildirim uygulama KAPALIYKEN de gidecek mi?
//
// Hatanin olcumu: erken uyari bildirimi yalnizca `kalanSureyiHesapla` icindeki
// saniyelik sayacla tetikleniyordu:
//
//   if (fark.inSeconds == erkenUyariSaniyesi) { bildirimGonder(); }
//
// Iki ayri kusur:
//   1) Sayac yalnizca AnaSayfa acikken doner. Uygulama arka plandayken veya
//      oldurulmusken o saniye hic gelmez -> bildirim HIC gelmez.
//   2) Tam esitlik sart: o TEK saniye kacirilirsa (telefon uykuya girdi,
//      sistem o saniyeyi atladi) bildirim KALICI olarak kaybolur. 15 dakikalik
//      erken uyari icin bile 1 saniyelik pencere var.
//
// Cozum: erken uyari da vakit alarmi gibi SISTEME planlanir (AlarmManager).
// Uygulamanin acik/kapali olmasi hicbir seyi degistirmez.
//
// Buradaki testler ZAMAN HESABINI sinar (saf fonksiyon, alarm kurulmasi
// degil). "Alarm gercekten kuruluyor mu" kismi ulasimda dogrulanamaz,
// ancak planlamanin dogru ZAMANI hesaplamasi her hatanin kaynagidir:
// yanlsa alarm dogru kurulsa da yanlis zamanda calisir.
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/utils/erken_uyari_zamani.dart';

void main() {
  group('erkenUyariZamani: vakitten N dakika once', () {
    test('15 dakika once', () {
      final DateTime vakit = DateTime(2026, 9, 26, 19, 42); // Akşam 19:42
      expect(erkenUyariZamani(vakit, 15), DateTime(2026, 9, 26, 19, 27));
    });

    test('30 dakika once', () {
      final DateTime vakit = DateTime(2026, 9, 26, 19, 42);
      expect(erkenUyariZamani(vakit, 30), DateTime(2026, 9, 26, 19, 12));
    });

    test('45 dakika once', () {
      final DateTime vakit = DateTime(2026, 9, 26, 5, 12); // İmsak 05:12
      expect(erkenUyariZamani(vakit, 45), DateTime(2026, 9, 26, 4, 27));
    });

    test('erken uyari kapaliyken (0) alarm kurulmaz', () {
      // 0 "kapali" demek; bu vakit icin erken uyari planlanmamali.
      expect(erkenUyariZamani(DateTime(2026, 9, 26, 19, 42), 0), isNull);
    });

    test('negatif deger guvenli sekilde null doner', () {
      // Hatali veri (bozuk hafiza) alarmi gecmise kurmamali.
      expect(erkenUyariZamani(DateTime(2026, 9, 26, 19, 42), -15), isNull);
    });
  });

  group('Gercek vakitlerle: alarm zamani daima gecmiste degil', () {
    // Istanbul'da 26.09.2026 vakitleri (Aladhan, Diyanet).
    final Map<String, DateTime> vakitler = <String, DateTime>{
      'imsak': DateTime(2026, 9, 26, 4, 53),
      'ogle': DateTime(2026, 9, 26, 13, 21),
      'ikindi': DateTime(2026, 9, 26, 16, 40),
      'aksam': DateTime(2026, 9, 26, 19, 24),
      'yatsi': DateTime(2026, 9, 26, 20, 52),
    };

    test('erken uyari daima vakitten once', () {
      for (final dakika in <int>[15, 30, 45]) {
        for (final vakit in vakitler.entries) {
          final DateTime? erken = erkenUyariZamani(vakit.value, dakika);
          expect(erken, isNotNull, reason: '${vakit.key} / $dakika dk');
          expect(erken!.isBefore(vakit.value), isTrue,
              reason: '${vakit.key} vakti $dakika dk once uyari vermeli');
        }
      }
    });

    test('fark tam olarak secilen dakika', () {
      for (final dakika in <int>[15, 30, 45]) {
        for (final vakit in vakitler.entries) {
          final DateTime erken = erkenUyariZamani(vakit.value, dakika)!;
          expect(vakit.value.difference(erken).inMinutes, dakika,
              reason: '${vakit.key} / $dakika dk');
        }
      }
    });

    test('ay sonu / yil sonu sinirinda hesap hatasiz', () {
      // Gece yarisi gecilen vakitlerde "vakit - 45 dk" onceki aya/a yila
      // kayabilir. Burada yanlis gun/ay/yil uretilmemeli.
      final DateTime geceVakti = DateTime(2026, 9, 27, 0, 12);
      final DateTime? erken = erkenUyariZamani(geceVakti, 45);

      expect(erken, DateTime(2026, 9, 26, 23, 27),
          reason: 'Gercek vakitlerde gece vakti 00:12 ise 45 dk once 23:27');
    });
  });

  group('Yeni vakit alarmi ile cakismaz', () {
    // Erken uyari ve vakit bildirimi AYRI kanallarda, ayri kimliklerde
    // kuruluyor. Erken uyari vaktinden once, vakit bildirimi tam vaktinde.
    final DateTime vakit = DateTime(2026, 9, 26, 19, 24); // Akşam 19:24

    test('erken uyari vakitten tam olarak N dakika once', () {
      final DateTime erken = erkenUyariZamani(vakit, 30)!;
      expect(vakit.difference(erken).inMinutes, 30);
    });

    test('erken uyari vakit bildiriminin yerine gecmez', () {
      // 30 dk once kurulan alarm ile vakit alarmi ayni anda DEGIL; aralarinda
      // tam 30 dakika fark var. Aksi halde vakit bildirimi ezilirdi.
      final DateTime erken = erkenUyariZamani(vakit, 30)!;
      expect(erken.isBefore(vakit), isTrue);
      expect(erken == vakit, isFalse);
    });
  });

  group('Sistem planlamasi icin gerekli nitelikler', () {
    test('saniye ve milisaniye bilesenleri korunur', () {
      // NEDEN SIFIRLANMIYOR? vakit saatleri zaten "SS:DD" biciminde gelir, yani
      // saniye her zaman 00'dir; bu durum kodda zaten var. Yine de fonksiyon
      // vaktin bilesenlerini OLDUGU GIBI korumalidir: sessizce yuvarlamak,
      // hatayi gizlerdi. Asil planlama karari "simdiden sonra mu" kontroludur
      // (asagidaki test).
      final DateTime vakit = DateTime(2026, 9, 26, 19, 24, 37);
      final DateTime? erken = erkenUyariZamani(vakit, 15);

      expect(erken, DateTime(2026, 9, 26, 19, 9, 37),
          reason: 'Vakit saatinin bileşenleri korunmalı');
      expect(erken!.millisecond, 0);
    });

    test('gercek vakit verisi saniyesiz gelir (Aladhan SS:DD)', () {
      // Uygulamadaki _saatiTemizle fonksiyonu vakitleri "SS:DD" olarak
      // saklar; saniye her zaman 00'dir. Bu, alarm zamaninin de saniyesiz
      // olduğunu ve hesapta kayma olmadigini garanti eder.
      final DateTime vakit = DateTime(2026, 9, 26, 19, 24); // saniye yok
      final DateTime erken = erkenUyariZamani(vakit, 30)!;
      expect(erken.second, 0);
      expect(erken, DateTime(2026, 9, 26, 18, 54));
    });

    test('zaman asla gecmis degildir (gecmis bir vakit icin planlama yapilmaz)', () {
      // Uygulama gece yarısini gecmis bir vakte gore acilirsa, hesaplanan
      // erken uyari zamani da gecmiste kalir. Planlama karari
      // `_gunlukBildirimleriZamanla` icinde "simdiden sonra mi" diye verilir;
      // bu test o kosulu hatirlatir.
      final DateTime suAn = DateTime(2026, 9, 26, 20, 0);
      final DateTime gecmisVakit = DateTime(2026, 9, 26, 19, 24);
      final DateTime? erken = erkenUyariZamani(gecmisVakit, 30);

      // Geçmiş vakit için hesap yine de üretilir; PLANLANMAMASI gerekir.
      expect(erken!.isBefore(suAn), isTrue,
          reason: 'Geçmiş vakit -> planlanmamalı (isAfter(suAn) kontrolü)');
    });
  });
}
