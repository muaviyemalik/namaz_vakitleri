import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'aladhan_cevap.dart';
import 'diyanet_verisi.dart';

class DiyanetAgSonuc {
  final VakitGunu bugun;
  final List<VakitGunu> gelecekGunler;
  final DateTime indirildi;
  final bool onbellekten;
  const DiyanetAgSonuc(
    this.bugun,
    this.gelecekGunler,
    this.indirildi, {
    this.onbellekten = false,
  });
}

/// Yalnız Diyanet'in HTTPS tablosu; hesaplanmış önbellekten tamamen ayrı.
/// Gömülü veri bulunmadığında çağrılır. Başarısızlık resmî etiket üretmez.
class DiyanetGuncelDepo {
  DiyanetGuncelDepo({http.Client? istemci, DateTime Function()? simdi})
    : _istemci = istemci,
      _simdi = simdi ?? DateTime.now;
  final http.Client? _istemci;
  final DateTime Function() _simdi;
  static const _onek = 'diyanet_resmi_web_v1_';
  final Map<int, DateTime> _sonDeneme = {};

  Future<DiyanetAgSonuc?> oku(int cityId, DateTime tarih, {int ileriGun = 7}) async {
    if (cityId <= 0) return null;
    final simdi = _simdi();
    final h = await SharedPreferences.getInstance();
    final anahtar = '$_onek$cityId';
    DiyanetAgSonuc? kayit;
    try {
      final j = jsonDecode(h.getString(anahtar) ?? '') as Map;
      final indirildi = DateTime.parse(j['indirildi'] as String);
      if (!indirildi.isAfter(simdi) &&
          simdi.difference(indirildi) <= const Duration(days: 7)) {
        kayit = cozumle(
          j['html'] as String,
          cityId,
          tarih,
          indirildi,
          onbellekten: true,
          ileriGun: ileriGun,
        );
      }
    } catch (_) {
      /* Bozuk kayıt resmî veri sayılmaz. */
    }
    if (kayit != null &&
        simdi.difference(kayit.indirildi) < const Duration(hours: 1)) {
      return kayit;
    }
    final son = _sonDeneme[cityId];
    if (son != null && simdi.difference(son) < const Duration(minutes: 5)) {
      return kayit;
    }
    _sonDeneme[cityId] = simdi;
    final istemci = _istemci ?? http.Client();
    try {
      final uri = Uri.https(
        'namazvakitleri.diyanet.gov.tr',
        '/tr-TR/$cityId/x',
      );
      final metin = await _sayfayiGetir(
        istemci,
        uri,
        cityId,
      ).timeout(const Duration(seconds: 8));
      if (metin == null) return kayit;
      final sonuc = cozumle(metin, cityId, tarih, simdi, ileriGun: ileriGun);
      if (sonuc == null) return kayit;
      await h.setString(
        anahtar,
        jsonEncode({'indirildi': simdi.toIso8601String(), 'html': metin}),
      );
      // En çok dört yerleşimin güncel tablosunu sakla.
      final digerleri =
          h.getKeys().where((k) => k.startsWith(_onek) && k != anahtar).toList()
            ..sort((a, b) => _kayitTarihi(h, a).compareTo(_kayitTarihi(h, b)));
      while (digerleri.length > 3) {
        await h.remove(digerleri.removeAt(0));
      }
      return sonuc;
    } catch (_) {
      return kayit;
    } finally {
      if (_istemci == null) istemci.close();
    }
  }

  static Future<String?> _sayfayiGetir(
    http.Client istemci,
    Uri uri,
    int cityId,
  ) async {
    for (var adim = 0; adim < 3; adim++) {
      if (uri.scheme != 'https' ||
          uri.host != 'namazvakitleri.diyanet.gov.tr' ||
          uri.pathSegments.length < 2 ||
          uri.pathSegments[0] != 'tr-TR' ||
          uri.pathSegments[1] != '$cityId')
        return null;
      final cevap = await istemci.send(
        http.Request('GET', uri)..followRedirects = false,
      );
      if ([301, 302, 303, 307, 308].contains(cevap.statusCode)) {
        final hedef = cevap.headers['location'];
        if (hedef == null) return null;
        uri = uri.resolve(hedef);
        await cevap.stream.drain<void>();
        continue;
      }
      if (cevap.statusCode != 200) return null;
      final bayt = await cevap.stream.fold<List<int>>([], (toplam, parca) {
        if (toplam.length + parca.length > 2000000)
          throw const FormatException('Büyük tablo');
        return toplam..addAll(parca);
      });
      return utf8.decode(bayt);
    }
    return null;
  }

