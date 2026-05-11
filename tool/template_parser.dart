// ASCII テンプレ → 中間表現パーサ。
//
// data/castles.txt / data/strategies.txt を読み、ParsedTemplate のリストを
// 返す standalone モジュール。lib/src/* には依存しない (PieceType の文字列
// 名のみ受け渡す)。tool/generate_*.dart と tool/export_*_to_ascii.dart の
// 双方で再利用する。
//
// ファイル仕様の詳細は docs/plans/ascii-codegen.md を参照。

/// パース結果の 1 テンプレ。
class ParsedTemplate {
  ParsedTemplate({
    required this.name,
    required this.parent,
    required this.aliases,
    required this.side,
    required this.placements,
    required this.sourceLine,
  });

  /// 必須: テンプレ名 (例: '金矢倉')
  final String name;

  /// 任意: 親テンプレ名
  final String? parent;

  /// 任意: 別名リスト
  final List<String> aliases;

  /// 戦法のみ使用: 'ibisha' | 'furibisha' | 'either' | null
  final String? side;

  /// 9×9 グリッドから抽出した placement セル群
  final List<PlacementCell> placements;

  /// `=== name: ...` が登場した行番号 (エラーメッセージ用、1-origin)
  final int sourceLine;
}

/// 配置 1 マス分の中間表現。
class PlacementCell {
  PlacementCell({
    required this.file,
    required this.rank,
    required this.kind,
    required this.pieceTypes,
  });

  /// 1..9 (盤右が 1)
  final int file;

  /// 1..9 (盤上が 1)
  final int rank;

  /// 'exact' | 'anyOf'
  final String kind;

  /// PieceType の Dart enum 名 (例: 'king', 'gold', 'promPawn', 'horse')
  final List<String> pieceTypes;
}

const Map<String, String> _sfenToEnum = <String, String>{
  'K': 'king',
  'R': 'rook',
  'B': 'bishop',
  'G': 'gold',
  'S': 'silver',
  'N': 'knight',
  'L': 'lance',
  'P': 'pawn',
  '+P': 'promPawn',
  '+L': 'promLance',
  '+N': 'promKnight',
  '+S': 'promSilver',
  '+B': 'horse',
  '+R': 'dragon',
};

/// SFEN ライクな駒トークン (`K`, `+P` 等) を PieceType の enum 名に変換する。
String sfenTokenToEnumName(String token) {
  final String? enumName = _sfenToEnum[token];
  if (enumName == null) {
    throw FormatException('unknown piece token: "$token"');
  }
  return enumName;
}

/// テンプレファイル本文をパースする。
List<ParsedTemplate> parseTemplateFile(String content) {
  final List<String> lines = content.split('\n');
  final List<ParsedTemplate> results = <ParsedTemplate>[];

  // Sliding window state for the current section being parsed.
  int? sectionStartLine;
  String? sectionName;
  String? sectionParent;
  List<String> sectionAliases = <String>[];
  String? sectionSide;
  final List<List<String>> gridRows = <List<String>>[];

  void finalizeSection() {
    if (sectionName == null) return;
    if (gridRows.length != 9) {
      throw FormatException(
        'section "$sectionName" (line $sectionStartLine): '
        'expected 9 grid rows, got ${gridRows.length}',
      );
    }
    final List<PlacementCell> placements = <PlacementCell>[];
    for (int rowIdx = 0; rowIdx < 9; rowIdx++) {
      final List<String> row = gridRows[rowIdx];
      if (row.length != 9) {
        throw FormatException(
          'section "$sectionName": expected 9 cells at row ${rowIdx + 1}, '
          'got ${row.length}',
        );
      }
      final int rank = rowIdx + 1; // top→bottom
      for (int colIdx = 0; colIdx < 9; colIdx++) {
        final String cell = row[colIdx];
        if (cell == '.') continue;
        final int file = 9 - colIdx; // left→right = file 9..1
        final _Cell parsed = _parseCellToken(cell, sectionName!, rowIdx + 1);
        placements.add(
          PlacementCell(
            file: file,
            rank: rank,
            kind: parsed.kind,
            pieceTypes: parsed.pieceTypes,
          ),
        );
      }
    }
    results.add(
      ParsedTemplate(
        name: sectionName!,
        parent: sectionParent,
        aliases: List<String>.unmodifiable(sectionAliases),
        side: sectionSide,
        placements: List<PlacementCell>.unmodifiable(placements),
        sourceLine: sectionStartLine ?? 0,
      ),
    );
  }

  void resetSection() {
    sectionStartLine = null;
    sectionName = null;
    sectionParent = null;
    sectionAliases = <String>[];
    sectionSide = null;
    gridRows.clear();
  }

  for (int i = 0; i < lines.length; i++) {
    final int lineNo = i + 1;
    final String raw = lines[i];
    final String stripped = _stripComments(raw).trim();
    if (stripped.isEmpty) continue;

    if (stripped.startsWith('===')) {
      // Finalize previous section (if any) before starting a new one.
      if (sectionName != null) {
        finalizeSection();
        resetSection();
      }
      final _Header header = _parseHeaderTriple(stripped, lineNo);
      if (header.key != 'name') {
        throw FormatException(
          'line $lineNo: expected "=== name: <name>", got "$stripped"',
        );
      }
      sectionStartLine = lineNo;
      sectionName = header.value;
      continue;
    }

    if (sectionName == null) {
      throw FormatException(
        'line $lineNo: content outside of any section: "$stripped"',
      );
    }

    // Header (key: value) lines come before any grid row.
    if (gridRows.isEmpty && stripped.contains(':')) {
      final _Header header = _parseHeader(stripped, lineNo);
      switch (header.key) {
        case 'parent':
          sectionParent = header.value;
          break;
        case 'aliases':
          sectionAliases = header.value
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty)
              .toList();
          break;
        case 'side':
          final String v = header.value;
          if (v != 'ibisha' && v != 'furibisha' && v != 'either') {
            throw FormatException(
              'line $lineNo: side must be ibisha|furibisha|either, got "$v"',
            );
          }
          sectionSide = v;
          break;
        case 'description':
          // Intentionally ignored (human comment).
          break;
        default:
          throw FormatException(
            'line $lineNo: unknown header "${header.key}"',
          );
      }
      continue;
    }

    // Otherwise this is a grid row.
    final List<String> cells = stripped.split(RegExp(r'\s+'));
    gridRows.add(cells);
  }

  if (sectionName != null) {
    finalizeSection();
  }
  return results;
}

