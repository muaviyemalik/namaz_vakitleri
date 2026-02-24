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

// --- GLOBAL DEĞİŞKENLER (Tema ve Bildirim Motoru) ---
final ValueNotifier<Color> seciliTemaRengi = ValueNotifier<Color>(Colors.teal);
final FlutterLocalNotificationsPlugin bildirimServisi = FlutterLocalNotificationsPlugin();

Future<void> temaRenginiKaydet(Color renk) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setInt('kayitli_tema_rengi', renk.value);
}

Future<void> temaRenginiYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  final int? renkKodu = hafiza.getInt('kayitli_tema_rengi');
  if (renkKodu != null) {
    seciliTemaRengi.value = Color(renkKodu);
  }
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
    return ValueListenableBuilder<Color>(
      valueListenable: seciliTemaRengi,
      builder: (context, aktifRenk, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: 'Namaz Vakitleri',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: aktifRenk, brightness: Brightness.light),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 4, 
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          home: const AnaMenu(), 
        );
      },
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
        ],
      ),
    );
  }
}