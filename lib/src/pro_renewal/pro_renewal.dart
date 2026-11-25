import 'package:flutter/material.dart';

import '../entitlements/entitlements_repository.dart';
import '../storage/key_value_store.dart';

/// Loại hộp thoại của PRODUCT_POLICY 7.6.
enum ProRenewalKind {
  /// 0 < `pro_until` - bây giờ ≤ 7 ngày: nhắc mỗi lần mở app.
  reminder,

  /// `pro_until` ≤ bây giờ, thiết bị từng có Pro: báo một lần mỗi `pro_until`.
  expired,
}

/// Nội dung NGUYÊN VĂN của PRODUCT_POLICY 7.6 (v2.0.0, bộ quy ước v7.0.0 - bỏ Q3).
/// KHÔNG sửa chữ ở đây - đổi ở bộ quy ước trước rồi đồng bộ lại.
class ProRenewalStrings {
  const ProRenewalStrings._({
    required this.title,
    required this.bodyTemplate,
    required this.primary,
    required this.secondary,
    this.datePlaceholder,
  });

  static const reminderVi = ProRenewalStrings._(
    title: 'Gia hạn TsuDEV Pro',
    bodyTemplate:
        'Gói TsuDEV Pro của bạn hết hạn sau {n} ngày (ngày {ngày}). Gia hạn để '
        'giữ huy hiệu và giao diện Pro. Nếu không gia hạn, tài khoản sẽ trở về '
        'bản miễn phí; mọi tính năng và dữ liệu trên thiết bị vẫn giữ nguyên.',
    primary: 'Gia hạn',
    secondary: 'Để sau',
    datePlaceholder: '{ngày}',
  );

  static const reminderEn = ProRenewalStrings._(
    title: 'Renew TsuDEV Pro',
    bodyTemplate:
        'Your TsuDEV Pro expires in {n} days (on {date}). Renew to keep the Pro '
        "badge and Pro themes. If you don't renew, your account returns to the "
        'free version; all features and data on your devices stay intact.',
    primary: 'Renew',
    secondary: 'Later',
    datePlaceholder: '{date}',
  );

  static const expiredVi = ProRenewalStrings._(
    title: 'TsuDEV Pro đã hết hạn',
    bodyTemplate:
        'Tài khoản đã trở về bản miễn phí: huy hiệu và giao diện Pro đã tắt. Mọi '
        'tính năng và dữ liệu trên thiết bị vẫn giữ nguyên.',
    primary: 'Gia hạn',
    secondary: 'Đóng',
  );

  static const expiredEn = ProRenewalStrings._(
    title: 'TsuDEV Pro has expired',
    bodyTemplate:
        'Your account is back on the free version: the Pro badge and Pro themes '
        'are off. All features and data on your devices stay intact.',
    primary: 'Renew',
    secondary: 'Close',
  );

  final String title;
  final String bodyTemplate;
  final String primary;
  final String secondary;

  /// `{ngày}` / `{date}` (chỉ bảng nhắc; báo hết kỳ không có ngày).
  final String? datePlaceholder;

  /// Điền `{n}` và ngày đã định dạng (chỉ bảng nhắc).
  String body({int? days, String? date}) {
    var t = bodyTemplate;
    if (days != null) t = t.replaceAll('{n}', '$days');
    final ph = datePlaceholder;
    if (ph != null && date != null) t = t.replaceAll(ph, date);
    return t;
  }

  static ProRenewalStrings of(
    ProRenewalKind kind,
    BuildContext context, [
    Locale? locale,
  ]) {
    final vi = _isVi(context, locale);
    return switch (kind) {
      ProRenewalKind.reminder => vi ? reminderVi : reminderEn,
      ProRenewalKind.expired => vi ? expiredVi : expiredEn,
    };
  }

  static bool _isVi(BuildContext context, Locale? locale) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi';
  }
}

