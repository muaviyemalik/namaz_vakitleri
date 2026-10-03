// test/gecikmis_cevap_saat_dilimi_test.dart
//
// GEÇ GELEN CEVAP, SON SEÇİLEN KONUMUN SAAT DİLİMİNİ DEĞİŞTİRMEZ.
//
// HATANIN TANIMI
//
// Ana sayfada her yükleme artan bir "istek jetonu" alır: `_verileriYukle`
// `final jeton = ++_istekJetonu` yapar ve cevap döndüğünde
// `jeton != _istekJetonu` ise cevabı ekrana uygulamaz. Kullanıcının son
// seçimi böylece korunur.
//
// ANCAK cevabın YAN ETKİSİ olan bir adım vardı ve o adım jetonu hiç
// almıyordu:
//
//   _agiDene(...)  ->  sonuc.basariliMi ise
//                        konumSaatDilimiKesinlestir(...)
//
// `konumSaatDilimiKesinlestir` global `aktifKonum`'u DEĞİŞTİRİP
// `konumKaydet` ile cihaza YAZAR. Yani yan etki, güncellik denetimi
// yapılmadan, hatta denetimin yapıldığı yerden (çağıranda) daha önce
// uygulanıyordu.
//
// BOZULMA SENARYOSU (bu testin ölçtüğü)
//
//   1. Ankara seçili, saat dilimi BİLİNİYOR. İstek atılır (jeton 1).
//   2. Ağ yavaş. Kullanıcı Tokyo'yu seçer (jeton 2). Tokyo'nun saat dilimi
//      HENÜZ BİLİNMİYOR (`''`).
//   3. Ankara'nın cevabı GELİR (geç). `_agiDene` içindeki yan etki çalışır:
//      o an seçili olan konum Tokyo, `saatDilimi` boş -> cevaptaki
//      "Europe/Istanbul" TOKYO'YA yazılır ve cihaza kaydedilir.
//   4. Tokyo'nun kendi cevabı gelir; jeton artık 2 değildir, bu yüzden
//      Tokyo'nun saat dilimi hiç doğrulanamaz ve yanlış dilim kalıcıdır.
//
// SONUÇ: Ekranda Tokyo yazar ama Tokyo'nun saat dilimi kalıcı olarak
// Europe/Istanbul. Cihaz yeniden açıldığında Tokyo vakitleri İstanbul
// saatinde hesaplanır (sessiz kayma) ve o hatalı dilim
// `VakitDepo.kayitliSaatDilimi` ile de kalıcıdır.
//
// BU TEST NASIL DETERMİNİSTİR?
//
//   * Gerçek üretim akışı: `AnaSayfa` gerçek widget'ı, gerçek
//     `VakitDepo`, gerçek `konumSaatDilimiKesinlestir`, gerçek
//     SharedPreferences (mock depoda), gerçek `http.get` (package:http).
//     Test içinde bir jeton algoritması YOKTUR; jetonun kendisi üretim
//     kodundadır ve bu test ona yalnızca DOLAYLI olarak gider.
//   * Ağ deterministiktir: `uretim_akisi.dart` içindeki sahte istemci
//     cevabı testin belirlediği sırada verir. Gerçek ağ, konum ve bildirim
//     servisine hiç dokunulmaz.
//   * Sabit saat: sonuç gerçek tarihe bağlı değildir.
//   * Test başına temiz tercih/önbellek.
//   * Sabit gerçek-zaman beklemesi yoktur: ceviriler bellekten gelir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uretim_akisi.dart';

/// Cihaza kaydedilen konumun saat dilimi alanı (5. parça).
Future<String?> _kayitliSaatDilimi() async {
  final h = await SharedPreferences.getInstance();
  final ham = h.getString(kayitliKonumAnahtari);
  if (ham == null) return null;
  final parca = ham.split('|');
  return parca.length >= 5 ? parca[4] : null;
}

