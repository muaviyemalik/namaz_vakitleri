// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:easy_localization/easy_localization.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';
import 'package:namaz_vakitleri/utils/iso1_yerellestirme.dart';

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

// --- KONUM (ÜLKE / ŞEHİR) DURUMU ---
// Seçilen ülkenin ISO 3166-1 alpha-2 kodu (örn. "TR"). Varsayılan Türkiye.
final ValueNotifier<String> aktifUlkeKodu = ValueNotifier<String>('TR');

// Seçilen şehir. Aladhan sorgusu bu koordinatlarla yapılır; şehir adıyla
// sorgulayan calendarByCity uç noktası küçük şehirleri çözemediği için
// (HTTP 503 "Geocoding is temporarily unavailable") koordinat tercih
// edilmiştir. Ayrıca meta.timezone doğru geldiği için saat dilimi
// kaymaları da önlenir.
final ValueNotifier<Sehir?> aktifSehir = ValueNotifier<Sehir?>(null);

const String kayitliUlkeAnahtari = 'secili_ulke_kodu';
const String kayitliSehirAnahtari = 'secili_sehir_veri';
const String kayitliYontemAnahtari = 'secili_hesaplama_yontemi';

// Seçilen hesaplama yöntemi (Aladhan "method" parametresi).
//
// null = OTOMATİK. Bu durumda parametre API'ye hiç gönderilmez ve Aladhan
// ülkeye göre doğru varsayılanı kendisi seçer (TR→Diyanet, US→ISNA,
// EG→Mısır, SA→Umm al-Qura, FR→UOIF, TN→Tunus, ID→KEMENAG, MY→JAKIM).
//
// Neden otomatik varsayılan? Hesaplama yöntemi vakitleri kaydırır. Ölçülen
// fark: method=13 (Türkiye) her ülkede sabit kullanıldığında Paris'te Fajr
// 38 dakika, New York'ta 16 dakika, Suudi Arabistan'da İşâ 19 dakika kadar
// sapıyor. 245 ülkeyi elle eşleştirmek hem hataya açık hem sürdürülemezdi.
//
// Kullanıcı Ayarlar menüsünden yöntemi değiştirebilir. Bu gereklidir çünkü
// "doğru" yöntem ülkeye göre değil, kullanıcının takip ettiği camiye ve
// mezhebe göre değişir; bunu yalnızca kullanıcı bilir.
final ValueNotifier<int?> aktifHesaplamaYontemi = ValueNotifier<int?>(null);

Future<void> hesaplamaYontemiKaydet(int? yontemId) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  if (yontemId == null) {
    await hafiza.remove(kayitliYontemAnahtari);
  } else {
    await hafiza.setInt(kayitliYontemAnahtari, yontemId);
  }
}

// Seçilen şehri cihazda saklar (ad + koordinat).
Future<void> sehirKaydet(Sehir sehir) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setString(
      kayitliSehirAnahtari, '${sehir.ad}|${sehir.enlem}|${sehir.boylam}');
}

Future<void> ulkeKaydet(String iso2) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setString(kayitliUlkeAnahtari, iso2);
}

/// Yeni şehir seçildiğinde çağrılır: state'i günceller ve cihaza kaydeder.
///
/// Vakitlerin yenilenmesi burada yapılmaz; ana sayfa `aktifSehir`
/// notifier'ını dinlediği için tetiklenir. Böylece hem ayarlar sayfasından
/// hem ana sayfadaki şehir seçiciden yapılan değişiklikler aynı yoldan geçer
/// ve vakit çekme mantığı tek yerde kalır.
Future<void> sehirAyarla(Sehir sehir) async {
  final mevcut = aktifSehir.value;
  if (mevcut != null && mevcut.ad == sehir.ad && mevcut.enlem == sehir.enlem) {
    return; // Değişiklik yok, gereksiz istek atma.
  }
  aktifSehir.value = sehir;
  await sehirKaydet(sehir);
}

// Kayıtlı ülke ve şehri cihazdan okur. Konum bulunamazsa Türkiye/Ankara
// varsayılanına düşer.
Future<void> konumYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();

  final String? ulke = hafiza.getString(kayitliUlkeAnahtari);
  if (ulke != null && ulke.length == 2) aktifUlkeKodu.value = ulke;

  // Hesaplama yöntemi: kayıt yoksa otomatik (null) kullanılır.
  aktifHesaplamaYontemi.value = hafiza.getInt(kayitliYontemAnahtari);

  final String? sehirHam = hafiza.getString(kayitliSehirAnahtari);
  if (sehirHam != null) {
    final parca = sehirHam.split('|');
    if (parca.length == 3) {
      final enlem = double.tryParse(parca[1]);
      final boylam = double.tryParse(parca[2]);
      if (enlem != null && boylam != null && parca[0].isNotEmpty) {
        aktifSehir.value = Sehir(ad: parca[0], enlem: enlem, boylam: boylam);
      }
    }
  }

  if (aktifSehir.value == null) {
    // Ankara'nın koordinatları: Türkiye'de makul bir başlangıç noktası.
    aktifSehir.value = const Sehir(ad: 'Ankara', enlem: 39.9334, boylam: 32.8597);
  }
  await saatDiliminiUygula();
}

