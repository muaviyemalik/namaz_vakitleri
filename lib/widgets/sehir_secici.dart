// lib/widgets/sehir_secici.dart
//
// Seçili ülkenin şehirlerini arama kutusuyla listeleyen diyalog.
//
// Şehir dosyası yalnızca bu diyalog açıldığında yüklenir ve sonraki
// açılışlarda önbellekten gelir. En kalabalık ülke (ABD, 12 bin şehir)
// bile 334 KB'dır.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

/// Şehir seçim diyaloğunu açar. Seçim yapılırsa [Sehir] döner.
Future<Sehir?> sehirSeciciGoster(BuildContext context, String iso2Kodu) {
  return showDialog<Sehir>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => _SehirSeciciDialog(iso2Kodu: iso2Kodu),
  );
}

class _SehirSeciciDialog extends StatefulWidget {
  final String iso2Kodu;
  const _SehirSeciciDialog({required this.iso2Kodu});

  @override
  State<_SehirSeciciDialog> createState() => _SehirSeciciDialogState();
}

class _SehirSeciciDialogState extends State<_SehirSeciciDialog> {
  final TextEditingController _aramaKutusu = TextEditingController();
  List<Sehir> _tumSehirler = const [];
  String _sorgu = '';
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _aramaKutusu.addListener(() => setState(() => _sorgu = _aramaKutusu.text));
    _yukle();
  }

  @override
  void dispose() {
    _aramaKutusu.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final liste = await UlkeVerisi.instance.sehirler(widget.iso2Kodu);
      if (!mounted) return;
      setState(() {
        _tumSehirler = liste;
        _yukleniyor = false;
        _hata = liste.isEmpty ? 'empty' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = '$e';
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sorgu boşken ilk 300 şehir, doluyken eşleşenler.
    final sonuc = _sorgu.trim().isEmpty
        ? _tumSehirler.take(300).toList(growable: false)
        : UlkeVerisi.ara(_tumSehirler, _sorgu, enFazla: 300);

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
                  Icon(Icons.location_city,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'select_city'.tr(),
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
                controller: _aramaKutusu,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'search_city'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _sorgu.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _aramaKutusu.clear,
                        ),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // --- Sonuç sayısı ---
            if (!_yukleniyor && _hata == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${'cities_found'.tr()}: ${sonuc.length}'
                    '${_sorgu.trim().isEmpty ? '' : ' / ${_tumSehirler.length}'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ),

            const Divider(height: 1),

            // --- Liste ---
            Expanded(
              child: _yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : _hata != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _hata == 'empty'
                                  ? 'no_city_data'.tr()
                                  : 'data_load_error'.tr() + '\n\n$_hata',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : sonuc.isEmpty
                          ? Center(child: Text('no_results'.tr()))
                          : ListView.builder(
                              itemCount: sonuc.length,
                              itemBuilder: (context, i) {
                                final s = sonuc[i];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(Icons.place_outlined,
                                      color: Theme.of(context).colorScheme.primary),
                                  title: Text(s.ad),
                                  onTap: () => Navigator.pop(context, s),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
