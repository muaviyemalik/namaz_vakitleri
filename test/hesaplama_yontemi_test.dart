// Hesaplama duzeltmesinin dogrulugunu olcer.
//
// ONCE: method=13 (Turkiye/Diyanet) her ulkede sabit kullaniliyordu.
// SONRA: method parametresi gonderilmiyor; Aladhan ulkeye gore dogru
//        varsayilani seciyor. Kullanici Ayarlar'dan degistirebiliyor.
//
// Bu test, her ulke icin varsayilan secimin ulkenin resmi yontemiyle
// eslesip eslesmedigini ve method=13'e gore farkin ne kadar azaldigini
// gosterir.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

Future<Map<String, dynamic>?> gunVerisi(
  double lat,
  double lon, {
  int? method,
}) async {
  final p = Sehir(ad: '', enlem: lat, boylam: lon)
      .aladhanParametreleri(yil: 2026, ay: 9, method: method);
  final r = await http
      .get(Uri.https('api.aladhan.com', '/v1/calendar', p))
      .timeout(const Duration(seconds: 25));
  if (r.statusCode != 200) return null;
  final g = json.decode(r.body);
  if (g['code'] != 200) return null;
  return (g['data'] as List)[25] as Map<String, dynamic>;
}

String k(dynamic v) => v.toString().split(' ').first;

