import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

import '../storage/key_value_store.dart';
import 'base64url.dart';

final _p256 = ECDomainParameters('secp256r1');

/// Khoá công khai P-256 đã kiểm nằm trên đường cong.
class Es256PublicKey {
  Es256PublicKey._(this.kid, this.key);

  final String kid;
  final ECPublicKey key;

  /// Đọc một JWK. Chỉ nhận `kty` = `EC`, `crv` = `P-256`, `alg` vắng hoặc
  /// `ES256`, `use` vắng hoặc `sig`. Trả `null` khi không hợp lệ.
  static Es256PublicKey? fromJwk(Map<String, Object?> jwk) {
    final kid = jwk['kid'];
    if (kid is! String || kid.isEmpty) return null;
    if (jwk['kty'] != 'EC' || jwk['crv'] != 'P-256') return null;
    final alg = jwk['alg'];
    if (alg != null && alg != 'ES256') return null;
    final use = jwk['use'];
    if (use != null && use != 'sig') return null;
    final x = _coord(jwk['x']);
    final y = _coord(jwk['y']);
    if (x == null || y == null) return null;
    if (!_onCurve(x, y)) return null;
    final q = _p256.curve.createPoint(x, y);
    return Es256PublicKey._(kid, ECPublicKey(q, _p256));
  }

  static BigInt? _coord(Object? raw) {
    if (raw is! String) return null;
    final bytes = tryDecodeBase64Url(raw);
    if (bytes == null || bytes.length != 32) return null;
    return bytesToBigInt(bytes);
  }

  /// y² = x³ + ax + b (mod p), 0 ≤ x, y < p - chặn khoá điểm lạ.
  static bool _onCurve(BigInt x, BigInt y) {
    if (x >= _p || y >= _p) return false;
    final lhs = (y * y) % _p;
    final rhs = (x * x * x + _a * x + _b) % _p;
    return lhs == rhs;
  }

  // Tham số secp256r1 (SEC 2 v2 mục 2.4.2).
  static final _p = BigInt.parse(
    'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
    radix: 16,
  );
  static final _a = _p - BigInt.from(3);
  static final _b = BigInt.parse(
    '5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b',
    radix: 16,
  );
}

/// Nguồn khoá cho bộ kiểm JWS.
abstract interface class JwksSource {
  /// Khoá theo `kid`; `null` nếu không có. [forceRefresh] khi gặp `kid` lạ.
  Future<Es256PublicKey?> keyFor(String kid, {bool forceRefresh = false});
}

/// Phân tích tài liệu JWKS (`{"keys": [...]}`), bỏ qua khoá không hợp lệ.
Map<String, Es256PublicKey> parseJwks(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map || decoded['keys'] is! List) {
    throw const FormatException('JWKS thiếu "keys"');
  }
  final out = <String, Es256PublicKey>{};
  for (final k in decoded['keys'] as List) {
    if (k is! Map) continue;
    final key = Es256PublicKey.fromJwk(k.cast<String, Object?>());
    if (key != null) out[key.kid] = key;
  }
  return out;
}

/// Bộ khoá cố định - cho test, hoặc app nhúng sẵn JWKS.
class StaticJwks implements JwksSource {
  StaticJwks(this._keys);

  factory StaticJwks.fromJson(String body) => StaticJwks(parseJwks(body));

  final Map<String, Es256PublicKey> _keys;

  @override
  Future<Es256PublicKey?> keyFor(
    String kid, {
    bool forceRefresh = false,
  }) async => _keys[kid];
}

/// JWKS của tsudev.com lấy qua discovery OIDC.
///
/// - Discovery `MUST` có `issuer` đúng [issuer]; `jwks_uri` `MUST` là https cùng
///   máy chủ với issuer (không theo khoá ở nơi khác).
/// - Đệm trong bộ nhớ [ttl]; `kid` lạ ⇒ tải lại, tối đa mỗi [minRefreshInterval].
/// - Có [store] ⇒ lưu JWKS tốt gần nhất (dữ liệu công khai) để kiểm JWS đệm
///   khi ngoại tuyến.
class DiscoveryJwks implements JwksSource {
  DiscoveryJwks({
    required this._client,
    this.issuer = defaultIssuer,
    this.store,
    this.ttl = const Duration(hours: 6),
    this.minRefreshInterval = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const defaultIssuer = 'https://tsudev.com/oidc';
  static const storageKey = 'tsu.entitlements.jwks';

  final http.Client _client;
  final String issuer;
  final TsuKeyValueStore? store;
  final Duration ttl;
  final Duration minRefreshInterval;
  final DateTime Function() _clock;

  Map<String, Es256PublicKey>? _keys;
  DateTime? _fetchedAt;
  DateTime? _lastAttempt;

  @override
  Future<Es256PublicKey?> keyFor(
    String kid, {
    bool forceRefresh = false,
  }) async {
    if (_keys == null) await _loadStored();
    final now = _clock();
    final stale = _fetchedAt == null || now.difference(_fetchedAt!) >= ttl;
    final missing = _keys?[kid] == null;
    if (stale || (forceRefresh && missing)) {
      final canTry =
          _lastAttempt == null ||
          now.difference(_lastAttempt!) >= minRefreshInterval;
      if (canTry) {
        _lastAttempt = now;
        try {
          await _fetch();
        } on Object {
          // Ngoại tuyến/máy chủ lỗi: dùng bộ khoá đang có (nếu có).
        }
      }
    }
    return _keys?[kid];
  }

  Future<void> _loadStored() async {
    final raw = await store?.read(storageKey);
    if (raw == null) return;
    try {
      _keys = parseJwks(raw);
    } on FormatException {
      await store?.delete(storageKey);
    }
  }

  Future<void> _fetch() async {
    final issuerUri = Uri.parse(issuer);
    final discoveryUri = Uri.parse('$issuer/.well-known/openid-configuration');
    final d = await _getJson(discoveryUri);
    if (d['issuer'] != issuer) {
      throw const FormatException('discovery: issuer không khớp');
    }
    final jwksRaw = d['jwks_uri'];
    final jwksUri = jwksRaw is String ? Uri.tryParse(jwksRaw) : null;
    if (jwksUri == null ||
        jwksUri.scheme != 'https' ||
        jwksUri.host != issuerUri.host) {
      throw const FormatException('discovery: jwks_uri không hợp lệ');
    }
    final res = await _client.get(jwksUri);
    if (res.statusCode != 200) {
      throw http.ClientException('JWKS HTTP ${res.statusCode}', jwksUri);
    }
    final body = utf8.decode(res.bodyBytes);
    final keys = parseJwks(body);
    if (keys.isEmpty) throw const FormatException('JWKS không có khoá ES256');
    _keys = keys;
    _fetchedAt = _clock();
    await store?.write(storageKey, body);
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', uri);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map) throw const FormatException('không phải JSON object');
    return decoded.cast<String, Object?>();
  }
}

/// Dùng chung cho bộ kiểm chữ ký.
BigInt bytesToBigInt(Uint8List bytes) {
  var r = BigInt.zero;
  for (final b in bytes) {
    r = (r << 8) | BigInt.from(b);
  }
  return r;
}
