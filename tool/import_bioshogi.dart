// Ruby (bioshogi) ASCII テンプレ → Dart データ形式インポータ。
//
// 使い方:
//   dart run tool/import_bioshogi.dart [--dry-run]
//
// 入力:
//   /tmp/bioshogi/lib/bioshogi/analysis/shape_info.rb     (盤面 ASCII テンプレ)
//   /tmp/bioshogi/lib/bioshogi/analysis/defense_info.rb   (囲いメタ)
//   /tmp/bioshogi/lib/bioshogi/analysis/attack_info.rb    (戦法メタ)
//
// 出力:
//   data/castles.txt     (defense_info × shape_info の積集合)
//   data/strategies.txt  (attack_info × shape_info の積集合)
//
// 法的整理: 駒の (file, rank, type) 座標と名称は事実情報 (uncopyrightable)
// として扱う。bioshogi 由来の ASCII 表現や DSL は本ファイルには持ち込まず、
// Dart の構造体としてのみ再構成する。
//
// 実装上の注記:
// - shape_info.rb の各テンプレ body は ASCII 罫線 + 段ラベル付きの 9 列
//   グリッド。完全な 9 行とは限らず、段ラベル (`|六` 等) で部分グリッドを
//   表現することがある。
// - セルトークンの種類: 自駒 (例: `玉`, `銀`, `歩`)、相手駒 (`v歩`)、
//   prefix `! @ * ~ ? ^` 付き、wildcard `・ ○ ● ◆ ■ □ ◇`、移動元
//   マーカー `★ ☆`。詳細は本ファイル中の _parseCell を参照。
// - 相手駒・移動元マーカーは本リポジトリの「自陣 1 サイドのみのテンプレ」
//   モデルでは扱わないので SKIP する。

import 'dart:io';

import 'template_parser.dart';

// ---------------------------------------------------------------------------
// 駒文字 → SFEN トークン (template_parser と互換)
// ---------------------------------------------------------------------------

const Map<String, String> _kanjiToSfen = <String, String>{
  '玉': 'K',
  '王': 'K',
  '飛': 'R',
  '角': 'B',
  '金': 'G',
  '銀': 'S',
  '桂': 'N',
  '香': 'L',
  '歩': 'P',
  'と': '+P',
  '馬': '+B',
  '竜': '+R',
  '龍': '+R',
  '全': '+S',
  '圭': '+N',
  '杏': '+L',
};

// ---------------------------------------------------------------------------
// shape_info.rb パース
// ---------------------------------------------------------------------------

class _ShapeRecord {
  _ShapeRecord({
    required this.key,
    required this.cells,
    required this.hasKing,
    this.primary,
  });
  final String key;
  final List<PlacementCell> cells;
  final bool hasKing;

  /// プライマリトリガー (`!<駒>`) のマスと駒種。drop_only 適用先として使う。
  final ({int file, int rank, String pieceEnum})? primary;
}

/// shape_info.rb 全体を読み、`{ key: ..., body: <<~EOT ... EOT }` ブロックを
/// 抽出して PlacementCell 列に変換する。
// ignore: library_private_types_in_public_api
Map<String, _ShapeRecord> parseShapeInfo(String source) {
  final Map<String, _ShapeRecord> out = <String, _ShapeRecord>{};
  final List<String> lines = source.split('\n');

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    final RegExpMatch? km = RegExp(r'key:\s*"([^"]+)"').firstMatch(line);
    if (km == null) continue;
    final String key = km.group(1)!;
    // ブロック body 開始 (<<~EOT) を探す
    int j = i;
    while (j < lines.length && !lines[j].contains('<<~EOT')) {
      j++;
    }
    if (j >= lines.length) continue;
    // EOT 終端まで本文
    final List<String> body = <String>[];
    int k = j + 1;
    while (k < lines.length && lines[k].trim() != 'EOT') {
      body.add(lines[k]);
      k++;
    }
    final _ShapeRecord rec = _parseAsciiBody(key, body);
    out[key] = rec;
    i = k;
  }
  return out;
}

