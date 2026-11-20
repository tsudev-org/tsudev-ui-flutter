# Nhật ký thay đổi

Theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/) và SemVer.

## [Chưa phát hành]

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
