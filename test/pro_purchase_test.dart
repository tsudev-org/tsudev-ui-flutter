import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

Widget host(Widget child, {Locale locale = const Locale('vi')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('vi'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

/// Đọc nguyên văn một đoạn trích của bộ quy ước nếu có bản sao cạnh repo.
String? standardsPolicy() {
  for (final p in [
    '../tsudev-standards/tsudev-standards/docs/PRODUCT_POLICY.md',
    '.standards/docs/PRODUCT_POLICY.md',
  ]) {
    final f = File(p);
    if (f.existsSync()) {
      final t = f.readAsStringSync();
      if (t.contains('3.7.3')) return t.replaceAll(RegExp(r'\s+'), ' ');
    }
  }
  return null;
}

void main() {
  group('PRODUCT_POLICY 3.7.3 - màn mua', () {
    late int bought;
    late int policy;
    late int terms;

    Widget sheet({
      Set<ProBenefit> benefits = const {ProBenefit.badge, ProBenefit.proTheme},
    }) => ProPurchaseSheet(
      benefits: benefits,
      price: '490.000 ₫',
      onOpenPaymentPolicy: () => policy++,
      onOpenTerms: () => terms++,
      onPurchase: () => bought++,
    );

    setUp(() => bought = policy = terms = 0);

    testWidgets('ô xác nhận không chọn sẵn, nút mua vô hiệu tới khi đánh dấu', (
      tester,
    ) async {
      await tester.pumpWidget(host(sheet()));
      final box = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('tsu-pro-confirm')),
      );
      expect(box.value, isFalse);
      final buy = find.byKey(const ValueKey('tsu-pro-buy'));
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
      await tester.tap(buy);
      expect(bought, 0);

      await tester.tap(find.byKey(const ValueKey('tsu-pro-confirm')));
      await tester.pump();
      expect(tester.widget<FilledButton>(buy).onPressed, isNotNull);
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      expect(bought, 1);

      // Bỏ đánh dấu ⇒ vô hiệu lại.
      await tester.ensureVisible(find.byKey(const ValueKey('tsu-pro-confirm')));
      await tester.tap(find.byKey(const ValueKey('tsu-pro-confirm')));
      await tester.pump();
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
    });

    testWidgets(
      'thứ tự: định vị → quyền lợi → điều khoản → ô xác nhận → nút mua',
      (tester) async {
        await tester.pumpWidget(host(sheet()));
        double y(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
        final order = [
          y('tsu-pro-positioning'),
          y('tsu-pro-benefit-badge'),
          y('tsu-pro-benefit-proTheme'),
          y('tsu-pro-terms'),
          y('tsu-pro-payment-policy'),
          y('tsu-pro-confirm'),
          y('tsu-pro-buy'),
        ];
        expect(order, List.of(order)..sort());
      },
    );

    testWidgets('chỉ hiện quyền lợi được truyền, theo thứ tự Q1 → Q2', (
      tester,
    ) async {
      await tester.pumpWidget(host(sheet(benefits: {ProBenefit.badge})));
      expect(
        find.byKey(const ValueKey('tsu-pro-benefit-proTheme')),
        findsNothing,
      );
      expect(find.text(ProPurchaseStrings.vi.proTheme), findsNothing);
      await tester.pumpWidget(
        host(sheet(benefits: {ProBenefit.proTheme, ProBenefit.badge})),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('tsu-pro-benefit-badge')))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('tsu-pro-benefit-proTheme')),
              )
              .dy,
        ),
      );
    });

    testWidgets(
      'điều khoản 7.5 có giá; liên kết chính sách + điều khoản bấm được',
      (tester) async {
        await tester.pumpWidget(host(sheet()));
        expect(
          find.text(ProPurchaseStrings.vi.termsFor('490.000 ₫')),
          findsOneWidget,
        );
        expect(
          ProPurchaseStrings.vi.termsFor('490.000 ₫'),
          startsWith('TsuDEV Pro 490.000 ₫ cho 1 năm, KHÔNG tự gia hạn.'),
        );
        await tester.tap(find.byKey(const ValueKey('tsu-pro-payment-policy')));
        await tester.tap(find.byKey(const ValueKey('tsu-pro-terms-link')));
        expect((policy, terms), (1, 1));
      },
    );

    testWidgets('tiếng Anh', (tester) async {
      await tester.pumpWidget(host(sheet(), locale: const Locale('en')));
      expect(find.text(ProPurchaseStrings.en.positioning), findsOneWidget);
      expect(find.text(ProPurchaseStrings.en.confirm), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('showProPurchaseSheet: Đóng ⇒ false; xác nhận + mua ⇒ true', (
      tester,
    ) async {
      final results = <bool>[];
      await tester.pumpWidget(
        host(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => results.add(
                await showProPurchaseSheet(
                  ctx,
                  benefits: const {ProBenefit.badge},
                  price: '490.000 ₫',
                  onOpenPaymentPolicy: () {},
                  onOpenTerms: () {},
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tsu-pro-confirm')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('tsu-pro-buy')));
      await tester.tap(find.byKey(const ValueKey('tsu-pro-buy')));
      await tester.pumpAndSettle();
      expect(results, [false, true]);
    });
  });

  group('nội dung khớp bộ quy ước', () {
    const banned = [
      'phi lợi nhuận',
      'non-profit',
      'nonprofit',
      'từ thiện',
      'tax-deductible',
      'khấu trừ thuế',
      'Đã xác minh',
      'verified',
    ];
    final all = [ProPurchaseStrings.vi, ProPurchaseStrings.en];

    test('không chữ cấm (3.7.4, 3.7.1)', () {
      for (final s in all) {
        final text = [
          s.positioning,
          s.badge,
          s.proTheme,
          s.termsTemplate,
          s.confirm,
          s.buy,
        ].join(' ').toLowerCase();
        for (final w in banned) {
          expect(text, isNot(contains(w.toLowerCase())), reason: w);
        }
      }
    });

    test('câu định vị, ô xác nhận, điều khoản 7.5 nguyên văn', () {
      final policy = standardsPolicy();
      if (policy == null) {
        markTestSkipped('không có bản sao bộ quy ước v6.1.0+ cạnh repo');
        return;
      }
      for (final s in all) {
        for (final t in [s.positioning, s.confirm, s.termsTemplate]) {
          final needle = t.replaceAll(RegExp(r'\s+'), ' ');
          expect(policy, contains(needle), reason: t);
        }
      }
    });
  });
}
