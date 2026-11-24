import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

/// Phiếu 20261124-UI1: đo tương phản TẠI biểu tượng thật đang vẽ (IconTheme tại phần tử Icon), nền = viên chỉ báo trộn
/// với nền thanh - bắt đúng lỗi "biểu tượng trắng trên viên nhạt" mà golden test dễ bỏ sót.
void main() {
  const surfaceLight = Color(0xFFFFFFFF);
  const surfaceDark = Color(0xFF141414);
  const accentLight = Color(0xFF0868C4);
  const accentDark = Color(0xFF38BDF8);

  TsuNavColors colors({required bool dark}) {
    final bg = dark ? surfaceDark : surfaceLight;
    final accent = dark ? accentDark : accentLight;
    return TsuNavColors(
      background: bg,
      indicator: accent.withValues(alpha: 0.14),
      selected: accent,
      unselected: dark ? const Color(0xFFA1A1A1) : const Color(0xFF5C5C5C),
      selectedLabel: dark ? const Color(0xFFEDEDED) : const Color(0xFF171717),
      unselectedLabel: dark ? const Color(0xFFB4B4B4) : const Color(0xFF52525B),
    );
  }

  ThemeData theme({required bool dark}) {
    final c = colors(dark: dark);
    final base = ColorScheme.fromSeed(
      seedColor: dark ? accentDark : accentLight,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return ThemeData(
      colorScheme: tsuCompleteContainers(
        base,
        accent: dark ? accentDark : accentLight,
        surface: c.background,
        onSurface: c.selectedLabel,
      ),
      navigationBarTheme: tsuNavigationBarTheme(c),
      navigationRailTheme: tsuNavigationRailTheme(c),
    );
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'Tối' : 'Sáng';

    testWidgets('NavigationBar - biểu tượng đang chọn và chưa chọn ≥ 3:1 ($mode)', (tester) async {
      final c = colors(dark: dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme(dark: dark),
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, key: Key('chon')),
                  label: 'Tổng quan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history, key: Key('chua')),
                  label: 'Lịch sử',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pill = Color.alphaBlend(c.indicator, c.background);
      final on = IconTheme.of(tester.element(find.byKey(const Key('chon')))).color!;
      final off = IconTheme.of(tester.element(find.byKey(const Key('chua')))).color!;
      expect(tsuContrast(on, pill), greaterThanOrEqualTo(3));
      expect(tsuContrast(off, c.background), greaterThanOrEqualTo(3));
    });

    testWidgets('NavigationRail - biểu tượng đang chọn ≥ 3:1 ($mode)', (tester) async {
      final c = colors(dark: dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme(dark: dark),
          home: Scaffold(
            body: NavigationRail(
              selectedIndex: 0,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined, key: Key('chon')),
                  label: Text('A'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history, key: Key('chua')),
                  label: Text('B'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pill = Color.alphaBlend(c.indicator, c.background);
      final on = IconTheme.of(tester.element(find.byKey(const Key('chon')))).color!;
      expect(tsuContrast(on, pill), greaterThanOrEqualTo(3));
    });

    test('ColorScheme có đủ cặp *Container, chữ trên nền ≥ 4,5:1 ($mode)', () {
      final cs = theme(dark: dark).colorScheme;
      for (final pair in [
        (cs.primaryContainer, cs.onPrimaryContainer),
        (cs.secondaryContainer, cs.onSecondaryContainer),
        (cs.tertiaryContainer, cs.onTertiaryContainer),
      ]) {
        expect(tsuContrast(pair.$2, pair.$1), greaterThanOrEqualTo(4.5));
      }
    });
  }

  test('TsuNavColors từ chối đúng cấu hình lỗi gốc: biểu tượng trắng trên viên nhạt', () {
    expect(
      () => TsuNavColors(
        background: const Color(0xFFFFFFFF),
        indicator: const Color(0xFFF2F2F2),
        selected: const Color(0xFFFFFFFF),
        unselected: const Color(0xFF5C5C5C),
        selectedLabel: const Color(0xFF171717),
        unselectedLabel: const Color(0xFF52525B),
      ),
      throwsArgumentError,
    );
  });

  test('tsuContrast khớp giá trị chuẩn WCAG', () {
    expect(tsuContrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(tsuContrast(Colors.white, Colors.white), closeTo(1, 0.001));
  });
}
