// lib/pages/ana_sayfa.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/plan_yenileme.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

import '../core/aladhan_cevap.dart';
import '../core/bildirim_ayarlari.dart';
import '../core/ezan_platformu.dart';
import '../core/ilk_acilis_izinleri.dart';
import '../core/bildirim_motoru.dart'
    show BildirimMotoru, BildirimPlanlayici;
import '../core/diyanet_verisi.dart';
import '../core/diyanet_guncel.dart';
import '../core/saat.dart';
import '../core/vakit_verisi.dart'
    show VakitDepo, VakitDurumu, VakitKaynagi, OnbellekOzeti, debugEkle;
import '../data/veri_havuzu.dart';
import '../data/ulke_verisi.dart';
import '../data/hesaplama_yontemleri.dart';
import '../main.dart';
import '../utils/widget_paketi.dart';
import '../widgets/sehir_secici.dart';

/// Bir yüklemenin sonucu.
///
/// NEDEN `bool` DEĞİL? `false` iki farklı olayı birleştiriyordu:
///
///   1) Gerçek hata (ağ yok, cevap reddedildi) → kullanıcı bilmeli,
///   2) Kullanıcı arada başka bir şehir seçtiği için bu yükleme
///      GEÇERSİZLEŞTİ → bu bir hata DEĞİLDİR, ekranda Tokyo'nun verisi
///      varken "internet yok" uyarısı çıkarmak yanlıştı.
enum _YuklemeSonucu {
  /// Veri ekrana uygulandı (ağdan ya da önbellekten).
  basarili,

  /// Gerçek hata: gösterecek taze veri yok.
  hata,

  /// Başka bir yükleme bu yüklemeyi geçersiz kıldı (veya ekran kapandı).
  /// Kullanıcıya hiçbir şey gösterilmez.
  iptal,
}

class _AnaSayfaState extends State<AnaSayfa> {

  // --- HAFIZA VE ŞEHİR YÖNETİMİ ---

  // --- GÜNCELLENEN: ARAMA DESTEKLİ ŞEHİR SEÇİMİ ---
  //
  // Önceden burada 81 ilin sabit listesi vardı ve yalnızca Türkiye
  // seçilebiliyordu. Artık seçili ülkenin tüm şehirleri (toplam 136 bin)
  // arama kutusuyla listeleniyor. Şehir dosyası yalnızca bu diyalog
  // açıldığında yüklenir.
  Future<void> _sehirDegistirDialog(BuildContext context) async {
    konumSecimiBaslat();
    setState(() => yukleniyor = false);
    final secilen = await sehirSeciciGoster(context, aktifUlkeKodu.value);
    if (secilen == null) return;
    await konumAyarla(secilen);
  }

  // --- ZİKİR HAFIZA FONKSİYONLARI ---

// Sayacı kaydetmek için
Future<void> _zikirKaydet(int deger) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('kayitli_zikir', deger);
}

