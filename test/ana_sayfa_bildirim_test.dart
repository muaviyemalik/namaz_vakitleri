// test/ana_sayfa_bildirim_test.dart
//
// ANA SAYFA -> BİLDİRİM MOTORU BAĞLANTISI: SON GEÇERLİ SEÇİM KAZANMALI.
//
// BOŞLUK
//
// `AnaSayfa._alarmlariKur` hem `Platform.isAndroid/isIOS` koşuluyla
// sınırlıydı hem de State'e ait bir `BildirimMotoru` örneği kullanıyordu.
// Windows'ta `flutter test` o yola HİÇ giremediği için sayfa -> motor
// bağlantısı yalnız gözle doğrulanabiliyordu; izin gecikmesi, şehir/ayar
// değişimi ve ekran yenilenmesi birlikte ölçülemiyordu.
//
// BU DOSYA NE ÖLÇÜYOR?
//
// ÜRETİMDEKİ GERÇEK AKIŞ: gerçek `AnaSayfa` widget'ı, gerçek
// `BildirimMotoru`, gerçek `BildirimPlanlayici`, gerçek `VakitDepo`, gerçek
// `http.get`, gerçek SharedPreferences mock deposu. Testte yarış algoritması
// yoktur; sıralamayı üretimin kendi kuralı belirler.
//
// SAHTE OLAN YALNIZCA TAŞIMADIR: ağ (uretim_akisi.dart) ve bildirim
// eklentisi. Eklenti sahtesi sistemdeki bekleyen bildirimleri KAYDEDER ve
// iki noktada kapı tutar:
//   * `canScheduleExactNotifications` -> GEÇİKMİŞ İZİN SORGUSU,
//   * `zonedSchedule`                -> PLAN UYGULANIRKEN GECİKME.
// Sahte eklentiye DOĞRU plan yazılması, gerçek Android/iOS alarm TESLİMİ
// DEĞİLDİR. Cihazda Doze/reboot/izin testi hâlâ açıktır.
//
// BEKLENEN: son geçerli seçimin zamanları ve kimlikleri hem bekleyen
// eklenti kayıtlarında hem kalıcı dizinde korunur; konum, vakit verisi ve
// ayarlar farklı seçimlerden BİRLEŞMEZ; motorun sahibi olmadığı
// bildirimlere dokunulmaz.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/aladhan_cevap.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'uretim_akisi.dart';

/// `BildirimMotoru`'nun kalıcı kimlik listesini tuttuğu anahtar.
const String kimlikDiziniAnahtari = 'bildirim_motoru_kimlikleri';

/// Bu motorun SAHİP OLMADIĞI, başka bir yolun kurduğu bir bildirim.
const int yabanciKimlik = 987654321;

// ---------------------------------------------------------------------------
// KONTROLLÜ İZİN
// ---------------------------------------------------------------------------

/// `canScheduleExactNotifications` sorusunu yanıtlayan, kapıda bekletebilen
/// sahte Android uygulaması.
///
/// Motor `tamZamanliIzinVar()` sorusunu bu nesne üzerinden sorar; soru
/// `_alarmlariKur` içinde `await` edilir. Kapı burada tutulduğunda GEÇİKMİŞ
/// İZİN SORGUSU senaryosu gerçekte olduğu gibi kurulur: eski seçimin planı
/// yeni seçimden sonra `uygula`'ya ulaşır.
class SahteAndroidIzin extends AndroidFlutterLocalNotificationsPlugin {
  SahteAndroidIzin(this.sahip);

  final KontrolluBildirimEklentisi sahip;

  /// `tamZamanliIzinVar()` ne desin? Üretimdeki Android cevabı taklit edilir.
  bool tamZamanliVar = true;

  int sorguSayisi = 0;

  /// Şu anda `await` edilen kapı. Kuyruktan ÇIKARILDIĞI için
  /// [KontrolluBildirimEklentisi.tumIzinleriSerbestBirak] yalnız kuyruğa
  /// bakarsa bu kapıya ulaşamaz; burada tutulur.
  final List<Completer<void>> aktifKapilar = <Completer<void>>[];

