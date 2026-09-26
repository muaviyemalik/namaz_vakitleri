// lib/pages/yasal_notlar_sayfasi.dart
//
// Lisans ve atif bilgileri ekrani.
//
// NEDEN AYRI BIR EKRAN?
// ODbL-1.0 kopyalaç bir lisans olduğu icin veri kaynagini belirtme
// YUKUMLULUGU getirir ve bu yalnizca README dosyasinda birakilamaz; kullanici
// uygulamayi acmadan da gorebilmelidir. Ayarlar menusunden erisilir.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:namaz_vakitleri/data/lisans_bilgileri.dart';

class YasalNotlarSayfasi extends StatelessWidget {
  const YasalNotlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final karanlik = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('legal_notices'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor:
            karanlik ? Colors.grey.shade900 : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: karanlik ? 0 : 10,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Uygulama bilgisi ---
          Card(
            color: Theme.of(context).cardColor,
            elevation: karanlik ? 1 : 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mosque,
                          color: Theme.of(context).colorScheme.primary, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          uygulamaAdi,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      Text('v$uygulamaSurumu',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- ODbL uyari kutusu ---
          // Kopyalaç lisanslar icin zorunlu. En ustte, dikkat cekici sekilde.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    odblAciklamasi,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Atıf girdileri ---
          Text(
            'credits'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          ...lisansGirdileri.map((g) => _girdiKarti(context, g)),
        ],
      ),
    );
  }

  Widget _girdiKarti(BuildContext context, LisansGirdisi g) {
    final karanlik = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: Theme.of(context).cardColor,
        elevation: karanlik ? 1 : 3,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık + kopyalaç rozeti
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.baslik,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (g.kopyalac)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'attribution_required'.tr(),
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(g.aciklama,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: karanlik ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 10),
              // Kaynak
              Row(
                children: [
                  Icon(Icons.storage_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      g.kaynak ?? '',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      g.lisans,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
