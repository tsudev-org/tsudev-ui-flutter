import 'package:flutter/material.dart';

import 'tsu_pro_theme.dart';

/// Khung ảnh đại diện Pro (phần Q2): vòng chuyển sắc `ringStart → ringEnd` của chủ đề quanh [child].
///
/// Thuần trang trí - không đổi ngữ nghĩa ảnh (trình đọc màn hình vẫn đọc nhãn của [child]); Pro không phải xác minh
/// danh tính nên KHÔNG có dấu tích/khiên. [theme] `null` (chưa Pro, tương phản cao) ⇒ trả về [child] nguyên vẹn.
class TsuProAvatarFrame extends StatelessWidget {
  const TsuProAvatarFrame({
    super.key,
    required this.child,
    required this.theme,
    this.ringWidth = 2.5,
    this.gap = 2,
  });

  final Widget child;
  final TsuProTheme? theme;
  final double ringWidth;

  /// Khe giữa vòng và ảnh, tô bằng `surface` để vòng tách khỏi ảnh ở mọi nền.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (t == null) return child;
    final scheme = Theme.of(context).colorScheme;
    final p = t.of(scheme.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [p.ringStart, p.ringEnd, p.ringStart]),
      ),
      child: Padding(
        padding: EdgeInsets.all(ringWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface,
          ),
          child: Padding(padding: EdgeInsets.all(gap), child: child),
        ),
      ),
    );
  }
}

/// Chuỗi của [TsuProThemePicker] (vi/en).
@immutable
class TsuProThemeStrings {
  const TsuProThemeStrings._({
    required this.title,
    required this.defaultLabel,
    required this.defaultHint,
    required this.previewNote,
    required this.learnMore,
    required this.highContrastNote,
  });

  final String title;
  final String defaultLabel;
  final String defaultHint;
  final String previewNote;
  final String learnMore;
  final String highContrastNote;

  static const vi = TsuProThemeStrings._(
    title: 'Chủ đề màu',
    defaultLabel: 'Mặc định',
    defaultHint: 'Màu của ứng dụng',
    previewNote:
        'Chủ đề màu bổ sung là một quyền lợi của TsuDEV Pro - gói tự nguyện ủng hộ tác giả. '
        'Giao diện mặc định, Sáng/Tối và tương phản cao luôn miễn phí.',
    learnMore: 'Tìm hiểu TsuDEV Pro',
    highContrastNote: 'Đang bật tương phản cao - chủ đề màu tạm không áp dụng.',
  );

  static const en = TsuProThemeStrings._(
    title: 'Colour theme',
    defaultLabel: 'Default',
    defaultHint: 'The app’s own colours',
    previewNote:
        'Extra colour themes are a TsuDEV Pro benefit - an optional plan to support the author. '
        'The default look, Light/Dark and high contrast are always free.',
    learnMore: 'Learn about TsuDEV Pro',
    highContrastNote: 'High contrast is on - colour themes are paused.',
  );

  static TsuProThemeStrings of(BuildContext context, [Locale? locale]) {
    final l = locale ?? Localizations.maybeLocaleOf(context);
    return l?.languageCode == 'en' ? en : vi;
  }
}

/// Bộ chọn chủ đề Pro cho **Cài đặt → Giao diện** (`DESIGN_SYSTEM.md` mục 1.3).
///
/// - Luôn có "Mặc định" (miễn phí) đứng đầu; 5 chủ đề hiện mẫu màu thật của cả Sáng và Tối.
/// - Chưa có Pro ([hasPro] = false): vẫn thấy đủ mẫu màu (không làm mờ, không ổ khoá), chỉ "Mặc định" chọn được,
///   kèm một câu giải thích và liên kết [onLearnMore] - lối vào Pro hợp lệ theo `PRODUCT_POLICY` 3.7.3.
/// - [highContrast] = true: hiện ghi chú, lựa chọn vẫn được lưu nhưng không áp dụng.
///
/// [selectedId] `null` = Mặc định. Gói không lưu trữ: app lưu [onChanged] vào kho của mình.
class TsuProThemePicker extends StatelessWidget {
  const TsuProThemePicker({
    super.key,
    required this.selectedId,
    required this.hasPro,
    required this.onChanged,
    this.onLearnMore,
    this.highContrast = false,
    this.locale,
  });

  final String? selectedId;
  final bool hasPro;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onLearnMore;
  final bool highContrast;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final s = TsuProThemeStrings.of(context, locale);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = hasPro ? TsuProTheme.byId(selectedId)?.id : null;
    final l = locale ?? Localizations.maybeLocaleOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s.title, style: text.titleMedium),
          ),
        ),
        _Option(
          label: s.defaultLabel,
          hint: s.defaultHint,
          selected: current == null,
          enabled: true,
          swatches: [scheme.primary, scheme.secondary],
          onTap: () => onChanged(null),
        ),
        for (final t in TsuProTheme.all)
          _Option(
            key: ValueKey('tsu-pro-theme-${t.id}'),
            label: t.name(l),
            selected: current == t.id,
            enabled: hasPro,
            swatches: [
              t.light.primary,
              t.light.bgSurface,
              t.dark.primary,
              t.dark.bgSurface,
            ],
            onTap: hasPro ? () => onChanged(t.id) : null,
          ),
        if (highContrast)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(s.highContrastNote, style: text.bodyMedium),
          ),
        if (!hasPro) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              s.previewNote,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (onLearnMore != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onLearnMore,
                child: Text(s.learnMore),
              ),
            ),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.swatches,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final bool enabled;
  final List<Color> swatches;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      button: true,
      label: label,
      hint: hint,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: enabled ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      if (hint != null)
                        Text(
                          hint!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                for (final c in swatches)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
