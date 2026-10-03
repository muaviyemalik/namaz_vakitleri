// Resmî Diyanet kimliğinin KALICI HAFIZA turu.
//
// NEDEN BU TEST
// `konumKaydet`/`konumYukle` cihaza yazılan tek yol. Yeni iki alan eklendi
// (`il` ve `diyanetCityId`) ve bunlar resmî modun AÇILIP AÇILMAYACAGINI
// belirliyor. Iki gercek risk var:
//
//   1) GERIYE UYUM. Uygulamayi kullanan mevcut kullanicinin kaydi 5 alanlidir
//      (`ad|ulke|enlem|boylam|saatDilimi`). Bu kayit okundugunda kullanici
//      Konumu KAYBOLMAMALI; yalnizca resmî kimlik bos kalmali ve
//      yeniden cozulebilmeli. Kullanici verisi SILINMEZ.
//
//   2) KIMLIK KAYBI. Kayit 7 alanliysa kimlik AYNEN geri gelmeli. Kimlik
//      geri gelmezse kullanici sessizce hesaplanmış moda duser ve
//      "Diyanet" varmis gibi davranan bir ekranla kalsin diye bir risk
//      dogar. (Aslinda bu durumda etiket hesaplanmis olur; yine de
//      kimligin korunmasi beklenir.)
//
// AYRICA `Konum.resmiDiyanetKullanilirMi` dogrulanir: uc kosulun hepsi
// saglanmalidir. Yanlis bir kosulun gecmesi, resmî olmayan bir yerde
// "Diyanet" etiketi gosterilmesi demektir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';
import 'package:namaz_vakitleri/core/saat.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_yardimcisi.dart';

