import 'package:flutter/material.dart';

import '../entitlements/entitlement.dart';

/// Màu lấy đúng từ `tsudev-standards/assets/badges/README.md` (v3.9.1).
abstract final class TsuBadgeColors {
  static const proStart = Color(0xFF30C8F0);
  static const proEnd = Color(0xFF1E90FF);
  static const proInk = Color(0xFF0A0A0A);

  static const donorLightFill = Color(0xFFCCFBF1);
  static const donorLightBorder = Color(0xFF0F766E);
  static const donorLightInk = Color(0xFF134E4A);

  static const donorDarkFill = Color(0xFF042F2E);
  static const donorDarkBorder = Color(0xFF2DD4BF);
  static const donorDarkInk = Color(0xFF99F6E4);
}

/// Chữ và nhãn đọc màn hình (README `assets/badges`).
class TsuBadgeStrings {
  const TsuBadgeStrings._(this.proLabel, this.donorText, this.donorLabel);

  static const vi = TsuBadgeStrings._(
    'Tài khoản Pro',
    'Ủng hộ',
    'Đã ủng hộ TsuDEV',
  );
  static const en = TsuBadgeStrings._(
    'Pro account',
    'Supporter',
    'Supported TsuDEV',
  );

  final String proLabel;
  final String donorText;
  final String donorLabel;

  static TsuBadgeStrings of(BuildContext context, [Locale? locale]) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi' ? vi : en;
  }
}

/// Cao huy hiệu = 0,75 × chiều cao dòng của tên, kẹp 16-20 px (PRODUCT_POLICY 4.2).
double tsuBadgeHeightFor(BuildContext context, TextStyle? nameStyle) {
  final style = DefaultTextStyle.of(context).style.merge(nameStyle);
  final fontSize = style.fontSize ?? 14;
  final lineHeight = MediaQuery.textScalerOf(context)
      .scale(fontSize * (style.height ?? 1.2));
  return (lineHeight * 0.75).clamp(16.0, 20.0);
}

/// Huy hiệu Pro / Ủng hộ. [TsuBadgeKind.both] ⇒ Pro trước, Ủng hộ sau;
/// [TsuBadgeKind.none] ⇒ không vẽ gì.
///
/// Chuyển động (shimmer Pro mỗi [shimmerPeriod], tim đập khi rê/chạm) tự tắt khi
/// hệ điều hành bật "Giảm chuyển động" ([MediaQueryData.disableAnimations]).
class TsuBadge extends StatelessWidget {
  const TsuBadge({
    super.key,
    required this.kind,
    this.height,
    this.nameStyle,
    this.locale,
    this.shimmerPeriod = const Duration(seconds: 7),
  });

  final TsuBadgeKind kind;

  /// Cao cố định (đã kẹp 16-20). Mặc định tính từ [nameStyle].
  final double? height;
  final TextStyle? nameStyle;

  /// Ép ngôn ngữ chữ `Ủng hộ`/`Supporter`; mặc định theo [Localizations].
  final Locale? locale;
  final Duration shimmerPeriod;

  @override
  Widget build(BuildContext context) {
    assert(
      shimmerPeriod >= const Duration(seconds: 6) &&
          shimmerPeriod <= const Duration(seconds: 8),
      'PRODUCT_POLICY 4.2: shimmer một lần mỗi 6-8 giây',
    );
    if (kind == TsuBadgeKind.none) return const SizedBox.shrink();
    final h = (height ?? tsuBadgeHeightFor(context, nameStyle)).clamp(
      16.0,
      20.0,
    );
    final strings = TsuBadgeStrings.of(context, locale);
    final pro = kind.showsPro
        ? _ProBadge(height: h, label: strings.proLabel, period: shimmerPeriod)
        : null;
    final donor = kind.showsDonor
        ? _DonorBadge(
            height: h,
            text: strings.donorText,
            label: strings.donorLabel,
          )
        : null;
    if (pro != null && donor != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pro,
          SizedBox(width: h * 0.2),
          donor,
        ],
      );
    }
    return pro ?? donor!;
  }
}

/// Tên + huy hiệu trên một dòng: tên tự cắt "…" trước, huy hiệu giữ nguyên
/// (PRODUCT_POLICY 4.2). Khoảng cách tên-huy hiệu 5 px.
class TsuNameWithBadge extends StatelessWidget {
  const TsuNameWithBadge({
    super.key,
    required this.name,
    required this.badge,
    this.style,
    this.locale,
  });

  final String name;
  final TsuBadgeKind badge;
  final TextStyle? style;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != TsuBadgeKind.none) ...[
          const SizedBox(width: 5),
          TsuBadge(kind: badge, nameStyle: style, locale: locale),
        ],
      ],
    );
  }
}

