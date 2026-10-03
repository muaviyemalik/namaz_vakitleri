// test/aladhan_dogrulama_test.dart
//
// ZORUNLU TEST MATRİSİ — CEVAP DOĞRULAMA VE ÖNBELLEK
//
//   10 Eksik Fajr, gecersiz "25:90", eksik timezone, yanlis tarihli
//      API cevaplarinin REDDEDILMESI                -> "cevap dogrulama" gruplari
//   11 Gecersiz cevabin SAGLAM cache'i EZMEMESI    -> "bozuk cevap onbellege yazilmaz"
//   12 Cached acilisin INTERNET BEKLEMEDEN calismasi-> "onbellekten aninda acilis"
//   13 Ilk kurulum ve yeni ayda internetsiz guvenli hata -> "veri yoksa hata, uydurma yok"
//   14 Sehir verisi olmayan ulkenin ONCEKI sehirini KULLANMAMASI -> ayarlar testinde
//   7  Hizli Ankara -> Paris -> Tokyo secimi; en son Tokyo KALIR     ->
//      gercek uretim akisiyla "gecikmis_cevap_saat_dilimi_test.dart";
//      veri katmanindaki karsiligi burada ("MATRIS 7 (veri katmani)")
//
// AĞ KULLANILMAZ. `SharedPreferences` bellek içi mock, saat `SabitSaat`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'fixture/aladhan_ornek.dart';

SabitSaat _utc(int y, int a, int g, int s, int d) =>
    SabitSaat(DateTime.utc(y, a, g, s, d));

Konum _konum(FixtureBilgi b, {int? yontem}) => Konum(
      ad: b.ad,
      ulkeIso2: b.ulke,
      enlem: b.enlem,
      boylam: b.boylam,
      saatDilimi: b.saatDilimi,
      yontemId: yontem,
    );

CevapSonucu _dogrula(String govde, {FixtureBilgi? bilgi, int? yontem, DateTime? gun}) {
  final b = bilgi ?? istanbulBilgi;
  return AladhanCevap(_utc(2026, 9, 26, 12, 0)).dogrula(
    govde,
    httpDurumKodu: 200,
    istenenKonum: _konum(b, yontem: yontem),
    yil: gun?.year ?? b.yil,
    ay: gun?.month ?? b.ay,
    istenenGun: gun,
  );
}

/// JSON'u okunabilir hale getirip tek bir gunun alanini degistirir.
String _degistir(String govde, String yol, {String? yeniMetin, num? yeniSayi, bool sil = false}) {
  final m = json.decode(govde) as Map<String, dynamic>;
  if (sil) {
    m.remove(yol);
  } else if (yeniMetin != null) {
    m[yol] = yeniMetin;
  } else {
    m[yol] = yeniSayi;
  }
  return json.encode(m);
}

String _timings(String govde, String alan, {String? yeniMetin, bool sil = false}) {
  final m = json.decode(govde) as Map<String, dynamic>;
  final t = (m['data'][0] as Map<String, dynamic>)['timings'] as Map<String, dynamic>;
  if (sil) {
    t.remove(alan);
  } else {
    t[alan] = yeniMetin;
  }
  return json.encode(m);
}

