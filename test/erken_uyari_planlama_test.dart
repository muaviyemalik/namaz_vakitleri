// Erken uyari PLANLAMASI denetimi: bildirim sisteme veriliyor mu?
//
// Zaman hesabi `erken_uyari_zamani_test.dart` icinde sinaniyor. Bu dosya
// onun BIR ADIM USTUNU denetler: hesaplanan zaman gercekten alarm olarak
// PLANLANIYOR mu, yoksa sadece hesaplanip birakiliyor mu?
//
// MIMARI DEGISIKLIK (2026-09-26)
// --------------------------------
// ONCEDEN bu test `lib/pages/anasayfa.dart` kaynak kodunu OKUYUP
// `_gunlukBildirimleriZamanla`, `_erkenUyariAlarmiKur`, `vakitIdBasi`
// gibi sembol adlarini ariyordu. Yeni motor `lib/core/bildirim_motoru.dart`
// icine tasindi ve kimlikler artik sabit bantlar DEGIL, tarih+vakit+tur
// karmasidir. Bu yuzden sembol adi aramak yanlis ve kırılgandı.
//
// SIMDI bu test iki sey yapiyor:
//   1) Kaynak denetimi: eski kirilgan kaliptilar ve `cancelAll()`
//      kullanimi KODDA KALMAMALI.
//   2) Davranis denetimi: motorun AYRI kanal ve AYRI kimlik kullandigi
//      `bildirim_motoru_test.dart` icinde GERCEKTEN test edilir.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Yorum satirlarini cikarir. Kaynak denetimi icin gerekir: bir
/// aciklamada geceen sembol adi ("cancelAll() kullanilmiyor") gercek
/// kod sayilmamalidir.
String koddan(String kaynak) => kaynak
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') &&
        // XML yorumlari: <!-- ... -->
        !l.trimLeft().startsWith('<!--') &&
        !l.trimLeft().contains('-->'))
    .join('\n');

/// Bir metodun govdesini metin olarak cikarir: imzadan sonraki ilk
/// satir ile, girintisi 2 olan `}` satirinin arasindaki bolum.
String metodGovdesi(String kaynak, String imza) {
  final int bas = kaynak.indexOf(imza);
  if (bas < 0) return '';
  final List<String> satirlar = kaynak.substring(bas).split('\n');
  final List<String> govde = <String>[];
  for (final l in satirlar.skip(1)) {
    // Metot sonu: sinif ici girintisinde kapanan suslu parantez.
    if (l.trimRight() == '  }') break;
    govde.add(l);
  }
  return govde.join('\n');
}

