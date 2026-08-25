import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/shared/common_widgets.dart';

/// Marka sembolü testi.
///
/// `flutter analyze` bir SVG'nin ayrıştırılamadığını ya da boş çizildiğini
/// yakalayamaz — hata ancak çalışma anında ortaya çıkar. Bu test sembolü
/// gerçekten yükleyip çizerek o boşluğu kapatır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BrandMark sembolü hatasız çizilir', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandMark(size: 64))),
      ),
    );

    // SvgPicture varlığı asenkron yükler; çizim tamamlanana kadar bekle.
    await tester.pumpAndSettle();

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BrandLogo tam logoyu hatasız çizer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandLogo(size: 120))),
      ),
    );
    await tester.pumpAndSettle();

    // Logo tek parça bir görsel: "Regipass" yazısı da onun içinde, canlı
    // metin olarak değil. Metin aranırsa test, doğru çizen bir widget'ı
    // hatalı gösterir.
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(BrandMark), findsNothing);
    expect(find.text('egipass'), findsNothing);
    expect(find.text('Regipass'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('sembol varlığı yüklenebiliyor ve beklenen yapıda', () async {
    // Varlık pubspec'te bildirilmemişse ya da yol yanlışsa burada patlar.
    final String svg = await rootBundle.loadString(
      'assets/brand/regipass_mark.svg',
    );

    expect(svg, contains('<svg'));
    expect(svg, contains('<path'));
    // viewBox olmadan flutter_svg boyutlandıramaz ve sembol görünmez olur.
    expect(svg, contains('viewBox='));
    // Renk dışarıdan verilebilsin diye currentColor kullanılmalı.
    expect(svg, contains('currentColor'));
  });

  test('tam logo varlığı yüklenebiliyor ve zemini yok', () async {
    final String svg = await rootBundle.loadString(
      'assets/brand/regipass_logo.svg',
    );

    expect(svg, contains('viewBox='));
    // Logo saydam: kaynak görseldeki siyah kare zemin alınmadı, aksi hâlde
    // açık temadaki ekranlarda kare bir yama olarak duruyordu.
    expect(svg, isNot(contains('fill="#000000"')));
    expect(svg, isNot(contains('<rect')));
    // viewBox içeriğe daraltıldı: logonun etrafında boş saydam alan kalmasın.
    expect(svg, isNot(contains('viewBox="0 0 1500 1500"')));
    // Kelime markası radyal gradyanla dolduruluyor.
    expect(svg, contains('<radialGradient'));
    // flutter_svg bunları çizemiyor; düzleştirme sırasında elenmiş olmalı.
    expect(svg, isNot(contains('feColorMatrix')));
    expect(svg, isNot(contains('<mask')));
  });
}
