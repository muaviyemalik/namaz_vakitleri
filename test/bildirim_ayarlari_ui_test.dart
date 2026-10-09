import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:namaz_vakitleri/core/bildirim_ayarlari.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/bildirim_ayarlari_sayfasi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bildirimAyarlari.value = const BildirimAyarlari();
    erkenUyariSuresi.value = 60;
    gunesDogumuBildirimiAcik.value = false;
    Localization.load(
      const Locale('tur'),
      translations: Translations(
        jsonDecode(File('assets/i18n/ceviri/tur.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  tearDown(() {
    erkenUyariSuresi.value = 0;
    bildirimAyarlari.value = const BildirimAyarlari();
  });
  testWidgets(
    'Dar ekranda ortak 60 dakika seçimi taşmaz; yalnız bir süre kontrolü vardır',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: BildirimAyarlariSayfasi()),
      );
      await tester.scrollUntilVisible(find.text('Hatırlatma sesi'), 250);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(find.text('60 dk önce'), findsOneWidget);
      expect(find.text('Sıcak yükseliş'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Sessiz modu kapatma tercihi kaydedilir; DND varsayılan kapalıdır',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BildirimAyarlariSayfasi()),
      );
      await tester.scrollUntilVisible(find.text('Sessiz modda ezan çal'), 250);
      await tester.tap(find.text('Sessiz modda ezan çal'));
      await tester.pumpAndSettle();
      expect(bildirimAyarlari.value.sessizdeCal, isFalse);
      expect(bildirimAyarlari.value.dndCal, isFalse);
      final h = await SharedPreferences.getInstance();
      expect(jsonDecode(h.getString(bildirimAyarAnahtari)!)['silent'], false);
      expect(tester.takeException(), isNull);
    },
  );
}
