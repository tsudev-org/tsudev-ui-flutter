# AGENTS.md - tsudev-ui-flutter

> **ĐỌC FILE NÀY ĐẦU TIÊN trong mọi phiên làm việc mới.**

## Phần A - Quy ước chung của hệ sinh thái (KHÔNG SỬA Ở ĐÂY)

Toàn bộ quy ước chung nằm trong bản sao chỉ-đọc tại
[`.standards/AGENTS.md`](.standards/AGENTS.md). `MUST` đọc file đó trước.

Bản quy ước repo này đang dùng: xem [`.standards-version`](.standards-version).

| Cần gì | Đọc file nào |
| --- | --- |
| Điểm vào, nguyên tắc chung | `.standards/AGENTS.md` |
| Quy trình phiên, khóa file, bàn giao | `.standards/docs/AGENT_PROTOCOL.md` |
| Bảo mật bắt buộc | `.standards/docs/SECURITY_BASELINE.md` |
| Quy tắc `.gitignore` | `.standards/docs/GITIGNORE_POLICY.md` |
| Nhánh, commit, PR, phát hành | `.standards/docs/GIT_WORKFLOW.md` |
| Đăng nhập, đăng ký, xác minh tài khoản | `.standards/docs/AUTH_AND_ACCOUNT.md` |
| Giao diện và token | `.standards/docs/DESIGN_SYSTEM.md` |
| Bảng bản ghi, bộ chọn số bản ghi | `.standards/docs/DATA_TABLE.md` |
| Logo, favicon, icon ứng dụng | `.standards/docs/BRAND_ASSETS.md` |
| tsudev.com, ảnh đại diện, trang hồ sơ | `.standards/docs/ECOSYSTEM_IDENTITY.md` |
| Cấu trúc thư mục | `.standards/docs/PROJECT_STRUCTURE.md` |
| Chọn ngôn ngữ, framework | `.standards/docs/LANGUAGE_SELECTION.md` |
| Hạ tầng 0 đồng | `.standards/docs/FREE_TIER_STACK.md` |
| Trình soạn thảo nội dung | `.standards/docs/RICH_TEXT_EDITOR.md` |
| Tìm kiếm và lọc tiếng Việt | `.standards/docs/SEARCH_AND_FILTER.md` |
| Kiểm thử và chất lượng mã | `.standards/docs/TESTING_QUALITY.md` |
| Khả năng truy cập | `.standards/docs/ACCESSIBILITY.md` |

`MUST NOT` sửa bất kỳ file nào trong `.standards/`. Cần đổi quy ước thì mở đề
xuất tại repo `tsudev-standards` theo `.standards/docs/SYNC.md` mục 1.

## Phần B - Riêng của repo này

> Phần này KHÔNG thuộc bộ quy ước chung. Điền theo thực tế của repo.

### B.1. Repo này là gì

- **Loại**: thư viện (gói Dart/Flutter `tsudev_ui`), dùng chung cho qulythuchi, tsuscan, sound-db, app-la-ban,
  lotus-share qua git dependency ghim tag/commit.
- **Stack**: Flutter 3.47.8 (Dart 3.13), `pointycastle` (ECDSA P-256), `http`. Chi tiết: `docs/adr/0001-*.md`.
- **Mức phân loại dữ liệu cao nhất**: D1 (JWS quyền lợi chứa `sub`, mã cài đặt) - không xử lý D2+.
- **Người liên hệ khi có sự cố**: chủ dự án tsudev.

### B.2. Chạy trong 5 phút

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test && flutter analyze --fatal-infos
flutter test                       # gồm golden (chỉ khớp trên Linux + đúng Flutter ghim)
flutter test --update-goldens test/golden_test.dart   # khi đổi giao diện có chủ đích, soát ảnh trước khi commit
```

### B.3. Ranh giới sở hữu file

| Vùng | Chủ sở hữu |
| --- | --- |
| `lib/src/badge/` | phiên điều phối (đổi thiết kế: sửa SVG ở tsudev-standards TRƯỚC) |
| `lib/src/sign_in_reminder/` | phiên điều phối (chữ NGUYÊN VĂN AUTH_AND_ACCOUNT 14.4.3, nhịp 14.4.2) |
| `lib/src/pro_renewal/` | phiên điều phối (chữ NGUYÊN VĂN PRODUCT_POLICY 7.6 - test đối chiếu tự động) |
| `lib/src/entitlements/`, `lib/src/installation/` | phiên điều phối (hợp đồng PRODUCT_POLICY 7.4, AUTH_AND_ACCOUNT 14.3) |

### B.4. Điểm lệch chuẩn đã biết

| Lệch ở đâu | Vì sao | Kế hoạch |
| --- | --- | --- |
| Không có CodeQL cho Dart | CodeQL không hỗ trợ Dart; default setup chỉ quét `actions` | Theo dõi khi GitHub hỗ trợ Dart |

### B.5. Việc riêng của repo cần biết trước khi sửa

- Chữ ProRenewal/ProPurchase/SignInReminder và màu huy hiệu là HỢP ĐỒNG: nguồn là `.standards/docs/PRODUCT_POLICY.md` + `assets/badges/` của
  tsudev-standards. Bộ quy ước đổi chữ ⇒ đồng bộ `.standards` + sửa `lib/` trong cùng PR (test so nguyên văn sẽ đỏ).
- Đổi API công khai ⇒ tăng phiên bản theo SemVer, ghi CHANGELOG, gắn tag; repo sản phẩm ghim tag.
- `test/support/jws_fixture.dart` chứa khoá riêng P-256 CÔNG KHAI của test (vector RFC 6979), không phải bí mật.
