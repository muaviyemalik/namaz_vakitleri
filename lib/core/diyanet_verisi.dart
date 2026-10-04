// lib/core/diyanet_verisi.dart
//
// RESMÎ DİYANET VERİSİNİN OKUNMASI.
//
// BU KATMANIN VAR OLMA SEBEBİ
//
// Aladhan'da `method=13` seçmek resmî Diyanet verisi kullanmak DEĞİLDİR.
// Aladhan kendi hesabını yapar ve cevabı `(experimental)` etiketiyle döner.
// Ölçülen sapma (Ankara, 3 Ekim 2026): 6 vaktin 4'ü 1 dakika yanlış,
// ortalama 0,67 dakika. "Dakika düzeyinde birebir" hedefi yalnızca
// Diyanet'in kendi yayımladığı tabloyla gerçekleşir.
//
// DÖRT KURAL
//
//   1. KİMLİK. Veri `CityID` ile gelir. Katalogdaki ad güvenilir değildir
//      (ölçüm: CityID 17909 katalogda "USAK", sayfanın kendi adı "Ulubey").
//      Bu yüzden eşleme dosyası SayfaAdı'na göre üretilir.
//
//   2. AYARLAR RESMÎ SAATLERİ DEĞİŞTİRMEZ. Asr, yüksek enlem ve
//      hesaplama yöntemi bir hesaplama ayarıdır; resmî tabloda karşılıkları
//      yoktur. Bu yüzden bu katman o ayarları HİÇ OKUMAZ. Kullanıcıya
//      nedeni arayüzde açıkça söylenir.
//
//   3. UZUVSESİZ DÜŞÜŞ YOK. Tarih paketin dışındaysa ya da paketteki
//      boşluktaysa sonuç `null` DEĞİLDİR: durum ayrıca bildirilir. Başka
//      kaynağa sessizce geçilmez ve "Diyanet" etiketi kullanılmaz.
//
//   4. ESKİ HESAPLANMIŞ ÖNBELLEK KARIŞMAZ. Resmî veri bir varlık paketinden
//      okunur, `VakitDepo`'ya YAZILMAZ. Kullanıcının mevcut Aladhan önbelleği
//      silinmez; iki kaynak birbirinden ayrıdır.
//
// BELLEK
// Paket ~15 MB'dır ve AÇILIŞTA YÜKLENMEZ. Yalnız `paket.json` (~4 KB)
// okunur; kullanıcının ilindeki tek parça (~190 KB) seçildiğinde okunur ve
// önbelleğe alınır.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'aladhan_cevap.dart';

/// Türkiye'nin tek saat dilimi (2016'dan beri kalıcı UTC+3).
const String kTurkiyeSaatDilimi = 'Europe/Istanbul';

/// Diyanet'in Aladhan'daki karşılığı. Yalnız GÖSTERİM için kullanılır:
/// resmî veri zaten Diyanet hesabıdır, `method` isteği hiç atılmaz.
const int kDiyanetYontemId = 13;

/// İki tarafın da aynı sonucu vermesi zorunlu ad normalleştirme.
///
/// Bu kural `tool/diyanet_verisi_uret.py` içindeki `katla()` ile BİREBİR
/// aynı olmalıdır. Farklı olursa eşleme dosyasındaki anahtarlar çalışma
/// anında bulunamaz ve resmî mod sessizce kapalı kalır.
///
/// KURAL: NFC -> ı/İ/ş/ğ/ü/ö/ç Latin karşılıklarına -> küçük harf.
/// `UlkeVerisi.normalize` BİLEREK kullanılmaz: o, noktalama ve boşlukları
/// da siler ("Afyon Karahisar" -> "afyonkarahisar") ve Python tarafıyla
/// aynı sonucu vermez.
String diyanetAnahtarNormalize(String s) {
  final buf = StringBuffer();
  for (final r in s.runes) {
    int c = r;
    switch (c) {
      case 0x0131: // ı
      case 0x0130: // İ
        c = 0x69; // i
      case 0x015F: // ş
      case 0x015E: // Ş
        c = 0x73; // s
      case 0x011E: // Ğ
      case 0x011F: // ğ
        c = 0x67; // g
      case 0x00FC: // ü
      case 0x00DC: // Ü
        c = 0x75; // u
      case 0x00F6: // ö
      case 0x00D6: // Ö
        c = 0x6F; // o
      case 0x00E7: // ç
      case 0x00C7: // Ç
        c = 0x63; // c
    }
    buf.writeCharCode(c);
  }
  return buf.toString().toLowerCase();
}