  @override
  Future<bool?> canScheduleExactNotifications() async {
    sorguSayisi++;
    // Sıradaki kapıda bekler (yoksa hemen döner). Kapı KUYRUĞUDUR: test
    // birden çok izin sorgusunu AYRI ayrı tutmak isteyebilir (ör. "eski plan
    // hâlâ motoru uygularken güncel plan izin kapısında beklesin").
    if (sahip.izinKapilari.isNotEmpty) {
      final kapi = sahip.izinKapilari.removeAt(0);
      aktifKapilar.add(kapi);
      sahip.izindeBekleyen++;
      try {
        await kapi.future;
      } finally {
        aktifKapilar.remove(kapi);
        sahip.izindeBekleyen--;
      }
    }
    return tamZamanliVar;
  }

  // Kanal kurma motor tarafından her uygulamada çağrılır; yalnız kaydedilir.
  final List<String> kurulanKanallar = <String>[];

  @override
  Future<void> createNotificationChannel(
      AndroidNotificationChannel kanal) async {
    kurulanKanallar.add(kanal.id);
  }
}

// ---------------------------------------------------------------------------
// KONTROLLÜ EKLENTİ
// ---------------------------------------------------------------------------

class KontrolluBildirimEklentisi implements FlutterLocalNotificationsPlugin {
  /// Sistemde bekleyen bildirimler: kimlik -> zaman.
  final Map<int, tz.TZDateTime> bekleyen = <int, tz.TZDateTime>{};

  /// Yazma/iptal çağrılarının kaydı (sıra ile).
  final List<String> cagriLog = <String>[];

  late final SahteAndroidIzin android = SahteAndroidIzin(this);

  /// İzin sorgularının SIRAYLA bekleyeceği kapılar (kuyruk).
  ///
  /// Neden kuyruk? Tek kapı yalnız İLK sorguyu tutardı. Birden çok planın
  /// izin sorgusunu AYRI ayrı tutmak gereken senaryolar oluyor: "eski plan
  /// motoru uygularken güncel plan izin kapısında bekliyor" gibi.
  final List<Completer<void>> izinKapilari = <Completer<void>>[];

  Completer<void>? kurulumKapi;
  int izindeBekleyen = 0;
  int kurulumdaBekleyen = 0;

  /// Sıradaki izin sorgusu [izniSerbestBirak] çağrılana kadar bekler.
  void ilkIzniBeklet() => izinKapilari.add(Completer<void>());

  /// SIRADAKİ tek kapıyı açar: önce kuyruktakiler, sonra bekleyenler.
  ///
  /// Kuyruk boş değilse yeni almış bir sorgu yok demektir; kuyruk boşsa
  /// serbest bırakma AKTİF kapıya gider. Aksi hâlde tekli serbest bırakma
  /// "hiçbir şey yapmadı" gibi görünür ve bekleyen sorgu hiç tamamlanmaz.
  void izniSerbestBirak() {
    if (izinKapilari.isNotEmpty) {
      final k = izinKapilari.removeAt(0);
      if (!k.isCompleted) k.complete();
      return;
    }
    if (android.aktifKapilar.isNotEmpty) {
      final k = android.aktifKapilar.first;
      if (!k.isCompleted) k.complete();
    }
  }

  /// Bekleyen izin kapılarının TAMAMINI açar (kuyruktakiler + bekleyenler).
  ///
  /// Birden çok sorgu tutulduysa hepsi birden açılmalıdır; tek tek açmak
  /// birini açık bırakır ve "güncel plan hâlâ bekliyor" ölçümü yanlış okunur.
  void tumIzinleriSerbestBirak() {
    for (final k in <Completer<void>>[
      ...izinKapilari,
      ...android.aktifKapilar,
    ]) {
      if (!k.isCompleted) k.complete();
    }
  }

  /// İLK kurulum çağrısı [kurulumuSerbestBirak] çağrılana kadar bekler.
  void ilkKurulumuBeklet() => kurulumKapi = Completer<void>();

  void kurulumuSerbestBirak() {
    final k = kurulumKapi;
    kurulumKapi = null;
    if (k != null && !k.isCompleted) k.complete();
  }

  /// Motorun sahibi olmadığı bildirimleri ayıklayarak döndürür.
  Map<int, tz.TZDateTime> motorunBekleyenleri() => <int, tz.TZDateTime>{
        for (final e in bekleyen.entries)
          if (e.key != yabanciKimlik) e.key: e.value,
      };

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    // Bu testin konusu Android yolu; iOS/masaüstü uygulamaları çağrılmaz.
    if (T == AndroidFlutterLocalNotificationsPlugin) return android as T;
    return null;
  }

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
    final kapi = kurulumKapi;
    if (kapi != null && kurulumdaBekleyen == 0) {
      kurulumdaBekleyen++;
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

  @override
  dynamic noSuchMethod(Invocation cagri) => super.noSuchMethod(cagri);
}

