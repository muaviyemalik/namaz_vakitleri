// Cevrimdisi ilk acilis DENETIM testi: uygulama COKMEMELI.
//
// Hatanin olcumu: vakitler hic yuklenemediginde (internet yok ve onbellekte
// o sehir icin kayit yok) `vakitleriGetir` `yukleniyor=false` yapip null
// `vakitler` ile donuyordu. `build` bu durumu hic ele almadigi icin dogrudan
// vakit kartlarini cizmeye geciyor ve `vakitler!['Fajr']` null check operator
// hatasi veriyordu: kirmizi ekran, uygulama kullanilamaz durumda. Internetsiz
// ilk acilista yani kullanicinin uygulamayi hic kullanamadigi senaryo.
//
// Test, hatayi gercekten uretmek icin:
//   1) bos onbellek (SharedPreferences mock) — kayitli vakit yok,
//   2) Hicbir ag isteginin basarisiz donmesi (HttpOverrides) — internet yok,
//   3) aktifSehir atanmis (main.dart'daki konumYukle() bunu yapiyor).
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_yardimcisi.dart';

Future<void> sayfayiYukle(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // main.dart'deki konumYukle() bunu yapiyor; testte de yapmamiz gerekir,
  // yoksa "sehir yok" yoluna dusulur ve yanlis senaryo olculmus olur.
  aktifSehir.value = const Sehir(ad: 'Ankara', enlem: 39.9334, boylam: 32.8597);

  await internetYokken(() async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/i18n/ceviri',
        supportedLocales: const [Locale('tur'), Locale('eng')],
        fallbackLocale: const Locale('tur'),
        child: const MaterialApp(home: AnaSayfa()),
      ),
    );
    // 1. kare cevirileri yukler, 2. kare sayfayi cizer. Ag istegi bu
    // arada basarisiz olur ve yukleme durumu biter.
    await tester.pump();
    // Ceviri dosyalari GERCEK dosya sisteminden okundugu icin sahte saatte
    // (pump) yetismez; easy_localization'a gercek sure veriyoruz.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Bos onbellek: bu ay icin kayitli vakit verisi YOK.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('internet yokken uygulama cokmez, hata ekrani gosterilir',
      (tester) async {
    await sayfayiYukle(tester);

    // Cokme burada yakalanirdi: "Null check operator used on a null value".
    expect(tester.takeException(), isNull,
        reason: 'vakitler null iken build cokmemeli');

    expect(find.byIcon(Icons.cloud_off), findsOneWidget,
        reason: 'Hata ekrani gosterilmeli');
    expect(find.byType(FilledButton), findsOneWidget,
        reason: 'Kullaniciya bir yol sunulmali: "Tekrar dene" dugmesi');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'Yukleme bitmis olmali, donen car kalmamali');

    // NOT: Hata ekraninin METINLERI burada dogrulanmiyor. easy_localization
    // ceviri dosyalarini gercek dosya sisteminden okudugu icin flutter test'in
    // sahte saatinde metinler cozumlenmiyor ve ekranda anahtar adlari gorunuyor.
    // Anahtarlarin 25 dilde de mevcut oldugu `ceviriler_test.dart`ta denetlenir.
  });

  testWidgets('vakit kartlari hata durumunda cizilmez', (tester) async {
    await sayfayiYukle(tester);

    // "Bugunun vakitleri" basligi ve vakit kartlari cizilmemeli.
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('Tekrar dene dugmesi cokme olmadan calisiyor', (tester) async {
    await sayfayiYukle(tester);
    expect(find.byType(FilledButton), findsOneWidget);

    // Dugmeye basinca vakitler yeniden istenir; internet yine yok, yine
    // hata ekrani gosterilmeli — ama uygulama cokmemeli.
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'Yeniden denemede de cokmemeli');
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });
}
