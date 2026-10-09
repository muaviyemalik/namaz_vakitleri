import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/bildirim_ayarlari.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:namaz_vakitleri/core/ezan_platformu.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'ana_sayfa_bildirim_test.dart' show KontrolluBildirimEklentisi;

class _Native extends EzanPlatformu {
  final Map<int, Map<String, Object>> records = {};
  final List<bool> attempts = [];
  bool denyExact = false;
  @override
  Future<void> planla(Map<String, Object> kayit, {required bool exact}) async {
    attempts.add(exact);
    if (exact && denyExact) throw PlatformException(code: 'exact_denied');
    records[kayit['id']! as int] = kayit;
  }

  @override
  Future<void> iptal(int id) async {
    records.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    bildirimAyarlari.value = const BildirimAyarlari();
  });
  const konum = Konum(
    ad: 'Ankara',
    ulkeIso2: 'TR',
    enlem: 39.93,
    boylam: 32.86,
    saatDilimi: 'Europe/Istanbul',
  );
  const gun = VakitGunu(
    yil: 2026,
    ay: 10,
    gun: 7,
    hicriTarih: '',
    saatDilimi: 'Europe/Istanbul',
    cevapYontemId: 13,
    saatler: {
      'fajr': '05:30',
      'sunrise': '07:00',
      'dhuhr': '12:45',
      'asr': '16:00',
      'maghrib': '18:20',
      'isha': '19:45',
    },
  );
  PlanOzeti plan({
    int dakika = 60,
    BildirimAyarlari a = const BildirimAyarlari(),
  }) => const BildirimPlanlayici().planla(
    konum: konum,
    sehirSaati: SehirSaati(
      konum: konum,
      saat: SabitSaat(DateTime.utc(2026, 10, 7, 0)),
    ),
    gunler: [gun],
    erkenUyariDakika: dakika,
    gunesDogumuBildirimiAcik: false,
    cevir: (k) => k,
    ayarlar: a,
  );

  test('Sessizde açık, DND kapalı; ayarlar yeniden açılışta korunur', () async {
    expect(bildirimAyarlari.value.sessizdeCal, isTrue);
    expect(bildirimAyarlari.value.dndCal, isFalse);
    final a = const BildirimAyarlari()
        .degistir(sessizde: false)
        .degistir(vakit: 'asr', mod: VakitBildirimModu.bildirim);
    await bildirimAyarlariKaydet(a);
    bildirimAyarlari.value = const BildirimAyarlari();
    await bildirimAyarlariYukle();
    expect(bildirimAyarlari.value.sessizdeCal, isFalse);
    expect(bildirimAyarlari.value.modu('asr'), VakitBildirimModu.bildirim);
    expect(bildirimAyarlari.value.modu('fajr'), VakitBildirimModu.ezan);
  });
  test(
    'Beş vakit, güneş hariç, ortak 60 dakika; kapalı vakit yalnız vakit alarmını kaldırır',
    () {
      final p = plan(
        a: const BildirimAyarlari().degistir(
          vakit: 'asr',
          mod: VakitBildirimModu.kapali,
        ),
      );
      expect(p.bildirimler.where((b) => b.tur == BildirimTuru.vakit).length, 4);
      expect(
        p.bildirimler.where((b) => b.tur == BildirimTuru.erkenUyari).length,
        5,
      );
      expect(p.bildirimler.any((b) => b.vakitAnahtari == 'sunrise'), isFalse);
      for (final b in p.bildirimler.where((b) => b.tur == BildirimTuru.vakit)) {
        final reminder = p.bildirimler.singleWhere(
          (r) =>
              r.vakitAnahtari == b.vakitAnahtari &&
              r.tur == BildirimTuru.erkenUyari,
        );
        expect(b.zaman.difference(reminder.zaman).inMinutes, 60);
      }
      expect(plan(dakika: 0).bildirimler.length, 5);
    },
  );
  test(
    'Native geçiş çift alarm bırakmaz; aynı UTC anı/metin/kimlik taşınır, temizlik iki yolu iptal eder',
    () async {
      final native = _Native();
      final plugin = KontrolluBildirimEklentisi();
      final p = plan();
      for (final b in p.bildirimler) {
        plugin.bekleyen[b.kimlik] = b.zaman;
      }
      final motor = BildirimMotoru(
        eklenti: plugin,
        planlayici: const BildirimPlanlayici(),
        sira: PlanSirasi(),
        ezan: native,
      );
      final result = await motor.uygula(p, secimNo: motor.yeniSecim());
      expect(result.bildirimler.length, 10);
      expect(native.records.length, 5);
      expect(plugin.bekleyen.length, 5);
      for (final b in p.bildirimler.where((b) => b.tur == BildirimTuru.vakit)) {
        expect(plugin.bekleyen.containsKey(b.kimlik), isFalse);
        expect(
          native.records[b.kimlik]!['time'],
          b.zaman.millisecondsSinceEpoch,
        );
        expect(native.records[b.kimlik]!['prayer'], b.vakitAnahtari);
      }
      await motor.planiTemizle(secimNo: motor.yeniSecim());
      expect(native.records, isEmpty);
      expect(plugin.bekleyen, isEmpty);
    },
  );
  test(
    'Native exact reddi yaklaşık olarak raporlanır, tam zamanlı diye sunulmaz',
    () async {
      final native = _Native()..denyExact = true;
      final motor = BildirimMotoru(
        eklenti: KontrolluBildirimEklentisi(),
        planlayici: const BildirimPlanlayici(),
        sira: PlanSirasi(),
        ezan: native,
      );
      final result = await motor.uygula(plan(), secimNo: motor.yeniSecim());
      expect(result.tamZamanli, isFalse);
      expect(result.uyari, 'exact_alarm_yok');
      expect(native.attempts.take(2), [true, false]);
      expect(native.records.length, 5);
    },
  );
  test(
    'Beş onaylı ezan ve özgün hatırlatma assetleri; kaynak/lisans durumu dürüst kaydedilir',
    () {
      final manifest =
          jsonDecode(File('assets/audio_sources.json').readAsStringSync())
              as Map;
      final records = manifest['adhan'] as List;
      expect(
        records.map((e) => e['prayer']).toSet(),
        BildirimAyarlari.vakitler.toSet(),
      );
      for (final r in records) {
        expect(
          File('android/app/src/main/res/raw/${r['file']}').lengthSync(),
          greaterThan(100000),
        );
        expect(r['license_verified'], false);
      }
      expect(
        File('android/app/src/main/res/raw/hatirlatici.wav').lengthSync(),
        greaterThan(10000),
      );
    },
  );
}
