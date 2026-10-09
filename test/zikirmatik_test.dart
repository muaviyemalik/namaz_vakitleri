import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/main.dart';
import 'package:namaz_vakitleri/pages/anasayfa.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bildirim implements FlutterLocalNotificationsPlugin {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final List<String?> metinler = [];
  bool reddet = false;
  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    if (reddet) throw StateError('izin yok');
    expect(id, lessThan(0)); // Namaz alarmlarının pozitif kimliklerinden ayrı.
    metinler.add(body);
  }
}

class _Ceviri extends AssetLoader {
  const _Ceviri();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Bildirim bildirim;
  late List<Object?> titresimler;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Localization.load(
      const Locale('tur'),
      translations: Translations(
        jsonDecode(File('assets/i18n/ceviri/tur.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  setUp(() {
    aktifKonum.value = null;
    SharedPreferences.setMockInitialValues({
      'kayitli_zikir': 32,
      'kayitli_hedef': 33,
    });
    bildirim = _Bildirim();
    titresimler = [];
    bildirimServisiDegistir(bildirim);
    bildirimYoluTasarimiAyarla(true);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate')
        titresimler.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('perfect_volume_control'),
      (_) async => null,
    );
  });
  tearDown(() {
    bildirimYoluTasarimiAyarla(null);
    bildirimServisiDegistir(FlutterLocalNotificationsPlugin());
  });
  Future<void> ac(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/i18n/ceviri',
        supportedLocales: const [Locale('tur')],
        startLocale: const Locale('tur'),
        assetLoader: const _Ceviri(),
        child: const MaterialApp(home: AnaSayfa()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('gerçek çeviriyle altı hedef sayısı görünür ve seçim kaydolur', (
    tester,
  ) async {
    await ac(tester);
    await tester.tap(find.byKey(const Key('zikir_hedef_sec')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (final sayi in [33, 66, 99, 100, 500, 1000]) {
      expect(find.text('Hedef: $sayi'), findsWidgets);
    }
    await tester.tap(find.text('Hedef: 66'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Hedef: 66'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getInt('kayitli_hedef'), 66);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'hedef geçişi bir kez titreşir ve bildirir, sıfırlama yeniden hazırlar',
    (tester) async {
      await ac(tester);
      await tester.tap(find.byKey(const Key('zikir_artir')));
      await tester.pump();
      expect(bildirim.metinler, ['33 zikir hedefine ulaştın.']);
      expect(titresimler.where((e) => e == null).length, 1);
      expect(find.text('Hedef tamamlandı'), findsOneWidget);
      await tester.tap(find.byKey(const Key('zikir_artir')));
      await tester.pump();
      expect(bildirim.metinler.length, 1);
      expect(
        (await SharedPreferences.getInstance()).getInt('kayitli_zikir'),
        34,
      );
      await tester.tap(find.text('Sıfırla'));
      await tester.pump();
      for (var i = 0; i < 33; i++) {
        await tester.tap(find.byKey(const Key('zikir_artir')));
        await tester.pump();
      }
      expect(bildirim.metinler.length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('bildirim reddedilse de sayaç ve hedef tamamlanır', (
    tester,
  ) async {
    bildirim.reddet = true;
    await ac(tester);
    await tester.tap(find.byKey(const Key('zikir_artir')));
    await tester.pump();
    expect(find.text('Hedef tamamlandı'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getInt('kayitli_zikir'), 33);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ses tuşu açık paneli günceller, kapalı panelde saymaz', (
    tester,
  ) async {
    Future<void> ses() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'perfect_volume_control',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('volumeChangeListener', 0.5),
            ),
            (_) {},
          );
      await tester.pump();
    }

    await ac(tester);
    await ses();
    expect(find.text('33'), findsOneWidget);
    expect(bildirim.metinler.length, 1);
    Navigator.of(tester.element(find.byKey(const Key('zikir_artir')))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await ses();
    expect((await SharedPreferences.getInstance()).getInt('kayitli_zikir'), 33);
    expect(bildirim.metinler.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
