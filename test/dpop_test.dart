import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointycastle/export.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

/// Vector tự sinh, tính ĐỘC LẬP bằng Python thuần (phép nhân điểm P-256 +
/// hashlib, không dùng pointycastle) từ khoá công khai của test RFC 6979 A.2.5.
const _x = 'YP7UuiVanTHJYet0xjVtaMBJuJI7Yfps5mliLmDyn7Y';
const _y = 'eQP-EAi4vJmkGunpVii8ZPLxsgwtfp9Rd6PClNRGIpk';
const _jkt = 'DOvxvJiAdIqVWIkFt5hDtCunXLF0BV4-JGv4f-ALSm0';
// Thẻ GIẢ cho vector `ath`: header {"alg":"ES256"}, payload {}, chữ ký "sig".
const _token = 'eyJhbGciOiJFUzI1NiJ9.e30.sig'; // gitleaks:allow
const _ath = 'OJSdcS6LgVOwJLvM5ED_2vv3mnMMWwCqHUQ--uNDCF8';
const _privHex =
    'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721';

Map<String, Object?> _part(String compact, int i) => jsonDecode(
  utf8.decode(base64Url.decode(base64Url.normalize(compact.split('.')[i]))),
) as Map<String, Object?>;

/// Kiểm chữ ký ES256 của bằng chứng bằng khoá trong header `jwk`.
bool _verifies(String compact) {
  final jwk = (_part(compact, 0)['jwk']! as Map).cast<String, Object?>();
  final key = Es256PublicKey.fromJwk({...jwk, 'kid': 'dpop'})!;
  final parts = compact.split('.');
  final sig = base64Url.decode(base64Url.normalize(parts[2]));
  BigInt big(List<int> b) =>
      b.fold(BigInt.zero, (a, v) => (a << 8) | BigInt.from(v));
  final verifier = ECDSASigner(SHA256Digest())
    ..init(false, PublicKeyParameter<ECPublicKey>(key.key));
  return verifier.verifySignature(
    Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
    ECSignature(big(sig.sublist(0, 32)), big(sig.sublist(32))),
  );
}

