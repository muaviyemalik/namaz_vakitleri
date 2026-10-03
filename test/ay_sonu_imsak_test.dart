import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uretim_akisi.dart';

void main() {
  setUpAll(uretimTestiBaslat);
  setUp(testOrtaminiSifirla);
  tearDown(testOrtaminiKapat);

  for (final kayit in ['gecerli', 'yok', 'bozuk']) {
    testWidgets('yil sonunda cevrimdisi acilis: sonraki ay $kayit',
        (tester) async {
      final saat = SabitSaat(DateTime.utc(2026, 12, 31, 20));
      saatKaynagiDegistir(saat);
      final depo = VakitDepo(saat: saat);
      for (final ay in [DateTime(2026, 12), DateTime(2027, 1)]) {
        if (ay.year == 2027 && kayit != 'gecerli') continue;
        final url = Uri.https('api.aladhan.com', '/v1/calendar', {
          'latitude': konumAnkara.enlem.toStringAsFixed(4),
          'longitude': konumAnkara.boylam.toStringAsFixed(4),
          'year': '${ay.year}', 'month': '${ay.month}',
        });
        await depo.agCevabiniIsle(konum: konumAnkara,
            govde: konumCevabiniUret(url), httpDurumKodu: 200,
            istenenGun: ay);
      }
      if (kayit == 'bozuk') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            konumAnkara.onbellekAnahtari(yil: 2027, ay: 1), '{bozuk');
      }
      final kuyruk = AgKuyrugu(konumCevabiniUret);
      await kontrolluAg(kuyruk, () async {
        await sayfayiAc(tester, konumAnkara);
        try {
          // Ag henuz cevap vermeden, gercek depo uzerinden acilis.
          expect(find.text('31.12.2026'), findsOneWidget);
          expect(find.text(kayit == 'gecerli' ? '05:43:00' : '--:--:--'),
              findsOneWidget);
          kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 12,
              durum: 503);
          await akisIlerlet(tester);
          kuyruk.kalanlariTamamla();
          await akisIlerlet(tester);
          final istekSayisi = kuyruk.istekler.length;
          await tester.pump(const Duration(seconds: 3));
          expect(find.text(kayit == 'gecerli' ? '05:43:00' : '--:--:--'),
              findsOneWidget);
          expect(kuyruk.istekler.length, istekSayisi);
          expect(tester.takeException(), isNull);
        } finally {
          await sayfayiKapat(tester, kuyruk);
        }
      });
    });
  }

  testWidgets('gec on indirme yeni sehrin sayacina dokunmaz', (tester) async {
    saatKaynagiDegistir(SabitSaat(DateTime.utc(2026, 9, 30, 20)));
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      try {
        kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 9);
        await akisIlerlet(tester);
        aktifKonum.value = konumParis;
        await akisIlerlet(tester);
        kuyruk.cevapVerIlkBekleyen(konumParis, yil: 2026, ay: 9);
        await akisIlerlet(tester);
        expect(find.text('--:--:--'), findsOneWidget);
        kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 10);
        await akisIlerlet(tester);
        expect(find.text('Paris'), findsOneWidget);
        expect(find.text('--:--:--'), findsOneWidget);
        kuyruk.cevapVerIlkBekleyen(konumParis, yil: 2026, ay: 10);
        await akisIlerlet(tester);
        expect(find.text('08:34:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await sayfayiKapat(tester, kuyruk);
      }
    });
  });

  testWidgets('ay sonu yatsidan sonra onbellekteki yarin imsagina sayar',
      (tester) async {
    // Ankara 30 Eylul 23:00. Yarin 1 Ekim 04:43: kalan 05:43:00.
    final saat = SabitSaat(DateTime.utc(2026, 9, 30, 20));
    saatKaynagiDegistir(saat);
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      try {
        kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 9);
        await akisIlerlet(tester);
        expect(kuyruk.istekler.length, 2,
            reason: 'Uretim sonraki ayi onceden indirmeye baslamali');
        kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 10);
        await akisIlerlet(tester);

        final ekim = await VakitDepo(saat: saat)
            .kayitOku(konumAnkara, yil: 2026, ay: 10);
        expect(ekim?.gun(DateTime(2026, 10, 1))?.saatler['fajr'], '04:43',
            reason: 'Yarinin gercek verisi dogrulanmis onbellekte var');

        expect(find.text('05:43:00'), findsOneWidget,
            reason: 'On indirme bitince saniyelik timer beklenmeden yenilenir');
        // Sabit duvar saati ilerlemez; uretim sayaci bir kere daha calisir.
        await tester.pump(const Duration(seconds: 1));
        await akisIlerlet(tester);
        expect(find.text('30.09.2026'), findsOneWidget);
        final sayaclar = tester.widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((t) => RegExp(r'^(\d{2}|--):(\d{2}|--):(\d{2}|--)$')
                .hasMatch(t))
            .toList();
        expect(sayaclar, contains('05:43:00'),
            reason: '1 Ekim onbellekteyken 30 Eylul gecesi sayac bos kalmamali');
        expect(kuyruk.istekler.length, 2,
            reason: 'Var olan veri icin ek ag istegi gerekmemeli');
        expect(tester.takeException(), isNull);
      } finally {
        await sayfayiKapat(tester, kuyruk);
      }
    });
  });
}