void main() {
  setUpAll(() async {
    await uretimTestiBaslat();
  });

  setUp(() {
    testOrtaminiSifirla();
  });

  tearDown(() {
    testOrtaminiKapat();
  });

  testWidgets(
      'gec gelen cevap, son secilen konumun saat dilimini BOZMAMALI '
      '(Ankara istegi surerken Tokyo secildi)', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      // 1) Ankara secili, saat dilimi biliniyor; istek agda bekliyor.
      await sayfayiAc(tester, konumAnkara);
      expect(kuyruk.istekSayisi(konumAnkara, yil: testYili, ay: testAyi), 1,
          reason: 'Ankara icin ag istegi atilmis olmali');

      // 2) Kullanici Tokyo'yu secme zamani gecti: saat dilimi bilinmiyor.
      aktifKonum.value = konumTokyo;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1,
          reason: 'Tokyo icin ikinci istek atilmis olmali');
      expect(aktifKonum.value!.saatDilimi, isEmpty,
          reason: 'Tokyo saat dilimi henuz bilinmiyor');

      // 3) GEC CEVAP: Ankara'nin cevabi simdi geliyor.
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // 4) Tokyo'nun kendi cevabi geliyor.
      kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // --- OLCUM ---
      expect(aktifKonum.value!.ad, 'Tokyo', reason: 'son secim kaybolmamali');
      expect(aktifKonum.value!.saatDilimi, 'Asia/Tokyo',
          reason: 'Ankara gec cevabi Tokyo ya Europe/Istanbul yazmamali');
      expect(await _kayitliSaatDilimi(), 'Asia/Tokyo',
          reason: 'kalici kayit da Tokyo saat dilimini göstermeli');

      // Ekranda da Tokyo vakitleri gorunmeli.
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'cevaplar ters sirada donse de son secilen konumun saat dilimi '
      'dogru kalmali (Tokyo once, Ankara sonra)', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      expect(kuyruk.istekSayisi(konumAnkara, yil: testYili, ay: testAyi), 1);

      aktifKonum.value = konumTokyo;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1);

      // Yeni cevap ONCE, eski cevap SONRA.
      kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(aktifKonum.value!.saatDilimi, 'Asia/Tokyo');
      expect(await _kayitliSaatDilimi(), 'Asia/Tokyo');
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'gec / iptal edilmis yukleme GERCEK ag hatasi sayilmaz '
      '(Tokyo yuklenmisken gec Paris cevabi uyari cikarmaz)', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // Paris istegi atilir; kullanici beklemeden Tokyo'yu secer. Paris'in
      // yuklemesi artik GECERSIZDIR (jetonu geçti), ama henuz bilmiyoruz.
      aktifKonum.value = konumParis;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumParis, yil: testYili, ay: testAyi), 1);

      aktifKonum.value = konumTokyo;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1);

      // Tokyo'nun cevabi gelir: ekran Tokyo'da acilir.
      kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);

      // Paris'in GEC cevabi gelir. Bu bir ag hatasi DEGILDIR: internet vardir,
      // veri vardir; yalnizca bu istek artik gecerli degildir.
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(find.byType(SnackBar), findsNothing,
          reason: 'gec cevap bir ag hatasi sayilmamali; ekranda gecerli '
              'Tokyo verisi varken "internet yok" uyarisi yanilticidir');

      // ESKI VERI EKRANA UYGULANMADI
      expect(aktifKonum.value!.ad, 'Tokyo');
      expect(find.text('Tokyo'), findsOneWidget,
          reason: 'baslik Tokyo kalmali');
      expect(find.text('Paris'), findsNothing,
          reason: 'gec Paris verisi ekrana uygulanmamali');
      expect(find.byIcon(Icons.cloud_off), findsNothing,
          reason: 'hata ekrani gosterilmemeli');

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'reddedilen cevap (gercek hata) uyariyi gostermeye devam eder',
      (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // Tokyo icin REDDEDILEN bir cevap: HTTP 503 + mantiksal hata.
      aktifKonum.value = konumTokyo;
      await akisIlerlet(tester);
      final sira = kuyruk.siralari(konumTokyo, yil: testYili, ay: testAyi).first;
      kuyruk.cevapVer(sira, durum: 503);
      await akisIlerlet(tester);

      expect(find.byType(SnackBar), findsOneWidget,
          reason: 'gercek hata kullaniciya bildirilmeli');
      expect(find.byIcon(Icons.cloud_off), findsOneWidget,
          reason: 'hata ekrani gosterilmeli');

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'KALDIRILMIS ekranin gec yaniti aktif ve kalici konuma dokunmamali',
      (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumTokyo);
      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1);

      // Ekran kaldirilir (dispose). Bekleyen Tokyo istegi iptal edilmez;
      // cevabi dondugunde karsilayacak bir State yoktur.
      await tester.pumpWidget(const SizedBox());

      // Kullanici bu arada Paris'i secip KAYDEDIYOR.
      aktifKonum.value = konumParis;
      await konumKaydet(konumParis);

      // Tokyo'nun gec cevabi geliyor.
      kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      final h = await SharedPreferences.getInstance();
      final ham = h.getString(kayitliKonumAnahtari)!;
      expect(
        <String>[
          aktifKonum.value!.ad,
          aktifKonum.value!.saatDilimi,
          ham.split('|')[4],
        ],
        <String>['Paris', 'Europe/Paris', 'Europe/Paris'],
        reason: 'dispose edilmis State in yaniti yeni secimi ve cihaz '
            'kaydini bozamaz. `dispose` jetonu gecersiz kilmaz; bu yuzden '
            'guncellik denetimi ekranin ayakta olmasini da kontrol etmeli',
      );
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'yeni AnaSayfa acildiginda secim korunur; eski ekranin gec yaniti '
      'yeni durumu bozmaz', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      // 1) Eski ekran: Tokyo istegi bekliyor.
      await sayfayiAc(tester, konumTokyo);
      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1);

      // 2) Eski ekran kaldirilir.
      await tester.pumpWidget(const SizedBox());

      // 3) Kullanici Paris'i secip kaydediyor, sonra uygulamaya donuyor.
      aktifKonum.value = konumParis;
      await konumKaydet(konumParis);

      // 4) YENI ekran acilir ve Paris'in verisini ister.
      await sayfayiAc(tester, konumParis);
      expect(kuyruk.istekSayisi(konumParis, yil: testYili, ay: testAyi), 1,
          reason: 'yeni ekran kendi konumunu kendi istegiyle yuklemeli');

      // 5) Eski ekranin Tokyo cevabi ONCE geliyor.
      kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      var h = await SharedPreferences.getInstance();
      var ham = h.getString(kayitliKonumAnahtari)!;
      expect(
        <String>[
          aktifKonum.value!.ad,
          aktifKonum.value!.saatDilimi,
          ham.split('|')[4],
        ],
        <String>['Paris', 'Europe/Paris', 'Europe/Paris'],
        reason: 'eski ekranin yaniti yeni secimi degistirmemeli',
      );
      expect(find.text('Paris'), findsOneWidget,
          reason: 'yeni ekran Paris bilgisini göstermeye devam etmeli');
      expect(find.byType(SnackBar), findsNothing,
          reason: 'eski yanit bir hata degildir; uyari cikmamali');

      // 6) Yeni ekranin kendi Paris cevabi geliyor.
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      h = await SharedPreferences.getInstance();
      ham = h.getString(kayitliKonumAnahtari)!;
      expect(
        <String>[
          aktifKonum.value!.ad,
          aktifKonum.value!.saatDilimi,
          ham.split('|')[4],
        ],
        <String>['Paris', 'Europe/Paris', 'Europe/Paris'],
      );
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget,
          reason: 'yeni ekran kendi dogrulanmis cevabini uygulamali');
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });
}
