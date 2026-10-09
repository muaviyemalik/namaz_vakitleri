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
  'setup_title', 'setup_city', 'setup_alert', 'setup_permissions',
  'setup_location_off', 'setup_location_denied', 'setup_location_error',
  'setup_city_desc', 'setup_alert_desc', 'setup_silent_desc',
  'setup_permissions_desc', 'setup_notification_desc', 'setup_alarm_desc',
  'setup_location_desc', 'setup_granted', 'setup_missing', 'setup_not_checked',
  'setup_request', 'setup_missing_desc', 'setup_permission_error',
  'setup_back', 'setup_next', 'setup_finish',
  'all_languages',
  'notification_settings',
  'notification_settings_desc',
  'prayer_notifications',
  'adhan_mode',
  'notification_only',
  'adhan_silent',
  'adhan_volume_desc',
  'adhan_dnd',
  'adhan_dnd_desc',
  'adhan_controls_desc',
  'reminder_common_desc',
  'reminder_sound',
  'warm_rise',
  'sound_preview',
  'ezan_stop',
  'alarm_access',
  'alarm_access_desc',
  'system_notifications',
  'notification_save_failed',
  'notification_preview_failed',
  'min_before_60',

  'app_name',
  // --- Kaynak gostergesi (AnaSayfa) ---
  'kaynak_diyanet',
  'kaynak_diyanet_guncel',
  'kaynak_hesaplanmis',
  'kaynak_resmi_onbellek',
  'kaynak_resmi_web',
  'kaynak_alindi',
  'kaynak_surum_ve_tarih',
  'resmi_not_asr_enlem',
  // --- Konum uyarilari ---
  'konum_bulundu',
  'konum_eski_korundu',
  'konum_ilce_kesinlesmedi',
  'konum_yerlesim_kesinlesmedi',
  // --- Ayarlar: resmi Diyanet tercihi ve hesaplama ayarlari ---
  'ayar_kapali_resmi_not',
  'diyanet_acik_desc',
  'diyanet_acik_veri_yok_desc',
  'diyanet_kapali_desc',
  'diyanet_yalniz_turkiye',
  'yuksek_enlem_desc',
  'asr_resmi_not',
  'yuksek_enlem_resmi_not',
  'yuksek_enlem_hesaplanmis_not',
  // --- Zikirmatik hedefi ---
  'hedef_sayisi',
  'zikir_hedef_tamamlandi',
  'zikir_hedef_bildirim',
  // --- Diyanet veri ayrintilari (kullaniciya gosterilir) ---
  'diyanet_aralik_var',
  'diyanet_aralik_yayimlanmadi',
  'diyanet_gun_yok',
  // --- Bildirim ---
  'kanal_vakit',
  'kanal_erken_uyari',
  'kanal_gunes_dogumu',
  'saat_dilimi_cozulemedi',
  // --- Lisans: Diyanet girdisi ceviriEki ile URETILEN iki anahtar ---
  'license_diyanet_title',
  'license_diyanet_desc',
  'lisans_diyanet_kaynak',
  // --- Hesaplama yontemleri (22 yontem) ---
  'yontem_0',
  'yontem_1',
  'yontem_2',
  'yontem_3',
  'yontem_4',
  'yontem_5',
  'yontem_7',
  'yontem_8',
  'yontem_9',
  'yontem_10',
  'yontem_11',
  'yontem_12',
  'yontem_13',
  'yontem_14',
  'yontem_16',
  'yontem_17',
  'yontem_18',
  'yontem_19',
  'yontem_20',
  'yontem_21',
  'yontem_22',
  'yontem_23',
  'parametre_fajr',
  'parametre_isha',
  'parametre_isha_aralik',
  // --- Asr / yuksek enlem enum adlari ---
  'asr_standart_ad',
  'asr_hanafi_ad',
  'yuksek_enlem_yarisi_ad',
  'yuksek_enlem_yedide_bir_ad',
  'yuksek_enlem_aci_ad',
  // --- Widget (Android kaynak dosyalariyla ayni icerik) ---
  'widget_vakit_bekleniyor',
  'widget_ayet_acilis',
  'widget_hadis_acilis',
  'widget_ayet_bulunamadi',
  'widget_hadis_bulunamadi',
  'widget_vakit_acilis',
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

  test('DINAMIK uretilen tum anahtarlar 25 dosyada da var', () {
    // Bu anahtarlar kodda DIZGI olarak yazili degil; birlestirme ile
    // uretiliyor. Statik arama onlari gormez, bu yuzden ayrica denetlenir:
    //
    //   - Lisans basligi/aciklamasi: `'${g.ceviriEki}_title'.tr()`
    //     `lisans_bilgileri.dart` icindeki her `ceviriEki` degerinden
    //     uretilir. (Once `license_diyanet_title/desc` HICbir dilde
    //     yoktu; yasal notlar sayfasi ham anahtar adi gosteriyordu.)
    //   - Bildirim uyarilari: motor bir ANAHTAR dizesi uretip
    //     `uyari` alaninda doner, ekran `.tr()` ile cozer.
    const ceviriEkiDegerleri = <String>[
      'license_city_db',
      'license_country_lang',
      'license_geonames',
      'license_iso639',
      'license_diyanet',
      'license_aladhan',
      'license_quran',
    ];
    const uyariAnahtarlari = <String>[
      'exact_alarm_yok',
      'bildirim_kurulamadi',
      'bildirim_iptal_edilemedi',
      'saat_dilimi_cozulemedi',
    ];

    final Map<String, List<String>> sorunlar = <String, List<String>>{};
    for (final dil in tumDiller()) {
      final Set<String> kume = anahtarlar(dil);
      final List<String> eksikler = <String>[
        for (final e in ceviriEkiDegerleri) ...<String>[
          '${e}_title',
          '${e}_desc',
        ],
        ...uyariAnahtarlari,
      ].where((a) => !kume.contains(a)).toList();
      if (eksikler.isNotEmpty) sorunlar[dil] = eksikler;
    }

    expect(sorunlar, isEmpty,
        reason: 'Kodda birlestirmeyle uretilen anahtarlar eksik. Eksik '
            'anahtar, o dilde ham anahtar adi olarak gorunur:\n'
            '${sorunlar.entries.map((e) => '  ${e.key} -> ${e.value.join(', ')}').join('\n')}');
  });

  test('Android values-<xx>/strings.xml ceviri dosyalariyla ayni icerigi tasiyor', () {
    // Widget ve launcher etiketi uygulama acilmadan once gorunur; bu
    // yuzden Android tarafinda AYRI bir ceviri katmani vardir. Iki katman
    // birbirinden ayriysa widget basligi ile uygulama metni uyusmaz.
    //
    // Android string kaynak adi -> ceviri anahtari eslesmesi.
    const eslesme = <String, String>{
      'app_name': 'app_name',
      'widget_vakit_baslik': 'next_time',
      'widget_gunluk_baslik': 'today_times',
      'widget_vakit_bekleniyor': 'widget_vakit_bekleniyor',
      'widget_ayet_baslik': 'ayah_of_the_day',
      'widget_ayet_acilis': 'widget_ayet_acilis',
      'widget_hadis_baslik': 'hadith_of_the_day',
      'widget_hadis_acilis': 'widget_hadis_acilis',
      'widget_ayet_bulunamadi': 'widget_ayet_bulunamadi',
      'widget_hadis_bulunamadi': 'widget_hadis_bulunamadi',
      'widget_vakit_acilis': 'widget_vakit_acilis',
    };

    // 3 harfli uygulama kodu -> Android values-<xx> kodu.
    const kodEsleme = <String, String>{
      'tur': 'tr', 'eng': 'en', 'deu': 'de', 'fra': 'fr', 'spa': 'es',
      'ita': 'it', 'por': 'pt', 'pol': 'pl', 'ron': 'ro', 'ind': 'id',
      'tuk': 'tk', 'vie': 'vi', 'rus': 'ru', 'ukr': 'uk', 'ara': 'ar',
      'fas': 'fa', 'zho': 'zh', 'jpn': 'ja', 'kor': 'ko', 'tha': 'th',
      'ben': 'bn', 'tam': 'ta', 'nep': 'ne', 'mya': 'my', 'amh': 'am',
    };

    String kacir(String metin) => metin
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll("\\'", "'")
        .trim();

    final Map<String, List<String>> sorunlar = <String, List<String>>{};
    for (final dil in tumDiller()) {
      final xx = kodEsleme[dil];
      if (xx == null) {
        sorunlar[dil] = <String>['Android values kodu tanimsiz'];
        continue;
      }
      final yol = dil == 'tur'
          ? 'android/app/src/main/res/values/strings.xml'
          : 'android/app/src/main/res/values-$xx/strings.xml';

      final File f = File(yol);
      if (!f.existsSync()) {
        sorunlar[dil] = <String>['dosya yok: $yol'];
        continue;
      }
      final String icerik = f.readAsStringSync(encoding: utf8);
      // Her kaynagi tek tek eslestirmek icin tum eslesmeleri aliyoruz.
      final Map<String, String> androidMetin = <String, String>{};
      for (final sat in icerik.split('\n')) {
        final RegExpMatch? s = RegExp(r'<string name="([^"]+)">(.*)</string>')
            .firstMatch(sat);
        if (s != null) androidMetin[s.group(1)!] = kacir(s.group(2)!);
      }
      if (androidMetin.isEmpty) {
        sorunlar[dil] = <String>['string kaynagi cozulemedi: $yol'];
        continue;
      }

      final Map<String, dynamic> ceviriVerisi = dosyaOku(dil);
      final List<String> farkli = <String>[];
      eslesme.forEach((kaynakAdi, anahtar) {
        final String? android = androidMetin[kaynakAdi];
        if (android == null) {
          farkli.add('$kaynakAdi -> kaynak eksik');
          return;
        }
        // `dosyaOku` Map<String, dynamic> doner; deger String olmalidir.
        if (ceviriVerisi[anahtar] != android) {
          farkli.add('$kaynakAdi != $anahtar');
        }
      });
      if (farkli.isNotEmpty) sorunlar[dil] = farkli;
    }

    expect(sorunlar, isEmpty,
        reason: 'Android widget metinleri ceviri dosyalariyla uyusmuyor. '
            'Widget, uygulama acilmadan once bu kaynaklardan okur:\n'
            '${sorunlar.entries.map((e) => '  ${e.key} -> ${e.value.join(', ')}').join('\n')}');
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
