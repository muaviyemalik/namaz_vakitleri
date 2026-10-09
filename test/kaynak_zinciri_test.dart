import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/diyanet_guncel.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:namaz_vakitleri/utils/widget_paketi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'diyanet_guncel_test.dart' show resmiSayfa;
import 'test_yardimcisi.dart';
import 'ana_sayfa_bildirim_test.dart' show KontrolluBildirimEklentisi;

/// Testte gerçek çeviri dosyalarını okuyan yükleyici.
///
/// `RootBundleAssetLoader` `rootBundle` üzerinden çalışır; bu, testte gerçek
/// dosya sistemi erişimi (ve sabit gerçek-zaman beklemesi) demektir. Ama bu
/// test KAYNAK ETİKETİNİ ölçer: "Diyanet" yazısı yalnız gerçekten Diyanet
/// tablosundan bir satır geldiğinde görünür. Bellek yükleyiciyle bu metin
/// çözülmez ve test yanlış sebeple geçer/başarısız olur — bu yüzden burada
/// GERÇEK dosyalar okunur.
class _DosyaCevirici {
  static const String ceviriDizini = 'assets/i18n/ceviri';

  /// Gerçek çeviri dosyasını okur; `rootBundle` kullanılmaz.
  static Future<Map<String, dynamic>> yukle(Locale locale) async {
    final File dosya = File('$ceviriDizini/${locale.languageCode}.json');
    if (!dosya.existsSync()) {
      throw StateError('ceviri dosyasi yok: ${dosya.path}');
    }
    return json.decode(dosya.readAsStringSync(encoding: utf8))
        as Map<String, dynamic>;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    // `ensureInitialized` kaynak dosyalari `RootBundleAssetLoader` ile yukler;
    // flutter test'te rootBundle dosya sistemine erisemez. Bu yuzden
    // Turkce metinleri elle yukleyip o dili kayitli yapiyoruz. Aksi halde
    // kaynak seridi ham anahtar adi olarak gorunur ve test yanlis sebeple
    // basarisiz olur.
    // `ensureInitialized` kaynak dosyalari `RootBundleAssetLoader` ile dener;
    // flutter test'te rootBundle dosya sistemine erisemedigi icin
    // cevirileri ELLE yukleyip dogrudan bagliyoruz. Aksi halde kaynak seridi
    // ham anahtar adi olarak gorunur ve test yanlis sebeple basarisiz olur.
    Localization.load(
      const Locale('tur'),
      translations: Translations(
        await _DosyaCevirici.yukle(const Locale('tur')),
      ),
      fallbackTranslations: Translations(
        await _DosyaCevirici.yukle(const Locale('tur')),
      ),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    aktifResmiDiyanet.value = true;
  });
  tearDown(() {
    aktifKonum.value = null;
    saatKaynagiDegistir(const GercekSaat());
  });