/// ASCII body をパースして PlacementCell 列を作る。
///
/// 例:
/// ```
/// +---------------------------+
/// | ・ ・ 歩 歩 ・ ・ ・ ・ ・|六
/// | ・ 歩 銀 金 ・ ・ ・ ・ ・|七
/// | ・ 玉 金 ・ ・ ・ ・ ・ ・|八
/// | ・ ・ ・ ・ ・ ・ ・ ・ ・|九
/// +---------------------------+
/// ```
/// - frame `+---+` は無視
/// - 行末の段ラベル (`|六`) を読んで rank を決定
/// - ラベルが無い行は「右上原点で上から順」になるが、castle/strategy 用途
///   では現状ラベル付きしか出現しない (TODO: 必要なら後で対応)
_ShapeRecord _parseAsciiBody(String key, List<String> bodyLines) {
  final List<PlacementCell> cells = <PlacementCell>[];
  // bioshogi の `★` (移動元マーカー) は「この駒が過去にここを通った」を
  // 表す。テンプレ内の `!<駒>` (primary trigger) と組にして PieceVisited 要件
  // に展開する。`★` が出てきた (file, rank) を一旦集めておき、`!<駒>` が
  // 同テンプレ内で見つかったら全 visited セルにその駒種を割り当てる。
  final List<({int file, int rank})> visitedSquares =
      <({int file, int rank})>[];
  String? primaryPieceEnum;
  ({int file, int rank, String pieceEnum})? primary;
  bool hasKing = false;
  // bioshogi の `*駒` (▲側 OR) / `?駒` (△側 OR) はテンプレ内の同駒種マスを 1 つの
  // OR グループにまとめる (= AnyPlacement)。駒種ごとに候補マスを集める。
  final Map<String, List<({int file, int rank})>> starGroups =
      <String, List<({int file, int rank})>>{};
  final Map<String, List<({int file, int rank})>> queryGroups =
      <String, List<({int file, int rank})>>{};
  // 段ラベルがある行のみ採用。ラベルがない場合、テンプレ全体としては平手
  // 等の完全盤面 (9 行) のはず。
  final List<({int rank, String row})> rankedRows =
      <({int rank, String row})>[];
  final List<String> unlabeled = <String>[];
  for (final String raw in bodyLines) {
    final String trimmed = raw.trimRight();
    if (trimmed.startsWith('+') || trimmed.isEmpty) continue;
    if (!trimmed.startsWith('|')) continue;
    // 末尾を `|<段ラベル>` 形式と解釈
    final int barEnd = trimmed.lastIndexOf('|');
    final String afterBar = trimmed.substring(barEnd + 1).trim();
    final int? rank = _kanjiRankToInt(afterBar);
    if (rank != null) {
      rankedRows.add((rank: rank, row: trimmed.substring(0, barEnd + 1)));
    } else {
      unlabeled.add(trimmed);
    }
  }

  void handleToken(_CellTok t, int file, int rank) {
    if (t.body == '★' || t.body == '☆') {
      // 移動元マーカー → 後で `!<駒>` と組み合わせて PieceVisited に変換。
      // (`☆` は実テンプレでは未使用。出現しても visited 同様に扱う。)
      visitedSquares.add((file: file, rank: rank));
      return;
    }
    // `*駒` (▲OR) / `?駒` (△OR) → 駒種ごとに OR 候補マスを集約。
    if (t.prefix == '*' || t.prefix == '?') {
      final String? sfen = _kanjiToSfen[t.body];
      if (sfen != null) {
        final String enumName = sfenTokenToEnumName(sfen);
        final Map<String, List<({int file, int rank})>> groups =
            t.prefix == '*' ? starGroups : queryGroups;
        (groups[enumName] ??= <({int file, int rank})>[])
            .add((file: file, rank: rank));
      }
      return;
    }
    final PlacementCell? cell = _toPlacement(t, file, rank);
    if (cell == null) return;
    cells.add(cell);
    if (cell.kind == 'exact' &&
        cell.pieceTypes.length == 1 &&
        cell.pieceTypes.single == 'king') {
      hasKing = true;
    }
    // primary trigger (`!<駒>`) の駒種 + マスを記録 (★/drop_only への充当用)。
    if (t.prefix == '!' &&
        cell.kind == 'exact' &&
        cell.pieceTypes.length == 1) {
      primaryPieceEnum ??= cell.pieceTypes.single;
      primary ??=
          (file: file, rank: rank, pieceEnum: cell.pieceTypes.single);
    }
  }

  if (rankedRows.isNotEmpty) {
    for (final ({int rank, String row}) e in rankedRows) {
      final List<_CellTok> tokens = _splitRow(e.row);
      // 9 列ぴったりが期待値だが、安全のため min を取る
      final int n = tokens.length < 9 ? tokens.length : 9;
      for (int c = 0; c < n; c++) {
        handleToken(tokens[c], 9 - c, e.rank);
      }
    }
  } else if (unlabeled.isNotEmpty) {
    // ラベル無しは「右上原点」モード。castle/strategy テンプレに該当は
    // ほぼ無いはずだが念のため対応する。先頭行 = rank 1 として上から並べる。
    for (int r = 0; r < unlabeled.length; r++) {
      final List<_CellTok> tokens = _splitRow(unlabeled[r]);
      final int n = tokens.length < 9 ? tokens.length : 9;
      for (int c = 0; c < n; c++) {
        handleToken(tokens[c], 9 - c, r + 1);
      }
    }
  }

  // `★` が見つかった場合は `!<駒>` で示された primary piece を当てる。
  // primary が無いテンプレ (= 単体で★だけ) は静的に意味づけられないので
  // 黙って捨てる (この場合 cells に visited は追加されない)。
  if (visitedSquares.isNotEmpty && primaryPieceEnum != null) {
    for (final ({int file, int rank}) v in visitedSquares) {
      cells.add(PlacementCell(
        kind: 'pieceVisited',
        file: v.file,
        rank: v.rank,
        pieceTypes: <String>[primaryPieceEnum!],
      ));
    }
  }

  // `*駒` / `?駒` の OR グループを AnyPlacement に変換。
  void emitAnyGroups(
    Map<String, List<({int file, int rank})>> groups, {
    required bool opponent,
  }) {
    final List<String> keys = groups.keys.toList()..sort();
    for (final String enumName in keys) {
      cells.add(PlacementCell(
        kind: 'anyPlacement',
        pieceTypes: <String>[enumName],
        opponent: opponent,
        squares: groups[enumName]!,
      ));
    }
  }

  emitAnyGroups(starGroups, opponent: false);
  emitAnyGroups(queryGroups, opponent: true);

  return _ShapeRecord(
      key: key, cells: cells, hasKing: hasKing, primary: primary);
}

