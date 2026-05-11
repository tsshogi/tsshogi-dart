import 'color.dart';
import 'generated/castles.g.dart' as gen;
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'record.dart';
import 'square.dart';

/// 囲い / 戦法テンプレートを構成する 1 つの要件。
///
/// サブタイプは大きく 2 系統に分かれる:
///
/// 1. **盤上 1 マスに対する要件 (per-cell)** — 先手視点で記述された
///    `file` / `rank` を持ち、後手検出時には 180° 回転 (file → 10-file,
///    rank → 10-rank) して照合される。`PiecePlacement`, `AnyOfPieces`,
///    `EmptySquare`, `NotOfPieces`, `AnyPiece` がこれに該当。
/// 2. **盤面/持駒全体に対する要件 (position-wide)** — 特定マスに紐づかず、
///    盤面または持駒の全状態を見て判定する。回転の概念がない。
///    `PieceAnywhere`, `HandPiece` がこれに該当。
///
/// すべてのサブタイプは [isSatisfiedBy] を実装し、[ImmutablePosition] 全体
/// と判定対象陣営 [Color] を受け取って bool を返す。マスの正規化 (黒/白の
/// 視点切り替え) は各サブタイプ内部で行う。
sealed class CastleRequirement {
  const CastleRequirement();

  /// この要件が局面 [position] において [side] 陣営の駒組として満たされて
  /// いるかを判定する。
  bool isSatisfiedBy(ImmutablePosition position, Color side);
}

/// 駒種を厳密に指定する盤上 1 マスの要件 (exact match)。
///
/// 例: `PiecePlacement(7, 8, PieceType.gold)` は 7八に先手視点で金。後手陣
/// 営の判定時には自動的に 3二に rotate される。
class PiecePlacement extends CastleRequirement {
  const PiecePlacement(this.file, this.rank, this.pieceType);

  /// 1..9 (盤の右が 1) — 先手視点
  final int file;

  /// 1..9 (盤の上が 1、先手玉の初期段が 9) — 先手視点
  final int rank;

  /// 駒の種類 (色は照合時に [side] を当てはめる)
  final PieceType pieceType;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    final int f = side == Color.black ? file : 10 - file;
    final int r = side == Color.black ? rank : 10 - rank;
    final Piece? piece = position.board.at(Square(f, r));
    if (piece == null) return false;
    if (piece.color != side) return false;
    return piece.type == pieceType;
  }

  @override
  bool operator ==(Object other) {
    return other is PiecePlacement &&
        other.file == file &&
        other.rank == rank &&
        other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash('PiecePlacement', file, rank, pieceType);
}

