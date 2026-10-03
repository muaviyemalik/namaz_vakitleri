// test/bildirim_plan_yarisi_test.dart
//
// BİLDİRİM PLANI ÇAKIŞMASI: SON GEÇERLİ SEÇİM KAZANMALI.
//
// SORUN
//
// `_alarmlariKur` her başarılı veri yüklemesinde, hesap ayarı değişiminde ve
// dil değişiminde çağrılır; `async` olduğu için çağrılar ÜST ÜSTE BİNEBİLİR.
// `BildirimMotoru.uygula` ise uzun bir yol: tercih deposu okunur, her bildirim
// için `zonedSchedule` çağrılır, artık gerekmeyenler iptal edilir ve sonunda
// kalıcı kimlik listesi TEK SEFERDE yazılır.
//
// Bu uzun yolda iki uygulama çakışırsa:
//   * ikisinin de "eski kimlikler" listesini okuması aynı anki kalıcı
//     listeyi görür,
//   * birinin iptal ettiği kimliği diğeri yeniden kurabilir,
//   * kalıcı kimlik listesi hangi planı anlattığına göre iki uygulamanın
//     SONUNCUSUNU yazar (yani eski plan listeyi, yeni plan bekleyenleri).
// Sonuç: ekranda Paris yazarken cihazda Ankara'nın alarmları bekliyor.
//
// AYRICA: plan uygulamaları "hangi seçime ait oldukları" bilgisi taşımıyordu.
// İzin sorgusu geciken bir çağrı, YENİ seçimden SONRA `uygula`'ya ulaşabilir
// ve son sözü o (eski) plan söyler.
//
// BU TEST NASIL KURULUYOR?
//
//   * GERÇEK ÜRETİM KODU: `BildirimMotoru` ve `BildirimPlanlayici` üretimden
//     olduğu gibi kullanılır. Testte yarış algoritması YOK; sıralamayı
//     motorun kendi kuralı belirler.
//   * KONTROLLÜ EKLENTİ: gerçek `FlutterLocalNotificationsPlugin` yerine
//     bekleyen bildirimleri kaydeden bir sahte. İlk kurulum çağrısı testin
//     açtığı bir kapıda bekletilir; böylece "eski uygulama ortasındayken yeni
//     uygulama başlar" durumu çift taraflı kapı olmadan da oluşturulur.
//   * KONTROLLÜ TERCİH DEPOSU: SharedPreferences bellek içi mock.
//   * Gerçek ağ, gerçek cihaz, gerçek alarm TESLİMİ yoktur. Bu test planın
//     SİSTEME NE YAZDIĞINI ölçer; alarmın gerçekten çalması cihazda
//     doğrulanır, burada değil.
import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'fixture/aladhan_ornek.dart';

/// `BildirimMotoru`'nun kalıcı kimlik listesini tuttuğu anahtar.
const String kimlikDiziniAnahtari = 'bildirim_motoru_kimlikleri';

/// Bu motorun SAHİP OLMADIĞI, başka bir yolun kurduğu bir bildirim.
const int yabanciKimlik = 987654321;

// ---------------------------------------------------------------------------
// KONTROLLÜ EKLENTİ
// ---------------------------------------------------------------------------

/// Bekleyen bildirimleri kaydeden, ilk kurulumu kapıda bekletebilen sahte
/// bildirim eklentisi.
class KontrolluBildirimEklentisi implements FlutterLocalNotificationsPlugin {
  /// Sistemde bekleyen bildirimler: kimlik -> zaman.
  final Map<int, tz.TZDateTime> bekleyen = <int, tz.TZDateTime>{};

  /// Eklentiye yapılan yazma/iptal çağrılarının kaydı (sıra ile).
  final List<String> cagriLog = <String>[];

  /// Kaç kurulum çağrısı bu kapıda bekledi.
  int kapidaBekleyen = 0;

  Completer<void>? _kapi;

  /// Bir sonraki (ilk) kurulum çağrısı [kapiyiAc] çağrılana kadar bekler.
  void ilkKurulumuBeklet() {
    _kapi = Completer<void>();
  }

  void kapiyiAc() => _kapi?.complete();

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final kapi = _kapi;
    if (kapi != null && kapidaBekleyen == 0) {
      kapidaBekleyen++;
      await kapi.future;
    }
    bekleyen[id] = scheduledDate;
    cagriLog.add('kur:$id');
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    bekleyen.remove(id);
    cagriLog.add('iptal:$id');
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      <PendingNotificationRequest>[
        for (final id in bekleyen.keys)
          PendingNotificationRequest(id, null, null, null),
      ];

  /// Android uygulamasına özgü bir çağrı yapılmaz: kanal/izin davranışı bu
  /// testin konusu değil. `null` dönmek "platform kısıtı yok" demektir.
  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() =>
      null;

