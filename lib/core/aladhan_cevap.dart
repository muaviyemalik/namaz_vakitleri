// lib/core/aladhan_cevap.dart
//
// ALADHAN CEVABINI DOĞRULAMA KATMANI.
//
// BU KATMANIN VAR OLMA SEBEBİ
//
// Aladhan hata durumunda bile HTTP 200 dönebilir; gerçek durum cevabın
// içindeki `code` alanındadır. Daha kötüsü: bazı hatalı cevaplar `code`
// 200 ve `data` dolu gelir. Önceden uygulama yalnız bu ikisine bakıyor,
// cevabı olduğu gibi kalıcı belleğe yazıyor ve ekranda gösteriyordu.
// Sonuç, kullanıcının namaz vakti sanarak baktığı `00:00` idi.
//
// DOĞRULANANLAR (hepsi red sebebi olarak döner):
//
//   1. HTTP durum kodu 200 mü?
//   2. Gövdedeki mantıksal `code` alanı 200 mü?
//   3. `data` gerçekten bir liste mi?
//   4. İstenen AY ve YIL cevapta aynı mı?  (Şubat 30 gün ise sessizce
//      kaydırılmamalı.)
//   5. Koordinat cevapta istenenle aynı mı?  (Bilinmeyen sebeple
//      başka bir şehrin verisi gelirse fark edilmelidir.)
//   6. `meta.timezone` var mı ve IANA olarak çözülebiliyor mu?
//   7. `meta.method` istenen yöntemle uyuşuyor mu?
//   8. Zorunlu vakit alanlarının altısı da var mı?
//   9. Her saat "SS:DD" biçiminde ve dakika 0-59, saat 0-23 aralığında mı?
//  10. Cevaptaki gün gerçekten istenen gün mü?  (`date.gregorian.date`
//      alanından eşleme yapılır; listedeki sıraya güvenilmez.)
//
// RED EDİLEN CEVAP ASLA ÖNBELLEĞE YAZILMAZ. Yazma kararı
// `VakitDepo` içindedir ve yalnız [GecerliCevap] üzerinden verilir.

import 'dart:convert';

import 'saat.dart';

/// Bir vakit günü. API'den tek bir günün okunmuş hâli.
class VakitGunu {
  /// Miladi tarih: yıl, ay, gün. API'nin `date.gregorian` alanından.
  final int yil;
  final int ay;
  final int gun;

  /// Hicri tarih (gün, ay adı, yıl) — ekranda gösterilmek üzere.
  final String hicriTarih;

  /// Bu günün vakitleri, seçili şehrin saat diliminde "SS:DD".
  ///
  /// `sunrise` bir namaz vakti değildir; yalnızca bilgi amaçlıdır.
  final Map<String, String> saatler;

  /// Cevabın `meta.timezone` değeri. Uygulamanın tek saat dilimi
  /// kaynağı budur.
  final String saatDilimi;

  /// Sağlayıcının gerçekte kullandığı yöntem (`meta.method.id`).
  ///
  /// Kullanıcı yöntem seçmediyse bu değer boş değildir ve ekranda
  /// "Aladhan otomatik yöntemi: X" olarak gösterilir. Kullanıcı bir
  /// yöntem seçtiyse bu değer seçilen yöntemle aynı olmak ZORUNDADIR;
  /// değilse cevap reddedilir.
  final int cevapYontemId;

  const VakitGunu({
    required this.yil,
    required this.ay,
    required this.gun,
    required this.hicriTarih,
    required this.saatler,
    required this.saatDilimi,
    required this.cevapYontemId,
  });

  DateTime get tarih => DateTime(yil, ay, gun);

  /// Bu günün gerçekten verilen gün olup olmadığını denetler.
  bool ayniGun(DateTime d) => yil == d.year && ay == d.month && gun == d.day;

  @override
  String toString() =>
      'VakitGunu($yil-$ay-$gun, tz=$saatDilimi, method=$cevapYontemId, $saatler)';
}

