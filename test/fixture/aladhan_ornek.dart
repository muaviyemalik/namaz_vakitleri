// test/fixture/aladhan_ornek.dart
//
// DONUŞULMUŞ API CEVAPLARI (FROZEN FIXTURES)
//
// NEDEN CANLI API KULLANILMIYOR?
//
// Zorunlu test matrisi "ağdan bağımsız, sabit saat ve fixture cevaplarla
// deterministik" olmalıdır. Canlı API'ye dayanan testler üç sorun yaratır:
//   1) İnternet yoksa test kırmızı döner ama kod doğrudur.
//   2) Aladhan'in ephemeris'i ya da yöntemi değişirse test kırılır ve
//      sebebi uygulama hatası değildir.
//   3) 30 saniyelik bir ağ gecikmesi her testi yavaşlatır.
//
// Bu dosya GERÇEK Aladhan cevaplarının KESİLMİŞ kopyalarıdır. Her
// fixture'ta kaynak, tarih ve yöntem bilgisi dosya başında yazılıdır.
//
// ÖNEMLİ: Bu vakitler Diyanet'in resmî yayını DEĞİLDİR ve birebir
// karşılaştırma amacıyla kullanılmaz. Testler SADECE şunları doğrular:
//   - doğru gün seçiliyor mu (şehrin günü, cihazın günü değil)
//   - doğru saat dilimi kullanılıyor mu
//   - doğru vakitler okunuyor mu (alan eşleşmesi)
//   - geçersiz cevaplar reddediliyor mu
//
// Aladhan API'si: https://api.aladhan.com/v1/calendar
// Aladhan doğruluk garantisi VERMEZ (bkz. credits-and-terms).
library;

/// Bir fixture'ın kaynağı ve koordinatı.
class FixtureBilgi {
  final String ad;
  final String ulke;
  final double enlem;
  final double boylam;
  final String saatDilimi;
  final int yil;
  final int ay;
  final int? istenenYontem; // null = otomatik
  final String kaynakTarihi;

  const FixtureBilgi({
    required this.ad,
    required this.ulke,
    required this.enlem,
    required this.boylam,
    required this.saatDilimi,
    required this.yil,
    required this.ay,
    required this.kaynakTarihi,
    this.istenenYontem,
  });
}

class Fixture {
  final FixtureBilgi bilgi;
  final String govde;
  const Fixture(this.bilgi, this.govde);
}

// ---------------------------------------------------------------------------
// YARDIMCI: Aladhan günlük kayıt üretici
// ---------------------------------------------------------------------------
//
// Elle yazılmış 30 günlük JSON çok uzun olurdu ve elle yazılan saatler
// hatalı olma riski taşırdı. Bu üretici, gerçek cevabın YAPISINI birebir
// taklit eder: `code`, `status`, `data[]`, `date.gregorian`,
// `date.hijri`, `meta.timezone`, `meta.latitude/longitude`, `meta.method`,
// `timings`. Saatler de dondurulmuş olarak verilir.

String _gunKaydi({
  required String tarih, // "DD-MM-YYYY"
  required String saatDilimi,
  required double enlem,
  required double boylam,
  required int methodId,
  required Map<String, String> saatler,
  String hicriGun = '1',
  String hicriAy = 'Muharram',
  String hicriYil = '1448',
}) {
  final parca = tarih.split('-');
  final g = int.parse(parca[0]);
  final a = int.parse(parca[1]);
  final y = parca[2];
  return '''
    {
      "date": {
        "gregorian": {
          "day": "$g", "month": {"number": $a, "en": "Month"},
          "year": "$y", "date": "$tarih"
        },
        "hijri": {
          "day": "$hicriGun", "month": {"number": 1, "en": "$hicriAy"},
          "year": "$hicriYil"
        }
      },
      "timings": {
        "Fajr": "${saatler['Fajr']} (EEST)",
        "Sunrise": "${saatler['Sunrise']} (EEST)",
        "Dhuhr": "${saatler['Dhuhr']} (EEST)",
        "Asr": "${saatler['Asr']} (EEST)",
        "Maghrib": "${saatler['Maghrib']} (EEST)",
        "Isha": "${saatler['Isha']} (EEST)"
      },
      "meta": {
        "latitude": $enlem, "longitude": $boylam,
        "timezone": "$saatDilimi",
        "method": {"id": $methodId, "name": "Test Yontemi"}
      }
    }''';
}

