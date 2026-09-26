// Alt menu DENETIM testi: sayfalar ACILISTA KURULMAZ.
//
// Hatanin olcumu: `IndexedStack` tum cocuklarini acilista kurar, yani her
// sayfanin `initState`'i uygulama acilisinda calisir. Kible sayfasi orada konum
// istiyor ve kible acisi bulununca `FlutterCompass.events` aboneliği kuruyordu.
// Sonuc: kullanici kible sekmesini hic acmasa bile GPS acilista calisiyor ve
// pusula sensoru uygulamanin omru boyunca acik kaliyordu.
//
// Bu test KIBLE SAYFASININ KENDISINI DEGIL, onu ne zaman kuran kabuğu (AnaMenu)
// sinar: bir sayfa `findsNothing` ise o sayfanin `initState`'i hic calismis
// demektir, yani hicbir sensor acilmamis olur.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:namaz_vakitleri/pages/ayarlar_sayfasi.dart';
import 'package:namaz_vakitleri/pages/kible_sayfasi.dart';
import 'package:namaz_vakitleri/pages/ozelGunler_sayfasi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_yardimcisi.dart';

/// Alt menüde [index]. sıradaki sekmeye dokunur.
///
/// `BottomNavigationBar` tek bir widget üretir; öğeleri `items` listesinin
/// doğrudan elemanlarıdır. Bu yüzden öğeye `Icon` üzerinden erişiyoruz.
const List<IconData> sekmeIkonlari = <IconData>[
  Icons.access_time,   // 0: vakitler
  Icons.event,         // 1: özel günler
  Icons.explore,       // 2: kıble
  Icons.settings,      // 3: ayarlar
];

Future<void> sekmeyeDokun(WidgetTester tester, int index) async {
  await tester.tap(find.byIcon(sekmeIkonlari[index]));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// `IndexedStack`, seçili OLMAYAN çocuklarını ağaçta tutar ama "offstage" sayar.
/// Varsayılan `find.byType` çağrıları offstage öğeleri atladiği için burada
/// `skipOffstage: false` şart: aksi hâlde "sayfa kurulmadı" kontrolü, sayfa
/// kurulmuş olsa bile geçer ve test yanlış güvence verir.
Finder sayfada<T extends Widget>() => find.byType(T, skipOffstage: false);

Future<void> menuyuYukle(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await internetYokken(() async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/i18n/ceviri',
        supportedLocales: const [Locale('tur'), Locale('eng')],
        fallbackLocale: const Locale('tur'),
        child: const MaterialApp(home: AnaMenu()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // Ana menü durumu sıfırdan başlasın.
    aktifSekmeIndeksi.value = 0;
  });

  testWidgets('acilisita sadece ana sayfa kurulur', (tester) async {
    await menuyuYukle(tester);

    expect(sayfada<AnaSayfa>(), findsOneWidget,
        reason: 'Varsayilan sekme kurulmus olmali');

    // Kible sayfasi kurulMAMALI: initState calismasin, konum istenmesin,
    // pusula sensoru acilmasin.
    expect(sayfada<KibleSayfasi>(), findsNothing,
        reason: 'Kible sayfasi acilista kurulmamali; GPS acilmamali');

    expect(sayfada<OzelGunlerSayfasi>(), findsNothing);
    expect(sayfada<AyarlarSayfasi>(), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('sekmesine dokunulunca sayfa kurulur', (tester) async {
    await menuyuYukle(tester);

    await sekmeyeDokun(tester, kibleSekmeIndeksi);

    expect(sayfada<KibleSayfasi>(), findsOneWidget,
        reason: 'Kullanici sekmeye dokununca sayfa kurulmali');
    expect(tester.takeException(), isNull,
        reason: 'Konum alinamasa bile sayfa cokmemeli');
  });

  testWidgets('her sekme ilk dokunuşta kurulur', (tester) async {
    await menuyuYukle(tester);

    await sekmeyeDokun(tester, 1);
    expect(sayfada<OzelGunlerSayfasi>(), findsOneWidget);

    await sekmeyeDokun(tester, 3);
    expect(sayfada<AyarlarSayfasi>(), findsOneWidget);

    // Geri dönüldüğünde sayfalar hâlâ kuruludur.
    await sekmeyeDokun(tester, 0);
    expect(sayfada<AnaSayfa>(), findsOneWidget);
    expect(sayfada<OzelGunlerSayfasi>(), findsOneWidget);
    expect(sayfada<AyarlarSayfasi>(), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('sayfaya donulunca durumu korunur', (tester) async {
    await menuyuYukle(tester);

    await sekmeyeDokun(tester, kibleSekmeIndeksi);
    await sekmeyeDokun(tester, 0); // Ana sayfaya dön
    await sekmeyeDokun(tester, kibleSekmeIndeksi); // Tekrar kibleye

    // Sayfa yeniden kurulmadı, aynı örnek yaşıyor.
    expect(sayfada<KibleSayfasi>(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aktifSekmeIndeksi menüyle senkron', (tester) async {
    await menuyuYukle(tester);
    expect(aktifSekmeIndeksi.value, 0);

    // Kible sayfasi bu degeri dinliyor (pusula aboneliğini yalnizca gorunurken
    // tutmak icin). Senkron degilse sensor yanlis zamanda acik kalir.
    await sekmeyeDokun(tester, 3);
    expect(aktifSekmeIndeksi.value, 3);

    await sekmeyeDokun(tester, kibleSekmeIndeksi);
    expect(aktifSekmeIndeksi.value, kibleSekmeIndeksi);
  });
}