// Aladhan'ın meta.timezone değeri, vakitlerin hangi saat dilimine göre
// olduğunu tam olarak bildirir. tz paketinin yerel konumunu buna göre
// ayarlıyoruz.
//
// ÖNEMLİ: Daha önce burada sabit kodlanmış 'Europe/Istanbul' vardı. Bu,
// uygulamanın başka ülkelerde kullanılması halinde saat dilimi
// kaymalarına yol açıyordu. Şimdi cihazın kendi saat dilimi kullanılıyor
// ve API'den gelen meta.timezone ile de doğrulanıp kesinleştiriliyor.
Future<void> saatDiliminiUygula([String? metaTimezone]) async {
  if (metaTimezone != null && metaTimezone.isNotEmpty) {
    try {
      tz.setLocalLocation(tz.getLocation(metaTimezone));
      return;
    } catch (_) {
      // Geçersiz/geçersiz yazılmış saat dilimi adı; aşağıda varsayılana düş.
    }
  }
  // Cihazın kendi saat dilimini kullan. timezone paketi varsayılan olarak
  // UTC'dir, o yüzden açıkça ayarlamamız gerekir.
  try {
    final int ofsetSaniye = DateTime.now().timeZoneOffset.inSeconds;
    final int saat = ofsetSaniye.abs() ~/ 3600;
    // Etc/GMT dilimlerinde işaret ters yazılır: UTC+3 -> Etc/GMT-3
    final String etiket = ofsetSaniye >= 0
        ? 'Etc/GMT-${saat.toString().padLeft(2, '0')}'
        : 'Etc/GMT+${saat.toString().padLeft(2, '0')}';
    tz.setLocalLocation(tz.getLocation(etiket));
  } catch (_) {
    // Son çare: tüm saat dilimleri yüklenemediyse Türkiye'ye sabitle.
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  }
}

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
  // Saat dilimi artık sabit kodlanmıyor; konumYukle() cihaz saat dilimini
  // uygular ve API'den gelen meta.timezone ile doğrular.

  const AndroidInitializationSettings androidAyarlari = AndroidInitializationSettings('@mipmap/ic_launcher');
  const LinuxInitializationSettings linuxAyarlari = LinuxInitializationSettings(defaultActionName: 'Uygulamayı Aç');
  const InitializationSettings baslangicAyarlari = InitializationSettings(android: androidAyarlari, linux: linuxAyarlari);
  
  await bildirimServisi.initialize(settings: baslangicAyarlari);
  await temaRenginiYukle();
  await temaModunuYukle();
  await erkenUyariYukle();
  await konumYukle();

  // Dil katalogu: 152 resmi dil, otokton adlar, yazım yönü ve cevirisi
  // hazir olan diller. supportedLocales sabit bir liste degil, bu
  // katalogdan geliyor; boylece yeni bir ceviri dosyasi eklediginizde
  // uygulama o dili otomatik tanir.
  await DilKatalogu.yukle();
  final katalog = DilKatalogu.ornek;
  final desteklenen = katalog.desteklenenYereller;

  // Cevirisi hic olmayan bir katalogda uygulama acilamaz; bu durumda
  // Turkce'ye duser (her kurulumda tur.json ve eng.json mevcuttur).
  // DIKKAT: Ceviri dosyalari 3 harfli ISO 639-2/3 kodyla adlandirilir
  // (tur.json, eng.json, ara.json) ve easy_localization dosya adini
  // Locale.languageCode'dan turetiyor. Bu yuzden 2 harfli 'tr'/'en' DEGIL,
  // 3 harfli 'tur'/'eng' kullanilmalidir; aksi halde easy_localization
  // tr.json diye var olmayan bir dosya arar ve tum metinler anahtar
  // adi olarak ekranda gorunur.
  final yereller = desteklenen.isEmpty
      ? const [Locale('tur'), Locale('eng')]
      : desteklenen;
  if (!yereller.any((l) => l.languageCode == 'tur')) {
    // easy_localization fallback olarak Turkce kullanilacak; yine de
    // listenin icinde bulunmasi guvenli taraftir.
  }

  runApp(
    EasyLocalization(
      supportedLocales: yereller,
      path: 'assets/i18n/ceviri',
      // Eksik anahtarlarda Turkceye dusulur. Cevirisi kismi olan yeni
      // diller ekledigimizde arayuzun tamami bos ekran olmaz.
      fallbackLocale: const Locale('tur'),
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
                
                // Locale 3 harfli kalir (tur, eng, ara) cunku easy_localization
                // ceviri dosyasinin adini Locale.languageCode'dan turetir.
                // Flutter'in global delegeleri ise yalnizca 2 harfli ISO-1
                // kodlarini tanir; sarmalayici delegeler 3 harfli kodu alip
                // Material/Widgets/Cupertino tarafina ISO-1 ile gecer.
                // Ayrinti icin: lib/utils/iso1_yerellestirme.dart
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates:
                      yerellestirmeDelegeleri(context.localizationDelegates),
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  title: 'Namaz Vakitleri',
                  themeMode: aktifMod,

                  // SAGDAN SOLA DIL DESTEGI
                  // Arapca, Farsca, Urduca, Ibranice, Aramice, Dhivehi ve
                  // Pestuca sagdan sola yazilir. Flutter varsayilan olarak
                  // her zaman soldan saga kurar; Directionality verilmezse bu
                  // dillerde menuler, listeler ve ikon yerlesimleri ters ve
                  // okunmaz gorunur.
                  builder: (context, child) {
                    // Katalog yuklenmediyse yonlendirmeye dokunmuyoruz;
                    // Flutter'in varsayilani (soldan saga) gecerli.
                    if (!DilKatalogu.yuklendiMi) return child!;
                    return Directionality(
                      textDirection:
                          DilKatalogu.ornek.yon(Localizations.localeOf(context)),
                      child: child!,
                    );
                  },

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