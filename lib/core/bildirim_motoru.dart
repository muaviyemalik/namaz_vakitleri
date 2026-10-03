// lib/core/bildirim_motoru.dart
//
// ZAMANLANMIŞ BİLDİRİM MOTORU.
//
// BU MOTORUN ÇÖZDÜĞÜ ÜÇ SORUN
//
// 1) `cancelAll()` KULLANILMAZ.
//    Önceden her veri yüklemesinde `bildirimServisi.cancelAll()` çağrılıyordu.
//    Bu, uygulamanın planladığı TÜM bildirimleri körlemesine siler ve
//    başka bir kod yolunun kurduğu bildirimleri de yok eder. Bunun yerine
//    bu motorun sahip olduğu kimlikler kayıt altında tutulur ve yalnız
//    onlar güncellenir. `kayitliKimlikler` listesi kalıcıdır; bir ayarlama
//    değişikliğinde artık gerekmeyen eski bildirimler kimlikleri tek tek
//    iptal edilir.
//
// 2) KİMLİKLER TARİH + VAKİT + TÜRDEN ÜRETİLİR.
//    Önceden kimlikler `100 + sıra`, `200 + sıra` idi: sabit ve gün
//    bağımsız. 1. ve 2. günün bildirimleri aynı kimliği alıyor, biri
//    diğerinin üstüne yazıyordu. Artık kimlik `tarih|vakit|tur`
//    üçlüsünden türetilen kararlı bir karmadır; aynı üçlü her zaman aynı
//    kimliği verir, farklı üçlüler çakışmaz.
//
// 3) GÜNEŞ DOĞUŞU "VAKİT GELDİ" BİLDİRİMİ DEĞİLDİR.
//    Güneş doğuşu bir namaz vakti değildir. Önceden aynı kanalı, aynı
//    metni ("Vakit Geldi!") kullanıyordu. Artık ayrı bir tür, ayrı bir
//    kanal ve açıkça adlandırılmış bir metin kullanır; varsayılan olarak
//    KAPALI dır ve kullanıcı ayarlardan açabilir.
//
// AYIRMA: `planla()` SAF bir fonksiyondur — ağa, dosyaya veya eklentiye
// dokunmaz, yalnız listede [PlanlananBildirim] döner. Test edilmesi
// bu yüzden mümkündür. Asıl işi yapan `BildirimMotoru.apply()` onu
// çağırır.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'aladhan_cevap.dart';
import 'saat.dart';

/// Bildirimin türü. Kimlik ve metin bu değerden türetilir.
enum BildirimTuru {
  /// Namaz vakti girdi.
  vakit,

  /// Erken uyarı.
  erkenUyari,

  /// Güneş doğuşu bilgisi. Namaz vakti DEĞİLDİR.
  gunesDogumu,
}

/// Bir bildirimin kimliğini `anahtar` metninden türetir.
///
int bildirimKimligi(String anahtar) {
  // 31 bit maskesi. Android bildirim kimliği imzalı 32 bit tamsayıdır;
  // sonucun daima 0..0x7fffffff aralığında olması gerekir.
  //
  // Maske BAŞLANGIÇ değerine de uygulanır: FNV ofset tabanı
  // 0x811c9dc5 = 2166136265 int32 sınırını AŞAR. Maskesiz başlanırsa
  // boş bir anahtar bile sınır dışı bir değer döner.
  const int maske = 0x7fffffff;
  int h = 0x811c9dc5 & maske;
  for (final birim in anahtar.codeUnits) {
    h = ((h ^ birim) * 0x01000193) & maske;
  }
  // 0, hiçbir bildirim kimliği olarak kullanılmaz.
  return h == 0 ? 1 : h;
}

/// Bir bildirimin kimlik anahtarı. Tarih + vakit + tür.
String kimlikAnahtari(DateTime tarih, String vakit, BildirimTuru tur) {
  final t = '${tarih.year.toString().padLeft(4, '0')}-'
      '${tarih.month.toString().padLeft(2, '0')}-'
      '${tarih.day.toString().padLeft(2, '0')}';
  // "namaz_vakitleri" öneki bu motorun kimliklerini diğer olası
  // kaynaklardan ayırır.
  return 'namaz_vakitleri|$t|$vakit|${tur.name}';
}

