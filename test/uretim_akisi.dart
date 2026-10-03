// test/uretim_akisi.dart
//
// ÜRETİM AKIŞI TESTLERİNİN ORTAK TAKIMI.
//
// Bu dosya bir TEST dosyasi degildir (`_test.dart` ile bitmez); `flutter test`
// tarafindan calistirilmaz, yalnizca import edilir.
//
// IKI SORUMLULUK:
//
//   1) AĞIN TAMAMEN TESTTE KONTROLÜ. `HttpOverrides` ile sahte istemci
//      kurulur: soket acilmaz, gercek ag denenmez. Istekler kaydedilir ve
//      cevabi TEST verir — hangi cevabin ne zaman dondugunu test belirler.
//      Bu, "gecikmis cevap" gibi yaris senaryolarini rastgele gecikmeye
//      baglamadan tekrarlanabilir sekilde kurmanin tek yoludur.
//
//   2) GERCEK-ZAMAN BEKLEMEDEN URETIM AGACI. Ceviriler BELLEKTE verilir
//      (dosya okunmaz), bu yuzden testin `runAsync(Future.delayed(...))` ile
//      gercek sure beklemesine gerek kalmaz. Saat [SabitSaat] ile sabitlenir.
//      Sonuç: testler gerçek tarihe, gerçek saate ve dosya sistemine
//      bagli olmadan ayni sonucu verir.
//
// URETIMDEKI KOD YOLU BOZULMAZ: testler `AnaSayfa` widget'ini, gerçek
// `VakitDepo`, gerçek `http.get` (package:http) ve gerçek SharedPreferences
// mock deposunu kullanır. Sahte olan YALNIZCA taşımadır (ağ) ve çeviri
// dosyasının okunmasıdır.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'fixture/aladhan_ornek.dart';

// ---------------------------------------------------------------------------
// SAHTE AĞ
// ---------------------------------------------------------------------------

/// Testte açıkta duran bir ağ isteği.
class BekleyenIstek {
  BekleyenIstek(this.url);

  final Uri url;
  final Completer<HttpClientResponse> _cevap = Completer<HttpClientResponse>();

  bool get tamamlandi => _cevap.isCompleted;

  void tamamla(String govde, {int durum = 200}) {
    if (tamamlandi) return;
    _cevap.complete(SahteCevap(govde, durum));
  }

  Future<HttpClientResponse> cevabiBekle() => _cevap.future;

  /// Bu istek, [lat] / [lon] koordinatları ve [yil]-[ay] için atılmış mı?
  bool belongsTo({
    required String lat,
    required String lon,
    required int yil,
    required int ay,
  }) {
    final q = url.queryParameters;
    return q['latitude'] == lat &&
        q['longitude'] == lon &&
        q['year'] == '$yil' &&
        q['month'] == '$ay';
  }
}

/// Gelen istekleri kaydeder; cevabı test verir.
class AgKuyrugu {
  AgKuyrugu(this.govdeUretici);

  /// İstenen adrese göre geçerli bir Aladhan cevabı üretir.
  final String Function(Uri url) govdeUretici;

  final List<BekleyenIstek> istekler = <BekleyenIstek>[];

  /// [sira] numaralı (0 tabanlı) isteğe cevap verir.
  void cevapVer(int sira, {int durum = 200}) {
    final istek = istekler[sira];
    istek.tamamla(govdeUretici(istek.url), durum: durum);
  }

  /// Test biterken hiçbir istek açıkta kalmasın.
  void kalanlariTamamla() {
    for (final istek in istekler) {
      if (!istek.tamamlandi) {
        istek.tamamla('{"code":500,"status":"ERROR","data":[]}');
      }
    }
  }

  /// [yil]-[ay] ayı için, [konum] koordinatlarına atılmış isteklerin sıra
  /// numaraları.
  List<int> siralari(Konum konum, {required int yil, required int ay}) {
    final lat = konum.enlem.toStringAsFixed(4);
    final lon = konum.boylam.toStringAsFixed(4);
    return <int>[
      for (var i = 0; i < istekler.length; i++)
        if (istekler[i].belongsTo(lat: lat, lon: lon, yil: yil, ay: ay)) i,
    ];
  }

