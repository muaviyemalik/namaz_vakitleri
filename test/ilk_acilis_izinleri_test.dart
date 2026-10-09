import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:namaz_vakitleri/core/ilk_acilis_izinleri.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late List<String> sira;
  late List<Object> hatalar;
  Future<void> iste({Future<void> Function()? alarm, bool Function()? devam}) =>
      IlkAcilisIzinleri().iste(
        tercihler: prefs,
        bildirim: () async {
          sira.add('bildirim');
        },
        alarm:
            alarm ??
            () async {
              sira.add('alarm');
            },
        konum: () async {
          sira.add('konum');
        },
        devam: devam ?? () => true,
        hataBildir: hatalar.add,
      );
  setUp(() async {
    SharedPreferences.setMockInitialValues({'sehir': 'Ankara'});
    prefs = await SharedPreferences.getInstance();
    sira = [];
    hatalar = [];
  });
  test('istemler sıralıdır ve yeni açılışta tekrar edilmez', () async {
    await iste();
    expect(sira, ['bildirim', 'alarm', 'konum']);
    await iste();
    expect(sira, ['bildirim', 'alarm', 'konum']);
    expect(prefs.getString('sehir'), 'Ankara');
  });
  test('alarm yanıtı beklenirken konum ve eşzamanlı akış açılmaz', () async {
    final bekle = Completer<void>();
    final basladi = Completer<void>();
    final ilk = iste(
      alarm: () async {
        expect(prefs.getBool(IlkAcilisIzinleri.alarmAnahtari), true);
        sira.add('alarm');
        basladi.complete();
        await bekle.future;
      },
    );
    await basladi.future;
    await iste();
    expect(sira, ['bildirim', 'alarm']);
    bekle.complete();
    await ilk;
    expect(sira, ['bildirim', 'alarm', 'konum']);
  });
  test('kesilen akış yalnızca başlanmamış adımlardan devam eder', () async {
    var acik = true;
    await iste(
      alarm: () async {
        sira.add('alarm');
        acik = false;
      },
      devam: () => acik,
    );
    expect(sira, ['bildirim', 'alarm']);
    expect(prefs.getBool(IlkAcilisIzinleri.konumAnahtari), isNull);
    await iste();
    expect(sira, ['bildirim', 'alarm', 'konum']);
  });
  test('izin hatası sonraki adımı engellemez ve yeniden istenmez', () async {
    await iste(
      alarm: () async {
        sira.add('alarm');
        throw StateError('ret');
      },
    );
    expect(hatalar, hasLength(1));
    expect(sira, ['bildirim', 'alarm', 'konum']);
    await iste();
    expect(sira, ['bildirim', 'alarm', 'konum']);
  });
}
