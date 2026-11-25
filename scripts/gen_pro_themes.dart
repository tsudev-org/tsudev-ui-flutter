// Sinh lib/src/pro_theme/tsu_pro_themes.g.dart TỪ .standards/tokens/pro-themes.json
// (tsudev-standards v6.4.0, DESIGN_SYSTEM.md mục 1.3). Không sửa tay tệp sinh ra.
//
//   dart run scripts/gen_pro_themes.dart          # ghi lại
//   dart run scripts/gen_pro_themes.dart --check  # chỉ đối chiếu (CI)
import 'dart:convert';
import 'dart:io';

const _src = '.standards/tokens/pro-themes.json';
const _out = 'lib/src/pro_theme/tsu_pro_themes.g.dart';

/// Thứ tự trường của TsuProPalette - khớp 1:1 với vai trò trong JSON.
const roles = <String, String>{
  'bg-base': 'bgBase',
  'bg-surface': 'bgSurface',
  'bg-subtle': 'bgSubtle',
  'bg-hover': 'bgHover',
  'border': 'border',
  'border-strong': 'borderStrong',
  'text-link': 'textLink',
  'primary': 'primary',
  'primary-hover': 'primaryHover',
  'primary-active': 'primaryActive',
  'on-primary': 'onPrimary',
  'focus-ring': 'focusRing',
  'accent': 'accent',
  'glow': 'glow',
  'icon-info': 'iconInfo',
  'icon-nav': 'iconNav',
  'pro-ring-start': 'ringStart',
  'pro-ring-end': 'ringEnd',
};

String _color(String v) {
  final hex = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(v);
  if (hex != null) return 'Color(0xFF${hex.group(1)!.toUpperCase()})';
  final m = RegExp(r'^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$')
      .firstMatch(v);
  if (m == null) throw FormatException('Màu không đọc được: $v');
  final a = (double.parse(m.group(4)!) * 255).round();
  String h(int x) => x.toRadixString(16).padLeft(2, '0').toUpperCase();
  return 'Color(0x${h(a)}${h(int.parse(m.group(1)!))}${h(int.parse(m.group(2)!))}${h(int.parse(m.group(3)!))})';
}

String _str(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String generate(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  final meta = data['meta'] as Map<String, dynamic>;
  final b = StringBuffer()
    ..writeln('// SINH TỰ ĐỘNG bởi scripts/gen_pro_themes.dart TỪ $_src')
    ..writeln('// (tsudev-pro-themes v${meta['version']}). KHÔNG SỬA TAY.')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln("part of 'tsu_pro_theme.dart';")
    ..writeln()
    ..writeln('/// Phiên bản bộ chủ đề Pro trong bộ quy ước.')
    ..writeln("const String tsuProThemesVersion = '${meta['version']}';")
    ..writeln()
    ..writeln('const List<TsuProTheme> _tsuProThemes = [');
  for (final t in (data['themes'] as List).cast<Map<String, dynamic>>()) {
    final name = t['name'] as Map<String, dynamic>;
    b
      ..writeln('  TsuProTheme._(')
      ..writeln('    id: ${_str(t['id'] as String)},')
      ..writeln('    nameVi: ${_str(name['vi'] as String)},')
      ..writeln('    nameEn: ${_str(name['en'] as String)},');
    for (final mode in ['light', 'dark']) {
      final c =
          (t['colors'] as Map<String, dynamic>)[mode] as Map<String, dynamic>;
      if (c.keys.toSet().difference(roles.keys.toSet()).isNotEmpty ||
          roles.keys.toSet().difference(c.keys.toSet()).isNotEmpty) {
        throw FormatException(
          '${t['id']} $mode: bộ vai trò khác TsuProPalette - cập nhật roles',
        );
      }
      b.writeln('    $mode: TsuProPalette(');
      for (final e in roles.entries) {
        b.writeln('      ${e.value}: ${_color(c[e.key] as String)},');
      }
      b.writeln('    ),');
    }
    b.writeln('  ),');
  }
  b.writeln('];');
  return b.toString();
}

void main(List<String> args) {
  final want = generate(File(_src).readAsStringSync());
  final out = File(_out);
  if (args.contains('--check')) {
    if (!out.existsSync() || out.readAsStringSync() != want) {
      stderr.writeln(
        'LỆCH: $_out khác bản sinh từ $_src - chạy: dart run scripts/gen_pro_themes.dart',
      );
      exit(1);
    }
    stdout.writeln('OK: $_out khớp $_src');
    return;
  }
  out.writeAsStringSync(want);
  stdout.writeln('Đã sinh $_out');
}
