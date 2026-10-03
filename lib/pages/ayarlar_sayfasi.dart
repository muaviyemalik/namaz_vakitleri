// lib/pages/ayarlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';
import 'package:namaz_vakitleri/data/hesaplama_yontemleri.dart';
import 'package:namaz_vakitleri/pages/yasal_notlar_sayfasi.dart';
import 'package:namaz_vakitleri/widgets/ulke_secici.dart';
import 'package:namaz_vakitleri/widgets/dil_secici.dart';

class AyarlarSayfasi extends StatefulWidget {
  const AyarlarSayfasi({super.key});

  @override
  State<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  Ulke? _aktifUlke;

  @override
  void initState() {
    super.initState();
    _ulkeyiYukle();
  }

  Future<void> _ulkeyiYukle() async {
    try {
      final liste = await UlkeVerisi.instance.ulkeler();
      for (final u in liste) {
        if (u.iso2 == aktifUlkeKodu.value) {
          if (mounted) setState(() => _aktifUlke = u);
          return;
        }
      }
    } catch (_) {
      // Veri okunamazsa kart yine de görünür, sadece isim boş kalır.
    }
  }

  /// Yeni ülke seçildiğinde çağrılır. Ülkeyi kaydeder ve o ülkenin
  /// başkentine (veri yoksa ilk şehre) geçer.
  Future<void> _ulkeSec() async {
    final secilen = await ulkeSeciciGoster(context);
    if (secilen == null) return;

    aktifUlkeKodu.value = secilen.iso2;
    await ulkeKaydet(secilen.iso2);
    if (mounted) setState(() => _aktifUlke = secilen);
    if (!mounted) return;

    final sehirler = await UlkeVerisi.instance.sehirler(secilen.iso2);

    // ŞEHİR VERİSİ OLMAYAN ÜLKE
    //
    // 245 ülkenin 16'sının (Anguilla, Vatikan, Cocos, Pitcairn, Svalbard,
    // Norfolk, Saint Helena, Sint Maarten, Britanya Virjin Adaları,
    // Montserrat, Cook, Falkland, Güney Georgia, BIOT, Niue, Christmas)
    // şehir dosyası BOŞTUR.
    //
    // ÖNCE: `sehirler.isNotEmpty` false ise hiçbir şey yapılmıyordu.
    // Sonuç: ülke değişmiş görünürken başlıkta ve vakitlerde ÖNCEKİ
    // ÜLKENİN ŞEHRİ kalıyordu. Kullanıcı "Britanya Virjin Adaları"nı
    // seçiyor, ekranda Türkiye'nin vakitlerini görüyordu. Bu, bu uygulamanın
    // en tehlikeli hatalarından biridir: yanlış ülkeye ait vakitler
    // namaz vakti gibi gösteriliyor.
    //
    // ŞİMDİ: aktif konum BOŞALTILIR. Böylece ana sayfa "veri yok" hata
    // ekranını gösterir ve kullanıcıya GPS ya da güvenli bir geri dönüş
    // yolu sunar. Önceki ülkenin şehri ASLA bu ülkenin adıyla gösterilmez.
    if (sehirler.isEmpty) {
      aktifKonum.value = null;
      await konumKaydetTemizle();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_city_data_action'.tr(
              args: [secilen.gorunenAd(context.locale.languageCode)])),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    Sehir? hedef;
    final baskent = secilen.baskent;
    if (baskent != null && baskent.isNotEmpty) {
      final arama = UlkeVerisi.normalize(baskent);
      for (final s in sehirler) {
        if (UlkeVerisi.normalize(s.ad) == arama) {
          hedef = s;
          break;
        }
      }
    }
    hedef ??= sehirler.first;
    await konumAyarla(hedef);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${'country_changed'.tr()}: '
            '${secilen.gorunenAd(context.locale.languageCode)}'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  /// Etkin dilin okunabilir adı (otokton + İngilizce).
  String _aktifDilAdi(BuildContext context) {
    if (!DilKatalogu.yuklendiMi) return context.locale.languageCode;
    final d = DilKatalogu.ornek.kodaGore(context.locale.languageCode);
    if (d == null) return context.locale.languageCode;
    return d.otoktonAd != null && d.otoktonAd != d.ad
        ? '${d.gorunenAd()} · ${d.ad}'
        : d.gorunenAd();
  }

