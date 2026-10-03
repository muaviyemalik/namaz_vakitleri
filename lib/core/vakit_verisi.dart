// lib/core/vakit_verisi.dart
//
// ÖNBELLEK VE ÇEVRİMDIŞI DAVRANIŞ.
//
// ÜÇ KURAL:
//
//   1. GEÇERLİ CEVAP ÖNCE YAZILIR. `yaz()` yalnızca doğrulanmış bir
//      [CevapGecerli] alır. Geçersiz cevap hiçbir koşulda diske
//      inmez; önceki sağlam kayıt yerinde kalır.
//
//   2. ANAHTAR KAPSAMAYI BELİRLER. Anahtar; koordinat + hesaplama
//      yöntemi + Asr ayarı + yüksek enlem ayarı + yıl + ay içerir.
//      Eski şehrin verisi yeni şehrin başlığı altında ASLA görünmez,
//      çünkü koordinat anahtardadır. Aynı adlı iki şehir
//      (Ankara/Gölbaşı ile Adıyaman/Gölbaşı) yalnız adla değil tam
//      koordinatla ayrılır.
//
//   3. BOZUK ÖNBELLEK ÇÖKERTMEZ. Okuma hatası yakalanır, o tek kayıt
//      karantinaya alınır ve diğer ayların sağlam kayıtları korunur.
//
// AÇILIŞ DAVRANIŞI (offline-first):
// Önce ekran önbellekten ANINDA açılır, arkasından ağ denenir. Kullanıcı
// her açılışta 10 saniye ağ beklemez. Kayıt gerçekten ağdan geldiyse
// ve tazeliği kabul edilebiliyorsa doğrudan ağdan açmak daha doğrudur;
// ama bu seçim ilk karede değil, veri katmanında ve ölçülebilir
// biçimde yapılır.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'aladhan_cevap.dart';
import 'saat.dart';

/// Bir önbellek kaydının nerden geldiğini ve ne zaman tazelendiğini
/// anlatan özet. Arayüz bunu küçük bir satırda gösterir.
class OnbellekOzeti {
  final DateTime indirildi;
  final String saatDilimi;
  final int cevapYontemId;
  final DateTime ilkTarih;
  final DateTime sonTarih;
  final int gunSayisi;
  final String konumAdi;

  const OnbellekOzeti({
    required this.indirildi,
    required this.saatDilimi,
    required this.cevapYontemId,
    required this.ilkTarih,
    required this.sonTarih,
    required this.gunSayisi,
    required this.konumAdi,
  });
}

/// Vakit verisinin nereden geldiği.
enum VakitKaynagi {
  /// Bu açılışta ağdan indirildi.
  ag,

  /// Ağ yoktu/başarısızdı, ekran önbellekten açıldı.
  onbellek,

  /// Resmî Diyanet verisi. Ağ YOKTUR: paket uygulamanın içindedir.
  ///
  /// Bu değer yalnız doğrulanmış resmî bir satır bulunduğunda atanır.
  /// "Diyanet" etiketi yalnız bu değerde gösterilir; başka kaynağa düşülüp
  /// bu etiket yeniden kullanılmaz.
  resmiDiyanet,

  /// Hiçbir kaynak yok; kullanıcıya hata gösterilecek.
  yok,
}

/// Yükleme sonucunun tamamı.
class VakitDurumu {
  /// Ekranda gösterilecek günün vakitleri.
  final VakitGunu? bugun;

  /// Bugüne ek olarak, alarm planlamak için kullanılacak günler.
  ///
  /// Yalnızca bugünü planlamak, uygulama ertesi gün açılmazsa
  /// bildirimlerin hiç gelmemesi demektir.
  final List<VakitGunu> gelecekGunler;

  final VakitKaynagi kaynak;
  final OnbellekOzeti? ozet;
  final Konum konum;
  final CevapReddedildi? hata;

  const VakitDurumu({
    required this.konum,
    required this.kaynak,
    required this.gelecekGunler,
    this.bugun,
    this.ozet,
    this.hata,
  });

  bool get basariliMi => bugun != null;
}