/// 駒種候補のいずれかにマッチする要件 (or 条件)。
///
/// 例: `AnyOfPieces(6, 7, [PieceType.gold, PieceType.silver])` は 6七に
/// 先手視点で金 or 銀。
class AnyOfPieces extends CastleRequirement {
  const AnyOfPieces(this.file, this.rank, this.options);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  /// 候補駒種 (このリストのいずれか 1 つにマッチすれば OK)
  final List<PieceType> options;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    final int f = side == Color.black ? file : 10 - file;
    final int r = side == Color.black ? rank : 10 - rank;
    final Piece? piece = position.board.at(Square(f, r));
    if (piece == null) return false;
    if (piece.color != side) return false;
    return options.contains(piece.type);
  }

  @override
  bool operator ==(Object other) {
    if (other is! AnyOfPieces) return false;
    if (other.file != file || other.rank != rank) return false;
    if (other.options.length != options.length) return false;
    for (int i = 0; i < options.length; i++) {
      if (other.options[i] != options[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash('AnyOfPieces', file, rank, Object.hashAll(options));
}

/// 指定マスが「完全に空 (どちらの陣営の駒もない)」であることを要求する要件。
///
/// 例: `EmptySquare(8, 8)` は 8八が空。後手陣営の判定時には 2二が空であるこ
/// とを要求する。
class EmptySquare extends CastleRequirement {
  const EmptySquare(this.file, this.rank);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    final int f = side == Color.black ? file : 10 - file;
    final int r = side == Color.black ? rank : 10 - rank;
    return position.board.at(Square(f, r)) == null;
  }

  @override
  bool operator ==(Object other) {
    return other is EmptySquare && other.file == file && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash('EmptySquare', file, rank);
}

/// 指定マスに「side の駒で [excluded] に含まれる種類のものは無い」ことを要
/// 求する要件。
///
/// 空マスや相手の駒は要件を満たす (ブロックしない)。
///
/// 例: `NotOfPieces(6, 7, [PieceType.gold, PieceType.silver])` は 6七が
/// 先手の金/銀以外 (空または先手の他の駒、または後手の任意の駒) であること
/// を要求する。
class NotOfPieces extends CastleRequirement {
  const NotOfPieces(this.file, this.rank, this.excluded);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  /// このリストに含まれる side の駒種があると要件を満たさない
  final List<PieceType> excluded;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    final int f = side == Color.black ? file : 10 - file;
    final int r = side == Color.black ? rank : 10 - rank;
    final Piece? piece = position.board.at(Square(f, r));
    if (piece == null) return true;
    if (piece.color != side) return true;
    return !excluded.contains(piece.type);
  }

  @override
  bool operator ==(Object other) {
    if (other is! NotOfPieces) return false;
    if (other.file != file || other.rank != rank) return false;
    if (other.excluded.length != excluded.length) return false;
    for (int i = 0; i < excluded.length; i++) {
      if (other.excluded[i] != excluded[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash('NotOfPieces', file, rank, Object.hashAll(excluded));
}

/// 指定マスに [side] の駒が (種類を問わず) あることを要求する要件。
///
/// 例: `AnyPiece(8, 8)` は 8八に先手の何らかの駒がいること。空マスや相手駒
/// では満たされない。
class AnyPiece extends CastleRequirement {
  const AnyPiece(this.file, this.rank);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    final int f = side == Color.black ? file : 10 - file;
    final int r = side == Color.black ? rank : 10 - rank;
    final Piece? piece = position.board.at(Square(f, r));
    if (piece == null) return false;
    return piece.color == side;
  }

  @override
  bool operator ==(Object other) {
    return other is AnyPiece && other.file == file && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash('AnyPiece', file, rank);
}

/// 盤上のいずれかのマスに [side] の指定駒が 1 枚以上あることを要求する要件。
/// マス指定はない (position-wide)。
///
/// 例: `PieceAnywhere(PieceType.bishop)` は side の角が盤上のどこかに存在
/// する。矢倉と角換わりの区別など、駒種の有無で峻別したい戦法定義に使う。
class PieceAnywhere extends CastleRequirement {
  const PieceAnywhere(this.pieceType);

  /// 探す駒種
  final PieceType pieceType;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    for (final ({Square square, Piece piece}) entry
        in position.board.listNonEmptySquares()) {
      if (entry.piece.color == side && entry.piece.type == pieceType) {
        return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    return other is PieceAnywhere && other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash('PieceAnywhere', pieceType);
}

/// [side] の持駒に指定駒種が [minCount] 枚以上あることを要求する要件。
///
/// 例: `HandPiece(PieceType.bishop)` は side の手駒に角が 1 枚以上。
/// `HandPiece(PieceType.pawn, 3)` は side の手駒に歩が 3 枚以上。
class HandPiece extends CastleRequirement {
  const HandPiece(this.pieceType, [this.minCount = 1]);

  /// 駒種
  final PieceType pieceType;

  /// 必要枚数 (デフォルト 1)
  final int minCount;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side) {
    return position.hand(side).count(pieceType) >= minCount;
  }

  @override
  bool operator ==(Object other) {
    return other is HandPiece &&
        other.pieceType == pieceType &&
        other.minCount == minCount;
  }

  @override
  int get hashCode => Object.hash('HandPiece', pieceType, minCount);
}

/// 囲い (king defensive formation) のテンプレート。
///
/// 配置は常に先手 (black) 視点で記述する。後手の検出時には per-cell の
/// 要件が自動的に 180° 回転 (file → 10-file, rank → 10-rank) して照合さ
/// れる。`PieceAnywhere` / `HandPiece` は position-wide なので回転不要。
class CastleTemplate {
  const CastleTemplate({
    required this.name,
    required this.placements,
    this.aliases = const <String>[],
    this.parent,
    this.plyEq,
    this.plyMax,
  });

  /// 囲い名 (例: '金矢倉')
  final String name;

  /// 別名
  final List<String> aliases;

  /// 親囲い (より広い分類、例: '矢倉囲い')。
  /// 親自身もテンプレートとして [knownCastles] に含まれる場合がある。
  final String? parent;

  /// 必須要件の集合 (先手視点)。per-cell と position-wide の要件を混在さ
  /// せられる。
  final List<CastleRequirement> placements;

  /// この囲いが成立する手数 (ply) の制約 (厳密一致)。
  ///
  /// 非 null の場合、棋譜走査ベース検出 (`record.castles`) では現在 ply が
  /// この値と一致するときのみマッチする。`plyMax` と併用可。
  /// 位置ベース検出 (`detectCastles(position)`) では ply 情報が無いため、
  /// 非 null のテンプレートはスキップされる。
  final int? plyEq;

  /// この囲いが成立する手数 (ply) の上限。
  ///
  /// 非 null の場合、棋譜走査ベース検出では現在 ply が <= plyMax のときのみ
  /// マッチする。`plyEq` と併用可。位置ベース検出では非 null のテンプレートは
  /// スキップされる。
  final int? plyMax;

  /// このテンプレートが ply 制約 (`plyEq` または `plyMax`) を持つかを返す。
  bool get hasPlyConstraint => plyEq != null || plyMax != null;

  /// 与えられた手数 [ply] でこのテンプレートが満たすべき ply 制約を満たすか。
  bool satisfiesPlyConstraint(int ply) {
    if (plyEq != null && plyEq != ply) return false;
    if (plyMax != null && ply > plyMax!) return false;
    return true;
  }
}

/// 局面における囲いの検出結果。
class DetectedCastle {
  const DetectedCastle({required this.template, required this.side});

  /// マッチしたテンプレート
  final CastleTemplate template;

  /// この囲いを構築している陣営
  final Color side;

  @override
  bool operator ==(Object other) {
    return other is DetectedCastle &&
        other.template.name == template.name &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(template.name, side);
}

// ---------------------------------------------------------------------------
// 既知の囲いテンプレート
// ---------------------------------------------------------------------------
//
// テンプレ本体は ASCII source-of-truth (data/castles.txt) から自動生成され、
// lib/src/generated/castles.g.dart に const リストとして書き出される。本ファ
// イルではそれを単に再エクスポートする。データを編集したい場合は
// data/castles.txt を直接書き換え、以下を実行する:
//
//   dart run tool/generate_castles.dart
//
// 囲いの考証ノート (bioshogi 不参照、玉位置等の修正履歴) は
// docs/plans/ascii-codegen.md および data/castles.txt 冒頭コメントを参照。

/// 既知の囲いテンプレート (135 件)。
///
/// 親カテゴリ (矢倉囲い・美濃囲い・穴熊囲い) も含む。
/// 子テンプレート (金矢倉等) がマッチすれば、親テンプレートも独立に判定される
/// (placements の包含関係が満たされていれば自然と両方検出される)。
const List<CastleTemplate> knownCastles = gen.castles;

/// 局面 [position] から囲いを検出する。
///
/// [side] が指定された場合はその陣営のみ、null の場合は両陣営を判定する。
/// 各テンプレートは先手視点で記述されており、後手判定では per-cell 要件が
/// 180° 回転して照合される。テンプレートの全 placements を満たせば検出。
/// テンプレートに含まれていない駒が他のマスにあっても判定には影響しない。
/// 複数の囲い (例: 金矢倉と矢倉囲い) が同時にマッチすることがある。
///
/// 注: ply 制約 (`plyEq` / `plyMax`) を持つテンプレートは position のみでは
/// 検証できないため、本関数では **常にスキップ** される。
/// ply 制約を考慮した検出が必要な場合は `record.castles` を使う。
List<DetectedCastle> detectCastles(
  ImmutablePosition position, {
  Color? side,
}) {
  final List<DetectedCastle> results = <DetectedCastle>[];
  for (final CastleTemplate template in knownCastles) {
    // ply 制約付きテンプレートは Record 経由でのみ判定可能。
    if (template.hasPlyConstraint) continue;
    if (side == null || side == Color.black) {
      if (_matchesTemplate(position, template, Color.black)) {
        results.add(DetectedCastle(template: template, side: Color.black));
      }
    }
    if (side == null || side == Color.white) {
      if (_matchesTemplate(position, template, Color.white)) {
        results.add(DetectedCastle(template: template, side: Color.white));
      }
    }
  }
  return results;
}

bool _matchesTemplate(
  ImmutablePosition position,
  CastleTemplate template,
  Color side,
) {
  for (final CastleRequirement req in template.placements) {
    if (!req.isSatisfiedBy(position, side)) return false;
  }
  return true;
}

/// 局面からの囲い検出ユーティリティ。
///
/// プロパティ形式で `position.castles` のように呼べる。手番は無視し
/// 両陣営の検出結果を返す。特定陣営のみが欲しい場合は filter する:
///
/// ```dart
/// final blackCastles =
///     position.castles.where((c) => c.side == Color.black).toList();
/// ```
///
/// 注: これは **スナップショット** 検出のため、囲い完成後ずっと検出され続け
/// る。「初めて成立した手」を知りたい場合は [ImmutableRecordCastles.castles]
/// を使う。
extension ImmutablePositionCastles on ImmutablePosition {
  /// この局面で検出される囲いを返す (両陣営)。
  List<DetectedCastle> get castles => detectCastles(this);
}

/// 棋譜の中で囲いが「初めて成立した手」を表す。
///
/// 同じ (テンプレ名, 陣営) は最も早い [ply] でのみ報告される。
class DetectedCastleAt {
  const DetectedCastleAt({
    required this.template,
    required this.side,
    required this.ply,
  });

  /// マッチしたテンプレート
  final CastleTemplate template;

  /// 囲いを構築している陣営
  final Color side;

  /// 初めてマッチした手数 (0 は初期局面)。
  final int ply;

  @override
  bool operator ==(Object other) =>
      other is DetectedCastleAt &&
      other.template.name == template.name &&
      other.side == side &&
      other.ply == ply;

  @override
  int get hashCode => Object.hash(template.name, side, ply);
}

/// 棋譜走査ベースの囲い検出。各囲いを「初めて成立した手」だけ報告する。
///
/// スナップショット形 ([ImmutablePositionCastles.castles]) と違い、一度
/// 検出された囲いは以降の手では再報告されない。四間飛車が成立した後
/// 関係ない手を指し続けても、ずっと検出され続けることはない。
///
/// ```dart
/// final r = Record.newByUSI('position startpos moves 7g7f ...')!;
/// for (final c in r.castles) {
///   print('${c.ply}手目: ${c.side.value} ${c.template.name}');
/// }
/// ```
extension ImmutableRecordCastles on ImmutableRecord {
  /// アクティブブランチを走査し、初めて成立した囲いを ply 順に返す。
  ///
  /// ply 制約 (`plyEq` / `plyMax`) を持つテンプレートは、各 ply で制約を満
  /// たすときのみ評価される。
  List<DetectedCastleAt> get castles {
    final List<DetectedCastleAt> results = <DetectedCastleAt>[];
    final Set<String> seen = <String>{};
    void emitAt(int ply, ImmutablePosition pos) {
      // ply 制約なしテンプレートは detectCastles(pos) で一括判定。
      for (final DetectedCastle d in detectCastles(pos)) {
        final String key = '${d.template.name}|${d.side.value}';
        if (seen.add(key)) {
          results.add(DetectedCastleAt(
            template: d.template,
            side: d.side,
            ply: ply,
          ));
        }
      }
      // ply 制約付きテンプレートは個別に評価。
      for (final CastleTemplate template in knownCastles) {
        if (!template.hasPlyConstraint) continue;
        if (!template.satisfiesPlyConstraint(ply)) continue;
        for (final Color side in const <Color>[Color.black, Color.white]) {
          if (!_matchesTemplate(pos, template, side)) continue;
          final String key = '${template.name}|${side.value}';
          if (seen.add(key)) {
            results.add(DetectedCastleAt(
              template: template,
              side: side,
              ply: ply,
            ));
          }
        }
      }
    }

    final Position pos = initialPosition.clone();
    emitAt(0, pos);
    ImmutableNode? node = first.next;
    while (node != null) {
      final Object raw = node.move;
      if (raw is Move) {
        pos.doMove(raw, ignoreValidation: true);
        emitAt(node.ply, pos);
      }
      node = node.next;
    }
    return results;
  }
}