TextStyle _badgeText(double h, Color color, {double letterSpacing = 0}) =>
    TextStyle(
      color: color,
      fontSize: h * 0.55,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
    );

class _ProBadge extends StatefulWidget {
  const _ProBadge({
    required this.height,
    required this.label,
    required this.period,
  });

  final double height;
  final String label;
  final Duration period;

  @override
  State<_ProBadge> createState() => _ProBadgeState();
}

class _ProBadgeState extends State<_ProBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final width = h * 1.9; // 38 × 20 trong SVG gốc
    return Semantics(
      label: widget.label,
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(h / 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [TsuBadgeColors.proStart, TsuBadgeColors.proEnd],
                  ),
                ),
              ),
              // Dải sáng nằm DƯỚI chữ: chỉ làm nền sáng hơn ⇒ tương phản không giảm.
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) =>
                    CustomPaint(painter: _ShimmerPainter(_c.value)),
              ),
              Center(
                child: Text(
                  'PRO',
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                  style: _badgeText(
                    h,
                    TsuBadgeColors.proInk,
                    letterSpacing: h * 0.03,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dải sáng lướt qua trong 20% đầu chu kỳ, còn lại đứng yên (≤ 1 lần / chu kỳ).
class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter(this.t);

  final double t;
  static const _sweep = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= _sweep) return;
    final p = t / _sweep;
    final band = size.width * 0.6;
    final left = -band + (size.width + band) * p;
    final rect = Rect.fromLTWH(left, 0, band, size.height);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t;
}

class _DonorBadge extends StatefulWidget {
  const _DonorBadge({
    required this.height,
    required this.text,
    required this.label,
  });

  final double height;
  final String text;
  final String label;

  @override
  State<_DonorBadge> createState() => _DonorBadgeState();
}

class _DonorBadgeState extends State<_DonorBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  // Một nhịp: 1 → 1,15 → 1 (một lần mỗi lần rê/chạm, không lặp).
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.15), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1), weight: 1),
  ]).animate(CurvedAnimation(parent: _beat, curve: Curves.easeInOut));

  void _pulse() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce || _beat.isAnimating) return;
    _beat.forward(from: 0);
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark
        ? TsuBadgeColors.donorDarkFill
        : TsuBadgeColors.donorLightFill;
    final border = dark
        ? TsuBadgeColors.donorDarkBorder
        : TsuBadgeColors.donorLightBorder;
    final ink = dark
        ? TsuBadgeColors.donorDarkInk
        : TsuBadgeColors.donorLightInk;
    final u = h / 20; // đơn vị của SVG gốc

    return Semantics(
      label: widget.label,
      container: true,
      excludeSemantics: true,
      // Listener không tranh cử chỉ: chạm vào huy hiệu vẫn tới nút cha.
      child: Listener(
        onPointerDown: (_) => _pulse(),
        child: MouseRegion(
          onEnter: (_) => _pulse(),
          child: Container(
            height: h,
            padding: EdgeInsets.only(left: 8.2 * u, right: 8 * u),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: border, width: u),
              borderRadius: BorderRadius.circular(h / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: CustomPaint(
                    size: Size(9.6 * u, 8.7 * u),
                    painter: _HeartPainter(ink),
                  ),
                ),
                SizedBox(width: 4.2 * u),
                Text(
                  widget.text,
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                  style: _badgeText(h, ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trái tim đúng đường `path` của `tsu-badge-donor-*.svg`, dời gốc về (8.2, 6.5).
class _HeartPainter extends CustomPainter {
  _HeartPainter(this.color);

  final Color color;

  static final Path _heart = Path()
    ..moveTo(13 - 8.2, 15.2 - 6.5)
    ..relativeLineTo(-.7, -.64)
    ..cubicTo(9.8 - 8.2, 12.3 - 6.5, 0, 10.85 - 6.5, 0, 9.1 - 6.5)
    ..relativeCubicTo(0, -1.45, 1.13, -2.6, 2.6, -2.6)
    ..relativeCubicTo(.82, 0, 1.6, .38, 2.2, .98)
    ..relativeCubicTo(.6, -.6, 1.38, -.98, 2.2, -.98)
    ..relativeCubicTo(1.47, 0, 2.6, 1.15, 2.6, 2.6)
    ..relativeCubicTo(0, 1.75, -1.6, 3.2, -4.1, 5.46)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 9.6;
    canvas
      ..save()
      ..scale(s)
      ..drawPath(_heart, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.color != color;
}
