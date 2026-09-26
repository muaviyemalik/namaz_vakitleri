// lib/widgets/sehir_secici.dart
//
// Secili ulkenin sehirlerini iki sekmeyle listeleyen diyalog.
//
// NEDEN SEKME VAR?
// Veri tabani ilce ve koy duzeyini de iceriyor. Turkiye icin 1.049 kayit
// var; bunlarin 615'i nufusu 15.000'in altinda kucuk yerlesimler. Bunlar
// alfabetik sirayla listelenince kullanici ilk ekranda "Abana, Acigul,
// Adakli" goruyor, Adana ancak 6. sırada. Kullanicinin onu birSure
// kaydirmasina gerek kalmasin diye varsayilan sekme SADECE sehirleri
// gosterir ve nufusa gore buyukten kucuge siralar. Koyler ayri sekmede,
// alfabetik sirayla durur.
//
// AYIRT ETME
// Ayni adi tasiyan farkli yerler vardir:
//
//   Ankara / Golbasi     165.201 kişi
//   Adiyaman / Golbasi     28.078 kişi
//
// Kullanici "Golbasi" yazdiginda ikisini de gorur; ilk satirinda hangisinin
// Ankara'da oldugu yazar. Bu ayrim veri katmaninda mumkun olur cunku her
// kayit il bilgisini tasir.
//
// Dosya yalnizca bu diyalog acildiginda yuklenir ve sonraki acilislarda
// onbellekten gelir. En kalabalik ulke dosyasi (ABD) 400 KB'dir.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:namaz_vakitleri/data/ulke_verisi.dart';

/// Sekme seciciyi gosterir. Secim yapilirsa [Sehir] doner.
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

class _SehirSeciciDialogState extends State<_SehirSeciciDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _aramaKutusu = TextEditingController();
  List<Sehir> _tumSehirler = const [];
  String _sorgu = '';
  bool _yukleniyor = true;
  String? _hata;
  late final TabController _sekme;

  @override
  void initState() {
    super.initState();
    _sekme = TabController(length: 2, vsync: this);
    _aramaKutusu.addListener(_aramaDegisti);
    _yukle();
  }

  void _aramaDegisti() {
    final yeni = _aramaKutusu.text;
    if (yeni == _sorgu) return;
    setState(() => _sorgu = yeni);
  }

  @override
  void dispose() {
    _aramaKutusu
      ..removeListener(_aramaDegisti)
      ..dispose();
    _sekme.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final liste = await UlkeVerisi.instance.sehirler(widget.iso2Kodu);
      if (!mounted) return;
      setState(() {
        _tumSehirler = liste;
        _bolunmus = UlkeVerisi.bol(liste);
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

  /// Arama yapiliyorsa bulunanlar, yoksa sekmeye gore filtrelenmis tam liste.
  ///
  /// Sekme mantigi: arama bosken "Sehirler" sekmesi yalnizca sehirleri
  /// gosterir; "Koyler" sekmesi koyleri gosterir. Arama yazildiginda iki
  /// sekme de arama sonuclarini gosterir, cunku kullanici ne aradigini
  /// bilmiyor olabilir ve koy olabilir.
  ///
  /// Bolme ve siralama [UlkeVerisi.bol] icinde yapilir; mantik orada
  /// test edilebilir.
  late (List<Sehir>, List<Sehir>) _bolunmus = (const [], const []);

  List<Sehir> _liste(bool koySekmesi) {
    if (_sorgu.trim().isNotEmpty) {
      return UlkeVerisi.ara(_tumSehirler, _sorgu);
    }
    return koySekmesi ? _bolunmus.$2 : _bolunmus.$1;
  }

  @override
  Widget build(BuildContext context) {
    final aramaVar = _sorgu.trim().isNotEmpty;
    final sehirler = _liste(false);
    final koyler = _liste(true);
    final aktifListe = _sekme.index == 0 ? sehirler : koyler;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // --- Baslik ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.location_city,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'select_city'.tr(),
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

            // --- Arama kutusu ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

            // --- Sekmeler ---
            // Arama sirasinda sekmeler gizlenir: kullanici ne aradigini
            // yazdiginda "sehir" ile "koy" ayrimi anlamli degildir.
            if (!aramaVar)
              TabBar(
                controller: _sekme,
                tabs: [
                  Tab(text: 'cities_tab'.tr()),
                  Tab(text: 'villages_tab'.tr()),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${'cities_found'.tr()}: ${aktifListe.length} / ${_tumSehirler.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),

            if (!aramaVar)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${'cities_found'.tr()}: ${aktifListe.length}',
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
                      : aramaVar
                          ? _listeGoster(aktifListe)
                          : TabBarView(
                              controller: _sekme,
                              children: [
                                _listeGoster(sehirler),
                                _listeGoster(koyler),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listeGoster(List<Sehir> liste) {
    if (liste.isEmpty) {
      return Center(child: Text('no_results'.tr()));
    }
    return ListView.builder(
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final s = liste[i];
        // "Kahramanmaras / Dulkadiroglu" -> il kalin, ilce gri ve normal.
        final etiketParcalari = s.etiket().split(' / ');
        final basaIlVar = etiketParcalari.length > 1;
        return ListTile(
          dense: true,
          leading: Icon(Icons.place_outlined,
              color: Theme.of(context).colorScheme.primary),
          title: basaIlVar
              ? Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${etiketParcalari.first} / ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: etiketParcalari.skip(1).join(' / ')),
                  ]),
                )
              : Text(s.ad),
          subtitle: s.nufus > 0
              ? Text(_nufusBicim(s.nufus), style: const TextStyle(fontSize: 11))
              : null,
          onTap: () => Navigator.pop(context, s),
        );
      },
    );
  }

  /// Nfusu yerel sayilara gore bicimler: 1.578.722 -> "1,58 Mn" gibi.
  ///
  /// Uygulamanin geri kalaninda da ayni bicim kullaniliyor; tek bir yerden
  /// gelmesi icin [UlkeVerisi] yerine burada sadelestirilmis bir surum
  /// kullaniliyor (cunku bu bir veri katmani, arayuz degil).
  String _nufusBicim(int nufus) {
    if (nufus >= 1000000) {
      return '${(nufus / 1000000).toStringAsFixed(1)}M';
    }
    if (nufus >= 1000) {
      return '${(nufus / 1000).toStringAsFixed(0)}K';
    }
    return '$nufus';
  }
}