  @override
  dynamic noSuchMethod(Invocation cagri) => super.noSuchMethod(cagri);
}

// ---------------------------------------------------------------------------
// GERÇEK PLANLAR (üretim planlayıcısı + donmuş cevaplar)
// ---------------------------------------------------------------------------

SabitSaat _utc(int y, int a, int g, int s, int d) =>
    SabitSaat(DateTime.utc(y, a, g, s, d));

Konum _konum(FixtureBilgi b) => Konum(
      ad: b.ad,
      ulkeIso2: b.ulke,
      enlem: b.enlem,
      boylam: b.boylam,
      saatDilimi: b.saatDilimi,
    );

/// Aylık cevaptan doğrulanmış gün listesi (gerçek doğrulayıcıdan geçer).
List<VakitGunu> _gunler(Fixture f) {
  final d = AladhanCevap(const GercekSaat()).dogrula(
    f.govde,
    httpDurumKodu: 200,
    istenenKonum: _konum(f.bilgi),
    yil: f.bilgi.yil,
    ay: f.bilgi.ay,
  );
  expect(d, isA<CevapGecerli>(), reason: 'geçerli fixture bekleniyor');
  return (d as CevapGecerli).gunler;
}

String _cevir(String k) => '<$k>';
String _vakitAdi(String k, int _) => k;

/// Bir şehrin planını ÜRETİM planlayıcısıyla üretir.
///
/// İki şehrin planı aynı günleri kapsar, dolayısıyla kimlik kümesi AYNI,
/// zamanları FARKLIDIR: kimlikler tarih+vakit+türden türer, saatler şehre göre
/// değişir. Bu, gerçekte "kullanıcı şehir değiştirdi" durumunun ta kendisidir.
PlanOzeti _plan(Fixture f, SabitSaat saat) {
  final konum = _konum(f.bilgi);
  return const BildirimPlanlayici().planla(
    konum: konum,
    sehirSaati: SehirSaati(konum: konum, saat: saat),
    gunler: _gunler(f),
    erkenUyariDakika: 0,
    gunesDogumuBildirimiAcik: false,
    cevir: _cevir,
    vakitAdiCevir: _vakitAdi,
  );
}

/// [plan]ın sistemde bulunması gereken hâli: kimlik -> zaman.
Map<int, tz.TZDateTime> _beklenen(PlanOzeti plan) => <int, tz.TZDateTime>{
      for (final b in plan.bildirimler) b.kimlik: b.zaman,
    };