int? _kanjiRankToInt(String s) {
  const Map<String, int> table = <String, int>{
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  // 段ラベルは通常 1 文字。
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    if (table.containsKey(c)) return table[c]!;
  }
  return null;
}

/// 1 行のセル文字列を 9 個のトークンに分解する。
///
/// bioshogi の行フォーマットは `| <cell1><cell2>...<cell9>|` の形で、
/// 各セルは 2 文字 (prefix + piece) 場合と 1 文字 (`・` などの wildcard)
/// 場合がある。具体的にはセルは「prefix 文字 1 文字 (空白含む) + 主トー
/// クン (駒 or 記号)」の 2 文字単位で並ぶ。
List<_CellTok> _splitRow(String row) {
  // 先頭の `|` を取り、その後をセル列として解釈する。
  String s = row;
  if (s.startsWith('|')) s = s.substring(1);
  // 末尾の `|` も取る。
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);

  final List<_CellTok> out = <_CellTok>[];
  // ランエンコード: 先頭から 2 グリフ単位で読む。
  // ASCII prefix (`!@*?~^v`) と全角文字を区別しつつ、`v駒` (相手駒) と
  // `prefix駒` (両方とも 2 グリフ) を 2-glyph セルとして扱う。
  // 「空白 + 全角文字」は 1 セル分。
  // 採用ロジック: rune を順に取り、空白なら次の文字をセル本体に、
  // ASCII prefix なら次の文字を駒本体に、それ以外なら 1 文字セルにする。
  final List<int> runes = s.runes.toList();
  int i = 0;
  while (i < runes.length) {
    final int r = runes[i];
    final String ch = String.fromCharCode(r);
    if (ch == ' ' || ch == '　') {
      // 半角/全角スペース → 次の rune を主トークンとする 1 セル。
      i++;
      if (i >= runes.length) break;
      final String body = String.fromCharCode(runes[i]);
      out.add(_CellTok(prefix: null, body: body));
      i++;
      continue;
    }
    // prefix 文字?
    if ('!@*?~^v'.contains(ch)) {
      i++;
      if (i >= runes.length) break;
      final String body = String.fromCharCode(runes[i]);
      out.add(_CellTok(prefix: ch, body: body));
      i++;
      continue;
    }
    // 単独の主トークン (prefix なし、空白直前なしのケース)
    out.add(_CellTok(prefix: null, body: ch));
    i++;
  }
  return out;
}

