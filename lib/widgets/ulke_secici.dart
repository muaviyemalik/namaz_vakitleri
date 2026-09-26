// lib/widgets/ulke_secici.dart
//
// Ayarlar sayfasında kullanılan ülke seçim bileşeni. 220 ülkeyi kıta
// gruplarına ayırarak ve arama kutusuyla listeler.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';
import 'package:namaz_vakitleri/main.dart' show aktifUlkeKodu;

/// Ülke seçim diyaloğunu açar. Seçim yapılırsa [Ulke] döner, iptal edilirse null.
Future<Ulke?> ulkeSeciciGoster(BuildContext context) {
  return showDialog<Ulke>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const _UlkeSeciciDialog(),
  );
}

class _UlkeSeciciDialog extends StatefulWidget {
  const _UlkeSeciciDialog();

  @override
  State<_UlkeSeciciDialog> createState() => _UlkeSeciciDialogState();
}

class _UlkeSeciciDialogState extends State<_UlkeSeciciDialog> {
  List<Ulke> _tumUlkeler = const [];
  String _sorgu = '';
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final liste = await UlkeVerisi.instance.ulkeler();
      if (!mounted) return;
      setState(() {
        _tumUlkeler = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = '$e';
        _yukleniyor = false;
      });
    }
  }

  List<Ulke> get _sorgulanmis => UlkeVerisi.ulkeAra(_tumUlkeler, _sorgu);

  @override
  Widget build(BuildContext context) {
    final dil = context.locale.languageCode;
    final sonuc = _sorgulanmis;

    // Kıta gruplarına ayır
    final gruplar = <String, List<Ulke>>{};
    for (final u in sonuc) {
      gruplar.putIfAbsent(u.bolge, () => []).add(u);
    }
    // Kıta sırası: Avrupa, Asya, Afrika, Amerika
    const bolgeSirasi = ['Europe', 'Asia', 'Africa', 'Americas'];
    final siraliBolgeler = bolgeSirasi.where(gruplar.containsKey).toList()
      ..addAll(gruplar.keys.where((k) => !bolgeSirasi.contains(k)));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // --- Başlık ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.public, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'select_country'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // --- Arama kutusu ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _sorgu = v),
                decoration: InputDecoration(
                  hintText: 'search_country'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _sorgu.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _sorgu = ''),
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // --- Sonuç listesi ---
            Expanded(
              child: _yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : _hata != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('data_load_error'.tr() + '\n\n$_hata',
                                textAlign: TextAlign.center),
                          ),
                        )
                      : sonuc.isEmpty
                          ? Center(child: Text('no_results'.tr()))
                          : ListView.builder(
                              itemCount: siraliBolgeler.length,
                              itemBuilder: (context, bolgeIndex) {
                                final bolge = siraliBolgeler[bolgeIndex];
                                final ulkeler = gruplar[bolge]!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Kıta başlığı
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.10),
                                      child: Text(
                                        '${Ulke.bolgeAdiStatik(bolge, dil)}  (${ulkeler.length})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    ...ulkeler.map((u) => _ulkeSatiri(u, dil)),
                                  ],
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ulkeSatiri(Ulke u, String dil) {
    final secili = u.iso2 == aktifUlkeKodu.value;
    return ListTile(
      dense: true,
      leading: Text(
        u.emoji ?? '',
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        u.gorunenAd(dil),
        style: TextStyle(
          fontWeight: secili ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${u.sehirSayisi} ${'city'.tr()}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: secili
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => Navigator.pop(context, u),
    );
  }
}
