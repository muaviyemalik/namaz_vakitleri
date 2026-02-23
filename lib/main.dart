// 1. KÜTÜPHANELER
import 'package:flutter/material.dart'; // Flutter'ın görsel materyalleri (Widget'lar, temalar)
import 'package:http/http.dart' as http; // İnternet (GET/POST) istekleri için. İsim çakışması olmasın diye 'as http' diyoruz.
import 'dart:convert'; // Gelen String veriyi (JSON) Dart'ın anlayacağı Map (sözlük) yapısına çevirmek için.
import 'dart:async'; // Timer (Zamanlayıcı) kullanmak için.
import 'package:geolocator/geolocator.dart'; // Konum koordinatlarını almak için
import 'package:geocoding/geocoding.dart'; // Koordinatı şehir ismine çevirmek için
import 'dart:io'; //Uygulamanın çalıştığı işletim sistemini bulmak için
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // YENİ: Bildirim kütüphanesi

// --- TEMA YÖNETİMİ ---
// ValueNotifier: İçindeki değer (renk) değiştiğinde, onu dinleyen widget'lara 
// "Güncellen!" mesajı gönderen özel bir yapıdır.
final ValueNotifier<Color> seciliTemaRengi = ValueNotifier<Color>(Colors.teal);

// YENİ: Bildirimleri yönetecek ana motorumuz (Global)
final FlutterLocalNotificationsPlugin bildirimServisi = FlutterLocalNotificationsPlugin();