int _dk(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int fark(String a, String b) {
  var x = _dk(b) - _dk(a);
  if (x > 720) x -= 1440;
  if (x < -720) x += 1440;
  return x;
}

/// Sehir, ISO2, ulkenin resmi yontemi (referans), o yontemin id'si
class Ornek {
  final String sehir;
  final String iso;
  final String beklenenYontemAdi;
  final int beklenenId;
  final double lat;
  final double lon;
  const Ornek(this.sehir, this.iso, this.beklenenYontemAdi, this.beklenenId,
      this.lat, this.lon);
}

void main() {
  // method gonderilmediginde Aladhan'in ulkeye gore sectigi resmi yontemler.
  // Bunlar ulkenin kamu/mesleki kurumunun belirledigi yontemlerdir.
  const ornekler = [
    Ornek('Istanbul', 'TR', 'Diyanet', 13, 41.0082, 28.9784),
    Ornek('New York', 'US', 'ISNA', 2, 40.7128, -74.0060),
    Ornek('Kahire', 'EG', 'Egyptian', 5, 30.0444, 31.2357),
    Ornek('Riyad', 'SA', 'Umm al-Qura', 4, 24.7136, 46.6753),
    Ornek('Jakarta', 'ID', 'KEMENAG', 20, -6.2088, 106.8456),
    Ornek('Kuala Lumpur', 'MY', 'JAKIM', 17, 3.1390, 101.6869),
    Ornek('Tunus', 'TN', 'Tunisia', 18, 36.8065, 10.1815),
    Ornek('Cezayir', 'DZ', 'Algeria', 19, 36.7538, 3.0588),
    Ornek('Paris', 'FR', 'UOIF', 12, 48.8566, 2.3522),
    Ornek('Londra', 'GB', 'MWL', 3, 51.5074, -0.1278),
    Ornek('Islamabad', 'PK', 'Karachi', 1, 33.6844, 73.0479),
    Ornek('Tahran', 'IR', 'Tehran', 7, 35.6892, 51.3890),
  ];

  test('method parametresi gönderilmezse Aladhan ülkeye göre '
      'doğru yöntemi seçiyor', () async {
    var eslesen = 0;
    final sapmali = <String>[];

    for (final o in ornekler) {
      final v = await gunVerisi(o.lat, o.lon);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (v == null) {
        fail('${o.sehir} verisi alınamadı');
      }
      final secilenId = (v['meta']['method'] as Map)['id'] as int;
      if (secilenId == o.beklenenId) {
        eslesen++;
        print('  OK  ${o.sehir.padRight(14)} ${o.iso}  m$secilenId  '
            'beklenen: ${o.beklenenYontemAdi}');
      } else {
        sapmali.add('${o.sehir} (${o.iso}): m$secilenId, beklenen '
            'm${o.beklenenId} ${o.beklenenYontemAdi}');
        print('  XX  ${o.sehir.padRight(14)} ${o.iso}  m$secilenId  '
            'beklenen: m${o.beklenenId} ${o.beklenenYontemAdi}');
      }
    }

    print('');
    print('  Eşleşen: $eslesen / ${ornekler.length}');
    expect(eslesen, greaterThanOrEqualTo(10),
        reason: 'Beklenenden az ülke doğru yöntemi seçti. Sapmalı: $sapmali');
  });

  test('method=13 sabitinin yarattığı sapma otomatik modda gider', () async {
    // method=13 her yerde kullanıldığında Paris'te Fajr 38 dakika sapıyordu.
    // Otomatik modda bu sapma sıfırlanmalı.
    final oto = await gunVerisi(48.8566, 2.3522);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final parisDogru = await gunVerisi(48.8566, 2.3522, method: 12); // UOIF
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final m13 = await gunVerisi(48.8566, 2.3522, method: 13);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(oto, isNotNull);
    expect(parisDogru, isNotNull);
    expect(m13, isNotNull);

    final otoFajr = k(oto!['timings']['Fajr']);
    final dogruFajr = k(parisDogru!['timings']['Fajr']);
    final m13Fajr = k(m13!['timings']['Fajr']);

    final otoSapma = fark(dogruFajr, otoFajr);
    final m13Sapma = fark(dogruFajr, m13Fajr);

    print('  Paris Fajr  otomatik=$otoFajr  doğru(UOIF)=$dogruFajr  '
        'm13=$m13Fajr');
    print('  Otomatik sapma: $otoSapma dk | method=13 sapması: $m13Sapma dk');

    expect(otoSapma, 0, reason: 'Otomatik mod Paris için doğru yöntemi seçmeli');
    expect(m13Sapma.abs(), greaterThan(10),
        reason: 'method=13ün bu şehirde belirgin sapması olduğu doğrulanmalı');
  });

  test('kullanıcı yöntem seçince o yöntem kullanılıyor', () async {
    // Ayarlar'dan MWL seçen bir kullanıcı için istek m3 göndermeli.
    const s = Sehir(ad: 'Londra', enlem: 51.5074, boylam: -0.1278);

    final oto = s.aladhanParametreleri(yil: 2026, ay: 9);
    expect(oto.containsKey('method'), isFalse,
        reason: 'Otomatik modda method gönderilmemeli');

    final mwl = s.aladhanParametreleri(yil: 2026, ay: 9, method: 3);
    expect(mwl['method'], '3');

    final diy = s.aladhanParametreleri(yil: 2026, ay: 9, method: 13);
    expect(diy['method'], '13');
    expect(diy['latitude'], s.enlem.toStringAsFixed(4));
    expect(diy['longitude'], s.boylam.toStringAsFixed(4));
  });

  test('yöntem değişince vakitler gerçekten değişiyor', () async {
    // Bu, "Fajr/İşâ saatleri yönteme göre kayıyor" iddiasının kanıtı.
    final mwl = await gunVerisi(41.0082, 28.9784, method: 3);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final uoif = await gunVerisi(41.0082, 28.9784, method: 12);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(mwl, isNotNull);
    expect(uoif, isNotNull);
    final dIsha = fark(k(mwl!['timings']['Isha']), k(uoif!['timings']['Isha']));
    print('  İstanbul İşâ  MWL=${k(mwl['timings']['Isha'])}  '
        'UOIF=${k(uoif['timings']['Isha'])}  fark=$dIsha dk');
    expect(dIsha.abs(), greaterThan(2),
        reason: 'Farklı yöntemler İşâ saatini değiştirmeli');
  });
}
