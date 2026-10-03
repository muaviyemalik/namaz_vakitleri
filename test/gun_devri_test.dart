import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uretim_akisi.dart';

void main() {
  setUpAll(uretimTestiBaslat);
  setUp(testOrtaminiSifirla);
  tearDown(testOrtaminiKapat);

  testWidgets('acik ekran sehirde gece yarisinda tarihi ve geri sayimi yeniler',
      (tester) async {
    // Ankara: 15 Eylül 23:59:59. Cihaz takvimi değil şehrin günü ölçülür.
    final saat = SabitSaat(DateTime.utc(2026, 9, 15, 20, 59, 59));
    saatKaynagiDegistir(saat);
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      try {
        expect(find.text('15.09.2026'), findsOneWidget);
        expect(find.text('04:43:01'), findsOneWidget,
            reason: 'Başlangıçta 16 Eylül 04:43 imsağına geri sayılır');

        // Hiç resumed/konum/ayar olayı yok: gerçek üretim timer'ı çalışır.
        saat.ilerlet(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        await akisIlerlet(tester);

        final gorunen = tester.widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((t) => RegExp(r'^\d{2}\.\d{2}\.\d{4}$|^\d+:\d{2}:\d{2}$')
                .hasMatch(t))
            .toList();
        expect(gorunen, containsAll(['16.09.2026', '04:42:59']),
            reason: '16 Eylül 00:00:01: bugün 16 Eylül, sıradaki imsak '
                'bugün 04:43 olmalı; 17 Eylüle atlanmamalı');
        expect(tester.takeException(), isNull);
      } finally {
        await sayfayiKapat(tester, kuyruk);
      }
    });
  });

  for (final aySiniri in [false, true]) {
    for (final resumed in [false, true]) {
      for (final kayit in ['gecerli', 'yok', 'bozuk']) {
        testWidgets('gun devri aySiniri=$aySiniri resumed=$resumed cache=$kayit',
            (tester) async {
          final eski = DateTime(2026, 9, aySiniri ? 30 : 15);
          final yeni = DateTime(2026, 9, eski.day + 1);
          final saat = SabitSaat(DateTime.utc(2026, 9, eski.day, 20, 59, 59));
          saatKaynagiDegistir(saat);
          final kuyruk = AgKuyrugu((url) => _gunlukCevap(url, yeni));
          await kontrolluAg(kuyruk, () async {
            await sayfayiAc(tester, konumAnkara);
            try {
              kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 9);
              await akisIlerlet(tester);
              if (aySiniri) {
                kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 10);
                await akisIlerlet(tester);
              }
              expect(find.text(_tarih(eski)), findsOneWidget);
              expect(find.text('12:59'), findsOneWidget);

              final prefs = await SharedPreferences.getInstance();
              final anahtar = konumAnkara.onbellekAnahtari(yil: yeni.year, ay: yeni.month);
              if (kayit == 'yok') await prefs.remove(anahtar);
              if (kayit == 'bozuk') await prefs.setString(anahtar, '{bozuk');
              final istekSayisi = kuyruk.istekler.length;
              if (resumed) {
                tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
              }
              saat.ilerlet(const Duration(seconds: 2));
              if (resumed) {
                // Timer ilerlemeden yalnız yaşam döngüsü ile ölç.
                tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
              } else {
                await tester.pump(const Duration(seconds: 2));
              }
              await akisIlerlet(tester);
              expect(find.text(_tarih(eski)), findsNothing);
              expect(find.text('12:59'), findsNothing);
              if (kayit == 'gecerli') {
                expect(find.text(_tarih(yeni)), findsOneWidget);
                expect(find.text('13:01'), findsOneWidget);
                expect(find.text('04:43:59'), findsOneWidget);
                expect(kuyruk.istekler.length, istekSayisi,
                    reason: 'Doğrulanmış yeni gün çevrimdışı kullanılmalı');
              } else {
                expect(find.text(_tarih(yeni)), findsNothing);
                expect(find.text('13:01'), findsNothing);
                expect(find.text('04:43:59'), findsNothing);
                expect(kuyruk.istekler.length, istekSayisi + 1);
                // Aynı yükleme sürerken yinelenen resumed + timer yeni istek açamaz.
                for (var i = 0; i < 3; i++) {
                  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
                  await tester.pump(const Duration(seconds: 1));
                }
                expect(kuyruk.istekler.length, istekSayisi + 1);
                // Ağ hiç cevap vermiyor: gerçek http timeout yolu.
                await tester.pump(const Duration(seconds: 11));
                await akisIlerlet(tester);
                expect(find.byIcon(Icons.cloud_off), findsOneWidget);
                expect(find.text(_tarih(eski)), findsNothing);
                expect(find.text(_tarih(yeni)), findsNothing);
              }
              for (var i = 0; i < 20; i++) {
                saat.ilerlet(const Duration(seconds: 1));
                await tester.pump(const Duration(seconds: 1));
              }
              expect(kuyruk.istekler.length, istekSayisi + (kayit == 'gecerli' ? 0 : 1),
                  reason: 'Başarı veya timeout sonrası saniyelik istek olmamalı');
              expect(tester.takeException(), isNull);
            } finally {
              await sayfayiKapat(tester, kuyruk);
            }
          });
        });
      }
    }
  }

  for (final basarili in [false, true]) {
    testWidgets('gece yarisini asan yukleme basarili=$basarili paralel acilmaz',
        (tester) async {
      final saat = SabitSaat(DateTime.utc(2026, 9, 15, 20, 59, 59));
      saatKaynagiDegistir(saat);
      final kuyruk = AgKuyrugu(konumCevabiniUret);
      await kontrolluAg(kuyruk, () async {
        await sayfayiAc(tester, konumAnkara);
        try {
          saat.ilerlet(const Duration(seconds: 2));
          await tester.pump(const Duration(seconds: 2));
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await akisIlerlet(tester);
          expect(kuyruk.istekler.length, 1);
          kuyruk.cevapVer(0, durum: basarili ? 200 : 503);
          await akisIlerlet(tester);
          expect(find.text('15.09.2026'), findsNothing);
          if (!basarili) {
            expect(kuyruk.istekler.length, 2);
            kuyruk.cevapVer(1);
            await akisIlerlet(tester);
          }
          expect(find.text('16.09.2026'), findsOneWidget);
          expect(find.text('04:42:59'), findsOneWidget);
          expect(kuyruk.istekler.length, basarili ? 1 : 2);
        } finally {
          await sayfayiKapat(tester, kuyruk);
        }
      });
    });
  }

  testWidgets('ay sinirinda bekleyen on indirmeye katilir', (tester) async {
    final saat = SabitSaat(DateTime.utc(2026, 9, 30, 20, 59, 59));
    saatKaynagiDegistir(saat);
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      try {
        kuyruk.cevapVer(0);
        await akisIlerlet(tester);
        expect(kuyruk.istekler.length, 2);
        saat.ilerlet(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await akisIlerlet(tester);
        expect(find.text('30.09.2026'), findsNothing);
        expect(kuyruk.istekler.length, 2);
        kuyruk.cevapVer(1);
        await akisIlerlet(tester);
        expect(find.text('01.10.2026'), findsOneWidget);
        expect(find.text('04:42:59'), findsOneWidget);
        expect(kuyruk.istekler.length, 2);
      } finally {
        await sayfayiKapat(tester, kuyruk);
      }
    });
  });

  testWidgets('tekrarlanan gun devri timer biriktirmez ve dispose durdurur',
      (tester) async {
    final saat = _OlculenSaat(DateTime.utc(2026, 9, 15, 21));
    saatKaynagiDegistir(saat);
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      try {
        kuyruk.cevapVer(0);
        await akisIlerlet(tester);
        Future<int> besSaniyeyiOlc() async {
          final once = saat.okuma;
          for (var i = 0; i < 5; i++) {
            saat.ilerlet(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
          }
          return saat.okuma - once;
        }

        final ilk = await besSaniyeyiOlc();
        expect(ilk, greaterThan(0));
        for (var gun = 0; gun < 3; gun++) {
          saat.ilerlet(const Duration(days: 1));
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await akisIlerlet(tester);
          expect(await besSaniyeyiOlc(), ilk,
              reason: 'Her yenilemeden sonra saniyelik iş miktarı sabit kalmalı');
        }
        expect(kuyruk.istekler.length, 1);
      } finally {
        await sayfayiKapat(tester, kuyruk);
      }
      final kapandi = saat.okuma;
      await tester.pump(const Duration(seconds: 30));
      expect(saat.okuma, kapandi, reason: 'dispose sonrası timer çalışmamalı');
    });
  });

  testWidgets('gun devri yuklenirken yeni sehir kazanir ve gec cevap karismaz',
      (tester) async {
    final saat = SabitSaat(DateTime.utc(2026, 9, 15, 20, 59, 59));
    saatKaynagiDegistir(saat);
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      try {
        kuyruk.cevapVer(0);
        await akisIlerlet(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(konumAnkara.onbellekAnahtari(yil: 2026, ay: 9));
        saat.ilerlet(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        await akisIlerlet(tester);
        aktifKonum.value = konumTokyo;
        await akisIlerlet(tester);
        kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: 2026, ay: 9);
        await akisIlerlet(tester);
        kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: 2026, ay: 9);
        await akisIlerlet(tester);
        expect(find.text('Tokyo'), findsOneWidget);
        expect(find.text('04:24'), findsOneWidget);
        expect(find.text('04:43'), findsNothing);
        expect(aktifKonum.value!.saatDilimi, 'Asia/Tokyo');
        expect(kuyruk.istekler.length, 3);
      } finally {
        await sayfayiKapat(tester, kuyruk);
      }
    });
  });
}

String _tarih(DateTime tarih) =>
    '${tarih.day.toString().padLeft(2, '0')}.'
    '${tarih.month.toString().padLeft(2, '0')}.${tarih.year}';

class _OlculenSaat extends SabitSaat {
  _OlculenSaat(super.baslangic);
  int okuma = 0;

  @override
  DateTime simdi() {
    okuma++;
    return super.simdi();
  }
}

// Günler bilerek farklı: yalnız tarihi değiştirip eski vakitleri tutmak geçemez.
String _gunlukCevap(Uri url, DateTime yeni) {
  final cevap = jsonDecode(konumCevabiniUret(url)) as Map<String, dynamic>;
  for (final gun in cevap['data'] as List) {
    if (gun['date']['gregorian']['date'] == _tarih(yeni).replaceAll('.', '-')) {
      gun['timings']['Fajr'] = '04:44';
      gun['timings']['Dhuhr'] = '13:01';
    }
  }
  return jsonEncode(cevap);
}
