import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:namaz_vakitleri/core/diyanet_guncel.dart';
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';
import 'package:namaz_vakitleri/core/plan_yenileme.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:namaz_vakitleri/utils/widget_paketi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

const ny = Konum(
  ad: 'New York',
  ulkeIso2: 'US',
  enlem: 40.7,
  boylam: -74,
  saatDilimi: 'America/New_York',
  yontemId: 2,
  asrYontemi: AsrYontemi.hanafi,
  yuksekEnlemAyaru: YuksekEnlemAyaru.aciTabanli,
);
const times = {
  'fajr': '05:30',
  'sunrise': '06:50',
  'dhuhr': '12:45',
  'asr': '16:00',
  'maghrib': '18:30',
  'isha': '20:00',
};
VakitGunu gun(DateTime d, Konum k) => VakitGunu(
  yil: d.year,
  ay: d.month,
  gun: d.day,
  hicriTarih: '',
  saatler: times,
  saatDilimi: k.saatDilimi,
  cevapYontemId: k.yontemId ?? 13,
);
List<VakitGunu> ayGunleri(int y, int m, Konum k) => [
  for (var i = 1; i <= DateTime(y, m + 1, 0).day; i++)
    gun(DateTime(y, m, i), k),
];
String aylik(int y, int m, Konum k) => jsonEncode({
  'code': 200,
  'status': 'OK',
  'data': [
    for (final g in ayGunleri(y, m, k))
      {
        'date': {
          'gregorian': {
            'date':
                '${g.gun.toString().padLeft(2, '0')}-${m.toString().padLeft(2, '0')}-$y',
            'day': '${g.gun}',
            'month': {'number': m},
            'year': '$y',
          },
          'hijri': {
            'day': '1',
            'month': {'en': 'Test'},
            'year': '1448',
          },
        },
        'meta': {
          'latitude': k.enlem,
          'longitude': k.boylam,
          'timezone': k.saatDilimi,
          'method': {'id': k.yontemId ?? 13},
        },
        'timings': {
          'Fajr': times['fajr'],
          'Sunrise': times['sunrise'],
          'Dhuhr': times['dhuhr'],
          'Asr': times['asr'],
          'Maghrib': times['maghrib'],
          'Isha': times['isha'],
        },
      },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('last hour of a 25-hour DST day still schedules its actual prayer', () {
    final d = VakitGunu(
      yil: 2026,
      ay: 11,
      gun: 1,
      hicriTarih: '',
      saatler: {...times, 'isha': '23:30'},
      saatDilimi: ny.saatDilimi,
      cevapYontemId: 2,
    );
    final s = SabitSaat(DateTime.utc(2026, 11, 2, 4, 15));
    final p = const BildirimPlanlayici(gunSiniri: 30).planla(
      konum: ny,
      sehirSaati: SehirSaati(konum: ny, saat: s),
      gunler: [d],
      erkenUyariDakika: 0,
      gunesDogumuBildirimiAcik: false,
      cevir: (s) => s,
    );
    expect(p.bildirimler.single.vakitAnahtari, 'isha');
    expect(
      p.bildirimler.single.zaman.toUtc(),
      DateTime.utc(2026, 11, 2, 4, 30),
    );
  });
  KayanVakitKaynak kaynak(Saat s, http.Client client) => KayanVakitKaynak(
    saat: s,
    depo: VakitDepo(saat: s),
    diyanet: DiyanetDepo(paketMetni: (p) async => File(p).readAsStringSync()),
    resmiAg: DiyanetGuncelDepo(istemci: client, simdi: s.simdi),
    istemci: client,
  );

  test('Turkey embedded source renews 30 real days without network', () async {
    const k = Konum(
      ad: 'Ankara',
      ulkeIso2: 'TR',
      enlem: 39.9,
      boylam: 32.8,
      saatDilimi: 'Europe/Istanbul',
      diyanetCityId: 9206,
      diyanetParca: 'TR/ankara.txt',
    );
    var network = 0;
    final client = MockClient((_) async {
      network++;
      throw const SocketException('offline');
    });
    final s = SabitSaat(DateTime.utc(2026, 10, 31, 9));
    final d = await kaynak(s, client).oku(k, resmi: true);
    expect(d.kaynak, VakitKaynagi.resmiDiyanet);
    expect(network, 0);
    expect(d.gelecekGunler.length, 30);
    expect(d.gelecekGunler.last.tarih, DateTime(2026, 11, 29));
    final canonical =
        await DiyanetDepo(
          paketMetni: (p) async => File(p).readAsStringSync(),
        ).vakitler(
          cityId: 9206,
          ilDosya: 'TR/ankara.txt',
          tarih: DateTime(2026, 11, 29),
        );
    expect(d.gelecekGunler.last.saatler, canonical.gun!.saatler);
  });

  test(
    'Turkey renewal repairs foreign zone before selecting the civil day',
    () async {
      const k = Konum(
        ad: 'Ankara',
        ulkeIso2: 'TR',
        enlem: 39.9,
        boylam: 32.8,
        saatDilimi: 'Asia/Shanghai',
        diyanetCityId: 9206,
        diyanetParca: 'TR/ankara.txt',
      );
      final client = MockClient(
        (_) async => throw const SocketException('offline'),
      );
      final s = SabitSaat(DateTime.utc(2026, 10, 31, 20));
      final d = await kaynak(s, client).oku(k, resmi: true);
      expect(d.konum.saatDilimi, 'Europe/Istanbul');
      expect(d.bugun!.tarih, DateTime(2026, 10, 31));
      final plan = const BildirimPlanlayici().planla(
        konum: d.konum,
        sehirSaati: SehirSaati(konum: d.konum, saat: s),
        gunler: d.gelecekGunler,
        erkenUyariDakika: 30,
        gunesDogumuBildirimiAcik: false,
        cevir: (a) => a,
      );
      final fajr = plan.bildirimler.firstWhere(
        (b) => b.vakitAnahtari == 'fajr' && b.tur == BildirimTuru.vakit,
      );
      final g = d.gelecekGunler.firstWhere(
        (g) => g.tarih == DateTime(2026, 11, 1),
      );
      expect(
        fajr.zaman.toUtc(),
        SehirSaati(
          konum: d.konum,
          saat: s,
        ).duvarSaati(g.saatler['fajr']!, tarih: g.tarih)!.toUtc(),
      );
    },
  );

  test(
    'international window spans three months and keeps selected calculation settings',
    () async {
      final requests = <Uri>[];
      final client = MockClient((r) async {
        requests.add(r.url);
        expect(r.url.queryParameters['method'], '2');
        expect(r.url.queryParameters['school'], ny.asrYontemi.apiParametresi);
        expect(
          r.url.queryParameters['latitudeAdjustmentMethod'],
          ny.yuksekEnlemAyaru.apiParametresi,
        );
        return http.Response(
          aylik(
            int.parse(r.url.queryParameters['year']!),
            int.parse(r.url.queryParameters['month']!),
            ny,
          ),
          200,
        );
      });
      final d = await kaynak(
        SabitSaat(DateTime.utc(2027, 1, 31, 15)),
        client,
      ).oku(ny, resmi: true);
      expect(d.basariliMi, true);
      expect(d.kaynak, VakitKaynagi.ag);
      expect(d.gelecekGunler.length, 30);
      expect(d.gelecekGunler.last.tarih, DateTime(2027, 3, 1));
      expect(requests.map((r) => r.queryParameters['month']), ['1', '2', '3']);
    },
  );

  test(
    'offline international cache crosses year boundary without inventing dates',
    () async {
      final s = SabitSaat(DateTime.utc(2026, 12, 28, 15));
      final depo = VakitDepo(saat: s);
      for (final d in [DateTime(2026, 12), DateTime(2027, 1)]) {
        await depo.kayitYaz(
          ny,
          CevapGecerli(
            gunler: ayGunleri(d.year, d.month, ny),
            saatDilimi: ny.saatDilimi,
            cevapYontemId: 2,
            cevapEnlem: ny.enlem,
            cevapBoylam: ny.boylam,
          ),
        );
      }
      final client = MockClient(
        (_) async => throw const SocketException('offline'),
      );
      final result = await kaynak(s, client).oku(ny, resmi: false);
      expect(result.basariliMi, true);
      expect(result.kaynak, VakitKaynagi.onbellek);
      expect(result.gelecekGunler.length, 30);
      expect(result.gelecekGunler.last.tarih, DateTime(2027, 1, 26));
    },
  );

  test(
    'invalid network timezone cannot overwrite a valid selected-city cache',
    () async {
      final s = SabitSaat(DateTime.utc(2026, 10, 7, 15));
      await VakitDepo(saat: s).kayitYaz(
        ny,
        CevapGecerli(
          gunler: ayGunleri(2026, 10, ny),
          saatDilimi: ny.saatDilimi,
          cevapYontemId: 2,
          cevapEnlem: ny.enlem,
          cevapBoylam: ny.boylam,
        ),
      );
      final h = await SharedPreferences.getInstance();
      final key = 'vakit_ozet_${ny.onbellekAnahtari(yil: 2026, ay: 10)}';
      final ozet = jsonDecode(h.getString(key)!) as Map<String, dynamic>;
      ozet['indirildi'] = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;
      await h.setString(key, jsonEncode(ozet));
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          aylik(2026, 10, ny).replaceAll(ny.saatDilimi, 'Europe/London'),
          200,
        );
      });
      final d = await kaynak(s, client).oku(ny, resmi: false);
      expect(d.bugun!.saatDilimi, ny.saatDilimi);
      expect(requests, greaterThan(0));
      expect(
        (await VakitDepo(saat: s).kayitOku(ny, yil: 2026, ay: 10))!.saatDilimi,
        ny.saatDilimi,
      );
    },
  );

  test('missing current or intermediate day never bridges a gap', () {
    final today = DateTime(2026, 10, 7);
    expect(
      KayanVakitKaynak.pencere([gun(DateTime(2026, 10, 8), ny)], today),
      isEmpty,
    );
    expect(
      KayanVakitKaynak.pencere([
        gun(today, ny),
        gun(DateTime(2026, 10, 9), ny),
      ], today).length,
      1,
    );
  });

  test('30-day widget and alarms follow New York DST, not device timezone', () {
    final s = SabitSaat(DateTime.utc(2026, 10, 25, 4));
    final days = [
      for (var i = 0; i < 30; i++) gun(DateTime(2026, 10, 25 + i), ny),
    ];
    final p = WidgetPaketi.olustur(
      konum: ny,
      saat: s,
      gunler: days,
      tema: ColorScheme.fromSeed(seedColor: Colors.teal),
      dil: 'eng',
      kaynak: 'Calculated',
      metinler: {},
      gunSiniri: 30,
    );
    final records = p['days'] as List<Map<String, Object>>;
    expect(records.length, 30);
    final dst = records.firstWhere((d) => d['date'] == '2026-11-01');
    expect(
      (dst['end'] as int) - (dst['start'] as int),
      const Duration(hours: 25).inMilliseconds,
    );
    final plan = const BildirimPlanlayici(gunSiniri: 30).planla(
      konum: ny,
      sehirSaati: SehirSaati(konum: ny, saat: s),
      gunler: days,
      erkenUyariDakika: 15,
      gunesDogumuBildirimiAcik: true,
      cevir: (s) => s,
    );
    expect(plan.kapsananGunSayisi, 30);
    expect(plan.bildirimler.length, 330);
    final fajr = plan.bildirimler.firstWhere(
      (b) =>
          b.tarih == DateTime(2026, 11, 1) &&
          b.vakitAnahtari == 'fajr' &&
          b.tur == BildirimTuru.vakit,
    );
    expect(fajr.zaman.toUtc(), DateTime.utc(2026, 11, 1, 10, 30));
  });
}
