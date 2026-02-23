// 1. KÜTÜPHANELER
import 'package:flutter/material.dart'; // Flutter'ın görsel materyalleri (Widget'lar, temalar)
import 'package:http/http.dart' as http; // İnternet (GET/POST) istekleri için. İsim çakışması olmasın diye 'as http' diyoruz.
import 'dart:convert'; // Gelen String veriyi (JSON) Dart'ın anlayacağı Map (sözlük) yapısına çevirmek için.
import 'dart:async'; // Timer (Zamanlayıcı) kullanmak için.
import 'package:geolocator/geolocator.dart'; // Konum koordinatlarını almak için
import 'package:geocoding/geocoding.dart'; // Koordinatı şehir ismine çevirmek için
import 'dart:io'; //Uygulamanın çalıştığı işletim sistemini bulmak için
// --- TEMA YÖNETİMİ ---
// ValueNotifier: İçindeki değer (renk) değiştiğinde, onu dinleyen widget'lara 
// "Güncellen!" mesajı gönderen özel bir yapıdır.
final ValueNotifier<Color> seciliTemaRengi = ValueNotifier<Color>(Colors.teal);

// 2. BAŞLANGIÇ NOKTASI (Entry Point)
// C#'taki static void Main() metodunun karşılığıdır.
void main() {
  // runApp(): Flutter'a ekrana çizmeye başlayacağı ilk sınıfı söyler.
  // const: Bellekte sadece bir kez oluşturulmasını sağlar, performansı artırır.
  runApp(const NamazVakitleriApp());
}

// 3. UYGULAMANIN KÖK DİZİNİ (Root Widget)
// StatelessWidget: İçindeki veriler sonradan değişmeyecekse kullanılır. Sadece temel ayarları tutar.
class NamazVakitleriApp extends StatelessWidget {
  const NamazVakitleriApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder: Belirttiğimiz 'seciliTemaRengi'ni dinler.
    // Kullanıcı paletten yeni renk seçtiğinde sadece bu bloğu (tüm uygulamayı) yeniden çizer.
    return ValueListenableBuilder<Color>(
      valueListenable: seciliTemaRengi,
      builder: (context, aktifRenk, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Namaz Vakitleri',
          theme: ThemeData(
            // seedColor kısmına artık sabit 'Colors.teal' yerine 'aktifRenk' veriyoruz.
            colorScheme: ColorScheme.fromSeed(seedColor: aktifRenk, brightness: Brightness.light),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 4, 
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          home: const AnaMenu(), // Artık ilk olarak alt menüyü çizen sınıfımız açılacak
        );
      },
    );
  }
}

// --- YENİ EKLENEN: ALT MENÜ YÖNETİCİSİ ---
class AnaMenu extends StatefulWidget {
  const AnaMenu({super.key});

  @override
  State<AnaMenu> createState() => _AnaMenuState();
}

class _AnaMenuState extends State<AnaMenu> {
  int _seciliSayfaIndeksi = 0; // Başlangıçta 0. sekme (Vakitler) açık olsun

  // Alt menüde gösterilecek sayfaların listesi
  final List<Widget> _sayfalar = [
    const AnaSayfa(), // Zaten var olan namaz vakitleri sayfamız
    const OzelGunlerSayfasi(), // Birazdan en alta ekleyeceğimiz yeni sayfa
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: Sayfalar arası geçişte sayacın sıfırlanmasını ve 
      // GPS/API'nin tekrar tekrar çağrılmasını engeller. Sayfayı hafızada tutar.
      body: IndexedStack(
        index: _seciliSayfaIndeksi,
        children: _sayfalar,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSayfaIndeksi,
        onTap: (index) {
          setState(() {
            _seciliSayfaIndeksi = index; // Tıklanan sekmeye geç
          });
        },
        // Temanın dinamik rengini alt menüye de yansıtıyoruz
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Vakitler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Özel Günler',
          ),
        ],
      ),
    );
  }
}



