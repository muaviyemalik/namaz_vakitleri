// Sayac ve ana ekran widget'i performans DENETIM testi.
//
// Amaci varsayimi olcmek: "Timer.periodic ust uste kurulunca gercekten kac
// kez tetikleniyor?" ve "saniye saniye ayni veri yazilirsa widget kac kez
// uyaniyor?".
//
// Testler sayfanin kendisini degil, sayfanin kullandigi karar mantigini
// sinar: VakitWidgetVerisi (lib/utils/vakit_widget_verisi.dart) dogrudan
// uygulama kodudur. Sayac olcumu ise Dart'in Timer davranisini olcer; amac
// duzeltmenin gerekcesini sayilarla gostermek icin (bkz. timezone_denetim_test.dart).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/utils/vakit_widget_verisi.dart';

void main() {
  group('VakitWidgetVerisi: ayni icerik tekrar gelirse yazma yapilmaz', () {
    test('ilk gelen icerik yazilir', () {
      final VakitWidgetVerisi v = VakitWidgetVerisi();
      expect(v.yazmaliMi('Aksam', '18:42'), isTrue,
          reason: 'Widget henuz bos; ilk deger yazilmalidir');
    });

    test('saniye saniye ayni icerik yazmaz', () {
      final VakitWidgetVerisi v = VakitWidgetVerisi();
      v.yazmaliMi('Aksam', '18:42');

      // Kalan sure her saniye yeniden hesaplaniyor, ama vakit adi ve saati
      // degismiyor. 60 saniye boyunca ayni deger geliyor.
      int yazilan = 0;
      for (int saniye = 0; saniye < 60; saniye++) {
        if (v.yazmaliMi('Aksam', '18:42')) yazilan++;
      }

      expect(yazilan, 0,
          reason: 'Icerik degismedigi icin 60 saniyede 0 yazma olmali');
    });

    test('vakit degisince yeniden yazilir', () {
      final VakitWidgetVerisi v = VakitWidgetVerisi();
      v.yazmaliMi('Aksam', '18:42');

      expect(v.yazmaliMi('Yatsi', '20:11'), isTrue,
          reason: 'Yeni vakit geldi; widget guncellenmelidir');
      // Yeni vakit de saniyelerce ayni kaliyor.
      expect(v.yazmaliMi('Yatsi', '20:11'), isFalse);
    });

    test('dil degisince (cevrilmis ad degisince) yeniden yazilir', () {
      final VakitWidgetVerisi v = VakitWidgetVerisi();
      v.yazmaliMi('Aksam', '18:42'); // Turkce

      // Kullanici Ingilizceye gecirdi: vakit anahtari ayni, metin farkli.
      expect(v.yazmaliMi('Maghrib', '18:42'), isTrue,
          reason: 'Ayni vakit, farkli dilde ad; widget eski metni gostermemeli');
    });

    test('saat ayni ama ad farkli ise yazilir', () {
      final VakitWidgetVerisi v = VakitWidgetVerisi();
      v.yazmaliMi('Gunes', '06:12');
      expect(v.yazmaliMi('Imsak', '06:12'), isTrue);
    });
  });

  group('Sayac: Timer.periodic ust uste kurulmamali', () {
    testWidgets('IPTAL EDILMEZSE her yenilemede bir timer daha birikir',
        (tester) async {
      // Uygulamadaki ESKI desen: Timer.periodic her cagrida yeniden kuruluyor,
      // onceki iptal edilmiyor. vakitleriGetir() her sehir/yontem degisiminde
      // sayaciBaslat() cagirir.
      final List<Timer> timercular = [];
      int tetiklenme = 0;
      void sayaciBaslatEski() {
        timercular.add(Timer.periodic(
            const Duration(seconds: 1), (_) => tetiklenme++));
      }

      for (int i = 0; i < 5; i++) {
        sayaciBaslatEski(); // 5 kez sehir degistirdik
      }
      await tester.pump(const Duration(seconds: 1));

      print('ESKI desen -> 5 yenileme sonrasi 1 saniyede $tetiklenme tetiklenme');
      expect(tetiklenme, 5,
          reason: 'Tek bir kullanici eylemi saniyede 5 kez calisiyor');

      for (final Timer t in timercular) {
        t.cancel();
      }
    });

    testWidgets('IPTAL EDILDIGINDE (duzeltme) her zaman tek timer kalir',
        (tester) async {
      // Uygulamadaki YENI desen: onceki timer iptal ediliyor.
      Timer? zamanlayici;
      int tetiklenme = 0;
      void sayaciBaslatYeni() {
        zamanlayici?.cancel();
        zamanlayici = Timer.periodic(
            const Duration(seconds: 1), (_) => tetiklenme++);
      }

      for (int i = 0; i < 5; i++) {
        sayaciBaslatYeni();
      }
      await tester.pump(const Duration(seconds: 1));

      print('YENI desen -> 5 yenileme sonrasi 1 saniyede $tetiklenme tetiklenme');
      expect(tetiklenme, 1,
          reason: 'Yenileme sayisindan bagimsiz olarak saniyede 1 kez');

      // 10 saniye daha gece: timer birikmeye devam etmemeli.
      await tester.pump(const Duration(seconds: 10));
      expect(tetiklenme, 11, reason: '10 saniye daha -> toplam 11 tetiklenme');

      zamanlayici?.cancel();
    });
  });
}
