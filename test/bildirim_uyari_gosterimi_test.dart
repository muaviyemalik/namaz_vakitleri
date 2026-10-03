// test/bildirim_uyari_gosterimi_test.dart
//
// BİLDİRİM SONUCU KULLANICIYA DOĞRU GÖSTERİLİR.
//
// HATANIN TANIMI
//
// `AnaSayfa._alarmlariKur` motorun sonucunu alıyor ama yalnız
// `sonuc.tamZamanli` DEĞERİNİ okuyordu; `sonuc.uyari` alanı hiç okunmuyordu.
// Ekranda tek bir sabit metin gösteriliyordu:
//
//   "Tam zamanlı alarm izni yok — bildirimler yaklaşık zamanlı gelir"
//
// Bu iki yanlışı birden söylüyor:
//
//   1) YANLIŞ UYARI. Tam zamanlı alarm izni yoksa motor YAKLAŞIK moda
//      düşer ve alarmlar kurulur — uyarı doğrudur. Ama kurulum TAMAMEN
//      başarısız olduğunda motor `uyari: 'bildirim_kurulamadi'` döner ve
//      HİÇBİR alarm kurulmaz. Ekran yine de "yaklaşık zamanlı gelir"
//      diyordu: kullanıcı vakit bildirimlerinin geleceğini sanıyor,
//      gelmeyecek.
//
//   2) TESLİM GARANTİSİ. "gelir" ifadesi bir garanti. Yaklaşık modda da
//      Android cihaz kısıtları (Doze, batarya optimizasyonu) bildirimi
//      geciktirebilir; kurulamadıysa hiç gelmez. Metin ne olursa olsun
//      GELECEĞİNİ vaat etmemeli, yalnız gerçeği söylemeli.
//
// AYRICA ÖLÇÜLEN İKİ KURAL
//
//   * Başarılı yeni plan ESKİ hata uyarısını temizlemeli. Aksi halde tek
//     seferlik bir hata ekranda kalıcılaşır ve gerçeği yanlış anlatır.
//
//   * Geç kalmış ya da kaldırılmış ekranın planı güncel uyarıyı
//     DEĞİŞTİRMEMELİ. "Ankara'da kurulum başarısız oldu" uyarısı, ekran
//     kalkıp Paris'e geçtikten SONRA da Ankara için geçerli olmayı sürdürür.
//
//     ÖLÇÜM NOTU: "Ekrana yazma" iki AYRI denetimle korunur:
//       - `!mounted`: kaldırılmış ekranın `setState`'i zaten çalışmaz.
//       - `gecmisSecimMi`: ekran HAYATTA olup planı geç kalmış olan
//         durumda eski seçimin uyarısını yazmasını engeller.
//
//     Aşağıdaki widget testleri EKRAN katmanını ölçer. `gecmisSecimMi`
//     kuralının motor düzeyindeki kanıtı `bildirim_hata_durumu_test.dart`
//     içindedir ("HATALI UYGULAMADAN SONRA GEC KALAN SECIM YAZMAZ"); ikisi
//     birbirinin yerine geçmez.
//
// BU TEST NASIL KURULUYOR?
//
//   * GERÇEK ÜRETİM AKIŞI: `AnaSayfa` widget'ı, gerçek `BildirimMotoru`,
//     gerçek `BildirimPlanlayici`, gerçek `VakitDepo`, gerçek `http.get`,
//     gerçek SharedPreferences mock deposu.
//   * SAHTE OLAN YALNIZCA TAŞIMADIR: ağ (`uretim_akisi.dart`) ve bildirim
//     eklentisi. Eklenti, motorun `zonedSchedule`/`cancel` çağrılarını
//     KONTROLLÜ biçimde reddeder; hangisinin reddedileceğini test belirler.
//   * Uyarı motorun `uyari` ALANIDIR: testte uydurulmaz, motorun kendi
//     kararı okunur.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/bildirim_motoru.dart' show PlanSirasi;
import 'package:namaz_vakitleri/main.dart';

