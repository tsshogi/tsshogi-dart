import 'color.dart';
import 'direction.dart';
import 'piece.dart';
import 'square.dart';

const String _standardSFEN =
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL';

int? _sfenCharToNumber(String sfen) {
  switch (sfen) {
    case '1':
      return 1;
    case '2':
      return 2;
    case '3':
      return 3;
    case '4':
      return 4;
    case '5':
      return 5;
    case '6':
      return 6;
    case '7':
      return 7;
    case '8':
      return 8;
    case '9':
      return 9;
    default:
      return null;
  }
}

/// 盤面(読み取り専用)
abstract interface class ImmutableBoard {
  /// 指定したマスの駒を取得します。
  Piece? at(Square square);

  /// 空ではないマスの一覧を取得します。
  Iterable<({Square square, Piece piece})> listNonEmptySquares();

  /// 指定した手番の玉のマスを返します。
  Square? findKing(Color color);

  /// 指定したマスに指定した手番の駒の利きがあるかどうかを判定します。
  bool hasPower(Square target, Color color, {Square? filled, Square? ignore});

  /// 指定した手番の玉に対して王手がかかっているかどうかを判定します。
  bool isChecked(Color kingColor, {Square? filled, Square? ignore});

  /// SFEN形式の文字列を取得します。
  String get sfen;
}

/// 盤面
class Board implements ImmutableBoard {
  Board() {
    _squares = List<Piece?>.filled(81, null);
    resetBySFEN(_standardSFEN);
  }

  late List<Piece?> _squares;

  /// 指定したマスの駒を取得します。
  @override
  Piece? at(Square square) {
    return _squares[square.index];
  }

  /// 指定したマスに駒を配置します。
  void set(Square square, Piece? piece) {
    _squares[square.index] = piece;
  }

  /// 指定した2マスの駒を入れ替えます。
  void swap(Square square1, Square square2) {
    final Piece? tmp = _squares[square1.index];
    _squares[square1.index] = _squares[square2.index];
    _squares[square2.index] = tmp;
  }

  /// 指定したマスの駒を取り除きます。
  Piece? remove(Square square) {
    final Piece? removed = _squares[square.index];
    _squares[square.index] = null;
    return removed;
  }

  /// 空ではないマスの一覧を取得します。
  @override
  Iterable<({Square square, Piece piece})> listNonEmptySquares() sync* {
    for (final Square square in Square.all) {
      final Piece? piece = _squares[square.index];
      if (piece != null) {
        yield (square: square, piece: piece);
      }
    }
  }

  /// 指定した手番の駒があるマスの一覧を取得します。
  Iterable<({Square square, Piece piece})> listSquaresByColor(
      Color color) sync* {
    for (final Square square in Square.all) {
      final Piece? piece = _squares[square.index];
      if (piece != null && piece.color == color) {
        yield (square: square, piece: piece);
      }
    }
  }

  /// 指定した駒があるマスの一覧を取得します。
  Iterable<({Square square, Piece piece})> listSquaresByPiece(
      Piece target) sync* {
    for (final Square square in Square.all) {
      final Piece? piece = _squares[square.index];
      if (piece != null && target.equals(piece)) {
        yield (square: square, piece: piece);
      }
    }
  }

  /// 全てのマスの駒を取り除きます。
  void clear() {
    for (final Square square in Square.all) {
      _squares[square.index] = null;
    }
  }

  /// SFEN形式の文字列を取得します。
  @override
  String get sfen {
    final StringBuffer ret = StringBuffer();
    int empty = 0;
    for (int y = 0; y < 9; y += 1) {
      for (int x = 0; x < 9; x += 1) {
        final Piece? piece = at(Square.newByXY(x, y));
        if (piece != null) {
          if (empty != 0) {
            ret.write(empty);
            empty = 0;
          }
          ret.write(piece.sfen);
        } else {
          empty += 1;
        }
      }
      if (empty != 0) {
        ret.write(empty);
        empty = 0;
      }
      if (y != 8) {
        ret.write('/');
      }
    }
    return ret.toString();
  }

  /// SFENで盤面を初期化します。
  bool resetBySFEN(String sfen) {
    if (!Board.isValidSFEN(sfen)) {
      return false;
    }
    clear();
    final List<String> rows = sfen.split('/');
    for (int y = 0; y < 9; y += 1) {
      int x = 0;
      final String row = rows[y];
      for (int i = 0; i < row.length; i += 1) {
        String c = row[i];
        if (c == '+') {
          i += 1;
          c += row[i];
        }
        final int? n = _sfenCharToNumber(c);
        if (n != null) {
          x += n;
        } else {
          set(Square.newByXY(x, y), Piece.newBySFEN(c));
          x += 1;
        }
      }
    }
    return true;
  }

  /// 指定した手番の玉のマスを返します。
  @override
  Square? findKing(Color color) {
    final Piece king = Piece(color, PieceType.king);
    for (final Square square in Square.all) {
      final Piece? piece = at(square);
      if (piece != null && king.equals(piece)) {
        return square;
      }
    }
    return null;
  }

  /// 指定したマスに指定した手番の駒の利きがあるかどうかを判定します。
  @override
  bool hasPower(Square target, Color color, {Square? filled, Square? ignore}) {
    for (final Direction dir in directions) {
      int step = 0;
      Square square = target.neighborByDirection(dir);
      bool found = false;
      while (square.valid) {
        step += 1;
        if (filled != null && square.equals(filled)) {
          break;
        }
        if (ignore != null && square.equals(ignore)) {
          square = square.neighborByDirection(dir);
          continue;
        }
        final Piece? piece = at(square);
        if (piece != null) {
          if (piece.color != color) {
            break;
          }
          final Direction rdir = reverseDirection(dir);
          final MoveType? type = resolveMoveType(piece, rdir);
          if (type == MoveType.long || (type == MoveType.short && step == 1)) {
            found = true;
          }
          break;
        }
        square = square.neighborByDirection(dir);
      }
      if (found) {
        return true;
      }
    }
    return false;
  }

  /// 指定した手番の玉に対して王手がかかっているかどうかを判定します。
  @override
  bool isChecked(Color kingColor, {Square? filled, Square? ignore}) {
    final Square? square = findKing(kingColor);
    if (square == null) {
      return false;
    }
    return hasPower(
      square,
      reverseColor(kingColor),
      filled: filled,
      ignore: ignore,
    );
  }

  /// 文字列が正しいSFEN形式であるか判定します。
  static bool isValidSFEN(String sfen) {
    final List<String> rows = sfen.split('/');
    if (rows.length != 9) {
      return false;
    }
    for (int y = 0; y < 9; y += 1) {
      int x = 0;
      final String row = rows[y];
      for (int i = 0; i < row.length; i += 1) {
        String c = row[i];
        if (c == '+') {
          i += 1;
          if (i >= row.length) {
            return false;
          }
          c += row[i];
        }
        final int? n = _sfenCharToNumber(c);
        if (n != null) {
          x += n;
        } else if (Piece.isValidSFEN(c)) {
          x += 1;
        } else {
          return false;
        }
      }
      if (x != 9) {
        return false;
      }
    }
    return true;
  }

  /// 別のオブジェクトから盤面をコピーします。
  void copyFrom(ImmutableBoard board) {
    for (final Square square in Square.all) {
      _squares[square.index] = board.at(square);
    }
  }
}
