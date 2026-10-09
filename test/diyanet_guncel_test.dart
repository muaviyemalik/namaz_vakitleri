import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:namaz_vakitleri/core/diyanet_guncel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Yapısal fixture; bu saatler Diyanet doğruluk kanıtı değildir.
String resmiSayfa({int id = 9206, String imsak = '05:20', String ek = ''}) =>
    '''
<link rel="canonical" href="https://namazvakitleri.diyanet.gov.tr/tr-TR/$id/x">
<script>var ilceId = $id;</script><table>
<tr><td>01 Ocak 2028 Cumartesi</td><td>Hicri</td><td>$imsak</td><td>07:00</td>
<td>12:00</td><td>15:00</td><td>18:00</td><td>19:00</td></tr>$ek</table>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tarih = DateTime(2028, 1, 1);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('doğru CityID ve altı geçerli vakit okunur', () {
    final sonuc = DiyanetGuncelDepo.cozumle(resmiSayfa(), 9206, tarih, tarih);
    expect(sonuc!.bugun.saatler['fajr'], '05:20');
    expect(sonuc.bugun.saatDilimi, 'Europe/Istanbul');
  });
  test('başka CityID, bozuk saat, yanlış tarih ve çelişki reddedilir', () {
    for (final sayfa in [
      resmiSayfa(id: 9207),
      resmiSayfa(imsak: '25:00'),
      resmiSayfa(imsak: '00:00'),
      resmiSayfa().replaceAll('01 Ocak', '32 Ocak'),
      resmiSayfa().replaceAll('var ilceId = 9206', 'var ilceId = 9207'),
      resmiSayfa(
        ek:
            '<tr><td>01 Ocak 2028</td><td>Hicri</td><td>05:21</td>'
            '<td>07:00</td><td>12:00</td><td>15:00</td><td>18:00</td><td>19:00</td></tr>',
      ),
    ]) {
      expect(DiyanetGuncelDepo.cozumle(sayfa, 9206, tarih, tarih), isNull);
    }
    expect(
      DiyanetGuncelDepo.cozumle(resmiSayfa(), 9206, DateTime(2029), tarih),
      isNull,
    );
  });
  test(
    'resmî kayıt çevrimdışı okunur, hesaplanmış önbelleğe yazılmaz',
    () async {
      var agAcik = true;
      var simdi = tarih;
      final istemci = MockClient((r) async {
        expect(r.url.host, 'namazvakitleri.diyanet.gov.tr');
        if (r.url.path != '/tr-TR/9206/x') return http.Response('', 503);
        expect(r.url.path, '/tr-TR/9206/x');
        return http.Response(agAcik ? resmiSayfa() : '', agAcik ? 200 : 503);
      });
      final depo = DiyanetGuncelDepo(istemci: istemci, simdi: () => simdi);
      expect((await depo.oku(9206, tarih))!.onbellekten, isFalse);
      agAcik = false;
      simdi = simdi.add(const Duration(hours: 2));
      expect((await depo.oku(9206, tarih))!.onbellekten, isTrue);
      final h = await SharedPreferences.getInstance();
      expect(
        h.getKeys().every((k) => k.startsWith('diyanet_resmi_web_v1_')),
        isTrue,
      );
      expect(await depo.oku(9207, tarih), isNull);
      simdi = simdi.add(const Duration(days: 8));
      expect(
        await depo.oku(9206, tarih),
        isNull,
        reason: 'eski resmi cache kullanılmaz',
      );
    },
  );
  test(
    'ağ geri gelince beş dakika sonra resmî veri otomatik bulunur',
    () async {
      var simdi = tarih;
      var agAcik = false;
      var sayi = 0;
      final depo = DiyanetGuncelDepo(
        simdi: () => simdi,
        istemci: MockClient((_) async {
          sayi++;
          return http.Response(agAcik ? resmiSayfa() : '', agAcik ? 200 : 503);
        }),
      );
      expect(await depo.oku(9206, tarih), isNull);
      agAcik = true;
      expect(await depo.oku(9206, tarih), isNull);
      expect(sayi, 1);
      simdi = simdi.add(const Duration(minutes: 5));
      expect((await depo.oku(9206, tarih))!.bugun.saatler['fajr'], '05:20');
      expect(sayi, 2);
    },
  );
  test(
    'aynı resmî host/CityID yönlendirmesi izlenir, başka host/ID reddedilir',
    () async {
      for (final hedef in [
        '/tr-TR/9206/ankara-namaz-vakitleri',
        'https://example.com/tr-TR/9206/x',
        '/tr-TR/9207/x',
      ]) {
        SharedPreferences.setMockInitialValues({});
        var istek = 0;
        final depo = DiyanetGuncelDepo(
          simdi: () => tarih,
          istemci: MockClient((r) async {
            istek++;
            if (istek == 1)
              return http.Response('', 302, headers: {'location': hedef});
            return http.Response(resmiSayfa(), 200);
          }),
        );
        final sonuc = await depo.oku(9206, tarih);
        if (hedef.contains('ankara-namaz')) {
          expect(sonuc, isNotNull);
          expect(istek, 2);
        } else {
          expect(sonuc, isNull);
          expect(istek, 1);
        }
      }
    },
  );
}
