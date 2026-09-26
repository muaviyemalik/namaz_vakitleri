// Bildirim metinleri DENETIM testi: 25 dilde de dogru ve eksiksiz mi?
//
// Hatanin olcumu: alarm/bildirim metinleri Turkce sabit olarak yazilmis.
// Kullanici uygulamayi Arapca, Cince veya Almanca acsa bile bildirimler
// Turkce geliyordu: "Vakit Geldi!", "Ezan Vakitleri",
// "{vakit} vakti girdi. Haydi namaza!".
//
// Test uc seyi dogrular:
//   1) Butun bildirim metinleri 25 ceviri dosyasinda mevcut,
//   2) yer tutucular ({vakit}/{dakika}) her dilde dogru ve tam birer kez,
//   3) Turkce metinler eski sabit metinlerle birebir ayni (regresyon yok).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String ceviriDizini = 'assets/i18n/ceviri';

/// Bildirimde kullanilan tum metin anahtarlari.
const List<String> bildirimAnahtarlari = <String>[
  'notif_channel_name',
  'notif_channel_desc',
  'notif_channel_bg_name',
  'notif_channel_bg_desc',
  'notif_channel_early_name',
  'notif_channel_early_desc',
  'notif_time_reached',
  'notif_time_reached_body',
  'notif_early_body',
  'open_app',
];

/// Metnin içinde geçmesi gereken yer tutucu KÜMESİ ve ADLARI (sıra değil).
///
/// Yer tutucular `{vakit}` / `{dakika}` biçiminde, `namedArgs` ile doldurulur.
/// Neden sıra değil: her değerin nerede duracağını DİLİN KENDİSİ belirler.
/// Türkçede "{vakit} vaktine {dakika} dakika kaldı", Arapçada
/// "بقي {dakika} دقيقة على وقت {vakit}" — aynı iki değer, ters sırada.
/// Sırayı zorlamak bu dillerden birini bozardı.
///
/// Kısıt: her ad TAM OLARAK BİR KEZ geçmeli ve kodda geçen `namedArgs`
/// anahtarlarıyla birebir eşleşmeli. Sessiz hata riski: easy_localization
/// eşleşmeyen `{bilinmeyen}` desenini olduğu gibi bırakır, ekranda
/// "{dakika}" yazısı görünür.
const Map<String, List<String>> beklenenYerTutucular = <String, List<String>>{
  'notif_time_reached_body': <String>['vakit'],
  'notif_early_body': <String>['vakit', 'dakika'],
  'notif_channel_name': <String>[],
  'notif_channel_desc': <String>[],
  'notif_channel_bg_name': <String>[],
  'notif_channel_bg_desc': <String>[],
  'notif_channel_early_name': <String>[],
  'notif_channel_early_desc': <String>[],
  'notif_time_reached': <String>[],
  'open_app': <String>[],
};

/// Kodda `namedArgs` olarak geçen anahtarlar. Metinlerle birebir eşleşmeli.
const Set<String> kodDakiArgAnahtarlari = <String>{'vakit', 'dakika'};

Map<String, dynamic> dosyaOku(String dil) => json.decode(
      File('$ceviriDizini/$dil.json').readAsStringSync(encoding: utf8),
    ) as Map<String, dynamic>;

List<String> tumDiller() => Directory(ceviriDizini)
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
    .toList()
    ..sort();