/// Önbelleğin okunması/yazılması ve ağdan gelen verinin değerlendirilmesi.
class VakitDepo {
  VakitDepo({required this.saat, Future<SharedPreferences> Function()? tercih})
      : _tercih = tercih ?? SharedPreferences.getInstance;

  final Saat saat;
  final Future<SharedPreferences> Function() _tercih;

  static const String onek = 'vakitler_';
  static const String _ozetOnek = 'vakit_ozet_';
  static const String _bozukOnek = 'vakit_bozuk_';
  static const String _dilimOnek = 'vakit_dilim_';

  static const int _enFazlaBozukKayit = 8;

  // -- DÜŞÜK SEVİYE: TEK KAYIT -----------------------------------------

  /// Anahtardaki ham metni okur. Ayrıştırma hatasında `null` döner ve
  /// bozuk kayıt karantinaya alınır.
  Future<String?> _hamOku(SharedPreferences h, String anahtar) async {
    if (!h.containsKey(anahtar)) return null;
    final ham = h.getString(anahtar);
    if (ham == null || ham.trim().isEmpty) {
      await _karantinayaAl(h, anahtar, 'boş');
      return null;
    }
    return ham;
  }

  /// Bozuk kaydı silmek yerine karantinaya alır.
  ///
  /// Böylece (a) uygulama çökmez, (b) O anahtarın sağlam sürümü yoksa
  /// veri kaybı olmaz — kullanıcı yeni ay verisini indirince üstüne
  /// yazabilir. Diğer ayların kayıtlarına dokunulmaz.
  Future<void> _karantinayaAl(
      SharedPreferences h, String anahtar, String sebep) async {
    final ham = h.getString(anahtar);
    if (ham != null) {
      await h.setString(
          '$_bozukOnek${DateTime.now().microsecondsSinceEpoch}', ham);
    }
    await h.remove(anahtar);

    // Karantina şişmesin.
    final bozuklar = h.getKeys().where((k) => k.startsWith(_bozukOnek)).toList()
      ..sort();
    while (bozuklar.length > _enFazlaBozukKayit) {
      await h.remove(bozuklar.removeAt(0));
    }
    debugEkle('bozuk önbellek karantinaya alındı: $anahtar ($sebep)');
  }

  // -- KAYIT: OKUMA ------------------------------------------------------

  /// Belirtilen konum + ay için kayıtlı veriyi okur.
  ///
  /// Ağ olmadan da aynı sonucu verir; bu, offline-first'in temelidir.
  Future<CevapGecerli?> kayitOku(Konum konum, {required int yil, required int ay}) async {
    final h = await _tercih();
    final anahtar = konum.onbellekAnahtari(yil: yil, ay: ay);
    final ham = await _hamOku(h, anahtar);
    if (ham == null) return null;

    try {
      final d = json.decode(ham) as Map<String, dynamic>;
      return _kayittanCevapGecerli(d);
    } catch (e) {
      await _karantinayaAl(h, anahtar, 'ayrıştırma: $e');
      return null;
    }
  }

  /// Kayıt özetini okur (kullanıcıya "ne zaman güncellendi" göstermek için).
  Future<OnbellekOzeti?> ozetOku(Konum konum, {required int yil, required int ay}) async {
    final h = await _tercih();
    final ham = h.getString('$_ozetOnek${konum.onbellekAnahtari(yil: yil, ay: ay)}');
    if (ham == null) return null;
    try {
      final d = json.decode(ham) as Map<String, dynamic>;
      return OnbellekOzeti(
        indirildi: DateTime.fromMillisecondsSinceEpoch(d['indirildi'] as int),
        saatDilimi: d['saatDilimi'] as String,
        cevapYontemId: d['cevapYontemId'] as int,
        ilkTarih: _tarihOku(d['ilkTarih']),
        sonTarih: _tarihOku(d['sonTarih']),
        gunSayisi: d['gunSayisi'] as int,
        konumAdi: (d['konumAdi'] ?? '') as String,
      );
    } catch (_) {
      // Özet bozuksa ekranı düşürmüyoruz; yalnızca gösterilmez.
      return null;
    }
  }

  // -- KAYIT: YAZMA ------------------------------------------------------