  /// [konum]/[yil]-[ay] için atılmış istek sayısı.
  ///
  /// "Aynı konum/ay için kaç ağ isteği atıldı?" sorusunun tek doğru
  /// cevabıdır; yan ay ön indirmesi gibi meşru istekleri saymaz.
  int istekSayisi(Konum konum, {required int yil, required int ay}) =>
      siralari(konum, yil: yil, ay: ay).length;

  /// [konum]/[yil]-[ay] için atılmış ve HENÜZ CEVAPLANMAMIŞ ilk isteğe
  /// cevap verir.
  ///
  /// Testler sıra numarasıyla değil, "hangi isteği cevaplıyorum" diye
  /// konuşur: ayın son günlerinde uygulama bir sonraki ayı önden indirdiği
  /// için sıra numaraları testten teste değişir.
  int cevapVerIlkBekleyen(
    Konum konum, {
    required int yil,
    required int ay,
    int durum = 200,
  }) {
    for (final i in siralari(konum, yil: yil, ay: ay)) {
      if (!istekler[i].tamamlandi) {
        cevapVer(i, durum: durum);
        return i;
      }
    }
    throw StateError('$konum için bekleyen istek yok ($yil-$ay)');
  }
}

Future<T> kontrolluAg<T>(AgKuyrugu kuyruk, Future<T> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (_) => _SahteAgIstemcisi(kuyruk),
  );
}

class _SahteAgIstemcisi implements HttpClient {
  _SahteAgIstemcisi(this.kuyruk);

  final AgKuyrugu kuyruk;

  @override
  Future<HttpClientRequest> openUrl(String metot, Uri url) async {
    final istek = BekleyenIstek(url);
    kuyruk.istekler.add(istek);
    return _SahteIstek(istek);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation cagri) => super.noSuchMethod(cagri);
}

class _SahteIstek implements HttpClientRequest {
  _SahteIstek(this._kayit);

  final BekleyenIstek _kayit;

  // package:http bu alanları isteği göndermeden önce yazar.
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = 0;
  @override
  bool persistentConnection = true;

  @override
  HttpHeaders get headers => SahteBasliklar();

  @override
  Future<HttpClientResponse> close() => _kayit.cevabiBekle();

  @override
  Future<HttpClientResponse> get done => _kayit.cevabiBekle();

  // package:http istek gövdesini (GET'te boş) bu sink'e yazar.
  @override
  void add(List<int> veri) {}

  @override
  void addError(Object hata, [StackTrace? yigin]) {}

  @override
  Future<void> addStream(Stream<List<int>> akis) => akis.drain<void>();

  @override
  dynamic noSuchMethod(Invocation cagri) => super.noSuchMethod(cagri);
}

/// package:http'nin kullandığı iki üyeyi (`set`, `forEach`) sunan sahte
/// başlıklar. `HttpHeaders` soyut sınıf olduğu için doğrudan kurulamaz.
class SahteBasliklar implements HttpHeaders {
  final Map<String, List<String>> _degerler = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _degerler[name.toLowerCase()] = <String>['$value'];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _degerler.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation cagri) => super.noSuchMethod(cagri);
}

class SahteCevap implements HttpClientResponse {
  SahteCevap(this.govde, this.durum);

  final String govde;
  final int durum;

  late final Uint8List _baytlar = Uint8List.fromList(utf8.encode(govde));

  @override
  int get statusCode => durum;

  @override
  int get contentLength => _baytlar.length;

  @override
  HttpHeaders get headers {
    final b = SahteBasliklar();
    b.set('content-type', ContentType.json.mimeType);
    return b;
  }

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  // Üst sınıfın parametre ADLARI aynı olmak zorunda; bu yüzden İngilizce
  // bırakıldı.
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> veri)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_baytlar).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation cagri) => super.noSuchMethod(cagri);
}

// ---------------------------------------------------------------------------
// ALADHAN CEVABI ÜRETİCİ
// ---------------------------------------------------------------------------

