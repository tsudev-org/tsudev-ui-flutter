import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sign_in/tsu_sign_in_screen.dart' show TsuSignInOption;
import '../storage/key_value_store.dart';

/// Nhắc đăng nhập khi có internet - tsudev-standards v7.1.0 `AUTH_AND_ACCOUNT.md` mục 14.4 (phiếu `20261126-LG3`).
///
/// Nhắc, KHÔNG ép: modal luôn đóng được, không chặn chức năng lõi. Gói không kéo plugin mạng: app tự đọc tín hiệu
/// "có internet" của hệ điều hành (R2 - ví dụ `connectivity_plus` + `NET_CAPABILITY_VALIDATED`) và truyền vào
/// [SignInReminderConditions]; `MUST NOT` gửi gói thăm dò để biết có mạng.

/// Các điều kiện R1-R6 (mục 14.4.1) tại thời điểm app định hiện nhắc.
@immutable
class SignInReminderConditions {
  const SignInReminderConditions({
    required this.signedIn,
    required this.online,
    required this.fullyOfflineMode,
    required this.atNaturalBreak,
    required this.appReadyAt,
    this.coreTaskCompleted = false,
    this.otherModalOpen = false,
  });

  /// R1: đã đăng nhập (phiên còn hiệu lực, kể cả ngoại tuyến ≤ 7 ngày) ⇒ không bao giờ nhắc.
  final bool signedIn;

  /// R2: hệ điều hành báo có internet (đã kiểm chứng). Không rõ ⇒ truyền `false`.
  final bool online;

  /// R3: Chế độ ngoại tuyến hoàn toàn đang bật.
  final bool fullyOfflineMode;

  /// R4: không đang quét/ghi/nhập liệu dở/đồng bộ Tsu Link/toàn màn hình/ván chơi.
  final bool atNaturalBreak;

  /// R5: thời điểm app sẵn sàng dùng trong lần chạy này.
  final DateTime appReadyAt;

  /// R5: tác vụ lõi đầu tiên đã xong (cho phép nhắc trước mốc 30 giây).
  final bool coreTaskCompleted;

  /// R6: modal khác đang mở (modal khoá cập nhật / "không chính thức" luôn ưu tiên).
  final bool otherModalOpen;
}

/// Kết quả người dùng chọn trên modal.
enum SignInReminderResult {
  /// Bấm một lối vào - luồng đăng nhập (trình duyệt hệ thống + PKCE) đã được gọi.
  signInStarted,

  /// "Để sau", nút X, Esc, Back, chạm ra ngoài.
  notNow,

  /// "Không nhắc trong 30 ngày".
  snoozed,
}

