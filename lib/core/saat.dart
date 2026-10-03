// lib/core/saat.dart
//
// ZAMANIN TEK KAYNAĞI.
//
// NEDEN BU DOSYA VAR?
//
// Uygulama önceden namaz vakitlerinin "bugününü" ve geri sayımı
// `DateTime.now()` ile kuruyordu. `DateTime.now()` CİHAZIN yerel
// saat dilimini kullanır. Kullanıcı Türkiye'deki bir telefonla New York
// seçtiğinde cihaz "25 Eylül 23:40", New York ise "25 Eylül 16:40"
// diyor. Aylık API cevabından `now.day - 1` indeksi seçilirse iki şehir
// farklı günlerdeyken yanlış günün vakitleri gösterilir.
//
// DÜZELTME: Zaman daima SEÇİLEN KONUMUN saat diliminde hesaplanır.
// `DateTime.now()` yalnızca "şu an kaç" sorusunun altındaki mutlak anı
// verir; ondan sonraki her adım seçili şehrin saat dilimindedir.
//
// BU DOSYA TEST EDİLEBİLİR Mİ? Evet. [Saat] arayüzü üretimde
// [GercekSaat], testte [SabitSaat] ile doldurulur. Böylece "gece
// yarısı", "yıl sonu", "yaz saati geçişi" senaryoları gerçek saate
// bağlı olmadan test edilir.

import 'package:timezone/timezone.dart' as tz;

/// Zaman sağlayıcı.
///
/// Uygulamadaki hiçbir katman `DateTime.now()` çağırmamalı; hepsi bu
/// arayüz üzerinden zaman almalı. Testler [SabitSaat] ile deterministik
/// sonuç alır.
abstract class Saat {
  /// Cihazın o anki zamanı.
  ///
  /// Dönen değer CİHAZIN yerel saat dilimindedir ve mutlak anı temsil
  /// eder. Gün hangi şehre aitse o şehrin günü DEĞİLDİR; gün
  /// [SehirSaati] içinde belirlenir.
  DateTime simdi();

  /// IANA saat dilimi adını `tz.Location`'a çevirir.
  ///
  /// Dilim veritabanında yoksa `null` döner. Çağıran taraf bu durumda
  /// sessizce bir yere sapmamalı, kullanıcıya hata göstermelidir.
  tz.Location? konumBul(String iana);

  /// Bu anın, verilen konumda okunduğu hâli.
  ///
  /// Bu, "seçili şehirde şu an kaç" sorusunun tek doğru cevabıdır.
  tz.TZDateTime sehirdeSimdi(tz.Location konum) => tz.TZDateTime.from(simdi(), konum);
}

/// Üretimde kullanılan saat: gerçek sistem saati.
class GercekSaat implements Saat {
  const GercekSaat();

  @override
  DateTime simdi() => DateTime.now();

  @override
  tz.Location? konumBul(String iana) {
    if (iana.trim().isEmpty) return null;
    try {
      return tz.getLocation(iana.trim());
    } catch (_) {
      // Bilinmeyen/geçersiz IANA adı. Sessizce yere sapmak yerine
      // çağıran tarafa bildirilir.
      return null;
    }
  }

  @override
  tz.TZDateTime sehirdeSimdi(tz.Location konum) =>
      tz.TZDateTime.from(simdi(), konum);
}

/// Testte kullanılan sabit saat.
///
/// [simdi] verilen anda sabit durur; [ilerlet] ile kontrollü biçimde
/// ileri alınabilir. Bu, "gece yarısı geçişi", "31 Aralık → 1 Ocak"
/// gibi senaryoları gerçek zamanı beklemeden test etmeyi sağlar.
class SabitSaat implements Saat {
  DateTime _an;
  final Map<String, tz.Location?> _cozulenKanon = <String, tz.Location?>{};

  SabitSaat(DateTime baslangic) : _an = baslangic;

  @override
  DateTime simdi() => _an;

  /// Saati [sure] kadar ileri alır (veya geriye).
  void ilerlet(Duration sure) => _an = _an.add(sure);

  @override
  tz.Location? konumBul(String iana) {
    if (iana.trim().isEmpty) return null;
    if (_cozulenKanon.containsKey(iana)) return _cozulenKanon[iana];
    tz.Location? sonuc;
    try {
      sonuc = tz.getLocation(iana.trim());
    } catch (_) {
      sonuc = null;
    }
    _cozulenKanon[iana] = sonuc;
    return sonuc;
  }

