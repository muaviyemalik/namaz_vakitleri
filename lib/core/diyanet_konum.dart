import 'dart:math' as math;

import '../data/ulke_verisi.dart';
import 'diyanet_verisi.dart';

class DiyanetKonumSonucu {
  final Sehir sehir;
  final bool ilMerkezi;
  const DiyanetKonumSonucu(this.sehir, {this.ilMerkezi = false});
}

/// Yerleşim noktaları idarî sınır değildir. Yalnız yakın ve ayrışan aday
/// veya koordinatla tutarlı kesin geocoder adı kabul edilir; fuzzy eşleme yok.
class DiyanetKonumCozucu {
  final DiyanetDepo depo;
  Future<List<Sehir>>? _liste;
  DiyanetKonumCozucu(this.depo);

  Future<List<Sehir>> _yukle() async {
    final sonuc = <Sehir>[];
    final kimlikler = <int>{};
    for (final s in await UlkeVerisi.instance.sehirler('TR')) {
      final e = await depo.eslemeBul(il: s.il, ad: s.ad);
      if (e != null && kimlikler.add(e.cityId)) {
        sonuc.add(
          diyanetAnahtarNormalize(s.il) == 'ankara' &&
                  diyanetAnahtarNormalize(s.ad) == 'ankara'
              // Mevcut uygulamanın Ankara başlangıç koordinatı. Şehir dosyasındaki
              // nokta il merkezinin 36 km batısında; veri üreticisine dokunulmaz.
              ? const Sehir(
                  ad: 'Ankara',
                  il: 'Ankara',
                  enlem: 39.9334,
                  boylam: 32.8597,
                )
              : s,
        );
      }
    }
    return sonuc;
  }

  Future<DiyanetKonumSonucu?> coz({
    required double enlem,
    required double boylam,
    required double hassasiyet,
    String? ulke,
    String il = '',
    List<String> adlar = const [],
  }) async {
    if (ulke != null && ulke != 'TR') return null;
    if (!enlem.isFinite ||
        !boylam.isFinite ||
        !hassasiyet.isFinite ||
        hassasiyet < 0 ||
        hassasiyet > 3000 ||
        enlem.abs() > 90 ||
        boylam.abs() > 180) {
      return null;
    }
    final liste = await (_liste ??= _yukle());
    final adaylar =
        liste
            .map((s) => (s, uzaklik(enlem, boylam, s.enlem, s.boylam)))
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
    if (adaylar.isEmpty) return null;
    final yakin = adaylar.first;
    final pay = hassasiyet / 1000;
    final ilAdi = diyanetAnahtarNormalize(
      il.trim().replaceAll(' Province', ''),
    );
    final isimler = adlar.map((a) => diyanetAnahtarNormalize(a.trim())).toSet();
    // Reverse geocoder yalnız ülke + il ile doğrulanan bir yardımcıdır.
    if (ulke == 'TR' && ilAdi.isNotEmpty) {
      final eslesen = adaylar
          .where(
            (a) =>
                diyanetAnahtarNormalize(a.$1.il) == ilAdi &&
                isimler.contains(diyanetAnahtarNormalize(a.$1.ad)) &&
                a.$2 + pay <= 25,
          )
          .toList();
      if (eslesen.length == 1) return DiyanetKonumSonucu(eslesen.single.$1);
    }
    // Offline ilçe: çok yakın, ikinci yerleşimden açıkça ayrışıyor.
    if (yakin.$2 + pay <= 3 &&
        (adaylar.length == 1 || adaylar[1].$2 - yakin.$2 > 2 * pay + 3)) {
      if (ilAdi.isEmpty || diyanetAnahtarNormalize(yakin.$1.il) == ilAdi) {
        return DiyanetKonumSonucu(yakin.$1);
      }
    }
    // İl merkezi ancak geocoder'ın il bilgisi yakındaki yerel adayla uyumluysa.
    // Ülke sınırları bilinmediği için sadece uzak noktaya bakıp il uydurulmaz.
    if (ulke == 'TR' &&
        ilAdi.isNotEmpty &&
        yakin.$2 + pay <= 30 &&
        diyanetAnahtarNormalize(yakin.$1.il) == ilAdi) {
      final merkezler = liste
          .where(
            (s) =>
                diyanetAnahtarNormalize(s.il) == ilAdi &&
                diyanetAnahtarNormalize(s.ad) == ilAdi,
          )
          .toList();
      if (merkezler.length == 1) {
        return DiyanetKonumSonucu(merkezler.single, ilMerkezi: true);
      }
    }
    return null;
  }

  /// Eski il bilgisi olmayan kayıt: aynı isim ve çok yakın koordinat gerekir.
  /// GPS çözümlemesiyle kayıtlı manuel şehri başka bir ilçeye taşımayız.
  Future<Sehir?> eskiKayit(String ad, double enlem, double boylam) async {
    final liste = await (_liste ??= _yukle());
    final isim = diyanetAnahtarNormalize(ad.trim());
    final adaylar = liste
        .where(
          (s) =>
              diyanetAnahtarNormalize(s.ad) == isim &&
              uzaklik(enlem, boylam, s.enlem, s.boylam) <= 3,
        )
        .toList();
    return adaylar.length == 1 ? adaylar.single : null;
  }

  static double uzaklik(double a, double b, double c, double d) {
    double rad(double v) => v * math.pi / 180;
    final h =
        math.pow(math.sin(rad(c - a) / 2), 2) +
        math.cos(rad(a)) *
            math.cos(rad(c)) *
            math.pow(math.sin(rad(d - b) / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }
}
