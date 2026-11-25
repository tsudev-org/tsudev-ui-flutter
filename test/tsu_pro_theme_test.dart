import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import '../scripts/gen_pro_themes.dart' as gen;

Color _hex(String v) {
  if (v.startsWith('#')) {
    return Color(int.parse('FF${v.substring(1)}', radix: 16));
  }
  final m = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)')
      .firstMatch(v)!;
  return Color.fromARGB(
    (double.parse(m.group(4)!) * 255).round(),
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

Widget _app(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
  theme: ThemeData(brightness: b),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  final src = File('.standards/tokens/pro-themes.json');
  final data = jsonDecode(src.readAsStringSync()) as Map<String, dynamic>;
  final themes = (data['themes'] as List).cast<Map<String, dynamic>>();

  group('Khớp bộ quy ước (.standards/tokens/pro-themes.json)', () {
    test('tệp sinh đúng bản sinh hiện tại', () {
      expect(
        File('lib/src/pro_theme/tsu_pro_themes.g.dart').readAsStringSync(),
        gen.generate(src.readAsStringSync()),
        reason: 'chạy: dart run scripts/gen_pro_themes.dart',
      );
    });

    test('đủ chủ đề, đúng thứ tự, đúng mọi màu', () {
      expect(TsuProTheme.all.map((t) => t.id), themes.map((t) => t['id']));
      expect(tsuProThemesVersion, (data['meta'] as Map)['version']);
      for (final j in themes) {
        final t = TsuProTheme.byId(j['id'] as String)!;
        for (final (mode, p) in [('light', t.light), ('dark', t.dark)]) {
          final c = (j['colors'] as Map)[mode] as Map<String, dynamic>;
          expect(
            p.primary,
            _hex(c['primary'] as String),
            reason: '${t.id} $mode',
          );
          expect(p.bgSurface, _hex(c['bg-surface'] as String));
          expect(p.glow, _hex(c['glow'] as String));
          expect(p.ringEnd, _hex(c['pro-ring-end'] as String));
        }
      }
    });
  });

  group('WCAG (đo lại phía Flutter)', () {
    for (final t in TsuProTheme.all) {
      for (final b in Brightness.values) {
        test('${t.id} ${b.name}', () {
          final p = t.of(b);
          expect(
            tsuContrast(p.onPrimary, p.primary),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            tsuContrast(p.onPrimary, p.primaryActive),
            greaterThanOrEqualTo(4.5),
          );
          for (final bg in [p.bgBase, p.bgSurface, p.bgSubtle]) {
            expect(tsuContrast(p.ringStart, bg), greaterThanOrEqualTo(3));
            expect(tsuContrast(p.ringEnd, bg), greaterThanOrEqualTo(3));
            expect(tsuContrast(p.focusRing, bg), greaterThanOrEqualTo(3));
          }
          for (final bg in [p.bgBase, p.bgSurface, p.bgSubtle, p.bgHover]) {
            expect(tsuContrast(p.textLink, bg), greaterThanOrEqualTo(4.5));
            expect(tsuContrast(p.accent, bg), greaterThanOrEqualTo(4.5));
          }
        });
      }
    }
  });

  group('tsuResolveProTheme', () {
    test('cần Pro, tương phản cao thắng, id lạ về mặc định', () {
      expect(
        tsuResolveProTheme(
          selectedId: 'cham-dem',
          hasPro: false,
          highContrast: false,
        ),
        isNull,
      );
      expect(
        tsuResolveProTheme(
          selectedId: 'cham-dem',
          hasPro: true,
          highContrast: true,
        ),
        isNull,
      );
      expect(
        tsuResolveProTheme(
          selectedId: 'khong-co',
          hasPro: true,
          highContrast: false,
        ),
        isNull,
      );
      expect(
        tsuResolveProTheme(selectedId: null, hasPro: true, highContrast: false),
        isNull,
      );
      expect(
        tsuResolveProTheme(
          selectedId: 'cham-dem',
          hasPro: true,
          highContrast: false,
        )?.id,
        'cham-dem',
      );
    });
  });

  test('tsuApplyProTheme giữ màu chữ và error, khai đủ container', () {
    final base = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );
    final t = TsuProTheme.byId('rung-thong')!;
    final s = tsuApplyProTheme(base, t);
    expect(s.primary, t.dark.primary);
    expect(s.surface, t.dark.bgSurface);
    expect(s.onSurface, base.onSurface);
    expect(s.error, base.error);
    expect(s.onPrimaryContainer, base.onSurface);
    expect(tsuContrast(s.onSurface, s.surface), greaterThanOrEqualTo(10));
  });

  group('TsuProThemePicker', () {
    testWidgets(
      'chưa Pro: thấy đủ mẫu, chỉ Mặc định chọn được, có liên kết tìm hiểu',
      (tester) async {
        String? picked = 'x';
        var learn = 0;
        await tester.pumpWidget(
          _app(
            TsuProThemePicker(
              selectedId: 'cham-dem',
              hasPro: false,
              onChanged: (v) => picked = v,
              onLearnMore: () => learn++,
              locale: const Locale('vi'),
            ),
          ),
        );
        for (final t in TsuProTheme.all) {
          expect(find.text(t.nameVi), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('tsu-pro-theme-cham-dem')));
        expect(
          picked,
          'x',
          reason: 'không có Pro thì không chọn được chủ đề Pro',
        );
        await tester.tap(find.text('Tìm hiểu TsuDEV Pro'));
        expect(learn, 1);
        await tester.tap(find.text('Mặc định'));
        expect(picked, isNull);
      },
    );

    testWidgets('có Pro: chọn được, đánh dấu đúng mục', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _app(
          TsuProThemePicker(
            selectedId: 'hoa-dao',
            hasPro: true,
            onChanged: (v) => picked = v,
          ),
        ),
      );
      expect(find.text('Tìm hiểu TsuDEV Pro'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tsu-pro-theme-ho-phach')));
      expect(picked, 'ho-phach');
      final sem = tester.getSemantics(
        find.byKey(const ValueKey('tsu-pro-theme-hoa-dao')),
      );
      expect(
        sem,
        isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
      );
    });

    testWidgets('tiếng Anh + ghi chú tương phản cao', (tester) async {
      await tester.pumpWidget(
        _app(
          TsuProThemePicker(
            selectedId: null,
            hasPro: true,
            highContrast: true,
            onChanged: (_) {},
            locale: const Locale('en'),
          ),
        ),
      );
      expect(find.text('Midnight Indigo'), findsOneWidget);
      expect(
        find.text('High contrast is on - colour themes are paused.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'TsuProAvatarFrame: null ⇒ giữ nguyên ảnh; có chủ đề ⇒ thêm vòng',
    (tester) async {
      const avatar = CircleAvatar(radius: 20, child: Text('A'));
      final ring = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is SweepGradient,
      );
      await tester.pumpWidget(
        _app(const TsuProAvatarFrame(theme: null, child: avatar)),
      );
      expect(ring, findsNothing);
      await tester.pumpWidget(
        _app(
          TsuProAvatarFrame(theme: TsuProTheme.byId('cham-dem'), child: avatar),
          b: Brightness.dark,
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(ring, findsOneWidget);
    },
  );
}
