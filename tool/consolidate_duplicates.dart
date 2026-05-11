// Consolidates templates that share identical placement signatures.
//
// 同一の placement signature を持つテンプレ群を検出し、最短名を canonical
// (代表) として残し、それ以外を canonical の `aliases` に統合する。データを
// data/castles.txt および data/strategies.txt に書き戻す。
//
// 使い方:
//   dart run tool/consolidate_duplicates.dart [--dry-run]
//
// --dry-run を付けると標準出力に変更案を表示するだけで書き込まない。

import 'dart:io';

import 'template_parser.dart';

void main(List<String> args) {
  final bool dryRun = args.contains('--dry-run');
  for (final String path in <String>[
    'data/castles.txt',
    'data/strategies.txt',
  ]) {
    _processFile(path, dryRun: dryRun);
  }
}

void _processFile(String path, {required bool dryRun}) {
  final String content = File(path).readAsStringSync();
  final List<ParsedTemplate> templates = parseTemplateFile(content);

  // Group by placement signature.
  final Map<String, List<int>> groups = <String, List<int>>{};
  for (int i = 0; i < templates.length; i++) {
    final String sig = _signature(templates[i]);
    groups.putIfAbsent(sig, () => <int>[]).add(i);
  }

  // Find duplicates.
  final List<List<int>> dupGroups =
      groups.values.where((List<int> indices) => indices.length > 1).toList();

  if (dupGroups.isEmpty) {
    stdout.writeln('$path: no duplicate placements found');
    return;
  }

  stdout.writeln('=== $path ===');
  // For each duplicate group, pick canonical via in-group root analysis.
  //   - "in-group root" = a template in the group whose parent is NOT in the
  //     group (i.e. it is not a child of another group member).
  //   - If exactly one in-group root → canonical.
  //   - Otherwise → heterogeneous (e.g. 矢倉 ≠ 角換わり), do NOT merge.
  final Set<int> toRemove = <int>{};
  final Map<int, List<String>> additionalAliases = <int, List<String>>{};

  for (final List<int> group in dupGroups) {
    final Set<String> groupNames = <String>{
      for (final int i in group) templates[i].name,
    };
    final List<int> roots = <int>[];
    for (final int i in group) {
      final String? parent = templates[i].parent;
      if (parent == null || !groupNames.contains(parent)) {
        roots.add(i);
      }
    }
    if (roots.length != 1) {
      stdout.writeln(
        '  [skip heterogeneous] '
        '${group.map((int i) => templates[i].name).join(" / ")} '
        '(roots: ${roots.map((int i) => templates[i].name).join(", ")})',
      );
      continue;
    }
    final int canonicalIdx = roots.first;
    final ParsedTemplate canonical = templates[canonicalIdx];
    final List<String> mergedAliases = <String>[...canonical.aliases];
    final List<String> mergedNames = <String>[];

    for (final int idx in group) {
      if (idx == canonicalIdx) continue;
      final ParsedTemplate other = templates[idx];
      mergedNames.add(other.name);
      if (!mergedAliases.contains(other.name)) {
        mergedAliases.add(other.name);
      }
      for (final String a in other.aliases) {
        if (a != canonical.name && !mergedAliases.contains(a)) {
          mergedAliases.add(a);
        }
      }
      toRemove.add(idx);
    }
    additionalAliases[canonicalIdx] = mergedAliases;
    stdout.writeln(
      '  ${canonical.name} <= ${mergedNames.join(", ")}',
    );
  }

  if (dryRun) {
    stdout.writeln('  (dry-run; no changes written)');
    return;
  }

  // Emit new file.
  final StringBuffer buf = StringBuffer();
  // Preserve top-of-file comments by scanning original until first `===`.
  final List<String> originalLines = content.split('\n');
  for (final String line in originalLines) {
    if (line.startsWith('=== ')) break;
    buf.writeln(line);
  }
  for (int i = 0; i < templates.length; i++) {
    if (toRemove.contains(i)) continue;
    final ParsedTemplate t = templates[i];
    final List<String> aliases = additionalAliases[i] ?? t.aliases;
    _writeTemplate(buf, t, aliases);
  }
  File(path).writeAsStringSync(buf.toString());
  stdout.writeln('  written: ${templates.length - toRemove.length} templates '
      '(${toRemove.length} merged as aliases)');
}

String _signature(ParsedTemplate t) {
  // Stable signature based on sorted placement cells.
  final List<String> cells = t.placements.map((PlacementCell c) {
    switch (c.kind) {
      case 'exact':
        return '${c.file},${c.rank},exact,${c.pieceTypes.single}';
      case 'anyOf':
        final List<String> sorted = List<String>.from(c.pieceTypes)..sort();
        return '${c.file},${c.rank},anyOf,${sorted.join("|")}';
      case 'notOf':
        final List<String> sorted = List<String>.from(c.pieceTypes)..sort();
        return '${c.file},${c.rank},notOf,${sorted.join("|")}';
      case 'empty':
        return '${c.file},${c.rank},empty';
      case 'anyPiece':
        return '${c.file},${c.rank},anyPiece';
      case 'pieceAnywhere':
        return 'board,${c.pieceTypes.single}';
      case 'handPiece':
        return 'hand,${c.pieceTypes.single},${c.minCount}';
      default:
        throw ArgumentError('unknown kind: ${c.kind}');
    }
  }).toList()
    ..sort();
  return cells.join(';');
}

void _writeTemplate(
  StringBuffer buf,
  ParsedTemplate t,
  List<String> aliases,
) {
  buf.writeln('=== name: ${t.name}');
  if (t.parent != null) buf.writeln('parent: ${t.parent}');
  if (aliases.isNotEmpty) buf.writeln('aliases: ${aliases.join(', ')}');
  if (t.side != null && t.side != 'either') buf.writeln('side: ${t.side}');
  final String? boardLine = formatBoardHeader(t.placements);
  if (boardLine != null) buf.writeln(boardLine);
  final String? handLine = formatHandHeader(t.placements);
  if (handLine != null) buf.writeln(handLine);
  buf.writeln();
  final List<List<String>> grid = buildGrid(t.placements);
  for (int r = 0; r < 9; r++) {
    buf.writeln(grid[r].join(' '));
  }
  buf.writeln();
}