/// Namaz vakitlerinin API'deki alan adları, sıra numarasıyla birlikte.
///
/// Sıra, alarm kimliklerinin ve "sıradaki vakit" sıralamasının kaynağıdır;
/// bu yüzden burada tanımlı ve değiştirilmez.
class VakitAlani {
  final String anahtar;
  final String apiAlani;
  final bool namazVaktiMi;

  const VakitAlani(this.anahtar, this.apiAlani, {this.namazVaktiMi = true});

  static const fajr = VakitAlani('fajr', 'Fajr');
  static const sunrise = VakitAlani('sunrise', 'Sunrise', namazVaktiMi: false);
  static const dhuhr = VakitAlani('dhuhr', 'Dhuhr');
  static const asr = VakitAlani('asr', 'Asr');
  static const maghrib = VakitAlani('maghrib', 'Maghrib');
  static const isha = VakitAlani('isha', 'Isha');

  /// Ekranda sırayla gösterilen alanlar.
  static const sirali = <VakitAlani>[fajr, sunrise, dhuhr, asr, maghrib, isha];

  /// Gerçek namaz vakitleri (sunrise bir vakit değildir).
  static const namazVakitleri = <VakitAlani>[fajr, dhuhr, asr, maghrib, isha];
}

/// Cevabın neden reddedildiği. Arayüz bunu çeviriye çevirir.
enum RedSebebi {
  httpHatasi,
  mantiksalHata,
  veriYok,
  tarihAyligiBozuk,
  ayYilBesiIlMi,
  koordinatBesiIlMi,
  saatDilimiYok,
  saatDilimiCozulemedi,
  yontemBesiIlMi,
  vakitAlaniEksik,
  saatBicimiBozuk,
  saatAralikBozuk,
  sifirSaat,
  gunBulunamadi,
}

/// Doğrulama sonucu: ya doğrulanmış aylık veri, ya da red gerekçesi.
sealed class CevapSonucu {
  const CevapSonucu();
}

/// Cevap doğrulandı. Önbelleğe yazılabilir.
class CevapGecerli extends CevapSonucu {
  final List<VakitGunu> gunler;
  final String saatDilimi;
  final int cevapYontemId;

  /// Cevabın meta'sında bildirilen koordinat.
  final double cevapEnlem;
  final double cevapBoylam;

  const CevapGecerli({
    required this.gunler,
    required this.saatDilimi,
    required this.cevapYontemId,
    required this.cevapEnlem,
    required this.cevapBoylam,
  });

  /// İstenen güne ait kaydı döner; yoksa `null`.
  ///
  /// Sıraya değil, GERÇEK tarihe bakar. Aladhan aylık cevapta günleri
  /// 1..N sırayla verir, ama bu bir taahhüt değildir ve cihazın günüyle
  /// `now.day - 1` eşleştirmek (eski davranış) farklı günlerdeyken
  /// yanlış günü seçer.
  VakitGunu? gun(DateTime tarih) {
    for (final g in gunler) {
      if (g.ay == tarih.month && g.gun == tarih.day && g.yil == tarih.year) {
        return g;
      }
    }
    return null;
  }
}

/// Cevap reddedildi. Önbelleğe ASLA yazılmaz.
class CevapReddedildi extends CevapSonucu {
  final RedSebebi sebep;
  final String? ayrinti;

  const CevapReddedildi(this.sebep, [this.ayrinti]);

  @override
  String toString() =>
      'CevapReddedildi(${sebep.name}${ayrinti == null ? '' : ': $ayrinti'})';
}

/// Aladhan `/v1/calendar` cevabını ayrıştırır ve doğrular.
///
/// Bu sınıf [Saat] alır çünkü `meta.timezone` değerinin gerçekten
/// kullanılabilir bir IANA adı olup olmadığını bilmek zaman dilimi
/// veritabanına bakar; testte sabit saat ile verilir.
class AladhanCevap {
  const AladhanCevap(this.saat);

