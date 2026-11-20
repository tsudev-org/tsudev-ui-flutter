import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../storage/key_value_store.dart';

/// Mã cài đặt theo AUTH_AND_ACCOUNT.md mục 14.3.
///
/// - 128 bit từ bộ sinh số ngẫu nhiên mật mã ([Random.secure]), base64url
///   không đệm (22 ký tự), sinh ở lần chạy đầu, lưu cục bộ.
/// - KHÔNG suy ra từ IMEI/MAC/Android ID/IDFV/vân tay thiết bị.
/// - Chỉ gửi khi đã đăng nhập, trong header [headerName].
abstract final class InstallationId {
  /// Khoá lưu cục bộ.
  static const storageKey = 'tsu.installation_id';

  /// Header gửi kèm các lượt gọi lấy quyền lợi và máy chủ đồng bộ.
  static const headerName = 'X-Tsu-Installation';

  static final _shape = RegExp(r'^[A-Za-z0-9_-]{22}$');

  /// Sinh mã mới. [random] chỉ để test; mặc định [Random.secure].
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Đúng 22 ký tự base64url VÀ ở dạng chuẩn (4 bit thừa cuối bằng 0), tức là
  /// giải mã ra đúng 16 byte rồi mã hoá lại ra đúng chuỗi cũ.
  static bool isValid(String? value) {
    if (value == null || !_shape.hasMatch(value)) return false;
    try {
      final bytes = base64Url.decode('$value==');
      return bytes.length == 16 &&
          base64Url.encode(bytes).replaceAll('=', '') == value;
    } on FormatException {
      return false;
    }
  }

  /// Đọc mã đã lưu; chưa có hoặc hỏng ⇒ sinh mã mới và lưu.
  static Future<String> getOrCreate(
    TsuKeyValueStore store, {
    Random? random,
  }) async {
    final existing = await store.read(storageKey);
    if (isValid(existing)) return existing!;
    final fresh = generate(random);
    await store.write(storageKey, fresh);
    return fresh;
  }

  /// Gọi khi "Đăng xuất và xoá dữ liệu cục bộ": lần sau sinh mã mới.
  static Future<void> clear(TsuKeyValueStore store) => store.delete(storageKey);
}
