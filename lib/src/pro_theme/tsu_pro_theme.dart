import 'package:flutter/material.dart';

import '../theme/tsu_nav_theme.dart';

part 'tsu_pro_themes.g.dart';

/// Bảng màu một chế độ của một chủ đề Pro - 18 vai trò, tsudev-standards `DESIGN_SYSTEM.md` mục 1.3.
///
/// Chữ (`text-*`), trạng thái (`success`/`warning`/`danger`/`info`) và lớp phủ KHÔNG nằm ở đây: chúng giữ nguyên lớp
/// nền chung của app để ý nghĩa màu không đổi khi đổi chủ đề.
@immutable
class TsuProPalette {
  const TsuProPalette({
    required this.bgBase,
    required this.bgSurface,
    required this.bgSubtle,
    required this.bgHover,
    required this.border,
    required this.borderStrong,
    required this.textLink,
    required this.primary,
    required this.primaryHover,
    required this.primaryActive,
    required this.onPrimary,
    required this.focusRing,
    required this.accent,
    required this.glow,
    required this.iconInfo,
    required this.iconNav,
    required this.ringStart,
    required this.ringEnd,
  });

  final Color bgBase;
  final Color bgSurface;
  final Color bgSubtle;
  final Color bgHover;
  final Color border;
  final Color borderStrong;
  final Color textLink;
  final Color primary;
  final Color primaryHover;
  final Color primaryActive;
  final Color onPrimary;
  final Color focusRing;
  final Color accent;
  final Color glow;
  final Color iconInfo;
  final Color iconNav;

  /// Hai đầu chuyển sắc của khung ảnh đại diện Pro (≥ 3:1 trên mọi nền ổn định).
  final Color ringStart;
  final Color ringEnd;
}

/// Một chủ đề Pro (quyền lợi Q2, `PRODUCT_POLICY.md` 3.7.1). Danh sách đóng: [TsuProTheme.all], sinh từ
/// `.standards/tokens/pro-themes.json` - app KHÔNG tự tạo chủ đề.
@immutable
class TsuProTheme {
  const TsuProTheme._({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.light,
    required this.dark,
  });

  /// Mã ổn định để lưu lựa chọn của người dùng (vd `cham-dem`).
  final String id;
  final String nameVi;
  final String nameEn;
  final TsuProPalette light;
  final TsuProPalette dark;

  /// Mọi chủ đề Pro, đúng thứ tự trong bộ quy ước.
  static const List<TsuProTheme> all = _tsuProThemes;

  /// Tìm theo [id]; id lạ hoặc `null` ⇒ `null` (app quay về bảng mặc định - chủ đề có thể bị bỏ ở bản quy ước sau).
  static TsuProTheme? byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Tên hiển thị theo ngôn ngữ (vi mặc định).
  String name(Locale? locale) => locale?.languageCode == 'en' ? nameEn : nameVi;

  /// Bảng theo độ sáng của theme đang dựng.
  TsuProPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Chủ đề Pro thực sự được áp, hoặc `null` = dùng bảng mặc định của sản phẩm.
///
/// Trả `null` khi: không có Pro ([hasPro] lấy từ JWS quyền lợi), bật tương phản cao (của hệ điều hành -
/// `MediaQuery.highContrastOf` - hoặc của app; tương phản cao luôn thắng), hoặc [selectedId] không còn tồn tại.
/// Hết hạn Pro ⇒ về mặc định nhưng app VẪN giữ [selectedId] đã lưu để dùng lại khi gia hạn.
TsuProTheme? tsuResolveProTheme({
  required String? selectedId,
  required bool hasPro,
  required bool highContrast,
}) {
  if (!hasPro || highContrast) return null;
  return TsuProTheme.byId(selectedId);
}

/// Gộp chủ đề Pro lên [scheme] của app: nhấn, nền, viền, và đủ ba cặp `*Container` (qua
/// [tsuCompleteContainers]) để thành phần M3 không rơi về màu chữ sai. Màu chữ (`onSurface`), `error` giữ nguyên.
ColorScheme tsuApplyProTheme(ColorScheme scheme, TsuProTheme theme) {
  final p = theme.of(scheme.brightness);
  final next = scheme.copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.accent,
    onSecondary: p.onPrimary,
    tertiary: p.accent,
    onTertiary: p.onPrimary,
    surface: p.bgSurface,
    surfaceDim: p.bgBase,
    surfaceBright: p.bgSurface,
    surfaceContainerLowest: p.bgSurface,
    surfaceContainerLow: p.bgBase,
    surfaceContainer: p.bgSubtle,
    surfaceContainerHigh: p.bgHover,
    surfaceContainerHighest: p.bgHover,
    outline: p.borderStrong,
    outlineVariant: p.border,
    surfaceTint: Colors.transparent,
  );
  return tsuCompleteContainers(
    next,
    accent: p.primary,
    surface: p.bgSurface,
    onSurface: scheme.onSurface,
  );
}