void main() {
  late String anasayfa;
  late String motor;

  setUpAll(() {
    // Yorum satirlari cikarilir: aciklamalarda geceen sembol adi
    // (or. "cancelAll() artik kullanilmiyor") gercek kod sayilmamali.
    anasayfa = koddan(
        File('lib/pages/anasayfa.dart').readAsStringSync(encoding: utf8));
    motor = koddan(
        File('lib/core/bildirim_motoru.dart').readAsStringSync(encoding: utf8));
  });

  group('Planlama yeni motor tarafindan yapilir', () {
    test('alarm planlama `lib/core/bildirim_motoru.dart` icindedir', () {
      expect(motor.contains('class BildirimPlanlayici'), isTrue,
          reason: 'Saf planlayici sinifi yok');
      expect(motor.contains('List<PlanlananBildirim>'), isTrue);
      expect(motor.contains('PlanOzeti planla('), isTrue);
    });

    test('anasayfa motoru cagirir, planlamayi kendisi yapmaz', () {
      expect(anasayfa.contains('BildirimPlanlayici'), isTrue,
          reason: 'Ana sayfa planlayıcıyı kullanmalı');
      expect(anasayfa.contains('zonedSchedule'), isFalse,
          reason: 'zonedSchedule motorda olmalı, ana sayfada değil');
    });

    test('erken uyarı AYRI bir tur olarak planlanir', () {
      expect(motor.contains('enum BildirimTuru'), isTrue);
      expect(motor.contains('erkenUyari'), isTrue,
          reason: 'Erken uyarı türü yok');
      expect(motor.contains('BildirimTuru.vakit'), isTrue);
    });

    test('her iki tür için AYRI kanal kullanilir', () {
      expect(motor.contains("vakitKanal = 'ezan_kanali_arka_plan'"), isTrue);
      expect(motor.contains("erkenUyariKanal = 'erken_uyari_kanali'"), isTrue);
      // Kanal seçimi türe göre yapılır.
      expect(motor.contains('switch (b.tur)'), isTrue,
          reason: 'Kanal seçimi türe göre yapılmalı');
    });

    test('güneş doğuşu AYRI bir tur olarak ve varsayılan KAPALI', () {
      expect(motor.contains('gunesDogumu'), isTrue);
      expect(motor.contains('gunesDogumuKanal'), isTrue);
      expect(anasayfa.contains('gunesDogumuBildirimiAcik'), isTrue,
          reason: 'Kullanıcı ayarı ana sayfada okunmalı');
      // Varsayılan kapalı olmalı.
      expect(anasayfa.contains('ValueNotifier<bool> gunesDogumuBildirimiAcik'),
          isFalse,
          reason: 'Varsayılan tanımı main.dart içinde olmalı');
      final main = koddan(File('lib/main.dart').readAsStringSync(encoding: utf8));
      expect(main.contains('ValueNotifier<bool> gunesDogumuBildirimiAcik'),
          isTrue);
      expect(main.contains('false'), isTrue);
    });
  });

  group('Kimlikler tarih + vakit + turden uretilir (sabit bant DEGIL)', () {
    test('sabit kimlik bantlari kaldirildi', () {
      expect(motor.contains('vakitIdBasi'), isFalse,
          reason: 'Sabit 100+sıra bandı kaldırılmalı');
      expect(motor.contains('erkenUyariIdBasi'), isFalse,
          reason: 'Sabit 200+sıra bandı kaldırılmalı');
      expect(anasayfa.contains('vakitIdBasi'), isFalse);
      expect(anasayfa.contains('erkenUyariIdBasi'), isFalse);
    });

    test('kimlik anahtari tarih + vakit + tur iceriyor', () {
      expect(motor.contains('String kimlikAnahtari('), isTrue);
      expect(motor.contains('namaz_vakitleri|'), isTrue,
          reason: 'Kimlik anahtarı motora özel olmalı');
      // Anahtar bilesenleri: yil, ay, gun, vakit, tur.
      expect(motor.contains('tarih.year'), isTrue);
      expect(motor.contains('tarih.month'), isTrue);
      expect(motor.contains('tarih.day'), isTrue);
      expect(motor.contains('tur.name'), isTrue);
    });

    test('kimlik karmasi 31-bit araliginda', () {
      expect(motor.contains('0x7fffffff'), isTrue,
          reason: 'int32 sınır maskesi uygulanmalı');
    });
  });

  group('Körlemesine cancelAll() YOK', () {
    test('`cancelAll()` hicbir yerde çağrılmıyor', () {
      expect(anasayfa.contains('.cancelAll()'), isFalse,
          reason: 'Tüm uygulama bildirimleri körlemesine silinmemeli');
      expect(motor.contains('.cancelAll()'), isFalse);
    });

    test('motor yalnız KENDİ kimliklerini iptal eder', () {
      expect(motor.contains('_kimlikDiziniAnahtari'), isTrue,
          reason: 'Sahiplenenen kimlik listesi tutulmalı');
      // İptal listesi "eskiden kalıp hedefte OLMAYAN" kimliklerdir: hedef,
      // yeni planın istediği kimliklerdir.
      expect(motor.contains('eski.difference(hedef)'), isTrue,
          reason: 'Eski plandan kalanlar kimlik bazında iptal edilmeli');
      expect(motor.contains('kendiPlaniniIptalEt'), isTrue);
    });
  });

  group('Kırılgan saniyelik tetik kaldırıldı', () {
    test('`erkenUyariSaniyesi` kalıntısı yok', () {
      expect(anasayfa.contains('erkenUyariSaniyesi'), isFalse,
          reason: 'Eski kırılgan tetik hâlâ kodda');
    });

    test('`formatliFark == "00:00:00"` ile anlık bildirim yok', () {
      expect(anasayfa.contains('formatliFark == "00:00:00"'), isFalse,
          reason: 'Eski anlık bildirim tetiği hâlâ kodda');
    });

    test('sayaç yalnızca ekranı güncelliyor', () {
      final String govde =
          metodGovdesi(anasayfa, 'void kalanSureyiHesapla()');
      expect(govde, isNotEmpty, reason: 'Metot govdesi bulunamadı');

      expect(govde.contains('setState'), isTrue,
          reason: 'Sayaç ekranı güncellemeye devam etmeli');
      expect(govde.contains('zonedSchedule'), isFalse,
          reason: 'Sayaç alarm kurmamalı');
    });

    test('sayaç seçili ŞEHRİN saatini kullanır (cihaz saati DEĞİL)', () {
      final String govde =
          metodGovdesi(anasayfa, 'void kalanSureyiHesapla()');
      expect(govde, isNotEmpty, reason: 'Metot govdesi bulunamadı');
      expect(govde.contains('sehirSaati.simdi()'), isTrue,
          reason: 'Sayaç şehrin saatini kullanmalı');
      // `DateTime.now()` yalnız VERİ TAZELİĞİ ölçümü için kullanılabilir
      // ("ne kadar önce güncellendi"); vakit hesabında KULLANILMAZ.
      expect(govde.contains('DateTime.now()'), isFalse,
          reason: 'Sayaç cihaz saatini kullanmamalı');
    });
  });

  group('Ayar değişince alarmlar yeniden kurulur', () {
    test('erkenUyariSuresi dinleyicisi kayıtlı VE kaldırılıyor', () {
      expect(anasayfa.contains('erkenUyariSuresi.addListener('), isTrue,
          reason: 'Ayar değişimine tepki verilmiyor');
      expect(anasayfa.contains('erkenUyariSuresi.removeListener('), isTrue,
          reason: 'Dinleyici kaldırılmıyor (bellek sızıntısı)');
    });

    test('güneş doğuşu ayarı da dinleyiciye bağlı', () {
      expect(anasayfa.contains('gunesDogumuBildirimiAcik.addListener('), isTrue);
      expect(anasayfa.contains('gunesDogumuBildirimiAcik.removeListener('),
          isTrue);
    });

    test('dinleyici planı yeniden kuruyor', () {
      final int i = anasayfa.indexOf('Future<void> _alarmAyariDegisti()');
      expect(i, greaterThan(-1));
      final String govde = anasayfa.substring(i, i + 300);
      expect(govde.contains('_alarmlariKur()'), isTrue,
          reason: 'Ayar değişince alarmlar yeniden planlanmıyor');
    });
  });

  group('DIL degisince plan yeniden kurulur', () {
    test('didChangeDependencies dili izliyor', () {
      expect(anasayfa.contains('didChangeDependencies'), isTrue);
      expect(anasayfa.contains('_sonDil'), isTrue,
          reason: 'Önceki dil tutulmalı ki değişim saptanabilsin');
    });

    test('dil değişince _alarmlariKur çağrılıyor', () {
      // Planlanan bildirim metinleri alarm anında üretilir; dil değişirse
      // yeniden üretilmelidir.
      expect(anasayfa.contains('_alarmlariKur'), isTrue);
    });
  });

  group('Izin reddi sessizce yutulmaz', () {
    test('tam zamanlı alarm sonucu kullanıcıya gösteriliyor', () {
      // Uyarı motorun `uyari` ALANI üzerinden ekrana çizilir. Yaklaşık mod
      // artık ayrı bir bool değil, `exact_alarm_yok` uyarısıdır: bool ve
      // uyarı ayrı tutulduğunda "bool false ama uyarı null" gibi sessiz ve
      // tutarsız durumlar oluşuyordu.
      expect(anasayfa.contains('_bildirimUyarisi'), isTrue,
          reason: 'motor sonucu ekrana baglanmali');
      expect(anasayfa.contains('sonuc.uyari'), isTrue,
          reason: 'motorun uyari alani okunmali');
      // Uyarı metni `_bildirimUyarisi?.tr()` ile çizilir: motorun `uyari`
      // degeri doğrudan çeviri anahtarıdır. Anahtar adları motor tarafında
      // üretilir (bkz. `BildirimMotoru.uyariAgirlikSirasi`).
      expect(anasayfa.contains('_bildirimUyarisiMetni'), isTrue,
          reason: 'uyari metni ekrana baglanmali');
      expect(anasayfa.contains('exact_alarm_yok'), isTrue,
          reason: 'İzin yoksa kullanıcıya bildirilmeli');
    });

    test('motor tam zamanlı/yaklaşık ayrımını korur', () {
      expect(motor.contains('tamZamanliIzinVar'), isTrue);
      expect(motor.contains('exactAllowWhileIdle'), isTrue);
      expect(motor.contains('inexactAllowWhileIdle'), isTrue);
      // Uyarı anahtarı motorda üretiliyor ve `uyari` alanına geçiriliyor;
      // ağırlık sırası hangi hatanın bildirileceğini belirler.
      expect(motor.contains("'exact_alarm_yok'"), isTrue,
          reason: 'Yaklaşık moda düşüş kullanıcıya bildirilmeli');
      expect(motor.contains('bildirim_kurulamadi'), isTrue,
          reason: 'Kurulamayan bildirim de bildirilmeli');
      expect(motor.contains('bildirim_iptal_edilemedi'), isTrue,
          reason: 'İptal edilemeyen bildirim de bildirilmeli');
    });
  });

  group('Manifest: zamanlanmis bildirim aliclari VAR', () {
    late String manifest;

    setUpAll(() {
      manifest = koddan(File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync(encoding: utf8));
    });

    test('ScheduledNotificationReceiver tanimli', () {
      expect(manifest.contains('ScheduledNotificationReceiver'), isTrue,
          reason: 'Bu alıcı olmadan zonedSchedule ÇALIŞMAZ');
    });

    test('ScheduledNotificationBootReceiver tanimli', () {
      expect(manifest.contains('ScheduledNotificationBootReceiver'), isTrue,
          reason: 'Yeniden başlatma sonrası plan geri gelmez');
    });

    test('BOOT_COMPLETED ve MY_PACKAGE_REPLACED dinleniyor', () {
      expect(manifest.contains('android.intent.action.BOOT_COMPLETED'), isTrue);
      expect(manifest.contains('android.intent.action.MY_PACKAGE_REPLACED'),
          isTrue);
    });

    test('USE_EXACT_ALARM YOK, yalniz SCHEDULE_EXACT_ALARM var', () {
      // Yorumlari temizlenmis metinde araniyor; yine de kesin olmak icin
      // yalnizca <uses-permission> satirina bakiyoruz.
      final izinler = manifest
          .split('\n')
          .where((l) => l.contains('<uses-permission'))
          .toList();
      expect(izinler.any((l) => l.contains('USE_EXACT_ALARM')), isFalse,
          reason: 'Gerekçesiz iki izin birlikte istenmemeli');
      expect(izinler.any((l) => l.contains('SCHEDULE_EXACT_ALARM')),
          isTrue);
    });
  });
}
