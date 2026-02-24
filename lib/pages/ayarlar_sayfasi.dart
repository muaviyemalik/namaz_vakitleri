// lib/pages/ayarlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // DİL SEÇİM KARTI
            Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(Icons.language, color: Theme.of(context).colorScheme.primary, size: 30),
                title: Text('language'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                trailing: DropdownButton<String>(
                  // O anki aktif dili seçili olarak gösterir
                  value: context.locale.languageCode, 
                  underline: const SizedBox(), // Altındaki klasik çizgiyi gizleyip daha şık yapıyoruz
                  icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
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
            
            // İPUCU: İleride AnaSayfa'nın AppBar'ındaki "Tema Seçimi" ikonunu da 
            // buraya yeni bir Card olarak taşıyabilirsin!
          ],
        ),
      ),
    );
  }
}