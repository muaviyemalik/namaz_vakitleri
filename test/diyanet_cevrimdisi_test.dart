// RESMÎ DİYANET MODUNUN ÇEVRİMDIŞI ÇALIŞTIĞININ DENETİMİ.
//
// Bu, "internet olmadan da çalışsın" hedefinin asıl kanıtıdır. Üç şey
// birlikte doğrulanır:
//
//   1) Ağ tamamen kapalıyken (HttpOverrides) ekran resmî vakitleri GÖSTERİR.
//      Aladhan'a hiç ulaşılamadığı için ekrandaki saatin tek kaynağı resmî
//      pakettir. Bu, "resmî veriden geliyor" iddiasının dolaylı değil
//      DOĞRUDAN kanıtıdır.
//
//   2) Ekrandaki saat, resmî pakette aynı gün için yazan değerle BİREBİR
//      aynıdır (kendi kendine karşılaştırma değil; paket ayrıştırıcısının
//      çıktısı ekrandaki metinle karşılaştırılır).
//
//   3) Kapsam dışında resmî web ve doğrulanmış hesaplanmış kaynaklar
//      denenir. Kaynak zincirinin fallback/geri dönüşü kaynak_zinciri_test'te.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_yardimcisi.dart';

const String paketDizini = 'assets/veri/diyanet';

/// Resmî pakette [cityId] için [gun] gününün İmsak saati.
String resmiImsak(int cityId, DateTime gun) {
  String? cid;
  for (final satir
      in File('$paketDizini/TR/ankara.txt').readAsLinesSync(encoding: utf8)) {
    if (satir.startsWith('#@')) {
      cid = satir.substring(2).split('|').first;
      continue;
    }
    if (satir.startsWith('#') || satir.isEmpty || cid != '$cityId') continue;
    final p = satir.split('|');
    if (p[0] ==
        '${gun.year.toString().padLeft(4, '0')}'
            '${gun.month.toString().padLeft(2, '0')}'
            '${gun.day.toString().padLeft(2, '0')}') {
      final s = p[1];
      return '${s.substring(0, 2)}:${s.substring(2, 4)}';
    }
  }
  return '';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // SIRA ÖNEMLİ: easy_localization açılışta SharedPreferences okur, bu yüzden
    // sahte depo ÖNCE kurulmalıdır.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    aktifResmiDiyanet.value = true;
  });

  tearDown(() {
    aktifKonum.value = null;
    aktifResmiDiyanet.value = true;
  });

  Future<void> sayfayiYukle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Ankara + resmî kimlik: cihazdaki kayıttan gelen gerçek durum.
    aktifKonum.value = const Konum(
      ad: 'Ankara',
      ulkeIso2: 'TR',
      enlem: 39.9334,
      boylam: 32.8597,
      saatDilimi: 'Europe/Istanbul',
      il: 'Ankara',
      diyanetCityId: 9206,
      diyanetParca: 'TR/ankara.txt',
    );

    await internetYokken(() async {
      await tester.pumpWidget(
        EasyLocalization(
          path: 'assets/i18n/ceviri',
          supportedLocales: const [Locale('tur'), Locale('eng')],
          fallbackLocale: const Locale('tur'),
          child: const MaterialApp(home: AnaSayfa()),
        ),
      );
      await tester.pump();
      // easy_localization çevirilerini GERÇEK dosya sisteminden okur;
      // flutter test'in sahte saatinde yetişmediği için gerçek süre verilir.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('ağ kapalıyken resmî vakit ekranda görünür', (tester) async {
    await sayfayiYukle(tester);

    // Uygulamanın göreceği gün (cihaz saati, Türkiye saat dilimi).
    final konum = aktifKonum.value!;
    final bugun = KonumTakvimi.tarih(konum, uygulamaSaati);
    final paket = await DiyanetDepo().paket();

    expect(paket, isNotNull, reason: 'paket okunabilmeli');

    if (paket!.araliktaMi(bugun) &&
        !paket.bosluklar.any((b) => b.icerir(bugun))) {
      final beklenen = resmiImsak(9206, bugun);
      expect(beklenen, isNotEmpty, reason: 'pakette $bugun bulunmalı');

      // Ekranda resmî "Diyanet" etiketi ve resmî saat görünür.
      expect(find.textContaining('Diyanet'), findsWidgets,
          reason: 'kaynak etiketi Diyanet olmalı');
      expect(find.text(beklenen), findsWidgets,
          reason: 'resmî İmsak saati ($beklenen) ekranda olmalı');
    } else {
      // Bu testte ağ engelli ve hesaplanmış önbellek boş: saat bulunamaz.
      expect(resmiImsak(9206, bugun), isEmpty,
          reason: 'bu gün pakette olmamalı');
      expect(find.textContaining('Diyanet'), findsWidgets,
          reason: 'kullanıcı durum bilgilendirilmeli');
    }
  });

  testWidgets('hesap ayarları resmî ekranda vakit değiştirmez', (tester) async {
    await sayfayiYukle(tester);

    final konum = aktifKonum.value!;
    final bugun = KonumTakvimi.tarih(konum, uygulamaSaati);
    final paket = await DiyanetDepo().paket();
    if (paket == null || !paket.araliktaMi(bugun)) return;

    final once = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    // Asr'ı Hanefi'ye çevir: hesaplanmış akışta İkindi ~48 dakika kayar.
    aktifAsrYontemi.value = AsrYontemi.hanafi;
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    final sonra = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(once, sonra,
        reason: 'resmî modda Asr ayarı ekranı DEĞİŞTİRMEMELİ');
  });

  testWidgets('resmî mod kapalıyken hesaplanmış akış devreye girer',
      (tester) async {
    aktifResmiDiyanet.value = false;
    await sayfayiYukle(tester);

    // Ağ kapalı olduğu için hesaplanmış veri de gelemez; bu yüzden burada
    // ölçülebilen şey "Diyanet" etiketinin YOKLUĞUDUR. Resmî olmayan bir
    // kaynakta Diyanet yazmaması, etiketin dürüstlüğünün kanıtıdır.
    expect(find.textContaining('Diyanet resmî'), findsNothing,
        reason: 'hesaplanmış akışta "Diyanet resmî" etiketi görünmemeli');
  });
}
