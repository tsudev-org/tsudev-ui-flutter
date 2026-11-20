import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

Matcher rejects(EntitlementError e) =>
    throwsA(isA<EntitlementException>().having((x) => x.error, 'error', e));

void main() {
  final v = testVerifier();

  test('JWS hợp lệ ⇒ đọc đủ claim', () async {
    final pro = testNow.add(const Duration(days: 20));
    final e = await v.verify(
      signerA.sign(
        claims(proUntil: pro, donor: true, badge: 'both', devices: 3),
      ),
      now: testNow,
    );
    expect(e.subject, 'user-018f');
    expect(e.badge, TsuBadgeKind.both);
    expect(e.donor, isTrue);
    expect(e.devices30d, 3);
    expect(e.isProActive(testNow), isTrue);
    expect(e.isProActive(pro), isFalse, reason: 'pro_until > now, không ≥');
    expect(e.proSource, 'web');
  });

  test('pro_until = 0 ⇒ chưa từng có Pro', () async {
    final e = await v.verify(signerA.sign(claims()), now: testNow);
    expect(e.proUntil, isNull);
    expect(e.isProActive(testNow), isFalse);
  });

  group('header', () {
    test('alg khác ES256 bị từ chối (none, HS256, ES384)', () async {
      for (final alg in ['none', 'HS256', 'ES384', 'es256']) {
        final jws = signerA.sign(
          claims(),
          header: {'alg': alg, 'typ': 'tsu-ent+jwt', 'kid': signerA.kid},
        );
        await expectLater(
          v.verify(jws, now: testNow),
          rejects(EntitlementError.unsupportedAlgorithm),
        );
      }
    });

    test('alg none không chữ ký bị từ chối', () async {
      final h = b64json({'alg': 'none', 'typ': 'tsu-ent+jwt'});
      await expectLater(
        v.verify('$h.${b64json(claims())}.', now: testNow),
        rejects(EntitlementError.unsupportedAlgorithm),
      );
    });

    test('typ khác tsu-ent+jwt (ví dụ ID token) bị từ chối', () async {
      final jws = signerA.sign(
        claims(),
        header: {'alg': 'ES256', 'typ': 'JWT', 'kid': signerA.kid},
      );
      await expectLater(
        v.verify(jws, now: testNow),
        rejects(EntitlementError.wrongType),
      );
    });

    test('có crit ⇒ từ chối', () async {
      final jws = signerA.sign(
        claims(),
        header: {
          'alg': 'ES256',
          'typ': 'tsu-ent+jwt',
          'kid': signerA.kid,
          'crit': ['exp'],
        },
      );
      await expectLater(
        v.verify(jws, now: testNow),
        rejects(EntitlementError.malformed),
      );
    });

    test('thiếu kid / kid lạ ⇒ unknownKey', () async {
      await expectLater(
        v.verify(signerA.sign(claims(), omitKid: true), now: testNow),
        rejects(EntitlementError.unknownKey),
      );
      final other = TestSigner('kid-khac', 'aa' * 32);
      await expectLater(
        v.verify(other.sign(claims()), now: testNow),
        rejects(EntitlementError.unknownKey),
      );
    });

    test('khoá nhúng trong header (jwk) không bao giờ được dùng', () async {
      final jws = attacker.sign(
        claims(proUntil: testNow.add(const Duration(days: 365))),
        header: {
          'alg': 'ES256',
          'typ': 'tsu-ent+jwt',
          'kid': attacker.kid,
          'jwk': attacker.jwk,
        },
      );
      await expectLater(
        v.verify(jws, now: testNow),
        rejects(EntitlementError.badSignature),
      );
    });
  });

  group('chữ ký', () {
    test('sửa payload ⇒ badSignature', () async {
      final parts = signerA.sign(claims()).split('.');
      final forged = b64json(
        claims(proUntil: testNow.add(const Duration(days: 30))),
      );
      await expectLater(
        v.verify('${parts[0]}.$forged.${parts[2]}', now: testNow),
        rejects(EntitlementError.badSignature),
      );
    });

    test('chữ ký sai độ dài / r = s = 0 bị từ chối', () async {
      final parts = signerA.sign(claims()).split('.');
      await expectLater(
        v.verify(
          '${parts[0]}.${parts[1]}.${b64(List.filled(63, 1))}',
          now: testNow,
        ),
        rejects(EntitlementError.badSignature),
      );
      await expectLater(
        v.verify(
          '${parts[0]}.${parts[1]}.${b64(List.filled(64, 0))}',
          now: testNow,
        ),
        rejects(EntitlementError.badSignature),
      );
    });

    test('chuỗi hỏng ⇒ malformed', () async {
      for (final bad in ['', 'a.b', 'a.b.c.d', '!!.e30.AA', 'e30=.e30.AA']) {
        await expectLater(
          v.verify(bad, now: testNow),
          rejects(EntitlementError.malformed),
        );
      }
    });
  });

  group('claim', () {
    test('iss sai', () async {
      await expectLater(
        v.verify(
          signerA.sign(claims(iss: 'https://evil.example/oidc')),
          now: testNow,
        ),
        rejects(EntitlementError.wrongIssuer),
      );
    });

    test('aud của app khác bị từ chối; mảng có client_id thì nhận', () async {
      await expectLater(
        v.verify(signerA.sign(claims(aud: 'tsuscan-app')), now: testNow),
        rejects(EntitlementError.wrongAudience),
      );
      final ok = await v.verify(
        signerA.sign(claims(aud: ['x', testClientId])),
        now: testNow,
      );
      expect(ok.audience, testClientId);
    });

    test('quá exp ⇒ expired (không nới exp)', () async {
      final jws = signerA.sign(claims(life: const Duration(days: 7)));
      final ok = await v.verify(
        jws,
        now: testNow.add(const Duration(days: 7, seconds: -1)),
      );
      expect(ok.isFresh(testNow), isTrue);
      await expectLater(
        v.verify(jws, now: testNow.add(const Duration(days: 7))),
        rejects(EntitlementError.expired),
      );
    });

    test('exp > iat + 7 ngày ⇒ lifetimeTooLong', () async {
      await expectLater(
        v.verify(
          signerA.sign(claims(life: const Duration(days: 7, seconds: 1))),
          now: testNow,
        ),
        rejects(EntitlementError.lifetimeTooLong),
      );
    });

    test('iat ở tương lai quá dung sai ⇒ notYetValid', () async {
      await expectLater(
        v.verify(
          signerA.sign(claims(iat: testNow.add(const Duration(minutes: 10)))),
          now: testNow,
        ),
        rejects(EntitlementError.notYetValid),
      );
    });

    test('kiểu claim sai ⇒ invalidClaims', () async {
      final base = claims();
      for (final patch in <Map<String, Object?>>[
        {'devices_30d': '2'},
        {'devices_30d': -1},
        {'donor': 'true'},
        {'exp': 1.5},
        {'sub': ''},
        {'pro_source': 1},
      ]) {
        await expectLater(
          v.verify(signerA.sign({...base, ...patch}), now: testNow),
          rejects(EntitlementError.invalidClaims),
          reason: jsonEncode(patch),
        );
      }
    });

    test('badge lạ ⇒ none', () async {
      final e = await v.verify(
        signerA.sign(claims(badge: 'gold')),
        now: testNow,
      );
      expect(e.badge, TsuBadgeKind.none);
    });
  });

  group('JWK', () {
    test('chỉ nhận EC P-256 hợp lệ, điểm phải nằm trên đường cong', () {
      final good = signerA.jwk;
      expect(Es256PublicKey.fromJwk(good), isNotNull);
      for (final patch in <Map<String, Object?>>[
        {'kty': 'RSA'},
        {'crv': 'P-384'},
        {'alg': 'RS256'},
        {'use': 'enc'},
        {'kid': ''},
        {'x': b64(List.filled(31, 1))},
        {'y': b64(List.filled(32, 7))}, // lệch khỏi đường cong
      ]) {
        expect(
          Es256PublicKey.fromJwk({...good, ...patch}),
          isNull,
          reason: jsonEncode(patch),
        );
      }
    });

    test('JWKS bỏ qua khoá hỏng, giữ khoá tốt', () {
      final body = jsonEncode({
        'keys': [
          {'kty': 'oct', 'kid': 'h', 'k': 'AA'},
          signerA.jwk,
        ],
      });
      expect(parseJwks(body).keys, [signerA.kid]);
      expect(() => parseJwks('{}'), throwsFormatException);
    });
  });
}
