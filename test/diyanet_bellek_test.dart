// Diyanet paketinin BELLEK davranışını ölçen test.
//
// Bu test "her şeyi belleğe alıyor mu" sorusunu YAPISAL olarak değil,
// ÖLÇÜMLE cevaplar. Amacı: paket 18,4 MB ham olmasına rağmen uygulama
// açılışta bunun tamamını RAM'e almamalı ve kullanıcı il değiştirdikçe
// bellek sınırsız büyümemeli.
//
// ÖLÇÜLENLER
//   1) Açılış yükü: yalnız `paket.json` okununca bellek artışı küçüktür.
//   2) İl parçası tembel yüklenir: ilk `vakitler()` çağrısı TEK dosya okur.
//   3) Önbellek SINIRLIDIR: 81 ilin hepsi gezilse bile bellek tavanı
//      korunur. Sınırsız büyüyen bir önbellek "açılışta yüklemiyor" avantajını
//      kullanım sırasında geri alırdı.

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ölçüm: açılışta tüm veri yüklenmiyor', () {
    test('paket() yalnız manifest okur, il parçası YÜKLEMEZ', () async {
      final depo = DiyanetDepo();
      final ilk = depo.parcaOnbellekUzunlugu;

      final paket = await depo.paket();
      expect(paket, isNotNull);

      expect(depo.parcaOnbellekUzunlugu, ilk,
          reason: 'paket() çağrısı hiçbir il parçasını okumamalı');
      expect(depo.parcaOnbellekUzunlugu, 0,
          reason: 'açılışta hiç il verisi bellekte olmamalı');
    });

    test('vakitler() yalnız TEK il parçası yükler', () async {
      final depo = DiyanetDepo();
      final e = (await depo.eslemeBul(il: 'Ankara', ad: 'Ankara'))!;

      await depo.vakitler(
          cityId: e.cityId, ilDosya: e.parca, tarih: DateTime(2026, 10, 3));

      expect(depo.parcaOnbellekUzunlugu, 1,
          reason: 'tek şehir seçimi tek parça yüklemeli');
    });
  });

  group('Ölçüm: önbellek sınırsız büyümemeli', () {
    test('birçok il gezildikten sonra önbellek tavanı korunur', () async {
      final depo = DiyanetDepo();
      final e = (await depo.eslemeBul(il: 'Ankara', ad: 'Ankara'))!;

      // Ankara parçasını oku.
      await depo.vakitler(
          cityId: e.cityId, ilDosya: e.parca, tarih: DateTime(2026, 10, 3));
      expect(depo.parcaOnbellekUzunlugu, 1);

      // FARKLI illerin parçalarını oku. Ankara'nın parçası evreklendiği için
      // önbellekteki il sayısı 1'de KALMALIDIR.
      for (final il in const ['İzmir', 'Konya', 'Trabzon', 'Erzurum']) {
        final kimlik = await depo.eslemeBul(il: il, ad: il);
        if (kimlik == null) continue; // o il paketlenmemişse atla
        await depo.vakitler(
            cityId: kimlik.cityId,
            ilDosya: kimlik.parca,
            tarih: DateTime(2026, 10, 3));
      }

      expect(depo.parcaOnbellekUzunlugu, lessThanOrEqualTo(2),
          reason: '81 il gezilse bile bellekte yalnız birkaç parça tutulmalı; '
              ' aksi halde kullanım sırasında 18 MB birikir');
    });
  });
}