// test/bildirim_motoru_test.dart
//
// ZORUNLU TEST MATRİSİ — BİLDİRİM MOTORU (Aşama 4)
//
//   15 Exact alarm izni, bildirim izni, reboot, app kill, Doze senaryoları
//      -> buradaki kısıt: plan SAF ve test edilebilir; izin/reboot cihaz
//         davranısıdır ve `tool/` + fiziksel cihazla doğrulanır.
//      -> Bu dosya "kurulacak bildirimlerin DOĞRU olduğunu" sınar.
//
//   14 (kismi) Sadece bu motorun yönettiği kimlikler güncellenir, cancelAll yok.
//
// AĞ KULLANILMAZ. Bildirim eklentisine DOKUNULMAZ: `BildirimPlanlayici.planla()`
// saf bir fonksiyondur ve testte eklentiye ihtiyaç duymaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:namaz_vakitleri/core/saat.dart';
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

/// Test çevirisi: anahtarı aynen döner ama kısaltma için işaretler.
/// Böylece testte hangi metnin hangi anahtardan geldiği görülür.
String _cevir(String k) => '<$k>';

/// Vakit adı çevirisi testi.
String _vakitAdi(String k, int _) => k;

/// Aylık cevaptan doğrulanmış gün listesini alır.
List<VakitGunu> _gunler(Fixture f, DateTime ilkGun) {
  final d = AladhanCevap(const GercekSaat()).dogrula(
    f.govde,
    httpDurumKodu: 200,
    istenenKonum: _konum(f.bilgi),
    yil: f.bilgi.yil,
    ay: f.bilgi.ay,
  );
  expect(d, isA<CevapGecerli>(), reason: 'fixture gecerli olmali');
  final gec = d as CevapGecerli;
  final sirali = [...gec.gunler]..sort((a, b) => a.tarih.compareTo(b.tarih));
  return sirali.where((g) => !g.tarih.isBefore(ilkGun)).toList();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('kimlik karmasi — kararli ve cakismaz', () {
    test('ayni anahtar HER ZAMAN ayni kimligi verir', () {
      final a = bildirimKimligi('namaz_vakitleri|2026-09-26|fajr|vakit');
      final b = bildirimKimligi('namaz_vakitleri|2026-09-26|fajr|vakit');
      expect(a, b, reason: 'deterministik olmali');
    });

    test('farkli anahtar farkli kimlik verir (PRATIK CAKISMA YOK)', () {
      // 21 vakit x 3 tur x 7 gun = 441 anahtar. 31-bit kimlik alaninda
      // 441 anahtarin tamamen ayri olmasi beklenir.
      final kimlikler = <int>{};
      for (var g = 1; g <= 7; g++) {
        final tarih = DateTime(2026, 9, g);
        for (final v in ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
          for (final t in BildirimTuru.values) {
            kimlikler.add(
                bildirimKimligi(kimlikAnahtari(tarih, v, t)));
          }
        }
      }
      expect(kimlikler.length, 7 * 6 * 3,
          reason: '441 anahtarın hepsi farklı kimlik almalı');
    });

    test('kimlikler imzali 32-bit araliginda ve pozitif', () {
      for (var g = 1; g <= 31; g++) {
        final k = bildirimKimligi(
            kimlikAnahtari(DateTime(2026, 9, g), 'isha', BildirimTuru.vakit));
        expect(k, greaterThan(0));
        expect(k, lessThanOrEqualTo(0x7fffffff),
            reason: 'Android bildirim kimligi int32 araliginda olmali');
      }
    });

    test('kimlik ASLA 0 degil ve her zaman int32 araliginda', () {
      // FNV karmasi bos girdide 0 donmez; 0'a dusmesi nadirdir ama
      // `h == 0 ? 1` korumasi vardir. Burada cogu girdi denenir.
      final girdiler = <String>[
        '',
        'a',
        'x' * 500,
        'namaz_vakitleri|2026-09-26|fajr|vakit',
        'namaz_vakitleri|2026-09-27|fajr|vakit',
        'ünïcodé àçentli şehir adı İstanbul',
      ];
      for (final g in girdiler) {
        final k = bildirimKimligi(g);
        expect(k, greaterThan(0), reason: 'kimlik 0 olamaz: "$g"');
        expect(k, lessThanOrEqualTo(0x7fffffff),
            reason: 'int32 araliginda olmali: "$g"');
      }
    });

    test('tarih + vakit + tur UCHUSU kimligi degistirir', () {
      final t = DateTime(2026, 9, 26);
      expect(bildirimKimligi(kimlikAnahtari(t, 'fajr', BildirimTuru.vakit)),
          isNot(bildirimKimligi(kimlikAnahtari(t, 'fajr', BildirimTuru.erkenUyari))));
      expect(bildirimKimligi(kimlikAnahtari(t, 'fajr', BildirimTuru.vakit)),
          isNot(bildirimKimligi(kimlikAnahtari(t, 'isha', BildirimTuru.vakit))));
      expect(bildirimKimligi(kimlikAnahtari(t, 'fajr', BildirimTuru.vakit)),
          isNot(bildirimKimligi(kimlikAnahtari(DateTime(2026, 9, 27), 'fajr', BildirimTuru.vakit))));
    });

    test('1. gun ile 2. gun ayni kimligi ALMAZ (eski hata duzeltildi)', () {
      // Önceden kimlikler 100+sıra idi: 1. ve 2. gün aynı kimliği alıyor,
      // biri diğerinin üstüne yazıyordu.
      final gun1 = bildirimKimligi(
          kimlikAnahtari(DateTime(2026, 9, 26), 'fajr', BildirimTuru.vakit));
      final gun2 = bildirimKimligi(
          kimlikAnahtari(DateTime(2026, 9, 27), 'fajr', BildirimTuru.vakit));
      expect(gun1, isNot(gun2));
    });
  });

  group('planlama — 7+ GUN, YALNIZCA VERI OLAN GUNLER', () {
    test('yeterli veri varsa tam 7 gun planlanir (ay ortasinda)', () {
      // 15 Eylul 03:00 UTC = Istanbul 06:00. 15-21 Eylul verisi var.
      // Önceden YALNIZ bugün planlanıyordu; uygulama ertesi gün açılmazsa
      // bildirimlerin hiç gelmemesi demekti.
      final saat = _utc(2026, 9, 15, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 15));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );

      expect(ozet.kapsananGunSayisi, greaterThanOrEqualTo(7),
          reason: 'en az 7 gun planlanmali');
      // Bugunun kismi vakitleri gecmis olabilir; 6 tam gun x 5 = 30 taban.
      expect(ozet.bildirimler.length, greaterThanOrEqualTo(30));
      expect(ozet.bildirimler.length, lessThanOrEqualTo(35));
      expect(ozet.bildirimler.map((b) => b.tarih).toSet().length, 7);
    });

    test('ay sonunda YALNIZCA VERI OLAN gunler planlanir, UYDURMA YOK', () {
      // 26 Eylul: 26-30 Eylul verisi var, Ekim verisi YOK.
      // 7 gun UYDURULMAZ; 5 gun planlanir. Kullanıcıya 1 Ekim'in imsağı
      // hakkında yanlış bilgi verilmez, sonraki ay önden indirilir.
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      expect(ozet.kapsananGunSayisi, 5, reason: 'Ekim verisi yok');
      expect(ozet.bildirimler.map((b) => b.tarih.day).toSet().toList(),
          [26, 27, 28, 29, 30]);
    });

    test('sonraki ay onden indirildiyse 7+ gun olur', () {
      // Gerçek davranış: 25 Eylül'den sonra sonraki ay önden indirilir.
      // 26 Eylül'da Eylül (5 gün) + Ekim verisi birleştirilir.
      const ekimBilgi = FixtureBilgi(
        ad: 'Istanbul',
        ulke: 'TR',
        enlem: 41.0054,
        boylam: 28.6825,
        saatDilimi: 'Europe/Istanbul',
        yil: 2026,
        ay: 10,
        kaynakTarihi: '2026-10-26',
      );
      final ekim = _gunler(
        Fixture(ekimBilgi,
            aylikCevap(bilgi: ekimBilgi, methodId: 13, sablonSaatler: saatler())),
        DateTime(2026, 10, 1),
      );
      final birlestirilmis = [
        ..._gunler(istanbulFixture, DateTime(2026, 9, 26)),
        ...ekim,
      ];

      final saat = _utc(2026, 9, 26, 3, 0);
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: birlestirilmis,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      expect(ozet.kapsananGunSayisi, 7);
      final gunlerKumesi = ozet.bildirimler.map((b) => b.tarih.day).toSet().toList();
      expect(gunlerKumesi, [26, 27, 28, 29, 30, 1, 2],
          reason: 'ay sinirini gecen 7 gun planlanmali');
    });

    test('planlanan bildirimlerin hepsi GELECEKTE', () {
      final saat = _utc(2026, 9, 26, 12, 0);
      final s = SehirSaati(konum: _konum(istanbulBilgi), saat: saat);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      final simdi = s.simdi()!;
      for (final b in ozet.bildirimler) {
        expect(b.zaman.isAfter(simdi), isTrue,
            reason: '${b.tarih} ${b.vakitAnahtari} gecmise dustu');
      }
    });

    test('ay sonunda yalniz mevcut gunler planlanir, UYDURMA yok', () {
      // 30 Eylul 23:00 UTC = Istanbul 02:00 (1 Ekim). Eylül verisinde
      // 1 Ekim YOK. Plan yalnız 30 Eylül'ü kapsar; 1 Ekim'in imsağı
      // UYDURULMAZ.
      final saat = _utc(2026, 9, 30, 23, 0);
      final s = SehirSaati(konum: _konum(istanbulBilgi), saat: saat);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 30));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      // Istanbul'da 1 Ekim 02:00 -> o gecenin vakitleri gecmisti.
      expect(ozet.bildirimler, isEmpty,
          reason: '1 Ekim verisi yoksa kimse icin bildirim kurulamaz');
    });
  });

  group('zaman dilimi — alarm SEÇILEN ŞEHIRDE kurulur', () {
    test('New York alarmlari New York duvar saatinde', () {
      // Istanbul cihazinda New York secili: alarmlar New York saatinde
      // kurulur. Bu, "uzak sehir alarmlari mutlak zamanda dogru
      // tetiklenir" kuralinin cekirdegidir.
      final saat = _utc(2026, 9, 1, 0, 0); // mutlak an
      final s = SehirSaati(konum: _konum(newYorkBilgi), saat: saat);
      final gunler = _gunler(newYorkFixture, DateTime(2026, 8, 1));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(newYorkBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      for (final b in ozet.bildirimler) {
        expect(b.zaman.timeZoneOffset, const Duration(hours: -4),
            reason: 'New York alarmlari EDT olmali');
        // Vakit saati, duvar saatinde 05:10 gibi okunmali
        // `toString()` saat dilimi ofseti icerdiginden saat
        // dogrudan b.zaman.hour/.minute okunur.
        expect(b.zaman.hour, inInclusiveRange(0, 23));
      }
    });

    test('alarm ZAMANI dogru gunun duvar saatinde kurulur', () {
      // 1 Eylül 2026, New York Fajr 05:10.
      // 15 Ağustos 04:00 UTC = New York 00:00. 15 Ağustos Fajr 05:10.
      final saat = _utc(2026, 8, 15, 4, 0);
      final s = SehirSaati(konum: _konum(newYorkBilgi), saat: saat);
      final gunler = _gunler(newYorkFixture, DateTime(2026, 8, 15));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(newYorkBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      final fajr = ozet.bildirimler.firstWhere(
          (b) => b.tarih == DateTime(2026, 8, 15) && b.vakitAnahtari == 'fajr');
      expect(fajr.zaman.year, 2026);
      expect(fajr.zaman.month, 8);
      expect(fajr.zaman.day, 15);
      expect(fajr.zaman.hour, 5);
      expect(fajr.zaman.minute, 10);
    });
  });

  group('erken uyarı ayri kanal ve ayri tur', () {
    test('erken uyarı vakitten TAM erkenDakika once kurulur', () {
      final saat = _utc(2026, 9, 26, 3, 0);
      final s = SehirSaati(konum: _konum(istanbulBilgi), saat: saat);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 15,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
        erkenUyariMetni: (d, v) => '$d dk once $v',
      );
      final vakitler = ozet.bildirimler
          .where((b) => b.tur == BildirimTuru.vakit)
          .toList();
      final erken = ozet.bildirimler
          .where((b) => b.tur == BildirimTuru.erkenUyari)
          .toList();
      expect(erken, isNotEmpty);
      for (final e in erken) {
        final v = vakitler.firstWhere((b) =>
            b.tarih == e.tarih && b.vakitAnahtari == e.vakitAnahtari);
        expect(v.zaman.difference(e.zaman), const Duration(minutes: 15));
        expect(e.kimlik, isNot(v.kimlik), reason: 'ayri kimlik');
        expect(e.icerik, contains('15 dk once'));
      }
    });

    test('erken uyarı KAPALI iken hicbir erken uyarı planlanmaz', () {
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      for (final dk in [0, 15, 30, 45]) {
        final ozet = const BildirimPlanlayici().planla(
          konum: _konum(istanbulBilgi),
          sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
          gunler: gunler,
          erkenUyariDakika: dk,
          gunesDogumuBildirimiAcik: false,
          cevir: _cevir,
          vakitAdiCevir: _vakitAdi,
        );
        final erken = ozet.bildirimler
            .where((b) => b.tur == BildirimTuru.erkenUyari)
            .length;
        if (dk == 0) {
          expect(erken, 0, reason: 'erken uyarı kapali');
        } else {
          expect(erken, greaterThan(0), reason: 'erken uyarı $dk dk');
        }
      }
    });

    test('gunes dogumu icin erken uyarı KURULMAZ', () {
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: gunler,
        erkenUyariDakika: 15,
        gunesDogumuBildirimiAcik: true,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      final sunriseErken = ozet.bildirimler.where(
          (b) => b.vakitAnahtari == 'sunrise' && b.tur == BildirimTuru.erkenUyari);
      expect(sunriseErken, isEmpty,
          reason: 'gunes dogusu bir namaz vakti degil; erken uyarilmaz');
    });
  });

  group('gunes dogumu AYRI ve KAPALI varsayilan', () {
    test('varsayilan KAPALI: sunrise bildirimi planlanmaz', () {
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      expect(ozet.bildirimler.where((b) => b.tur == BildirimTuru.gunesDogumu),
          isEmpty);
      expect(ozet.bildirimler.where((b) => b.vakitAnahtari == 'sunrise'),
          isEmpty);
    });

    test('ACIK iken sunrise AYRI turlen ve acikca adlandirilir', () {
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: true,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      final sunrise = ozet.bildirimler
          .where((b) => b.tur == BildirimTuru.gunesDogumu)
          .toList();
      expect(sunrise, isNotEmpty);
      // "Vakit Geldi" DEGIL; acikca adlandirilmis bilgi bildirimi.
      for (final b in sunrise) {
        expect(b.baslik, isNot(contains('notif_time_reached')));
        expect(b.baslik, contains('notif_sunrise_title'));
      }
      // Namaz vaktiyle ayni kimligi almaz.
      final vakit = ozet.bildirimler
          .where((b) => b.tur == BildirimTuru.vakit)
          .map((b) => b.kimlik)
          .toSet();
      for (final b in sunrise) {
        expect(vakit.contains(b.kimlik), isFalse);
      }
    });
  });

  group('metinler planlandigi dilde kalir', () {
    test('metinler ceviri cagrisi aninda uretilir', () {
      // Metinler `.tr()` ile plan anında çevrilir; alarm uygulama kapalıyken
      // gösterildiği için bellekteki dil bilinmez.
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));

      String cevirTr(String k) => k == 'notif_time_reached' ? 'Vakit Geldi!' : k;
      String cevirEn(String k) => k == 'notif_time_reached' ? 'Time has come!' : k;

      final s = SehirSaati(konum: _konum(istanbulBilgi), saat: saat);
      final planTr = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: cevirTr,
        vakitAdiCevir: _vakitAdi,
      );
      final planEn = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: s,
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: cevirEn,
        vakitAdiCevir: _vakitAdi,
      );
      expect(planTr.bildirimler.first.baslik, 'Vakit Geldi!');
      expect(planEn.bildirimler.first.baslik, 'Time has come!');
    });
  });

  group('tam zamanli alarm izni KIRILIRSA uyari uretilir', () {
    test('tamZamanli=false ise plan yine kurulur ama uyari verilir', () {
      final saat = _utc(2026, 9, 26, 3, 0);
      final gunler = _gunler(istanbulFixture, DateTime(2026, 9, 26));
      final ozet = const BildirimPlanlayici().planla(
        konum: _konum(istanbulBilgi),
        sehirSaati: SehirSaati(konum: _konum(istanbulBilgi), saat: saat),
        gunler: gunler,
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
        tamZamanli: false,
      );
      expect(ozet.tamZamanli, isFalse);
      expect(ozet.bildirimler, isNotEmpty,
          reason: 'yaklasik alarm da planlanmali; bildirim hic gelmememeli');
    });
  });

  group('saat dilimi cozulemezse HICBIR bildirim kurulmaz', () {
    test('bilinmeyen saat diliminde plan bos doner', () {
      final bozukKonum = Konum(
        ad: 'X',
        ulkeIso2: 'XX',
        enlem: 0,
        boylam: 0,
        saatDilimi: 'Europe/YokBoyleYer',
      );
      final ozet = const BildirimPlanlayici().planla(
        konum: bozukKonum,
        sehirSaati: SehirSaati(konum: bozukKonum, saat: _utc(2026, 9, 26, 12, 0)),
        gunler: _gunler(istanbulFixture, DateTime(2026, 9, 26)),
        erkenUyariDakika: 0,
        gunesDogumuBildirimiAcik: false,
        cevir: _cevir,
        vakitAdiCevir: _vakitAdi,
      );
      expect(ozet.bildirimler, isEmpty,
          reason: 'saat dilimi bilinmeden alarm kurulamaz; cihaz saatine dusulmez');
      expect(ozet.uyari, isNotNull);
    });
  });
}
