import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

final _p256 = ECDomainParameters('secp256r1');

const testIssuer = 'https://tsudev.com/oidc';
const testClientId = 'qulythuchi-app';

/// Giờ "hiện tại" cố định của mọi test: 20/11/2026 00:00 UTC.
final testNow = DateTime.utc(2026, 11, 20);

int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String b64json(Object o) => b64(utf8.encode(jsonEncode(o)));

Uint8List _fixed32(BigInt v) {
  final out = Uint8List(32);
  var x = v;
  for (var i = 31; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x >>= 8;
  }
  return out;
}

/// Khoá ký P-256 TẤT ĐỊNH (khoá riêng là hằng số công khai của test, không
/// phải bí mật) + ký RFC 6979 ⇒ test lặp lại được từng byte.
class TestSigner {
  TestSigner(this.kid, String privateHex)
    : _d = BigInt.parse(privateHex, radix: 16) {
    _q = (_p256.G * _d)!;
  }

  final String kid;
  final BigInt _d;
  late final ECPoint _q;

  Map<String, Object?> get jwk => {
    'kty': 'EC',
    'crv': 'P-256',
    'kid': kid,
    'use': 'sig',
    'alg': 'ES256',
    'x': b64(_fixed32(_q.x!.toBigInteger()!)),
    'y': b64(_fixed32(_q.y!.toBigInteger()!)),
  };

  Uint8List rawSign(String signingInput) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(_d, _p256)));
    final sig = signer.generateSignature(
      Uint8List.fromList(ascii.encode(signingInput)),
    ) as ECSignature;
    return Uint8List.fromList([..._fixed32(sig.r), ..._fixed32(sig.s)]);
  }

  String sign(
    Map<String, Object?> claims, {
    Map<String, Object?>? header,
    bool omitKid = false,
  }) {
    final h =
        header ??
        {'alg': 'ES256', 'typ': 'tsu-ent+jwt', if (!omitKid) 'kid': kid};
    final input = '${b64json(h)}.${b64json(claims)}';
    return '$input.${b64(rawSign(input))}';
  }
}

final signerA = TestSigner(
  'tsu-2026-11',
  'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721',
);

/// Khoá "kẻ tấn công" - KHÔNG có trong JWKS.
final attacker = TestSigner(
  'tsu-2026-11',
  '0f56db78ca460b055c500064824bed999a25aaf48ebb519ac201537b85479813',
);

String jwksJson([List<TestSigner>? signers]) => jsonEncode({
  'keys': [
    for (final s in signers ?? [signerA]) s.jwk,
  ],
});

StaticJwks testJwks() => StaticJwks.fromJson(jwksJson());

EntitlementVerifier testVerifier([JwksSource? jwks]) =>
    EntitlementVerifier(clientId: testClientId, jwks: jwks ?? testJwks());

/// Bộ claim hợp lệ mặc định: miễn phí, 1 thiết bị, sống 7 ngày từ [testNow].
Map<String, Object?> claims({
  DateTime? iat,
  Duration life = const Duration(days: 7),
  DateTime? proUntil,
  bool donor = false,
  String badge = 'none',
  int devices = 1,
  Object? aud = testClientId,
  Object? iss = testIssuer,
}) {
  final i = iat ?? testNow;
  return {
    'iss': iss,
    'sub': 'user-018f',
    'aud': aud,
    'iat': secs(i),
    'exp': secs(i.add(life)),
    'pro_until': proUntil == null ? 0 : secs(proUntil),
    'pro_source': proUntil == null ? null : 'web',
    'donor': donor,
    'badge': badge,
    'devices_30d': devices,
  };
}
