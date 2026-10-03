// test/saat_dilimi_kesinlesmesi_test.dart
//
// SAAT DİLİMİ KESİNLEŞMESİ, BAŞARILI YÜKLEMEYİ GEÇERSİZ KILMAMALI.
//
// HATANIN TANIMI
//
// `_agiDene` cevabı doğruladıktan sonra saat dilimini konuma işler:
// `konumSaatDilimiKesinlestir` global `aktifKonum`'u GÜNCELLER ve cihaza
// yazar. Bu değişiklik `_aktifKonumDegisti` dinleyicisini tetikler ve
// dinleyici yeni bir `_verileriYukle` başlatır — yani jeton artar. Bunun
// sonucu ÜÇ hata birden doğuyordu:
//
//   1) Aynı konum ve aynı ay için GEREKSİZ BİR İKİNCİ ağ isteği atılıyordu
//      (önbellek anahtarı saat dilimini içermez; veri zaten eldeydi).
//   2) Saat dilimini kesinleştiren yükleme, KENDİ YAPTIĞI değişiklik
//      yüzünden "eski" sayılıyordu: `jeton != _istekJetonu` kontrolünde
//      cevap reddediliyor ve EKRANA UYGULANMIYORDU. Doğrulanmış veri,
//      doğruladığı andan sonra çöpe gidiyordu.
//   3) `false` dönen yükleme, `_aktifKonumDegisti` içinde kırmızı
//      "internet yok" uyarısı gösteriyordu — oysa internet ve veri vardı.
//
// BU TEST NASIL ÖLÇÜYOR?
//
//   * Gerçek üretim akışı: `AnaSayfa` widget'ı, gerçek `VakitDepo`, gerçek
//     `konumSaatDilimiKesinlestir`, gerçek `http.get`, gerçek
//     SharedPreferences (mock depo).
//   * Sabit saat ([SabitSaat]) — sonuç gerçek tarihe bağlı değildir.
//   * Test başına temiz tercih/önbellek (`testOrtaminiSifirla`).
//   * Kontrollü ağ (`uretim_akisi.dart`): istemci testte, cevap testte.
//   * Sabit gerçek-zaman beklemesi yoktur: ceviriler bellekten gelir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';

