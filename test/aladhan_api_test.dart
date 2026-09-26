// Aladhan API entegrasyonunun canlı doğrulaması.
//
// Uygulama artık /v1/calendarByCity (şehir adıyla) DEĞİL, /v1/calendar
// (koordinatla) uç noktasını kullanıyor. Bunun sebebi: calendarByCity dahili
// bir geocoder'a dayanıyor ve 136 bin şehirlik veri setindeki küçük
// şehirlerin çoğunu çözemiyor (HTTP 503). Bu test, koordinat yolunun gerçekten
// çalıştığını ve geocoder'ın çözemediği şehirlerin de vakit ürettiğini gösterir.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

/// Bir şehrin aylık vakitlerini koordinatla çeker (uygulamadakiyle aynı yol).
Future<Map<String, dynamic>> aylikVakitler(Sehir sehir, {int yil = 2026, int ay = 9}) async {
  final url = Uri.https(
    'api.aladhan.com',
    '/v1/calendar',
    sehir.aladhanParametreleri(method: 13, yil: yil, ay: ay),
  );
  final cevap = await http.get(url, headers: const {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 25));
  expect(cevap.statusCode, 200, reason: 'HTTP ${cevap.statusCode}: ${cevap.body}');
  final govde = json.decode(cevap.body);
  expect(govde['code'], 200, reason: 'Aladhan mantıksal hata: ${govde['status']}');
  return govde as Map<String, dynamic>;
}

