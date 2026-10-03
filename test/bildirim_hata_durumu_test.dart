// test/bildirim_hata_durumu_test.dart
//
// BİLDİRİM KURULUM/İPTAL HATASI: SONUÇ VE KALICI KAYIT GERÇEĞİ YANSITSIN.
//
// HATANIN TANIMI
//
// `_uygulaKilitli` üç gerçeği gizliyordu:
//
//   1) `planlanan.add(b.kimlik)` kurulum DENEMESİNDEN ÖNCE çalışıyordu.
//      Yani hem exact hem inexact reddedilse bile kimlik "planlandı" sayılıyor,
//      kalıcı dizine yazılıyor ve `PlanOzeti.bildirimler`de başarıyla
//      kurulmuş gibi raporlanıyordu. Kullanıcı ekranda "7 gün planlandı"
//      görürken sistemde 3 alarm olabiliyordu ve motor, aslında hiç olmayan
//      bir bildirimi "yönetiyordu".
//
//   2) inexact kurulum hatası yalnız `debugEkle` ile geçiştiriliyordu:
//      sonuçta hiçbir iz kalmıyordu.
//
//   3) İptal hatası yutuluyor (`catch (_) {}`) ve kimlik yine de kalıcı
//      dizinden SİLİNİYORDU. Sistemde kalan alarmın sahiplik izi böylece
//      kalıcı olarak kayboluyor, sonraki hiçbir uygulamada tekrar iptal
//      edilmiyor ve kullanıcının seçmediği bir şehrin alarmı sonsuza dek
//      çalışıyordu.
//
// BU DOSYA NE ÖLÇÜYOR?
//
// Gerçek üretim sınıfları: `BildirimMotoru` ve `BildirimPlanlayici`
// üretimden kullanılır. Testte yarış/kural algoritması yoktur. Sahte olan
// YALNIZCA bildirim eklentisinin taşımasıdır (sistem yazma/iptal); hangi
// çağrının reddedileceğini ve kaç kez reddedileceğini TEST belirler.
//
// "Hata sonrası kuyruğun ilerlemesi" ve "paylaşılan sıra / son seçim"
// kuralları da burada sınanır: hatalı bir uygulama SONRAKİ bir uygulamayı
// kilitlememelidir, geç kalmış bir seçim yine de söz sahibi olmamalıdır.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'ana_sayfa_bildirim_test.dart' as takim;

/// Motorun kalıcı kimlik listesini tuttuğu anahtar.
const String kimlikDizini = 'bildirim_motoru_kimlikleri';

/// Bu motorun sahibi olmadığı, başka bir yolun kurduğu bildirim.
const int yabanciKimlik = 987654321;

// ---------------------------------------------------------------------------
// HATA ÜRETEN EKLENTİ
// ---------------------------------------------------------------------------

/// Kurulum ve iptal hatalarını KONTROLLÜ biçimde üreten bildirim eklentisi.
///
/// Taşıma kaydı taban sınıftan gelir ([takim.KontrolluBildirimEklentisi]);
/// burada yalnız HATA hangi çağrıda olacak sorusu yanıtlanır.
class HataEklentisi extends takim.KontrolluBildirimEklentisi {
  HataEklentisi();

  /// Bu kimlikler HİÇBİR modda kurulamaz (exact + inexact reddedilir).
  final Set<int> kurulamayan = <int>{};

  /// exact modunun her kimlik için reddedilmesi (tam zamanlı alarm izni yok).
  bool exactReddi = false;

  /// Kalan iptal hatası sayısı. 0 ise iptal hep başarılıdır.
  int iptalHatasi = 0;

  /// Kurulum denemeleri: `mod:kimlik`.
  final List<String> kurulumLog = <String>[];

  /// İptal denemeleri.
  final List<String> iptalLog = <String>[];