  @override
  tz.TZDateTime sehirdeSimdi(tz.Location konum) =>
      tz.TZDateTime.from(simdi(), konum);
}

/// SEÇİLİ ŞEHRİN SAATİ — gün ve duvar saati üretiminin tek yolu.
///
/// Bu sınıfın varlık sebebi bir kuraldır:
///
///   Bir vakti önce cihaz saat diliminde `DateTime` yapıp sonra
///   `TZDateTime.from` ile dönüştürmek YANLIŞTIR.
///
/// `TZDateTime.from` bir zamanı başka bir dilime "çevirmez", aynı anı
/// hedef dilimde yeniden ifade eder. Cihazda "05:30" olan bir saat
/// New York'a çevrildiğinde o da "05:30 New York" olur; iki şehir arası
/// fark kaybolmaz, üstelik kaybolmaması gereken kayıp oluşur.
///
/// DOĞRU YOL: şehrin saat dilimi doğrudan verilir.
///
///     TZDateTime(sehirSaatDilimi, yil, ay, gun, saat, dakika)
///
/// Bu, şehrin duvar saatini o dilimde sıfırdan kurar. Gün de aynı
/// şekilde belirlenir: cihazın günü değil, şehrin günü.
class SehirSaati {
  SehirSaati({
    required this.konum,
    required this.saat,
  })  : _location = saat.konumBul(konum.saatDilimi),
        _locationHatasi = saat.konumBul(konum.saatDilimi) == null;

  final Konum konum;
  final Saat saat;

  final tz.Location? _location;
  final bool _locationHatasi;

  /// Seçilen şehrin saat dilimi çözülemiyorsa `true`.
  ///
  /// Bu durumda uygulama cihaz saatine ya da Türkiye saatine sessizce
  /// düşmemeli; çağıran taraf kullanıcıya hata göstermelidir.
  bool get saatDilimiCozulemedi => _locationHatasi || _location == null;

  tz.Location? get location => _location;

  /// Seçili şehirde "şu an".
  ///
  /// [saatDilimiCozulemedi] true ise `null` döner; çünkü şehrin
  /// yerel saati bilinmiyordur ve uydurulamaz.
  tz.TZDateTime? simdi() {
    if (saatDilimiCozulemedi) return null;
    return tz.TZDateTime.from(saat.simdi(), _location!);
  }

  /// Seçili şehirde şu anın günü.
  ///
  /// Cihazın günü DEĞİLDİR. Cihaz İstanbul'da 26 Eylül 23:40,
  /// seçili şehir Tokyo ise bu değer 27 Eylül olabilir.
  DateTime? bugun() {
    final s = simdi();
    return s == null ? null : DateTime(s.year, s.month, s.day);
  }

  /// Şehrin saat diliminde [tarih] gününe ait [saat]:[dakika] duvar
  /// saatini kurar.
  ///
  /// [saat] 0-23, [dakika] 0-59 aralığında olmalıdır; dışındaysa
  /// `null` döner (sessizce yuvarlanmaz).
  ///
  /// `00:00` DA `null` DÖNER. Gece yarısı bir namaz vakti olamaz; `00:00`
  /// bir veri hatasının işaretidir. Alarm planlarken `00:00`ı kabul
  /// etmek, gece yarısında "vakit geldi" bildirimi kurmak demektir.
  ///
  /// [tarih] verilmezse seçili şehrin BUGÜNÜ kullanılır.
  tz.TZDateTime? duvarSaati(
    String saat, {
    String? dakika,
    DateTime? tarih,
  }) {
    if (saatDilimiCozulemedi) return null;
    final parcalar = saat.split(':');
    if (parcalar.isEmpty) return null;
    final int? s = int.tryParse(parcalar[0].trim());
    final int? d = dakika != null
        ? int.tryParse(dakika.trim())
        : (parcalar.length > 1 ? int.tryParse(parcalar[1].trim()) : null);
    if (s == null || d == null) return null;
    if (s < 0 || s > 23 || d < 0 || d > 59) return null;
    if (s == 0 && d == 0) return null;

    final gun = tarih ?? bugun();
    if (gun == null) return null;

    return tz.TZDateTime(_location!, gun.year, gun.month, gun.day, s, d);
  }
}