  static DateTime _kayitTarihi(SharedPreferences h, String k) {
    try {
      return DateTime.parse((jsonDecode(h.getString(k)!) as Map)['indirildi']);
    } catch (_) {
      return DateTime(1970);
    }
  }

  /// Aynı CityID, gerçek tarih, altı sıralı saat ve tutarlı tekrarlar şart.
  static DiyanetAgSonuc? cozumle(
    String metin,
    int cityId,
    DateTime tarih,
    DateTime indirildi, {
    bool onbellekten = false,
    int ileriGun = 7,
  }) {
    final doc = html.parse(metin);
    final canonical = Uri.tryParse(
      doc.querySelector('link[rel="canonical"]')?.attributes['href'] ?? '',
    );
    if (canonical == null ||
        canonical.scheme != 'https' ||
        canonical.host != 'namazvakitleri.diyanet.gov.tr' ||
        canonical.pathSegments.length < 2 ||
        canonical.pathSegments[0] != 'tr-TR' ||
        canonical.pathSegments[1] != '$cityId') {
      return null;
    }
    final kimlik = RegExp(r'\bvar\s+ilceId\s*=\s*(\d+)\s*;').firstMatch(metin);
    if (kimlik?.group(1) != '$cityId') return null;
    const aylar = [
      'ocak',
      'subat',
      'mart',
      'nisan',
      'mayis',
      'haziran',
      'temmuz',
      'agustos',
      'eylul',
      'ekim',
      'kasim',
      'aralik',
    ];
    final gunler = <DateTime, VakitGunu>{};
    for (final tr in doc.querySelectorAll('tr')) {
      final td = tr.querySelectorAll('td');
      if (td.length != 8) continue;
      final m = RegExp(
        r'^(\d{1,2})\s+(\S+)\s+(\d{4})(?:\s|$)',
      ).firstMatch(td[0].text.trim());
      if (m == null) continue;
      final ay = aylar.indexOf(diyanetAnahtarNormalize(m[2]!)) + 1;
      if (ay == 0) return null;
      final yil = int.parse(m[3]!);
      final gun = int.parse(m[1]!);
      final dt = DateTime(yil, ay, gun);
      if (dt.year != yil || dt.month != ay || dt.day != gun) return null;
      final saatler = <String, String>{};
      var once = -1;
      for (var i = 0; i < 6; i++) {
        final s = td[i + 2].text.trim();
        if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(s)) return null;
        final dakika =
            int.parse(s.substring(0, 2)) * 60 + int.parse(s.substring(3));
        if (dakika == 0 || dakika <= once) return null;
        once = dakika;
        saatler[VakitAlani.sirali[i].anahtar] = s;
      }
      final eski = gunler[dt];
      if (eski != null && jsonEncode(eski.saatler) != jsonEncode(saatler)) {
        return null;
      }
      gunler[dt] = VakitGunu(
        yil: yil,
        ay: ay,
        gun: gun,
        hicriTarih: td[1].text.trim(),
        saatler: saatler,
        saatDilimi: kTurkiyeSaatDilimi,
        cevapYontemId: kDiyanetYontemId,
      );
    }
    final bugun = gunler[DateTime(tarih.year, tarih.month, tarih.day)];
    if (bugun == null) return null;
    final gelecek = gunler.values.where((g) {
      final fark = g.tarih.difference(bugun.tarih).inDays;
      return fark > 0 && fark <= ileriGun;
    }).toList()..sort((a, b) => a.tarih.compareTo(b.tarih));
    return DiyanetAgSonuc(bugun, gelecek, indirildi, onbellekten: onbellekten);
  }
}
