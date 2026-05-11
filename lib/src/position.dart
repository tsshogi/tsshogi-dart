import 'board.dart';
import 'color.dart';
import 'direction.dart';
import 'hand.dart';
import 'move.dart';
import 'piece.dart';
import 'square.dart';

/// 初期局面の種類 (Deprecated: Use [InitialPositionSFEN] instead.)
enum InitialPositionType {
  standard('standard'),
  empty('empty'),
  handicapLance('handicapLance'),
  handicapRightLance('handicapRightLance'),
  handicapBishop('handicapBishop'),
  handicapRook('handicapRook'),
  handicapRookLance('handicapRookLance'),
  handicap2Pieces('handicap2Pieces'),
  handicap4Pieces('handicap4Pieces'),
  handicap6Pieces('handicap6Pieces'),
  handicap8Pieces('handicap8Pieces'),
  handicap10Pieces('handicap10Pieces'),
  tsumeShogi('tsumeShogi'),
  tsumeShogi2Kings('tsumeShogi2Kings');

  const InitialPositionType(this.value);
  final String value;
}

/// 初期局面の SFEN 文字列
enum InitialPositionSFEN {
  standard('lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1'),
  empty('9/9/9/9/9/9/9/9/9 b - 1'),
  handicapLance(
      'lnsgkgsn1/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicapRightLance(
      '1nsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicapBishop(
      'lnsgkgsnl/1r7/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicapRook(
      'lnsgkgsnl/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicapRookLance(
      'lnsgkgsn1/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicap2Pieces(
      'lnsgkgsnl/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicap4Pieces(
      '1nsgkgsn1/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicap6Pieces(
      '2sgkgs2/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicap8Pieces(
      '3gkg3/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  handicap10Pieces(
      '4k4/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1'),
  tsumeShogi('4k4/9/9/9/9/9/9/9/9 b 2r2b4g4s4n4l18p 1'),
  tsumeShogi2Kings('4k4/9/9/9/9/9/9/9/4K4 b 2r2b4g4s4n4l18p 1');

  const InitialPositionSFEN(this.value);
  final String value;
}

/// [InitialPositionType] から SFEN 形式の文字列に変換します。
String initialPositionTypeToSFEN(InitialPositionType type) {
  switch (type) {
    case InitialPositionType.standard:
      return InitialPositionSFEN.standard.value;
    case InitialPositionType.empty:
      return InitialPositionSFEN.empty.value;
    case InitialPositionType.handicapLance:
      return InitialPositionSFEN.handicapLance.value;
    case InitialPositionType.handicapRightLance:
      return InitialPositionSFEN.handicapRightLance.value;
    case InitialPositionType.handicapBishop:
      return InitialPositionSFEN.handicapBishop.value;
    case InitialPositionType.handicapRook:
      return InitialPositionSFEN.handicapRook.value;
    case InitialPositionType.handicapRookLance:
      return InitialPositionSFEN.handicapRookLance.value;
    case InitialPositionType.handicap2Pieces:
      return InitialPositionSFEN.handicap2Pieces.value;
    case InitialPositionType.handicap4Pieces:
      return InitialPositionSFEN.handicap4Pieces.value;
    case InitialPositionType.handicap6Pieces:
      return InitialPositionSFEN.handicap6Pieces.value;
    case InitialPositionType.handicap8Pieces:
      return InitialPositionSFEN.handicap8Pieces.value;
    case InitialPositionType.handicap10Pieces:
      return InitialPositionSFEN.handicap10Pieces.value;
    case InitialPositionType.tsumeShogi:
      return InitialPositionSFEN.tsumeShogi.value;
    case InitialPositionType.tsumeShogi2Kings:
      return InitialPositionSFEN.tsumeShogi2Kings.value;
  }
}

const Map<Color, Map<PieceType, Map<int, bool>>> _invalidRankMap = {
  Color.black: {
    PieceType.pawn: {1: true},
    PieceType.lance: {1: true},
    PieceType.knight: {1: true, 2: true},
  },
  Color.white: {
    PieceType.pawn: {9: true},
    PieceType.lance: {9: true},
    PieceType.knight: {9: true, 8: true},
  },
};