class _CellTok {
  const _CellTok({required this.prefix, required this.body});
  final String? prefix;
  final String body;
}

/// セルトークン → PlacementCell。SKIP すべきセルは null を返す。
PlacementCell? _toPlacement(_CellTok t, int file, int rank) {
  final String? prefix = t.prefix;
  final String body = t.body;
  // `v駒` = 相手 (後手) の駒が指定マスにある (bioshogi の opponent piece)。
  // 駒種を解決して PiecePlacement(color: Color.white) を emit する。
  if (prefix == 'v') {
    final String? sfen = _kanjiToSfen[body];
    if (sfen == null) return null;
    return PlacementCell(
      kind: 'opponent',
      file: file,
      rank: rank,
      pieceTypes: <String>[sfenTokenToEnumName(sfen)],
    );
  }
  // `*駒` (▲OR) / `?駒` (△OR) は handleToken 側で AnyPlacement に集約済み。
  // ここに来たら念のため SKIP。
  if (prefix == '*' || prefix == '?') return null;
  // `^駒` = 「△側でここに含まれない」→ 相手陣の NotOfPieces。
  if (prefix == '^') {
    final String? sfen = _kanjiToSfen[body];
    if (sfen == null) return null;
    return PlacementCell(
      kind: 'notOf',
      file: file,
      rank: rank,
      pieceTypes: <String>[sfenTokenToEnumName(sfen)],
      opponent: true,
    );
  }
  // 移動元マーカー: ★ / ☆ → SKIP (handleToken で処理済み)
  if (body == '★' || body == '☆') return null;
  // 空マス (要件無し)
  if (body == '・') return null;
  // wildcard 系
  if (body == '○') {
    // 「この座標に何もない」(両陣営とも空)。
    return PlacementCell(kind: 'empty', file: file, rank: rank);
  }
  if (body == '●') {
    // 「この座標に何かある」(陣営問わず)。
    return PlacementCell(
        kind: 'anyPiece', file: file, rank: rank, anySide: true);
  }
  if (body == '◇') {
    // 「自分の歩以上がある」= 任意の自駒。
    return PlacementCell(kind: 'anyPiece', file: file, rank: rank);
  }
  if (body == '◆') {
    // 「自分の銀以上 (abs_weight >= 銀) がある」。歩/香/桂のみ除外、それ以外
    // (成駒含む) は銀以上。
    return PlacementCell(
      kind: 'anyOf',
      file: file,
      rank: rank,
      pieceTypes: const <String>[
        'silver',
        'gold',
        'bishop',
        'rook',
        'king',
        'promPawn',
        'promLance',
        'promKnight',
        'promSilver',
        'horse',
        'dragon',
      ],
    );
  }
  if (body == '■') {
    // 「自分の銀 or 金がある」。piece.key ベースなので成銀(全)も銀扱い。
    return PlacementCell(
      kind: 'anyOf',
      file: file,
      rank: rank,
      pieceTypes: const <String>['silver', 'gold', 'promSilver'],
    );
  }
  if (body == '□') {
    // 「自分の銀 or 金がない」。
    return PlacementCell(
      kind: 'notOf',
      file: file,
      rank: rank,
      pieceTypes: const <String>['silver', 'gold', 'promSilver'],
    );
  }
  // 駒記号
  final String? sfen = _kanjiToSfen[body];
  if (sfen == null) return null;
  final String enumName = sfenTokenToEnumName(sfen);
  // prefix ~ → 「▲側でここに含まれない」= 自陣の NotOfPieces。
  if (prefix == '~') {
    return PlacementCell(
      kind: 'notOf',
      file: file,
      rank: rank,
      pieceTypes: <String>[enumName],
    );
  }
  // prefix ! / @ / * / null → exact
  return PlacementCell(
    kind: 'exact',
    file: file,
    rank: rank,
    pieceTypes: <String>[enumName],
  );
}

// ---------------------------------------------------------------------------
// defense_info.rb / attack_info.rb メタデータパース
// ---------------------------------------------------------------------------

class _MetaRecord {
  _MetaRecord({
    required this.key,
    this.parent,
    this.aliases = const <String>[],
    this.turnEq,
    this.turnMax,
    this.dropOnly = false,
    this.holdPieceEmpty = false,
    this.holdPieceIn = const <({String pieceEnum, int count})>[],
  });
  final String key;
  final String? parent;
  final List<String> aliases;

