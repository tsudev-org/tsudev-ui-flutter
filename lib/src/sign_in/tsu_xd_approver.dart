import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'tsu_xd_link.dart';

/// Vai XÁC NHẬN trong app (CROSS_DEVICE_LOGIN v1.1.0 mục 1, 4.1, 6.3, 7 - Đ2 Kéo; phiếu 20261124-QR1 QR2b).
///
/// App ĐÃ đăng nhập quét QR ở màn đăng nhập máy tính (`TsuXdLink.parse` ra [TsuXdFlow.pull]) rồi:
///   1. [TsuXdApprover.scan] ⇒ thông tin thiết bị mới cho màn Cho phép;
///   2. người dùng bấm Cho phép ⇒ app MỞ KHOÁ CỤC BỘ (sinh trắc/PIN - T8) ⇒ [TsuXdApprover.approve] ⇒ mã khớp;
///   3. người dùng gõ mã khớp trên máy tính.
///
/// Gọi `POST https://tsudev.com/api/xd/scan|approve|deny` bằng access token OIDC có scope `tsudev.xd` - client OIDC
/// của app phải được đăng ký scope này ở IdP. Bí mật QR chỉ gửi lúc `scan`, không lưu.
class TsuXdApprover {
  TsuXdApprover({
    required this.accessToken,
    http.Client? client,
    Uri? base,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       base = base ?? Uri.parse('https://tsudev.com');

  /// Access token OIDC còn hạn (scope `tsudev.xd`); `null` ⇒ chưa đăng nhập.
  final Future<String?> Function() accessToken;
  final Uri base;
  final Duration timeout;
  final http.Client _client;

  Future<TsuXdRequester> scan(TsuXdLink link) async {
    final b = await _post('scan', link, {'k': link.uri.fragment});
    final r = b['requester'];
    return TsuXdRequester(
      label: r is Map && r['label'] is String ? r['label'] as String : '',
      country: r is Map && r['country'] is String ? r['country'] as String : '',
    );
  }

  Future<TsuXdCode> approve(TsuXdLink link) async {
    final b = await _post('approve', link, const {});
    final code = b['code'];
    final ttl = b['expiresIn'];
    if (code is! String || code.isEmpty) {
      throw const TsuXdException('bad_response');
    }
    return TsuXdCode(code, Duration(seconds: ttl is num ? ttl.toInt() : 60));
  }

  Future<void> deny(TsuXdLink link) => _post('deny', link, const {});

  Future<Map<String, dynamic>> _post(
    String action,
    TsuXdLink link,
    Map<String, String> extra,
  ) async {
    if (link.flow != TsuXdFlow.pull) throw const TsuXdException('wrong_flow');
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      throw const TsuXdException('unauthenticated', 401);
    }
    final http.Response res;
    try {
      res = await _client
          .post(
            base.replace(path: '/api/xd/$action'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'id': link.uri.pathSegments[1], ...extra}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TsuXdException('network');
    } on http.ClientException {
      throw const TsuXdException('network');
    }
    Map<String, dynamic> body;
    try {
      final d = jsonDecode(res.body);
      body = d is Map<String, dynamic> ? d : <String, dynamic>{};
    } on FormatException {
      body = <String, dynamic>{};
    }
    if (res.statusCode != 200) {
      final e = body['error'];
      throw TsuXdException(
        e is String ? e : 'http_${res.statusCode}',
        res.statusCode,
      );
    }
    return body;
  }
}

class TsuXdRequester {
  const TsuXdRequester({required this.label, required this.country});

  /// Thiết bị + hệ điều hành + trình duyệt (IdP rút từ User-Agent).
  final String label;

  /// Mã quốc gia 2 chữ theo IP (`XX`/rỗng = không rõ).
  final String country;
}

class TsuXdCode {
  const TsuXdCode(this.code, this.ttl);

  /// `K7QF-M2XD`.
  final String code;
  final Duration ttl;
}

class TsuXdException implements Exception {
  const TsuXdException(this.code, [this.status = 0]);

  /// Mã IdP (`used_or_expired`, `country_mismatch`, `insufficient_scope`, `not_found`, `expired`, `conflict`...)
  /// hoặc `network` / `unauthenticated` / `wrong_flow` / `bad_response`.
  final String code;
  final int status;

  @override
  String toString() => 'TsuXdException($code, $status)';
}

/// Chữ của màn xác nhận - câu trong ngoặc kép là NGUYÊN VĂN CROSS_DEVICE_LOGIN 6.3/6.4.
class TsuXdStrings {
  const TsuXdStrings._({
    required this.title,
    required this.product,
    required this.device,
    required this.location,
    required this.time,
    required this.warning,
    required this.deny,
    required this.allow,
    required this.codeTitle,
    required this.codeHint,
    required this.codeExpired,
    required this.done,
    required this.denied,
    required this.used,
    required this.countryMismatch,
    required this.notTsudev,
    required this.scopeMissing,
    required this.unlockFailed,
    required this.network,
    required this.generic,
    required this.unknown,
  });

  static const vi = TsuXdStrings._(
    title: 'Đăng nhập trên thiết bị khác?',
    product: 'Sản phẩm',
    device: 'Thiết bị',
    location: 'Vị trí',
    time: 'Thời điểm',
    warning:
        'Chỉ cho phép nếu bạn đang cầm cả hai thiết bị. Nếu ai đó gửi mã QR này cho bạn qua tin nhắn, trang web hay '
        'điện thoại, hãy bấm Từ chối.',
    deny: 'Từ chối',
    allow: 'Cho phép',
    codeTitle: 'Mã khớp',
    codeHint: 'Nhập mã này trên thiết bị mới. tsudev không bao giờ hỏi mã này qua điện thoại, tin nhắn hay trang web khác.',
    codeExpired: 'Mã đã hết hạn. Quét lại mã QR trên thiết bị mới.',
    done: 'Xong',
    denied: 'Đã từ chối yêu cầu đăng nhập.',
    used: 'Mã QR này đã được dùng. Tạo mã mới trên thiết bị kia.',
    countryMismatch:
        'Không thể xác nhận: hai thiết bị đang ở hai quốc gia khác nhau.',
    notTsudev: 'Mã QR này không phải của tsudev.',
    scopeMissing: 'Ứng dụng này chưa được cấp quyền xác nhận đăng nhập. Hãy đăng nhập lại.',
    unlockFailed: 'Chưa mở khoá được. Chưa có gì được cho phép.',
    network: 'Không kết nối được tsudev.com. Thử lại.',
    generic: 'Không xác nhận được. Tạo mã mới trên thiết bị kia.',
    unknown: 'Không rõ',
  );

  static const en = TsuXdStrings._(
    title: 'Sign in on another device?',
    product: 'Product',
    device: 'Device',
    location: 'Location',
    time: 'Time',
    warning:
        'Only allow this if you are holding both devices. If someone sent you this QR code by message, website or '
        'phone call, tap Deny.',
    deny: 'Deny',
    allow: 'Allow',
    codeTitle: 'Matching code',
    codeHint: 'Enter this code on the new device. tsudev never asks for this code by phone, message or another website.',
    codeExpired:
        'The code has expired. Scan the QR code on the new device again.',
    done: 'Done',
    denied: 'Sign-in request denied.',
    used: 'This QR code has already been used. Create a new one on the other device.',
    countryMismatch:
        'Cannot confirm: the two devices are in different countries.',
    notTsudev: 'This QR code is not from tsudev.',
    scopeMissing: 'This app is not allowed to confirm sign-ins yet. Please sign in again.',
    unlockFailed: 'Not unlocked. Nothing was allowed.',
    network: 'Cannot reach tsudev.com. Try again.',
    generic: 'Could not confirm. Create a new code on the other device.',
    unknown: 'Unknown',
  );

  final String title;
  final String product;
  final String device;
  final String location;
  final String time;
  final String warning;
  final String deny;
  final String allow;
  final String codeTitle;
  final String codeHint;
  final String codeExpired;
  final String done;
  final String denied;
  final String used;
  final String countryMismatch;
  final String notTsudev;
  final String scopeMissing;
  final String unlockFailed;
  final String network;
  final String generic;
  final String unknown;

  static TsuXdStrings of(BuildContext context, [Locale? locale]) {
    final l =
        locale ??
        Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'vi' ? vi : en;
  }

  String error(TsuXdException e) => switch (e.code) {
    'used_or_expired' || 'expired' || 'not_found' || 'conflict' => used,
    'country_mismatch' => countryMismatch,
    'wrong_flow' => notTsudev,
    'insufficient_scope' ||
    'invalid_token' ||
    'unauthenticated' => scopeMissing,
    'network' => network,
    _ => generic,
  };
}

enum _Phase { loading, confirm, working, code, finished, error }

/// Màn Cho phép + màn hiện mã khớp (CROSS_DEVICE_LOGIN 6.3). App mở màn này sau khi bộ quét trả [TsuXdLink] kiểu
/// [TsuXdFlow.pull] (với [TsuXdFlow.push] app mở URL trong trình duyệt hệ thống như QR3).
///
/// [unlock] là BẮT BUỘC (T8): gọi khoá sinh trắc/PIN của app (vd. `local_auth` hay khoá ứng dụng sẵn có) và trả
/// `true` chỉ khi người dùng mở khoá thành công. Gói không tự kéo `local_auth` để không bắt mọi app đổi
/// `FlutterFragmentActivity`; app chưa có khoá cục bộ thì PHẢI thêm trước khi bật tính năng này.
class TsuXdApproveScreen extends StatefulWidget {
  const TsuXdApproveScreen({
    super.key,
    required this.link,
    required this.approver,
    required this.unlock,
    this.onClose,
    this.locale,
    this.clock,
  });

  final TsuXdLink link;
  final TsuXdApprover approver;
  final Future<bool> Function() unlock;

  /// Đóng màn (mặc định `Navigator.maybePop`).
  final VoidCallback? onClose;
  final Locale? locale;
  final DateTime Function()? clock;

  @override
  State<TsuXdApproveScreen> createState() => _TsuXdApproveScreenState();
}

class _TsuXdApproveScreenState extends State<TsuXdApproveScreen> {
  _Phase _phase = _Phase.loading;
  TsuXdRequester? _requester;
  TsuXdCode? _code;
  String? _message;
  DateTime? _scannedAt;
  DateTime? _codeUntil;
  Timer? _tick;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    if (widget.link.flow != TsuXdFlow.pull) {
      return _fail(const TsuXdException('wrong_flow'));
    }
    try {
      final r = await widget.approver.scan(widget.link);
      if (!mounted) return;
      setState(() {
        _requester = r;
        _scannedAt = _now();
        _phase = _Phase.confirm;
      });
    } on TsuXdException catch (e) {
      _fail(e);
    }
  }

  void _fail(TsuXdException e) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _message = TsuXdStrings.of(context, widget.locale).error(e);
    });
  }

  Future<void> _deny() async {
    setState(() => _phase = _Phase.working);
    try {
      await widget.approver.deny(widget.link);
    } on TsuXdException {
      // Từ chối là đích an toàn: lỗi mạng thì phiên vẫn tự chết sau 120 giây.
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.finished;
      _message = TsuXdStrings.of(context, widget.locale).denied;
    });
  }

  Future<void> _allow() async {
    final s = TsuXdStrings.of(context, widget.locale);
    setState(() => _phase = _Phase.working);
    bool ok;
    try {
      ok = await widget.unlock();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _phase = _Phase.confirm;
        _message = s.unlockFailed;
      });
      return;
    }
    try {
      final c = await widget.approver.approve(widget.link);
      if (!mounted) return;
      setState(() {
        _code = c;
        _codeUntil = _now().add(c.ttl);
        _message = null;
        _phase = _Phase.code;
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_remaining() == Duration.zero) _tick?.cancel();
      });
    } on TsuXdException catch (e) {
      _fail(e);
    }
  }

  Duration _remaining() {
    final u = _codeUntil;
    if (u == null) return Duration.zero;
    final d = u.difference(_now());
    return d.isNegative ? Duration.zero : d;
  }

  void _close() => widget.onClose != null
      ? widget.onClose!()
      : Navigator.of(context).maybePop();

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final s = TsuXdStrings.of(context, widget.locale);
    final theme = Theme.of(context);
    final body = switch (_phase) {
      _Phase.loading ||
      _Phase.working => const Center(child: CircularProgressIndicator()),
      _Phase.confirm => _confirm(context, s, theme),
      _Phase.code => _codeView(s, theme),
      _Phase.finished || _Phase.error => _endView(s, theme),
    };
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(24), child: body),
      ),
    );
  }

  Widget _row(String k, String v, ThemeData t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(v, style: t.textTheme.bodyLarge)),
      ],
    ),
  );

  Widget _confirm(BuildContext context, TsuXdStrings s, ThemeData t) {
    final r = _requester!;
    final at = _scannedAt!;
    final country = r.country.isEmpty || r.country == 'XX'
        ? s.unknown
        : r.country;
    return ListView(
      children: [
        _row(s.product, 'tsudev.com', t),
        _row(s.device, r.label.isEmpty ? s.unknown : r.label, t),
        _row(s.location, country, t),
        _row(
          s.time,
          '${_two(at.hour)}:${_two(at.minute)} ${_two(at.day)}/${_two(at.month)}/${at.year}',
          t,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            s.warning,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, style: TextStyle(color: t.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                key: const Key('tsu-xd-deny'),
                autofocus: true,
                onPressed: _deny,
                child: Text(s.deny),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                key: const Key('tsu-xd-allow'),
                onPressed: _allow,
                child: Text(s.allow),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _codeView(TsuXdStrings s, ThemeData t) {
    final left = _remaining();
    final expired = left == Duration.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.codeTitle,
          style: t.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SelectableText(
          expired ? '----' : _code!.code,
          key: const Key('tsu-xd-code'),
          textAlign: TextAlign.center,
          style: t.textTheme.displaySmall?.copyWith(
            fontFamily: 'monospace',
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          expired
              ? s.codeExpired
              : '${left.inMinutes}:${_two(left.inSeconds % 60)}',
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text(
          s.codeHint,
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton(onPressed: _close, child: Text(s.done)),
      ],
    );
  }

  Widget _endView(TsuXdStrings s, ThemeData t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _message ?? s.generic,
        style: t.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const Spacer(),
      FilledButton(onPressed: _close, child: Text(s.done)),
    ],
  );
}
