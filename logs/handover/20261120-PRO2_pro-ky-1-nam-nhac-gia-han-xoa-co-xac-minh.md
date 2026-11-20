# 20261120-PRO2 - tsudev-ui-flutter: TsuDEV Pro kỳ 1 năm, nhắc gia hạn 7 ngày, xoá có xác minh

- **Người lập**: phiên điều phối `projects-a6`, 20/11/2026 - phiếu mẹ `~/projects/logs/handover/20261120-PRO2_pro-ky-1-nam-xoa-co-xac-minh-toan-he.md`
- **Hợp đồng**: `tsudev-org/tsudev-standards` **v4.0.0** - `docs/PRODUCT_POLICY.md` v1.2.0 mục 3.3, 7.2, 7.4, 7.5,
  **7.6**, 8. Lệch giữa phiếu và PRODUCT_POLICY ⇒ PRODUCT_POLICY thắng.
- **Thay phần tương ứng** của phiếu `20261119-PRO1` trong repo này (giá tháng/năm, mã `thang`, "tự gia hạn").
- **Người làm**: phiên điều phối (phase PRO2-UI, ranh giới AGENTS.md B.3)

## 1. Bối cảnh (chủ dự án 20/11/2026)

- Pro áp dụng **1 năm**, **không tự gia hạn**; hết kỳ mà không gia hạn ⇒ về **trạng thái miễn phí ("khách mời")**:
  dùng đủ tính năng cục bộ, KHÔNG đồng bộ/sao lưu lên đám mây; dữ liệu trên thiết bị giữ nguyên; bản sao đám mây kéo/xuất
  được 90 ngày rồi bị xoá **có xác minh**.
- 7 ngày cuối trước khi hết hạn: **nhắc gia hạn mỗi lần mở app**; hết kỳ: báo **một lần**.
- Lỗi cần chặn: người **gia hạn trên web mà không mở app suốt 90 ngày** bị máy chủ xoá nhầm bản sao đám mây (máy chủ chỉ
  biết `pro_until` cũ; kênh RP `GET /api/rp/entitlements/{sub}` trả 404 khi grant OIDC quá 30 ngày).

## 2. Việc phải làm

### 2.1. `ProRenewalNotice` + báo hết kỳ (PRODUCT_POLICY 7.6) - API công khai mới, tag **v0.2.0**

- `ProRenewalPolicy` (thuần, nhận `now`, `proUntil`, `lastResumeAt`) + `ProRenewalController` (lưu
  `tsu.pro_expired.notified_until` qua `KeyValueStore`) + `ProRenewalDialog` + `maybeShowProRenewal(context, ...)`.
- Chữ vi/en NGUYÊN VĂN 7.6 - test so với `.standards/docs/PRODUCT_POLICY.md` (như ProNotice); `{n}` làm tròn lên ≥ 1,
  ngày DD/MM/YYYY (vi). Nút chính gọi callback của app (app tự mở IAP hoặc web theo kênh).
- Đủ 6 test bắt buộc + widget khổ hẹp/rộng + golden Sáng/Tối.

### 2.2. Quyền lợi

- `EntitlementsRepository`: cung cấp `jwsForServer()` - lấy JWS mới khi `iat` > 23 giờ (máy chủ nhận ≤ 24 giờ) và khi
  máy chủ trả `401 reason: "stale"`.
- DPoP (`SHOULD`): khoá P-256 mỗi cài đặt (kho khoá an toàn của nền tảng; không xuất khoá riêng), `DpopSigner.proof(
  method, url, accessToken)`; gửi header `DPoP` khi gọi `/api/me/entitlements` và khi gọi máy chủ đồng bộ với JWS có
  `cnf.jkt`. Test theo vector tự sinh (thumbprint RFC 7638, `ath`).
- CHANGELOG, SemVer `0.2.0`, README cách dùng; báo các repo Flutter (qulythuchi, tsuscan, sound-db, app-la-ban,
  lotus-share, tsudev-lotus) nâng `ref: v0.2.0`.

## 3. Điều kiện xong

- [ ] Các mục ở phần 2 xong, test xanh, CI xanh; sync bộ quy ước **v4.0.0** trong cùng PR (thay v3.9.1 của PRO1).
- [ ] Checklist PRODUCT_POLICY mục 8 (các dòng Pro) đạt; số liệu/ảnh chụp nhắc gia hạn vi/en Sáng/Tối trong PR.
- [ ] Việc cần chủ dự án (Play Console, App Store Connect, deploy production, merge bị bộ phân loại chặn): ghi rõ lệnh
  `!` cho chủ dự án, không lách.

## 4. Không làm

- Không thêm tự gia hạn, gói tháng, dùng thử miễn phí, popup nhắc Ủng hộ (chỉ nhắc Pro đúng điều kiện 7.6).
- Không xoá dữ liệu trên thiết bị trong bất kỳ trường hợp nào.

## 5. Kết quả xử lý (mỗi phiên ghi một dòng)

- 20/11/2026 - phiên điều phối (PRO2-UI): mục 2.1 + 2.2 xong ở **v0.2.0** (nhánh `feat/pro2-renewal-v0.2.0`): ProRenewal
  chữ nguyên văn 7.6 có test so `.standards`, đủ 6 ca bắt buộc, widget hẹp/rộng (chữ 200%), 8 golden Sáng/Tối;
  `jwsForServer()` (> 23 giờ lấy mới) + `sendWithServerJws()` (401 stale ⇒ thử lại 1 lần) + `serverAuthHeaders()`;
  `DpopSigner`/`DpopKey`/`SoftwareDpopKey` (vector RFC 7638 tính độc lập bằng Python), header `DPoP` ở
  `/api/me/entitlements`. Khoá kho phần cứng: app tự cài `DpopKey` (gói không kéo plugin). Còn: các repo Flutter nâng
  `ref: v0.2.0` (đã nhắn); mục 3 dòng 2 (ảnh chụp) = golden trong PR.