/// Konumun "bugün"ünü belirleyen tek giriş noktası.
///
/// NEDEN AYRI BİR SINIF?
///
/// Yeni bir şehir ilk kez seçildiğinde o şehrin IANA saat dilimini henüz
/// bilmiyoruz: dilim API'den `meta.timezone` ile gelir ve o istek, hangi
/// ayın sorulacağını bilmemiz gerektiği için yapılır. Bu bir tavuk-yumurta
/// durumudur ve şöyle çözülür:
///
///   1. Saat dilimi biliniyorsa: IANA dilimiyle kesin hesaplanır.
///   2. Saat dilimi bilinmiyorsa: BOYLAMAYA DAYALI bir TAHMİN kullanılır.
///      Bu tahmin YALNIZCA "hangi ayı isteyeceğimiz" sorusunu yanıtlar.
///
/// ÖNEMLİ: Tahmin hiçbir zaman ekranda gösterilmez, vakit hesabına
/// girmez ve önbellek anahtarına yazılmaz. Yalnızca bir HTTP isteğinin
/// `month`/`year` parametresini seçer. Cevap geldiğinde `meta.timezone`
/// gelir ve o andan itibaren tüm hesaplar kesinleşir; ay tutmuyorsa
/// doğru ay için istek yeniden yapılır.
class KonumTakvimi {
  KonumTakvimi._();

  /// Uzunluğa dayalı yaklaşık UTC ofseti (saniye).
  ///
  /// 15 derece = 1 saat. Bu kaba bir yöntemdir: yaz saati ve siyasi
  /// saat dilimi sınırlarını bilmez. YALNIZCA istek yönlendirmesi içindir.
  static int ofsetTahmini(double boylam) =>
      ((boylam / 15.0) * 3600).round();

  /// [konum]un bugününü döner.
  ///
  /// [cihazAni] verilmezse [Saat.simdi] kullanılır.
  static DateTime tarih(Konum konum, Saat saat, {DateTime? cihazAni}) {
    final an = cihazAni ?? saat.simdi();
    final konumSaati = SehirSaati(konum: konum, saat: saat);
    final kesin = konumSaati.simdi();
    if (kesin != null) {
      return DateTime(kesin.year, kesin.month, kesin.day);
    }
    // Saat dilimi bilinmiyor. Boylama dayalı tahminle günü bul.
    final ofset = ofsetTahmini(konum.boylam);
    final kaydirilmis = DateTime.fromMillisecondsSinceEpoch(
      an.toUtc().millisecondsSinceEpoch + ofset * 1000,
      isUtc: true,
    );
    return DateTime(kaydirilmis.year, kaydirilmis.month, kaydirilmis.day);
  }

  /// [konum] için bugünün hâlâ tahminle bulunduğunu söyler.
  static bool tahminiMi(Konum konum, Saat saat) =>
      SehirSaati(konum: konum, saat: saat).saatDilimiCozulemedi;
}

/// Uygulamanın seçili konumunun tamamını taşıyan model.
///
/// Bu alanların hepsi tek yerde durmalıdır. Aksi halde "hangi şehir
/// hangi koordinat hangi yöntem hangi saat dilimi" bilgisi farklı
/// farklı yerlere dağılır ve bunlardan biri güncellenince diğeri
/// eski kalır — bu da sessiz yanlış vakite yol açar.
class Konum {
  /// Görünen yer adı (şehir, ilçe veya GPS'ten gelen açıklama).
  final String ad;

  /// ISO 3166-1 alpha-2 ülke kodu (örn. "TR").
  final String ulkeIso2;

  /// Coğrafi koordinat.
  ///
  /// Bu DEĞİŞTİRİLMEZ. Koordinatın vakitlere "Diyanet'e yaklaştırmak"
  /// için kaydırılması, kullanıcıya başka bir yerde durduğu yanıltıcı
  /// bir vakit gösterir. Aradaki fark kullanıcıya açıkça bildirilir.
  final double enlem;
  final double boylam;

  /// IANA saat dilimi (örn. "Europe/Istanbul", "Asia/Tokyo").
  ///
  /// Bu alan API'den gelen `meta.timezone` ile doğrulanır ve kalıcı
  /// hâlde saklanır; açılışta cihaz saat dilimine düşülmez.
  final String saatDilimi;

  /// Seçilen hesaplama yöntemi. `null` = Aladhan'ın otomatik seçimi.
  final int? yontemId;

