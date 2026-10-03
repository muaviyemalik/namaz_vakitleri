// Ceviri dosyalari TUTARLILIK testi.
//
// easy_localization'da bir anahtar eksikse arayuz o dilde ham anahtar adini
// gosterir; uyanma (fallback) de yoksa Turkce metne duser. Yani bir ceviri
// dosyasinda tek bir anahtarin eksik/yanlis yazilmasi o dili konusan
// kullaniciya kirik arayuz gosterir ve bu turden iki gercek hata bulundu:
//   - eng.json: "foundqible" (kodun kullandigi "found_qible" degil)
//   - zho.json: "qibla_found" ve "qibla_search" eksikti
//
// Test, 25 dosyanin anahtar kumesinin Turkce ile BIREBIR ayni oldugunu
// denetler: yeni bir anahtar eklenirken unutulan dosya olursa burada kirmizi
// olur. Ayni zamanda arayuzun kullandigi zorunlu anahtarlarin hepsinin
// gercekten her dosyada oldugunu dogrular.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String ceviriDizini = 'assets/i18n/ceviri';
const String referansDil = 'tur';

/// Arayuzde `.tr()` ile kullanilan ve HER dilde bulunmasi gereken anahtarlar.
/// Yeni bir arayuz metni eklerken buraya da eklenmeli.
const List<String> zorunluAnahtarlar = <String>[
  'all_languages',
  'app_name',
  'asr',
  'ayah_of_the_day',
  'calculation_method',
  'calculation_source_note',
  'city',
  'close',
  'country',
  'dark_mode',
  'data_load_error',
  'early_warning',
  'fajr',
  'found_qible',
  'hadith_of_the_day',
  'isha',
  'language',
  'license_aladhan_desc',
  'license_aladhan_terms',
  'license_aladhan_title',
  'license_city_db_desc',
  'license_city_db_title',
  'license_country_lang_desc',
  'license_country_lang_title',
  'license_geonames_desc',
  'license_geonames_notice',
  'license_geonames_title',
  'license_iso639_desc',
  'license_iso639_title',
  'license_odbl_notice',
  'license_quran_desc',
  'license_quran_terms',
  'license_quran_title',
  'loading',
  'loc_perm_denied',
  'method_auto',
  'no_internet_city',
  'notif_channel_bg_desc',
  'notif_channel_bg_name',
  'notif_channel_desc',
  'notif_channel_name',
  'notif_early_body',
  'notif_time_reached',
  'notif_time_reached_body',
  'qibla',
  'qibla_found',
  'qibla_not_found',
  'qibla_search',
  'reset',
  'retry',
  'select_city',
  'select_country',
  'select_language',
  'select_theme',
  'settings',
  'share',
  'special_day_no_date',
  'special_day_no_description',
  'special_day_unknown',
  'special_days',
  'tasbih',
  'time_remaining',
  'times',
  'today_times',
  'turn_qible',
];

Map<String, dynamic> dosyaOku(String dil) => json.decode(
      File('$ceviriDizini/$dil.json').readAsStringSync(encoding: utf8),
    ) as Map<String, dynamic>;

Set<String> anahtarlar(String dil) => dosyaOku(dil).keys.toSet();

List<String> tumDiller() => Directory(ceviriDizini)
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
    .toList()
    ..sort();

