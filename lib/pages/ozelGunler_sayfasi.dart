// lib/pages/ozelGunler_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// Veri katmanımızdan (Repository) verileri çekmek için
import '../data/ozel_gunler.dart'; 

class OzelGunlerSayfasi extends StatelessWidget {
  const OzelGunlerSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final String aktifDil = context.locale.languageCode;

    // Veri gömülü bir statik map'ten geliyor; ağ isteği ve bekleme yok.
    //
    // ÖNCE: 1 saniyelik sahte bir gecikme ("API hissi") ekleniyordu ve liste
    // `build()` içinde `FutureBuilder(future: _ozelGunleriGetirAPI(...))`
    // ile çiziliyordu. Future her build'de YENİDEN oluşturulduğu için
    // FutureBuilder her yeniden çizimde sıfırlanıyor ve
    // `connectionState` yeniden "waiting"e dönüyordu: tema rengi, karanlık
    // mod veya dil değişiminde liste 1 saniye boyunca yerine çark gösterip
    // kayboluyordu. Ana menü `IndexedStack` kullandığı için bu, kullanıcı
    // başka sekmede olsa bile oluşuyordu.
    //
    // Aşağıdaki üç metin, veride karşılığı eksik alanlar için YEDEK'tir.
    // `ozel_gunler.dart` 25 dilin her biri için 9 kaydı eksiksiz tanımladığı
    // için normalde hiç görünmezler. Yine de çeviri dosyasından geliyorlar:
    // önceden burada Türkçe sabitler yazılıydı ("Bilinmeyen Gün", "Tarih Yok",
    // "Açıklama bulunamadı."), yani bir dil bloğu eksik kaldığında (örn. yeni
    // bir çeviri dosyası eklenip `ozel_gunler.dart`'e karşılığı unutulursa)
    // o dilde Türkçe metin çıkardı.
    //
    // Sıralama önemli: önce yedekler, üstüne gerçek veri yazılıyor. Dart'ta
    // map yayılımında sağdaki kazanır, dolayısıyla `eleman` o anahtarı taşıdığı
    // sürece yedek ezilmez ve `DiniGun.fromJson` imzası değişmeden kalır.
    final Map<String, String> yedekler = <String, String>{
      'isim': 'special_day_unknown'.tr(),
      'tarih': 'special_day_no_date'.tr(),
      'aciklama': 'special_day_no_description'.tr(),
    };

    final List<DiniGun> gunler = OzelGunler.ozelGunleriGetir(aktifDil)
        .map((eleman) => DiniGun.fromJson(<String, String>{...yedekler, ...eleman}))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('special_days'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // YENİ 1: Aydınlık modda ana renk, Karanlık modda mat ve şık bir koyu gri!
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900 
            : Theme.of(context).colorScheme.primary, 
            
        foregroundColor: Colors.white,
        
        // YENİ 2: Karanlık modda barın altındaki gölgeyi sıfırlıyoruz ki arka planla tam birleşsin
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 10,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), 
              // YENİ ALT RENK
              Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white
            ],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: gunler.length,
          itemBuilder: (context, index) {
            final DiniGun oAnkiGun = gunler[index];
            return _gunKarti(context, oAnkiGun.isim, oAnkiGun.tarih, oAnkiGun.hicriTarih, oAnkiGun.ikon, oAnkiGun.aciklama);
          },
        ),
      ),
    );
  }

  Widget _gunKarti(BuildContext context, String isim, String tarih, String hicriTarih, IconData ikon, String aciklama) {
    bool karanlikMi = Theme.of(context).brightness == Brightness.dark;

    return Card(
      // YENİ: Colors.white kodunu sildik, yerine akıllı kart rengini ekledik
      color: Theme.of(context).cardColor, 
      elevation: karanlikMi ? 1 : 4,
      child: ListTile(
        leading: Icon(ikon, color: Theme.of(context).colorScheme.primary, size: 32),
        title: Text(isim, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: karanlikMi ? Colors.white : Colors.black87)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4), 
            Text(tarih, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            Text(hicriTarih, style: TextStyle(fontSize: 14, color: karanlikMi ? Colors.grey.shade400 : Colors.grey.shade600)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: karanlikMi ? Colors.grey.shade500 : Colors.grey),
        onTap: () => _altPanelAc(context, isim, tarih, hicriTarih, aciklama, ikon),
      ),
    );
  }

  void _altPanelAc(BuildContext context, String isim, String tarih, String hicriTarih, String aciklama, IconData ikon) {
    // ÖNCE: `aktifDil == 'en' ? 'Close' : 'Kapat'` — uygulama 25 dilde çalışmasına
    // rağmen bu düğme yalnızca İngilizce/Türkçe ayrımı yapıyordu, yani diğer
    // 23 dilde Türkçe "Kapat" görünüyordu. Artık çeviri dosyasından geliyor.
    String kapatYazisi = 'close'.tr();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Icon(ikon, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(isim, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(tarih, style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(hicriTarih, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const Divider(height: 32, thickness: 1),
              Text(aciklama, style: const TextStyle(fontSize: 16, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(kapatYazisi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }
    );
  }
}

// --- VERİ MODELİ (DTO) ---
class DiniGun {
  final String isim;
  final String tarih;
  final String hicriTarih;
  final String aciklama;
  final IconData ikon;

  DiniGun({
    required this.isim,
    required this.tarih,
    required this.hicriTarih,
    required this.aciklama,
    required this.ikon,
  });

  factory DiniGun.fromJson(Map<String, dynamic> json) {
    return DiniGun(
      isim: json['isim'] ?? 'special_day_unknown'.tr(),
      tarih: json['tarih'] ?? 'special_day_no_date'.tr(),
      hicriTarih: json['hicriTarih'] ?? '',
      aciklama: json['aciklama'] ?? 'special_day_no_description'.tr(),
      ikon: _ikonBelirle(json['ikon']), 
    );
  }

  static IconData _ikonBelirle(String? ikonAdi) {
    switch (ikonAdi) {
      case 'auto_awesome': return Icons.auto_awesome;
      case 'nightlight_round': return Icons.nightlight_round;
      case 'brightness_3': return Icons.brightness_3;
      case 'star': return Icons.star;
      case 'celebration': return Icons.celebration;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'event': return Icons.event;
      case 'local_dining': return Icons.local_dining;
      case 'menu_book': return Icons.menu_book;
      default: return Icons.calendar_today; 
    }
  }
}