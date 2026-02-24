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
import 'package:home_widget/home_widget.dart'; //widget için
import 'package:easy_localization/easy_localization.dart'; //yabancı dil desteği için

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
  
  // YENİ: Dil motorunu başlat
  await EasyLocalization.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  const AndroidInitializationSettings androidAyarlari = AndroidInitializationSettings('@mipmap/ic_launcher');
  const LinuxInitializationSettings linuxAyarlari = LinuxInitializationSettings(defaultActionName: 'Uygulamayı Aç');
  const InitializationSettings baslangicAyarlari = InitializationSettings(android: androidAyarlari, linux: linuxAyarlari);
  
  await bildirimServisi.initialize(settings: baslangicAyarlari);
  await temaRenginiYukle();

  // YENİ: Uygulamayı EasyLocalization sarmalayıcısı ile çalıştır
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')], // Desteklenen diller
      path: 'assets/translations', // JSON dosyalarının olduğu klasör
      fallbackLocale: const Locale('tr'), // Cihaz farklı bir dildeyse (örn: Almanca) varsayılan olarak Türkçe aç
      child: const NamazVakitleriApp(),
    ),
  );
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

          // YENİ: Dil delegasyonları ve ayarları
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

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
        items:  [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'times'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'special_days'.tr(),
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

Future<void> _widgetAyetiniGuncelle() async {
    String aktifDil = context.locale.languageCode;

    final List<Map<String, String>> ayetListesiTR = [
      {"sure": "Bakara Suresi, 152. Ayet", "meal": "Öyleyse yalnız beni anın ki ben de sizi anayım. Bana şükredin, sakın nankörlük etmeyin."},
      {"sure": "İnşirah Suresi, 5-6. Ayet", "meal": "Elbette zorluğun yanında bir kolaylık vardır. Gerçekten, zorlukla beraber bir kolaylık daha vardır."},
      {"sure": "Tâhâ Suresi, 46. Ayet", "meal": "Korkmayın! Çünkü ben sizinle beraberim; işitirim ve görürüm."},
      {"sure": "Zümer Suresi, 53. Ayet", "meal": "Ey kendi aleyhlerine haddi aşan kullarım! Allah'ın rahmetinden ümidinizi kesmeyin."},
      {"sure": "Rad Suresi, 28. Ayet", "meal": "Onlar, inananlar ve kalpleri Allah'ı anmakla huzura kavuşanlardır. Biliniz ki, kalpler ancak Allah'ı anmakla huzur bulur."}
    ];

    final List<Map<String, String>> ayetListesiEN = [
      {"sure": "Surah Al-Baqarah, 152", "meal": "So remember Me; I will remember you. And be grateful to Me and do not deny Me."},
      {"sure": "Surah Ash-Sharh, 5-6", "meal": "For indeed, with hardship [will be] ease. Indeed, with hardship [will be] ease."},
      {"sure": "Surah Taha, 46", "meal": "Fear not. Indeed, I am with you both; I hear and I see."},
      {"sure": "Surah Az-Zumar, 53", "meal": "O My servants who have transgressed against themselves [by sinning], do not despair of the mercy of Allah."},
      {"sure": "Surah Ar-Ra'd, 28", "meal": "Those who have believed and whose hearts are assured by the remembrance of Allah. Unquestionably, by the remembrance of Allah hearts are assured."}
    ];

    final List<Map<String, String>> aktifListe = (aktifDil == 'en') ? ayetListesiEN : ayetListesiTR;

    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final kacinciGun = suAn.difference(yilinIlkGunu).inDays;
    final secilenAyet = aktifListe[kacinciGun % aktifListe.length];

    // Gösterilecek tam metni hazırla
    String widgetMetni = '"${secilenAyet["meal"]}"\n\n- ${secilenAyet["sure"]}';
    // 2. Veriyi Android'in (Kotlin) okuyacağı o ortak hafızaya KAYDET!
    await HomeWidget.saveWidgetData<String>('kayitli_ayet', widgetMetni);
    // 3. Android'e "Hey! AyetWidget'ı yenile!" diye sinyal gönder
    await HomeWidget.updateWidget(name: 'AyetWidget');
  }

Future<void> _widgetHadisiniGuncelle() async {
    String aktifDil = context.locale.languageCode;

    final List<Map<String, String>> hadisListesiTR = [
      {"kaynak": "Buhârî, Îmân, 1", "hadis": "Ameller niyetlere göredir. Herkes sadece niyetinin karşılığını alır."},
      {"kaynak": "Müslim, Birr, 32", "hadis": "Kim bir müminin dünyevi sıkıntılarından birini giderirse, Allah da onun kıyamet günündeki sıkıntılarından birini giderir."},
      {"kaynak": "Tirmizî, Birr, 16", "hadis": "Sizin en hayırlınız, ahlâkı en güzel olanınızdır."},
      {"kaynak": "Ebû Dâvûd, Edeb, 60", "hadis": "İnsanlara merhamet etmeyene Allah merhamet etmez."},
      {"kaynak": "Buhârî, Rikak, 3", "hadis": "İki nimet vardır ki insanların çoğu bu konuda aldanmıştır: Sağlık ve boş vakit."},
      {"kaynak": "Buhârî, İlim, 10", "hadis": "Allah, kimin için hayır dilerse onu dinde derin anlayış sahibi kılar."},
      {"kaynak": "Müslim, Îmân, 71", "hadis": "Hiçbiriniz, kendisi için istediğini kardeşi için de istemedikçe (gerçek manada) iman etmiş olmaz."}
    ];

    final List<Map<String, String>> hadisListesiEN = [
      {"kaynak": "Sahih al-Bukhari, Belief, 1", "hadis": "Deeds are considered by their intentions, and a person will get the reward according to his intention."},
      {"kaynak": "Sahih Muslim, Piety, 32", "hadis": "Whoever relieves a believer of some worldly distress, Allah will relieve him of some of the distress of the Day of Resurrection."},
      {"kaynak": "Jami` at-Tirmidhi, Righteousness, 16", "hadis": "The best among you are those who have the best manners and character."},
      {"kaynak": "Sunan Abi Dawud, General Behavior, 60", "hadis": "He who does not show mercy to people, Allah will not show mercy to him."},
      {"kaynak": "Sahih al-Bukhari, Softening of the Hearts, 3", "hadis": "There are two blessings which many people lose: health and free time."},
      {"kaynak": "Sahih al-Bukhari, Knowledge, 10", "hadis": "If Allah wants to do good to a person, He makes him comprehend the religion."},
      {"kaynak": "Sahih Muslim, Faith, 71", "hadis": "None of you truly believes until he loves for his brother what he loves for himself."}
    ];

    final List<Map<String, String>> aktifListe = (aktifDil == 'en') ? hadisListesiEN : hadisListesiTR;

    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final kacinciGun = suAn.difference(yilinIlkGunu).inDays;
    final secilenHadis = aktifListe[kacinciGun % aktifListe.length];

    String widgetMetni = '"${secilenHadis["hadis"]}"\n\n- ${secilenHadis["kaynak"]}';

    await HomeWidget.saveWidgetData<String>('kayitli_hadis', widgetMetni);
    await HomeWidget.updateWidget(name: 'HadisWidget');
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

        //Widget için
        _widgetAyetiniGuncelle();
        _widgetHadisiniGuncelle();
        
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

    // YENİ EKLENEN: Vakit değiştiyse Ana Ekran Widget'ına yeni vakti gönder
    HomeWidget.saveWidgetData<String>('kayitli_vakit_ad', siradakiVakitAd);
    
    // API'den "16:35" olan formatı bulup gönderiyoruz
    String siradakiVakitSaati = vakitListesi[siradakiVakitAd] ?? vakitler!['Fajr'];
    HomeWidget.saveWidgetData<String>('kayitli_vakit_saat', siradakiVakitSaati);
    
    HomeWidget.updateWidget(name: 'VakitWidget');
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
    // 1. O anki aktif dili buluyoruz ('tr' veya 'en')
    String aktifDil = context.locale.languageCode;

    // --- TÜRKÇE AYET HAVUZU ---
    final List<Map<String, String>> ayetListesiTR = [
      {"sure": "Bakara Suresi, 152. Ayet", "meal": "Öyleyse yalnız beni anın ki ben de sizi anayım. Bana şükredin, sakın nankörlük etmeyin."},
      {"sure": "İnşirah Suresi, 5-6. Ayet", "meal": "Elbette zorluğun yanında bir kolaylık vardır. Gerçekten, zorlukla beraber bir kolaylık daha vardır."},
      {"sure": "Tâhâ Suresi, 46. Ayet", "meal": "Korkmayın! Çünkü ben sizinle beraberim; işitirim ve görürüm."},
      {"sure": "Zümer Suresi, 53. Ayet", "meal": "Ey kendi aleyhlerine haddi aşan kullarım! Allah'ın rahmetinden ümidinizi kesmeyin."},
      {"sure": "Rad Suresi, 28. Ayet", "meal": "Onlar, inananlar ve kalpleri Allah'ı anmakla huzura kavuşanlardır. Biliniz ki, kalpler ancak Allah'ı anmakla huzur bulur."}
    ];

    // --- İNGİLİZCE AYET HAVUZU (Senin İngilizce pratik alanın!) ---
    final List<Map<String, String>> ayetListesiEN = [
      {"sure": "Surah Al-Baqarah, 152", "meal": "So remember Me; I will remember you. And be grateful to Me and do not deny Me."},
      {"sure": "Surah Ash-Sharh, 5-6", "meal": "For indeed, with hardship [will be] ease. Indeed, with hardship [will be] ease."},
      {"sure": "Surah Taha, 46", "meal": "Fear not. Indeed, I am with you both; I hear and I see."},
      {"sure": "Surah Az-Zumar, 53", "meal": "O My servants who have transgressed against themselves [by sinning], do not despair of the mercy of Allah."},
      {"sure": "Surah Ar-Ra'd, 28", "meal": "Those who have believed and whose hearts are assured by the remembrance of Allah. Unquestionably, by the remembrance of Allah hearts are assured."}
    ];

    // 2. Dile göre doğru listeyi seç
    final List<Map<String, String>> aktifListe = (aktifDil == 'en') ? ayetListesiEN : ayetListesiTR;

    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final int kacinciGun = suAn.difference(yilinIlkGunu).inDays;

    final int ayetIndeksi = kacinciGun % aktifListe.length;
    final Map<String, String> bugununAyeti = aktifListe[ayetIndeksi];

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
                  const Spacer(), 
                  Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  // JSON'DAN BAŞLIĞI ÇEKİYORUZ
                  Text("ayah_of_the_day".tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
                  const Spacer(), 
                  
                  IconButton(
                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary, size: 20),
                    tooltip: 'Paylaş',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Share.share('"${bugununAyeti["meal"]}"\n\n- ${bugununAyeti["sure"]}\n\n${"app_name".tr()}');
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
    // 1. O anki aktif dili buluyoruz
    String aktifDil = context.locale.languageCode;

    // --- TÜRKÇE HADİS HAVUZU ---
    final List<Map<String, String>> hadisListesiTR = [
      {"kaynak": "Buhârî, Îmân, 1", "hadis": "Ameller niyetlere göredir. Herkes sadece niyetinin karşılığını alır."},
      {"kaynak": "Müslim, Birr, 32", "hadis": "Kim bir müminin dünyevi sıkıntılarından birini giderirse, Allah da onun kıyamet günündeki sıkıntılarından birini giderir."},
      {"kaynak": "Tirmizî, Birr, 16", "hadis": "Sizin en hayırlınız, ahlâkı en güzel olanınızdır."},
      {"kaynak": "Ebû Dâvûd, Edeb, 60", "hadis": "İnsanlara merhamet etmeyene Allah merhamet etmez."},
      {"kaynak": "Buhârî, Rikak, 3", "hadis": "İki nimet vardır ki insanların çoğu bu konuda aldanmıştır: Sağlık ve boş vakit."},
      {"kaynak": "Buhârî, İlim, 10", "hadis": "Allah, kimin için hayır dilerse onu dinde derin anlayış sahibi kılar."},
      {"kaynak": "Müslim, Îmân, 71", "hadis": "Hiçbiriniz, kendisi için istediğini kardeşi için de istemedikçe (gerçek manada) iman etmiş olmaz."}
    ];

    // --- İNGİLİZCE HADİS HAVUZU ---
    final List<Map<String, String>> hadisListesiEN = [
      {"kaynak": "Sahih al-Bukhari, Belief, 1", "hadis": "Deeds are considered by their intentions, and a person will get the reward according to his intention."},
      {"kaynak": "Sahih Muslim, Piety, 32", "hadis": "Whoever relieves a believer of some worldly distress, Allah will relieve him of some of the distress of the Day of Resurrection."},
      {"kaynak": "Jami` at-Tirmidhi, Righteousness, 16", "hadis": "The best among you are those who have the best manners and character."},
      {"kaynak": "Sunan Abi Dawud, General Behavior, 60", "hadis": "He who does not show mercy to people, Allah will not show mercy to him."},
      {"kaynak": "Sahih al-Bukhari, Softening of the Hearts, 3", "hadis": "There are two blessings which many people lose: health and free time."},
      {"kaynak": "Sahih al-Bukhari, Knowledge, 10", "hadis": "If Allah wants to do good to a person, He makes him comprehend the religion."},
      {"kaynak": "Sahih Muslim, Faith, 71", "hadis": "None of you truly believes until he loves for his brother what he loves for himself."}
    ];

    // 2. Dile göre doğru listeyi seç
    final List<Map<String, String>> aktifListe = (aktifDil == 'en') ? hadisListesiEN : hadisListesiTR;

    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final int kacinciGun = suAn.difference(yilinIlkGunu).inDays;

    final int hadisIndeksi = kacinciGun % aktifListe.length;
    final Map<String, String> bugununHadisi = aktifListe[hadisIndeksi];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
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
                  Icon(Icons.menu_book, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  // JSON'DAN BAŞLIĞI ÇEKİYORUZ
                  Text("hadith_of_the_day".tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.menu_book, color: Theme.of(context).colorScheme.secondary),
                  const Spacer(),
                  
                  IconButton(
                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.secondary, size: 20),
                    tooltip: 'Paylaş',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Share.share('"${bugununHadisi["hadis"]}"\n\n- ${bugununHadisi["kaynak"]}\n\n${"app_name".tr()}');
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

// --- ÖZEL GÜNLER SAYFASI (GÜNCELLENDİ: 2026 Tarihleri ve Dil Desteği) ---
class OzelGunlerSayfasi extends StatelessWidget {
  const OzelGunlerSayfasi({super.key});

  // API'ye dil parametresi (aktifDil) gönderiyormuşuz gibi düşünüyoruz
  Future<List<DiniGun>> _ozelGunleriGetirAPI(String aktifDil) async {
    await Future.delayed(const Duration(seconds: 1));

    // --- TÜRKÇE (2026 YILI KESİNLEŞMİŞ DİYANET TAKVİMİ) ---
    String sahteJsonResponseTR = '''
    [
      {
        "isim": "Miraç Kandili", 
        "tarih": "15 Ocak 2026", 
        "hicriTarih": "26 Recep 1447",
        "aciklama": "Peygamber Efendimiz'in (s.a.v) Mescid-i Haram'dan Mescid-i Aksa'ya, oradan da göğe yükseldiği mucizevi gecedir.", 
        "ikon": "auto_awesome"
      },
      {
        "isim": "Berat Kandili", 
        "tarih": "2 Şubat 2026", 
        "hicriTarih": "14 Şaban 1447",
        "aciklama": "Günahlardan arınma, af, şefaat ve mağfiret gecesidir.", 
        "ikon": "nightlight_round"
      },
      {
        "isim": "Ramazan Başlangıcı", 
        "tarih": "19 Şubat 2026", 
        "hicriTarih": "1 Ramazan 1447",
        "aciklama": "On bir ayın sultanı, oruç ibadetinin yerine getirildiği mübarek aydır.", 
        "ikon": "brightness_3"
      },
      {
        "isim": "Kadir Gecesi", 
        "tarih": "16 Mart 2026", 
        "hicriTarih": "27 Ramazan 1447",
        "aciklama": "Kur'an-ı Kerim'in indirildiği, bin aydan daha hayırlı olan gecedir.", 
        "ikon": "star"
      },
      {
        "isim": "Ramazan Bayramı", 
        "tarih": "20 Mart 2026", 
        "hicriTarih": "1 Şevval 1447",
        "aciklama": "Oruç ibadetinin ardından Müslümanların sevincini paylaştığı günlerdir.", 
        "ikon": "celebration"
      },
      {
        "isim": "Kurban Bayramı", 
        "tarih": "27 Mayıs 2026", 
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
        "tarih": "24 Ağustos 2026", 
        "hicriTarih": "11 Rebiülevvel 1448",
        "aciklama": "Alemlere rahmet olarak gönderilen Peygamber Efendimiz'in (s.a.v) dünyaya teşrif ettiği gecedir.", 
        "ikon": "menu_book"
      }
    ]
    ''';

    // --- İNGİLİZCE (2026 YILI DİNİ GÜNLERİ) ---
    String sahteJsonResponseEN = '''
    [
      {
        "isim": "Al-Isra wal-Mi'raj", 
        "tarih": "15 January 2026", 
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "The miraculous night journey and ascension of Prophet Muhammad (PBUH) to the heavens.", 
        "ikon": "auto_awesome"
      },
      {
        "isim": "Mid-Sha'ban (Berat)", 
        "tarih": "2 February 2026", 
        "hicriTarih": "14 Sha'ban 1447",
        "aciklama": "The night of forgiveness, mercy, and intercession.", 
        "ikon": "nightlight_round"
      },
      {
        "isim": "Start of Ramadan", 
        "tarih": "19 February 2026", 
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "The sultan of eleven months, the blessed month of fasting.", 
        "ikon": "brightness_3"
      },
      {
        "isim": "Laylat al-Qadr", 
        "tarih": "16 March 2026", 
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "The Night of Decree, when the Quran was revealed, better than a thousand months.", 
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr", 
        "tarih": "20 March 2026", 
        "hicriTarih": "1 Shawwal 1447",
        "aciklama": "The festival of breaking the fast, where Muslims share their joy after a month of fasting.", 
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha", 
        "tarih": "27 May 2026", 
        "hicriTarih": "10 Dhu al-Hijjah 1447",
        "aciklama": "The festival of sacrifice, marking the peak of solidarity and the Hajj pilgrimage.", 
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Islamic New Year", 
        "tarih": "16 June 2026", 
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "The first day of the Hijri calendar, based on the Prophet's migration to Medina.", 
        "ikon": "event"
      },
      {
        "isim": "Day of Ashura", 
        "tarih": "25 June 2026", 
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "A day of blessings and sharing, marking significant events in the lives of the Prophets.", 
        "ikon": "local_dining"
      },
      {
        "isim": "Mawlid al-Nabi", 
        "tarih": "24 August 2026", 
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "The night celebrating the birth of Prophet Muhammad (PBUH), sent as a mercy to the worlds.", 
        "ikon": "menu_book"
      }
    ]
    ''';

    // Telefonun diline göre doğru JSON tablosunu seçiyoruz
    String seciliJson = (aktifDil == 'en') ? sahteJsonResponseEN : sahteJsonResponseTR;

    List<dynamic> cozulmusJson = json.decode(seciliJson);
    return cozulmusJson.map((jsonElemani) => DiniGun.fromJson(jsonElemani)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Telefonun o anki dilini al ('tr' veya 'en')
    String aktifDil = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        // JSON'daki special_days anahtarını kullanıyoruz (Yoksa doğrudan tr() fonksiyonuna yönlendiririz)
        title: Text('special_days'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        child: FutureBuilder<List<DiniGun>>(
          // Fonksiyonumuza dili parametre olarak gönderiyoruz
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

  // --- KART TASARIMI ---
  Widget _gunKarti(BuildContext context, String isim, String tarih, String hicriTarih, IconData ikon, String aciklama, String aktifDil) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(ikon, color: Theme.of(context).colorScheme.primary, size: 32),
        title: Text(isim, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4), 
            Text(tarih, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            Text(hicriTarih, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _altPanelAc(context, isim, tarih, hicriTarih, aciklama, ikon, aktifDil),
      ),
    );
  }

  // --- DETAY PANELİ TASARIMI ---
  void _altPanelAc(BuildContext context, String isim, String tarih, String hicriTarih, String aciklama, IconData ikon, String aktifDil) {
    // Dile göre buton yazısını ayarlıyoruz
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
// --- YENİ: YÖN OKLU VE KABE SİMGELİ KIBLE PUSULASI ---
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
        _kibleAcisi = _kibleHesapla(pozisyon.latitude, pozisyon.longitude);
        _konumAraniyor = false;
      });
    } catch (e) {
      setState(() {
        _konumAraniyor = false;
      });
    }
  }

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

  // YENİ: Kodla çizdiğimiz tatlı ve şık Kabe Simgesi
  Widget _kabeSimgesi() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black, // Kabe'nin örtüsü
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(height: 4, color: Colors.amber), // Kabe'nin altın sarısı şeridi
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
                : StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Sensör hatası.'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      double? cihazAcisi = snapshot.data?.heading;
                      if (cihazAcisi == null) return const Center(child: Text("Cihazınızda pusula sensörü bulunamadı."));

                      // Kabe ile aramızdaki açı farkı
                      double fark = (_kibleAcisi! - cihazAcisi + 360) % 360;
                      // Hassasiyet: +- 3 derece
                      bool kibleyiBulduMu = (fark < 3 || fark > 357);

                      if (kibleyiBulduMu && !_titrediMi) {
                        HapticFeedback.vibrate(); // Telefonda %100 çalışan klasik titreşim
                        _titrediMi = true;
                      } else if (!kibleyiBulduMu && _titrediMi) {
                        _titrediMi = false;
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            kibleyiBulduMu ? "Kıble'desiniz" : "Kıbleyi Bulmak İçin Dönün",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kibleyiBulduMu ? Colors.green.shade600 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // SABİT HEDEF OKU (Yeşil ışık yanacak kısım)
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

                          // DÖNEN PUSULA KADRANI
                          // Transform.rotate kullanarak 359'dan 0'a geçerken çıldırmasını önlüyoruz
                          Transform.rotate(
                            angle: -cihazAcisi * (math.pi / 180),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pusulanın Dış Çerçevesi
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
                                
                                // İç Çapraz Çizgiler (Çok hafif opaklıkta)
                                Container(width: 1, height: 260, color: Colors.grey.shade300),
                                Container(width: 260, height: 1, color: Colors.grey.shade300),

                                // Yön Harfleri (Kuzey, Güney, Doğu, Batı)
                                Positioned(top: 10, child: Text("K", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red.shade700))),
                                Positioned(bottom: 10, child: Text("G", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700))),
                                Positioned(right: 15, child: Text("D", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700))),
                                Positioned(left: 15, child: Text("B", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade700))),

                                // KABE SİMGESİ (Pusula üzerinde doğru açıya sabitlenir ve pusulayla döner)
                                Transform.rotate(
                                  angle: _kibleAcisi! * (math.pi / 180),
                                  child: Container(
                                    width: 280,
                                    height: 280,
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 25), // Kabe'yi çizgiye yaklaştırır
                                      child: _kabeSimgesi(), // Yazdığımız özel Kabe widget'ı
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