  /// DOĞRULANMIŞ cevabı kalıcılaştırır.
  ///
  /// [cevp] [CevapGecerli] olmak ZORUNDADIR; başka tür geçirilirse
  /// hiçbir şey yazılmaz. Bu, "doğrulanmamış cevap son sağlam
  /// önbelleğin üzerine yazılamaz" kuralının tek yerde uygulanmasıdır.
  Future<bool> kayitYaz(Konum konum, CevapGecerli cevp) async {
    // Savunma amaçlı: yine de türü doğrula.
    if (cevp.gunler.isEmpty) return false;

    final h = await _tercih();
    final yil = cevp.gunler.first.yil;
    final ay = cevp.gunler.first.ay;
    final anahtar = konum.onbellekAnahtari(yil: yil, ay: ay);

    final sirali = [...cevp.gunler]..sort((a, b) {
        final x = a.tarih.compareTo(b.tarih);
        return x != 0 ? x : 0;
      });

    final govde = json.encode({
      'surum': 1,
      'kaynak': 'aladhan /v1/calendar',
      'indirildi': DateTime.now().millisecondsSinceEpoch,
      'konumAdi': konum.ad,
      'konumIso2': konum.ulkeIso2,
      'enlem': konum.enlem,
      'boylam': konum.boylam,
      'saatDilimi': cevp.saatDilimi,
      'istenenYontemId': konum.yontemId,
      'cevapYontemId': cevp.cevapYontemId,
      'asrYontemi': konum.asrYontemi.kod,
      'yuksekEnlemAyaru': konum.yuksekEnlemAyaru.kod,
      'ilkTarih': '${sirali.first.yil}-${sirali.first.ay}-${sirali.first.gun}',
      'sonTarih': '${sirali.last.yil}-${sirali.last.ay}-${sirali.last.gun}',
      'gunler': sirali
          .map((g) => {
                'y': g.yil,
                'a': g.ay,
                'g': g.gun,
                'h': g.hicriTarih,
                's': g.saatler,
                'tz': g.saatDilimi,
              })
          .toList(),
    });

    try {
      await h.setString(anahtar, govde);
      await h.setString('$_ozetOnek$anahtar', json.encode({
        'indirildi': DateTime.now().millisecondsSinceEpoch,
        'saatDilimi': cevp.saatDilimi,
        'cevapYontemId': cevp.cevapYontemId,
        'ilkTarih': '${sirali.first.yil}-${sirali.first.ay}-${sirali.first.gun}',
        'sonTarih': '${sirali.last.yil}-${sirali.last.ay}-${sirali.last.gun}',
        'gunSayisi': sirali.length,
        'konumAdi': konum.ad,
      }));
      await h.setString('$_dilimOnek${konum.hesapAnahtari}',
          cevp.saatDilimi);
      return true;
    } catch (e) {
      // Disk dolu vb. Uygulama çökmez; veri ağdan geldiği için ekranda
      // yine de gösterilir, yalnız kalıcı değildir.
      debugEkle('önbelleğe yazılamadı: $e');
      return false;
    }
  }

  // -- SAAT DİLİMİ KALICI HAFIZASI --------------------------------------

  /// Bir konum için en son doğrulanmış `meta.timezone` değeri.
  ///
  /// Açılışta cihaz saat dilimine düşmemek için gereklidir: internet
  /// yokken de doğru günü bulabilmeliyiz.
  Future<String?> kayitliSaatDilimi(Konum konum) async {
    final h = await _tercih();
    return h.getString('$_dilimOnek${konum.hesapAnahtari}');
  }

  // -- AĞ CEVABINI DEĞERLENDİRME ----------------------------------------

