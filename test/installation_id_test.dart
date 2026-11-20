import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsudev_ui/tsudev_ui.dart';

void main() {
  test('22 ký tự base64url không đệm, giải ra đúng 16 byte (128 bit)', () {
    for (var i = 0; i < 200; i++) {
      final id = InstallationId.generate();
      expect(id, hasLength(22));
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
      expect(base64Url.decode('$id=='), hasLength(16));
      expect(InstallationId.isValid(id), isTrue);
    }
  });

  test('không trùng trong 10.000 lần sinh', () {
    final seen = {for (var i = 0; i < 10000; i++) InstallationId.generate()};
    expect(seen, hasLength(10000));
  });

  test('sinh một lần rồi dùng lại; mã hỏng ⇒ sinh mới', () async {
    final store = InMemoryKeyValueStore();
    final a = await InstallationId.getOrCreate(store);
    expect(await InstallationId.getOrCreate(store), a);
    expect(store.snapshot[InstallationId.storageKey], a);

    await store.write(InstallationId.storageKey, 'khong-hop-le');
    final b = await InstallationId.getOrCreate(store, random: Random(1));
    expect(b, isNot('khong-hop-le'));
    expect(InstallationId.isValid(b), isTrue);
  });

  test('clear() ⇒ lần sau mã mới', () async {
    final store = InMemoryKeyValueStore();
    final a = await InstallationId.getOrCreate(store);
    await InstallationId.clear(store);
    expect(store.snapshot, isEmpty);
    expect(await InstallationId.getOrCreate(store), isNot(a));
  });

  test('từ chối sai định dạng và dạng không chuẩn', () {
    for (final bad in [
      null,
      '',
      'A' * 21,
      'A' * 23,
      '${'A' * 21}=',
      '${'A' * 21}+',
      '${'A' * 21}B', // 4 bit thừa khác 0 ⇒ không chuẩn
    ]) {
      expect(InstallationId.isValid(bad), isFalse, reason: '$bad');
    }
    expect(InstallationId.isValid('${'A' * 21}A'), isTrue);
  });

  test('tên khoá và header theo hợp đồng', () {
    expect(InstallationId.headerName, 'X-Tsu-Installation');
    expect(InstallationId.storageKey, 'tsu.installation_id');
  });
}