class _Header {
  const _Header(this.key, this.value);
  final String key;
  final String value;
}

_Header _parseHeader(String line, int lineNo) {
  final int idx = line.indexOf(':');
  if (idx < 0) {
    throw FormatException('line $lineNo: expected "key: value", got "$line"');
  }
  final String key = line.substring(0, idx).trim();
  final String value = line.substring(idx + 1).trim();
  if (key.isEmpty) {
    throw FormatException('line $lineNo: empty key in "$line"');
  }
  return _Header(key, value);
}

/// `=== name: 金矢倉` → ('name', '金矢倉')
_Header _parseHeaderTriple(String line, int lineNo) {
  // Strip leading "===".
  final String rest = line.substring(3).trimLeft();
  return _parseHeader(rest, lineNo);
}

String _stripComments(String line) {
  // `#` or `//` introduces a comment to end-of-line. Tokens never contain
  // these characters, so a substring match is sufficient.
  int cut = line.length;
  final int hashIdx = line.indexOf('#');
  if (hashIdx >= 0 && hashIdx < cut) cut = hashIdx;
  final int slashIdx = line.indexOf('//');
  if (slashIdx >= 0 && slashIdx < cut) cut = slashIdx;
  return line.substring(0, cut);
}

class _Cell {
  const _Cell(this.kind, this.pieceTypes);
  final String kind;
  final List<String> pieceTypes;
}

_Cell _parseCellToken(String token, String section, int row) {
  if (token.startsWith('[')) {
    if (!token.endsWith(']')) {
      throw FormatException(
        'section "$section" row $row: unterminated alternation: "$token"',
      );
    }
    final String inner = token.substring(1, token.length - 1);
    if (inner.isEmpty) {
      throw FormatException(
        'section "$section" row $row: empty alternation "[]"',
      );
    }
    final List<String> pieces =
        _tokenizeAlternation(inner).map(sfenTokenToEnumName).toList();
    if (pieces.isEmpty) {
      throw FormatException(
        'section "$section" row $row: empty alternation in "$token"',
      );
    }
    return _Cell('anyOf', pieces);
  }
  return _Cell('exact', <String>[sfenTokenToEnumName(token)]);
}

/// `[GS]` → ['G', 'S'] / `[G+R]` → ['G', '+R'] / `[+P +L]` → ['+P', '+L'].
List<String> _tokenizeAlternation(String inner) {
  final List<String> out = <String>[];
  int i = 0;
  while (i < inner.length) {
    final String c = inner[i];
    if (c == ' ' || c == '\t' || c == ',') {
      i++;
      continue;
    }
    if (c == '+') {
      if (i + 1 >= inner.length) {
        throw FormatException('dangling "+" in alternation "[$inner]"');
      }
      out.add('+${inner[i + 1]}');
      i += 2;
      continue;
    }
    out.add(c);
    i++;
  }
  return out;
}

// ===========================================================================
// 共通ユーティリティ — generator / exporter から呼ぶ。
// ===========================================================================

const Map<String, String> _enumToSfen = <String, String>{
  'king': 'K',
  'rook': 'R',
  'bishop': 'B',
  'gold': 'G',
  'silver': 'S',
  'knight': 'N',
  'lance': 'L',
  'pawn': 'P',
  'promPawn': '+P',
  'promLance': '+L',
  'promKnight': '+N',
  'promSilver': '+S',
  'horse': '+B',
  'dragon': '+R',
};

/// PieceType enum 名 (`'king'`, `'horse'` 等) を ASCII セルトークンに変換する。
String enumNameToSfenToken(String enumName) {
  final String? t = _enumToSfen[enumName];
  if (t == null) {
    throw ArgumentError('unknown enum name: "$enumName"');
  }
  return t;
}

/// 配置リストから 9×9 のグリッド (`.`/トークン) を組み立てる。
/// 衝突 (同マスに 2 つ) が出たら ArgumentError。
List<List<String>> buildGrid(List<PlacementCell> placements) {
  final List<List<String>> grid = List<List<String>>.generate(
    9,
    (_) => List<String>.filled(9, '.'),
  );
  for (final PlacementCell p in placements) {
    final int rowIdx = p.rank - 1;
    final int colIdx = 9 - p.file;
    if (rowIdx < 0 || rowIdx > 8 || colIdx < 0 || colIdx > 8) {
      throw ArgumentError(
        'placement out of board: file=${p.file} rank=${p.rank}',
      );
    }
    if (grid[rowIdx][colIdx] != '.') {
      throw ArgumentError(
        'duplicate placement at file=${p.file} rank=${p.rank}',
      );
    }
    grid[rowIdx][colIdx] = _cellToToken(p);
  }
  return grid;
}

String _cellToToken(PlacementCell p) {
  if (p.kind == 'exact') {
    return enumNameToSfenToken(p.pieceTypes.single);
  }
  // anyOf
  final String joined = p.pieceTypes.map(enumNameToSfenToken).join('');
  return '[$joined]';
}
