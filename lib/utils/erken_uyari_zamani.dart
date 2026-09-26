// lib/utils/erken_uyari_zamani.dart
//
// ERKEN UYARI ZAMANLAMA (uygulama kapalıyken de çalışması için)
//
// Sorun: erken uyarı bildirimi yalnızca `kalanSureyiHesapla()` içinde,
// saniyelik sayaçla tetikleniyordu:
//
//   if (fark.inSeconds == erkenUyariSaniyesi) { bildirimGonder(); }
//
// Bu iki sorunu birlikte doğuruyordu:
//
//   1) UYGULAMA KAPALIYKEN HİÇ ÇALIŞMAZ. Sayaç yalnızca `AnaSayfa` açıkken
//      döner; arka planda veya uygulama öldürülmüşken o saniye hiç gelmez.
//   2) TAM EŞİTLİK ŞANSI. Sayaç 1 saniyede bir çalışır, bildirim ancak
//      `fark.inSeconds == 900` olduğu KAREDE gönderilir. Uygulama o saniyede
//      arka plana geçerse, telefon uykuya girerse veya sistem o saniyeyi
//      kaçırırsa bildirim kalıcı olarak kaybolur. 15 dakikalık erken uyarı
//      için bile bu tek saniyelik pencere var.
//
// Çözüm: erken uyarı da vakit alarmı gibi SİSTEME planlanır. `AlarmManager`
// uygulama kapalıyken de, cihaz uykudayken bile tetiklenir; hesaplama yapılacak
// yeri de yoktur. Uygulamanın açık olup olmadığı hiçbir şeyi değiştirmez.
//
// Bu dosya yalnızca ZAMAN HESABI yapar; alarmı kuran taraf
// `anasayfa.dart`'daki `_erkenUyariAlarmlariZamanla`dır. Ayrım önemlidir:
// hesap saf ve test edilebilir, alarm kurma işlemi değil.

/// Bir vakitin erken uyarı bildiriminin gösterileceği zamanı döner.
///
/// [vakitZamani]: vaktin girdiği an.
/// [erkenDakika]: kaç dakika önce haber verilecek (0 ise erken uyarı yok).
///
/// [vakitZamani]dan [erkenDakika] önceki ana düşer. Dakika 0 ise `null`
/// döner: bu ayar "kapalı" anlamına gelir ve o vakit için alarm kurulmaz.
DateTime? erkenUyariZamani(DateTime vakitZamani, int erkenDakika) {
  if (erkenDakika <= 0) return null;
  return vakitZamani.subtract(Duration(minutes: erkenDakika));
}