void main() {
  test('Aladhan parametreleri doğru URL oluşturuyor', () {
    const s = Sehir(ad: 'İstanbul', enlem: 41.0082, boylam: 28.9784);
    final url = Uri.https('api.aladhan.com', '/v1/calendar',
        s.aladhanParametreleri(method: 13, yil: 2026, ay: 9));
    expect(url.toString(),
        'https://api.aladhan.com/v1/calendar?latitude=41.0082&longitude=28.9784&method=13&month=9&year=2026');
  });

  test('canlı API aylık 30 gün vakit döndürüyor', () async {
    const istanbul = Sehir(ad: 'İstanbul', enlem: 41.0082, boylam: 28.9784);
    final veri = await aylikVakitler(istanbul);
    final liste = veri['data'] as List;
    expect(liste.length, 30, reason: 'Eylül 2026 -> 30 gün');

    // Her günün beklenen alanları var mı?
    for (final gun in liste) {
      expect((gun['timings'] as Map).containsKey('Fajr'), isTrue);
      expect((gun['timings'] as Map).containsKey('Isha'), isTrue);
      expect((gun['date'] as Map).containsKey('hijri'), isTrue);
    }
  });

  test('geocoder çözemediği şehirler koordinatla çalışıyor', () async {
    // Bu iki şehir calendarByCity ile sorgulandığında 503 döndürüyordu:
    //   Marker (Norveç)          -> 503 Geocoding is temporarily unavailable
    //   Alvorada do Gurguéia (BR) -> 503
    // Koordinat yolu ikisini de çözüyor.
    const testler = [
      Sehir(ad: 'Marker', enlem: 63.9111, boylam: 11.3556),
      Sehir(ad: 'Alvorada do Gurguéia', enlem: -10.7833, boylam: -45.3833),
    ];

    for (final s in testler) {
      final veri = await aylikVakitler(s);
      final liste = veri['data'] as List;
      expect(liste, isNotEmpty, reason: '${s.ad} için veri gelmedi');
      final fajr = liste[0]['timings']['Fajr'];
      expect(fajr, isNotNull);
      expect(fajr.toString(), matches(RegExp(r'^\d{2}:\d{2}')), reason: '${s.ad} Fajr=$fajr');
      print('  ${s.ad.padRight(24)} Fajr=$fajr  tz=${liste[0]['meta']['timezone']}');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  });

  test('meta.timezone doğru ülke saat dilimini veriyor', () async {
    // Bu, saat dilimi hatasının çözülmesinin temelidir: uygulama alarmları
    // bu değere göre zamanlar.
    const testler = [
      (Sehir(ad: 'Tokyo', enlem: 35.6762, boylam: 139.6503), 'Asia/Tokyo'),
      (Sehir(ad: 'New York', enlem: 40.7128, boylam: -74.0060), 'America/New_York'),
      (Sehir(ad: 'Cairo', enlem: 30.0444, boylam: 31.2357), 'Africa/Cairo'),
      (Sehir(ad: 'Berlin', enlem: 52.5200, boylam: 13.4050), 'Europe/Berlin'),
    ];
    for (final t in testler) {
      final veri = await aylikVakitler(t.$1);
      final tz = (veri['data'] as List)[0]['meta']['timezone'];
      expect(tz, t.$2, reason: '${t.$1.ad} için yanlış saat dilimi: $tz');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  });

  test('dört kıtadan örnek şehirler vakit üretiyor', () async {
    // Kullanıcının istediği dört bölgenin her birinden birer örnek.
    const testler = [
      (Sehir(ad: 'İstanbul', enlem: 41.0082, boylam: 28.9784), 'Europe'),
      (Sehir(ad: 'New York', enlem: 40.7128, boylam: -74.0060), 'Americas'),
      (Sehir(ad: 'Tokyo', enlem: 35.6762, boylam: 139.6503), 'Asia'),
      (Sehir(ad: 'Lagos', enlem: 6.5244, boylam: 3.3792), 'Africa'),
    ];
    for (final t in testler) {
      final veri = await aylikVakitler(t.$1);
      final liste = veri['data'] as List;
      expect(liste.length, 30, reason: '${t.$2}/${t.$1.ad} veri eksik');
      print('  ${t.$2.padRight(10)} ${t.$1.ad.padRight(12)} '
          'Fajr=${liste[0]['timings']['Fajr']}  tz=${liste[0]['meta']['timezone']}');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  });

  test('veri setinden gerçek şehir koordinatları vakit üretiyor', () async {
    // Üretilmiş veri dosyasından okunan koordinatları kullanarak doğrulama.
    // Bu, "veri dosyasındaki koordinatlar gerçekten API'de işe yarıyor mu"
    // sorusunu cevaplar.
    final hepsi = sehirleriDosyadanOku('TR');
    expect(hepsi.length, greaterThan(800), reason: 'TR veri dosyası beklenenden küçük');

    // Türkiye'nin büyük şehirlerinden birkaçı.
    //
    // DİKKAT: veri setinde yazım tutarsız - "Istanbul" ASCII I ile,
    // "İzmir" ise noktalı İ ile yazılmış. Bu yüzden karşılaştırmayı
    // replaceAll ile değil, UlkeVerisi.normalize() ile yapıyoruz; aynı
    // işlevi kullandığımız için arama ile eşleştirme birebir tutarlı.
    const arananlar = {'ankara', 'istanbul', 'izmir', 'antalya', 'bursa'};
    final ornekler = hepsi
        .where((s) => arananlar.contains(UlkeVerisi.normalize(s.ad)))
        .toList();
    expect(ornekler.length, greaterThanOrEqualTo(4),
        reason: 'TR verisinde beklenen şehirler bulunamadı. '
            'Bulunan: ${hepsi.map((s) => s.ad).take(20).toList()}');

    for (final s in ornekler) {
      final veri = await aylikVakitler(s);
      expect((veri['data'] as List), isNotEmpty, reason: '${s.ad} veri gelmedi');
      final ilk = (veri['data'] as List)[0];
      print('  ${s.ad.padRight(10)} (${s.enlem}, ${s.boylam})  '
          'Fajr=${ilk['timings']['Fajr']}  tz=${ilk['meta']['timezone']}');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  });
}

/// Üretilmiş şehir veri dosyasını okur. (rootBundle yerine doğrudan disk:
/// flutter test asset bundle'ı sağlamaz.)
List<Sehir> sehirleriDosyadanOku(String iso2) {
  return File('assets/data/sehirler/$iso2.txt')
      .readAsLinesSync(encoding: utf8)
      .where((s) => s.trim().isNotEmpty)
      .map(Sehir.satirdan)
      .toList();
}
