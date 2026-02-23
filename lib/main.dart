// 1. KÜTÜPHANELER
import 'package:flutter/material.dart'; // Flutter'ın görsel materyalleri (Widget'lar, temalar)
import 'package:http/http.dart' as http; // İnternet (GET/POST) istekleri için. İsim çakışması olmasın diye 'as http' diyoruz.
import 'dart:convert'; // Gelen String veriyi (JSON) Dart'ın anlayacağı Map (sözlük) yapısına çevirmek için.
import 'dart:async'; // Timer (Zamanlayıcı) kullanmak için.
import 'package:geolocator/geolocator.dart'; // Konum koordinatlarını almak için
import 'package:geocoding/geocoding.dart'; // Koordinatı şehir ismine çevirmek için
import 'dart:io'; //Uygulamanın çalıştığı işletim sistemini bulmak için
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // YENİ: Bildirim kütüphanesi
import 'package:shared_preferences/shared_preferences.dart'; //Kullanıcı tercihlerini kaydeder
import 'package:timezone/data/latest_all.dart' as tz; //arka plan bildirimleri için
import 'package:timezone/timezone.dart' as tz; //arka plan bildirimleri için
import 'package:share_plus/share_plus.dart'; //ayet paylaşabilmek için
import 'dart:math' as math; // Trigonometrik Kıble hesaplamaları için
import 'package:flutter/services.dart'; // HapticFeedback (Titreşim) için
import 'package:flutter_compass/flutter_compass.dart'; // Pusula sensörü için

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

// --- TEMA HAFIZA YÖNETİMİ ---

// Seçilen rengi telefona kaydeder
Future<void> temaRenginiKaydet(Color renk) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  // Renk kodunu (0xFF...) integer olarak kaydediyoruz
  await hafiza.setInt('kayitli_tema_rengi', renk.value);
}

