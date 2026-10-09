import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:namaz_vakitleri/pages/ayarlar_sayfasi.dart';
import 'package:namaz_vakitleri/pages/bildirim_ayarlari_sayfasi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/utils/iso1_yerellestirme.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

class _Assets extends AssetLoader {
  const _Assets();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _App extends StatelessWidget {
  const _App(this.page, this.scale, this.rtl);
  final Widget page;
  final double scale;
  final bool rtl;
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: yerellestirmeDelegeleri(
      context.localizationDelegates,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: child!,
      ),
    ),
    home: page,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final codes =
      Directory('assets/i18n/ceviri')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.split('.').first)
          .toList()
        ..sort();
  setUpAll(() async {
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  tearDown(() {
    aktifKonum.value = null;
    aktifResmiDiyanet.value = true;
    saatKaynagiDegistir(const GercekSaat());
  });
  setUp(() {
    aktifKonum.value = null;
    SharedPreferences.setMockInitialValues({
      'kayitli_zikir': 33,
      'kayitli_hedef': 1000,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['perfect_volume_control', 'namaz_vakitleri/ezan']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
  });
  for (final code in codes) {
    for (final spec in [
      (320.0, 640.0, 2.0),
      (640.0, 360.0, 1.4),
      (800.0, 1280.0, 1.0),
    ]) {
      testWidgets('$code ${spec.$1}x${spec.$2} text ${spec.$3}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(spec.$1, spec.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> mount(Widget page) async {
          await tester.pumpWidget(const SizedBox());
          Localization.load(
            Locale(code),
            translations: Translations(
              jsonDecode(
                    File('assets/i18n/ceviri/$code.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>,
            ),
          );
          await tester.pumpWidget(
            EasyLocalization(
              key: UniqueKey(),
              path: 'assets/i18n/ceviri',
              supportedLocales: [Locale(code)],
              startLocale: Locale(code),
              assetLoader: const _Assets(),
              saveLocale: false,
              child: _App(page, spec.$3, ['ara', 'fas'].contains(code)),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            tester.takeException(),
            isNull,
            reason: 'initial ${page.runtimeType}',
          );
        }

        await mount(const AnaSayfa());
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: 'zikir panel');
        await tester.ensureVisible(find.byKey(const Key('zikir_hedef_sec')));
        await tester.tap(find.byKey(const Key('zikir_hedef_sec')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: 'goal menu');
        await tester.pumpWidget(const SizedBox());
        final clock = SabitSaat(DateTime.utc(2028, 1, 1, 8));
        saatKaynagiDegistir(clock);
        aktifResmiDiyanet.value = false;
        aktifKonum.value = Konum(
          ad: 'Ankara',
          ulkeIso2: 'TR',
          enlem: 39.9334,
          boylam: 32.8597,
          saatDilimi: 'Europe/Istanbul',
          il: 'Ankara',
        );
        final days = [
          for (var day = 1; day <= 3; day++)
            VakitGunu(
              yil: 2028,
              ay: 1,
              gun: day,
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
            ),
        ];
        await VakitDepo(saat: clock).kayitYaz(
          aktifKonum.value!,
          CevapGecerli(
            gunler: days,
            saatDilimi: 'Europe/Istanbul',
            cevapYontemId: 13,
            cevapEnlem: 39.9334,
            cevapBoylam: 32.8597,
          ),
        );
        await mount(const AnaSayfa());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        for (var i = 0; i < 30 && find.text('05:30').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (find.byType(Scrollable).evaluate().isNotEmpty) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -160),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
        }
        expect(
          find.text('05:30'),
          findsOneWidget,
          reason:
              'loaded prayer cards ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
        );
        expect(tester.takeException(), isNull, reason: 'loaded home');
        Future<void> scrollToEnd(String page) async {
          final scroll = find.byType(Scrollable).first;
          final position = tester.state<ScrollableState>(scroll).position;
          for (var i = 0; i < 35 && position.pixels < position.maxScrollExtent; i++) {
            await tester.drag(scroll, const Offset(0, -220));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: '$page scroll $i');
          }
          expect(position.pixels, closeTo(position.maxScrollExtent, 1), reason: '$page reached bottom');
        }
        await scrollToEnd('loaded home');
        expect(find.text('19:00'), findsOneWidget, reason: 'last prayer visible');
        for (final page in [
          const AyarlarSayfasi(),
          const BildirimAyarlariSayfasi(),
        ]) {
          await mount(page);
          await scrollToEnd('${page.runtimeType}');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
