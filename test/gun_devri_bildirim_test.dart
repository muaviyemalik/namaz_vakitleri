import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ana_sayfa_bildirim_test.dart' show kimlikDiziniAnahtari, yabanciKimlik;
import 'bildirim_hata_durumu_test.dart' show HataEklentisi;
import 'bildirim_uyari_gosterimi_test.dart' show metinBul;
import 'uretim_akisi.dart';

void main() {
  setUpAll(uretimTestiBaslat);
  setUp(() {
    testOrtaminiSifirla();
    bildirimYoluTasarimiAyarla(true);
    bildirimPlanSirasiDegistir(PlanSirasi());
  });
  tearDown(() {
    bildirimYoluTasarimiAyarla(null);
    bildirimServisiDegistir(FlutterLocalNotificationsPlugin());
    bildirimPlanSirasiDegistir(PlanSirasi());
    testOrtaminiKapat();
  });

  for (final resumed in [false, true]) {
    for (final kurulumda in [false, true]) {
      for (final yeniVeriOnce in [false, true]) {
        testWidgets('gun devri resumed=$resumed kurulumda=$kurulumda '
            'yeniVeriOnce=$yeniVeriOnce', (tester) async {
          final saat = SabitSaat(DateTime.utc(2026, 9, 15, 20, 59, 59));
          saatKaynagiDegistir(saat);
          final eklenti = HataEklentisi();
          eklenti.android.tamZamanliVar = false;
          if (kurulumda) {
            eklenti.ilkKurulumuBeklet();
          } else {
            eklenti.ilkIzniBeklet();
          }
          bildirimServisiDegistir(eklenti);
          final kuyruk = AgKuyrugu(_farkliGunCevabi);
          await kontrolluAg(kuyruk, () async {
            await sayfayiAc(tester, konumAnkara);
            try {
              kuyruk.cevapVer(0);
              await akisIlerlet(tester);
              expect(find.text('15.09.2026'), findsOneWidget);
              expect(
                kurulumda ? eklenti.kurulumdaBekleyen : eklenti.izindeBekleyen,
                1,
              );
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(
                konumAnkara.onbellekAnahtari(yil: 2026, ay: 9),
              );

              await _gunuDegistir(tester, saat, resumed);
              expect(find.text('15.09.2026'), findsNothing);
              expect(
                kuyruk.istekler.length,
                2,
                reason: 'Yeni gunun verisi henuz gelmedi, eski gun temizlendi',
              );

              if (yeniVeriOnce) {
                // Yeni veri görünür, fakat yeni plan kendi izin kapısında kalır.
                // Eski sonucun yeni sonuçla örtülmeden ölçülmesi gerekir.
                eklenti.ilkIzniBeklet();
                kuyruk.cevapVer(1);
                await akisIlerlet(tester);
                expect(find.text('16.09.2026'), findsOneWidget);
                expect(eklenti.izindeBekleyen, kurulumda ? 1 : 2);
              }
              if (kurulumda) {
                eklenti.kurulumuSerbestBirak();
              } else {
                eklenti.izniSerbestBirak();
              }
              await akisIlerlet(tester);
              expect(
                eklenti.izindeBekleyen,
                yeniVeriOnce ? 1 : 0,
                reason: 'Gec sorgu mutlaka tamamlansin',
              );
              if (kurulumda) {
                expect(
                  eklenti.cagriLog.where((c) => c.startsWith('kur:')),
                  isNotEmpty,
                  reason: 'Bekleyen sistem cagrisi gercekten tamamlandi',
                );
              } else {
                expect(
                  eklenti.kurulumLog,
                  isEmpty,
                  reason: 'Eski izin sonucu hic plan uygulamamali',
                );
              }
              expect(
                tester.takeException(),
                isNull,
                reason: 'Bekleyen plan temizlenmis _bugun verisine dokunmamali',
              );
              expect(
                metinBul('exact_alarm_yok'),
                findsNothing,
                reason: 'Eski yaklasik planin uyarisi sizmamali',
              );
              expect(metinBul('bildirim_kurulamadi'), findsNothing);
              expect(
                eklenti.bekleyen,
                isEmpty,
                reason: 'Yeni plan beklerken de eski plan temizlenmeli',
              );
              expect(prefs.getStringList(kimlikDiziniAnahtari) ?? [], isEmpty);

              eklenti.android.tamZamanliVar = true;
              if (yeniVeriOnce) {
                eklenti.izniSerbestBirak();
              } else {
                kuyruk.cevapVer(1);
              }
              await akisIlerlet(tester);
              expect(find.text('16.09.2026'), findsOneWidget);
              expect(
                eklenti.bekleyen,
                isNotEmpty,
                reason: 'Yeni gunun gecerli plani bastirilmamali',
              );
              final imsak = eklenti.bekleyen.values.where(
                (t) =>
                    t.year == 2026 &&
                    t.month == 9 &&
                    t.day == 16 &&
                    t.hour == 4,
              );
              expect(imsak.map((t) => t.minute), [
                44,
              ], reason: 'Yeni gunun 04:44 verisi kullanilmali');
              expect(eklenti.bekleyen.values.every((t) => t.day >= 16), isTrue);
              expect(
                prefs.getStringList(kimlikDiziniAnahtari)!.toSet(),
                eklenti.bekleyen.keys.map((id) => '$id').toSet(),
              );
              expect(eklenti.izindeBekleyen, 0);
              expect(metinBul('exact_alarm_yok'), findsNothing);
              expect(metinBul('bildirim_kurulamadi'), findsNothing);
              expect(tester.takeException(), isNull);
            } finally {
              eklenti.tumIzinleriSerbestBirak();
              eklenti.kurulumuSerbestBirak();
              await sayfayiKapat(tester, kuyruk);
            }
          });
        });
      }
    }
    testWidgets('gorunen eski uyari gun devrinde temizlenir resumed=$resumed', (
      tester,
    ) async {
      final saat = SabitSaat(DateTime.utc(2026, 9, 15, 20, 59, 59));
      saatKaynagiDegistir(saat);
      final eklenti = HataEklentisi();
      eklenti.android.tamZamanliVar = false;
      bildirimServisiDegistir(eklenti);
      final kuyruk = AgKuyrugu(_farkliGunCevabi);
      await kontrolluAg(kuyruk, () async {
        await sayfayiAc(tester, konumAnkara);
        try {
          kuyruk.cevapVer(0);
          await akisIlerlet(tester);
          expect(metinBul('exact_alarm_yok'), findsOneWidget);
          eklenti.bekleyen[yabanciKimlik] = eklenti.bekleyen.values.first;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(konumAnkara.onbellekAnahtari(yil: 2026, ay: 9));
          await _gunuDegistir(tester, saat, resumed);
          expect(metinBul('exact_alarm_yok'), findsNothing);
          expect(eklenti.bekleyen.keys, [
            yabanciKimlik,
          ], reason: 'Yalniz motorun eski plani temizlenmeli');
          eklenti.android.tamZamanliVar = true;
          eklenti.ilkIzniBeklet();
          kuyruk.cevapVer(1);
          await akisIlerlet(tester);
          expect(eklenti.izindeBekleyen, 1);
          expect(find.text('16.09.2026'), findsOneWidget);
          expect(
            metinBul('exact_alarm_yok'),
            findsNothing,
            reason: 'Yeni plan bitmeden eski uyari yeniden gorunmemeli',
          );
          eklenti.izniSerbestBirak();
          await akisIlerlet(tester);
          expect(eklenti.motorunBekleyenleri(), isNotEmpty);
          expect(metinBul('exact_alarm_yok'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          eklenti.tumIzinleriSerbestBirak();
          await sayfayiKapat(tester, kuyruk);
        }
      });
    });
  }
}

Future<void> _gunuDegistir(
  WidgetTester tester,
  SabitSaat saat,
  bool resumed,
) async {
  if (resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }
  saat.ilerlet(const Duration(seconds: 2));
  if (resumed) {
    // Fake timer ilerlemez: yalniz resumed yolu olculur.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  } else {
    await tester.pump(const Duration(seconds: 2));
  }
  await akisIlerlet(tester);
}

String _farkliGunCevabi(Uri url) {
  final cevap = jsonDecode(konumCevabiniUret(url)) as Map<String, dynamic>;
  for (final gun in cevap['data'] as List) {
    if (gun['date']['gregorian']['date'] == '16-09-2026') {
      gun['timings']['Fajr'] = '04:44';
    }
  }
  return jsonEncode(cevap);
}