/// Planlanmış tek bir bildirim.
class PlanlananBildirim {
  final int kimlik;
  final String kimlikAnahtari;
  final tz.TZDateTime zaman;
  final String baslik;
  final String icerik;
  final BildirimTuru tur;
  final DateTime tarih;
  final String vakitAnahtari;

  const PlanlananBildirim({
    required this.kimlik,
    required this.kimlikAnahtari,
    required this.zaman,
    required this.baslik,
    required this.icerik,
    required this.tur,
    required this.tarih,
    required this.vakitAnahtari,
  });
}

/// Planlama sonucunun özeti — arayüz bunu kullanıcıya gösterebilir.
class PlanOzeti {
  final List<PlanlananBildirim> bildirimler;
  final int kapsananGunSayisi;
  final bool tamZamanli;
  final String? uyari;

  const PlanOzeti({
    required this.bildirimler,
    required this.kapsananGunSayisi,
    required this.tamZamanli,
    this.uyari,
  });
}

/// Alarm planını hesaplar. SAF fonksiyon.
class BildirimPlanlayici {
  const BildirimPlanlayici();

  /// En az kaç gün ileri planlanır.
  static const int enAzGun = 7;

  /// [cevir] parametresi, çeviri anahtarını metne çeviren fonksiyondur
  /// (uygulamada `.tr()`). Testte basit bir sözlük verilir; böylece bu
  /// katman easy_localization'a bağımlı olmaz.
  ///
  /// DÖNÜŞ: Gelecekteki tüm vakitler için bildirim listesi. Geçmiş
  /// vakitler kurulmaz.
  PlanOzeti planla({
    required Konum konum,
    required SehirSaati sehirSaati,
    required List<VakitGunu> gunler,
    required int erkenUyariDakika,
    required bool gunesDogumuBildirimiAcik,
    required String Function(String anahtar) cevir,
    String Function(String vakitAnahtari, int dakika) vakitAdiCevir = _varsayilanVakitAdi,
    String Function(int dakika, String vakitAdi)? erkenUyariMetni,
    String Function(String vakitAdi)? vakitMetni,
    String Function()? gunesDogumuMetni,
    bool tamZamanli = true,
  }) {
    final simdi = sehirSaati.simdi();
    if (simdi == null) {
      return const PlanOzeti(
        bildirimler: [],
        kapsananGunSayisi: 0,
        tamZamanli: true,
        uyari: 'saat_dilimi_cozulemedi',
      );
    }

    final sonuc = <PlanlananBildirim>[];

    // Tarihleri sırayla işle ki "en az 7 gün" kuralı ölçülebilir olsun.
    final sirali = [...gunler]..sort((a, b) => a.tarih.compareTo(b.tarih));
    var kapsananGun = 0;

    for (final gun in sirali) {
      if (sehirSaati.saatDilimiCozulemedi) break;

      // Gün başlangıcı: seçili şehrin o günü, gece yarısı.
      final gunBaslangic = tz.TZDateTime(
          sehirSaati.location!, gun.yil, gun.ay, gun.gun);

      // Bu gün artık geçtiyse (şehirde şimdi bu günden sonraysa) atla.
      //
      // DİKKAT: `kapsananGun` sayacı BURADA artırılmaz. Sayaç yalnız
      // planlanan günleri sayar. Önceden kontrol `continue`'dan sonra
      // geldiği için geçmiş günler sayacı tüketiyor ve 7 güne ulaşılamıyordu.
      if (!simdi.isBefore(gunBaslangic.add(const Duration(days: 1)))) {
        continue;
      }
      if (kapsananGun >= enAzGun) break;
      kapsananGun++;

      for (final alan in VakitAlani.sirali) {
        // Güneş doğuşu ayrı türdür ve varsayılan kapalıdır.
        final tur = alan == VakitAlani.sunrise
            ? BildirimTuru.gunesDogumu
            : BildirimTuru.vakit;

        if (tur == BildirimTuru.gunesDogumu && !gunesDogumuBildirimiAcik) {
          continue;
        }

        // Şehrin DUVAR SAATİ doğrudan kurulur. Cihaz saat diliminde
        // DateTime yapıp TZDateTime.from ile dönüştürmek yanlıştır: o
        // işlem aynı anı hedef dilimde yeniden ifade eder, saat dilimi
        // farkını ortadan kaldırmaz.
        final vakitZamani = sehirSaati.duvarSaati(
          gun.saatler[alan.anahtar]!,
          tarih: DateTime(gun.yil, gun.ay, gun.gun),
        );
        if (vakitZamani == null) continue; // geçersizse kurma, sessizce atla
        if (!vakitZamani.isAfter(simdi)) continue; // geçmiş vakit

        final vakitAdi = vakitAdiCevir(alan.anahtar, erkenUyariDakika);
        final a = kimlikAnahtari(gun.tarih, alan.anahtar, tur);
        sonuc.add(PlanlananBildirim(
          kimlik: bildirimKimligi(a),
          kimlikAnahtari: a,
          zaman: vakitZamani,
          baslik: cevir(tur == BildirimTuru.gunesDogumu
              ? 'notif_sunrise_title'
              : 'notif_time_reached'),
          icerik: tur == BildirimTuru.gunesDogumu
              ? (gunesDogumuMetni?.call() ?? cevir('notif_sunrise_body'))
              : (vakitMetni?.call(vakitAdi) ??
                  cevir('notif_time_reached_body')),
          tur: tur,
          tarih: gun.tarih,
          vakitAnahtari: alan.anahtar,
        ));

        // Erken uyarı: AYRI bir tür ve ayrı bir kanal. Kullanıcı erken
        // uyarıyı kapatıp vakit bildirimini açık bırakabilmeli.
        if (tur == BildirimTuru.vakit && erkenUyariDakika > 0) {
          final erkenZaman = vakitZamani.subtract(Duration(minutes: erkenUyariDakika));
          if (erkenZaman.isAfter(simdi)) {
            final ea = kimlikAnahtari(gun.tarih, alan.anahtar, BildirimTuru.erkenUyari);
            sonuc.add(PlanlananBildirim(
              kimlik: bildirimKimligi(ea),
              kimlikAnahtari: ea,
              zaman: erkenZaman,
              baslik: cevir('early_warning'),
              icerik: erkenUyariMetni?.call(erkenUyariDakika, vakitAdi) ??
                  '$erkenUyariDakika $vakitAdi',
              tur: BildirimTuru.erkenUyari,
              tarih: gun.tarih,
              vakitAnahtari: alan.anahtar,
            ));
          }
        }
      }
    }

    return PlanOzeti(
      bildirimler: sonuc,
      kapsananGunSayisi: kapsananGun,
      tamZamanli: tamZamanli,
    );
  }

