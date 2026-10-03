// tool/yeni_anahtarlari_ekle.dart
//
// Yeni çeviri anahtarlarını 25 dile ekler.
//
// NEDEN BU DOSYA VAR?
//
// Yeni özellikler (veri kaynağı göstergesi, hesaplama yöntemi şeridi,
// reddedilen cevap gerekçeleri, güneş doğuşu bildirimi) arayüzde yeni
// çeviri anahtarları gerektiriyor. `test/ceviriler_test.dart` her dosyanın
// anahtar kümesinin `tur.json` ile BİREBİR aynı olmasını zorunlu kılıyor.
// Bu dosya o eşliği korur: önce `tur.json`'a ekler, sonra 24 dile aynı
// anahtarları yazar.
//
// ÇALIŞTIRMA:
//     dart run tool/yeni_anahtarlari_ekle.dart
//
// UYARI: AI tarafından üretilen çeviriler İNSAN GÖZÜYLE denetlenmelidir.
// Özellikle dini/terimsel içerik (ör. "kıble", "vakit") ve RTL diller
// (Arapça, Farsça) için bu denetim yapılmadan yayına gidilmemelidir.
import 'dart:convert';
import 'dart:io';

import 'yeni_anahtar_cevirileri.dart';

/// Yeni anahtarlar ve TÜRKÇE karşılıkları.
const Map<String, String> yeniAnahtarlar = <String, String>{
  // --- Yeni hesaplama ayarları (Aşama 2/4) ---
  'asr_method': 'Asr hesaplama yöntemi',
  'high_latency': 'Yüksek enlem ayarı',
  'sunrise_notification': 'Güneş doğuşu bildirimi',
  'sunrise_notification_desc':
      'Güneş doğuşu bilgi bildirimi (namaz vakti değildir)',

  // --- Veri kaynağı şeridi (Aşama 3) ---
  'data_source_live': 'Canlı veri',
  'data_source_cache': 'Önbellekten',
  'data_source_unknown': 'Güncelleme bilgisi yok',
  'data_updated_now': 'az önce güncellendi',
  'data_updated_minutes': '{} dakika önce güncellendi',
  'data_updated_hours': '{} saat önce güncellendi',
  'data_updated_days': '{} gün önce güncellendi',

  // --- Hesaplama yöntemi şeridi (Aşama 2) ---
  'method_auto_with_result': 'Aladhan otomatik yöntemi: {}',
  'high_latency_setting': 'Yüksek enlem ayarı: {}',

  // --- Tam zamanlı alarm (Aşama 4) ---
  'exact_alarm_yok':
      'Tam zamanlı alarm izni yok — bildirimler yaklaşık zamanlı gelir',

  // --- Güneş doğuşu bilgi bildirimi (Aşama 4) ---
  'notif_sunrise_title': 'Güneş doğuşu',
  'notif_sunrise_body': 'Güneş doğuşu (namaz vakti değildir)',
  'notif_channel_sunrise_name': 'Güneş doğuşu bilgisi',

  // --- Şehir verisi olmayan ülke (Aşama 5) ---
  'no_city_data_action':
      '{} için şehir listesi boş. Konumunuzu GPS ile bulun veya bir şehir '
      'seçin.',

  // --- Reddedilen cevap gerekçeleri (Aşama 1) ---
  'reject_http': 'Sunucu hatası (ağ veya API sorunu)',
  'reject_logic': 'Sunucu geçersiz bir cevap döndü',
  'reject_empty': 'Sunucudan veri gelmedi',
  'reject_date_broken': 'Cevaptaki tarih geçersiz',
  'reject_month_mismatch': 'Cevap istenen aya ait değil',
  'reject_coords_mismatch': 'Cevap farklı bir konuma ait',
  'reject_tz_missing': 'Cevapta saat dilimi yok',
  'reject_tz_unknown': 'Cevaptaki saat dilimi tanınmıyor',
  'reject_method_mismatch': 'Cevap seçilen hesaplama yöntemiyle uyuşmuyor',
  'reject_field_missing': 'Cevapta bazı vakitler eksik',
  'reject_time_format': 'Cevaptaki saat biçimi geçersiz',
  'reject_time_range': 'Cevaptaki saat geçersiz değer içeriyor',
  'reject_zero_time': 'Cevap gece yarısı (00:00) içeriyor',
  'reject_day_missing': 'İstenen gün cevapta bulunamadı',
};