void main() {
  test('25 ceviri dosyasi var', () {
    expect(tumDiller().length, 25);
  });

  test('her dosyanin anahtar kumesi Turkce ile birebir ayni', () {
    final Set<String> referans = anahtarlar(referansDil);
    final Map<String, List<String>> sorunlar = <String, List<String>>{};

    for (final dil in tumDiller()) {
      if (dil == referansDil) continue;
      final Set<String> kume = anahtarlar(dil);

      final List<String> eksikler = referans.difference(kume).toList()..sort();
      final List<String> fazlalar = kume.difference(referans).toList()..sort();
      if (eksikler.isNotEmpty || fazlalar.isNotEmpty) {
        sorunlar[dil] = <String>[
          if (eksikler.isNotEmpty) 'eksik: ${eksikler.join(', ')}',
          if (fazlalar.isNotEmpty) 'fazlalik: ${fazlalar.join(', ')}',
        ];
      }
    }

    expect(sorunlar, isEmpty,
        reason: 'Anahtar kumesi tutarsiz. Eksik anahtar, o dilde ham anahtar '
            'metni gosterir:\n${sorunlar.entries.map((e) => '  ${e.key} -> ${e.value.join(' | ')}').join('\n')}');
  });

  test('zorunlu anahtarlar 25 dosyada da mevcut', () {
    final Map<String, List<String>> sorunlar = <String, List<String>>{};
    for (final dil in tumDiller()) {
      final Set<String> kume = anahtarlar(dil);
      final List<String> eksikler =
          zorunluAnahtarlar.where((a) => !kume.contains(a)).toList();
      if (eksikler.isNotEmpty) sorunlar[dil] = eksikler;
    }
    expect(sorunlar, isEmpty,
        reason: 'Zorunlu anahtarlar eksik:\n${sorunlar.entries.map((e) => '  ${e.key} -> ${e.value.join(', ')}').join('\n')}');
  });

  group('Bildirim sonucu uyari metinleri', () {
    // Bu uyarilar motorun `uyari` ALANININ degerleridir ve AnaSayfa'da
    // ekrana cizilir. Uc durum AYRI ayri anlatilir: kurulum basarisiz,
    // iptal basarisiz, basarili yaklasik mod.
    const uyariAnahtarlari = <String>[
      'exact_alarm_yok',
      'bildirim_kurulamadi',
      'bildirim_iptal_edilemedi',
    ];

    test('uyari anahtarlari Turkce dosyasinda mevcut', () {
      final Map<String, dynamic> tur = dosyaOku(referansDil);
      final List<String> eksikler = uyariAnahtarlari
          .where((a) => !tur.containsKey(a))
          .toList();
      expect(eksikler, isEmpty, reason: 'Eksik uyari anahtari: $eksikler');
    });

    test('uyari metinleri 25 dilin TAMAMINDA dolu', () {
      // Anahtar kumesi tutarliligi ayrica yukarida sinnanir; burada ozel
      // olarak bu uc anahtarin her dilde var ve BOS olmadigi kontrol edilir.
      final Map<String, List<String>> sorunlar = <String, List<String>>{};
      for (final dil in tumDiller()) {
        final Map<String, dynamic> d = dosyaOku(dil);
        final List<String> eksikler = <String>[];
        for (final a in uyariAnahtarlari) {
          final Object? v = d[a];
          if (v is! String || v.trim().isEmpty) eksikler.add(a);
        }
        if (eksikler.isNotEmpty) sorunlar[dil] = eksikler;
      }
      expect(sorunlar, isEmpty,
          reason: '25 dilin tamaminda dolu metin olmali:\n'
              '${sorunlar.entries.map((e) => '  ${e.key} -> ${e.value.join(', ')}').join('\n')}');
    });

    test('metinler TESLIM GARANTISI VERMEZ', () {
      // Uyari metni, bildirimin GECECE'GI vaadinde bulunmamalidir:
      // yaklasik modda cihaz kisitlari (Doze, pil optimizasyonu)
      // bildirimi geciktirebilir, kurulamadiginda hic gelmez. Vaat
      // dogrudan ifadelerle verilirse kullanici yaniltilir.
      final Map<String, dynamic> tur = dosyaOku(referansDil);
      const vaatler = <String>[
        'gelir', 'gelecek', 'gönderilecek', 'bildirilecek', 'garanti',
      ];
      final List<String> supheliler = <String>[];
      for (final a in uyariAnahtarlari) {
        final String m = (tur[a]! as String).toLowerCase();
        for (final v in vaatler) {
          if (m.contains(v)) supheliler.add('$a -> "$v"');
        }
      }
      expect(supheliler, isEmpty,
          reason: 'Uyari metinleri teslim vaadi icermemeli: $supheliler');
    });

    test('kurulum hatasi, iptal hatasi ve yaklasik mod AYRI metin', () {
      final Map<String, dynamic> tur = dosyaOku(referansDil);
      // Uc farkli sorundur; ayni metni gostermek kullaniciyi yaniltir.
      expect(tur['bildirim_kurulamadi'],
          isNot(tur['bildirim_iptal_edilemedi']));
      expect(tur['bildirim_kurulamadi'], isNot(tur['exact_alarm_yok']));
      expect(tur['bildirim_iptal_edilemedi'], isNot(tur['exact_alarm_yok']));
    });
  });

  test('hicbir deger bos degil', () {
    final Map<String, String> boslar = <String, String>{};
    for (final dil in tumDiller()) {
      dosyaOku(dil).forEach((anahtar, deger) {
        if (deger is String && deger.trim().isEmpty) {
          boslar['$dil/$anahtar'] = deger;
        }
      });
    }
    expect(boslar, isEmpty, reason: 'Bos ceviri degerleri: $boslar');
  });
}
