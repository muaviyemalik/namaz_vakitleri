// lib/main.dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:easy_localization/easy_localization.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart' show PlanSirasi;
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/core/vakit_verisi.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';
import 'package:namaz_vakitleri/utils/iso1_yerellestirme.dart';

// --- SAYFALARIMIZ ---
import 'pages/anasayfa.dart';
import 'pages/ozelGunler_sayfasi.dart';
import 'pages/kible_sayfasi.dart';
import 'pages/ayarlar_sayfasi.dart';

// --- GLOBAL DEĞİŞKENLER (Tema ve Bildirim Motoru) ---

/// Resmî Diyanet veri deposu. Tek örnek; tüm ekranlar ve widget bu
/// örneği kullanır, böylece ana ekran / geri sayım / bildirim / widget
/// AYNI kaynaktan beslenir.
final DiyanetDepo diyanetDepo = DiyanetDepo();

/// Türkiye'de resmî Diyanet verisi kullanılsın mı?
///
/// Varsayılan `true`: hedef budur. Kullanıcı kapatırsa mevcut Aladhan
/// hesaplama akışı DEVAM EDER — bu akış korunur, yalnız varsayılan değildir.
///
/// Bu tercih [Konum.resmiDiyanetKullanilirMi]'ne DIŞARIDAN verilir; konum
/// modeli kullanıcı tercihini bilmez.
final ValueNotifier<bool> aktifResmiDiyanet = ValueNotifier<bool>(true);

Future<void> resmiDiyanetKaydet(bool acik) async {
  aktifResmiDiyanet.value = acik;
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setBool(kayitliResmiDiyanetAnahtari, acik);
}

final ValueNotifier<Color> seciliTemaRengiAydinlik = ValueNotifier<Color>(Colors.teal); // Gündüz rengi
final ValueNotifier<Color> seciliTemaRengiKaranlik = ValueNotifier<Color>(Colors.indigo); // Gece rengi
final ValueNotifier<ThemeMode> aktifTemaModu = ValueNotifier<ThemeMode>(ThemeMode.light);
// Bildirim eklentisi.
//
// Üretimde her zaman gerçek eklentidir. Testte değiştirilebilmesi için
// `final` DEĞİLDİR: AnaSayfa'nın bildirim yolu (izin → plan → motor →
// kalıcı kimlik dizini) ancak GERÇEK çağıran ve GERÇEK motor ile
// ölçülebilir. Testler bu değişkeni kayıt tutan sahte bir eklentiye bağlar;
// sahte olan yalnız taşımadır (sistem yazma/iptal), karar kodu üretimdeki
// ile birebir aynıdır.
FlutterLocalNotificationsPlugin bildirimServisi = FlutterLocalNotificationsPlugin();

/// Bildirim eklentisini değiştirir (yalnız testler için).
///
/// Üretimde çağrılmaz. Testler `tearDown`'de `bildirimServisiDegistir`
/// ile kullandıkları sahte eklentiyi temizler.
void bildirimServisiDegistir(FlutterLocalNotificationsPlugin yeni) {
  bildirimServisi = yeni;
}

/// Zamanlanmış bildirim yolunun açık olup olmadığı.
///
/// `null` (üretim) = platform kuralı: yalnız Android ve iOS'ta
/// `flutter_local_notifications` alarm kurabildiği için masaüstünde bu yol
/// çalıştırılmaz.
///
/// NEDEN `Platform` DEĞİL DE BU? AnaSayfa'nın planlama kapısı üretimde
/// `Platform.isAndroid/isIOS` idi. Bu koşul Windows'ta `false` olduğu için
/// `flutter test` sayfa → bildirim motoru bağlantısına HİÇ giremiyordu:
/// entegrasyon yalnız gözle doğrulanabiliyordu. Aynı kararın tek yerden,
/// üretimde aynı sonucu veren ve testte ölçülebilen bir yerden okunması,
/// davranışı değiştirmeden kapıyı açar.
bool? _bildirimYoluTasarimi;

/// Testte platform kuralının yerine geçer. Üretimde çağrılmaz.
void bildirimYoluTasarimiAyarla(bool? deger) {
  _bildirimYoluTasarimi = deger;
}

/// [bildirimYoluTasarimi] varsa onu, yoksa platform kuralını döndürür.
bool bildirimYoluCalisir() =>
    _bildirimYoluTasarimi ?? (Platform.isAndroid || Platform.isIOS);