  /// Ağdan gelen ham cevabı doğrular, doğrulanmışsa kaydeder ve
  /// [VakitDurumu] üretir.
  Future<VakitDurumu> agCevabiniIsle({
    required Konum konum,
    required String govde,
    required int httpDurumKodu,
    required DateTime istenenGun,
  }) async {
    final dogrulayici = AladhanCevap(saat);
    final sonuc = dogrulayici.dogrula(
      govde,
      httpDurumKodu: httpDurumKodu,
      istenenKonum: konum,
      yil: istenenGun.year,
      ay: istenenGun.month,
      istenenGun: istenenGun,
    );

    switch (sonuc) {
      case CevapReddedildi():
        // GEÇERSİZ CEVAP: KALICI BELLEĞE DOKUNULMAZ.
        // Ekranda daha önce gösterilen sağlam veri korunur.
        final mevcut = await kayitOku(konum,
            yil: istenenGun.year, ay: istenenGun.month);
        final ozet = await ozetOku(konum,
            yil: istenenGun.year, ay: istenenGun.month);
        return VakitDurumu(
          konum: konum,
          kaynak: mevcut == null ? VakitKaynagi.yok : VakitKaynagi.onbellek,
          bugun: mevcut?.gun(istenenGun),
          gelecekGunler: mevcut == null ? const [] : _sonrakiGunler(mevcut, istenenGun),
          ozet: ozet,
          hata: sonuc,
        );

      case CevapGecerli():
        await kayitYaz(konum, sonuc);
        final ozet = await ozetOku(konum,
            yil: istenenGun.year, ay: istenenGun.month);
        return VakitDurumu(
          konum: konum,
          kaynak: VakitKaynagi.ag,
          bugun: sonuc.gun(istenenGun),
          gelecekGunler: _sonrakiGunler(sonuc, istenenGun),
          ozet: ozet,
        );
    }
  }

  /// İstenen günden sonraki günler, mevcut oldukları kadar.
  ///
  /// Ay sınırında sonraki ayın verisi gerekir; o ay henüz
  /// indirilmemişse liste burada kesilir (sessizce yanlış gün
  /// üretilmez).
  List<VakitGunu> _sonrakiGunler(CevapGecerli cevp, DateTime istenenGun) {
    final sirali = [...cevp.gunler]..sort((a, b) => a.tarih.compareTo(b.tarih));
    return sirali.where((g) {
      final f = g.tarih.difference(DateTime(istenenGun.year, istenenGun.month, istenenGun.day));
      return f.inDays >= 0 && f.inDays <= 7;
    }).toList(growable: false);
  }

  // -- SERİ DÖNÜŞÜM -----------------------------------------------------

  CevapGecerli _kayittanCevapGecerli(Map<String, dynamic> d) {
    final liste = d['gunler'];
    if (liste is! List || liste.isEmpty) {
      throw const FormatException('gunler listesi boş');
    }
    final gunler = <VakitGunu>[];
    for (final oge in liste) {
      if (oge is! Map) continue;
      final s = oge['s'];
      if (s is! Map) continue;
      final saatler = <String, String>{};
      for (final alan in VakitAlani.sirali) {
        final v = s[alan.anahtar];
        // Kayıttan okurken de saat doğrulanır: bozuk önbellek
        // ekrana sızmaz.
        final temiz = AladhanCevap.saatiTemizle(v);
        if (temiz == null) {
          throw FormatException('kayıtta geçersiz saat: ${alan.anahtar}');
        }
        saatler[alan.anahtar] = temiz;
      }
      gunler.add(VakitGunu(
        yil: oge['y'] as int,
        ay: oge['a'] as int,
        gun: oge['g'] as int,
        hicriTarih: (oge['h'] ?? '') as String,
        saatler: saatler,
        saatDilimi: (oge['tz'] ?? d['saatDilimi']) as String,
        cevapYontemId: (d['cevapYontemId'] ?? -1) as int,
      ));
    }
    if (gunler.isEmpty) throw const FormatException('okunabilir gün yok');
    return CevapGecerli(
      gunler: gunler,
      saatDilimi: d['saatDilimi'] as String,
      cevapYontemId: (d['cevapYontemId'] ?? -1) as int,
      cevapEnlem: (d['enlem'] as num?)?.toDouble() ?? 0,
      cevapBoylam: (d['boylam'] as num?)?.toDouble() ?? 0,
    );
  }

  static DateTime _tarihOku(dynamic v) {
    final p = v.toString().split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

/// Hata ayıklama çıktısı. Üretimde `debugPrint` yerine geçer, testlerde
/// sessizdir.
void debugEkle(String mesaj) {
  assert(() {
    // ignore: avoid_print
    print('[vakit] $mesaj');
    return true;
  }());
}
