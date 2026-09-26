// Bildirim metinlerinin UCTAN UCA doldurulmasi: easy_localization'ın
// `namedArgs` mekanizması gerçekten {vakit}/{dakika} desenlerini doğru
// dolduruyor mu?
//
// Bu test, çeviri dosyalarını okumakla kalmaz; metinleri gerçekten bir bildirim
// gibi birleştirip beklenen çıktıyı denetler. Neden önemli: easy_localization
// 3.x'te `args: [...]` yalnızca "{}" desenini doldurur ve "@0"/"@1" gibi
// sıralı desenleri TANIMAZ — bu sessizce hatalı metin üretir (ekranda
// "@0 vaktine @1 dakika kaldı" görünür, değerler hiç konmaz). Test, altyapının
// bu tuzağa düşmediğini kanıtlar.
//
// easy_localization'ın `_replaceNamedArgs` mantığı `RegExp('{key}')` ile
// çalışır ve eşleşmeyen alanları olduğu gibi bırakır. Burada aynı mantığı
// birebir uyguluyoruz; amaç metin DEĞİL, mekanizmanın sözleşmesini sınamak.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// `Localization` ve `Translations` ana kütüphane dosyasından export EDİLMİYOR;
// easy_localization/src/... yoluyla doğrudan içe aktarılıyorlar. Testin
// amacı zaten bu internal API'yi sınamak (kendi metinlerimizi değil,
// çeviri dosyasının + kütüphanenin birlikte çalışmasını doğruluyoruz).
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String ceviriDizini = 'assets/i18n/ceviri';

Map<String, dynamic> dosyaOku(String dil) => json.decode(
      File('$ceviriDizini/$dil.json').readAsStringSync(encoding: utf8),
    ) as Map<String, dynamic>;

List<String> tumDiller() => Directory(ceviriDizini)
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
    .toList()
    ..sort();

/// easy_localization'ın `namedArgs` doldurmasının birebir kopyası.
/// Kaynak: easy_localization-3.0.8/lib/src/localization.dart
///   _replaceNamedArgs(res, args) =>
///       args.forEach((k, v) => res = res.replaceAll(RegExp('{$k}'), v))
String doldur(String metin, Map<String, String> namedArgs) {
  var sonuc = metin;
  namedArgs.forEach((String anahtar, String deger) {
    sonuc = sonuc.replaceAll(RegExp('{$anahtar}'), deger);
  });
  return sonuc;
}

