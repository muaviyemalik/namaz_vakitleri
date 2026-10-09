import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:namaz_vakitleri/core/ilk_kurulum.dart';
import 'package:namaz_vakitleri/core/bildirim_ayarlari.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/ilk_kurulum_sayfasi.dart';

const paris = KurulumKonumu(
  Sehir(ad: 'Paris', enlem: 48.85, boylam: 2.35),
  'FR',
);

class SahteKurulum extends KurulumIslemleri {
  KurulumKonumu? secilen = paris;
  Object? gpsHatasi;
  bool kayitHatasi = false;
  int istemler = 0;
  int ayarlar = 0;
  int kayitlar = 0;
  VakitBildirimModu? kayitModu;
  bool? kayitSessizde;
  @override
  bool get alarmDestekli => true;
  @override
  bool get konumDestekli => true;
  @override
  Future<KurulumKonumu?> elleSec(BuildContext context) async => secilen;
  @override
  Future<KurulumKonumu> otomatikBul() async {
    if (gpsHatasi != null) throw gpsHatasi!;
    return paris;
  }

  @override
  Future<void> ayarlariAc(KurulumKonumHatasi hata) async {
    ayarlar++;
  }

  @override
  Future<void> izinleriIste(bool Function() devam) async {
    istemler++;
  }

