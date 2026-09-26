// Yeni ulke/sehir secim anahtarlarini tr/en/zh ceviri dosyalarina ekler.
// Idempotenttir: anahtar zaten varsa gunceller, yoksa ekler.
import 'dart:convert';
import 'dart:io';

const yeniAnahtarlar = <String, Map<String, String>>{
  'tr': {
    'country': 'Ülke',
    'select_country': 'Ülke Seç',
    'search_country': 'Ülke ara (örn. Almanya, Egypt)...',
    'search_city': 'Şehir ara (örn. İstanbul, Sivas)...',
    'city': 'şehir',
    'city_count': 'şehir',
    'cities_found': 'Bulunan',
    'country_changed': 'Ülke değiştirildi',
    'no_results': 'Sonuç bulunamadı',
    'no_city_data': 'Bu ülke için şehir verisi bulunmuyor.',
    'data_load_error': 'Veri yüklenemedi',
    'calculation_method': 'Hesaplama Yöntemi',
    'method_auto': 'Otomatik (ülkeye göre önerilen)',
    'method_auto_desc': 'Ülkenize uygun resmi yöntem otomatik seçilir.',
    'method_help':
        'Hesaplama yöntemi vakitleri değiştirir. Emin değilseniz takip ettiğiniz '
        'caminin yöntemini seçin ya da otomatik bırakın.',
  },
  'en': {
    'country': 'Country',
    'select_country': 'Select Country',
    'search_country': 'Search country (e.g. Germany, Egypt)...',
    'search_city': 'Search city (e.g. Istanbul, Sivas)...',
    'city': 'cities',
    'city_count': 'cities',
    'cities_found': 'Found',
    'country_changed': 'Country changed',
    'no_results': 'No results found',
    'no_city_data': 'No city data available for this country.',
    'data_load_error': 'Could not load data',
    'calculation_method': 'Calculation Method',
    'method_auto': 'Automatic (recommended for your country)',
    'method_auto_desc': 'The official method for your country is selected automatically.',
    'method_help':
        'The calculation method changes the times. If unsure, pick the method used '
        'by the mosque you attend, or leave it automatic.',
  },
  'zh': {
    'country': '国家/地区',
    'select_country': '选择国家',
    'search_country': '搜索国家（例如 德国、埃及）...',
    'search_city': '搜索城市（例如 开罗、喀什）...',
    'city': '城市',
    'city_count': '城市',
    'cities_found': '找到',
    'country_changed': '国家已更改',
    'no_results': '未找到结果',
    'no_city_data': '该国家没有城市数据。',
    'data_load_error': '无法加载数据',
    'calculation_method': '计算方法',
    'method_auto': '自动（推荐适合您所在国家的方法）',
    'method_auto_desc': '已自动选择适合您所在国家的官方方法。',
    'method_help': '计算方法会改变礼拜时间。若不确定，请选择您常去清真寺使用的方法，或保持自动。',
  },
};

void main() {
  for (final dil in yeniAnahtarlar.keys) {
    final yol = 'assets/translations/$dil.json';
    final mevcut = json.decode(File(yol).readAsStringSync(encoding: utf8))
        as Map<String, dynamic>;

    var eklendi = 0;
    for (final giris in yeniAnahtarlar[dil]!.entries) {
      if (!mevcut.containsKey(giris.key)) eklendi++;
      mevcut[giris.key] = giris.value;
    }

    // alfabetik sirala (okunabilirlik icin)
    final sirali = Map<String, dynamic>.fromEntries(
      mevcut.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    File(yol).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(sirali)}\n',
      encoding: utf8,
    );
    print('$dil.json : $eklendi yeni anahtar eklendi, toplam ${sirali.length}');
  }
}