/// Bildirim planına yazma hakkının sırası: UYGULAMA GENELİNDE TEK ÖRNEK.
///
/// Neden tek? Bildirim eklentisindeki bekleyen bildirimler ve kalıcı kimlik
/// dizini uygulama genelinde tek kopyadır. `AnaSayfa` her açılışta kendi
/// `BildirimMotoru` örneğini kurar; iki ekran aynı anda varsa iki motor ama
/// tek eklenti ve tek kalıcı dizin vardır. Sıra motor örneğinde kalsaydı
/// KALDIRILMIŞ ekranın geç kalan planı "daha yeni seçim yok" diye kendini
/// geçerli sayar, ekranda Paris yarken cihazda Ankara alarmları kalırdı.
/// Ölçüm: `test/ana_sayfa_bildirim_test.dart`.
///
/// `final` DEĞİLDİR: her test kendi temiz sırasıyla başlamalıdır. Testler
/// `tearDown`'de üretimdeki tek örneği geri koyar.
PlanSirasi bildirimPlanSirasi = PlanSirasi();

/// Bildirim plan sırasını değiştirir (yalnız testler için).
void bildirimPlanSirasiDegistir(PlanSirasi yeni) {
  bildirimPlanSirasi = yeni;
}

//Erken Uyarı Sistemi için
final ValueNotifier<int> erkenUyariSuresi = ValueNotifier<int>(0);

// Güneş doğuşu bilgi bildirimi. Varsayılan KAPALI: güneş doğuşu bir
// namaz vakti değildir ve "vakit geldi" diye bildirilmemelidir. Kullanıcı
// ayarlardan açabilir.
final ValueNotifier<bool> gunesDogumuBildirimiAcik = ValueNotifier<bool>(false);

// Uygulamanın kullandığı tek saat kaynağı. Üretimde duvar saati okunur.
//
// Testte [SabitSaat] ile değiştirilir (bkz. [saatKaynagiDegistir]). Bu yüzden
// `final` DEĞİLDİR: "gece yarısı geçti", "ay değişti", "iki şehir farklı
// takvim gününde" gibi senaryolar gerçek sistem saatine bağlı olmadan
// ölçülebilmelidir. Testler bunu `tearDown`'de [GercekSaat]'e döndürür.
Saat uygulamaSaati = const GercekSaat();

/// Uygulamanın saat kaynağını değiştirir (yalnız testler için).
///
/// Üretimde değiştirilmez: [main] her zaman [GercekSaat] ile başlar.
void saatKaynagiDegistir(Saat kaynak) {
  uygulamaSaati = kaynak;
}

// --- KONUM (ÜLKE / ŞEHİR) DURUMU ---
// Seçilen ülkenin ISO 3166-1 alpha-2 kodu (örn. "TR"). Varsayılan Türkiye.
final ValueNotifier<String> aktifUlkeKodu = ValueNotifier<String>('TR');

// Seçilen KONUM. Şehir adı + ülke + koordinat + IANA saat dilimi +
// hesaplama yöntemi + Asr/yüksek enlem ayarları TEK modelde tutulur.
//
// Bu tek model önceden ikiye bölünmüştü: `aktifSehir` yalnız ad ve
// koordinat tutuyordu, saat dilimi `tz.local` içinde gizliydi. Bu ayrılık
// yüzünden cihaz saatiyle şehir saati karışıyordu.
final ValueNotifier<Konum?> aktifKonum = ValueNotifier<Konum?>(null);

const String kayitliUlkeAnahtari = 'secili_ulke_kodu';
const String kayitliKonumAnahtari = 'secili_konum_veri';

// Resmî Diyanet modu açık mı? Kayıt yoksa VARSAYILAN açıktır: hedef,
// Türkiye'de Diyanet'in yayımladığı vakitlerin gösterilmesidir.
const String kayitliResmiDiyanetAnahtari = 'resmi_diyanet_acik';
const String kayitliYontemAnahtari = 'secili_hesaplama_yontemi';
const String kayitliAsrAnahtari = 'secili_asr_yontemi';
const String kayitliYuksekEnlemAnahtari = 'secili_yuksek_enlem';
const String kayitliGunesDogumuAnahtari = 'secili_gunes_dogumu_bildirimi';

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

