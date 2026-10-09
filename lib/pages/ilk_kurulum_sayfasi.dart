import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/ilk_kurulum.dart';
import '../core/bildirim_ayarlari.dart';

class IlkKurulumSayfasi extends StatefulWidget {
  const IlkKurulumSayfasi({super.key, required this.tamamlandi, this.islemler});
  final VoidCallback tamamlandi;
  final KurulumIslemleri? islemler;
  @override
  State<IlkKurulumSayfasi> createState() => _IlkKurulumSayfasiState();
}

class _IlkKurulumSayfasiState extends State<IlkKurulumSayfasi>
    with WidgetsBindingObserver {
  late final KurulumIslemleri _islemler = widget.islemler ?? KurulumIslemleri();
  int _adim = 0;
  int _secim = 0;
  bool _mesgul = false;
  bool _izinlerDenendi = false;
  bool _sessizde = false;
  KurulumKonumu? _konum;
  VakitBildirimModu? _mod;
  KurulumIzinDurumu? _izinler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _adim == 2 && !_mesgul) {
      _durumuOku();
    }
  }

  Future<void> _durumuOku() async {
    try {
      final durum = await _islemler.izinDurumu();
      if (mounted) setState(() => _izinler = durum);
    } catch (_) {
      if (mounted) setState(() => _hata = 'setup_permission_error'.tr());
    }
  }

  Future<void> _konumSec(bool otomatik) async {
    final secim = ++_secim;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final konum = otomatik
          ? await _islemler.otomatikBul()
          : await _islemler.elleSec(context);
      if (mounted && secim == _secim && konum != null) {
        setState(() => _konum = konum);
      }
    } catch (hata) {
      if (!mounted || secim != _secim) return;
      final anahtar = switch (hata) {
        KurulumKonumHatasi.servisKapali => 'setup_location_off',
        KurulumKonumHatasi.kaliciRet => 'loc_perm_forever',
        KurulumKonumHatasi.izinReddedildi => 'setup_location_denied',
        _ => 'setup_location_error',
      };
      setState(() => _hata = anahtar.tr());
      if (hata == KurulumKonumHatasi.servisKapali ||
          hata == KurulumKonumHatasi.kaliciRet) {
        final ac = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('find_location'.tr()),
            content: Text(anahtar.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('settings'.tr()),
              ),
            ],
          ),
        );
        if (ac == true && mounted) {
          try {
            await _islemler.ayarlariAc(hata as KurulumKonumHatasi);
          } catch (_) {
            if (mounted) setState(() => _hata = 'setup_location_error'.tr());
          }
        }
      }
    } finally {
      if (mounted && secim == _secim) setState(() => _mesgul = false);
    }
  }

  Future<void> _izinleriIste() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await _islemler.izinleriIste(() => mounted);
      if (!mounted) return;
      await _durumuOku();
      if (mounted) setState(() => _izinlerDenendi = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _hata = 'setup_permission_error'.tr();
          _izinlerDenendi = true;
        });
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _tamamla() async {
    if (_konum == null || _mod == null || !_izinlerDenendi) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await _islemler.tamamla(_konum!, _mod!, _sessizde);
      if (mounted) widget.tamamlandi();
    } catch (_) {
      if (mounted) setState(() => _hata = 'notification_save_failed'.tr());
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Widget _izinSatiri(String baslik, String aciklama, bool? durum) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(durum == true ? Icons.check_circle : Icons.info_outline),
    title: Text(baslik.tr()),
    trailing: durum == false ? const Icon(Icons.settings) : null,
    onTap: durum != false || _mesgul
        ? null
        : () async {
            try {
              await _islemler.izinAyariniAc(
                baslik == 'alarm_access'
                    ? 'exact'
                    : baslik == 'system_notifications'
                    ? 'notifications'
                    : 'location',
              );
            } catch (_) {
              if (mounted) {
                setState(() => _hata = 'setup_permission_error'.tr());
              }
            }
          },
    subtitle: Text(
      '${aciklama.tr()}\n${(durum == true
          ? 'setup_granted'
          : durum == false
          ? 'setup_missing'
          : 'setup_not_checked').tr()}',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final baslik = ['setup_city', 'setup_alert', 'setup_permissions'][_adim];
    return Scaffold(
      appBar: AppBar(title: Text('setup_title'.tr())),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${_adim + 1} / 3 · ${baslik.tr()}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (_adim + 1) / 3),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_adim == 0) ...[
                    Text('setup_city_desc'.tr()),
                    const SizedBox(height: 24),
                    if (_konum != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(_konum!.sehir.etiket()),
                          subtitle: Text(_konum!.ulke),
                        ),
                      ),
                    if (_islemler.konumDestekli)
                      OutlinedButton.icon(
                        key: const Key('setup_gps'),
                        onPressed: _mesgul ? null : () => _konumSec(true),
                        icon: const Icon(Icons.my_location),
                        label: Text('find_location'.tr()),
                      ),
                    OutlinedButton.icon(
                      key: const Key('setup_manual'),
                      onPressed: _mesgul ? null : () => _konumSec(false),
                      icon: const Icon(Icons.location_city),
                      label: Text('select_city'.tr()),
                    ),
                  ],
                  if (_adim == 1) ...[
                    Text('setup_alert_desc'.tr()),
                    RadioGroup<VakitBildirimModu>(
                      groupValue: _mod,
                      onChanged: (v) => setState(() => _mod = v),
                      child: Column(
                        children: [
                          for (final mod in VakitBildirimModu.values)
                            RadioListTile<VakitBildirimModu>(
                              key: Key('setup_mode_${mod.name}'),
                              value: mod,
                              title: Text(
                                (mod == VakitBildirimModu.ezan
                                        ? 'adhan_mode'
                                        : mod == VakitBildirimModu.bildirim
                                        ? 'notification_only'
                                        : 'off')
                                    .tr(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_mod == VakitBildirimModu.ezan)
                      SwitchListTile(
                        key: const Key('setup_silent'),
                        title: Text('adhan_silent'.tr()),
                        subtitle: Text('setup_silent_desc'.tr()),
                        value: _sessizde,
                        onChanged: (v) => setState(() => _sessizde = v),
                      ),
                  ],
                  if (_adim == 2) ...[
                    Text('setup_permissions_desc'.tr()),
                    _izinSatiri(
                      'system_notifications',
                      'setup_notification_desc',
                      _izinler?.bildirim,
                    ),
                    if (_islemler.alarmDestekli)
                      _izinSatiri(
                        'alarm_access',
                        'setup_alarm_desc',
                        _izinler?.alarm,
                      ),
                    if (_islemler.konumDestekli)
                      _izinSatiri(
                        'find_location',
                        'setup_location_desc',
                        _izinler?.konum,
                      ),
                    FilledButton.tonal(
                      key: const Key('setup_request'),
                      onPressed: _mesgul || _izinlerDenendi
                          ? null
                          : _izinleriIste,
                      child: Text('setup_request'.tr()),
                    ),
                    if (_izinlerDenendi &&
                        (_izinler?.bildirim != true ||
                            (_islemler.alarmDestekli &&
                                _izinler?.alarm != true)))
                      Text('setup_missing_desc'.tr()),
                  ],
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _hata!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_mesgul)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_adim > 0)
                    Flexible(
                      child: TextButton(
                        key: const Key('setup_back'),
                        onPressed: _mesgul
                            ? null
                            : () => setState(() {
                                _adim--;
                                _hata = null;
                              }),
                        child: Text('setup_back'.tr()),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('setup_next'),
                      onPressed:
                          _mesgul ||
                              (_adim == 0 && _konum == null) ||
                              (_adim == 1 && _mod == null) ||
                              (_adim == 2 && !_izinlerDenendi)
                          ? null
                          : () async {
                              if (_adim == 2) {
                                await _tamamla();
                                return;
                              }
                              setState(() {
                                _adim++;
                                _hata = null;
                              });
                              if (_adim == 2) await _durumuOku();
                            },
                      child: Text(
                        (_adim == 2 ? 'setup_finish' : 'setup_next').tr(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BaslangicSayfasi extends StatefulWidget {
  const BaslangicSayfasi({
    super.key,
    required this.kurulumGerekli,
    required this.anaMenu,
  });
  final bool kurulumGerekli;
  final Widget anaMenu;
  @override
  State<BaslangicSayfasi> createState() => _BaslangicSayfasiState();
}

class _BaslangicSayfasiState extends State<BaslangicSayfasi> {
  late bool _kurulum = widget.kurulumGerekli;
  @override
  Widget build(BuildContext context) => _kurulum
      ? IlkKurulumSayfasi(tamamlandi: () => setState(() => _kurulum = false))
      : widget.anaMenu;
}