/// İstenen adres için geçerli bir aylık Aladhan cevabı üretir.
///
/// Gerçek API'nin davranışı taklit edilir: koordinat, ay, yıl ve istenen
/// yöntem istekten YANITLANIR; `meta.timezone` ve vakit saatleri konuma
/// özgüdür. Böylece testte üretilen veri, istenen konum için geçerli bir
/// cevaptır — doğrulayıcı reddetmez.
String aladhanCevabi(
  Uri url, {
  required Konum konum,
  required String saatDilimi,
  required Map<String, String> saatler,
  int varsayilanYontem = 13,
}) {
  final q = url.queryParameters;
  final enlem = double.parse(q['latitude']!);
  final boylam = double.parse(q['longitude']!);
  final yil = int.parse(q['year']!);
  final ay = int.parse(q['month']!);

  return aylikCevap(
    bilgi: FixtureBilgi(
      ad: konum.ad,
      ulke: konum.ulkeIso2,
      enlem: enlem,
      boylam: boylam,
      saatDilimi: saatDilimi,
      yil: yil,
      ay: ay,
      kaynakTarihi: '$yil-$ay',
    ),
    methodId: int.tryParse(q['method'] ?? '') ?? varsayilanYontem,
    gunSayisi: DateTime(yil, ay + 1, 0).day,
    sablonSaatler: saatler,
  );
}

/// Bir konum için üretilecek cevabın nitelikleri.
class KonumCevabi {
  const KonumCevabi(this.konum, this.saatDilimi, this.saatler);

  final Konum konum;
  final String saatDilimi;
  final Map<String, String> saatler;
}

/// Uzaklarda her koordinat için geçerli bir cevap üretilmesi gerekir.
const Map<String, KonumCevabi> konumCevaplari = <String, KonumCevabi>{
  '39.9334': KonumCevabi(
      konumAnkara,
      'Europe/Istanbul',
      <String, String>{
        'Fajr': '04:43',
        'Sunrise': '06:14',
        'Dhuhr': '12:59',
        'Asr': '16:29',
        'Maghrib': '19:23',
        'Isha': '20:53',
      }),
  '35.6762': KonumCevabi(
      konumTokyo,
      'Asia/Tokyo',
      <String, String>{
        'Fajr': '04:24',
        'Sunrise': '05:33',
        'Dhuhr': '11:46',
        'Asr': '15:19',
        'Maghrib': '17:52',
        'Isha': '19:22',
      }),
  '48.8566': KonumCevabi(
      konumParis,
      'Europe/Paris',
      <String, String>{
        'Fajr': '06:34',
        'Sunrise': '07:32',
        'Dhuhr': '13:44',
        'Asr': '17:12',
        'Maghrib': '20:16',
        'Isha': '21:51',
      }),
  '22.5726': KonumCevabi(
      konumKolkata,
      'Asia/Kolkata',
      <String, String>{
        'Fajr': '04:45',
        'Sunrise': '05:58',
        'Dhuhr': '11:44',
        'Asr': '15:12',
        'Maghrib': '18:00',
        'Isha': '19:15',
      }),
};

/// [AgKuyrugu] için doğrudan kullanılabilir üretici.
///
/// [konumCevaplari]de olmayan bir koordinat istenirse hata fırlatır: testin
/// sessizce yanlış ölçüm yapması, sessizce geçmekten iyidir.
String konumCevabiniUret(Uri url) {
  final c = konumCevaplari[url.queryParameters['latitude']];
  if (c == null) throw StateError('cevabı olmayan konum: $url');
  return aladhanCevabi(
    url,
    konum: c.konum,
    saatDilimi: c.saatDilimi,
    saatler: c.saatler,
  );
}

// ---------------------------------------------------------------------------
// ÇEVİRİ: BELLEKTE, DOSYA SİSTEMİNDEN OKUMADAN
// ---------------------------------------------------------------------------

/// Cevirileri bellekten veren yükleyici.
///
/// Gerçek `RootBundleAssetLoader` ceviri dosyalarını `rootBundle` üzerinden
/// okur; bu, testte GERÇEK dosya sistemi erişimi (ve dolayısıyla sabit
/// gerçek-zaman beklemesi) demektir. Testler metinlere değil widget
/// yapılarına baktığı için bu yükleyici yalnız birkaç anahtar döner.
class BellekCevirici extends AssetLoader {
  const BellekCevirici();

