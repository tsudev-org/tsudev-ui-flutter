import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Theme thanh điều hướng (NavigationBar, NavigationRail) và các cặp `*Container` của ColorScheme, an toàn tương phản
/// ở MỌI trạng thái - tsudev-standards `DESIGN_SYSTEM.md` mục 1 (v4.1.0), phiếu `20261124-UI1`.
///
/// Lỗi gốc (Sound Db, Quly Thu Chi, 24/11/2026): app ghi đè `indicatorColor` (nền viên chỉ báo, màu nhạt) nhưng để
/// Material 3 tự chọn màu biểu tượng đang chọn = `onSecondaryContainer`; ColorScheme không khai cặp `*Container` nên
/// giá trị đó rơi về `onSecondary` (trắng) ⇒ biểu tượng trắng trên nền nhạt, tương phản ~1,2:1.
///
/// Dùng:
/// ```dart
/// final nav = TsuNavColors(
///   background: p.bgSurface, indicator: p.primary.withValues(alpha: 0.14),
///   selected: p.primary, unselected: p.iconNav,
///   selectedLabel: p.textPrimary, unselectedLabel: p.textSecondary);
/// ThemeData(
///   colorScheme: tsuCompleteContainers(scheme, accent: p.primary, surface: p.bgSurface, onSurface: p.textPrimary),
///   navigationBarTheme: tsuNavigationBarTheme(nav),
///   navigationRailTheme: tsuNavigationRailTheme(nav),
/// );
/// ```
/// [TsuNavColors] ném [ArgumentError] khi một cặp biểu tượng/nền dưới 3:1 (WCAG 1.4.11) - lỗi lộ ra ngay ở lần dựng
/// theme đầu tiên, trong test, thay vì trên máy người dùng.
@immutable
class TsuNavColors {
  TsuNavColors({
    required this.background,
    required this.indicator,
    required this.selected,
    required this.unselected,
    required this.selectedLabel,
    required this.unselectedLabel,
  }) {
    final pill = Color.alphaBlend(indicator, background);
    _require('biểu tượng đang chọn / viên chỉ báo', selected, pill);
    _require('biểu tượng chưa chọn / nền thanh', unselected, background);
  }

  /// Nền thanh điều hướng.
  final Color background;

  /// Nền viên chỉ báo của mục đang chọn (có thể bán trong suốt - đo sau khi trộn với [background]).
  final Color indicator;

  /// Biểu tượng mục đang chọn.
  final Color selected;

  /// Biểu tượng mục chưa chọn.
  final Color unselected;

  /// Nhãn mục đang chọn / chưa chọn.
  final Color selectedLabel;
  final Color unselectedLabel;

  static void _require(String what, Color fg, Color bg) {
    final ratio = tsuContrast(fg, bg);
    if (ratio < 3) {
      throw ArgumentError('TsuNavColors: $what chỉ ${ratio.toStringAsFixed(2)}:1, cần ≥ 3:1 (WCAG 1.4.11).');
    }
  }
}

/// Tỉ lệ tương phản WCAG 2.x giữa hai màu đục.
double tsuContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

WidgetStateProperty<IconThemeData> _icons(TsuNavColors c) => WidgetStateProperty.resolveWith(
  (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.selected : c.unselected),
);

WidgetStateProperty<TextStyle> _labels(TsuNavColors c) => WidgetStateProperty.resolveWith(
  (s) => s.contains(WidgetState.selected)
      ? TextStyle(color: c.selectedLabel, fontWeight: FontWeight.w600)
      : TextStyle(color: c.unselectedLabel, fontWeight: FontWeight.w500),
);

/// NavigationBar: ghi đè CẢ nền viên chỉ báo, biểu tượng và nhãn theo `WidgetState` - không để M3 tự suy.
NavigationBarThemeData tsuNavigationBarTheme(TsuNavColors c) => NavigationBarThemeData(
  backgroundColor: c.background,
  indicatorColor: c.indicator,
  surfaceTintColor: Colors.transparent,
  iconTheme: _icons(c),
  labelTextStyle: _labels(c),
);

/// NavigationRail: cùng bộ màu với [tsuNavigationBarTheme].
NavigationRailThemeData tsuNavigationRailTheme(TsuNavColors c) => NavigationRailThemeData(
  backgroundColor: c.background,
  indicatorColor: c.indicator,
  selectedIconTheme: IconThemeData(color: c.selected),
  unselectedIconTheme: IconThemeData(color: c.unselected),
  selectedLabelTextStyle: TextStyle(color: c.selectedLabel, fontWeight: FontWeight.w600),
  unselectedLabelTextStyle: TextStyle(color: c.unselectedLabel, fontWeight: FontWeight.w500),
);

/// Khai đủ ba cặp `primary/secondary/tertiaryContainer` từ màu nhấn của sản phẩm: nền = [accent] phủ 14% trên
/// [surface], chữ/biểu tượng = [onSurface]. Thành phần M3 khác (Chip, FilledTonalButton, Badge, SegmentedButton,
/// NavigationDrawer) đọc các cặp này - bỏ trống là rơi về `on*` (thường là trắng) như lỗi gốc.
ColorScheme tsuCompleteContainers(
  ColorScheme scheme, {
  required Color accent,
  required Color surface,
  required Color onSurface,
}) {
  final container = Color.alphaBlend(accent.withValues(alpha: 0.14), surface);
  return scheme.copyWith(
    primaryContainer: container,
    onPrimaryContainer: onSurface,
    secondaryContainer: container,
    onSecondaryContainer: onSurface,
    tertiaryContainer: container,
    onTertiaryContainer: onSurface,
  );
}