/// Nhịp nhắc (mục 14.4.2) - lưu CỤC BỘ, không gửi đi đâu.
///
/// Mỗi phiên chạy app tạo MỘT đối tượng (giới hạn "một lần mỗi phiên" nằm trong bộ nhớ).
class SignInReminderPolicy {
  SignInReminderPolicy({required this.store, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// R5: chờ tối thiểu sau khi app sẵn sàng.
  static const minReadyDelay = Duration(seconds: 30);

  /// Khoảng cách sau lần "Để sau" thứ 1, 2, ≥ 3.
  static const intervals = [
    Duration(hours: 24),
    Duration(days: 3),
    Duration(days: 7),
  ];

  /// "Không nhắc trong 30 ngày".
  static const snooze = Duration(days: 30);

  /// Sau khi người dùng chủ động đăng xuất.
  static const afterSignOut = Duration(hours: 24);

  /// Khoá lưu (cùng chỗ cài đặt app; xoá bởi "Đăng xuất và xóa dữ liệu cục bộ" qua [reset]).
  static const keyNextAt = 'tsu.signin_reminder.next_at';
  static const keyDismissCount = 'tsu.signin_reminder.dismiss_count';

  /// Kho cài đặt cục bộ của app.
  final TsuKeyValueStore store;
  final DateTime Function() _clock;
  bool _shownThisSession = false;

  /// Đã hiện trong phiên chạy này chưa.
  bool get shownThisSession => _shownThisSession;

  Future<DateTime?> _nextAt() async {
    final v = await store.read(keyNextAt);
    return v == null ? null : DateTime.tryParse(v)?.toUtc();
  }

  Future<int> _dismissCount() async =>
      int.tryParse(await store.read(keyDismissCount) ?? '') ?? 0;

  Future<void> _setNextAt(DateTime t) =>
      store.write(keyNextAt, t.toUtc().toIso8601String());

  /// `true` nếu đủ R1-R6 và đúng nhịp.
  Future<bool> shouldShow(SignInReminderConditions c) async {
    if (c.signedIn ||
        !c.online ||
        c.fullyOfflineMode ||
        !c.atNaturalBreak ||
        c.otherModalOpen) {
      return false;
    }
    if (_shownThisSession) return false;
    final now = _clock().toUtc();
    if (!c.coreTaskCompleted &&
        now.difference(c.appReadyAt.toUtc()) < minReadyDelay) {
      return false;
    }
    final next = await _nextAt();
    return next == null || !now.isBefore(next);
  }

  /// Ghi nhận kết quả của lần hiện modal.
  Future<void> record(SignInReminderResult result) async {
    _shownThisSession = true;
    final now = _clock().toUtc();
    switch (result) {
      case SignInReminderResult.notNow:
        final n = await _dismissCount() + 1;
        await store.write(keyDismissCount, '$n');
        await _setNextAt(
          now.add(intervals[(n - 1).clamp(0, intervals.length - 1)]),
        );
      case SignInReminderResult.snoozed:
        final n = await _dismissCount();
        if (n < intervals.length) {
          await store.write(keyDismissCount, '${intervals.length}');
        }
        await _setNextAt(now.add(snooze));
      case SignInReminderResult.signInStarted:
        // Bỏ dở giữa chừng ⇒ không nhắc lại trước 24 giờ.
        await _setNextAt(now.add(intervals.first));
    }
  }

  /// Đăng nhập thành công ⇒ xoá nhịp.
  Future<void> recordSignedIn() => reset();

  /// Người dùng chủ động đăng xuất ⇒ không nhắc trong 24 giờ.
  Future<void> recordSignOut() async {
    final now = _clock().toUtc();
    final next = await _nextAt();
    final candidate = now.add(afterSignOut);
    if (next == null || next.isBefore(candidate)) await _setNextAt(candidate);
  }

  /// Xoá trạng thái nhịp ("Đăng xuất và xóa dữ liệu cục bộ").
  Future<void> reset() async {
    await store.delete(keyNextAt);
    await store.delete(keyDismissCount);
  }
}

/// Nội dung NGUYÊN VĂN mục 14.4.3 - KHÔNG sửa chữ ở đây; đổi ở bộ quy ước trước rồi đồng bộ lại.
class SignInReminderStrings {
  const SignInReminderStrings._({
    required this.title,
    required this.body,
    required this.notNow,
    required this.snooze30,
    required this.why,
    required this.identityPrefix,
    required this.close,
    required this.scanToSignIn,
  });

  static const vi = SignInReminderStrings._(
    title: 'Đăng nhập để được hỗ trợ tốt hơn',
    body:
        'Đăng nhập tài khoản TsuDEV, hoặc bằng Google, GitHub, Apple, giúp bạn khôi phục tài khoản và quyền lợi khi '
        'đổi máy, gửi báo cáo sự cố kèm tài khoản để được hỗ trợ nhanh hơn. Dữ liệu của bạn vẫn chỉ nằm trên thiết bị '
        'này - đăng nhập không tải dữ liệu lên mạng.',
    notNow: 'Để sau',
    snooze30: 'Không nhắc trong 30 ngày',
    why: 'Vì sao nên đăng nhập?',
    identityPrefix: 'Bạn sẽ đăng nhập tại ',
    close: 'Đóng',
    scanToSignIn: 'Quét mã QR',
  );

  static const en = SignInReminderStrings._(
    title: 'Sign in for better support',
    body:
        'Sign in with your TsuDEV account, or with Google, GitHub or Apple, to restore your account and benefits on a '
        'new device and to send problem reports linked to your account for faster help. Your data stays on this '
        'device - signing in does not upload it.',
    notNow: 'Not now',
    snooze30: "Don't remind me for 30 days",
    why: 'Why sign in?',
    identityPrefix: 'You will sign in at ',
    close: 'Close',
    scanToSignIn: 'Scan QR code',
  );

  /// Tên miền nhận diện (chống trang giả mạo).
  static const domain = 'tsudev.com';

  /// Trang giải thích (mở bằng trình duyệt hệ thống).
  static final whyUrl = Uri.parse('https://tsudev.com/privacy#dang-nhap');

  final String title;
  final String body;
  final String notNow;
  final String snooze30;
  final String why;
  final String identityPrefix;
  final String close;
  final String scanToSignIn;

  static SignInReminderStrings of(BuildContext context, [Locale? locale]) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi' ? vi : en;
  }
}

/// Modal nổi nhắc đăng nhập (mục 14.4.3). Không có ô nhập mật khẩu: mỗi lối vào gọi `onPressed` của app, nơi app
/// mở luồng mục 4 (trình duyệt hệ thống + PKCE).
class TsuSignInReminder extends StatelessWidget {
  const TsuSignInReminder({
    super.key,
    required this.options,
    required this.onOpenWhy,
    this.onScanToSignIn,
    this.locale,
  });