// ---------------------------------------------------------------------------
// GERÇEK PLANLAR (üretim planlayıcısı + donmuş cevaplar)
// ---------------------------------------------------------------------------

/// Aylık cevaptan doğrulanmış gün listesi (gerçek doğrulayıcıdan geçer).
List<VakitGunu> _gunler(Konum konum, {required int yil, required int ay}) {
  final url = Uri.https('api.aladhan.com', '/v1/calendar', <String, String>{
    'latitude': konum.enlem.toStringAsFixed(4),
    'longitude': konum.boylam.toStringAsFixed(4),
    'year': '$yil',
    'month': '$ay',
  });
  final govde = konumCevabiniUret(url);
  final d = AladhanCevap(SabitSaat(sabitAn)).dogrula(
    govde,
    httpDurumKodu: 200,
    istenenKonum: konum,
    yil: yil,
    ay: ay,
  );
  expect(d, isA<CevapGecerli>(), reason: 'geçerli cevap bekleniyor');
  return (d as CevapGecerli).gunler;
}

String _cevir(String k) => '<$k>';
String _vakitAdi(String k, int _) => k;

/// Olay döngüsünü birkaç tur ilerletir (duvar saati beklemesi DEĞİLDİR).
Future<void> _tur() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Ekranda metin aramak için: `find.byWidgetPredicate`.
Finder metinBul(String parca) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(parca),
      description: '"$parca" içeren metin',
    );

/// Ekranda görünen TÜM metinler (tanılama amaçlı).
Iterable<String> ekrandakiMetinler(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty);

