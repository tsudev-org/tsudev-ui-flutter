import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'base64url.dart';
import 'entitlement.dart';
import 'jwks.dart';

/// Kiểm JWS quyền lợi theo PRODUCT_POLICY 7.4.
///
/// - Chỉ nhận `alg` = `ES256`, header `typ` = `tsu-ent+jwt`, có `kid`; header
///   có `crit` ⇒ từ chối (không hiểu phần mở rộng nào). Khoá nhúng trong header
///   (`jwk`, `jku`, `x5u`, `x5c`) KHÔNG BAO GIỜ được dùng.
/// - Kiểm `iss`, `aud` = [clientId], `exp`, `iat`, và `exp` ≤ `iat` + 7 ngày.
class EntitlementVerifier {
  EntitlementVerifier({
    required this.clientId,
    required this.jwks,
    this.issuer = DiscoveryJwks.defaultIssuer,
    this.clockSkew = const Duration(minutes: 2),
  });

  static const jwsType = 'tsu-ent+jwt';
  static const maxLifetime = Duration(days: 7);

  final String clientId;
  final String issuer;
  final JwksSource jwks;

  /// Dung sai đồng hồ cho `iat` ở tương lai. KHÔNG nới `exp`.
  final Duration clockSkew;

  Future<Entitlement> verify(String compact, {required DateTime now}) async {
    final parts = compact.split('.');
    if (parts.length != 3) _fail(EntitlementError.malformed, '3 phần');
    final headerBytes = tryDecodeBase64Url(parts[0]);
    final payloadBytes = tryDecodeBase64Url(parts[1]);
    final sig = tryDecodeBase64Url(parts[2]);
    if (headerBytes == null || payloadBytes == null || sig == null) {
      _fail(EntitlementError.malformed, 'base64url');
    }

    final header = _jsonObject(headerBytes);
    if (header['alg'] != 'ES256') _fail(EntitlementError.unsupportedAlgorithm);
    if (header['typ'] != jwsType) _fail(EntitlementError.wrongType);
    if (header.containsKey('crit')) _fail(EntitlementError.malformed, 'crit');
    final kid = header['kid'];
    if (kid is! String || kid.isEmpty) {
      _fail(EntitlementError.unknownKey, 'thiếu kid');
    }
    if (sig.length != 64) _fail(EntitlementError.badSignature, 'độ dài');

    final key =
        await jwks.keyFor(kid) ?? await jwks.keyFor(kid, forceRefresh: true);
    if (key == null) _fail(EntitlementError.unknownKey, kid);

    final signingInput = Uint8List.fromList(
      ascii.encode('${parts[0]}.${parts[1]}'),
    );
    final signature = ECSignature(
      bytesToBigInt(Uint8List.sublistView(sig, 0, 32)),
      bytesToBigInt(Uint8List.sublistView(sig, 32)),
    );
    final signer = ECDSASigner(SHA256Digest())
      ..init(false, PublicKeyParameter<ECPublicKey>(key.key));
    if (!signer.verifySignature(signingInput, signature)) {
      _fail(EntitlementError.badSignature);
    }

    return _claims(_jsonObject(payloadBytes), now.toUtc());
  }

  Entitlement _claims(Map<String, Object?> c, DateTime now) {
    if (c['iss'] != issuer) _fail(EntitlementError.wrongIssuer);
    final aud = c['aud'];
    final audOk = aud == clientId || (aud is List && aud.contains(clientId));
    if (!audOk) _fail(EntitlementError.wrongAudience);

    final iat = _time(c['iat'], 'iat');
    final exp = _time(c['exp'], 'exp');
    if (!exp.isAfter(iat)) _fail(EntitlementError.invalidClaims, 'exp ≤ iat');
    if (exp.difference(iat) > maxLifetime) {
      _fail(EntitlementError.lifetimeTooLong);
    }
    if (iat.isAfter(now.add(clockSkew))) _fail(EntitlementError.notYetValid);
    if (!now.isBefore(exp)) _fail(EntitlementError.expired);

    final sub = c['sub'];
    if (sub is! String || sub.isEmpty) {
      _fail(EntitlementError.invalidClaims, 'sub');
    }
    final proUntilRaw = c['pro_until'] ?? 0;
    final proUntil = _seconds(proUntilRaw, 'pro_until');
    final proSource = c['pro_source'];
    if (proSource != null && proSource is! String) {
      _fail(EntitlementError.invalidClaims, 'pro_source');
    }
    final donor = c['donor'] ?? false;
    if (donor is! bool) _fail(EntitlementError.invalidClaims, 'donor');
    final devices = c['devices_30d'] ?? 0;
    if (devices is! int || devices < 0) {
      _fail(EntitlementError.invalidClaims, 'devices_30d');
    }

    return Entitlement(
      subject: sub,
      audience: clientId,
      issuedAt: iat,
      expiresAt: exp,
      proUntil: proUntil == 0 ? null : _fromSeconds(proUntil),
      proSource: proSource as String?,
      donor: donor,
      badge: TsuBadgeKind.parse(c['badge']),
      devices30d: devices,
    );
  }

  static DateTime _time(Object? raw, String name) =>
      _fromSeconds(_seconds(raw, name));

  static int _seconds(Object? raw, String name) {
    if (raw is! int || raw < 0) _fail(EntitlementError.invalidClaims, name);
    return raw;
  }

  static DateTime _fromSeconds(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  static Map<String, Object?> _jsonObject(Uint8List bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      _fail(EntitlementError.malformed, 'JSON');
    }
    if (decoded is! Map<String, Object?>) {
      _fail(EntitlementError.malformed, 'không phải object');
    }
    return decoded;
  }

  static Never _fail(EntitlementError e, [String? detail]) =>
      throw EntitlementException(e, detail);
}