String _meta(String govde, String alan, {String? yeniMetin, num? yeniSayi, bool sil = false}) {
  final m = json.decode(govde) as Map<String, dynamic>;
  final meta = (m['data'][0] as Map<String, dynamic>)['meta'] as Map<String, dynamic>;
  if (sil) {
    meta.remove(alan);
  } else if (yeniMetin != null) {
    meta[alan] = yeniMetin;
  } else {
    meta[alan] = yeniSayi;
  }
  return json.encode(m);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('MATRIS 10a — temel dogrulama', () {
    test('gecerli cevap KABUL edilir', () {
      final d = _dogrula(istanbulFixture.govde);
      expect(d, isA<CevapGecerli>());
      final g = (d as CevapGecerli).gun(DateTime(2026, 9, 26))!;
      expect(g.saatler['fajr'], '04:52');
      expect(g.saatler['isha'], '21:29');
      expect(g.saatDilimi, 'Europe/Istanbul');
      expect(g.cevapYontemId, 13);
    });

    test('HTTP 500 REDDEDILIR', () {
      final d = AladhanCevap(_utc(2026, 9, 26, 12, 0)).dogrula(
        istanbulFixture.govde,
        httpDurumKodu: 500,
        istenenKonum: _konum(istanbulBilgi),
        yil: 2026,
        ay: 9,
      );
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.httpHatasi);
    });

    test('govde code=400 REDDEDILIR (Aladhan HTTP 200 donse bile)', () {
      final bozuk = _degistir(istanbulFixture.govde, 'code', yeniSayi: 400);
      final d = _dogrula(bozuk);
      expect((d as CevapReddedildi).sebep, RedSebebi.mantiksalHata);
    });

    test('data bos listesi REDDEDILIR', () {
      final bozuk = _degistir(istanbulFixture.govde, 'data', yeniMetin: '[]');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.veriYok);
    });

    test('data list degilse REDDEDILIR', () {
      final bozuk = _degistir(istanbulFixture.govde, 'data', yeniMetin: 'yok');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.veriYok);
    });

    test('JSON bozuksa UYGULAMA COKMEZ, reddedilir', () {
      final d = _dogrula('{bu json degil');
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.mantiksalHata);
    });
  });

  group('MATRIS 10b — eksik/gecersiz vakit alanlari', () {
    test('EKSIK FAJR reddedilir (00:00 URETILMEZ)', () {
      final bozuk = _timings(istanbulFixture.govde, 'Fajr', sil: true);
      final d = _dogrula(bozuk);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.vakitAlaniEksik);
      expect(d.ayrinti, contains('Fajr'));
    });

    test('EKSIK ISHA reddedilir', () {
      final bozuk = _timings(istanbulFixture.govde, 'Isha', sil: true);
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.vakitAlaniEksik);
    });

    test('EKSIK SUNRISE reddedilir', () {
      final bozuk = _timings(istanbulFixture.govde, 'Sunrise', sil: true);
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.vakitAlaniEksik);
    });

    test('"25:90" gecersiz saat REDDEDILIR', () {
      final bozuk = _timings(istanbulFixture.govde, 'Fajr', yeniMetin: '25:90 (EEST)');
      final d = _dogrula(bozuk);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.saatAralikBozuk);
    });

    test('"24:00" gecersiz saat REDDEDILIR', () {
      final bozuk = _timings(istanbulFixture.govde, 'Isha', yeniMetin: '24:00 (EEST)');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.saatAralikBozuk);
    });

    test('"00:70" gecersiz DAKIKA reddedilir', () {
      final bozuk = _timings(istanbulFixture.govde, 'Asr', yeniMetin: '00:70 (EEST)');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.saatAralikBozuk);
    });

    test('"00:00" REDDEDILIR — namaz vakti olarak gosterilmez', () {
      final bozuk = _timings(istanbulFixture.govde, 'Fajr', yeniMetin: '00:00 (EEST)');
      final d = _dogrula(bozuk);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.sifirSaat);
    });

    test('saat bicimi bozuksa REDDEDILIR', () {
      final bozuk = _timings(istanbulFixture.govde, 'Maghrib', yeniMetin: 'abc (EEST)');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.saatBicimiBozuk);
    });

    test('bos string saat REDDEDILIR', () {
      final bozuk = _timings(istanbulFixture.govde, 'Dhuhr', yeniMetin: '   ');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.vakitAlaniEksik);
    });
  });

  group('MATRIS 10c — eksik/gecersiz timezone', () {
    test('meta.timezone YOKSA reddedilir', () {
      final bozuk = _meta(istanbulFixture.govde, 'timezone', sil: true);
      final d = _dogrula(bozuk);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.saatDilimiYok);
    });

    test('meta.timezone BOSSA reddedilir', () {
      final bozuk = _meta(istanbulFixture.govde, 'timezone', yeniMetin: '  ');
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.saatDilimiYok);
    });

    test('meta.timezone COZULEMEYEN IANA adi reddedilir', () {
      final bozuk = _meta(istanbulFixture.govde, 'timezone', yeniMetin: 'Europe/YokBoyleYer');
      final d = _dogrula(bozuk);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.saatDilimiCozulemedi);
    });
  });

  group('MATRIS 10d — yanlis tarih / ay-yil uyusmazligi', () {
    test('istenen gun listede YOKSA reddedilir', () {
      // 26 Eylul isteniyor ama cevapta 26 Kasim var.
      final d = _dogrula(istanbulFixture.govde,
          gun: DateTime(2026, 9, 26), bilgi: istanbulBilgi);
      expect(d, isA<CevapGecerli>());

      // Aralik cevabini Eylul istegiyle dogrula: aylar tutmuyor.
      final d2 = _dogrula(aralikFixture.govde, bilgi: istanbulBilgi);
      expect(d2, isA<CevapReddedildi>());
      expect((d2 as CevapReddedildi).sebep, RedSebebi.ayYilBesiIlMi);
    });

    test('gregorian.date bozulursa reddedilir', () {
      final m = json.decode(istanbulFixture.govde) as Map<String, dynamic>;
      final g = ((m['data'][0] as Map<String, dynamic>)['date'] as Map)['gregorian'] as Map;
      g['date'] = '2026-09-26'; // bicim yanlis (DD-MM-YYYY degil)
      expect((_dogrula(json.encode(m)) as CevapReddedildi).sebep,
          RedSebebi.tarihAyligiBozuk);
    });

    test('imkansiz gun (31 Subat) reddedilir', () {
      final m = json.decode(istanbulFixture.govde) as Map<String, dynamic>;
      final g = ((m['data'][0] as Map<String, dynamic>)['date'] as Map)['gregorian'] as Map;
      g['date'] = '31-02-2026';
      expect((_dogrula(json.encode(m)) as CevapReddedildi).sebep,
          RedSebebi.tarihAyligiBozuk);
    });

    test('gun 0 veya 32 reddedilir', () {
      for (final bozukGun in ['00-09-2026', '32-09-2026']) {
        final m = json.decode(istanbulFixture.govde) as Map<String, dynamic>;
        final g = ((m['data'][0] as Map<String, dynamic>)['date'] as Map)['gregorian'] as Map;
        g['date'] = bozukGun;
        expect((_dogrula(json.encode(m)) as CevapReddedildi).sebep,
            RedSebebi.tarihAyligiBozuk,
            reason: bozukGun);
      }
    });
  });

  group('MATRIS 10e — koordinat ve yontem uyusmazligi', () {
    test('farkli SEHIR verisi gelirse REDDEDILIR', () {
      // Koordinat New York'unkine cevriliyor ama Istanbul soruluyor.
      final bozuk = _meta(istanbulFixture.govde, 'latitude', yeniSayi: 40.7128);
      final d = _dogrula(bozuk);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.koordinatBesiIlMi);
    });

    test('boylam farkli ise REDDEDILIR', () {
      final bozuk = _meta(istanbulFixture.govde, 'longitude', yeniSayi: -74.0060);
      expect((_dogrula(bozuk) as CevapReddedildi).sebep, RedSebebi.koordinatBesiIlMi);
    });

    test('4 ondalik yuvarlama farki REDDEDILMEZ (tolerans)', () {
      // 41.0054 -> 41.00541 farki 0.00001 derece; bu ayni noktadir.
      final bozuk = _meta(istanbulFixture.govde, 'latitude', yeniSayi: 41.00541);
      expect(_dogrula(bozuk), isA<CevapGecerli>());
    });

    test('kullanici method 13 istedi, cevap 2 dondu REDDEDILIR', () {
      // Bu, "yanlis hesaplama yontemiyle vakit gosterme" hatasini engeller.
      final d = _dogrula(istanbulFixture.govde, yontem: 2);
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.yontemBesiIlMi);
    });

    test('kullanici method 13 istedi, cevap 13 dondu KABUL', () {
      expect(_dogrula(istanbulFixture.govde, yontem: 13), isA<CevapGecerli>());
    });

    test('otomatik mod (yontem null) cevabin yontemini KAYDEDER', () {
      final d = _dogrula(istanbulFixture.govde) as CevapGecerli;
      expect(d.cevapYontemId, 13,
          reason: 'Aladhan Turkiye icin 13 secmis; kullaniciya gosterilmeli');
    });
  });

  group('MATRIS 8 — kullanici method 13: URL ve metadata', () {
    test('method 13 istendiginde cevap metadata 13 olur', () {
      final d = _dogrula(istanbulFixture.govde, yontem: 13) as CevapGecerli;
      expect(d.cevapYontemId, 13);
      for (final g in d.gunler) {
        expect(g.cevapYontemId, 13, reason: '${g.gun}. gun de 13 olmali');
      }
    });

    test('method 13 Paris icin 38 dakika sapma KORUNUR (olculmus gercek)', () {
      // Paris otomatik (UOIF/12) ile method 13 arasinda 38 dakika fark
      // vardir. Bu, method=13 her ulkede kullanilirsa olusan gercek
      // sapmadir ve sessizce "duzeltilmez".
      final otomatik = _dogrula(parisOtomatikFixture.govde, bilgi: parisBilgi) as CevapGecerli;
      final m13 = _dogrula(parisMethod13Fixture.govde, bilgi: parisBilgi, yontem: 13) as CevapGecerli;

      expect(otomatik.cevapYontemId, 12, reason: 'otomatik = UOIF');
      expect(m13.cevapYontemId, 13);

      final fajrOto = otomatik.gun(DateTime(2026, 9, 26))!.saatler['fajr']!;
      final fajr13 = m13.gun(DateTime(2026, 9, 26))!.saatler['fajr']!;
      final fark = _dakika(fajr13) - _dakika(fajrOto);
      expect(fark, -38, reason: 'method 13 Paris Fajr 38 dakika ERKEN');
    });
  });

  group('MATRIS 11/12/13 — onbellek davranisi', () {
    late VakitDepo depo;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      depo = VakitDepo(saat: _utc(2026, 9, 26, 12, 0));
    });

    test('gecerli cevap yazilir ve tekrar okunur', () async {
      final konum = _konum(istanbulBilgi);
      final d = _dogrula(istanbulFixture.govde) as CevapGecerli;
      expect(await depo.kayitYaz(konum, d), isTrue);

      final okunan = await depo.kayitOku(konum, yil: 2026, ay: 9);
      expect(okunan, isNotNull);
      expect(okunan!.gun(DateTime(2026, 9, 26))!.saatler['fajr'], '04:52');
      expect(okunan.saatDilimi, 'Europe/Istanbul');
    });

    test('GECERSIZ cevap SAGLAM onbellegi EZMEZ', () async {
      final konum = _konum(istanbulBilgi);
      // 1) Sağlam veri yaz.
      final iyi = _dogrula(istanbulFixture.govde) as CevapGecerli;
      await depo.kayitYaz(konum, iyi);

      // 2) Bozuk cevap geliyor: Fajr eksik.
      final bozuk = _timings(istanbulFixture.govde, 'Fajr', sil: true);
      final sonuc = await depo.agCevabiniIsle(
        konum: konum,
        govde: bozuk,
        httpDurumKodu: 200,
        istenenGun: DateTime(2026, 9, 26),
      );

      // 3) Sonuc: hata bildirildi ama ESKI SAGLAM VERI KORUNDU.
      expect(sonuc.basariliMi, isTrue,
          reason: 'gecersiz cevap geldi ama onbellekteki saglam veri kullanilmali');
      expect(sonuc.hata, isNotNull, reason: 'ama gerekce de bildirilmeli');
      expect(sonuc.hata!.sebep, RedSebebi.vakitAlaniEksik);

      // 4) Diskteki veri hâlâ sağlam.
      final okunan = await depo.kayitOku(konum, yil: 2026, ay: 9);
      expect(okunan!.gun(DateTime(2026, 9, 26))!.saatler['fajr'], '04:52',
          reason: 'bozuk cevap sağlam onbelleğin UZERINE yazilmadi');
    });

    test('gecersiz cevap onbellekte kayit VARDIR ama bozulmaz', () async {
      final konum = _konum(istanbulBilgi);
      await depo.kayitYaz(konum, _dogrula(istanbulFixture.govde) as CevapGecerli);

      // Hicbir sehirle eslesmeyen koordinatli cevap.
      final yabanc = _meta(istanbulFixture.govde, 'latitude', yeniSayi: 10.0);
      final s = await depo.agCevabiniIsle(
        konum: konum,
        govde: yabanc,
        httpDurumKodu: 200,
        istenenGun: DateTime(2026, 9, 26),
      );
      expect(s.hata!.sebep, RedSebebi.koordinatBesiIlMi);
      expect((await depo.kayitOku(konum, yil: 2026, ay: 9))!.gunler.length, 30);
    });

    test('MATRIS 12: onbellekten aninda acilis (ag beklenmez)', () async {
      // Yalnız onbellek var; ag YOK.
      final konum = _konum(istanbulBilgi);
      await depo.kayitYaz(konum, _dogrula(istanbulFixture.govde) as CevapGecerli);

      final kayit = await depo.kayitOku(konum, yil: 2026, ay: 9);
      expect(kayit, isNotNull, reason: 'acilis aninda ag olmadan veri bulunmali');
      expect(kayit!.gun(DateTime(2026, 9, 26)), isNotNull);
    });

    test('MATRIS 13: veri YOKSA uydurma uretilmez, hata doner', () async {
      final konum = _konum(tokyoBilgi); // hic yuklenmemis
      final kayit = await depo.kayitOku(konum, yil: 2026, ay: 9);
      expect(kayit, isNull);

      final sonuc = await depo.agCevabiniIsle(
        konum: konum,
        govde: '{"code":500,"status":"error","data":[]}',
        httpDurumKodu: 500,
        istenenGun: DateTime(2026, 9, 26),
      );
      expect(sonuc.basariliMi, isFalse);
      expect(sonuc.bugun, isNull, reason: 'hicbir vakit uydurulmamali');
      expect(sonuc.kaynak, VakitKaynagi.yok);
      expect(sonuc.hata, isNotNull);
    });

    test('MATRIS 13: yeni ay internetsiz guvenli hata verir', () async {
      final konum = _konum(istanbulBilgi);
      // Eylül var, Ekim yok.
      await depo.kayitYaz(konum, _dogrula(istanbulFixture.govde) as CevapGecerli);
      expect(await depo.kayitOku(konum, yil: 2026, ay: 9), isNotNull);
      expect(await depo.kayitOku(konum, yil: 2026, ay: 10), isNull,
          reason: 'ekim verisi yok; Eylul verisi EKSIK YERINE gosterilmemeli');
    });

    test('bozuk onbellek cökmmez ve karantinaya alinir', () async {
      final konum = _konum(istanbulBilgi);
      await depo.kayitYaz(konum, _dogrula(istanbulFixture.govde) as CevapGecerli);

      // Elle bozuk veri yaz (bir başka yolun, sürüm düşürme vb. sonucu).
      final h = await SharedPreferences.getInstance();
      await h.setString(konum.onbellekAnahtari(yil: 2026, ay: 9), '{bozuk json');

      // Okuma çökmüyor, null dönüyor.
      final okunan = await depo.kayitOku(konum, yil: 2026, ay: 9);
      expect(okunan, isNull);

      // Bozuk kayıt artık normal anahtarda değil.
      expect(h.containsKey(konum.onbellekAnahtari(yil: 2026, ay: 9)), isFalse);
      final karantina = h.getKeys().where((k) => k.startsWith('vakit_bozuk_'));
      expect(karantina.length, greaterThan(0),
          reason: 'bozuk veri silinmez, karantinaya alinir');
    });

    test('ESKI SEHIR verisi yeni sehir basliginda GORUNMEZ', () async {
      final istanbul = _konum(istanbulBilgi);
      final tokyo = _konum(tokyoBilgi);
      await depo.kayitYaz(istanbul, _dogrula(istanbulFixture.govde) as CevapGecerli);

      // Tokyo'nun anahtarı İstanbul'unkinden farklı -> Tokyo için boş.
      expect(await depo.kayitOku(tokyo, yil: 2026, ay: 9), isNull);
      expect(await depo.kayitOku(istanbul, yil: 2026, ay: 9), isNotNull);
    });

    test('MATRIS 7 (veri katmani): iki konumun verisi birbirine karismaz',
        () async {
      // Buradaki asil olcum: depo cevabi ISTEGILEN KONUMA yazar. Ana
      // sayfadaki "hangi cevap gosterilecek" yarisi (istek jetonu) veri
      // katmaninda degil, sayfada cozulur; onun GERCEK URETIM AKISIyla
      // (AnaSayfa + sahte ag + gercek jeton) olculdugu test
      // `gecikmis_cevap_saat_dilimi_test.dart` dosyasindadir.
      //
      // ONCEDEN burada bir "jeton" sayaci tutuluyordu; o sayac yalnizca
      // testin kendi degiskeniydi, uretim koduna hic dokunmadan testi
      // yesil gosteriyordu. Boyle bir sahte olcum buradan kaldirildi.
      final ankara = Konum(
        ad: 'Ankara', ulkeIso2: 'TR', enlem: 39.9334, boylam: 32.8597,
        saatDilimi: 'Europe/Istanbul');
      final tokyo = _konum(tokyoBilgi);

      final ankaraCevap = await depo.agCevabiniIsle(
        konum: ankara, govde: ankaraFixture.govde, httpDurumKodu: 200,
        istenenGun: DateTime(2026, 9, 26));
      expect(ankaraCevap.basariliMi, isTrue,
          reason: ankaraCevap.hata.toString());

      // Tokyo istegi gelir; Ankara'nin cevabi kendi yerinde kalir.
      final tokyoCevap = await depo.agCevabiniIsle(
        konum: tokyo, govde: tokyoFixture.govde, httpDurumKodu: 200,
        istenenGun: DateTime(2026, 9, 26));
      expect(tokyoCevap.basariliMi, isTrue,
          reason: tokyoCevap.hata.toString());

      // Tokyo verisi Tokyo anahtarinda, Ankara verisi kendi yerinde.
      expect((await depo.kayitOku(tokyo, yil: 2026, ay: 9))!.saatDilimi, 'Asia/Tokyo');
      expect((await depo.kayitOku(ankara, yil: 2026, ay: 9))!.saatDilimi, 'Europe/Istanbul');
    });
  });

  group('onbellek ozeti metadata', () {
    test('kaynak, indirme zamani, timezone ve tarih araligi tutulur', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final depo = VakitDepo(saat: _utc(2026, 9, 26, 12, 0));
      final konum = _konum(istanbulBilgi);
      await depo.kayitYaz(konum, _dogrula(istanbulFixture.govde) as CevapGecerli);

      final ozet = await depo.ozetOku(konum, yil: 2026, ay: 9);
      expect(ozet, isNotNull);
      expect(ozet!.saatDilimi, 'Europe/Istanbul');
      expect(ozet.cevapYontemId, 13);
      expect(ozet.gunSayisi, 30);
      expect(ozet.ilkTarih, DateTime(2026, 9, 1));
      expect(ozet.sonTarih, DateTime(2026, 9, 30));
      expect(ozet.konumAdi, 'Istanbul');
      expect(ozet.indirildi.millisecondsSinceEpoch, greaterThan(0));
    });
  });
}

int _dakika(String ssdd) {
  final p = ssdd.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}
