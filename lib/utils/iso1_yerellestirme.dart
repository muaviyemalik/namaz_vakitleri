// Flutter'in global yerellestirme delegeleri (Material/Widgets/Cupertino)
// yalnizca ISO 639-1, yani 2 harfli kodlari tanir: GlobalMaterialLocalizations
// icin "tr" vardir, "tur" yoktur.
//
// Bu proje ceviri dosyalarini ISO 639-2/3 (3 harfli) koduyla adlandirir
// (tur.json, eng.json, ara.json) ve easy_localization da locale'i 3 harfli
// tutar; cunku easy_localization dosya adini Locale.languageCode'dan turetir.
//
// Sonuc olarak MaterialApp'e 3 harfli locale verilince su iki secenekten
// biri olur:
//   1) Global delegeler isSupported=false doner ve "No MaterialLocalizations
//      found" hatasi cikar.
//   2) MaterialApp'e 2 harfli locale verilir; easy_localization'in delegate'i
//      2 harfli kodu gorup tr.json diye var olmayan dosyayi arar ve tum
//      anahtarlar "not found" olur.
//
// Buradaki delegeler 3 harfli locale'i alir, ama Material/Widgets/Cupertino
// tarafina ISO-1 kodu ile gider. Boylece ceviri dosyalari 3 harfli kalmaya
// devam eder (projenin ve dil_katalogu.dart'taki belgelenen tasarimi) ve
// global yerellestirmeler de dogru calisir.
//
// Not: Flutter'in 116 Material yerellestirmesi var ama 152 dilli katalogda
// turkmen (tk) gibi bazi kodlar bunlarin disinda kalir. Boyle bir dil
// secildiginde arayuzun cokmemesi icin [desteklenenIso1] Ingilizce'ye duser.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/dil_katalogu.dart';

/// 3 harfli kodu ISO 639-1'e cevirir; katalog yuklenmemisse ya da eslesme
/// yoksa kodu oldugu gibi dondurur.
String iso1Koda(String kod) {
  if (!DilKatalogu.yuklendiMi) return kod;
  return DilKatalogu.ornek.kodaGore(kod)?.iso1 ?? kod;
}

/// [delege] tarafindan taninan ISO-1 kodu. Taninmiyorsa 'en' doner, boylece
/// MaterialLocalizations hic bulunamaz ve arayuz cokmez.
String desteklenenIso1(String kod, LocalizationsDelegate<Object?> delega) {
  final iso1 = iso1Koda(kod);
  if (delega.isSupported(Locale(iso1))) return iso1;
  return 'en';
}

class MaterialYerellestirmeDelegesi
    extends LocalizationsDelegate<MaterialLocalizations> {
  const MaterialYerellestirmeDelegesi();

  @override
  bool isSupported(Locale locale) => GlobalMaterialLocalizations.delegate
      .isSupported(Locale(desteklenenIso1(locale.languageCode,
          GlobalMaterialLocalizations.delegate)));

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(Locale(desteklenenIso1(
          locale.languageCode, GlobalMaterialLocalizations.delegate)));

  @override
  bool shouldReload(covariant MaterialYerellestirmeDelegesi old) => false;
}

class WidgetsYerellestirmeDelegesi
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const WidgetsYerellestirmeDelegesi();

  @override
  bool isSupported(Locale locale) => GlobalWidgetsLocalizations.delegate
      .isSupported(Locale(desteklenenIso1(locale.languageCode,
          GlobalWidgetsLocalizations.delegate)));

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(Locale(desteklenenIso1(
          locale.languageCode, GlobalWidgetsLocalizations.delegate)));

  @override
  bool shouldReload(covariant WidgetsYerellestirmeDelegesi old) => false;
}

class CupertinoYerellestirmeDelegesi
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const CupertinoYerellestirmeDelegesi();

  @override
  bool isSupported(Locale locale) => GlobalCupertinoLocalizations.delegate
      .isSupported(Locale(desteklenenIso1(locale.languageCode,
          GlobalCupertinoLocalizations.delegate)));

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(Locale(desteklenenIso1(
          locale.languageCode, GlobalCupertinoLocalizations.delegate)));

  @override
  bool shouldReload(covariant CupertinoYerellestirmeDelegesi old) => false;
}

/// MaterialApp'e verilecek delegeler listesi. Sarmalayicilar once gelir;
/// [delegates] icindeki Global delegeler 3 harfli kodda isSupported=false
/// dondugu icin zaten devreye girmez.
List<LocalizationsDelegate<dynamic>> yerellestirmeDelegeleri(
    List<LocalizationsDelegate<dynamic>> delegates) {
  return <LocalizationsDelegate<dynamic>>[
    const MaterialYerellestirmeDelegesi(),
    const WidgetsYerellestirmeDelegesi(),
    const CupertinoYerellestirmeDelegesi(),
    ...delegates,
  ];
}
