import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

final t0 = DateTime.utc(2026, 11, 26, 8);

SignInReminderConditions cond({
  bool signedIn = false,
  bool online = true,
  bool fullyOfflineMode = false,
  bool atNaturalBreak = true,
  DateTime? appReadyAt,
  bool coreTaskCompleted = false,
  bool otherModalOpen = false,
}) => SignInReminderConditions(
  signedIn: signedIn,
  online: online,
  fullyOfflineMode: fullyOfflineMode,
  atNaturalBreak: atNaturalBreak,
  appReadyAt: appReadyAt ?? t0.subtract(const Duration(minutes: 5)),
  coreTaskCompleted: coreTaskCompleted,
  otherModalOpen: otherModalOpen,
);

void main() {
  group('AUTH_AND_ACCOUNT 14.4.1 - điều kiện R1-R6', () {
    late InMemoryKeyValueStore store;
    late DateTime now;
    late SignInReminderPolicy p;

    setUp(() {
      store = InMemoryKeyValueStore();
      now = t0;
      p = SignInReminderPolicy(store: store, clock: () => now);
    });

    test(
      'đủ điều kiện ⇒ hiện',
      () async => expect(await p.shouldShow(cond()), isTrue),
    );
    test(
      'R1 đã đăng nhập ⇒ không',
      () async => expect(await p.shouldShow(cond(signedIn: true)), isFalse),
    );
    test(
      'R2 không mạng ⇒ không',
      () async => expect(await p.shouldShow(cond(online: false)), isFalse),
    );
    test('R3 ngoại tuyến hoàn toàn ⇒ không', () async {
      expect(await p.shouldShow(cond(fullyOfflineMode: true)), isFalse);
    });
    test(
      'R4 đang tác vụ ⇒ không',
      () async =>
          expect(await p.shouldShow(cond(atNaturalBreak: false)), isFalse),
    );
    test(
      'R5 chưa đủ 30 giây ⇒ không, trừ khi tác vụ lõi đầu đã xong',
      () async {
        final ready = now.subtract(const Duration(seconds: 10));
        expect(await p.shouldShow(cond(appReadyAt: ready)), isFalse);
        expect(
          await p.shouldShow(cond(appReadyAt: ready, coreTaskCompleted: true)),
          isTrue,
        );
      },
    );
    test('R6 modal khác đang mở ⇒ không', () async {
      expect(await p.shouldShow(cond(otherModalOpen: true)), isFalse);
    });
  });

  group('AUTH_AND_ACCOUNT 14.4.2 - nhịp', () {
    late InMemoryKeyValueStore store;
    late DateTime now;
    late SignInReminderPolicy p;

    setUp(() {
      store = InMemoryKeyValueStore();
      now = t0;
      p = SignInReminderPolicy(store: store, clock: () => now);
    });

    /// Mở lại app (phiên chạy mới, cùng kho).
    void coldStart() =>
        p = SignInReminderPolicy(store: store, clock: () => now);

    Future<bool> at(Duration d) async {
      now = t0.add(d);
      coldStart();
      return p.shouldShow(
        cond(appReadyAt: now.subtract(const Duration(minutes: 1))),
      );
    }

    test('một lần mỗi phiên chạy', () async {
      expect(await p.shouldShow(cond()), isTrue);
      await p.record(SignInReminderResult.notNow);
      now = now.add(const Duration(days: 30));
      expect(await p.shouldShow(cond()), isFalse);
    });

    test('Để sau: 24 giờ → 3 ngày → 7 ngày', () async {
      await p.record(SignInReminderResult.notNow); // lần 1 lúc t0
      expect(await at(const Duration(hours: 23)), isFalse);
      expect(await at(const Duration(hours: 24)), isTrue);
      await p.record(SignInReminderResult.notNow); // lần 2 lúc t0+24h
      expect(await at(const Duration(hours: 24 + 71)), isFalse);
      expect(await at(const Duration(hours: 24 + 72)), isTrue);
      await p.record(SignInReminderResult.notNow); // lần 3
      final base = const Duration(hours: 96);
      expect(await at(base + const Duration(days: 6)), isFalse);
      expect(await at(base + const Duration(days: 7)), isTrue);
      await p.record(SignInReminderResult.notNow); // lần 4 - vẫn 7 ngày
      final b2 = base + const Duration(days: 7);
      expect(await at(b2 + const Duration(days: 6)), isFalse);
      expect(await at(b2 + const Duration(days: 7)), isTrue);
    });

    test('Không nhắc trong 30 ngày, rồi nhịp 7 ngày', () async {
      await p.record(SignInReminderResult.snoozed);
      expect(await at(const Duration(days: 29)), isFalse);
      expect(await at(const Duration(days: 30)), isTrue);
      await p.record(SignInReminderResult.notNow);
      expect(await at(const Duration(days: 36)), isFalse);
      expect(await at(const Duration(days: 37)), isTrue);
    });

    test('bấm lối vào rồi bỏ dở ⇒ 24 giờ', () async {
      await p.record(SignInReminderResult.signInStarted);
      expect(await at(const Duration(hours: 23)), isFalse);
      expect(await at(const Duration(hours: 24)), isTrue);
    });

    test('đăng nhập thành công xoá nhịp; đăng xuất ⇒ 24 giờ', () async {
      await p.record(SignInReminderResult.snoozed);
      await p.recordSignedIn();
      expect(store.snapshot, isEmpty);
      await p.recordSignOut();
      expect(await at(const Duration(hours: 23)), isFalse);
      expect(await at(const Duration(hours: 24)), isTrue);
    });

    test('đăng xuất không rút ngắn lần hoãn 30 ngày', () async {
      await p.record(SignInReminderResult.snoozed);
      await p.recordSignOut();
      expect(await at(const Duration(days: 2)), isFalse);
    });

    test('chỉ ghi khoá cục bộ của nhịp', () async {
      await p.record(SignInReminderResult.notNow);
      expect(store.snapshot.keys.toSet(), {
        SignInReminderPolicy.keyNextAt,
        SignInReminderPolicy.keyDismissCount,
      });
      await p.reset();
      expect(store.snapshot, isEmpty);
    });
  });

  group('AUTH_AND_ACCOUNT 14.4.3 - modal', () {
    Future<SignInReminderResult?> open(
      WidgetTester tester, {
      Locale locale = const Locale('vi'),
      List<String>? pressed,
      VoidCallback? onWhy,
      VoidCallback? onScan,
    }) async {
      SignInReminderResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await TsuSignInReminder.show(
                    context,
                    locale: locale,
                    onOpenWhy: onWhy ?? () {},
                    onScanToSignIn: onScan,
                    options: [
                      for (final id in ['google', 'github', 'tsudev'])
                        TsuSignInOption(
                          id: id,
                          label: 'Tiếp tục với $id',
                          icon: const Icon(Icons.login),
                          onPressed: () => pressed?.add(id),
                        ),
                    ],
                  );
                },
                child: const Text('mo'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mo'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('nguyên văn tiếng Việt + tên miền nhận diện, không có ô nhập', (
      tester,
    ) async {
      await open(tester);
      expect(find.text(SignInReminderStrings.vi.title), findsOneWidget);
      expect(find.text(SignInReminderStrings.vi.body), findsOneWidget);
      expect(find.text(SignInReminderStrings.vi.notNow), findsOneWidget);
      expect(find.text(SignInReminderStrings.vi.snooze30), findsOneWidget);
      expect(
        find.textContaining('tsudev.com', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('tiếng Anh', (tester) async {
      await open(tester, locale: const Locale('en'));
      expect(find.text(SignInReminderStrings.en.title), findsOneWidget);
      expect(find.text(SignInReminderStrings.en.notNow), findsOneWidget);
    });

    testWidgets('tiêu điểm đầu ở lối vào chính', (tester) async {
      await open(tester);
      final focused = FocusManager.instance.primaryFocus?.context?.widget;
      expect(focused, isNotNull);
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.autofocus, isTrue);
    });

    Future<SignInReminderResult?> closeWith(
      WidgetTester tester,
      Future<void> Function() action,
    ) async {
      SignInReminderResult? r;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => r = await TsuSignInReminder.show(
                context,
                locale: const Locale('vi'),
                onOpenWhy: () {},
                options: [
                  TsuSignInOption(
                    id: 'google',
                    label: 'G',
                    icon: const Icon(Icons.login),
                    onPressed: () {},
                  ),
                ],
              ),
              child: const Text('mo'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mo'));
      await tester.pumpAndSettle();
      await action();
      await tester.pumpAndSettle();
      expect(find.text(SignInReminderStrings.vi.title), findsNothing);
      return r;
    }

    testWidgets('Esc = Để sau', (tester) async {
      final r = await closeWith(
        tester,
        () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      );
      expect(r, SignInReminderResult.notNow);
    });

    testWidgets('nút X = Để sau', (tester) async {
      final r = await closeWith(
        tester,
        () => tester.tap(find.byIcon(Icons.close)),
      );
      expect(r, SignInReminderResult.notNow);
    });

    testWidgets('chạm ra ngoài = Để sau', (tester) async {
      final r = await closeWith(tester, () => tester.tapAt(const Offset(5, 5)));
      expect(r, SignInReminderResult.notNow);
    });

    testWidgets('Không nhắc trong 30 ngày', (tester) async {
      final r = await closeWith(
        tester,
        () => tester.tap(find.text(SignInReminderStrings.vi.snooze30)),
      );
      expect(r, SignInReminderResult.snoozed);
    });

    testWidgets('bấm lối vào ⇒ đóng modal rồi gọi luồng của app', (
      tester,
    ) async {
      final pressed = <String>[];
      await open(tester, pressed: pressed);
      await tester.tap(find.text('Tiếp tục với github'));
      await tester.pumpAndSettle();
      expect(pressed, ['github']);
      expect(find.text(SignInReminderStrings.vi.title), findsNothing);
    });

    testWidgets('Quét mã QR khi app cung cấp', (tester) async {
      var scanned = false;
      await open(tester, onScan: () => scanned = true);
      await tester.tap(find.text(SignInReminderStrings.vi.scanToSignIn));
      await tester.pumpAndSettle();
      expect(scanned, isTrue);
    });

    testWidgets('maybeShow: không đủ điều kiện ⇒ không hiện, không ghi gì', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      SignInReminderResult? r = SignInReminderResult.snoozed;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => r = await TsuSignInReminder.maybeShow(
                context,
                policy: SignInReminderPolicy(store: store, clock: () => t0),
                conditions: cond(online: false),
                onOpenWhy: () {},
                options: const [],
              ),
              child: const Text('mo'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mo'));
      await tester.pumpAndSettle();
      expect(r, isNull);
      expect(find.text(SignInReminderStrings.vi.title), findsNothing);
      expect(store.snapshot, isEmpty);
    });
  });
}