  static String _varsayilanVakitAdi(String vakitAnahtari, int _) => vakitAnahtari;
}

/// Bildirim planına yazma hakkının SIRASINI ve son seçim numarasını tutar.
///
/// NEDEN MOTOR ÖRNEĞİNDE DEĞİL?
///
/// Motorun yönettiği kaynaklar UYGULAMA GENELİNDE TEK kopyadır: bildirim
/// eklentisindeki bekleyen bildirimler ve `SharedPreferences` içindeki
/// kalıcı kimlik dizini. `AnaSayfa` her açılışta kendi `BildirimMotoru`
/// örneğini kurar; iki ekran aynı anda varsa İKİ motor ama TEK eklenti ve
/// TEK kalıcı dizin vardır.
///
/// Önceden sıra ve sayaç motor örneğinde tutuluyordu. Bu, TEK motor
/// içindeki çakışmayı doğru çözüyordu ama İKİ MOTOR arasındakini hiç
/// görmüyordu: yeni ekran sıfırdan başladığı için, KALDIRILMIŞ ekranın geç
/// kalan planı "daha yeni seçim yok" diye kendini geçerli sayıyor ve yeni
/// seçimin üzerine yazıyordu. Sonuç: ekranda Paris yarken cihazda Ankara'nın
/// alarmları bekliyor, kalıcı dizin eski planı anlatıyor.
///
/// SINIR: bu kural AYNI kaynak üzerinde yazan motorlar arasında geçerlidir.
/// Farklı bir eklenti ya da ayrı bir kalıcı dizin kullanan motor kendi
/// sırasını verir (testler böyle yapar).
///
/// [BildirimMotoru.sira] ZORUNLUDUR: motor sırasını kendisi yaratmaz.
/// Ortak bir kaynağa yazan iki motor aynı [PlanSirasi]'yı paylaşmalıdır;
/// paylaşmazlarsa sıra ve sayaç motor örneklerinde kalır ve yarış sessizce
/// geri gelir.
class PlanSirasi {
  int _sonSecim = 0;

