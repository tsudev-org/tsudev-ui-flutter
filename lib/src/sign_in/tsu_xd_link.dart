/// Mã QR đăng nhập chéo thiết bị của tsudev (CROSS_DEVICE_LOGIN v1.1.0, mục 3 T9 + mục 7).
///
/// Bộ quét trong app CHỈ nhận đúng dạng `https://tsudev.com/x/<id 22 ký tự>?f=k|d#<bí mật 43 ký tự>`; mọi thứ khác
/// (tên miền giả `tsudev.com.evil.io`, http, đường dẫn lạ) bị từ chối và KHÔNG được mở. Mã hợp lệ thì app mở chính
/// URL đó trong trình duyệt hệ thống (Custom Tab / ASWebAuthenticationSession) - trang `/x/<id>` làm phần còn lại.
enum TsuXdFlow {
  /// Đ2 kéo: máy mới hiện QR, máy đã đăng nhập (app này) quét để Cho phép.
  pull,

  /// Đ1 đẩy: máy đã đăng nhập hiện QR, máy mới (app này, chưa đăng nhập) quét để đăng nhập.
  push,
}

class TsuXdLink {
  const TsuXdLink._(this.uri, this.flow);

  final Uri uri;
  final TsuXdFlow flow;

  static const host = 'tsudev.com';
  static final _id = RegExp(r'^[A-Za-z0-9_-]{22}$');
  static final _secret = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// `null` khi không phải mã QR đăng nhập của tsudev.
  static TsuXdLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != host ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final seg = uri.pathSegments;
    if (seg.length != 2 || seg[0] != 'x' || !_id.hasMatch(seg[1])) return null;
    if (!_secret.hasMatch(uri.fragment)) return null;
    final f = uri.queryParameters['f'];
    if (uri.queryParameters.length != 1) return null;
    final flow = switch (f) {
      'k' => TsuXdFlow.pull,
      'd' => TsuXdFlow.push,
      _ => null,
    };
    return flow == null ? null : TsuXdLink._(uri, flow);
  }
}
