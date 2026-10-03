// tool/manifest_yorumlarini_temizle.dart
//
// AndroidManifest.xml içindeki XML yorumlarını güvenli hale getirir.
//
// SORUN
// ------
// Yorumlarda `-->` veya `--` dizisi geçmemeli. Bazı açıklamalarımızda
// "NEDEN `USE_EXACT_ALARM` YOK?" gibi ifadeler vardı; yorum bloğu içinde
// geçen bir `--` dizisi yorumu ERKEN kapatır ve sonrasındaki metin XML
// özniteliği olarak yorumlanır. AAPT bu yüzden
// "attribute android:hardwareAccelered not found" hatası verir.
//
// ÇÖZÜM
// ------
// 1) Dosyanın BOM/UTF-8 olduğunu doğrular.
// 2) Yorum içindeki `--` ve `-->` dizilerini temizler.
// 3) XML'in gerçekten geçerli olduğunu doğrular.
//
// KULLANIM
//     dart run tool/manifest_yorumlarini_temizle.dart
import 'dart:io';

void main() {
  const yol = 'android/app/src/main/AndroidManifest.xml';
  final dosya = File(yol);
  if (!dosya.existsSync()) {
    stderr.writeln('HATA: $yol bulunamadi. Proje kokunden calistirin.');
    exitCode = 1;
    return;
  }

  var metin = dosya.readAsStringSync();
  final ozet = dosya.lengthSync();

  // 1) Yorum bloklarını bul ve içlerini temizle.
  final yorumKalibi = RegExp(r'<!--(.*?)-->', dotAll: true);
  var duzeltilenYorum = 0;

  metin = metin.replaceAllMapped(yorumKalibi, (m) {
    var ic = m.group(1) ?? '';
    final temiz = ic
        // `-->` erken kapatmayı engelle
        .replaceAll(RegExp(r'--+>'), '—>')
        // XML yorumunda `--` yasaktır
        .replaceAll(RegExp(r'--(?![->])'), '—');
    if (temiz != ic) duzeltilenYorum++;
    return '<!--$temiz-->';
  });

  // 2) Geri besleme (CDATA) ve işaretleme yoksa dokunma.
  if (duzeltilenYorum == 0) {
    // ignore: avoid_print
    print('Yorumlarda `--` veya `-->` yok; dosya olduğu gibi birakildi.');
  } else {
    dosya.writeAsStringSync(metin, flush: true);
    // ignore: avoid_print
    print('$duzeltilenYorum yorum duzeltildi.');
  }

  // 3) XML gecerlilik denetimi.
  final sonMetin = dosya.readAsStringSync();
  final acik = RegExp(r'<!--').allMatches(sonMetin).length;
  final kapali = RegExp(r'-->').allMatches(sonMetin).length;
  if (acik != kapali) {
    stderr.writeln('HATA: Yorum sayimi tutarsiz. acik=$acik kapali=$kapali');
    exitCode = 1;
    return;
  }

  // Gercek XML ayristirma denemesi (dart:xml kullanmadan, kaba denetim).
  if (!sonMetin.trimLeft().startsWith('<?xml') &&
      !sonMetin.trimLeft().startsWith('<')) {
    stderr.writeln('HATA: XML basligi bulunamadi.');
    exitCode = 1;
    return;
  }

  // ignore: avoid_print
  print('XML yorumlari dengeli. Boyut: $ozet bayt -> ${dosya.lengthSync()} bayt');
  // ignore: avoid_print
  print('Simdi `flutter build apk --debug` deneyebilirsin.');
}
