// lib/pages/kible_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Titreşim için
import 'package:flutter_compass/flutter_compass.dart'; // Pusula sensörü için
import 'package:geolocator/geolocator.dart'; // Konum için
import 'package:easy_localization/easy_localization.dart'; // Çeviri motoru için
import 'dart:math' as math; // Trigonometri için

// Kendi yazdığımız hesaplayıcıyı da import ediyoruz (Yoluna dikkat et: bir üst klasöre çıkıp utils'e girer '..')
import '../utils/kible_hesapla.dart';

class KibleSayfasi extends StatefulWidget {
  const KibleSayfasi({super.key});

  @override
  State<KibleSayfasi> createState() => _KibleSayfasiState();
}

class _KibleSayfasiState extends State<KibleSayfasi> {
  double? _kibleAcisi;
  bool _konumAraniyor = true;
  bool _titrediMi = false;

  @override
  void initState() {
    super.initState();
    _kibleIcinKonumBul();
  }

  Future<void> _kibleIcinKonumBul() async {
    try {
      Position pozisyon = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        // Utils klasöründeki matematik sınıfımızı çağırdık
        _kibleAcisi = KibleHesaplayici.hesapla(pozisyon.latitude, pozisyon.longitude);
        _konumAraniyor = false;
      });
    } catch (e) {
      setState(() {
        _konumAraniyor = false;
      });
    }
  }

  Widget _kabeSimgesi() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black, 
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(height: 4, color: Colors.amber), 
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('qibla'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity, // Bu sayfada genişlik ayarı vardı, onu koruyoruz
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
        child: _konumAraniyor
            ? const Center(child: CircularProgressIndicator())
            : _kibleAcisi == null
                ? Center(child: Text('qibla_not_found'.tr()),)
                : StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Sensör hatası.'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      double? cihazAcisi = snapshot.data?.heading;
                      if (cihazAcisi == null) return const Center(child: Text("Cihazınızda pusula sensörü bulunamadı."));

                      double fark = (_kibleAcisi! - cihazAcisi + 360) % 360;
                      bool kibleyiBulduMu = (fark < 3 || fark > 357);

                      if (kibleyiBulduMu && !_titrediMi) {
                        HapticFeedback.vibrate(); 
                        _titrediMi = true;
                      } else if (!kibleyiBulduMu && _titrediMi) {
                        _titrediMi = false;
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            kibleyiBulduMu ? 'found_qible'.tr() : 'turn_qible'.tr(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kibleyiBulduMu ? Colors.green.shade600 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: kibleyiBulduMu 
                                  ? [const BoxShadow(color: Colors.green, blurRadius: 20, spreadRadius: 5)] 
                                  : [],
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 60,
                              color: kibleyiBulduMu ? Colors.green : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          
                          const SizedBox(height: 10),

                          Transform.rotate(
                            angle: -cihazAcisi * (math.pi / 180),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.grey.shade300, width: 3),
                                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
                                  ),
                                ),
                                
                                Container(width: 1, height: 260, color: Colors.grey.shade300),
                                Container(width: 260, height: 1, color: Colors.grey.shade300),

                                Positioned(top: 10, child: Text("K", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red.shade700))),
                                Positioned(bottom: 10, child: Text("G", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700))),
                                Positioned(right: 15, child: Text("D", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700))),
                                Positioned(left: 15, child: Text("B", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700))),

                                Transform.rotate(
                                  angle: _kibleAcisi! * (math.pi / 180),
                                  child: Container(
                                    width: 280,
                                    height: 280,
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 25), 
                                      child: _kabeSimgesi(), 
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}