import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

Widget host(
  Widget child, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  bool reduceMotion = true,
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('vi'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(brightness: brightness),
  builder: (context, w) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: w!,
  ),
  home: Scaffold(body: Center(child: child)),
);

const longName = 'Nguyễn Thị Phương Thảo Trang Linh Hoa Mai Lan Cúc Trúc Đào';

void main() {
  testWidgets('none ⇒ không vẽ gì', (tester) async {
    await tester.pumpWidget(host(const TsuBadge(kind: TsuBadgeKind.none)));
    expect(find.text('PRO'), findsNothing);
    expect(find.text('Ủng hộ'), findsNothing);
  });

  testWidgets('nhãn đọc màn hình vi/en, cả hai ⇒ Pro trước', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const TsuBadge(kind: TsuBadgeKind.both)));
    expect(find.bySemanticsLabel('Tài khoản Pro'), findsOneWidget);
    expect(find.bySemanticsLabel('Đã ủng hộ TsuDEV'), findsOneWidget);
    expect(
      tester.getCenter(find.bySemanticsLabel('Tài khoản Pro')).dx,
      lessThan(tester.getCenter(find.bySemanticsLabel('Đã ủng hộ TsuDEV')).dx),
    );

    await tester.pumpWidget(
      host(const TsuBadge(kind: TsuBadgeKind.both), locale: const Locale('en')),
    );
    expect(find.bySemanticsLabel('Pro account'), findsOneWidget);
    expect(find.bySemanticsLabel('Supported TsuDEV'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('cao = 0,75 × dòng tên, kẹp 16-20 px', (tester) async {
    for (final (style, scale, want) in <(TextStyle, double, double)>[
      (const TextStyle(fontSize: 14, height: 1.43), 1.0, 16.0), // 15 ⇒ 16
      (const TextStyle(fontSize: 16, height: 1.5), 1.0, 18.0),
      (const TextStyle(fontSize: 22, height: 1.27), 1.0, 20.0), // 21 ⇒ 20
      (const TextStyle(fontSize: 14, height: 1.43), 2.0, 20.0),
    ]) {
      await tester.pumpWidget(
        host(
          TsuBadge(kind: TsuBadgeKind.pro, nameStyle: style),
          textScale: scale,
        ),
      );
      final size = tester.getSize(
        find.descendant(
          of: find.byType(TsuBadge),
          matching: find.byType(SizedBox).first,
        ),
      );
      expect(size.height, want, reason: '$style ×$scale');
    }
  });

  group('tên + huy hiệu', () {
    for (final (label, width) in <(String, double)>[
      ('khổ hẹp', 240.0),
      ('khổ rộng', 1200.0),
    ]) {
      testWidgets('$label: tên cắt trước, huy hiệu giữ nguyên, không tràn', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          host(
            const TsuNameWithBadge(
              name: longName,
              badge: TsuBadgeKind.both,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final para = tester.renderObject<RenderParagraph>(find.text(longName));
        expect(para.didExceedMaxLines, width < 600);
        final pro = tester.getRect(find.text('PRO'));
        final donor = tester.getRect(find.text('Ủng hộ'));
        expect(pro.right, lessThanOrEqualTo(width));
        expect(donor.right, lessThanOrEqualTo(width));
        // Một dòng: tên và huy hiệu cùng tâm dọc.
        expect(
          (tester.getCenter(find.text(longName)).dy - pro.center.dy).abs(),
          lessThan(2),
        );
        final gap =
            tester.getTopLeft(find.byType(TsuBadge)).dx -
            tester.getTopRight(find.text(longName)).dx;
        expect(gap, inInclusiveRange(4, 6));
      });
    }
  });

  testWidgets('giảm chuyển động ⇒ không có hoạt ảnh nào chạy', (tester) async {
    await tester.pumpWidget(host(const TsuBadge(kind: TsuBadgeKind.both)));
    // pumpAndSettle sẽ hết giờ nếu shimmer còn lặp.
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(find.text('Ủng hộ'));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0, reason: 'tim không đập');
  });

  testWidgets('bình thường ⇒ shimmer lặp, tim đập khi chạm rồi dừng', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TsuBadge(kind: TsuBadgeKind.both), reduceMotion: false),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1, reason: 'shimmer chạy');
    await tester.tap(find.text('Ủng hộ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final scale = tester.widget<ScaleTransition>(
      find.descendant(
        of: find.byType(TsuBadge),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scale.scale.value, greaterThan(1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(scale.scale.value, 1);
    // Tháo cây để dừng shimmer lặp.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chạm vào huy hiệu không chặn nút cha', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        InkWell(
          onTap: () => taps++,
          child: const TsuNameWithBadge(name: 'An', badge: TsuBadgeKind.donor),
        ),
      ),
    );
    await tester.tap(find.text('Ủng hộ'));
    expect(taps, 1);
  });

  test('màu đúng bảng assets/badges/README.md', () {
    expect(TsuBadgeColors.proStart, const Color(0xFF30C8F0));
    expect(TsuBadgeColors.proEnd, const Color(0xFF1E90FF));
    expect(TsuBadgeColors.proInk, const Color(0xFF0A0A0A));
    expect(TsuBadgeColors.donorLightFill, const Color(0xFFCCFBF1));
    expect(TsuBadgeColors.donorLightBorder, const Color(0xFF0F766E));
    expect(TsuBadgeColors.donorLightInk, const Color(0xFF134E4A));
    expect(TsuBadgeColors.donorDarkFill, const Color(0xFF042F2E));
    expect(TsuBadgeColors.donorDarkBorder, const Color(0xFF2DD4BF));
    expect(TsuBadgeColors.donorDarkInk, const Color(0xFF99F6E4));
  });
}