// Asr ve yüksek enlem ayarları. Bu ikisi vakitleri değiştirir, bu yüzden
// gizli varsayılan olarak bırakılmaz: hem modelde hem önbellek anahtarında
// bulunur ve kullanıcıya gösterilir.
final ValueNotifier<AsrYontemi> aktifAsrYontemi =
    ValueNotifier<AsrYontemi>(AsrYontemi.standart);
final ValueNotifier<YuksekEnlemAyaru> aktifYuksekEnlemAyaru =
    ValueNotifier<YuksekEnlemAyaru>(YuksekEnlemAyaru.orta);

Future<void> hesaplamaYontemiKaydet(int? yontemId) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  if (yontemId == null) {
    await hafiza.remove(kayitliYontemAnahtari);
  } else {
    await hafiza.setInt(kayitliYontemAnahtari, yontemId);
  }
}

// Seçilen konumu cihazda saklar. Saat dilimi biliniyorsa o da yazılır;
// bilinmiyorsa boş bırakılır ve ilk cevaptan sonra kesinleştirilir.
//
// Altıncı ve yedinci alan resmî Diyanet kimliğidir (il adı ve CityID).
// ESKİ KAYITLARDA YOKTUR; okunduğunda boş gelirler ve konum yeniden
// eşlenir (bkz. konumYukle). Kullanıcının mevcut verisi SİLİNMEZ.
Future<void> konumKaydet(Konum konum) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setString(
    kayitliKonumAnahtari,
    '${konum.ad}|${konum.ulkeIso2}|${konum.enlem}|${konum.boylam}|${konum.saatDilimi}'
    '|${konum.il}|${konum.diyanetCityId ?? ''}',
  );
}

Future<void> ulkeKaydet(String iso2) async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.setString(kayitliUlkeAnahtari, iso2);
}

/// Seçili konumu TEMİZLER.
///
/// Şehir verisi olmayan bir ülke seçildiğinde çağrılır. Kayıtlı konum
/// silinmezse uygulama bir sonraki açılışta eski şehri geri getirir ve
/// kullanıcı yine yanlış yerde sanar. Bu yüzden hem state hem kayıt
/// temizlenir; ekranda "veri yok" hatası ve GPS/geri dönüş yolu sunulur.
Future<void> konumKaydetTemizle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();
  await hafiza.remove(kayitliKonumAnahtari);
}

/// Yeni konum seçildiğinde çağrılır.
///
/// [sehir] veri setinden gelen kayıttır. Saat dilimi daha önce bu
/// koordinat için doğrulanmışsa ([VakitDepo.kayitliSaatDilimi]) hemen
/// bilinir; bilinmiyorsa boş bırakılır ve `KonumTakvimi` boylama dayalı
/// tahminle hangi ayın isteneceğini belirler. Cevap gelince
/// [konumSaatDilimiKesinlestir] ile kesinleştirilir.
Future<void> konumAyarla(Sehir sehir) async {
  final depo = VakitDepo(saat: uygulamaSaati);
  final kimlik = await diyanetKimligiCoz(sehir);
  final kayitliTz = await depo.kayitliSaatDilimi(Konum(
    ad: sehir.ad,
    ulkeIso2: aktifUlkeKodu.value,
    enlem: sehir.enlem,
    boylam: sehir.boylam,
    // Bu çağrı yalnız anahtar üretmek içindir; saat dilimi burada
    // BİLEREK boş bırakılıyor, çünkü aranan değer de tam olarak budur.
    saatDilimi: '',
    yontemId: aktifHesaplamaYontemi.value,
  ));

  final konum = Konum(
    ad: sehir.ad,
    ulkeIso2: aktifUlkeKodu.value,
    enlem: sehir.enlem,
    boylam: sehir.boylam,
    saatDilimi: kayitliTz ?? '',
    yontemId: aktifHesaplamaYontemi.value,
    asrYontemi: AsrYontemi.values.byName(
        aktifAsrYontemi.value.name),
    yuksekEnlemAyaru: aktifYuksekEnlemAyaru.value,
    il: sehir.il.isEmpty ? kimlik.il : sehir.il,
    diyanetCityId: kimlik.cityId,
    diyanetParca: kimlik.parca,
  );

  if (aktifKonum.value == konum) return; // Değişiklik yok.
  aktifKonum.value = konum;
  await konumKaydet(konum);
}

