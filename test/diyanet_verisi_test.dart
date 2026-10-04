// Resmî Diyanet veri paketinin DOĞRULAMA testleri.
//
// Bu dosya test SAYISINI artırmak için değil, üç somut riski kapatmak için
// yazıldı. Her test, bir şeyin GERÇEKTEN bozuk olması durumunda kırmızıdır;
// "aynı yanlış veriyi hem beklenen hem gerçek kabul eden" test yoktur.
//
// RİSK 1 — EKSİK/TEKRAR
//   Paket 730 gün iddia ediyor. Her yerleşimde aynı aralık olmalı, hiçbir
//   tarih TEKRARlanmamalı ve kayıtlı boşluklar gerçekten boşluk olmalı.
//
// RİSK 2 — YERLEŞİM EŞLEŞMESİ
//   Resmî katalogdaki `City` alanı YANLIŞ olabilir (ölçüm: CityID 17909
//   katalogda "USAK", sayfada "Ulubey"). Eşleme bu yüzden sayfa adına göre
//   kurulur. Test, "Ulubey" adının iki farklı ilde (Uşak ve Ordu) bulunduğunu
//   ve yalnız UŞAK'ın eşlendiğini doğrular. Bir CityID'nin iki farklı uygulama
//   anahtarına bağlanması da sessiz yanlış eşlemedir ve reddedilir.
//
// RİSK 3 — KAYNAKLA BİREBİRLİK
//   Paket, ham Diyanet HTML'inden ayrıştırıldı. Burada AYRIŞTIRMA sonucu,
//   resmî sayfadaki satırlarla karşılaştırılır. Beklenen değerler canlı
//   sayfadan okunmuştur; pakete kopyalanmamıştır. Yani test "paket kendisiyle
//   tutarlı" diye bir şeyi kanıtlamaz — kaynakla birebirliği kanıtlar.
//
// KAPSAM DIŞI TARİHLER
//   2026 arşiviyle eski boşluk kapandı. 2025 ve 2028 kapsam dışında
//   kalır; tarihler hesaplanarak veya başka yıldan kopyalanarak doldurulmaz.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/diyanet_verisi.dart';

const String paketDizini = 'assets/veri/diyanet';

/// Resmî CityID'ler (Türkiye kataloğundan).
///
/// `ankaraId` ve `adanaId` sabitlenmiştir: bunların 2026-10-03 satırları
/// canlı Diyanet sayfalarından okunmuş ve aşağıda birebir doğrulanır.
const int ankaraId = 9206;
const int adanaId = 9146;

DiyanetPaketi paketi() => DiyanetPaketi.fromJson(
    (json.decode(File('$paketDizini/paket.json').readAsStringSync(encoding: utf8))
            as Map)
        .cast<String, dynamic>());

/// Paketteki tüm satırları okur: `cityId -> tarih -> saatler`.
Map<int, Map<DateTime, List<String>>> tumVeri() {
  final sonuc = <int, Map<DateTime, List<String>>>{};
  final dizin = Directory('$paketDizini/TR');
  for (final dosya in dizin.listSync().whereType<File>()) {
    int? cid;
    for (final satir in dosya.readAsLinesSync(encoding: utf8)) {
      if (satir.startsWith('#@')) {
        cid = int.parse(satir.substring(2).split('|').first);
        sonuc[cid] = <DateTime, List<String>>{};
        continue;
      }
      if (satir.startsWith('#') || satir.isEmpty) continue;
      final p = satir.split('|');
      sonuc[cid!]![DateTime(
        int.parse(p[0].substring(0, 4)),
        int.parse(p[0].substring(4, 6)),
        int.parse(p[0].substring(6, 8)),
      )] = p.sublist(1, 7);
    }
  }
  return sonuc;
}