  Future<void> ac(
    WidgetTester tester,
    SabitSaat saat,
    DiyanetGuncelDepo resmi, {
    int yil = 2028,
    String saatDilimi = 'Europe/Istanbul',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    saatKaynagiDegistir(saat);
    aktifKonum.value = Konum(
      ad: 'Ankara',
      ulkeIso2: 'TR',
      enlem: 39.9334,
      boylam: 32.8597,
      saatDilimi: saatDilimi,
      il: 'Ankara',
      diyanetCityId: 9206,
      diyanetParca: 'TR/ankara.txt',
    );
    final gun = VakitGunu(
      yil: yil,
      ay: 1,
      gun: 1,
      hicriTarih: '',
      saatDilimi: 'Europe/Istanbul',
      cevapYontemId: 13,
      saatler: const {
        'fajr': '05:30',
        'sunrise': '07:00',
        'dhuhr': '12:00',
        'asr': '15:00',
        'maghrib': '18:00',
        'isha': '19:00',
      },
    );
    await VakitDepo(saat: saat).kayitYaz(
      aktifKonum.value!,
      CevapGecerli(
        gunler: [gun],
        saatDilimi: gun.saatDilimi,
        cevapYontemId: 13,
        cevapEnlem: 39.9334,
        cevapBoylam: 32.8597,
      ),
    );
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/i18n/ceviri',
        supportedLocales: const [Locale('tur'), Locale('eng')],
        fallbackLocale: const Locale('tur'),
        startLocale: const Locale('tur'),
        child: MaterialApp(home: AnaSayfa(guncelDiyanet: resmi)),
      ),
    );
    await ilerlet(tester);
  }

  testWidgets('gömülü veri hesaplanmış cache ve resmî ağdan önce gelir', (
    tester,
  ) async {
    var istek = 0;
    final saat = SabitSaat(DateTime.utc(2026, 1, 1, 0));
    final resmi = DiyanetGuncelDepo(
      simdi: saat.simdi,
      istemci: MockClient((_) async {
        istek++;
        return http.Response(resmiSayfa(), 200);
      }),
    );
    await internetYokken(() async {
      await ac(tester, saat, resmi, yil: 2026);
      expect(find.textContaining('Diyanet resmî vakitleri'), findsOneWidget);
      expect(find.textContaining('{surum}'), findsNothing);
      expect(find.textContaining('{tarih}'), findsNothing);
      expect(find.textContaining('00:00:00.000'), findsNothing);
      expect(find.textContaining('Hesaplanmış ·'), findsNothing);
      expect(istek, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  for (final dilim in [
    '',
    'Invalid/Zone',
    'gece-yarisi',
    'Europe/Istanbul',
    'Asia/Shanghai',
  ]) {
    testWidgets(
      'gömülü kaynak dilimi kesinleştirir; sayaç, widget ve bildirim işler: $dilim',
      (tester) async {
        final eklenti = KontrolluBildirimEklentisi();
        bildirimYoluTasarimiAyarla(true);
        bildirimServisiDegistir(eklenti);
        bildirimPlanSirasiDegistir(PlanSirasi());
        addTearDown(() {
          bildirimYoluTasarimiAyarla(null);
          bildirimServisiDegistir(FlutterLocalNotificationsPlugin());
          bildirimPlanSirasiDegistir(PlanSirasi());
        });
        final gece = dilim == 'gece-yarisi';
        final saat = SabitSaat(
          DateTime.utc(2026, 1, 1, gece ? 21 : 0, gece ? 5 : 0),
        );
        var istek = 0;
        final resmi = DiyanetGuncelDepo(
          simdi: saat.simdi,
          istemci: MockClient((_) async {
            istek++;
            return http.Response('', 503);
          }),
        );
        await internetYokken(() async {
          await ac(
            tester,
            saat,
            resmi,
            yil: 2026,
            saatDilimi: gece ? '' : dilim,
          );
          expect(aktifKonum.value!.saatDilimi, 'Europe/Istanbul');
          expect(aktifVakitDurumu.value!.konum.saatDilimi, 'Europe/Istanbul');
          final sayac = RegExp(r'^\d{2}:\d{2}:\d{2}$');
          String metin() => tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? '')
              .firstWhere(sayac.hasMatch);
          final once = metin();
          saat.ilerlet(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(metin(), isNot(once));
          final durum = aktifVakitDurumu.value!;
          expect(durum.bugun!.tarih, DateTime(2026, 1, gece ? 2 : 1));
          final paket = WidgetPaketi.olustur(
            konum: aktifKonum.value,
            saat: saat,
            gunler: [durum.bugun!, ...durum.gelecekGunler],
            tema: ColorScheme.fromSeed(seedColor: Colors.green),
            dil: 'tur',
            kaynak: 'Diyanet',
            metinler: const {},
          );
          expect(paket['days'], isNotEmpty);
          // Gerçek AnaSayfa → motor → sahte platform kaydı. Cihazda çalmaz.
          final kurulan = eklenti.motorunBekleyenleri();
          expect(kurulan, isNotEmpty);
          final ilk = kurulan.values.reduce((a, b) => a.isBefore(b) ? a : b);
          final imsak = SehirSaati(konum: durum.konum, saat: saat).duvarSaati(
            durum.bugun!.saatler['fajr']!,
            tarih: durum.bugun!.tarih,
          )!;
          expect(ilk.toUtc(), imsak.toUtc());
          expect(kurulan.values.every((z) => z.isAfter(saat.simdi())), isTrue);
          expect(
            (await SharedPreferences.getInstance()).getStringList(
              'bildirim_motoru_kimlikleri',
            ),
            hasLength(kurulan.length),
          );
          expect(istek, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      },
    );
  }

  testWidgets(
    'gömülü kapsam biterse hesaplanmış cache; resmî dönünce otomatik geçiş',
    (tester) async {
      var agAcik = false;
      final saat = SabitSaat(DateTime.utc(2028, 1, 1, 0));
      final resmi = DiyanetGuncelDepo(
        simdi: saat.simdi,
        istemci: MockClient(
          (_) async =>
              http.Response(agAcik ? resmiSayfa() : '', agAcik ? 200 : 503),
        ),
      );
      await internetYokken(() async {
        await ac(tester, saat, resmi);
        expect(find.textContaining('Hesaplanmış ·'), findsOneWidget);
        expect(
          find.textContaining('hesaplanmış vakitler gösteriliyor'),
          findsOneWidget,
        );
        expect(find.textContaining('Diyanet resmî vakitleri'), findsNothing);
        expect(find.text('05:30'), findsWidgets);
        agAcik = true;
        saat.ilerlet(const Duration(minutes: 5));
        await tester.pump(const Duration(seconds: 1));
        await ilerlet(tester);
        expect(
          find.textContaining('Diyanet resmî vakitleri · güncel tablo'),
          findsOneWidget,
        );
        expect(find.textContaining('Hesaplanmış ·'), findsNothing);
        expect(find.text('05:20'), findsWidgets);
        expect(find.text('05:30'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );
}

Future<void> ilerlet(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
  await tester.pumpAndSettle();
}