/// Bir şehir kaydının resmî Diyanet kimliği.
class DiyanetKimlik {
  final int? cityId;
  final String? parca;
  final String il;

  const DiyanetKimlik({this.cityId, this.parca, this.il = ''});

  static const DiyanetKimlik yok = DiyanetKimlik();
}

/// [sehir] kaydının resmî Diyanet kimliğini çözer.
///
/// Bu bir İSİM EŞLEŞMESİDİR ama çalışma anında değil, paket üretiminde
/// (`tool/diyanet_verisi_uret.py`) yapılmıştır; burada yalnız hazır anahtar
/// tablosu okunur. Anahtar KESİNTİR: normalize edilmiş il + ad. Birden çok
/// aday varsa veya aday yoksa `cityId` boş kalır; uygulama o yerleşim için
/// il merkezinin vakitlerini KOPYALAMAZ, "resmî veri yok" der.
Future<DiyanetKimlik> diyanetKimligiCoz(Sehir sehir) async {
  if (aktifUlkeKodu.value != 'TR') return DiyanetKimlik.yok;
  if (sehir.il.isEmpty) return DiyanetKimlik.yok;
  final e = await diyanetDepo.eslemeBul(il: sehir.il, ad: sehir.ad);
  // Parça adı eşleme dosyasından gelir; burada yeniden hesaplanmaz.
  if (e == null || e.parca.isEmpty) return DiyanetKimlik(il: sehir.il);
  return DiyanetKimlik(cityId: e.cityId, parca: e.parca, il: sehir.il);
}

/// API'den `meta.timezone` geldiğinde konumun saat dilimini kesinleştirir.
///
/// Önceden burada `tz.setLocalLocation()` çağrılıyordu, yani GLOBAL
/// `tz.local` değiştiriliyordu. Bunun iki sakıncası vardı:
///   1) Uygulamanın geri kalanı o global duruma bağımlı hale geliyordu;
///      iki şehrin aynı anda doğru hesaplanması imkânsızlaşıyordu.
///   2) Cihazın saat dilimi bilinmiyorsa Türkiye'ye sessizce düşülüyordu.
///
/// Artık `tz.local` HİÇ DEĞİŞTİRİLMEZ. Saat dilimi konumun kendi
/// alanıdır ve fonksiyonlara açıkça geçirilir.
Future<void> konumSaatDilimiKesinlestir(String iana) async {
  if (iana.trim().isEmpty) return;
  if (uygulamaSaati.konumBul(iana) == null) {
    debugEkle('bilinmeyen saat dilimi, yoksayıldı: $iana');
    return;
  }
  final mevcut = aktifKonum.value;
  if (mevcut == null || mevcut.saatDilimi == iana) return;
  final yeni = mevcut.kopyala(saatDilimi: iana);
  aktifKonum.value = yeni;
  await konumKaydet(yeni);
}

