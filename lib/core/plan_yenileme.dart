import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../data/dil_katalogu.dart';
import '../utils/widget_paketi.dart';
import 'aladhan_cevap.dart';
import 'bildirim_ayarlari.dart';
import 'bildirim_motoru.dart';
import 'diyanet_guncel.dart';
import 'diyanet_verisi.dart';
import 'ezan_platformu.dart';
import 'saat.dart';
import 'vakit_verisi.dart';

const planYenilemeKanali = MethodChannel('namaz_vakitleri/renewal');

/// A source request, not a second prayer calculator. Both UI and background
/// consume the existing validators, cache, Diyanet depot and alarm planner.
class KayanVakitKaynak {
  KayanVakitKaynak({
    required this.saat,
    required this.depo,
    required this.diyanet,
    required this.resmiAg,
    required this.istemci,
  });
  final Saat saat;
  final VakitDepo depo;
  final DiyanetDepo diyanet;
  final DiyanetGuncelDepo resmiAg;
  final http.Client istemci;
  static const gunSayisi = 30;

  Future<VakitDurumu> oku(Konum konum, {required bool resmi}) async {
    if (resmi && konum.ulkeIso2 == 'TR' && konum.diyanetCityId != null) {
      konum = konum.kopyala(saatDilimi: kTurkiyeSaatDilimi);
    }
    final tarih = SehirSaati(konum: konum, saat: saat).bugun();
    if (tarih == null) {
      throw const FormatException('Unknown selected-city timezone');
    }
    final id = konum.diyanetCityId;
    final parca = konum.diyanetParca;
    if (resmi && konum.ulkeIso2 == 'TR' && id != null) {
      if (parca != null && parca.isNotEmpty) {
        final sonuc = await diyanet.vakitler(
          cityId: id,
          ilDosya: parca,
          tarih: tarih,
          ileriGun: gunSayisi - 1,
        );
        if (sonuc.basariliMi) {
          return VakitDurumu(
            konum: konum,
            kaynak: VakitKaynagi.resmiDiyanet,
            bugun: sonuc.gun,
            gelecekGunler: pencere([
              sonuc.gun!,
              ...sonuc.siradakiGunler,
            ], tarih),
          );
        }
      }
      final sonuc = await resmiAg.oku(id, tarih, ileriGun: gunSayisi - 1);
      if (sonuc != null) {
        return VakitDurumu(
          konum: konum,
          kaynak: VakitKaynagi.resmiDiyanetGuncel,
          bugun: sonuc.bugun,
          gelecekGunler: pencere([sonuc.bugun, ...sonuc.gelecekGunler], tarih),
        );
      }
    }
    // A 30-day civil-date window can span three months around February.
    final son = DateTime(tarih.year, tarih.month, tarih.day + gunSayisi - 1);
    final gunler = <VakitGunu>[];
    var agdan = false;
    for (
      var ay = DateTime(tarih.year, tarih.month, 1);
      !ay.isAfter(son);
      ay = DateTime(ay.year, ay.month + 1, 1)
    ) {
      var cevap = await depo.kayitOku(konum, yil: ay.year, ay: ay.month);
      final ozet = await depo.ozetOku(konum, yil: ay.year, ay: ay.month);
      if (cevap == null ||
          ozet == null ||
          saat.simdi().difference(ozet.indirildi) > const Duration(days: 1)) {
        try {
          final r = await istemci
              .get(
                Uri.https('api.aladhan.com', '/v1/calendar', {
                  'latitude': konum.enlem.toStringAsFixed(4),
                  'longitude': konum.boylam.toStringAsFixed(4),
                  'month': '${ay.month}',
                  'year': '${ay.year}',
                  if (konum.yontemId != null) 'method': '${konum.yontemId}',
                  'school': konum.asrYontemi.apiParametresi,
                  'latitudeAdjustmentMethod':
                      konum.yuksekEnlemAyaru.apiParametresi,
                }),
                headers: const {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 10));
          final dogru = AladhanCevap(saat).dogrula(
            r.body,
            httpDurumKodu: r.statusCode,
            istenenKonum: konum,
            yil: ay.year,
            ay: ay.month,
            istenenGun: ay,
          );
          if (dogru is CevapGecerli && dogru.saatDilimi == konum.saatDilimi) {
            await depo.kayitYaz(konum, dogru);
            cevap = dogru;
            agdan = true;
          }
        } catch (_) {
          /* Offline or rejected: preserve valid cache and alarms. */
        }
      }
      if (cevap?.saatDilimi == konum.saatDilimi) gunler.addAll(cevap!.gunler);
    }
    final sirali = pencere(gunler, tarih);
    return VakitDurumu(
      konum: konum,
      kaynak: agdan ? VakitKaynagi.ag : VakitKaynagi.onbellek,
      bugun: sirali.where((g) => g.ayniGun(tarih)).firstOrNull,
      gelecekGunler: sirali,
    );
  }

  /// Never bridge a missing date with a different day's times.
  static List<VakitGunu> pencere(List<VakitGunu> gunler, DateTime tarih) {
    final index = {for (final g in gunler) g.tarih: g};
    final result = <VakitGunu>[];
    for (var i = 0; i < gunSayisi; i++) {
      final g = index[DateTime(tarih.year, tarih.month, tarih.day + i)];
      if (g == null) break;
      result.add(g);
    }
    return result;
  }
}