  String _mod(AndroidScheduleMode m) =>
      m == AndroidScheduleMode.exactAllowWhileIdle ? 'exact' : 'inexact';

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
    final mod = _mod(androidScheduleMode);
    kurulumLog.add('$mod:$id');
    if (kurulamayan.contains(id) || (exactReddi && mod == 'exact')) {
      throw PlatformException(code: 'kontrollu_kurulum_hatasi');
    }
    await super.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: androidScheduleMode,
      title: title,
      body: body,
      payload: payload,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    iptalLog.add('iptal:$id');
    if (iptalHatasi > 0) {
      iptalHatasi--;
      throw PlatformException(code: 'kontrollu_iptal_hatasi');
    }
    await super.cancel(id: id, tag: tag);
  }
}

// ---------------------------------------------------------------------------
// YARDIMCILAR
// ---------------------------------------------------------------------------

PlanlananBildirim bild(
  int kimlik, {
  String vakit = 'fajr',
  int gun = 3,
  BildirimTuru tur = BildirimTuru.vakit,
}) =>
    PlanlananBildirim(
      kimlik: kimlik,
      kimlikAnahtari: 'namaz_vakitleri|2026-10-$gun|$vakit|${tur.name}',
      zaman: tz.TZDateTime(tz.getLocation('UTC'), 2026, 10, gun, 5),
      baslik: 'baslik',
      icerik: 'icerik',
      tur: tur,
      tarih: DateTime(2026, 10, gun),
      vakitAnahtari: vakit,
    );

PlanOzeti plan(List<PlanlananBildirim> bildirimler, {bool tamZamanli = true}) =>
    PlanOzeti(
      bildirimler: bildirimler,
      kapsananGunSayisi: 1,
      tamZamanli: tamZamanli,
    );

BildirimMotoru motor(HataEklentisi eklenti, {PlanSirasi? sira}) =>
    BildirimMotoru(
      eklenti: eklenti,
      planlayici: const BildirimPlanlayici(),
      sira: sira ?? PlanSirasi(),
    );

Future<List<String>> dizin() async {
  final h = await SharedPreferences.getInstance();
  return h.getStringList(kimlikDizini) ?? <String>[];
}

Future<void> diziniYaz(List<String> degerler) async {
  final h = await SharedPreferences.getInstance();
  await h.setStringList(kimlikDizini, degerler);
}

// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tzdata.initializeTimeZones();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('KURULAMAYAN ALARM BASARILI KURULMUS GIBI RAPORLANMAZ', () async {
    final e = HataEklentisi()..kurulamayan.add(123);
    final m = motor(e);

    final sonuc = await m.uygula(plan([bild(123)]), secimNo: m.yeniSecim());

    expect(e.bekleyen, isEmpty, reason: 'hiçbir alarm kurulmamış olmalı');
    expect(await dizin(), isEmpty,
        reason: 'kurulamayan kimlik sahiplik dizinine YAZILMAMALI: '
            'motorun yönettiği bir bildirim sistemde yok');
    expect(sonuc.bildirimler, isEmpty,
        reason: 'sonuç da kurulamayanı başarı SAYMAMALI');
    expect(sonuc.uyari, isNotNull,
        reason: 'kullanıcıya/çağırana hata bildirilmeli, sessizce yutulmamalı');
  });

  test('IPTAL EDILEMEYEN ALARM TAKIP DIZININDEN UNUTULMAZ', () async {
    final e = HataEklentisi()..iptalHatasi = 1;
    e.bekleyen[123] = tz.TZDateTime(tz.getLocation('UTC'), 2026, 10, 3, 5);
    await diziniYaz(<String>['123']);
    final m = motor(e);

    await m.uygula(plan(const <PlanlananBildirim>[]), secimNo: m.yeniSecim());

    expect(e.bekleyen.containsKey(123), isTrue,
        reason: 'sistemde kalan alarm durmalı');
    expect(await dizin(), contains('123'),
        reason: 'sistemde kalan motor alarmı sonraki iptal denemelerinde '
            'izlenebilmeli; izi unutmak onu sonsuza dek yalnız bırakır');
  });

  test('IPTAL HATASINDAN SONRA AYNI KIMLIK TEKRAR DENENIR', () async {
    final e = HataEklentisi();
    final m = motor(e);

    // 1) Kimlik kurulur ve kaydedilir.
    await m.uygula(plan([bild(123)]), secimNo: m.yeniSecim());
    expect(e.bekleyen.keys, containsAll(<int>[123]));
    expect(await dizin(), contains('123'));

    // 2) Yeni planda yok; iptal bir kez reddedilir. İz KORUNUR.
    e.iptalHatasi = 1;
    await m.uygula(plan(const <PlanlananBildirim>[]), secimNo: m.yeniSecim());
    expect(e.bekleyen.containsKey(123), isTrue);
    expect(await dizin(), contains('123'),
        reason: 'iptal başarısızken iz silinmemeli');

    // 3) Sonraki uygulamada iptal yeniden denenir ve bu kez başarılı olur.
    await m.uygula(plan(const <PlanlananBildirim>[]), secimNo: m.yeniSecim());
    expect(e.iptalLog.where((c) => c == 'iptal:123').length, 2,
        reason: 'ikinci uygulama da aynı kimliği iptal etmeyi denemeli');
    expect(e.bekleyen.containsKey(123), isFalse,
        reason: 'gecikmeyen denemede alarm kaldırılmalı');
    expect(await dizin(), isEmpty);
  });

  test('KARMASIK KURULUM: BASARILI VE BASARISIZ AYRI SAYILIR', () async {
    final e = HataEklentisi()..kurulamayan.add(222);
    final m = motor(e);

    final sonuc = await m.uygula(
        plan([bild(111), bild(222), bild(333)]), secimNo: m.yeniSecim());

    expect(e.bekleyen.keys.toSet(), <int>{111, 333},
        reason: 'kurulabilenler kurulmalı, kurulamayan kurulmamalı');
    expect(sonuc.bildirimler.map((b) => b.kimlik).toSet(), <int>{111, 333},
        reason: 'sonuç yalnız GERÇEKTEN kurulanları bildirmeli');
    expect((await dizin()).toSet(), <String>{'111', '333'});
    expect(sonuc.uyari, isNotNull,
        reason: 'eksik kalan alarm sessizce bırakılmamalı');
  });

  test('BASARILI INEXACT YEDEK KAYIP DEGILDIR', () async {
    // Exact reddedilir (tam zamanlı alarm izni yok) ama YAKLAŞIK kurulum
    // başarılıdır: alarm kurulmuştur, kaybolmamalıdır.
    final e = HataEklentisi()..exactReddi = true;
    final m = motor(e);

    final sonuc = await m.uygula(
        plan([bild(111), bild(222)]), secimNo: m.yeniSecim());

    expect(e.bekleyen.keys.toSet(), <int>{111, 222},
        reason: 'yaklaşık alarm da gerçek bir alarmdır');
    expect((await dizin()).toSet(), <String>{'111', '222'});
    expect(sonuc.bildirimler.length, 2);
    expect(sonuc.tamZamanli, isFalse,
        reason: 'yaklaşık alarm "tam zamanlı" gibi sunulmamalı');
    expect(sonuc.uyari, 'exact_alarm_yok');
    expect(e.kurulumLog.where((c) => c.startsWith('inexact')).length, 2,
        reason: 'her bildirim için yaklaşık denemesi yapılmalı');
  });

  test('HATA SONRASI KUYRUK ILERLER', () async {
    // Tercih deposu ilk çağrıda patlar: uygulama HATA fırlatır.
    var cagri = 0;
    final e = HataEklentisi();
    final m = BildirimMotoru(
      eklenti: e,
      planlayici: const BildirimPlanlayici(),
      sira: PlanSirasi(),
      tercih: () async {
        cagri++;
        if (cagri == 1) throw StateError('depo yok');
        return SharedPreferences.getInstance();
      },
    );

    // 1) Hatalı uygulama çağıranı düşürür.
    await expectLater(
      m.uygula(plan([bild(111)]), secimNo: m.yeniSecim()),
      throwsStateError,
    );

    // 2) Kuyruk KİLİTLİ KALMAMALI: sonraki uygulama çalışmalı.
    final sonuc = await m.uygula(plan([bild(222)]), secimNo: m.yeniSecim());

    expect(e.bekleyen.keys.toSet(), <int>{222},
        reason: 'hata sonrası sonraki plan uygulanabilmeli');
    expect((await dizin()).toSet(), <String>{'222'});
    expect(sonuc.bildirimler.map((b) => b.kimlik), <int>[222]);
  });

  // ---------------------------------------------------------------------------
