import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/bildirim_ayarlari.dart';
import '../core/ezan_platformu.dart';
import '../main.dart';

class BildirimAyarlariSayfasi extends StatefulWidget {
  const BildirimAyarlariSayfasi({super.key});
  @override
  State<BildirimAyarlariSayfasi> createState() =>
      _BildirimAyarlariSayfasiState();
}

class _BildirimAyarlariSayfasiState extends State<BildirimAyarlariSayfasi>
    with WidgetsBindingObserver {
  bool _bekleyenDnd = false;
  bool _kaydediyor = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ezanPlatformu.onizlemeyiDurdur();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _bekleyenDnd) _dndDonusu();
  }

  Future<void> _dndDonusu() async {
    _bekleyenDnd = false;
    if (await ezanPlatformu.dndIzni() && mounted) {
      await _kaydet(bildirimAyarlari.value.degistir(dnd: true));
    }
  }

  Future<void> _kaydet(BildirimAyarlari a) async {
    if (_kaydediyor) return;
    setState(() => _kaydediyor = true);
    try {
      await bildirimAyarlariKaydet(a);
    } catch (_) {
      if (mounted) _mesaj('notification_save_failed'.tr());
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  void _mesaj(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> _dinle(String ses) async {
    try {
      await ezanPlatformu.dinle(ses);
    } catch (_) {
      if (mounted) _mesaj('notification_preview_failed'.tr());
    }
  }

  static const _makamlar = {
    'fajr': 'Sabâ',
    'dhuhr': 'Uşşak',
    'asr': 'Hicaz',
    'maghrib': 'Segâh',
    'isha': 'Rast',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('notification_settings'.tr())),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'prayer_notifications'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<BildirimAyarlari>(
          valueListenable: bildirimAyarlari,
          builder: (context, a, _) => Column(
            children: [
              Card(
                child: Column(
                  children: [
                    for (final v in BildirimAyarlari.vakitler)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${v.tr()} · ${_makamlar[v]}'),
                                ),
                                if (EzanPlatformu.destekleniyor)
                                  IconButton(
                                    tooltip: 'sound_preview'.tr(),
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () => _dinle(v),
                                  ),
                              ],
                            ),
                            DropdownButtonFormField<VakitBildirimModu>(
                              initialValue: a.modu(v),
                              isExpanded: true,
                              items: [
                                for (final m in VakitBildirimModu.values)
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(switch (m) {
                                      VakitBildirimModu.ezan =>
                                        'adhan_mode'.tr(),
                                      VakitBildirimModu.bildirim =>
                                        'notification_only'.tr(),
                                      VakitBildirimModu.kapali => 'off'.tr(),
                                    }),
                                  ),
                              ],
                              onChanged: _kaydediyor
                                  ? null
                                  : (m) {
                                      if (m != null) {
                                        _kaydet(a.degistir(vakit: v, mod: m));
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('adhan_silent'.tr()),
                      value: a.sessizdeCal,
                      subtitle: Text('adhan_volume_desc'.tr()),
                      onChanged: _kaydediyor
                          ? null
                          : (v) => _kaydet(a.degistir(sessizde: v)),
                    ),
                    SwitchListTile(
                      title: Text('adhan_dnd'.tr()),
                      value: a.dndCal,
                      subtitle: Text('adhan_dnd_desc'.tr()),
                      onChanged: _kaydediyor
                          ? null
                          : (v) async {
                              if (v && !await ezanPlatformu.dndIzni()) {
                                _bekleyenDnd = true;
                                await ezanPlatformu.sistemAyari('dnd');
                              } else {
                                await _kaydet(a.degistir(dnd: v));
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('adhan_controls_desc'.tr()),
        ),
        if (EzanPlatformu.destekleniyor)
          TextButton.icon(
            onPressed: () => ezanPlatformu.durdur(),
            icon: const Icon(Icons.stop),
            label: Text('ezan_stop'.tr()),
          ),
        const SizedBox(height: 16),
        Text(
          'early_warning'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('reminder_common_desc'.tr()),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: erkenUyariSuresi,
                  builder: (context, sure, _) => DropdownButtonFormField<int>(
                    initialValue: sure,
                    isExpanded: true,
                    items: [
                      for (final m in [0, 15, 30, 45, 60])
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m == 0 ? 'off'.tr() : 'min_before_$m'.tr(),
                          ),
                        ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await erkenUyariKaydet(v);
                      erkenUyariSuresi.value = v;
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('reminder_sound'.tr()),
                  subtitle: Text('warm_rise'.tr()),
                  trailing: EzanPlatformu.destekleniyor
                      ? IconButton(
                          tooltip: 'sound_preview'.tr(),
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => _dinle('hatirlatici'),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ValueListenableBuilder<bool>(
            valueListenable: gunesDogumuBildirimiAcik,
            builder: (context, acik, _) => SwitchListTile(
              title: Text('sunrise_notification'.tr()),
              subtitle: Text('sunrise_notification_desc'.tr()),
              value: acik,
              onChanged: (v) async {
                await gunesDogumuBildirimiKaydet(v);
                gunesDogumuBildirimiAcik.value = v;
              },
            ),
          ),
        ),
        if (EzanPlatformu.destekleniyor)
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('alarm_access'.tr()),
                  subtitle: Text('alarm_access_desc'.tr()),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => ezanPlatformu.sistemAyari('exact'),
                ),
                ListTile(
                  title: Text('system_notifications'.tr()),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => ezanPlatformu.sistemAyari('notifications'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
