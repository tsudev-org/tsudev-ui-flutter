import 'package:flutter/material.dart';

/// Quyền lợi Pro - danh sách ĐÓNG của PRODUCT_POLICY 3.7.1 (bộ quy ước v6.1.0).
/// Thêm quyền lợi riêng của một sản phẩm ⇒ ADR + chủ dự án duyệt, sửa bộ quy
/// ước trước rồi mới thêm ở đây.
enum ProBenefit {
  /// Q1 - huy hiệu Pro cạnh tên tài khoản.
  badge,

  /// Q2 - giao diện Pro (chủ đề màu, biểu tượng app thay thế, khung ảnh đại diện).
  proTheme,

  /// Q3 - đồng bộ + sao lưu đám mây mã hoá đầu cuối.
  cloudSync,
}

/// Nội dung NGUYÊN VĂN của PRODUCT_POLICY 3.7.3 + 7.5 (bộ quy ước v6.1.0).
/// KHÔNG sửa câu định vị, điều khoản, ô xác nhận ở đây - đổi ở bộ quy ước trước.
class ProPurchaseStrings {
  const ProPurchaseStrings._({
    required this.title,
    required this.positioning,
    required this.benefitsHeading,
    required this.badge,
    required this.proTheme,
    required this.cloudSync,
    required this.termsTemplate,
    required this.pricePlaceholder,
    required this.paymentPolicy,
    required this.terms,
    required this.confirm,
    required this.buy,
    required this.close,
  });

  static const vi = ProPurchaseStrings._(
    title: 'TsuDEV Pro',
    positioning:
        'Ứng dụng TsuDEV miễn phí; dự án gắn nhãn OPEN công khai mã nguồn trên '
        'GitHub. TsuDEV Pro không bắt buộc: bạn chọn Pro để ủng hộ tác giả duy '
        'trì và phát triển dự án, đổi lại tài khoản nhận thêm các quyền lợi '
        'dưới đây.',
    benefitsHeading: 'Quyền lợi',
    badge: 'Huy hiệu Pro cạnh tên tài khoản ở mọi ứng dụng và website TsuDEV',
    proTheme:
        'Giao diện Pro: thêm chủ đề màu, biểu tượng ứng dụng và khung ảnh đại '
        'diện',
    cloudSync: 'Đồng bộ và sao lưu đám mây mã hoá đầu cuối',
    termsTemplate:
        'TsuDEV Pro {giá} cho 1 năm, KHÔNG tự gia hạn. Gia hạn sớm được cộng '
        'thêm 1 năm vào thời hạn còn lại. Hết hạn mà chưa gia hạn, ứng dụng trở '
        'về bản miễn phí và ngừng đồng bộ lên đám mây; dữ liệu trên thiết bị vẫn '
        'giữ nguyên, bản sao trên đám mây còn tải về được 90 ngày rồi bị xoá.',
    pricePlaceholder: '{giá}',
    paymentPolicy: 'Chính sách thanh toán, hoàn tiền và khiếu nại',
    terms: 'Điều khoản sử dụng',
    confirm:
        'Tôi hiểu TsuDEV Pro là gói dịch vụ trả phí không bắt buộc, có thời '
        'hạn 1 năm và không tự gia hạn.',
    buy: 'Mua TsuDEV Pro',
    close: 'Đóng',
  );

  static const en = ProPurchaseStrings._(
    title: 'TsuDEV Pro',
    positioning:
        'TsuDEV apps are free; projects labelled OPEN publish their source code '
        'on GitHub. TsuDEV Pro is optional: choose Pro to support the author in '
        'maintaining and developing the project, and your account gets the '
        'extra benefits below.',
    benefitsHeading: 'Benefits',
    badge:
        'Pro badge next to your account name in every TsuDEV app and website',
    proTheme: 'Pro look: extra color themes, app icons and avatar frames',
    cloudSync: 'End-to-end encrypted cloud sync and backup',
    termsTemplate:
        'TsuDEV Pro {price} for 1 year, does NOT renew automatically. Renewing '
        'early adds 1 year to your remaining time. If it expires without '
        'renewal, the app returns to the free version and stops syncing to the '
        'cloud; data on your device stays intact, and your cloud copy can be '
        'downloaded for 90 days before it is deleted.',
    pricePlaceholder: '{price}',
    paymentPolicy: 'Payment, refund and complaint policy',
    terms: 'Terms of use',
    confirm:
        'I understand TsuDEV Pro is an optional paid plan that lasts 1 year and '
        'does not renew automatically.',
    buy: 'Buy TsuDEV Pro',
    close: 'Close',
  );

  final String title;
  final String positioning;
  final String benefitsHeading;
  final String badge;
  final String proTheme;
  final String cloudSync;
  final String termsTemplate;
  final String pricePlaceholder;
  final String paymentPolicy;
  final String terms;
  final String confirm;
  final String buy;
  final String close;

  String benefit(ProBenefit b) => switch (b) {
    ProBenefit.badge => badge,
    ProBenefit.proTheme => proTheme,
    ProBenefit.cloudSync => cloudSync,
  };

