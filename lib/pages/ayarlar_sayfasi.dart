// lib/pages/ayarlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namaz_vakitleri/main.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

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
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                  )
                ),
                trailing: DropdownButton<String>(
                  // O anki aktif dili seçili olarak gösterir
                  value: context.locale.languageCode, 
                  underline: const SizedBox(), // Altındaki klasik çizgiyi gizleyip daha şık yapıyoruz
                  icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                  ),
                  onChanged: (String? yeniDilKodu) {
                    if (yeniDilKodu != null) {
                      // YENİ: Dili anında değiştirir ve hafızaya kaydeder!
                      context.setLocale(Locale(yeniDilKodu));
                    }
                  },
                  items: [
                    DropdownMenuItem(value: 'tr', child: Text('turkish'.tr())),
                    DropdownMenuItem(value: 'en', child: Text('english'.tr())),
                    DropdownMenuItem(value: 'zh', child: Text('chinese'.tr())),
                  ],
                ),
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
            
            // İPUCU: İleride AnaSayfa'nın AppBar'ındaki "Tema Seçimi" ikonunu da 
            // buraya yeni bir Card olarak taşıyabilirsin!
          ],
        ),
      ),
    );
  }
}