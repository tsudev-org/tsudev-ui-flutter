import 'package:flutter/material.dart';

/// Màn đăng nhập/đăng ký/Ủng hộ thống nhất của hệ TsuDEV - tsudev-standards `AUTH_AND_ACCOUNT.md` mục 13.2 (v3.3.0,
/// mẫu Quly Thu Chi + Lark) và 13.4 (ô đồng ý).
///
/// App truyền vào các lối vào THẬT đang bật ở IdP (Google, Apple khi IdP có Apple, GitHub, Tài khoản tsudev; khoá truy
/// cập; SSO tổ chức khi IdP có tổ chức) - màn này không gõ cứng nhà cung cấp, không hiện nút chết. Mọi lối vào chạy
/// QUA ô đồng ý: chưa tích ⇒ bảng dưới "Đồng ý và tiếp tục" chạy tiếp đúng lối vào đã bấm. Chế độ khách (hạng C,
/// mục 14) không bắt tích ô.
class TsuSignInOption {
  const TsuSignInOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  /// Định danh ổn định (`google`, `github`, `tsudev`, `passkey`, `sso`...) - dùng cho nhãn "Lần trước".
  final String id;
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
}

class TsuSignInStrings {
  const TsuSignInStrings._({
    required this.lastUsed,
    required this.consentPrefix,
    required this.terms,
    required this.and,
    required this.privacy,
    required this.moreOptions,
    required this.scanToSignIn,
    required this.or,
    required this.sheetTitle,
    required this.sheetBody,
    required this.agree,
    required this.cancel,
  });

  static const vi = TsuSignInStrings._(
    lastUsed: 'Lần trước bạn dùng cách này',
    consentPrefix: 'Tôi đã đọc và chấp nhận ',
    terms: 'Điều khoản dịch vụ',
    and: ' và ',
    privacy: 'Chính sách quyền riêng tư',
    moreOptions: 'Thêm tuỳ chọn đăng nhập',
    scanToSignIn: 'Quét để đăng nhập',
    or: 'hoặc',
    sheetTitle: 'Đồng ý Điều khoản để tiếp tục',
    sheetBody:
        'TsuDEV chỉ dùng tài khoản của bạn để đăng nhập các sản phẩm của hệ sinh thái, không bán dữ liệu, '
        'không quảng cáo.',
    agree: 'Đồng ý và tiếp tục',
    cancel: 'Huỷ',
  );

  static const en = TsuSignInStrings._(
    lastUsed: 'You used this last time',
    consentPrefix: 'I have read and accept the ',
    terms: 'Terms of Service',
    and: ' and ',
    privacy: 'Privacy Policy',
    moreOptions: 'More sign-in options',
    scanToSignIn: 'Scan to sign in',
    or: 'or',
    sheetTitle: 'Accept the Terms to continue',
    sheetBody: 'TsuDEV uses your account only to sign in to its products. No data sales, no ads.',
    agree: 'Agree and continue',
    cancel: 'Cancel',
  );

  final String lastUsed;
  final String consentPrefix;
  final String terms;
  final String and;
  final String privacy;
  final String moreOptions;
  final String scanToSignIn;
  final String or;
  final String sheetTitle;
  final String sheetBody;
  final String agree;
  final String cancel;

  static TsuSignInStrings of(BuildContext context, [Locale? locale]) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi' ? vi : en;
  }
}

class TsuSignInScreen extends StatefulWidget {
  const TsuSignInScreen({
    super.key,
    required this.logo,
    required this.title,
    required this.tagline,
    required this.primary,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    this.more = const [],
    this.onScanToSignIn,
    this.lastUsedId,
    this.guestLabel,
    this.onGuest,
    this.guestNote,
    this.extra = const [],
    this.languageSelector,
    this.locale,
  });

  /// Logo sản phẩm (48px, BRAND_ASSETS mục 2).
  final Widget logo;

  /// "Chào mừng tới `Tên sản phẩm`".
  final String title;

  /// Một câu giá trị.
  final String tagline;

  /// Google, Apple (khi có), GitHub, Tài khoản tsudev - theo đúng thứ tự mục 3.
  final List<TsuSignInOption> primary;

  /// Khoá truy cập, SSO tổ chức (khi IdP có) - dưới dải "Thêm tuỳ chọn đăng nhập".
  final List<TsuSignInOption> more;

  /// Đ1 thiết bị mới: mở bộ quét QR của app. `null` = không hiện liên kết.
  final VoidCallback? onScanToSignIn;
  final String? lastUsedId;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  /// Chế độ khách (hạng C) - không bắt tích ô đồng ý.
  final String? guestLabel;
  final VoidCallback? onGuest;
  final String? guestNote;

  /// Lối phụ của app (vd. "Khôi phục từ tệp sao lưu") - hiện dưới nút khách.
  final List<Widget> extra;
  final Widget? languageSelector;
  final Locale? locale;

  @override
  State<TsuSignInScreen> createState() => _TsuSignInScreenState();
}

class _TsuSignInScreenState extends State<TsuSignInScreen> {
  bool _agreed = false;

  Future<void> _guard(VoidCallback run) async {
    if (_agreed) return run();
    final s = TsuSignInStrings.of(context, widget.locale);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.sheetTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(s.sheetBody),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.agree),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() => _agreed = true);
      run();
    }
  }

  Widget _option(TsuSignInOption o, TsuSignInStrings s) {
    final last = o.id == widget.lastUsedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: ValueKey('tsu-sign-in-${o.id}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _guard(o.onPressed),
            icon: o.icon,
            label: Text(o.label),
          ),
          if (last)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.lastUsed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider(String text) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: muted),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = TsuSignInStrings.of(context, widget.locale);
    final t = Theme.of(context).textTheme;
    final link = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              if (widget.languageSelector != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: widget.languageSelector,
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox.square(dimension: 48, child: widget.logo),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.tagline,
                style: t.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              for (final o in widget.primary) _option(o, s),
              CheckboxListTile(
                key: const ValueKey('tsu-sign-in-consent'),
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Wrap(
                  children: [
                    Text(s.consentPrefix),
                    InkWell(
                      onTap: widget.onOpenTerms,
                      child: Text(s.terms, style: link),
                    ),
                    Text(s.and),
                    InkWell(
                      onTap: widget.onOpenPrivacy,
                      child: Text(s.privacy, style: link),
                    ),
                    const Text('.'),
                  ],
                ),
              ),
              if (widget.more.isNotEmpty || widget.onScanToSignIn != null)
                _divider(s.moreOptions),
              for (final o in widget.more) _option(o, s),
              if (widget.onScanToSignIn != null)
                TextButton.icon(
                  key: const ValueKey('tsu-sign-in-scan'),
                  onPressed: () => _guard(widget.onScanToSignIn!),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(s.scanToSignIn),
                ),
              if (widget.onGuest != null) ...[
                _divider(s.or),
                FilledButton.tonal(
                  key: const ValueKey('tsu-sign-in-guest'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: widget.onGuest,
                  child: Text(widget.guestLabel ?? ''),
                ),
                if (widget.guestNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.guestNote!,
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ),
              ],
              ...widget.extra,
            ],
          ),
        ),
      ),
    );
  }
}
