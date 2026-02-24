// lib/pages/ana_sayfa.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:share_plus/share_plus.dart';
import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart';

import '../data/veri_havuzu.dart';
import '../main.dart';

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


    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('select_city'.tr()),
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
                child: Text('cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, seciliDeger),
                child: Text('ok'.tr()),
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
    if (Platform.isAndroid || Platform.isIOS) {
    String aktifDil = context.locale.languageCode;

    final List<Map<String, String>> aktifListe = VeriHavuzu.ayetleriGetir(aktifDil);  

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
}

Future<void> _widgetHadisiniGuncelle() async {
  if (Platform.isAndroid || Platform.isIOS) {
    String aktifDil = context.locale.languageCode;

    final List<Map<String, String>> aktifListe = VeriHavuzu.hadisleriGetir(aktifDil);

    final suAn = DateTime.now();
    final yilinIlkGunu = DateTime(suAn.year, 1, 1);
    final kacinciGun = suAn.difference(yilinIlkGunu).inDays;
    final secilenHadis = aktifListe[kacinciGun % aktifListe.length];

    String widgetMetni = '"${secilenHadis["hadis"]}"\n\n- ${secilenHadis["kaynak"]}';

    await HomeWidget.saveWidgetData<String>('kayitli_hadis', widgetMetni);
    await HomeWidget.updateWidget(name: 'HadisWidget');
  }
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
        _konumHatasiBildir('loc_service_off'.tr());
        return;
      }

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
        if (izin == LocationPermission.denied) {
          _konumHatasiBildir('loc_perm_denied'.tr());
          return;
        }
      }

      if (izin == LocationPermission.deniedForever) {
        _konumHatasiBildir('loc_perm_forever'.tr());
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
        _konumHatasiBildir('city_not_found'.tr());
      }

    } catch (e) {
      debugPrint("Konum hatası: $e");
      // Linux DBus veya diğer hatalarda ekranı bozmadan uyarı ver
      _konumHatasiBildir('loc_error'.tr());
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
    if (Platform.isAndroid || Platform.isIOS) {
    if (vakitler == null) return;

    await bildirimServisi.cancelAll(); // Eski alarmları temizle
    final suAn = DateTime.now();

    Map<String, String> vakitListesi = {
        'fajr': vakitler!['Fajr'], 'sunrise': vakitler!['Sunrise'], 'dhuhr': vakitler!['Dhuhr'],
        'asr': vakitler!['Asr'], 'maghrib': vakitler!['Maghrib'], 'isha': vakitler!['Isha'],
      };

    int id = 0;
    vakitListesi.forEach((vakitAdi, saatMetni) async {
      List<String> saatDakika = saatMetni.split(':');
      DateTime vakitZamani = DateTime(suAn.year, suAn.month, suAn.day, int.parse(saatDakika[0]), int.parse(saatDakika[1]));

      if (vakitZamani.isAfter(suAn)) {
        await _tekilAlarmKur(id, vakitAdi.tr(), vakitZamani);
      }
      id++; 
    });
  }
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
      'fajr': vakitler!['Fajr'], 'sunrise': vakitler!['Sunrise'], 'dhuhr': vakitler!['Dhuhr'],
      'asr': vakitler!['Asr'], 'maghrib': vakitler!['Maghrib'], 'isha': vakitler!['Isha'],
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

    if (Platform.isAndroid || Platform.isIOS) {
      HomeWidget.saveWidgetData<String>('kayitli_vakit_ad', siradakiVakitAd);
      
      String siradakiVakitSaati = vakitListesi[siradakiVakitAd] ?? vakitler!['Fajr'];
      // YENİ EKLENEN: Vakit değiştiyse Ana Ekran Widget'ına yeni vakti gönder
      HomeWidget.saveWidgetData<String>('kayitli_vakit_saat', siradakiVakitSaati);
      HomeWidget.updateWidget(name: 'VakitWidget');
  }
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
            tooltip: 'find_location'.tr(),
            onPressed: () {
              // Tıklandığında yazdığımız motoru çalıştırır
              _otomatikKonumBul();
            },
          ),
          // Şehir Değiştirme Butonu
          IconButton(
            icon: const Icon(Icons.location_city),
            tooltip: 'select_city'.tr(),
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
                      content: Text("no_internet_city".tr(args: [yeniSehir])),
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
            icon: const Icon(Icons.palette), 
            tooltip: 'select_theme'.tr(),
            onSelected: (Color yeniRenk) {
              // O anki temanın ne olduğunu bul
              bool karanlikMi = Theme.of(context).brightness == Brightness.dark;
              
              // Seçimi ona göre global değişkene yaz ve kaydet
              if (karanlikMi) {
                seciliTemaRengiKaranlik.value = yeniRenk;
              } else {
                seciliTemaRengiAydinlik.value = yeniRenk;
              }
              temaRenginiKaydet(yeniRenk, karanlikMi); 
            },
            // Menüyü de anlık temaya göre çiziyoruz!
            itemBuilder: (BuildContext context) => Theme.of(context).brightness == Brightness.dark
              ? <PopupMenuEntry<Color>>[
                  // KARANLIK MOD RENKLERİ
                  PopupMenuItem<Color>(value: Colors.indigo, child: Text('theme_dark_indigo'.tr())),
                  PopupMenuItem<Color>(value: Colors.red.shade900, child: Text('theme_dark_crimson'.tr())),
                  PopupMenuItem<Color>(value: Colors.green.shade900, child: Text('theme_dark_emerald'.tr())),
                  PopupMenuItem<Color>(value: Colors.amber.shade700, child: Text('theme_dark_amber'.tr())),
                  PopupMenuItem<Color>(value: Colors.deepPurple.shade900, child: Text('theme_dark_violet'.tr())),
                ]
              : <PopupMenuEntry<Color>>[
                  // AYDINLIK MOD RENKLERİ
                  PopupMenuItem<Color>(value: Colors.teal, child: Text('theme_teal'.tr())),
                  PopupMenuItem<Color>(value: Colors.blue, child: Text('theme_blue'.tr())),
                  PopupMenuItem<Color>(value: Colors.deepPurple, child: Text('theme_purple'.tr())),
                  PopupMenuItem<Color>(value: Colors.orange, child: Text('theme_orange'.tr())),
                  PopupMenuItem<Color>(value: Colors.brown, child: Text('theme_brown'.tr())),
                  PopupMenuItem<Color>(value: const Color.fromARGB(255, 248, 108, 204), child: Text('theme_pink'.tr())),
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
                            // YENİ: "Bugünün Vakitleri" yazısını çevirdik
                            child: Text("today_times".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
                          ),
                        ),
                        
                        // YENİ: Kart isimlerini .tr() ile çeviriyoruz.
                        // siradakiVakitIsmi artık "fajr" gibi döneceği için kıyaslamayı da ona göre yapıyoruz:
                        _vakitKarti('fajr'.tr(), vakitler!['Fajr'], Icons.nights_stay, siradakiVakitIsmi == 'fajr'),
                        _vakitKarti('sunrise'.tr(), vakitler!['Sunrise'], Icons.wb_sunny_outlined, siradakiVakitIsmi == 'sunrise'),
                        _vakitKarti('dhuhr'.tr(), vakitler!['Dhuhr'], Icons.wb_sunny, siradakiVakitIsmi == 'dhuhr'),
                        _vakitKarti('asr'.tr(), vakitler!['Asr'], Icons.wb_twilight, siradakiVakitIsmi == 'asr'),
                        _vakitKarti('maghrib'.tr(), vakitler!['Maghrib'], Icons.nightlight_round, siradakiVakitIsmi == 'maghrib'),
                        _vakitKarti('isha'.tr(), vakitler!['Isha'], Icons.bedtime, siradakiVakitIsmi == 'isha'),
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
              Text('${siradakiVakitIsmi.tr()} ${"time_remaining".tr()}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
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
    String aktifDil = context.locale.languageCode;

    // YENİ: Bütün o kalabalık listeler yerine sadece VeriHavuzu'nu çağırıyoruz!
    final List<Map<String, String>> aktifListe = VeriHavuzu.ayetleriGetir(aktifDil);

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
                    tooltip: 'share'.tr(),
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
    //Veri havuzundan hadisleri çekiyoruz
    final List<Map<String, String>> aktifListe = VeriHavuzu.hadisleriGetir(aktifDil);

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
                    tooltip: 'share'.tr(),
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
// 4. DURUMU DEĞİŞEBİLEN EKRAN (StatefulWidget)
// API'den veri gelince ve sayaç her saniye aktığında ekranın güncellenmesi gerektiği için bunu kullanıyoruz.
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}