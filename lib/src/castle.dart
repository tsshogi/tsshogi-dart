import 'color.dart';
import 'generated/castles.g.dart' as gen;
import 'hand.dart';
import 'move.dart';
import 'move_history.dart';
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
  ///
  /// [history] が与えられた場合、棋譜走査ベースの履歴依存要件
  /// (`PieceUnmoved`, `PieceVisited`) が利用する。位置ベース検出では `null`
  /// が渡される — 履歴依存要件は履歴情報無しでは満たせないため常に `false`
  /// を返す。
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]);

  /// この要件が `MoveHistory` (棋譜走査) なしには判定できないかを返す。
  /// `true` の要件を含むテンプレートは position-only 検出 (履歴 null) では
  /// 必ずスキップされる。デフォルトは `false`; 履歴に依存するサブクラス
  /// (`PieceUnmoved` / `PieceVisited` / `PieceDropped` / `KingIgyoku`) で
  /// `true` をオーバーライドする。
  bool get isHistoryDependent => false;
}

/// 先手視点で記述された (file, rank) を、判定対象 [side] の盤上座標へ変換する。
/// 後手なら 180° 回転 (file → 10-file, rank → 10-rank) する。per-cell 要件が
/// 共通して使う座標正規化。
Square _squareForSide(int file, int rank, Color side) =>
    side == Color.black ? Square(file, rank) : Square(10 - file, 10 - rank);

/// テンプレ視点の絶対色 [templateColor] を、判定対象 [side] における期待色へ
/// 変換する。`Color.black` = 自陣 → side そのまま、`Color.white` = 相手陣 →
/// reverseColor(side)。
Color _expectedColor(Color templateColor, Color side) =>
    templateColor == Color.black ? side : reverseColor(side);

/// 駒種を厳密に指定する盤上 1 マスの要件 (exact match)。
///
/// 例: `PiecePlacement(7, 8, PieceType.gold)` は 7八に先手視点で金。後手陣
/// 営の判定時には自動的に 3二に rotate される。
///
/// [color] は **テンプレ視点での絶対色**:
/// - `Color.black` (デフォルト) = テンプレ自陣の駒。
///   side=black 判定なら黒駒、side=white 判定なら mirror して白駒を期待。
/// - `Color.white` = テンプレ相手の駒 (bioshogi の `v駒` 相当)。
///   side=black 判定なら白駒、side=white 判定なら mirror して黒駒を期待。
class PiecePlacement extends CastleRequirement {
  const PiecePlacement(
    this.file,
    this.rank,
    this.pieceType, {
    this.color = Color.black,
  });

  /// 1..9 (盤の右が 1) — 先手視点
  final int file;

  /// 1..9 (盤の上が 1、先手玉の初期段が 9) — 先手視点
  final int rank;

  /// 駒の種類 (絶対色は [color]、相対色は照合時の [side] と組み合わせて決まる)
  final PieceType pieceType;