  /// bioshogi の turn_eq (= 当該テンプレが該当する厳密な手数)。
  final int? turnEq;

  /// bioshogi の turn_max (= 当該テンプレが該当する手数の上限)。
  final int? turnMax;

  /// bioshogi の drop_only (= トリガー駒が打ち駒であること)。
  final bool dropOnly;

  /// bioshogi の hold_piece_empty (= 持駒が空であること)。
  final bool holdPieceEmpty;

  /// bioshogi の hold_piece_in (= 持駒に指定駒を含むこと)。レグスペの角交換等。
  final List<({String pieceEnum, int count})> holdPieceIn;
}

/// bioshogi の持駒表記 (例: `"角"`, `"角桂歩2"`) を (駒, 枚数) 列にパースする。
/// 駒は漢字、枚数は駒の直後の算用数字 (無ければ 1)。
List<({String pieceEnum, int count})> _parseHandSpec(String spec) {
  final List<({String pieceEnum, int count})> out =
      <({String pieceEnum, int count})>[];
  int i = 0;
  while (i < spec.length) {
    final String ch = spec[i];
    final String? sfen = _kanjiToSfen[ch];
    if (sfen == null) {
      i++;
      continue;
    }
    int count = 1;
    int j = i + 1;
    final StringBuffer digits = StringBuffer();
    while (j < spec.length && RegExp(r'[0-9]').hasMatch(spec[j])) {
      digits.write(spec[j]);
      j++;
    }
    if (digits.isNotEmpty) count = int.parse(digits.toString());
    out.add((pieceEnum: sfenTokenToEnumName(sfen), count: count));
    i = j;
  }
  return out;
}

