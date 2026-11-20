import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

/// Lấy trạng thái quyền lợi qua đúng đường thật: JWS ký → repository → verifier.
Future<EntitlementState> stateFor(
  String jws, {
  required DateTime now,
  bool offline = false,
}) {
  final store = InMemoryKeyValueStore({EntitlementsRepository.cacheKey: jws});
  return EntitlementsRepository(
    verifier: testVerifier(),
    store: store,
    fetchJws: () async =>
        offline ? throw const SocketException('offline') : jws,
    clock: () => now,
  ).refresh();
}

void main() {
  group('PRODUCT_POLICY 7.3 - 5 ca bắt buộc', () {
    late InMemoryKeyValueStore store;
    late DateTime now;
    late ProNoticeController c;

    setUp(() {
      store = InMemoryKeyValueStore();
      now = testNow;
      c = ProNoticeController(store: store, clock: () => now);
    });

    test('1. một thiết bị ⇒ không hiện', () async {
      final s = await stateFor(signerA.sign(claims(devices: 1)), now: now);
      expect(await c.shouldShow(s), isFalse);
    });

    test('2. hai thiết bị ⇒ hiện', () async {
      final s = await stateFor(signerA.sign(claims(devices: 2)), now: now);
      expect(await c.shouldShow(s), isTrue);
    });

    test('3. hiện ngày 0 ⇒ ngày 29 không hiện, ngày 30 hiện lại', () async {
      Future<bool> on(int day) async {
        now = testNow.add(Duration(days: day));
        // JWS mới mỗi lần mở app (sống ≤ 7 ngày).
        final s = await stateFor(
          signerA.sign(claims(iat: now, devices: 2)),
          now: now,
        );
        return c.shouldShow(s);
      }

      expect(await on(0), isTrue);
      await c.markShown();
      expect(
        store.snapshot[ProNoticePolicy.lastShownKey],
        '2026-11-20T00:00:00.000Z',
        reason: 'giờ UTC, ISO 8601',
      );
      expect(await on(29), isFalse);
      expect(await on(30), isTrue);
    });

    test('4. có Pro ⇒ không hiện', () async {
      final s = await stateFor(
        signerA.sign(
          claims(devices: 4, proUntil: now.add(const Duration(days: 10))),
        ),
        now: now,
      );
      expect(await c.shouldShow(s), isFalse);
    });

    test('5. ngoại tuyến, JWS đệm hết hạn ⇒ không hiện, không lỗi', () async {
      final jws = signerA.sign(claims(devices: 3));
      now = testNow.add(const Duration(days: 8));
      final s = await stateFor(jws, now: now, offline: true);
      expect(s.source, EntitlementSource.none);
      expect(await c.shouldShow(s), isFalse);
    });
  });

  group('chu kỳ', () {
    test('mốc hỏng ⇒ coi như chưa hiện; mốc ở tương lai xa ⇒ hiện', () async {
      final s = await stateFor(signerA.sign(claims(devices: 2)), now: testNow);
      final store = InMemoryKeyValueStore({
        ProNoticePolicy.lastShownKey: 'không phải ngày',
      });
      final c = ProNoticeController(store: store, clock: () => testNow);
      expect(await c.shouldShow(s), isTrue);
      await store.write(ProNoticePolicy.lastShownKey, '2027-06-01T00:00:00Z');
      expect(await c.shouldShow(s), isTrue);
    });
  });

  test('nội dung vi/en NGUYÊN VĂN bảng PRODUCT_POLICY 7.3', () {
    final doc = File('.standards/docs/PRODUCT_POLICY.md').readAsStringSync();
    String cell(String row, int col) {
      final line = doc
          .split('\n')
          .firstWhere((l) => l.startsWith('  | $row |'), orElse: () => '');
      expect(line, isNotEmpty, reason: 'không thấy hàng "$row"');
      return line.split('|')[col].trim();
    }

    const vi = ProNoticeStrings.vi;
    const en = ProNoticeStrings.en;
    expect(vi.title, cell('Tiêu đề', 2));
    expect(en.title, cell('Tiêu đề', 3));
    expect(vi.bodyTemplate, cell('Thân', 2));
    expect(en.bodyTemplate, cell('Thân', 3));
    expect(vi.primary, cell('Nút chính', 2));
    expect(en.primary, cell('Nút chính', 3));
    expect(vi.secondary, cell('Nút phụ', 2));
    expect(en.secondary, cell('Nút phụ', 3));
    expect(vi.link, cell('Liên kết', 2));
    expect(en.link, cell('Liên kết', 3));
    expect(vi.body(3), contains('trên 3 thiết bị'));
  });

  test('trang Pro ngoài cửa hàng', () {
    expect(
      proWebUrl('tsuscan').toString(),
      'https://tsudev.com/pro?app=tsuscan',
    );
  });

  group('widget', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required Size size,
      required Widget Function(BuildContext) child,
      double textScale = 1,
      Locale locale = const Locale('vi'),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, w) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: w!,
          ),
          home: Scaffold(body: Builder(builder: child)),
        ),
      );
    }

    testWidgets('maybeShowProNotice: hiện, ghi mốc, nút chính gọi onSeePro', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      final c = ProNoticeController(store: store, clock: () => testNow);
      final s = await tester.runAsync(
        () => stateFor(signerA.sign(claims(devices: 2)), now: testNow),
      );
      var seePro = 0;
      var backup = 0;
      ProNoticeAction? result;
      await pumpHost(
        tester,
        size: const Size(400, 800),
        child: (ctx) => TextButton(
          onPressed: () async => result = await maybeShowProNotice(
            ctx,
            controller: c,
            state: s!,
            onSeePro: () => seePro++,
            onBackupToFile: () => backup++,
          ),
          child: const Text('mở'),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(find.text(ProNoticeStrings.vi.title), findsOneWidget);
      expect(find.text(ProNoticeStrings.vi.body(2)), findsOneWidget);
      expect(store.snapshot[ProNoticePolicy.lastShownKey], isNotNull);
      await tester.tap(find.text('Xem gói Pro'));
      await tester.pumpAndSettle();
      expect(seePro, 1);
      expect(backup, 0);
      expect(result, ProNoticeAction.seePro);

      // Lần hai cùng ngày: không hiện.
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(find.text(ProNoticeStrings.vi.title), findsNothing);
      expect(result, isNull);
    });

    testWidgets('đóng được bằng "Để sau" và chạm ngoài hộp thoại', (
      tester,
    ) async {
      for (final close in ['later', 'barrier']) {
        final c = ProNoticeController(
          store: InMemoryKeyValueStore(),
          clock: () => testNow,
        );
        final s = await tester.runAsync(
          () => stateFor(signerA.sign(claims(devices: 2)), now: testNow),
        );
        ProNoticeAction? result;
        await pumpHost(
          tester,
          size: const Size(400, 800),
          locale: const Locale('en'),
          child: (ctx) => TextButton(
            onPressed: () async => result = await maybeShowProNotice(
              ctx,
              controller: c,
              state: s!,
              onSeePro: () {},
              onBackupToFile: () {},
            ),
            child: const Text('open'),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Your data stays on this device'), findsOneWidget);
        if (close == 'later') {
          await tester.tap(find.text('Not now'));
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ProNoticeDialog), findsNothing);
        expect(
          result,
          close == 'later' ? ProNoticeAction.later : ProNoticeAction.dismissed,
        );
      }
    });

    testWidgets('liên kết "Sao lưu ra tệp (miễn phí)" gọi onBackupToFile', (
      tester,
    ) async {
      final c = ProNoticeController(
        store: InMemoryKeyValueStore(),
        clock: () => testNow,
      );
      final s = await tester.runAsync(
        () => stateFor(signerA.sign(claims(devices: 2)), now: testNow),
      );
      var backup = 0;
      await pumpHost(
        tester,
        size: const Size(400, 800),
        child: (ctx) => TextButton(
          onPressed: () => maybeShowProNotice(
            ctx,
            controller: c,
            state: s!,
            onSeePro: () {},
            onBackupToFile: () => backup++,
          ),
          child: const Text('mở'),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sao lưu ra tệp (miễn phí)'));
      await tester.pumpAndSettle();
      expect(backup, 1);
    });

    for (final (name, size, scale) in [
      ('khổ hẹp 320×568, chữ 200%', const Size(320, 568), 2.0),
      ('khổ hẹp 360×640', const Size(360, 640), 1.0),
      ('khổ rộng 1280×800', const Size(1280, 800), 1.0),
    ]) {
      testWidgets('hộp thoại không tràn: $name', (tester) async {
        for (final locale in const [Locale('vi'), Locale('en')]) {
          await pumpHost(
            tester,
            size: size,
            textScale: scale,
            locale: locale,
            child: (_) => const ProNoticeDialog(devices: 12),
          );
          expect(tester.takeException(), isNull);
          final box = tester.getRect(find.byType(AlertDialog));
          expect(box.width, lessThanOrEqualTo(size.width));
          expect(box.height, lessThanOrEqualTo(size.height));
          // Nút chính luôn chạm tới được (cuộn nếu cần).
          final primary = find.byType(FilledButton);
          await tester.ensureVisible(primary);
          expect(tester.getSize(primary).height, greaterThanOrEqualTo(40));
        }
      });
    }
  });
}
