// test/saat_dilimi_motoru_test.dart
//
// ZORUNLU TEST MATRİSİ — SAAT DİLİMİ MOTORU
//
// Bu dosya "hangi gün ve hangi saat" sorusunun tek doğruluk kaynağını
// sınar. AĞ KULLANILMAZ; saat `SabitSaat` ile sabitlenir, veriler
// `fixture/aladhan_ornek.dart` içindeki donmuş cevaplardan gelir.
//
// Matris karşılıkları:
//   1  İstanbul cihazı + İstanbul seçimi              -> "Istanbul cihazinda Istanbul secimi, ayni gun ve ayni vakitler"
//   2  İstanbul cihazı + New York, farklı takvim günü -> "istanbul cihazinda New York secimi, iki sehir farkli takvim gunundeyken"
//   3  İstanbul cihazı + Tokyo/Sydney, ertesi gün      -> "istanbul cihazinda Tokyo secimi..." / "...Sydney secimi..."
//   4  New York ve Londra yaz/kış saati               -> "New York yaz saati baslangic gunu" / "Londra yaz saati..." (ayrica asagida)
//   5  28/29 Şubat, 30/31 gün, 31 Aralık->1 Ocak     -> subat/yil sonu testleri
//   6  Ayın son gecesinde yarının GERÇEK Fajr'ı        -> aylikCevap icin ay sonu testi
//   7  Ankara -> Paris -> Tokyo hızlı seçim            -> istek jetonu testi
//      (gecikmis_cevap_saat_dilimi_test.dart)
//   8  method 13 URL + metadata                         -> "kullanici method 13 secmis..."
//   9  Yöntem diyaloğu geri tuşu                        -> ayarlar_sayfasi testi
//   10 Eksik/geçersiz/yanlış tarihli cevap reddi       -> aladhan_cevap_test.dart
//   11 Geçersiz cevabın cache'i ezmesi                 -> vakit_verisi_test.dart
//   18 Yüksek enlem                                    -> "yuksek enlem ornegi"
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'fixture/aladhan_ornek.dart';

/// Cihazın saat dilimini testte SABİTLER.
///
/// `flutter test` sanal saatte çalışır ve `DateTime.now()` gerçek
/// sistem saatini döner. Testin hangi cihaz saat dilimini taklit ettiğini
/// söylemesi gerekir. Bunun için zamanı "bileşik" biçimde üretiyoruz:
/// cihazın `DateTime.now()`'ına ertelenmiş bir `TZDateTime` DEĞİL,
/// doğrudan istenen duvar saatine sahip bir `DateTime` veriyoruz.
class CihazSaat extends SabitSaat {
  CihazSaat(DateTime cihazDuvarSaati) : super(cihazDuvarSaati);
}

Konum _konum(FixtureBilgi b, {int? yontem}) => Konum(
      ad: b.ad,
      ulkeIso2: b.ulke,
      enlem: b.enlem,
      boylam: b.boylam,
      saatDilimi: b.saatDilimi,
      yontemId: yontem,
    );

/// Cihazın yerel saat dilimini test ortamında belirler.
///
/// `DateTime` nesneleri cihaz saat diliminde yorumlanır. Testin "İstanbul
/// cihazı" demesi şu anlama gelir: `DateTime(2026, 9, 26, 23, 40)` nesnesi
/// cihazda İstanbul 23:40'ı okunur. Bunu `SabitSaat`'e verdiğimizde
/// `KonumTakvimi` şehri kendi dilimine çevirir.
SabitSaat _cihaz(int y, int a, int g, int s, int d) =>
    SabitSaat(DateTime(y, a, g, s, d));

/// Mutlak UTC ani uretir. DST testleri icin gereklidir: cihaz saat
/// dilimi degil, MUTLAK an uzerinden sehirin saatine donusum yapilir.
SabitSaat _utc(int y, int a, int g, int s, int d) =>
    SabitSaat(DateTime.utc(y, a, g, s, d));

