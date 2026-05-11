// 初期局面 (標準平手) でマッチしてしまうテンプレを data/*.txt から駆除する。
//
// 「玉 + 飛車だけ」のような粗いテンプレは初期局面そのものでも発火するため、
// 検出 API としてノイズになる。本ツールはそういうテンプレを以下の基準で削除
// する:
//
//   1. 標準初期局面の Position に対してテンプレが match する
//   2. かつ、テンプレ名が allowlist に含まれていない
//      (allowlist: 居玉 / 居玉以外で意図的に初期局面を表現する名前)
//
// 使い方:
//   dart run tool/purge_initial_match_templates.dart [--dry-run]
//
// 削除後は dart run tool/generate_{castles,strategies}.dart で
// lib/src/generated/*.g.dart を更新すること。

import 'dart:io';

import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/strategy.dart';

void main(List<String> args) {
  final bool dryRun = args.contains('--dry-run');

  // 初期局面でマッチしても許容する名前 (= 意図的に初期局面を表現するもの)。
  const Set<String> allowlist = <String>{
    '居玉',
  };

  // --- castles ---
  final Position p = Position();
  final Set<String> firingCastles = p.castles
      .where((DetectedCastle d) => d.side == Color.black)
      .map((DetectedCastle d) => d.template.name)
      .toSet();
  final Set<String> toRemoveCastles =
      firingCastles.difference(allowlist).toSet();
  stdout.writeln('=== data/castles.txt ===');
  if (toRemoveCastles.isEmpty) {
    stdout.writeln('  (no offenders)');
  } else {
    stdout.writeln('  remove: ${toRemoveCastles.join(", ")}');
    if (!dryRun) _removeTemplates('data/castles.txt', toRemoveCastles);
  }

  // --- strategies ---
  final Set<String> firingStrategies = p.strategies
      .where((DetectedStrategy d) => d.side == Color.black)
      .map((DetectedStrategy d) => d.template.name)
      .toSet();
  final Set<String> toRemoveStrategies =
      firingStrategies.difference(allowlist).toSet();
  stdout.writeln('=== data/strategies.txt ===');
  if (toRemoveStrategies.isEmpty) {
    stdout.writeln('  (no offenders)');
  } else {
    stdout.writeln('  remove: ${toRemoveStrategies.join(", ")}');
    if (!dryRun) _removeTemplates('data/strategies.txt', toRemoveStrategies);
  }

  if (dryRun) {
    stdout.writeln('\n(dry-run; no changes written)');
  } else {
    stdout.writeln('\n次に: dart run tool/generate_castles.dart && '
        'dart run tool/generate_strategies.dart');
  }
}

void _removeTemplates(String path, Set<String> names) {
  final String content = File(path).readAsStringSync();
  // テンプレを `=== name: ` で区切って parse、対象 name を除外して再構成。
  final List<String> lines = content.split('\n');
  final List<String> output = <String>[];
  // ヘッダ (先頭の `=== name:` までのコメント) を保持。
  int i = 0;
  while (i < lines.length && !lines[i].startsWith('=== ')) {
    output.add(lines[i]);
    i++;
  }
  // 各テンプレを処理。
  while (i < lines.length) {
    final List<String> templateLines = <String>[];
    if (lines[i].startsWith('=== ')) {
      templateLines.add(lines[i]);
      i++;
      while (i < lines.length && !lines[i].startsWith('=== ')) {
        templateLines.add(lines[i]);
        i++;
      }
      final String? name = _extractName(templateLines[0]);
      if (name != null && names.contains(name)) {
        // skip
        continue;
      }
      output.addAll(templateLines);
    } else {
      output.add(lines[i]);
      i++;
    }
  }
  // 末尾の連続空行は 1 行にトリム
  while (output.length >= 2 &&
      output[output.length - 1].isEmpty &&
      output[output.length - 2].isEmpty) {
    output.removeLast();
  }
  File(path).writeAsStringSync(output.join('\n'));
}

String? _extractName(String headerLine) {
  // "=== name: 金矢倉" → "金矢倉"
  const String prefix = '=== name:';
  if (!headerLine.startsWith(prefix)) return null;
  return headerLine.substring(prefix.length).trim();
}
