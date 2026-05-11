import 'color.dart';
import 'piece.dart';
import 'square.dart';

/// 指し手の出発地点。盤上のマス目または持ち駒の駒種。
sealed class MoveOrigin {
  const MoveOrigin();
}

/// 盤上のマス目から指す。
class FromSquare extends MoveOrigin {
  const FromSquare(this.square);
  final Square square;

  @override
  bool operator ==(Object other) {
    return other is FromSquare && other.square == square;
  }

  @override
  int get hashCode => Object.hash('FromSquare', square);
}

/// 持ち駒から打つ。
class FromHand extends MoveOrigin {
  const FromHand(this.pieceType);
  final PieceType pieceType;

  @override
  bool operator ==(Object other) {
    return other is FromHand && other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash('FromHand', pieceType);
}

/// 指し手
class Move {
  Move(
    this.from,
    this.to,
    this.promote,
    this.color,
    this.pieceType,
    this.capturedPieceType,
  );

  MoveOrigin from;
  Square to;
  bool promote;
  Color color;
  PieceType pieceType;
  PieceType? capturedPieceType;

  /// 指し手が等しいかどうかを判定します。
  bool equals(Move? move) {
    if (move == null) return false;
    return from == move.from &&
        to.equals(move.to) &&
        promote == move.promote &&
        color == move.color &&
        pieceType == move.pieceType &&
        capturedPieceType == move.capturedPieceType;
  }

  @override
  bool operator ==(Object other) {
    return other is Move &&
        other.from == from &&
        other.to == to &&
        other.promote == promote &&
        other.color == color &&
        other.pieceType == pieceType &&
        other.capturedPieceType == capturedPieceType;
  }

  @override
  int get hashCode =>
      Object.hash(from, to, promote, color, pieceType, capturedPieceType);

  /// 成る手を返します。
  Move withPromote() {
    return Move(from, to, true, color, pieceType, capturedPieceType);
  }

  /// USI形式の文字列を取得します。
  String get usi {
    final String head = switch (from) {
      FromSquare(:final square) => square.usi,
      FromHand(:final pieceType) => '${pieceTypeToSFEN(pieceType)}*',
    };
    final String tail = promote ? '+' : '';
    return '$head${to.usi}$tail';
  }
}

/// USI形式の文字列を解析します。失敗時は null を返します。
({MoveOrigin from, Square to, bool promote})? parseUSIMove(String usiMove) {
  if (usiMove.length < 4) return null;
  final MoveOrigin from;
  if (usiMove[1] == '*') {
    final Piece? piece = Piece.newBySFEN(usiMove[0]);
    if (piece == null) return null;
    from = FromHand(piece.type);
  } else {
    final Square? square = Square.newByUSI(usiMove);
    if (square == null) return null;
    from = FromSquare(square);
  }
  final Square? to = Square.newByUSI(usiMove.substring(2));
  if (to == null) return null;
  final bool promote = usiMove.length >= 5 && usiMove[4] == '+';
  return (from: from, to: to, promote: promote);
}

/// 特殊な指し手の種類
enum SpecialMoveType {
  start('start'),
  interrupt('interrupt'),
  resign('resign'),
  maxMoves('maxMoves'),
  impass('impass'),
  draw('draw'),
  repetitionDraw('repetitionDraw'),
  mate('mate'),
  noMate('noMate'),
  timeout('timeout'),

  /// 手番側の勝ち(直前の指し手が反則手)
  foulWin('foulWin'),

  /// 手番側の負け
  foulLose('foulLose'),
  enteringOfKing('enteringOfKing'),
  winByDefault('winByDefault'),
  loseByDefault('loseByDefault'),

  /// トライ成立
  try_('try');

  const SpecialMoveType(this.value);

  final String value;
}

/// 特殊な指し手
sealed class SpecialMove {
  const SpecialMove();
}

/// 定義済みの特殊な指し手
class PredefinedSpecialMove extends SpecialMove {
  const PredefinedSpecialMove(this.type);
  final SpecialMoveType type;

  @override
  bool operator ==(Object other) {
    return other is PredefinedSpecialMove && other.type == type;
  }

  @override
  int get hashCode => Object.hash('PredefinedSpecialMove', type);
}

/// 未定義の特殊な指し手
class AnySpecialMove extends SpecialMove {
  const AnySpecialMove(this.name);
  final String name;

  @override
  bool operator ==(Object other) {
    return other is AnySpecialMove && other.name == name;
  }

  @override
  int get hashCode => Object.hash('AnySpecialMove', name);
}

/// 定義済みの特殊な指し手を作成します。
PredefinedSpecialMove specialMove(SpecialMoveType type) {
  return PredefinedSpecialMove(type);
}

/// 未定義の特殊な指し手を作成します。
AnySpecialMove anySpecialMove(String name) {
  return AnySpecialMove(name);
}

/// 定義済みの特殊な指し手かどうかを判定します。
bool isKnownSpecialMove(Object move) {
  return move is PredefinedSpecialMove;
}

bool areSameSpecialMoves(SpecialMove a, SpecialMove b) {
  if (a is AnySpecialMove && b is AnySpecialMove) {
    return a.name == b.name;
  }
  if (a is PredefinedSpecialMove && b is PredefinedSpecialMove) {
    return a.type == b.type;
  }
  return false;
}

/// `Move` または `SpecialMove` を受け取り、同一かを判定します。
bool areSameMoves(Object a, Object b) {
  if (a is Move && b is Move) {
    return a.equals(b);
  }
  if (a is Move || b is Move) {
    return false;
  }
  if (a is SpecialMove && b is SpecialMove) {
    return areSameSpecialMoves(a, b);
  }
  return false;
}
