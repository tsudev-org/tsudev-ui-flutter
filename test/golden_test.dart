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

  // Giữa trưa UTC ⇒ ngày theo giờ máy giống nhau ở mọi múi giờ ±11 giờ.
  final until = DateTime.utc(2026, 11, 26, 12);
  final renewals = {
    'nhac': ProRenewalDecision.reminder(proUntil: until, daysLeft: 7),
    'het_ky': ProRenewalDecision.expired(proUntil: until),
  };

  Widget renewal(Brightness b, ProRenewalDecision d) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: b, fontFamily: 'Roboto'),
    home: Scaffold(
      body: ProRenewalDialog(decision: d, locale: const Locale('vi')),
    ),
  );

  for (final b in Brightness.values) {
    final name = b == Brightness.light ? 'sang' : 'toi';

    for (final MapEntry(key: kind, value: d) in renewals.entries) {
      for (final (label, size) in [
        ('hep', const Size(360, 640)),
        ('rong', const Size(1024, 640)),
      ]) {
        testWidgets('ProRenewal $kind - $name - $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(renewal(b, d));
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/pro_renewal_${kind}_${name}_$label.png'),
          );
        });
      }
    }

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
  }
}
