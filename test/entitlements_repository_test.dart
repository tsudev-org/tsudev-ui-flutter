import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

void main() {
  group('EntitlementsRepository', () {
    late InMemoryKeyValueStore store;
    late DateTime now;

    EntitlementsRepository repo(Future<String> Function() fetch) =>
        EntitlementsRepository(
          verifier: testVerifier(),
          store: store,
          fetchJws: fetch,
          clock: () => now,
        );

    setUp(() {
      store = InMemoryKeyValueStore();
      now = testNow;
    });

    test('lấy mới thành công ⇒ đệm JWS', () async {
      final jws = signerA.sign(claims(devices: 2));
      final s = await repo(() async => jws).refresh();
      expect(s.source, EntitlementSource.network);
      expect(s.devices30d, 2);
      expect(store.snapshot[EntitlementsRepository.cacheKey], jws);
    });

    test('ngoại tuyến ⇒ dùng đệm còn hạn (kiểm lại chữ ký)', () async {
      store = InMemoryKeyValueStore({
        EntitlementsRepository.cacheKey: signerA.sign(
          claims(proUntil: testNow.add(const Duration(days: 30))),
        ),
      });
      now = testNow.add(const Duration(days: 6));
      final s = await repo(() => throw const SocketException('offline'))
          .refresh();
      expect(s.source, EntitlementSource.cache);
      expect(s.isPro(now), isTrue);
    });

    test('đệm quá exp (≤ 7 ngày) ⇒ miễn phí, không lỗi', () async {
      store = InMemoryKeyValueStore({
        EntitlementsRepository.cacheKey: signerA.sign(
          claims(proUntil: testNow.add(const Duration(days: 30))),
        ),
      });
      now = testNow.add(const Duration(days: 7));
      final s = await repo(() => throw const SocketException('offline'))
          .refresh();
      expect(s.source, EntitlementSource.none);
      expect(s.isPro(now), isFalse);
      expect(s.badge, TsuBadgeKind.none);
    });

    test('đệm bị sửa ⇒ xoá, miễn phí', () async {
      final parts = signerA.sign(claims()).split('.');
      final forged =
          '${parts[0]}.${b64json(claims(proUntil: DateTime.utc(2030)))}.${parts[2]}';
      store = InMemoryKeyValueStore({EntitlementsRepository.cacheKey: forged});
      final s = await repo(() async => throw Exception('x')).current();
      expect(s.entitlement, isNull);
      expect(store.snapshot, isEmpty);
    });

    test('máy chủ trả JWS giả ⇒ không ghi đè đệm tốt', () async {
      final good = signerA.sign(claims(devices: 3));
      store = InMemoryKeyValueStore({EntitlementsRepository.cacheKey: good});
      final s = await repo(
        () async => attacker.sign(claims(proUntil: DateTime.utc(2030))),
      ).refresh();
      expect(s.source, EntitlementSource.cache);
      expect(s.isPro(now), isFalse);
      expect(store.snapshot[EntitlementsRepository.cacheKey], good);
    });

    test('clear() bỏ đệm', () async {
      final r = repo(() async => signerA.sign(claims()));
      await r.refresh();
      await r.clear();
      expect((await r.current()).entitlement, isNull);
    });
  });

  group('DiscoveryJwks', () {
    Map<String, Object?> discovery({
      String issuer = testIssuer,
      String jwksUri = 'https://tsudev.com/oidc/jwks',
    }) => {'issuer': issuer, 'jwks_uri': jwksUri};

    MockClient client(Map<String, Object?> d, {int jwksStatus = 200}) =>
        MockClient((req) async {
          if (req.url.path.endsWith('/.well-known/openid-configuration')) {
            return http.Response(jsonEncode(d), 200);
          }
          if (req.url.toString() == d['jwks_uri']) {
            return http.Response(jwksJson(), jwksStatus);
          }
          return http.Response('not found', 404);
        });

    test('discovery đúng ⇒ kiểm được JWS, lưu JWKS', () async {
      final store = InMemoryKeyValueStore();
      final jwks = DiscoveryJwks(client: client(discovery()), store: store);
      final e = await testVerifier(jwks)
          .verify(signerA.sign(claims()), now: testNow);
      expect(e.subject, 'user-018f');
      expect(store.snapshot[DiscoveryJwks.storageKey], isNotNull);
    });

    test('issuer lạ hoặc jwks_uri khác máy chủ ⇒ không có khoá', () async {
      for (final d in [
        discovery(issuer: 'https://evil.example/oidc'),
        discovery(jwksUri: 'https://evil.example/jwks'),
        discovery(jwksUri: 'http://tsudev.com/oidc/jwks'),
      ]) {
        final jwks = DiscoveryJwks(client: client(d));
        expect(await jwks.keyFor(signerA.kid), isNull, reason: '$d');
      }
    });

    test('ngoại tuyến ⇒ dùng JWKS đã lưu', () async {
      final store = InMemoryKeyValueStore({
        DiscoveryJwks.storageKey: jwksJson(),
      });
      final offline = MockClient(
        (_) async => throw const SocketException('offline'),
      );
      final jwks = DiscoveryJwks(client: offline, store: store);
      expect(await jwks.keyFor(signerA.kid), isNotNull);
    });

    test('kid lạ ⇒ tải lại tối đa một lần mỗi 5 phút', () async {
      var calls = 0;
      var t = testNow;
      final c = MockClient((req) async {
        calls++;
        return req.url.path.endsWith('openid-configuration')
            ? http.Response(jsonEncode(discovery()), 200)
            : http.Response(jwksJson(), 200);
      });
      final jwks = DiscoveryJwks(client: c, clock: () => t);
      await jwks.keyFor('lạ', forceRefresh: true);
      await jwks.keyFor('lạ', forceRefresh: true);
      expect(calls, 2, reason: 'discovery + jwks một lần');
      t = t.add(const Duration(minutes: 5));
      await jwks.keyFor('lạ', forceRefresh: true);
      expect(calls, 4);
    });
  });

  group('TsudevEntitlementsApi', () {
    test('gửi Bearer + X-Tsu-Installation, đọc {"jws"}', () async {
      late http.Request seen;
      final api = TsudevEntitlementsApi(
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode({'jws': 'a.b.c'}), 200);
        }),
        accessToken: () async => 'tok',
        installationId: () async => 'AAAAAAAAAAAAAAAAAAAAAA',
      );
      expect(await api.fetch(), 'a.b.c');
      expect(seen.url, TsudevEntitlementsApi.defaultEndpoint);
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.headers['X-Tsu-Installation'], 'AAAAAAAAAAAAAAAAAAAAAA');
    });

    test('mã cài đặt sai định dạng ⇒ không gửi header', () async {
      late http.Request seen;
      final api = TsudevEntitlementsApi(
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode({'jws': 'a.b.c'}), 200);
        }),
        accessToken: () async => 'tok',
        installationId: () async => 'ngan',
      );
      await api.fetch();
      expect(seen.headers.containsKey('X-Tsu-Installation'), isFalse);
    });

    test('403 insufficient_scope ⇒ lỗi có mã', () async {
      final api = TsudevEntitlementsApi(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'insufficient_scope'}), 403),
        ),
        accessToken: () async => 'tok',
        installationId: () async => 'AAAAAAAAAAAAAAAAAAAAAA',
      );
      await expectLater(
        api.fetch(),
        throwsA(
          isA<EntitlementsHttpException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.code, 'code', 'insufficient_scope'),
        ),
      );
    });

    test('endpoint không https bị từ chối', () {
      expect(
        () => TsudevEntitlementsApi(
          client: MockClient((_) async => http.Response('', 200)),
          accessToken: () async => '',
          installationId: () async => '',
          endpoint: Uri.parse('http://tsudev.com/api/me/entitlements'),
        ),
        throwsArgumentError,
      );
    });
  });
}