  /// テンプレ視点の絶対色。Color.black = 自陣、Color.white = 相手陣。
  final Color color;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    final Piece? piece = position.board.at(_squareForSide(file, rank, side));
    if (piece == null) return false;
    if (piece.color != _expectedColor(color, side)) return false;
    return piece.type == pieceType;
  }

  @override
  bool operator ==(Object other) {
    return other is PiecePlacement &&
        other.file == file &&
        other.rank == rank &&
        other.pieceType == pieceType &&
        other.color == color;
  }

  @override
  int get hashCode =>
      Object.hash('PiecePlacement', file, rank, pieceType, color);
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
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    final Piece? piece = position.board.at(_squareForSide(file, rank, side));
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
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    return position.board.at(_squareForSide(file, rank, side)) == null;
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
  const NotOfPieces(this.file, this.rank, this.excluded,
      {this.color = Color.black});

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  /// このリストに含まれる駒種があると要件を満たさない
  final List<PieceType> excluded;

  /// テンプレ視点の絶対色 ([PiecePlacement] と同規約)。
  /// - `Color.black` (デフォルト) = 自陣 (bioshogi の `~駒`)。
  /// - `Color.white` = 相手陣 (bioshogi の `^駒` = 「△側でここに含まれない」)。
  final Color color;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    final Piece? piece = position.board.at(_squareForSide(file, rank, side));
    if (piece == null) return true;
    if (piece.color != _expectedColor(color, side)) return true;
    return !excluded.contains(piece.type);
  }

  @override
  bool operator ==(Object other) {
    if (other is! NotOfPieces) return false;
    if (other.file != file || other.rank != rank || other.color != color) {
      return false;
    }
    if (other.excluded.length != excluded.length) return false;
    for (int i = 0; i < excluded.length; i++) {
      if (other.excluded[i] != excluded[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash('NotOfPieces', file, rank, color, Object.hashAll(excluded));
}

/// 指定マスに駒があることを要求する要件。
///
/// 例: `AnyPiece(8, 8)` は 8八に先手の何らかの駒がいること (bioshogi の
/// `◇` = 「自分の歩以上がある」相当)。空マスや相手駒では満たされない。
///
/// [anySide] が `true` の場合は陣営を問わず「何かしらの駒があれば」満たされる
/// (bioshogi の `●` = 「この座標に何かある」相当)。
class AnyPiece extends CastleRequirement {
  const AnyPiece(this.file, this.rank, {this.anySide = false});

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  /// true なら陣営を問わず駒の存在のみを判定する (`●`)。
  final bool anySide;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    final Piece? piece = position.board.at(_squareForSide(file, rank, side));
    if (piece == null) return false;
    return anySide || piece.color == side;
  }

  @override
  bool operator ==(Object other) {
    return other is AnyPiece &&
        other.file == file &&
        other.rank == rank &&
        other.anySide == anySide;
  }

  @override
  int get hashCode => Object.hash('AnyPiece', file, rank, anySide);
}

/// 複数マスのうち **いずれか 1 つ** に指定駒があれば満たされる OR 要件。
///
/// bioshogi の `*駒` (「▲側でどれかのマスにこの駒がある」) と `?駒` (「△側で
/// どれか」) に対応する。例えば雁木の自陣角は角が 7七 か 8八 のどちらかに
/// あればよく、`AnyPlacement(PieceType.bishop, [(file: 7, rank: 7),
/// (file: 8, rank: 8)])` と表す。
///
/// [color] は [PiecePlacement] と同規約: `Color.black` = 自陣 (`*`)、
/// `Color.white` = 相手陣 (`?`)。各マスは後手判定時に 180° 回転される。
class AnyPlacement extends CastleRequirement {
  const AnyPlacement(this.pieceType, this.squares, {this.color = Color.black});

  /// 探す駒種 (bioshogi では 1 つの `*`/`?` グループは単一駒種)。
  final PieceType pieceType;

  /// 候補マス (先手視点)。このいずれかに [pieceType] があれば成立。
  final List<({int file, int rank})> squares;

  /// テンプレ視点の絶対色。Color.black = 自陣、Color.white = 相手陣。
  final Color color;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    final Color expected = _expectedColor(color, side);
    for (final ({int file, int rank}) sq in squares) {
      final Piece? piece =
          position.board.at(_squareForSide(sq.file, sq.rank, side));
      if (piece != null && piece.color == expected && piece.type == pieceType) {
        return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (other is! AnyPlacement) return false;
    if (other.pieceType != pieceType || other.color != color) return false;
    if (other.squares.length != squares.length) return false;
    for (int i = 0; i < squares.length; i++) {
      if (other.squares[i] != squares[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash('AnyPlacement', pieceType, color, Object.hashAll(squares));
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
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
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

/// 持駒に指定駒種が [minCount] 枚以上あることを要求する要件。
///
/// 例: `HandPiece(PieceType.bishop)` は side の手駒に角が 1 枚以上。
/// `HandPiece(PieceType.pawn, 3)` は side の手駒に歩が 3 枚以上。
///
/// [color] は [PiecePlacement] と同じくテンプレ視点の絶対色:
/// - `Color.black` (デフォルト) = 自陣の持駒。side=black なら黒の手駒、
///   side=white なら白の手駒を見る。
/// - `Color.white` = 相手陣の持駒 (bioshogi の `v駒` 相当)。角交換振り飛車の
///   ように「相手が角を持駒にしている」状況を表現したいときに使う。
class HandPiece extends CastleRequirement {
  const HandPiece(this.pieceType,
      [this.minCount = 1, this.color = Color.black]);

  /// 駒種
  final PieceType pieceType;

  /// 必要枚数 (デフォルト 1)
  final int minCount;

  /// テンプレ視点の絶対色。Color.black = 自陣、Color.white = 相手陣。
  final Color color;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    final Color handSide = _expectedColor(color, side);
    return position.hand(handSide).count(pieceType) >= minCount;
  }

  @override
  bool operator ==(Object other) {
    return other is HandPiece &&
        other.pieceType == pieceType &&
        other.minCount == minCount &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash('HandPiece', pieceType, minCount, color);
}

/// [side] が指定マスから一度も `move.from` として動いていないことを要求する
/// 履歴依存要件。
///
/// 例: `PieceUnmoved(5, 9)` は 5九 (先手玉の初期マス) から一度も動いていな
/// いこと。後手判定時には 5一 (= file 5, rank 1) に rotate される。
///
/// 履歴情報 (`MoveHistory`) が無い (=`null`) 場合は常に `false` を返す。
/// したがって `detectCastles(position)` / `detectStrategies(position)` のよ
/// うな履歴非対応の経路では、本要件を含むテンプレートは決してマッチしない。
class PieceUnmoved extends CastleRequirement {
  const PieceUnmoved(this.file, this.rank);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    if (history == null) return false;
    final Square sq = _squareForSide(file, rank, side);
    return history.isUnmoved(side, sq.file, sq.rank);
  }

  @override
  bool get isHistoryDependent => true;

  @override
  bool operator ==(Object other) {
    return other is PieceUnmoved && other.file == file && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash('PieceUnmoved', file, rank);
}

/// 居玉 (bioshogi 同等の判定)。
///
/// 「玉が一度も動いていない」OR「玉の最初の移動が outbreak (歩・角以外の
/// 駒が初めて取られた手) 以降」の場合に満たされる。"戦いが始まるまで玉を
/// 囲わなかった" 状況を含めて評価する。
///
/// 履歴情報 (`MoveHistory`) が無い (=`null`) 場合は常に `false` を返す。
///
/// 判定ロジック (per-ply 呼び出し前提):
/// - `kingFirstMovedTurn(side)` が `null` → `true` (まだ動いていない)
/// - `outbreakTurn` が `null` AND king は既に動いている → `false`
///   (戦いが始まる前に玉が動いた = 居玉ではない)
/// - `kingFirstMovedTurn(side) >= outbreakTurn` → `true`
/// - それ以外 → `false`
///
/// 注: 本要件を含むテンプレートは `evaluateAtGameEnd: true` でマークすべき
/// で、`record.castles` / `record.strategies` の game-end 評価フェーズで
/// 最終状態に基づいて判定される。
class KingIgyoku extends CastleRequirement {
  const KingIgyoku();

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    if (history == null) return false;
    final int? kingMoved = history.kingFirstMovedTurn(side);
    if (kingMoved == null) return true;
    final int? outbreak = history.outbreakTurn;
    if (outbreak == null) return false;
    return kingMoved >= outbreak;
  }

  @override
  bool get isHistoryDependent => true;

  @override
  bool operator ==(Object other) => other is KingIgyoku;

  @override
  int get hashCode => Object.hash('KingIgyoku', 0);
}

/// [side] の [pieceType] が指定マスを過去に通過したことを要求する履歴依存
/// 要件。
///
/// 例: `PieceVisited(6, 8, PieceType.rook)` は 6八に先手の飛車が「過去に」
/// 居たことを要求する (現在そこに飛車がある必要はない)。後手判定時には
/// 4二に rotate される。
///
/// 履歴情報 (`MoveHistory`) が無い (=`null`) 場合は常に `false` を返す。
class PieceVisited extends CastleRequirement {
  const PieceVisited(this.file, this.rank, this.pieceType);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  /// 探す駒種
  final PieceType pieceType;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    if (history == null) return false;
    final Square sq = _squareForSide(file, rank, side);
    return history.hasVisited(side, pieceType, sq.file, sq.rank);
  }

  @override
  bool get isHistoryDependent => true;

  @override
  bool operator ==(Object other) {
    return other is PieceVisited &&
        other.file == file &&
        other.rank == rank &&
        other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash('PieceVisited', file, rank, pieceType);
}

/// 指定マスの駒が「持駒から打たれてそのまま動いていない」ことを要求する
/// 履歴依存要件 (bioshogi の `drop_only` 相当)。
///
/// 例: はく式四間飛車は角交換後に持駒の角を 7七 へ打ち直した自陣角なので、
/// `PieceDropped(7, 7, PieceType.bishop)` で「7七の角は打ち駒」と判定する。
/// 角を盤上から動かして 7七 に上がったノーマル四間飛車とはこれで区別できる。
/// 履歴が無い (position-only) 検出では常に `false`。
class PieceDropped extends CastleRequirement {
  const PieceDropped(this.file, this.rank, this.pieceType);

  /// 1..9 — 先手視点
  final int file;

  /// 1..9 — 先手視点
  final int rank;

  /// 打ち駒として期待する駒種
  final PieceType pieceType;

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    if (history == null) return false;
    final Square sq = _squareForSide(file, rank, side);
    final Piece? piece = position.board.at(sq);
    if (piece == null || piece.color != side || piece.type != pieceType) {
      return false;
    }
    return history.isDroppedInPlace(side, sq.file, sq.rank);
  }

  @override
  bool get isHistoryDependent => true;

  @override
  bool operator ==(Object other) {
    return other is PieceDropped &&
        other.file == file &&
        other.rank == rank &&
        other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash('PieceDropped', file, rank, pieceType);
}

/// [side] の持駒が空であることを要求する要件 (bioshogi の `hold_piece_empty`)。
class HandEmpty extends CastleRequirement {
  const HandEmpty();

  @override
  bool isSatisfiedBy(ImmutablePosition position, Color side,
      [MoveHistory? history]) {
    bool empty = true;
    position.hand(side).forEach((PieceType _, int n) {
      if (n > 0) empty = false;
    });
    return empty;
  }

  @override
  bool operator ==(Object other) => other is HandEmpty;

  @override
  int get hashCode => 'HandEmpty'.hashCode;
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
    this.evaluateAtGameEnd = false,
    this.outbreakSkip = false,
    this.killCountLteq,
    this.killOnly = false,
    this.orderKey,
    this.handEq,
    this.opHandEq,
    this.handNotIn = const <PieceType>[],
    this.noPawnInHand = false,
    this.onlyPawnsInHand = false,
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

  /// このテンプレートが履歴依存要件 (`PieceUnmoved` / `PieceVisited` /
  /// `PieceDropped` / `KingIgyoku`) を含むかを返す。`true` の場合、位置ベース
  /// 検出 (`detectCastles(position)`) では常にスキップされる。
  bool get hasHistoryRequirement =>
      placements.any((CastleRequirement r) => r.isHistoryDependent);

  /// このテンプレートを「棋譜の最終手まで評価を遅延し、最終状態で 1 度だけ
  /// 判定する」べきかを示すフラグ。
  ///
  /// `KingIgyoku` のように「最終状態 (= ゲーム終了時の MoveHistory) でしか
  /// 厳密に判定できない」要件を持つテンプレートに付与する。`record.castles`
  /// / `record.strategies` の per-ply 評価では本フラグが立っているテンプレ
  /// ートはスキップし、走査終了後に 1 度だけ評価して emit する。
  final bool evaluateAtGameEnd;

  /// bioshogi `outbreak_skip`: 開戦 (歩・角以外が取られた) 後は判定しない。
  final bool outbreakSkip;

  /// bioshogi `kill_count_lteq`: 総取り駒数がこの値以下のときのみ成立。
  final int? killCountLteq;

  /// bioshogi `kill_only`: 直前の手で駒を取っているときのみ成立。
  final bool killOnly;

  /// bioshogi `order_key`: 手番限定 ('first'=先手 / 'second'=後手)。
  final String? orderKey;

  /// bioshogi `hold_piece_eq`: 自分の持駒がこの multiset と完全一致のとき成立。
  final Map<PieceType, int>? handEq;

  /// bioshogi `op_hold_piece_eq`: 相手の持駒が完全一致のとき成立。
  final Map<PieceType, int>? opHandEq;

  /// bioshogi `hold_piece_not_in`: 自分の持駒にこれらを含まないとき成立。
  final List<PieceType> handNotIn;

  /// bioshogi `has_pawn_then_skip`: 自分の持駒に歩があれば不成立。
  final bool noPawnInHand;

  /// bioshogi `has_other_pawn_then_skip`: 自分の持駒に歩以外があれば不成立。
  final bool onlyPawnsInHand;

  /// このテンプレートが棋譜走査ゲート (outbreak/kill/order) を持つかを返す。
  bool get hasRecordGate =>
      outbreakSkip || killCountLteq != null || killOnly || orderKey != null;

  /// 棋譜走査ゲート (game-context 制約) を満たすか (`record.castles` 専用)。
  bool passesRecordGate(Color side, MoveHistory history) {
    if (outbreakSkip && history.outbreakTurn != null) return false;
    if (killCountLteq != null && history.captureCount > killCountLteq!) {
      return false;
    }
    if (killOnly && !history.lastMoveCaptured) return false;
    if (orderKey != null) {
      final Color want = orderKey == 'first' ? Color.black : Color.white;
      if (side != want) return false;
    }
    return true;
  }

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
  // position-only 評価向け MoveHistory:
  //   - 標準初期局面の駒位置を visited に登録
  //   - 現局面の駒位置も追加で登録
  // これで「飛車が 2八 (初期) と 6八 (現在) を visited した」のような
  // 標準ゲーム由来の要件が静的局面でも満たされる。
  final MoveHistory history = MoveHistory()
    ..initFromPosition(Position())
    ..initFromPosition(position);
  for (final CastleTemplate template in knownCastles) {
    // ply 制約付きテンプレートは Record 経由でのみ判定可能。
    if (template.hasPlyConstraint) continue;
    // game-end 評価テンプレ (居玉 等) は record.castles からのみ。
    if (template.evaluateAtGameEnd) continue;
    if (side == null || side == Color.black) {
      if (_matchesTemplate(position, template, Color.black, history: history)) {
        results.add(DetectedCastle(template: template, side: Color.black));
      }
    }
    if (side == null || side == Color.white) {
      if (_matchesTemplate(position, template, Color.white, history: history)) {
        results.add(DetectedCastle(template: template, side: Color.white));
      }
    }
  }
  return results;
}

bool _matchesTemplate(
  ImmutablePosition position,
  CastleTemplate template,
  Color side, {
  MoveHistory? history,
}) {
  for (final CastleRequirement req in template.placements) {
    if (!req.isSatisfiedBy(position, side, history)) return false;
  }
  return passesHandConstraints(
    position,
    side,
    handEq: template.handEq,
    opHandEq: template.opHandEq,
    handNotIn: template.handNotIn,
    noPawnInHand: template.noPawnInHand,
    onlyPawnsInHand: template.onlyPawnsInHand,
  );
}

/// bioshogi の持駒系メタデータ (hold_piece_eq / op_hold_piece_eq /
/// hold_piece_not_in / has_pawn_then_skip / has_other_pawn_then_skip) を
/// 局面の持駒に対して検証する共通関数。[StrategyTemplate] / [CastleTemplate]
/// の双方から呼ばれる。持駒は局面に含まれるため position / record 両モードで
/// 評価できる。
bool passesHandConstraints(
  ImmutablePosition position,
  Color side, {
  Map<PieceType, int>? handEq,
  Map<PieceType, int>? opHandEq,
  List<PieceType> handNotIn = const <PieceType>[],
  bool noPawnInHand = false,
  bool onlyPawnsInHand = false,
}) {
  final ImmutableHand own = position.hand(side);
  if (handEq != null && !_handEquals(own, handEq)) return false;
  if (opHandEq != null &&
      !_handEquals(position.hand(reverseColor(side)), opHandEq)) {
    return false;
  }
  for (final PieceType p in handNotIn) {
    if (own.count(p) > 0) return false;
  }
  if (noPawnInHand && own.count(PieceType.pawn) > 0) return false;
  if (onlyPawnsInHand) {
    bool onlyPawns = true;
    own.forEach((PieceType t, int n) {
      if (t != PieceType.pawn && n > 0) onlyPawns = false;
    });
    if (!onlyPawns) return false;
  }
  return true;
}

bool _handEquals(ImmutableHand hand, Map<PieceType, int> spec) {
  bool equal = true;
  spec.forEach((PieceType t, int n) {
    if (hand.count(t) != n) equal = false;
  });
  hand.forEach((PieceType t, int n) {
    if (n != (spec[t] ?? 0)) equal = false;
  });
  return equal;
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
  /// - ply 0 (初期局面) は走査対象外。最初の指し手以降のみ評価する。
  /// - ply 制約 (`plyEq` / `plyMax`) を持つテンプレートは、各 ply で制約
  ///   を満たすときのみ評価される。
  /// - 同じ (テンプレ名, 陣営) は最初の 1 回のみ報告 (snapshot 重複防止)。
  /// - `evaluateAtGameEnd: true` を持つテンプレ (例: 居玉) は per-ply
  ///   評価をスキップし、走査終了後の最終 ply で 1 度だけ評価する。
  List<DetectedCastleAt> get castles {
    final List<DetectedCastleAt> results = <DetectedCastleAt>[];
    final Set<String> seen = <String>{};
    final MoveHistory history = MoveHistory()
      ..initFromPosition(initialPosition);
    void emitAt(int ply, ImmutablePosition pos) {
      // 1. ply 制約も履歴依存要件も無いテンプレートは detectCastles(pos)
      //    で一括判定 (高速路)。
      for (final DetectedCastle d in detectCastles(pos)) {
        if (!d.template.passesRecordGate(d.side, history)) continue;
        final String key = '${d.template.name}|${d.side.value}';
        if (seen.add(key)) {
          results.add(DetectedCastleAt(
            template: d.template,
            side: d.side,
            ply: ply,
          ));
        }
      }
      // 2. ply 制約付き / 履歴依存テンプレートは個別に評価。
      //    ただし evaluateAtGameEnd のものは per-ply で評価しない。
      for (final CastleTemplate template in knownCastles) {
        if (template.evaluateAtGameEnd) continue;
        if (!template.hasPlyConstraint && !template.hasHistoryRequirement) {
          continue;
        }
        if (template.hasPlyConstraint &&
            !template.satisfiesPlyConstraint(ply)) {
          continue;
        }
        for (final Color side in const <Color>[Color.black, Color.white]) {
          if (!_matchesTemplate(pos, template, side, history: history)) {
            continue;
          }
          if (!template.passesRecordGate(side, history)) continue;
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
    // ply 0 はスキップ。最初の指し手以降のみ評価する。
    ImmutableNode? node = first.next;
    int lastPly = 0;
    while (node != null) {
      final Object raw = node.move;
      if (raw is Move) {
        // 履歴は doMove の前に記録する: PieceUnmoved は「from」が
        // sourceTouched に居ない (まだ動いていない) ことを判定するため、
        // 動かす直前のマス情報を必要とする。
        history.recordMove(raw, node.ply);
        pos.doMove(raw, ignoreValidation: true);
        emitAt(node.ply, pos);
        lastPly = node.ply;
      }
      node = node.next;
    }

    // 既に検出されている囲い (per-ply emit 分) を陣営別に集計する。game-end
    // フェーズの「居玉」系テンプレは、その陣営に他の囲いが何も無いときだ
    // け emit する (他の囲いが組めていれば 居玉 は表示価値が薄いため)。
    final Set<Color> sidesWithOtherCastle = <Color>{
      for (final DetectedCastleAt d in results) d.side,
    };

    // game-end フェーズ: 最終 MoveHistory に基づいて評価する。
    //
    // ply 0 (= 初期局面のみ、指し手が 1 つもない記録) は走査対象外なので
    // game-end フェーズ自体も実行しない (`lastPly == 0` で skip)。
    if (lastPly > 0) {
      for (final CastleTemplate template in knownCastles) {
        if (!template.evaluateAtGameEnd) continue;
        for (final Color side in const <Color>[Color.black, Color.white]) {
          // 同陣営に既に「ちゃんとした囲い」(per-ply 検出のもの) があれば、
          // game-end の 居玉 は emit しない。
          if (sidesWithOtherCastle.contains(side)) continue;
          if (!_matchesTemplate(pos, template, side, history: history)) {
            continue;
          }
          final String key = '${template.name}|${side.value}';
          if (!seen.add(key)) continue;
          // 居玉 = 「戦いが起きた時点で玉が動いてない」状態。emit ply は
          // 戦い開始 (outbreak_turn) を使う。戦いが起きなかった棋譜なら
          // 最終 ply にフォールバック。
          final int emitPly = history.outbreakTurn ?? lastPly;
          results.add(DetectedCastleAt(
            template: template,
            side: side,
            ply: emitPly,
          ));
        }
      }
    }
    return results;
  }
}
