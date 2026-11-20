import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nạp phông Roboto đi kèm Flutter SDK (Apache 2.0, có đủ dấu tiếng Việt) để
/// golden hiện chữ thật thay vì ô vuông Ahem. Không nhúng phông vào repo.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fonts = _materialFontsDir();
  final loader = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = File('${fonts.path}/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  await testMain();
}

Directory _materialFontsDir() {
  // flutter_tester nằm ở <flutter>/bin/cache/artifacts/engine/<nền tảng>/.
  final fromTester = Directory(
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
  );
  if (fromTester.existsSync()) return fromTester;
  final root = Platform.environment['FLUTTER_ROOT'];
  final fromRoot = Directory('$root/bin/cache/artifacts/material_fonts');
  if (root != null && fromRoot.existsSync()) return fromRoot;
  throw StateError('Không tìm thấy material_fonts của Flutter SDK');
}
