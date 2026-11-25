# Nhật ký thay đổi

Theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/) và SemVer.

## [Chưa phát hành]

## [0.7.1] - 25/11/2026

### Đổi

- `ProPurchaseStrings.positioning` (vi/en) theo câu định vị mới chủ dự án duyệt 25/11/2026 (tsudev-standards **v6.6.0**,
  `PRODUCT_POLICY` 3.7.3): "Ứng dụng TsuDEV miễn phí; dự án gắn nhãn OPEN công khai mã nguồn trên GitHub. …" / "TsuDEV
  apps are free; projects labelled OPEN publish their source code on GitHub. …" (có dự án PRIVATE - mục 3.7.7).
- Đồng bộ bộ quy ước v6.4.0 → v6.6.0.

## [0.7.0] - 25/11/2026

### Thêm

- Chủ đề Pro (Q2, PRODUCT_POLICY 3.7.1; tsudev-standards **v6.4.0** `DESIGN_SYSTEM.md` mục 1.3; phiếu `20261125-PRO3`):
  `TsuProTheme` (5 chủ đề, `all`, `byId`, tên vi/en), `TsuProPalette` (18 vai trò × Sáng/Tối), `tsuResolveProTheme`
  (cần Pro; tương phản cao thắng; id lạ ⇒ mặc định), `tsuApplyProTheme` (gộp vào `ColorScheme`, giữ `onSurface`/`error`,
  khai đủ `*Container`), `TsuProThemePicker` (Cài đặt → Giao diện, vi/en, ngữ nghĩa nhóm chọn một; chưa Pro vẫn thấy mẫu
  màu, không làm mờ/khoá, chỉ "Mặc định" chọn được + "Tìm hiểu TsuDEV Pro"), `TsuProAvatarFrame` (vòng chuyển sắc, không
  dấu tích).
- `scripts/gen_pro_themes.dart`: sinh `lib/src/pro_theme/tsu_pro_themes.g.dart` từ `.standards/tokens/pro-themes.json`;
  test bắt lệch với bộ quy ước và đo lại WCAG phía Flutter.

### Đổi

- Đồng bộ bộ quy ước v4.2.0 → **v6.4.0** (`.standards/`).
- App đã có Q2 chạy thật mới được truyền `ProBenefit.proTheme` vào `ProPurchaseSheet`.

## [0.6.0] - 25/11/2026

### Thêm

- `ProPurchaseSheet` + `showProPurchaseSheet` + `ProPurchaseStrings` (vi/en) + `ProBenefit` (Q1 huy hiệu, Q2 giao diện
  Pro, Q3 đồng bộ) - màn mua TsuDEV Pro theo PRODUCT_POLICY 3.7.3 (bộ quy ước v6.1.0, phiếu `20261125-PRO3`): câu định
  vị nguyên văn → chỉ quyền lợi app truyền vào (đang chạy thật) → điều khoản 7.5 có giá + liên kết Chính sách thanh
  toán, hoàn tiền và khiếu nại / Điều khoản → ô xác nhận KHÔNG chọn sẵn; nút mua vô hiệu tới khi đánh dấu; nút "Đóng"
  trung tính. Gói không tự thanh toán - app chọn IAP cửa hàng hoặc `proWebUrl`. Test đối chiếu nguyên văn với
  `PRODUCT_POLICY.md` khi có bản sao bộ quy ước cạnh repo.

### Chưa làm