/// İngilizce karşılıklar.
const Map<String, String> enAnahtarlar = <String, String>{
  'asr_method': 'Asr calculation method',
  'high_latency': 'High-latitude setting',
  'sunrise_notification': 'Sunrise notification',
  'sunrise_notification_desc': 'Sunrise info notification (not a prayer time)',

  'data_source_live': 'Live data',
  'data_source_cache': 'From cache',
  'data_source_unknown': 'No update info',
  'data_updated_now': 'updated just now',
  'data_updated_minutes': 'updated {} min ago',
  'data_updated_hours': 'updated {} h ago',
  'data_updated_days': 'updated {} days ago',

  'method_auto_with_result': "Aladhan's automatic method: {}",
  'high_latency_setting': 'High-latitude setting: {}',

  'exact_alarm_yok':
      'No exact alarm permission — notifications arrive approximately',

  'notif_sunrise_title': 'Sunrise',
  'notif_sunrise_body': 'Sunrise (not a prayer time)',
  'notif_channel_sunrise_name': 'Sunrise info',

  'no_city_data_action':
      'No city list for {}. Find your location via GPS or pick a city.',

  'reject_http': 'Server error (network or API problem)',
  'reject_logic': 'Server returned an invalid response',
  'reject_empty': 'No data from server',
  'reject_date_broken': 'Response date is invalid',
  'reject_month_mismatch': 'Response is not for the requested month',
  'reject_coords_mismatch': 'Response belongs to a different location',
  'reject_tz_missing': 'Response has no time zone',
  'reject_tz_unknown': 'Response time zone is not recognised',
  'reject_method_mismatch':
      'Response method does not match the selected method',
  'reject_field_missing': 'Response is missing some prayer times',
  'reject_time_format': 'Response time format is invalid',
  'reject_time_range': 'Response contains an invalid time value',
  'reject_zero_time': 'Response contains midnight (00:00)',
  'reject_day_missing': 'Requested day not found in response',
};

void main() {
  final dizin = Directory('assets/i18n/ceviri');
  if (!dizin.existsSync()) {
    stderr.writeln('HATA: ${dizin.path} bulunamadi. Proje kokunden calistirin.');
    exitCode = 1;
    return;
  }

  final dosyalar = dizin
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // ignore: avoid_print
  print('Islenecek ceviri dosyasi: ${dosyalar.length}');

  for (final f in dosyalar) {
    final kod = f.uri.pathSegments.last.replaceAll('.json', '');
    final metin = f.readAsStringSync();
    final Map<String, dynamic> harita;

    try {
      harita = json.decode(metin) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('HATA: ${f.path} okunamadi: $e');
      exitCode = 1;
      continue;
    }

    var eklendi = 0;
    for (final anahtar in yeniAnahtarlar.keys) {
      if (harita.containsKey(anahtar)) continue; // Var: dokunma.
      final deger = kod == 'eng'
          ? enAnahtarlar[anahtar]
          : (kod == 'tur' ? yeniAnahtarlar[anahtar] : _dilVarsayilani(kod, anahtar));
      if (deger == null) {
        stderr.writeln('UYARI: $kod icin "$anahtar" cevirisi yok, anahtar eklendi.');
        harita[anahtar] = anahtar;
      } else {
        harita[anahtar] = deger;
      }
      eklendi++;
    }

    // Anahtarlari alfabetik sirala: dosyalar arasinda tutarlilik ve
    // karsilastirilabilirlik icin.
    final sirali = Map<String, dynamic>.fromEntries(
      harita.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

    f.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(sirali) + '\n',
      flush: true,
    );
    // ignore: avoid_print
    print('$kod: +$eklendi anahtar (toplam ${sirali.length})');
  }

  // ignore: avoid_print
  print('Tamamlandi. AI cevirilerini insan gozuyle denetlemeyi unutma.');
}

/// Henuz çevrilmemiş anahtar için dilin kendi dilinde geçici karşılık.
///
/// Dürüstlük notu: Bu değerler İNSAN DEĞİLDİR. `test/ceviriler_test.dart`
/// anahtar varlığını doğrular ama doğru çeviriyi doğrulayamaz. Arapça,
/// Farsça, Almanca ve Endonezce dâhil 25 dilin tamamı yerel dil gözüyle
/// kontrol edilmelidir.
String? _dilVarsayilani(String kod, String anahtar) =>
    dilCevirileri[kod]?[anahtar];