  /// Sıradaki uygulamanın bekleyeceği future. TAMSAMLA olmadan başlatılmaz:
  /// `sirala` çağrısının YAPILDIĞI yerde yaratılır. Yapılandırmada
  /// `Future.value()` ile doldurulsaydı bu nesne, çağrılardan ÖNCE yaratıldığı
  /// zaman diliminde tamamlanmış olurdu ve bekleyen çağrı kendi zaman
  /// diliminde ilerleyemezdi (testte her test ayrı bir bölge alır).
  Future<void>? _kilit;

  int get sonSecim => _sonSecim;

  /// Yeni bir plan isteği için sonraki numarayı üretir.
  ///
  /// Numaralar UYGULAMA GENELİNDE artar. Çağıran tarafın kendi sayacı
  /// olsaydı, iki ekran da 1 numarasını alır ve "hangisi yeni?" sorusu
  /// cevapsız kalırdı.
  int yeniSecim() {
    _sonSecim++;
    return _sonSecim;
  }

  void secimiKaydet(int secimNo) {
    if (secimNo > _sonSecim) _sonSecim = secimNo;
  }

  /// [secimNo] numaralı plan artık söz söyleyebilir mi?
  bool gecmisMi(int secimNo) => secimNo < _sonSecim;

  /// [islem]'i sıraya alır; sıra, çağrı geliş sırasıdır.
  Future<T> sirala<T>(Future<T> Function() islem) async {
    final oncedekiler = _kilit;
    final bitti = Completer<void>();
    _kilit = bitti.future;
    if (oncedekiler != null) await oncedekiler;
    try {
      return await islem();
    } finally {
      bitti.complete();
    }
  }
}

/// Hata uyarılarının ağırlık sırası: EN AĞIR İLK.
///
/// Sıralama "ne kadar kötü"ye göre, çünkü tek bir `uyari` alanı var:
///
///   1) `bildirim_kurulamadi` — bildirimler KURULMADI. Kullanıcı vakit
///      gelmeyecek; en ağırı budur.
///   2) `bildirim_iptal_edilemedi` — artık gerekmeyen bir bildirim SİSTEMDE
///      kaldı ve izi korunuyor; sonraki uygulamada tekrar denenecek.
///   3) `exact_alarm_yok` — hepsi kuruldu ama YAKLAŞIK; teslim edilir,
///      yalnız tam zamanlı değildir.
const List<String> uyariAgirlikSirasi = <String>[
  'bildirim_kurulamadi',
  'bildirim_iptal_edilemedi',
  'exact_alarm_yok',
];

/// [mevcut] ile [yeni] arasından daha ağır uyarıyı döndürür.
///
/// [mevcut] listede değilse (ör. planlayıcının `saat_dilimi_cozulemedi`
/// uyarısı) [yeni] kazanır: o uyarı bu aşamada daha somut bir bilgidir.
String? agirUari(String? mevcut, String yeni) {
  final y = uyariAgirlikSirasi.indexOf(yeni);
  if (y < 0) return mevcut ?? yeni;
  final m = uyariAgirlikSirasi.indexOf(mevcut ?? '');
  if (m < 0) return yeni;
  return y < m ? yeni : mevcut;
}

/// Zamanlanmış bildirimleri sisteme yazan motor.
class BildirimMotoru {
  BildirimMotoru({
    required this.eklenti,
    required this.planlayici,
    required PlanSirasi sira,
    Future<SharedPreferences> Function()? tercih,
  })  : _tercih = tercih ?? SharedPreferences.getInstance,
        _sira = sira;

  final FlutterLocalNotificationsPlugin eklenti;
  final BildirimPlanlayici planlayici;
  final Future<SharedPreferences> Function() _tercih;

  /// Motorun yönettiği kaynak üzerinde söz söyleme sırası. Aynı kaynağa
  /// yazan motorlar aynı örneği paylaşmalıdır (bkz. [PlanSirasi]).
  final PlanSirasi _sira;

  /// Bu motorun yönettiği kimlikler.
  static const String _kimlikDiziniAnahtari = 'bildirim_motoru_kimlikleri';

  static const String vakitKanal = 'ezan_kanali_arka_plan';
  static const String erkenUyariKanal = 'erken_uyari_kanali';
  static const String gunesDogumuKanal = 'gunes_dogumu_kanali';