bool _isInvalidRank(Color color, PieceType type, int rank) {
  final Map<int, bool>? rule = _invalidRankMap[color]![type];
  if (rule == null) return false;
  return rule[rank] ?? false;
}

/// 指定した段が成れる段かどうかを返します。
bool isPromotableRank(Color color, int rank) {
  if (color == Color.black) {
    return rank <= 3;
  }
  return rank >= 7;
}

bool _pawnExists(Color color, Board board, int file) {
  for (int rank = 1; rank <= 9; rank += 1) {
    final Piece? piece = board.at(Square(file, rank));
    if (piece != null &&
        piece.type == PieceType.pawn &&
        piece.color == color) {
      return true;
    }
  }
  return false;
}

/// 局面編集の指示
class PositionMoveChange {
  PositionMoveChange({required this.from, required this.to});

  /// 移動元のマスまたは持ち駒 (Square または Piece)
  final Object from;

  /// 移動先のマスまたは駒台 (Square または Color)
  final Object to;
}

/// 局面編集の指示
class PositionChange {
  PositionChange({this.move, this.rotate});
  final PositionMoveChange? move;
  final Square? rotate;
}

/// 局面(読み取り専用)
abstract interface class ImmutablePosition {
  ImmutableBoard get board;
  Color get color;
  ImmutableHand get blackHand;
  ImmutableHand get whiteHand;
  ImmutableHand hand(Color color);
  bool get checked;
  Move? createMove(MoveOrigin from, Square to);
  Move? createMoveByUSI(String usiMove);
  bool isPawnDropMate(Move move);
  List<Square> listAttackers(Square to);
  List<Square> listAttackersByPiece(Square to, Piece piece);
  bool isValidMove(Move move);
  bool isValidEditing(Object from, Object to);
  String get sfen;
  String getSFEN(int nextPly);
  Position clone();
}

/// 局面
class Position implements ImmutablePosition {
  Position();

  final Board _board = Board();
  Color _color = Color.black;
  Hand _blackHand = Hand();
  Hand _whiteHand = Hand();

  @override
  Board get board => _board;

  @override
  Color get color => _color;

  @override
  Hand get blackHand => _blackHand;

  @override
  Hand get whiteHand => _whiteHand;

  @override
  Hand hand(Color color) {
    if (color == Color.black) {
      return _blackHand;
    }
    return _whiteHand;
  }

  @override
  bool get checked => _board.isChecked(color);

  @override
  Move? createMove(MoveOrigin from, Square to) {
    final PieceType pieceType;
    if (from is FromSquare) {
      final Piece? piece = _board.at(from.square);
      if (piece == null) {
        return null;
      }
      pieceType = piece.type;
    } else if (from is FromHand) {
      pieceType = from.pieceType;
    } else {
      return null;
    }
    final Piece? capturedPiece = _board.at(to);
    return Move(
      from,
      to,
      false,
      color,
      pieceType,
      capturedPiece?.type,
    );
  }

  @override
  Move? createMoveByUSI(String usiMove) {
    final parsed = parseUSIMove(usiMove);
    if (parsed == null) {
      return null;
    }
    Move? move = createMove(parsed.from, parsed.to);
    if (move == null) {
      return null;
    }
    if (parsed.promote) {
      move = move.withPromote();
    }
    return move;
  }

