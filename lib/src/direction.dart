import 'color.dart';
import 'piece.dart';

/// 方向
enum Direction {
  up('up'),
  down('down'),
  left('left'),
  right('right'),
  leftUp('left_up'),
  rightUp('right_up'),
  leftDown('left_down'),
  rightDown('right_down'),
  leftUpKnight('left_up_knight'),
  rightUpKnight('right_up_knight'),
  leftDownKnight('left_down_knight'),
  rightDownKnight('right_down_knight');

  const Direction(this.value);

  final String value;
}

const Map<Direction, Direction> _reverseMap = {
  Direction.up: Direction.down,
  Direction.down: Direction.up,
  Direction.left: Direction.right,
  Direction.right: Direction.left,
  Direction.leftUp: Direction.rightDown,
  Direction.rightUp: Direction.leftDown,
  Direction.leftDown: Direction.rightUp,
  Direction.rightDown: Direction.leftUp,
  Direction.leftUpKnight: Direction.rightDownKnight,
  Direction.rightUpKnight: Direction.leftDownKnight,
  Direction.leftDownKnight: Direction.rightUpKnight,
  Direction.rightDownKnight: Direction.leftUpKnight,
};

/// 反転した方向を返します。
Direction reverseDirection(Direction dir) {
  return _reverseMap[dir]!;
}

const List<Direction> directions = [
  Direction.up,
  Direction.down,
  Direction.left,
  Direction.right,
  Direction.leftUp,
  Direction.rightUp,
  Direction.leftDown,
  Direction.rightDown,
  Direction.leftUpKnight,
  Direction.rightUpKnight,
  Direction.leftDownKnight,
  Direction.rightDownKnight,
];

enum MoveType {
  short('short'),
  long('long');

  const MoveType(this.value);

  final String value;
}

