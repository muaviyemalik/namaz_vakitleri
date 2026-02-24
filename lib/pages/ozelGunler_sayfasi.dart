// lib/pages/ozelGunler_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// Veri katmanımızdan (Repository) verileri çekmek için
import '../data/ozel_gunler.dart'; 

class OzelGunlerSayfasi extends StatelessWidget {
  const OzelGunlerSayfasi({super.key});

  Future<List<DiniGun>> _ozelGunleriGetirAPI(String aktifDil) async {
    // API hissi vermek için 1 saniye bekletiyoruz
    await Future.delayed(const Duration(seconds: 1));

    // Veri havuzundan o anki dile uygun veriyi çekiyoruz
    final List<Map<String, dynamic>> hamVeriler = OzelGunler.ozelGunleriGetir(aktifDil);
    
    return hamVeriler.map((eleman) => DiniGun.fromJson(eleman)).toList();
  }

  @override
  Widget build(BuildContext context) {
    String aktifDil = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('special_days'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
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
        child: FutureBuilder<List<DiniGun>>(
          future: _ozelGunleriGetirAPI(aktifDil), 
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('loading'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              );
            }
            
            if (snapshot.hasError) {
              return Center(child: Text('Hata / Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }
            
            if (snapshot.hasData) {
              List<DiniGun> gelenListe = snapshot.data!; 
              
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: gelenListe.length, 
                itemBuilder: (context, index) {
                  DiniGun oAnkiGun = gelenListe[index]; 
                  return _gunKarti(context, oAnkiGun.isim, oAnkiGun.tarih, oAnkiGun.hicriTarih, oAnkiGun.ikon, oAnkiGun.aciklama, aktifDil);
                },
              );
            }
            
            return const Center(child: Text('No data found.'));
          },
        ),
      ),
    );
  }

  Widget _gunKarti(BuildContext context, String isim, String tarih, String hicriTarih, IconData ikon, String aciklama, String aktifDil) {
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
        onTap: () => _altPanelAc(context, isim, tarih, hicriTarih, aciklama, ikon, aktifDil),
      ),
    );
  }

  void _altPanelAc(BuildContext context, String isim, String tarih, String hicriTarih, String aciklama, IconData ikon, String aktifDil) {
    String kapatYazisi = (aktifDil == 'en') ? 'Close' : 'Kapat';

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
      isim: json['isim'] ?? "Bilinmeyen Gün",
      tarih: json['tarih'] ?? "Tarih Yok",
      hicriTarih: json['hicriTarih'] ?? "",
      aciklama: json['aciklama'] ?? "Açıklama bulunamadı.",
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