  final Saat saat;

  /// Koordinat toleransı (derece). ~1,1 km. Aladhan 4 ondalığa
  /// yuvarlar; bu tolerans ondalık yuvarlama farkını tolere eder ama
  /// komşu bir şehri tolere etmez.
  static const double koordinatTolerans = 0.02;

  /// Bir saati doğrular ve "SS:DD" biçimine getirir.
  ///
  /// Aladhan bazen `"04:52 (EEST)"`, bazen `"04:52:11"`, bazen
  /// `"04:52 (EEST+03:00)"` döner. Önceden `substring(0,5)` ile
  /// kırpılıyordu; alan null ya da kısa geldiğinde `RangeError` ile
  /// uygulama çöküyordu.
  ///
  /// DÖNÜŞ: `null` geçersizse. Çağıran taraf bunu `00:00` YAPMAMALI;
  /// cevabı reddetmelidir.
  static String? saatiTemizle(dynamic ham) {
    if (ham == null) return null;
    var metin = ham.toString().trim();
    if (metin.isEmpty) return null;

    // "04:52 (EEST)" / "04:52:11" / "04:52:11 (EEST)" -> "04:52"
    final bosluk = metin.indexOf(' ');
    if (bosluk > 0) metin = metin.substring(0, bosluk);
    final parcalar = metin.split(':');
    if (parcalar.length < 2) return null;

    final int? s = int.tryParse(parcalar[0].trim());
    final int? d = int.tryParse(parcalar[1].trim());
    if (s == null || d == null) return null;
    if (s < 0 || s > 23) return null;
    if (d < 0 || d > 59) return null;

    // 00:00 bir veri hatası işareti olarak değerlendirilir. Namaz vakti
    // olarak 00:00 fiziksel olarak mümkün değildir; kutup bölgelerinde
    // güneş doğuşu gerçekten hiç gerçekleşmiyorsa Aladhan bunu
    // bildirmemektedir. Kullanıcı 00:00'a "vakit" yazmaktense
    // anlaşılır bir hata görüp yeniden denemesi doğrudur.
    if (s == 0 && d == 0) return null;

    return '${s.toString().padLeft(2, '0')}:${d.toString().padLeft(2, '0')}';
  }

