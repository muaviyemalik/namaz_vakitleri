import 'package:shared_preferences/shared_preferences.dart';

/// İzinler sırayla sorulur; ret, sonraki açılışta yeniden isteme sebebi değildir.
/// Her adım önceden kaydedilir: sistem ayarlarında uygulama kapanırsa tamamlanan
/// istemler tekrarlanmaz, henüz başlanmamış adımlardan devam edilir.
class IlkAcilisIzinleri {
  static const bildirimAnahtari = 'ilk_izin_bildirim_v1';
  static const alarmAnahtari = 'ilk_izin_alarm_v1';
  static const konumAnahtari = 'ilk_izin_konum_v1';
  static bool _suruyor = false;

  Future<void> iste({
    required SharedPreferences tercihler,
    required Future<void> Function() bildirim,
    required Future<void> Function() alarm,
    required Future<void> Function() konum,
    required bool Function() devam,
    required void Function(Object hata) hataBildir,
  }) async {
    if (_suruyor) return;
    _suruyor = true;
    try {
      for (final adim in [
        (bildirimAnahtari, bildirim),
        (alarmAnahtari, alarm),
        (konumAnahtari, konum),
      ]) {
        if (!devam()) return;
        if (tercihler.getBool(adim.$1) == true) continue;
        if (!await tercihler.setBool(adim.$1, true)) return;
        if (!devam()) return;
        try {
          await adim.$2();
        } catch (hata) {
          hataBildir(hata);
        }
      }
    } finally {
      _suruyor = false;
    }
  }
}