void main() {
  setUpAll(() async {
    await uretimTestiBaslat();
  });

  setUp(() {
    testOrtaminiSifirla();
    // Bildirim yolunu host platformunda da ölçülebilir kılan üç dikiş yeri.
    // Sıra HER TESTE tazedir: `flutter test` her teste ayrı sahte-zaman
    // bölgesi verir, önceki testten kalan kuyruk future'ı burada ilerlemez.
    bildirimYoluTasarimiAyarla(true);
    bildirimServisiDegistir(KontrolluBildirimEklentisi());
    bildirimPlanSirasiDegistir(PlanSirasi());
  });

  tearDown(() {
    bildirimYoluTasarimiAyarla(null);
    bildirimServisiDegistir(FlutterLocalNotificationsPlugin());
    bildirimPlanSirasiDegistir(PlanSirasi());
    testOrtaminiKapat();
  });

  testWidgets(
      'GECIKEN IZIN SORGUSU SONRASINDA SEHIR DEGISTI: SON SECIM KAZANIR',
      (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    final eklenti = bildirimServisi as KontrolluBildirimEklentisi;
    eklenti.bekleyen[yabanciKimlik] =
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 20, 6);

    await kontrolluAg(kuyruk, () async {
      // 1) İzin sorgusu gecikmeye alınır; Ankara açılır.
      eklenti.ilkIzniBeklet();
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(eklenti.izindeBekleyen, 1,
          reason: 'Ankara planı izin sorgusunda bekliyor olmalı');
      expect(eklenti.izinKapilari, isEmpty,
          reason: 'sorgu kapıyı kuyruktan alıp beklemeye başladı');
      expect(eklenti.android.aktifKapilar.length, 1,
          reason: 'sorgu şu an AKTİF kapıda bekliyor');
      expect(eklenti.motorunBekleyenleri(), isEmpty,
          reason: 'izin cevabı gelmeden sisteme hiçbir şey yazılmamalı');

      // 2) Kullanıcı izin sürerken Paris'i seçer.
      aktifKonum.value = konumParis;
      await akisIlerlet(tester);
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // 3) Geciken izin cevabı gelir: artık sözü Paris söylemelidir.
      eklenti.izniSerbestBirak();
      await akisIlerlet(tester);

      // ÖNEMLİ: yalnız yeni planın doğru olması yetmez. ESKİ (geç kalan)
      // izin sorgusunun GERÇEKTEN tamamlandığı da doğrulanmalıdır: sorgu
      // açıkta kalırsa "geç kalan plan atlandı" dalı hiç çalışmamış olur ve
      // test yanlış güven verir.
      expect(eklenti.izindeBekleyen, 0,
          reason: 'geciken izin sorgusu tamamlanmış olmalı; açıkta kalan '
              'sorgu yarışın ölçülmediği anlamına gelir');
      expect(eklenti.android.aktifKapilar, isEmpty,
          reason: 'aktif kapı kalmamalı');

      final beklenen = beklenenPlan(konumParis);
      expect(eklenti.motorunBekleyenleri(), beklenen,
          reason: 'sistemde yalnız SON SEÇİME (Paris) ait plan olmalı');
      expect(await kaliciKimlikler(), beklenen.keys.toSet(),
          reason: 'kalıcı kimlik listesi de son seçime ait olmalı');
      expect(aktifKonum.value!.ad, 'Paris');

      // 4) Yabancı bildirime dokunulmamış olmalı.
      expect(eklenti.bekleyen.containsKey(yabanciKimlik), isTrue);
      expect(eklenti.cagriLog.where((c) => c == 'iptal:$yabanciKimlik'),
          isEmpty);

      eklenti.izniSerbestBirak();
      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'GECIKEN IZIN SONRASI SEHIR VE ERKEN UYARI DEGISTI: PLAN KARIŞMAZ',
      (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    final eklenti = bildirimServisi as KontrolluBildirimEklentisi;

    await kontrolluAg(kuyruk, () async {
      // 1) Ankara açılır ve planı uygulanır (erken uyarı kapalı).
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(eklenti.motorunBekleyenleri(), beklenenPlan(konumAnkara),
          reason: 'ilk seçimin planı sistemde olmalı');

      // 2) Kullanıcı erken uyarıyı 10 dakika yapar; plan yeniden kurulur ve
      //    bu kez izin sorgusu gecikmeye alınır.
      eklenti.ilkIzniBeklet();
      erkenUyariSuresi.value = 10;
      await akisIlerlet(tester);
      expect(eklenti.izindeBekleyen, 1,
          reason: 'ayar değişimi yeniden planlamayı tetiklemeli');

      // 3) Ayar değişikliği sürerken şehir değişir.
      aktifKonum.value = konumParis;
      await akisIlerlet(tester);
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      eklenti.izniSerbestBirak();
      await akisIlerlet(tester);

      // Geciken izin sorgusunun tamamlandığını doğrula (yukarıdaki gerekçe).
      expect(eklenti.izindeBekleyen, 0,
          reason: 'geciken izin sorgusu tamamlanmalı');
      expect(eklenti.android.aktifKapilar, isEmpty);

      // 4) Kazanan seçim: Paris + 10 dakika erken uyarı. Konum, vakit
      //    verisi ve ayar farklı seçimlerden BİRLEŞMEMELİ.
      final beklenen = beklenenPlan(konumParis, erkenUyariDakika: 10);
      expect(eklenti.motorunBekleyenleri(), beklenen,
          reason: 'sistemdeki plan tek bir seçime ait olmalı: Paris, '
              'erken uyarı 10 dakika');
      expect(await kaliciKimlikler(), beklenen.keys.toSet());

      // "Birleşmemeli" denetimi açık olarak: kayıtlı HİÇBİR saat Ankara'nın
      // (+03:00) ofsetini taşımamalı. Ankara'nın planı ayrı bir seçimdi.
      final ankaraOfseti = beklenenPlan(konumAnkara)
          .values
          .map((z) => z.timeZoneOffset)
          .toSet();
      for (final b in eklenti.motorunBekleyenleri().values) {
        expect(ankaraOfseti.contains(b.timeZoneOffset), isFalse,
            reason: '$b Ankara saat diliminden sızmış: iki seçim birleşmiş');
      }

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'ESKI EKRAN KALDIRILIP YENI EKRAN ACILDI: SON SECIM KAZANIR',
      (tester) async {
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    final eklenti = bildirimServisi as KontrolluBildirimEklentisi;
    eklenti.bekleyen[yabanciKimlik] =
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 20, 6);

    await kontrolluAg(kuyruk, () async {
      // 1) Ankara ekranı açılır; plan uygulaması İLK kurulumda kapıda kalır
      //    (motor uygulamasının ortasındayken ekran kapanacak).
      eklenti.ilkKurulumuBeklet();
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(eklenti.kurulumdaBekleyen, 1,
          reason: 'Ankara planının uygulaması yarıda beklemeli');

      // 2) ESKİ EKRAN KALDIRILIR.
      await tester.pumpWidget(const SizedBox());
      await akisIlerlet(tester);

      // 3) YENİ EKRAN Paris ile açılır. Kurulumu, kaldırılmış ekranın
      //    yarım kalan uygulaması bitene kadar sırada bekler; asıl ölçüm
      //    ikisi de bittikten sonraki NİHAİ durumdur.
      await sayfayiAc(tester, konumParis);
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // 4) ESKİ EKRANIN GEÇ KALAN UYGULAMASI tamamlanır. Artık sözü Paris'in
      //    söylemesi gerekir: kaldırılmış ekranın planı yeni seçimin üzerine
      //    yazmamalı, kendi zamanlarını bırakmamalı ve kalıcı dizini bozmamalı.
      eklenti.kurulumuSerbestBirak();
      await akisIlerlet(tester);

      final beklenen = beklenenPlan(konumParis);
      expect(eklenti.motorunBekleyenleri(), beklenen,
          reason: 'kaldırılmış ekranın geç kalan planı yeni seçimin '
              'üzerine yazmamalı ve kendi zamanlarını bırakmamalı');
      expect(await kaliciKimlikler(), beklenen.keys.toSet(),
          reason: 'kalıcı kimlik listesi yeni ekranın planını anlatmalı');
      expect(aktifKonum.value!.ad, 'Paris');

      expect(eklenti.bekleyen.containsKey(yabanciKimlik), isTrue);
      expect(eklenti.cagriLog.where((c) => c == 'iptal:$yabanciKimlik'),
          isEmpty);

      eklenti.kurulumuSerbestBirak();
      await sayfayiKapat(tester, kuyruk);
    });
  });

  // -------------------------------------------------------------------------
  // ORTAK YARDIMCI: İZİN KAPISI
  //
  // Bu kapı test altyapısıdır, üretim kodudur DEĞİLDİR. Buradaki iki kural
  // yanlışsa bütün gecikme yarış testleri sessizce yanlış ölçüm yapar:
  //
  //   1) TEKİL serbest bırakma, bekleyen sorguyu GERÇEKTEN tamamlamalıdır.
  //      Sorgu kapıyı kuyruktan ÇIKARIP kendi beklediği için, yalnız kuyruğa
  //      bakan bir serbest bırakma hiçbir şey açmaz ve sorgu sonsuza dek
  //      bekler.
  //   2) TOPLU serbest bırakma AÇIK sorgu bırakmamalıdır.
  // -------------------------------------------------------------------------
  group('Izin kapisi yardimcisi', () {
    test('tek kapida bekleyen sorgu TEKIL serbest birakmayla tamamlanir',
        () async {
      final e = KontrolluBildirimEklentisi();
      e.ilkIzniBeklet();
      final sorgu = e.android.canScheduleExactNotifications();
      await _tur();

      expect(e.izindeBekleyen, 1, reason: 'sorgu bekliyor');
      expect(e.izinKapilari, isEmpty,
          reason: 'sorgu kapıyı kuyruktan aldı');
      expect(e.android.aktifKapilar.length, 1,
          reason: 'sorgu şimdi AKTİF kapıda bekliyor');

      e.izniSerbestBirak();
      await _tur();

      expect(e.izindeBekleyen, 0,
          reason: 'tekli serbest bırakma bekleyen sorguyu tamamlamalı; '
              'aksi hâlde geç kalan cevap hiç oluşmaz ve yarış ölçülmez');
      expect(e.android.aktifKapilar, isEmpty);

      // Sorgu GERÇEKTEN cevap döndürmeli: yalnız sayaç değil.
      expect(await sorgu, isTrue);
    });

    test('toplu serbest birakma Acik sorgu BIRAKMAZ', () async {
      final e = KontrolluBildirimEklentisi();
      e.ilkIzniBeklet();
      e.ilkIzniBeklet(); // ikinci kapı kuyrukta beklesin
      final s1 = e.android.canScheduleExactNotifications();
      final s2 = e.android.canScheduleExactNotifications();
      await _tur();

      expect(e.izindeBekleyen, 2, reason: 'iki sorgu da bekliyor');
      expect(e.android.aktifKapilar.length, 2,
          reason: 'İKİ sorgu AYNI anda aktif kapıda bekliyor');

      e.tumIzinleriSerbestBirak();
      await _tur();

      expect(e.izindeBekleyen, 0,
          reason: 'toplu serbest bırakma hiçbir sorguyu açıkta bırakmamalı');
      expect(e.android.aktifKapilar, isEmpty);
      expect(await s1, isTrue);
      expect(await s2, isTrue);
    });

    test('birden fazla AKTIF sorgu desteklenir', () async {
      // Aktif kapılar LİSTE tutulur; tek bir alan olsaydı ikinci sorgu
      // birincinin kapısını ezmiş ya da kaybolmuş olurdu.
      final e = KontrolluBildirimEklentisi();
      e.ilkIzniBeklet();
      e.ilkIzniBeklet();
      e.ilkIzniBeklet();

      final s1 = e.android.canScheduleExactNotifications();
      final s2 = e.android.canScheduleExactNotifications();
      final s3 = e.android.canScheduleExactNotifications();
      await _tur();

      expect(e.izindeBekleyen, 3);
      expect(e.android.aktifKapilar.length, 3,
          reason: 'üç sorgu da kendi kapısında beklemeli');

      // Tekli serbest bırakma SIRAYA göre birer tane açar.
      e.izniSerbestBirak();
      await _tur();
      expect(e.izindeBekleyen, 2);

      e.izniSerbestBirak();
      await _tur();
      expect(e.izindeBekleyen, 1);

      e.izniSerbestBirak();
      await _tur();
      expect(e.izindeBekleyen, 0, reason: 'üçüncü açma son sorguyu da bitirdi');

      expect(await s1, isTrue);
      expect(await s2, isTrue);
      expect(await s3, isTrue);
    });

    test('tumIzinleriSerbestBirak kapisi olmayan durumda PATLAMAZ', () async {
      // Serbest bırakma, tutulmuş kapı yokken de sık sık çağrılır
      // (testin temizlik satırları). Boş listede hata vermemeli.
      final e = KontrolluBildirimEklentisi();
      e.tumIzinleriSerbestBirak();
      e.izniSerbestBirak();
      expect(e.izindeBekleyen, 0);

      // Serbest bırakılmış bir kapı serbest bırakılsa da hata vermemeli.
      e.ilkIzniBeklet();
      final s = e.android.canScheduleExactNotifications();
      await _tur();
      e.tumIzinleriSerbestBirak();
      e.tumIzinleriSerbestBirak();
      await _tur();
      expect(e.izindeBekleyen, 0);
      expect(await s, isTrue);
    });
  });

  /// Ekranda metin aramak için: `find.byWidgetPredicate`.
}

/// [konum] için üretim planlayıcısının verdiği plan: kimlik -> zaman.
///
/// Beklenti ELLE YAZILMAZ; aynı üretim planlayıcısı, aynı sabit saat ve
/// testin sahte ağından gelen AYNI cevapla üretilir. Böylece ölçüm "plan
/// doğru mu?" değil, "sistemde son geçerli seçimin planı mı var?".
Map<int, tz.TZDateTime> beklenenPlan(Konum konum, {int erkenUyariDakika = 0}) {
  final ozet = const BildirimPlanlayici().planla(
    konum: konum,
    sehirSaati: SehirSaati(konum: konum, saat: SabitSaat(sabitAn)),
    gunler: _ayGunleri(konum),
    erkenUyariDakika: erkenUyariDakika,
    gunesDogumuBildirimiAcik: false,
    cevir: _cevir,
    vakitAdiCevir: _vakitAdi,
  );
  expect(ozet.bildirimler, isNotEmpty, reason: 'beklenen plan boş olmamalı');
  return <int, tz.TZDateTime>{
    for (final b in ozet.bildirimler) b.kimlik: b.zaman,
  };
}

/// Testin sahte ağından gelen cevabı GERÇEK doğrulayıcıdan geçirir.
List<VakitGunu> _ayGunleri(Konum konum) =>
    _gunler(konum, yil: testYili, ay: testAyi);

Future<Set<int>> kaliciKimlikler() async {
  final h = await SharedPreferences.getInstance();
  return (h.getStringList(kimlikDiziniAnahtari) ?? <String>[])
      .map(int.tryParse)
      .whereType<int>()
      .toSet();
}