// Kayıtlı ülke, konum, yöntem ve ayarları cihazdan okur.
Future<void> konumYukle() async {
  final SharedPreferences hafiza = await SharedPreferences.getInstance();

  final String? ulke = hafiza.getString(kayitliUlkeAnahtari);
  if (ulke != null && ulke.length == 2) aktifUlkeKodu.value = ulke;

  // Hesaplama yöntemi: kayıt yoksa otomatik (null) kullanılır.
  aktifHesaplamaYontemi.value = hafiza.getInt(kayitliYontemAnahtari);

  aktifAsrYontemi.value = _asrOku(hafiza.getString(kayitliAsrAnahtari));
  aktifYuksekEnlemAyaru.value =
      _yuksekEnlemOku(hafiza.getString(kayitliYuksekEnlemAnahtari));
  gunesDogumuBildirimiAcik.value =
      hafiza.getBool(kayitliGunesDogumuAnahtari) ?? false;

  // Resmî Diyanet modu: kayıt yoksa AÇIK (varsayılan).
  aktifResmiDiyanet.value = hafiza.getBool(kayitliResmiDiyanetAnahtari) ?? true;

  final String? ham = hafiza.getString(kayitliKonumAnahtari);
  if (ham != null) {
    final parca = ham.split('|');
    if (parca.length >= 4) {
      final enlem = double.tryParse(parca[2]);
      final boylam = double.tryParse(parca[3]);
      if (enlem != null && boylam != null && parca[0].isNotEmpty) {
        // Altıncı alan il, yedinci alan resmî CityID'dir. ESKİ KAYITLARDA
        // YOKTUR. Bu durumda konum yine de yüklenir (kullanıcının verisi
        // silinmez) ama resmî kimlik boş kalır; aşağıda il bilgisi elde
        // edilirse kimlik yeniden çözülür.
        final il = parca.length >= 6 ? parca[5] : '';
        final kayitliId =
            parca.length >= 7 ? int.tryParse(parca[6]) : null;
        aktifKonum.value = Konum(
          ad: parca[0],
          ulkeIso2: parca[1].isEmpty ? aktifUlkeKodu.value : parca[1],
          enlem: enlem,
          boylam: boylam,
          // Beşinci alan saat dilimidir. Eski kayıtlarda yoktur; o
          // durumda boş bırakılır ve tahmin devreye girer.
          saatDilimi: parca.length >= 5 ? parca[4] : '',
          yontemId: aktifHesaplamaYontemi.value,
          asrYontemi: aktifAsrYontemi.value,
          yuksekEnlemAyaru: aktifYuksekEnlemAyaru.value,
          il: il,
          diyanetCityId: kayitliId,
        );
        // Resmî kimlik kayıtlı değilse (eski kurulum) burada sessizce
        // vazgeçilmez: kimlik çözülebilirse çözülür.
        if (kayitliId == null && il.isNotEmpty) {
          final e = await diyanetDepo.eslemeBul(il: il, ad: parca[0]);
          if (e != null && e.parca.isNotEmpty) {
            aktifKonum.value = aktifKonum.value!
                .kopyala(diyanetCityId: e.cityId, diyanetParca: e.parca);
            await konumKaydet(aktifKonum.value!);
          }
        }
      }
    }
  }

  if (aktifKonum.value == null) {
    // Ankara'nın koordinatları: Türkiye'de makul bir başlangıç noktası.
    // Saat dilimi BİLİNÇLİ OLARAK boş bırakılır: ilk cevap gelene kadar
    // tahmin kullanılır, cihaz saatine sessizce düşülmez.
    aktifKonum.value = Konum(
      ad: 'Ankara',
      ulkeIso2: 'TR',
      enlem: 39.9334,
      boylam: 32.8597,
      saatDilimi: '',
      yontemId: aktifHesaplamaYontemi.value,
      asrYontemi: aktifAsrYontemi.value,
      yuksekEnlemAyaru: aktifYuksekEnlemAyaru.value,
      il: 'Ankara',
    );
    // Ankara resmî katalogda vardır; kimlik ilk açılışta çözülür.
    final e = await diyanetDepo.eslemeBul(il: 'Ankara', ad: 'Ankara');
    if (e != null && e.parca.isNotEmpty) {
      aktifKonum.value =
          aktifKonum.value!.kopyala(diyanetCityId: e.cityId, diyanetParca: e.parca);
    }
  }
}

AsrYontemi _asrOku(String? kod) => AsrYontemi.values
    .firstWhere((a) => a.kod == kod, orElse: () => AsrYontemi.standart);

YuksekEnlemAyaru _yuksekEnlemOku(String? kod) => YuksekEnlemAyaru.values
    .firstWhere((a) => a.kod == kod, orElse: () => YuksekEnlemAyaru.orta);

Future<void> asrYontemiKaydet(AsrYontemi a) async {
  final h = await SharedPreferences.getInstance();
  await h.setString(kayitliAsrAnahtari, a.kod);
}

Future<void> yuksekEnlemKaydet(YuksekEnlemAyaru a) async {
  final h = await SharedPreferences.getInstance();
  await h.setString(kayitliYuksekEnlemAnahtari, a.kod);
}