/// Resmî paketin kimlik bilgisi ve kapsamı.
class DiyanetPaketi {
  final String surum;

  /// Kapsanan ilk ve son gün.
  final DateTime ilkTarih;
  final DateTime sonTarih;

  /// Paketin İÇİNDEKİ boşluklar (başlangıç..bitiş, gün sayısıyla).
  ///
  /// İlk paketteki 2026 boşluğu 4 Ekim arşiv aktarımıyla kapatıldı.
  /// Gelecek paketlerde boşluk varsa geniş tarih aralığından ayrı tutulur.
  final List<DiyanetBosluk> bosluklar;

  final int ilSayisi;
  final int yerlesimSayisi;
  final int verilenGunSayisi;

  /// Paket bütünlüğü (sha256) — `paket.json` içindeki değer.
  final String butunluk;

  final String kaynakUrl;
  final String edinmeTarihi;

  const DiyanetPaketi({
    required this.surum,
    required this.ilkTarih,
    required this.sonTarih,
    required this.bosluklar,
    required this.ilSayisi,
    required this.yerlesimSayisi,
    required this.verilenGunSayisi,
    required this.butunluk,
    required this.kaynakUrl,
    required this.edinmeTarihi,
  });

  factory DiyanetPaketi.fromJson(Map<String, dynamic> j) {
    final k = (j['kapsam'] as Map).cast<String, dynamic>();
    return DiyanetPaketi(
      surum: j['surum'] as String,
      ilkTarih: DateTime.parse(k['ilkTarih'] as String),
      sonTarih: DateTime.parse(k['sonTarih'] as String),
      bosluklar: ((k['iceridekiBosluklar'] as List?) ?? const [])
          .map((e) => DiyanetBosluk.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      ilSayisi: (k['ilSayisi'] as num).toInt(),
      yerlesimSayisi: (k['yerlesimSayisi'] as num).toInt(),
      verilenGunSayisi: (k['verilenGunSayisi'] as num).toInt(),
      butunluk: ((j['butunluk'] as Map)['paket'] as String?) ?? '',
      kaynakUrl: ((j['kaynak'] as Map)['sayfaUrlKalibi'] as String?) ?? '',
      edinmeTarihi: (j['edinmeTarihi'] as String?) ?? '',
    );
  }

  /// Geniş aralık denetimi: [gun] paketin uçları arasında mı?
  bool araliktaMi(DateTime gun) {
    final g = DateTime(gun.year, gun.month, gun.day);
    return !g.isBefore(ilkTarih) && !g.isAfter(sonTarih);
  }
}

/// Paketin içindeki, resmî kaynakta yayımlanmamış gün aralığı.
class DiyanetBosluk {
  final DateTime baslangic;
  final DateTime bitis;
  final int eksikGun;

  const DiyanetBosluk({
    required this.baslangic,
    required this.bitis,
    required this.eksikGun,
  });

  factory DiyanetBosluk.fromJson(Map<String, dynamic> j) => DiyanetBosluk(
        baslangic: DateTime.parse(j['baslangic'] as String),
        bitis: DateTime.parse(j['bitis'] as String),
        eksikGun: (j['eksikGun'] as num).toInt(),
      );

  bool icerir(DateTime gun) {
    final g = DateTime(gun.year, gun.month, gun.day);
    return !g.isBefore(baslangic) && g.isBefore(bitis);
  }
}

/// Resmî veriyle ilgili her olası durum. Sessiz düşüş YOKTUR.
enum DiyanetDurum {
  /// Resmî veri var.
  veriVar,

  /// Tarih paketin uçları dışında (örn. 2028).
  kapsamBitti,

