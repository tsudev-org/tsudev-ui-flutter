import 'package:flutter/material.dart';

import '../entitlements/entitlements_repository.dart';
import '../storage/key_value_store.dart';

/// Nội dung NGUYÊN VĂN của PRODUCT_POLICY 7.3 (v1.1.1, bộ quy ước v3.9.1).
/// KHÔNG sửa chữ ở đây - đổi ở bộ quy ước trước rồi đồng bộ lại.
class ProNoticeStrings {
  const ProNoticeStrings._({
    required this.title,
    required this.bodyTemplate,
    required this.primary,
    required this.secondary,
    required this.link,
  });

  static const vi = ProNoticeStrings._(
    title: 'Dữ liệu chỉ lưu trên thiết bị này',
    bodyTemplate:
        'Tài khoản của bạn đang dùng trên {n} thiết bị. Ở bản miễn phí, dữ liệu '
        'chỉ lưu trên từng thiết bị, không gửi lên internet hay đám mây, nên các '
        'thiết bị không tự đồng bộ với nhau. Để đồng bộ và sao lưu dữ liệu giữa '
        'các thiết bị, hãy nâng cấp lên TsuDEV Pro.',
    primary: 'Xem gói Pro',
    secondary: 'Để sau',
    link: 'Sao lưu ra tệp (miễn phí)',
  );

  static const en = ProNoticeStrings._(
    title: 'Your data stays on this device',
    bodyTemplate:
        'Your account is signed in on {n} devices. On the free plan, data is '
        'stored only on each device and is never sent to the internet or the '
        'cloud, so your devices do not sync with each other. To sync and back '
        'up your data across devices, upgrade to TsuDEV Pro.',
    primary: 'See Pro plans',
    secondary: 'Not now',
    link: 'Back up to a file (free)',
  );

  final String title;
  final String bodyTemplate;
  final String primary;
  final String secondary;
  final String link;

  String body(int devices) => bodyTemplate.replaceAll('{n}', '$devices');

  static ProNoticeStrings of(BuildContext context, [Locale? locale]) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi' ? vi : en;
  }
}

/// Quy tắc hiện/không hiện (PRODUCT_POLICY 7.3) - hàm thuần, dễ test.
abstract final class ProNoticePolicy {
  /// Mốc lần hiện gần nhất TRÊN THIẾT BỊ NÀY (giờ UTC, ISO 8601).
  static const lastShownKey = 'tsu.pro_notice.last_shown';
  static const interval = Duration(days: 30);

  /// Mốc ở tương lai xa hơn mức này (đồng hồ từng chạy sai) ⇒ coi như chưa hiện,
  /// tránh câm vĩnh viễn.
  static const _futureTolerance = Duration(days: 1);

  static bool shouldShow({
    required EntitlementState state,
    required DateTime now,
    DateTime? lastShown,
  }) {
    final e = state.entitlement;
    // Không có JWS còn hạn (ngoại tuyến quá lâu, chưa đăng nhập) ⇒ không hiện:
    // không đủ dữ liệu để biết có ≥ 2 thiết bị.
    if (e == null) return false;
    if (e.isProActive(now)) return false;
    if (e.devices30d < 2) return false;
    if (lastShown == null) return true;
    final utcNow = now.toUtc();
    if (lastShown.isAfter(utcNow.add(_futureTolerance))) return true;
    return utcNow.difference(lastShown) >= interval;
  }
}

/// Đọc/ghi mốc [ProNoticePolicy.lastShownKey] và quyết định có hiện không.
class ProNoticeController {
  ProNoticeController({required this.store, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TsuKeyValueStore store;
  final DateTime Function() _clock;

  Future<DateTime?> lastShown() async {
    final raw = await store.read(ProNoticePolicy.lastShownKey);
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return parsed?.toUtc();
  }

  Future<bool> shouldShow(EntitlementState state) async =>
      ProNoticePolicy.shouldShow(
        state: state,
        now: _clock(),
        lastShown: await lastShown(),
      );

  Future<void> markShown() => store.write(
    ProNoticePolicy.lastShownKey,
    _clock().toUtc().toIso8601String(),
  );
}

/// Người dùng đã bấm gì.
enum ProNoticeAction { seePro, later, backupToFile, dismissed }

/// Hộp thoại "nhiều thiết bị chưa có Pro". Đóng được, không đếm ngược.
///
/// Nút chính: bản Play/App Store ⇒ mở luồng IAP; bản ngoài cửa hàng ⇒ mở
/// [proWebUrl]. Bản Play `MUST NOT` dẫn ra thanh toán web (PRODUCT_POLICY 4.3) -
/// app tự chọn trong `onSeePro` của [maybeShowProNotice].
class ProNoticeDialog extends StatelessWidget {
  const ProNoticeDialog({super.key, required this.devices, this.locale});

  final int devices;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final s = ProNoticeStrings.of(context, locale);
    return AlertDialog(
      title: Text(s.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.body(devices)),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () =>
                  Navigator.of(context).pop(ProNoticeAction.backupToFile),
              child: Text(
                s.link,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ProNoticeAction.later),
          child: Text(s.secondary),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ProNoticeAction.seePro),
          child: Text(s.primary),
        ),
      ],
    );
  }
}

/// Trang Pro cho bản ngoài cửa hàng (PRODUCT_POLICY 7.4).
Uri proWebUrl(String clientId) =>
    Uri.https('tsudev.com', '/pro', {'app': clientId});

/// Gọi khi mở app / ở màn chính (KHÔNG gọi giữa lúc người dùng đang nhập liệu).
///
/// Hiện hộp thoại nếu [ProNoticePolicy] cho phép, ghi mốc ngay khi hiện, rồi
/// chuyển hành động cho app. Trả `null` nếu không hiện. Không bao giờ ném lỗi.
Future<ProNoticeAction?> maybeShowProNotice(
  BuildContext context, {
  required ProNoticeController controller,
  required EntitlementState state,
  required VoidCallback onSeePro,
  required VoidCallback onBackupToFile,
  Locale? locale,
}) async {
  try {
    if (!await controller.shouldShow(state)) return null;
    if (!context.mounted) return null;
    await controller.markShown();
    if (!context.mounted) return null;
    final action =
        await showDialog<ProNoticeAction>(
          context: context,
          builder: (_) =>
              ProNoticeDialog(devices: state.devices30d, locale: locale),
        ) ??
        ProNoticeAction.dismissed;
    switch (action) {
      case ProNoticeAction.seePro:
        onSeePro();
      case ProNoticeAction.backupToFile:
        onBackupToFile();
      case ProNoticeAction.later || ProNoticeAction.dismissed:
        break;
    }
    return action;
  } on Object {
    return null;
  }
}