  @override
  Future<KurulumIzinDurumu> izinDurumu() async =>
      const KurulumIzinDurumu(bildirim: false, alarm: false, konum: false);
  @override
  Future<void> tamamla(
    KurulumKonumu konum,
    VakitBildirimModu mod,
    bool sessizde,
  ) async {
    kayitlar++;
    if (kayitHatasi) throw StateError('disk');
    kayitModu = mod;
    kayitSessizde = sessizde;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    tzdata.initializeTimeZones();
    Localization.load(
      const Locale('tur'),
      translations: Translations(
        jsonDecode(File('assets/i18n/ceviri/tur.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    aktifKonum.value = null;
  });
  test('Türkçe üç harfli dil kodu ülke ve bölge adını Türkçe gösterir', () {
    const ulke = Ulke(
      iso2: 'TR',
      iso3: 'TUR',
      ad: 'Turkey',
      adTr: 'Türkiye',
      bolge: 'Europe',
      sehirSayisi: 1,
    );
    expect(ulke.gorunenAd('tur'), 'Türkiye');
    expect(ulke.bolgeAdi('tur'), 'Avrupa');
    expect(ulke.gorunenAd('tr'), 'Türkiye');
    expect(ulke.gorunenAd('eng'), 'Turkey');
  });
  test('yeni kurulum şehir istemeden Ankara atamaz', () async {
    await konumYukle();
    expect(aktifKonum.value, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(await ilkKurulumGerekir(prefs), true);
    expect(prefs.getBool(kurulumBasladiAnahtari), true);
  });
  test('eski kullanıcı şehri ve bildirim tercihi korunur', () async {
    SharedPreferences.setMockInitialValues({
      kayitliKonumAnahtari: 'Paris|FR|48.85|2.35|Europe/Paris',
      bildirimAyarAnahtari: 'korunacak',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(await ilkKurulumGerekir(prefs), false);
    expect(prefs.getString(bildirimAyarAnahtari), 'korunacak');
    expect(prefs.getString(kayitliKonumAnahtari), startsWith('Paris'));
  });
  test(
    'yarım kurulum şehir kaydetmiş olsa da atlanmaz; tamamlanmış tekrar açılmaz',
    () async {
      SharedPreferences.setMockInitialValues({
        kurulumBasladiAnahtari: true,
        kayitliKonumAnahtari: 'Paris|FR|48.85|2.35|Europe/Paris',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await ilkKurulumGerekir(prefs), true);
      await prefs.setBool(kurulumBittiAnahtari, true);
      expect(await ilkKurulumGerekir(prefs), false);
    },
  );
  test(
    'gerçek tamamlamada kapalı tüm vakitlere uygulanır; şehir ve tamamlanma kalıcıdır',
    () async {
      erkenUyariSuresi.value = 15;
      gunesDogumuBildirimiAcik.value = true;
      await KurulumIslemleri().tamamla(paris, VakitBildirimModu.kapali, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kayitliKonumAnahtari), startsWith('Paris|FR|'));
      expect(prefs.getBool(kurulumBittiAnahtari), true);
      expect(erkenUyariSuresi.value, 0);
      expect(gunesDogumuBildirimiAcik.value, false);
      for (final vakit in BildirimAyarlari.vakitler) {
        expect(bildirimAyarlari.value.modu(vakit), VakitBildirimModu.kapali);
      }
      expect(bildirimAyarlari.value.dndCal, false);
    },
  );

  testWidgets('başlangıç kapısı ana ekranı kurulum bitmeden kurmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaslangicSayfasi(
          kurulumGerekli: true,
          anaMenu: Text('ana ekran'),
        ),
      ),
    );
    expect(find.byType(IlkKurulumSayfasi), findsOneWidget);
    expect(find.text('ana ekran'), findsNothing);
    await tester.pumpWidget(
      const MaterialApp(
        home: BaslangicSayfasi(
          key: ValueKey('eski'),
          kurulumGerekli: false,
          anaMenu: Text('ana ekran'),
        ),
      ),
    );
    expect(find.byType(IlkKurulumSayfasi), findsNothing);
    expect(find.text('ana ekran'), findsOneWidget);
  });

  Future<void> ac(
    WidgetTester tester,
    SahteKurulum islem,
    VoidCallback bitti,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IlkKurulumSayfasi(islemler: islem, tamamlandi: bitti),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> bas(WidgetTester tester, String key) async {
    if (find.byKey(Key(key)).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> izinAdiminaGit(WidgetTester tester, String mod) async {
    await bas(tester, 'setup_manual');
    await bas(tester, 'setup_next');
    await bas(tester, 'setup_mode_$mod');
    await bas(tester, 'setup_next');
  }

  testWidgets(
    'ilk kurulum konum ret mesajı olmayan kayıtlı şehirden söz etmez',
    (tester) async {
      final islem = SahteKurulum()
        ..gpsHatasi = KurulumKonumHatasi.izinReddedildi;
      await ac(tester, islem, () {});
      await bas(tester, 'setup_gps');
      expect(find.textContaining('Şehrini elle seçebilir'), findsOneWidget);
      expect(find.textContaining('Kayıtlı şehir'), findsNothing);
      expect(find.textContaining('Eski şehir'), findsNothing);
    },
  );
  testWidgets(
    'şehir ve uyarı seçilmeden ilerlenmez; seçilen şehir doğrulanır',
    (tester) async {
      final islem = SahteKurulum();
      await ac(tester, islem, () {});
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('setup_next')))
            .onPressed,
        isNull,
      );
      expect(find.text('Ankara'), findsNothing);
      expect(islem.istemler, 0);
      await bas(tester, 'setup_manual');
      expect(find.text('Paris'), findsOneWidget);
      await bas(tester, 'setup_next');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('setup_next')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('manuel seçim iptali ve kapalı GPS varsayılan şehre düşürmez', (
    tester,
  ) async {
    final islem = SahteKurulum()
      ..secilen = null
      ..gpsHatasi = KurulumKonumHatasi.servisKapali;
    await ac(tester, islem, () {});
    await bas(tester, 'setup_manual');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('setup_next')))
          .onPressed,
      isNull,
    );
    await bas(tester, 'setup_gps');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(islem.ayarlar, 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('setup_next')))
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'reddedilmiş izinlerle devam edilir; sessizde ezan varsayılan kapalıdır',
    (tester) async {
      final islem = SahteKurulum();
      var bitti = false;
      await ac(tester, islem, () => bitti = true);
      await bas(tester, 'setup_manual');
      await bas(tester, 'setup_next');
      await bas(tester, 'setup_mode_ezan');
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('setup_silent')))
            .value,
        false,
      );
      await bas(tester, 'setup_next');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('setup_next')))
            .onPressed,
        isNull,
      );
      await bas(tester, 'setup_request');
      expect(find.textContaining('Uyarılar gelmeyebilir'), findsOneWidget);
      await bas(tester, 'setup_next');
      expect(bitti, true);
      expect(islem.kayitModu, VakitBildirimModu.ezan);
      expect(islem.kayitSessizde, false);
      expect(islem.istemler, 1);
    },
  );
  testWidgets(
    'geri ilerleme izinleri tekrar istemez, kayıt hatası kurulumu kapatmaz',
    (tester) async {
      final islem = SahteKurulum()..kayitHatasi = true;
      var bitti = false;
      await ac(tester, islem, () => bitti = true);
      await izinAdiminaGit(tester, 'bildirim');
      await bas(tester, 'setup_request');
      await bas(tester, 'setup_back');
      await bas(tester, 'setup_next');
      expect(islem.istemler, 1);
      await bas(tester, 'setup_next');
      expect(bitti, false);
      islem.kayitHatasi = false;
      await bas(tester, 'setup_next');
      expect(bitti, true);
      expect(islem.kayitModu, VakitBildirimModu.bildirim);
    },
  );
  testWidgets('küçük ekranda büyük yazıyla üç adım kaydırılabilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: IlkKurulumSayfasi(islemler: SahteKurulum(), tamamlandi: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await izinAdiminaGit(tester, 'kapali');
    await bas(tester, 'setup_request');
    expect(tester.takeException(), isNull);
  });
}