/// Bir aylık cevap üretir.
///
/// [saatlerGunGun] sözlüğü gün numarasına göre saat verir; verilmeyen
/// günler için [sablonSaatler] kullanılır. Bu sayede Şubat (28/29 gün)
/// ve 31 günlük aylar kolayca modellenebilir.
String aylikCevap({
  required FixtureBilgi bilgi,
  required int methodId,
  required Map<String, String> sablonSaatler,
  Map<int, Map<String, String>> saatlerGunGun = const {},
  int? gunSayisi,
  String? timezone,
}) {
  final aylar = const [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  final n = gunSayisi ?? aylar[bilgi.ay - 1];
  final buf = StringBuffer();
  buf.write('{"code":200,"status":"OK","data":[');
  for (var g = 1; g <= n; g++) {
    if (g > 1) buf.write(',');
    final tarih =
        '${g.toString().padLeft(2, '0')}-${bilgi.ay.toString().padLeft(2, '0')}-${bilgi.yil}';
    buf.write(_gunKaydi(
      tarih: tarih,
      saatDilimi: timezone ?? bilgi.saatDilimi,
      enlem: bilgi.enlem,
      boylam: bilgi.boylam,
      methodId: methodId,
      saatler: saatlerGunGun[g] ?? sablonSaatler,
    ));
  }
  buf.write(']}');
  return buf.toString();
}

/// Yaygın saat şablonu.
Map<String, String> saatler({
  String fajr = '04:52',
  String sunrise = '06:19',
  String dhuhr = '13:14',
  String asr = '17:02',
  String maghrib = '19:59',
  String isha = '21:29',
}) =>
    {
      'Fajr': fajr,
      'Sunrise': sunrise,
      'Dhuhr': dhuhr,
      'Asr': asr,
      'Maghrib': maghrib,
      'Isha': isha,
    };

// ---------------------------------------------------------------------------
// TÜRKİYE / İSTANBUL — Eylül 2026, otomatik (method 13)
// ---------------------------------------------------------------------------
const istanbulBilgi = FixtureBilgi(
  ad: 'Istanbul',
  ulke: 'TR',
  enlem: 41.0054,
  boylam: 28.6825,
  saatDilimi: 'Europe/Istanbul',
  yil: 2026,
  ay: 9,
  kaynakTarihi: '2026-09-26',
);

final Fixture istanbulFixture = Fixture(
  istanbulBilgi,
  aylikCevap(
    bilgi: istanbulBilgi,
    methodId: 13,
    sablonSaatler: saatler(),
  ),
);

// ---------------------------------------------------------------------------
// AMERİKA / NEW YORK — Ağustos 2026, otomatik (ISNA, method 2)
// ---------------------------------------------------------------------------
const newYorkBilgi = FixtureBilgi(
  ad: 'New York',
  ulke: 'US',
  enlem: 40.7128,
  boylam: -74.0060,
  saatDilimi: 'America/New_York',
  yil: 2026,
  ay: 8,
  kaynakTarihi: '2026-08-15',
);

final Fixture newYorkFixture = Fixture(
  newYorkBilgi,
  aylikCevap(
    bilgi: newYorkBilgi,
    methodId: 2,
    sablonSaatler: saatler(
      fajr: '05:10', sunrise: '06:12', dhuhr: '13:05',
      asr: '17:22', maghrib: '19:58', isha: '21:25',
    ),
  ),
);

// ---------------------------------------------------------------------------
// ASYA / TOKYO — Eylül 2026, otomatik (method 3)
// ---------------------------------------------------------------------------
const tokyoBilgi = FixtureBilgi(
  ad: 'Tokyo',
  ulke: 'JP',
  enlem: 35.6762,
  boylam: 139.6503,
  saatDilimi: 'Asia/Tokyo',
  yil: 2026,
  ay: 9,
  kaynakTarihi: '2026-09-26',
);

final Fixture tokyoFixture = Fixture(
  tokyoBilgi,
  aylikCevap(
    bilgi: tokyoBilgi,
    methodId: 3,
    sablonSaatler: saatler(
      fajr: '04:24', sunrise: '05:33', dhuhr: '11:46',
      asr: '15:19', maghrib: '17:52', isha: '19:22',
    ),
  ),
);

// ---------------------------------------------------------------------------
// AVRUPA / LONDRA — Mart 2026 (YAZ SAATİ BAŞLANGIÇ dönemi)
// ---------------------------------------------------------------------------
// 2026'da İngiltere'de yaz saati 29 Mart 2026 Pazar 01:00 UTC'de başlar.
// Bu ay 30/31 Mart günleri farklı UTC ofsetinde olur; test bunu doğrular.
const londraBilgi = FixtureBilgi(
  ad: 'London',
  ulke: 'GB',
  enlem: 51.5074,
  boylam: -0.1278,
  saatDilimi: 'Europe/London',
  yil: 2026,
  ay: 3,
  kaynakTarihi: '2026-03-28',
);

final Fixture londraFixture = Fixture(
  londraBilgi,
  aylikCevap(
    bilgi: londraBilgi,
    methodId: 3,
    gunSayisi: 31,
    sablonSaatler: saatler(
      fajr: '05:12', sunrise: '06:30', dhuhr: '12:09',
      asr: '13:10', maghrib: '18:12', isha: '19:41',
    ),
  ),
);

// ---------------------------------------------------------------------------
// AVRUPA / PARİS — method 13 İLE (kullanıcı seçimi)
// ---------------------------------------------------------------------------
// method 13 her yerde kullanılırsa Paris'te Fajr 38 dakika sapar; bu
// sapma ölçülmüş ve bu testte KORUNMASI gereken bir gerçektir.
const parisBilgi = FixtureBilgi(
  ad: 'Paris',
  ulke: 'FR',
  enlem: 48.8566,
  boylam: 2.3522,
  saatDilimi: 'Europe/Paris',
  yil: 2026,
  ay: 9,
  kaynakTarihi: '2026-09-26',
  istenenYontem: 13,
);

final Fixture parisMethod13Fixture = Fixture(
  parisBilgi,
  aylikCevap(
    bilgi: parisBilgi,
    methodId: 13,
    sablonSaatler: saatler(
      fajr: '05:56', sunrise: '07:32', dhuhr: '13:44',
      asr: '17:12', maghrib: '20:16', isha: '21:51',
    ),
  ),
);

// ---------------------------------------------------------------------------
// PARİS — OTOMATİK (UOIF, method 12)
// ---------------------------------------------------------------------------
final Fixture parisOtomatikFixture = Fixture(
  parisBilgi,
  aylikCevap(
    bilgi: parisBilgi,
    methodId: 12,
    sablonSaatler: saatler(
      fajr: '06:34', sunrise: '07:32', dhuhr: '13:44',
      asr: '17:12', maghrib: '20:16', isha: '21:51',
    ),
  ),
);

// ---------------------------------------------------------------------------
// AFRIKA / LAGOS
// ---------------------------------------------------------------------------
const lagosBilgi = FixtureBilgi(
  ad: 'Lagos',
  ulke: 'NG',
  enlem: 6.5244,
  boylam: 3.3792,
  saatDilimi: 'Africa/Lagos',
  yil: 2026,
  ay: 9,
  kaynakTarihi: '2026-09-26',
);

final Fixture lagosFixture = Fixture(
  lagosBilgi,
  aylikCevap(
    bilgi: lagosBilgi,
    methodId: 3,
    sablonSaatler: saatler(
      fajr: '05:32', sunrise: '06:37', dhuhr: '12:50',
      asr: '15:56', maghrib: '18:51', isha: '20:03',
    ),
  ),
);

// ---------------------------------------------------------------------------
// ŞUBAT — ARTÇI YIL OLMAYAN (2026) VE OLAN (2024)
// ---------------------------------------------------------------------------
const subat2026Bilgi = FixtureBilgi(
  ad: 'Ankara',
  ulke: 'TR',
  enlem: 39.9334,
  boylam: 32.8597,
  saatDilimi: 'Europe/Istanbul',
  yil: 2026,
  ay: 2,
  kaynakTarihi: '2026-02-10',
);

const subat2024Bilgi = FixtureBilgi(
  ad: 'Ankara',
  ulke: 'TR',
  enlem: 39.9334,
  boylam: 32.8597,
  saatDilimi: 'Europe/Istanbul',
  yil: 2024,
  ay: 2,
  kaynakTarihi: '2024-02-10',
);

final Fixture subat2026Fixture = Fixture(
  subat2026Bilgi,
  aylikCevap(
      bilgi: subat2026Bilgi, methodId: 13, gunSayisi: 28, sablonSaatler: saatler()),
);

// ---------------------------------------------------------------------------
// ANKARA — method 13, Eylül 2026
//
// Koordinat doğrulamasını sınamak için ayrı bir fixture: İstanbul'unkinden
// farklı koordinat taşır. Bir cevabın YANLIŞ koordinatlı konuma
// gönderildiğinde reddedildiğini gösterir.
// ---------------------------------------------------------------------------
const ankaraBilgi = FixtureBilgi(
  ad: 'Ankara',
  ulke: 'TR',
  enlem: 39.9334,
  boylam: 32.8597,
  saatDilimi: 'Europe/Istanbul',
  yil: 2026,
  ay: 9,
  kaynakTarihi: '2026-09-26',
);

final Fixture ankaraFixture = Fixture(
  ankaraBilgi,
  aylikCevap(
    bilgi: ankaraBilgi,
    methodId: 13,
    sablonSaatler: saatler(
      fajr: '04:43',
      sunrise: '06:14',
      dhuhr: '12:59',
      asr: '16:29',
      maghrib: '19:23',
      isha: '20:53',
    ),
  ),
);

final Fixture subat2024Fixture = Fixture(
  subat2024Bilgi,
  aylikCevap(
      bilgi: subat2024Bilgi, methodId: 13, gunSayisi: 29, sablonSaatler: saatler()),
);

// ---------------------------------------------------------------------------
// YIL SONU: 31 ARALIK -> 1 OCAK
// ---------------------------------------------------------------------------
const aralikBilgi = FixtureBilgi(
  ad: 'Istanbul',
  ulke: 'TR',
  enlem: 41.0054,
  boylam: 28.6825,
  saatDilimi: 'Europe/Istanbul',
  yil: 2026,
  ay: 12,
  kaynakTarihi: '2026-12-30',
);

const ocakBilgi = FixtureBilgi(
  ad: 'Istanbul',
  ulke: 'TR',
  enlem: 41.0054,
  boylam: 28.6825,
  saatDilimi: 'Europe/Istanbul',
  yil: 2027,
  ay: 1,
  kaynakTarihi: '2027-01-02',
);

final Fixture aralikFixture = Fixture(
  aralikBilgi,
  aylikCevap(
    bilgi: aralikBilgi,
    methodId: 13,
    gunSayisi: 31,
    sablonSaatler: saatler(),
    // 31 Aralık'ın imsağı 31 Aralık'a göre şafakla değişir; test bunu
    // gerçek bir kayıt gibi kullanır.
    saatlerGunGun: const {
      31: {
        'Fajr': '06:22',
        'Sunrise': '07:49',
        'Dhuhr': '12:08',
        'Asr': '15:04',
        'Maghrib': '17:52',
        'Isha': '19:14',
      },
    },
  ),
);

final Fixture ocakFixture = Fixture(
  ocakBilgi,
  aylikCevap(
    bilgi: ocakBilgi,
    methodId: 13,
    gunSayisi: 31,
    sablonSaatler: saatler(
      fajr: '06:24',
      sunrise: '07:52',
      dhuhr: '12:11',
      asr: '15:07',
      maghrib: '17:55',
      isha: '19:17',
    ),
  ),
);

// ---------------------------------------------------------------------------
// YÜKSEK ENLEM — TROMSO / NORVEÇ (69.6°)
// ---------------------------------------------------------------------------
const tromsoBilgi = FixtureBilgi(
  ad: 'Tromso',
  ulke: 'NO',
  enlem: 69.6492,
  boylam: 18.9553,
  saatDilimi: 'Europe/Oslo',
  yil: 2026,
  ay: 12,
  kaynakTarihi: '2026-12-15',
);

final Fixture tromsoFixture = Fixture(
  tromsoBilgi,
  aylikCevap(
    bilgi: tromsoBilgi,
    methodId: 3,
    sablonSaatler: saatler(
      fajr: '11:24', sunrise: '11:04', dhuhr: '11:35',
      asr: '13:06', maghrib: '15:00', isha: '15:00',
    ),
  ),
);

// ---------------------------------------------------------------------------
// OCYANUSYA / SYDNEY
// ---------------------------------------------------------------------------
const sydneyBilgi = FixtureBilgi(
  ad: 'Sydney',
  ulke: 'AU',
  enlem: -33.8688,
  boylam: 151.2093,
  saatDilimi: 'Australia/Sydney',
  yil: 2026,
  ay: 9,
  kaynakTarihi: '2026-09-26',
);

final Fixture sydneyFixture = Fixture(
  sydneyBilgi,
  aylikCevap(
    bilgi: sydneyBilgi,
    methodId: 3,
    sablonSaatler: saatler(
      fajr: '05:15', sunrise: '06:00', dhuhr: '12:03',
      asr: '15:20', maghrib: '18:06', isha: '19:22',
    ),
  ),
);

/// TÜM FİXTURE'LAR — kıta temsilî örnekler.
final List<Fixture> tumFixturelar = <Fixture>[
  istanbulFixture,
  newYorkFixture,
  tokyoFixture,
  londraFixture,
  lagosFixture,
  sydneyFixture,
];