  /// Tarih paketin içinde ama resmî kaynakta yayımlanmamış
  /// (2026-11-03..2026-12-31).
  paketBosluk,

  /// Bu yerleşim resmî katalogda yok, ya da kaydı ölü (HTTP 500).
  yerlesimYok,

  /// Paket/veri okunamadı.
  paketYok,
}

extension DiyanetDurumAciklama on DiyanetDurum {
  /// Arayüzün neden o sonucu göstereceğini anlatabilmesi için.
  ///
  /// Ekranda "Diyanet" etiketi YALNIZCA [veriVar] durumunda gösterilir.
  bool get resmiVeriMi => this == DiyanetDurum.veriVar;

  String get anahtari => switch (this) {
        DiyanetDurum.veriVar => 'veriVar',
        DiyanetDurum.kapsamBitti => 'kapsamBitti',
        DiyanetDurum.paketBosluk => 'paketBosluk',
        DiyanetDurum.yerlesimYok => 'yerlesimYok',
        DiyanetDurum.paketYok => 'paketYok',
      };
}

/// [DiyanetDepo.vakitler] sonucu.
class DiyanetSonuc {
  final DiyanetDurum durum;

  /// İstenen günün resmî vakitleri. Yalnız [DiyanetDurum.veriVar]'da dolu.
  final VakitGunu? gun;

  /// Bildirimleri planlamak için sonraki günler (varsa).
  final List<VakitGunu> siradakiGunler;

  final DiyanetPaketi? paket;

  /// Boşluğun ya da eşleşmesizliğin ayrıntısı (kullanıcıya gösterilebilir).
  final String? ayrinti;

  const DiyanetSonuc({
    required this.durum,
    this.gun,
    this.siradakiGunler = const [],
    this.paket,
    this.ayrinti,
  });

  bool get basariliMi => durum == DiyanetDurum.veriVar && gun != null;
}

/// Eşleme dosyasındaki tek satır: uygulama kaydı → resmî kimlik.
class DiyanetEsleme {
  final int cityId;

  /// Bu yerleşimin bulunduğu il parçası (`"TR/ankara.txt"`).
  ///
  /// Dosya adı PAKET ÜRETİCİSİNDE yazılır, burada yeniden hesaplanmaz.
  /// Böylece il adından slug üreten kural iki dilde iki kez yaşamaz ve
  /// ayrışıp sessizce "veri yok" duruma düşme riski ortadan kalkar.
  final String parca;

  const DiyanetEsleme(this.cityId, this.parca);
}

/// Resmî vakit paketini okuyan depo.
///
/// Paket AÇILIŞTA yüklenmez. `paket.json` (~4 KB) ilk ihtiyaçta okunur;
/// kullanıcının iline ait ~190 KB'lık parça yalnız o il seçildiğinde okunur.
class DiyanetDepo {
  DiyanetDepo({Future<String> Function(String)? paketMetni})
      : _paketMetni = paketMetni;

  final Future<String> Function(String)? _paketMetni;

  static const String paketYolu = 'assets/veri/diyanet/paket.json';
  static const String eslemeYolu = 'assets/veri/diyanet/esleme.txt';
  static const String parcaDizini = 'assets/veri/diyanet/';

  DiyanetPaketi? _paket;
  Map<String, DiyanetEsleme>? _esleme;

  /// Bellekte tutulacak en fazla il parçası sayısı.
  ///
  /// 2: kullanıcının o an bulunduğu il ve hemen önceki il. Günlük kullanımda
  /// bu zaten yeterlidir; 81 ilin tamamı hiçbir zaman bellekte olmaz.
  static const int _azamiParca = 2;

  final Map<String, List<Map<String, dynamic>>> _parcaOnbellegi = {};

  Future<String> _oku(String yol) async {
    final okuyucu = _paketMetni;
    if (okuyucu != null) return okuyucu(yol);
    return rootBundle.loadString(yol);
  }

