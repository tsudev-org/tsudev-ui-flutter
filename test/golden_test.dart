@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

/// Golden Sáng/Tối. Sinh lại: `flutter test --update-goldens test/golden_test.dart`
/// (chỉ trên Linux, đúng Flutter ghim trong CI) rồi soát ảnh bằng mắt trước khi commit.
void main() {
  Widget sheet(Brightness b) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: b, fontFamily: 'Roboto'),
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              for (final locale in const [Locale('vi'), Locale('en')])
                for (final k in TsuBadgeKind.values)
                  TsuNameWithBadge(
                    name: 'Trần Văn An (${k.name}, ${locale.languageCode})',
                    badge: k,
                    locale: locale,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
              const SizedBox(
                width: 220,
                child: TsuNameWithBadge(
                  name: 'Nguyễn Thị Phương Thảo Trang',
                  badge: TsuBadgeKind.both,
                  style: TextStyle(fontSize: 14, height: 1.43),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget dialog(Brightness b, Locale l) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: b, fontFamily: 'Roboto'),
    home: Scaffold(body: ProNoticeDialog(devices: 2, locale: l)),
  );

  for (final b in Brightness.values) {
    final name = b == Brightness.light ? 'sang' : 'toi';

    testWidgets('huy hiệu - $name', (tester) async {
      tester.view.physicalSize = const Size(420, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sheet(b));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/tsu_badge_$name.png'),
      );
    });

    for (final (label, size) in [
      ('hep', const Size(360, 640)),
      ('rong', const Size(1024, 640)),
    ]) {
      testWidgets('ProNotice - $name - $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(dialog(b, const Locale('vi')));
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/pro_notice_${name}_$label.png'),
        );
      });
    }
  }
}
