// lib/pages/kible_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Titreşim için
import 'package:flutter_compass/flutter_compass.dart'; // Pusula sensörü için
import 'package:geolocator/geolocator.dart'; // Konum için
import 'package:easy_localization/easy_localization.dart'; // Çeviri motoru için
import 'dart:math' as math; // Trigonometri için

// Kendi yazdığımız hesaplayıcıyı da import ediyoruz (Yoluna dikkat et: bir üst klasöre çıkıp utils'e girer '..')
import '../utils/kible_hesapla.dart';
import '../main.dart';

class KibleSayfasi extends StatefulWidget {
  const KibleSayfasi({super.key});

  @override
  State<KibleSayfasi> createState() => _KibleSayfasiState();
}

class _KibleSayfasiState extends State<KibleSayfasi> {
  double? _kibleAcisi;

  /// Konum hâlâ aranıyor mu?
  bool _konumAraniyor = true;

  /// Hata durumunda gösterilecek çeviri anahtarı (null ise hata yok).
  ///
  /// ÖNCE: konum alınamadığında tek bir mesaj (`qibla_not_found`) gösteriliyordu.
  /// Oysa çoğu zaman sorun kıble değil, konum izni ya da kapalı konum servisiydi;
  /// kullanıcı "Kıble bulunamadı" görüp ne yapacağını bilemiyordu.
  String? _hataAnahtari;

  /// Kıble bulunduğunda bir kez titreşildi mi? (Her karede değil.)
  bool _titrediMi = false;

  @override
  void initState() {
    super.initState();
    // Sayfa yalnızca kullanıcı sekmeye dokunduğunda kurulur (bkz.
    // AnaMenu'daki `_acilanSekmeler`). Yani buradaki konum isteği bilinçli bir
    // kullanıcı eyleminin sonucudur; uygulama açılışında otomatik çalışmaz.
    _konumBul();
  }

  /// Konumu (ve dolayısıyla kıble açısını) bulur.
  ///
  /// İzinler önceden kontrol edilir. Önceden doğrudan `getCurrentPosition`
  /// çağrılıyordu; izin verilmemişse bu çağrı hata fırlatıyor ve sayfa
  /// yanlış mesajla "Kıble bulunamadı" diyordu.
  Future<void> _konumBul() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _hataVer('loc_service_off');
        return;
      }

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.deniedForever) {
        _hataVer('loc_perm_forever');
        return;
      }
      if (izin == LocationPermission.denied) {
        _hataVer('loc_perm_denied');
        return;
      }

      // Bu işlem 3-5 saniye sürebilir
      final Position pozisyon = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;

      setState(() {
        // Utils klasöründeki matematik sınıfımızı çağırdık
        _kibleAcisi =
            KibleHesaplayici.hesapla(pozisyon.latitude, pozisyon.longitude);
        _konumAraniyor = false;
        _hataAnahtari = null;
      });
    } catch (e) {
      debugPrint('Kible konumu alinamadi: $e');
      _hataVer('loc_error');
    }
  }

  void _hataVer(String ceviriAnahtari) {
    if (!mounted) return;
    setState(() {
      _konumAraniyor = false;
      _hataAnahtari = ceviriAnahtari;
    });
  }

  /// Konumu yeniden ister (AppBar düğmesi ve hata ekranından çağrılır).
  Future<void> _konumYenile() async {
    setState(() {
      _konumAraniyor = true;
      _hataAnahtari = null;
      // Kıble açısı sıfırlanmıyor: eski açıyla ekranı göstermeye devam eder,
      // ama üstteki çark "yeniden aranıyor" durumunu belirtir.
    });
    await _konumBul();
  }

  /// Kıble bulunduğunda/anlaşıldığında bir kez titreşim üretir.
  ///
  /// ÖNCE: bu mantık `build` içindeydi, yani her karede çalışıyordu. Titreşim
  /// bir çizim yan etkisidir; build sırasında doğrudan çağrılmamalıdır. Artık
  /// kare bittikten sonra (`addPostFrameCallback`) çalışıyor.
  void _titresimiGuncelle(bool kibleyiBulduMu) {
    if (kibleyiBulduMu == _titrediMi) return;
    _titrediMi = kibleyiBulduMu;
    if (!kibleyiBulduMu) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HapticFeedback.vibrate();
    });
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
    // "KONUMU YENİDEN ARA" düğmesi her zaman AppBar'da durur: kullanıcı
    // kıbleyi bulduğunda konum hâlâ hatalıysa (ör. yeni şehre taşındıysa)
    // sayfayı yeniden kurmadan yeniden deneyebilir.
    return Scaffold(
      appBar: AppBar(
        title: Text('qibla'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // YENİ 1: Aydınlık modda ana renk, Karanlık modda mat ve şık bir koyu gri!
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900 
            : Theme.of(context).colorScheme.primary, 
            
        foregroundColor: Colors.white,
        
        // YENİ 2: Karanlık modda barın altındaki gölgeyi sıfırlıyoruz ki arka planla tam birleşsin
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 10,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'retry'.tr(),
            onPressed: _konumYenile,
          ),
        ],
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
        child: _govde(),
      ),
    );
  }

  Widget _govde() {
    if (_konumAraniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    final String? hata = _hataAnahtari;
    if (hata != null) return _hataEkrani(hata);

    if (_kibleAcisi == null) {
      return Center(child: Text('qibla_not_found'.tr()));
    }

    // Pusula sensörü YALNIZCA sekme görünürken açıktır.
    //
    // Sayfa `IndexedStack` içinde bir kez kurulduktan sonra yaşamaya devam
    // eder. Bu yüzden başka bir sekmede bulunurken `FlutterCompass.events`
    // aboneliğini kapatıyoruz: aksi hâlde kullanıcı kıbleye bakmıyorken bile
    // sensör sürekli ölçüm yapıyor, yani pil boşuna harcanıyordu. Sekmeden
    // çıkılınca `StreamBuilder` ağaçtan kaldırıldığı için abonelik de iptal
    // olur; geri gelindiğinde yeniden abone olur (pusula anlıktır, beklemez).
    return ValueListenableBuilder<int>(
      valueListenable: aktifSekmeIndeksi,
      builder: (BuildContext context, int sekme, Widget? child) {
        if (sekme != kibleSekmeIndeksi) return const SizedBox.shrink();
        return _pusula();
      },
    );
  }

  Widget _hataEkrani(String ceviriAnahtari) {
    final bool karanlikMi = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_disabled,
            size: 64,
            color: karanlikMi ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 20),
          Text(
            ceviriAnahtari.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: karanlikMi ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 28),
          // İzin ayarlarından sonra tekrar denemek için.
          FilledButton.icon(
            onPressed: _konumYenile,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _pusula() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (BuildContext context, AsyncSnapshot<CompassEvent> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('compass_error'.tr()));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final double? cihazAcisi = snapshot.data?.heading;
        if (cihazAcisi == null) {
          return Center(child: Text('no_compass'.tr()));
        }

        final double fark = (_kibleAcisi! - cihazAcisi + 360) % 360;
        final bool kibleyiBulduMu = (fark < 3 || fark > 357);

        // Titreşim build'in yan etkisi olarak değil, kare bittikten sonra.
        _titresimiGuncelle(kibleyiBulduMu);

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
    );
  }
}
