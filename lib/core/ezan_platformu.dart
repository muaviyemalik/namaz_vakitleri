import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Flutter planını Android AlarmManager'a taşır. Saat/veri hesaplamaz.
class EzanPlatformu {
  const EzanPlatformu();
  static const kanal = MethodChannel('namaz_vakitleri/ezan');
  static bool get destekleniyor => Platform.isAndroid;

  Future<void> planla(Map<String, Object> kayit, {required bool exact}) async {
    await kanal.invokeMethod<void>('schedule', {...kayit, 'exact': exact});
  }

  Future<void> iptal(int id) => kanal.invokeMethod<void>('cancel', {'id': id});
  Future<void> ayarla(Map<String, Object> ayarlar) async {
    if (destekleniyor) await kanal.invokeMethod<void>('configure', ayarlar);
  }

  Future<bool> dndIzni() async =>
      destekleniyor &&
      (await kanal.invokeMethod<bool>('policyAccess') ?? false);
  Future<void> sistemAyari(String tur) async {
    if (destekleniyor) {
      await kanal.invokeMethod<void>('settings', {'type': tur});
    }
  }

  Future<void> dinle(String ses) async {
    if (destekleniyor) {
      await kanal.invokeMethod<void>('preview', {'sound': ses});
    }
  }

  Future<void> durdur() async {
    if (destekleniyor) await kanal.invokeMethod<void>('stop');
  }

  Future<void> onizlemeyiDurdur() async {
    if (destekleniyor) await kanal.invokeMethod<void>('stopPreview');
  }
}
