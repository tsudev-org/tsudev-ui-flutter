# tsudev-ui-flutter - gói `tsudev_ui`

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/16948/badge)](https://www.bestpractices.dev/projects/16948)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/tsudev-org/tsudev-ui-flutter/badge)](https://scorecard.dev/viewer/?uri=github.com/tsudev-org/tsudev-ui-flutter)

Thành phần dùng chung của hệ TsuDEV cho Flutter, viết một lần để mọi app Flutter (qulythuchi, tsuscan, sound-db,
app-la-ban, lotus-share) dùng đúng một bản:

| Thành phần | Theo | Việc |
| --- | --- | --- |
| `TsuBadge`, `TsuNameWithBadge` | PRODUCT_POLICY 4.2, `assets/badges/` | Huy hiệu Pro / Ủng hộ cạnh tên: 0,75 × dòng (16-20 px), shimmer 7 giây, tim đập khi rê/chạm, tắt khi Giảm chuyển động, nhãn đọc màn hình vi/en |
| `ProNotice*`, `maybeShowProNotice` | PRODUCT_POLICY 7.3 | Hộp thoại "nhiều thiết bị chưa có Pro": chữ nguyên văn vi/en, chu kỳ 30 ngày ở `tsu.pro_notice.last_shown` |
| `ProRenewal*`, `maybeShowProRenewal` | PRODUCT_POLICY 7.6 | Nhắc gia hạn 7 ngày cuối (mỗi lần mở app) + báo hết kỳ một lần mỗi `pro_until`: chữ nguyên văn vi/en |
| `ProPurchaseSheet`, `showProPurchaseSheet`, `ProBenefit` | PRODUCT_POLICY 3.7.3, 7.5 | Màn mua Pro: câu định vị nguyên văn → quyền lợi đang chạy thật (Q1-Q3) → điều khoản 7.5 + liên kết Chính sách thanh toán / Điều khoản → ô xác nhận KHÔNG chọn sẵn; nút mua vô hiệu tới khi đánh dấu; vi/en |
| `EntitlementVerifier`, `EntitlementsRepository`, `DiscoveryJwks`, `TsudevEntitlementsApi` | PRODUCT_POLICY 7.4 | Kiểm JWS quyền lợi ES256 bằng JWKS (`iss`, `aud`, `exp`, `typ`, `cnf.jkt`), đệm ≤ 7 ngày, hết hạn ⇒ miễn phí; `jwsForServer()` cho máy chủ đồng bộ (`iat` ≤ 24 giờ, thử lại khi `401 stale`) |
| `DpopSigner`, `DpopKey`, `SoftwareDpopKey` | PRODUCT_POLICY 7.4, RFC 9449/7638 | Bằng chứng DPoP bằng khoá P-256 riêng mỗi cài đặt; thumbprint `cnf.jkt` |
| `InstallationId` | AUTH_AND_ACCOUNT 14.3 | Mã cài đặt ngẫu nhiên 128 bit, base64url 22 ký tự, header `X-Tsu-Installation` |

Giấy phép: **AGPL-3.0-only** (như bộ hệ TsuDEV). Bộ quy ước: `.standards-version` (v4.0.0).

## Cài

Không đăng pub.dev. Ghim tag trong `pubspec.yaml` của app:

```yaml
dependencies:
  tsudev_ui:
    git:
      url: https://github.com/tsudev-org/tsudev-ui-flutter.git
      ref: v0.5.0
```

## Dùng

```dart
import 'package:http/http.dart' as http;
import 'package:tsudev_ui/tsudev_ui.dart';

// 1. Nối kho cài đặt của app (ví dụ shared_preferences) vào TsuKeyValueStore.
final TsuKeyValueStore store = MyPrefsStore();

// 2. Quyền lợi: lấy JWS khi mở app / đăng nhập; lỗi mạng ⇒ tự rơi về đệm còn hạn, hết hạn ⇒ miễn phí.
final client = http.Client();
final repo = EntitlementsRepository(
  verifier: EntitlementVerifier(
    clientId: 'qulythuchi-app',
    jwks: DiscoveryJwks(client: client, store: store),
  ),
  store: store,
  fetchJws: TsudevEntitlementsApi(
    client: client,
    accessToken: () => auth.accessToken(),          // scope tsudev.entitlements
    installationId: () => InstallationId.getOrCreate(store),
  ).fetch,
);
final state = await repo.refresh();                  // chỉ gọi khi ĐÃ đăng nhập
final isPro = state.isPro(DateTime.now());           // chỉ để ẩn/hiện nút; máy chủ tự kiểm (N4)

// 3. Huy hiệu cạnh tên: tên tự cắt "…", huy hiệu giữ nguyên.
TsuNameWithBadge(name: user.displayName, badge: state.badge, style: theme.textTheme.titleMedium);

// 4. Ở màn chính sau khi mở app (KHÔNG giữa lúc nhập liệu):
await maybeShowProNotice(
  context,
  controller: ProNoticeController(store: store),
  state: state,
  onSeePro: () => isPlayBuild ? startPlayBilling() : launchUrl(proWebUrl('qulythuchi-app')),
  onBackupToFile: openBackupToFile,
);

// 5. Nhắc gia hạn / báo hết kỳ (7.6): MỘT controller cho cả tiến trình, nối vòng đời app.
final renewal = ProRenewalController(store: store);
final lifecycle = AppLifecycleListener(onStateChange: renewal.handleAppLifecycleState);
// Mỗi lần mở app / quay lại (sau khi refresh quyền lợi):
await maybeShowProRenewal(
  context,
  controller: renewal,
  state: state,
  onRenew: () => isPlayBuild ? startPlayBilling('tsudev_pro', 'nam') : launchUrl(proWebUrl('qulythuchi-app')),
  hasCloudSync: true,                                 // app không có đồng bộ đám mây ⇒ false (bỏ câu cuối)
);

// 6. Màn mua Pro (3.7.3) - chỉ mở từ Tài khoản/Cài đặt, Giới thiệu, hoặc nút của hộp thoại 7.3/7.6.
if (await showProPurchaseSheet(
  context,
  benefits: {ProBenefit.badge, ProBenefit.cloudSync},   // CHỈ quyền lợi đang chạy thật trong app
  price: isPlayBuild ? playPrice : '490.000 ₫',          // web: giá đã gồm thuế; Play: giá cửa hàng trả về
  onOpenPaymentPolicy: () => launchUrl(Uri.parse('https://tsudev.com/chinh-sach-thanh-toan')),
  onOpenTerms: () => launchUrl(Uri.parse('https://tsudev.com/terms')),
)) {
  isPlayBuild ? startPlayBilling('tsudev_pro', 'nam') : launchUrl(proWebUrl('qulythuchi-app'));
}
```

### DPoP và JWS cho máy chủ đồng bộ

```dart
// Khoá P-256 của cài đặt này. Tốt nhất: cài DpopKey bằng kho khoá phần cứng (Keystore/Secure Enclave);
// dự phòng: SoftwareDpopKey lưu trong kho BÍ MẬT của hệ điều hành (không phải shared_preferences).
final dpop = DpopSigner(await SoftwareDpopKey.getOrCreate(secureStore));
final api = TsudevEntitlementsApi(client: client, accessToken: ..., installationId: ..., dpop: dpop);
final repo = EntitlementsRepository(verifier: ..., store: store, fetchJws: api.fetch, dpop: dpop);

// Gọi TsuDEV Sync / máy chủ sản phẩm nhận JWS làm thẻ: JWS > 23 giờ tự lấy mới; 401 stale ⇒ lấy mới, thử lại 1 lần.
final url = Uri.parse('https://sync.tsudev.com/v1/list');
final res = await repo.sendWithServerJws(
  (jws) async => client.get(url, headers: await repo.serverAuthHeaders(jws, 'GET', url)),
);
if (res == null) { /* chưa có JWS dùng được: hoãn đồng bộ */ }
else if (res.statusCode == 402) { /* pro_required: hiện màn Pro, không thử lại */ }
```

- Bản Google Play: `onSeePro` `MUST` mở Play Billing, `MUST NOT` mở trang thanh toán web (PRODUCT_POLICY 4.3).
- Đăng xuất và xoá dữ liệu cục bộ: `repo.clear()` + `InstallationId.clear(store)`.
- Khoá lưu cục bộ: `tsu.installation_id`, `tsu.entitlements.jws`, `tsu.entitlements.jwks`, `tsu.pro_notice.last_shown`,
  `tsu.pro_expired.notified_until` (7.6), `tsu.pro_renewal.seen_pro_until` (nội bộ: thiết bị từng thấy Pro còn hạn);
  kho bí mật: `tsu.dpop.key` (chỉ khi dùng `SoftwareDpopKey`).

### Màn đăng nhập thống nhất + quét QR (từ v0.4.0)

```dart
TsuSignInScreen(
  logo: Image.asset('assets/brand/logo.png'),
  title: 'Chào mừng tới Quly Thu Chi',
  tagline: 'Dữ liệu được mã hoá ngay trên thiết bị.',
  primary: [googleOption, githubOption, tsudevEmailOption], // chỉ lối vào IdP đang bật
  more: [passkeyOption],
  lastUsedId: prefs.lastSignIn,
  onScanToSignIn: () async {
    final link = TsuXdLink.parse(await scanQr()); // null ⇒ "Mã QR này không phải của tsudev."
    if (link != null) await openInSystemBrowser(link.uri); // rồi bắt đầu đăng nhập OIDC như thường
  },
  guestLabel: 'Dùng ngay, không cần tài khoản',
  onGuest: startGuest,
  onOpenTerms: () => launch('https://tsudev.com/terms'),
  onOpenPrivacy: () => launch('https://tsudev.com/privacy'),
);
```

### Xác nhận đăng nhập máy khác bằng QR - vai xác nhận Đ2 (từ v0.5.0)

App ĐÃ đăng nhập quét QR ở màn đăng nhập tsudev.com trên máy tính. Client OIDC của app cần scope `tsudev.xd` (xin IdP
cấp - phiếu điều phối) và app xin scope đó lúc đăng nhập.

```dart
final link = TsuXdLink.parse(await scanQr());
if (link == null) return showError('Mã QR này không phải của tsudev.');
if (link.flow == TsuXdFlow.push) return openInSystemBrowser(link.uri); // Đ1: app là thiết bị mới
Navigator.push(context, MaterialPageRoute(builder: (_) => TsuXdApproveScreen(
  link: link,
  approver: TsuXdApprover(accessToken: auth.freshAccessToken), // scope tsudev.xd
  unlock: () => appLock.authenticate(reason: 'Xác nhận đăng nhập máy khác'), // BẮT BUỘC (T8)
)));
```

`unlock` trả `true` chỉ khi người dùng mở khoá được (vd. `local_auth` hay khoá ứng dụng sẵn có). Gói không tự kéo
`local_auth`.

### Thanh điều hướng không bị biểu tượng trắng (từ v0.3.0)

```dart
final nav = TsuNavColors(
  background: p.bgSurface,
  indicator: p.primary.withValues(alpha: 0.14),
  selected: p.primary,
  unselected: p.iconNav,
  selectedLabel: p.textPrimary,
  unselectedLabel: p.textSecondary,
); // ném ArgumentError nếu biểu tượng/nền < 3:1
ThemeData(
  colorScheme: tsuCompleteContainers(scheme, accent: p.primary, surface: p.bgSurface, onSurface: p.textPrimary),
  navigationBarTheme: tsuNavigationBarTheme(nav),
  navigationRailTheme: tsuNavigationRailTheme(nav),
);
```

## Phát triển

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test                    # 125 test, gồm golden Sáng/Tối, khổ hẹp/rộng và fuzz bộ kiểm JWS
```

Golden chỉ khớp trên Linux với đúng Flutter ghim trong CI (`3.47.8`); phông Roboto lấy từ Flutter SDK lúc test.
Quyết định thiết kế: [`docs/adr/0001-thu-vien-dung-chung-quyen-loi-huy-hieu.md`](docs/adr/0001-thu-vien-dung-chung-quyen-loi-huy-hieu.md).
Báo lỗ hổng: [`SECURITY.md`](SECURITY.md). Đóng góp: [`CONTRIBUTING.md`](CONTRIBUTING.md). Hồ sơ OpenSSF Best
Practices: [`docs/best-practices.json`](docs/best-practices.json).

## English summary

`tsudev_ui` is the shared Flutter package of the TsuDEV apps (AGPL-3.0-only). It provides:

- **Badges** (`TsuBadge`, `TsuNameWithBadge`): Pro / Supporter badges next to a user name, light/dark, reduced-motion
  aware, with screen reader labels in Vietnamese and English.
- **Pro notices** (`ProNotice*`, `ProRenewal*`): the "several devices without Pro" dialog and the Pro renewal /
  expiry reminders, with the exact policy texts in Vietnamese and English.
- **Pro purchase sheet** (`ProPurchaseSheet`, `showProPurchaseSheet`): every TsuDEV app is free and open source; Pro is
  an optional plan to support the author. The sheet shows the positioning sentence, the benefits that actually work in
  the app, the 1-year non-renewing terms and an unticked confirmation box that enables the buy button.
- **Entitlements** (`EntitlementVerifier`, `EntitlementsRepository`): verifies the ES256-signed entitlement JWS from
  tsudev.com against its JWKS (`iss`, `aud`, `exp`, `typ`, `cnf.jkt`), caches it for at most 7 days and falls back
  to the free tier on any error; `jwsForServer()` for sync servers.
- **DPoP** (`DpopSigner`, RFC 9449 / RFC 7638) with a per-installation P-256 key, and a random 128-bit
  **installation id**.

Install by pinning a git tag in the app's `pubspec.yaml` (see *Cài* above). Build and test with `flutter pub get`,
`flutter analyze --fatal-infos` and `flutter test`; details in [CONTRIBUTING.md](CONTRIBUTING.md). Report
vulnerabilities privately as described in [SECURITY.md](SECURITY.md). Changes are listed in
[CHANGELOG.md](CHANGELOG.md).