  // `exact_alarm_yok` ve kardeşleri ZORUNLUDUR: AnaSayfa motorun `uyari`
  // anahtarını ekranda `.tr()` ile gösterir. Bu anahtarlar bellekte de
  // gerçek metinle dönmüyorsa ekran HAM ANAHTARI gösterir ve "yanlış mesaj"
  // testleri yanlış sebeple geçer (metni bulamaz, yeşil sanır).
  static const Map<String, String> _turkce = <String, String>{
    'app_name': 'Namaz Vakitleri',
    'today_times': 'Bugünün Vakitleri',
    'retry': 'Tekrar dene',
    'data_load_error': 'Vakitler yüklenemedi.',
    'no_internet_city': 'İnternet yok, veri alınamadı.',
    'tasbih': 'Tesbih',
    // Bildirim durumu uyarıları. Sıralama motorun `uyariAgirlikSirasi`
    // ile aynıdır: en ağırı sonuç olarak bildirilir.
    'exact_alarm_yok': 'Tam zamanlı alarm izni yok — bildirimler yaklaşık '
        'zamanlı gösterilebilir',
    'bildirim_kurulamadi': 'Bazı vakit bildirimleri kurulamadı',
    'bildirim_iptal_edilemedi': 'Eski bir vakit bildirimi silinemedi',
  };

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      <String, dynamic>{..._turkce};
}

// ---------------------------------------------------------------------------
// ORTAK KONUM SENARYOLARI
// ---------------------------------------------------------------------------
//
// Koordinatlar hata riski taşıdığı için (yanlış koordinat, cevabın
// "koordinat besleşmi" gerekçesiyle reddedilmesine yol açar) tek yerde
// tanımlanır. `saatDilimi: ''` = kullanıcı bu şehri İLK KEZ seçiyor, dilim
// henüz bilinmiyor ve cevapla kesinleşecek.

/// Saat dilimi BİLİNEN konum (kullanıcı daha önce kullanmış).
const Konum konumAnkara = Konum(
  ad: 'Ankara',
  ulkeIso2: 'TR',
  enlem: 39.9334,
  boylam: 32.8597,
  saatDilimi: 'Europe/Istanbul',
);

/// Saat dilimi HENÜZ BİLİNMEYEN konum. Kesinleşince günü değiştirmez.
const Konum konumTokyo = Konum(
  ad: 'Tokyo',
  ulkeIso2: 'JP',
  enlem: 35.6762,
  boylam: 139.6503,
  saatDilimi: '',
);

/// Saat dilimi BİLİNEN ikinci konum: gerçek şehir değişikliği için.
const Konum konumParis = Konum(
  ad: 'Paris',
  ulkeIso2: 'FR',
  enlem: 48.8566,
  boylam: 2.3522,
  saatDilimi: 'Europe/Paris',
);

/// Saat dilimi bilinmeyen ve boylama dayalı tahminin GÜNÜ YANLIŞ bulduğu
/// konum. Bkz. [sabitAn].
const Konum konumKolkata = Konum(
  ad: 'Kolkata',
  ulkeIso2: 'IN',
  enlem: 22.5726,
  boylam: 88.3639,
  saatDilimi: '',
);

/// [sabitAn] hangi yıl/aya düşüyorsa testlerin beklentileri.
const int testYili = 2026;
const int testAyi = 9;

// ---------------------------------------------------------------------------
// TEST BAŞLANGICI
// ---------------------------------------------------------------------------

/// Test dosyasının `setUpAll`'unda çağrılır.
///
/// `EasyLocalization` cihazın dilimini `ensureInitialized` ile BİR KEZ okur
/// (`_deviceLocale` statik alanı); bu çağrı yapılmazsa `EasyLocalization`
/// kurulurken `LateInitializationError` verir.
Future<void> uretimTestiBaslat() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Sıralama önemli: `EasyLocalization.ensureInitialized` kayıtlı dili
  // SharedPreferences'tan okur, mock depo önce kurulmalıdır.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await EasyLocalization.ensureInitialized();
  // IANA saat dilimi veritabanı. Üretimde `main()` bunu yapar; testte
  // yapılmazsa `meta.timezone` "bilinmeyen" sayılır ve DOĞRU cevaplar bile
  // reddedilir (sessizce yanlış ölçüm).
  tzdata.initializeTimeZones();
}