// Uygulama açılırken rengi geri yükler
Future<void> temaRenginiYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  final int? renkKodu = hafiza.getInt('kayitli_tema_rengi');
  
  if (renkKodu != null) {
    // Eğer daha önce kaydedilmiş bir renk varsa, global değişkeni güncelle
    seciliTemaRengi.value = Color(renkKodu);
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // YENİ: Saat dilimi (timezone) veritabanını başlat
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  const AndroidInitializationSettings androidAyarlari = AndroidInitializationSettings('@mipmap/ic_launcher');
  const LinuxInitializationSettings linuxAyarlari = LinuxInitializationSettings(defaultActionName: 'Uygulamayı Aç');
  const InitializationSettings baslangicAyarlari = InitializationSettings(android: androidAyarlari, linux: linuxAyarlari);
  
  await bildirimServisi.initialize(settings: baslangicAyarlari);
  await temaRenginiYukle();

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
    const OzelGunlerSayfasi(), //Özel Günler sayfası
    const KibleSayfasi(), //Pusula sayfası
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
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Kıble',
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

  // --- HAFIZA VE ŞEHİR YÖNETİMİ ---

  // --- GÜNCELLENEN: AÇILIR MENÜLÜ ŞEHİR SEÇİMİ ---
  Future<String?> _sehirDegistirDialog(BuildContext context) {
    // 81 ilin alfabetik tam listesi
    List<String> sehirler = [
      'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara', 'Antalya', 'Ardahan', 'Artvin',
      'Aydın', 'Balıkesir', 'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
      'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
      'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul',
      'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale', 'Kırklareli', 'Kırşehir',
      'Kilis', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
      'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas',
      'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
    ];

    String seciliDeger = sehirler.contains(aktifSehir) ? aktifSehir : 'Ankara';

    // --- GÜNÜN AYETİ HAVUZU ---
  final List<Map<String, String>> _ayetListesi = [
    {
      "sure": "Bakara Suresi, 152. Ayet",
      "meal": "Öyleyse yalnız beni anın ki ben de sizi anayım. Bana şükredin, sakın nankörlük etmeyin."
    },
    {
      "sure": "İnşirah Suresi, 5-6. Ayet",
      "meal": "Elbette zorluğun yanında bir kolaylık vardır. Gerçekten, zorlukla beraber bir kolaylık daha vardır."
    },
    {
      "sure": "Tâhâ Suresi, 46. Ayet",
      "meal": "Korkmayın! Çünkü ben sizinle beraberim; işitirim ve görürüm."
    },
    {
      "sure": "Zümer Suresi, 53. Ayet",
      "meal": "Ey kendi aleyhlerine haddi aşan kullarım! Allah'ın rahmetinden ümidinizi kesmeyin."
    },
    {
      "sure": "Rad Suresi, 28. Ayet",
      "meal": "Onlar, inananlar ve kalpleri Allah'ı anmakla huzura kavuşanlardır. Biliniz ki, kalpler ancak Allah'ı anmakla huzur bulur."
    }
  ];

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Şehir Seçin'),
            content: DropdownButton<String>(
              value: seciliDeger,
              isExpanded: true,
              // Liste çok uzun olacağı için kaydırma çubuğu otomatik çıkacaktır
              menuMaxHeight: 400, 
              icon: const Icon(Icons.location_on, color: Colors.teal),
              items: sehirler.map((String sehir) {
                return DropdownMenuItem<String>(
                  value: sehir,
                  child: Text(sehir, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              onChanged: (String? yeniDeger) {
                if (yeniDeger != null) {
                  setStateDialog(() {
                    seciliDeger = yeniDeger;
                  });
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('İptal')
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, seciliDeger),
                child: const Text('Tamam'),
              ),
            ],
          );
        }
      ),
    );
  }
  // --- DEĞİŞKENLER (STATE) ---

  Map<String, dynamic>? vakitler; // JSON'dan gelecek vakitleri tutacak. Başlangıçta null.
  bool yukleniyor = true; // Ekranda yüklenme çarkını gösterme kontrolü.
  String hataMesaji = ''; // İnternet/API hatalarını tutacak metin.
  
  Timer? _zamanlayici; // Her saniye çalışacak motor.
  String siradakiVakitIsmi = ''; // Ekrana basılacak sıradaki vaktin adı.
  String kalanSureMetni = ''; // Ekrana basılacak 00:00:00 formatındaki süre.
  String aktifSehir = 'Ankara'; // Varsayılan şehir. GPS bulana kadar bu görünecek.
  String miladiTarih = ""; //Mevcut miladi tarih
  String hicriTarih = ""; // Mevcut hicri tarih

  // initState(): Ekran oluşturulmadan hemen ÖNCE BİR KERE çalışır (C# Constructor / Form_Load gibi).
  @override
  void initState() {
    super.initState();
    _uygulamaVerileriniYukle();
  }

  Future<void> _uygulamaVerileriniYukle() async {
    final SharedPreferences hafiza = await SharedPreferences.getInstance();
    
    // Kayıtlı şehri al, yoksa Ankara'yı varsayılan yap
    String kayitliSehir = hafiza.getString('secili_sehir') ?? 'Ankara';
    
    setState(() { 
      aktifSehir = kayitliSehir; 
    });
    
    // Şehri belirledikten sonra vakitleri getir
    await vakitleriGetir();
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
  Future<void> _vakitBildirimiGonder() async {
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

  // --- YENİ EKLENEN: OTOMATİK KONUM BULMA MOTORU ---
  // --- YENİ GÜNCELLENEN: OTOMATİK KONUM BULMA MOTORU ---
  Future<void> _otomatikKonumBul() async {
    setState(() {
      yukleniyor = true; 
      // hataMesaji'ni bilerek doldurmuyoruz ki UI çökmesin!
    });

    try {
      bool servisAcikMi = await Geolocator.isLocationServiceEnabled();
      if (!servisAcikMi) {
        _konumHatasiBildir("Konum servisleri kapalı. Kayıtlı şehirden devam ediliyor.");
        return;
      }

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
        if (izin == LocationPermission.denied) {
          _konumHatasiBildir("Konum izni reddedildi. Kayıtlı şehirden devam ediliyor.");
          return;
        }
      }

      if (izin == LocationPermission.deniedForever) {
        _konumHatasiBildir("Konum izinleri kalıcı olarak reddedildi.");
        return;
      }

      // Bu işlem 3-5 saniye sürebilir
      Position pozisyon = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);

      List<Placemark> yerIsimleri = await placemarkFromCoordinates(pozisyon.latitude, pozisyon.longitude);
      
      if (yerIsimleri.isNotEmpty) {
        Placemark yer = yerIsimleri[0];
        
        String bulunanSehir = yer.administrativeArea ?? yer.subAdministrativeArea ?? "";
        bulunanSehir = bulunanSehir.replaceAll(" Province", "").replaceAll(" Province", "");

        setState(() {
          aktifSehir = bulunanSehir;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('secili_sehir', bulunanSehir);
        
        await vakitleriGetir(); // Yeni şehrin verilerini çek
        
      } else {
        _konumHatasiBildir("Bulunduğunuz şehir tespit edilemedi.");
      }

    } catch (e) {
      debugPrint("Konum hatası: $e");
      // Linux DBus veya diğer hatalarda ekranı bozmadan uyarı ver
      _konumHatasiBildir("Konum bulunamadı (PC'de normaldir). Eski şehirden devam ediliyor.");
    }
  }

  // YENİ EKLENEN YARDIMCI FONKSİYON: Ekranı bozmadan şık uyarı verir
  void _konumHatasiBildir(String uyariMetni) {
    setState(() {
      yukleniyor = false; // Yüklenme çarkını durdur, eski ekrana dön
    });
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(uyariMetni),
        backgroundColor: Colors.orange.shade800, // Dikkat çekici ama rahatsız etmeyen turuncu
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // 6. API'DEN VERİ ÇEKME (Asenkron - Future)
  // async/await: İnternetten cevap gelene kadar uygulamanın arayüzünü kilitlememek (donmamasını sağlamak) için.
  // void yerine bool yaptık
  Future<bool> vakitleriGetir() async {
    setState(() { yukleniyor = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final String hafizaAnahtari = 'vakitler_${aktifSehir}_${now.month}_${now.year}';
      
      String? telefondakiVeri = prefs.getString(hafizaAnahtari);

      final url = Uri.parse('http://api.aladhan.com/v1/calendarByCity?city=$aktifSehir&country=Turkey&method=13&month=${now.month}&year=${now.year}');

      try {
        final cevap = await http.get(url).timeout(const Duration(seconds: 5));
        if (cevap.statusCode == 200) {
          telefondakiVeri = cevap.body;
          await prefs.setString(hafizaAnahtari, telefondakiVeri);
        }
      } catch (e) {
        debugPrint("İnternet yok, hafızaya bakılıyor.");
      }

      if (telefondakiVeri != null) {
        final jsonVeri = json.decode(telefondakiVeri);
        final aylikListe = jsonVeri['data'] as List;
        final bugunIndex = now.day - 1;
        final gunlukVeri = aylikListe[bugunIndex];
        
        final tarihVerisi = gunlukVeri['date'];
        final vakitlerVerisi = gunlukVeri['timings'];

        setState(() {
          vakitler = {
            'Fajr': vakitlerVerisi['Fajr'].substring(0, 5),
            'Sunrise': vakitlerVerisi['Sunrise'].substring(0, 5),
            'Dhuhr': vakitlerVerisi['Dhuhr'].substring(0, 5),
            'Asr': vakitlerVerisi['Asr'].substring(0, 5),
            'Maghrib': vakitlerVerisi['Maghrib'].substring(0, 5),
            'Isha': vakitlerVerisi['Isha'].substring(0, 5),
          };

          miladiTarih = tarihVerisi['gregorian']['date'];
          
          String hGun = tarihVerisi['hijri']['day'];
          String hAy = tarihVerisi['hijri']['month']['en'];
          String hYil = tarihVerisi['hijri']['year'];
          hicriTarih = "$hGun $hAy $hYil";
          
          yukleniyor = false;
        });

        // Sayacı da başlattık
        sayaciBaslat(); 

        // YENİ: Alarmları sisteme kur!
        _gunlukBildirimleriZamanla();
        
        return true; // <--- İŞLEM BAŞARILI, TRUE DÖNDÜR
      } else {
        setState(() { yukleniyor = false; });
        return false; // <--- İŞLEM BAŞARISIZ (İnternet ve veri yok), FALSE DÖNDÜR
      }
    } catch (e) {
      debugPrint("Kritik Hata: $e");
      setState(() { yukleniyor = false; });
      return false; // <--- HATA OLDU, FALSE DÖNDÜR
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
// --- EKSİK OLAN ARKA PLAN BİLDİRİM DÖNGÜSÜ ---
  Future<void> _gunlukBildirimleriZamanla() async {
    if (vakitler == null) return;

    await bildirimServisi.cancelAll(); // Eski alarmları temizle
    final suAn = DateTime.now();

    Map<String, String> vakitListesi = {
      'İmsak': vakitler!['Fajr'], 'Güneş': vakitler!['Sunrise'], 'Öğle': vakitler!['Dhuhr'],
      'İkindi': vakitler!['Asr'], 'Akşam': vakitler!['Maghrib'], 'Yatsı': vakitler!['Isha'],
    };

    int id = 0;
    vakitListesi.forEach((vakitAdi, saatMetni) async {
      List<String> saatDakika = saatMetni.split(':');
      DateTime vakitZamani = DateTime(suAn.year, suAn.month, suAn.day, int.parse(saatDakika[0]), int.parse(saatDakika[1]));

      if (vakitZamani.isAfter(suAn)) {
        await _tekilAlarmKur(id, vakitAdi, vakitZamani);
      }
      id++; 
    });
  }

  Future<void> _tekilAlarmKur(int id, String vakitAdi, DateTime zaman) async {
    const AndroidNotificationDetails androidDetay = AndroidNotificationDetails(
      'ezan_kanali_arka_plan', 
      'Arka Plan Ezan Vakitleri',
      channelDescription: 'Uygulama kapalıyken vakit girdiğinde haber verir',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails bildirimDetaylari = NotificationDetails(android: androidDetay);

    // YENİ SÜRÜM KURALLARI: Bütün parametreler isimlendirildi (named arguments) 
    // ve kaldırılan uiLocalNotificationDateInterpretation ayarı silindi.
    await bildirimServisi.zonedSchedule(
      id: id,
      title: 'Vakit Geldi!',
      body: '$vakitAdi vakti girdi. Haydi namaza!',
      scheduledDate: tz.TZDateTime.from(zaman, tz.local),
      notificationDetails: bildirimDetaylari,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Uykuda bile uyandırır
    );
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
    
    // --- GÜNCELLENEN: GÜVENLİ OTOMATİK BİLDİRİM ---
    if (formatliFark == "00:00:00") {
      // Sadece o saniyede bir kez çalışması için kontrol
      _vakitBildirimiGonder();
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

          // YENİ EKLENEN: Otomatik Konum Bulma Butonu (GPS İkonu)
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Konumumu Bul',
            onPressed: () {
              // Tıklandığında yazdığımız motoru çalıştırır
              _otomatikKonumBul();
            },
          ),
          // Şehir Değiştirme Butonu
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: () async {
              // Dialog'dan yeni şehri bekle
              String? yeniSehir = await _sehirDegistirDialog(context);
              
              // Eğer kullanıcı iptal demediyse ve farklı bir şehir seçtiyse:
              if (yeniSehir != null && yeniSehir != aktifSehir) {
                
                String eskiSehir = aktifSehir; // Eski şehri yedekle (Örn: Ankara)
                
                setState(() {
                  aktifSehir = yeniSehir; // Yeni şehri ayarla (Örn: İstanbul)
                });
                
                // Verileri çekmeyi dene ve sonucu dinle
                bool basariliMi = await vakitleriGetir();
                
                // Eğer internet yoksa ve o şehrin verisi daha önce inmemişse:
                if (!basariliMi) {
                  setState(() {
                    aktifSehir = eskiSehir; // Sessizce eski şehre geri dön
                  });
                  
                  if (!context.mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("İnternet bağlantısı yok! $yeniSehir verileri alınamadı."),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(10),
                    ),
                  );
                } else {
                  // YENİ EKLENEN KISIM BURASI: Veri başarıyla çekildiyse şehri hafızaya kazı!
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('secili_sehir', yeniSehir);
                }
              }
            },
          ),

          PopupMenuButton<Color>(
            icon: const Icon(Icons.palette), // Fırça paleti ikonu
            tooltip: 'Tema Seç',
            // onSelected: Listeden bir renk seçildiğinde çalışır.
            onSelected: (Color yeniRenk) {
  seciliTemaRengi.value = yeniRenk; // Ekranı günceller
  temaRenginiKaydet(yeniRenk);     // YENİ: Hafızaya yazar
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
                  : // Column ve Expanded yerine tüm sayfayı tek bir ListView yapıyoruz:
                   ListView(
                      padding: const EdgeInsets.only(bottom: 20), // En alta biraz boşluk
                      children: [
                        const SizedBox(height: 20),
                        
                        _anaSayacKarti(), // Ana Sayaç
                        _gununAyetiKarti(), // Günün Ayeti
                        _gununHadisiKarti(), // Günün Hadisi
                        
                        const SizedBox(height: 10), 
                        
                        Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft, 
                            child: Text("Bugünün Vakitleri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
                          ),
                        ),
                        
                        // Artık Expanded'a gerek yok, kartları direkt listeye diziyoruz
                        _vakitKarti('İmsak', vakitler!['Fajr'], Icons.nights_stay, siradakiVakitIsmi == 'İmsak'),
                        _vakitKarti('Güneş', vakitler!['Sunrise'], Icons.wb_sunny_outlined, siradakiVakitIsmi == 'Güneş'),
                        _vakitKarti('Öğle', vakitler!['Dhuhr'], Icons.wb_sunny, siradakiVakitIsmi == 'Öğle'),
                        _vakitKarti('İkindi', vakitler!['Asr'], Icons.wb_twilight, siradakiVakitIsmi == 'İkindi'),
                        _vakitKarti('Akşam', vakitler!['Maghrib'], Icons.nightlight_round, siradakiVakitIsmi == 'Akşam'),
                        _vakitKarti('Yatsı', vakitler!['Isha'], Icons.bedtime, siradakiVakitIsmi == 'Yatsı'),
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
              Text('$miladiTarih', style: const TextStyle(fontSize: 16, color: Colors.white70)),
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
  Widget _gununAyetiKarti() {
    // AYET HAVUZUNU DOĞRUDAN FONKSİYONUN İÇİNE ALDIK (Hata riski sıfırlandı)
    final List<Map<String, String>> ayetListesi = [
      {
        "sure": "Bakara Suresi, 152. Ayet",
        "meal": "Öyleyse yalnız beni anın ki ben de sizi anayım. Bana şükredin, sakın nankörlük etmeyin."
      },
      {
        "sure": "İnşirah Suresi, 5-6. Ayet",
        "meal": "Elbette zorluğun yanında bir kolaylık vardır. Gerçekten, zorlukla beraber bir kolaylık daha vardır."
      },
      {
        "sure": "Tâhâ Suresi, 46. Ayet",
        "meal": "Korkmayın! Çünkü ben sizinle beraberim; işitirim ve görürüm."
      },
      {
        "sure": "Zümer Suresi, 53. Ayet",
        "meal": "Ey kendi aleyhlerine haddi aşan kullarım! Allah'ın rahmetinden ümidinizi kesmeyin."
      },
      {
        "sure": "Rad Suresi, 28. Ayet",
        "meal": "Onlar, inananlar ve kalpleri Allah'ı anmakla huzura kavuşanlardır. Biliniz ki, kalpler ancak Allah'ı anmakla huzur bulur."
      },
      {
        "sure": "Bakara Suresi, 153. Ayet",
        "meal": "Ey iman edenler! Sabır ve namazla yardım dileyin. Şüphesiz Allah sabredenlerin yanındadır."
      },
      {
        "sure": "Tevbe Suresi, 40. Ayet",
        "meal": "Üzülme, çünkü Allah bizimle beraberdir."
      },
      {
        "sure": "Duhâ Suresi, 3. Ayet",
        "meal": "Rabbin seni ne terk etti, ne de sana darıldı."
      },
      {
        "sure": "Talâk Suresi, 3. Ayet",
        "meal": "Kim Allah’a tevekkül ederse, O kendisine yeter. Şüphesiz Allah, emrini yerine getirendir."
      },
      {
        "sure": "Necm Suresi, 39. Ayet",
        "meal": "Bilsin ki insan için kendi çalışmasından başka bir şey yoktur."
      },
      {
        "sure": "İbrahim Suresi, 7. Ayet",
        "meal": "Andolsun, eğer şükrederseniz elbette size nimetimi artırırım."
      },
      {
        "sure": "Bakara Suresi, 216. Ayet",
        "meal": "Sizin hayır bildiğinizde şer, şer bildiğinizde hayır vardır. Allah bilir, siz bilemezsiniz."
      },
      {
        "sure": "Mü’minûn Suresi, 118. Ayet",
        "meal": "De ki: Rabbim, bağışla ve merhamet et! Sen merhametlilerin en hayırlısısın."
      },
      {
        "sure": "Yusuf Suresi, 87. Ayet",
        "meal": "Allah'ın rahmetinden ümit kesmeyin. Çünkü kafirler topluluğundan başkası Allah'ın rahmetinden ümit kesmez."
      },
      {
        "sure": "İnşirah Suresi, 7-8. Ayet",
        "meal": "Boş kaldın mı hemen başka bir işe koyul ve yalnız Rabbine yönel."
      },
      {
        "sure": "Kaf Suresi, 16. Ayet",
        "meal": "Andolsun, insanı biz yarattık ve nefsinin ona verdiği vesveseyi de biz biliriz. Çünkü biz ona şah damarından daha yakınız."
      },
      {
        "sure": "Hicr Suresi, 99. Ayet",
        "meal": "Sana ölüm gelinceye kadar Rabbine ibadet et."
      },
      {
        "sure": "Ankebût Suresi, 69. Ayet",
        "meal": "Bizim uğrumuzda cihat edenler var ya, biz onları mutlaka yollarımıza ileteceğiz."
      },
      {
        "sure": "Bakara Suresi, 286. Ayet",
        "meal": "Allah kimseye gücünün yettiğinden fazlasını yüklemez."
      },
      {
        "sure": "Âl-i İmrân Suresi, 139. Ayet",
        "meal": "Gevşemeyin, hüzünlenmeyin. Eğer (gerçekten) iman etmişseniz, üstün olan sizsiniz."
      },
      {
        "sure": "En'âm Suresi, 17. Ayet",
        "meal": "Eğer Allah sana bir zarar dokunduracak olsa, onu O'ndan başka giderecek yoktur."
      },
      {
        "sure": "Mülk Suresi, 19. Ayet",
        "meal": "Üstlerinde kanat çırparak uçan kuşlara bakmazlar mı? Onları (havada) Rahman olan Allah’tan başkası tutmuyor."
      },
      {
        "sure": "Şuarâ Suresi, 80. Ayet",
        "meal": "Hastalandığım zaman bana şifa veren O’dur."
      },
      {
        "sure": "Nahl Suresi, 128. Ayet",
        "meal": "Şüphesiz Allah, takva sahipleriyle ve iyilikte bulunanlarla beraberdir."
      },
      {
        "sure": "Meryem Suresi, 96. Ayet",
        "meal": "İnanıp hayırlı işler yapanlar için Rahman olan Allah, (gönüllerde) bir sevgi yaratacaktır."
      }
    ];

    // 1. Yılın kaçıncı gününde olduğumuzu bul
    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final int kacinciGun = suAn.difference(yilinIlkGunu).inDays;

    // 2. Modül işlemi (Artık liste burada olduğu için int hatası vermeyecek)
    final int ayetIndeksi = kacinciGun % ayetListesi.length;
    final Map<String, String> bugununAyeti = ayetListesi[ayetIndeksi];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(), // Yazıyı ortalamak için boşluk itici
                  Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text("Günün Ayeti", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
                  const Spacer(), // Yazıyı ortalamak için boşluk itici
                  
                  // YENİ: Paylaş Butonu
                  IconButton(
                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary, size: 20),
                    tooltip: 'Ayeti Paylaş',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(), // Butonun etrafındaki gereksiz boşluğu alır
                    onPressed: () {
                      // Tıklandığında telefonun kendi paylaşım menüsünü açar
                      Share.share('"${bugununAyeti["meal"]}"\n\n- ${bugununAyeti["sure"]}\n\nNamaz Vakitleri Uygulamasından paylaşıldı.');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '"${bugununAyeti["meal"]}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                "- ${bugununAyeti["sure"]}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _gununHadisiKarti() {
    // --- HADİS HAVUZU ---
    final List<Map<String, String>> hadisListesi = [
      {
        "kaynak": "Buhârî, Îmân, 1",
        "hadis": "Ameller niyetlere göredir. Herkes sadece niyetinin karşılığını alır."
      },
      {
        "kaynak": "Müslim, Birr, 32",
        "hadis": "Kim bir müminin dünyevi sıkıntılarından birini giderirse, Allah da onun kıyamet günündeki sıkıntılarından birini giderir."
      },
      {
        "kaynak": "Tirmizî, Birr, 16",
        "hadis": "Sizin en hayırlınız, ahlâkı en güzel olanınızdır."
      },
      {
        "kaynak": "Ebû Dâvûd, Edeb, 60",
        "hadis": "İnsanlara merhamet etmeyene Allah merhamet etmez."
      },
      {
        "kaynak": "Buhârî, Rikak, 3",
        "hadis": "İki nimet vardır ki insanların çoğu bu konuda aldanmıştır: Sağlık ve boş vakit."
      },
      {
    "kaynak": "Buhârî, İlim, 10",
    "hadis": "Allah, kimin için hayır dilerse onu dinde derin anlayış sahibi kılar."
  },
  {
    "kaynak": "Müslim, Îmân, 71",
    "hadis": "Hiçbiriniz, kendisi için istediğini kardeşi için de istemedikçe (gerçek manada) iman etmiş olmaz."
  },
  {
    "kaynak": "Tirmizî, Zühd, 11",
    "hadis": "Kendisini ilgilendirmeyen şeyleri terk etmesi, bir kişinin müslümanlığının güzelliğindendir."
  },
  {
    "kaynak": "İbn Mâce, Mukaddime, 17",
    "hadis": "İlim öğrenmek, her müslüman üzerine farzdır."
  },
  {
    "kaynak": "Ebû Dâvûd, Edeb, 20",
    "hadis": "Hayra vesile olan, o hayrı işlemiş gibidir."
  },
  {
    "kaynak": "Buhârî, Edeb, 69",
    "hadis": "Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz."
  },
  {
    "kaynak": "Müslim, Îmân, 164",
    "hadis": "Müslüman, dilinden ve elinden insanların güvende olduğu kişidir."
  },
  {
    "kaynak": "Tirmizî, Birr, 18",
    "hadis": "Nerede olursan ol, Allah’tan kork. Kötülüğün peşinden hemen bir iyilik yap ki onu silsin."
  },
  {
    "kaynak": "Ebû Dâvûd, Edeb, 7",
    "hadis": "Küçüklerimize merhamet etmeyen, büyüklerimize saygı göstermeyen bizden değildir."
  },
  {
    "kaynak": "Buhârî, Îmân, 1",
    "hadis": "Doğruluktan ayrılmayın. Çünkü doğruluk iyiliğe, iyilik de cennete götürür."
  },
  {
    "kaynak": "Müslim, Zikir, 38",
    "hadis": "Dua, ibadetin özüdür."
  },
  {
    "kaynak": "Tirmizî, Birr, 36",
    "hadis": "Güler yüzle insanlara selam vermen de bir sadakadır."
  },
  {
    "kaynak": "Buhârî, Edeb, 31",
    "hadis": "Komşusu açken tok yatan bizden değildir."
  },
  {
    "kaynak": "İbn Mâce, Zühd, 15",
    "hadis": "Dünyada bir garip veya bir yolcu gibi ol."
  },
  {
    "kaynak": "Müslim, Birr, 2",
    "hadis": "İyilik, güzel ahlaktır. Günah ise vicdanını rahatsız eden şeydir."
  },
  {
    "kaynak": "Ebû Dâvûd, Edeb, 81",
    "hadis": "Bizi aldatan bizden değildir."
  },
  {
    "kaynak": "Buhârî, Edeb, 18",
    "hadis": "Söz taşıyan (koğuculuk yapan) cennete giremez."
  },
  {
    "kaynak": "Tirmizî, Zühd, 52",
    "hadis": "Zenginlik mal çokluğu değil, gönül zenginliğidir."
  },
  {
    "kaynak": "Müslim, Îmân, 93",
    "hadis": "Kalbinde zerre kadar kibir olan kimse cennete giremez."
  },
  {
    "kaynak": "Buhârî, Edeb, 27",
    "hadis": "Gerçek pehlivan, güreşte rakibini yenen değil, öfke anında kendine hâkim olandır."
  }
    ];

    // Yılın kaçıncı gününde olduğumuzu buluyoruz
    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final int kacinciGun = suAn.difference(yilinIlkGunu).inDays;

    // Modül işlemi ile sıradaki hadisi seçiyoruz
    final int hadisIndeksi = kacinciGun % hadisListesi.length;
    final Map<String, String> bugununHadisi = hadisListesi[hadisIndeksi];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        // Ayet kartından biraz farklı hissettirmesi için opacity (saydamlık) değerini biraz düşürdük
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5), 
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Icon(Icons.menu_book, color: Theme.of(context).colorScheme.secondary), // Kitap ikonu
                  const SizedBox(width: 8),
                  Text("Günün Hadisi", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.menu_book, color: Theme.of(context).colorScheme.secondary),
                  const Spacer(),
                  
                  // Paylaş Butonu
                  IconButton(
                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.secondary, size: 20),
                    tooltip: 'Hadisi Paylaş',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Share.share('"${bugununHadisi["hadis"]}"\n\n- ${bugununHadisi["kaynak"]}\n\nNamaz Vakitleri Uygulamasından paylaşıldı.');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '"${bugununHadisi["hadis"]}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                "- ${bugununHadisi["kaynak"]}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
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
//dnm
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
// --- YENİ: MİNİMALİST ZEN KIBLE PUSULASI ---
class KibleSayfasi extends StatefulWidget {
  const KibleSayfasi({super.key});

  @override
  State<KibleSayfasi> createState() => _KibleSayfasiState();
}

class _KibleSayfasiState extends State<KibleSayfasi> {
  double? _kibleAcisi;
  bool _konumAraniyor = true;
  bool _titrediMi = false; // Titreşimin sürekli tekrarlamasını engellemek için

  @override
  void initState() {
    super.initState();
    _kibleIcinKonumBul();
  }

  // Kıble açısını bulmak için kullanıcının anlık konumunu alıyoruz
  Future<void> _kibleIcinKonumBul() async {
    try {
      Position pozisyon = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _kibleAcisi = _kibleHesapla(pozisyon.latitude, pozisyon.longitude);
        _konumAraniyor = false;
      });
    } catch (e) {
      setState(() {
        _konumAraniyor = false;
      });
    }
  }

  // Dünyanın eğimini hesaba katan gerçek Kıble trigonometrisi
  double _kibleHesapla(double enlem, double boylam) {
    const double kabeEnlem = 21.422487;
    const double kabeBoylam = 39.826206;

    double enlemR = enlem * (math.pi / 180.0);
    double boylamR = boylam * (math.pi / 180.0);
    double kabeEnlemR = kabeEnlem * (math.pi / 180.0);
    double kabeBoylamR = kabeBoylam * (math.pi / 180.0);

    double y = math.sin(kabeBoylamR - boylamR) * math.cos(kabeEnlemR);
    double x = math.cos(enlemR) * math.sin(kabeEnlemR) -
        math.sin(enlemR) * math.cos(kabeEnlemR) * math.cos(kabeBoylamR - boylamR);

    double kibleRadyan = math.atan2(y, x);
    double kibleDerece = kibleRadyan * (180.0 / math.pi);

    return (kibleDerece + 360.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kıble', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), Colors.white],
          ),
        ),
        child: _konumAraniyor
            ? const Center(child: CircularProgressIndicator())
            : _kibleAcisi == null
                ? const Center(child: Text("Konum alınamadığı için Kıble hesaplanamıyor."))
                // Pusula sensöründen gelen veriyi anlık dinleyen StreamBuilder
                : StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Sensör hatası.'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      double? cihazAcisi = snapshot.data?.heading;
                      if (cihazAcisi == null) return const Center(child: Text("Cihazınızda pusula sensörü bulunamadı."));

                      // Cihazın baktığı yön ile Kabe arasındaki farkı bul
                      double fark = (_kibleAcisi! - cihazAcisi + 360) % 360;
                      // Kabe'ye dönük müyüz? (Hassasiyet: +- 3 derece)
                      bool kibleyiBulduMu = (fark < 3 || fark > 357);

                      // Kıbleyi bulunca tok bir titreşim ver
                      if (kibleyiBulduMu && !_titrediMi) {
                        HapticFeedback.heavyImpact();
                        _titrediMi = true;
                      } else if (!kibleyiBulduMu && _titrediMi) {
                        _titrediMi = false; // Yön bozulursa titreşim kilidini aç
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            kibleyiBulduMu ? "Kıble'desiniz" : "Kıbleyi Bulmak İçin Dönün",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kibleyiBulduMu ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Zen Çemberi Tasarımı
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Dış Halka (Sabit)
                              Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: kibleyiBulduMu 
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.5) 
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                              ),
                              
                              // Ortadaki Kabe İkonu (Sadece doğru yöndeyken görünür)
                              AnimatedOpacity(
                                opacity: kibleyiBulduMu ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 500),
                                child: Icon(Icons.mosque, size: 60, color: Theme.of(context).colorScheme.primary),
                              ),

                              // Dönen Pusula İbresi (Kıble Noktası)
                              AnimatedRotation(
                                turns: fark / 360, // Açıyı tur sayısına çevirir
                                duration: const Duration(milliseconds: 200), // Yağ gibi akan animasyon
                                child: Container(
                                  width: 250,
                                  height: 250,
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    width: kibleyiBulduMu ? 24 : 16,
                                    height: kibleyiBulduMu ? 24 : 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: kibleyiBulduMu ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                                      boxShadow: kibleyiBulduMu ? [
                                        BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.6), blurRadius: 15, spreadRadius: 5)
                                      ] : [],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}