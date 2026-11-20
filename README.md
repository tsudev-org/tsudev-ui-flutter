# tsudev-ui-flutter - gói `tsudev_ui`

Thành phần dùng chung của hệ TsuDEV cho Flutter, viết một lần để mọi app Flutter (qulythuchi, tsuscan, sound-db,
app-la-ban, lotus-share) dùng đúng một bản:

| Thành phần | Theo | Việc |
| --- | --- | --- |
| `TsuBadge`, `TsuNameWithBadge` | PRODUCT_POLICY 4.2, `assets/badges/` | Huy hiệu Pro / Ủng hộ cạnh tên: 0,75 × dòng (16-20 px), shimmer 7 giây, tim đập khi rê/chạm, tắt khi Giảm chuyển động, nhãn đọc màn hình vi/en |
| `ProNotice*`, `maybeShowProNotice` | PRODUCT_POLICY 7.3 | Hộp thoại "nhiều thiết bị chưa có Pro": chữ nguyên văn vi/en, chu kỳ 30 ngày ở `tsu.pro_notice.last_shown` |
| `EntitlementVerifier`, `EntitlementsRepository`, `DiscoveryJwks`, `TsudevEntitlementsApi` | PRODUCT_POLICY 7.4 | Kiểm JWS quyền lợi ES256 bằng JWKS (`iss`, `aud`, `exp`, `typ`), đệm ≤ 7 ngày, hết hạn ⇒ miễn phí |
| `InstallationId` | AUTH_AND_ACCOUNT 14.3 | Mã cài đặt ngẫu nhiên 128 bit, base64url 22 ký tự, header `X-Tsu-Installation` |

Giấy phép: **AGPL-3.0-only** (như bộ hệ TsuDEV). Bộ quy ước: `.standards-version` (v3.9.1).

## Cài

Không đăng pub.dev. Ghim tag trong `pubspec.yaml` của app:

```yaml
dependencies:
  tsudev_ui:
    git:
      url: https://github.com/tsudev-org/tsudev-ui-flutter.git
      ref: v0.1.0
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
```

- Bản Google Play: `onSeePro` `MUST` mở Play Billing, `MUST NOT` mở trang thanh toán web (PRODUCT_POLICY 4.3).
- Đăng xuất và xoá dữ liệu cục bộ: `repo.clear()` + `InstallationId.clear(store)`.
- Khoá lưu cục bộ: `tsu.installation_id`, `tsu.entitlements.jws`, `tsu.entitlements.jwks`, `tsu.pro_notice.last_shown`.

## Phát triển

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test                    # 69 test, gồm golden Sáng/Tối và khổ hẹp/rộng
```

Golden chỉ khớp trên Linux với đúng Flutter ghim trong CI (`3.47.8`); phông Roboto lấy từ Flutter SDK lúc test.
Quyết định thiết kế: [`docs/adr/0001-thu-vien-dung-chung-quyen-loi-huy-hieu.md`](docs/adr/0001-thu-vien-dung-chung-quyen-loi-huy-hieu.md).
Báo lỗ hổng: [`SECURITY.md`](SECURITY.md).
