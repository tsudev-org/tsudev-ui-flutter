import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

void main() {
  group('TsuXdLink.parse (CROSS_DEVICE_LOGIN T9)', () {
    const id = 'AbCdEfGhIjKlMnOpQrStUv';
    const k = 'k1234567890123456789012345678901234567890AB';

    test('nhận đúng hai dạng QR của tsudev', () {
      expect(
        TsuXdLink.parse('https://tsudev.com/x/$id?f=k#$k')?.flow,
        TsuXdFlow.pull,
      );
      expect(
        TsuXdLink.parse('https://tsudev.com/x/$id?f=d#$k')?.flow,
        TsuXdFlow.push,
      );
    });

    test(
      'từ chối tên miền giả, http, cổng, userinfo, đường dẫn lạ, thiếu bí mật',
      () {
        for (final bad in [
          'https://tsudev.com.evil.io/x/$id?f=k#$k',
          'https://evil.io/tsudev.com/x/$id?f=k#$k',
          'http://tsudev.com/x/$id?f=k#$k',
          'https://tsudev.com:444/x/$id?f=k#$k',
          'https://a@tsudev.com/x/$id?f=k#$k',
          'https://tsudev.com/y/$id?f=k#$k',
          'https://tsudev.com/x/$id?f=z#$k',
          'https://tsudev.com/x/$id?f=k&next=https://evil.io#$k',
          'https://tsudev.com/x/$id?f=k',
          'https://tsudev.com/x/short?f=k#$k',
          'không phải url',
        ]) {
          expect(TsuXdLink.parse(bad), isNull, reason: bad);
        }
      },
    );
  });

  group('TsuSignInScreen (AUTH_AND_ACCOUNT 13.2, 13.4)', () {
    Future<List<String>> pump(WidgetTester tester, {String? lastUsed}) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          home: Scaffold(
            body: TsuSignInScreen(
              locale: const Locale('vi'),
              logo: const FlutterLogo(),
              title: 'Chào mừng tới Quly Thu Chi',
              tagline: 'Dữ liệu được mã hoá ngay trên thiết bị.',
              lastUsedId: lastUsed,
              primary: [
                TsuSignInOption(
                  id: 'google',
                  label: 'Tiếp tục với Google',
                  icon: const Icon(Icons.g_mobiledata),
                  onPressed: () => calls.add('google'),
                ),
              ],
              more: [
                TsuSignInOption(
                  id: 'passkey',
                  label: 'Tiếp tục với khoá truy cập',
                  icon: const Icon(Icons.key),
                  onPressed: () => calls.add('passkey'),
                ),
              ],
              onScanToSignIn: () => calls.add('scan'),
              guestLabel: 'Dùng ngay, không cần tài khoản',
              onGuest: () => calls.add('guest'),
              onOpenTerms: () {},
              onOpenPrivacy: () {},
            ),
          ),
        ),
      );
      return calls;
    }

    testWidgets(
      'ô đồng ý không tích sẵn; bấm lối vào ⇒ bảng Đồng ý và tiếp tục ⇒ chạy đúng lối vào',
      (tester) async {
        final calls = await pump(tester);
        final box = tester.widget<CheckboxListTile>(
          find.byKey(const ValueKey('tsu-sign-in-consent')),
        );
        expect(box.value, isFalse);

        await tester.tap(find.byKey(const ValueKey('tsu-sign-in-google')));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        await tester.tap(find.text('Đồng ý và tiếp tục'));
        await tester.pumpAndSettle();
        expect(calls, ['google']);

        // Đã đồng ý ⇒ lối vào khác chạy thẳng.
        await tester.tap(find.byKey(const ValueKey('tsu-sign-in-scan')));
        await tester.pumpAndSettle();
        expect(calls, ['google', 'scan']);
      },
    );

    testWidgets('Huỷ ở bảng đồng ý ⇒ không chạy lối vào', (tester) async {
      final calls = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('tsu-sign-in-passkey')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('chế độ khách không bắt tích ô; nhãn "Lần trước" đúng nút', (
      tester,
    ) async {
      final calls = await pump(tester, lastUsed: 'google');
      expect(find.text('Lần trước bạn dùng cách này'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('tsu-sign-in-guest')),
      );
      await tester.tap(find.byKey(const ValueKey('tsu-sign-in-guest')));
      await tester.pumpAndSettle();
      expect(calls, ['guest']);
    });
  });
}