  /// Lối vào THẬT đang bật ở IdP theo thứ tự mục 3 (Google, GitHub, Apple khi áp dụng, Email TsuDEV).
  final List<TsuSignInOption> options;

  /// Mở [SignInReminderStrings.whyUrl] bằng trình duyệt hệ thống.
  final VoidCallback onOpenWhy;

  /// "Quét mã QR" (CROSS_DEVICE_LOGIN.md) - null ⇒ ẩn.
  final VoidCallback? onScanToSignIn;

  final Locale? locale;

  /// Hiện modal; đóng bằng X/Esc/Back/chạm ngoài ⇒ [SignInReminderResult.notNow].
  static Future<SignInReminderResult> show(
    BuildContext context, {
    required List<TsuSignInOption> options,
    required VoidCallback onOpenWhy,
    VoidCallback? onScanToSignIn,
    Locale? locale,
  }) async {
    final r = await showDialog<SignInReminderResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: SignInReminderStrings.of(context, locale).close,
      builder: (_) => TsuSignInReminder(
        options: options,
        onOpenWhy: onOpenWhy,
        onScanToSignIn: onScanToSignIn,
        locale: locale,
      ),
    );
    return r ?? SignInReminderResult.notNow;
  }

  /// Kiểm R1-R6 + nhịp, hiện modal nếu đủ, ghi nhận kết quả. Trả `null` nếu không hiện.
  static Future<SignInReminderResult?> maybeShow(
    BuildContext context, {
    required SignInReminderPolicy policy,
    required SignInReminderConditions conditions,
    required List<TsuSignInOption> options,
    required VoidCallback onOpenWhy,
    VoidCallback? onScanToSignIn,
    Locale? locale,
  }) async {
    if (!await policy.shouldShow(conditions) || !context.mounted) return null;
    final r = await show(
      context,
      options: options,
      onOpenWhy: onOpenWhy,
      onScanToSignIn: onScanToSignIn,
      locale: locale,
    );
    await policy.record(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final s = SignInReminderStrings.of(context, locale);
    final theme = Theme.of(context);
    void pop(SignInReminderResult r) => Navigator.of(context).pop(r);

    Widget option(TsuSignInOption o, {required bool first}) {
      final child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          o.icon,
          const SizedBox(width: 8),
          Flexible(child: Text(o.label)),
        ],
      );
      void onPressed() {
        pop(SignInReminderResult.signInStarted);
        o.onPressed();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: first
            ? FilledButton(autofocus: true, onPressed: onPressed, child: child)
            : OutlinedButton(onPressed: onPressed, child: child),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            pop(SignInReminderResult.notNow),
      },
      child: AlertDialog(
        semanticLabel: s.title,
        title: Row(
          children: [
            Expanded(child: Text(s.title)),
            IconButton(
              tooltip: s.close,
              icon: const Icon(Icons.close),
              onPressed: () => pop(SignInReminderResult.notNow),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.body),
                const SizedBox(height: 16),
                for (var i = 0; i < options.length; i++)
                  option(options[i], first: i == 0),
                if (onScanToSignIn != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(s.scanToSignIn),
                      onPressed: () {
                        pop(SignInReminderResult.signInStarted);
                        onScanToSignIn!();
                      },
                    ),
                  ),
                Text.rich(
                  TextSpan(
                    text: s.identityPrefix,
                    children: [
                      TextSpan(
                        text: SignInReminderStrings.domain,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => pop(SignInReminderResult.snoozed),
                      child: Text(s.snooze30),
                    ),
                    TextButton(onPressed: onOpenWhy, child: Text(s.why)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => pop(SignInReminderResult.notNow),
            child: Text(s.notNow),
          ),
        ],
      ),
    );
  }
}
