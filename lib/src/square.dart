import 'direction.dart';

int? _usiFileToNumber(String usi) {
  if (usi.length != 1) return null;
  final int code = usi.codeUnitAt(0);
  if (code >= 0x31 /* '1' */ && code <= 0x39 /* '9' */) {
    return code - 0x30;
  }
  return null;
}

int? _usiRankToNumber(String usi) {
  switch (usi) {
    case 'a':
      return 1;
    case 'b':
      return 2;
    case 'c':
      return 3;
    case 'd':
      return 4;
    case 'e':
      return 5;
    case 'f':
      return 6;
    case 'g':
      return 7;
    case 'h':
      return 8;
    case 'i':
      return 9;
    default:
      return null;
  }
}

const List<String> _sfenRanks = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];

/// マス目
class Square {
  Square(this.file, this.rank);

  /// 1〜9 の筋
  int file;

  /// 1〜9 の段
  int rank;

  /// 9筋を0としたx座標
  int get x => 9 - file;

  /// 1段目を0としたy座標
  int get y => rank - 1;

  /// 0～80のインデックス
  /// 0=「9一」, 1=「8一」, ..., 80=「1九」
  int get index => y * 9 + x;

  /// 先後を反転したマスを取得します。
  Square get opposite => Square(10 - file, 10 - rank);

  /// 相対座標を指定して近隣のマスを取得します。
  Square neighbor(int dx, int dy) {
    return Square(file - dx, rank + dy);
  }

  /// 方向を指定して隣接(桂馬とびを含む)のマスを取得します。
  Square neighborByDirection(Direction dir) {
    switch (dir) {
      case Direction.up:
        return Square(file, rank - 1);
      case Direction.down:
        return Square(file, rank + 1);
      case Direction.left:
        return Square(file + 1, rank);
      case Direction.right:
        return Square(file - 1, rank);
      case Direction.leftUp:
        return Square(file + 1, rank - 1);
      case Direction.rightUp:
        return Square(file - 1, rank - 1);
      case Direction.leftDown:
        return Square(file + 1, rank + 1);
      case Direction.rightDown:
        return Square(file - 1, rank + 1);
      case Direction.leftUpKnight:
        return Square(file + 1, rank - 2);
      case Direction.rightUpKnight:
        return Square(file - 1, rank - 2);
      case Direction.leftDownKnight:
        return Square(file + 1, rank + 2);
      case Direction.rightDownKnight:
        return Square(file - 1, rank + 2);
    }
  }

  /// 指定したマスへの方向を返します。
  Direction directionTo(Square square) {
    return vectorToDirectionAndDistance(square.x - x, square.y - y)!.direction;
  }

  /// 有効なマス目であるか判定します。
  bool get valid => file >= 1 && file <= 9 && rank >= 1 && rank <= 9;

  /// 同じマス目か判定します。
  bool equals(Square? square) {
    if (square == null) return false;
    return file == square.file && rank == square.rank;
  }

  @override
  bool operator ==(Object other) {
    return other is Square && other.file == file && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(file, rank);

  /// 座標を指定してマスを取得します。
  static Square newByXY(int x, int y) {
    return Square(9 - x, y + 1);
  }

  /// インデクスを指定してマスを取得します。
  static Square newByIndex(int index) {
    return Square(9 - (index % 9), (index ~/ 9) + 1);
  }

  /// 全てのマス目の一覧
  static final List<Square> all =
      List<Square>.generate(81, Square.newByIndex, growable: false);

  /// SFEN形式の文字列を取得します。
  @Deprecated('Use usi instead.')
  String get sfen => usi;

  /// USI形式の文字列を取得します。
  String get usi => '$file${_sfenRanks[rank - 1]}';

  /// SFEN形式のマス目をパースします。
  @Deprecated('Use newByUSI instead.')
  static Square? parseSFENSquare(String sfen) {
    return Square.newByUSI(sfen);
  }

  /// USI形式のマス目をパースします。
  static Square? newByUSI(String usi) {
    if (usi.length < 2) return null;
    final int? file = _usiFileToNumber(usi[0]);
    final int? rank = _usiRankToNumber(usi[1]);
    if (file == null || rank == null) return null;
    return Square(file, rank);
  }
}