/// Olay döngüsünü birkaç tur ilerletir (duvar saati beklemesi DEĞİLDİR).
Future<void> _tur() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<Set<int>> _kayitliKimlikler() async {
  final h = await SharedPreferences.getInstance();
  return (h.getStringList(kimlikDiziniAnahtari) ?? <String>[])
      .map(int.tryParse)
      .whereType<int>()
      .toSet();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('CAKISAN IKI UYGULAMADA SON GECERLI SECIM KAZANIR', () async {
    final eklenti = KontrolluBildirimEklentisi();
    final motor = BildirimMotoru(
      eklenti: eklenti,
      planlayici: const BildirimPlanlayici(),
      // Plan sırası kaynak (uygulama) geneli seviyesindedir; bu testler
      // motorun İÇ kuralını tek örnek üzerinde ölçer, bu yüzden her test
      // kendi sırasını alır ve testler birbirinden yalıtılır.
      sira: PlanSirasi(),
    );

    final saat = _utc(2026, 9, 15, 3, 0); // 15 Eylul, İstanbul 06:00
    final ankaraPlan = _plan(istanbulFixture, saat);
    final parisPlan = _plan(parisOtomatikFixture, saat);
    expect(ankaraPlan.bildirimler, isNotEmpty);
    expect(parisPlan.bildirimler, isNotEmpty);

    // İki planın kimlik kümesi ÇAKIŞIR ama AYNI DEĞİLDİR: aynı günler
    // planlanır, ama "geçmiş vakitler kurulmaz" kuralı şehrin saatine
    // göre işlediği için birinde kurulup diğerinde kurulmayan vakitler
    // olur. Bu, gerçekte şehir değiştirdiğimizde olan durumun ta kendisidir
    // ve hem ÜZERİNE YAZMA hem de YALNIZCA İPTAL riskini bir arada doğurur.
    final ankaraKimlikler = _beklenen(ankaraPlan).keys.toSet();
    final parisKimlikler = _beklenen(parisPlan).keys.toSet();
    expect(ankaraKimlikler.intersection(parisKimlikler), isNotEmpty,
        reason: 'senaryo ortak kimlikler üzerine yazma içermeli');
    expect(
      <int>{...parisKimlikler}..removeAll(ankaraKimlikler),
      isNotEmpty,
      reason: 'senaryo, yalnız yeni planda bulunan kimlikleri de içermeli: '
          'eski planın iptal döngüsü tam olarak bunları yanlışlıkla silebilir',
    );

    // Yabanci bildirim: motorun sahibi olmadığı bir kurulum.
    eklenti.bekleyen[yabanciKimlik] =
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 20, 6);

    // ESKİ seçimin uygulaması, ilk kurulumda kapıda kalır.
    eklenti.ilkKurulumuBeklet();
    final eskiUygulama = motor.uygula(ankaraPlan, secimNo: 1);
    await _tur();
    expect(eklenti.kapidaBekleyen, 1,
        reason: 'eski uygulamanın kurulumda beklediği doğrulanmalı');

    // YENİ seçimin uygulaması başlar.
    final yeniUygulama = motor.uygula(parisPlan, secimNo: 2);
    await _tur();

    // Kapı açılır; her iki uygulama da tamamlanır.
    eklenti.kapiyiAc();
    await Future.wait<void>(<Future<void>>[eskiUygulama, yeniUygulama]);
    await _tur();

    // --- KABUL: son geçerli seçim (Paris) kazanır ---
    final bekleyen = eklenti.bekleyen;
    expect(
      <int, tz.TZDateTime>{
        for (final e in bekleyen.entries)
          if (e.key != yabanciKimlik) e.key: e.value,
      },
      _beklenen(parisPlan),
      reason: 'bekleyen bildirimler SON SEÇİME ait olmalı; eski plan '
          'kimliklerin üzerine yazmamalı ve kendi zamanlarını bırakmamalı',
    );
    expect(await _kayitliKimlikler(), _beklenen(parisPlan).keys.toSet(),
        reason: 'kalıcı kimlik listesi son uygulanan planla tutarlı olmalı');

    // Motorun sahibi olmadığı bildirim korunur.
    expect(bekleyen.containsKey(yabanciKimlik), isTrue,
        reason: 'başka bir kodun bildirimi silinmemeli');
    expect(
        eklenti.cagriLog.where((c) => c == 'iptal:$yabanciKimlik'), isEmpty,
        reason: 'motor yalnızca kendi kimliklerini iptal edebilmeli');
    expect(await _kayitliKimlikler(), isNot(contains(yabanciKimlik)));
  });

  test('GEC KALAN ESKI SECIM YENI PLANI EZMEZ', () async {
    final eklenti = KontrolluBildirimEklentisi();
    final motor = BildirimMotoru(
      eklenti: eklenti,
      planlayici: const BildirimPlanlayici(),
      sira: PlanSirasi(),
    );

    final saat = _utc(2026, 9, 15, 3, 0);
    final ankaraPlan = _plan(istanbulFixture, saat);
    final parisPlan = _plan(parisOtomatikFixture, saat);

    // Yeni seçim önce uygulanır (izin sorgusu hızlı döndü).
    await motor.uygula(parisPlan, secimNo: 2);
    final yazmaSayisi = eklenti.cagriLog.length;

    // Eski seçimin uygulaması GEÇ döner: artık sözü o söylememeli.
    await motor.uygula(ankaraPlan, secimNo: 1);
    await _tur();

    expect(eklenti.bekleyen, equals(_beklenen(parisPlan)),
        reason: 'geç kalan eski plan yeni planın üzerine yazmamalı');
    expect(eklenti.cagriLog.length, yazmaSayisi,
        reason: 'geç kalan uygulama eklentiye hiçbir yazma yapmamalı');
    expect(await _kayitliKimlikler(), _beklenen(parisPlan).keys.toSet());
  });

  test('motorun sahip olmadigi bildirimler korunur', () async {
    final eklenti = KontrolluBildirimEklentisi();
    final motor = BildirimMotoru(
      eklenti: eklenti,
      planlayici: const BildirimPlanlayici(),
      sira: PlanSirasi(),
    );

    final saat = _utc(2026, 9, 15, 3, 0);
    final plan = _plan(istanbulFixture, saat);
    eklenti.bekleyen[yabanciKimlik] =
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 20, 6);

    await motor.uygula(plan, secimNo: 1);

    expect(eklenti.bekleyen.containsKey(yabanciKimlik), isTrue);
    expect(await motor.planlananSayisi(), plan.bildirimler.length + 1,
        reason: 'sistemdeki bekleyen bildirimler: motorun planı + yabancı');
    expect(await _kayitliKimlikler(), _beklenen(plan).keys.toSet(),
        reason: 'kalıcı liste yalnız motorun kendi kimliklerini içermeli');
  });
}
