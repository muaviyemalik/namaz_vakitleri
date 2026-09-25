// Aladhan API URL kurgusunun dogrulamasi. Turkce karakterli sehir adlari
// (space, apostrof, slah) ile Uri.https() parametreleri dogru kodluyor mu?
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Uri.https Turkce karakterli sehir adini dogru kodlar', () {
    final url = Uri.https('api.aladhan.com', '/v1/calendarByCity', {
      'city': 'Şanlıurfa',
      'country': 'TR',
      'method': '13',
      'month': '9',
      'year': '2026',
    });
    // URL'de ham Turkce karakter veya bosluk KALMAMALI.
    expect(url.query, contains('city=%C5%9Eanl%C4%B1urfa'));
    expect(url.toString(), isNot(contains(' ')));
    expect(url.scheme, 'https');
    print('URL: $url');
  });

  test('canli Aladhan API yanit veriyor ve beklenen alanlar geliyor', () async {
    final url = Uri.https('api.aladhan.com', '/v1/calendarByCity', {
      'city': 'Şanlıurfa',
      'country': 'TR',
      'method': '13',
      'month': '9',
      'year': '2026',
    });

    final cevap = await http.get(url, headers: const {'Accept': 'application/json'});
    expect(cevap.statusCode, 200);

    final govde = json.decode(cevap.body);
    expect(govde['code'], 200, reason: 'Aladhan mantiksal hata dondurdu');
    expect(govde['data'], isA<List>());

    final aylik = govde['data'] as List;
    expect(aylik.length, 30, reason: 'Eylul 30 gun olmali');

    final gunluk = aylik[25]; // 26. Eylul
    final vakitler = gunluk['timings'] as Map;
    print('26 Eylul SRLIUFRA timings: ${vakitler['Fajr']} | ${vakitler['Isha']}');

    for (final anahtar in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(vakitler.containsKey(anahtar), isTrue, reason: '$anahtar eksik');
    }

    // _saatiTemizle() ile kullanilan bicim dogrulamasi
    final ham = vakitler['Fajr'].toString();
    final parcalar = ham.split(':');
    expect(parcalar.length, greaterThanOrEqualTo(2));
    final temiz = '${parcalar[0].padLeft(2, '0')}:${parcalar[1].substring(0, 2)}';
    expect(temiz, matches(RegExp(r'^\d{2}:\d{2}$')));
    print('Ham: "$ham" -> Temiz: "$temiz"');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
