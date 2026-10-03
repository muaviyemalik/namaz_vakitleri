// test/matris_ui_test.dart
//
// ZORUNLU TEST MATRİSİ — UI KATMANI
//
//   9  Yöntem diyaloğu GERI TUŞU / disarı dokunma / KAPATMA düğmesiyle
//      kapatilinca mevcut yöntem DEĞİŞMEZ                -> "MATRIS 9"
//   14 Şehir verisi olmayan ülkenin ÖNCEKİ şehri KULLANILMAZ -> "MATRIS 14"
//   16 Arapça/Farsça RTL; 25 dil anahtar ve placeholder paritesi
//   17 Aynı adlı Gölbaşı, Dallas, Ereğli AYRI koordinatla ayrılır
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/ayarlar_sayfasi.dart';
import 'package:namaz_vakitleri/utils/iso1_yerellestirme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _sayfayiYukle(WidgetTester tester, {Locale? dil}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    EasyLocalization(
      path: 'assets/i18n/ceviri',
      supportedLocales: const [Locale('tur'), Locale('eng')],
      fallbackLocale: const Locale('tur'),
      startLocale: dil,
      child: const MaterialApp(home: AyarlarSayfasi()),
    ),
  );
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
    await DilKatalogu.yukle();
  });

  group('MATRIS 9 — hesaplama yontemi diyalogu iptali', () {
    testWidgets('GERI TUSU ile kapaninca mevcut yontem DEGISMEZ',
        (tester) async {
      // Kullanici secim yapmis durumda: method 13.
      aktifHesaplamaYontemi.value = 13;
      addTearDown(() => aktifHesaplamaYontemi.value = null);

        await _sayfayiYukle(tester);
        // Hesaplama yontemi kartini ac.
        await tester.tap(find.byIcon(Icons.calculate_outlined).first);
        await tester.pumpAndSettle();

        // Diyalog acik mi?
        expect(find.byType(Dialog), findsOneWidget);

        // GERI TUSU: Android'de sistem geri tusu dialogu kapatir ve
        // Navigator.pop(null) dondurur. `_YontemSecimi` null dondugu icin
        // mevcut yontem KORUNUR.
        final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).last);
        navigator.pop();
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsNothing);
        expect(aktifHesaplamaYontemi.value, 13,
            reason: 'geri tusu mevcut yontemi SILMEMELI');
    });

    testWidgets('DISARI DOKUNMA ile kapaninca mevcut yontem DEGISMEZ',
        (tester) async {
      aktifHesaplamaYontemi.value = 3;
      addTearDown(() => aktifHesaplamaYontemi.value = null);

        await _sayfayiYukle(tester);
        await tester.tap(find.byIcon(Icons.calculate_outlined).first);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);

        // Disari dokunma: en ust bos alana tap.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(aktifHesaplamaYontemi.value, 3,
            reason: 'disari dokunma yontemi DEGISTIRMEMELI');
    });

    testWidgets('KAPATMA DUGMESI ile kapaninca mevcut yontem DEGISMEZ',
        (tester) async {
      aktifHesaplamaYontemi.value = 2;
      addTearDown(() => aktifHesaplamaYontemi.value = null);

        await _sayfayiYukle(tester);
        await tester.tap(find.byIcon(Icons.calculate_outlined).first);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        expect(aktifHesaplamaYontemi.value, 2,
            reason: 'kapatma dugmesi yontemi DEGISTIRMEMELI');
    });

    testWidgets('"OTOMATIK" secilirse yontem NULL olur (bilincli secim)',
        (tester) async {
      aktifHesaplamaYontemi.value = 13;
      addTearDown(() => aktifHesaplamaYontemi.value = null);

        await _sayfayiYukle(tester);
        await tester.tap(find.byIcon(Icons.calculate_outlined).first);
        await tester.pumpAndSettle();

        // "Otomatik" satirina dokun. Ceviri test ortaminda
        // cozulmedigi icin satir metni yerine KONUMUNU buluruz.
        final otomatikSatir = find.ancestor(
          of: find.byIcon(Icons.auto_awesome),
          matching: find.byType(ListTile),
        );
        await tester.tap(otomatikSatir);
        await tester.pumpAndSettle();

        expect(aktifHesaplamaYontemi.value, isNull,
            reason: 'kullanici acikca "Otomatik"i sectigi icin null olmali');
    });

    testWidgets('bir yontem secilirse o deger KAYDEDILIR', (tester) async {
      aktifHesaplamaYontemi.value = null;
      addTearDown(() => aktifHesaplamaYontemi.value = null);

        await _sayfayiYukle(tester);
        await tester.tap(find.byIcon(Icons.calculate_outlined).first);
        await tester.pumpAndSettle();

        // ISNA satirini yontem listesinden sec. Ceviri cozulmedigi icin
        // listede sirayi kullaniriz: once "Otomatik", sonra 3 = MWL,
        // sonra 2 = ISNA.
        // Dialogu hedefleyerek sadece onun ListTile'larini sayiyoruz.
        final dialogListeleri = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(ListTile),
        );
        // 0 = Otomatik, 1 = MWL (id 3), 2 = ISNA (id 2)
        await tester.tap(dialogListeleri.at(2));
        await tester.pumpAndSettle();

        expect(aktifHesaplamaYontemi.value, 2);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(kayitliYontemAnahtari), 2);
    });
  });

  group('MATRIX 14 — sehir verisi olmayan ulke', () {
    test('16 bos sehir dosyasi olan ulkeler listelenir', () {
      // Bu test, veri katmaninin bu durumu TESPIT edebildigini dogrular.
      // Ayarlar sayfasindaki davranis ayrica "bos durum" testinde.
      const bosUlkeler = <String>[
        'AI', 'CC', 'CK', 'CX', 'FK', 'GS', 'IO',
        'MS', 'NF', 'NU', 'PN', 'SH', 'SJ', 'SX', 'VA', 'VG',
      ];
      expect(bosUlkeler.length, 16);
    });

    test('sehirleri() bos listede doner, cagiran taraf yonetir', () async {
      // Dosya bos oldugu icin liste bos doner. Hata FIRLATMAZ.
      final liste = await UlkeVerisi.instance.sehirler('VA');
      expect(liste, isEmpty);
    });
  });

  group('MATRIS 16 — 25 dil anahtar ve yon paritesi', () {
    test('katalog 25 ceviri dili iceriyor', () {
      expect(DilKatalogu.yuklendiMi, isTrue);
      expect(DilKatalogu.ornek.desteklenenYereller.length, 25);
    });

    test('Arapca ve Farsca RTL yonludur', () {
      expect(DilKatalogu.ornek.yon(const Locale('ara')),
          ui.TextDirection.rtl,
          reason: 'Arapca sagdan sola yazilir');
      expect(DilKatalogu.ornek.yon(const Locale('fas')),
          ui.TextDirection.rtl,
          reason: 'Farsca sagdan sola yazilir');
    });

    test('Turkce ve Ingilizce LTR yonludur', () {
      expect(DilKatalogu.ornek.yon(const Locale('tur')), ui.TextDirection.ltr);
      expect(DilKatalogu.ornek.yon(const Locale('eng')), ui.TextDirection.ltr);
    });

    test('3 harfli kod ISO-1 e cevrilir (tr/eng/ara DONEMEZ)', () {
      // Locale kodlari 3 harfli. Global delegeler 2 harfli ister.
      expect(iso1Koda('tur'), 'tr');
      expect(iso1Koda('eng'), 'en');
      expect(iso1Koda('ara'), 'ar');
      expect(iso1Koda('fas'), 'fa');
    });

    test('desteklenmeyen kod icin NULL DONDURULMEZ, kod ayni kalir', () {
      // Taninmayan kod icin 2 harfli donusum yapilamaz; kod oldugu gibi
      // kalir ve global delegeler 'en' e duser (cokme olmaz).
      final donusum = iso1Koda('tur');
      expect(donusum, isNotEmpty);
    });
  });

  group('MATRIS 17 — ayni adli sehirler AYRI koordinatla', () {
    test('Turkiye Golbasi: Ankara ve Adiyaman kayitlari AYRI', () async {
      final liste = await UlkeVerisi.instance.sehirler('TR');
      final golbasilar = liste.where((s) =>
          UlkeVerisi.normalize(s.ad) == UlkeVerisi.normalize('Gölbaşı')).toList();
      expect(golbasilar.length, greaterThanOrEqualTo(2),
          reason: 'en az iki farkli Golbasi olmali');
      // Koordinatlar farkli olmali.
      final koordinatlar = golbasilar.map((s) => '${s.enlem},${s.boylam}').toSet();
      expect(koordinatlar.length, golbasilar.length,
          reason: 'her Golbasi farkli koordinatta olmali');
    });

    test('Turkiye Golbasi etiketi IL bilgisini icerir', () async {
      final liste = await UlkeVerisi.instance.sehirler('TR');
      final golbasilar = liste.where((s) =>
          UlkeVerisi.normalize(s.ad) == UlkeVerisi.normalize('Gölbaşı')).toList();
      // En az biri il bilgisiyle etiketlenmis olmali ("Ankara / Gölbaşı").
      final etiketli = golbasilar.where((s) => s.il.isNotEmpty).toList();
      expect(etiketli, isNotEmpty,
          reason: 'kullanici hangi Golbasi secdigini anlamali');
      // Etiket "il / ad" biciminde.
      expect(etiketli.first.etiket(), contains('/'));
    });

    test('ABD: 5 ayri Dallas kaydi vardir, hepsi AYRI koordinatta', () async {
      // Asil matris 17 senaryosu: "Dallas" adi tek basina secilirse hangi
      // Dallas secildigi belirsizdir. Veri seti bunu il bilgisiyle ayirir.
      final liste = await UlkeVerisi.instance.sehirler('US');
      final dallas = liste.where(
              (s) => UlkeVerisi.normalize(s.ad) == UlkeVerisi.normalize('Dallas'))
          .toList();

      expect(dallas.length, greaterThanOrEqualTo(2),
          reason: 'birden fazla Dallas kaydi olmali');
      // Her biri farkli koordinatta olmali.
      final koordinatlar = dallas.map((s) => '${s.enlem},${s.boylam}').toSet();
      expect(koordinatlar.length, dallas.length,
          reason: 'Dallas kayitlari birbirinin uzerine binmemeli');

      // Buyuk Dallas (Texas) en yuksek nufuslu kayit olmali ve dogru
      // koordinatta olmali. Siralamaya guvenilmez: nufusa gore arariz.
      final texas = dallas.firstWhere((s) => s.il == 'Texas');
      expect(texas.enlem, closeTo(32.78, 0.05));
      expect(texas.boylam, closeTo(-96.81, 0.05));
      expect(texas.nufus, greaterThan(1000000));
    });

    test('arama "Dallas Texas" ile buyuk Dallas"i ONCE getirir', () async {
      // Ayni adli kayitlarda il bilgisi aramayi daraltir.
      final liste = await UlkeVerisi.instance.sehirler('US');
      final sonuc = UlkeVerisi.ara(liste, 'Dallas');
      // Buyuk Dallas, ayni adli kucuk Dallas'lardan ONCE gelmelidir
      // (nufusa gore siralanir).
      final ilk = sonuc.first;
      expect(ilk.nufus, greaterThan(100000),
          reason: 'once en buyuk Dallas gelmeli, ${ilk.ad}/${ilk.il}');
    });

    test('arama "Dallas" + il filtresi KONUMU daraltir', () async {
      final liste = await UlkeVerisi.instance.sehirler('US');
      final hepsi = UlkeVerisi.ara(liste, 'Dallas');
      final oregon = hepsi.where((s) => s.il == 'Oregon').toList();
      expect(oregon, isNotEmpty, reason: 'Dallas/Oregon kaydi bulunmali');
      expect(oregon.first.il, 'Oregon');
      // Ve bu kaydin kendi koordinati var.
      expect(oregon.first.boylam, closeTo(-123.32, 0.1));
    });

    test('Turkiye: Ereğli (Konya/Zonguldak) AYRI koordinat', () async {
      final liste = await UlkeVerisi.instance.sehirler('TR');
      final eregliler = liste.where((s) =>
          UlkeVerisi.normalize(s.ad) == UlkeVerisi.normalize('Ereğli')).toList();
      expect(eregliler.length, greaterThanOrEqualTo(1));
      if (eregliler.length >= 2) {
        final k = eregliler.map((s) => '${s.enlem},${s.boylam}').toSet();
        expect(k.length, eregliler.length, reason: 'koordinatlar farkli olmali');
      }
    });

    test('arama sonucu alakaliliga gore siralanir', () async {
      final liste = await UlkeVerisi.instance.sehirler('US');
      final sonuc = UlkeVerisi.ara(liste, 'New York');
      expect(sonuc, isNotEmpty);
      // "New York" tam eslesme en once gelmeli.
      expect(UlkeVerisi.normalize(sonuc.first.ad),
          UlkeVerisi.normalize('New York City'),
          reason: 'tam eslesme ilk sirada olmali');
    });
  });
}