// 2. BAŞLANGIÇ NOKTASI (Entry Point)
// C#'taki static void Main() metodunun karşılığıdır.
// 2. BAŞLANGIÇ NOKTASI (Entry Point - Güncellendi)
// asenkron (async) yaptık çünkü bildirim ayarlarının yüklenmesini bekleyeceğiz.
void main() async {
  // YENİ: main() içinde 'await' kullanıyorsak, Flutter motorunun tamamen hazır 
  // olduğundan emin olmak için bu satırı yazmak zorundayız.
  WidgetsFlutterBinding.ensureInitialized();

  // YENİ: BİLDİRİM AYARLARI
  // Android için varsayılan uygulama ikonunu kullan diyoruz.
  const AndroidInitializationSettings androidAyarlari = AndroidInitializationSettings('@mipmap/ic_launcher');
  // Senin şu an test ettiğin Pop!_OS (Linux) için gerekli ayarlar
  const LinuxInitializationSettings linuxAyarlari = LinuxInitializationSettings(defaultActionName: 'Uygulamayı Aç');
  
  // İşletim sistemlerini birleştir
  const InitializationSettings baslangicAyarlari = InitializationSettings(
    android: androidAyarlari,
    linux: linuxAyarlari,
  );

  // DÜZELTME: 'initializationSettings' etiketi zorunludur!
  await bildirimServisi.initialize(settings: baslangicAyarlari);

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

  // --- YENİ EKLENEN: BİLDİRİM GÖNDERME FONKSİYONU ---
  Future<void> _testBildirimiGonder() async {
    const AndroidNotificationDetails androidDetay = AndroidNotificationDetails(
      'ezan_kanali', 
      'Ezan Vakitleri',
      channelDescription: 'Vakit girdiğinde haber verir',
      importance: Importance.max,
      priority: Priority.high,
    );
    const LinuxNotificationDetails linuxDetay = LinuxNotificationDetails();

    const NotificationDetails bildirimDetaylari = NotificationDetails(
      android: androidDetay, 
      linux: linuxDetay
    );

    // Kütüphanenin beklediği tam format:
    await bildirimServisi.show(
      id: 0, 
      title: 'Vakit Geldi!', 
      body: '$siradakiVakitIsmi vakti girdi. Haydi namaza!', 
      notificationDetails: bildirimDetaylari,
    );
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
    
    if (formatliFark == "00:00:00") {
      _testBildirimiGonder(); // Bildirim metodunu çağır
    }

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
          // YENİ: Bildirimi manuel test etmek için zil butonu
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Bildirimi Test Et',
            onPressed: () {
              _testBildirimiGonder(); // Butona basınca bildirimi fırlat
            },
          ),
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

// --- ÖZEL GÜNLER SAYFASI (GÜNCELLENDİ: İnternetten Veri Çekme Mantığı) ---
class OzelGunlerSayfasi extends StatelessWidget {
  const OzelGunlerSayfasi({super.key});

  // --- API SİMÜLASYONU (Asenkron Veri Çekme) ---
  // C#'taki Task<List<DiniGun>> yapısının karşılığıdır.
  Future<List<DiniGun>> _ozelGunleriGetirAPI() async {
    // Gerçek bir API'den çekiyor olsaydık bu iki satırı kullanacaktık:
    // final cevap = await http.get(Uri.parse('https://senin-api-siten.com/dini-gunler'));
    // final String jsonMetni = cevap.body;

    // Arayüzü dondurmamak için asenkron (arka planda) 1 saniye bekletiyoruz (İnternet gecikmesi)
    await Future.delayed(const Duration(seconds: 1));

    // Sunucudan (API) bize döndüğünü varsaydığımız JSON formatında bir veri kümesi (Array)
    String sahteJsonResponse = '''
    [
      {
        "isim": "Üç Aylar Başlangıcı", 
        "tarih": "19 Aralık 2025", 
        "hicriTarih": "1 Recep 1447",
        "aciklama": "Recep, Şaban ve Ramazan aylarını kapsayan manevi iklimin başlangıcıdır.", 
        "ikon": "calendar_month"
      },
      {
        "isim": "Regaib Kandili", 
        "tarih": "22 Ocak 2026", 
        "hicriTarih": "3 Recep 1447",
        "aciklama": "Rahmet ve mağfiret gecesi, üç ayların ilk kandilidir. 'Regaib' çokça rağbet edilen, arzulanan anlamına gelir.", 
        "ikon": "mosque"
      },
      {
        "isim": "Miraç Kandili", 
        "tarih": "13 Şubat 2026", 
        "hicriTarih": "26 Recep 1447",
        "aciklama": "Peygamber Efendimiz'in (s.a.v) Mescid-i Haram'dan Mescid-i Aksa'ya, oradan da göğe yükseldiği mucizevi gecedir.", 
        "ikon": "auto_awesome"
      },
      {
        "isim": "Ramazan Başlangıcı", 
        "tarih": "17 Şubat 2026", 
        "hicriTarih": "1 Ramazan 1447",
        "aciklama": "On bir ayın sultanı, oruç ibadetinin yerine getirildiği mübarek aydır.", 
        "ikon": "brightness_3"
      },
      {
        "isim": "Berat Kandili", 
        "tarih": "3 Mart 2026", 
        "hicriTarih": "14 Şaban 1447",
        "aciklama": "Günahlardan arınma, af, şefaat ve mağfiret gecesidir.", 
        "ikon": "nightlight_round"
      },
      {
        "isim": "Kadir Gecesi", 
        "tarih": "15 Mart 2026", 
        "hicriTarih": "27 Ramazan 1447",
        "aciklama": "Kur'an-ı Kerim'in indirildiği, bin aydan daha hayırlı olan gecedir.", 
        "ikon": "star"
      },
      {
        "isim": "Ramazan Bayramı", 
        "tarih": "19 Mart 2026", 
        "hicriTarih": "1 Şevval 1447",
        "aciklama": "Oruç ibadetinin ardından Müslümanların sevincini paylaştığı günlerdir.", 
        "ikon": "celebration"
      },
      {
        "isim": "Kurban Bayramı", 
        "tarih": "26 Mayıs 2026", 
        "hicriTarih": "10 Zilhicce 1447",
        "aciklama": "Yardımlaşma ve dayanışmanın zirveye çıktığı, kurban ibadetinin yerine getirildiği bayramdır.", 
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Hicri Yılbaşı", 
        "tarih": "16 Haziran 2026", 
        "hicriTarih": "1 Muharrem 1448",
        "aciklama": "Peygamber Efendimiz'in (s.a.v) Mekke'den Medine'ye hicretini esas alan Hicri takvimin ilk günüdür.", 
        "ikon": "event"
      },
      {
        "isim": "Aşure Günü", 
        "tarih": "25 Haziran 2026", 
        "hicriTarih": "10 Muharrem 1448",
        "aciklama": "Peygamberlerin hayatında birçok önemli hadisenin gerçekleştiği, bereket ve paylaşma günüdür.", 
        "ikon": "local_dining"
      },
      {
        "isim": "Mevlid Kandili", 
        "tarih": "25 Ağustos 2026", 
        "hicriTarih": "11 Rebiülevvel 1448",
        "aciklama": "Alemlere rahmet olarak gönderilen Peygamber Efendimiz'in (s.a.v) dünyaya teşrif ettiği (doğduğu) gecedir.", 
        "ikon": "menu_book"
      }
    ]
    ''';

    // 1. JSON metnini List<dynamic> yapısına dönüştür (Decode)
    List<dynamic> cozulmusJson = json.decode(sahteJsonResponse);
    
    // 2. Listedeki her bir elemanı (Map) DiniGun nesnesine çevir ve bir List<DiniGun> olarak geri döndür.
    // C#'taki LINQ Select() metodu ile birebir aynı işi yapar.
    return cozulmusJson.map((jsonElemani) => DiniGun.fromJson(jsonElemani)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dini Günler', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), Colors.white],
          ),
        ),
        // FUTUREBUILDER: Arka planda çalışan bir fonksiyonu dinler. 
        // Veri beklerken çark gösterir, veri gelince ekranı çizer.
        child: FutureBuilder<List<DiniGun>>(
          future: _ozelGunleriGetirAPI(), // Hangi asenkron fonksiyonu bekleyecek?
          builder: (context, snapshot) {
            
            // Durum 1: İnternetten veri hala iniyor
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Sunucudan veriler alınıyor...', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              );
            }
            
            // Durum 2: API'den hata döndü (Bağlantı koptu vb.)
            if (snapshot.hasError) {
              return Center(child: Text('Bir hata oluştu: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }
            
            // Durum 3: Veriler başarıyla geldi ve çözümlendi
            if (snapshot.hasData) {
              List<DiniGun> gelenListe = snapshot.data!; // Artık elimizde nesne listemiz var
              
              // ListView.builder: Tıpkı bir 'foreach' döngüsü gibi, elindeki liste kadar kart çizer.
              // Ekrandan taşan binlerce veri olsa bile sadece ekranda görünenleri belleğe alır (Çok performanslıdır).
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: gelenListe.length, // Kaç tane dönecek?
                itemBuilder: (context, index) {
                  // O anki satırın nesnesini alıyoruz
                  DiniGun oAnkiGun = gelenListe[index]; 
                  
                  // Ve kartımıza gönderiyoruz
                  return _gunKarti(context, oAnkiGun.isim, oAnkiGun.tarih, oAnkiGun.hicriTarih, oAnkiGun.ikon, oAnkiGun.aciklama);
                },
              );
            }
            
            return const Center(child: Text('Gösterilecek veri bulunamadı.'));
          },
        ),
      ),
    );
  }

  // --- KART TASARIMI (GÜNCELLENDİ) ---
  Widget _gunKarti(BuildContext context, String isim, String tarih, String hicriTarih, IconData ikon, String aciklama) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(ikon, color: Theme.of(context).colorScheme.primary, size: 32),
        title: Text(isim, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        // YENİ: Alt başlık (subtitle) kısmında artık alt alta iki yazı göstermek için Column kullanıyoruz.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Yazıları sola yasla
          children: [
            const SizedBox(height: 4), // İsimle tarih arasına minik bir boşluk
            Text(tarih, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            Text(hicriTarih, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)), // İstediğin gri ve biraz daha küçük fontlu hicri tarih
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _altPanelAc(context, isim, tarih, hicriTarih, aciklama, ikon),
      ),
    );
  }

  // --- DETAY PANELİ TASARIMI (GÜNCELLENDİ) ---
  void _altPanelAc(BuildContext context, String isim, String tarih, String hicriTarih, String aciklama, IconData ikon) {
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
              // Panelin içine de hicri tarihi ekliyoruz
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
                  child: const Text('Kapat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
// --- YENİ EKLENEN: VERİ MODELİ (DTO) ---
// --- VERİ MODELİ (GÜNCELLENDİ: Hicri Tarih Eklendi) ---
// --- VERİ MODELİ (GÜNCELLENDİ: Hicri Tarih Eklendi) ---
// --- VERİ MODELİ (GÜNCELLENDİ: Yeni İkonlar Eklendi) ---
class DiniGun {
  final String isim;
  final String tarih;
  final String hicriTarih; 
  final String aciklama;
  final IconData ikon;

  DiniGun({required this.isim, required this.tarih, required this.hicriTarih, required this.aciklama, required this.ikon});

  factory DiniGun.fromJson(Map<String, dynamic> json) {
    IconData seciliIkon = Icons.event; // Varsayılan ikon
    if (json['ikon'] == 'brightness_3') seciliIkon = Icons.brightness_3;
    if (json['ikon'] == 'star') seciliIkon = Icons.star;
    if (json['ikon'] == 'celebration') seciliIkon = Icons.celebration;
    if (json['ikon'] == 'volunteer_activism') seciliIkon = Icons.volunteer_activism;
    if (json['ikon'] == 'calendar_month') seciliIkon = Icons.calendar_month;
    
    // YENİ EKLENEN İKONLAR: Kandiller ve diğer özel günler için
    if (json['ikon'] == 'mosque') seciliIkon = Icons.mosque; // Camii ikonu
    if (json['ikon'] == 'auto_awesome') seciliIkon = Icons.auto_awesome; // Parıltı/Mucize ikonu
    if (json['ikon'] == 'nightlight_round') seciliIkon = Icons.nightlight_round; // Gece/Kandil ikonu
    if (json['ikon'] == 'local_dining') seciliIkon = Icons.local_dining; // Aşure/İkram ikonu
    if (json['ikon'] == 'menu_book') seciliIkon = Icons.menu_book; // Kitap/Mevlid ikonu

    return DiniGun(
      isim: json['isim'],
      tarih: json['tarih'],
      hicriTarih: json['hicriTarih'], 
      aciklama: json['aciklama'],
      ikon: seciliIkon,
    );
  }
}