  /// Paket kimliğini okur (yoksa `null`).
  ///
  /// Bu, uygulamanın açılışında yaptığı TEK Diyanet okumasıdır.
  Future<DiyanetPaketi?> paket() async {
    if (_paket != null) return _paket;
    try {
      final metin = await _oku(paketYolu);
      _paket = DiyanetPaketi.fromJson(
          (json.decode(metin) as Map).cast<String, dynamic>());
    } catch (_) {
      _paket = null;
    }
    return _paket;
  }

  /// Uygulamanın (il, ad) kaydını resmî `CityID`'ye bağlar.
  ///
  /// Anahtar KESİNTİR: normalize edilmiş il + ad. Benzerlik skoru yoktur.
  /// Birden çok aday varsa ya da aday yoksa `null` döner — bu durumda
  /// uygulama "resmî veri yok" gösterir; il merkezinin vakitleri
  /// KOPYALANMAZ.
  Future<DiyanetEsleme?> eslemeBul({required String il, required String ad}) async {
    final e = await _eslemeOku();
    if (e == null) return null;
    final anahtar = '${diyanetAnahtarNormalize(il)}|'
        '${diyanetAnahtarNormalize(ad)}';
    return e[anahtar];
  }

  Future<Map<String, DiyanetEsleme>?> _eslemeOku() async {
    if (_esleme != null) return _esleme;
    try {
      final metin = await _oku(eslemeYolu);
      final sonuc = <String, DiyanetEsleme>{};
      for (final satir in metin.split('\n')) {
        if (satir.isEmpty || satir.startsWith('#')) continue;
        final p = satir.split('|');
        // 3 alanlı (eski) satırlar da okunur: parça bilgisi yoksa il
        // parçası çözülemez, bu yüzden kayıt REDDEDİLMEZ ama parça boş
        // kalır ve çağıran taraf bunu "eşleşme yok" sayar.
        if (p.length < 3) continue;
        final id = int.tryParse(p[2]);
        if (id != null) {
          sonuc['${p[0]}|${p[1]}'] =
              DiyanetEsleme(id, p.length > 3 ? p[3] : '');
        }
      }
      _esleme = sonuc;
    } catch (_) {
      _esleme = null;
    }
    return _esleme;
  }

  /// İlin veri parçasını okur (önbellekli, EN FAZLA [_azamiParca] parça).
  ///
  /// SINIR NEDEN VAR? Paket 81 il parçasından oluşuyor ve kullanıcı günler
  /// içinde onlarca il arasında seçim yapabilir. Sınırsız bir önbellek
  /// "18 MB'ı açılışta yüklemiyoruz" avantajını kullanım sırasında geri
  /// alırdı: 81 ilin hepsi gezilince bellekte onlarca MB birikir.
  ///
  /// Bu yüzden en eski parça atılır (LRU). Kullanıcı tipik olarak tek ilde
  /// kalır; iki parçalık tavan onu hiç etkilemez.
  Future<List<Map<String, dynamic>>> parcaOku(String ilDosya) async {
    final varolan = _parcaOnbellegi.remove(ilDosya);
    if (varolan != null) {
      // Yeniden kullan: en son kullanılan sona taşınır.
      _parcaOnbellegi[ilDosya] = varolan;
      return varolan;
    }
    try {
      final metin = await _oku('$parcaDizini$ilDosya');
      final liste = <Map<String, dynamic>>[];
      String? cityId;
      for (final satir in metin.split('\n')) {
        if (satir.isEmpty) continue;
        if (satir.startsWith('#@')) {
          cityId = satir.substring(2).split('|').first;
          continue;
        }
        if (satir.startsWith('#')) continue;
        if (cityId == null) continue;
        final p = satir.split('|');
        if (p.length < 7) continue;
        liste.add({
          'cityId': int.tryParse(cityId) ?? -1,
          'yil': int.tryParse(p[0].substring(0, 4)),
          'ay': int.tryParse(p[0].substring(4, 6)),
          'gun': int.tryParse(p[0].substring(6, 8)),
          'saatler': [p[1], p[2], p[3], p[4], p[5], p[6]],
          'hicri': p.length > 7 ? p.sublist(7).join('|') : '',
        });
      }
      _parcaOnbellegi[ilDosya] = liste;
      while (_parcaOnbellegi.length > _azamiParca) {
        // Map sıralı olduğu için ilk anahtar en eski kullanımdır.
        _parcaOnbellegi.remove(_parcaOnbellegi.keys.first);
      }
      return liste;
    } catch (_) {
      return const [];
    }
  }

