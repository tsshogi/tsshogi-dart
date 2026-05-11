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
    this.plyEq,
    this.plyMax,
  });

  /// 必須: テンプレ名 (例: '金矢倉')
  final String name;

  /// 任意: 親テンプレ名
  final String? parent;

  /// 任意: 別名リスト
  final List<String> aliases;

  /// 戦法のみ使用: 'ibisha' | 'furibisha' | 'either' | null
  final String? side;

  /// グリッド + ヘッダから抽出した要件セル群。
  ///
  /// `PlacementCell.kind` の値で per-cell / position-wide を区別する:
  /// - per-cell:  `'exact'`, `'anyOf'`, `'empty'`, `'notOf'`, `'anyPiece'`
  /// - position-wide: `'pieceAnywhere'`, `'handPiece'`
  final List<PlacementCell> placements;

  /// `=== name: ...` が登場した行番号 (エラーメッセージ用、1-origin)
  final int sourceLine;

  /// `ply:` ヘッダから抽出した厳密一致制約。
  final int? plyEq;

  /// `ply:` ヘッダから抽出した手数上限制約。
  final int? plyMax;
}

/// 要件 1 件分の中間表現。per-cell と position-wide のどちらも 1 つの型で
/// 表現する (位置 + 駒種 + min count を選択的に保持)。
class PlacementCell {
  PlacementCell({
    required this.kind,
    this.file = 0,
    this.rank = 0,
    this.pieceTypes = const <String>[],
    this.minCount = 1,
  });

  /// 要件種別。
  /// - per-cell:  `'exact'`, `'anyOf'`, `'empty'`, `'notOf'`, `'anyPiece'`
  /// - position-wide: `'pieceAnywhere'`, `'handPiece'`
  /// - history-based: `'pieceUnmoved'`, `'pieceVisited'`
  final String kind;

  /// 1..9 (盤右が 1)。position-wide kind では 0 (unused)。
  final int file;

  /// 1..9 (盤上が 1)。position-wide kind では 0 (unused)。
  final int rank;

  /// PieceType の Dart enum 名 (例: 'king', 'gold', 'promPawn', 'horse')。
  /// - `'exact'` / `'anyPiece'` / `'empty'`: AnyPiece は空、それ以外は単/複数
  /// - `'anyOf'`: 候補駒種リスト
  /// - `'notOf'`: 除外駒種リスト
  /// - `'pieceAnywhere'` / `'handPiece'`: 単一要素
  final List<String> pieceTypes;

