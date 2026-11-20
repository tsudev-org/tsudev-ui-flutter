# Nhật ký thay đổi

Theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/) và SemVer.

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