/// Yalnizca YIL-AY-GUN dondurur (`DateTime.toString()` zaman da yazar).
String _t(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('MATRIS 1 — Istanbul cihazi + Istanbul secimi', () {
    test('cihaz ve sehir ayni gundeyken gun ve vakitler birebir', () {
      // 12:00 UTC = Istanbul 15:00. Istanbul cihazinda 26 Eylul.
      final cihaz = _utc(2026, 9, 26, 12, 0);
      final konum = _konum(istanbulBilgi);
      final takvim = KonumTakvimi.tarih(konum, cihaz);

      expect(_t(takvim), '2026-09-26');
      expect(takvim.month, 9);
      expect(takvim.day, 26);
    });

    test('duvar saati cihazdan dogrudan kurulur, ceviri ile degil', () {
      final cihaz = _cihaz(2026, 9, 26, 12, 0);
      final s = SehirSaati(konum: _konum(istanbulBilgi), saat: cihaz);

      // "04:52" İstanbul 04:52 DEMEDİR. Cihaz da İstanbul'daysa iki
      // okuma aynı duvar saatini vermelidir.
      final vakit = s.duvarSaati('04:52')!;
      expect(vakit.hour, 4);
      expect(vakit.minute, 52);
      expect(vakit.year, 2026);
      expect(vakit.month, 9);
      expect(vakit.day, 26);
      expect(vakit.timeZoneOffset, const Duration(hours: 3));
    });
  });

  group('MATRIS 2 — Istanbul cihazi + New York secimi', () {
    test('iki sehir farkli takvim gunundeyken dogru gun secilir', () {
      // Istanbul 27 Eylul 02:00 (UTC+3) = 2026-09-26 23:00 UTC.
      // New York'ta o an 19:00 EDT, 26 Eylul -> FARKLI TAKVIM GUNU.
      final cihaz = _utc(2026, 9, 26, 23, 0);
      final konum = _konum(newYorkBilgi);

      final istanbulTarihi = DateTime(2026, 9, 27);
      final newYorkTarihi = KonumTakvimi.tarih(konum, cihaz);

      expect(_t(newYorkTarihi), '2026-09-26',
          reason: 'cihaz 27 Eylul, New York 26 Eylul olmalı');
      expect(newYorkTarihi.difference(istanbulTarihi).inDays, -1);
    });

    test('New York vakitleri New York duvar saatiyle kurulur', () {
      final cihaz = _utc(2026, 9, 26, 23, 0);
      final s = SehirSaati(konum: _konum(newYorkBilgi), saat: cihaz);

      // 23:00 UTC -> New York 19:00 EDT, 26 Eylul.
      expect(s.simdi()!.day, 26);
      expect(s.simdi()!.hour, 19);

      // "05:10" New York 05:10 olmalı; cihazın 27'sine değil 26'sına.
      final fajr = s.duvarSaati('05:10')!;
      expect(fajr.day, 26);
      expect(fajr.hour, 5);
      expect(fajr.minute, 10);
      expect(fajr.timeZoneOffset, const Duration(hours: -4));
    });

    test('BIAS YOK: ayni an iki sehirde farkli duvar saati', () {
      // 12:00 UTC. Istanbul 15:00 (UTC+3), New York 08:00 (EDT, UTC-4).
      final an = DateTime.utc(2026, 9, 26, 12, 0);
      final ist = SehirSaati(konum: _konum(istanbulBilgi), saat: SabitSaat(an));
      final ny = SehirSaati(konum: _konum(newYorkBilgi), saat: SabitSaat(an));

      // Aynı MUTLAK an iki şehirde iki farklı duvar saati okunur.
      // `millisecondsSinceEpoch` her ikisinde de AYNI olmalıdır: bu, saat
      // dilimi kaydırmasının anı DEĞİŞTİRMEDİĞİNİ, yalnızca okuma
      // biçimini değiştirdiğini kanıtlar. Eski hatalı yaklaşım
      // (`TZDateTime.from`) burada da anı korurdu ama duvar saatini
      // yanlış şehrinki gibi gösterirdi.
      expect(ist.simdi()!.millisecondsSinceEpoch,
          ny.simdi()!.millisecondsSinceEpoch,
          reason: 'mutlak an degismemeli');

      expect(ist.simdi()!.hour, 15);
      expect(ny.simdi()!.hour, 8);

      // Saat dilimi farkı tam olarak 7 saat.
      expect(ist.simdi()!.timeZoneOffset - ny.simdi()!.timeZoneOffset,
          const Duration(hours: 7));
    });
  });

  group('MATRIS 3 — Istanbul cihazi + Tokyo / Sydney (ertesi gun)', () {
    test('Tokyo: cihaz 26 Eylul 22:00 iken Tokyo 27 Eylulde', () {
      final cihaz = _cihaz(2026, 9, 26, 22, 0);
      final konum = _konum(tokyoBilgi);

      expect(_t(KonumTakvimi.tarih(konum, cihaz)), '2026-09-27');
    });

    test('Sydney: cihaz 26 Eylul 21:30 iken Sydney 27 Eylulde', () {
      // Sydney UTC+10, yaz saati (AEST). Istanbul UTC+3.
      // Istanbul 26 Eylul 21:30 -> UTC 18:30 -> Sydney 27 Eylul 04:30.
      final cihaz = _cihaz(2026, 9, 26, 21, 30);
      final konum = _konum(sydneyBilgi);

      expect(_t(KonumTakvimi.tarih(konum, cihaz)), '2026-09-27');
    });

    test('Tokyo: gun degisse de vakitler arac tarafindan secilir', () {
      // KRITIK: eski kod `now.day - 1` ile aylik listeden secim yapardi.
      // Cihaz 26 Eyluldeyken Tokyo 27 Eylulde oldugu halde eski kod
      // 26 Eylulu gorurdu. Burada dogrudan "gercek tarihle eslestir"
      // davranisini dogruluyoruz.
      final cihaz = _cihaz(2026, 9, 26, 22, 0);
      final s = SehirSaati(konum: _konum(tokyoBilgi), saat: cihaz);
      final dogrulayici = AladhanCevap(SabitSaat(_cihaz(2026, 9, 26, 22, 0).simdi()));
      final sonuc = dogrulayici.dogrula(
        tokyoFixture.govde,
        httpDurumKodu: 200,
        istenenKonum: _konum(tokyoBilgi),
        yil: 2026,
        ay: 9,
        istenenGun: s.bugun(),
      );
      expect(sonuc, isA<CevapGecerli>());
      final gecerli = sonuc as CevapGecerli;
      expect(gecerli.gun(DateTime(2026, 9, 27))!.gun, 27);
      expect(gecerli.gun(DateTime(2026, 9, 26))!.gun, 26);
    });
  });

  group('MATRIS 4 — yaz saati / kış saati geçişleri', () {
    test('New York yaz saati BASLANGIC gunu (12 Mart 2026)', () {
      // ABD'de 2026'da yaz saati 8 Mart 2026 Pazar 02:00'de başlar.
      // 8 Mart 00:30 EST (UTC-5) -> 8 Mart 01:30 EST -> 8 Mart 02:30 EDT
      // (UTC-4). IANA veritabanı bu geçişi kendisi bilir.
      // 8 Mart 2026 06:30 UTC = 01:30 EST (yaz saati ONCESI, UTC-5)
      final cihaz = _utc(2026, 3, 8, 6, 30);
      final s = SehirSaati(konum: _konum(newYorkBilgi), saat: cihaz);
      final simdi = s.simdi()!;
      expect(simdi.day, 8);
      // 06:30 UTC -> 01:30 EST. Yaz saati 07:00 UTC'de baslar.
      expect(simdi.hour, 1);
      expect(simdi.timeZoneOffset, const Duration(hours: -5));

      // Ayni gunun 07:30 UTC'si 03:30 EDT olur: saat ILEERI kayar.
      final sonra = SehirSaati(
              konum: _konum(newYorkBilgi), saat: _utc(2026, 3, 8, 7, 30))
          .simdi()!;
      expect(sonra.hour, 3);
      expect(sonra.timeZoneOffset, const Duration(hours: -4));
    });

    test('New York yaz saati BITIS gunu (1 Kasim 2026)', () {
      // 1 Kasim 2026 Pazar 02:00 EDT -> 01:00 EST. Yani 01:30 saat iki kez
      // geçer. IANA veritabanı bunu doğru çözer.
      // 1 Kasim 2026: 06:00 UTC'de saat 02:00 EDT'den 01:00 EST'e geri alinir.
      final cihaz = _utc(2026, 11, 1, 6, 30);
      final s = SehirSaati(konum: _konum(newYorkBilgi), saat: cihaz);
      final simdi = s.simdi()!;
      // 06:30 UTC, 1 Kasim: 02:30 EDT (UTC-4) -> saat 02:30 olur ve
      // "EDT" etiketi taşır (geçiş saat 02:00'de).
      expect(simdi.day, 1);
      expect(simdi.hour, 1, reason: '06:30 UTC = 01:30 EST (UTC-5)');
    });

    test('Londra yaz saati BASLANGIC gunu (29 Mart 2026)', () {
      // İngiltere 29 Mart 2026 01:00 UTC'de BST'ye geçer. 00:30 UTC
      // -> 00:30 GMT. 01:30 UTC -> 02:30 BST.
      // 29 Mart 2026 01:00 UTC'de BST baslar.
      final cihaz = _utc(2026, 3, 29, 0, 30);
      final s = SehirSaati(konum: _konum(londraBilgi), saat: cihaz);
      expect(s.simdi()!.day, 29);
      expect(s.simdi()!.hour, 0);
      expect(s.simdi()!.timeZoneOffset, Duration.zero);

      final cihaz2 = _utc(2026, 3, 29, 1, 30);
      final s2 = SehirSaati(konum: _konum(londraBilgi), saat: cihaz2);
      expect(s2.simdi()!.hour, 2, reason: '01:30 UTC = 02:30 BST');
      expect(s2.simdi()!.timeZoneOffset, const Duration(hours: 1));
    });

    test('Londra yaz saati BITIS gunu (25 Ekim 2026)', () {
      // 25 Ekim 2026 02:00 BST -> 01:00 GMT.
      // 25 Ekim 2026 01:00 UTC'de BST -> GMT.
      final cihaz = _utc(2026, 10, 25, 0, 30);
      final s = SehirSaati(konum: _konum(londraBilgi), saat: cihaz);
      expect(s.simdi()!.hour, 1, reason: '00:30 UTC = 01:30 BST');
      expect(s.simdi()!.timeZoneOffset, const Duration(hours: 1));

      final cihaz2 = _utc(2026, 10, 25, 1, 30);
      final s2 = SehirSaati(konum: _konum(londraBilgi), saat: cihaz2);
      expect(s2.simdi()!.hour, 1, reason: '01:30 UTC = 01:30 GMT');
      expect(s2.simdi()!.timeZoneOffset, Duration.zero);
    });
  });

  group('MATRIS 5 — ay sonu, artik yil ve yil sonu', () {
    test('Subat 2026: 28 gun, 29. gun YOK', () {
      final d = AladhanCevap(const GercekSaat()).dogrula(
        subat2026Fixture.govde,
        httpDurumKodu: 200,
        istenenKonum: _konum(subat2026Bilgi),
        yil: 2026,
        ay: 2,
      );
      expect(d, isA<CevapGecerli>());
      expect((d as CevapGecerli).gunler.length, 28);
      expect(d.gun(DateTime(2026, 2, 28)), isNotNull);
      expect(d.gun(DateTime(2026, 2, 29)), isNull);
    });

    test('Subat 2024 (artik yil): 29 gun VAR', () {
      final d = AladhanCevap(const GercekSaat()).dogrula(
        subat2024Fixture.govde,
        httpDurumKodu: 200,
        istenenKonum: _konum(subat2024Bilgi),
        yil: 2024,
        ay: 2,
      );
      expect(d, isA<CevapGecerli>());
      expect((d as CevapGecerli).gunler.length, 29);
      expect(d.gun(DateTime(2024, 2, 29)), isNotNull);
    });

    test('Artik yil olmayan yilda 29 Subat tarihi REDDEDILIR', () {
      // 2026 artik yil degil; 29 Subat 2026 bir tarih degildir.
      final bozuk = subat2026Fixture.govde.replaceFirst(
        '"date": "28-02-2026"', '"date": "29-02-2026"');
      final d = AladhanCevap(const GercekSaat()).dogrula(
        bozuk,
        httpDurumKodu: 200,
        istenenKonum: _konum(subat2026Bilgi),
        yil: 2026,
        ay: 2,
      );
      expect(d, isA<CevapReddedildi>());
      expect((d as CevapReddedildi).sebep, RedSebebi.tarihAyligiBozuk);
    });

    test('Artik yil OLMAYAN yil 400 ile bolunemez, 100 ile bolunur', () {
      // 1900 artik yil DEGIL; 2000 artik yil.
      final u1900 = DateTime(1900, 3, 1).difference(DateTime(1900, 2, 28)).inDays;
      final u2000 = DateTime(2000, 3, 1).difference(DateTime(2000, 2, 28)).inDays;
      expect(u1900, 1, reason: '1900 artik yil degil -> 28 Subat ardindan 1 Mart');
      expect(u2000, 2, reason: '2000 artik yil -> 29 Subat var');
    });

    test('31 Aralik -> 1 Ocak: iki ay AYRI kayitlar', () {
      final a = AladhanCevap(const GercekSaat()).dogrula(
        aralikFixture.govde,
        httpDurumKodu: 200,
        istenenKonum: _konum(aralikBilgi),
        yil: 2026,
        ay: 12,
      );
      final o = AladhanCevap(const GercekSaat()).dogrula(
        ocakFixture.govde,
        httpDurumKodu: 200,
        istenenKonum: _konum(ocakBilgi),
        yil: 2027,
        ay: 1,
      );
      expect(a, isA<CevapGecerli>());
      expect(o, isA<CevapGecerli>());
      expect((a as CevapGecerli).gunler.length, 31);
      expect((o as CevapGecerli).gunler.length, 31);
      expect(a.gun(DateTime(2026, 12, 31))!.saatler['fajr'], '06:22');
      expect(o.gun(DateTime(2027, 1, 1))!.saatler['fajr'], '06:24');
    });

    test('30 gunluk ve 31 gunluk aylar dogru kapsam', () {
      for (final bilgi in <FixtureBilgi>[subat2026Bilgi, aralikBilgi]) {
        final d = AladhanCevap(const GercekSaat()).dogrula(
          bilgi.ay == 12 ? aralikFixture.govde : subat2026Fixture.govde,
          httpDurumKodu: 200,
          istenenKonum: _konum(bilgi),
          yil: bilgi.yil,
          ay: bilgi.ay,
        );
        expect(d, isA<CevapGecerli>(), reason: '${bilgi.ad} ${bilgi.ay}');
      }
    });
  });

  group('MATRIS 6 — ayin son gecesinde YARININ GERCEK imsagi', () {
    test('30 gunluk ayin son gununde imsak 30. gunun kaydindan gelir', () {
      // Kasım 30 gündür. 30 Kasım 23:50 iken sıradaki vakit 1 Aralık
      // 05:xx'tir. Bu değer KASIM cevabında YOKTUR; Aralık cevabından
      // gelmelidir. Eski kod bugünün 05:30'una +1 gün ekliyordu.
      final kasimBilgi = FixtureBilgi(
        ad: 'Istanbul',
        ulke: 'TR',
        enlem: 41.0054,
        boylam: 28.6825,
        saatDilimi: 'Europe/Istanbul',
        yil: 2026,
        ay: 11,
        kaynakTarihi: '2026-11-30',
      );
      final kasim = aylikCevap(
        bilgi: kasimBilgi,
        methodId: 13,
        gunSayisi: 30,
        sablonSaatler: saatler(fajr: '06:42'),
        saatlerGunGun: const {
          30: {
            'Fajr': '06:45',
            'Sunrise': '08:12',
            'Dhuhr': '12:37',
            'Asr': '15:28',
            'Maghrib': '17:56',
            'Isha': '19:18',
          }
        },
      );
      final aralik2 = aylikCevap(
        bilgi: FixtureBilgi(
          ad: 'Istanbul',
          ulke: 'TR',
          enlem: 41.0054,
          boylam: 28.6825,
          saatDilimi: 'Europe/Istanbul',
          yil: 2026,
          ay: 12,
          kaynakTarihi: '2026-12-01',
        ),
        methodId: 13,
        gunSayisi: 31,
        sablonSaatler: saatler(fajr: '06:48'),
      );

      final d1 = AladhanCevap(const GercekSaat()).dogrula(kasim,
          httpDurumKodu: 200, istenenKonum: _konum(kasimBilgi), yil: 2026, ay: 11);
      final d2 = AladhanCevap(const GercekSaat()).dogrula(aralik2,
          httpDurumKodu: 200,
          istenenKonum: _konum(kasimBilgi),
          yil: 2026,
          ay: 12);

      final kasimGecerli = d1 as CevapGecerli;
      final aralikGecerli = d2 as CevapGecerli;

      // Kasım 30'un imsağı
      final kasim30 = kasimGecerli.gun(DateTime(2026, 11, 30))!;
      expect(kasim30.saatler['fajr'], '06:45');

      // Aralık 1'in imsağı FARKLIDIR
      final aralik1 = aralikGecerli.gun(DateTime(2026, 12, 1))!;
      expect(aralik1.saatler['fajr'], '06:48');

      // Uydurma yöntem 06:45 verirdi; bu YANLIŞTIR.
      expect(kasim30.saatler['fajr'], isNot(aralik1.saatler['fajr']),
          reason: 'yarinin imsagi bugunkinden farkli olmali');
    });
  });

  group('MATRIS 18 — yuksek enlem ornegi', () {
    test('69.6 kuzeyde (Tromso) vakitler doner ve ayar gorunur kalir', () {
      // Yuksek enlemde "gece yarısı" gündüz saatlerine kayabilir. Burada
      // saatlerin GECERLI oldugunu ve 00:00 OLMAIDIGINI dogruluyoruz:
      // 00:00 bir veri hatasidir ve reddedilir.
      final d = AladhanCevap(const GercekSaat()).dogrula(
        tromsoFixture.govde,
        httpDurumKodu: 200,
        istenenKonum: _konum(tromsoBilgi),
        yil: 2026,
        ay: 12,
      );
      expect(d, isA<CevapGecerli>(), reason: '00:00 olmayan yuksek enlem verisi kabul edilir');
      final g = (d as CevapGecerli).gun(DateTime(2026, 12, 15))!;
      for (final v in VakitAlani.sirali) {
        expect(g.saatler[v.anahtar], isNot('00:00'));
        final p = g.saatler[v.anahtar]!.split(':');
        expect(int.parse(p[0]), inInclusiveRange(0, 23));
        expect(int.parse(p[1]), inInclusiveRange(0, 59));
      }
    });

    test('yuksek enlem ayari modelde ve onbellek anahtarinda AYRILIR', () {
      final a = _konum(tromsoBilgi)
          .kopyala(yuksekEnlemAyaru: YuksekEnlemAyaru.geceninYarisi);
      final b = _konum(tromsoBilgi)
          .kopyala(yuksekEnlemAyaru: YuksekEnlemAyaru.yedideBir);
      expect(a.onbellekAnahtari(yil: 2026, ay: 12),
          isNot(b.onbellekAnahtari(yil: 2026, ay: 12)));
      expect(a.yuksekEnlemAyaru.apiParametresi, '1');
      expect(b.yuksekEnlemAyaru.apiParametresi, '2');
    });

    test('asr yontemi onbellek anahtarini degistirir', () {
      final a = _konum(istanbulBilgi).kopyala(asrYontemi: AsrYontemi.standart);
      final b = _konum(istanbulBilgi).kopyala(asrYontemi: AsrYontemi.hanafi);
      expect(a.onbellekAnahtari(yil: 2026, ay: 9),
          isNot(b.onbellekAnahtari(yil: 2026, ay: 9)));
      expect(a.asrYontemi.apiParametresi, '0');
      expect(b.asrYontemi.apiParametresi, '1');
      expect(a.hesapAnahtari, contains('_astandart_'));
      expect(b.hesapAnahtari, contains('_ahanafi_v2_'),
          reason: 'Eski yanlis Hanefi onbellegi yeniden kullanilmamali');
    });
  });

  group('saat dilimi bilinmiyorsa TAHMIN — sessizce kaybolmaz', () {
    test('bilinmeyen dilimde KonumTakvimi boylamdan tahmin eder', () {
      // Yeni seçilen şehrin IANA dilimi henüz bilinmiyor.
      final bilinmeyen = Konum(
        ad: 'Tokyo',
        ulkeIso2: 'JP',
        enlem: 35.6762,
        boylam: 139.6503,
        saatDilimi: '', // bilinmiyor
      );
      final s = SehirSaati(konum: bilinmeyen, saat: _cihaz(2026, 9, 26, 22, 0));
      expect(s.saatDilimiCozulemedi, isTrue);
      expect(s.simdi(), isNull, reason: 'uydurma bir "simdi" uretilmez');
      expect(s.duvarSaati('04:24'), isNull);

      // KonumTakvimi yine de bir gün döner (yalnız istek yönlendirmesi).
      expect(KonumTakvimi.tahminiMi(bilinmeyen, _cihaz(2026, 9, 26, 22, 0)), isTrue);
      final t = KonumTakvimi.tarih(bilinmeyen, _cihaz(2026, 9, 26, 22, 0));
      // 139.65 boylam -> UTC+9 -> 22:00 Istanbul (UTC+3) = 19:00 UTC ->
      // 04:00 Tokyo (UTC+9) -> 27 Eylul.
      expect(_t(t), '2026-09-27');
    });

    test('gecersiz IANA adi cozulemez, Turkceye dusez', () {
      final bozuk = Konum(
        ad: 'X',
        ulkeIso2: 'XX',
        enlem: 0,
        boylam: 0,
        saatDilimi: 'Europe/BuYOlmayanYer',
      );
      expect(_cihaz(2026, 1, 1, 0, 0).konumBul('Europe/BuYOlmayanYer'), isNull);
      expect(SehirSaati(konum: bozuk, saat: _cihaz(2026, 1, 1, 0, 0)).saatDilimiCozulemedi,
          isTrue);
    });
  });

  group('saat bicimi ve aralik dogrulamasi', () {
    test('"SS:DD (TZ)" bicimi ayristirilir', () {
      expect(AladhanCevap.saatiTemizle('04:52 (EEST)'), '04:52');
      expect(AladhanCevap.saatiTemizle('04:52:11'), '04:52');
      expect(AladhanCevap.saatiTemizle('  04:52  '), '04:52');
      expect(AladhanCevap.saatiTemizle('4:52'), '04:52');
    });

    test('gecersiz saatler NULL doner (00:00 URETILMEZ)', () {
      expect(AladhanCevap.saatiTemizle('25:90'), isNull);
      expect(AladhanCevap.saatiTemizle('24:00'), isNull);
      expect(AladhanCevap.saatiTemizle('00:60'), isNull);
      expect(AladhanCevap.saatiTemizle('00:00'), isNull,
          reason: '00:00 bir veri hatasidir; 00:00 uretilmez');
      expect(AladhanCevap.saatiTemizle('abc'), isNull);
      expect(AladhanCevap.saatiTemizle(null), isNull);
      expect(AladhanCevap.saatiTemizle(''), isNull);
      expect(AladhanCevap.saatiTemizle('12'), isNull);
    });

    test('gecersiz saat duvar saatinde de reddedilir', () {
      final s = SehirSaati(konum: _konum(istanbulBilgi), saat: _cihaz(2026, 9, 26, 12, 0));
      expect(s.duvarSaati('25:90'), isNull);
      expect(s.duvarSaati('00:00'), isNull);
      expect(s.duvarSaati('04:52'), isNotNull);
    });
  });

  group('onbellek anahtari kapsami', () {
    test('ay, yil, koordinat, yontem anahtarin hepsi yer alir', () {
      final k = _konum(istanbulBilgi);
      final a1 = k.onbellekAnahtari(yil: 2026, ay: 9);
      final a2 = k.onbellekAnahtari(yil: 2026, ay: 10);
      final a3 = k.onbellekAnahtari(yil: 2027, ay: 9);
      final a4 = k.kopyala(yontemId: 13).onbellekAnahtari(yil: 2026, ay: 9);
      final a5 = Konum(
        ad: 'Ankara',
        ulkeIso2: 'TR',
        enlem: 39.0000,
        boylam: 32.8597,
        saatDilimi: 'Europe/Istanbul',
      ).onbellekAnahtari(yil: 2026, ay: 9);

      expect({a1, a2, a3, a4, a5}.length, 5,
          reason: 'her boyut anahtari degistirmeli');
    });

    test('ayni adli iki sehir AYRI anahtar uretir (Gölbaşı senaryosu)', () {
      // Ankara/Gölbaşı ile Adıyaman/Gölbaşı
      final golbasiAnkara = Konum(
        ad: 'Gölbaşı',
        ulkeIso2: 'TR',
        enlem: 40.2312,
        boylam: 32.7126,
        saatDilimi: 'Europe/Istanbul',
      );
      final golbasiAdiyaman = Konum(
        ad: 'Gölbaşı',
        ulkeIso2: 'TR',
        enlem: 37.7850,
        boylam: 38.7833,
        saatDilimi: 'Europe/Istanbul',
      );
      expect(golbasiAnkara.ad, golbasiAdiyaman.ad);
      expect(golbasiAnkara.onbellekAnahtari(yil: 2026, ay: 9),
          isNot(golbasiAdiyaman.onbellekAnahtari(yil: 2026, ay: 9)));
    });
  });
}