  /// Asr (öğle sonrası) hesaplama yöntemi.
  final AsrYontemi asrYontemi;

  /// Yüksek enlemlerde uygulanan düzeltme ayarı.
  ///
  /// Sağlayıcının ne yaptığını bilmediğimiz için bu değer gizli
  /// varsayım olarak bırakılmaz; hem modelde hem önbellek anahtarında
  /// bulunur ve kullanıcıya gösterilir.
  ///
  /// RESMÎ DİYANET MODUNDA BU AYAR OKUNMAZ. Resmî tabloda bir "yüksek enlem
  /// düzeltmesi" alanı yoktur; Diyanet tek bir tablo yayımlar. Ayarı
  /// uygulamak resmî saati değiştirmek olurdu, o da "resmî veri" etiketinin
  /// anlamını bozardı.
  final YuksekEnlemAyaru yuksekEnlemAyaru;

  /// Bağlı olduğu il / eyalet adı (Türkiye'de resmî yerleşim eşleştirmesi
  /// için gerekir; diğer ülkelerde ekran etiketi olarak da kullanılabilir).
  final String il;

  /// Resmî Diyanet yerleşim kimliği (`CityID`).
  ///
  /// `null` ise bu kayıt resmî katalogda karşılık bulamadı ya da veri
  /// alamadı. Bu durumda uygulama il merkezinin vakitlerini KOPYALAMAZ;
  /// "resmî veri yok" gösterir.
  final int? diyanetCityId;

  /// Resmî veri paketinde bu yerleşimin bulunduğu il parçasının dosya adı
  /// (örn. `"TR/ankara.txt"`). [diyanetCityId] doluysa doludur.
  final String? diyanetParca;

  const Konum({
    required this.ad,
    required this.ulkeIso2,
    required this.enlem,
    required this.boylam,
    required this.saatDilimi,
    this.yontemId,
    this.asrYontemi = AsrYontemi.standart,
    this.yuksekEnlemAyaru = YuksekEnlemAyaru.orta,
    this.il = '',
    this.diyanetCityId,
    this.diyanetParca,
  });

  /// Bu konum resmî Diyanet verisiyle gösterilebilir mi?
  ///
  /// Üç koşulun HEPSİ sağlanmalıdır:
  ///   1. Türkiye (resmî veri yalnız Türkiye için var),
  ///   2. resmî katalogda karşılığı bulundu ([diyanetCityId] dolu),
  ///   3. kullanıcı resmî modu kapatmamış (bkz. `aktifResmiDiyanet`).
  ///
  /// [resmiModAcik] bilinçli olarak DIŞARIDAN verilir: `Konum` bir veri
  /// modelidir, kullanıcı tercihini bilmez. Bu ayrım sayesinde aynı konum
  /// "resmî" ve "hesaplanmış" modda farklı davranabilir.
  bool resmiDiyanetKullanilirMi({required bool resmiModAcik}) =>
      resmiModAcik && ulkeIso2 == 'TR' && diyanetCityId != null;

  /// Önbellek anahtarının hesap yöntemiyle ilgili kısmı.
  ///
  /// Asr ve yüksek enlem ayarları da buraya girer: bu ayarlar vakitleri
  /// değiştirir, dolayısıyla aynı önbellek anahtarını paylaşamazlar.
  String get hesapAnahtari =>
      'm${yontemId ?? 'oto'}_a${asrYontemi.onbellekKodu}_y${yuksekEnlemAyaru.kod}';

  /// Tam önbellek anahtarı: koordinat + hesap + ay + yıl.
  ///
  /// Koordinat anahtarda 4 ondalığa yuvarlanır. Bu kasıtlıdır: ölçüm
  /// script'leri bazen 39.933400 ve 39.93341 gibi aynı noktanın
  /// farklı yazımlarını üretir ve bunlar aynı yerde hesaplanan aynı
  /// vakitlerdir. Ayrıca "Gölbaşı" gibi aynı adlı iki kayıt
  /// (Ankara/Gölbaşı ile Adıyaman/Gölbaşı) yalnız adla değil, tam
  /// koordinatla ayrılır.
  String onbellekAnahtari({required int yil, required int ay}) {
    return 'vakitler_${enlem.toStringAsFixed(4)}_${boylam.toStringAsFixed(4)}'
        '_${hesapAnahtari}_$yil-$ay';
  }

