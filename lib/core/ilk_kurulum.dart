import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../data/ulke_verisi.dart';
import '../widgets/ulke_secici.dart';
import '../widgets/sehir_secici.dart';
import 'bildirim_ayarlari.dart';
import 'ilk_acilis_izinleri.dart';

const kurulumBasladiAnahtari = 'ilk_kurulum_basladi_v1';
const kurulumBittiAnahtari = 'ilk_kurulum_bitti_v1';

/// Eski kayıtlı şehirleri korur; yarım kalmış yeni kurulum şehir kaydetse bile atlanmaz.
Future<bool> ilkKurulumGerekir(
  SharedPreferences prefs, {
  bool kayitliKonumGecerli = true,
}) async {
  if (prefs.getBool(kurulumBittiAnahtari) == true && kayitliKonumGecerli) {
    return false;
  }
  if (prefs.getBool(kurulumBasladiAnahtari) != true &&
      kayitliKonumGecerli &&
      (prefs.getString(kayitliKonumAnahtari)?.isNotEmpty ?? false)) {
    await prefs.setBool(kurulumBittiAnahtari, true);
    return false;
  }
  if (!await prefs.setBool(kurulumBasladiAnahtari, true)) {
    throw StateError('Kurulum kaydı yazılamadı');
  }
  return true;
}

class KurulumKonumu {
  const KurulumKonumu(this.sehir, this.ulke);
  final Sehir sehir;
  final String ulke;
}

enum KurulumKonumHatasi { servisKapali, izinReddedildi, kaliciRet, bulunamadi }

class KurulumIzinDurumu {
  const KurulumIzinDurumu({this.bildirim, this.alarm, this.konum});
  final bool? bildirim;
  final bool? alarm;
  final bool? konum;
}

/// UI testleri aynı akışı platform ekranı açmadan denetleyebilir.
class KurulumIslemleri {
  bool get alarmDestekli => Platform.isAndroid;
  bool get konumDestekli => Platform.isAndroid || Platform.isIOS;

  Future<KurulumKonumu?> elleSec(BuildContext context) async {
    final ulke = await ulkeSeciciGoster(context);
    if (ulke == null || !context.mounted) return null;
    final sehir = await sehirSeciciGoster(context, ulke.iso2);
    return sehir == null ? null : KurulumKonumu(sehir, ulke.iso2);
  }

  Future<void> konumIzniIste() async {
    if (!konumDestekli) return;
    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(IlkAcilisIzinleri.konumAnahtari, true);
      await Geolocator.requestPermission();
    }
  }

  Future<KurulumKonumu> otomatikBul() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw KurulumKonumHatasi.servisKapali;
    }
    await konumIzniIste();
    final izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.deniedForever) {
      throw KurulumKonumHatasi.kaliciRet;
    }
    if (izin == LocationPermission.denied) {
      throw KurulumKonumHatasi.izinReddedildi;
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 20));
    Placemark? yer;
    try {
      final yerler = await placemarkFromCoordinates(
        p.latitude,
        p.longitude,
      ).timeout(const Duration(seconds: 4));
      yer = yerler.firstOrNull;
    } catch (_) {
      /* Yerel Türkiye kataloğu internet olmadan da kullanılabilir. */
    }
    final iso = yer?.isoCountryCode?.trim().toUpperCase();
    final ulke = iso != null && RegExp(r'^[A-Z]{2}$').hasMatch(iso)
        ? iso
        : null;
    final sonuc = await diyanetKonumCozucu.coz(
      enlem: p.latitude,
      boylam: p.longitude,
      hassasiyet: p.accuracy,
      ulke: ulke,
      il: yer?.administrativeArea ?? '',
      adlar: [
        yer?.subAdministrativeArea ?? '',
        yer?.locality ?? '',
        yer?.subLocality ?? '',
      ],
    );
    if (sonuc != null) return KurulumKonumu(sonuc.sehir, 'TR');
    if (ulke != null && ulke != 'TR') {
      final ad = [
        yer?.locality,
        yer?.subAdministrativeArea,
        yer?.administrativeArea,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).firstOrNull;
      return KurulumKonumu(
        Sehir(
          ad:
              ad ??
              '${p.latitude.toStringAsFixed(3)}, ${p.longitude.toStringAsFixed(3)}',
          enlem: p.latitude,
          boylam: p.longitude,
        ),
        ulke,
      );
    }
    throw KurulumKonumHatasi.bulunamadi;
  }

  Future<void> ayarlariAc(KurulumKonumHatasi hata) async {
    if (hata == KurulumKonumHatasi.servisKapali) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> izinAyariniAc(String tur) async {
    if (Platform.isAndroid && tur != 'location') {
      await ezanPlatformu.sistemAyari(tur);
    } else if (konumDestekli) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> izinleriIste(bool Function() devam) async {
    if (!konumDestekli) return;
    await IlkAcilisIzinleri().iste(
      tercihler: await SharedPreferences.getInstance(),
      devam: devam,
      bildirim: () async {
        if (Platform.isAndroid) {
          await bildirimServisi
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        } else if (Platform.isIOS) {
          await bildirimServisi
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        }
      },
      alarm: () async {
        if (Platform.isAndroid) {
          await bildirimServisi
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestExactAlarmsPermission();
        }
      },
      konum: konumIzniIste,
      hataBildir: (hata) => debugPrint('Kurulum izni: $hata'),
    );
  }

  Future<KurulumIzinDurumu> izinDurumu() async {
    bool? bildirim;
    bool? alarm;
    if (Platform.isAndroid) {
      final android = bildirimServisi
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      bildirim = await android?.areNotificationsEnabled();
      alarm = await android?.canScheduleExactNotifications();
    } else if (Platform.isIOS) {
      bildirim =
          (await bildirimServisi
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled;
    }
    final konum = konumDestekli ? await Geolocator.checkPermission() : null;
    return KurulumIzinDurumu(
      bildirim: bildirim,
      alarm: alarm,
      konum: konum == null
          ? null
          : konum == LocationPermission.always ||
                konum == LocationPermission.whileInUse,
    );
  }

  Future<void> tamamla(
    KurulumKonumu konum,
    VakitBildirimModu mod,
    bool sessizde,
  ) async {
    // Bildirim tercihi şehirden önce kaydedilir: yeni şehir varsayılan ezanla planlanmaz.
    await bildirimAyarlariKaydet(
      BildirimAyarlari(
        sessizdeCal: mod == VakitBildirimModu.ezan && sessizde,
        dndCal: false,
        modlar: {for (final vakit in BildirimAyarlari.vakitler) vakit: mod},
      ),
    );
    await erkenUyariKaydet(0);
    await gunesDogumuBildirimiKaydet(false);
    erkenUyariSuresi.value = 0;
    gunesDogumuBildirimiAcik.value = false;
    await konumAyarla(konum.sehir, ulke: konum.ulke);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(kurulumBittiAnahtari, true)) {
      throw StateError('Kurulum tamamlanamadı');
    }
  }
}