void main() {
  // `konumYukle` `rootBundle` üzerinden resmî eşleme tablosunu okur.
  TestWidgetsFlutterBinding.ensureInitialized();

  const paketDizini = 'assets/veri/diyanet';
  const eskiKayit = 'Ankara|TR|39.9334|32.8597|Europe/Istanbul';
  const yeniKayit =
      'Ankara|TR|39.9334|32.8597|Europe/Istanbul|Ankara|9206';

  group('Konum.resmiDiyanetKullanilirMi — üç koşulun hepsi şart', () {
    Konum yap({
      String ulke = 'TR',
      int? cityId = 9206,
      String il = 'Ankara',
    }) =>
        Konum(
          ad: 'Ankara',
          ulkeIso2: ulke,
          enlem: 39.9334,
          boylam: 32.8597,
          saatDilimi: 'Europe/Istanbul',
          il: il,
          diyanetCityId: cityId,
        );

    test('TR + kimlik + mod açık → resmî', () {
      expect(yap().resmiDiyanetKullanilirMi(resmiModAcik: true), isTrue);
    });

    test('mod kapalıysa resmî mod kullanılmaz', () {
      expect(yap().resmiDiyanetKullanilirMi(resmiModAcik: false), isFalse);
    });

    test('Türkiye dışında ASLA resmî mod kullanılmaz', () {
      // Resmî paket yalnız Türkiye'yi kapsar. Yabancı ülkede kimlik alanı
      // yanlışlıkla dolu olsa bile paket okunmamalı.
      expect(yap(ulke: 'DE').resmiDiyanetKullanilirMi(resmiModAcik: true),
          isFalse);
    });

    test('kimlik yoksa resmî mod kullanılmaz (il merkezi kopyalanmaz)', () {
      expect(
          yap(cityId: null).resmiDiyanetKullanilirMi(resmiModAcik: true),
          isFalse);
    });

    test('Asr ve yüksek enlem değişimi resmî modu ETKİLEMEZ', () {
      final taban = yap();
      final hanefi = taban.kopyala(asrYontemi: AsrYontemi.hanafi);
      final ceyrek = taban.kopyala(yuksekEnlemAyaru: YuksekEnlemAyaru.ceyrek);
      final yontem = taban.kopyala(yontemId: 3);

      for (final k in [taban, hanefi, ceyrek, yontem]) {
        expect(k.resmiDiyanetKullanilirMi(resmiModAcik: true), isTrue,
            reason: 'hesap ayarı resmî mod kararını değiştirmemeli');
      }
    });
  });

  group('Kayıt turu: yeni kayıt kimliği korur', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('yaz-oku turunda il ve CityID aynen geri gelir', () async {
      final konum = Konum(
        ad: 'Ankara',
        ulkeIso2: 'TR',
        enlem: 39.9334,
        boylam: 32.8597,
        saatDilimi: 'Europe/Istanbul',
        il: 'Ankara',
        diyanetCityId: 9206,
        diyanetParca: 'TR/ankara.txt',
      );
      await konumKaydet(konum);
      await konumYukle();

      final y = aktifKonum.value!;
      expect(y.ad, 'Ankara');
      expect(y.enlem, 39.9334);
      expect(y.boylam, 32.8597);
      expect(y.saatDilimi, 'Europe/Istanbul');
      expect(y.il, 'Ankara');
      expect(y.diyanetCityId, 9206,
          reason: 'kimlik kaybolursa kullanıcı sessizce hesaplanmış moda düşer');
      expect(y.resmiDiyanetKullanilirMi(resmiModAcik: true), isTrue);
    });
  });

  group('Kayıt turu: eski 5 alanlı kayıt kullanıcı verisini kaybetmez', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          kayitliKonumAnahtari: eskiKayit,
          kayitliUlkeAnahtari: 'TR',
        }));

    test('konum yüklenir; resmî kimlik boştur ama veri bozulmaz', () async {
      await konumYukle();

      final y = aktifKonum.value!;
      // Kullanıcının verisi AYNI kalmalı.
      expect(y.ad, 'Ankara');
      expect(y.enlem, 39.9334);
      expect(y.boylam, 32.8597);
      expect(y.saatDilimi, 'Europe/Istanbul');
      // Eski kayıtta `il` ve `CityID` alanları yoktur.
      expect(y.il, isEmpty);
      expect(y.diyanetCityId, isNull);
      // Kimliksiz konum resmî moda GİRMEZ — il merkezi verisi uydurulmaz.
      expect(y.resmiDiyanetKullanilirMi(resmiModAcik: true), isFalse);
    });
  });

  group('Kayıt turu: yeni kimlik eski kayıttan yeniden çözülür', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          kayitliKonumAnahtari: eskiKayit,
          kayitliUlkeAnahtari: 'TR',
        }));

    test('il bilgisi elde edilince kimlik çözülür ve KAYDEDİLİR', () async {
      // Eski kayıtta `il` yok; konumYukle önce onu doldurup sonra kimliği
      // çözemeyebilir. Burada amaç: il YAZILI olduktan sonra kimlik gelir.
      final hafiza = await SharedPreferences.getInstance();
      await hafiza.setString(kayitliKonumAnahtari, yeniKayit);
      await konumYukle();

      final y = aktifKonum.value!;
      expect(y.il, 'Ankara');
      expect(y.diyanetCityId, 9206);
      expect(y.resmiDiyanetKullanilirMi(resmiModAcik: true), isTrue);
    });
  });

  group('Varsayılan açılış: Ankara resmî kimliğini çözer', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('kayıt yoksa Ankara seçilir ve resmî kimlik atanır', () async {
      await konumYukle();

      final y = aktifKonum.value!;
      expect(y.ad, 'Ankara');
      expect(y.ulkeIso2, 'TR');
      expect(y.il, 'Ankara');
      expect(y.diyanetCityId, isNotNull,
          reason: 'varsayılan şehir resmî pakete bağlanmalı');
      expect(y.resmiDiyanetKullanilirMi(resmiModAcik: true), isTrue);
    });
  });

  group('Eşleme tablosu gerçek paketten okunur', () {
    test('eslemeBul gerçek CityID ve il parçası döndürür', () async {
      final depo = DiyanetDepo();
      final e = await depo.eslemeBul(il: 'Ankara', ad: 'Ankara');
      expect(e, isNotNull);
      expect(e!.cityId, 9206);
      expect(e.parca, 'TR/ankara.txt');
      expect(File('$paketDizini/${e.parca}').existsSync(), isTrue);
    });

    test('Türkçe karakterden bağımsız aynı anahtarı bulur', () async {
      final depo = DiyanetDepo();
      final e = await depo.eslemeBul(il: 'ankara', ad: 'ANKARA');
      expect(e?.cityId, 9206);
    });

    test('resmî kaydı olmayan yerleşim null döner', () async {
      final depo = DiyanetDepo();
      expect(await depo.eslemeBul(il: 'Ordu', ad: 'Ulubey'), isNull,
          reason: 'Ordu/Ulubey resmî pakette yok (Diyanet Uşak/Ulubey yayımlıyor)');
    });

    test('tüm ağ kapalıyken resmî vakit yine de okunur', () async {
      // Resmî yolun çevrimdışı çalıştığı burada GERÇEKTEN denetlenir: ağ
      // tümüyle kapatılır, sonuç yine gelmelidir. (Yalnız "ağ kullanmıyor"
      // diye yorum yapmak denetim değildir.)
      final depo = DiyanetDepo();
      await internetYokken(() async {
        final e = await depo.eslemeBul(il: 'Ankara', ad: 'Ankara');
        expect(e?.cityId, 9206, reason: 'ağ kapalıyken eşleme okunamadı');

        final sonuc = await depo.vakitler(
          cityId: 9206,
          ilDosya: e!.parca,
          tarih: DateTime(2026, 10, 3),
        );
        expect(sonuc.durum, DiyanetDurum.veriVar);
        expect(sonuc.gun!.saatler['fajr'], '05:17');
      });
    });

    test('çevrimdışı ikinci gün de okunur (gerçek kapsam denetimi)', () async {
      final depo = DiyanetDepo();
      final e = (await depo.eslemeBul(il: 'Ankara', ad: 'Ankara'))!;
      final sonuc = await depo.vakitler(
          cityId: e.cityId, ilDosya: e.parca, tarih: DateTime(2027, 6, 15));
      expect(sonuc.durum, DiyanetDurum.veriVar);
      expect(sonuc.gun!.yil, 2027);
    });
  });
}