  /// Resmî vakitleri getirir.
  ///
  /// [cityId] resmî katalog kimliğidir. Asr/yüksek enlem/yöntem bilerek
  /// ALINMAZ: resmî tabloda bu ayarların karşılığı yoktur.
  Future<DiyanetSonuc> vakitler({
    required int cityId,
    required String ilDosya,
    required DateTime tarih,
  }) async {
    final p = await paket();
    if (p == null) {
      return const DiyanetSonuc(durum: DiyanetDurum.paketYok);
    }
    if (!p.araliktaMi(tarih)) {
      return DiyanetSonuc(
        durum: DiyanetDurum.kapsamBitti,
        paket: p,
        ayrinti: '${p.ilkTarih} .. ${p.sonTarih} arası resmî veri var',
      );
    }
    for (final b in p.bosluklar) {
      if (b.icerir(tarih)) {
        return DiyanetSonuc(
          durum: DiyanetDurum.paketBosluk,
          paket: p,
          ayrinti: '${b.baslangic} .. ${b.bitis} arası Diyanet '
              'henüz yayımlamadı (${b.eksikGun} gün)',
        );
      }
    }

    final satirlar = await parcaOku(ilDosya);
    if (satirlar.isEmpty) {
      return DiyanetSonuc(
          durum: DiyanetDurum.paketYok, paket: p, ayrinti: ilDosya);
    }

    VakitGunu? istenen;
    final siradaki = <VakitGunu>[];
    for (final s in satirlar) {
      if (s['cityId'] != cityId) continue;
      final y = s['yil'] as int?;
      final a = s['ay'] as int?;
      final g = s['gun'] as int?;
      if (y == null || a == null || g == null) continue;
      final gun = VakitGunu(
        yil: y,
        ay: a,
        gun: g,
        hicriTarih: (s['hicri'] as String?) ?? '',
        saatler: _saatHaritasi(s['saatler'] as List),
        saatDilimi: kTurkiyeSaatDilimi,
        cevapYontemId: kDiyanetYontemId,
      );
      if (gun.ayniGun(tarih)) {
        istenen = gun;
      } else {
        final f = gun.tarih.difference(
            DateTime(tarih.year, tarih.month, tarih.day)).inDays;
        if (f > 0 && f <= 7) siradaki.add(gun);
      }
    }

    if (istenen == null) {
      return DiyanetSonuc(
        durum: DiyanetDurum.yerlesimYok,
        paket: p,
        ayrinti: 'CityID $cityId için $ilDosya içinde gün yok',
      );
    }
    siradaki.sort((x, y2) => x.tarih.compareTo(y2.tarih));
    return DiyanetSonuc(
      durum: DiyanetDurum.veriVar,
      gun: istenen,
      siradakiGunler: siradaki,
      paket: p,
    );
  }

  Map<String, String> _saatHaritasi(List ham) {
    const alanlar = VakitAlani.sirali;
    final sonuc = <String, String>{};
    for (var i = 0; i < alanlar.length && i < ham.length; i++) {
      final s = ham[i] as String;
      if (s.length < 4) continue;
      sonuc[alanlar[i].anahtar] = '${s.substring(0, 2)}:${s.substring(2, 4)}';
    }
    return sonuc;
  }

  /// Bellekte tutulan il parçası sayısı (yalnız test/denetim için).
  ///
  /// Açılış yükünün ölçülmesinde kullanılır: "18 MB paket" ile "18 MB
  /// RAM'de yük" aynı şey DEĞİLDİR. Bu sayı, uygulamanın gerçekten yalnız
  /// seçilen ilin parçasını tuttuğunu kanıtlar.
  int get parcaOnbellekUzunlugu => _parcaOnbellegi.length;

  /// Test/denetim için belleği boşaltır.
  void onbellegiTemizle() {
    _parcaOnbellegi.clear();
  }
}