// Hedefi kaydetmek için
Future<void> _hedefKaydet(int deger) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('kayitli_hedef', deger);
}

  StateSetter? _zikirPanelState;

  void _zikirArtir() {
    if (!mounted || _zikirPanelState == null) return;
    final onceki = zikirSayaci;
    setState(() => zikirSayaci++);
    _zikirPanelState?.call(() {});
    unawaited(_zikirKaydet(zikirSayaci));
    if (zikirHedefi > 0 && onceki < zikirHedefi && zikirSayaci >= zikirHedefi) {
      unawaited(_zikirHedefBildir(zikirHedefi));
    } else {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  Future<void> _zikirHedefBildir(int hedef) async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Zikir hedef titreşimi kullanılamadı: $e');
    }
    if (!bildirimYoluCalisir()) return;
    try {
      await bildirimServisi.show(
        id: -33001, // Vakit motorunun pozitif kimliklerinden ayrı.
        title: 'zikir_hedef_tamamlandi'.tr(),
        body: 'zikir_hedef_bildirim'.tr(namedArgs: {'sayi': '$hedef'}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'zikir_hedef_v1', 'tasbih'.tr(),
            importance: Importance.high, priority: Priority.high,
            playSound: false, enableVibration: false,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentSound: false, presentBadge: false,
          ),
        ),
        payload: 'zikir_hedef|$hedef',
      );
    } catch (e) {
      // Bildirim izni/eklenti sorunu saymayı veya titreşimi engellemez.
      debugPrint('Zikir hedef bildirimi gösterilemedi: $e');
    }
  }

  // --- DEĞİŞKENLER (STATE) ---

  // --- GÖSTERİLEN VAKİTLER (DOĞRULANMIŞ) ---
  //
  // ÖNCE: `Map<String, dynamic>? vakitler` idi ve JSON'dan dolduruluyordu.
  // Artık yalnız DOĞRULANMIŞ bir [VakitGunu] gösterilir. Doğrulanmamış bir
  // cevap bu değişkene hiçbir yoldan giremez; giriyorsa bu bir hatadır.
  VakitGunu? _bugun;
  List<VakitGunu> _gelecekGunler = const [];

  // Verinin nereden geldiği ve ne zaman tazelendiği. Arayüzde küçük bir
  // satırda gösterilir: kullanıcı "bu veri ne zaman güncellendi?" sorusunu
  // cevapsız bırakmaz.
  VakitKaynagi _kaynak = VakitKaynagi.yok;
  OnbellekOzeti? _ozet;
  CevapReddedildi? _sonHata;

  bool yukleniyor = true; // Ekranda yüklenme çarkını gösterme kontrolü.
  String hataMesaji = ''; // İnternet/API hatalarını tutacak metin.

  // --- RESMÎ DİYANET ---
  //
  // `_diyanet` son denenen resmî sorgunun sonucudur; ekran etiketi ve
  // uyarı metni bundan türetilir.
  //
  // Uyarı “ne oldu + hangi kaynak kullanıldı” bilgisidir; modal karar istemez.
  DiyanetSonuc? _diyanet;
  String diyanetUyarisi = '';

  /// Resmî veri deposu. `main.dart` içindeki TEK örnek kullanılır; böylece
  /// ana ekran, geri sayım, bildirimler ve widget aynı pakete bakar.
  DiyanetDepo get _diyanetDepo => diyanetDepo;
  late final DiyanetGuncelDepo _guncelDiyanet =
      widget.guncelDiyanet ?? DiyanetGuncelDepo(simdi: uygulamaSaati.simdi);
  DiyanetAgSonuc? _resmiAg;
  DateTime? _sonResmiDeneme;
  bool get _resmiKaynak => _kaynak == VakitKaynagi.resmiDiyanet ||
      _kaynak == VakitKaynagi.resmiDiyanetGuncel;

  Timer? _zamanlayici; // Her saniye çalışacak motor.
  String siradakiVakitIsmi = ''; // Ekrana basılacak sıradaki vaktin adı.
  String kalanSureMetni = ''; // Ekrana basılacak 00:00:00 formatındaki süre.
  String miladiTarih = ""; //Mevcut miladi tarih
  String hicriTarih = ""; // Mevcut hicri tarih

  // Ekranda gösterilecek BİLDİRİM UYARISI: motorun `uyari` alanı.
  //
  // NEDEN AYRI ALAN? Motor üç durumu AYRI ayrı bildirir ve kullanıcıya
  // farklı düzeltmeler gerekir:
  //
  //   * `exact_alarm_yok`          → alarmlar kuruldu, YAKLAŞIK zamanlı.
  //   * `bildirim_kurulamadi`      → bazı alarmlar kurulamadı.
  //   * `bildirim_iptal_edilemedi` → eski bir alarm silinemedi.
  //
  // Önceden `bool _tamZamanliAlarm` tutuluyor ve ekranda TEK sabit metin
  // ("... bildirimler yaklaşık zamanlı gelir") gösteriliyordu. Kurulum TAMAMEN
  // başarısız olduğunda bile bu metin çıkıyordu: kullanıcı vakit
  // bildirimlerinin geleceğini sanıyordu, gelmeyecekti. `uyari` okunmuyordu.
  //
  // `null` = uyarı yok. Yeni başarılı plan eski uyarıyı TEMİZLER; geç
  // kalan ya da kaldırılmış ekranın planı ise güncel uyarıya DOKUNMAZ.
  //
  // NOT: `tamZamanli` ayrıca tutulmaz. "Yaklaşık mod" durumu zaten
  // `exact_alarm_yok` uyarısıyla bildirilir; ayrı bir bool aynı bilgiyi
  // ikinci kez taşır ve tutarsız kalmaya açıktır (bool `false`, uyarı
  // `null` olduğunda ekran hiçbir şey söylemezdi).
  String? _bildirimUyarisi;

  /// Ekranda gösterilecek uyarı metni (çeviri çözülmüş).
  String? get _bildirimUyarisiMetni => _bildirimUyarisi?.tr();

  // Alarm planı SEÇİM sayacı "son geçerli seçim kazanır" kuralının
  // sayfa tarafındaki yarısıdır; diğer yarısı motorun uygulama kilididir
  // (bkz. `BildirimMotoru.uygula`).
  //
  // SAYAC BURADA DEĞİL, MOTORDA: numara motorun paylaşılan
  // `PlanSirasi`'ndan gelir. Sayfa-yerel bir sayaç olsaydı yeni açılan
  // ekran 1'den başlardı ve KALDIRILMIŞ ekranın geç kalan planıyla aynı
  // numarayı alırdı; "hangisi yeni?" sorusu cevapsız kalırdı. Ölçüm:
  // `test/ana_sayfa_bildirim_test.dart`.

  // -- İSTEK YARIŞI YÖNETİMİ --
  //
  // Hızlı şehir/yöntem değişikliklerinde (Ankara → Paris → Tokyo) eski
  // ağ cevabı yeni seçimin üzerine yazabilirdi. Her yükleme bir "jeton"
  // alır; cevap geldiğinde jeton hâlâ güncel mi diye bakılır. Değilse
  // cevap SESSİZCE BIRAKILIR. Kullanıcının son seçimi her zaman kazanır.
  //
  // Jetonu YALNIZCA gerçek bir yükleme artırır: kullanıcının yeni bir
  // konum/yöntem seçmesi. Yüklemenin kendi yan etkisi olan saat dilimi
  // kesinleşmesi jetonu artırmaz; bkz. [_saatDilimiKesinlesiyor].
  int _istekJetonu = 0;
  int? _yuklenenJeton;
  DateTime? _denenenTarih;
  final Map<String, Future<void>> _onIndirmeler = {};

  // Saat dilimi şu anda KENDİMİZCE işleniyor.
  //
  // `konumSaatDilimiKesinlestir` global `aktifKonum`'u günceller; normalde
  // bu, `_aktifKonumDegisti` dinleyicisini tetikleyip YENİ bir yükleme
  // başlatır. Oysa bu değişiklik aynı konumun, aynı ayın verisi
  // yüklenirken yapılır: tek fark saat dilimi. Önceden dinleyici yeniden
  // yükleme başlatıyordu; sonucu üç hata birden doğuyordu:
  //   1) aynı konum/ay için gereksiz ikinci ağ isteği,
  //   2) az önce alınan DOĞRULANMIŞ cevabın "eski" sayılıp ekrana
  //      uygulanmaması,
  //   3) `false` dönen yükleme yüzünden yanlış "internet yok" uyarısı.
  //
  // Yan etki sırasında "bu değişiklik benim" sinyali. Bastırma YALNIZCA
  // gerçekten aynı yeri gösteren VE yalnız saat dilimi değişen konum için
  // geçerlidir ([_sadeceSaatDilimiDegisti]); kullanıcı bu arada başka bir
  // şehir seçtiyse ya da gerçek bir hesap ayarı değiştirdiyse onun isteği
  // atlanmaz.
  bool _saatDilimiKesinlesiyor = false;
  Konum? _onaylananKonum;

  // Abonelik: dispose içinde kapatılır. Önceden tutulmuyordu, bu yüzden
  // iptal edilemiyor ve ekran kapansa bile ses olayları gelmeye devam
  // ediyordu.
  StreamSubscription<num>? _sesAboneligi;

  final VakitDepo _depo = VakitDepo(saat: uygulamaSaati);
  late final BildirimMotoru _bildirimMotoru = BildirimMotoru(
    eklenti: bildirimServisi,
    planlayici: const BildirimPlanlayici(),
    // Uygulama genelindeki TEK sıra: bu State'in motoru, önceki ekranın
    // motoruyla AYNI kaynağa (eklenti + kalıcı kimlik dizini) yazdığı için
    // sözü sırayla söylemelidir.
    sira: bildirimPlanSirasi,
    ezan: EzanPlatformu.destekleniyor ? ezanPlatformu : null,
  );

  // VakitWidget'a yazılan son içerik. Yazma kararı bu sınıfın içinde:
  // saniye saniye aynı gelen ad+saat için gereksiz yazma (ve Android'de
  // her saniye widget uyanması) böylece engelleniyor.
  final WidgetKoprusu _widgetKoprusu = WidgetKoprusu();

  // NOT: Aktif konum artık bu sınıfta değil, main.dart içindeki global
  // `aktifKonum` notifier'ında tutuluyor. Böylece ayarlar sayfasından
  // yapılan ülke değişikliği de aynı state'i günceller; iki ayrı kaynak
  // tutulması gerekmiyor.
  Konum? get _konum => aktifKonum.value;
  String get _sehirAdi => aktifKonum.value?.ad ?? 'select_city'.tr();

  /// Seçili şehrin saat takvimi. Gün ve duvar saati üretiminin tek yolu.
  SehirSaati? _sehirSaati(Konum? konum) =>
      konum == null ? null : SehirSaati(konum: konum, saat: uygulamaSaati);

  /// Ekranda gösterilen vakitler (doğrulanmış).
  Map<String, String>? get _vakitSaatleri => _bugun?.saatler;

  /// Önbellek/ağ özeti (arayüzde gösterilir).
  OnbellekOzeti? get _ozetVeri => _ozet;

  /// Sağlayıcının gerçekte kullandığı yöntem (`meta.method.id`).
  ///
  /// Otomatik modda kullanıcı bunu GÖRMELİDİR: "hangi hesapla
  /// hesaplandı" sorusunun cevabı budur. `_sonHata` varsa gösterilmez.
  int? get _donenYontemId => _ozet?.cevapYontemId;

  /// Yöntem id'sini okunabilir adı çevirir.
  String? yontemAdi(int? id) {
    if (id == null) return null;
    for (final y in hesaplamaYontemleri) {
      if (y.id == id) return y.ceviriAdi;
    }
    return null;
  }

  // initState(): Ekran oluşturulmadan hemen ÖNCE BİR KERE çalışır (C# Constructor / Form_Load gibi).
  @override
  void initState() {
    super.initState();
    _zikirYukle();
    final gecis = yuksekEnlemGecisBilgisi;
    yuksekEnlemGecisBilgisi = null;
    if (gecis != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gecis)));
      });
    }

    // Konum değişikliklerini dinle. Kaynak: ana sayfadaki şehir seçici,
    // GPS butonu veya ayarlar sayfasındaki ülke seçimi. Hepsi aynı
    // notifier'ı güncellediği için vakitler tek noktadan yenilenir.
    aktifKonum.addListener(_aktifKonumDegisti);

    // Hesaplama yöntemi değişirse vakitler değişir; yeniden çek.
    aktifHesaplamaYontemi.addListener(_yontemDegisti);
    aktifAsrYontemi.addListener(_hesapAyariDegisti);
    aktifYuksekEnlemAyaru.addListener(_hesapAyariDegisti);

    // Resmî Diyanet modu açılıp kapandığında vakit KAYNAĞI değişir:
    // paketten okunan resmî saatler ile hesaplanmış saatler birbirinin
    // yerine geçmez. Bu yüzden ayar "yalnız hesap ayarı" gibi ele
    // alınamaz; yeniden yükleme tetikler.
    aktifResmiDiyanet.addListener(_yontemDegisti);

    // Erken uyarı ve güneş doğuşu ayarları yalnız PLANLANMIŞ alarmları
    // etkiler; veriyi yeniden çekmeye gerek yok, planı yeniden kurmak yeter.
    erkenUyariSuresi.addListener(_alarmAyariDegisti);
    bildirimAyarlari.addListener(_alarmAyariDegisti);
    gunesDogumuBildirimiAcik.addListener(_alarmAyariDegisti);

    // Ses seviyesi aboneliği. Önceden `PerfectVolumeControl.stream.listen`
    // dönen abonelik TUTULMUYORDU; bu yüzden dispose içinde iptal
    // edilemiyor ve ekran kapansa bile sayaç artmaya devam ediyordu.
    try {
      _sesAboneligi = PerfectVolumeControl.stream.listen((value) {
        if (!mounted || _zikirPanelState == null) return;
        PerfectVolumeControl.hideUI = true;
        _zikirArtir();
      });
    } catch (e) {
      // Masaüstü platformlarda bu eklenti olmayabilir; zikirmatik
      // çalışmaz ama uygulama çökmez.
      debugPrint('Ses aboneliği kurulamadı: $e');
    }

    // Yaşam döngüsü: uygulama arka plandan öne geldiğinde gün değişmiş
    // olabilir. Veri ve sayaç yeniden değerlendirilir.
    WidgetsBinding.instance.addObserver(_yasamDongusuGozcusu);
    sayaciBaslat();

    // İlk yükleme. Vakitler önce açılır; bildirim izni ayrı bir adımda
    // ve ASLA vakit yüklemesini engellemez şekilde istenir.
    //
    // Sıralamanın sebebi: önceden `await bildirimServisi.initialize()` ve
    // izin isteği `vakitleriGetir`'den ÖNCE çalışıyordu. Kullanıcı bildirim
    // iznini reddederse vakitler hiç yüklenmiyor ve uygulama kullanılamaz
    // hale geliyordu. Namaz vakitleri bildirimlerden DAHA önemlidir.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _verileriYukle();
      if (mounted) await _ilkAcilisIzinleriniIste();
    });
  }

  /// Uygulama arka plana girip öne geldiğinde çağrılır.
  ///
  /// Gece yarısını geçmiş, ay değiştirmiş ya da cihaz saat dilimini
  /// değiştirmiş olabiliriz. Üçü de sessizce yanlış veriye yol açar.
  Future<void> _onYasamDongusuDurumuDegisti(AppLifecycleState durum) async {
    if (durum != AppLifecycleState.resumed) return;
    if (!mounted) return;

    final bekleyenKonum = _bekleyenKonumAyari;
    _bekleyenKonumAyari = null;
    if (bekleyenKonum != null && bekleyenKonum == konumSecimSurumu) {
      final servisAcik = await Geolocator.isLocationServiceEnabled();
      if (mounted && bekleyenKonum == konumSecimSurumu && servisAcik &&
          await Geolocator.checkPermission() != LocationPermission.deniedForever) {
        if (mounted && bekleyenKonum == konumSecimSurumu) {
          await _otomatikKonumBul();
        }
      }
    }
    if (!mounted) return;

    // 1) Cihazın saat dilimi değişti mi? Değişmişse konumun günü
    //    yeniden hesaplanmalı.
    // 2) Seçili şehrin günü değişti mi?
    final konum = _konum;
    if (konum == null) return;

    _gunuDenetle(yenidenDene: true);
    _resmiKaynakYenidenDene();
    kalanSureyiHesapla();
    // Sistem ayarlarından dönüşte aynı günün izinleri de değişmiş olabilir.
    // Gün yükleniyorsa onun sonucu zaten plan kurar; ikinci plan başlatma.
    if (_bugun != null && _yuklenenJeton == null) {
      await _alarmlariKur();
    }
  }

  // Timer ve resumed aynı kapıdan geçer. Başarısız bir gün devri her
  // saniye tekrarlanmaz; resumed veya kullanıcının tekrar denemesi beklenir.
  void _gunuDenetle({bool yenidenDene = false}) {
    final konum = _konum;
    if (!mounted || konum == null || _denenenTarih == null) return;
    final tarih = KonumTakvimi.tarih(konum, uygulamaSaati);
    if (_bugun != null && _bugun!.tarih != tarih) {
      setState(_gunuTemizle);
    _widgetleriYayinla();
    }
    if (_yuklenenJeton != null) return;
    if (_denenenTarih != tarih || (yenidenDene && _bugun == null)) {
      unawaited(_verileriYukle(onbellekYeterli: true));
    }
  }

  void _resmiKaynakYenidenDene() {
    final konum = _konum;
    if (!mounted || konum?.ulkeIso2 != 'TR' || !aktifResmiDiyanet.value ||
        _kaynak == VakitKaynagi.resmiDiyanet || _yuklenenJeton != null) return;
    final simdi = uygulamaSaati.simdi();
    if (_sonResmiDeneme != null &&
        simdi.difference(_sonResmiDeneme!) < const Duration(minutes: 5)) return;
    unawaited(_verileriYukle(onbellekYeterli: true));
  }

  void _gunuTemizle() {
    if (_bugun != null && bildirimYoluCalisir()) {
      unawaited(_gununBildirimleriniTemizle());
    }
    _bildirimUyarisi = null;
    _bugun = null;
    _gelecekGunler = const [];
    _kaynak = VakitKaynagi.yok;
    _ozet = null;
    _sonHata = null;
    diyanetUyarisi = '';
    miladiTarih = '';
    hicriTarih = '';
    siradakiVakitIsmi = '';
    kalanSureMetni = '--:--:--';
    hataMesaji = '';
    yukleniyor = true;
  }

  Future<void> _gununBildirimleriniTemizle() async {
    // İzin bekleyen çağrı hemen eskir. Başlamış sistem yazması ise motorun
    // kuyruğunda tamamlanıp temizlenir; yeni günün planı bunun arkasına girer.
    final secim = _bildirimMotoru.yeniSecim();
    final sonuc = await _bildirimMotoru.planiTemizle(secimNo: secim);
    if (!mounted || _bildirimMotoru.gecmisSecimMi(secim)) return;
    setState(() => _bildirimUyarisi = sonuc.uyari);
  }

  /// Bildirim izinlerini ister.
  ///
  /// ÖNCE bu, `initState` içinde `await` ediliyordu; yani uygulama açılışta
  /// kullanıcıyı karşılıyordu ve bildirim izni reddedilse bile vakitler
  /// yüklenmiyordu. Artık izinler ayrı bir adımda ve vakit yüklemesinden
  /// BAĞIMSIZ olarak istenir: kullanıcı bildirimleri reddederse bile
  /// vakitler görünür.
  Future<void> _bildirimIzinleriniIste() async {
    if (Platform.isAndroid) {
      try {
        await bildirimServisi
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('Bildirim izni istenemedi: $e');
      }
    } else if (Platform.isIOS) {
      try {
        await bildirimServisi
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (e) {
        debugPrint('iOS bildirim izni istenemedi: $e');
      }
    }
  }

  Future<void> _ilkAcilisIzinleriniIste() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final tercihler = await SharedPreferences.getInstance();
    if (!mounted) return;
    await IlkAcilisIzinleri().iste(
      tercihler: tercihler,
      bildirim: _bildirimIzinleriniIste,
      alarm: () async {
        if (Platform.isAndroid) {
          await bildirimServisi.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
              ?.requestExactAlarmsPermission();
        }
      },
      konum: () async {
        if (await Geolocator.checkPermission() == LocationPermission.denied && mounted) {
          await Geolocator.requestPermission();
        }
      },
      devam: () => mounted,
      hataBildir: (hata) => debugPrint('İlk açılış izni istenemedi: $hata'),
    );
    if (mounted && _bugun != null) await _alarmlariKur();
  }

  /// Hesaplama yöntemi değişti: vakitler değişir, yeniden çekilir.
  Future<void> _yontemDegisti() async {
    if (!mounted) return;
    // Yöntem değiştiğinde KONUMUN KENDİSİ de değişir (yöntem konumun
    // alanıdır ve önbellek anahtarına girer).
    final konum = _konum;
    if (konum == null) return;
    aktifKonum.value = konum.kopyala(yontemId: aktifHesaplamaYontemi.value);
    await konumKaydet(aktifKonum.value!);
    // Not: aktifKonum değişimi zaten _aktifKonumDegisti'ni tetikler; veri
    // orada çekilir. Burada ek istek atmıyoruz (çift ağ isteği olurdu).
  }

  /// Asr ya da yüksek enlem ayarı değişti: vakitler değişir.
  Future<void> _hesapAyariDegisti() async {
    if (!mounted) return;
    final konum = _konum;
    if (konum == null) return;
    aktifKonum.value = konum.kopyala(
      asrYontemi: aktifAsrYontemi.value,
      yuksekEnlemAyaru: aktifYuksekEnlemAyaru.value,
    );
    await konumKaydet(aktifKonum.value!);
  }

  /// Erken uyarı ya da güneş doğuşü ayarı değişti: yalnız alarm planı
  /// yeniden kurulur, veri çekilmez.
  Future<void> _alarmAyariDegisti() async {
    if (!mounted) return;
    if (_bugun == null) return;
    await _alarmlariKur();
  }

  /// Aktif konum değiştiğinde tetiklenir: yeni konumun vakitlerini çeker.
  ///
  /// Hem ana sayfadaki şehir seçiciden, GPS'ten hem de ayarlar sayfasındaki
  /// ülke seçiminden gelen değişiklikler bu tek noktadan geçer.
  ///
  /// TEK İSTİSNA: [_saatDilimiKesinlesiyor] sırasındaki ve YALNIZCA saat
  /// dilimiyle değişen konum. O değişiklik KENDİ kaynaklıdır ve yükleme
  /// zaten sürüyordur; bkz. [_saatDiliminiIsle].
  Future<void> _aktifKonumDegisti() async {
    if (!mounted) return;
    final onaylanan = _onaylananKonum;
    if (_saatDilimiKesinlesiyor &&
        onaylanan != null &&
        _konum != null &&
        _sadeceSaatDilimiDegisti(onaylanan, _konum!)) {
      debugEkle('saat dilimi kesinleşti: aynı konum için tekrar yükleme yok');
      return;
    }
    final sonuc = await _verileriYukle();
    // Yalnız GERÇEK hatada uyarı gösterilir. `iptal` (bu yükleme
    // arada geçersizleşti) bir hata değildir: sonucu daha yeni bir
    // yükleme belirliyor ve o kendi durumunu zaten bildirdi. Buradaki
    // hatanın sebebi "internet yok"u.
    if (sonuc == _YuklemeSonucu.hata && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_internet_city'.tr(args: [_sehirAdi])),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  // 5. BELLEK YÖNETİMİ (Kritik Edge Case)
  @override
  void dispose() {
    _zikirPanelState = null;
    _zamanlayici?.cancel();
    WidgetsBinding.instance.removeObserver(_yasamDongusuGozcusu);
    // Abonelik kapatılır. Bu yapılmazsa ekran kapansa bile ses olayları
    // gelmeye devam eder ve sayaç arka planda artar.
    _sesAboneligi?.cancel();
    _sesAboneligi = null;
    // Global notifier'a eklediğimiz dinleyicileri kaldır. Bu yapılmazsa,
    // AnaSayfa çökse bile notifier bu State'i tutmaya devam eder ve
    // bellek sızıntısı oluşur.
    aktifKonum.removeListener(_aktifKonumDegisti);
    aktifHesaplamaYontemi.removeListener(_yontemDegisti);
    aktifAsrYontemi.removeListener(_hesapAyariDegisti);
    aktifYuksekEnlemAyaru.removeListener(_hesapAyariDegisti);
    aktifResmiDiyanet.removeListener(_yontemDegisti);
    erkenUyariSuresi.removeListener(_alarmAyariDegisti);
    bildirimAyarlari.removeListener(_alarmAyariDegisti);
    gunesDogumuBildirimiAcik.removeListener(_alarmAyariDegisti);
    super.dispose();
  }

  /// Yaşam döngüsü gözlemcisi.
  ///
  /// `didChangeAppLifecycleState` ile uygulamanın arka plandan öne
  /// gelmesini dinler. Gece yarısını geçirmiş, ay değiştirmiş ya da
  /// cihazın saat dilimini değiştirmiş olabiliriz; üçü de sessizce
  /// yanlış vakite yol açardı.
  late final WidgetsBindingObserver _yasamDongusuGozcusu = _Gozlemci(this);

  void yasamDongusuDurumuDegisti(AppLifecycleState durum) {
    _onYasamDongusuDurumuDegisti(durum);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // DİL DEĞİŞTİĞİNDE planlanmış bildirim metinleri eski dilde kalmasın.
    //
    // Bildirim metinleri ALARM KURULURKEN çeviriye bağlanır; çünkü alarm
    // uygulama kapalıyken gösterilir ve o an hangi dilin seçili olduğu
    // bellekten bilinmez. Bu yüzden dil değişince plan yeniden kurulmalı.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _widgetleriYayinla();
    });
    final yeniDil = context.locale.languageCode;
    if (_sonDil != null && _sonDil != yeniDil) {
      _sonDil = yeniDil;
      if (_bugun != null) {
        // Bu, planı yeniden kurar; `context` bağımlılığı değiştiği için
        // bir sonraki karede çalışır.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _alarmlariKur();
        });
      }
    } else {
      _sonDil = yeniDil;
    }
  }

  String? _sonDil;

  // --- BİLDİRİM GÖNDERME ---
  //
  // Tüm bildirim metinleri çeviri dosyasından gelir. Önceden "Vakit Geldi!",
  // "Ezan Vakitleri", "Uygulamayı Aç" gibi metinler Türkçe sabit yazılmıştı;
  // uygulama 25 dilde çalışmasına rağmen bildirimler Türkçe gidiyordu.
  //
  // Vakit bildiriminin başlık ve içeriğini üretir.
  //
  // Metinlerdeki {vakit} / {dakika} yer tutucuları `namedArgs` ile doldurulur.
  //
  // Neden `args` değil: easy_localization 3.x'te `args: [...]` YALNIZCA "{}"
  // desenini değiştirir ve her seferinde ilk "{}"ı doldurur; sıralı "@0/@1"
  // desenini tanımaz. `namedArgs` ise ad eşlemesi kullanır ve her değerin
  // metinde nerede duracağını DİLİN KENDİSİ belirler. Bu 25 dil için şart:
  // Arapçada "بقي {dakika} دقيقة على وقت {vakit}" (kalan {dakika} dakika,
  // {vakit} vaktine) ile Türkçede "{vakit} vaktine {dakika} dakika kaldı"
  // sıralaması tamamen farklıdır. Sıralı desen kullanılsaydı bu iki dilden
  // biri (ya da ikisi) anlamsız metin üretirdi.
  ///
  /// [erkenUyariMi] true ise erken uyarı başlığı ve dakika sayısı içerir.
  (String, String) _bildirimMetinleri({
    required String vakitAdi,
    required bool erkenUyariMi,
    required int erkenDakika,
  }) {
    if (erkenUyariMi) {
      return (
        'early_warning'.tr(),
        'notif_early_body'.tr(
          namedArgs: <String, String>{
            'vakit': vakitAdi,
            'dakika': '$erkenDakika',
          },
        ),
      );
    }
    return (
      'notif_time_reached'.tr(),
      'notif_time_reached_body'.tr(
        namedArgs: <String, String>{'vakit': vakitAdi},
      ),
    );
  }

  void _widgetleriYayinla() {
    if (!mounted || !Platform.isAndroid) return;
    final gunler = [..._gelecekGunler];
    if (_bugun != null) gunler.insert(0, _bugun!);
    final paket = WidgetPaketi.olustur(
      konum: _konum, saat: uygulamaSaati,
      gunler: gunler,
      tema: Theme.of(context).colorScheme, dil: context.locale.languageCode,
      kaynak: (_resmiKaynak ? 'kaynak_diyanet' : 'kaynak_hesaplanmis').tr(),
      metinler: {
        for (final ad in WidgetPaketi.vakitler) ad: ad.tr(),
        'nextTitle': 'next_time'.tr(), 'open': 'widget_vakit_acilis'.tr(),
        'ayahTitle': 'ayah_of_the_day'.tr(), 'hadithTitle': 'hadith_of_the_day'.tr(),
        'approximate': 'alarm_access_desc'.tr(),
      },
    );
    paket['renewal'] = yenilemeAyarlari(_konum,
      resmi: aktifResmiDiyanet.value, bildirim: bildirimAyarlari.value,
      erken: erkenUyariSuresi.value, gunes: gunesDogumuBildirimiAcik.value);
    unawaited(_widgetKoprusu.yayinla(paket).catchError((Object e) {
      debugPrint('Widget güncellenemedi: $e');
    }));
  }
  // --- YENİ EKLENEN: OTOMATİK KONUM BULMA MOTORU ---
  // --- YENİ GÜNCELLENEN: OTOMATİK KONUM BULMA MOTORU ---
  int? _bekleyenKonumAyari;

  Future<void> _konumAyariniSor(int surum, {required bool servisKapali}) async {
    if (!mounted || surum != konumSecimSurumu) return;
    setState(() => yukleniyor = false);
    final ac = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('find_location'.tr()),
        content: Text((servisKapali ? 'loc_service_off' : 'loc_perm_forever').tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('settings'.tr())),
        ],
      ),
    );
    if (ac != true || !mounted || surum != konumSecimSurumu) return;
    _bekleyenKonumAyari = surum;
    try {
      final acildi = servisKapali
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
      if (!acildi && _bekleyenKonumAyari == surum) _bekleyenKonumAyari = null;
    } catch (_) {
      if (_bekleyenKonumAyari == surum) _bekleyenKonumAyari = null;
      rethrow;
    }
  }

  Future<void> _otomatikKonumBul() async {
    final surum = konumSecimiBaslat();
    bool guncel() => mounted && surum == konumSecimSurumu;
    void hata(String mesaj) {
      // Son ek, her hata türünde aynıdır; ayrı bir çeviri anahtarıyla alınır
      // ki cümle dilbilgisi başka bir dile çevrilirken yeniden kurulabilsin.
      if (guncel()) {
        _konumHatasiBildir(
            '$mesaj ${'konum_eski_korundu'.tr()}');
      }
    }
    setState(() => yukleniyor = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (guncel()) await _konumAyariniSor(surum, servisKapali: true);
        return;
      }
      var izin = await Geolocator.checkPermission();
      if (!guncel()) return;
      if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
      if (!guncel()) return;
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        if (izin == LocationPermission.deniedForever) {
          await _konumAyariniSor(surum, servisKapali: false);
        } else {
          hata('loc_perm_denied'.tr());
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 20));
      if (!guncel()) return;
      Placemark? yer;
      try {
        final isimler = await placemarkFromCoordinates(p.latitude, p.longitude)
            .timeout(const Duration(seconds: 4));
        if (isimler.isNotEmpty) yer = isimler.first;
      } catch (_) {
        // Geocoder/ağ yoksa yerel katalog yine çalışır.
      }
      if (!guncel()) return;
      final iso = yer?.isoCountryCode?.trim().toUpperCase();
      final ulke = iso != null && RegExp(r'^[A-Z]{2}$').hasMatch(iso) ? iso : null;
      final sonuc = await diyanetKonumCozucu.coz(
        enlem: p.latitude, boylam: p.longitude, hassasiyet: p.accuracy,
        ulke: ulke, il: yer?.administrativeArea ?? '',
        adlar: [yer?.subAdministrativeArea ?? '', yer?.locality ?? '',
          yer?.subLocality ?? ''],
      );
      if (!guncel()) return;
      if (sonuc != null) {
        await konumAyarla(sonuc.sehir, secimSurumu: surum, ulke: 'TR', guncelMi: guncel);
        if (guncel()) {
          _konumHatasiBildir(sonuc.ilMerkezi
              ? 'konum_ilce_kesinlesmedi'.tr(args: [sonuc.sehir.il])
              : 'konum_bulundu'.tr(args: [sonuc.sehir.etiket()]));
        }
      } else if (ulke != null && ulke != 'TR') {
        final ad = [yer?.locality, yer?.subAdministrativeArea, yer?.administrativeArea]
            .whereType<String>().where((s) => s.trim().isNotEmpty).firstOrNull;
        await konumAyarla(Sehir(ad: ad ?? '${p.latitude.toStringAsFixed(3)}, ${p.longitude.toStringAsFixed(3)}',
          enlem: p.latitude, boylam: p.longitude), secimSurumu: surum,
          ulke: ulke, guncelMi: guncel);
      } else {
        hata('konum_yerlesim_kesinlesmedi'.tr());
      }
    } catch (_) {
      hata('loc_error'.tr());
    }
  }

  // YENİ EKLENEN YARDIMCI FONKSİYON: Ekranı bozmadan şık uyarı verir
  void _konumHatasiBildir(String uyariMetni) {
    if (!mounted) return;
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

  // 6. VERİ YÜKLEME — offline-first
  //
  // SIRALAMA ÖNEMLİ:
  //   1) Önce ÖNBELLEK okunur ve ekran ANINDA açılır. Kullanıcı her
  //      açılışta 10 saniye ağ beklemez.
  //   2) Sonra arka planda ağ denenir.
  //   3) Ağdan gelen cevap DOĞRULANIRSA ekran tazelenir ve önbelleğe
  //      yazılır. Doğrulanmazsa önbelleğe DOKUNULMAZ; ekranda önbellekteki
  //      sağlam veri kalır ve hata bilgilendirme amaçlı gösterilir.
  //
  // Gün devrinde doğrulanmış yeni gün yeterlidir; saniyelik ağ tazelemesi yok.
  Future<_YuklemeSonucu> _verileriYukle({bool onbellekYeterli = false}) async {
    if (!mounted) return _YuklemeSonucu.iptal;
    final konum = _konum;
    if (konum == null) {
      setState(() {
        yukleniyor = false;
        hataMesaji = 'data_load_error'.tr();
      });
      return _YuklemeSonucu.hata;
    }

    // İSTEK JETONU: her yükleme artan bir jeton alır. Ağ cevabı
    // geldiğinde bu jeton hâlâ güncel mi diye bakılır; değilse cevap
    // yok sayılır. Bu, "Ankara → Paris → Tokyo" hızlı seçiminde Tokyo'nun
    // cevabının ekranda kalmasını garanti eder.
    final jeton = ++_istekJetonu;
    final sehirTarihi = KonumTakvimi.tarih(konum, uygulamaSaati);
    _yuklenenJeton = jeton;
    _denenenTarih = sehirTarihi;
    setState(_gunuTemizle);
    _widgetleriYayinla();
    try {
      return await _verileriYukleIstek(konum, sehirTarihi, jeton,
          onbellekYeterli: onbellekYeterli);
    } finally {
      if (_yuklenenJeton == jeton) {
        _yuklenenJeton = null;
        // Yükleme sürerken gece yarısı geçmiş olabilir (ağ hatasında da).
        _gunuDenetle();
      }
    }
  }

  /// Tek kaynak zinciri: gömülü → doğrulanmış resmî web → hesaplanmış.
  /// null, hesaplanmış akışa devam demektir; iptal ayrı bir sonuçtur.
  Future<_YuklemeSonucu?> _resmiDiyanetYukle(
      Konum konum, DateTime tarih, int jeton) async {
    _sonResmiDeneme = uygulamaSaati.simdi();
    _resmiAg = null;
    // Resmî TR tablosunun dilimi bilinir. Önceki şehirden kalabilen
    // geçerli ama yanlış dilim de sayaç/widget/alarmlar için düzeltilir.
    if (konum.saatDilimi != kTurkiyeSaatDilimi) {
      await _saatDiliminiIsle(konum, kTurkiyeSaatDilimi);
      if (!mounted || jeton != _istekJetonu) return _YuklemeSonucu.iptal;
      konum = _konum!;
      tarih = KonumTakvimi.tarih(konum, uygulamaSaati);
      _denenenTarih = tarih; // Tahmini gün gece yarısında farklı olabilir.
    }
    final id = konum.diyanetCityId;
    final parca = konum.diyanetParca;
    final sonuc = id != null && parca != null
        ? await _diyanetDepo.vakitler(cityId: id, ilDosya: parca, tarih: tarih)
        : const DiyanetSonuc(durum: DiyanetDurum.yerlesimYok);
    if (jeton != _istekJetonu || !mounted) return _YuklemeSonucu.iptal;
    if (KonumTakvimi.tarih(_konum ?? konum, uygulamaSaati) != tarih) {
      return _YuklemeSonucu.iptal;
    }
    _diyanet = sonuc;
    if (sonuc.basariliMi) {
      diyanetUyarisi = '';
      _durumuUygula(VakitDurumu(konum: konum,
          kaynak: VakitKaynagi.resmiDiyanet, bugun: sonuc.gun,
          gelecekGunler: sonuc.siradakiGunler));
      return _YuklemeSonucu.basarili;
    }
    final guncel = id == null ? null : await _guncelDiyanet.oku(id, tarih);
    if (jeton != _istekJetonu || !mounted) return _YuklemeSonucu.iptal;
    if (KonumTakvimi.tarih(_konum ?? konum, uygulamaSaati) != tarih) {
      return _YuklemeSonucu.iptal;
    }
    if (guncel != null) {
      _resmiAg = guncel;
      diyanetUyarisi = 'Gömülü veri bugün kullanılamıyor; güncel resmî Diyanet tablosu kullanıldı.';
      _durumuUygula(VakitDurumu(konum: konum,
          kaynak: VakitKaynagi.resmiDiyanetGuncel, bugun: guncel.bugun,
          gelecekGunler: guncel.gelecekGunler));
      return _YuklemeSonucu.basarili;
    }
    // Henüz hesaplanmış veri bulunmadı; “gösteriliyor” denmez.
    diyanetUyarisi = 'Resmî Diyanet verisi bugün kullanılamıyor; hesaplanmış vakitler aranıyor.';
    return null;
  }
  Future<_YuklemeSonucu> _verileriYukleIstek(
      Konum konum, DateTime sehirTarihi, int jeton,
      {required bool onbellekYeterli}) async {
    if (!mounted) return _YuklemeSonucu.iptal;

    // --- ADIM 1: ÖNBELLEKten aç ---
    // Ay sınırında aynı ayı indiren ön yükleme varsa ona katıl.
    await _onIndirmeler[konum.onbellekAnahtari(
        yil: sehirTarihi.year, ay: sehirTarihi.month)];
    if (jeton != _istekJetonu || !mounted) return _YuklemeSonucu.iptal;
    VakitDurumu? onbellekDurumu;
    try {
      final kayitli = await _depo.kayitOku(konum,
          yil: sehirTarihi.year, ay: sehirTarihi.month);
      if (kayitli != null) {
        final ozet = await _depo.ozetOku(konum,
            yil: sehirTarihi.year, ay: sehirTarihi.month);
        onbellekDurumu = VakitDurumu(
          konum: konum,
          kaynak: VakitKaynagi.onbellek,
          bugun: kayitli.gun(sehirTarihi),
          gelecekGunler: await _gelecekGunleriTamamla(
              konum, sehirTarihi, _gelecekleriSirala(kayitli, sehirTarihi)),
          ozet: ozet,
        );
      }
    } catch (e) {
      // Bozuk önbellek uygulamayı düşürmez; katman kendi karantinaya
      // alma işlemini yaptı.
      debugPrint('Önbellek okunamadı: $e');
    }

    // Önbelleği okurken arada başka bir yükleme başladıysa bu yükleme
    // geçersizdir: sunucuya gider bile olmayacak. Hata değil (bkz.
    // [_YuklemeSonucu]).
    if (jeton != _istekJetonu || !mounted) return _YuklemeSonucu.iptal;
    if (KonumTakvimi.tarih(_konum ?? konum, uygulamaSaati) != sehirTarihi) {
      return _YuklemeSonucu.iptal;
    }

    if (konum.ulkeIso2 == 'TR' && aktifResmiDiyanet.value) {
      final resmi = await _resmiDiyanetYukle(konum, sehirTarihi, jeton);
      if (resmi != null) return resmi;
    } else {
      _diyanet = null;
      _resmiAg = null;
      diyanetUyarisi = '';
    }
    if (jeton != _istekJetonu || !mounted) return _YuklemeSonucu.iptal;
    // Önbellekte bugün varsa EKRANI HEMEN AÇ. Arayüz donmaz.
    if (onbellekDurumu?.bugun != null) {
      _durumuUygula(onbellekDurumu!);
      if (onbellekYeterli) return _YuklemeSonucu.basarili;
    } else {
      setState(() => yukleniyor = true);
    }

    // --- ADIM 2: Arka planda ağdan tazele ---
    // Jeton `_agiDene`'ye de verilir: cevabın YAN ETKİSİ olan tek adım
    // orada (saat dilimi yazımı) ve güncellik denetimi ondan önce
    // yapılmalıdır. Aşağıdaki denetim yalnız EKRAN durumunu korur.
    final cevap = await _agiDene(konum, sehirTarihi, jeton);
    final gelecekGunler = cevap == null
        ? null
        : await _gelecekGunleriTamamla(
            konum, sehirTarihi, cevap.gelecekGunler);

    // Geçerli jeton değilse: kullanıcı arada başka bir şehir/yöntem
    // seçti. Bu cevap EKRANA UYGULANMAZ ve seçili konumun saat dilimine
    // dokunmaz.
    //
    // ÖNCEKİ YORUM YANLIŞTI ("önbelleğe de yazılmaz" deniyordu): veri
    // katmanı bu cevabı ZATEN yazdı. `agCevabiniIsle` cevabı
    // `konum.onbellekAnahtari(...)` ile, yani O KONUMUN KENDİ anahtarına
    // yazar (koordinat + yöntem + Asr/yüksek enlem + yıl-ay). Bu güvenli ve
    // istenen davranıştır: geç gelen DOĞRULANMIŞ bir cevap, kullanıcının
    // artık seçmediği bir şehrin önbelleğini doldurur — başka bir şehrin
    // başlığı altına veri SIzdıramaz, çünkü anahtarda koordinat vardır.
    //
    // Sonuç `iptal`dir, HATA DEĞİLDİR: bu yüklemenin sonucunu belirleyen
    // başka bir yükleme vardır ve o zaten kendi sonucunu bildirecektir.
    if (jeton != _istekJetonu) {
      debugPrint('eski cevap yok sayıldı (jeton $jeton != $_istekJetonu)');
      return _YuklemeSonucu.iptal;
    }
    if (!mounted) return _YuklemeSonucu.iptal;

    // Geç gelen başarısız cevap da eski günü ekrana geri getiremez.
    if (KonumTakvimi.tarih(konum, uygulamaSaati) != sehirTarihi) {
      return _verileriYukle(onbellekYeterli: true);
    }

    if (cevap == null) {
      // Ağ yok ya da hata verdi. Önbellek varsa ekran açık kalır.
      if (onbellekDurumu?.bugun != null) {
        return _YuklemeSonucu.basarili;
      }
      setState(() {
        yukleniyor = false;
        _kaynak = VakitKaynagi.yok;
        if (konum.ulkeIso2 == 'TR' && aktifResmiDiyanet.value) {
          diyanetUyarisi = 'Resmî ve güvenilir hesaplanmış veri bulunamadı; vakit gösterilmiyor.';
        }
      });
      return _YuklemeSonucu.hata;
    }

    // --- ADIM 3: Kesinleşen saat dilimi "bugün"ü değiştirdi mi? ---
    //
    // Saat dilimi bilinmediğinde gün, boylama dayalı bir TAHMİNLE bulunur
    // (bkz. KonumTakvimi). Cevap geldi ve doğrulanan dilim bu tahmini
    // DOĞRULAMADIYSA (yarım saatlik dilimlerde, tahmin ile gerçek ofset
    // arasındaki fark kadar bir pencerede) ekranda yanlış günün vakitleri
    // gösterilirdi. O durumda aynı konum için DOĞRU günün isteği atılır.
    //
    // Gün değişmediyse — normalde böyledir — HİÇBİR ek istek atılmaz.
    if (cevap.basariliMi) {
      final kesinKonum = _konum ?? konum;
      final kesinTarih = KonumTakvimi.tarih(kesinKonum, uygulamaSaati);
      if (kesinTarih != sehirTarihi) {
        debugEkle('saat dilimi kesinleşti, gün düzeltiliyor: '
            '$sehirTarihi -> $kesinTarih');
        // Aynı ayın kaydı zaten önbellekte; bu yükleme ekranı yine ANINDA
        // açar, yalnızca ağ tarafından tazelenir.
        return _verileriYukle();
      }
    }

    // --- ADIM 4: Doğrulanmış cevabı uygula ---
    _durumuUygula(cevap, gelecekGunler: gelecekGunler);

    // Ay sonuna yaklaşınca sonraki ayı da önceden indir.
    _sonrakiAyiOndenIndir(konum, sehirTarihi);

    // Cevap doğrulanmadıysa gerçek bir yükleme hatasıdır (HTTP hatası,
    // bozuk gövde, eksik gün). `_durumuUygula` bunu ekran hatası olarak
    // gösterdi; çağıran da "veri yenilenemedi" uyarısını verir.
    return cevap.basariliMi ? _YuklemeSonucu.basarili : _YuklemeSonucu.hata;
  }

  /// Doğrulanmış `meta.timezone` değerini konuma işler.
  ///
  /// [konumSaatDilimiKesinlestir] global konumu günceller; bu, normalde
  /// `_aktifKonumDegisti` dinleyicisini tetikler ve yeni bir yükleme
  /// başlatır. Buradaki değişiklik KENDİ kaynaklı olduğu için dinleyiciye
  /// "yeni bir konum seçilmedi" sinyali verilir: aynı konum/ay için ikinci
  /// bir ağ isteği atılmaz ve az önce alınan doğrulanmış cevap "eski"
  /// sayılmaz. Yüklemenin devamı, cevabı doğruladığı saat dilimiyle ekrana
  /// uygular (bkz. [KonumTakvimi] ile gün düzeltmesi).
  Future<void> _saatDiliminiIsle(Konum istenenKonum, String iana) async {
    _onaylananKonum = istenenKonum;
    _saatDilimiKesinlesiyor = true;
    try {
      await konumSaatDilimiKesinlestir(iana);
    } finally {
      _saatDilimiKesinlesiyor = false;
      _onaylananKonum = null;
    }
  }

  /// [yeni], [eski]'den YALNIZCA saat dilimiyle mi farklı?
  ///
  /// Bu, bastırmanın tam olarak neyi kapsadığını tanımlar:
  ///
  ///   * Saat dilimi değişikliği → aynı ayın verisi zaten yükleniyor,
  ///     yeni istek gereksizdir ( bastırılır).
  ///   * Yöntem / Asr / yüksek enlem değişikliği → hesap ayarıdır,
  ///     ÖNBELLEK ANAHTARINA GİRER ve vakitleri gerçekten değiştirir;
  ///     bastırılırsa kullanıcının ayarı sessizce hiç uygulanmaz.
  ///     Bu yüzden `false` döner (bastırılmaz).
  ///
  /// Koordinat/ad/ülke farkı da kapsam dışıdır: başka bir yerdir.
  static bool _sadeceSaatDilimiDegisti(Konum eski, Konum yeni) {
    if (eski.saatDilimi == yeni.saatDilimi) return false;
    return eski.ad == yeni.ad &&
        eski.ulkeIso2 == yeni.ulkeIso2 &&
        eski.enlem == yeni.enlem &&
        eski.boylam == yeni.boylam &&
        eski.yontemId == yeni.yontemId &&
        eski.asrYontemi == yeni.asrYontemi &&
        eski.yuksekEnlemAyaru == yeni.yuksekEnlemAyaru;
  }

  /// Ağ isteğini yapar ve DOĞRULANMIŞ cevap ya da `null` döner.
  ///
  /// `null` dönmesi "ağ yok/istek başarısız" demektir; geçersiz cevap
  /// `null` DEĞİLDİR, [VakitDurumu.hata] dolu döner.
  ///
  /// [jeton] bu isteğin güncellik damgasıdır. YAN ETKİSİ OLAN TEK ADIM
  /// burada olduğu için (saat diliminin konuma yazılması) güncellik
  /// denetimi de yan etkinin hemen önünde, burada yapılır.
  Future<VakitDurumu?> _agiDene(
      Konum konum, DateTime sehirTarihi, int jeton) async {
    // Aladhan `/v1/calendar` uç noktası KOORDİNAT kabul eder ve
    // `calendarByCity`'nin aksine dahili geocoder kullanmaz; 160 bin
    // kayıtlık veri setindeki küçük şehirlerde HTTP 503 vermez.
    final p = <String, String>{
      'latitude': konum.enlem.toStringAsFixed(4),
      'longitude': konum.boylam.toStringAsFixed(4),
      'month': sehirTarihi.month.toString(),
      'year': sehirTarihi.year.toString(),
    };
    if (konum.yontemId != null) p['method'] = konum.yontemId.toString();
    p['school'] = konum.asrYontemi.apiParametresi;
    p['latitudeAdjustmentMethod'] = konum.yuksekEnlemAyaru.apiParametresi;

    final url = Uri.https('api.aladhan.com', '/v1/calendar', p);
    String govde;
    int durum;

    try {
      final c = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      govde = c.body;
      durum = c.statusCode;
    } catch (e) {
      debugPrint('ağ yok: $e');
      return null;
    }

    // Cevabı doğrula. Geçersizse burada REDDEDİLİR ve önbelleğe yazılmaz.
    final sonuc = await _depo.agCevabiniIsle(
      konum: konum,
      govde: govde,
      httpDurumKodu: durum,
      istenenGun: sehirTarihi,
    );

    // Saat dilimi doğrulandı: konumun kalıcı alanına yazılır. Bundan
    // sonra açılışlarda cihaz saatine düşülmeden doğru gün bulunur.
    //
    // ANCAK bu bir YAN ETKİDİR: GLOBAL `aktifKonum` değişir ve cihaza
    // yazılır. Bu yüzden yan etki yapılmadan ÖNCE cevabın hâlâ RELEVANT
    // olduğu İKİ koşulla denetlenir:
    //
    //   1) JETON: kullanıcı arada başka bir konum/yöntem seçtiyse cevap
    //      geçersizdir. "Ankara sürerken Tokyo seçildi" senaryosunda
    //      Ankara'nın geç cevabı Tokyo'nun konumunu kendi saat dilimiyle
    //      değiştirip cihaza yanlış değeri yazardı.
    //   2) EKRAN HENÜZ AYAKTA: `dispose` jetonu sıfırlamaz ve
    //      `_istekJetonu` bu State'e AİT olduğu için, ekran kalktıktan
    //      sonra gelen cevap "geçerli" görünür. Oysa yan etki global
    //      duruma yazıyor: ekranı kalkmış bir sayfanın yanıtı, o sırada
    //      başka bir konum seçilmiş (ya da yeni bir ekranda açılmış) olan
    //      KULLANICIYI etkilememeli.
    //
    // Veri katmanının yazdığı önbellek KALIR: cevap kendi konum anahtarına
    // (koordinat + yöntem + Asr/yüksek enlem + yıl-ay) yazılır, hiçbir
    // başka şehrin başlığını zedelemez. Yalnız GLOBAL/KALICI konum ve
    // ekran durumu korunur.
    //
    // Yazılacak değer `_konum`'dan değil, isteğin yapıldığı [konum]'dan
    // okunur: yanlış olan hangisi olursa olsun istenen konuma yazılmalıdır.
    if (!sonuc.basariliMi) return sonuc;
    if (!mounted || jeton != _istekJetonu) {
      debugEkle('geç cevap: saat dilimi güncellenmedi '
          '(jeton $jeton != $_istekJetonu, ekrandaki=$mounted)');
      return sonuc;
    }
    await _saatDiliminiIsle(
      konum,
      konum.saatDilimi.isEmpty
          ? (sonuc.ozet?.saatDilimi ?? '')
          : konum.saatDilimi,
    );
    return sonuc;
  }

  /// Gelen doğrulanmış durumu arayüze uygular.
  void _durumuUygula(VakitDurumu d, {List<VakitGunu>? gelecekGunler}) {
    if (!mounted) return;
    aktifVakitDurumu.value = d;
    final bugun = d.bugun;
    if (bugun == null) {
      setState(() {
        _bugun = null;
        _kaynak = d.kaynak;
        _sonHata = d.hata;
        yukleniyor = false;
        if (_konum?.ulkeIso2 == 'TR' && aktifResmiDiyanet.value) {
          diyanetUyarisi = 'Resmî ve güvenilir hesaplanmış veri bulunamadı; vakit gösterilmiyor.';
        }
      });
      _widgetleriYayinla();
      return;
    }

    setState(() {
      _bugun = bugun;
      _gelecekGunler = gelecekGunler ?? d.gelecekGunler;
      _kaynak = d.kaynak;
      _ozet = d.ozet;
      _sonHata = null;
      if (!_resmiKaynak && _konum?.ulkeIso2 == 'TR' && aktifResmiDiyanet.value) {
        diyanetUyarisi = 'Resmî Diyanet verisi bugün kullanılamıyor; hesaplanmış vakitler gösteriliyor.';
      }
      miladiTarih = '${bugun.gun.toString().padLeft(2, '0')}.'
          '${bugun.ay.toString().padLeft(2, '0')}.${bugun.yil}';
      hicriTarih = bugun.hicriTarih;
      yukleniyor = false;
      hataMesaji = '';
    });

    sayaciBaslat();
    _alarmlariKur();
    _widgetleriYayinla();
  }

  /// Aylık cevaptan bugünden sonraki günleri sıralar.
  List<VakitGunu> _gelecekleriSirala(CevapGecerli cevp, DateTime bugun) {
    final s = [...cevp.gunler]..sort((a, b) => a.tarih.compareTo(b.tarih));
    final baslangic = DateTime(bugun.year, bugun.month, bugun.day);
    return s
        .where((g) =>
            g.tarih.difference(baslangic).inDays >= 0 &&
            g.tarih.difference(baslangic).inDays <= 7)
        .toList(growable: false);
  }

  /// Yedi günlük pencere ay/yıl sınırını aşarsa doğrulanmış kaydı ekler.
  /// Yalnız yükleme sırasında okunur; saniyelik sayaç disk/ağ kullanmaz.
  Future<List<VakitGunu>> _gelecekGunleriTamamla(
      Konum konum, DateTime tarih, List<VakitGunu> gunler) async {
    final sonGun = DateTime(tarih.year, tarih.month, tarih.day + 7);
    if (sonGun.month == tarih.month && sonGun.year == tarih.year) return gunler;
    final sonraki = await _depo.kayitOku(konum,
        yil: sonGun.year, ay: sonGun.month);
    if (sonraki == null) return gunler;
    final birlesik = {for (final gun in gunler) gun.tarih: gun};
    for (final gun in _gelecekleriSirala(sonraki, tarih)) {
      birlesik[gun.tarih] = gun;
    }
    return birlesik.values.toList()
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
  }

  /// Ay sonuna yaklaşınca sonraki ayı da önceden indirir.
  ///
  /// Ayın 25'inden sonrası için yapılır. Böylece gece yarısını aşan
  /// kullanıcı ertesi günün vakitlerini çevrimdışı da bulur. Hata olursa
  /// sessizce geçilir: bu bir optimizasyondur, kritik yol değildir.
  Future<void> _sonrakiAyiOndenIndir(Konum konum, DateTime suAn) async {
    // Resmî modda AĞ GEREKMEZ: veri zaten pakette, üstelik gelecek yılın
    // tamamı mevcut. Bir aylık ön indirme hem boşuna ağ yorar hem de
    // hesaplanmış önbelleği resmî veriyle karıştırma riskini doğurur.
    if (_resmiKaynak) {
      return;
    }
    final ayinGunu = suAn.day;
    if (ayinGunu < 25) return;
    final jeton = _istekJetonu;
    final sonraki = DateTime(suAn.year, suAn.month + 1, 1);
    final anahtar = konum.onbellekAnahtari(yil: sonraki.year, ay: sonraki.month);
    final islem = _onIndirmeler[anahtar] ?? _sonrakiAyiIndir(konum, sonraki);
    _onIndirmeler[anahtar] = islem;
    try {
      await islem;
    } finally {
      if (identical(_onIndirmeler[anahtar], islem)) {
        _onIndirmeler.remove(anahtar);
      }
    }
    // İndirme eski konumun önbelleğini doldurabilir; ekranı değiştiremez.
    if (!mounted || jeton != _istekJetonu || _bugun?.tarih != suAn || _resmiKaynak) return;
    final gunler = await _gelecekGunleriTamamla(konum, suAn, _gelecekGunler);
    if (!mounted || jeton != _istekJetonu || _bugun?.tarih != suAn ||
        _resmiKaynak ||
        KonumTakvimi.tarih(_konum ?? konum, uygulamaSaati) != suAn) {
      return;
    }
    if (gunler.length == _gelecekGunler.length) return;
    _gelecekGunler = gunler;
    kalanSureyiHesapla();
    _alarmlariKur();
  }

  Future<void> _sonrakiAyiIndir(Konum konum, DateTime sonraki) async {
    try {
      if (await _depo.kayitOku(konum, yil: sonraki.year, ay: sonraki.month) !=
          null) {
        return; // Zaten var.
      }
      final p = <String, String>{
        'latitude': konum.enlem.toStringAsFixed(4),
        'longitude': konum.boylam.toStringAsFixed(4),
        'month': sonraki.month.toString(),
        'year': sonraki.year.toString(),
      };
      if (konum.yontemId != null) p['method'] = konum.yontemId.toString();
      p['school'] = konum.asrYontemi.apiParametresi;
      p['latitudeAdjustmentMethod'] = konum.yuksekEnlemAyaru.apiParametresi;
      final c = await http
          .get(Uri.https('api.aladhan.com', '/v1/calendar', p),
              headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (c.statusCode != 200) return;
      await _depo.agCevabiniIsle(
        konum: konum,
        govde: c.body,
        httpDurumKodu: c.statusCode,
        istenenGun: sonraki,
      );
    } catch (_) {
      // Önden indirme başarısız olabilir; kritik değil.
    }
  }

  // 7. SAYAÇ MANTIĞI
  void sayaciBaslat() {
    // ÖNEMLİ: Bu metot vakitler her yenilendiğinde yeniden çağrılıyor.
    // Timer.periodic iptal edilmeden üstüne yeni bir tane kurulursa eskisi
    // çalışmaya devam eder.
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (timer) {
      kalanSureyiHesapla();
      _resmiKaynakYenidenDene();
    });
    kalanSureyiHesapla(); // İlk saniyeyi beklemeden hemen ilk hesaplamayı yap.
  }
// --- ARKA PLAN BİLDİRİM DÖNGÜSÜ ---
  //
  // ÖNCE (kötü): `cancelAll()` + yalnız bugünün 6 vakti + sabit ID'ler
  // (100+sıra, 200+sıra) + cıhaz saatine göre kurulum.
  //
  // ŞİMDİ:
  //   - `cancelAll()` YOK. Yalnız bu motorun yönettiği kimlikler güncellenir.
  //   - Kimlikler `tarih|vakit|tür` ücücüsünden türetilir (çakışmasız).
  //   - En az 7 gün planlanır (yalnız bugün değil) ki uygulama ertesi gün
  //     açılmasa da bildirimler gelsin.
  //   - Zamanlar SEÇİLİ ŞEHİRİNİ saat diliminde, duvar saati olarak kurulur.
  //   - Güneş doğuşu ayrı türdür ve varsayılan kapalıdır.
  Future<void> _alarmlariKur() async {
    if (!bildirimYoluCalisir()) return;
    _widgetleriYayinla();
    final konum = _konum;
    if (konum == null || _bugun == null) return;

    final sehirSaati = _sehirSaati(konum);
    if (sehirSaati == null || sehirSaati.saatDilimiCozulemedi) {
      debugEkle('saat dilimi çözülemedi, alarm kurulmadı');
      return;
    }

    // Bu çağrının SEÇİM numarası, bekleme başlamadan ÖNCE alınır: numara
    // "hangi seçim bu planı istedi" bilgisidir, "hangi çağrı ne zaman
    // döndü" bilgisi değildir. İzin sorgusu bir eklenti çağrısıdır ve
    // gecikir; geciken çağrı artarızaman eskimiştir ve planı UYGULANMAZ —
    // aksi hâlde eski şehrin alarmları yeni seçimin üzerine yazılır.
    final secim = _bildirimMotoru.yeniSecim();

    final tamZamanliVar = await _bildirimMotoru.tamZamanliIzinVar();
    if (!mounted || _bildirimMotoru.gecmisSecimMi(secim)) {
      debugEkle('geciken alarm planı atlandı: daha yeni bir seçim var');
      return;
    }

    final ozet = const BildirimPlanlayici().planla(
      konum: konum,
      sehirSaati: sehirSaati,
      // Diyanet ileri listesi bugünü içermez; Aladhan içerebilir.
      // Bugünü her zaman ekle, aynı tarihin alarmını iki kez üretme.
      gunler: {
        for (final gun in _gelecekGunler) gun.tarih: gun,
        _bugun!.tarih: _bugun!,
      }.values.toList(),
      erkenUyariDakika: erkenUyariSuresi.value,
      ayarlar: bildirimAyarlari.value,
      gunesDogumuBildirimiAcik: gunesDogumuBildirimiAcik.value,
      cevir: _cevir,
      vakitAdiCevir: _vakitAdi,
      erkenUyariMetni: _erkenUyariMetni,
      vakitMetni: _vakitMetni,
      tamZamanli: tamZamanliVar,
    );

    final sonuc = await _bildirimMotoru.uygula(ozet, secimNo: secim);

    // Uygulama sırasında daha yeni bir seçim başladıysa bu plan zaten
    // uygulanmadı; ekranda da eski "tam zamanlı" bilgisini değiştirmeyiz.
    //
    // AYNI KURAL UYARI İÇİN DE GEÇERLİ: geç kalan ya da kaldırılmış ekranın
    // planı güncel uyarıyı DEĞİŞTİRMEZ. Aksi halde "Ankara'da kurulum
    // başarısız" uyarısı, ekran kalkıp Paris'e geçtikten sonra da görünür ve
    // artık doğruyu anlatmaz.
    if (!mounted || _bildirimMotoru.gecmisSecimMi(secim)) return;

    setState(() {
      // Başarılı bir plan eski hata uyarısını TEMİZLER (`uyari == null`).
      // Uyarı motorun kendi kararıdır; burada yeniden yorumlanmaz.
      _bildirimUyarisi = sonuc.uyari;
    });

    // Tam zamanlı alarm kurulamadıysa bunu GİZLEMEYİZ. Yaklaşık alarm
    // "tam zamanlı" gibi sunulmamalıdır; kullanıcı ayarlarda uyarılır.
    if (!sonuc.tamZamanli) {
      debugEkle('tam zamanlı alarm izni yok, yaklaşık moda düşüldü');
    }
  }

  /// Çeviri metnini döndürür. Anahtar eksikse anahtar adını döner;
  /// böylece eksik çeviri sessizce boş metin olmaz.
  String _cevir(String anahtar) {
    final d = anahtar.tr();
    return d == anahtar ? anahtar : d;
  }

  /// Vakit adını çevirir (`fajr` -> "İmsak").
  String _vakitAdi(String vakitAnahtari, int _) => _cevir(vakitAnahtari);

  String _vakitMetni(String vakitAdi) => _bildirimMetinleri(
        vakitAdi: vakitAdi,
        erkenUyariMi: false,
        erkenDakika: 0,
      ).$2;

  String _erkenUyariMetni(int dakika, String vakitAdi) => _bildirimMetinleri(
        vakitAdi: vakitAdi,
        erkenUyariMi: true,
        erkenDakika: dakika,
      ).$2;

  

  // 8. ZAMAN HESAPLAMASI (İşin Beyni)
  //
  // ÖNCEKİ HÂLİ ÜÇ HATA İÇERİYORDU:
  //
  //   1) `DateTime.now()` CİHAZ saatini kullanıyordu. Cihaz İstanbul'da,
  //      seçili şehir New York'ta ise sayaç yanlış şehri gösteriyordu.
  //   2) Yatsıdan sonra "sıradaki vakit" için `Fajr + 1 gün` yapılıyordu.
  //      Bu UYDURMA bir saattir: gerçek yarının imsak saati farklıdır ve
  //      API'de/cache'te zaten vardır.
  //   3) Vakitler `int.parse(saatDakika[0])` ile okunuyordu; bozuk bir
  //      saatte RangeError/FormatException ile çöküşe yol açardı.
  //
  // ŞİMDİ: hepsi doğrulanmış [VakitGunu] kayıtlarından ve seçili şehrin
  // saat diliminden hesaplanır. Yatsıdan sonra GERÇEK yarının Fajr'ı
  // kullanılır; o gün cache'te yoksa geri sayım gösterilmez, hata verilir.
  void kalanSureyiHesapla() {
    _gunuDenetle();
    final konum = _konum;
    if (konum == null || _bugun == null) return; // Veri yoksa boşa hesap yapma.

    final sehirSaati = _sehirSaati(konum);
    if (sehirSaati == null || sehirSaati.saatDilimiCozulemedi) return;
    final simdi = sehirSaati.simdi();
    if (simdi == null) return;

    tz.TZDateTime? siradakiVakitZamani;
    String siradakiVakitAd = '';

    // Bugünün vakitlerini seçili şehrin saat diliminde sırayla gez.
    for (final alan in VakitAlani.sirali) {
      final saatMetni = _bugun!.saatler[alan.anahtar];
      if (saatMetni == null) continue;
      final z = sehirSaati.duvarSaati(
        saatMetni,
        tarih: _bugun!.tarih,
      );
      if (z == null) continue; // geçersizse atla (veri zaten doğrulandı)
      if (z.isAfter(simdi)) {
        siradakiVakitZamani = z;
        siradakiVakitAd = alan.anahtar;
        break;
      }
    }

    // Yatsı geçti: sıradaki vakit GERÇEK yarının imsağıdır.
    //
    // ÖNCE: bugünün Fajr'ına bir gün ekleniyordu. Bu, yarının imsağı
    // DEĞİLDİR; yılın 365 günü içinde imsak saati günde 1-2 dakika
    // değişir. Gerçek değer `_gelecekGunler` içinde, ertesi günün
    // kaydı olarak bulunur.
    if (siradakiVakitZamani == null) {
      final yarin = _gunIcindeTarih(sehirSaati, simdi, 1);
      final yarinGunu = _gunBul(yarin);
      if (yarinGunu == null) {
        // Gerçek yarının verisi yok (cache yetersiz ya da yeni ay).
        // UYDURMA YAPMIYORUZ: geri sayımı dondurup kullanıcıya
        // anlaşılır bir durum bildiriyoruz.
        if (!mounted) return;
        setState(() {
          siradakiVakitIsmi = '';
          kalanSureMetni = '--:--:--';
          hataMesaji = 'data_load_error'.tr();
        });
        return;
      }
      final z = sehirSaati.duvarSaati(
        yarinGunu.saatler['fajr']!,
        tarih: yarin,
      );
      if (z == null) return;
      siradakiVakitZamani = z;
      siradakiVakitAd = 'fajr';
    }

    final fark = siradakiVakitZamani.difference(simdi);
    final formatliFark =
        '${fark.inHours.toString().padLeft(2, '0')}:'
        '${(fark.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(fark.inSeconds % 60).toString().padLeft(2, '0')}';

    if (!mounted) return;
    // Saniyede iki ayrı setState YAPILMAZ. `setState` bir karede bir kez
    // çağrılır; ikinci çağrı gereksiz yeniden çizimdir.
    setState(() {
      siradakiVakitIsmi = siradakiVakitAd;
      kalanSureMetni = formatliFark;
      hataMesaji = '';
    });

  }

  /// [simdi]nın üzerine [gun] gün ekleyerek YEREL gün tarihini döner.
  DateTime _gunIcindeTarih(SehirSaati s, tz.TZDateTime simdi, int gun) {
    final d = simdi.add(Duration(days: gun));
    return DateTime(d.year, d.month, d.day);
  }

  /// Verilen günün vakit kaydını bulur: bugün ya da `_gelecekGunler`
  /// içinde. Bulunamazsa `null` döner — UYDURMA YAPILMAZ.
  VakitGunu? _gunBul(DateTime tarih) {
    if (_bugun?.tarih == tarih) return _bugun;
    for (final g in _gelecekGunler) {
      if (g.ay == tarih.month && g.gun == tarih.day && g.yil == tarih.year) {
        return g;
      }
    }
    return null;
  }

  void _zikirmatikPaneliniAc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Arka planı saydam yapıyoruz ki kendi kartımızı çizelim
      isScrollControlled: true, // Panelin yüksekliğini ayarlayabilmek için
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            _zikirPanelState = setModalState;
            bool karanlikMi = Theme.of(context).brightness == Brightness.dark;
            
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 0)],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üstteki küçük tutma çubuğu (Görsel detay)
                  Container(
                    width: 40, height: 5,
                    margin: const EdgeInsets.only(top: 10, bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                  ),
                  Text('tasbih'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // DEV ZİKİR BUTONU
                  GestureDetector(
  key: const Key('zikir_artir'),
  onTap: _zikirArtir,
  // ÇÖZÜM BURADA:
  child: Container(
    width: 250, // Genişliği artırdık
    height: 250, // Yüksekliği artırdık
    decoration: BoxDecoration(
      shape: BoxShape.circle, // Alanı yuvarlak yaptık (daha şık durur)
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05), // Çok hafif bir dolgu rengi
      // İstersen buraya bir çerçeve de ekleyebilirsin:
      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 2),
    ),
    child: Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Text(
          '$zikirSayaci',
          key: ValueKey<int>(zikirSayaci),
          style: TextStyle(
            fontSize: 80, // Sayıyı da biraz devleştirelim
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).colorScheme.primary
          ),
        ),
      ),
    ),
  ),
),
                  const SizedBox(height: 16),
                  if (zikirHedefi > 0 && zikirSayaci >= zikirHedefi)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('zikir_hedef_tamamlandi'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  // ALT BUTONLAR (Sıfırla ve Hedef)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      // SIFIRLA BUTONU
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() { zikirSayaci = 0; });
                          _zikirKaydet(0);
                          HapticFeedback.vibrate();
                        }, 
                        icon: Icon(Icons.refresh, color: karanlikMi ? Colors.white70 : Colors.black54), 
                        label: Text('reset'.tr(), style: TextStyle(color: karanlikMi ? Colors.white70 : Colors.black54))
                      ),

                      // YENİ: HEDEF BELİRLEME BUTONU (Açılır Menü)
                      PopupMenuButton<int>(
                        key: const Key('zikir_hedef_sec'),
                        initialValue: zikirHedefi,
                        onSelected: (int yeniHedef) {
                          setModalState(() { zikirHedefi = yeniHedef; });
                          _hedefKaydet(yeniHedef); // Seçilen hedefi hafızaya al
                          HapticFeedback.vibrate();
                        },
                        color: Theme.of(context).cardColor,
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                          PopupMenuItem<int>(
                              value: 33,
                              child: Text('hedef_sayisi'.tr(namedArgs: {'sayi': '33'}))),
                          PopupMenuItem<int>(
                              value: 66,
                              child: Text('hedef_sayisi'.tr(namedArgs: {'sayi': '66'}))),
                          PopupMenuItem<int>(
                              value: 99,
                              child: Text('hedef_sayisi'.tr(namedArgs: {'sayi': '99'}))),
                          PopupMenuItem<int>(
                              value: 100,
                              child: Text('hedef_sayisi'.tr(namedArgs: {'sayi': '100'}))),
                          PopupMenuItem<int>(
                              value: 500,
                              child: Text('hedef_sayisi'.tr(namedArgs: {'sayi': '500'}))),
                          PopupMenuItem<int>(
                              value: 1000,
                              child: Text('hedef_sayisi'.tr(namedArgs: {'sayi': '1000'}))),
                        ],
                        // Butonun Görünümü
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag, color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'hedef_sayisi'.tr(namedArgs: {'sayi': '$zikirHedefi'}),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                  ),
                ),
              ),
            );
          }
        );
      }
    ).whenComplete(() {
      _zikirPanelState = null;
      if (Platform.isAndroid || Platform.isIOS) PerfectVolumeControl.hideUI = false;
    });
  }

  // 9. EKRAN ÇİZİMİ (UI)
  @override
  Widget build(BuildContext context) {
    // Scaffold: Sayfanın inşaat iskelesidir (AppBar ve Body barındırır).
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _zikirmatikPaneliniAc(context),
        
        // Butonun arka plan rengi: Gündüz beyaz, Gece koyu gri
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade800 
            : Colors.white, 
            
        elevation: Theme.of(context).brightness == Brightness.dark ? 2 : 6,
        tooltip: 'tasbih'.tr(),
        
        // YENİ: Temaya göre değişen Akıllı Görsel (Adaptive Asset)
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            // Eğer karanlık moddaysak karanlık resmi, değilsek aydınlık resmi yükle
            Theme.of(context).brightness == Brightness.dark 
                ? 'assets/images/zikir_karanlik.png' 
                : 'assets/images/zikir_aydinlik.png',
            fit: BoxFit.contain, 
          ),
        ),
      ),
      appBar: AppBar(
        title: ValueListenableBuilder<Konum?>(
          valueListenable: aktifKonum,
          builder: (context, konum, child) => Text(
            konum?.ad ?? '...',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        // YENİ 1: Aydınlık modda ana renk, Karanlık modda mat ve şık bir koyu gri!
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900 
            : Theme.of(context).colorScheme.primary, 
            
        foregroundColor: Colors.white,
        
        // YENİ 2: Karanlık modda barın altındaki gölgeyi sıfırlıyoruz ki arka planla tam birleşsin
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 10,
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
            // Yeni şehir seçimi tek bir yoldan geçer: sehirAyarla() state'i
            // günceller, dinleyici vakitleri yeniler. Buradaki eski kod aynı
            // işi üç ayrı yerde yapıyordu (state + hafıza + vakit çekme) ve
            // internet yoksa geri dönüş mantığı gereksiz yere karmaşıktı.
            onPressed: () => _sehirDegistirDialog(context),
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
                  PopupMenuItem<Color>(value: const Color.fromARGB(255, 184, 8, 8), child: Text('theme_dark_crimson'.tr())),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              // Üst renk: Temanın ana renginin saydam hali (Bu zaten iyi)
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), 
              
              // YENİ ALT RENK: Karanlık modda koyu gri, aydınlıkta beyaz!
              Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white
            ],
          ),
        ),
        child: Center(
          child: yukleniyor
              ? const CircularProgressIndicator() // Yükleniyorsa dönen çark
              // Vakitler hiç yüklenemedi (internet yok ve önbellekte bu şehir
              // için kayıt bulunmuyor).
              //
              // ÖNCE: burada yalnızca `hataMesaji` doluysa hata metni
              // basılıyordu; o değişken hiçbir yerde doldurulmadığı için
              // liste çizilmeye çalışılıyor ve `vakitler!['Fajr']` null check
              // hatası verip uygulama kırmızı ekranla ÇÖKÜYORDU. İlk açılışta
              // internetsiz cihazda yani uygulamayı hiç kullanamama durumu.
              : _bugun == null
                  ? _hataEkrani(context)
                  : // Column ve Expanded yerine tüm sayfayı tek bir ListView yapıyoruz:
                   ListView(
                      padding: const EdgeInsets.only(bottom: 20), // En alta biraz boşluk
                      children: [
                        const SizedBox(height: 20),

                        _anaSayacKarti(), // Ana Sayaç
                        _veriKaynagiSeridi(), // Önbellek/ağ + güncelleme zamanı
                        _diyanetUyarisiSeridi() ?? const SizedBox.shrink(),
                        _hesapYontemiSeridi(), // Görünür ve doğrulanmış yöntem
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
                        _vakitKarti(_cevir('fajr'), _vakitSaatleri!['fajr'], Icons.nights_stay, siradakiVakitIsmi == 'fajr'),
                        _vakitKarti(_cevir('sunrise'), _vakitSaatleri!['sunrise'], Icons.wb_sunny_outlined, siradakiVakitIsmi == 'sunrise'),
                        _vakitKarti(_cevir('dhuhr'), _vakitSaatleri!['dhuhr'], Icons.wb_sunny, siradakiVakitIsmi == 'dhuhr'),
                        _vakitKarti(_cevir('asr'), _vakitSaatleri!['asr'], Icons.wb_twilight, siradakiVakitIsmi == 'asr'),
                        _vakitKarti(_cevir('maghrib'), _vakitSaatleri!['maghrib'], Icons.nightlight_round, siradakiVakitIsmi == 'maghrib'),
                        _vakitKarti(_cevir('isha'), _vakitSaatleri!['isha'], Icons.bedtime, siradakiVakitIsmi == 'isha'),
                      ],
                    ),
                    ),
        ),
    );
  }

  /// Verinin nereden geldiğini ve ne zaman tazelendiğini gösteren ince şerit.
  ///
  /// Kullanıcı "bu vakitler ne zaman güncellendi?" ve "internetsiz mi
  /// gösteriyorum?" sorularını cevapsız bırakmamalı. Önceden hiçbir
  /// göstergesi yoktu: kullanıcı ekranın açılmasının nedenini bilmiyordu.
  Widget _veriKaynagiSeridi() {
    final karanlikMi = Theme.of(context).brightness == Brightness.dark;
    final renk = karanlikMi ? Colors.white38 : Colors.black38;

    // --- RESMÎ DİYANET: etiket kaynağa göre dürüst kalır ---
    //
    // "Diyanet" yazısı YALNIZCA gerçekten Diyanet tablosundan bir satır
    // geldiğinde görünür. Hesaplanmış veride görünmez; onun yerine
    // hesaplanmış kaynak yazılır. Bu ayrım, kullanıcının ekranda gördüğü
    // saatin Diyanet'in saatı olup olmadığını bilmesini sağlar.
    final resmiMi = _resmiKaynak;
    final paket = _diyanet?.paket;
    final kaynakEtiketi = _kaynak == VakitKaynagi.resmiDiyanetGuncel
        ? 'kaynak_diyanet_guncel'.tr()
        : resmiMi
        ? '${'kaynak_diyanet'.tr()}'
            '${paket == null ? '' : ' (${paket.ilkTarih.toIso8601String().split('T').first} – ${paket.sonTarih.toIso8601String().split('T').first})'}'
        : _kaynak == VakitKaynagi.ag
            ? '${'kaynak_hesaplanmis'.tr()} · ${'data_source_live'.tr()}'
            : '${'kaynak_hesaplanmis'.tr()} · ${'data_source_cache'.tr()}';

    final String zamanMetni;
    if (_kaynak == VakitKaynagi.resmiDiyanetGuncel) {
      final String nereden = _resmiAg?.onbellekten == true
          ? 'kaynak_resmi_onbellek'.tr()
          : 'kaynak_resmi_web'.tr();
      zamanMetni = '$nereden · ${'kaynak_alindi'.tr(namedArgs: {
        'tarih': _resmiAg?.indirildi.toIso8601String() ?? '',
      })}';
    } else if (resmiMi) {
      // Resmî veri uygulamanın içindedir; "şimdi güncellendi" gibi bir
      // zaman damgası YANLIŞ olur. Paket sürümü dürüst bilgidir.
      zamanMetni = paket == null
          ? 'data_source_unknown'.tr()
          : 'kaynak_surum_ve_tarih'.tr(
              namedArgs: {'surum': paket.surum, 'tarih': paket.edinmeTarihi});
    } else {
      final ozet = _ozetVeri;
      if (ozet == null) {
        zamanMetni = 'data_source_unknown'.tr();
      } else {
        final fark = DateTime.now().difference(ozet.indirildi);
        zamanMetni = fark.inMinutes < 1
            ? 'data_updated_now'.tr()
            : fark.inHours < 1
                ? 'data_updated_minutes'.tr(args: ['${fark.inMinutes}'])
                : fark.inDays < 1
                    ? 'data_updated_hours'.tr(args: ['${fark.inHours}'])
                    : 'data_updated_days'.tr(args: ['${fark.inDays}']);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            resmiMi
                ? Icons.verified_outlined
                : _kaynak == VakitKaynagi.ag
                    ? Icons.cloud_done_outlined
                    : Icons.offline_bolt_outlined,
            size: 14,
            color: resmiMi
                ? (karanlikMi ? Colors.tealAccent : Colors.teal.shade700)
                : renk,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$kaynakEtiketi · $zamanMetni',
              style: TextStyle(fontSize: 11, color: resmiMi ? renk : renk),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Resmî veri neden kullanılmadı? Kullanıcıya AÇIKÇA söyler.
  ///
  /// Bu şerit "Diyanet" etiketi taşımaz. Kapsam dışı ya da paketteki
  /// boşlukta vakitler GÖSTERİLMEZ; yerleşimin resmî kaydı yoksa
  /// hesaplanmış saatler gösterilir ama kaynak "hesaplanmış" olarak yazılır.
  Widget? _diyanetUyarisiSeridi() {
    if (diyanetUyarisi.isEmpty) return null;
    final karanlikMi = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: karanlikMi ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              diyanetUyarisi,
              style: TextStyle(fontSize: 11.5, color: karanlikMi
                  ? Colors.orange.shade100
                  : Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  /// Hesaplama yöntemini AÇIKÇA gösterir.
  ///
  /// Otomatik modda sağlayıcının gerçekte neyi seçtiği (`meta.method.id`)
  /// gösterilir. Bu, "resmî yöntem" iddiasında bulunmadan kullanıcının
  /// hangi hesapla vakitlerin geldiğini bilmesini sağlar.
  ///
  /// Yüksek enlem ve Asr ayarları da gizli varsayılan olarak bırakılmaz.
  Widget _hesapYontemiSeridi() {
    final karanlikMi = Theme.of(context).brightness == Brightness.dark;
    final renk = karanlikMi ? Colors.white38 : Colors.black38;
    final konum = _konum;
    if (konum == null) return const SizedBox.shrink();

    final yontemMetni = _resmiKaynak ? 'kaynak_diyanet'.tr() : konum.yontemId == null
        // Otomatik mod: Aladhan'ın seçtiği yöntem gösterilir.
        ? 'method_auto_with_result'.tr(
            args: [yontemAdi(_donenYontemId) ?? 'method_auto'.tr()])
        : (yontemAdi(konum.yontemId) ?? '${konum.yontemId}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calculate_outlined, size: 14, color: renk),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  yontemMetni,
                  style: TextStyle(fontSize: 11, color: renk),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // Yüksek enlem ayarı sessiz varsayım olarak kalmasın.
          if (konum.enlem.abs() >= 48)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'high_latency_setting'.tr(args: [konum.yuksekEnlemAyaru.ad]),
                style: TextStyle(fontSize: 10, color: renk),
                textAlign: TextAlign.center,
              ),
            ),
          // RESMÎ MODDA HESAPLAMA AYARLARI UYGULANMAZ — nedeni yazılır.
          //
          // Kullanıcı Asr ya da yüksek enlem ayarını değiştirdiğinde
          // vakitlerin DEĞİŞMEDİĞINI görecektir. Bu bir hata gibi görünür;
          // o yüzden nedeni ekranda açıkça söylenir: resmî tabloda bu
          // ayarların karşılığı yoktur, Diyanet tek tablo yayımlar.
          if (_resmiKaynak)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'resmi_not_asr_enlem'.tr(),
                style: TextStyle(fontSize: 10, color: renk),
                textAlign: TextAlign.center,
              ),
            ),
          // Bildirim durumu uyarısı. HANGİ durumun olduğu motorun kararıdır
          // (`_bildirimUyarisi`); burada yalnız metni çizilir.
          //
          // Önceden yalnız `_tamZamanliAlarm` denetleniyordu ve TEK sabit metin
          // çiziliyordu: "tam zamanlı alarm izni yok — bildirimler yaklaşık
          // zamanlı gelir". Kurulum tamamen başarısız olduğunda HİÇBİR alarm
          // kurulmaz ama aynı metin çıkardı; kullanıcı bildirimlerin geleceğini
          // sanıyordu. Artık kurulum hatası ile iptal hatası AYRI gösterilir
          // ve hiçbiri teslim vaadi vermez.
          if (_bildirimUyarisi != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kurulum/iptal hatası "sadece bir kısıt" değil, kullanıcının
                  // vakit bildirimlerini kaçırabileceği gerçek bir sorundur.
                  Icon(Icons.warning_amber_rounded,
                      size: 14,
                      color: _bildirimUyarisi == 'exact_alarm_yok'
                          ? Colors.orange.shade700
                          : Colors.redAccent.shade700),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _bildirimUyarisiMetni ?? '',
                      style: TextStyle(
                          fontSize: 11,
                          color: _bildirimUyarisi == 'exact_alarm_yok'
                              ? Colors.orange.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Vakitler yüklenemediğinde gösterilen ekran.
  ///
  /// Önceden bu durum hiç işlenmiyordu: `build` yüklenme bittiğinde doğrudan
  /// vakit kartlarını çizmeye geçiyordu ve `vakitler` null olduğu için
  /// uygulama çöküyordu. Kullanıcı internetsiz ilk açılışta uygulamayı hiç
  /// kullanamıyordu.
  ///
  /// Burada iki şey önemli: kullanıcıya ne olduğu söyleniyor ve elinde tek bir
  /// işlem olduğu için "Tekrar dene" sunuluyor. İnternet gelince tek
  /// dokunuşla vakitler yeniden çekilir.
  Widget _hataEkrani(BuildContext context) {
    final bool karanlikMi = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: karanlikMi ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 20),
          Text(
            'data_load_error'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: karanlikMi ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hataMesaji.isNotEmpty
                ? hataMesaji
                : 'no_internet_city'.tr(args: [_sehirAdi]),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: karanlikMi ? Colors.white60 : Colors.black54,
            ),
          ),
          // REDDEDİLEN CEVABIN GEREKÇESİ
          //
          // Önceden reddedilen cevap sessizce kayboluyordu: ekranda
          // yalnız "veri yüklenemedi" yazıyordu, kullanıcı nedenini
          // bilmiyordu. Burada gerekçe ve varsa teknik ayrıntı gösterilir.
          if (_sonHata != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: karanlikMi ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _sonHataSebebiMetni(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: karanlikMi ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (_sonHata!.ayrinti != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _sonHata!.ayrinti!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: karanlikMi ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _yenidenDene,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }

  /// Reddedilen cevabin gerekcesini kullanici diline cevirir.
  ///
  /// Kullanici "veri neden yuklenmedi" sorusunun cevabini gormelidir;
  /// aksi halde uygulama sebebi gizliyor olur.
  String _sonHataSebebiMetni() {
    return switch (_sonHata!.sebep) {
      RedSebebi.httpHatasi => 'reject_http'.tr(),
      RedSebebi.mantiksalHata => 'reject_logic'.tr(),
      RedSebebi.veriYok => 'reject_empty'.tr(),
      RedSebebi.tarihAyligiBozuk => 'reject_date_broken'.tr(),
      RedSebebi.ayYilBesiIlMi => 'reject_month_mismatch'.tr(),
      RedSebebi.koordinatBesiIlMi => 'reject_coords_mismatch'.tr(),
      RedSebebi.saatDilimiYok => 'reject_tz_missing'.tr(),
      RedSebebi.saatDilimiCozulemedi => 'reject_tz_unknown'.tr(),
      RedSebebi.yontemBesiIlMi => 'reject_method_mismatch'.tr(),
      RedSebebi.vakitAlaniEksik => 'reject_field_missing'.tr(),
      RedSebebi.saatBicimiBozuk => 'reject_time_format'.tr(),
      RedSebebi.saatAralikBozuk => 'reject_time_range'.tr(),
      RedSebebi.sifirSaat => 'reject_zero_time'.tr(),
      RedSebebi.gunBulunamadi => 'reject_day_missing'.tr(),
    };
  }

  /// "Tekrar dene" düğmesi: önceki hata mesajını temizleyip vakitleri yeniden
  /// çeker. `vakitleriGetir` yüklenme durumunu kendi yönetir.
  Future<void> _yenidenDene() async {
    if (!mounted) return;
    setState(() {
      hataMesaji = '';
      _sonHata = null;
    });
    if (_yuklenenJeton != null) return;
    await _verileriYukle();
  }

  Widget _anaSayacKarti() {
    // O anki temanın karanlık olup olmadığını tespit ediyoruz
    bool karanlikMi = Theme.of(context).brightness == Brightness.dark;
    
    // Göz yormaması için Karanlık Modda saf beyaz yerine yumuşak gri tonları kullanıyoruz
    Color anaMetinRengi = karanlikMi ? Colors.grey.shade300 : Colors.white;
    Color altMetinRengi = karanlikMi ? Colors.grey.shade400 : Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: karanlikMi 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.6) 
            : Theme.of(context).colorScheme.primary,
        elevation: karanlikMi ? 2 : 6,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text('$miladiTarih', style: TextStyle(fontSize: 16, color: altMetinRengi)),
              Text('${siradakiVakitIsmi.tr()} ${"time_remaining".tr()}', style: TextStyle(fontSize: 16, color: altMetinRengi)),
              const SizedBox(height: 10),
              Text(
                kalanSureMetni, 
                style: TextStyle(
                  fontSize: 50, 
                  fontWeight: FontWeight.bold, 
                  color: anaMetinRengi, // Parlamayan, yumuşatılmış ana renk
                  letterSpacing: 2
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vakitKarti(String isim, String? saat, IconData ikon, bool aktifMi) {
    bool karanlikMi = Theme.of(context).brightness == Brightness.dark;

    // YENİ: Aktif kart belirgin olsun, pasif kartlar Colors.white yerine temaya uysun!
    Color kartRengi = aktifMi 
        ? Theme.of(context).colorScheme.primaryContainer 
        : Theme.of(context).cardColor; 

    // YENİ: Yazı rengi de karanlık/aydınlık moda göre otomatik şekillensin
    Color yaziRengi = aktifMi 
        ? Theme.of(context).colorScheme.onPrimaryContainer 
        : (karanlikMi ? Colors.white70 : Colors.black87);

    return Card(
      color: kartRengi,
      elevation: karanlikMi ? 1 : 4, // Karanlıkta gölgeyi kısıyoruz ki parlamasın
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

    final suAn = _bugun?.tarih ?? _sehirSaati(_konum)?.bugun() ?? uygulamaSaati.simdi();
    final yilinIlkGunu = DateTime.utc(suAn.year, 1, 1);
    final int kacinciGun = DateTime.utc(suAn.year, suAn.month, suAn.day).difference(yilinIlkGunu).inDays;

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

    final suAn = _bugun?.tarih ?? _sehirSaati(_konum)?.bugun() ?? uygulamaSaati.simdi();
    final yilinIlkGunu = DateTime.utc(suAn.year, 1, 1);
    final int kacinciGun = DateTime.utc(suAn.year, suAn.month, suAn.day).difference(yilinIlkGunu).inDays;

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
  int zikirSayaci = 0;
  int zikirHedefi = 33; // YENİ: Varsayılan hedef 33

  // Mevcut _zikirYukle fonksiyonunu şu şekilde güncelle:
  Future<void> _zikirYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      zikirSayaci = prefs.getInt('kayitli_zikir') ?? 0;
      zikirHedefi = prefs.getInt('kayitli_hedef') ?? 33; // Hedefi de hafızadan çek
    });
    _zikirPanelState?.call(() {});
  }
}
// 4. DURUMU DEĞİŞEBİLEN EKRAN (StatefulWidget)
// API'den veri gelince ve sayaç her saniye aktığında ekranın güncellenmesi gerektiği için bunu kullanıyoruz.
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key, this.guncelDiyanet});
  final DiyanetGuncelDepo? guncelDiyanet;

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}
/// Yasam dongusu gozlemcisi.
///
/// `didChangeAppLifecycleState` uygulamanin arka plandan one
/// gelmesini bildirir. Bu State'e baglanir ve `dispose` icinde
/// kaldirilir; birakildigi surece State sizdirir.
class _Gozlemci extends WidgetsBindingObserver {
  _Gozlemci(this._durum);
  final _AnaSayfaState _durum;

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    _durum.yasamDongusuDurumuDegisti(durum);
  }
}
