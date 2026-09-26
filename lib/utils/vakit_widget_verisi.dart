// lib/utils/vakit_widget_verisi.dart
//
// "Sıradaki vakit" bilgisi her saniye yeniden hesaplanır (geri sayım için),
// ama ana ekran widget'ına yazılan içerik — vakit adı ve saati — saniyelerce
// aynı kalır. `HomeWidget.saveWidgetData` + `updateWidget` her saniye
// çağrıldığında Android'deki araç her saniye uyanır: pil düşer, araç gözle
// görülür şekilde titrer ve hiç değişmeyen bir metin için boşuna yazma
// yapılır.
//
// Bu sınıf "widget'a yazmak gerekiyor mu?" kararını tek yerde tutar, böylece
// karar mantığı arayüzden bağımsız olarak test edilebilir.

class VakitWidgetVerisi {
  String? _ad;
  String? _saat;

  /// Widget'a yazılması gereken yeni içerik geldiyse true döner ve değerleri
  /// saklar; aynı içerik tekrar gelirse false döner (yazma yapılmaz).
  ///
  /// [ad] çevrilmiş olmalıdır (`.tr()` uygulanmış). Kullanıcı dili
  /// değiştirdiğinde vakit anahtarı (`fajr`, `isha`...) aynı kalır ama metin
  /// değişir; karşılaştırma metni yaptığı için widget yeni dildeki adı da
  /// alır.
  bool yazmaliMi(String ad, String saat) {
    if (_ad == ad && _saat == saat) return false;
    _ad = ad;
    _saat = saat;
    return true;
  }
}