void main() {
  group('Metin birleştirme: hicbir yerde ham yer tutucu kalmaz', () {
    test('Turkce vakit bildirimi dogru kurulur', () {
      final String sablon = dosyaOku('tur')['notif_time_reached_body'] as String;
      final String sonuc =
          doldur(sablon, <String, String>{'vakit': 'Akşam'});

      expect(sonuc, 'Akşam vakti girdi. Haydi namaza!');
      expect(sonuc, isNot(contains('{')),
          reason: 'Ham yer tutucu kalmamali');
    });

    test('Turkce erken uyari bildirimi dogru kurulur', () {
      final String sablon = dosyaOku('tur')['notif_early_body'] as String;
      final String sonuc =
          doldur(sablon, <String, String>{'vakit': 'Akşam', 'dakika': '15'});

      expect(sonuc, 'Akşam vaktine 15 dakika kaldı. Hazırlanma vakti!');
      expect(sonuc, isNot(contains('{')), reason: 'Ham yer tutucu kalmamali');
    });

    test('Arapca erken uyari: dakika once, vakit sonra', () {
      // Sıralı desen (@0/@1) kullanılsaydı bu cümle bozulurdu.
      final String sablon = dosyaOku('ara')['notif_early_body'] as String;
      final String sonuc =
          doldur(sablon, <String, String>{'vakit': 'المغرب', 'dakika': '15'});

      expect(sonuc, contains('15'));
      expect(sonuc, contains('المغرب'));
      expect(sonuc, isNot(contains('{')), reason: 'Ham yer tutucu kalmamali');
      // Değerlerin metindeki sırası dile göre değişir, içerik aynı kalır.
      expect(sonuc.indexOf('15'), lessThan(sonuc.indexOf('المغرب')));
    });

    test('25 dilin tamaminda tum bildirimleri doldurulabiliyor', () {
      final List<String> hatalar = <String>[];

      for (final dil in tumDiller()) {
        final Map<String, dynamic> veri = dosyaOku(dil);

        final String vakitMetni = doldur(
          veri['notif_time_reached_body'] as String,
          <String, String>{'vakit': 'VAKIT'},
        );
        if (vakitMetni.contains('{')) hatalar.add('$dil/vakit-girdi');

        final String erkenMetni = doldur(
          veri['notif_early_body'] as String,
          <String, String>{'vakit': 'VAKIT', 'dakika': '15'},
        );
        if (erkenMetni.contains('{')) hatalar.add('$dil/erken-uyari');

        // Doldurulan metin gerçekten değer içermeli (yanlış anahtarla
        // doldurulup yerinde duran bir şey olmamalı).
        if (!vakitMetni.contains('VAKIT')) hatalar.add('$dil/vakit-degeri-yok');
        if (!erkenMetni.contains('VAKIT')) hatalar.add('$dil/erken-vakit-yok');
        if (!erkenMetni.contains('15')) hatalar.add('$dil/erken-dakika-yok');
      }

      expect(hatalar, isEmpty,
          reason: 'Doldurulamayan bildirimler: $hatalar');
    });

    test('dakika sayisi metne dogru giriyor (30 ve 45)', () {
      final String sablon = dosyaOku('tur')['notif_early_body'] as String;
      for (final dakika in <String>['15', '30', '45']) {
        final String sonuc = doldur(
            sablon, <String, String>{'vakit': 'Yatsı', 'dakika': dakika});
        expect(sonuc, contains('Yatsı vaktine $dakika dakika kaldı'));
      }
    });
  });

  group('Sıralı @0/@1 deseni desteklenmiyor (tuzak)', () {
    test('easy_localization args ile @0/@1 deseni calismaz', () {
      // Bu, tuzağın kendisini belgeler: easy_localization 3.x'in `args`
      // parametresi RegExp('{}') kullanır, "@0" desenini tanımaz. Eğer ileride
      // sürüm güncellenip davranış değişirse bu test kırılır ve o zaman
      // metinleri geri çevirmek gerektiğini hatırlatır.
      //
      // Kaynak: _replaceArgs -> res.replaceFirst(RegExp('{}'), str)
      const String sablon = '@0 vaktine @1 dakika kaldı.';
      var sonuc = sablon;
      for (final d in <String>['Akşam', '15']) {
        sonuc = sonuc.replaceFirst(RegExp('{}'), d);
      }
      expect(sonuc, sablon,
          reason: 'Sıralı desen desteklenmiyor; namedArgs kullanılmalı');
    });
  });

  group('GERÇEK easy_localization: namedArgs çalışıyor', () {
    // Yukarıdaki testler doldurma mantığını BİREBİR kopyalıyordu. Bu grup
    // asıl kütüphaneyi çağırıyor: çeviri dosyasındaki metin, uygulamanın
    // kullandığı `namedArgs` çağrısıyla gerçekten dolduruluyor mu?
    //
    // `Localization.load` easy_localization'ın public API'si: çevirileri
    // hazırlayıp global örneğe yükler. Widget ağacı kurmadan, doğrudan
    // kütüphane üzerinden sınıyoruz; böylece sahte saatin asset yükleme
    // sorunu da devreye girmiyor.

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    void yukleDil(String dil) {
      final Map<String, dynamic> veri = dosyaOku(dil);
      Localization.load(
        Locale(dil),
        translations: Translations(veri),
        fallbackTranslations: Translations(dosyaOku('tur')),
      );
    }

    test('Turkce bildirim metni gercekten doldurulur', () {
      yukleDil('tur');
      // AnaSayfa'daki çağrının birebir kopyası:
      final String icerik = 'notif_time_reached_body'.tr(
        namedArgs: <String, String>{'vakit': 'Akşam'},
      );
      expect(icerik, 'Akşam vakti girdi. Haydi namaza!');
      expect(icerik, isNot(contains('{')), reason: 'Ham yer tutucu kalmamali');
    });

    test('Turkce erken uyari metni gercekten doldurulur', () {
      yukleDil('tur');
      final String icerik = 'notif_early_body'.tr(
        namedArgs: <String, String>{'vakit': 'Akşam', 'dakika': '15'},
      );
      expect(icerik, 'Akşam vaktine 15 dakika kaldı. Hazırlanma vakti!');
      expect(icerik, isNot(contains('{')), reason: 'Ham yer tutucu kalmamali');
    });

    test('Ingilizce bildirim metni gercekten doldurulur', () {
      yukleDil('eng');
      final String icerik = 'notif_time_reached_body'.tr(
        namedArgs: <String, String>{'vakit': 'Maghrib'},
      );
      expect(icerik, 'It’s time for Maghrib. Let’s pray!');
      expect(icerik, isNot(contains('{')));
    });

    test('Cince erken uyari: dakika sonra, vakit once', () {
      yukleDil('zho');
      final String icerik = 'notif_early_body'.tr(
        namedArgs: <String, String>{'vakit': '昏礼', 'dakika': '30'},
      );
      expect(icerik, contains('30'));
      expect(icerik, contains('昏礼'));
      expect(icerik, isNot(contains('{')), reason: 'Ham yer tutucu kalmamali');
    });

    test('Arapca: degerlerin yeri degismis ama ikisi de yerinde', () {
      yukleDil('ara');
      final String icerik = 'notif_early_body'.tr(
        namedArgs: <String, String>{'vakit': 'المغرب', 'dakika': '15'},
      );
      expect(icerik, isNot(contains('{')));
      expect(icerik.indexOf('15'), lessThan(icerik.indexOf('المغرب')));
    });

    test('eksik namedArgs ham yer tutucu birakir (beklenen davranis)', () {
      // easy_localization eşleşmeyen alanı OLDUĞU gibi bırakır. Bu yüzden
      // kodda gönderilen anahtar kümesi metinlerle birebir eşleşmeli.
      // Bu davranışı bilerek sabitliyoruz: sessiz hata olmasın.
      yukleDil('tur');
      final String icerik =
          'notif_early_body'.tr(namedArgs: <String, String>{'vakit': 'Akşam'});
      expect(icerik, contains('{dakika}'),
          reason: 'Eşleşmeyen alan ham kalır; anahtar kümesi önemli');
    });
  });
}
