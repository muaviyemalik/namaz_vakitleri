import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/utils/widget_paketi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);
  const konum = Konum(ad: 'Ankara', ulkeIso2: 'TR', enlem: 39.9, boylam: 32.8, saatDilimi: 'Europe/Istanbul');
  VakitGunu gun(int day, {String zone = 'Europe/Istanbul'}) => VakitGunu(
    yil: 2026, ay: 10, gun: day, hicriTarih: '', saatDilimi: zone, cevapYontemId: 13,
    saatler: {'fajr': day == 7 ? '05:30' : '05:31', 'sunrise': '06:50', 'dhuhr': '12:45', 'asr': '16:00', 'maghrib': '18:30', 'isha': '20:00'},
  );
  Map<String, Object> paket({Color seed = Colors.teal, Brightness mode = Brightness.light, List<VakitGunu>? days}) => WidgetPaketi.olustur(
    konum: konum, saat: SabitSaat(DateTime.utc(2026, 10, 7, 20, 59)),
    gunler: days ?? [gun(8), gun(7), gun(7)], tema: ColorScheme.fromSeed(seedColor: seed, brightness: mode),
    dil: 'tur', kaynak: 'Diyanet', metinler: {'fajr': 'İmsak'},
  );
  test('widget timeline keeps actual tomorrow, unique days and city UTC', () {
    final p = paket();
    final days = p['days'] as List<Map<String, Object>>;
    expect(days.length, 2);
    final today = days.first, tomorrow = days.last;
    final times = tomorrow['prayers'] as List<Map<String, Object>>;
    expect(times.first['time'], '05:31');
    expect(times.first['label'], 'İmsak');
    expect(times.first['at'], DateTime.utc(2026, 10, 8, 2, 31).millisecondsSinceEpoch);
    expect(today['end'], tomorrow['start']);
    expect(days.first['ayah'], isNotEmpty);
  });
  test('theme mode and selected seed produce same app color scheme', () {
    final light = paket()['colors'] as Map;
    final dark = paket(mode: Brightness.dark, seed: Colors.purple)['colors'] as Map;
    final expected = ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark);
    expect(dark['surface'], expected.surface.toARGB32());
    expect(dark['primary'], expected.primary.toARGB32());
    expect(dark['surface'], isNot(light['surface']));
  });
  test('DST day boundary is calendar based, not a 24 hour guess', () {
    final ny = konum.kopyala(saatDilimi: 'America/New_York');
    final g = VakitGunu(yil: 2026, ay: 11, gun: 1, hicriTarih: '', saatDilimi: ny.saatDilimi, cevapYontemId: 2, saatler: gun(7).saatler);
    final p = WidgetPaketi.olustur(konum: ny, saat: SabitSaat(DateTime.utc(2026,11,1,15)), gunler: [g], tema: ColorScheme.fromSeed(seedColor: Colors.teal), dil: 'eng', kaynak: 'Calculated', metinler: {});
    final d = (p['days'] as List).single as Map;
    expect((d['end'] as int) - (d['start'] as int), const Duration(hours:25).inMilliseconds);
    expect(tz.TZDateTime.fromMillisecondsSinceEpoch(tz.getLocation(ny.saatDilimi), d['start'] as int).hour,0);
  });
  test('missing day stays missing; a source failure clears old timeline', () {
    expect(paket(days: [])['days'], isEmpty);
    final p = paket(days: [gun(9)]);
    expect((p['days'] as List).length,1);
    expect(((p['days'] as List).first as Map)['date'], '2026-10-09');
  });
  test('bridge writes one atomic snapshot only when changed, retries failure', () async {
    final calls = <String>[];
    var fail = true;
    const channel = MethodChannel('namaz_vakitleri/widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call) async {
      calls.add(call.arguments as String);
      if (fail) { fail=false; throw PlatformException(code:'disk'); }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
    final bridge = WidgetKoprusu();
    await expectLater(bridge.yayinla(paket()), throwsA(isA<PlatformException>()));
    await bridge.yayinla(paket());
    await bridge.yayinla(paket());
    expect(calls.length,2);
    await bridge.yayinla(paket(seed:Colors.orange));
    expect(calls.length,3);
    expect(jsonDecode(calls.last)['city'],'Ankara');
  });
}