// 4. DURUMU DEĞİŞEBİLEN EKRAN (StatefulWidget)
// API'den veri gelince ve sayaç her saniye aktığında ekranın güncellenmesi gerektiği için bunu kullanıyoruz.
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  // --- DEĞİŞKENLER (STATE) ---
  Map<String, dynamic>? vakitler; // JSON'dan gelecek vakitleri tutacak. Başlangıçta null.
  bool yukleniyor = true; // Ekranda yüklenme çarkını gösterme kontrolü.
  String hataMesaji = ''; // İnternet/API hatalarını tutacak metin.
  
  Timer? _zamanlayici; // Her saniye çalışacak motor.
  String siradakiVakitIsmi = ''; // Ekrana basılacak sıradaki vaktin adı.
  String kalanSureMetni = ''; // Ekrana basılacak 00:00:00 formatındaki süre.
  String aktifSehir = 'Ankara'; // Varsayılan şehir. GPS bulana kadar bu görünecek.

  // initState(): Ekran oluşturulmadan hemen ÖNCE BİR KERE çalışır (C# Constructor / Form_Load gibi).
  @override
  void initState() {
    super.initState();
    // --- YENİ EKLENEN: KONUM BULMA FONKSİYONU ---
  Future<void> konumBul() async {

    if (Platform.isLinux || Platform.isWindows) {
      setState(() { 
        aktifSehir = 'Ankara'; // Geliştirme ortamı için sahte konum
        yukleniyor = false;
      });
      await vakitleriGetir();
      return; // Alt satırlara inme, fonksiyonu burada bitir.
    }
    bool servisAcikMi;
    LocationPermission izin;
    
    // İhtimal 1: Cihazın GPS servisi (Konum) tamamen kapalı mı?
    servisAcikMi = await Geolocator.isLocationServiceEnabled();
    if (!servisAcikMi) {
      setState(() { hataMesaji = 'Lütfen cihazın konum (GPS) servisini açın.'; yukleniyor = false; });
      return; // İşlemi burada kes, aşağıya geçme.
    }

    // İhtimal 2: Uygulamamıza konum izni verilmiş mi?
    izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission(); // Kullanıcıdan ekranda izin iste
      if (izin == LocationPermission.denied) {
        setState(() { hataMesaji = 'Konum izni reddedildi. Sadece Ankara gösteriliyor.'; yukleniyor = false; });
        await vakitleriGetir(); // İzin verilmediyse bile varsayılan şehirle vakitleri getir.
        return;
      }
    }
    
    // İhtimal 3: Kullanıcı ayarlardan izni kalıcı olarak kapatmış.
    if (izin == LocationPermission.deniedForever) {
      setState(() { hataMesaji = 'Konum izni kalıcı olarak reddedildi.'; yukleniyor = false; });
      return;
    }

    // Her şey yolundaysa ve izin varsa konumu al (Enlem ve Boylam)
    try {
      // desiredAccuracy: Cihazın pilini sömürmemek için hassasiyeti 'low' (düşük) tutuyoruz. Bize sadece şehir lazım, sokak değil.
      Position pozisyon = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      
      // Koordinatları şehir ismine çevir (Reverse Geocoding)
      List<Placemark> yerler = await placemarkFromCoordinates(pozisyon.latitude, pozisyon.longitude);
      if (yerler.isNotEmpty) {
        // administrativeArea genelde İl ismini tutar (Örn: "Istanbul")
        String bulunanSehir = yerler.first.administrativeArea ?? 'Ankara';
        
        setState(() { aktifSehir = bulunanSehir; });
        
        // Şehri bulduk, şimdi bu yeni şehre göre API'ye istek at!
        await vakitleriGetir(); 
      }
    } catch (e) {
      setState(() { hataMesaji = 'Konum alınırken bir hata oluştu: $e'; yukleniyor = false; });
    }
  }
    konumBul(); // Ekran açılır açılmaz API'ye istek at.
  }

  // 5. BELLEK YÖNETİMİ (Kritik Edge Case)
  // dispose(): Ekran veya uygulama kapatıldığında çalışır.
  // İhtimal: Eğer Timer'ı burada iptal etmezsek (cancel), arka planda sonsuza kadar çalışıp RAM'i doldurur (Memory Leak).
  @override
  void dispose() {
    _zamanlayici?.cancel(); 
    super.dispose();
  }

  // 6. API'DEN VERİ ÇEKME (Asenkron - Future)
  // async/await: İnternetten cevap gelene kadar uygulamanın arayüzünü kilitlememek (donmamasını sağlamak) için.
  Future<void> vakitleriGetir() async {
    try {
      final url = Uri.parse('http://api.aladhan.com/v1/timingsByCity?city=$aktifSehir&country=Turkey&method=13');
      final cevap = await http.get(url); // await: Cevap gelene kadar burada bekle.

      // İhtimal 1: Sunucu 200 (OK) döndürdü, veri başarıyla geldi.
      if (cevap.statusCode == 200) {
        final jsonVeri = json.decode(cevap.body); // Metni JSON sözlüğüne çevir.
        
        // setState(): Değişkenleri günceller ve arayüze "Kendini yeni verilerle tekrar çiz" der.
        setState(() {
          vakitler = jsonVeri['data']['timings'];
          yukleniyor = false; // Yükleme bitti, çarkı gizle.
        });
        
        sayaciBaslat(); // Veriler elimizde olduğuna göre sayacı tetikleyebiliriz.
      } 
      // İhtimal 2: Sunucu hata döndürdü (404, 500 vb.)
      else {
        setState(() { hataMesaji = 'Veri alınamadı: ${cevap.statusCode}'; yukleniyor = false; });
      }
    } 
    // İhtimal 3: İnternet yok veya API sunucusu kapalı.
    catch (e) {
      setState(() { hataMesaji = 'Bağlantı hatası: $e'; yukleniyor = false; });
    }
  }

  // 7. SAYAÇ MANTIĞI
  void sayaciBaslat() {
    // Timer.periodic: İçindeki kodu 1 saniyede bir sonsuza kadar tekrar eder.
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (timer) {
      kalanSureyiHesapla();
    });
    kalanSureyiHesapla(); // İlk saniyeyi beklemeden hemen ilk hesaplamayı yap.
  }

  // 8. ZAMAN HESAPLAMASI (İşin Beyni)
  void kalanSureyiHesapla() {
    if (vakitler == null) return; // Veri yoksa boşa hesaplama yapma.

    final suAn = DateTime.now();
    
    // API'den gelen "05:30" gibi String saatleri DateTime ile kıyaslamak için bir sözlük oluşturduk.
    Map<String, String> vakitListesi = {
      'İmsak': vakitler!['Fajr'], 'Güneş': vakitler!['Sunrise'], 'Öğle': vakitler!['Dhuhr'],
      'İkindi': vakitler!['Asr'], 'Akşam': vakitler!['Maghrib'], 'Yatsı': vakitler!['Isha'],
    };

    DateTime? siradakiVakitZamani; 
    String siradakiVakitAd = '';

    // Döngü: Vakitleri sırayla gezip şu anki saatten İLERİDE olan İLK vakti buluyoruz.
    for (var entry in vakitListesi.entries) {
      List<String> saatDakika = entry.value.split(':'); // "15:30" -> ["15", "30"]
      DateTime vakitZamani = DateTime(suAn.year, suAn.month, suAn.day, int.parse(saatDakika[0]), int.parse(saatDakika[1]));
      
      if (vakitZamani.isAfter(suAn)) { 
        siradakiVakitZamani = vakitZamani; 
        siradakiVakitAd = entry.key; 
        break; // İlk ileri vakti bulduk, döngüyü kır.
      }
    }

    // EDGE CASE (Uç İhtimal): Saat 23:00 ve Yatsı okundu. İleride vakit yok.
    // Bu durumda sıradaki vakit, YARININ İmsak vaktidir.
    if (siradakiVakitZamani == null) {
      siradakiVakitAd = 'İmsak'; 
      List<String> imsakSaat = vakitler!['Fajr'].split(':');
      // Bugüne 1 gün ekleyip (add) yarının tarihini elde ediyoruz.
      siradakiVakitZamani = DateTime(suAn.year, suAn.month, suAn.day, int.parse(imsakSaat[0]), int.parse(imsakSaat[1])).add(const Duration(days: 1));
    }

    // İki zaman arasındaki farkı bul ve formatla (00:00:00 görünümü için padLeft kullanıyoruz)
    Duration fark = siradakiVakitZamani.difference(suAn);
    String formatliFark = '${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}';
    
    // Ekranda değişen sadece bu iki değişken olduğu için sadece bunları setState içine alıyoruz.
    setState(() { siradakiVakitIsmi = siradakiVakitAd; kalanSureMetni = formatliFark; });
  }

  // 9. EKRAN ÇİZİMİ (UI)
  @override
  Widget build(BuildContext context) {
    // Scaffold: Sayfanın inşaat iskelesidir (AppBar ve Body barındırır).
    return Scaffold(
      appBar: AppBar(
        title: Text(aktifSehir, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // DİNAMİK RENK: Sabit teal yerine, temanın ana rengini (primary) al diyoruz.
        backgroundColor: Theme.of(context).colorScheme.primary, 
        foregroundColor: Colors.white,
        elevation: 10,
        // actions: AppBar'ın sağ tarafına buton eklememizi sağlar.
        actions: [
          PopupMenuButton<Color>(
            icon: const Icon(Icons.palette), // Fırça paleti ikonu
            tooltip: 'Tema Seç',
            // onSelected: Listeden bir renk seçildiğinde çalışır.
            onSelected: (Color yeniRenk) {
              seciliTemaRengi.value = yeniRenk; // ValueNotifier'ı tetikler!
              setState(() {}); // Ekrandaki renkli kartların anında güncellenmesi için
            },
            // Seçenekleri oluşturuyoruz:
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Color>>[
              const PopupMenuItem<Color>(value: Colors.teal, child: Text('Zümrüt Yeşili')),
              const PopupMenuItem<Color>(value: Colors.blue, child: Text('Okyanus Mavisi')),
              const PopupMenuItem<Color>(value: Colors.deepPurple, child: Text('Gece Moru')),
              const PopupMenuItem<Color>(value: Colors.orange, child: Text('Gün Batımı Turuncusu')),
              const PopupMenuItem<Color>(value: Colors.brown, child: Text('Toprak Rengi')),
              const PopupMenuItem<Color>(value: Color.fromARGB(255, 248, 108, 204), child:Text('Toz Pembe')),
            ],
          ),
        ],
      ),
      // Container ile arka plana renk geçişi (Gradient) ekliyoruz.
      body: 
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), Colors.white],
          ),
        ),
        child: Center(
          child: yukleniyor
              ? const CircularProgressIndicator() // Yükleniyorsa dönen çark
              : hataMesaji.isNotEmpty
                  ? Padding(padding: const EdgeInsets.all(20), child: Text(hataMesaji, textAlign: TextAlign.center)) // Hata varsa metni bas
                  : Column(
                      children: [
                        const SizedBox(height: 20),
                        _anaSayacKarti(), // Özel tasarım ana sayaç widget'ımız
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 10),
                          child: Align(alignment: Alignment.centerLeft, child: Text("Bugünün Vakitleri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
                        ),
                        // Expanded & ListView: Kartların ekrandan taşmasını engeller, kaydırılabilir liste yapar.
                        Expanded(
                          child: ListView(
                            children: [
                              // DÜZELTME 2: Akşam vakti için sunset_call yerine nightlight_round kullanıldı.
                              _vakitKarti('İmsak', vakitler!['Fajr'], Icons.nights_stay, siradakiVakitIsmi == 'İmsak'),
                              _vakitKarti('Güneş', vakitler!['Sunrise'], Icons.wb_sunny_outlined, siradakiVakitIsmi == 'Güneş'),
                              _vakitKarti('Öğle', vakitler!['Dhuhr'], Icons.wb_sunny, siradakiVakitIsmi == 'Öğle'),
                              _vakitKarti('İkindi', vakitler!['Asr'], Icons.wb_twilight, siradakiVakitIsmi == 'İkindi'),
                              _vakitKarti('Akşam', vakitler!['Maghrib'], Icons.nightlight_round, siradakiVakitIsmi == 'Akşam'),
                              _vakitKarti('Yatsı', vakitler!['Isha'], Icons.bedtime, siradakiVakitIsmi == 'Yatsı'),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
    ),
    );
  }

  // 10. ÖZEL BİLEŞENLER (Kod tekrarını önlemek için dışarı çıkardığımız Widget'lar)
  Widget _anaSayacKarti() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text('$siradakiVakitIsmi Vaktine Kalan Süre', style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 10),
              Text(kalanSureMetni, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vakitKarti(String isim, String? saat, IconData ikon, bool aktifMi) {
    Color kartRengi = aktifMi ? Theme.of(context).colorScheme.primaryContainer : Colors.white;
    Color yaziRengi = aktifMi ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black87;

    return Card(
      color: kartRengi,
      child: ListTile(
        leading: Icon(ikon, color: Theme.of(context).colorScheme.primary, size: 32), 
        title: Text(isim, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: yaziRengi)),
        trailing: Text(saat ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: yaziRengi)),
      ),
    );
  }
}

// --- YENİ EKLENEN: ÖZEL GÜNLER SAYFASI ---
class OzelGunlerSayfasi extends StatelessWidget {
  const OzelGunlerSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dini Günler', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 10,
      ),
      // Arka plan renk geçişini bu sayfaya da uyguluyoruz
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Şimdilik örnek tarihleri elle giriyoruz
            _gunKarti(context, 'Üç Aylar Başlangıcı', '19 Aralık 2025', Icons.calendar_month),
            _gunKarti(context, 'Ramazan Başlangıcı', '17 Şubat 2026', Icons.brightness_3),
            _gunKarti(context, 'Kadir Gecesi', '15 Mart 2026', Icons.star),
            _gunKarti(context, 'Ramazan Bayramı', '19 Mart 2026', Icons.celebration),
            _gunKarti(context, 'Kurban Bayramı', '26 Mayıs 2026', Icons.volunteer_activism),
          ],
        ),
      ),
    );
  }

  // Özel günler için oluşturduğumuz yeni kart tasarımı
  Widget _gunKarti(BuildContext context, String isim, String tarih, IconData ikon) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(ikon, color: Theme.of(context).colorScheme.primary, size: 32),
        title: Text(isim, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(tarih, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}