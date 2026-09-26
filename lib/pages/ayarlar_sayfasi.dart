// lib/pages/ayarlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
    if (sehirler.isNotEmpty) {
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
      await sehirAyarla(hedef);
    }

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

  /// Hesaplama yöntemini seçer. "Otomatik" seçeneği Aladhan'ın ülkeye göre
  /// varsayılanını kullanır; geri kalanı resmi 24 yöntemdir.
  Future<void> _yontemSec() async {
    final secilenId = await showDialog<int?>(
      context: context,
      builder: (context) => _YontemSeciciDialog(
        seciliId: aktifHesaplamaYontemi.value,
      ),
    );
    if (!mounted) return;
    // null döndüyse "Otomatik" seçilmiş demektir; iptal de aynı değeri
    // üretir. Bu yüzden ayrımı dialog'un dönüşünde yapıyoruz.
    aktifHesaplamaYontemi.value = secilenId;
    await hesaplamaYontemiKaydet(secilenId);
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

/// Hesaplama yöntemi seçim diyaloğu.
///
/// null döner: "Otomatik" seçildi (API'ye method gönderilmez, Aladhan
/// ülkeye göre seçer). Diğer bir değer döner: o yöntemin id'si.
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
                    onPressed: () => Navigator.pop(context, seciliId),
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
                  // Otomatik seçenek
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
                    onTap: () => Navigator.pop(context, null),
                  ),
                  const Divider(height: 1),
                  // Resmi yöntemler
                  ...hesaplamaYontemleri.map((y) => ListTile(
                        dense: true,
                        title: Text(y.ad, style: const TextStyle(fontSize: 15)),
                        subtitle: Text(y.parametreAciklama,
                            style: const TextStyle(fontSize: 12)),
                        trailing: seciliId == y.id
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () => Navigator.pop(context, y.id),
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