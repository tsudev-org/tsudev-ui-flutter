import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

import 'support/jws_fixture.dart';

/// Trạng thái quyền lợi qua đúng đường thật: JWS ký → repository → verifier.
/// JWS mới mỗi lần mở app (`iat` = [now], sống 7 ngày).
Future<EntitlementState> stateAt(
  DateTime now, {
  DateTime? proUntil,
  bool offline = false,
  String? cachedJws,
}) {
  final jws = cachedJws ?? signerA.sign(claims(iat: now, proUntil: proUntil));
  return EntitlementsRepository(
    verifier: testVerifier(),
    store: InMemoryKeyValueStore({EntitlementsRepository.cacheKey: jws}),
    fetchJws: () async =>
        offline ? throw const SocketException('offline') : jws,
    clock: () => now,
  ).refresh();
}

void main() {
  group('PRODUCT_POLICY 7.6 - 6 ca bắt buộc', () {
    late InMemoryKeyValueStore store;
    late DateTime now;
    late ProRenewalController c;

    setUp(() {
      store = InMemoryKeyValueStore();
      now = testNow;
      c = ProRenewalController(store: store, clock: () => now);
    });

    /// Mở app lại (tiến trình mới): controller mới, cùng kho.
    void coldStart() =>
        c = ProRenewalController(store: store, clock: () => now);

    test('1. còn 8 ngày ⇒ không nhắc', () async {
      final s = await stateAt(now, proUntil: now.add(const Duration(days: 8)));
      expect(await c.check(s), isNull);
    });

    test('2. còn 7 ngày ⇒ nhắc, {n} = 7', () async {
      final until = now.add(const Duration(days: 7));
      final d = await c.check(await stateAt(now, proUntil: until));
      expect(d, ProRenewalDecision.reminder(proUntil: until, daysLeft: 7));
    });

    test('3. mở app 2 lần trong 7 ngày cuối ⇒ nhắc 2 lần; quay lại < 30 phút ⇒ không', () async {
      final until = testNow.add(const Duration(days: 5));
      Future<ProRenewalDecision?> check() async =>
          c.check(await stateAt(now, proUntil: until));

      // Lần mở 1 (khởi động mới).
      final d1 = await check();
      expect(d1?.kind, ProRenewalKind.reminder);
      await c.markShown(d1!);
      expect(await check(), isNull, reason: 'tối đa 1 lần mỗi lần mở');

      // Vào nền 29 phút rồi quay lại ⇒ cùng lần mở.
      c.handleAppLifecycleState(AppLifecycleState.hidden);
      c.handleAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 29, seconds: 59));
      c.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(await check(), isNull);

      // Vào nền đúng 30 phút ⇒ lần mở 2.
      c.handleAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 30));
      c.handleAppLifecycleState(AppLifecycleState.resumed);
      final d2 = await check();
      expect(d2?.kind, ProRenewalKind.reminder);
      await c.markShown(d2!);

      // Hôm sau khởi động mới ⇒ lần mở 3, {n} giảm.
      now = now.add(const Duration(days: 1));
      coldStart();
      expect((await check())?.daysLeft, 4);
    });

    test('4. hết hạn ⇒ báo hết kỳ đúng một lần; mở lại ⇒ không báo', () async {
      final until = testNow.add(const Duration(days: 3));
      // Thiết bị từng thấy Pro còn hạn.
      final active = await c.check(await stateAt(now, proUntil: until));
      expect(active?.kind, ProRenewalKind.reminder);

      now = until.add(const Duration(hours: 1));
      coldStart();
      final d = await c.check(await stateAt(now, proUntil: until));
      expect(d, ProRenewalDecision.expired(proUntil: until));
      await c.markShown(d!);
      expect(
        store.snapshot[ProRenewalPolicy.notifiedUntilKey],
        '${secs(until)}',
        reason: 'giây Unix của pro_until đã báo',
      );

      expect(await c.check(await stateAt(now, proUntil: until)), isNull);
      now = now.add(const Duration(days: 2));
      coldStart();
      expect(await c.check(await stateAt(now, proUntil: until)), isNull);
    });

    test('5. gia hạn ⇒ thôi nhắc; lần hết kỳ sau báo lại', () async {
      final first = testNow.add(const Duration(days: 2));
      expect(
        (await c.check(await stateAt(now, proUntil: first)))?.kind,
        ProRenewalKind.reminder,
      );

      // Hết kỳ 1, báo.
      now = first.add(const Duration(days: 1));
      coldStart();
      final e1 = await c.check(await stateAt(now, proUntil: first));
      expect(e1?.kind, ProRenewalKind.expired);
      await c.markShown(e1!);

      // Gia hạn 1 năm: JWS mới có pro_until xa hơn ⇒ không nhắc, không báo.
      final second = first.add(const Duration(days: 365));
      coldStart();
      expect(await c.check(await stateAt(now, proUntil: second)), isNull);

      // Gia hạn ngay trong 7 ngày cuối cũng thôi nhắc.
      now = second.subtract(const Duration(days: 3));
      coldStart();
      expect(
        (await c.check(await stateAt(now, proUntil: second)))?.kind,
        ProRenewalKind.reminder,
      );
      coldStart();
      expect(
        await c.check(
          await stateAt(now, proUntil: second.add(const Duration(days: 365))),
        ),
        isNull,
      );

      // Không gia hạn tiếp ⇒ hết kỳ 2 báo lại (khác pro_until đã báo).
      now = second.add(const Duration(hours: 2));
      coldStart();
      final e2 = await c.check(await stateAt(now, proUntil: second));
      expect(e2, ProRenewalDecision.expired(proUntil: second));
    });

    test('6. ngoại tuyến với JWS hết hạn ⇒ không nhắc, không lỗi', () async {
      final until = testNow.add(const Duration(days: 3));
      final old = signerA.sign(claims(iat: testNow, proUntil: until));
      expect(
        (await c.check(await stateAt(now, cachedJws: old)))?.kind,
        ProRenewalKind.reminder,
      );
      // 8 ngày sau, ngoại tuyến: JWS đệm quá exp ⇒ miễn phí, không hiện gì
      // (kể cả báo hết kỳ - không có JWS còn hạn).
      now = testNow.add(const Duration(days: 8));
      coldStart();
      final s = await stateAt(now, cachedJws: old, offline: true);
      expect(s.source, EntitlementSource.none);
      expect(await c.check(s), isNull);
    });
  });

  group('điều kiện phụ', () {
    test('chưa từng có Pro (pro_until = 0) ⇒ không gì', () async {
      final c = ProRenewalController(
        store: InMemoryKeyValueStore(),
        clock: () => testNow,
      );
      expect(await c.check(await stateAt(testNow)), isNull);
    });

    test('thiết bị chưa từng thấy Pro còn hạn ⇒ không báo hết kỳ', () async {
      final c = ProRenewalController(
        store: InMemoryKeyValueStore(),
        clock: () => testNow,
      );
      final s = await stateAt(
        testNow,
        proUntil: testNow.subtract(const Duration(days: 30)),
      );
      expect(await c.check(s), isNull);
    });

    test('{n} làm tròn lên, ≥ 1', () {
      final until = testNow.add(const Duration(days: 7));
      expect(ProRenewalPolicy.daysLeft(until, testNow), 7);
      expect(
        ProRenewalPolicy.daysLeft(
          until,
          testNow.add(const Duration(seconds: 1)),
        ),
        7,
      );
      expect(
        ProRenewalPolicy.daysLeft(
          until,
          until.subtract(const Duration(seconds: 1)),
        ),
        1,
      );
      expect(
        ProRenewalPolicy.daysLeft(
          until,
          testNow.add(const Duration(days: 6, hours: 1)),
        ),
        1,
      );
    });

    test('vào nền rồi inactive/detached không tính là lần mở mới', () {
      var now = testNow;
      final c = ProRenewalController(
        store: InMemoryKeyValueStore(),
        clock: () => now,
      );
      c.markShown(ProRenewalDecision.reminder(proUntil: now, daysLeft: 1));
      expect(c.openPending, isFalse);
      c.handleAppLifecycleState(AppLifecycleState.inactive);
      now = now.add(const Duration(hours: 2));
      c.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(c.openPending, isFalse, reason: 'inactive không phải vào nền');
    });
  });

  group('nội dung NGUYÊN VĂN PRODUCT_POLICY 7.6', () {
    final doc = File('.standards/docs/PRODUCT_POLICY.md').readAsStringSync();
    final start = doc.indexOf('### 7.6.');
    final end = doc.indexOf('\n## 8.', start);
    final section = doc.substring(start, end);
    final split = section.indexOf('**Khi hết kỳ**');
    final tables = {
      'nhắc': section.substring(0, split),
      'hết kỳ': section.substring(split),
    };

    String cell(String table, String row, int col) {
      final line = tables[table]!
          .split('\n')
          .firstWhere((l) => l.startsWith('  | $row |'), orElse: () => '');
      expect(line, isNotEmpty, reason: 'không thấy hàng "$row" ($table)');
      return line.split('|')[col].trim();
    }

    for (final (table, vi, en) in [
      ('nhắc', ProRenewalStrings.reminderVi, ProRenewalStrings.reminderEn),
      ('hết kỳ', ProRenewalStrings.expiredVi, ProRenewalStrings.expiredEn),
    ]) {
      test('bảng $table', () {
        expect(start, greaterThan(0));
        expect(vi.title, cell(table, 'Tiêu đề', 2));
        expect(en.title, cell(table, 'Tiêu đề', 3));
        expect(vi.bodyTemplate, cell(table, 'Thân', 2));
        expect(en.bodyTemplate, cell(table, 'Thân', 3));
        expect(vi.primary, cell(table, 'Nút chính', 2));
        expect(en.primary, cell(table, 'Nút chính', 3));
        expect(vi.secondary, cell(table, 'Nút phụ', 2));
        expect(en.secondary, cell(table, 'Nút phụ', 3));
      });
    }

    test('điền {n}, ngày; bỏ câu đám mây khi sản phẩm không đồng bộ', () {
      expect(
        ProRenewalStrings.reminderVi.body(days: 3, date: '27/11/2026'),
        startsWith(
          'Gói TsuDEV Pro của bạn hết hạn sau 3 ngày (ngày 27/11/2026). ',
        ),
      );
      expect(
        ProRenewalStrings.reminderEn.body(days: 3, date: 'November 27, 2026'),
        startsWith('Your TsuDEV Pro expires in 3 days (on November 27, 2026).'),
      );
      expect(
        ProRenewalStrings.expiredVi.body(),
        'Tài khoản đã trở về bản miễn phí: huy hiệu và giao diện Pro đã tắt. '
        'Mọi tính năng và dữ liệu trên thiết bị vẫn giữ nguyên.',
      );
      expect(
        ProRenewalStrings.expiredEn.body(),
        endsWith('All features and data on your devices stay intact.'),
      );
      for (final s in [
        ProRenewalStrings.reminderVi,
        ProRenewalStrings.reminderEn,
        ProRenewalStrings.expiredVi,
        ProRenewalStrings.expiredEn,
      ]) {
        expect(s.bodyTemplate.toLowerCase(), isNot(contains('đám mây')));
        expect(s.bodyTemplate.toLowerCase(), isNot(contains('cloud')));
      }
    });

    test('ngày: vi DD/MM/YYYY, en theo ngôn ngữ', () {
      final d = DateTime(2027, 2, 5, 23, 59);
      expect(formatProRenewalDate(d, const Locale('vi')), '05/02/2027');
      expect(formatProRenewalDate(d, const Locale('en')), 'February 5, 2027');
    });
  });

  group('widget', () {
    // Giữa trưa UTC ⇒ ngày theo giờ máy không đổi ở mọi múi giờ ±11 giờ.
    final until = DateTime.utc(2026, 11, 26, 12);
    final reminder = ProRenewalDecision.reminder(proUntil: until, daysLeft: 7);
    final expired = ProRenewalDecision.expired(proUntil: until);

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

    testWidgets(
      'maybeShowProRenewal: nhắc, "Gia hạn" gọi onRenew, 1 lần/lần mở',
      (tester) async {
        final store = InMemoryKeyValueStore();
        final c = ProRenewalController(store: store, clock: () => testNow);
        final s = await tester.runAsync(
          () => stateAt(testNow, proUntil: until),
        );
        var renew = 0;
        ProRenewalAction? result;
        await pumpHost(
          tester,
          size: const Size(400, 800),
          child: (ctx) => TextButton(
            onPressed: () async => result = await maybeShowProRenewal(
              ctx,
              controller: c,
              state: s!,
              onRenew: () => renew++,
            ),
            child: const Text('mở'),
          ),
        );
        await tester.tap(find.text('mở'));
        await tester.pumpAndSettle();
        expect(find.text('Gia hạn TsuDEV Pro'), findsOneWidget);
        expect(
          find.textContaining('hết hạn sau 7 ngày (ngày 26/11/2026)'),
          findsOneWidget,
        );
        await tester.tap(find.text('Gia hạn'));
        await tester.pumpAndSettle();
        expect(renew, 1);
        expect(result, ProRenewalAction.renew);

        await tester.tap(find.text('mở'));
        await tester.pumpAndSettle();
        expect(find.byType(ProRenewalDialog), findsNothing);
        expect(result, isNull);
      },
    );

    testWidgets('báo hết kỳ (en): "Close" và chạm ngoài đều đóng được', (
      tester,
    ) async {
      for (final close in ['close', 'barrier']) {
        final store = InMemoryKeyValueStore({
          ProRenewalPolicy.seenProUntilKey: '${secs(until)}',
        });
        final now = until.add(const Duration(days: 1));
        final c = ProRenewalController(store: store, clock: () => now);
        final s = await tester.runAsync(() => stateAt(now, proUntil: until));
        ProRenewalAction? result;
        await pumpHost(
          tester,
          size: const Size(400, 800),
          locale: const Locale('en'),
          child: (ctx) => TextButton(
            onPressed: () async => result = await maybeShowProRenewal(
              ctx,
              controller: c,
              state: s!,
              onRenew: () {},
            ),
            child: const Text('open'),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('TsuDEV Pro has expired'), findsOneWidget);
        expect(
          find.textContaining(
            'All features and data on your devices stay intact.',
          ),
          findsOneWidget,
        );
        if (close == 'close') {
          await tester.tap(find.text('Close'));
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ProRenewalDialog), findsNothing);
        expect(
          result,
          close == 'close'
              ? ProRenewalAction.later
              : ProRenewalAction.dismissed,
        );
        expect(
          store.snapshot[ProRenewalPolicy.notifiedUntilKey],
          '${secs(until)}',
        );
      }
    });

    testWidgets('đang nhập liệu ⇒ không chen, không tiêu lượt', (tester) async {
      final c = ProRenewalController(
        store: InMemoryKeyValueStore(),
        clock: () => testNow,
      );
      final s = await tester.runAsync(() => stateAt(testNow, proUntil: until));
      ProRenewalAction? result;
      late BuildContext host;
      await pumpHost(
        tester,
        size: const Size(400, 800),
        child: (ctx) {
          host = ctx;
          return const TextField();
        },
      );
      await tester.showKeyboard(find.byType(TextField));
      result = await maybeShowProRenewal(
        host,
        controller: c,
        state: s!,
        onRenew: () {},
      );
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(ProRenewalDialog), findsNothing);
      expect(c.openPending, isTrue);
    });

    for (final (name, size, scale) in [
      ('khổ hẹp 320×568, chữ 200%', const Size(320, 568), 2.0),
      ('khổ hẹp 360×640', const Size(360, 640), 1.0),
      ('khổ rộng 1280×800', const Size(1280, 800), 1.0),
    ]) {
      testWidgets('hộp thoại không tràn: $name', (tester) async {
        for (final d in [reminder, expired]) {
          for (final locale in const [Locale('vi'), Locale('en')]) {
            await pumpHost(
              tester,
              size: size,
              textScale: scale,
              locale: locale,
              child: (_) => ProRenewalDialog(decision: d),
            );
            expect(tester.takeException(), isNull);
            final box = tester.getRect(find.byType(AlertDialog));
            expect(box.width, lessThanOrEqualTo(size.width));
            expect(box.height, lessThanOrEqualTo(size.height));
            final primary = find.byType(FilledButton);
            await tester.ensureVisible(primary);
            expect(tester.getSize(primary).height, greaterThanOrEqualTo(40));
          }
        }
      });
    }
  });
}
