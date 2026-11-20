import 'dart:convert';
import 'dart:typed_data';

final _alphabet = RegExp(r'^[A-Za-z0-9_-]*$');

/// Giải base64url KHÔNG đệm (RFC 7515 mục 2). Ký tự lạ hoặc có `=` ⇒ `null`.
Uint8List? tryDecodeBase64Url(String s) {
  if (!_alphabet.hasMatch(s) || s.length % 4 == 1) return null;
  try {
    return base64Url.decode(base64Url.normalize(s));
  } on FormatException {
    return null;
  }
}
