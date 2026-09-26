// Testler arasında paylasilan yardimcilar.
//
// Bu dosya bir TEST dosyasi degildir (sonu `_test.dart` ile bitmiyor), bu
// yuzden `flutter test` tarafindan calistirilmaz; yalnizca import edilir.
import 'dart:io';

/// Butun ag isteklerini basarisiz yapan istemci: "internet yok" senaryosu.
///
/// package:http'in IOClient'i `HttpClient()` fabrikasini kullandigi icin
/// HttpOverrides ile devreye giriyor. `HttpClient` fabrika constructor'li
/// oldugu icin `extends` edilemez; bu yuzden `implements` + `noSuchMethod`
/// ile tum cagirilar hata firlatir.
class InternetYokHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('test: internet baglantisi yok');
}

/// [body] calisirken butun ag isteklerini basarisiz yapan yardimci.
///
/// easy_localization cevirileri de bu bolgede yuklenir; onlar da basarisiz
/// olur ama EasyLocalization hatayi yutup anahtarlari gostermeye devam eder,
/// bu da bu testlerde sorun degildir.
Future<T> internetYokken<T>(Future<T> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (_) => InternetYokHttpClient(),
  );
}
