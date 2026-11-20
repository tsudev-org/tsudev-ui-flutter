/// Kho khoá-giá trị cục bộ mà gói này cần (mốc ProNotice, mã cài đặt, JWS đệm).
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