const Map<Color, Map<PieceType, Map<Direction, MoveType>>>
    _movableDirectionMap = {
  Color.black: {
    PieceType.pawn: {Direction.up: MoveType.short},
    PieceType.lance: {Direction.up: MoveType.long},
    PieceType.knight: {
      Direction.leftUpKnight: MoveType.short,
      Direction.rightUpKnight: MoveType.short,
    },
    PieceType.silver: {
      Direction.leftUp: MoveType.short,
      Direction.up: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.leftDown: MoveType.short,
      Direction.rightDown: MoveType.short,
    },
    PieceType.gold: {
      Direction.leftUp: MoveType.short,
      Direction.up: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.down: MoveType.short,
    },
    PieceType.bishop: {
      Direction.leftUp: MoveType.long,
      Direction.rightUp: MoveType.long,
      Direction.leftDown: MoveType.long,
      Direction.rightDown: MoveType.long,
    },
    PieceType.rook: {
      Direction.up: MoveType.long,
      Direction.left: MoveType.long,
      Direction.right: MoveType.long,
      Direction.down: MoveType.long,
    },
    PieceType.king: {
      Direction.leftDown: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.leftUp: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.down: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.promPawn: {
      Direction.leftUp: MoveType.short,
      Direction.up: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.down: MoveType.short,
    },
    PieceType.promLance: {
      Direction.leftUp: MoveType.short,
      Direction.up: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.down: MoveType.short,
    },
    PieceType.promKnight: {
      Direction.leftUp: MoveType.short,
      Direction.up: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.down: MoveType.short,
    },
    PieceType.promSilver: {
      Direction.leftUp: MoveType.short,
      Direction.up: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.down: MoveType.short,
    },
    PieceType.horse: {
      Direction.leftUp: MoveType.long,
      Direction.rightUp: MoveType.long,
      Direction.leftDown: MoveType.long,
      Direction.rightDown: MoveType.long,
      Direction.up: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.down: MoveType.short,
    },
    PieceType.dragon: {
      Direction.up: MoveType.long,
      Direction.left: MoveType.long,
      Direction.right: MoveType.long,
      Direction.down: MoveType.long,
      Direction.leftUp: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.leftDown: MoveType.short,
      Direction.rightDown: MoveType.short,
    },
  },
  Color.white: {
    PieceType.pawn: {Direction.down: MoveType.short},
    PieceType.lance: {Direction.down: MoveType.long},
    PieceType.knight: {
      Direction.leftDownKnight: MoveType.short,
      Direction.rightDownKnight: MoveType.short,
    },
    PieceType.silver: {
      Direction.leftDown: MoveType.short,
      Direction.down: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.leftUp: MoveType.short,
      Direction.rightUp: MoveType.short,
    },
    PieceType.gold: {
      Direction.leftDown: MoveType.short,
      Direction.down: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.bishop: {
      Direction.leftDown: MoveType.long,
      Direction.rightDown: MoveType.long,
      Direction.leftUp: MoveType.long,
      Direction.rightUp: MoveType.long,
    },
    PieceType.rook: {
      Direction.down: MoveType.long,
      Direction.left: MoveType.long,
      Direction.right: MoveType.long,
      Direction.up: MoveType.long,
    },
    PieceType.king: {
      Direction.leftDown: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.leftUp: MoveType.short,
      Direction.rightUp: MoveType.short,
      Direction.down: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.promPawn: {
      Direction.leftDown: MoveType.short,
      Direction.down: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.promLance: {
      Direction.leftDown: MoveType.short,
      Direction.down: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.promKnight: {
      Direction.leftDown: MoveType.short,
      Direction.down: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.promSilver: {
      Direction.leftDown: MoveType.short,
      Direction.down: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.horse: {
      Direction.leftDown: MoveType.long,
      Direction.rightDown: MoveType.long,
      Direction.leftUp: MoveType.long,
      Direction.rightUp: MoveType.long,
      Direction.down: MoveType.short,
      Direction.left: MoveType.short,
      Direction.right: MoveType.short,
      Direction.up: MoveType.short,
    },
    PieceType.dragon: {
      Direction.down: MoveType.long,
      Direction.left: MoveType.long,
      Direction.right: MoveType.long,
      Direction.up: MoveType.long,
      Direction.leftDown: MoveType.short,
      Direction.rightDown: MoveType.short,
      Direction.leftUp: MoveType.short,
      Direction.rightUp: MoveType.short,
    },
  },
};

/// 指定した駒の移動可能な方向を返します。
List<Direction> movableDirections(Piece piece) {
  return _movableDirectionMap[piece.color]![piece.type]!.keys.toList();
}

/// 指定した駒と方向に対して、1マスのみ移動可能か遠距離移動可能かを返します。
MoveType? resolveMoveType(Piece piece, Direction direction) {
  return _movableDirectionMap[piece.color]![piece.type]![direction];
}

/// 方向と (x, y) デルタの対応マップ。
const Map<Direction, ({int x, int y})> directionToDeltaMap = {
  Direction.up: (x: 0, y: -1),
  Direction.down: (x: 0, y: 1),
  Direction.left: (x: -1, y: 0),
  Direction.right: (x: 1, y: 0),
  Direction.leftUp: (x: -1, y: -1),
  Direction.rightUp: (x: 1, y: -1),
  Direction.leftDown: (x: -1, y: 1),
  Direction.rightDown: (x: 1, y: 1),
  Direction.leftUpKnight: (x: -1, y: -2),
  Direction.rightUpKnight: (x: 1, y: -2),
  Direction.leftDownKnight: (x: -1, y: 2),
  Direction.rightDownKnight: (x: 1, y: 2),
};

/// ベクトルを方向と距離に変換します。
/// 揃った方向に変換できない場合は null を返します(TS の `ok: false` 相当)。
({Direction direction, int distance})? vectorToDirectionAndDistance(
    int x, int y) {
  if (x == 1 && y == -2) {
    return (direction: Direction.rightUpKnight, distance: 1);
  }
  if (x == -1 && y == -2) {
    return (direction: Direction.leftUpKnight, distance: 1);
  }
  if (x == 1 && y == 2) {
    return (direction: Direction.rightDownKnight, distance: 1);
  }
  if (x == -1 && y == 2) {
    return (direction: Direction.leftDownKnight, distance: 1);
  }
  if (x != 0 && y != 0 && x.abs() != y.abs()) {
    return null;
  }
  final int distance = (() {
    if (x != 0) return x.abs();
    if (y != 0) return y.abs();
    return 0;
  })();
  if (distance == 0) {
    return null;
  }
  final int dx = x == 0 ? 0 : x ~/ distance;
  final int dy = y == 0 ? 0 : y ~/ distance;
  if (dx == -1 && dy == -1) {
    return (direction: Direction.leftUp, distance: distance);
  }
  if (dx == 0 && dy == -1) {
    return (direction: Direction.up, distance: distance);
  }
  if (dx == 1 && dy == -1) {
    return (direction: Direction.rightUp, distance: distance);
  }
  if (dx == -1 && dy == 0) {
    return (direction: Direction.left, distance: distance);
  }
  if (dx == 1 && dy == 0) {
    return (direction: Direction.right, distance: distance);
  }
  if (dx == -1 && dy == 1) {
    return (direction: Direction.leftDown, distance: distance);
  }
  if (dx == 0 && dy == 1) {
    return (direction: Direction.down, distance: distance);
  }
  if (dx == 1 && dy == 1) {
    return (direction: Direction.rightDown, distance: distance);
  }
  return null;
}

enum VDirection {
  up('up'),
  none('none'),
  down('down');

  const VDirection(this.value);

  final String value;
}

/// 垂直方向の動きを取り出します。
VDirection directionToVDirection(Direction direction) {
  switch (direction) {
    case Direction.up:
    case Direction.leftUp:
    case Direction.rightUp:
    case Direction.leftUpKnight:
    case Direction.rightUpKnight:
      return VDirection.up;
    case Direction.down:
    case Direction.leftDown:
    case Direction.rightDown:
    case Direction.leftDownKnight:
    case Direction.rightDownKnight:
      return VDirection.down;
    case Direction.left:
    case Direction.right:
      return VDirection.none;
  }
}

enum HDirection {
  left('left'),
  none('none'),
  right('right');

  const HDirection(this.value);

  final String value;
}

/// 水平方向の動きを取り出します。
HDirection directionToHDirection(Direction direction) {
  switch (direction) {
    case Direction.left:
    case Direction.leftUp:
    case Direction.leftDown:
    case Direction.leftUpKnight:
    case Direction.leftDownKnight:
      return HDirection.left;
    case Direction.right:
    case Direction.rightUp:
    case Direction.rightDown:
    case Direction.rightUpKnight:
    case Direction.rightDownKnight:
      return HDirection.right;
    case Direction.up:
    case Direction.down:
      return HDirection.none;
  }
}