void main() {
  final key = SoftwareDpopKey.fromPrivateHex(_privHex);

  test('JWK công khai + thumbprint RFC 7638 khớp vector độc lập', () async {
    final jwk = await key.publicJwk();
    expect(jwk, {'kty': 'EC', 'crv': 'P-256', 'x': _x, 'y': _y});
    expect(jwk.containsKey('d'), isFalse, reason: 'không lộ khoá riêng');
    expect(jwkThumbprint(jwk), _jkt);
    expect(await DpopSigner(key).thumbprint(), _jkt);
    // Thứ tự thành viên đầu vào không ảnh hưởng (RFC 7638 mục 3).
    expect(
      jwkThumbprint({'y': _y, 'x': _x, 'kty': 'EC', 'crv': 'P-256'}),
      _jkt,
    );
  });

  test('ath = base64url(SHA-256(token))', () {
    expect(DpopSigner.accessTokenHash(_token), _ath);
  });

  test('bằng chứng DPoP: header, claim, chữ ký (RFC 9449 mục 4)', () async {
    final signer = DpopSigner(key, clock: () => testNow);
    final proof = await signer.proof(
      'post',
      Uri.parse('https://sync.tsudev.com/v1/blob?id=7#x'),
      accessToken: _token,
      nonce: 'n-1',
    );
    final h = _part(proof, 0);
    final p = _part(proof, 1);
    expect(h['typ'], 'dpop+jwt');
    expect(h['alg'], 'ES256');
    expect(h['jwk'], {'kty': 'EC', 'crv': 'P-256', 'x': _x, 'y': _y});
    expect(p['htm'], 'POST');
    expect(
      p['htu'],
      'https://sync.tsudev.com/v1/blob',
      reason: 'bỏ query, fragment',
    );
    expect(p['iat'], secs(testNow));
    expect(p['ath'], _ath);
    expect(p['nonce'], 'n-1');
    expect(p['jti'], isA<String>());
    expect(
      base64Url.decode(base64Url.normalize(p['jti']! as String)),
      hasLength(16),
    );
    expect(_verifies(proof), isTrue);
  });

  test('jti khác nhau mỗi lần; không có token ⇒ không có ath', () async {
    final signer = DpopSigner(key, clock: () => testNow);
    final url = Uri.parse('https://tsudev.com/api/me/entitlements');
    final a = _part(await signer.proof('GET', url), 1);
    final b = _part(await signer.proof('GET', url), 1);
    expect(a['jti'], isNot(b['jti']));
    expect(a.containsKey('ath'), isFalse);
    expect(a.containsKey('nonce'), isFalse);
  });

  test('htu giữ cổng không mặc định', () {
    expect(
      DpopSigner.htu(Uri.parse('https://localhost:8787/a/b?q=1')),
      'https://localhost:8787/a/b',
    );
  });

  test(
    'boundHeaders: Authorization DPoP + bằng chứng có ath của thẻ',
    () async {
      final hs = await DpopSigner(key, clock: () => testNow).boundHeaders(
        'GET',
        Uri.parse('https://sync.tsudev.com/v1/list'),
        _token,
      );
      expect(hs['Authorization'], 'DPoP $_token');
      expect(_part(hs['DPoP']!, 1)['ath'], _ath);
    },
  );

  group('SoftwareDpopKey', () {
    test('getOrCreate: sinh một lần, lưu, đọc lại cùng khoá', () async {
      final store = InMemoryKeyValueStore();
      final k1 = await SoftwareDpopKey.getOrCreate(store);
      final k2 = await SoftwareDpopKey.getOrCreate(store);
      expect(await k2.publicJwk(), await k1.publicJwk());
      expect(store.snapshot[SoftwareDpopKey.storageKey], hasLength(64));
    });

    test('khoá hỏng ⇒ thay khoá mới, không lỗi', () async {
      final store = InMemoryKeyValueStore({SoftwareDpopKey.storageKey: 'zz'});
      final k = await SoftwareDpopKey.getOrCreate(store);
      expect((await k.publicJwk())['kty'], 'EC');
      expect(store.snapshot[SoftwareDpopKey.storageKey], isNot('zz'));
    });

    test('từ chối khoá ngoài miền [1, n-1]', () {
      expect(
        () => SoftwareDpopKey.fromPrivateHex('0' * 64),
        throwsArgumentError,
      );
      expect(
        () => SoftwareDpopKey.fromPrivateHex('f' * 64),
        throwsArgumentError,
      );
    });

    test('generate ⇒ khoá ký được, mỗi lần khác nhau', () async {
      final a = SoftwareDpopKey.generate(Random(1));
      final b = SoftwareDpopKey.generate(Random(2));
      expect(await a.publicJwk(), isNot(await b.publicJwk()));
      final proof = await DpopSigner(a)
          .proof('GET', Uri.parse('https://x.test/'));
      expect(_verifies(proof), isTrue);
    });
  });

  group('TsudevEntitlementsApi + DPoP', () {
    test('gửi header DPoP (htm, htu, ath của access token)', () async {
      http.Request? seen;
      final api = TsudevEntitlementsApi(
        client: MockClient((req) async {
          seen = req;
          return http.Response('{"jws":"a.b.c"}', 200);
        }),
        accessToken: () async => _token,
        installationId: () async => '',
        dpop: DpopSigner(key, clock: () => testNow),
      );
      expect(await api.fetch(), 'a.b.c');
      expect(seen!.headers['Authorization'], 'Bearer $_token');
      final p = _part(seen!.headers['DPoP']!, 1);
      expect(p['htm'], 'GET');
      expect(p['htu'], 'https://tsudev.com/api/me/entitlements');
      expect(p['ath'], _ath);
    });

    test('máy chủ đòi nonce ⇒ thử lại đúng một lần với nonce', () async {
      final nonces = <Object?>[];
      final api = TsudevEntitlementsApi(
        client: MockClient((req) async {
          final n = _part(req.headers['DPoP']!, 1)['nonce'];
          nonces.add(n);
          if (n == null) {
            return http.Response(
              '{"error":"use_dpop_nonce"}',
              401,
              headers: {'dpop-nonce': 'abc'},
            );
          }
          return http.Response('{"jws":"a.b.c"}', 200);
        }),
        accessToken: () async => _token,
        installationId: () async => '',
        dpop: DpopSigner(key, clock: () => testNow),
      );
      expect(await api.fetch(), 'a.b.c');
      expect(nonces, [null, 'abc']);
    });
  });
}