// ---------------------------------------------------------------------------
// UYGULAMA DURUMU
// ---------------------------------------------------------------------------

/// Testin sabitleneceği MUTLAK an: 15 Eylül 2026 18:10 UTC.
///
/// Neden bu an?
///
///   * Ayın 25'inden sonrası değil: öyle günlerde uygulama sonraki ayı da
///     önden indirir ve testte bekleyen ek istekler oluşurdu.
///   * `DateTime` CİHAZIN yerel saat diliminde yorumlanır; bu yüzden UTC
///     mutlak anı seçiyoruz ve şehrin yerel saatini dilimine göre
///     düşünüyoruz.
///
/// Bu ande (18:10 UTC):
///
///   * Ankara (Europe/Istanbul, +03:00) → 15 Eylül 21:10.
///   * Tokyo (Asia/Tokyo, +09:00)       → 16 Eylül 03:10. Saat dilimi
///     bilinmediğinde kullanılan boylama tahmini (+09:18) da 16 Eylül'ü
///     verir: yani kesinleşince GÜN DEĞİŞMEZ → ek istek olmamalıdır.
///   * Kolkata (Asia/Kolkata, +05:30)   → 15 Eylül 23:40; boylama tahmini
///     (+05:53) ise 16 Eylül 00:03 der. Yani kesinleşince GÜN DEĞİŞİR →
///     "gün düzeltme" yolu ölçülebilir.
final DateTime sabitAn = DateTime.utc(2026, 9, 15, 18, 10);

/// Saati sabitler ve uygulamanın global tercihlerini varsayılana döndürür.
///
/// Her test kendi temiz cihazıyla başlar: kayıtlı konum, vakit önbelleği ve
/// hesaplama ayarları sıfırdan gelir.
void testOrtaminiSifirla() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  saatKaynagiDegistir(SabitSaat(sabitAn));
  aktifKonum.value = null;
  aktifUlkeKodu.value = 'TR';
  aktifHesaplamaYontemi.value = null;
  aktifAsrYontemi.value = AsrYontemi.standart;
  aktifYuksekEnlemAyaru.value = YuksekEnlemAyaru.orta;
  erkenUyariSuresi.value = 0;
  gunesDogumuBildirimiAcik.value = false;
}

/// Test bittiğinde global durumu üretim değerine döndürür.
void testOrtaminiKapat() {
  saatKaynagiDegistir(const GercekSaat());
  aktifKonum.value = null;
}

// ---------------------------------------------------------------------------
// WIDGET AKIŞI
// ---------------------------------------------------------------------------

/// Sahte saatte asenkron zinciri ilerletir.
///
/// `pump()` süre vermediği için HİÇBİR zamanlayıcı tetiklenmez; yalnız
/// mikro görevler (prefs okuma, cevap doğrulama, önbelleğe yazma) boşalır.
Future<void> akisIlerlet(WidgetTester tester, {int adim = 12}) async {
  for (var i = 0; i < adim; i++) {
    await tester.pump();
  }
}

/// Üretimdeki widget ağacını kurar: `EasyLocalization` + `MaterialApp` +
/// `AnaSayfa`, seçili konum [konum] olmak üzere.
Future<void> sayfayiAc(WidgetTester tester, Konum konum) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  aktifKonum.value = konum;

  await tester.pumpWidget(
    EasyLocalization(
      path: 'assets/i18n/ceviri',
      supportedLocales: const [Locale('tur'), Locale('eng')],
      fallbackLocale: const Locale('tur'),
      assetLoader: const BellekCevirici(),
      child: const MaterialApp(home: AnaSayfa()),
    ),
  );
  await akisIlerlet(tester);
}

/// Widget'ı kaldırır (timer'lar ve global dinleyiciler kapanır) ve açıkta
/// kalan isteklerin zaman aşımını tetikler.
Future<void> sayfayiKapat(WidgetTester tester, AgKuyrugu kuyruk) async {
  kuyruk.kalanlariTamamla();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 12));
}
