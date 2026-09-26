// lib/widgets/dil_secici.dart
//
// Ayarlar menusunde kullanilan dil secici. Yalnizca cevirisi hazir olan
// dilleri gosterir; arama hem otokton adi hem Ingilizce adi kapsar.
//
// Uc ayrinti onemli:
//  1) Kullanicinin secili ulkesinin resmi dilleri en ustte onerilir.
//     Misirli kullaniciya Arapca, Endonezyaliya Endonezce cikabilir.
//  2) Sagdan sola yazan diller (Arapca, Farsca, Urduca...) isaretlenir; bu
//     dillerde arayuzun yonu degisecegi icin kullanici onceden gorur.
//  3) Arama Turkce karakterden bagimsizdir.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:namaz_vakitleri/data/dil_katalogu.dart';
import 'package:namaz_vakitleri/main.dart' show aktifUlkeKodu;

/// Dil secim diyalogunu acar. Secim yapilirsa dil kodu doner.
Future<String?> dilSeciciGoster(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const _DilSeciciDialog(),
  );
}

class _DilSeciciDialog extends StatefulWidget {
  const _DilSeciciDialog();

  @override
  State<_DilSeciciDialog> createState() => _DilSeciciDialogState();
}

class _DilSeciciDialogState extends State<_DilSeciciDialog> {
  String _sorgu = '';

  @override
  Widget build(BuildContext context) {
    if (!DilKatalogu.yuklendiMi) {
      return const Dialog(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    final katalog = DilKatalogu.ornek;
    final tum = katalog.ceviriliDiller;
    final aktifDil = context.locale.languageCode;

    // Secili ulkenin resmi dilleri (cevirisi hazir olanlar)
    final onerilenler = katalog.ulkeninDilleri(aktifUlkeKodu.value);
    final arananlar = DilKatalogu.ara(tum, _sorgu);

    // Arama varken oneri bolumunu gizle
    final oneriGoster = _sorgu.trim().isEmpty && onerilenler.isNotEmpty;
    final seciliUlkeninDilleri = oneriGoster ? onerilenler : <Dil>[];
    final digerleri =
        oneriGoster ? arananlar.where((d) => !seciliUlkeninDilleri.contains(d)).toList() : arananlar;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Baslik
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.translate,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'select_language'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Arama
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (v) => setState(() => _sorgu = v),
                decoration: InputDecoration(
                  hintText: 'search_language'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _sorgu.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _sorgu = ''),
                        ),
                  isDense: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                children: [
                  // Secili ulkenin resmi dilleri
                  if (seciliUlkeninDilleri.isNotEmpty) ...[
                    _bolumBasligi(context, 'suggested_languages'.tr(),
                        seciliUlkeninDilleri.length),
                    ...seciliUlkeninDilleri.map((d) => _satir(d, aktifDil)),
                    const Divider(height: 1),
                  ],
                  _bolumBasligi(
                      context,
                      oneriGoster ? 'all_languages'.tr() : 'search_results'.tr(),
                      digerleri.length),
                  if (digerleri.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('no_results'.tr())),
                    )
                  else
                    ...digerleri.map((d) => _satir(d, aktifDil)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bolumBasligi(BuildContext context, String metin, int sayi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
      child: Text(
        '$metin ($sayi)',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _satir(Dil d, String aktifDil) {
    final secili = d.kod == aktifDil;
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              d.gorunenAd(),
              style: TextStyle(
                fontWeight: secili ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Otokton ad varsa Ingilizce adini yanina yaziyoruz; kullanici
          // hem kendi dilinde hem tanidigi dilde gormus oluyor.
          if (d.otoktonAd != null && d.otoktonAd != d.ad) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                d.ad,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          if (d.rtl) ...[
            Icon(Icons.format_textdirection_r_to_l, size: 14,
                color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text('rtl'.tr(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(width: 10),
          ],
          Text('${d.ulkeSayisi} ${'country'.tr()}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
      trailing: secili
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => Navigator.pop(context, d.kod),
    );
  }
}