Future<void> gunesDogumuBildirimiKaydet(bool acik) async {
  final h = await SharedPreferences.getInstance();
  await h.setBool(kayitliGunesDogumuAnahtari, acik);
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
  // Linux bildirimindeki eylem düğmesi adı.
  //
  // BİLEREK TÜRKÇE SABİT: bildirim eklentisi `runApp`'den ÖNCE
  // başlatılmak zorunda (AnaSayfa'nın initState'i içinde bildirim izni
  // isteniyor), ama easy_localization çevirileri EasyLocalization widget'ı
  // kurulurken yükleniyor. Yani burada `.tr()` çağırsak çeviri henüz
  // yüklenmemiş olur ve düğmede anahtar adı ("open_app") görünürdü.
  // Yanlış görünen bir çeviriden iyi olan: düz ve okunur bir etiket.
  // (Uygulamanın hedeflediği platform Android; bu yalnızca Linux.)
  const LinuxInitializationSettings linuxAyarlari = LinuxInitializationSettings(defaultActionName: 'Open App');

  // iOS/Darwin ayarları.
  //
  // ÖNCE YOKTU. flutter_local_notifications 20.x, `settings.iOS` null ise
  // `initialize()` çağrısında ArgumentError fırlatır. Bu çağrı
  // `runApp`'den ÖNCE ve try/catch olmadan yapıldığı için iOS'ta uygulama
  // arayüze hiç ulaşamadan çöküyordu.
  //
  // NOT: Bu ayar iOS'ta bildirim PLANLAMAYI etkinleştirmez. iOS'ta
  // planlı bildirim için ek background mode/provisioning gerekir ve
  // fiziksel iPhone'da doğrulanmamıştır. iOS yayın desteği iddiası
  // README'den kaldırılmıştır; buradaki düzeltme yalnız "açılışta
  // ArgumentError" yolunu kapatır.
  const DarwinInitializationSettings iOSAyarlari = DarwinInitializationSettings();

  const InitializationSettings baslangicAyarlari = InitializationSettings(
    android: androidAyarlari,
    iOS: iOSAyarlari,
    linux: linuxAyarlari,
  );

  // Başlangıç hatalarının uygulamayı boş ekranla öldürmesini engelle.
  //
  // `main()` içinde try/catch olmaması, `DilKatalogu.yukle()` gibi
  // dosya okuyan bir adımın patlaması halinde uygulamanın ilk kareden
  // önce ölmesine yol açıyordu. Bildirim eklentisi başlatılamazsa
  // uygulama çalışmaya devam eder; vakitler yine gösterilir, yalnız
  // planlı bildirimler kurulamaz.
  try {
    await bildirimServisi.initialize(settings: baslangicAyarlari);
  } catch (e) {
    debugEkle('bildirim eklentisi başlatılamadı: $e');
  }
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

/// Alt menüde açık olan sekmenin indeksi.
///
/// Kıble gibi donanım kullanan sayfalar yalnızca GÖRÜNÜR olduklarında çalışsın
/// diye bunu dinler. Nedeni: sayfa bir kez kurulduktan sonra `IndexedStack`
/// içinde yaşamaya devam eder; görünmezken de pusula sensörü açık tutulursa
/// pil boşuna harcanır.
final ValueNotifier<int> aktifSekmeIndeksi = ValueNotifier<int>(0);

/// Kıble sekmesinin `AnaMenu` içindeki sırası.
const int kibleSekmeIndeksi = 2;

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

  /// Kullanıcının en az bir kez dokunduğu sekmeler.
  ///
  /// `IndexedStack`, TÜM çocuklarını uygulama açılışında kurar; yani her
  /// sayfanın `initState`'i açılışta çalışır. Kıble sayfası burada konum
  /// istiyor ve kıble açısı bulununca pusula sensörüne abone oluyordu:
  /// kullanıcı kıble sekmesini hiç açmasa bile GPS açılışta çalışıyor, sensör
  /// uygulamanın ömrü boyunca açık kalıyordu.
  ///
  /// Çözüm: henüz açılmamış sekmelerin yerine boş bir kutu konur. Böylece o
  /// sayfa hiç kurulmaz (`initState` çalışmaz, sensör açılmaz); kullanıcı
  /// sekmeye dokunduğunda kurulur ve o andan sonra `IndexedStack` içinde kalır,
  /// yani sekmeler arasında geçince durumu korunur.
  final Set<int> _acilanSekmeler = <int>{0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _seciliSayfaIndeksi,
        children: List<Widget>.generate(
          _sayfalar.length,
          (int i) => _acilanSekmeler.contains(i)
              ? _sayfalar[i]
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSayfaIndeksi,
        onTap: (index) {
          setState(() {
            _seciliSayfaIndeksi = index; 
            _acilanSekmeler.add(index);
          });
          // Sayfalar görünürlüğünü bu bildirimle takip ediyor (bkz.
          // ValueNotifier<int> aktifSekmeIndeksi).
          aktifSekmeIndeksi.value = index;
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