  // -- UYGULAMA SIRASI --
  //
  // `uygula` uzun bir yoldur (tercih okuma → her bildirim için kurulum →
  // gereksizleri iptal → kalıcı listeyi yazma) ve çağıran taraftan birden
  // fazla kez ÖRTÜŞMELİ ÇAĞRILABİLİR: her veri yüklemesinde, her hesap
  // ayarı değişiminde, her dil değişiminde.
  //
  // Örtüşen iki uygulama birbirini bozuyordu:
  //   * ikisi de "eskiden kalan kimlikler" listesini aynı anda okuyor,
  //   * birinin iptal ettiği kimliği diğeri yeniden kurabiliyor,
  //   * kalıcı liste son yazanın planını anlatıyordu; yani bekleyen
  //     bildirimler yeni, liste eski plandan kalabiliyordu.
  //
  // İki kural birlikte bunu kapatır:
  //   1) KİLİT: uygulamalar sırayla çalışır, birbirine karışamaz.
  //   2) SEÇİM NUMARASI: [uygula]'ya verilen numara, planın hangi seçime
  //      ait olduğudur. Numarası daha küçükse plan ARTARZAMAN GEÇ KALMIŞ
  //      demektir (izin sorgusu gecikmiştir) ve hiçbir yazma yapılmadan
  //      bırakılır; sözü daha yeni seçim söyler.
  //
  // İkisi de [PlanSirasi] içindedir ve orası motor ÖRNEĞİNE değil motorun
  // yönettiği KAYNAĞA aittir: iki ayrı motor aynı eklente ve aynı kalıcı
  // dizini yazdığı için aralarında da geçerlidir.

  /// Yeni bir plan isteği için seçim numarası üretir (uygulama genelinde artar).
  int yeniSecim() => _sira.yeniSecim();

  /// [secimNo] hâlâ son geçerli seçim mi?
  bool gecmisSecimMi(int secimNo) => _sira.gecmisMi(secimNo);

  /// [ozet]i sisteme yazar ve bu motorun yönettiği kimlikleri günceller.
  ///
  /// `cancelAll()` ÇAĞRILMAZ. Önceki plandan kalan ve yeni planda
  /// bulunmayan kimlikler tek tek iptal edilir.
  ///
  /// [secimNo] bu planın ait olduğu SEÇİM numarasıdır ([yeniSecim] ile
  /// alınır). Daha küçük bir numara GEÇ KALMIŞ bir plandır: hiçbir şeye
  /// dokunmadan bırakılır, çünkü artık sözü daha yeni bir seçim söyler.
  /// Uygulamalar birbirine karışmasın diye SIRAYA alınır: ikinci bir
  /// uygulama, birincisi bitene kadar bekler.
  Future<PlanOzeti> uygula(PlanOzeti ozet, {required int secimNo}) async {
    // Numara bekleme başlamadan ÖNCE kaydedilir: çağrı geliş sırası, numara
    // sırasıyla aynı olmazsa geç kalan bir çağrı söz sahibi olur.
    _sira.secimiKaydet(secimNo);

    return _sira.sirala(() async {
      if (_sira.gecmisMi(secimNo)) {
        // Daha yeni bir seçim var: bu plan sözü söylemez. Uygulansaydı
        // yeni planın bildirimlerini üzerine yazardı.
        debugEkle('geç kalan plan uygulanmadı '
            '(seçim $secimNo < ${_sira.sonSecim})');
        return ozet;
      }

      return _uygulaKilitli(ozet);
    });
  }

  /// Gün verisi temizlendiğinde başlamış yazmanın arkasına boş plan koyar.
  /// Yeni plan izin beklerken bile bu temizlik atlanmaz; aynı kuyruktaki
  /// yeni plan daima bundan sonra uygulanır. İptal hataları ve sahiplik
  /// kaydı normal uygulama yoluyla korunur.
  Future<PlanOzeti> planiTemizle({required int secimNo}) {
    _sira.secimiKaydet(secimNo);
    return _sira.sirala(() => _uygulaKilitli(const PlanOzeti(
      bildirimler: [],
      kapsananGunSayisi: 0,
      tamZamanli: true,
    )));
  }

