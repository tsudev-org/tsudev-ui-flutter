import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

void main() {
  late InMemoryKeyValueStore store;
  late DateTime now;
  late int fetches;
  late bool offline;

  /// Máy chủ quyền lợi: mỗi lần gọi ký JWS mới với `iat` = [now].
  EntitlementsRepository repo({DpopSigner? dpop}) => EntitlementsRepository(
    verifier: testVerifier(),
    store: store,
    fetchJws: () async {
      if (offline) throw const SocketException('offline');
      fetches++;
      return signerA.sign(claims(iat: now));
    },
    dpop: dpop,
    clock: () => now,
  );

  setUp(() {
    store = InMemoryKeyValueStore();
    now = testNow;
    fetches = 0;
    offline = false;
  });

  int iatOf(String jws) {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(jws.split('.')[1])),
    );
    return (jsonDecode(payload) as Map<String, Object?>)['iat']! as int;
  }

  group('jwsForServer (PRODUCT_POLICY 7.4: máy chủ nhận iat ≤ 24 giờ)', () {
    test('chưa có đệm ⇒ lấy mới và đệm', () async {
      final r = repo();
      final jws = await r.jwsForServer();
      expect(jws, isNotNull);
      expect(fetches, 1);
      expect(store.snapshot[EntitlementsRepository.cacheKey], jws);
    });

    test('iat ≤ 23 giờ ⇒ dùng đệm; > 23 giờ ⇒ lấy mới', () async {
      final r = repo();
      final first = await r.jwsForServer();
      now = testNow.add(const Duration(hours: 23));
      expect(await r.jwsForServer(), first);
      expect(fetches, 1);
      now = testNow.add(const Duration(hours: 23, seconds: 1));
      final second = await r.jwsForServer();
      expect(fetches, 2);
      expect(iatOf(second!), secs(now));
    });

    test('lấy mới lỗi ⇒ đệm còn < 24 giờ thì dùng, đủ 24 giờ ⇒ null', () async {
      final r = repo();
      final first = await r.jwsForServer();
      offline = true;
      now = testNow.add(const Duration(hours: 23, minutes: 59));
      expect(await r.jwsForServer(), first);
      now = testNow.add(const Duration(hours: 24));
      expect(await r.jwsForServer(), isNull);
    });

    test(
      'forceRefresh ⇒ luôn lấy mới; lỗi ⇒ null (không trả lại JWS cũ)',
      () async {
        final r = repo();
        await r.jwsForServer();
        expect(await r.jwsForServer(forceRefresh: true), isNotNull);
        expect(fetches, 2);
        offline = true;
        expect(await r.jwsForServer(forceRefresh: true), isNull);
      },
    );

    test('nhiều lời gọi đồng thời ⇒ một yêu cầu mạng', () async {
      final r = repo();
      final all = await Future.wait([
        r.jwsForServer(),
        r.jwsForServer(),
        r.jwsForServer(),
      ]);
      expect(fetches, 1);
      expect(all.toSet(), hasLength(1));
    });

    test('fetchJws ném lỗi đồng bộ ⇒ lần sau vẫn lấy lại được', () async {
      var throwNow = true;
      final r = EntitlementsRepository(
        verifier: testVerifier(),
        store: store,
        fetchJws: () {
          if (throwNow) throw StateError('đồng bộ');
          return Future.value(signerA.sign(claims(iat: now)));
        },
        clock: () => now,
      );
      expect(await r.jwsForServer(), isNull);
      throwNow = false;
      await Future<void>.delayed(Duration.zero);
      expect(await r.jwsForServer(), isNotNull);
    });
  });

  group('sendWithServerJws: 401 stale ⇒ lấy mới, thử lại một lần', () {
    http.Response stale() =>
        http.Response('{"error":"invalid_token","reason":"stale"}', 401);

    test('stale ⇒ JWS mới, gửi lại, trả kết quả lần hai', () async {
      final r = repo();
      final sent = <String>[];
      var first = true;
      final res = await r.sendWithServerJws((jws) async {
        sent.add(jws);
        if (first) {
          first = false;
          now = now.add(const Duration(seconds: 5)); // JWS mới có iat khác
          return stale();
        }
        return http.Response('ok', 200);
      });
      expect(res!.statusCode, 200);
      expect(sent, hasLength(2));
      expect(sent[0], isNot(sent[1]));
      expect(fetches, 2);
    });

    test('stale lần hai ⇒ không lặp vô hạn, trả 401', () async {
      final r = repo();
      var calls = 0;
      final res = await r.sendWithServerJws((jws) async {
        calls++;
        now = now.add(const Duration(seconds: 5));
        return stale();
      });
      expect(res!.statusCode, 401);
      expect(calls, 2);
    });

    test('401 khác lý do / 402 ⇒ không thử lại', () async {
      for (final res in [
        http.Response('{"error":"invalid_token"}', 401),
        http.Response('{"error":"pro_required"}', 402),
      ]) {
        var calls = 0;
        final out = await repo().sendWithServerJws((_) async {
          calls++;
          return res;
        });
        expect(out!.statusCode, res.statusCode);
        expect(calls, 1);
      }
    });

    test('không có JWS dùng được ⇒ null, không gửi', () async {
      offline = true;
      var calls = 0;
      expect(
        await repo().sendWithServerJws((_) async {
          calls++;
          return http.Response('ok', 200);
        }),
        isNull,
      );
      expect(calls, 0);
    });
  });

  group('serverAuthHeaders', () {
    final url = Uri.parse('https://sync.tsudev.com/v1/list');
    final key = SoftwareDpopKey.fromPrivateHex(
      'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721',
    );

    test('không có cnf.jkt ⇒ Bearer', () async {
      final jws = signerA.sign(claims());
      expect(await repo().serverAuthHeaders(jws, 'GET', url), {
        'Authorization': 'Bearer $jws',
      });
    });

    test('có cnf.jkt ⇒ DPoP + bằng chứng; thiếu signer ⇒ StateError', () async {
      final signer = DpopSigner(key, clock: () => testNow);
      final jws = signerA.sign({
        ...claims(),
        'cnf': {'jkt': await signer.thumbprint()},
      });
      final hs = await repo(dpop: signer).serverAuthHeaders(jws, 'GET', url);
      expect(hs['Authorization'], 'DPoP $jws');
      expect(hs['DPoP'], isNotNull);
      expect(() => repo().serverAuthHeaders(jws, 'GET', url), throwsStateError);
    });

    test('verifier đọc cnf.jkt; giá trị sai dạng ⇒ từ chối', () async {
      final jkt = await DpopSigner(key).thumbprint();
      final e = await testVerifier().verify(
        signerA.sign({
          ...claims(),
          'cnf': {'jkt': jkt},
        }),
        now: testNow,
      );
      expect(e.confirmationJkt, jkt);
      await expectLater(
        testVerifier().verify(
          signerA.sign({
            ...claims(),
            'cnf': {'jkt': 'ngắn'},
          }),
          now: testNow,
        ),
        throwsA(isA<EntitlementException>()),
      );
    });
  });
}