import 'ana_sayfa_bildirim_test.dart' show beklenenPlan;
import 'bildirim_hata_durumu_test.dart' as hata;
import 'uretim_akisi.dart';

/// Ekranda görünen metinlerden biri var mı?
///
/// `find.text` yerine metin parçası aranır: mesajlar cihaz diline göre
/// değişebilir, ama test Türkçe çeviriciyle çalışır.
Finder metinBul(String parca) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(parca),
      description: '"$parca" içeren metin',
    );

/// Ekranda görünen TÜM metinler.
Iterable<String> ekrandakiMetinler(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty);

void main() {
  setUpAll(() async {
    await uretimTestiBaslat();
  });

  setUp(() {
    testOrtaminiSifirla();
    bildirimYoluTasarimiAyarla(true);
    bildirimServisiDegistir(hata.HataEklentisi());
    // Sıra HER TESTE tazedir: `flutter test` her teste ayrı sahte-zaman
    // bölgesi verir, önceki testten kalan kuyruk future'ı burada ilerlemez.
    bildirimPlanSirasiDegistir(PlanSirasi());
  });

  tearDown(() {
    bildirimYoluTasarimiAyarla(null);
    bildirimServisiDegistir(FlutterLocalNotificationsPlugin());
    bildirimPlanSirasiDegistir(PlanSirasi());
    testOrtaminiKapat();
  });

  testWidgets(
      'TAM BASARISIZ KURULUMDA YAKLASIK GELIR MESAJI GOSTERILMEZ',
      (tester) async {
    final e = hata.HataEklentisi();
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      // Kurulum yapılabilsin ama HER bildirim reddedilsin: eklenti, gelen
      // kimliklerin tamamını reddeder. Kimlikler önceden bilinmez; üretim
      // planlayıcısının ürettiği küme testte hesaplanır.
      e.kurulamayan.addAll(beklenenPlan(konumAnkara).keys.toSet());

      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(e.kurulumLog, isNotEmpty,
          reason: 'ön koşul: kurulum denendi');
      expect(e.bekleyen, isEmpty,
          reason: 'ön koşul: hiçbir alarm kurulmadı');
      expect(await hata.dizin(), isEmpty,
          reason: 'ön koşul: dizinde de kimlik yok');

      // Ekranda YAKLAŞIK MOD uyarısı olmamalı: hiçbir şey kurulmadı.
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'kurulum tamamen başarısızken yaklaşık mod uyarısı '
              'gösterilmemeli');
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'teslim/vakit vaadi içeren mesaj gösterilmemeli');

      // Bunun yerine kurulum hatası uyarısı olmalı.
      expect(metinBul('bildirim_kurulamadi'), findsOneWidget,
          reason: 'gerçeği söyleyen kurulum hatası uyarısı görünmeli');
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets('BASARILI YAKLASIK MOD KENDI MESAJINI GOSTERIR', (tester) async {
    // Exact reddedilir, inexact BAŞARILI: alarmlar kurulur, yaklaşık gelir.
    final e = hata.HataEklentisi()..exactReddi = true;
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(e.bekleyen, isNotEmpty,
          reason: 'ön koşul: yaklaşık alarmlar kuruldu');

      // Yaklaşık mod kendi mesajını göstermeli (kurulum hatası DEĞİL).
      expect(metinBul('exact_alarm_yok'), findsOneWidget);
      expect(metinBul('bildirim_kurulamadi'), findsNothing,
          reason: 'alarmlar kurulduysa kurulum hatası gösterilmemeli');

      expect(tester.takeException(), isNull);
      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets('BASARILI YENI PLAN ESKI HATA UYARISINI TEMIZLER',
      (tester) async {
    final e = hata.HataEklentisi();
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(metinBul('exact_alarm_yok'), findsNothing);
      expect(metinBul('bildirim_kurulamadi'), findsNothing,
          reason: 'ön koşul: başlangıçta uyarı yok');

      // 1) Plan tamamen başarısız olur -> kurulum hatası uyarısı görünür.
      e.kurulamayan
        ..clear()
        ..addAll(beklenenPlan(konumAnkara).keys.toSet());
      erkenUyariSuresi.value = 15; // planı yeniden kurar
      await akisIlerlet(tester);
      expect(metinBul('bildirim_kurulamadi'), findsOneWidget,
          reason: 'hata uyarısı görünmeli');

      // 2) Aynı ayar tekrar değişir, bu kez kurulum başarılı -> uyarı SİLİNMELİ.
      e.kurulamayan.clear();
      erkenUyariSuresi.value = 20;
      await akisIlerlet(tester);

      expect(e.bekleyen, isNotEmpty, reason: 'ön koşul: plan kuruldu');
      expect(metinBul('bildirim_kurulamadi'), findsNothing,
          reason: 'başarılı plan eski hata uyarısını temizlemeli');
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'başarılı plan uyarı bırakmamalı');

      expect(tester.takeException(), isNull);
      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets('IPTAL HATASI KENDI UYARISINI GOSTERIR', (tester) async {
    // Kurulum hatası ile iptal hatası AYRI sorunlardır: ilki eksik alarm,
    // ikincisi artık gerekmeyen ama silinemeyen alarm. Kullanıcıya farklı
    // metin gösterilmelidir.
    final e = hata.HataEklentisi();
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      // 1) Erken uyarı AÇIK: vakit + erken uyarı bildirimleri kurulur.
      erkenUyariSuresi.value = 10;
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(e.bekleyen, isNotEmpty, reason: 'ön koşul: plan kuruldu');
      expect(metinBul('bildirim_iptal_edilemedi'), findsNothing);
      expect(metinBul('bildirim_kurulamadi'), findsNothing);

      // 2) Erken uyarı KAPALI: erken uyarı alarmları artık gereksizdir ve
      //    iptal edilmek istenir, ama iptal bir kez reddedilir.
      e.iptalHatasi = 1;
      erkenUyariSuresi.value = 0;
      await akisIlerlet(tester);

      expect(e.iptalLog, isNotEmpty, reason: 'ön koşul: iptal denendi');
      expect(metinBul('bildirim_iptal_edilemedi'), findsOneWidget,
          reason: 'iptal hatası kendi uyarısını göstermeli');
      // Kurulum başarılıydı: kurulum hatası GÖSTERİLMEMELİ.
      expect(metinBul('bildirim_kurulamadi'), findsNothing,
          reason: 'alarmlar kuruldu; kurulum hatası gösterilmemeli');
      expect(metinBul('exact_alarm_yok'), findsNothing);

      expect(tester.takeException(), isNull);
      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets(
      'GEC KALAN PLAN GUNCEL UYARIYI DEGISTIRMEZ (kaldirilmis ekran)',
      (tester) async {
    final e = hata.HataEklentisi();
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      // 1) Ankara planı kurulur (başarılı): uyarı yok.
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(metinBul('bildirim_kurulamadi'), findsNothing);
      expect(metinBul('exact_alarm_yok'), findsNothing);

      // 2) Eski ekranın planı yarıda beklerken ekran KALDIRILIR.
      //    Ankara planının kurulumu İLK çağrıda kapıda kalır.
      e.ilkKurulumuBeklet();
      erkenUyariSuresi.value = 10;
      await akisIlerlet(tester);
      expect(e.kurulumdaBekleyen, 1,
          reason: 'ön koşul: eski plan uygulanmayı bekliyor');

      await tester.pumpWidget(const SizedBox());
      await akisIlerlet(tester);

      // 3) Yeni ekran Paris ile açılır. Yeni plan, eski ekranın kuyruğunda
      //    bekleyeceği için ANKARA'nın kurulumu ÖNCE tamamlanır.
      await sayfayiAc(tester, konumParis);
      kuyruk.cevapVerIlkBekleyen(konumParis, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // Eski ekranın kuyruğu açılır: ANKARA'nın planı tamamlanır. Bu arada
      // yeni ekran İPTAL HATASI üretecek biçimde ayarlanır.
      e.kurulamayan.clear();
      e.iptalHatasi = 1;
      erkenUyariSuresi.value = 10; // Paris planı: erken uyarı alarmlarını
      // (artık gereksiz olanları) iptal etmeye çalışacak
      e.kurulumuSerbestBirak();
      await akisIlerlet(tester);

      // Kaldırılmış ekranın ANKARA planı BAŞARISIZ olsun: eski seçime ait
      // bir hata üretmemeli ekranı etkilemesin.
      e.kurulamayan.addAll(beklenenPlan(konumAnkara).keys.toSet());
      erkenUyariSuresi.value = 20; // yeni ekranın planı yeniden kurulur
      await akisIlerlet(tester);

      expect(tester.takeException(), isNull);

      // 4) YENİ ekranın planı da başarılı olsun: ekranda uyarı KALMAMALI.
      //    Kaldırılmış ekranın Ankara hatası sızsa
      //    'bildirim_kurulamadi' görünürdü.
      e.kurulamayan.clear();
      erkenUyariSuresi.value = 25;
      await akisIlerlet(tester);

      expect(aktifKonum.value!.ad, 'Paris', reason: 'ön koşul: Paris seçili');
      expect(metinBul('bildirim_kurulamadi'), findsNothing,
          reason: 'kaldırılmış ekranın hatası güncel uyarıya sızmamalı');
      expect(metinBul('exact_alarm_yok'), findsNothing);

    });
  });

  testWidgets(
      'GEC KALAN SONUC TAMAMLANIRKEN GUNCEL PLAN BEKLİYOR: EKRAN DEGİŞMEZ',
      (tester) async {
    // ÖLÇÜM: Zamanlamayı AÇIKÇA ayırmak gerekir. Zayıf testler iki planı
    // birlikte serbest bırakır ve "ekranda tek uyarı var" diye bakar; oysa
    // iki plan da aynı şeyi ürettiğinde test yine yeşil kalır ve hiçbir
    // şey ölçmez.
    //
    // Buradaki sıra ÖNEMLİDİR ve dört aşamada ölçülür:
    //
    //   A) ESKİ plan motoru uygulamaya başlar ve ORTADA bekler.
    //   B) GÜNCEL plan doğar (daha yeni seçim no alır) ama İZİN kapısında
    //      bekler: motor uygulamasına HİÇ GİRMEZ.
    //   C) ESKİ plan serbest bırakılır ve TAMAMLanır. O anda güncel plan
    //      hâlâ bekliyor olmalı. Eski sonuç ekranı DEĞİŞTİRMEMELİDİR.
    //   D) GÜNCEL plan serbest bırakılır ve KENDİ uyarısı yazılır.
    //
    // Aşama C'de ekranda güncel uyarının KENDİSİ henüz yazılmamıştır (D
    // bekleniyor); ölçtüğümüz şey eski planın kendi uyarısının da
    // yazılmamış olmasıdır.
    //
    // AYIRMA: Geç kalan seçimin MOTORDA yazılmadığı ayrıca
    // `bildirim_hata_durumu_test.dart` içinde kanıtlanır. Bu test EKRAN
    // katmanını ölçer; biri diğerinin yerine geçmez.
    final e = hata.HataEklentisi();
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      // 0) Sayfa açılır, plan tam zamanlı ve başarıyla kurulur: uyarı YOK.
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(e.bekleyen, isNotEmpty, reason: 'ön koşul: ilk plan kuruldu');
      expect(metinBul('exact_alarm_yok'), findsNothing);
      expect(metinBul('bildirim_kurulamadi'), findsNothing);

      // A) ESKİ plan: izin YOK (yaklaşık kurulum) ve kurulumu kapıda bekler.
      //    Bu plan tamamlandığında `exact_alarm_yok` uyarısını taşıyacak.
      e.android.tamZamanliVar = false;
      e.ilkKurulumuBeklet();
      erkenUyariSuresi.value = 10;
      await akisIlerlet(tester);
      expect(e.kurulumdaBekleyen, 1,
          reason: 'ön koşul: eski plan motor uygulamasında bekliyor');
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'eski plan henüz tamamlanmadı, uyarı yazılmamış olmalı');

      // B) GÜNCEL plan doğar. Kurulum YAPILAMAZ olsun (kurulum hatası
      //    uyarısı üretecek).
      //
      // GÜNCEL PLAN BURADA MOTOR UYGULAMASINDA DEĞİL, İZİN KAPISINDA
      // bekler: `PlanSirasi` PAYLAŞILAN bir kuyruktur, eski plan onu tuttuğu
      // için güncel plan zaten sıra bekliyordur. İzin kapısı güncel planı
      // motor uygulamasına GİRMEYECEK şekilde burada tutar.
      e.android.tamZamanliVar = true;
      e.kurulamayan.addAll(beklenenPlan(konumAnkara).keys.toSet());
      e.ilkIzniBeklet();
      erkenUyariSuresi.value = 20;
      await akisIlerlet(tester);
      expect(metinBul('bildirim_kurulamadi'), findsNothing,
          reason: 'güncel plan henüz tamamlanmadı');

      // C) ESKİ plan serbest bırakılır ve TAMAMLANIR. Güncel plan hâlâ
      //    bekliyor. Eski sonuç ekranı DEĞİŞTİRMEMELİDİR.
      final kurulumLogOnce = e.kurulumLog.length;
      e.kurulumuSerbestBirak();
      await akisIlerlet(tester);

      // AYIRT EDİCİ ÖN KOŞUL: güncel planın kurulumu HENÜZ denenmedi.
      // Güncel plan izin cevabını bekliyor; eski plan tamamlandı.
      //
      // AYIRICI NEDEN KURULUM MODU? İki plan da aynı şehrin (Ankara) planı
      // olduğundan kimlikleri AYNI. Eski plan izin YOK olduğu için hep
      // 'inexact' dener; güncel plan izin VAR olduğu için önce 'exact'
      // dener. Yeni denemelerde 'exact' görülmemeli.
      final yeniDenemeler = e.kurulumLog.skip(kurulumLogOnce).toList();
      expect(yeniDenemeler, isNotEmpty,
          reason: 'ön koşul: eski planın kurulumu devam etti');
      expect(yeniDenemeler.any((c) => c.startsWith('exact:')), isFalse,
          reason: 'güncel planın kurulumu henüz denenmemeli (izin kapısında '
              'bekliyor); yoksa aşama C ölçümü anlamsız olur');

      // --- ASIL ÖLÇÜM ---
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'geç kalan eski planın uyarısı ekrana YAZILMAMALI; '
              'güncel plan henüz bekliyor');
      expect(metinBul('bildirim_kurulamadi'), findsNothing);
      expect(tester.takeException(), isNull);

      // D) GÜNCEL plan serbest bırakılır: KENDİ uyarısını yazmalı.
      e.tumIzinleriSerbestBirak();
      await akisIlerlet(tester);

      expect(metinBul('bildirim_kurulamadi'), findsOneWidget,
          reason: 'güncel planın kurulum hatası uyarısı görünmeli');
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'eski planın uyarısı sonradan sızmamalı');
      expect(tester.takeException(), isNull);

      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets('IZIN BAS FALSE: BASARILI YAKLASIK KURULUM EKRANDA GORUNUR',
      (tester) async {
    // Probe'un ikinci senaryosu: izin sorgusu BAŞTAN false dönerse alarmlar
    // yaklaşık kurulur ve ekranda bunu söyleyen bir uyarı GÖRÜNMELİDİR.
    //
    // Önceden yalnız "exact denemesi sonradan reddedildi" yolunda uyarı
    // üretiliyordu; izin baştan yokken ekran sessizce geçiyordu.
    final e = hata.HataEklentisi();
    e.android.tamZamanliVar = false;
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      // Ön koşullar: izin sorgulandı, alarmlar KURULDU, tam zamanlı denenmedi.
      expect(e.android.sorguSayisi, greaterThan(0), reason: 'izin sorgulanmalı');
      expect(e.bekleyen, isNotEmpty, reason: 'yaklaşık alarmlar kurulmalı');
      expect(e.kurulumLog, isNotEmpty);
      expect(e.kurulumLog.every((c) => c.startsWith('inexact:')), isTrue,
          reason: 'izin baştan yoksa exact hiç denenmemeli');

      // Ekranda uyarı görünmeli: "sessiz kalınmamalı".
      expect(metinBul('exact_alarm_yok'), findsOneWidget,
          reason: 'izin false ve alarmlar yaklaşık: ekranda bildirilmeli');
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Kurulum hatası GÖSTERİLMEMELİ: her şey kuruldu.
      expect(metinBul('bildirim_kurulamadi'), findsNothing);

      expect(tester.takeException(), isNull);
      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets('IZIN BAS FALSE + KURULUM HATASI: HATA MESAJI GORUNUR',
      (tester) async {
    // Yaklaşık-mod mesajı, kurulum hatasını ÖRTMEMELİ. İkisi birlikte
    // varsa ağırlık sırası belirler ve burada KURULUM HATASI kazanır:
    // kullanıcı alarmın hiç gelmeyeceğini bilmeli.
    final e = hata.HataEklentisi();
    e.android.tamZamanliVar = false;
    e.kurulamayan.addAll(beklenenPlan(konumAnkara).keys.toSet());
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);

      expect(e.bekleyen, isEmpty, reason: 'ön koşul: hiç alarm kurulmadı');

      expect(metinBul('bildirim_kurulamadi'), findsOneWidget,
          reason: 'kurulum hatası görünmeli');
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'yaklaşık-mod mesajı kurulum hatasını örtmemeli');

      expect(tester.takeException(), isNull);
      await sayfayiKapat(tester, kuyruk);
    });
  });

  testWidgets('IZIN FALSE -> TRUE: EKRANDAKI UYARI TEMIZLENIR', (tester) async {
    // Kullanıcı ayarlardan tam zamanlı alarm iznini açar. Sonraki plan tam
    // zamanlı kurulur ve ekrandaki yaklaşık-mod uyarısı SİLİNMELİDİR;
    // aksi halde ekran artık doğru olmayan bir uyarıyı göstermeye devam eder.
    final e = hata.HataEklentisi();
    e.android.tamZamanliVar = false;
    final kuyruk = AgKuyrugu(konumCevabiniUret);
    bildirimServisiDegistir(e);

    await kontrolluAg(kuyruk, () async {
      await sayfayiAc(tester, konumAnkara);
      kuyruk.cevapVerIlkBekleyen(konumAnkara, yil: testYili, ay: testAyi);
      await akisIlerlet(tester);
      expect(metinBul('exact_alarm_yok'), findsOneWidget,
          reason: 'ön koşul: uyarı görünüyor');

      // Yalnız sistem ayarlarından dönülür; şehir/erken uyarı değişmez.
      final istekSayisi = kuyruk.istekler.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      e.android.tamZamanliVar = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await akisIlerlet(tester);

      expect(e.kurulumLog.any((c) => c.startsWith('exact:')), isTrue,
          reason: 'izin açıldıktan sonra exact denenmeli');
      expect(metinBul('exact_alarm_yok'), findsNothing,
          reason: 'başarılı tam zamanlı kurulum uyarıyı temizlemeli');
      expect(kuyruk.istekler.length, istekSayisi,
          reason: 'izin değişimi için vakitleri yeniden indirmek gerekmez');

      // Aynı gün izin geri alınırsa uyarı ve yaklaşık plan geri gelir.
      final oncekiKurulumlar = e.kurulumLog.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      e.android.tamZamanliVar = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await akisIlerlet(tester);
      final yeniKurulumlar = e.kurulumLog.skip(oncekiKurulumlar).toList();
      expect(yeniKurulumlar, isNotEmpty);
      expect(yeniKurulumlar.every((c) => c.startsWith('inexact:')), isTrue);
      expect(metinBul('exact_alarm_yok'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await sayfayiKapat(tester, kuyruk);
    });
  });
}
