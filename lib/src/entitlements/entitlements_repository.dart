import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_id.dart';
import '../storage/key_value_store.dart';
import 'entitlement.dart';
import 'entitlement_verifier.dart';

/// Nơi trạng thái quyền lợi đến từ đâu.
enum EntitlementSource {
  /// Vừa lấy từ máy chủ và kiểm xong.
  network,

  /// JWS đệm cục bộ, đã kiểm lại và còn hạn.
  cache,

  /// Không có JWS hợp lệ còn hạn ⇒ miễn phí.
  none,
}

/// Trạng thái quyền lợi mà giao diện dùng. Không có [entitlement] ⇒ miễn phí.
class EntitlementState {
  const EntitlementState._(this.entitlement, this.source);

  const EntitlementState.free() : this._(null, EntitlementSource.none);

  final Entitlement? entitlement;
  final EntitlementSource source;

  bool isPro(DateTime now) => entitlement?.isProActive(now) ?? false;
  TsuBadgeKind get badge => entitlement?.badge ?? TsuBadgeKind.none;
  int get devices30d => entitlement?.devices30d ?? 0;
}

/// Lấy, kiểm, đệm JWS quyền lợi (PRODUCT_POLICY 7.4).
///
/// - JWS đệm dưới khoá [cacheKey]; mỗi lần đọc đều KIỂM LẠI đủ chữ ký + `exp`
///   (không tin bản đã lưu). Đệm sống tối đa tới `exp` (≤ 7 ngày sau `iat`).
/// - Lấy mới lỗi (ngoại tuyến, 5xx, JWS hỏng) ⇒ rơi về bản đệm còn hạn; hết
///   hạn ⇒ miễn phí. Không bao giờ ném lỗi ra giao diện.
/// - Đây chỉ là cổng ẩn/hiện ở app; máy chủ đồng bộ tự kiểm Pro (nguyên tắc N4).
class EntitlementsRepository {
  EntitlementsRepository({
    required this.verifier,
    required this.store,
    required this.fetchJws,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const cacheKey = 'tsu.entitlements.jws';

  final EntitlementVerifier verifier;
  final TsuKeyValueStore store;

  /// Trả JWS compact mới từ máy chủ (ví dụ [TsudevEntitlementsApi.fetch]).
  final Future<String> Function() fetchJws;
  final DateTime Function() _clock;

  /// Đọc bản đệm; không có hoặc không hợp lệ/hết hạn ⇒ [EntitlementState.free].
  Future<EntitlementState> current() async {
    final cached = await store.read(cacheKey);
    if (cached == null) return const EntitlementState.free();
    try {
      final e = await verifier.verify(cached, now: _clock());
      return EntitlementState._(e, EntitlementSource.cache);
    } on EntitlementException catch (err) {
      // Hết hạn thì giữ bản đệm (vô hại) - chỉ xoá bản hỏng/giả.
      if (err.error != EntitlementError.expired) await store.delete(cacheKey);
      return const EntitlementState.free();
    }
  }

  /// Lấy mới; lỗi ⇒ [current].
  Future<EntitlementState> refresh() async {
    try {
      final jws = await fetchJws();
      final e = await verifier.verify(jws, now: _clock());
      await store.write(cacheKey, jws);
      return EntitlementState._(e, EntitlementSource.network);
    } on Object {
      return current();
    }
  }

  /// Đăng xuất: bỏ JWS đệm.
  Future<void> clear() => store.delete(cacheKey);
}

/// Lỗi HTTP khi lấy quyền lợi.
class EntitlementsHttpException implements Exception {
  const EntitlementsHttpException(this.statusCode, this.code);

  final int statusCode;

  /// Mã lỗi máy đọc được nếu có (ví dụ `insufficient_scope`).
  final String? code;

  @override
  String toString() => 'EntitlementsHttpException($statusCode, $code)';
}

/// Gọi `GET https://tsudev.com/api/me/entitlements` bằng access token có scope
/// `tsudev.entitlements`, kèm header mã cài đặt (chỉ gọi khi đã đăng nhập).
class TsudevEntitlementsApi {
  TsudevEntitlementsApi({
    required this._client,
    required this.accessToken,
    required this.installationId,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
  }) : endpoint = endpoint ?? defaultEndpoint {
    if (this.endpoint.scheme != 'https') {
      throw ArgumentError.value(endpoint, 'endpoint', 'phải là https');
    }
  }

  static final defaultEndpoint = Uri.parse(
    'https://tsudev.com/api/me/entitlements',
  );

  final http.Client _client;
  final Uri endpoint;
  final Duration timeout;

  /// Access token hiện tại (lấy từ kho bí mật của hệ điều hành).
  final Future<String> Function() accessToken;

  /// Thường là `() => InstallationId.getOrCreate(store)`.
  final Future<String> Function() installationId;

  Future<String> fetch() async {
    final token = await accessToken();
    final inst = await installationId();
    final res = await _client
        .get(
          endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            if (InstallationId.isValid(inst)) InstallationId.headerName: inst,
          },
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw EntitlementsHttpException(res.statusCode, _errorCode(res));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final jws = body is Map ? body['jws'] : null;
    if (jws is! String) throw const FormatException('thiếu "jws"');
    return jws;
  }

  static String? _errorCode(http.Response res) {
    try {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      final code = b is Map ? (b['error'] ?? b['code']) : null;
      return code is String ? code : null;
    } on FormatException {
      return null;
    }
  }
}
