import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../installation/installation_id.dart';
import '../storage/key_value_store.dart';
import 'dpop.dart';
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
    this.dpop,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const cacheKey = 'tsu.entitlements.jws';

  /// JWS gửi thẳng lên máy chủ đồng bộ cũ hơn mức này ⇒ lấy mới trước khi gửi
  /// (máy chủ chỉ nhận `iat` ≤ [serverMaxAge], PRODUCT_POLICY 7.4).
  static const serverRefreshAge = Duration(hours: 23);
  static const serverMaxAge = Duration(hours: 24);

  /// Khoá DPoP của cài đặt này - cần khi JWS có `cnf.jkt` ([serverAuthHeaders]).
  final DpopSigner? dpop;

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
      final (_, e) = await _fetchVerified();
      return EntitlementState._(e, EntitlementSource.network);
    } on Object {
      return current();
    }
  }

  /// JWS để gửi thẳng lên máy chủ đồng bộ (TsuDEV Sync / máy chủ sản phẩm nhận
  /// JWS làm thẻ, PRODUCT_POLICY 7.4).
  ///
  /// - Bản đệm hợp lệ có `iat` ≤ [serverRefreshAge] ⇒ dùng luôn; cũ hơn, hoặc
  ///   [forceRefresh] (máy chủ vừa trả `401 reason: "stale"`) ⇒ lấy mới.
  /// - Lấy mới lỗi ⇒ rơi về bản đệm nếu còn `iat` < [serverMaxAge] (trừ khi
  ///   [forceRefresh]); không còn gì dùng được ⇒ `null` (app hoãn đồng bộ).
  ///   Không bao giờ ném lỗi.
  Future<String?> jwsForServer({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final c = await _cachedForServer(serverRefreshAge);
      if (c != null) return c;
    }
    try {
      final (jws, _) = await _fetchVerified();
      return jws;
    } on Object {
      return forceRefresh ? null : _cachedForServer(serverMaxAge, strict: true);
    }
  }

  /// Gửi một yêu cầu lên máy chủ đồng bộ với JWS từ [jwsForServer]; máy chủ trả
  /// `401 {"error":"invalid_token","reason":"stale"}` ⇒ lấy JWS mới rồi thử lại
  /// ĐÚNG MỘT lần. `null` ⇒ không có JWS dùng được (ngoại tuyến quá lâu, chưa
  /// đăng nhập). Lỗi mạng của [send] được ném nguyên cho app.
  Future<http.Response?> sendWithServerJws(
    Future<http.Response> Function(String jws) send,
  ) async {
    final jws = await jwsForServer();
    if (jws == null) return null;
    final res = await send(jws);
    if (!isStaleJwsResponse(res)) return res;
    final fresh = await jwsForServer(forceRefresh: true);
    if (fresh == null || fresh == jws) return res;
    return send(fresh);
  }

  /// Header xác thực cho [jws] khi gọi máy chủ đồng bộ: JWS có `cnf.jkt` ⇒
  /// `Authorization: DPoP` + bằng chứng `DPoP` (cần [dpop]); không có ⇒
  /// `Authorization: Bearer`.
  Future<Map<String, String>> serverAuthHeaders(
    String jws,
    String method,
    Uri url, {
    String? nonce,
  }) async {
    if (_confirmationJkt(jws) == null) return {'Authorization': 'Bearer $jws'};
    final signer = dpop;
    if (signer == null) {
      throw StateError('JWS có cnf.jkt nhưng repository chưa có DpopSigner');
    }
    return signer.boundHeaders(method, url, jws, nonce: nonce);
  }

  /// `401` với `reason` = `stale` (PRODUCT_POLICY 7.4).
  static bool isStaleJwsResponse(http.Response res) {
    if (res.statusCode != 401) return false;
    try {
      final b = jsonDecode(utf8.decode(res.bodyBytes));
      return b is Map && b['reason'] == 'stale';
    } on FormatException {
      return false;
    }
  }

  Future<(String, Entitlement)>? _inflight;

  /// Lấy mới + kiểm + đệm; các lời gọi đồng thời dùng chung một yêu cầu mạng.
  Future<(String, Entitlement)> _fetchVerified() {
    final pending = _inflight;
    if (pending != null) return pending;
    final f = _fetchOnce();
    _inflight = f;
    // whenComplete luôn chạy bất đồng bộ ⇒ phép gán ở trên đã xong.
    f.whenComplete(() {
      if (identical(_inflight, f)) _inflight = null;
    }).ignore();
    return f;
  }

  Future<(String, Entitlement)> _fetchOnce() async {
    final jws = await fetchJws();
    final e = await verifier.verify(jws, now: _clock());
    await store.write(cacheKey, jws);
    return (jws, e);
  }

  Future<String?> _cachedForServer(
    Duration maxAge, {
    bool strict = false,
  }) async {
    final cached = await store.read(cacheKey);
    if (cached == null) return null;
    try {
      final now = _clock();
      final e = await verifier.verify(cached, now: now);
      final age = now.toUtc().difference(e.issuedAt);
      final ok = strict ? age < maxAge : age <= maxAge;
      return ok ? cached : null;
    } on EntitlementException {
      return null;
    }
  }

  static String? _confirmationJkt(String jws) {
    final parts = jws.split('.');
    if (parts.length != 3) return null;
    try {
      final c = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final jkt = c is Map ? c['cnf'] : null;
      final v = jkt is Map ? jkt['jkt'] : null;
      return v is String ? v : null;
    } on FormatException {
      return null;
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
    this.dpop,
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

  /// Có ⇒ gửi kèm bằng chứng `DPoP` (PRODUCT_POLICY 7.4, `SHOULD`) để tsudev.com
  /// gắn `cnf.jkt` của khoá cài đặt này vào JWS. Access token vẫn gửi dạng
  /// `Bearer`; bằng chứng có `ath` = băm của access token.
  final DpopSigner? dpop;

  Future<String> fetch() async {
    final token = await accessToken();
    final inst = await installationId();
    Future<http.Response> send(String? nonce) async => _client
        .get(
          endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            if (InstallationId.isValid(inst)) InstallationId.headerName: inst,
            if (dpop != null)
              'DPoP': await dpop!.proof(
                'GET',
                endpoint,
                accessToken: token,
                nonce: nonce,
              ),
          },
        )
        .timeout(timeout);
    var res = await send(null);
    // RFC 9449 mục 8: máy chủ đòi nonce ⇒ thử lại đúng một lần với nonce đó.
    final nonce = res.headers['dpop-nonce'];
    if (dpop != null &&
        nonce != null &&
        (res.statusCode == 400 || res.statusCode == 401) &&
        _errorCode(res) == 'use_dpop_nonce') {
      res = await send(nonce);
    }
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