// ignore: library_private_types_in_public_api
List<_MetaRecord> parseMetaInfo(String source) {
  final List<_MetaRecord> out = <_MetaRecord>[];
  final List<String> lines = source.split('\n');
  for (final String raw in lines) {
    final String line = raw;
    final String trimmed = line.trimLeft();
    if (!trimmed.startsWith('{')) continue;
    // Ruby のコメント行 (`# { key: ... }`) も skip
    if (trimmed.startsWith('#')) continue;
    final int hashIdx = line.indexOf('#');
    final bool hasHash = hashIdx >= 0 && line.lastIndexOf('{') > hashIdx;
    if (hasHash) continue;
    final RegExpMatch? km = RegExp(r'key:\s*"([^"]+)"').firstMatch(line);
    if (km == null) continue;
    final String key = km.group(1)!;
    // parent
    String? parent;
    final RegExpMatch? pm = RegExp(r'parent:\s*"([^"]+)"').firstMatch(line);
    if (pm != null) {
      parent = pm.group(1);
    }
    // alias_names: "..."  or  alias_names: ["...", "..."]
    final List<String> aliases = <String>[];
    final RegExpMatch? aListM =
        RegExp(r'alias_names:\s*\[([^\]]*)\]').firstMatch(line);
    if (aListM != null) {
      for (final RegExpMatch m
          in RegExp(r'"([^"]+)"').allMatches(aListM.group(1)!)) {
        aliases.add(m.group(1)!);
      }
    } else {
      final RegExpMatch? aStrM =
          RegExp(r'alias_names:\s*"([^"]+)"').firstMatch(line);
      if (aStrM != null) {
        aliases.add(aStrM.group(1)!);
      }
    }
    // turn_eq / turn_max: 整数 (`turn_eq: 3`) or nil (`turn_eq: nil`)。
    int? turnEq;
    final RegExpMatch? tem = RegExp(r'turn_eq:\s*(\d+)').firstMatch(line);
    if (tem != null) {
      turnEq = int.tryParse(tem.group(1)!);
    }
    int? turnMax;
    final RegExpMatch? tmm = RegExp(r'turn_max:\s*(\d+)').firstMatch(line);
    if (tmm != null) {
      turnMax = int.tryParse(tmm.group(1)!);
    }
    // drop_only / hold_piece_empty: `true` のみ採用 (nil/false は無視)。
    final bool dropOnly =
        RegExp(r'drop_only:\s*true').hasMatch(line);
    final bool holdPieceEmpty =
        RegExp(r'hold_piece_empty:\s*true').hasMatch(line);
    // hold_piece_in: "角" 等 → 持駒に含む駒。
    List<({String pieceEnum, int count})> holdPieceIn =
        const <({String pieceEnum, int count})>[];
    final RegExpMatch? hpi =
        RegExp(r'hold_piece_in:\s*"([^"]*)"').firstMatch(line);
    if (hpi != null && hpi.group(1)!.isNotEmpty) {
      holdPieceIn = _parseHandSpec(hpi.group(1)!);
    }
    out.add(_MetaRecord(
      key: key,
      parent: parent,
      aliases: aliases,
      turnEq: turnEq,
      turnMax: turnMax,
      dropOnly: dropOnly,
      holdPieceEmpty: holdPieceEmpty,
      holdPieceIn: holdPieceIn,
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// data/*.txt 書き出し
// ---------------------------------------------------------------------------

const String _legalHeader = '''
# Castle / strategy templates derived from bioshogi
# (https://github.com/akicho8/bioshogi).
#
# Names and (file, rank, piece-type) coordinate data are treated as factual
# information not subject to copyright. The ASCII art expression of the
# original bioshogi source is NOT carried over -- only the structured data.
# License of this file: MIT (matching the rest of this project).
#
# Source ASCII parsed by: tool/import_bioshogi.dart
''';

/// shape の cells に metadata (drop_only / hold_piece_empty) 由来のセルを
/// 足した配置リストを返す。
/// - drop_only: プライマリ `!<駒>` のマスに `pieceDropped` を追加。
/// - hold_piece_empty: `handEmpty` を追加。
List<PlacementCell> _withMeta(_ShapeRecord sh, _MetaRecord m) {
  final List<PlacementCell> cells = List<PlacementCell>.of(sh.cells);
  if (m.dropOnly && sh.primary != null) {
    cells.add(PlacementCell(
      kind: 'pieceDropped',
      file: sh.primary!.file,
      rank: sh.primary!.rank,
      pieceTypes: <String>[sh.primary!.pieceEnum],
    ));
  }
  if (m.holdPieceEmpty) {
    cells.add(PlacementCell(kind: 'handEmpty'));
  }
  for (final ({String pieceEnum, int count}) h in m.holdPieceIn) {
    cells.add(PlacementCell(
      kind: 'handPiece',
      pieceTypes: <String>[h.pieceEnum],
      minCount: h.count,
    ));
  }
  return cells;
}

/// 1 件分のテンプレを ASCII 形式 (`=== name: ...` ヘッダ + 9x9 グリッド)
/// に書き出す。空マスは `.`、Exact は SFEN 1 文字、AnyOf は `[...]`、
/// NotOf は `[!...]`、empty は `_`、anyPiece は `*`。
String _formatTemplate({
  required String name,
  required String? parent,
  required List<String> aliases,
  required String? side,
  required List<PlacementCell> cells,
  int? plyEq,
  int? plyMax,
}) {
  final StringBuffer buf = StringBuffer();
  buf.writeln('=== name: $name');
  if (parent != null) buf.writeln('parent: $parent');
  if (aliases.isNotEmpty) buf.writeln('aliases: ${aliases.join(', ')}');
  if (side != null) buf.writeln('side: $side');
  final String? plyLine = formatPlyHeader(plyEq: plyEq, plyMax: plyMax);
  if (plyLine != null) buf.writeln(plyLine);
  final String? igyokuLine = formatIgyokuHeader(cells);
  if (igyokuLine != null) buf.writeln(igyokuLine);
  for (final String line in formatUnmovedHeaders(cells)) {
    buf.writeln(line);
  }
  for (final String line in formatVisitedHeaders(cells)) {
    buf.writeln(line);
  }
  for (final String line in formatAnyHeaders(cells)) {
    buf.writeln(line);
  }
  final String? handLine = formatHandHeader(cells);
  if (handLine != null) buf.writeln(handLine);
  for (final String line in formatDroppedHeaders(cells)) {
    buf.writeln(line);
  }
  final String? handEmptyLine = formatHandEmptyHeader(cells);
  if (handEmptyLine != null) buf.writeln(handEmptyLine);
  buf.writeln();

  // build grid (履歴依存 / position-wide セルは grid に出ない)
  final List<List<String>> grid = List<List<String>>.generate(
    9,
    (_) => List<String>.filled(9, '.'),
  );
  for (final PlacementCell p in cells) {
    if (p.kind == 'pieceAnywhere' ||
        p.kind == 'handPiece' ||
        p.kind == 'pieceUnmoved' ||
        p.kind == 'pieceVisited' ||
        p.kind == 'pieceDropped' ||
        p.kind == 'handEmpty' ||
        p.kind == 'kingIgyoku' ||
        p.kind == 'anyPlacement') {
      continue;
    }
    final int rowIdx = p.rank - 1;
    final int colIdx = 9 - p.file;
    if (rowIdx < 0 || rowIdx > 8 || colIdx < 0 || colIdx > 8) continue;
    if (grid[rowIdx][colIdx] != '.') continue; // 重複したら最初優先
    grid[rowIdx][colIdx] = _cellToken(p);
  }
  for (final List<String> row in grid) {
    buf.writeln(row.join(' '));
  }
  buf.writeln();
  return buf.toString();
}

String _cellToken(PlacementCell p) {
  switch (p.kind) {
    case 'exact':
      return enumNameToSfenToken(p.pieceTypes.single);
    case 'opponent':
      return enumNameToSfenToken(p.pieceTypes.single).toLowerCase();
    case 'anyOf':
      return '[${p.pieceTypes.map(enumNameToSfenToken).join('')}]';
    case 'notOf':
      // 相手陣の不在 (`^駒`) は小文字で `[!s]` と表す。
      final String joined = p.pieceTypes
          .map(enumNameToSfenToken)
          .map((String t) => p.opponent ? t.toLowerCase() : t)
          .join('');
      return '[!$joined]';
    case 'empty':
      return '_';
    case 'anyPiece':
      // `*` = 自分の歩以上 (◇)、`?` = 陣営問わず存在 (●)。
      return p.anySide ? '?' : '*';
    default:
      return '.';
  }
}

// ---------------------------------------------------------------------------
// 戦法の side 推定 (簡易)
// ---------------------------------------------------------------------------

/// AttackInfo の戦法名から side を粗推定する。明示できない場合は null
/// (= either)。
String? _guessSide(String name) {
  const List<String> furibishaKeywords = <String>[
    '中飛車',
    '四間飛車',
    '三間飛車',
    '向かい飛車',
    '向飛車',
    '石田流',
    '振り飛車',
    '振飛車',
    'ゴキゲン',
    '藤井システム',
    'コーヤン',
    '鬼殺し',
    '阪田流',
    '阪田流向かい飛車',
    '相振り',
  ];
  const List<String> ibishaKeywords = <String>[
    '矢倉',
    '角換わり',
    '横歩取り',
    '相掛かり',
    '雁木',
    '棒銀',
    '腰掛け銀',
    '腰掛銀',
    '居飛車',
    '右四間飛車', // 居飛車の右四間
  ];
  for (final String kw in furibishaKeywords) {
    if (name.contains(kw)) return 'furibisha';
  }
  for (final String kw in ibishaKeywords) {
    if (name.contains(kw)) return 'ibisha';
  }
  return null;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final bool dryRun = args.contains('--dry-run');
  final bool debug = args.contains('--debug');

  const String shapePath = '/tmp/bioshogi/lib/bioshogi/analysis/shape_info.rb';
  const String defensePath =
      '/tmp/bioshogi/lib/bioshogi/analysis/defense_info.rb';
  const String attackPath =
      '/tmp/bioshogi/lib/bioshogi/analysis/attack_info.rb';

  final Map<String, _ShapeRecord> shapes =
      parseShapeInfo(File(shapePath).readAsStringSync());
  final List<_MetaRecord> defenses =
      parseMetaInfo(File(defensePath).readAsStringSync());
  final List<_MetaRecord> attacks =
      parseMetaInfo(File(attackPath).readAsStringSync());

  stdout.writeln('parsed shapes:    ${shapes.length}');
  stdout.writeln('parsed defenses:  ${defenses.length}');
  stdout.writeln('parsed attacks:   ${attacks.length}');

  if (debug) {
    for (final String name in <String>[
      '金矢倉',
      '美濃囲い',
      '居飛車穴熊',
      'ゴキゲン中飛車',
      '矢倉'
    ]) {
      final _ShapeRecord? sh = shapes[name];
      if (sh == null) {
        stdout.writeln('[debug] $name: NOT FOUND in shapes');
        continue;
      }
      stdout.writeln('[debug] $name (hasKing=${sh.hasKing}):');
      for (final PlacementCell c in sh.cells) {
        stdout.writeln(
          '   ${c.file}${c.rank} ${c.kind} ${c.pieceTypes.join("/")}',
        );
      }
    }
  }

  // 統計用
  int nonExactCount = 0;
  bool isNonExact(PlacementCell p) =>
      p.kind == 'anyOf' ||
      p.kind == 'notOf' ||
      p.kind == 'empty' ||
      p.kind == 'anyPiece';

  // 出力ビルド: castles
  final StringBuffer castleBuf = StringBuffer();
  castleBuf.writeln(_legalHeader);
  castleBuf.writeln('# Last regenerated: ${DateTime.now().toIso8601String()}');
  castleBuf.writeln('# Source: defense_info.rb (133 metadata rows) ');
  castleBuf.writeln('#  ∩  shape_info.rb (394 ASCII templates)');
  castleBuf.writeln();
  int castleCount = 0;
  int castleSkipped = 0;
  // 居玉 は shape_info に無いが、defense_info にあり、テストや UX 上重要
  // なので合成テンプレートで追加する。
  //
  // bioshogi 同等の判定:「玉が一度も動いていない」OR「玉の最初の移動が
  // outbreak (歩・角以外が初めて取られた手) 以降」。`KingIgyoku()` 要件
  // 1 つで表現し、評価は per-ply ではなく game-end に遅延する
  // (evaluate_at_game_end は parser が igyoku: true から自動的に立てる)。
  bool emittedIgyoku = false;
  void emitIgyoku() {
    if (emittedIgyoku) return;
    emittedIgyoku = true;
    castleBuf.write(_formatTemplate(
      name: '居玉',
      parent: null,
      aliases: const <String>[],
      side: null,
      cells: <PlacementCell>[
        PlacementCell(kind: 'kingIgyoku'),
      ],
    ));
    castleCount++;
  }

  for (final _MetaRecord m in defenses) {
    if (m.key == '居玉') {
      emitIgyoku();
      continue;
    }
    final _ShapeRecord? sh = shapes[m.key];
    if (sh == null) {
      castleSkipped++;
      continue;
    }
    if (sh.cells.isEmpty) {
      castleSkipped++;
      continue;
    }
    castleBuf.write(_formatTemplate(
      name: m.key,
      parent: m.parent,
      aliases: m.aliases,
      side: null,
      cells: _withMeta(sh, m),
      plyEq: m.turnEq,
      plyMax: m.turnMax,
    ));
    castleCount++;
    for (final PlacementCell p in sh.cells) {
      if (isNonExact(p)) nonExactCount++;
    }
  }
  // 万一 defense_info に 居玉 が無いケースでも emit する。
  emitIgyoku();

  // 出力ビルド: strategies
  final StringBuffer strategyBuf = StringBuffer();
  strategyBuf.writeln(_legalHeader);
  strategyBuf
      .writeln('# Last regenerated: ${DateTime.now().toIso8601String()}');
  strategyBuf.writeln('# Source: attack_info.rb (246 metadata rows)');
  strategyBuf.writeln('#  ∩  shape_info.rb (394 ASCII templates)');
  strategyBuf.writeln();
  int strategyCount = 0;
  int strategySkipped = 0;
  for (final _MetaRecord m in attacks) {
    final _ShapeRecord? sh = shapes[m.key];
    if (sh == null) {
      strategySkipped++;
      continue;
    }
    strategyBuf.write(_formatTemplate(
      name: m.key,
      parent: m.parent,
      aliases: m.aliases,
      side: _guessSide(m.key),
      cells: _withMeta(sh, m),
      plyEq: m.turnEq,
      plyMax: m.turnMax,
    ));
    strategyCount++;
    for (final PlacementCell p in sh.cells) {
      if (isNonExact(p)) nonExactCount++;
    }
  }

  stdout.writeln('---');
  stdout.writeln('castles to write:    $castleCount '
      '(skipped: $castleSkipped — no shape or no king)');
  stdout.writeln('strategies to write: $strategyCount '
      '(skipped: $strategySkipped — no shape match)');
  stdout.writeln('total cells with non-exact requirements: $nonExactCount');

  if (dryRun) {
    stdout.writeln('--dry-run: not writing files');
    return;
  }

  File('data/castles.txt').writeAsStringSync(castleBuf.toString());
  File('data/strategies.txt').writeAsStringSync(strategyBuf.toString());
  stdout.writeln('wrote data/castles.txt and data/strategies.txt');
}
