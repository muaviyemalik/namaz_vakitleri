// Ozel gunler sayfasi UX DENETIM testi: sayfa acilisinda ve yeniden cizimde
// donme gostergesi (CircularProgressIndicator) GORUNMEMELI.
//
// Hatanin olcumu: veri gomulu bir statik map'ten geliyor, yani ağ istegi ve
// bekleme yok. Buna ragmen once "API hissi" icin 1 saniyelik sahte gecikme
// eklenmis ve liste `build()` icinde FutureBuilder ile cizilmisti. Future her
// build'de yeniden olusturuldugu icin FutureBuilder sifirlaniyor ve
// connectionState yeniden "waiting"e donuyordu; tema, karanlik mod veya dil
// degisiminde liste 1 saniye boyunca kaybolup yerine cark gorunuyordu.
// Ana menu IndexedStack kullandigi icin bu, kullanici baska sekmede olsa bile
// oluyordu.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/pages/ozelGunler_sayfasi.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> sayfayiYukle(WidgetTester tester, {ThemeData? tema}) async {
  // ListView.builder yalnizca gorunur olan kartlari cizer. Test penceresi
  // varsayilan 800x600 oldugu icin 9 kartin 3'u ekran disinda kalir ve
  // sayfayi bos sanirdik. Gercek cihaz olculerinde (1080x2400) hepsi cizilir.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    EasyLocalization(
      path: 'assets/i18n/ceviri',
      supportedLocales: const [Locale('tur'), Locale('eng'), Locale('zho')],
      fallbackLocale: const Locale('tur'),
      child: MaterialApp(
        theme: tema,
        home: const OzelGunlerSayfasi(),
      ),
    ),
  );
  // 1. kare: ceviri dosyasi yuklenir. 2. kare: sayfa gercekten cizilir.
  // (Eski kodda 2. karede cark gorunurdu.)
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // EasyLocalization, kayitli dili okumak icin shared_preferences kullanir;
    // testte eklenti kanali yok, bu yuzden bos degerlerle mock'lanir.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('acilisista donme gostergesi cikmaz, 9 gun listede',
      (tester) async {
    await sayfayiYukle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'Veri senkron; yukleme durumu olmamali');
    expect(find.byType(ListTile), findsNWidgets(9),
        reason: '9 ozel gun listelenmeli');
  });

  testWidgets('tema degisimiyle yeniden cizimde cark belirmez', (tester) async {
    await sayfayiYukle(tester, tema: ThemeData.light());
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Karanlik moda gecis: tema degistigi icin sayfa yeniden cizilir.
    await sayfayiYukle(tester, tema: ThemeData.dark());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'Yeniden cizimde FutureBuilder sifirlanip cark gostermemeli');
    expect(find.byType(ListTile), findsNWidgets(9));
  });

  testWidgets('1 saniye beklenmeden tum kartlar hazir', (tester) async {
    // Gercekci zaman ilerletmeden: eski kodda 1 saniyelik gecikme oldugu icin
    // bu anda liste hâlâ bos olurdu.
    await sayfayiYukle(tester);
    expect(find.byType(ListTile), findsNWidgets(9),
        reason: 'Gecikme kaldirildi, veri ilk karede hazir');
  });
}