  /// Điều khoản 7.5 với giá đã định dạng (vd. "490.000 ₫" hoặc giá cửa hàng trả về).
  String termsFor(String price) =>
      termsTemplate.replaceAll(pricePlaceholder, price);

  static ProPurchaseStrings of(BuildContext context, [Locale? locale]) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi' ? vi : en;
  }
}

/// Màn mua TsuDEV Pro (PRODUCT_POLICY 3.7.3), theo thứ tự bắt buộc: câu định vị
/// → quyền lợi ĐANG CHẠY THẬT ([benefits]) → điều khoản 7.5 + liên kết Chính
/// sách thanh toán và Điều khoản → ô xác nhận KHÔNG chọn sẵn → nút mua (vô hiệu
/// tới khi đánh dấu).
///
/// Gói không tự thanh toán: [onPurchase] do app quyết (Play/App Store ⇒ mở luồng
/// mua của cửa hàng; ngoài cửa hàng ⇒ mở `proWebUrl(clientId)`; bản Play `MUST
/// NOT` dẫn ra thanh toán web). Chỉ mở màn này từ lối vào đã duyệt (3.7.2):
/// Tài khoản/Cài đặt, Giới thiệu, hai hộp thoại 7.3 / 7.6.
class ProPurchaseSheet extends StatefulWidget {
  const ProPurchaseSheet({
    super.key,
    required this.benefits,
    required this.price,
    required this.onOpenPaymentPolicy,
    required this.onOpenTerms,
    required this.onPurchase,
    this.onClose,
    this.locale,
  });

  /// Quyền lợi đang hoạt động thật trong sản phẩm này; chưa làm xong `MUST NOT`
  /// có mặt. Hiện theo thứ tự Q1 → Q3, bỏ trùng.
  final Set<ProBenefit> benefits;

  /// Giá hiển thị một lần, đủ: "490.000 ₫" (web, đã gồm thuế) hoặc giá cửa
  /// hàng trả về. Không giá gạch, không "giảm giá".
  final String price;

  /// Mở `https://tsudev.com/chinh-sach-thanh-toan`.
  final VoidCallback onOpenPaymentPolicy;

  /// Mở `https://tsudev.com/terms`.
  final VoidCallback onOpenTerms;

  /// Chỉ gọi khi ô xác nhận đã đánh dấu.
  final VoidCallback onPurchase;

  /// Nút "Đóng"; mặc định `Navigator.maybePop`.
  final VoidCallback? onClose;

  final Locale? locale;

  @override
  State<ProPurchaseSheet> createState() => _ProPurchaseSheetState();
}

class _ProPurchaseSheetState extends State<ProPurchaseSheet> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    assert(
      widget.benefits.isNotEmpty,
      'PRODUCT_POLICY 3.7.3: cần ≥ 1 quyền lợi',
    );
    final s = ProPurchaseStrings.of(context, widget.locale);
    final theme = Theme.of(context);
    final link = TextStyle(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final ordered = ProBenefit.values.where(widget.benefits.contains);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(s.title, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: 12),
            Text(
              s.positioning,
              key: const ValueKey('tsu-pro-positioning'),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                s.benefitsHeading,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            for (final b in ordered)
              Padding(
                key: ValueKey('tsu-pro-benefit-${b.name}'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ExcludeSemantics(child: Text('•  ')),
                    Expanded(child: Text(s.benefit(b))),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              s.termsFor(widget.price),
              key: const ValueKey('tsu-pro-terms'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                InkWell(
                  key: const ValueKey('tsu-pro-payment-policy'),
                  onTap: widget.onOpenPaymentPolicy,
                  child: Text(s.paymentPolicy, style: link),
                ),
                InkWell(
                  key: const ValueKey('tsu-pro-terms-link'),
                  onTap: widget.onOpenTerms,
                  child: Text(s.terms, style: link),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const ValueKey('tsu-pro-confirm'),
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(s.confirm),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('tsu-pro-buy'),
              onPressed: _confirmed ? widget.onPurchase : null,
              child: Text(s.buy),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('tsu-pro-close'),
              onPressed:
                  widget.onClose ?? () => Navigator.of(context).maybePop(),
              child: Text(s.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở [ProPurchaseSheet] dạng bảng dưới, đóng được (vuốt/nút Đóng).
/// Trả `true` nếu người dùng đã xác nhận và bấm mua - khi đó app TỰ mở luồng
/// thanh toán phù hợp kênh phát hành.
Future<bool> showProPurchaseSheet(
  BuildContext context, {
  required Set<ProBenefit> benefits,
  required String price,
  required VoidCallback onOpenPaymentPolicy,
  required VoidCallback onOpenTerms,
  Locale? locale,
}) async {
  final bought = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ProPurchaseSheet(
      benefits: benefits,
      price: price,
      locale: locale,
      onOpenPaymentPolicy: onOpenPaymentPolicy,
      onOpenTerms: onOpenTerms,
      onPurchase: () => Navigator.of(ctx).pop(true),
      onClose: () => Navigator.of(ctx).pop(false),
    ),
  );
  return bought ?? false;
}