  /// Ham gövdeyi doğrular ve [CevapGecerli] ya da [CevapReddedildi]
  /// döner.
  ///
  /// [istenenKonum] hangi şehir/yöntem için sorulduğunu, [yil]/[ay]
  /// hangi ayın istendiğini, [istenenGun] ise ekranda gösterilecek
  /// günü tanımlar. [istenenGun] verilmezse gün eşlemesi yapılmaz
  /// (aylık önden indirme için).
  CevapSonucu dogrula(
    String govde, {
    required int httpDurumKodu,
    required Konum istenenKonum,
    required int yil,
    required int ay,
    DateTime? istenenGun,
  }) {
    if (httpDurumKodu != 200) {
      return CevapReddedildi(RedSebebi.httpHatasi, 'HTTP $httpDurumKodu');
    }

    final Object? cozulmus;
    try {
      cozulmus = json.decode(govde);
    } catch (e) {
      return CevapReddedildi(RedSebebi.mantiksalHata, 'JSON okunamadı: $e');
    }

    if (cozulmus is! Map) {
      return const CevapReddedildi(RedSebebi.mantiksalHata, 'gövde harita değil');
    }

    // Aladhan hata durumunda da HTTP 200 dönebilir; gerçek durum
    // gövdedeki `code` alanındadır.
    if (cozulmus['code'] != 200) {
      final durum = cozulmus['status'];
      return CevapReddedildi(
          RedSebebi.mantiksalHata, 'code=${cozulmus['code']} status=$durum');
    }

    final veri = cozulmus['data'];
    if (veri is! List || veri.isEmpty) {
      return const CevapReddedildi(RedSebebi.veriYok, 'data boş veya liste değil');
    }

    // -- Ay/yıl denetimi -------------------------------------------------
    // Aladhan beklenenden kısa bir liste döndürürse (ör. ayın 1'inde geçersiz
    // tarih istenmişse) sessizce kabul edilmemeli.
    Map<String, dynamic>? ilkKayit;
    for (final oge in veri) {
      if (oge is Map<String, dynamic>) {
        ilkKayit = oge;
        break;
      }
    }
    if (ilkKayit == null) {
      return const CevapReddedildi(RedSebebi.veriYok, 'liste içinde kayıt yok');
    }
    final ilkTarih = ilkKayit['date'] is Map
        ? (ilkKayit['date'] as Map)['gregorian']
        : null;
    if (ilkTarih is! Map) {
      return const CevapReddedildi(RedSebebi.tarihAyligiBozuk, 'gregorian yok');
    }
    final cevapYili = _sayiOku(ilkTarih['year']);
    final cevapAyi = _sayiOku(_haritaOku(ilkTarih, 'month', 'number'));
    if (cevapAyi != ay || cevapYili != yil) {
      return CevapReddedildi(
        RedSebebi.ayYilBesiIlMi, 'istenen $yil-$ay, cevap $cevapYili-$cevapAyi');
    }

    // -- meta: koordinat, saat dilimi, yöntem ----------------------------
    final meta = ilkKayit['meta'];
    if (meta is! Map) {
      return const CevapReddedildi(RedSebebi.saatDilimiYok, 'meta yok');
    }

    final cevapEnlem = _ondalikOku(meta['latitude']);
    final cevapBoylam = _ondalikOku(meta['longitude']);
    if (cevapEnlem == null || cevapBoylam == null) {
      return const CevapReddedildi(RedSebebi.koordinatBesiIlMi,
          'meta koordinat okunamadı');
    }
    if ((cevapEnlem - istenenKonum.enlem).abs() > koordinatTolerans ||
        (cevapBoylam - istenenKonum.boylam).abs() > koordinatTolerans) {
      return CevapReddedildi(RedSebebi.koordinatBesiIlMi,
          'istenen ${istenenKonum.enlem},${istenenKonum.boylam} '
          'cevap $cevapEnlem,$cevapBoylam');
    }

    final metaTimezone = (meta['timezone'] ?? '').toString().trim();
    if (metaTimezone.isEmpty) {
      return const CevapReddedildi(RedSebebi.saatDilimiYok, 'meta.timezone boş');
    }
    if (saat.konumBul(metaTimezone) == null) {
      return CevapReddedildi(RedSebebi.saatDilimiCozulemedi, metaTimezone);
    }

    // Yöntem denetimi.
    //
    // Kullanıcı bir yöntem SEÇTİYSE cevap o yöntemi kullanmış olmalıdır;
    // başka bir yöntemle gelen vakitler kullanıcıya gösterilemez.
    // Kullanıcı seçmediyse (otomatik mod) sağlayıcının neyi seçtiğini
    // kaydeder ve kullanıcıya gösteririz.
    final methodMeta = meta['method'];
    final methodId = methodMeta is Map ? _sayiOku(methodMeta['id']) : null;
    if (methodId == null) {
      return const CevapReddedildi(RedSebebi.yontemBesiIlMi, 'meta.method.id yok');
    }
    if (istenenKonum.yontemId != null &&
        methodId != istenenKonum.yontemId) {
      return CevapReddedildi(RedSebebi.yontemBesiIlMi,
          'istenen ${istenenKonum.yontemId}, cevap $methodId');
    }

    // -- Günlerin ayrıştırılması -----------------------------------------
    final gunler = <VakitGunu>[];
    for (final oge in veri) {
      if (oge is! Map) continue;
      final t = dogrulaGun(oge, beklEnenMetaTimezone: metaTimezone,
          beklEnenYontemId: methodId);
      switch (t) {
        case _GunHatasi(:final sebep, :final ayrinti):
          return CevapReddedildi(sebep, ayrinti);
        case _GunBasarili(:final gun):
          gunler.add(gun);
      }
    }

    if (gunler.isEmpty) {
      return const CevapReddedildi(RedSebebi.veriYok, 'doğrulanabilir gün kalmadı');
    }

    // İstenen gün gerçekten var mı? Yoksa cevap yetersizdir: ekranda
    // yanlış günü göstermektense hata vermek doğrudur.
    if (istenenGun != null) {
      final bulundu = gunler.any((g) => g.ay == istenenGun.month &&
          g.gun == istenenGun.day &&
          g.yil == istenenGun.year);
      if (!bulundu) {
        return CevapReddedildi(RedSebebi.gunBulunamadi,
            '${istenenGun.year}-${istenenGun.month}-${istenenGun.day} yok');
      }
    }

    return CevapGecerli(
      gunler: gunler,
      saatDilimi: metaTimezone,
      cevapYontemId: methodId,
      cevapEnlem: cevapEnlem,
      cevapBoylam: cevapBoylam,
    );
  }