  Konum kopyala({
    String? ad,
    String? ulkeIso2,
    double? enlem,
    double? boylam,
    String? saatDilimi,
    int? yontemId,
    bool yontemTemizle = false,
    AsrYontemi? asrYontemi,
    YuksekEnlemAyaru? yuksekEnlemAyaru,
    String? il,
    int? diyanetCityId,
    String? diyanetParca,
  }) {
    return Konum(
      ad: ad ?? this.ad,
      ulkeIso2: ulkeIso2 ?? this.ulkeIso2,
      enlem: enlem ?? this.enlem,
      boylam: boylam ?? this.boylam,
      saatDilimi: saatDilimi ?? this.saatDilimi,
      yontemId: yontemTemizle ? null : (yontemId ?? this.yontemId),
      asrYontemi: asrYontemi ?? this.asrYontemi,
      yuksekEnlemAyaru: yuksekEnlemAyaru ?? this.yuksekEnlemAyaru,
      il: il ?? this.il,
      diyanetCityId: diyanetCityId ?? this.diyanetCityId,
      diyanetParca: diyanetParca ?? this.diyanetParca,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Konum &&
      other.ad == ad &&
      other.ulkeIso2 == ulkeIso2 &&
      other.enlem == enlem &&
      other.boylam == boylam &&
      other.saatDilimi == saatDilimi &&
      other.yontemId == yontemId &&
      other.asrYontemi == asrYontemi &&
      other.yuksekEnlemAyaru == yuksekEnlemAyaru &&
      other.il == il &&
      other.diyanetCityId == diyanetCityId &&
      other.diyanetParca == diyanetParca;

  @override
  int get hashCode => Object.hash(ad, ulkeIso2, enlem, boylam, saatDilimi,
      yontemId, asrYontemi.kod, yuksekEnlemAyaru.kod, il, diyanetCityId,
      diyanetParca);

  @override
  String toString() => 'Konum($ad, $ulkeIso2, $enlem, $boylam, $saatDilimi, '
      'yontem=$yontemId, asr=${asrYontemi.kod}, yuksekEnlem=${yuksekEnlemAyaru.kod}'
      '${il.isEmpty ? '' : ', il=$il'}'
      '${diyanetCityId == null ? '' : ', diyanet=$diyanetCityId'}';
}

/// Asr (öğle sonrası) hesaplama yöntemi.
///
/// Aladhan'ın `school` parametresine karşılık gelir. Sessiz bir
/// varsayılan bırakılmaz; modelde ve önbellek anahtarında durur.
enum AsrYontemi {
  standart('standart', 'Standard (Hanefi olmayan)'),
  hanafi('hanafi', 'Hanefi');

  const AsrYontemi(this.kod, this.ad);
  final String kod;
  final String ad;

  // İstek sayısaldır; STANDARD/HANAFI yalnız cevabın meta.school alanıdır.
  String get apiParametresi => this == AsrYontemi.hanafi ? '1' : '0';

  // Eski HANAFI isteği sunucuda standart vakit üretiyordu. Bu kayıtlar
  // yeni Hanefi seçimine taşınmaz; doğru olan standart önbelleği korunur.
  String get onbellekKodu => this == AsrYontemi.hanafi ? 'hanafi_v2' : kod;
}

/// Yüksek enlemlerde uygulanan düzeltme ayarı.
///
/// Aladhan'ın `adjustmentMethod` parametresine karşılık gelir. 48°
/// üzeri enlemlerde (Norveç, İsveç, Finlandiya, Grönland, bazı Rusya
/// bölgeleri) farklı mezhepler farklı düzeltmeler uygular; bu yüzden
/// ayar gizli tutulamaz.
enum YuksekEnlemAyaru {
  yok('yok', 'Düzeltme yok'),
  orta('orta', 'Orta (1/7 gölge)'),
  ceyrek('ceyrek', 'Çeyrek (1/4 gölge)'),
  yarim('yarim', 'Yarım');

  const YuksekEnlemAyaru(this.kod, this.ad);
  final String kod;
  final String ad;

  String get apiParametresi => switch (this) {
        YuksekEnlemAyaru.yok => 'NONE',
        YuksekEnlemAyaru.orta => 'MIDDLE',
        YuksekEnlemAyaru.ceyrek => 'QUARTER',
        YuksekEnlemAyaru.yarim => 'HALF',
      };
}