  /// `'handPiece'` 専用: 最低必要枚数 (デフォルト 1)。他 kind では未使用。
  final int minCount;
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
  int? sectionPlyEq;
  int? sectionPlyMax;
  final List<PlacementCell> sectionExtras = <PlacementCell>[];
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
    // board:/hand: ヘッダは grid の後ろに連結 (順序は決定論的)。
    placements.addAll(sectionExtras);
    results.add(
      ParsedTemplate(
        name: sectionName!,
        parent: sectionParent,
        aliases: List<String>.unmodifiable(sectionAliases),
        side: sectionSide,
        placements: List<PlacementCell>.unmodifiable(placements),
        sourceLine: sectionStartLine ?? 0,
        plyEq: sectionPlyEq,
        plyMax: sectionPlyMax,
      ),
    );
  }

  void resetSection() {
    sectionStartLine = null;
    sectionName = null;
    sectionParent = null;
    sectionAliases = <String>[];
    sectionSide = null;
    sectionPlyEq = null;
    sectionPlyMax = null;
    sectionExtras.clear();
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
        case 'board':
          // `board: B R G` → 駒種ごとに PieceAnywhere セルを 1 つ追加。
          for (final String token in _splitPieceTokens(header.value)) {
            sectionExtras.add(
              PlacementCell(
                kind: 'pieceAnywhere',
                pieceTypes: <String>[sfenTokenToEnumName(token)],
              ),
            );
          }
          break;
        case 'hand':
          // `hand: B*2 R` → 各トークンを HandPiece セルに展開。`X*N` で N 枚指定。
          for (final String token in _splitPieceTokens(header.value)) {
            final int starIdx = token.indexOf('*');
            final String pieceToken;
            final int minCount;
            if (starIdx < 0) {
              pieceToken = token;
              minCount = 1;
            } else {
              pieceToken = token.substring(0, starIdx);
              final int? n = int.tryParse(token.substring(starIdx + 1));
              if (n == null || n < 1) {
                throw FormatException(
                  'line $lineNo: invalid hand count in "$token"',
                );
              }
              minCount = n;
            }
            sectionExtras.add(
              PlacementCell(
                kind: 'handPiece',
                pieceTypes: <String>[sfenTokenToEnumName(pieceToken)],
                minCount: minCount,
              ),
            );
          }
          break;
        case 'description':
          // Intentionally ignored (human comment).
          break;
        case 'ply':
          // `ply: 3` → plyEq=3
          // `ply: max 10` → plyMax=10
          // `ply: 3, max 10` → plyEq=3, plyMax=10 (rare)
          final ({int? eq, int? max}) parsed =
              _parsePlyHeader(header.value, lineNo);
          if (parsed.eq != null) sectionPlyEq = parsed.eq;
          if (parsed.max != null) sectionPlyMax = parsed.max;
          break;
        case 'unmoved':
          // `unmoved: K 5 9` → PieceUnmoved(5, 9)
          // (駒種トークンは要件本体に不要だが、可読性のため形式は必須)
          final ({int file, int rank}) coord =
              _parseHistoryHeader(header.value, lineNo, 'unmoved');
          sectionExtras.add(
            PlacementCell(
              kind: 'pieceUnmoved',
              file: coord.file,
              rank: coord.rank,
            ),
          );
          break;
        case 'visited':
          // `visited: R 6 8` → PieceVisited(6, 8, rook)
          final ({String piece, int file, int rank}) v =
              _parseVisitedHeader(header.value, lineNo);
          sectionExtras.add(
            PlacementCell(
              kind: 'pieceVisited',
              file: v.file,
              rank: v.rank,
              pieceTypes: <String>[v.piece],
            ),
          );
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

/// `B R G` や `B*2 R` のような whitespace 区切りトークン列を分解する。
List<String> _splitPieceTokens(String value) {
  return value.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
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

/// `unmoved: K 5 9` の値部分 (`K 5 9`) をパースする。
///
/// 駒種トークン (例: `K`) は可読性のため必須だが、`PieceUnmoved` 自体は駒種
/// を保持しないので捨てる。
({int file, int rank}) _parseHistoryHeader(
  String value,
  int lineNo,
  String headerKey,
) {
  final List<String> tokens =
      value.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (tokens.length != 3) {
    throw FormatException(
      'line $lineNo: expected "$headerKey: <piece> <file> <rank>", '
      'got "$value"',
    );
  }
  // 駒種は parse して valid であることだけ確認 (捨てる)。
  sfenTokenToEnumName(tokens[0]);
  final int? file = int.tryParse(tokens[1]);
  final int? rank = int.tryParse(tokens[2]);
  if (file == null ||
      rank == null ||
      file < 1 ||
      file > 9 ||
      rank < 1 ||
      rank > 9) {
    throw FormatException(
      'line $lineNo: invalid coordinates in "$headerKey: $value"',
    );
  }
  return (file: file, rank: rank);
}

/// `visited: R 6 8` の値部分 (`R 6 8`) をパースする。
({String piece, int file, int rank}) _parseVisitedHeader(
  String value,
  int lineNo,
) {
  final List<String> tokens =
      value.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (tokens.length != 3) {
    throw FormatException(
      'line $lineNo: expected "visited: <piece> <file> <rank>", got "$value"',
    );
  }
  final String enumName = sfenTokenToEnumName(tokens[0]);
  final int? file = int.tryParse(tokens[1]);
  final int? rank = int.tryParse(tokens[2]);
  if (file == null ||
      rank == null ||
      file < 1 ||
      file > 9 ||
      rank < 1 ||
      rank > 9) {
    throw FormatException(
      'line $lineNo: invalid coordinates in "visited: $value"',
    );
  }
  return (piece: enumName, file: file, rank: rank);
}

/// `ply:` ヘッダ値をパースする。
///
/// 受け入れる形式:
/// - `3` → eq=3
/// - `max 10` → max=10
/// - `3, max 10` → eq=3, max=10
({int? eq, int? max}) _parsePlyHeader(String value, int lineNo) {
  int? eq;
  int? max;
  final List<String> parts = value
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();
  for (final String part in parts) {
    if (part.startsWith('max')) {
      final String numStr = part.substring(3).trim();
      final int? n = int.tryParse(numStr);
      if (n == null || n < 0) {
        throw FormatException(
          'line $lineNo: invalid ply max value "$part"',
        );
      }
      max = n;
    } else {
      final int? n = int.tryParse(part);
      if (n == null || n < 0) {
        throw FormatException(
          'line $lineNo: invalid ply eq value "$part"',
        );
      }
      eq = n;
    }
  }
  return (eq: eq, max: max);
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
  // Empty marker.
  if (token == '_') return const _Cell('empty', <String>[]);
  // Wildcard: any piece of the side.
  if (token == '*') return const _Cell('anyPiece', <String>[]);

  if (token.startsWith('[')) {
    if (!token.endsWith(']')) {
      throw FormatException(
        'section "$section" row $row: unterminated alternation: "$token"',
      );
    }
    String inner = token.substring(1, token.length - 1);
    if (inner.isEmpty) {
      throw FormatException(
        'section "$section" row $row: empty alternation "[]"',
      );
    }
    // `[!GS]` → NotOfPieces with excluded gold/silver.
    final bool negated = inner.startsWith('!');
    if (negated) {
      inner = inner.substring(1);
      if (inner.isEmpty) {
        throw FormatException(
          'section "$section" row $row: empty exclusion in "[!]"',
        );
      }
    }
    final List<String> pieces =
        _tokenizeAlternation(inner).map(sfenTokenToEnumName).toList();
    if (pieces.isEmpty) {
      throw FormatException(
        'section "$section" row $row: empty alternation in "$token"',
      );
    }
    return _Cell(negated ? 'notOf' : 'anyOf', pieces);
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
///
/// position-wide kind (`pieceAnywhere`, `handPiece`) はグリッドには出ない
/// ので無視される。これらは `formatBoardHeader` / `formatHandHeader` で
/// 別途出力する。
List<List<String>> buildGrid(List<PlacementCell> placements) {
  final List<List<String>> grid = List<List<String>>.generate(
    9,
    (_) => List<String>.filled(9, '.'),
  );
  for (final PlacementCell p in placements) {
    if (p.kind == 'pieceAnywhere' ||
        p.kind == 'handPiece' ||
        p.kind == 'pieceUnmoved' ||
        p.kind == 'pieceVisited') {
      continue;
    }
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
  switch (p.kind) {
    case 'exact':
      return enumNameToSfenToken(p.pieceTypes.single);
    case 'anyOf':
      final String joined = p.pieceTypes.map(enumNameToSfenToken).join('');
      return '[$joined]';
    case 'notOf':
      final String joined = p.pieceTypes.map(enumNameToSfenToken).join('');
      return '[!$joined]';
    case 'empty':
      return '_';
    case 'anyPiece':
      return '*';
    default:
      throw ArgumentError('unsupported per-cell kind: ${p.kind}');
  }
}

/// `board: B R G` 形式の 1 行を返す。position-wide な `pieceAnywhere` セルが
/// 1 つも無ければ `null`。
String? formatBoardHeader(List<PlacementCell> placements) {
  final List<String> tokens = <String>[];
  for (final PlacementCell p in placements) {
    if (p.kind != 'pieceAnywhere') continue;
    tokens.add(enumNameToSfenToken(p.pieceTypes.single));
  }
  if (tokens.isEmpty) return null;
  return 'board: ${tokens.join(' ')}';
}

/// `ply: 3, max 10` 形式の 1 行を返す。`plyEq` / `plyMax` が両方 null なら
/// `null`。両方が null でない場合は `ply: <eq>, max <max>`、いずれか片方なら
/// 該当部分のみを返す。
String? formatPlyHeader({int? plyEq, int? plyMax}) {
  if (plyEq == null && plyMax == null) return null;
  final List<String> parts = <String>[];
  if (plyEq != null) parts.add('$plyEq');
  if (plyMax != null) parts.add('max $plyMax');
  return 'ply: ${parts.join(', ')}';
}

/// `unmoved: <piece> <file> <rank>` 形式の行を 0 件以上返す。
///
/// `PieceUnmoved` は駒種を持たないが、可読性のためマスにある駒種を引数で
/// 渡す。代表的な使い方は「居玉 = K 5 9」のように玉専用なので、自然な
/// `K` を出力する。指定が無い場合は `?` を出す (パーサ側では捨てるので
/// 動作には影響しないが、人間が読めなくなる)。
///
/// 出力順序はリスト順 (= 配置時に同順)。
List<String> formatUnmovedHeaders(List<PlacementCell> placements,
    {String fallbackPieceToken = 'K'}) {
  final List<String> out = <String>[];
  for (final PlacementCell p in placements) {
    if (p.kind != 'pieceUnmoved') continue;
    final String piece = p.pieceTypes.isNotEmpty
        ? enumNameToSfenToken(p.pieceTypes.single)
        : fallbackPieceToken;
    out.add('unmoved: $piece ${p.file} ${p.rank}');
  }
  return out;
}

/// `visited: <piece> <file> <rank>` 形式の行を 0 件以上返す。
List<String> formatVisitedHeaders(List<PlacementCell> placements) {
  final List<String> out = <String>[];
  for (final PlacementCell p in placements) {
    if (p.kind != 'pieceVisited') continue;
    final String piece = enumNameToSfenToken(p.pieceTypes.single);
    out.add('visited: $piece ${p.file} ${p.rank}');
  }
  return out;
}

/// `hand: B*2 R` 形式の 1 行を返す。position-wide な `handPiece` セルが
/// 1 つも無ければ `null`。`minCount == 1` は `*N` を省略。
String? formatHandHeader(List<PlacementCell> placements) {
  final List<String> tokens = <String>[];
  for (final PlacementCell p in placements) {
    if (p.kind != 'handPiece') continue;
    final String piece = enumNameToSfenToken(p.pieceTypes.single);
    tokens.add(p.minCount == 1 ? piece : '$piece*${p.minCount}');
  }
  if (tokens.isEmpty) return null;
  return 'hand: ${tokens.join(' ')}';
}
