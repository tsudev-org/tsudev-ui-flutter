# Chính sách bảo mật - tsudev-ui-flutter

## Báo lỗ hổng

**KHÔNG mở issue công khai.** Dùng [Báo cáo lỗ hổng riêng tư của GitHub](https://github.com/tsudev-org/tsudev-ui-flutter/security/advisories/new).
Gửi kèm: thành phần, phiên bản (tag), cách tái hiện, tác động. Phản hồi trong 7 ngày, bản sửa lỗi nghiêm trọng trong
30 ngày. Quy trình chung: [`.standards/SECURITY.md`](.standards/SECURITY.md).

## Phạm vi và cam kết

- **Kiểm JWS quyền lợi**: chỉ `ES256`, header `typ` = `tsu-ent+jwt`, khoá chọn theo `kid` từ JWKS lấy qua discovery
  (`issuer` khớp, `jwks_uri` https cùng máy chủ); không bao giờ dùng khoá nhúng trong header (`jwk`/`jku`/`x5u`/`x5c`);
  từ chối `crit`; khoá JWK phải nằm trên đường cong P-256; kiểm `iss`, `aud`, `exp` (không nới), `iat`, và
  `exp` ≤ `iat` + 7 ngày. Mọi lỗi ⇒ trạng thái miễn phí, không ném ra giao diện.
- **Ranh giới tin cậy**: kết quả kiểm ở app chỉ để ẩn/hiện nút. Máy chủ đồng bộ `MUST` tự kiểm Pro (PRODUCT_POLICY
  7.1 N4) - người kiểm soát thiết bị có thể sửa kho cục bộ.
- **Mã cài đặt**: 128 bit từ `Random.secure()`, không suy ra từ định danh phần cứng; chỉ gửi khi đã đăng nhập.
- **Mật mã**: ECDSA P-256/SHA-256 của `pointycastle` (ghim phiên bản qua pub, Dependabot theo dõi); không tự cài đặt
  thuật toán. Log không chứa JWS, token hay mã cài đặt.