- Chủ đề Pro (Q2): bộ quy ước chưa có token chủ đề Pro - cần thêm ở `tsudev-standards/tokens` trước (3.7.1: "repo không
  tự chế"). App chưa có Q2 thì KHÔNG truyền `ProBenefit.proTheme`.

## [0.5.0] - 24/11/2026

### Thêm

- `TsuXdApprover` + `TsuXdApproveScreen` + `TsuXdStrings` (vi/en) - vai XÁC NHẬN đăng nhập QR trong app (CROSS_DEVICE_LOGIN
  v1.1.0 mục 1, 6.3, 7; phiếu `20261124-QR1` QR2b): app đã đăng nhập quét QR Đ2 ở màn đăng nhập máy tính ⇒ màn Cho phép
  (thiết bị, quốc gia, thời điểm, câu cảnh báo nguyên văn, Từ chối có focus mặc định, hai nút cùng cỡ) ⇒ **mở khoá cục
  bộ bắt buộc** (`unlock`, T8) ⇒ mã khớp + đồng hồ 60 giây. Gọi `POST https://tsudev.com/api/xd/scan|approve|deny` bằng
  access token OIDC scope `tsudev.xd` (client OIDC của app phải được cấp scope này ở IdP). QR Đ1 không bao giờ được gửi lên
  - app mở trình duyệt như QR3.
- Gói KHÔNG kéo `local_auth`: app truyền `unlock` (sinh trắc/PIN/khoá ứng dụng sẵn có) để không bắt mọi app đổi
  `FlutterFragmentActivity`.

## [0.4.0] - 24/11/2026

### Thêm

- `TsuSignInScreen` + `TsuSignInOption` + `TsuSignInStrings` (vi/en): màn đăng nhập/đăng ký/Ủng hộ thống nhất theo
  AUTH_AND_ACCOUNT 13.2 (mẫu Quly Thu Chi + Lark) - lối vào lấy từ app (không gõ cứng nhà cung cấp), nhãn "Lần trước
  bạn dùng cách này", ô đồng ý Điều khoản KHÔNG tích sẵn + bảng "Đồng ý và tiếp tục" (13.4), dải "Thêm tuỳ chọn đăng
  nhập", "Quét để đăng nhập", chế độ khách không bắt tích ô.
- `TsuXdLink.parse` (CROSS_DEVICE_LOGIN v1.1.0 T9): chỉ nhận `https://tsudev.com/x/<id>?f=k|d#<bí mật>`; app mở chính
  URL đó trong trình duyệt hệ thống để đăng nhập bằng QR (Đ1), rồi đăng nhập OIDC như thường - SSO trả mã ngay.

## [0.3.0] - 24/11/2026

### Thêm

- `TsuNavColors`, `tsuNavigationBarTheme`, `tsuNavigationRailTheme`, `tsuCompleteContainers`, `tsuContrast`
  (phiếu `20261124-UI1`, DESIGN_SYSTEM 4.1.0): theme thanh điều hướng ghi đè biểu tượng + nhãn theo `WidgetState`,
  khai đủ cặp `*Container`; `TsuNavColors` ném lỗi khi biểu tượng/nền dưới 3:1. Sửa gốc lỗi biểu tượng trắng trên viên
  chỉ báo nhạt (Sound Db, Quly Thu Chi). Test đo tương phản tại `IconTheme` của biểu tượng thật, đã kiểm đột biến.

### Thêm

- Test fuzz đột biến cho `EntitlementVerifier` (seed cố định, `--dart-define=FUZZ_SEED`): chuỗi JWS bị sửa, claim và
  header ngẫu nhiên có chữ ký hợp lệ chỉ được nhận đúng bản gốc hoặc ném `EntitlementException`.
- `CONTRIBUTING.md` (tiếng Anh), tóm tắt tiếng Anh trong README và SECURITY, hồ sơ OpenSSF Best Practices
  `docs/best-practices.json`.

## [0.2.0] - 20/11/2026

Bộ quy ước **v4.0.0** (PRODUCT_POLICY v1.2.0: Pro 1 năm không tự gia hạn, mục 7.6, kênh trạng thái).

### Thêm

- `ProRenewalDialog`, `ProRenewalController`, `ProRenewalPolicy`, `ProRenewalStrings`, `maybeShowProRenewal`,
  `formatProRenewalDate`: nhắc gia hạn khi còn ≤ 7 ngày (mỗi lần mở app: khởi động mới hoặc quay lại sau ≥ 30 phút ở
  nền, tối đa một lần mỗi lần mở, không chen khi đang nhập liệu) và báo hết kỳ một lần mỗi `pro_until`
  (`tsu.pro_expired.notified_until`), `{ngày_xoá}` = `pro_until` + 90 ngày, bỏ câu đám mây khi `hasCloudSync: false`
  (PRODUCT_POLICY 7.6) - chữ nguyên văn vi/en có test so với `.standards`, đủ 6 test bắt buộc, golden Sáng/Tối.
- `EntitlementsRepository.jwsForServer()`: JWS gửi thẳng lên máy chủ đồng bộ, lấy mới khi `iat` > 23 giờ;
  `sendWithServerJws()` lấy JWS mới và thử lại đúng một lần khi máy chủ trả `401 reason: "stale"`;
  `serverAuthHeaders()` chọn `Bearer` hoặc `DPoP` theo `cnf.jkt`; các lời gọi lấy JWS đồng thời dùng chung một yêu cầu.
- `DpopSigner`, `DpopKey`, `SoftwareDpopKey`, `jwkThumbprint`: bằng chứng DPoP (RFC 9449: `htm`, `htu`, `iat`, `jti`
  128 bit, `ath`, `nonce`) bằng khoá P-256 riêng mỗi cài đặt, thumbprint RFC 7638 - test theo vector tính độc lập.
- `TsudevEntitlementsApi(dpop: ...)`: gửi header `DPoP` khi gọi `/api/me/entitlements`, thử lại một lần khi máy chủ
  đòi `DPoP-Nonce`.
- `Entitlement.confirmationJkt` (`cnf.jkt`); verifier từ chối `cnf`/`cnf.jkt` sai dạng.

### Đổi

- Đồng bộ bộ quy ước v3.9.1 → v4.0.0 (chữ PRODUCT_POLICY 7.3 không đổi).

## [0.1.0] - 20/11/2026

### Thêm

- `TsuBadge`, `TsuNameWithBadge`: huy hiệu Pro / Ủng hộ theo PRODUCT_POLICY 4.2 và `assets/badges/` (bộ quy ước
  v3.9.1) - màu Sáng/Tối, 0,75 × dòng (16-20 px), shimmer 7 giây, tim đập khi rê/chạm, tắt khi Giảm chuyển động,
  nhãn đọc màn hình vi/en.
- `ProNoticeDialog`, `ProNoticeController`, `ProNoticePolicy`, `maybeShowProNotice`: thông báo "nhiều thiết bị chưa
  có Pro" (PRODUCT_POLICY 7.3) - chữ nguyên văn vi/en, chu kỳ 30 ngày ở `tsu.pro_notice.last_shown`, đủ 5 test bắt buộc.
- `EntitlementVerifier`, `EntitlementsRepository`, `DiscoveryJwks`, `StaticJwks`, `TsudevEntitlementsApi`: kiểm JWS
  quyền lợi ES256 + JWKS, đệm ≤ 7 ngày, hết hạn ⇒ miễn phí (PRODUCT_POLICY 7.4).
- `InstallationId`: mã cài đặt 128 bit, header `X-Tsu-Installation` (AUTH_AND_ACCOUNT 14.3).
