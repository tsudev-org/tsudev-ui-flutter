/// Huy hiệu SAU khi máy chủ đã áp `badge_display` (PRODUCT_POLICY 7.4).
enum TsuBadgeKind {
  none,
  pro,
  donor,
  both;

  /// Giá trị lạ ⇒ [none] (đóng an toàn: không tự hiện huy hiệu không rõ).
  static TsuBadgeKind parse(Object? raw) => switch (raw) {
    'pro' => pro,
    'donor' => donor,
    'both' => both,
    _ => none,
  };

  bool get showsPro => this == pro || this == both;
  bool get showsDonor => this == donor || this == both;
}

/// Nội dung JWS quyền lợi đã kiểm chữ ký, `iss`, `aud`, `exp`.
class Entitlement {
  const Entitlement({
    required this.subject,
    required this.audience,
    required this.issuedAt,
    required this.expiresAt,
    required this.proUntil,
    required this.proSource,
    required this.donor,
    required this.badge,
    required this.devices30d,
  });

  final String subject;
  final String audience;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// `null` khi `pro_until` = 0 (chưa từng có Pro).
  final DateTime? proUntil;

  /// `play` | `appstore` | `web` | `null`.
  final String? proSource;
  final bool donor;
  final TsuBadgeKind badge;

  /// Số mã cài đặt có hoạt động trong 30 ngày (PRODUCT_POLICY 7.3).
  final int devices30d;

  /// Pro còn hạn khi `pro_until` > giờ hiện tại.
  bool isProActive(DateTime now) =>
      proUntil != null && proUntil!.isAfter(now.toUtc());

  /// JWS còn dùng được (chưa quá `exp`). Quá hạn ⇒ coi là miễn phí.
  bool isFresh(DateTime now) => now.toUtc().isBefore(expiresAt);
}

/// Lý do JWS bị từ chối. Mọi lỗi đều dẫn tới trạng thái miễn phí.
enum EntitlementError {
  malformed,
  unsupportedAlgorithm,
  wrongType,
  unknownKey,
  badSignature,
  wrongIssuer,
  wrongAudience,
  expired,
  notYetValid,
  lifetimeTooLong,
  invalidClaims,
}

class EntitlementException implements Exception {
  const EntitlementException(this.error, [this.detail]);

  final EntitlementError error;
  final String? detail;

  @override
  String toString() =>
      'EntitlementException(${error.name}${detail == null ? '' : ': $detail'})';
}
