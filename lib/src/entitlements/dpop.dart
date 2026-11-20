import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../storage/key_value_store.dart';

final _p256 = ECDomainParameters('secp256r1');

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _sha256(List<int> bytes) =>
    SHA256Digest().process(Uint8List.fromList(bytes));

Uint8List _fixed32(BigInt v) {
  final out = Uint8List(32);
  var x = v;
  for (var i = 31; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x >>= 8;
  }
  return out;
}

/// Khoá P-256 của MỘT cài đặt, dùng ký bằng chứng DPoP (RFC 9449).
///
/// Bản thật nên nằm trong kho khoá an toàn của nền tảng (Android Keystore /
/// StrongBox, Secure Enclave, TPM/CNG) và KHÔNG BAO GIỜ xuất khoá riêng: app
/// tự cài giao diện này bằng plugin nền tảng của mình (gói không kéo plugin
/// nào). [SoftwareDpopKey] là phương án dự phòng khi nền tảng không có kho khoá.
abstract interface class DpopKey {
  /// JWK công khai: đúng 4 thành viên `kty`, `crv`, `x`, `y` (không có `d`).
  Future<Map<String, String>> publicJwk();

  /// Ký ES256 [signingInput]; trả chữ ký thô `r || s` 64 byte (RFC 7518 3.4).
  Future<Uint8List> sign(Uint8List signingInput);
}

/// Khoá DPoP phần mềm (pointycastle, ký tất định RFC 6979).
///
/// Khoá riêng lưu dưới [storageKey] trong [TsuKeyValueStore] mà app truyền vào -
/// `MUST` là kho bí mật của hệ điều hành (ví dụ `flutter_secure_storage`), không
/// phải kho cài đặt thường. Dùng khi nền tảng không có kho khoá phần cứng.
class SoftwareDpopKey implements DpopKey {
  SoftwareDpopKey._(this._d) : _q = (_p256.G * _d)!;

  static const storageKey = 'tsu.dpop.key';

  final BigInt _d;
  final ECPoint _q;

  /// Tạo từ khoá riêng (hex 64 ký tự). Chỉ dùng cho test/khôi phục.
  factory SoftwareDpopKey.fromPrivateHex(String hex) {
    final d = BigInt.tryParse(hex, radix: 16);
    if (hex.length != 64 || d == null || d <= BigInt.zero || d >= _p256.n) {
      throw ArgumentError.value('***', 'hex', 'khoá P-256 không hợp lệ');
    }
    return SoftwareDpopKey._(d);
  }

  /// Sinh khoá mới bằng nguồn ngẫu nhiên an toàn của hệ điều hành.
  factory SoftwareDpopKey.generate([Random? random]) {
    final rnd = random ?? Random.secure();
    while (true) {
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      final d = bytes.fold(BigInt.zero, (a, b) => (a << 8) | BigInt.from(b));
      if (d > BigInt.zero && d < _p256.n) return SoftwareDpopKey._(d);
    }
  }

  /// Đọc khoá của cài đặt này; chưa có (hoặc hỏng) ⇒ sinh mới và lưu.
  static Future<SoftwareDpopKey> getOrCreate(
    TsuKeyValueStore secureStore,
  ) async {
    final raw = await secureStore.read(storageKey);
    if (raw != null) {
      try {
        return SoftwareDpopKey.fromPrivateHex(raw);
      } on ArgumentError {
        // Hỏng ⇒ thay khoá mới (máy chủ chỉ thấy một khoá thiết bị mới).
      }
    }
    final k = SoftwareDpopKey.generate();
    await secureStore.write(
      storageKey,
      k._d.toRadixString(16).padLeft(64, '0'),
    );
    return k;
  }

  @override
  Future<Map<String, String>> publicJwk() async => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': _b64(_fixed32(_q.x!.toBigInteger()!)),
    'y': _b64(_fixed32(_q.y!.toBigInteger()!)),
  };

  @override
  Future<Uint8List> sign(Uint8List signingInput) async {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(_d, _p256)));
    final sig = signer.generateSignature(signingInput) as ECSignature;
    // Chuẩn hoá low-S không bắt buộc với ES256; giữ nguyên r, s.
    return Uint8List.fromList([..._fixed32(sig.r), ..._fixed32(sig.s)]);
  }
}