  /// Bir günlük kaydı doğrular ve ya [_GunBasarili] ya [_GunHatasi]
  /// döner.
  ///
  /// [beklEnenMetaTimezone] ve [beklEnenYontemId] verilirse yalnızca o
  /// değerlere uyan günler kabul edilir: aylık cevapta bir günün
  /// `meta.timezone`'si diğerlerinden farklıysa bu veri bozuktur.
  Object dogrulaGun(
    Map oge, {
    String? beklEnenMetaTimezone,
    int? beklEnenYontemId,
  }) {
    final date = oge['date'];
    if (date is! Map) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, 'date yok');
    }
    final gregorian = date['gregorian'];
    if (gregorian is! Map) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, 'date.gregorian yok');
    }
    // Gerçek tarih buradan okunur; listedeki sıraya güvenilmez.
    final hamTarih = (gregorian['date'] ?? '').toString().trim();
    final parcalar = hamTarih.split('-');
    if (parcalar.length != 3) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, 'date.gregorian.date=$hamTarih');
    }
    final g = int.tryParse(parcalar[0].trim());
    final a = int.tryParse(parcalar[1].trim());
    final y = int.tryParse(parcalar[2].trim());
    if (g == null || a == null || y == null || g < 1 || g > 31 || a < 1 || a > 12) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, 'geçersiz tarih $hamTarih');
    }
    if (g > _ayGunSayisi(y, a)) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, '$y-$a içinde $g. gün yok');
    }

    // Ay/yıl alanları da tarihle tutarlı olmalı.
    final alanYili = _sayiOku(gregorian['year']);
    final alanAyi = _sayiOku(_haritaOku(gregorian, 'month', 'number'));
    if (alanYili != null && alanYili != y) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, 'year $alanYili != $y');
    }
    if (alanAyi != null && alanAyi != a) {
      return _GunHatasi(RedSebebi.tarihAyligiBozuk, 'month $alanAyi != $a');
    }

    // meta bu gün için de geçerli mi?
    final meta = oge['meta'];
    if (meta is! Map) {
      return _GunHatasi(RedSebebi.saatDilimiYok, 'gün meta verisi yok');
    }
    final gunTz = (meta['timezone'] ?? '').toString().trim();
    if (gunTz.isEmpty) {
      return _GunHatasi(RedSebebi.saatDilimiYok, 'gün meta.timezone boş');
    }
    if (beklEnenMetaTimezone != null && gunTz != beklEnenMetaTimezone) {
      return _GunHatasi(RedSebebi.saatDilimiYok,
          'gün tz=$gunTz, ay tz=$beklEnenMetaTimezone');
    }
    if (beklEnenYontemId != null) {
      final method = meta['method'];
      final gunMethod = method is Map ? _sayiOku(method['id']) : null;
      if (gunMethod != beklEnenYontemId) {
        return _GunHatasi(RedSebebi.yontemBesiIlMi,
            'gün method=$gunMethod, ay method=$beklEnenYontemId');
      }
    }

    // Vakitler
    final timings = oge['timings'];
    if (timings is! Map) {
      return _GunHatasi(RedSebebi.vakitAlaniEksik, 'timings yok');
    }
    final saatler = <String, String>{};
    for (final alan in VakitAlani.sirali) {
      final ham = timings[alan.apiAlani];
      if (ham == null || ham.toString().trim().isEmpty) {
        return _GunHatasi(RedSebebi.vakitAlaniEksik, '${alan.apiAlani} eksik');
      }
      final temiz = saatiTemizle(ham);
      if (temiz == null) {
        // Biçim/aralık geçersizse mi yoksa 00:00 mı ayırt et.
        final hamMetin = ham.toString().trim();
        final bosluk = hamMetin.indexOf(' ');
        final kisa = bosluk > 0 ? hamMetin.substring(0, bosluk) : hamMetin;
        final p = kisa.split(':');
        final s = p.isNotEmpty ? int.tryParse(p[0].trim()) : null;
        final d = p.length > 1 ? int.tryParse(p[1].trim()) : null;
        if (s == null || d == null) {
          return _GunHatasi(RedSebebi.saatBicimiBozuk,
              '${alan.apiAlani}="$hamMetin"');
        }
        if (s < 0 || s > 23 || d < 0 || d > 59) {
          return _GunHatasi(RedSebebi.saatAralikBozuk,
              '${alan.apiAlani}="$hamMetin"');
        }
        return _GunHatasi(RedSebebi.sifirSaat, '${alan.apiAlani} 00:00');
      }
      saatler[alan.anahtar] = temiz;
    }

    // Hicri tarih — ekranda gösteriliyor, boş olmamalı.
    final hijri = date['hijri'];
    var hicriMetni = '';
    if (hijri is Map) {
      final hGun = (hijri['day'] ?? '').toString().trim();
      final hAy = _haritaOku(hijri, 'month', 'en')?.toString().trim() ?? '';
      final hYil = (hijri['year'] ?? '').toString().trim();
      if (hGun.isNotEmpty && hAy.isNotEmpty && hYil.isNotEmpty) {
        hicriMetni = '$hGun $hAy $hYil';
      }
    }

    return _GunBasarili(VakitGunu(
      yil: y,
      ay: a,
      gun: g,
      hicriTarih: hicriMetni,
      saatler: saatler,
      saatDilimi: gunTz,
      cevapYontemId: beklEnenYontemId ??
          ((meta['method'] is Map
              ? _sayiOku((meta['method'] as Map)['id']) ?? -1
              : -1)),
    ));
  }

  /// Bir ayın kaç gün çektiğini döner (Artık yıl dahil).
  ///
  /// Şubat için 29 Şubat 2024'ün var olduğu ama 2023'te olmadığı
  /// senaryosu testte kullanılır.
  static int _ayGunSayisi(int yil, int ay) {
    const g = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (ay == 2 && _artikYilMi(yil)) return 29;
    return g[ay - 1];
  }

  static bool _artikYilMi(int yil) =>
      (yil % 4 == 0 && yil % 100 != 0) || yil % 400 == 0;
}

class _GunBasarili {
  final VakitGunu gun;
  const _GunBasarili(this.gun);
}

class _GunHatasi {
  final RedSebebi sebep;
  final String? ayrinti;
  const _GunHatasi(this.sebep, [this.ayrinti]);
}

int? _sayiOku(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _ondalikOku(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

dynamic _haritaOku(Map m, String anahtar, String altAnahtar) {
  final v = m[anahtar];
  if (v is Map) return v[altAnahtar];
  return null;
}
