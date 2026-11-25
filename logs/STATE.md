# STATE.md - Trạng thái project

> Agent đọc file này ở đầu mỗi phiên và cập nhật ở cuối mỗi phiên.
> Quy trình: `.standards/docs/AGENT_PROTOCOL.md`.

## Hàng đợi task (làm từ trên xuống)

- [ ] Repo sản phẩm (qulythuchi, tsuscan, sound-db, app-la-ban, lotus-share) chuyển sang `tsudev_ui` ở PR PRO1 đầu tiên
  của mỗi repo (phiếu con PRO1 mục 6) - việc của phiên từng repo, không làm ở đây.
- [ ] Repo sản phẩm nâng `ref: v0.2.0` và gắn `maybeShowProRenewal` (7.6), `jwsForServer`/DPoP khi có đồng bộ - việc
  của phiên từng repo.

## Đang thực hiện

| Task | Agent | Bắt đầu |
| --- | --- | --- |

## Đã hoàn thành (mới nhất trên cùng)

- 26/11/2026 - v0.9.0 SYN1: bỏ Q3 + ProNotice, nguyên văn 7.5/7.6 v2.0.0, quy ước v7.1.0. Còn SYN1: màn "Đồng bộ thiết bị" (chờ tsulink P2-P5).

- 26/11/2026 - v0.8.0 LG3: `TsuSignInReminder` + `SignInReminderPolicy` (AUTH 14.4, phiếu `logs/handover/20261126-LG3_*`).

- 20/11/2026 - v0.2.0: ProRenewal (7.6, 6 ca bắt buộc + golden), `jwsForServer()`/401 stale, DPoP P-256 (RFC
  9449/7638), `cnf.jkt`, bộ quy ước v4.0.0 (phase PRO2-UI của phiên điều phối).
- 20/11/2026 - v0.1.0: TsuBadge, ProNotice (5 ca bắt buộc), kiểm JWS ES256 + JWKS, mã cài đặt 128 bit; CI xanh
  (phase PRO-C2 của phiên điều phối).

## Quyết định quan trọng

- 20/11/2026 - Một gói dùng chung, git dependency ghim tag - `docs/adr/0001-thu-vien-dung-chung-quyen-loi-huy-hieu.md`.

## Sự cố bảo mật

> Ghi theo `.standards/docs/SECURITY_BASELINE.md` mục 9. Để trống nếu chưa có.

- (chưa có)