/// Ký bằng chứng DPoP (RFC 9449 mục 4) cho mỗi yêu cầu HTTP.
///
/// - Header: `typ` = `dpop+jwt`, `alg` = `ES256`, `jwk` = khoá công khai.
/// - Payload: `jti` (128 bit ngẫu nhiên, dùng một lần), `htm`, `htu` (bỏ query
///   và fragment), `iat`, `ath` = base64url(SHA-256(access token)) khi có token,
///   `nonce` khi máy chủ yêu cầu (`DPoP-Nonce`).
class DpopSigner {
  DpopSigner(this.key, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  final DpopKey key;
  final DateTime Function() _clock;
  final Random _random;

  /// Thumbprint RFC 7638 của khoá công khai - giá trị `cnf.jkt` trong JWS.
  Future<String> thumbprint() async => jwkThumbprint(await key.publicJwk());

  /// Bằng chứng DPoP compact cho [method] + [url].
  Future<String> proof(
    String method,
    Uri url, {
    String? accessToken,
    String? nonce,
  }) async {
    final header = {
      'typ': 'dpop+jwt',
      'alg': 'ES256',
      'jwk': await key.publicJwk(),
    };
    final payload = {
      'jti': _b64(List<int>.generate(16, (_) => _random.nextInt(256))),
      'htm': method.toUpperCase(),
      'htu': htu(url),
      'iat': _clock().toUtc().millisecondsSinceEpoch ~/ 1000,
      if (accessToken != null) 'ath': accessTokenHash(accessToken),
      'nonce': ?nonce,
    };
    final input =
        '${_b64(utf8.encode(jsonEncode(header)))}.'
        '${_b64(utf8.encode(jsonEncode(payload)))}';
    final sig = await key.sign(Uint8List.fromList(ascii.encode(input)));
    if (sig.length != 64) throw StateError('chữ ký ES256 phải 64 byte');
    return '$input.${_b64(sig)}';
  }

  /// Header cho yêu cầu mang thẻ gắn khoá: `Authorization: DPoP <token>` +
  /// `DPoP: <bằng chứng>` (RFC 9449 mục 7.1). Dùng khi gửi JWS có `cnf.jkt`
  /// lên máy chủ đồng bộ.
  Future<Map<String, String>> boundHeaders(
    String method,
    Uri url,
    String token, {
    String? nonce,
  }) async => {
    'Authorization': 'DPoP $token',
    'DPoP': await proof(method, url, accessToken: token, nonce: nonce),
  };

  /// `htu` = URI không có query và fragment (RFC 9449 mục 4.2).
  static String htu(Uri url) => Uri(
    scheme: url.scheme,
    userInfo: url.userInfo.isEmpty ? null : url.userInfo,
    host: url.host,
    port: url.hasPort ? url.port : null,
    path: url.path,
  ).toString();

  /// `ath` = base64url(SHA-256(ASCII(token))).
  static String accessTokenHash(String token) =>
      _b64(_sha256(ascii.encode(token)));
}

/// Thumbprint JWK theo RFC 7638 cho khoá EC: SHA-256 của JSON chỉ gồm
/// `crv`, `kty`, `x`, `y` theo thứ tự từ điển, không khoảng trắng.
String jwkThumbprint(Map<String, String> jwk) {
  for (final m in const ['crv', 'kty', 'x', 'y']) {
    if (jwk[m] == null) throw ArgumentError.value(jwk, 'jwk', 'thiếu "$m"');
  }
  if (jwk['kty'] != 'EC') throw ArgumentError.value(jwk, 'jwk', 'kty ≠ EC');
  final canonical =
      '{"crv":${jsonEncode(jwk['crv'])},"kty":"EC",'
      '"x":${jsonEncode(jwk['x'])},"y":${jsonEncode(jwk['y'])}}';
  return _b64(_sha256(utf8.encode(canonical)));
}
