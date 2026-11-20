# ADR-0001: Một gói Flutter dùng chung cho huy hiệu, ProNotice, JWS quyền lợi và mã cài đặt

- **Trạng thái**: ĐÃ CHẤP NHẬN
- **Ngày**: 20/11/2026
- **Người quyết định**: phiên điều phối tsudev (phase PRO-C2, phiếu `~/projects/logs/handover/20261120-01_*`)
- **Liên quan**: PRODUCT_POLICY mục 4, 7.3, 7.4, 7.5; AUTH_AND_ACCOUNT mục 14.3 (bộ quy ước v3.9.1)

## 1. Bối cảnh

Năm app Flutter cần cùng một huy hiệu, cùng một hộp thoại "nhiều thiết bị chưa có Pro" (chữ nguyên văn, chu kỳ
30 ngày, 5 test bắt buộc), cùng cách kiểm JWS quyền lợi và cùng mã cài đặt. Viết riêng ở từng repo dễ lệch chữ, lệch
màu và lệch kiểm chữ ký. Ràng buộc 0 đồng: không đăng gói trả phí, không dịch vụ ngoài. Dữ liệu cao nhất D1.

## 2. Các phương án đã cân nhắc

| Phương án | Ưu | Nhược | Chi phí |
| --- | --- | --- | --- |
| A. Một gói `tsudev_ui`, app ghim tag qua git dependency | Một nguồn, test một lần | Phải gắn tag khi đổi | 0 |
| B. Chép mã vào từng repo | Không phụ thuộc chéo | 5 bản lệch nhau, 5 lần test | 0 |
| C. Đăng pub.dev | Cài tiện | Lộ API ra công chúng, cần quy trình phát hành riêng | 0 |

## 3. Quyết định

Chọn **A**. Chi tiết:

1. **Không kéo plugin nền tảng**: lưu trữ qua giao diện `TsuKeyValueStore`; app tự nối kho cài đặt của mình.
2. **ES256 bằng `pointycastle`** (Dart thuần, chạy cả web/desktop/di động). Phần JWS (tách, base64url, kiểm header,
   claim) tự viết ngắn để kiểm soát đúng hợp đồng 7.4 thay vì dùng thư viện JOSE tổng quát (nhiều thuật toán, nhiều
   đường cấu hình sai). Chữ ký thô r‖s 64 byte; JWK phải nằm trên đường cong P-256.
3. **Header `typ` = `tsu-ent+jwt` bắt buộc** - chặn đem ID token (cùng khoá OIDC ký) thay cho JWS quyền lợi.
4. **Đệm**: JWS ở `tsu.entitlements.jws`, JWKS (công khai) ở `tsu.entitlements.jwks` để kiểm lại khi ngoại tuyến;
   mỗi lần đọc kiểm lại đủ, `exp` không nới (dung sai đồng hồ chỉ áp cho `iat`). JWS mới giả/hỏng không ghi đè bản
   đệm tốt.
5. **ProNotice không hiện khi không có JWS còn hạn** (ca bắt buộc số 5) - thiếu dữ liệu thì im lặng, không đoán.
6. **Mã cài đặt** lưu ở `tsu.installation_id` (bộ quy ước chưa đặt tên khoá; chọn cùng tiền tố `tsu.` với
   `tsu.pro_notice.last_shown`). Header chỉ gửi khi giá trị đúng dạng chuẩn 22 ký tự.
7. **Golden** dùng Roboto lấy từ Flutter SDK lúc test (không commit phông), chỉ so trên Linux với Flutter ghim.

## 4. Hệ quả

- Repo sản phẩm ghim `ref: vX.Y.Z`; đổi API ⇒ tăng phiên bản + CHANGELOG + tag.
- Bộ quy ước đổi chữ 7.3 ⇒ test đối chiếu nguyên văn đỏ cho tới khi `lib/` được sửa cùng PR đồng bộ.
- Gate ở app không phải biện pháp an ninh; máy chủ đồng bộ tự kiểm Pro (N4).
