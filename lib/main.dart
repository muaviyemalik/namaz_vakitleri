// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:easy_localization/easy_localization.dart';

// --- SAYFALARIMIZ ---
import 'pages/anasayfa.dart';
import 'pages/ozelGunler_sayfasi.dart';
import 'pages/kible_sayfasi.dart';
import 'pages/ayarlar_sayfasi.dart';

// --- GLOBAL DEĞİŞKENLER (Tema ve Bildirim Motoru) ---
final ValueNotifier<Color> seciliTemaRengiAydinlik = ValueNotifier<Color>(Colors.teal); // Gündüz rengi
final ValueNotifier<Color> seciliTemaRengiKaranlik = ValueNotifier<Color>(Colors.indigo); // Gece rengi
final ValueNotifier<ThemeMode> aktifTemaModu = ValueNotifier<ThemeMode>(ThemeMode.light);
final FlutterLocalNotificationsPlugin bildirimServisi = FlutterLocalNotificationsPlugin();
//Erken Uyarı Sistemi için
final ValueNotifier<int> erkenUyariSuresi = ValueNotifier<int>(0);

// YENİ: Erken Uyarı Süresini Kaydetme
Future<void> erkenUyariKaydet(int dakika) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setInt('kayitli_erken_uyari', dakika);
}

// YENİ: Erken Uyarı Süresini Yükleme
Future<void> erkenUyariYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  final int? kayitliDakika = hafiza.getInt('kayitli_erken_uyari');
  if (kayitliDakika != null) {
    erkenUyariSuresi.value = kayitliDakika;
  }
}

Future<void> temaModunuKaydet(bool isDark) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setBool('karanlik_mod', isDark);
}
Future<void> temaModunuYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  final bool? isDark = hafiza.getBool('karanlik_mod');
  if (isDark != null && isDark) {
    aktifTemaModu.value = ThemeMode.dark;
  } else {
    aktifTemaModu.value = ThemeMode.light;
  }
}
//Tema rengini kaydetme (hangi moddaysa onun rengini kaydeder)
Future<void> temaRenginiKaydet(Color renk, bool karanlikMi) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  if (karanlikMi) {
    await hafiza.setInt('kayitli_tema_rengi_karanlik', renk.value);
  } else {
    await hafiza.setInt('kayitli_tema_rengi_aydinlik', renk.value);
  }
}

// YENİ: Hem gece hem gündüz renklerini yükler
Future<void> temaRenginiYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  final int? renkKoduAydinlik = hafiza.getInt('kayitli_tema_rengi_aydinlik');
  final int? renkKoduKaranlik = hafiza.getInt('kayitli_tema_rengi_karanlik');

  if (renkKoduAydinlik != null) seciliTemaRengiAydinlik.value = Color(renkKoduAydinlik);
  if (renkKoduKaranlik != null) seciliTemaRengiKaranlik.value = Color(renkKoduKaranlik);
}

// --- BAŞLANGIÇ NOKTASI ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  const AndroidInitializationSettings androidAyarlari = AndroidInitializationSettings('@mipmap/ic_launcher');
  const LinuxInitializationSettings linuxAyarlari = LinuxInitializationSettings(defaultActionName: 'Uygulamayı Aç');
  const InitializationSettings baslangicAyarlari = InitializationSettings(android: androidAyarlari, linux: linuxAyarlari);
  
  await bildirimServisi.initialize(settings: baslangicAyarlari);
  await temaRenginiYukle();
  await temaModunuYukle();
  await erkenUyariYukle();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('zh')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: const NamazVakitleriApp(),
    ),
  );
}

class NamazVakitleriApp extends StatelessWidget {
  const NamazVakitleriApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 3 Katmanlı Dinleyici: Mod, Aydınlık Renk, Karanlık Renk
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: aktifTemaModu,
      builder: (context, aktifMod, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: seciliTemaRengiAydinlik,
          builder: (context, aydinlikRenk, child) {
            return ValueListenableBuilder<Color>(
              valueListenable: seciliTemaRengiKaranlik,
              builder: (context, karanlikRenk, child) {
                
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  title: 'Namaz Vakitleri',
                  themeMode: aktifMod, 
                  
                  // GÜNDÜZ TEMASI (Aydınlık Renk Besleniyor)
                  theme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(seedColor: aydinlikRenk, brightness: Brightness.light),
                    useMaterial3: true,
                    cardTheme: CardThemeData(elevation: 4, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  
                  // GECE TEMASI (Karanlık Renk Besleniyor)
                  darkTheme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(seedColor: karanlikRenk, brightness: Brightness.dark),
                    useMaterial3: true,
                    cardTheme: CardThemeData(elevation: 4, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  home: const AnaMenu(), 
                );
              }
            );
          }
        );
      }
    );
  }
}

// --- ALT MENÜ YÖNETİCİSİ ---
class AnaMenu extends StatefulWidget {
  const AnaMenu({super.key});

  @override
  State<AnaMenu> createState() => _AnaMenuState();
}

class _AnaMenuState extends State<AnaMenu> {
  int _seciliSayfaIndeksi = 0;

  final List<Widget> _sayfalar = [
    const AnaSayfa(), 
    const OzelGunlerSayfasi(), 
    const KibleSayfasi(), 
    const AyarlarSayfasi()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _seciliSayfaIndeksi,
        children: _sayfalar,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSayfaIndeksi,
        onTap: (index) {
          setState(() {
            _seciliSayfaIndeksi = index; 
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.access_time),
            label: 'times'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event),
            label: 'special_days'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore),
            label: 'qibla'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'settings'.tr(),
          ),
        ],
      ),
    );
  }
}