import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namaz_vakitleri/pages/ayarlar_sayfasi.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uretim_akisi.dart';

void main() {
  setUpAll(uretimTestiBaslat);
  setUp(testOrtaminiSifirla);
  tearDown(testOrtaminiKapat);
  const londra = Konum(
    ad: 'Londra',
    ulkeIso2: 'GB',
    enlem: 51.5074,
    boylam: -0.1278,
    saatDilimi: 'Europe/London',
    yontemId: 3,
  );

  testWidgets('Dar ekranda ayar düğmesi; resmî kaynaktaki yüksek enlem kapalı', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      aktifVakitDurumu.value = null;
    });
    const ankara = Konum(ad: 'Ankara', ulkeIso2: 'TR', enlem: 39.9334,
        boylam: 32.8597, saatDilimi: 'Europe/Istanbul', il: 'Ankara', diyanetCityId: 9206);
    aktifKonum.value = ankara;
    aktifResmiDiyanet.value = true;
    aktifVakitDurumu.value = const VakitDurumu(konum: ankara,
        kaynak: VakitKaynagi.resmiDiyanet, gelecekGunler: []);
    await tester.pumpWidget(EasyLocalization(path: 'assets/i18n/ceviri',
      supportedLocales: const [Locale('tur'), Locale('eng')],
      fallbackLocale: const Locale('tur'), assetLoader: const BellekCevirici(),
      child: const MaterialApp(home: AyarlarSayfasi())));
    await akisIlerlet(tester);
    final asr = tester.widget<DropdownButton<AsrYontemi>>(find.byType(DropdownButton<AsrYontemi>));
    // Menüde görünen metin artık HAM KOD (`standart`) değil, kullanıcı diline
    // çevrilmiş addır; model ve önbellek `kod` alanını kullanmaya devam eder.
    expect((asr.items!.first.child as Text).data, AsrYontemi.standart.ceviriAdi);
    expect(asr.onChanged, isNull);
    expect(asr.value, isNull);
    final resmiAnahtar = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'kaynak_diyanet'.tr()));
    final asrDegeri = aktifAsrYontemi.value;
    final alan = find.byType(DropdownButton<YuksekEnlemAyaru>);
    await tester.ensureVisible(alan);
    await tester.pump();
    expect(tester.widget<DropdownButton<YuksekEnlemAyaru>>(alan).onChanged, isNull);
    expect(find.text('ayar_kapali_resmi_not'.tr()), findsAtLeastNWidgets(1));
    expect(find.text('calculation_source_note'.tr()), findsNothing);
    resmiAnahtar.onChanged!(false);
    await akisIlerlet(tester);
    expect(find.byType(AyarlarSayfasi), findsOneWidget,
        reason: 'Diyanet anahtarı ana route’u kapatıp siyah ekran üretmez');
    expect((await SharedPreferences.getInstance()).getBool(kayitliResmiDiyanetAnahtari), isFalse);
    resmiAnahtar.onChanged!(true);
    await akisIlerlet(tester);
    expect(find.byType(AyarlarSayfasi), findsOneWidget);
    expect(tester.widget<DropdownButton<YuksekEnlemAyaru>>(alan).onChanged, isNull);
    aktifVakitDurumu.value = const VakitDurumu(konum: ankara,
        kaynak: VakitKaynagi.ag, gelecekGunler: []);
    await tester.pump();
    await tester.ensureVisible(find.text('calculation_source_note'.tr()));
    expect(find.text('calculation_source_note'.tr()), findsOneWidget);
    expect(tester.widget<DropdownButton<YuksekEnlemAyaru>>(alan).onChanged, isNotNull);
    await tester.ensureVisible(alan);
    await tester.pump();
    await tester.tap(alan);
    await tester.pumpAndSettle();
    await tester.tap(find.text(YuksekEnlemAyaru.yedideBir.ceviriAdi).last);
    await tester.pumpAndSettle();
    expect(aktifYuksekEnlemAyaru.value, YuksekEnlemAyaru.yedideBir);
    expect((await SharedPreferences.getInstance()).getString(kayitliYuksekEnlemAnahtari), 'seventh_v2');
    await tester.scrollUntilVisible(find.byType(DropdownButton<AsrYontemi>), -150);
    await tester.pump();
    final hesaplanmisAsr = tester.widget<DropdownButton<AsrYontemi>>(
        find.byType(DropdownButton<AsrYontemi>));
    expect(hesaplanmisAsr.onChanged, isNotNull);
    expect(aktifAsrYontemi.value, asrDegeri, reason: 'resmî mod eski hesap tercihini silmez');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'Eski/geçersiz tercih güvenli seçime geçer, konum ve Asr korunur',
    () async {
      for (final eski in ['orta', 'ceyrek', 'yarim', 'yok', 'bilinmeyen']) {
        SharedPreferences.setMockInitialValues({
          kayitliKonumAnahtari: 'Londra|GB|51.5074|-0.1278|Europe/London',
          kayitliUlkeAnahtari: 'GB',
          kayitliYuksekEnlemAnahtari: eski,
          kayitliAsrAnahtari: AsrYontemi.hanafi.kod,
        });
        yuksekEnlemGecisBilgisi = null;
        await konumYukle();
        expect(aktifYuksekEnlemAyaru.value, YuksekEnlemAyaru.geceninYarisi);
        expect(aktifKonum.value!.ad, 'Londra');
        expect(aktifKonum.value!.asrYontemi, AsrYontemi.hanafi);
        expect(yuksekEnlemGecisBilgisi, isNotNull);
        final h = await SharedPreferences.getInstance();
        expect(h.getString(kayitliYuksekEnlemAnahtari), 'middle_v2');
        yuksekEnlemGecisBilgisi = null;
        await konumYukle();
        expect(yuksekEnlemGecisBilgisi, isNull, reason: 'geçiş yalnız bir kez');
      }
    },
  );

  test('Yeni üç seçim kayıt/yeniden açılışta aynen korunur', () async {
    for (final secim in YuksekEnlemAyaru.values) {
      SharedPreferences.setMockInitialValues({});
      await yuksekEnlemKaydet(secim);
      await konumYukle();
      expect(aktifYuksekEnlemAyaru.value, secim);
    }
  });

  testWidgets(
    'Gerçek Aladhan tablolarıyla seçim ekran, sayaç ve ayrı cache değiştirir',
    (tester) async {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/aladhan_yuksek_enlem_londra.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cevaplar = fixture['responses'] as Map<String, dynamic>;
      final kuyruk = AgKuyrugu(
        (url) => jsonEncode(
          cevaplar[url.queryParameters['latitudeAdjustmentMethod']],
        ),
      );
      await kontrolluAg(kuyruk, () async {
        saatKaynagiDegistir(SabitSaat(DateTime.utc(2026, 5, 15, 0)));
        aktifHesaplamaYontemi.value = 3;
        final h = await SharedPreferences.getInstance();
        final eskiAnahtar = londra
            .onbellekAnahtari(yil: 2026, ay: 5)
            .replaceAll('_ymiddle_v2_', '_yorta_');
        await h.setString(eskiAnahtar, '{"surum":1,"eski":true}');
        expect(
          await VakitDepo(
            saat: uygulamaSaati,
          ).kayitOku(londra, yil: 2026, ay: 5),
          isNull,
        );
        await sayfayiAc(tester, londra);
        final sonuclar = <String>[];
        for (final (secim, fajr, isha, sayac) in [
          (YuksekEnlemAyaru.geceninYarisi, '02:06', '23:30', '01:06:00'),
          (YuksekEnlemAyaru.yedideBir, '03:57', '21:58', '02:57:00'),
          (YuksekEnlemAyaru.aciTabanli, '02:38', '23:08', '01:38:00'),
        ]) {
          aktifYuksekEnlemAyaru.value = secim;
          await akisIlerlet(tester);
          final konum = aktifKonum.value!;
          final sira = kuyruk.siralari(konum, yil: 2026, ay: 5).last;
          expect(
            kuyruk
                .istekler[sira]
                .url
                .queryParameters['latitudeAdjustmentMethod'],
            secim.apiParametresi,
          );
          expect(
            kuyruk.istekler[sira].url.queryParameters.containsKey(
              'adjustmentMethod',
            ),
            isFalse,
          );
          kuyruk.cevapVer(sira);
          await akisIlerlet(tester);
          final kayit = await VakitDepo(
            saat: uygulamaSaati,
          ).kayitOku(konum, yil: 2026, ay: 5);
          expect(
            kayit!.gun(DateTime(2026, 5, 15))!.saatler['fajr'],
            fajr,
          );
          expect(kayit.gun(DateTime(2026, 5, 15))!.saatler['isha'], isha);
          expect(find.text(sayac), findsOneWidget);
          sonuclar.add(konum.onbellekAnahtari(yil: 2026, ay: 5));
        }
        expect(sonuclar.toSet(), hasLength(3));
        expect(
          h.containsKey(eskiAnahtar),
          isTrue,
          reason: 'eski kayıt silinmez ama yeni hesap diye kullanılmaz',
        );
        expect(tester.takeException(), isNull);
        await sayfayiKapat(tester, kuyruk);
      });
    },
  );
}