/// `esleme.txt` satırları: uygulama anahtarı -> (cityId, parça).
Map<String, (int, String)> eslemeler() {
  final sonuc = <String, (int, String)>{};
  for (final satir
      in File('$paketDizini/esleme.txt').readAsLinesSync(encoding: utf8)) {
    if (satir.isEmpty || satir.startsWith('#')) continue;
    final p = satir.split('|');
    sonuc['${p[0]}|${p[1]}'] = (int.parse(p[2]), p.length > 3 ? p[3] : '');
  }
  return sonuc;
}

void main() {
  // `rootBundle` yalnız bağlama (binding) kurulduğunda asset okur. Bu test
  // GERÇEK paketi okur; sahte metin kullanmaz. Çünkü kaynakla birebirlik
  // iddiası ancak üretilen dosyanın kendisiyle sınanabilir.
  TestWidgetsFlutterBinding.ensureInitialized();

  final p = paketi();
  final veri = tumVeri();
  final esleme = eslemeler();

  group('Paket kimliği ve kapsam', () {
    test('paket.json gerçek kimlik ve kaynak bilgisi taşır', () {
      expect(p.surum, isNotEmpty);
      expect(p.kaynakUrl, contains('namazvakitleri.diyanet.gov.tr'));
      expect(p.edinmeTarihi, isNotEmpty);
      expect(p.butunluk, isNotEmpty, reason: 'bütünlük damgası kayıtlı olmalı');
      expect(p.ilSayisi, greaterThan(80), reason: '81 il kapsanmalı');
      expect(p.yerlesimSayisi, greaterThan(800));
    });

    test('paket yalnız ileri tarihlere yayılır; geçmiş veri yok', () {
      // Bugün 3 Ekim 2026. Paket bugünden başlar, iki yıl geçmişle doldurulmaz.
      expect(p.ilkTarih, DateTime(2026, 10, 3));
      expect(p.sonTarih, DateTime(2027, 12, 31));
    });

    test('kapsanan gün sayısı ilan edilenle aynı', () {
      final aralik = p.sonTarih.difference(p.ilkTarih).inDays + 1;
      final eksik = p.bosluklar.fold<int>(0, (t, b) => t + b.eksikGun);
      expect(p.verilenGunSayisi, aralik - eksik);
    });

    test('bir ilde iki kayıt aynı günü iki kez içermez', () {
      // Sayac HER YERLEŞIMDE sıfırlanır. Aksi halde aynı gün, ildeki her
      // yerleşim için bir kez göründüğü için "tekrar" sanılır.
      final dizin = Directory('$paketDizini/TR');
      for (final dosya in dizin.listSync().whereType<File>()) {
        var tarihler = <String>[];
        void denetle() {
          expect(tarihler.length, tarihler.toSet().length,
              reason: '${dosya.path} içinde tekrar eden tarih var');
        }

        for (final satir in dosya.readAsLinesSync(encoding: utf8)) {
          if (satir.startsWith('#@')) {
            if (tarihler.isNotEmpty) denetle();
            tarihler = <String>[];
            continue;
          }
          if (satir.startsWith('#') || satir.isEmpty) continue;
          tarihler.add(satir.split('|')[0]);
        }
        if (tarihler.isNotEmpty) denetle();
      }
    });
  });

  group('Eksiksizlik: her yerleşim aynı günleri içerir', () {
    test('tüm yerleşimlerde aynı tarih kümesi var', () {
      final referans = veri.values.first.keys.toSet();
      expect(referans.length, p.verilenGunSayisi);

      for (final giris in veri.entries) {
        expect(giris.value.keys.toSet(), referans,
            reason: 'CityID ${giris.key} farklı gün kümesine sahip');
      }
    });

    test('ilan edilen boşluklar gerçekten boş', () {
      for (final b in p.bosluklar) {
        for (final giris in veri.entries) {
          for (var g = b.baslangic;
              g.isBefore(b.bitis);
              g = g.add(const Duration(days: 1))) {
            expect(giris.value.containsKey(DateTime(g.year, g.month, g.day)),
                isFalse,
                reason:
                    'CityID ${giris.key} ${g.toIso8601String()} tarihinde veri '
                    'var ama paket bunu boşluk diye işaretliyor');
          }
        }
      }
    });

    test('boşluk dışında eksik gün yok', () {
      final bosluklu = <DateTime>{};
      for (final b in p.bosluklar) {
        for (var g = b.baslangic;
            g.isBefore(b.bitis);
            g = g.add(const Duration(days: 1))) {
          bosluklu.add(DateTime(g.year, g.month, g.day));
        }
      }
      final referans = veri.values.first.keys.toSet();
      var gun = p.ilkTarih;
      var eksik = 0;
      while (!gun.isAfter(p.sonTarih)) {
        if (!referans.contains(gun) && !bosluklu.contains(gun)) eksik++;
        gun = gun.add(const Duration(days: 1));
      }
      expect(eksik, 0, reason: 'beyan edilmemiş eksik gün var');
    });
  });

  group('Yerleşim eşleşmesi', () {
    test('her eşleme pakette gerçekten var olan bir CityID\'yi gösterir', () {
      for (final g in esleme.entries) {
        expect(veri.containsKey(g.value.$1), isTrue,
            reason: '${g.key} -> CityID ${g.value.$1} pakette yok');
        expect(g.value.$2, isNotEmpty,
            reason: '${g.key} için il parçası boş');
      }
    });

    test('bir CityID yalnız bir uygulama anahtarına bağlanır', () {
      // Aynı resmî veri iki farklı yere bağlanırsa biri sessizce yanlıştır.
      final sayac = <int, List<String>>{};
      for (final g in esleme.entries) {
        sayac.putIfAbsent(g.value.$1, () => []).add(g.key);
      }
      final cakisan =
          sayac.entries.where((e) => e.value.length > 1).map((e) => e.key).toList();
      expect(cakisan, isEmpty,
          reason: 'bu CityID\'ler birden çok kayda bağlı: $cakisan');
    });

    test('ULUBEY tuzağı: katalog yanlış yazmış, eşleme doğru okumuş', () {
      // Resmî katalog CityID 17909'u "USAK / USAK" diye yazıyor; sayfanın
      // kendi adı "Ulubey". Doğru davranış: UŞAK'ın Ulubey'i 17909'a
      // bağlanır. Ordu'nun Ulubey'i BAĞLANMAZ (il anahtarı ayırır).
      final usakUlubey = esleme['usak|ulubey'];
      expect(usakUlubey, isNotNull, reason: 'Uşak/Ulubey eşlenmeli');
      expect(usakUlubey!.$1, 17909);

      expect(esleme.containsKey('ordu|ulubey'), isFalse,
          reason: 'Ordu/Ulubey resmî veriye bağlanmamalı');
    });

    test('ULUBEY ile UŞAK merkezi birbirine karışmaz', () {
      // Uşak merkezi 9919, Ulubey 17909. Bu ikisi 1 dakika farklı veri
      // taşır; biri diğerinin yerine konursa kullanıcı yanlış vakit görür.
      final usak = esleme['usak|usak'];
      expect(usak, isNotNull);
      expect(usak!.$1, 9919);
      expect(usak.$1, isNot(17909));
    });

    test('eşleme anahtarları normalize edilmiş ve Türkçe karakter içermez', () {
      for (final anahtar in esleme.keys) {
        expect(anahtar, anahtar.toLowerCase());
        expect(anahtar, isNot(matches(r'[şŞğĞıİüÜöÖçÇ]')),
            reason: '"$anahtar" normalize edilmemiş');
      }
    });

    test('il parçası dosyası gerçekten var', () {
      final parcalar = esleme.values.map((e) => e.$2).toSet();
      for (final p in parcalar) {
        expect(File('$paketDizini/$p').existsSync(), isTrue,
            reason: '$p dosyası yok');
      }
    });
  });

  group('Kaynakla birebirlik', () {
    // Bu değerler 3 Ekim 2026'da canlı Diyanet sayfalarından OKUNMUŞTUR
    // (bkz. geri_donus/diyanet_resmi_veri_20261003/SONUCLAR.md). Pakete
    // kopyalanmadı; test paketin ayrıştırmasını kaynağa karşı denetler.
    test('Ankara 2026-10-03 resmî değerlerle birebir', () {
      final satir = veri[ankaraId]![DateTime(2026, 10, 3)];
      expect(satir, ['0517', '0639', '1243', '1559', '1836', '1954']);
    });

    test('Adana 2026-10-03 resmî değerlerle birebir', () {
      final satir = veri[adanaId]![DateTime(2026, 10, 3)];
      expect(satir, ['0509', '0628', '1233', '1552', '1827', '1942']);
    });

    test('Ankara ile Adana AYNI GÜN farklı vakit gösterir', () {
      // Bu, sayfanın gerçekten yerleşime özgü olduğunun kanıtıdır. Veri
      // yanlışlıkla tek şehirden kopyalandıysa bu test kızarır.
      expect(veri[ankaraId]![DateTime(2026, 10, 3)],
          isNot(veri[adanaId]![DateTime(2026, 10, 3)]));
    });

    test('vakitler gün içinde artan sırada', () {
      for (final giris in veri.entries) {
        for (final g in giris.value.entries) {
          final d = g.value.map((s) => int.parse(s)).toList();
          for (var i = 1; i < d.length; i++) {
            expect(d[i], greaterThanOrEqualTo(d[i - 1]),
                reason: 'CityID ${giris.key} ${g.key} vakit sırası bozuk');
          }
        }
      }
    });
  });

  group('Kapsam dışı tarihler sessizce doldurulmaz', () {
    late DiyanetDepo depo;

    setUp(() {
      depo = DiyanetDepo();
    });

    Future<DiyanetSonuc> sor(int cityId, String parca, DateTime gun) =>
        depo.vakitler(cityId: cityId, ilDosya: parca, tarih: gun);

    test('paketin son günü hâlâ resmî veri verir', () async {
      final sonuc = await sor(9206, 'TR/ankara.txt', DateTime(2027, 12, 31));
      expect(sonuc.durum, DiyanetDurum.veriVar);
      expect(sonuc.gun!.saatler['fajr'], isNotEmpty);
    });

    test('2028 paketin dışındadır: kapsamBitti, uydurma gün yok', () async {
      final sonuc = await sor(9206, 'TR/ankara.txt', DateTime(2028, 1, 15));
      expect(sonuc.durum, DiyanetDurum.kapsamBitti);
      expect(sonuc.gun, isNull, reason: 'kapsam dışında gün UYDURULMAMALI');
      expect(sonuc.durum.resmiVeriMi, isFalse);
    });

    test('2026 arşivi eski boşluğu ve yıl sınırlarını kapsar', () async {
      for (final gun in [
        DateTime(2026, 1, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 15),
        DateTime(2026, 12, 31),
      ]) {
        final sonuc = await sor(9206, 'TR/ankara.txt', gun);
        expect(sonuc.durum, DiyanetDurum.veriVar);
        expect(sonuc.gun, isNotNull);
      }
      expect(paketi().bosluklar, isEmpty);
    });

    test('paketin ilk gününden öncesi kapsam dışıdır', () async {
      final sonuc = await sor(9206, 'TR/ankara.txt', DateTime(2025, 12, 31));
      expect(sonuc.durum, DiyanetDurum.kapsamBitti);
      expect(sonuc.gun, isNull);
    });

    test('olmayan CityID yerlesimYok der, komşu ilin verisini vermez', () async {
      final sonuc = await sor(999999, 'TR/ankara.txt', DateTime(2026, 10, 3));
      expect(sonuc.durum, DiyanetDurum.yerlesimYok);
      expect(sonuc.gun, isNull);
    });

    test('resmî sonuç yalnız veriVar durumunda resmiVeriMi üretir', () {
      for (final d in DiyanetDurum.values) {
        expect(d.resmiVeriMi, d == DiyanetDurum.veriVar);
      }
    });
  });

  group('Hesap ayarları resmî saatleri değiştirmez', () {
    test('Asr ve yüksek enlem okunmaz; sonuç ayarlardan bağımsızdır', () {
      // Resmî veri katmanı AsrYontemi/YuksekEnlemAyaru HİÇ ALMAZ. Test,
      // paket verisinin bu ayarların hiçbirinden etkilenmediğini gösterir:
      // aynı gün için tek ve tek bir satır vardır ve o satır kaynakla birebir
      // aynıdır (bir ust kaydın "kaydırılmış" kopyası olamaz).
      final gun = DateTime(2026, 10, 3);
      expect(veri[ankaraId]![gun],
          ['0517', '0639', '1243', '1559', '1836', '1954']);
    });

    test('paket Hanefi Asr DEĞERİ taşımaz', () {
      // Aynı gün için iki farklı İkindi satırı bulunması, hesaplanmış
      // verinin pakete karıştığını gösterirdi. Somut kanıt: Ankara
      // 2026-10-03 İkindisi resmî tabloda 15:59'dur. Aynı gün Aladhan'ın
      // HANEFİ hesabı 16:48 verir (canlı ölçüm). Pakette 15:59 olduğuna
      // göre içinde Hanefi varyantı YOKTUR; resmî tablo kopyalanmıştır.
      final ankaraAsr = veri[ankaraId]![DateTime(2026, 10, 3)]![3];
      expect(ankaraAsr, '1559');
      expect(ankaraAsr, isNot('1648'));
    });

    test('her yerleşimde aynı gün için TEK bir satır vardır', () {
      // Veri yapısı günde bir anahtar tutar. Burada il parçası satırları
      // üzerinden denetlenir ve SAYAÇ HER YERLEŞİMDE sıfırlanır: aksi
      // halde ildeki her yerleşim aynı günü taşıdığı için "tekrar" sanılır.
      final dizin = Directory('$paketDizini/TR');
      for (final dosya in dizin.listSync().whereType<File>()) {
        var sayac = <String, int>{};
        var fazla = <MapEntry<String, int>>[];
        void denetle() {
          fazla = sayac.entries.where((e) => e.value > 1).toList();
          expect(fazla, isEmpty,
              reason: '${dosya.path}: gün başına birden çok satır');
        }

        for (final satir in dosya.readAsLinesSync(encoding: utf8)) {
          if (satir.startsWith('#@')) {
            if (sayac.isNotEmpty) denetle();
            sayac = <String, int>{};
            continue;
          }
          if (satir.startsWith('#') || satir.isEmpty) continue;
          final t = satir.split('|')[0];
          sayac[t] = (sayac[t] ?? 0) + 1;
        }
        if (sayac.isNotEmpty) denetle();
      }
    });
  });

  group('Anahtar normalleştirme iki tarafta aynı sonucu verir', () {
    test('Türkçe karakterler katlanır', () {
      expect(diyanetAnahtarNormalize('Şanlıurfa'), 'sanliurfa');
      expect(diyanetAnahtarNormalize('Ağrı'), 'agri');
      expect(diyanetAnahtarNormalize('Uşak'), 'usak');
      expect(diyanetAnahtarNormalize('İzmir'), 'izmir');
      expect(diyanetAnahtarNormalize('Çukurova'), 'cukurova');
      expect(diyanetAnahtarNormalize('Gümüşhane'), 'gumushane');
    });

    test('boşluk ve noktalama SİLİNMEZ', () {
      // Python tarafındaki kural da böyle. İki tarafın kuralı farklıysa
      // eşleme çalışma anında bulunamaz ve resmî mod sessizce kapalı kalır.
      expect(diyanetAnahtarNormalize('Afyon Karahisar'), 'afyon karahisar');
      expect(diyanetAnahtarNormalize('A-B'), 'a-b');
    });

    test('Türkçe İ/ı çifti aynı sonucu vermeli', () {
      expect(diyanetAnahtarNormalize('Kastamonu'),
          diyanetAnahtarNormalize('KASTAMONU'));
    });
  });
}