Map<String, Object?> yenilemeAyarlari(
  Konum? k, {
  required bool resmi,
  required BildirimAyarlari bildirim,
  required int erken,
  required bool gunes,
}) => {
  'location': k == null
      ? null
      : {
          'name': k.ad,
          'country': k.ulkeIso2,
          'latitude': k.enlem,
          'longitude': k.boylam,
          'zone': k.saatDilimi,
          'method': k.yontemId,
          'school': k.asrYontemi.kod,
          'highLatitude': k.yuksekEnlemAyaru.kod,
          'province': k.il,
          'cityId': k.diyanetCityId,
          'part': k.diyanetParca,
        },
  'official': resmi,
  'settings': bildirim.toMap(),
  'early': erken,
  'sunrise': gunes,
};

Konum yenilemeKonumu(Map<String, dynamic> m) => Konum(
  ad: m['name'] as String,
  ulkeIso2: m['country'] as String,
  enlem: (m['latitude'] as num).toDouble(),
  boylam: (m['longitude'] as num).toDouble(),
  saatDilimi: m['zone'] as String,
  yontemId: m['method'] as int?,
  asrYontemi: AsrYontemi.values.firstWhere((a) => a.kod == m['school']),
  yuksekEnlemAyaru: YuksekEnlemAyaru.values.firstWhere(
    (a) => a.kod == m['highLatitude'],
  ),
  il: m['province'] as String,
  diyanetCityId: m['cityId'] as int?,
  diyanetParca: m['part'] as String?,
);

/// Headless Flutter engine entrypoint; no Activity, runApp, GPS or permission UI.
@pragma('vm:entry-point')
Future<void> arkaPlanYenile() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final istemci = http.Client();
  Map<String, Object> rapor = {'ok': false};
  try {
    final raw = await planYenilemeKanali.invokeMethod<String>('context');
    final p = jsonDecode(raw!) as Map<String, dynamic>;
    final config = p['renewal'] as Map<String, dynamic>;
    final istenenKonum = yenilemeKonumu(
      config['location'] as Map<String, dynamic>,
    );
    final h = await SharedPreferences.getInstance();
    await h.reload();
    await DilKatalogu.yukle();
    const saat = GercekSaat();
    final veri = await KayanVakitKaynak(
      saat: saat,
      depo: VakitDepo(saat: saat),
      diyanet: DiyanetDepo(),
      resmiAg: DiyanetGuncelDepo(istemci: istemci),
      istemci: istemci,
    ).oku(istenenKonum, resmi: config['official'] == true);
    if (!veri.basariliMi) {
      throw const FormatException('No valid current-day coverage');
    }
    final k = veri.konum;
    final dil = p['language'] as String;
    final metin =
        jsonDecode(await rootBundle.loadString('assets/i18n/ceviri/$dil.json'))
            as Map;
    String cevir(String key) => (metin[key] ?? key).toString();
    String bicim(String key, String vakit, [int? dakika]) => cevir(
      key,
    ).replaceAll('{vakit}', vakit).replaceAll('{dakika}', '${dakika ?? ''}');
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final motor = BildirimMotoru(
      eklenti: plugin,
      planlayici: const BildirimPlanlayici(gunSiniri: 30),
      sira: PlanSirasi(),
      ezan: const EzanPlatformu(),
      cevir: cevir,
      arkaPlan: true,
    );
    final plan = const BildirimPlanlayici(gunSiniri: 30).planla(
      konum: k,
      sehirSaati: SehirSaati(konum: k, saat: saat),
      gunler: veri.gelecekGunler,
      erkenUyariDakika: config['early'] as int,
      gunesDogumuBildirimiAcik: config['sunrise'] == true,
      ayarlar: BildirimAyarlari.oku(config['settings'] as Map<String, dynamic>),
      cevir: cevir,
      vakitAdiCevir: (ad, _) => cevir(ad),
      erkenUyariMetni: (dk, ad) => bicim('notif_early_body', ad, dk),
      vakitMetni: (ad) => bicim('notif_time_reached_body', ad),
      gunesDogumuMetni: () => cevir('notif_sunrise_body'),
      tamZamanli: await motor.tamZamanliIzinVar(),
    );
    final sonuc = await motor.uygula(plan, secimNo: motor.yeniSecim());
    final resmi =
        veri.kaynak == VakitKaynagi.resmiDiyanet ||
        veri.kaynak == VakitKaynagi.resmiDiyanetGuncel;
    final paket = WidgetPaketi.olustur(
      konum: k,
      saat: saat,
      gunler: veri.gelecekGunler,
      tema: ColorScheme.fromSeed(seedColor: Colors.teal),
      dil: dil,
      kaynak: cevir(resmi ? 'kaynak_diyanet' : 'kaynak_hesaplanmis'),
      metinler: Map<String, String>.from(p['labels'] as Map),
      gunSiniri: 30,
    );
    paket['colors'] = Map<String, Object>.from(p['colors'] as Map);
    await const MethodChannel(
      'namaz_vakitleri/widget',
    ).invokeMethod<void>('publish', jsonEncode(paket));
    rapor = {
      'ok': sonuc.uyari == null || sonuc.uyari == 'exact_alarm_yok',
      'days': sonuc.kapsananGunSayisi,
      'alarms': sonuc.bildirimler.length,
      'source': veri.kaynak.name,
      'zone': k.saatDilimi,
      'lastDay': veri.gelecekGunler.last.tarih.toIso8601String(),
      if (sonuc.uyari != null) 'warning': sonuc.uyari!,
    };
  } catch (e) {
    rapor = {'ok': false, 'error': e.toString()};
  } finally {
    istemci.close();
    await planYenilemeKanali.invokeMethod<void>('complete', rapor);
  }
}
