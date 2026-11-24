import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

/// QR2b - vai xác nhận trong app (CROSS_DEVICE_LOGIN 1, 6.3, 7).
void main() {
  const id = 'AbCdEfGhIjKlMnOpQrStUv';
  const k = 'k1234567890123456789012345678901234567890AB';
  final pull = TsuXdLink.parse('https://tsudev.com/x/$id?f=k#$k')!;
  final push = TsuXdLink.parse('https://tsudev.com/x/$id?f=d#$k')!;

  MockClient server(
    List<http.Request> log, {
    Map<String, (int, Object)> replies = const {},
  }) => MockClient((req) async {
    log.add(req);
    final action = req.url.pathSegments.last;
    final (status, body) =
        replies[action] ??
        switch (action) {
          'scan' => (
            200,
            {
              'requester': {'label': 'Chrome trên Windows', 'country': 'VN'},
              'createdAt': 0,
            },
          ),
          'approve' => (200, {'code': 'K7QF-M2XD', 'expiresIn': 60}),
          _ => (200, {'ok': true}),
        };
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  });

  group('TsuXdApprover', () {
    test(
      'gọi đúng /api/xd/<hành động>, Bearer, bí mật QR chỉ gửi lúc scan',
      () async {
        final log = <http.Request>[];
        final a = TsuXdApprover(
          accessToken: () async => 'tok',
          client: server(log),
        );
        final r = await a.scan(pull);
        expect(r.label, 'Chrome trên Windows');
        expect(r.country, 'VN');
        final c = await a.approve(pull);
        expect(c.code, 'K7QF-M2XD');
        expect(c.ttl, const Duration(seconds: 60));
        await a.deny(pull);
        expect(log.map((r) => r.url.toString()), [
          'https://tsudev.com/api/xd/scan',
          'https://tsudev.com/api/xd/approve',
          'https://tsudev.com/api/xd/deny',
        ]);
        for (final r in log) {
          expect(r.headers['Authorization'], 'Bearer tok');
          expect(
            r.headers.keys.map((h) => h.toLowerCase()),
            isNot(contains('cookie')),
          );
        }
        expect(jsonDecode(log[0].body), {'id': id, 'k': k});
        expect(jsonDecode(log[1].body), {'id': id});
      },
    );

    test('QR Đ1 (đẩy) không được gửi lên - app phải mở trình duyệt', () async {
      final log = <http.Request>[];
      final a = TsuXdApprover(
        accessToken: () async => 'tok',
        client: server(log),
      );
      await expectLater(
        a.scan(push),
        throwsA(
          isA<TsuXdException>().having((e) => e.code, 'code', 'wrong_flow'),
        ),
      );
      expect(log, isEmpty);
    });

    test('chưa đăng nhập ⇒ không gọi mạng', () async {
      final log = <http.Request>[];
      final a = TsuXdApprover(
        accessToken: () async => null,
        client: server(log),
      );
      await expectLater(a.scan(pull), throwsA(isA<TsuXdException>()));
      expect(log, isEmpty);
    });

    test('lỗi IdP ra mã ngắn', () async {
      final a = TsuXdApprover(
        accessToken: () async => 'tok',
        client: server(
          [],
          replies: {
            'approve': (403, {'error': 'country_mismatch'}),
          },
        ),
      );
      await expectLater(
        a.approve(pull),
        throwsA(
          isA<TsuXdException>().having(
            (e) => e.code,
            'code',
            'country_mismatch',
          ),
        ),
      );
    });
  });

  group('TsuXdApproveScreen (6.3)', () {
    Future<List<http.Request>> pump(
      WidgetTester tester, {
      required Future<bool> Function() unlock,
      Map<String, (int, Object)> replies = const {},
      TsuXdLink? link,
    }) async {
      final log = <http.Request>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TsuXdApproveScreen(
            locale: const Locale('vi'),
            link: link ?? pull,
            unlock: unlock,
            clock: () => DateTime(2026, 11, 24, 20, 5),
            approver: TsuXdApprover(
              accessToken: () async => 'tok',
              client: server(log, replies: replies),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return log;
    }

    testWidgets(
      'hiện thiết bị, vị trí, câu cảnh báo nguyên văn; Từ chối có focus mặc định',
      (tester) async {
        await pump(tester, unlock: () async => true);
        expect(find.text('Chrome trên Windows'), findsOneWidget);
        expect(find.text('VN'), findsOneWidget);
        expect(
          find.textContaining('Chỉ cho phép nếu bạn đang cầm cả hai thiết bị.'),
          findsOneWidget,
        );
        final deny = tester.widget<FilledButton>(
          find.byKey(const Key('tsu-xd-deny')),
        );
        expect(deny.autofocus, isTrue);
        final dSize = tester.getSize(find.byKey(const Key('tsu-xd-deny')));
        final aSize = tester.getSize(find.byKey(const Key('tsu-xd-allow')));
        expect(dSize, aSize);
      },
    );

    testWidgets('Cho phép mà mở khoá thất bại ⇒ KHÔNG gọi approve', (
      tester,
    ) async {
      final log = await pump(tester, unlock: () async => false);
      await tester.tap(find.byKey(const Key('tsu-xd-allow')));
      await tester.pumpAndSettle();
      expect(log.where((r) => r.url.path.endsWith('/approve')), isEmpty);
      expect(find.textContaining('Chưa mở khoá được'), findsOneWidget);
    });

    testWidgets('mở khoá xong ⇒ hiện mã khớp + dòng cảnh báo hỏi mã', (
      tester,
    ) async {
      var unlocked = 0;
      final log = await pump(
        tester,
        unlock: () async {
          unlocked++;
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('tsu-xd-allow')));
      await tester.pump();
      await tester.pump();
      expect(unlocked, 1);
      expect(log.where((r) => r.url.path.endsWith('/approve')), hasLength(1));
      expect(find.text('K7QF-M2XD'), findsOneWidget);
      expect(
        find.textContaining('tsudev không bao giờ hỏi mã này'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Từ chối ⇒ gọi deny, không mở khoá', (tester) async {
      var unlocked = false;
      final log = await pump(
        tester,
        unlock: () async {
          unlocked = true;
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('tsu-xd-deny')));
      await tester.pumpAndSettle();
      expect(unlocked, isFalse);
      expect(log.last.url.path, '/api/xd/deny');
      expect(find.text('Đã từ chối yêu cầu đăng nhập.'), findsOneWidget);
    });

    testWidgets('QR đã dùng ⇒ thông điệp chuẩn 6.4', (tester) async {
      await pump(
        tester,
        unlock: () async => true,
        replies: {
          'scan': (410, {'error': 'used_or_expired'}),
        },
      );
      expect(
        find.text('Mã QR này đã được dùng. Tạo mã mới trên thiết bị kia.'),
        findsOneWidget,
      );
    });
  });
}