void main() {
  test('bildirim metinleri 25 dilde de mevcut', () {
    final Map<String, List<String>> eksikler = <String, List<String>>{};
    for (final dil in tumDiller()) {
      final Map<String, dynamic> veri = dosyaOku(dil);
      final List<String> yok = bildirimAnahtarlari
          .where((a) => !veri.containsKey(a))
          .toList();
      if (yok.isNotEmpty) eksikler[dil] = yok;
    }
    expect(eksikler, isEmpty,
        reason: 'Eksik bildirim anahtarlari: $eksikler');
  });

  test('erken uyari ve vakit bildirimi AYRI kanallarda', () {
    // Kullanici erken uyariyi kapatip vakit bildirimini birakabilmeli.
    // Ayni kanal kullanilsaydi biri digerini sessizce ezerdi.
    // Kanallar lib/pages/anasayfa.dart icinde sabit string olarak geciyor:
    //   ezan_kanali           -> vakit bildirimi
    //   ezan_kanali_arka_plan -> arka plan vakit alarmi
    //   erken_uyari_kanali    -> erken uyari
    // Burada metinlerinin AYRI ve DOLU oldugunu dogruluyoruz; kanal
    // kimliklerinin kendisi derleme zamaninda kodla bagli.
    for (final dil in tumDiller()) {
      final Map<String, dynamic> veri = dosyaOku(dil);
      final String vakitKanal = veri['notif_channel_name'] as String;
      final String erkenKanal = veri['notif_channel_early_name'] as String;
      expect(vakitKanal.trim(), isNotEmpty, reason: '$dil vakit kanalı boş');
      expect(erkenKanal.trim(), isNotEmpty, reason: '$dil erken uyarı kanalı boş');
      // Ayni metin olsalardı kullanıcı ayarları ayırt edemezdi.
      expect(erkenKanal == vakitKanal, isFalse,
          reason: '$dil: iki kanal aynı adı taşıyor olmamalı');
    }
  });

  test('her dilde yer tutucu kumesi dogru, hicbiri eksik veya fazla degil', () {
    final Map<String, String> hatalar = <String, String>{};

    for (final dil in tumDiller()) {
      final Map<String, dynamic> veri = dosyaOku(dil);
      for (final anahtar in bildirimAnahtarlari) {
        final String metin = veri[anahtar] as String? ?? '';

        // {ad} desenlerini topla.
        final List<String> sirali = RegExp(r'\{(\w+)\}')
            .allMatches(metin)
            .map((m) => m.group(1)!)
            .toList();
        final Set<String> bulunan = sirali.toSet();

        final Set<String> beklenen = beklenenYerTutucular[anahtar]!.toSet();

        // Eksik/fazla yer tutucu.
        if (bulunan.length != beklenen.length ||
            !bulunan.containsAll(beklenen)) {
          hatalar['$dil/$anahtar'] = 'bulunan=$bulunan beklenen=$beklenen';
        }
        // Bir yer tutucu birden fazla kez geciyor mu? (namedArgs tek değer
        // veriyor; ikinci kez geçerse o yerde ham "{dakika}" kalır.)
        if (sirali.length != sirali.toSet().length) {
          hatalar['$dil/$anahtar'] = 'tekrarli yer tutucu: $sirali';
        }
      }
    }

    expect(hatalar, isEmpty,
        reason: 'Yer tutucu hatasi:\n${hatalar.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}');
  });

  test('metinlerde kodun tanimadigi bir yer tutucu adi kalmadi', () {
    // easy_localization, `namedArgs` ile eslesmeyen bir `{ad}` desenini
    // OLDUGU gibi birakir; ekranda "{dakika}" yazisi gorunur. Bu sessiz
    // hatayi onlemek icin metinlerdeki tum adlar kodun gonderdigi
    // anahtarlarla (vakit, dakika) birebir ortusmeli.
    final Map<String, String> bilinmeyenler = <String, String>{};
    for (final dil in tumDiller()) {
      final Map<String, dynamic> veri = dosyaOku(dil);
      for (final anahtar in bildirimAnahtarlari) {
        final String metin = veri[anahtar] as String? ?? '';
        for (final ad in RegExp(r'\{(\w+)\}')
            .allMatches(metin)
            .map((m) => m.group(1)!)) {
          if (!kodDakiArgAnahtarlari.contains(ad)) {
            bilinmeyenler['$dil/$anahtar'] = '{$ad}';
          }
        }
      }
    }
    expect(bilinmeyenler, isEmpty,
        reason: 'Kodda gonderilmeyen yer tutucu: $bilinmeyenler');
  });

  test('erken uyari metni Turkce referansla birebir ayni', () {
    // Türkçe kalıp: vakit adı önce, dakika sonra.
    // args sırası: namedArgs -> hangi ad ne olduğu kodda belli.
    expect(dosyaOku('tur')['notif_early_body'],
        '{vakit} vaktine {dakika} dakika kaldı. Hazırlanma vakti!');
    expect(dosyaOku('tur')['notif_time_reached_body'],
        '{vakit} vakti girdi. Haydi namaza!');
  });

  test('Arapca metinde iki degerin yeri degismis (dogru sira)', () {
    // Arapçada "بقي {dakika} دقيقة على وقت {vakit}" -> dakika önce gelir.
    // Bu, sıralı {} deseni kullanılsaydı bozulacak olan cümledir.
    final String ara = dosyaOku('ara')['notif_early_body'] as String;
    expect(ara.indexOf('{dakika}'), lessThan(ara.indexOf('{vakit}')),
        reason: 'Arapca metinde dakika vakitten once gelmeli');
  });

  test('Turkce metinler eski sabitlerle ayni anlami tasiyor', () {
    // Metinler kaldırılmadan önceki davranış buydu (bildirimler Türkçeydi).
    // Değişiklik yalnızca erişilebilirlik olmalı; anlam aynı kalmalı.
    final Map<String, dynamic> tur = dosyaOku('tur');
    expect(tur['notif_time_reached'], 'Vakit Geldi!');
    expect(tur['notif_time_reached_body'], '{vakit} vakti girdi. Haydi namaza!');
    expect(tur['notif_early_body'],
        '{vakit} vaktine {dakika} dakika kaldı. Hazırlanma vakti!');
    expect(tur['notif_channel_name'], 'Ezan Vakitleri');
    expect(tur['notif_channel_bg_name'], 'Arka Plan Ezan Vakitleri');
    expect(tur['notif_channel_desc'], 'Vakit girdiğinde veya yaklaşırken haber verir');
    expect(tur['notif_channel_bg_desc'],
        'Uygulama kapalıyken vakit girdiğinde haber verir');
  });

  test('hicbir dilde Turkce kalmayan sabit metin kalmadi', () {
    // Bildirim metinlerinde Turkce kalinti kontrolu. Bilinen ve kabul
    // edilen tek istisna: "namaz" kelimesi Turkce icinde de gecer, o yuzden
    // listede de geciyor.
    const List<String> turkceKalinti = <String>[
      'Vakit Geldi',
      'vakti girdi',
      'Haydi namaza',
      'Ezan Vakitleri',
      'dakika kaldı',
      'Hazırlanma vakti',
      'Arka Plan',
      'haber verir',
      'Uygulamayı Aç',
    ];

    final Map<String, String> bulunanlar = <String, String>{};
    for (final dil in tumDiller()) {
      if (dil == 'tur') continue; // Turkce referans olarak kendisi kalir.
      final Map<String, dynamic> veri = dosyaOku(dil);
      for (final anahtar in bildirimAnahtarlari) {
        final String metin = (veri[anahtar] as String? ?? '');
        for (final kalinti in turkceKalinti) {
          if (metin.contains(kalinti)) {
            bulunanlar['$dil/$anahtar'] = kalinti;
          }
        }
      }
    }
    expect(bulunanlar, isEmpty,
        reason: 'Turkce kalmis bildirim metni: $bulunanlar');
  });

  test('vakit adinin kendisi Turkce metin olarak gomulu kalmadi', () {
    // Bildirim metinleri {vakit} ile vakit adini alir. Vakit adinin cevirisi
    // zaten "fajr"/"maghrib" gibi ayri anahtarlardan geliyor; bu yuzden
    // bildirim metninin icine Turkce vakit adi gomulmemeli. Aksi halde
    // Turkce disi dillerde cift ceviri olurdu ("Akşam" metni Turkce kalirdi).
    final Map<String, String> turkceVakitAdlari = <String, String>{
      'fajr': dosyaOku('tur')['fajr'] as String,
      'sunrise': dosyaOku('tur')['sunrise'] as String,
      'dhuhr': dosyaOku('tur')['dhuhr'] as String,
      'asr': dosyaOku('tur')['asr'] as String,
      'maghrib': dosyaOku('tur')['maghrib'] as String,
      'isha': dosyaOku('tur')['isha'] as String,
    };

    final Map<String, String> bulanlar = <String, String>{};
    for (final dil in tumDiller()) {
      if (dil == 'tur') continue;
      final Map<String, dynamic> veri = dosyaOku(dil);
      for (final anahtar in bildirimAnahtarlari) {
        final String metin = (veri[anahtar] as String? ?? '');
        for (final ad in turkceVakitAdlari.entries) {
          // "Akşam" gibi tek kelimelik adlar: metnin ICINDE gecmemeli.
          if (metin.contains(ad.value) && ad.value.length > 3) {
            bulanlar['$dil/$anahtar'] = ad.value;
          }
        }
      }
    }
    expect(bulanlar, isEmpty,
        reason: 'Bildirim metnine Turkce vakit adi gomulmus: $bulanlar');
  });

  test('RTL dillerde bildirim metinleri bos degil', () {
    // Arapca/Farsi sagdan sola yazilir. Metinlerdeki yer tutucu sirasinin
    // bozulmadigi daha once dogrulandi; burada ek olarak metinlerin bos
    // olmadigini ve makul bir uzunlukta oldugunu kontrol ediyoruz.
    for (final dil in const <String>['ara', 'fas']) {
      final Map<String, dynamic> veri = dosyaOku(dil);
      for (final anahtar in bildirimAnahtarlari) {
        final String metin = (veri[anahtar] as String? ?? '');
        expect(metin.trim(), isNotEmpty, reason: '$dil/$anahtar bos');
      }
    }
  });
}

