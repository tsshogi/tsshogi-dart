import 'color.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// 棋譜走査中に各駒の移動履歴を集計するトラッカー。
///
/// `record.castles` / `record.strategies` が指し手を 1 手ずつ進める際に
/// 更新され、`PieceUnmoved` / `PieceVisited` / `KingIgyoku` 等の履歴依存
/// 要件から参照される。
class MoveHistory {
  MoveHistory();

  /// (color, square) — そのマスから一度でも `move.from` として動かれたか。
  ///
  /// `PieceUnmoved` が `!_sourceTouched.contains(...)` を真偽判定に使う。
  final Set<({Color color, Square square})> _sourceTouched =
      <({Color color, Square square})>{};

  /// (color, pieceType) → そのチームのその種類の駒が居たことのある全マス。
  /// 初期局面の配置 + 各 `Move.to` を蓄積していく。
  final Map<({Color color, PieceType pieceType}), Set<Square>> _visited =
      <({Color color, PieceType pieceType}), Set<Square>>{};

  /// 各陣営の玉が最初に動いた手数 (ply)。動いていなければ `null`。
  ///
  /// bioshogi の `king_first_moved_turn` に相当。`recordMove` 時に king
  /// の `from` がマス起点であれば、その色について初回のみセットする。
  final Map<Color, int?> _kingFirstMovedTurn = <Color, int?>{
    Color.black: null,
    Color.white: null,
  };

  /// 「歩・角以外の駒が初めて取られた手数 (ply)」を保持する。
  ///
  /// bioshogi の `outbreak_turn` に相当。`capturedPieceType` が
  /// `pawn` / `bishop` 以外であった最初の手を記録する。`+B` (馬) や `+P`
  /// (と金) はそれぞれ「角・歩の成駒」だが、bioshogi 本体の判定では
  /// 「歩・角の生駒のみ除外」する素朴な式なので本実装でもそれに合わせる。
  int? _outbreakTurn;

  /// 初期局面の駒配置で履歴を初期化する。
  ///
  /// 各駒の初期マスを `_visited` に登録する。`_sourceTouched` は空のまま
  /// (まだ 1 手も指されていない)。
  void initFromPosition(ImmutablePosition position) {
    for (final ({Square square, Piece piece}) entry
        in position.board.listNonEmptySquares()) {
      final ({Color color, PieceType pieceType}) key = (
        color: entry.piece.color,
        pieceType: entry.piece.type,
      );
      (_visited[key] ??= <Square>{}).add(entry.square);
    }
  }

  /// 一手 [move] を [ply] 手目として適用したときに履歴を更新する。
  ///
  /// 盤上からの移動 (`FromSquare`) なら出発マスを `_sourceTouched` に追加し、
  /// 到着マス + 駒種を `_visited` に追加する。打ち手 (`FromHand`) では到着マ
  /// スのみ追加される。
  ///
  /// 加えて:
  /// - king の盤上移動なら、その陣営の `kingFirstMovedTurn` を初回のみ設定。
  /// - `capturedPieceType` が pawn / bishop 以外なら `outbreakTurn` を初回
  ///   のみ設定。
  void recordMove(Move move, int ply) {
    final MoveOrigin from = move.from;
    if (from is FromSquare) {
      _sourceTouched.add((color: move.color, square: from.square));
      if (move.pieceType == PieceType.king) {
        if (_kingFirstMovedTurn[move.color] == null) {
          _kingFirstMovedTurn[move.color] = ply;
        }
      }
    }
    final ({Color color, PieceType pieceType}) key = (
      color: move.color,
      pieceType: move.pieceType,
    );
    (_visited[key] ??= <Square>{}).add(move.to);

    final PieceType? captured = move.capturedPieceType;
    if (captured != null &&
        captured != PieceType.pawn &&
        captured != PieceType.bishop &&
        _outbreakTurn == null) {
      _outbreakTurn = ply;
    }
  }

  /// [side] が file,rank マスから一度も動いていないか。
  bool isUnmoved(Color side, int file, int rank) {
    return !_sourceTouched.contains((color: side, square: Square(file, rank)));
  }

  /// [side] の [pieceType] が file,rank マスに過去いたことがあるか。
  bool hasVisited(Color side, PieceType pieceType, int file, int rank) {
    final ({Color color, PieceType pieceType}) key = (
      color: side,
      pieceType: pieceType,
    );
    return _visited[key]?.contains(Square(file, rank)) ?? false;
  }

  /// [side] の玉が最初に動いた手数。まだ動いていなければ `null`。
  int? kingFirstMovedTurn(Color side) => _kingFirstMovedTurn[side];

  /// 歩・角以外の駒が初めて取られた手数。まだ起きていなければ `null`。
  int? get outbreakTurn => _outbreakTurn;
}
