import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ezan_platformu.dart';

enum VakitBildirimModu { ezan, bildirim, kapali }

class BildirimAyarlari {
  const BildirimAyarlari({
    this.sessizdeCal = true,
    this.dndCal = false,
    this.modlar = const {},
  });
  final bool sessizdeCal;
  final bool dndCal;
  final Map<String, VakitBildirimModu> modlar;
  static const vakitler = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  VakitBildirimModu modu(String vakit) =>
      modlar[vakit] ?? VakitBildirimModu.ezan;
  BildirimAyarlari degistir({
    bool? sessizde,
    bool? dnd,
    String? vakit,
    VakitBildirimModu? mod,
  }) => BildirimAyarlari(
    sessizdeCal: sessizde ?? sessizdeCal,
    dndCal: dnd ?? dndCal,
    modlar: {...modlar, if (vakit != null && mod != null) vakit: mod},
  );
  Map<String, Object> toMap() => {
    'silent': sessizdeCal,
    'dnd': dndCal,
    'modes': {for (final v in vakitler) v: modu(v).name},
  };
  static BildirimAyarlari oku(Map<String, dynamic> m) {
    final modes = m['modes'];
    return BildirimAyarlari(
      sessizdeCal: m['silent'] != false,
      dndCal: m['dnd'] == true,
      modlar: {
        for (final v in vakitler)
          v: VakitBildirimModu.values.firstWhere(
            (e) => e.name == (modes is Map ? modes[v] : null),
            orElse: () => VakitBildirimModu.ezan,
          ),
      },
    );
  }
}

final bildirimAyarlari = ValueNotifier(const BildirimAyarlari());
const ezanPlatformu = EzanPlatformu();
const bildirimAyarAnahtari = 'bildirim_ayarlari_v1';
Future<void> bildirimAyarlariYukle() async {
  final h = await SharedPreferences.getInstance();
  try {
    final kayit = h.getString(bildirimAyarAnahtari);
    bildirimAyarlari.value = kayit == null
        ? const BildirimAyarlari()
        : BildirimAyarlari.oku(jsonDecode(kayit) as Map<String, dynamic>);
  } catch (_) {
    bildirimAyarlari.value = const BildirimAyarlari();
  }
  await ezanPlatformu.ayarla(bildirimAyarlari.value.toMap());
}

Future<void> bildirimAyarlariKaydet(BildirimAyarlari a) async {
  // Native ayar önce yazılır: çalma anı Flutter belleğine bağlı değildir.
  await ezanPlatformu.ayarla(a.toMap());
  final h = await SharedPreferences.getInstance();
  await h.setString(bildirimAyarAnahtari, jsonEncode(a.toMap()));
  bildirimAyarlari.value = a;
}
