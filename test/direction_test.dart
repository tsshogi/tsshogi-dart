import 'package:test/test.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/direction.dart';
import 'package:tsshogi/src/piece.dart';

void main() {
  group('Direction enum', () {
    test('all 12 directions exist', () {
      expect(Direction.values.length, 12);
      expect(directions.length, 12);
    });

    test('value strings are unique', () {
      final Set<String> set =
          Direction.values.map((Direction d) => d.value).toSet();
      expect(set.length, 12);
    });
  });

  group('reverseDirection', () {
    test('orthogonal pairs', () {
      expect(reverseDirection(Direction.up), Direction.down);
      expect(reverseDirection(Direction.down), Direction.up);
      expect(reverseDirection(Direction.left), Direction.right);
      expect(reverseDirection(Direction.right), Direction.left);
    });

    test('diagonal pairs', () {
      expect(reverseDirection(Direction.leftUp), Direction.rightDown);
      expect(reverseDirection(Direction.rightUp), Direction.leftDown);
      expect(reverseDirection(Direction.leftDown), Direction.rightUp);
      expect(reverseDirection(Direction.rightDown), Direction.leftUp);
    });

    test('knight pairs', () {
      expect(
          reverseDirection(Direction.leftUpKnight), Direction.rightDownKnight);
      expect(
          reverseDirection(Direction.rightUpKnight), Direction.leftDownKnight);
      expect(
          reverseDirection(Direction.leftDownKnight), Direction.rightUpKnight);
      expect(
          reverseDirection(Direction.rightDownKnight), Direction.leftUpKnight);
    });
  });

  group('movableDirections / resolveMoveType', () {
    test('black pawn moves only up', () {
      final Piece p = Piece(Color.black, PieceType.pawn);
      final List<Direction> ds = movableDirections(p);
      expect(ds, equals(<Direction>[Direction.up]));
      expect(resolveMoveType(p, Direction.up), MoveType.short);
      expect(resolveMoveType(p, Direction.down), isNull);
    });

    test('white pawn moves only down', () {
      final Piece p = Piece(Color.white, PieceType.pawn);
      final List<Direction> ds = movableDirections(p);
      expect(ds, equals(<Direction>[Direction.down]));
      expect(resolveMoveType(p, Direction.down), MoveType.short);
      expect(resolveMoveType(p, Direction.up), isNull);
    });

    test('lance is LONG up (black) / down (white)', () {
      expect(
        resolveMoveType(Piece(Color.black, PieceType.lance), Direction.up),
        MoveType.long,
      );
      expect(
        resolveMoveType(Piece(Color.white, PieceType.lance), Direction.down),
        MoveType.long,
      );
    });

    test('knight has 2 SHORT directions on black side', () {
      final Piece p = Piece(Color.black, PieceType.knight);
      final List<Direction> ds = movableDirections(p);
      expect(ds, contains(Direction.leftUpKnight));
      expect(ds, contains(Direction.rightUpKnight));
      expect(ds.length, 2);
    });

    test('rook is LONG in 4 orthogonal directions', () {
      final Piece p = Piece(Color.black, PieceType.rook);
      for (final Direction d in <Direction>[
        Direction.up,
        Direction.down,
        Direction.left,
        Direction.right,
      ]) {
        expect(resolveMoveType(p, d), MoveType.long);
      }
      expect(resolveMoveType(p, Direction.leftUp), isNull);
    });

    test('bishop is LONG in 4 diagonal directions', () {
      final Piece p = Piece(Color.black, PieceType.bishop);
      for (final Direction d in <Direction>[
        Direction.leftUp,
        Direction.rightUp,
        Direction.leftDown,
        Direction.rightDown,
      ]) {
        expect(resolveMoveType(p, d), MoveType.long);
      }
      expect(resolveMoveType(p, Direction.up), isNull);
    });

    test('king moves SHORT in 8 directions', () {
      final Piece p = Piece(Color.black, PieceType.king);
      final List<Direction> ds = movableDirections(p);
      expect(ds.length, 8);
      expect(ds, contains(Direction.up));
      expect(ds, contains(Direction.leftUp));
      expect(ds, isNot(contains(Direction.leftUpKnight)));
    });

    test('horse (promoted bishop) adds 4 orthogonal SHORT moves', () {
      final Piece p = Piece(Color.black, PieceType.horse);
      final List<Direction> ds = movableDirections(p);
      expect(ds.length, 8);
      // 4 diagonals LONG
      expect(resolveMoveType(p, Direction.leftUp), MoveType.long);
      // 4 orthogonals SHORT
      expect(resolveMoveType(p, Direction.up), MoveType.short);
    });

    test('dragon (promoted rook) adds 4 diagonal SHORT moves', () {
      final Piece p = Piece(Color.black, PieceType.dragon);
      final List<Direction> ds = movableDirections(p);
      expect(ds.length, 8);
      expect(resolveMoveType(p, Direction.up), MoveType.long);
      expect(resolveMoveType(p, Direction.leftUp), MoveType.short);
    });

    test('promoted pawn/lance/knight/silver move like gold', () {
      for (final PieceType pt in <PieceType>[
        PieceType.promPawn,
        PieceType.promLance,
        PieceType.promKnight,
        PieceType.promSilver,
      ]) {
        final Piece p = Piece(Color.black, pt);
        final List<Direction> ds = movableDirections(p);
        // gold-like: 6 directions
        expect(ds.length, 6, reason: pt.value);
        expect(ds, contains(Direction.up));
        expect(ds, contains(Direction.leftUp));
        expect(ds, contains(Direction.rightUp));
        expect(ds, contains(Direction.left));
        expect(ds, contains(Direction.right));
        expect(ds, contains(Direction.down));
      }
    });
  });

  group('directionToDeltaMap', () {
    test('orthogonal deltas', () {
      expect(directionToDeltaMap[Direction.up]!.y, -1);
      expect(directionToDeltaMap[Direction.down]!.y, 1);
      expect(directionToDeltaMap[Direction.left]!.x, -1);
      expect(directionToDeltaMap[Direction.right]!.x, 1);
    });

    test('knight deltas have y == ±2', () {
      expect(directionToDeltaMap[Direction.leftUpKnight]!.y, -2);
      expect(directionToDeltaMap[Direction.rightDownKnight]!.y, 2);
    });
  });

  group('vectorToDirectionAndDistance', () {
    test('orthogonal up at distance 3', () {
      final r = vectorToDirectionAndDistance(0, -3)!;
      expect(r.direction, Direction.up);
      expect(r.distance, 3);
    });

    test('orthogonal down at distance 1', () {
      final r = vectorToDirectionAndDistance(0, 1)!;
      expect(r.direction, Direction.down);
      expect(r.distance, 1);
    });

    test('orthogonal left / right', () {
      expect(vectorToDirectionAndDistance(-2, 0)!.direction, Direction.left);
      expect(vectorToDirectionAndDistance(5, 0)!.direction, Direction.right);
    });

    test('diagonal at distance 4', () {
      final r = vectorToDirectionAndDistance(4, -4)!;
      expect(r.direction, Direction.rightUp);
      expect(r.distance, 4);
    });

    test('all four diagonals', () {
      expect(vectorToDirectionAndDistance(-1, -1)!.direction, Direction.leftUp);
      expect(vectorToDirectionAndDistance(1, -1)!.direction, Direction.rightUp);
      expect(
          vectorToDirectionAndDistance(-1, 1)!.direction, Direction.leftDown);
      expect(
          vectorToDirectionAndDistance(1, 1)!.direction, Direction.rightDown);
    });

    test('all four knight directions', () {
      expect(vectorToDirectionAndDistance(-1, -2)!.direction,
          Direction.leftUpKnight);
      expect(vectorToDirectionAndDistance(1, -2)!.direction,
          Direction.rightUpKnight);
      expect(vectorToDirectionAndDistance(-1, 2)!.direction,
          Direction.leftDownKnight);
      expect(vectorToDirectionAndDistance(1, 2)!.direction,
          Direction.rightDownKnight);
    });

    test('(0, 0) returns null', () {
      expect(vectorToDirectionAndDistance(0, 0), isNull);
    });

    test('non-aligned vector returns null', () {
      // |x| != |y| かつ どちらも 0 でない → null
      expect(vectorToDirectionAndDistance(2, 3), isNull);
      expect(vectorToDirectionAndDistance(3, 1), isNull);
    });
  });

  group('VDirection / HDirection projection', () {
    test('directionToVDirection: up family → up', () {
      expect(directionToVDirection(Direction.up), VDirection.up);
      expect(directionToVDirection(Direction.leftUp), VDirection.up);
      expect(directionToVDirection(Direction.rightUp), VDirection.up);
      expect(directionToVDirection(Direction.leftUpKnight), VDirection.up);
      expect(directionToVDirection(Direction.rightUpKnight), VDirection.up);
    });

    test('directionToVDirection: down family → down', () {
      expect(directionToVDirection(Direction.down), VDirection.down);
      expect(directionToVDirection(Direction.leftDown), VDirection.down);
      expect(directionToVDirection(Direction.rightDown), VDirection.down);
      expect(directionToVDirection(Direction.leftDownKnight), VDirection.down);
      expect(directionToVDirection(Direction.rightDownKnight), VDirection.down);
    });

    test('directionToVDirection: left / right → none', () {
      expect(directionToVDirection(Direction.left), VDirection.none);
      expect(directionToVDirection(Direction.right), VDirection.none);
    });

    test('directionToHDirection: left family → left', () {
      expect(directionToHDirection(Direction.left), HDirection.left);
      expect(directionToHDirection(Direction.leftUp), HDirection.left);
      expect(directionToHDirection(Direction.leftDown), HDirection.left);
      expect(directionToHDirection(Direction.leftUpKnight), HDirection.left);
      expect(directionToHDirection(Direction.leftDownKnight), HDirection.left);
    });

    test('directionToHDirection: right family → right', () {
      expect(directionToHDirection(Direction.right), HDirection.right);
      expect(directionToHDirection(Direction.rightUp), HDirection.right);
      expect(directionToHDirection(Direction.rightDown), HDirection.right);
      expect(directionToHDirection(Direction.rightUpKnight), HDirection.right);
      expect(
          directionToHDirection(Direction.rightDownKnight), HDirection.right);
    });

    test('directionToHDirection: up / down → none', () {
      expect(directionToHDirection(Direction.up), HDirection.none);
      expect(directionToHDirection(Direction.down), HDirection.none);
    });
  });
}
