// lib/utils/kible_hesapla.dart
import 'dart:math' as math;

class KibleHesaplayici {
  // Kabe'nin sabit koordinatları
  static const double kabeEnlem = 21.422487;
  static const double kabeBoylam = 39.826206;

  // Verilen enlem ve boylama göre Kıble açısını (derece cinsinden) döndürür
  static double hesapla(double enlem, double boylam) {
    double enlemR = enlem * (math.pi / 180.0);
    double boylamR = boylam * (math.pi / 180.0);
    double kabeEnlemR = kabeEnlem * (math.pi / 180.0);
    double kabeBoylamR = kabeBoylam * (math.pi / 180.0);

    double y = math.sin(kabeBoylamR - boylamR) * math.cos(kabeEnlemR);
    double x = math.cos(enlemR) * math.sin(kabeEnlemR) -
        math.sin(enlemR) * math.cos(kabeEnlemR) * math.cos(kabeBoylamR - boylamR);

    double kibleRadyan = math.atan2(y, x);
    double kibleDerece = kibleRadyan * (180.0 / math.pi);

    return (kibleDerece + 360.0) % 360.0;
  }
}