  /// Tam zamanlı alarm izni var mı?
  ///
  /// Android 12+ (API 31) tam zamanlı alarmı ayrı bir izinle kısıtlar.
  /// İzin yoksa `zonedSchedule(exactAllowWhileIdle)` PlatformException
  /// fırlatır. Bu durumda motor YAKLAŞIK moda düşer ve [PlanOzeti.uyari]
  /// ile bunu kullanıcıya bildirir; yaklaşık alarm "tam zamanlı" gibi
  /// sunulmaz.
  ///
  /// DİKKAT: Bu bir eklenti çağrısıdır ve GEÇİKEBİLİR. Çağıran taraf bu
  /// sorgudan sonra kendi seçim numarasını yeniden denetlemelidir.
  Future<bool> tamZamanliIzinVar() async {
    try {
      final e = eklenti.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (e == null) return true; // iOS/desktop: kısıt yok
      return await e.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Tam zamanlı alarm iznini ister (SCHEDULE_EXACT_ALARM yaklaşımı).
  ///
  /// Bu, kullanıcıya sistem ayarlarında açık bir seçim sunar. `USE_EXACT_ALARM`
  /// seçilmemiştir: o izin kullanıcı onayı istemez ve mağaza politikası
  /// açısından yalnız alarm/saatlik uygulamaları kapsar; gerekçesiz
  /// kullanımı Play tarafından reddedilme riski taşır.
  Future<bool> tamZamanliIzinIste() async {
    try {
      final e = eklenti.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (e == null) return true;
      await e.requestExactAlarmsPermission();
      return await e.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [ozet]i sisteme yazar ve bu motorun yönettiği kimlikleri günceller.
  ///
  /// `cancelAll()` ÇAĞRILMAZ. Önceki plandan kalan ve yeni planda
  /// bulunmayan kimlikler tek tek iptal edilir.
  ///
  /// SONUÇ GERÇEĞİ YANSITIR. Üç kural birlikte bunu sağlar:
  ///
  ///   * KURULAMAYAN SAYILMAZ. Bir bildirim ancak `zonedSchedule` GERÇEKTEN
  ///     başarılı olduğunda kurulmuş sayılır. Exact reddedilip inexact de
  ///     reddedilirse kimlik ne kalıcı dizine yazılır ne de sonuçta
  ///     başarıyla raporlanır; `uyari` ile hata bildirilir. (Önceden
  ///     `planlanan.add` denemeden ÖNCE çalışıyordu: sistemde hiç olmayan
  ///     bir bildirim "yönetiliyordu".)
  ///
  ///   * İPTAL EDİLEMEYEN UNUTULMAZ. İptali başarısız olan kimlik hâlâ
  ///     sistemdedir, dolayısıyla kalıcı dizinde TUTULUR ve sonraki her
  ///     uygulamada tekrar denenir. (Önceden hata yutuluyor, kimlik yine de
  ///     dizinden siliniyor ve kullanıcının seçmediği şehrin alarmı sonsuza
  ///     dek kalıyordu.)
  ///
  ///   * PLANDA OLAN AMA KURULAMAYAN İZİ KAYBEDİZ. Yeni planda bulunan bir
  ///     kimlik önceki plandan da kayıtlıysa sistemde zaten vardır; kurulum
  ///     bu kez de reddedilse bile izi korunur.
  ///
  /// SAHİPLİK İZİ ≠ BAŞARI. Bu ikisi BİRBİRİNE KARIŞTIRILMAZ ve bilinçli
  /// olarak ayrı hesaplanır:
  ///
  ///   * KALICI DİZİN "sahiplik"tir: motorun TAKİP ETTİĞİ her alarm.
  ///     İptal edilemeyen artıklar ve güncellenemeyen eski kayıtlar da
  ///     burada kalır ki bir daha aranabilsin.
  ///
  ///   * [PlanOzeti.bildirimler] "başarı"dır: bu uygulamanın DEĞERLERİ
  ///     sistemde yazan bildirimler. Bir kimlik dizinde bulunmak, sistemde
  ///     O DEĞERLERLE bir alarm bulunduğunu GÖSTERMEZ: kimlik
  ///     tarih+vakit+tür'den türer, saat ve metinler değişebilir. Güncelleme
  ///     reddedilirse sistemde ESKİ değerler durur; yeni değerleri başarı
  ///     diye raporlamak sonucu gerçeğin tersine çevirirdi.
  Future<PlanOzeti> _uygulaKilitli(PlanOzeti ozet) async {
    final h = await _tercih();
    final eski = (h.getStringList(_kimlikDiziniAnahtari) ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();

    final yeniKumeler = <String, String>{
      vakitKanal: 'notif_channel_bg_name',
      erkenUyariKanal: 'notif_channel_early_name',
      gunesDogumuKanal: 'notif_channel_sunrise_name',
    };
    for (final e in yeniKumeler.keys) {
      await eklenti
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              e,
              // Kanal adı sistemde bir kez oluşturulur ve sonra
              // değiştirilemez; Android bunu desteklemez. Başlık ve
              // içerik ise her planda güncel dilden üretilir.
              e == vakitKanal
                  ? 'Vakit'
                  : e == erkenUyariKanal
                      ? 'Erken uyarı'
                      : 'Güneş doğuşu',
              importance: Importance.max,
            ),
          );
    }

    // Bu planın İSTEDİĞİ kimlikler: ne olursa olsun artık gerekmeyen
    // bildirimlerin iptal listesi bundan türetilir.
    final hedef = <int>{for (final b in ozet.bildirimler) b.kimlik};

    // Gerçekten kurulanlar.
    final kurulan = <int>{};
    var tamZamanliBasarili = ozet.tamZamanli;
    String? uyari = ozet.uyari;

    for (final b in ozet.bildirimler) {
      final detay = _detay(b);
      var kuruldu = false;

      if (tamZamanliBasarili) {
        try {
          await eklenti.zonedSchedule(
            id: b.kimlik,
            title: b.baslik,
            body: b.icerik,
            scheduledDate: b.zaman,
            notificationDetails: detay,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: '${b.tur.name}|${b.vakitAnahtari}|${b.kimlikAnahtari}',
          );
          kuruldu = true;
        } on PlatformException {
          // İzin yok ya da cihaz reddetti. Yaklaşık moda düşüyoruz.
          // Uyarının KENDİSİ döngüden sonra, sonuca bağlı olarak üretilir
          // (bkz. "YAKLAŞIK MOD BİLDİRİMİ"): buradaki tek iş yola çıkmak.
          tamZamanliBasarili = false;
        }
      }

      if (!kuruldu) {
        try {
          await eklenti.zonedSchedule(
            id: b.kimlik,
            title: b.baslik,
            body: b.icerik,
            scheduledDate: b.zaman,
            notificationDetails: detay,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: '${b.tur.name}|${b.vakitAnahtari}|${b.kimlikAnahtari}',
          );
          kuruldu = true;
        } catch (e) {
          // Yaklaşık kurulum da reddedildi: bu bildirim KURULMADI. Kimliği
          // kayıt altına alınmaz; sonuç da onu başarı saymaz.
          uyari = agirUari(uyari, 'bildirim_kurulamadi');
          debugEkle('bildirim planlanamadı ${b.kimlik}: $e');
        }
      }

      if (kuruldu) kurulan.add(b.kimlik);
    }

    // YAKLAŞIK MOD BİLDİRİMİ: uyarı, KULLANILAN YOLA DEĞİL SONUCA BAĞLIDIR.
    //
    // Yaklaşık moda iki farklı yolla girilir ve ikisi de aynı sonucu
    // üretir: alarmlar kurulur ama tam zamanlı değildir.
    //
    //   1) İzin BAŞTAN yok: döngü exact'i hiç denemez, `tamZamanli`
    //      baştan `false` gelir.
    //   2) Exact DENENDİ ve reddedildi: `on PlatformException` yakalar.
    //
    // Önceden uyarı yalnız 2. yolda üretiliyordu (döngü içinde). 1. yolda
    // döngü hiç girmediği için `uyari` null kalıyordu: alarmlar yaklaşık
    // kurulmuşken ekran sessizce geçiyordu, "tam zamanlı alarm yok" bilgisi
    // kayboluyordu. İki yol TUTARLI OLMADI.
    //
    // Bu yüzden karar yolundan değil SONDAN alınır: kurulan bir alarm varsa
    // ve tam zamanlı değilsek, yaklaşık mod bildirilir. AĞIRLIK SİRASI
    // devreye girer: kurulum/iptal hatası varsa O AĞIRLIKTIR ve bu mesaj
    // onun ALTINDA kalır — hata, yaklaşık-mod mesajıyla ÖRTÜLMEZ.
    if (kurulan.isNotEmpty && !tamZamanliBasarili) {
      uyari = agirUari(uyari, 'exact_alarm_yok');
    }

    // Bu uygulamanın sonunda SİSTEMDE GERÇEKTEN bulunması gereken bildirimler:
    // yeni kurulanlar + yeni planda olup önceki plandan da kayıtlı olanlar
    // (kurulum reddedilse bile sistemde zaten vardırlar).
    //
    // DİKKAT: bu küme SAHİPLİK içindir, BAŞARI değil. Kimlik dizinde
    // bulunmak, sistemde o değerlerle alarm bulunduğunu kanıtlamaz.
    final izlenen = <int>{...kurulan, ...hedef.intersection(eski)};

    // Artık gerekmeyen bildirimleri iptal et. Yalnız BU MOTORUN
    // yönettiği kimlikler taranır.
    final iptalEdilemeyenler = <int>{};
    for (final kimlik in eski.difference(hedef)) {
      try {
        await eklenti.cancel(id: kimlik);
      } catch (e) {
        // Hâlâ sistemde duruyor: izi silmek onu bir daha hiç aranamaz
        // yapardı. Dizinde tutulur, sonraki uygulamada yeniden denenir.
        iptalEdilemeyenler.add(kimlik);
        uyari = agirUari(uyari, 'bildirim_iptal_edilemedi');
        debugEkle('bildirim iptal edilemedi $kimlik: $e');
      }
    }

    // Sahiplik dizini: takip edilen HER motor bildirimi. Eksik kalan her şey
    // burada, sonraki uygulamada tekrar denebilsin diye.
    final sahiplenilen = <int>{...izlenen, ...iptalEdilemeyenler};
    await h.setStringList(
        _kimlikDiziniAnahtari, sahiplenilen.map((e) => e.toString()).toList());

    return PlanOzeti(
      // Yalnız bu uygulamanın DEĞERLERİNİ sistemde yazdığı bildirimler.
      // `hedef ∩ eski` kümesi bilinçli olarak DIŞARIDA: o kimlik sistemde
      // ESKİ zaman/metinlerle duruyor, yenisi reddedildi.
      bildirimler:
          ozet.bildirimler.where((b) => kurulan.contains(b.kimlik)).toList(
              growable: false),
      kapsananGunSayisi: ozet.kapsananGunSayisi,
      tamZamanli: tamZamanliBasarili,
      uyari: uyari,
    );
  }

  /// Uygulama güncellendiğinde/cihaz yeniden başladığında planın geri
  /// geldiğini doğrular.
  ///
  /// `ScheduledNotificationBootReceiver` manifestte tanımlıysa Android,
  /// `BOOT_COMPLETED` ve `MY_PACKAGE_REPLACED` sonrası planlanmış
  /// bildirimleri kendiliğinden geri getirir. Bu metot o geri gelen
  /// planın gerçekten var olduğunu sayar.
  Future<int> planlananSayisi() async {
    try {
      final list = await eklenti.pendingNotificationRequests();
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  /// Yalnız bu motorun yönettiği bildirimleri iptal eder.
  Future<void> kendiPlaniniIptalEt() async {
    final h = await _tercih();
    final ids = (h.getStringList(_kimlikDiziniAnahtari) ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    for (final id in ids) {
      try {
        await eklenti.cancel(id: id);
      } catch (_) {}
    }
    await h.remove(_kimlikDiziniAnahtari);
  }

  NotificationDetails _detay(PlanlananBildirim b) {
    final kanal = switch (b.tur) {
      BildirimTuru.vakit => vakitKanal,
      BildirimTuru.erkenUyari => erkenUyariKanal,
      BildirimTuru.gunesDogumu => gunesDogumuKanal,
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        kanal,
        kanal,
        channelDescription: null,
        importance: b.tur == BildirimTuru.gunesDogumu
            ? Importance.defaultImportance
            : Importance.max,
        priority: b.tur == BildirimTuru.gunesDogumu
            ? Priority.defaultPriority
            : Priority.high,
        // Ayrı kanallar kullanıcıya ayrı kapatma imkânı verir.
        // Güneş doğuşu varsayılan olarak kapalıdır.
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }
}

void debugEkle(String mesaj) {
  assert(() {
    // ignore: avoid_print
    print('[bildirim] $mesaj');
    return true;
  }());
}
