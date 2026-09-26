// Erken uyari PLANLAMASI denetimi: bildirim sisteme veriliyor mu?
//
// Zaman hesabi `erken_uyari_zamani_test.dart` icinde sinaniyor. Bu dosya
// onun BIR ADIM USTUNU denetler: hesaplanan zaman gercekten alarm olarak
// PLANLANIYOR mu, yoksa sadece hesaplanip birakiliyor mu?
//
// Uygulama kaynak kodunu okuyup denetliyoruz. Bunun nedeni: `zonedSchedule`
// cagrisi platform eklentisidir ve flutter test'inde calismaz; ama bugun
// yakaladigimiz hata tam da buradaydi — hesap dogruydu, planlama HIC YOKTU.
// Kaynak denetimi, bu tur hatalarin geri donmesini engelliyor.
//
// Denetim kriterleri:
//   1) `_gunlukBildirimleriZamanla` icinde erken uyari planlanmali.
//   2) Saniyelik sayacta `fark.inSeconds == ...` ESKI KALINTISI olmamali
//      (o kosul uygulama kapaliyken hic tetiklenmez ve tek saniye kacirilirsa
//      bildirim kalici olarak kaybolur).
//   3) Erken uyari icin AYRI bir kanal kullanilmali.
//   4) Ayar degisince alarmlar yeniden kurulmali (dinleyici).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String kaynak;

  setUpAll(() {
    kaynak = File('lib/pages/anasayfa.dart').readAsStringSync(encoding: utf8);
  });

  group('Erken uyari sisteme planlaniyor', () {
    test('zamanlama fonksiyonu icinde erken uyari planlama var', () {
      // `_gunlukBildirimleriZamanla` govdesi, ilk satirindan sonraki
      // _erkenUyariAlarmiKur tanimina kadar.
      final int baslangic = kaynak.indexOf('Future<void> _gunlukBildirimleriZamanla');
      expect(baslangic, greaterThan(-1), reason: 'Zamanlama fonksiyonu bulunamadı');

      final int bitis = kaynak.indexOf('Future<void> _erkenUyariAlarmiKur');
      expect(bitis, greaterThan(baslangic));

      final String govde = kaynak.substring(baslangic, bitis);

      // Erken uyari zamaninin hesaplandigi ve alarmin kuruldugu yer.
      expect(govde.contains('erkenUyariZamani('), isTrue,
          reason: 'Erken uyari zamani hesaplanmiyor');
      expect(govde.contains('_erkenUyariAlarmiKur('), isTrue,
          reason: 'Erken uyari alarmi kurulmiyor');
    });

    test('erken uyari ve vakit alarmi farkli kimlik bandinda', () {
      // Cakisma olursa biri digerini ezer.
      final int baslangic = kaynak.indexOf('Future<void> _gunlukBildirimleriZamanla');
      final int bitis = kaynak.indexOf('Future<void> _erkenUyariAlarmiKur');
      final String govde = kaynak.substring(baslangic, bitis);

      expect(govde.contains('vakitIdBasi'), isTrue);
      expect(govde.contains('erkenUyariIdBasi'), isTrue);
      expect(govde.contains('vakitIdBasi + sira'), isTrue);
      expect(govde.contains('erkenUyariIdBasi + sira'), isTrue);
    });

    test('erken uyari icin ayri kanal kullaniliyor', () {
      // Vakit: ezan_kanali_arka_plan
      // Erken uyari: erken_uyari_kanali
      final int baslangic = kaynak.indexOf('Future<void> _erkenUyariAlarmiKur');
      final int tekilAlarmYeri = kaynak.indexOf('Future<void> _tekilAlarmKur');
      final int bitis =
          (tekilAlarmYeri > baslangic) ? tekilAlarmYeri : kaynak.length;
      final String govde = kaynak.substring(baslangic, bitis);

      expect(govde.contains("'erken_uyari_kanali'"), isTrue,
          reason: 'Erken uyarı kendi kanalını kullanmalı');
      expect(govde.contains('notif_channel_early_name'), isTrue,
          reason: 'Erken uyarı kanalı adı çevrilmeli');
    });
  });

  group('Kırılgan saniyelik tetik kaldırıldı', () {
    test('`fark.inSeconds == erkenUyariSaniyesi` kalıntısı yok', () {
      // Bu kosul iki kusur birden getiriyordu: uygulama kapaliyken hic
      // calismiyor, uygulama acikken o tek saniye kacirilirsa kalici olarak
      // kayboluyordu. Artik alarm sisteme planlaniyor.
      expect(kaynak.contains('erkenUyariSaniyesi'), isFalse,
          reason: 'Eski kırılgan tetik hâlâ kodda');
    });

    test('`formatliFark == "00:00:00"` ile anlık bildirim yok', () {
      // Vakit bildirimi de artık planlanıyor; bu kosul çift bildirim üretirdi.
      expect(kaynak.contains('formatliFark == "00:00:00"'), isFalse,
          reason: 'Eski anlık bildirim tetiği hâlâ kodda');
    });

    test('sayaç artık yalnızca ekranı güncelliyor', () {
      // Sayaç hâlâ var (geri sayım için) ama bildirim göndermiyor.
      final int baslangic = kaynak.indexOf('void kalanSureyiHesapla()');
      expect(baslangic, greaterThan(-1));

      final int bitis = kaynak.indexOf('Widget _gununAyetiKarti');
      final String govde = kaynak.substring(baslangic, bitis < 0 ? kaynak.length : bitis);

      expect(govde.contains('setState'), isTrue,
          reason: 'Sayaç ekranı güncellemeye devam etmeli');
      expect(govde.contains('zonedSchedule'), isFalse,
          reason: 'Sayac alarm kurmamali');
    });
  });

  group('Ayar değişince alarmlar yeniden kuruluyor', () {
    test('erkenUyariSuresi dinleyicisi kayitli', () {
      expect(kaynak.contains('erkenUyariSuresi.addListener('), isTrue,
          reason: 'Ayar değişimine tepki verilmiyor');
      expect(kaynak.contains('erkenUyariSuresi.removeListener('), isTrue,
          reason: 'Dinleyici kaldırılmıyor (bellek sızıntısı)');
    });

    test('dinleyici alarmlari yeniden kuruyor', () {
      // Aksi halde 15 dakika sectiginde alarmlar eski ayarla (30/45) kalir.
      final int i = kaynak.indexOf('Future<void> _erkenUyariDegisti()');
      expect(i, greaterThan(-1));
      final String govde =
          kaynak.substring(i, i + 400);
      expect(govde.contains('_gunlukBildirimleriZamanla()'), isTrue,
          reason: 'Ayar değişince alarmlar yeniden planlanmıyor');
    });
  });
}
