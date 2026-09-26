// Uretilen sehir verisinin butunlugu. Araca bagli degildir; dosyalari
// oldugu gibi denetler. test/sehir_kapsam_test.dart ile ayni mantigi
// paylasir ama burada sunucu tarafi calisir (245 ulke, 160 bin satir).
import 'dart:convert';
import 'dart:io';

const _ENLEM = 0;
const _BOYLAM = 1;
const _AD = 2;
const _IL = 3;
const _NUFUS = 4;
const _TAKMA = 5;

void main() {
  final sehirDir = Directory('assets/veri/sehirler');
  final dosyalar = sehirDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var toplamKayit = 0;
  var toplamSehir = 0;
  var toplamNufuslu = 0;
  final bicimHatalari = <String>[];
  final MUKERRERAdIl = <String>[];
  final MUKERRERKoordinat = <String>[];
  final takmaCakismasi = <String>[];
  final negatifNufus = <String>[];
  final ilEtiketiHatali = <String>[];

  for (final f in dosyalar) {
    final iso = f.uri.pathSegments.last.replaceAll('.txt', '');
    final satirlar =
        f.readAsLinesSync(encoding: utf8).where((l) => l.trim().isNotEmpty).toList();
    toplamKayit += satirlar.length;

    final adIl = <String>{};
    final koordinatlar = <String, String>{};
    final anaAdlar = <String>{};

    for (final satir in satirlar) {
      final p = satir.split('|');
      if (p.length != 6) {
        bicimHatalari.add('$iso: ${p.length} alan -> "$satir"');
        continue;
      }
      final enlem = double.tryParse(p[_ENLEM]);
      final boylam = double.tryParse(p[_BOYLAM]);
      final nufus = int.tryParse(p[_NUFUS]);
      if (enlem == null || boylam == null || nufus == null) {
        bicimHatalari.add('$iso: sayi okunamadi -> "$satir"');
        continue;
      }
      if (enlem < -90 || enlem > 90 || boylam < -180 || boylam > 180) {
        bicimHatalari.add('$iso: koordinat gecersiz -> "$satir"');
        continue;
      }
      if (nufus < 0) negatifNufus.add('$iso: "$satir"');
      if (p[_AD].trim().isEmpty) bicimHatalari.add('$iso: ad bos -> "$satir"');
      if (nufus > 0) {
        toplamNufuslu++;
        if (nufus >= 15000) toplamSehir++;
      }

      // Ayni (ad, il) iki kez gecmemeli
      final anahtar = '${p[_AD]}|${p[_IL]}';
      if (!adIl.add(anahtar)) MUKERRERAdIl.add('$iso: $anahtar');
      anaAdlar.add(p[_AD]);

      // Ayni koordinat iki kez gecmemeli
      final k = '$enlem|$boylam';
      final onceki = koordinatlar[k];
      if (onceki != null) {
        MUKERRERKoordinat.add('$iso: $k -> "$onceki" ve "${p[_AD]}"');
      } else {
        koordinatlar[k] = p[_AD];
      }

      // Takma ad, baska bir kaydin ana adiyla cakismamali
      if (p[_TAKMA].trim().isNotEmpty) {
        for (final t in p[_TAKMA].split(',')) {
          if (t.trim() == p[_AD]) {
            takmaCakismasi.add('$iso: takma ad ana adla ayni -> "$satir"');
          }
        }
      }

      // Il adi, sehir adinin bas harfleriyle baslamiyorsa dikkat gerekir
      // (yildirim uyarisi, hata degil)
      if (p[_IL].isNotEmpty && p[_AD].isNotEmpty) {
        final ilK = p[_IL].toLowerCase();
        final adK = p[_AD].toLowerCase();
        if (ilK.length > 3 && adK.length > 3) {
          final ilKisa = ilK.substring(0, 4);
          final adKisa = adK.substring(0, 4);
          if (ilKisa != adKisa && !adK.startsWith(ilKisa.substring(0, 3))) {
            ilEtiketiHatali.add('$iso: ${p[_IL]} / ${p[_AD]}');
          }
        }
      }
    }
  }

  void goster(String baslik, List<String> liste, {int gosterim = 8}) {
    print('$baslik: ${liste.length}');
    for (final e in liste.take(gosterim)) {
      print('    $e');
    }
    if (liste.length > gosterim) {
      print('    ... ve ${liste.length - gosterim} tane daha');
    }
    print('');
  }

  print('ulke dosyasi     : ${dosyalar.length}');
  print('toplam kayit     : $toplamKayit');
  print('nufusu bilinen   : $toplamNufuslu');
  print('sehir (>=15000)  : $toplamSehir');
  print('koy              : ${toplamKayit - toplamSehir}');
  print('');

  goster('BICIM HATASI', bicimHatalari);
  goster('MUKERRER (ad, il)', MUKERRERAdIl);
  goster('MUKERRER KOORDINAT', MUKERRERKoordinat);
  goster('TAKMA AD CAKISMASI', takmaCakismasi);
  goster('NEGATIF NUFUS', negatifNufus);
  goster('IL ETIKETI SUPHELI (il adi ile sehir adi uyusmuyor)', ilEtiketiHatali,
      gosterim: 15);
}
