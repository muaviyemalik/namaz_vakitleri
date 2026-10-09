import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/aladhan_cevap.dart';
import '../core/saat.dart';
import '../data/veri_havuzu.dart';

/// One atomic native snapshot. Dates and UTC instants come from the canonical
/// verified days; native widgets never calculate a second prayer timetable.
class WidgetPaketi {
  static const vakitler = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static Map<String, Object> renkler(ColorScheme c) => {
    'surface': c.surface.toARGB32(),
    'card': c.surfaceContainer.toARGB32(),
    'primary': c.primary.toARGB32(),
    'accent': c.primaryContainer.toARGB32(),
    'onAccent': c.onPrimaryContainer.toARGB32(),
    'text': c.onSurface.toARGB32(),
    'muted': c.onSurfaceVariant.toARGB32(),
    'outline': c.outlineVariant.toARGB32(),
  };

  static Map<String, Object> olustur({
    required Konum? konum,
    required Saat saat,
    required List<VakitGunu> gunler,
    required ColorScheme tema,
    required String dil,
    required String kaynak,
    required Map<String, String> metinler,
    int gunSiniri = 8,
  }) {
    final kayitlar = <Map<String, Object>>[];
    if (konum != null && !SehirSaati(konum: konum, saat: saat).saatDilimiCozulemedi) {
      final sehir = SehirSaati(konum: konum, saat: saat);
      final zone = saat.konumBul(konum.saatDilimi)!;
      final bugun = sehir.bugun()!;
      final ayetler = VeriHavuzu.ayetleriGetir(dil);
      final hadisler = VeriHavuzu.hadisleriGetir(dil);
      final tekil = {for (final g in gunler) g.tarih: g};
      final sirali = tekil.values.toList()..sort((a, b) => a.tarih.compareTo(b.tarih));
      for (final g in sirali) {
        final fark = DateTime.utc(g.yil, g.ay, g.gun).difference(DateTime.utc(bugun.year, bugun.month, bugun.day)).inDays;
        if (fark < 0 || fark >= gunSiniri) continue;
        final vakit = <Map<String, Object>>[];
        for (final ad in vakitler) {
          final metin = g.saatler[ad];
          final an = metin == null ? null : sehir.duvarSaati(metin, tarih: g.tarih);
          if (an == null) break;
          vakit.add({'key': ad, 'label': metinler[ad] ?? ad, 'time': metin!, 'at': an.millisecondsSinceEpoch});
        }
        if (vakit.length != 6) continue;
        final indeks = DateTime.utc(g.yil, g.ay, g.gun).difference(DateTime.utc(g.yil, 1, 1)).inDays;
        final ayet = ayetler[indeks % ayetler.length];
        final hadis = hadisler[indeks % hadisler.length];
        kayitlar.add({
          'date': '${g.yil}-${g.ay.toString().padLeft(2, '0')}-${g.gun.toString().padLeft(2, '0')}',
          'start': tz.TZDateTime(zone, g.yil, g.ay, g.gun).millisecondsSinceEpoch,
          'end': tz.TZDateTime(zone, g.yil, g.ay, g.gun + 1).millisecondsSinceEpoch,
          'prayers': vakit,
          'ayah': ayet['meal'] ?? '', 'ayahSource': ayet['sure'] ?? '',
          'hadith': hadis['hadis'] ?? '', 'hadithSource': hadis['kaynak'] ?? '',
        });
      }
    }
    return {
      'version': 1, 'city': konum?.ad ?? '', 'zone': konum?.saatDilimi ?? '',
      'source': kaynak, 'language': dil, 'colors': renkler(tema),
      'labels': metinler, 'days': kayitlar,
    };
  }
}

class WidgetKoprusu {
  static const _kanal = MethodChannel('namaz_vakitleri/widget');
  String? _son;
  Future<void> yayinla(Map<String, Object> paket) async {
    final json = jsonEncode(paket);
    if (_son == json) return;
    _son = json;
    try { await _kanal.invokeMethod<void>('publish', json); }
    catch (_) { if (_son == json) _son = null; rethrow; }
  }
}
