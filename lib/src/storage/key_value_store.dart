/// Kho khoá-giá trị cục bộ mà gói này cần (mã cài đặt, JWS đệm, mốc nhắc gia hạn/nhắc đăng nhập).
///
/// App tự nối vào kho cài đặt của mình (ví dụ `shared_preferences`) - gói không
/// kéo plugin nền tảng nào để repo sản phẩm giữ toàn quyền chọn chỗ lưu.
/// Mã cài đặt `MUST` nằm cùng chỗ với cài đặt của app (AUTH_AND_ACCOUNT.md 14.3).
abstract interface class TsuKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Kho trong bộ nhớ: cho test và cho app chưa nối kho thật.
class InMemoryKeyValueStore implements TsuKeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial]) : _data = {...?initial};

  final Map<String, String> _data;

  /// Ảnh chụp chỉ-đọc, để test kiểm nội dung đã ghi.
  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Khoá của thông báo "nhiều thiết bị chưa có Pro" (PRODUCT_POLICY 7.3) - bỏ từ bộ quy ước v7.0.0.
const legacyProNoticeKey = 'tsu.pro_notice.last_shown';

/// Xoá dữ liệu cục bộ của các tính năng đã bỏ (gọi một lần ở lần chạy đầu của bản mới, PRODUCT_POLICY 7.3).
Future<void> removeLegacyLocalKeys(TsuKeyValueStore store) =>
    store.delete(legacyProNoticeKey);