  /// Dili değiştirir. Diyalog kapatılırsa hiçbir şey değişmez.
  Future<void> _dilSec(BuildContext context) async {
    final yeniDilKodu = await dilSeciciGoster(context);
    if (yeniDilKodu == null || !context.mounted) return;
    if (yeniDilKodu == context.locale.languageCode) return;
    context.setLocale(Locale(yeniDilKodu));
  }

  /// Hesaplama yöntemini seçer.
  ///
  /// İPTAL SORUNU DÜZELTİLDİ
  ///
  /// Önceden `showDialog<int?>` kullanılıyordu ve metot `null` olduğunda
  /// hem "Otomatik" seçilmiş hem de diyalog kapatılmış anlamına geliyordu.
  /// Geri tuşu, dışarı dokunma ve kapatma düğmesi `null` döndürdüğü için
  /// kullanıcı yöntemi görmeden DİYALOĞU KAPATTIĞINDA mevcut yöntemi
  /// "Otomatik"a çeviriyordu. Kullanıcının bilinçli bir seçim yapmadan
  /// hesaplama yöntemi değişiyordu.
  ///
  /// Çözüm: [_YontemSecimi] sarmalayıcısı kullanılır. `null` yalnız İPTAL
  /// demektir; "Otomatik" seçimi ayrı bir değerle (`-1`) temsil edilir.
  Future<void> _yontemSec() async {
    final secim = await showDialog<_YontemSecimi>(
      context: context,
      builder: (context) => _YontemSeciciDialog(
        seciliId: aktifHesaplamaYontemi.value,
      ),
    );

    // İptal: kullanıcı bir şey SEÇMEDİ. Mevcut yöntem AYNEN korunur.
    if (secim == null) return;
    if (!mounted) return;

    final yeniId = secim.otomatikMi ? null : secim.yontemId;
    if (yeniId == aktifHesaplamaYontemi.value) return; // Değişiklik yok.

    aktifHesaplamaYontemi.value = yeniId;
    await hesaplamaYontemiKaydet(yeniId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // YENİ 1: Aydınlık modda ana renk, Karanlık modda mat ve şık bir koyu gri!
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900 
            : Theme.of(context).colorScheme.primary, 
            
        foregroundColor: Colors.white,
        
        // YENİ 2: Karanlık modda barın altındaki gölgeyi sıfırlıyoruz ki arka planla tam birleşsin
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 10,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), 
              // YENİ ALT RENK
              Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ÜLKE SEÇİM KARTI
            Card(
              color: Theme.of(context).cardColor,
              elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
              child: ListTile(
                leading: Icon(Icons.public,
                    color: Theme.of(context).colorScheme.primary, size: 30),
                title: Text(
                  'country'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  _aktifUlke == null
                      ? 'loading'.tr()
                      : '${_aktifUlke!.gorunenAd(context.locale.languageCode)}'
                          '${_aktifUlke!.emoji ?? ''}'
                          ' • ${_aktifUlke!.sehirSayisi} ${'city_count'.tr()}',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                onTap: _ulkeSec,
              ),
            ),

            const SizedBox(height: 10),

            // HESAPLAMA YÖNTEMİ KARTI
            // Hesaplama yöntemi vakitleri kaydırır (ölçülen fark: method=13
            // her ülkede sabitken Paris'te Fajr 38 dakika sapıyordu).
            // Varsayılan: Aladhan'ın ülkeye göre seçtiği yöntem. Kullanıcı
            // takip ettiği camiyin yöntemini seçebilir.
            ValueListenableBuilder<int?>(
              valueListenable: aktifHesaplamaYontemi,
              builder: (context, seciliYontemId, child) {
                final seciliYontem =
                    seciliYontemId == null ? null : yontemBul(seciliYontemId);
                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
                  child: ListTile(
                    leading: Icon(Icons.calculate_outlined,
                        color: Theme.of(context).colorScheme.primary, size: 30),
                    title: Text(
                      'calculation_method'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      seciliYontem == null
                          ? 'method_auto_desc'.tr()
                          : '${seciliYontem.ad} · ${seciliYontem.parametreAciklama}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    onTap: _yontemSec,
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // RESMÎ DİYANET VERİSİ (Türkiye)
            //
            // Varsayılan AÇIK. Kapalıyken mevcut Aladhan hesaplama akışı
            // çalışır — bu akış korunur, yalnız varsayılan olmaktan çıkar.
            //
            // Neden bir anahtar? Resmî veri paketi yalnız Türkiye'yi kapsar
            // ve yalnız resmî yayımladığı tarihleri içerir. Kullanıcı bu
            // aralık dışında hesaplanmış saatleri görmek isteyebilir; bu
            // seçim AÇIK olmalıdır, "sessizce" yapılamaz.
            ValueListenableBuilder<bool>(
              valueListenable: aktifResmiDiyanet,
              builder: (context, acikMi, child) {
                final konum = aktifKonum.value;
                final kimlikVar = konum != null && konum.diyanetCityId != null;
                final turkiyeMi = konum?.ulkeIso2 == 'TR';
                return Card(
                  color: Theme.of(context).cardColor,
                  elevation:
                      Theme.of(context).brightness == Brightness.dark ? 1 : 4,
                  child: SwitchListTile(
                    value: acikMi,
                    onChanged: (v) async {
                      // Navigator await ÖNCESinde alınır: async aradan sonra
                      // BuildContext kullanmak güvenli değildir.
                      final navigator = Navigator.of(context);
                      await resmiDiyanetKaydet(v);
                      // Ana ekran `aktifResmiDiyanet` dinleyicisiyle
                      // yeniden yüklenir; burada ekranı kapatmak yeterli.
                      navigator.pop();
                    },
                    secondary: Icon(Icons.verified_outlined,
                        color: Theme.of(context).colorScheme.primary, size: 30),
                    title: Text(
                      'Diyanet resmî vakitleri',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      !turkiyeMi
                          ? 'Yalnız Türkiye için. Seçili ülke: ${konum?.ulkeIso2 ?? '-'}'
                          : acikMi
                              ? kimlikVar
                                  ? 'Açık — Diyanet\'in yayımladığı saatler '
                                      'gösterilir. Asr ve yüksek enlem ayarı '
                                      'bu tabloda yer almaz, vakitleri '
                                      'değiştirmez.'
                                  : 'Açık — ancak bu yerleşim için Diyanet '
                                      'resmî vakit yayımlamıyor; hesaplanmış '
                                      'saatler gösterilir.'
                              : 'Kapalı — vakitler hesaplanır '
                                  '(Diyanet hesaplama yöntemi).',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // ASR (ÖĞLE SONRASI) YÖNTEMİ
            //
            // Bu ayar vakitleri değiştirir. Önceden gizli bir varsayılandı:
            // kullanıcı "Asr'im şu anki şekilde hesaplanıyor" bilgisine
            // sahip değildi. Şimdi açıkça seçilebilir ve hangi değerin
            // kullanıldığı hesap özetinde yazar.
            ValueListenableBuilder<AsrYontemi>(
              valueListenable: aktifAsrYontemi,
              builder: (context, aktifAsr, child) {
                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
                  child: ListTile(
                    leading: Icon(Icons.wb_twilight,
                        color: Theme.of(context).colorScheme.primary, size: 30),
                    title: Text(
                      'asr_method'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(aktifAsr.ad, style: const TextStyle(fontSize: 12)),
                    trailing: DropdownButton<AsrYontemi>(
                      value: aktifAsr,
                      underline: const SizedBox(),
                      dropdownColor: Theme.of(context).cardColor,
                      onChanged: (AsrYontemi? yeni) {
                        if (yeni == null) return;
                        aktifAsrYontemi.value = yeni;
                        asrYontemiKaydet(yeni);
                      },
                      items: AsrYontemi.values
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(a.kod,
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // YÜKSEK ENLEM AYARI
            //
            // 48° üzeri enlemlerde (Norveç, İsveç, Finlandiya, Grönland,
            // bazı Rusya bölgeleri) farklı mezhepler farklı düzeltmeler
            // uygular. Bu ayar gizli bir varsayılan olarak bırakılmaz.
            ValueListenableBuilder<YuksekEnlemAyaru>(
              valueListenable: aktifYuksekEnlemAyaru,
              builder: (context, aktifAyar, child) {
                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
                  child: ListTile(
                    leading: Icon(Icons.terrain,
                        color: Theme.of(context).colorScheme.primary, size: 30),
                    title: Text(
                      'high_latency'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(aktifAyar.ad, style: const TextStyle(fontSize: 12)),
                    trailing: DropdownButton<YuksekEnlemAyaru>(
                      value: aktifAyar,
                      underline: const SizedBox(),
                      dropdownColor: Theme.of(context).cardColor,
                      onChanged: (YuksekEnlemAyaru? yeni) {
                        if (yeni == null) return;
                        aktifYuksekEnlemAyaru.value = yeni;
                        yuksekEnlemKaydet(yeni);
                      },
                      items: YuksekEnlemAyaru.values
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(a.kod,
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // GÜNEŞ DOĞUŞU BİLGİ BİLDİRİMİ
            //
            // Güneş doğuşu bir namaz vakti DEĞİLDİR. Önceden aynı kanalı
            // ve aynı "Vakit Geldi!" metnini kullanıyordu. Artık ayrı bir
            // tür, ayrı bir kanal ve varsayılan olarak KAPALI.
            ValueListenableBuilder<bool>(
              valueListenable: gunesDogumuBildirimiAcik,
              builder: (context, acik, child) {
                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
                  child: SwitchListTile(
                    secondary: Icon(Icons.wb_sunny_outlined,
                        color: Theme.of(context).colorScheme.primary, size: 30),
                    title: Text('sunrise_notification'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('sunrise_notification_desc'.tr(),
                        style: const TextStyle(fontSize: 12)),
                    value: acik,
                    onChanged: (bool yeni) {
                      gunesDogumuBildirimiAcik.value = yeni;
                      gunesDogumuBildirimiKaydet(yeni);
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // VERİ KAYNAĞI NOTU
            //
            // Kullanıcı vakitleri Diyanet'le karşılaştırınca bazı vakitlerde
            // 1-2 dakikalık fark görüyor ve bunu hata sanıyor.
            //
            // Ölçülen durum (Eylül 2026, 11 şehir, 528 vakit): ortalama sapma
            // 0,68 dakika. En yüksek olanlar Ankara İkindi (+2,6 dk) ve
            // İstanbul Güneş doğumu (+2,0 dk).
            //
            // Sebep hesaplama yöntemi DEĞİL: Aladhan, `method` gönderilmediğinde
            // Türkiye için doğru yöntemi (13 = Diyanet) kendisi seçiyor —
            // `method=13` ile elle göndermek 6 vakitte de aynı sonucu veriyor.
            // İki gerçek sebep var:
            //   1) `assets/veri/sehirler/TR.txt` içindeki koordinatlar GeoNames /
            //      dr5hn şehir merkezi noktaları; Diyanet tablolarını farklı bir
            //      referans noktası için hesaplıyor. Aladhan'de 0,1 derece ≈
            //      1 dakika ediyor. Ankara'nın koordinatı optimumlanınca toplam
            //      sapma 8 dakikadan 3 dakikaya, İstanbul'unki 7'den 3'e iniyor.
            //   2) Kalan ±1 dakika koordinatla kapanmıyor: Aladhan'in method 13'ü
            //      Aladhan'in KENDİ uygulaması (cevapta `(experimental)` diye
            //      etiketli) ve Diyanet'in yayınladığı değerlerle farklı
            //      yuvarlama/ephemeris kullanıyor.
            //
            // Yani Aladhan ile Diyanet'in saati birebir eşitlenemez. Kullanıcıyı
            // yanlış bilgilendirmemek ve bu farkı "uygulama hatası" sanmasını
            // önlemek için not burada açıkça yazıyor.
            Card(
              color: Theme.of(context).cardColor,
              elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'calculation_source_note'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // DİL SEÇİM KARTI
            Card(
              color: Theme.of(context).cardColor,
              elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
              child: ListTile(
                leading: Icon(Icons.language, color: Theme.of(context).colorScheme.primary, size: 30),
                title: Text(
                  'language'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87
                  )
                ),
                subtitle: Text(
                  _aktifDilAdi(context),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                onTap: () => _dilSec(context),
              ),
            ),

            const SizedBox(height: 10), // Araya ufak bir boşluk

            // KARANLIK MOD KARTI
            ValueListenableBuilder<ThemeMode>(
              valueListenable: aktifTemaModu,
              builder: (context, aktifMod, child) {
                bool karanlikMi = aktifMod == ThemeMode.dark;
                
                return Card(
                  color: Theme.of(context).cardColor,
                  child: SwitchListTile(
                    activeColor: Theme.of(context).colorScheme.primary,
                    secondary: Icon(
                      karanlikMi ? Icons.nightlight_round : Icons.wb_sunny, 
                      color: karanlikMi ? Colors.amber.shade300 : Colors.orange, 
                      size: 30
                    ),
                    title: Text('dark_mode'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    value: karanlikMi,
                    onChanged: (bool isDark) {
                      aktifTemaModu.value = isDark ? ThemeMode.dark : ThemeMode.light;
                      temaModunuKaydet(isDark); // Hafızaya yaz
                    },
                  ),
                );
              }
            ),
            const SizedBox(height: 10), // Araya ufak bir boşluk

            // ERKEN UYARI KARTI
            ValueListenableBuilder<int>(
              valueListenable: erkenUyariSuresi,
              builder: (context, aktifSure, child) {
                return Card(
                  color: Theme.of(context).cardColor,
                  elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
                  child: ListTile(
                    leading: Icon(Icons.alarm_on, color: Theme.of(context).colorScheme.primary, size: 30),
                    title: Text(
                      'early_warning'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: aktifSure,
                      underline: const SizedBox(), 
                      icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                      dropdownColor: Theme.of(context).cardColor, 
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                      ),
                      onChanged: (int? yeniSure) {
                        if (yeniSure != null) {
                          // Seçilen dakikayı değişkene ata ve telefona kaydet
                          erkenUyariSuresi.value = yeniSure;
                          erkenUyariKaydet(yeniSure);
                        }
                      },
                      items: [
                        DropdownMenuItem(value: 0, child: Text('off'.tr())),
                        DropdownMenuItem(value: 15, child: Text('min_before_15'.tr())),
                        DropdownMenuItem(value: 30, child: Text('min_before_30'.tr())),
                        DropdownMenuItem(value: 45, child: Text('min_before_45'.tr())),
                      ],
                    ),
                  ),
                );
              }
            ),
            // LİSANS VE ATIF KARTI
            // ODbL-1.0 kopyalaç lisansı nedeniyle veri kaynaklarının
            // belirtilmesi zorunludur. Atıf yalnızca README'de değil,
            // uygulama içinde de görünmelidir.
            Card(
              color: Theme.of(context).cardColor,
              elevation: Theme.of(context).brightness == Brightness.dark ? 1 : 4,
              child: ListTile(
                leading: Icon(Icons.description_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 30),
                title: Text(
                  'legal_notices'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'legal_notices_desc'.tr(),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const YasalNotlarSayfasi()),
                ),
              ),
            ),

            // İPUCU: İleride AnaSayfa'nın AppBar'ındaki "Tema Seçimi" ikonunu da
            // buraya yeni bir Card olarak taşıyabilirsin!
          ],
        ),
      ),
    );
  }
}

/// Diyaloğun döndürdüğü seçim.
///
/// `null` dönmesi yalnız İPTAL demektir. "Otomatik" seçimi ayrı bir
/// değerle temsil edilir; bu ayrım olmadan geri tuşu mevcut yöntemi
/// sessizce sıfırlıyordu.
class _YontemSecimi {
  /// `true` ise kullanıcı "Otomatik"i seçti (API'ye `method` gönderilmez).
  final bool otomatikMi;

  /// Seçilen yöntemin id'si. `otomatikMi` true ise `null`.
  final int? yontemId;

  const _YontemSecimi.otomatik() : otomatikMi = true, yontemId = null;
  const _YontemSecimi.yontem(this.yontemId) : otomatikMi = false;
}

/// Hesaplama yöntemi seçim diyaloğu.
class _YontemSeciciDialog extends StatelessWidget {
  final int? seciliId;
  const _YontemSeciciDialog({required this.seciliId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'calculation_method'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    // Kapatma düğmesi İPTAL'dir. Önceden `Navigator.pop(context,
                    // seciliId)` çağrılıyordu; bu, "Otomatik" seçiliyse
                    // (seciliId null) kullanıcı kapatınca yöntemi zaten
                    // otomatik yapıyordu, seçili değilse de aynı değeri
                    // geri yazıyordu. Artık hiçbir şey değişmiyor.
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'method_help'.tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  // Otomatik seçenek.
                  //
                  // ÖNEMLİ: "Otomatik", Aladhan'ın ÜLKEYE GÖRE SEÇTİĞİ
                  // yöntemdir; "ülkenin resmî yöntemi" DEĞİLDİR. 245 ülke
                  // için kanıtsız bir "resmî yöntem" tablosu uydurulmamıştır.
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text('method_auto'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('method_auto_desc'.tr(),
                        style: const TextStyle(fontSize: 12)),
                    trailing: seciliId == null
                        ? Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(context, const _YontemSecimi.otomatik()),
                  ),
                  const Divider(height: 1),
                  // Sağlayıcının desteklediği hesaplama yöntemleri
                  ...hesaplamaYontemleri.map((y) => ListTile(
                        dense: true,
                        title: Text(y.ad, style: const TextStyle(fontSize: 15)),
                        subtitle: Text(y.parametreAciklama,
                            style: const TextStyle(fontSize: 12)),
                        trailing: seciliId == y.id
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () => Navigator.pop(context, _YontemSecimi.yontem(y.id)),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}