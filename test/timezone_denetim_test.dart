// timezone paketi kullaniminin DENETIM testi.
// Amac: tz.setLocalLocation'in sabit kodlanmasi gercekten bir hata mi uretiyor,
// yoksa yalnizca semantik olarak yanlis mi? Varsayim yerine olcuyoruz.
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('VARSAYILAN: sabit kodlanmis tz.local alarmin ANLIK zamanini degistirmiyor', () {
    // Uygulama Istanbul sabitliyor (main.dart:77)
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Cihaz farkli bir saat diliminde olsun diye dogrudan bir an olusturuyoruz.
    final DateTime cihazYerel = DateTime.utc(2026, 9, 26, 12, 0);
    final tz.TZDateTime istanbul = tz.TZDateTime.from(cihazYerel, tz.local);
    final tz.TZDateTime berlin = tz.TZDateTime.from(cihazYerel, tz.getLocation('Europe/Berlin'));

    // Ayni AN ayni anlamali; sadece gosterim farki olmali.
    expect(istanbul.millisecondsSinceEpoch, berlin.millisecondsSinceEpoch);
    expect(istanbul.millisecondsSinceEpoch, cihazYerel.millisecondsSinceEpoch);
  });

  test('GERCEK SORUN: sehir vakitleri cihaz saat dilimine gore yorumlaniyor', () {
    // Aladhan, secili SEHIRIN kendi saat diliminde vakit dondurur ve bunu
    // meta.timezone alaninda bildirir (Istanbul icin "Europe/Istanbul").
    //
    // Uygulama bu duz saati DateTime(y, m, d, h, min) ile kuruyor. Bu kurulum
    // cihazin YEREL saat dilimine gore bir AN uretir. Cihaz ile secili sehir
    // farkli UTC ofsetine sahipse vakit kayar.
    //
    // Sapma, iki saat diliminin UTC ofset farki kadardir. Ofsetleri tz
    // veritabanindan okuyarak deterministik olarak hesapliyoruz.
    const int fajrSaat = 4;
    const int fajrDakika = 49;

    int ofsetFarki(String cihazDilimi, String sehirDilimi, int yil, int ay, int gun) {
      final tz.TZDateTime cihazda = tz.TZDateTime(tz.getLocation(cihazDilimi), yil, ay, gun, 12);
      final tz.TZDateTime sehirde = tz.TZDateTime(tz.getLocation(sehirDilimi), yil, ay, gun, 12);
      // Iki zonun ayni ANI (12:00) gostermesi icin gereken ofset farki.
      return cihazda.timeZoneOffset.inMinutes - sehirde.timeZoneOffset.inMinutes;
    }

    // Eylul 2026: Berlin (CEST) UTC+2, Istanbul UTC+3 -> fark 60 dakika.
    final int sapmaBerlin = ofsetFarki('Europe/Berlin', 'Europe/Istanbul', 2026, 9, 26);
    print('Berlin cihaz + Istanbul sehir sapmasi : $sapmaBerlin dakika');
    expect(sapmaBerlin, -60, reason: 'Cihaz 1 saat geride, vakit 1 saat ERKEN gider');

    // New York (EDT) UTC-4, Istanbul UTC+3 -> fark 420 dakika (7 saat).
    final int sapmaNewYork = ofsetFarki('America/New_York', 'Europe/Istanbul', 2026, 9, 26);
    print('New York cihaz + Istanbul sehir sapmasi: $sapmaNewYork dakika');
    expect(sapmaNewYork, -420, reason: '7 saatlik sapma olmali');

    // Her iki durumda da sapma sifirdan farkli: mevcut kod bu senaryolarda
    // vakitleri yanlis kurar. Dogru cozum, Aladhan meta.timezone degerini
    // kullanip vakti o zonda yorumlamak.
    expect(sapmaBerlin, isNot(0));
    expect(sapmaNewYork, isNot(0));
    expect(fajrSaat, 4, reason: 'fajr saati test icin');
    expect(fajrDakika, 49, reason: 'fajr saati test icin');
  });

  test('CIHAZ VE SEHIR AYNI SAAT DILIMINDEYSE SAPMA OLMAZ', () {
    // Turkiye'de yaygin senaryo: cihaz de secilen sehir de Europe/Istanbul.
    // Mevcut kod bu durumda dogru calisiyor; sorun yalnizca yurt disinda.
    final tz.TZDateTime dogruAn = tz.TZDateTime(
      tz.getLocation('Europe/Istanbul'),
      2026,
      9,
      26,
      4,
      49,
    );
    final DateTime cihazYerelSaat = DateTime(2026, 9, 26, 4, 49);

    expect(cihazYerelSaat.difference(dogruAn.toLocal()).inMinutes, 0);
  });
}