/// Định dạng ngày theo giờ máy: vi ⇒ DD/MM/YYYY; ngôn ngữ khác ⇒ kiểu tiếng
/// Anh "November 27, 2026" (không mơ hồ ngày/tháng). [local] phải là giờ máy.
String formatProRenewalDate(DateTime local, Locale locale) {
  String two(int v) => v.toString().padLeft(2, '0');
  if (locale.languageCode == 'vi') {
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

/// Kết quả quyết định: hiện hộp thoại nào, với số liệu gì.
@immutable
class ProRenewalDecision {
  const ProRenewalDecision._(this.kind, this.proUntil, this.daysLeft);

  /// Dựng sẵn để xem trước/golden; app thường nhận từ [ProRenewalPolicy.decide].
  const ProRenewalDecision.reminder({
    required DateTime proUntil,
    required int daysLeft,
  }) : this._(ProRenewalKind.reminder, proUntil, daysLeft);

  const ProRenewalDecision.expired({required DateTime proUntil})
    : this._(ProRenewalKind.expired, proUntil, null);

  final ProRenewalKind kind;

  /// `pro_until` của JWS (UTC).
  final DateTime proUntil;

  /// `{n}` - số ngày còn lại làm tròn lên, ≥ 1 (chỉ với [ProRenewalKind.reminder]).
  final int? daysLeft;

  @override
  bool operator ==(Object other) =>
      other is ProRenewalDecision &&
      other.kind == kind &&
      other.proUntil == proUntil &&
      other.daysLeft == daysLeft;

  @override
  int get hashCode => Object.hash(kind, proUntil, daysLeft);

  @override
  String toString() => 'ProRenewalDecision(${kind.name}, $proUntil, $daysLeft)';
}

/// Quy tắc hiện/không hiện (PRODUCT_POLICY 7.6) - hàm thuần, dễ test.
abstract final class ProRenewalPolicy {
  /// `pro_until` đã báo hết kỳ (giây Unix) - định danh của 7.6.
  static const notifiedUntilKey = 'tsu.pro_expired.notified_until';

  /// `pro_until` lớn nhất mà thiết bị này từng thấy KHI Pro còn hạn (giây Unix) -
  /// dùng cho điều kiện "JWS trước đó của thiết bị từng có Pro". Khoá nội bộ
  /// của gói, không phải định danh hợp đồng.
  static const seenProUntilKey = 'tsu.pro_renewal.seen_pro_until';

  static const reminderWindow = Duration(days: 7);

  /// Quay lại app sau ≥ mức này ở nền ⇒ tính là một lần mở mới.
  static const reopenAfter = Duration(minutes: 30);

  /// `{n}` = số ngày còn lại làm tròn lên, ≥ 1.
  static int daysLeft(DateTime proUntil, DateTime now) {
    final ms = proUntil.difference(now.toUtc()).inMilliseconds;
    final days = (ms / Duration.millisecondsPerDay).ceil();
    return days < 1 ? 1 : days;
  }

  /// Lần mở mới: khởi động mới ([backgroundedAt] = null) hoặc quay lại sau
  /// ≥ [reopenAfter] ở nền.
  static bool isNewOpen({
    required DateTime? backgroundedAt,
    required DateTime now,
  }) =>
      backgroundedAt == null ||
      now.toUtc().difference(backgroundedAt.toUtc()) >= reopenAfter;

  /// - Không có JWS còn hạn ⇒ không gì (coi như miễn phí, mục 3.4).
  /// - Nhắc: 0 < `pro_until` - [now] ≤ 7 ngày và lần mở này chưa nhắc
  ///   ([openPending]).
  /// - Hết kỳ: `pro_until` ≤ [now], thiết bị từng thấy Pro còn hạn
  ///   ([seenProUntil] ≠ null) và chưa báo cho đúng giá trị `pro_until` này
  ///   ([notifiedUntil]).
  static ProRenewalDecision? decide({
    required EntitlementState state,
    required DateTime now,
    required bool openPending,
    int? notifiedUntil,
    int? seenProUntil,
  }) {
    final proUntil = state.entitlement?.proUntil;
    if (proUntil == null) return null;
    final utcNow = now.toUtc();
    if (proUntil.isAfter(utcNow)) {
      if (!openPending) return null;
      if (proUntil.difference(utcNow) > reminderWindow) return null;
      return ProRenewalDecision._(
        ProRenewalKind.reminder,
        proUntil,
        daysLeft(proUntil, utcNow),
      );
    }
    if (seenProUntil == null) return null;
    if (notifiedUntil == _seconds(proUntil)) return null;
    return ProRenewalDecision._(ProRenewalKind.expired, proUntil, null);
  }

  static int _seconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
}

/// Giữ trạng thái "lần mở" (trong bộ nhớ) và hai khoá cục bộ của 7.6.
///
/// Tạo MỘT đối tượng cho cả vòng đời tiến trình (khởi động mới = một lần mở
/// chưa nhắc) và nối vòng đời app:
/// `AppLifecycleListener(onStateChange: controller.handleAppLifecycleState)`.
class ProRenewalController {
  ProRenewalController({required this.store, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TsuKeyValueStore store;
  final DateTime Function() _clock;

  bool _openPending = true;
  DateTime? _backgroundedAt;

  /// Lần mở hiện tại còn được nhắc gia hạn không.
  bool get openPending => _openPending;

  /// Nhận sự kiện vòng đời: vào nền (`hidden`/`paused`) ghi mốc; `resumed` sau
  /// ≥ 30 phút ⇒ lần mở mới.
  void handleAppLifecycleState(AppLifecycleState s) {
    switch (s) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgroundedAt ??= _clock().toUtc();
      case AppLifecycleState.resumed:
        final at = _backgroundedAt;
        if (at != null &&
            ProRenewalPolicy.isNewOpen(backgroundedAt: at, now: _clock())) {
          _openPending = true;
        }
        _backgroundedAt = null;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// Ghi nhận trạng thái quyền lợi (Pro còn hạn ⇒ nhớ thiết bị từng có Pro) rồi
  /// quyết định. Không ghi gì về "đã hiện" - gọi [markShown] khi thật sự hiện.
  Future<ProRenewalDecision?> check(EntitlementState state) async {
    final now = _clock();
    final e = state.entitlement;
    var seen = _int(await store.read(ProRenewalPolicy.seenProUntilKey));
    if (e != null && e.isProActive(now)) {
      final p = ProRenewalPolicy._seconds(e.proUntil!);
      if (seen == null || p > seen) {
        await store.write(ProRenewalPolicy.seenProUntilKey, '$p');
        seen = p;
      }
    }
    return ProRenewalPolicy.decide(
      state: state,
      now: now,
      openPending: _openPending,
      notifiedUntil: _int(await store.read(ProRenewalPolicy.notifiedUntilKey)),
      seenProUntil: seen,
    );
  }

  /// Nhắc ⇒ hết lượt cho lần mở này; hết kỳ ⇒ ghi
  /// `tsu.pro_expired.notified_until` = `pro_until` (giây Unix).
  Future<void> markShown(ProRenewalDecision d) async {
    switch (d.kind) {
      case ProRenewalKind.reminder:
        _openPending = false;
      case ProRenewalKind.expired:
        await store.write(
          ProRenewalPolicy.notifiedUntilKey,
          '${ProRenewalPolicy._seconds(d.proUntil)}',
        );
    }
  }

  static int? _int(String? raw) => raw == null ? null : int.tryParse(raw);
}

/// Người dùng đã bấm gì.
enum ProRenewalAction { renew, later, dismissed }

/// Hộp thoại nhắc gia hạn / báo hết kỳ. Đóng được, không chặn dùng app.
class ProRenewalDialog extends StatelessWidget {
  const ProRenewalDialog({
    super.key,
    required this.decision,
    this.locale,
    this.formatDate = formatProRenewalDate,
  });

  final ProRenewalDecision decision;
  final Locale? locale;

  /// Định dạng ngày (nhận giờ máy). Mặc định [formatProRenewalDate].
  final String Function(DateTime local, Locale locale) formatDate;

  @override
  Widget build(BuildContext context) {
    final s = ProRenewalStrings.of(decision.kind, context, locale);
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final date = switch (decision.kind) {
      ProRenewalKind.reminder => formatDate(decision.proUntil.toLocal(), l),
      ProRenewalKind.expired => null,
    };
    return AlertDialog(
      title: Text(s.title),
      scrollable: true,
      content: Text(s.body(days: decision.daysLeft, date: date)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ProRenewalAction.later),
          child: Text(s.secondary),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ProRenewalAction.renew),
          child: Text(s.primary),
        ),
      ],
    );
  }
}

/// Đang có ô nhập liệu giữ tiêu điểm ⇒ không chen hộp thoại (7.6).
bool _isEditingText() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null || !ctx.mounted) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Gọi khi mở app / quay lại app / sau khi làm mới quyền lợi.
///
/// Hiện nhắc gia hạn hoặc báo hết kỳ nếu [ProRenewalPolicy] cho phép, ghi nhận
/// ngay khi hiện, rồi chuyển "Gia hạn" cho app qua [onRenew] (app tự chọn: bản
/// Play/App Store ⇒ IAP gói `nam`; ngoài cửa hàng ⇒ `proWebUrl(clientId)`; bản
/// Play `MUST NOT` dẫn ra thanh toán web). Đang nhập liệu ⇒ không hiện và
/// KHÔNG tiêu lượt (gọi lại sau). Trả `null` nếu không hiện. Không bao giờ ném lỗi.
Future<ProRenewalAction?> maybeShowProRenewal(
  BuildContext context, {
  required ProRenewalController controller,
  required EntitlementState state,
  required VoidCallback onRenew,
  Locale? locale,
}) async {
  try {
    final d = await controller.check(state);
    if (d == null || !context.mounted || _isEditingText()) return null;
    await controller.markShown(d);
    if (!context.mounted) return null;
    final action =
        await showDialog<ProRenewalAction>(
          context: context,
          builder: (_) => ProRenewalDialog(decision: d, locale: locale),
        ) ??
        ProRenewalAction.dismissed;
    if (action == ProRenewalAction.renew) onRenew();
    return action;
  } on Object {
    return null;
  }
}