import 'uretim_akisi.dart';

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
      'saat dilimi kesinlesmesi ayni konum/ay icin ikinci istek atmaz ve '
      'basarili yaniti ekrana uygular', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      // --- Hazirlik: Ankara yuklensin (saat dilimi zaten biliniyor) ---
      await sayfayiAc(tester, konumAnkara);
      expect(kuyruk.istekSayisi(konumAnkara, yil: testYili, ay: testAyi), 1);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget,
          reason: 'Ankara agdan acildi');

      // --- Tokyo secildi: saat dilimi henuz bilinmiyor ---
      aktifKonum.value = konumTokyo;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1,
          reason: 'Tokyo icin ilk istek atilmali');
      expect(aktifKonum.value!.saatDilimi, isEmpty,
          reason: 'Tokyo saat dilimi cevap gelene kadar bilinmiyor');

      // --- Tokyo'nun cevabi geldi: saat dilimi kesinlesiyor ---
      kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // --- OLCUM ---
      expect(aktifKonum.value!.saatDilimi, 'Asia/Tokyo',
          reason: 'dogru saat dilimi kesinlesmeli');

      expect(kuyruk.istekSayisi(konumTokyo, yil: testYili, ay: testAyi), 1,
          reason: 'saat dilimi kesinlesti diye ayni konum/ay icin ikinci ag '
              'istegi atilmamali');

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget,
          reason: 'dogrulanan ag cevabi ekrana uygulanmali (kaynak: ag). '
              'Onbellekten acilsaydi "cevrimdisi" isareti gorunurdu');

      expect(find.byType(SnackBar), findsNothing,
          reason: 'internet ve veri varken "internet yok" uyarisi '
              'gosterilmemeli');

      expect(find.byIcon(Icons.cloud_off), findsNothing,
          reason: 'hata ekrani gosterilmemeli');

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'saat dilimi kesinlesmesi bastirilirken GERCEK sehir ve yontem '
      'degisimi yine de istek atar', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // --- Gercek sehir degisikligi ---
      aktifKonum.value = konumParis;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumParis, yil: testYili, ay: testAyi), 1,
          reason: 'sehir degisince yeni istek atilmali');
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(find.text('Paris'), findsOneWidget, reason: 'baslik Paris olmali');
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);

      // --- Gercek yontem degisikligi (konumun kendisi degisir) ---
      aktifHesaplamaYontemi.value = 13;
      await akisIlerlet(tester);
      final siralar = kuyruk.siralari(konumParis, yil: testYili, ay: testAyi);
      expect(siralar.length, 2,
          reason: 'yontem degisince ayni konum/ay icin yeni istek atilmali');
      expect(
          kuyruk.istekler[siralar.last].url.queryParameters['method'], '13',
          reason: 'kullanicinin sectigi yontem APIye gonderilmeli');
      kuyruk.cevapVer(siralar.last);
      await akisIlerlet(tester);

      expect(aktifKonum.value!.yontemId, 13);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'saat dilimi kesinlesmesi GUNU degistiriyorsa dogru gunun verisi '
      'yuklenir', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // Kolkata secildi. Saat dilimi bilinmedigi icin gun, boylama dayali
      // tahminle BULUNUR ve bu tahmin [sabitAn] itibariyla 16 Eylul der
      // (gercek gun 15 Eylul).
      aktifKonum.value = konumKolkata;
      await akisIlerlet(tester);
      expect(kuyruk.istekSayisi(konumKolkata, yil: testYili, ay: testAyi), 1);

      kuyruk.cevapVerIlkBekleyen(konumKolkata, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(aktifKonum.value!.saatDilimi, 'Asia/Kolkata',
          reason: 'saat dilimi kesinlesmeli');

      // Kesin gun tahminden farkli: ayni ayin DOGRU gunu icin bu MESRU bir
      // ek istektir (olcum burada gereksiz ile gerekli isteyi ayirt eder).
      expect(kuyruk.istekSayisi(konumKolkata, yil: testYili, ay: testAyi), 2,
          reason: 'gun duzeltmesi icin ikinci istek atilmali (gereksiz degil, '
              'gerekli)');

      kuyruk.cevapVerIlkBekleyen(konumKolkata, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(find.text('15.09.2026'), findsOneWidget,
          reason: 'dogru gunun vakitleri gosterilmeli');
      expect(find.text('16.09.2026'), findsNothing,
          reason: 'tahmin gunu gosterilmemeli');
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'kesinlesme anindaki GERCEK hesap ayari degisimi bastirilmaz; yeni '
      'istek secilen ayarlari tasiyor', (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);

    // Ayar degisimi, saat diliminin KESINLESTIGI ANDA yapilir. Bu en zor
    // zamanlama: bastirma bayrağı açıkken yapılan gerçek bir değişiklik
    // yanlışlıkla kendi değişikliği sanılıp yutulmamalı.
    var tetiklendi = false;
    void ayarDegistir() {
      if (tetiklendi) return;
      if (aktifKonum.value?.ad == 'Tokyo' &&
          aktifKonum.value?.saatDilimi == 'Asia/Tokyo') {
        tetiklendi = true;
        aktifHesaplamaYontemi.value = 4;
      }
    }

    await kontrolluAg(kuyruk, () async {
      try {
        await sayfayiAc(tester, konumAnkara);
        kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
        await akisIlerlet(tester);

        aktifKonum.addListener(ayarDegistir);
        aktifKonum.value = konumTokyo;
        await akisIlerlet(tester);
        kuyruk.cevapVerIlkBekleyen(konumTokyo, yil: testYili, ay: testAyi);
        await akisIlerlet(tester);
      } finally {
        aktifKonum.removeListener(ayarDegistir);
      }

      expect(tetiklendi, isTrue,
          reason: 'ayar değişimi kesinleşme anında yapılmalı; olmadıysa bu '
              'test yanlış şeyi ölçer');
      expect(aktifKonum.value!.yontemId, 4);

      // Gerçek yöntem değişimi BASTIRILMADI: aynı konum/ay için ikinci istek.
      final siralar = kuyruk.siralari(konumTokyo, yil: testYili, ay: testAyi);
      expect(siralar.length, 2,
          reason: 'gerçek yöntem değişimi kendi metadata değişikliğidir, '
              'saat dilimi değişikliğiyle karıştırılmamalı');
      final yeniUrl = kuyruk.istekler[siralar.last].url;
      expect(yeniUrl.queryParameters['method'], '4');
      expect(yeniUrl.queryParameters['school'], '0');
      expect(yeniUrl.queryParameters['adjustmentMethod'], 'MIDDLE');

      kuyruk.cevapVer(siralar.last);
      await akisIlerlet(tester);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget,
          reason: 'yeni ayarlarla gelen veri ekrana uygulanmalı');
      expect(find.byType(SnackBar), findsNothing);

      // Asr (school) değişimi de kendi parametresini taşır.
      aktifAsrYontemi.value = AsrYontemi.hanafi;
      await akisIlerlet(tester);
      final asrSirasi =
          kuyruk.siralari(konumTokyo, yil: testYili, ay: testAyi).last;
      expect(kuyruk.istekler[asrSirasi].url.queryParameters['school'], '1',
          reason: 'Asr ayarı API parametresine yansımalı');
      expect(kuyruk.istekler[asrSirasi].url.queryParameters['method'], '4',
          reason: 'seçili yöntem korunmalı');
      kuyruk.cevapVer(asrSirasi);
      await akisIlerlet(tester);

      // Yüksek enlem (adjustmentMethod) değişimi de kendi parametresini taşır.
      aktifYuksekEnlemAyaru.value = YuksekEnlemAyaru.ceyrek;
      await akisIlerlet(tester);
      final yukSirasi =
          kuyruk.siralari(konumTokyo, yil: testYili, ay: testAyi).last;
      expect(kuyruk.istekler[yukSirasi].url.queryParameters['adjustmentMethod'],
          'QUARTER');
      kuyruk.cevapVer(yukSirasi);
      await akisIlerlet(tester);

      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });
}
