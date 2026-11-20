// Fuzz đột biến cho EntitlementVerifier - đầu vào KHÔNG tin cậy duy nhất của gói
// (JWS từ mạng hoặc kho cục bộ). Tính chất: với MỌI chuỗi, verify() hoặc trả
// đúng quyền lợi của JWS gốc, hoặc ném EntitlementException - không bao giờ ném
// lỗi khác (TypeError, RangeError, FormatException...) và không bao giờ nhận một
// JWS đã bị sửa nội dung. Seed cố định ⇒ lặp lại được; đổi seed bằng
// `--dart-define=FUZZ_SEED=<số>` để chạy thêm.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

const _seed = int.fromEnvironment('FUZZ_SEED', defaultValue: 20261120);
const _rounds = 3000;
// Ký ECDSA chậm ⇒ ít vòng hơn cho hai test có chữ ký hợp lệ.
const _signedRounds = 300;
const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.=+/ {}"\\\u0000é';

String _mutate(String s, Random r) {
  var out = s;
  final steps = 1 + r.nextInt(4);
  for (var i = 0; i < steps; i++) {
    final pos = out.isEmpty ? 0 : r.nextInt(out.length);
    final ch = _alphabet[r.nextInt(_alphabet.length)];
    switch (r.nextInt(6)) {
      case 0: // thay một ký tự
        if (out.isNotEmpty) {
          out = out.replaceRange(pos, pos + 1, ch);
        }
      case 1: // chèn
        out = out.replaceRange(pos, pos, ch);
      case 2: // xoá
        if (out.isNotEmpty) {
          out = out.replaceRange(pos, pos + 1, '');
        }
      case 3: // cắt cụt
        out = out.substring(0, pos);
      case 4: // đổi chỗ hai đoạn
        final p = out.split('.');
        if (p.length > 1) {
          final a = r.nextInt(p.length), b = r.nextInt(p.length);
          final t = p[a];
          p[a] = p[b];
          p[b] = t;
          out = p.join('.');
        }
      default: // nhân đôi một đoạn
        out = out + out.substring(pos);
    }
  }
  return out;
}

Object? _randomJson(Random r, int depth) {
  switch (r.nextInt(depth > 2 ? 6 : 8)) {
    case 0:
      return null;
    case 1:
      return r.nextBool();
    case 2:
      return r.nextInt(1 << 32) - (1 << 31);
    case 3:
      return r.nextDouble() * 1e12;
    case 4:
      return 'x' * r.nextInt(5);
    case 5:
      return testClientId;
    case 6:
      return [for (var i = 0; i < r.nextInt(3); i++) _randomJson(r, depth + 1)];
    default:
      return {'k${r.nextInt(3)}': _randomJson(r, depth + 1)};
  }
}

Future<void> _expectOnlyKnownOutcome(
  EntitlementVerifier v,
  String jws, {
  Entitlement? acceptOnly,
}) async {
  try {
    final e = await v.verify(jws, now: testNow);
    if (acceptOnly == null) {
      fail('JWS lẽ ra bị từ chối nhưng được nhận: $jws');
    }
    expect(e.subject, acceptOnly.subject);
    expect(e.proUntil, acceptOnly.proUntil);
    expect(e.badge, acceptOnly.badge);
  } on EntitlementException {
    // Kết quả mong đợi: app rơi về trạng thái miễn phí.
  } catch (e, st) {
    fail('Lỗi ngoài EntitlementException với "$jws": $e\n$st');
  }
}

void main() {
  final v = testVerifier();
  final original = signerA.sign(
    claims(
      proUntil: testNow.add(const Duration(days: 20)),
      donor: true,
      badge: 'both',
    ),
  );

  test(
    'đột biến chuỗi JWS: chỉ nhận đúng bản gốc, chỉ ném lỗi đã biết',
    () async {
      final good = await v.verify(original, now: testNow);
      final r = Random(_seed);
      for (var i = 0; i < _rounds; i++) {
        final m = _mutate(original, r);
        // base64url có thể giải mã giống hệt (bit đệm cuối) ⇒ cho phép nhận,
        // nhưng nội dung phải trùng bản gốc.
        await _expectOnlyKnownOutcome(v, m, acceptOnly: good);
      }
    },
  );

  test('claim ngẫu nhiên có chữ ký hợp lệ: chỉ ném lỗi đã biết', () async {
    final r = Random(_seed + 1);
    const keys = [
      'iss', 'sub', 'aud', 'iat', 'exp', 'pro_until', 'pro_source', //
      'donor', 'badge', 'devices_30d', 'cnf',
    ];
    for (var i = 0; i < _signedRounds; i++) {
      final c = Map<String, Object?>.of(claims());
      for (var j = 0; j < 1 + r.nextInt(3); j++) {
        final k = keys[r.nextInt(keys.length)];
        if (r.nextInt(5) == 0) {
          c.remove(k);
        } else {
          c[k] = _randomJson(r, 0);
        }
      }
      try {
        await v.verify(signerA.sign(c), now: testNow);
      } on EntitlementException {
        // ok
      } catch (e, st) {
        fail(
          'Lỗi ngoài EntitlementException với claim ${jsonEncode(c)}: $e\n$st',
        );
      }
    }
  });

  test('header ngẫu nhiên có chữ ký hợp lệ: chỉ ném lỗi đã biết', () async {
    final r = Random(_seed + 2);
    const keys = ['alg', 'typ', 'kid', 'crit', 'jwk', 'jku', 'b64'];
    for (var i = 0; i < _signedRounds; i++) {
      final h = <String, Object?>{
        'alg': 'ES256',
        'typ': 'tsu-ent+jwt',
        'kid': signerA.kid,
      };
      for (var j = 0; j < 1 + r.nextInt(2); j++) {
        h[keys[r.nextInt(keys.length)]] = _randomJson(r, 0);
      }
      try {
        await v.verify(signerA.sign(claims(), header: h), now: testNow);
      } on EntitlementException {
        // ok
      } catch (e, st) {
        fail(
          'Lỗi ngoài EntitlementException với header ${jsonEncode(h)}: $e\n$st',
        );
      }
    }
  });
}