// YAKLAŞIK MOD: İKİ FARKLI YOL, TEK ANLAM
//
// Yaklaşık moda iki yolla girilir ve ikisi de aynı sonucu verir (alarmlar
// kurulur, tam zamanlı değildir):
//
//   1) İzin BAŞTAN yok  -> döngü exact'i hiç denemez.
//   2) Exact denendi ve reddedildi -> `on PlatformException` yakalar.
//
// Uyarı bu iki yolda da üretilmelidir. Önceden yalnız 2. yolda üretiliyordu.
// ---------------------------------------------------------------------------

group('Yaklasik mod bildirimi iki yolda da tutarli', () {
    test('IZIN BASTAN YOK: basarili kurulum uyarisiz donmez', () async {
      final e = HataEklentisi();
      final m = motor(e);

      // `tamZamanli: false` = izin sorgusu baştan false döndü.
      final sonuc = await m.uygula(
          plan([bild(111), bild(222)], tamZamanli: false),
          secimNo: m.yeniSecim());

      expect(e.kurulumLog, ['inexact:111', 'inexact:222'],
          reason: 'exact hic denenmemeli');
      expect(e.bekleyen, isNotEmpty, reason: 'alarmlar kuruldu');
      expect(sonuc.tamZamanli, isFalse);
      expect(sonuc.uyari, 'exact_alarm_yok',
          reason: 'başarılı yaklaşık kurulum, izin baştan yokken de '
              'bildirilmelidir; aksi halde ekran sessizce geçer');
      expect(sonuc.bildirimler.length, 2,
          reason: 'kurulan alarmlar başarıyla raporlanmalı');
    });

    test('EXACT SONRADAN REDDEDILDI: ayni uyari uretilir', () async {
      final e = HataEklentisi()..exactReddi = true;
      final m = motor(e);

      final sonuc = await m.uygula(
          plan([bild(111), bild(222)], tamZamanli: true),
          secimNo: m.yeniSecim());

      expect(e.kurulumLog, isNotEmpty);
      expect(e.bekleyen, isNotEmpty, reason: 'alarmlar kuruldu');
      expect(sonuc.tamZamanli, isFalse);
      expect(sonuc.uyari, 'exact_alarm_yok',
          reason: 'izin baştan yok ile sonradan reddedilmesi AYNI sonucu '
              've AYNI uyarıyı üretmeli');
    });

    test('IZIN BASTAN YOK + KURULUM HATASI: hata mesaji yaklasik-modu ORTMEZ',
        () async {
      final e = HataEklentisi()..kurulamayan.add(222);
      final m = motor(e);

      final sonuc = await m.uygula(
          plan([bild(111), bild(222)], tamZamanli: false),
          secimNo: m.yeniSecim());

      expect(e.bekleyen.keys.toSet(), <int>{111},
          reason: 'kurulabilen kuruldu, kurulamayan kurulmadı');
      expect(sonuc.tamZamanli, isFalse);
      expect(sonuc.uyari, 'bildirim_kurulamadi',
          reason: 'kurulum hatası yaklaşık-mod mesajıyla ÖRTÜLMEMELİ: '
              'kullanıcı alarmın hiç gelmeyeceğini bilmeli');
    });

    test('EXACT REDDI + KURULUM HATASI: yine hata mesaji agir', () async {
      final e = HataEklentisi()
        ..exactReddi = true
        ..kurulamayan.add(222);
      final m = motor(e);

      final sonuc = await m.uygula(
          plan([bild(111), bild(222)], tamZamanli: true),
          secimNo: m.yeniSecim());

      expect(sonuc.uyari, 'bildirim_kurulamadi',
          reason: 'ağırlık sırası: kurulum hatası yaklaşık moddan ağırdır');
    });

    test('HIÇBIR ALARM KURULMADIYSA yaklasik-mod uyarisi YOK', () async {
      // Kurulacak alarm yoksa "yaklaşık moddayız" demek anlamsızdır:
      // kullanıcıya gösterilecek gerçek sorun yoktur.
      final e = HataEklentisi();
      final m = motor(e);

      final sonuc = await m.uygula(plan(const <PlanlananBildirim>[]),
          secimNo: m.yeniSecim());

      expect(sonuc.bildirimler, isEmpty);
      expect(sonuc.uyari, isNull,
          reason: 'boş planda uyarı üretmek yanlış bilgi verir');
    });

    test('IZIN YENIDEN TRUE: yaklasik-mod uyarisi TEMIZLENIR', () async {
      // Kullanıcı ayarlardan tam zamanlı alarm iznini açar; sonraki plan
      // tam zamanlı kurulur ve eski uyarı SİLİNMELİDİR. Aksi halde ekranda
      // artık doğru olmayan bir uyarı kalır.
      final e = HataEklentisi();
      final m = motor(e);

      // 1) İzin yok: yaklaşık kurulum + uyarı.
      final yaklasik = await m.uygula(plan([bild(111)], tamZamanli: false),
          secimNo: m.yeniSecim());
      expect(yaklasik.uyari, 'exact_alarm_yok', reason: 'ön koşul');

      // 2) İzin açıldı: tam zamanlı kurulum.
      final tam = await m.uygula(plan([bild(111)], tamZamanli: true),
          secimNo: m.yeniSecim());

      expect(tam.tamZamanli, isTrue);
      expect(tam.uyari, isNull,
          reason: 'başarılı tam zamanlı kurulum eski uyarıyı temizlemeli');
      expect(e.kurulumLog.last, 'exact:111',
          reason: 'izin açıldıktan sonra exact denenmeli');
    });
  });

  test('HATALI UYGULAMADAN SONRA GEC KALAN SECIM YAZMAZ', () async {
    final e = HataEklentisi();
    final m = motor(e);
    // İlk plan bir kimliği kuramayacak.
    e.kurulamayan.add(111);

    // 1) Yeni seçim (2) önce uygulanır.
    final yeni = await m.uygula(plan([bild(222)]), secimNo: 2);
    expect(yeni.bildirimler.map((b) => b.kimlik), <int>[222]);

    // 2) Geç kalan ESKİ seçim (1) artık söz sahibi değildir.
    final eski = await m.uygula(plan([bild(111)]), secimNo: 1);

    expect(eski.bildirimler.map((b) => b.kimlik), <int>[111],
        reason: 'döndürülen özet kendi planını anlatır (uygulanmadı)');
    expect(e.bekleyen.keys.toSet(), <int>{222},
        reason: 'geç kalan seçim sisteme dokunmamalı');
    expect((await dizin()).toSet(), <String>{'222'},
        reason: 'kalıcı dizin son geçerli seçimi anlatmalı');
  });

  test('PLANDA OLAN AMA KURULAMAYAN KIMLIGIN IZI KORUNUR', () async {
    // Önceki planda kayıtlı bir kimlik, yeni planda da isteniyor ama bu kez
    // kurulamıyor. İZİ korunmalı (aksi halde sonraki plandan çıktığında hiç
    // aranamaz) ama BAŞARI OLARAK RAPORLANMAMALI: sistemde eski zamanıyla
    // duruyor, yeni zaman yazılmadı.
    final e = HataEklentisi();
    final m = motor(e);

    await m.uygula(plan([bild(111)]), secimNo: m.yeniSecim());
    expect(e.bekleyen[111], isNotNull);

    e.kurulamayan.add(111);
    final sonuc = await m.uygula(plan([bild(111)]), secimNo: m.yeniSecim());

    expect(e.bekleyen[111], isNotNull, reason: 'sistemdeki alarm durmalı');
    expect(await dizin(), contains('111'),
        reason: 'sistemde duran kimliğin İZİ korunmalı');
    expect(sonuc.bildirimler, isEmpty,
        reason: 'güncellenemeyen bildirim BAŞARI diye raporlanmamalı');
    expect(sonuc.uyari, 'bildirim_kurulamadi');

    // İz korunduğu için, kimlik yeni plandan ÇIKTIĞINDA iptal denenecek.
    e.kurulamayan.clear();
    await m.uygula(plan(const <PlanlananBildirim>[]), secimNo: m.yeniSecim());
    expect(e.bekleyen.containsKey(111), isFalse,
        reason: 'korunan iz sayesinde sonraki planda iptal edilebildi');
  });

  // -------------------------------------------------------------------------
  // SAHİPLİK İZİ ≠ BAŞARI
  //
  // Kimlik `tarih|vakit|tür` üçlüsünden türer; saat, başlık ve içerik
  // değişebilir. Bu yüzden kalıcı dizinde bir kimliğin bulunması, sistemde
  // O DEĞERLERLE bir alarm bulunduğunun kanıtı DEĞİLDİR. Sonuç yalnız
  // değerleri gerçekten sisteme yazılmış bildirimleri bildirmelidir.
  // -------------------------------------------------------------------------

  test('REDDEDILEN YENI DEGERLER BASARI DIYE RAPORLANMAZ', () async {
    final e = HataEklentisi();
    final m = motor(e);

    // Eski kayıt: 05:00, eski metinler.
    final eski = bild(111);
    await m.uygula(plan([eski]), secimNo: m.yeniSecim());
    expect(e.bekleyen[111], eski.zaman);

    // Aynı kimlik, GERÇEKTEN FARKLI saat ve metinlerle yeniden isteniyor
    // (kullanıcı şehir değiştirdi) ama kurulum reddediliyor.
    final yeniSaat = tz.TZDateTime(tz.getLocation('UTC'), 2026, 10, 3, 7);
    final yeni = PlanlananBildirim(
      kimlik: eski.kimlik,
      kimlikAnahtari: eski.kimlikAnahtari,
      zaman: yeniSaat,
      baslik: 'Yeni sehir',
      icerik: 'Yeni plan',
      tur: eski.tur,
      tarih: eski.tarih,
      vakitAnahtari: eski.vakitAnahtari,
    );
    e.kurulamayan.add(111);

    final sonuc = await m.uygula(plan([yeni]), secimNo: m.yeniSecim());

    expect(e.bekleyen[111], eski.zaman,
        reason: 'sistemde yalnız ESKİ kayıt var');
    expect(await dizin(), contains('111'),
        reason: 'eski alarm takipten silinmemeli');
    expect(sonuc.uyari, 'bildirim_kurulamadi');
    expect(sonuc.bildirimler.map((b) => b.zaman), isNot(contains(yeniSaat)),
        reason: 'sistemde 05:00 varken reddedilen 07:00 başarı diye '
            'raporlanmamalı');
    expect(sonuc.bildirimler.map((b) => b.baslik), isNot(contains('Yeni sehir')),
        reason: 'reddedilen yeni başlık da başarı diye raporlanmamalı');
    expect(sonuc.bildirimler, isEmpty);
  });

  test('BASARILI GUNCELLEME YENI DEGERLERI RAPORLAR', () async {
    final e = HataEklentisi();
    final m = motor(e);

    final eski = bild(111);
    await m.uygula(plan([eski]), secimNo: m.yeniSecim());
    expect(e.bekleyen[111], eski.zaman);

    final yeniSaat = tz.TZDateTime(tz.getLocation('UTC'), 2026, 10, 3, 7);
    final yeni = PlanlananBildirim(
      kimlik: eski.kimlik,
      kimlikAnahtari: eski.kimlikAnahtari,
      zaman: yeniSaat,
      baslik: 'Yeni sehir',
      icerik: 'Yeni plan',
      tur: eski.tur,
      tarih: eski.tarih,
      vakitAnahtari: eski.vakitAnahtari,
    );

    // Bu kez kurulum BAŞARILI.
    final sonuc = await m.uygula(plan([yeni]), secimNo: m.yeniSecim());

    expect(e.bekleyen[111], yeniSaat, reason: 'sistemde yeni zaman olmalı');
    expect(sonuc.bildirimler.length, 1);
    expect(sonuc.bildirimler.single.zaman, yeniSaat);
    expect(sonuc.bildirimler.single.baslik, 'Yeni sehir');
    expect(sonuc.bildirimler.single.icerik, 'Yeni plan');
    expect(sonuc.uyari, isNull,
        reason: 'başarılı güncellemede uyarı olmamalı');
    expect(await dizin(), contains('111'));
  });

  test('DIZINDE KIMLIK VAR AMA SISTEMDE ALARM YOK: BASARI SAYILMAZ', () async {
    // Kalıcı dizin yanlışlıkla bir kimlik taşıyor (ör. uygulama verisi
    // temizlendi, ya da alarm çoktan tetiklendi ve artık "bekleyen" değil).
    // Sistemde o kimlikle bir alarm YOK. Dizindeki kayıt varlık kanıtı
    // olmadığı için sonuç başarı saymamalı, iz ise silinmemeli.
    final e = HataEklentisi();
    e.bekleyen.clear();
    await diziniYaz(<String>['111']);

    final m = motor(e);
    e.kurulamayan.add(111); // kurulum da reddediliyor
    final sonuc = await m.uygula(plan([bild(111)]), secimNo: m.yeniSecim());

    expect(e.bekleyen, isEmpty, reason: 'sistemde alarm yok');
    expect(await dizin(), contains('111'),
        reason: 'dizin izi kaybolmamalı: kimlik bir gün yeniden denenecek');
    expect(sonuc.bildirimler, isEmpty,
        reason: 'dizindeki kayıt tek başına varlık kanıtı değildir');
    expect(sonuc.uyari, 'bildirim_kurulamadi');
  });

  test('HATALI IPTAL YABANCI BILDIRIMLERI TUTMAZ', () async {
    final e = HataEklentisi()..iptalHatasi = 5;
    e.bekleyen[yabanciKimlik] =
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 10, 20, 6);
    await diziniYaz(<String>['123']);
    final m = motor(e);

    await m.uygula(plan(const <PlanlananBildirim>[]), secimNo: m.yeniSecim());

    expect(e.bekleyen.containsKey(yabanciKimlik), isTrue);
    expect(e.iptalLog.where((c) => c == 'iptal:$yabanciKimlik'), isEmpty,
        reason: 'motor yalnızca kendi kimliklerini iptal edebilmeli');
    expect(await dizin(), isNot(contains('$yabanciKimlik')));
    expect(await dizin(), contains('123'),
        reason: 'kendi iptal edilemeyen kimliği izlenmeli');
  });
}