  @override
  bool isPawnDropMate(Move move) {
    if (move.from is! FromHand) {
      return false;
    }
    if (move.pieceType != PieceType.pawn) {
      return false;
    }
    final Square kingSquare = move.to.neighborByDirection(
      move.color == Color.black ? Direction.up : Direction.down,
    );
    final Piece? king = board.at(kingSquare);
    if (king == null ||
        king.type != PieceType.king ||
        king.color == move.color) {
      return false;
    }
    final bool kingMovable = movableDirections(king).any((Direction dir) {
      final Square to = kingSquare.neighborByDirection(dir);
      if (!to.valid) {
        return false;
      }
      final Piece? piece = board.at(to);
      if (piece != null && piece.color == king.color) {
        return false;
      }
      return !board.hasPower(to, move.color, filled: move.to);
    });
    if (kingMovable) {
      return false;
    }
    // 玉以外の駒で取って王手を解除できるか
    for (final entry in board.listSquaresByColor(king.color)) {
      final Square from = entry.square;
      if (from.equals(kingSquare)) {
        continue;
      }
      if (_isMovable(from, move.to) &&
          !board.isChecked(king.color, filled: move.to, ignore: from)) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Square> listAttackers(Square to) {
    final List<Square> result = <Square>[];
    for (final entry in board.listNonEmptySquares()) {
      if (_isMovable(entry.square, to)) {
        result.add(entry.square);
      }
    }
    return result;
  }

  @override
  List<Square> listAttackersByPiece(Square to, Piece piece) {
    final List<Square> result = <Square>[];
    for (final entry in board.listSquaresByPiece(piece)) {
      if (_isMovable(entry.square, to)) {
        result.add(entry.square);
      }
    }
    return result;
  }

  @override
  bool isValidMove(Move move) {
    final MoveOrigin origin = move.from;
    if (origin is FromSquare) {
      final Square fromSquare = origin.square;
      final Piece? target = _board.at(fromSquare);
      if (target == null ||
          target.color != color ||
          target.type != move.pieceType) {
        return false;
      }
      if (!_isMovable(fromSquare, move.to)) {
        return false;
      }
      final Piece? captured = _board.at(move.to);
      if (captured != null && captured.color == color) {
        return false;
      }
      if ((captured == null) != (move.capturedPieceType == null)) {
        return false;
      }
      if (captured != null &&
          move.capturedPieceType != null &&
          captured.type != move.capturedPieceType) {
        return false;
      }
      if (move.promote) {
        if (!target.isPromotable()) {
          return false;
        }
        if (!isPromotableRank(color, fromSquare.rank) &&
            !isPromotableRank(color, move.to.rank)) {
          return false;
        }
      } else if (_isInvalidRank(color, target.type, move.to.rank)) {
        return false;
      }
      if (move.pieceType != PieceType.king
          ? _board.isChecked(color, filled: move.to, ignore: fromSquare)
          : _board.hasPower(move.to, reverseColor(color), ignore: fromSquare)) {
        return false;
      }
    } else if (origin is FromHand) {
      final PieceType handType = origin.pieceType;
      if (move.promote) {
        return false;
      }
      if (move.color != color) {
        return false;
      }
      if (hand(color).count(handType) == 0) {
        return false;
      }
      if (_board.at(move.to) != null) {
        return false;
      }
      if (_isInvalidRank(color, handType, move.to.rank)) {
        return false;
      }
      if (handType == PieceType.pawn &&
          _pawnExists(color, _board, move.to.file)) {
        return false;
      }
      if (_board.isChecked(color, filled: move.to)) {
        return false;
      }
      if (isPawnDropMate(move)) {
        return false;
      }
    }
    return true;
  }

  /// 指定した指し手で駒を動かします。
  bool doMove(Move move, {bool ignoreValidation = false}) {
    if (!ignoreValidation && !isValidMove(move)) {
      return false;
    }
    final MoveOrigin origin = move.from;
    if (origin is FromSquare) {
      final Square fromSquare = origin.square;
      final Piece? target = _board.at(fromSquare);
      if (target == null) {
        return false;
      }
      final Piece? captured = _board.at(move.to);
      _board.remove(fromSquare);
      _board.set(move.to, move.promote ? target.promoted() : target);
      if (captured != null && captured.type != PieceType.king) {
        hand(color).add(captured.unpromoted().type, 1);
      }
    } else if (origin is FromHand) {
      hand(color).reduce(origin.pieceType, 1);
      _board.set(move.to, Piece(color, origin.pieceType));
    }
    _color = reverseColor(color);
    return true;
  }

  /// 指定した指し手を元に戻します。
  void undoMove(Move move) {
    _color = reverseColor(color);
    final MoveOrigin origin = move.from;
    if (origin is FromSquare) {
      _board.set(origin.square, Piece(color, move.pieceType));
      if (move.capturedPieceType != null) {
        final Piece capturedPiece =
            Piece(reverseColor(color), move.capturedPieceType!);
        _board.set(move.to, capturedPiece);
        if (capturedPiece.type != PieceType.king) {
          hand(color).reduce(capturedPiece.unpromoted().type, 1);
        }
      } else {
        _board.remove(move.to);
      }
    } else if (origin is FromHand) {
      hand(color).add(origin.pieceType, 1);
      _board.remove(move.to);
    }
  }

  @override
  bool isValidEditing(Object from, Object to) {
    if (from is Square) {
      final Piece? piece = _board.at(from);
      if (piece == null) {
        return false;
      }
      if (to is Square) {
        if (from.equals(to)) {
          return false;
        }
      } else if (to is Color) {
        if (piece.type == PieceType.king) {
          return false;
        }
      } else {
        return false;
      }
    } else if (from is Piece) {
      if (hand(from.color).count(from.type) == 0) {
        return false;
      }
      if (to is Square) {
        if (_board.at(to) != null) {
          return false;
        }
      } else if (to is Color) {
        if (from.color == to) {
          return false;
        }
      } else {
        return false;
      }
    } else {
      return false;
    }
    return true;
  }

  /// 盤面を編集します。
  bool edit(PositionChange change) {
    final PositionMoveChange? move = change.move;
    if (move != null) {
      if (!isValidEditing(move.from, move.to)) {
        return false;
      }
      final Object from = move.from;
      final Object to = move.to;
      if (from is Piece) {
        hand(from.color).reduce(from.type, 1);
        if (to is Square) {
          _board.set(to, from);
        } else if (to is Color) {
          hand(to).add(from.type, 1);
        }
      } else if (from is Square && to is Color) {
        final Piece? piece = _board.remove(from);
        if (piece != null) {
          hand(to).add(piece.unpromoted().type, 1);
        }
      } else if (from is Square && to is Square) {
        _board.swap(from, to);
      }
    }
    final Square? rotate = change.rotate;
    if (rotate != null) {
      final Piece? piece = _board.at(rotate);
      if (piece != null) {
        _board.set(rotate, piece.rotate());
      }
    }
    return true;
  }

  /// (Deprecated) [resetBySFEN] を使ってください。
  void reset(InitialPositionType type) {
    resetBySFEN(initialPositionTypeToSFEN(type));
  }

  /// SFEN形式の文字列を返します。
  @override
  String get sfen => getSFEN(1);

  /// 手数を指定してSFEN形式の文字列を取得します。
  @override
  String getSFEN(int nextPly) {
    final StringBuffer ret = StringBuffer();
    ret.write(_board.sfen);
    ret.write(' ');
    ret.write(colorToSFEN(color));
    ret.write(' ');
    ret.write(Hand.formatSFENOf(_blackHand, _whiteHand));
    ret.write(' ');
    ret.write(nextPly < 1 ? 1 : nextPly);
    return ret.toString();
  }

  /// SFENで盤面を初期化します。
  bool resetBySFEN(String sfen) {
    if (!Position.isValidSFEN(sfen)) {
      return false;
    }
    final List<String> sections = sfen.split(' ');
    if (sections[0] == 'sfen') {
      sections.removeAt(0);
    }
    _board.resetBySFEN(sections[0]);
    _color = parseSFENColor(sections[1]);
    final hands = Hand.parseSFEN(sections[2]);
    if (hands == null) {
      return false;
    }
    _blackHand = hands.black;
    _whiteHand = hands.white;
    return true;
  }

  /// 手番を設定します。
  void setColor(Color color) {
    _color = color;
  }

  /// 正しいSFEN形式の文字列かどうかを判定します。
  static bool isValidSFEN(String sfen) {
    final List<String> sections = sfen.split(' ');
    if ((sections.length == 5 || sections.length == 4) &&
        sections[0] == 'sfen') {
      sections.removeAt(0);
    }
    if (sections.length != 4 && sections.length != 3) {
      return false;
    }
    if (!Board.isValidSFEN(sections[0])) {
      return false;
    }
    if (!isValidSFENColor(sections[1])) {
      return false;
    }
    if (!Hand.isValidSFEN(sections[2])) {
      return false;
    }
    if (sections.length == 4 && !RegExp(r'[0-9]+').hasMatch(sections[3])) {
      return false;
    }
    return true;
  }

  /// SFEN形式の文字列から局面を生成します。
  static Position? newBySFEN(String sfen) {
    final Position position = Position();
    return position.resetBySFEN(sfen) ? position : null;
  }

  bool _isMovable(Square from, Square to) {
    final int dx = to.x - from.x;
    final int dy = to.y - from.y;
    final result = vectorToDirectionAndDistance(dx, dy);
    if (result == null) {
      return false;
    }
    final Direction direction = result.direction;
    final int distance = result.distance;
    final Piece? piece = _board.at(from);
    if (piece == null) {
      return false;
    }
    final MoveType? type = resolveMoveType(piece, direction);
    if (type == null) {
      return false;
    }
    switch (type) {
      case MoveType.short:
        return distance == 1;
      case MoveType.long:
        final delta = directionToDeltaMap[direction]!;
        Square square = from.neighbor(delta.x, delta.y);
        while (square.valid) {
          if (square.equals(to)) {
            return true;
          }
          if (_board.at(square) != null) {
            return false;
          }
          square = square.neighbor(delta.x, delta.y);
        }
        return false;
    }
  }

  /// 別のオブジェクトからコピーします。
  void copyFrom(ImmutablePosition position) {
    _board.copyFrom(position.board);
    _color = position.color;
    _blackHand.copyFrom(position.blackHand);
    _whiteHand.copyFrom(position.whiteHand);
  }

  /// クローンを生成します。
  @override
  Position clone() {
    final Position position = Position();
    position.copyFrom(this);
    return position;
  }
}

/// 局面オプション
class DoMoveOption {
  const DoMoveOption({this.ignoreValidation = false});
  final bool ignoreValidation;
}

/// 各駒種の現在の枚数
Map<PieceType, int> countExistingPieces(ImmutablePosition position) {
  final Map<PieceType, int> result = <PieceType, int>{
    PieceType.pawn: 0,
    PieceType.lance: 0,
    PieceType.knight: 0,
    PieceType.silver: 0,
    PieceType.gold: 0,
    PieceType.bishop: 0,
    PieceType.rook: 0,
    PieceType.king: 0,
    PieceType.promPawn: 0,
    PieceType.promLance: 0,
    PieceType.promKnight: 0,
    PieceType.promSilver: 0,
    PieceType.horse: 0,
    PieceType.dragon: 0,
  };
  for (final Square square in Square.all) {
    final Piece? piece = position.board.at(square);
    if (piece != null) {
      result[piece.type] = (result[piece.type] ?? 0) + 1;
    }
  }
  position.blackHand.forEach((PieceType type, int n) {
    result[type] = (result[type] ?? 0) + n;
  });
  position.whiteHand.forEach((PieceType type, int n) {
    result[type] = (result[type] ?? 0) + n;
  });
  return result;
}

/// 盤上と持ち駒に存在しない駒の枚数
Map<PieceType, int> countNotExistingPieces(ImmutablePosition position) {
  final Map<PieceType, int> existed = countExistingPieces(position);
  return <PieceType, int>{
    PieceType.pawn:
        18 - (existed[PieceType.pawn]!) - (existed[PieceType.promPawn]!),
    PieceType.lance:
        4 - (existed[PieceType.lance]!) - (existed[PieceType.promLance]!),
    PieceType.knight:
        4 - (existed[PieceType.knight]!) - (existed[PieceType.promKnight]!),
    PieceType.silver:
        4 - (existed[PieceType.silver]!) - (existed[PieceType.promSilver]!),
    PieceType.gold: 4 - (existed[PieceType.gold]!),
    PieceType.bishop:
        2 - (existed[PieceType.bishop]!) - (existed[PieceType.horse]!),
    PieceType.rook:
        2 - (existed[PieceType.rook]!) - (existed[PieceType.dragon]!),
    PieceType.king: 2 - (existed[PieceType.king]!),
    PieceType.promPawn: 0,
    PieceType.promLance: 0,
    PieceType.promKnight: 0,
    PieceType.promSilver: 0,
    PieceType.horse: 0,
    PieceType.dragon: 0,
  };
}

/// 持将棋宣言ルール
enum JishogiDeclarationRule {
  general24('general24'),
  general27('general27');

  const JishogiDeclarationRule(this.value);
  final String value;
}

/// 持将棋宣言結果
enum JishogiDeclarationResult {
  win('win'),
  lose('lose'),
  draw('draw');

  const JishogiDeclarationResult(this.value);
  final String value;
}

Iterable<Piece> _invadingPieces(ImmutableBoard board, Color color) sync* {
  for (final entry in board.listNonEmptySquares()) {
    if (!isPromotableRank(color, entry.square.rank)) {
      continue;
    }
    final Piece piece = entry.piece;
    if (piece.color == color && piece.type != PieceType.king) {
      yield piece;
    }
  }
}

/// 持将棋指し直し判定の点数を計算します。
int countJishogiPoint(ImmutablePosition position, Color color) {
  int point = 0;
  for (final Square square in Square.all) {
    final Piece? piece = position.board.at(square);
    if (piece != null && piece.color == color && piece.type != PieceType.king) {
      final PieceType type = piece.unpromoted().type;
      point += (type == PieceType.bishop || type == PieceType.rook) ? 5 : 1;
    }
  }
  final ImmutableHand hand = position.hand(color);
  point += hand.count(PieceType.pawn) +
      hand.count(PieceType.lance) +
      hand.count(PieceType.knight) +
      hand.count(PieceType.silver) +
      hand.count(PieceType.gold) +
      hand.count(PieceType.bishop) * 5 +
      hand.count(PieceType.rook) * 5;
  if (color == Color.white) {
    final Map<PieceType, int> notExisting = countNotExistingPieces(position);
    point += (notExisting[PieceType.pawn]!) +
        (notExisting[PieceType.lance]!) +
        (notExisting[PieceType.knight]!) +
        (notExisting[PieceType.silver]!) +
        (notExisting[PieceType.gold]!) +
        (notExisting[PieceType.bishop]!) * 5 +
        (notExisting[PieceType.rook]!) * 5;
  }
  return point;
}

/// 入玉宣言法に基づいて宣言する際の点数を計算します。
int countJishogiDeclarationPoint(ImmutablePosition position, Color color) {
  int point = 0;
  for (final Piece piece in _invadingPieces(position.board, color)) {
    final PieceType type = piece.unpromoted().type;
    point += (type == PieceType.bishop || type == PieceType.rook) ? 5 : 1;
  }
  final ImmutableHand hand = position.hand(color);
  point += hand.count(PieceType.pawn) +
      hand.count(PieceType.lance) +
      hand.count(PieceType.knight) +
      hand.count(PieceType.silver) +
      hand.count(PieceType.gold) +
      hand.count(PieceType.bishop) * 5 +
      hand.count(PieceType.rook) * 5;
  if (color == Color.white) {
    final Map<PieceType, int> notExisting = countNotExistingPieces(position);
    point += (notExisting[PieceType.pawn]!) +
        (notExisting[PieceType.lance]!) +
        (notExisting[PieceType.knight]!) +
        (notExisting[PieceType.silver]!) +
        (notExisting[PieceType.gold]!) +
        (notExisting[PieceType.bishop]!) * 5 +
        (notExisting[PieceType.rook]!) * 5;
  }
  return point;
}

/// 入玉宣言法に基づいて宣言した場合の結果を判定します。
JishogiDeclarationResult judgeJishogiDeclaration(
  JishogiDeclarationRule rule,
  ImmutablePosition position,
  Color color,
) {
  // 自分の手番か。
  if (position.color != color) {
    return JishogiDeclarationResult.lose;
  }

  // 玉が敵陣に入っているか。
  final Square? king = position.board.findKing(color);
  if (king == null || !isPromotableRank(color, king.rank)) {
    return JishogiDeclarationResult.lose;
  }

  // 王手されていないか。
  if (position.board.isChecked(color)) {
    return JishogiDeclarationResult.lose;
  }

  // 敵陣に 10 枚以上駒が侵入しているか。
  if (_invadingPieces(position.board, color).length < 10) {
    return JishogiDeclarationResult.lose;
  }

  final int point = countJishogiDeclarationPoint(position, color);

  if (rule == JishogiDeclarationRule.general24) {
    if (point >= 31) return JishogiDeclarationResult.win;
    if (point >= 24) return JishogiDeclarationResult.draw;
    return JishogiDeclarationResult.lose;
  }

  // 27 点法
  if (color == Color.black) {
    return point >= 28
        ? JishogiDeclarationResult.win
        : JishogiDeclarationResult.draw;
  } else {
    return point >= 27
        ? JishogiDeclarationResult.win
        : JishogiDeclarationResult.draw;
  }
}
