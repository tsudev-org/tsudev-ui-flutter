# PHIẾU YÊU CẦU MUI1 - Chuyển `tsudev_ui` sang `material_ui` / `cupertino_ui` (Flutter 3.50)

- **Mã phiếu**: 20261125-MUI1 - **Từ**: agent-qulythuchi (phiên SES-20261125-0104-52cc), 25/11/2026 - **Trạng thái**: MỞ
- **Ảnh hưởng**: mọi app Flutter của hệ dùng `tsudev_ui` khi nâng lên Flutter 3.50.x

## 1. Vấn đề

Flutter 3.50.1 (Dart 3.14.0) đánh dấu lỗi thời `package:flutter/material.dart`, `package:flutter/cupertino.dart` và
`GlobalMaterialLocalizations` / `GlobalCupertinoLocalizations` của `flutter_localizations` ("deprecated after
v3.47.0-0.0.pre"). Thay thế: gói `material_ui` 1.11.1 + `cupertino_ui` 1.1.7 (nhà phát hành `flutter.dev`).
Codemod: `dart fix --apply --code=migrate_design_widgets`.

`material_ui` là **bản sao tách rời** (không tái xuất kiểu của `flutter/material`). `tsudev_ui` v0.4.0/v0.5.0 vẫn
`import 'package:flutter/material.dart'` và trả về kiểu Material cho app ghép vào `ThemeData`:

- `tsuNavigationBarTheme(...)` ⇒ `NavigationBarThemeData`, `tsuNavigationRailTheme(...)` ⇒ `NavigationRailThemeData`,
  `tsuCompleteContainers(ColorScheme)`.

App chuyển sang `material_ui` trong khi `tsudev_ui` chưa chuyển ⇒ **lỗi biên dịch** (khác kiểu). Vì vậy qulythuchi
(PR nâng Flutter 3.50, nhánh `chore/flutter-3.50`) tạm chặn TỪNG DÒNG `// ignore: deprecated_member_use` ở các import.

## 2. Đề nghị

1. Phát hành `tsudev_ui` bản mới (vd. v0.6.0) phụ thuộc `material_ui` + `cupertino_ui`, ràng buộc Flutter ≥ 3.50
   (Dart ^3.14.0), chạy codemod, `flutter analyze --fatal-infos` sạch.
2. Ghi CHANGELOG: app dùng bản này PHẢI chuyển cùng lúc (không trộn kiểu `flutter/material` và `material_ui`);
   widget bên thứ ba còn dùng `flutter/material` ⇒ bọc `MaterialUiCompatibilityBridge` (README `material_ui` bước 3).
3. Báo lại cho qulythuchi (ghi dòng "Kết quả xử lý" dưới đây) để app gỡ các dòng `ignore` và header `l10n.yaml`.

## 3. Kết quả xử lý

- 25/11/2026 - agent-qulythuchi: mở phiếu.
