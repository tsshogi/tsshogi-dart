import 'package:test/test.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/square.dart';

/// 駒を 1 つだけ置いた最小 Position を作る。
Position _positionWithPiece(int file, int rank, Color color, PieceType type) {
  final Position p = Position();
  p.reset(InitialPositionType.empty);
  p.board.set(Square(file, rank), Piece(color, type));
  return p;
}

/// 完全に空 (玉も置かない) の Position。
Position _emptyPosition() {
  final Position p = Position();
  p.reset(InitialPositionType.empty);
  return p;
}

void main() {
  // ---------------------------------------------------------------------------
  // PiecePlacement — refactor 後も既存の振る舞いを維持
  // ---------------------------------------------------------------------------
  group('PiecePlacement (post-refactor)', () {
    test('matches when piece is exactly at the square', () {
      const PiecePlacement req = PiecePlacement(8, 8, PieceType.king);
      final Position p = _positionWithPiece(8, 8, Color.black, PieceType.king);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
    });

    test('does not match when square is empty', () {
      const PiecePlacement req = PiecePlacement(8, 8, PieceType.king);
      expect(req.isSatisfiedBy(_emptyPosition(), Color.black), isFalse);
    });

    test('does not match when piece is wrong type', () {
      const PiecePlacement req = PiecePlacement(8, 8, PieceType.king);
      final Position p = _positionWithPiece(8, 8, Color.black, PieceType.gold);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('does not match when piece is opponent color', () {
      const PiecePlacement req = PiecePlacement(8, 8, PieceType.king);
      final Position p = _positionWithPiece(8, 8, Color.white, PieceType.king);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('white side: mirrors file/rank (10-f, 10-r)', () {
      const PiecePlacement req = PiecePlacement(8, 8, PieceType.king);
      // 白側で 8八は 10-8=2, 10-8=2 → 2二
      final Position p = _positionWithPiece(2, 2, Color.white, PieceType.king);
      expect(req.isSatisfiedBy(p, Color.white), isTrue);
      // 8八に黒玉を置いてもマッチしない (白から見て 8八は 2二ではないから)
      final Position p2 = _positionWithPiece(8, 8, Color.black, PieceType.king);
      expect(req.isSatisfiedBy(p2, Color.white), isFalse);
    });

    test('equality / hashCode', () {
      const PiecePlacement a = PiecePlacement(8, 8, PieceType.king);
      const PiecePlacement b = PiecePlacement(8, 8, PieceType.king);
      const PiecePlacement c = PiecePlacement(8, 9, PieceType.king);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // EmptySquare
  // ---------------------------------------------------------------------------
  group('EmptySquare', () {
    test('matches when square is empty', () {
      const EmptySquare req = EmptySquare(5, 5);
      expect(req.isSatisfiedBy(_emptyPosition(), Color.black), isTrue);
    });

    test('does NOT match when side has a piece at the square', () {
      const EmptySquare req = EmptySquare(5, 5);
      final Position p = _positionWithPiece(5, 5, Color.black, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('does NOT match even when opponent has a piece at the square', () {
      // "fully empty" semantics: 相手駒があってもダメ。
      const EmptySquare req = EmptySquare(5, 5);
      final Position p = _positionWithPiece(5, 5, Color.white, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('white side mirror', () {
      const EmptySquare req = EmptySquare(8, 8);
      // 白側で 8八 → 2二。2二に駒があれば失敗。
      final Position p = _positionWithPiece(2, 2, Color.white, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.white), isFalse);
      // 2二が空ならOK (玉位置等は気にしない)
      final Position p2 = _emptyPosition();
      p2.board.set(Square(8, 8), Piece(Color.black, PieceType.king));
      expect(req.isSatisfiedBy(p2, Color.white), isTrue);
    });

    test('equality / hashCode', () {
      const EmptySquare a = EmptySquare(5, 5);
      const EmptySquare b = EmptySquare(5, 5);
      const EmptySquare c = EmptySquare(5, 6);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // NotOfPieces
  // ---------------------------------------------------------------------------
  group('NotOfPieces', () {
    test('matches when square is empty', () {
      const NotOfPieces req =
          NotOfPieces(6, 7, <PieceType>[PieceType.gold, PieceType.silver]);
      expect(req.isSatisfiedBy(_emptyPosition(), Color.black), isTrue);
    });

    test('matches when side has a piece NOT in excluded list', () {
      const NotOfPieces req =
          NotOfPieces(6, 7, <PieceType>[PieceType.gold, PieceType.silver]);
      final Position p = _positionWithPiece(6, 7, Color.black, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
    });

    test('does NOT match when side has an excluded piece', () {
      const NotOfPieces req =
          NotOfPieces(6, 7, <PieceType>[PieceType.gold, PieceType.silver]);
      final Position p = _positionWithPiece(6, 7, Color.black, PieceType.gold);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
      final Position p2 =
          _positionWithPiece(6, 7, Color.black, PieceType.silver);
      expect(req.isSatisfiedBy(p2, Color.black), isFalse);
    });

    test('matches when opponent has an excluded-type piece (not blocked)', () {
      // 相手駒は side の駒ではないので除外対象にならない。
      const NotOfPieces req = NotOfPieces(6, 7, <PieceType>[PieceType.gold]);
      final Position p = _positionWithPiece(6, 7, Color.white, PieceType.gold);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
    });

    test('white side mirror', () {
      const NotOfPieces req = NotOfPieces(6, 7, <PieceType>[PieceType.gold]);
      // 白側 6七 → 4三
      final Position p = _positionWithPiece(4, 3, Color.white, PieceType.gold);
      expect(req.isSatisfiedBy(p, Color.white), isFalse);
      final Position p2 =
          _positionWithPiece(4, 3, Color.white, PieceType.silver);
      expect(req.isSatisfiedBy(p2, Color.white), isTrue);
    });

    test('equality / hashCode', () {
      const NotOfPieces a =
          NotOfPieces(6, 7, <PieceType>[PieceType.gold, PieceType.silver]);
      const NotOfPieces b =
          NotOfPieces(6, 7, <PieceType>[PieceType.gold, PieceType.silver]);
      const NotOfPieces c =
          NotOfPieces(6, 7, <PieceType>[PieceType.silver, PieceType.gold]);
      const NotOfPieces d = NotOfPieces(6, 7, <PieceType>[PieceType.gold]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c))); // 順序保持
      expect(a, isNot(equals(d)));
    });
  });

  // ---------------------------------------------------------------------------
  // AnyPiece
  // ---------------------------------------------------------------------------
  group('AnyPiece', () {
    test('matches when side has any piece at the square', () {
      const AnyPiece req = AnyPiece(8, 8);
      final Position p = _positionWithPiece(8, 8, Color.black, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
      final Position p2 = _positionWithPiece(8, 8, Color.black, PieceType.king);
      expect(req.isSatisfiedBy(p2, Color.black), isTrue);
    });

    test('does NOT match when square is empty', () {
      const AnyPiece req = AnyPiece(8, 8);
      expect(req.isSatisfiedBy(_emptyPosition(), Color.black), isFalse);
    });

    test('does NOT match when only opponent has a piece', () {
      const AnyPiece req = AnyPiece(8, 8);
      final Position p = _positionWithPiece(8, 8, Color.white, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('white side mirror', () {
      const AnyPiece req = AnyPiece(8, 8);
      final Position p = _positionWithPiece(2, 2, Color.white, PieceType.pawn);
      expect(req.isSatisfiedBy(p, Color.white), isTrue);
      // 黒視点の 8八 (= 白視点の 2二) を白駒で塞いでも、白の 8八は空のままなので false ではなくて
      // 上の p で 2二 に白駒を置いているのでマッチ。逆ケースを確認:
      final Position p2 = _positionWithPiece(8, 8, Color.white, PieceType.pawn);
      expect(req.isSatisfiedBy(p2, Color.white), isFalse);
    });

    test('equality / hashCode', () {
      const AnyPiece a = AnyPiece(8, 8);
      const AnyPiece b = AnyPiece(8, 8);
      const AnyPiece c = AnyPiece(8, 9);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // PieceAnywhere (position-wide; no rotation)
  // ---------------------------------------------------------------------------
  group('PieceAnywhere', () {
    test('matches when side has the piece type somewhere on the board', () {
      const PieceAnywhere req = PieceAnywhere(PieceType.bishop);
      final Position p =
          _positionWithPiece(8, 8, Color.black, PieceType.bishop);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
      final Position p2 =
          _positionWithPiece(1, 1, Color.black, PieceType.bishop);
      expect(req.isSatisfiedBy(p2, Color.black), isTrue);
    });

    test('does NOT match when side has no piece of that type', () {
      const PieceAnywhere req = PieceAnywhere(PieceType.bishop);
      final Position p = _positionWithPiece(8, 8, Color.black, PieceType.rook);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
      expect(req.isSatisfiedBy(_emptyPosition(), Color.black), isFalse);
    });

    test('does NOT match when only opponent has that piece type', () {
      const PieceAnywhere req = PieceAnywhere(PieceType.bishop);
      final Position p =
          _positionWithPiece(8, 8, Color.white, PieceType.bishop);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('white side: piece anywhere on the board, no rotation needed', () {
      const PieceAnywhere req = PieceAnywhere(PieceType.bishop);
      final Position p =
          _positionWithPiece(2, 2, Color.white, PieceType.bishop);
      expect(req.isSatisfiedBy(p, Color.white), isTrue);
      final Position p2 =
          _positionWithPiece(9, 9, Color.white, PieceType.bishop);
      expect(req.isSatisfiedBy(p2, Color.white), isTrue);
    });

    test('equality / hashCode', () {
      const PieceAnywhere a = PieceAnywhere(PieceType.bishop);
      const PieceAnywhere b = PieceAnywhere(PieceType.bishop);
      const PieceAnywhere c = PieceAnywhere(PieceType.rook);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // HandPiece (position-wide hand; no rotation)
  // ---------------------------------------------------------------------------
  group('HandPiece', () {
    test('matches when hand has 1 piece (default minCount)', () {
      const HandPiece req = HandPiece(PieceType.bishop);
      final Position p = _emptyPosition();
      p.blackHand.set(PieceType.bishop, 1);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
    });

    test('matches when hand has more than minCount', () {
      const HandPiece req = HandPiece(PieceType.pawn, 3);
      final Position p = _emptyPosition();
      p.blackHand.set(PieceType.pawn, 5);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
    });

    test('matches when hand has exactly minCount', () {
      const HandPiece req = HandPiece(PieceType.pawn, 3);
      final Position p = _emptyPosition();
      p.blackHand.set(PieceType.pawn, 3);
      expect(req.isSatisfiedBy(p, Color.black), isTrue);
    });

    test('does NOT match when hand is short of minCount', () {
      const HandPiece req = HandPiece(PieceType.pawn, 3);
      final Position p = _emptyPosition();
      p.blackHand.set(PieceType.pawn, 2);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('does NOT match when hand is empty', () {
      const HandPiece req = HandPiece(PieceType.bishop);
      expect(req.isSatisfiedBy(_emptyPosition(), Color.black), isFalse);
    });

    test('does NOT match when only opponent hand has the piece', () {
      const HandPiece req = HandPiece(PieceType.bishop);
      final Position p = _emptyPosition();
      p.whiteHand.set(PieceType.bishop, 1);
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('white side: checks white hand', () {
      const HandPiece req = HandPiece(PieceType.bishop);
      final Position p = _emptyPosition();
      p.whiteHand.set(PieceType.bishop, 1);
      expect(req.isSatisfiedBy(p, Color.white), isTrue);
    });

    test('equality / hashCode', () {
      const HandPiece a = HandPiece(PieceType.bishop);
      const HandPiece b = HandPiece(PieceType.bishop);
      const HandPiece c = HandPiece(PieceType.bishop, 2);
      const HandPiece d = HandPiece(PieceType.rook);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });

  // ---------------------------------------------------------------------------
  // Composite check via CastleTemplate
  // ---------------------------------------------------------------------------
  group('CastleTemplate with mixed requirements', () {
    test('PiecePlacement + PieceAnywhere + HandPiece all combine via AND', () {
      const CastleTemplate t = CastleTemplate(
        name: 'mix',
        placements: <CastleRequirement>[
          PiecePlacement(5, 9, PieceType.king),
          PieceAnywhere(PieceType.bishop),
          HandPiece(PieceType.gold, 2),
        ],
      );

      final Position p = _emptyPosition();
      p.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      p.board.set(Square(1, 1), Piece(Color.black, PieceType.bishop));
      p.blackHand.set(PieceType.gold, 2);

      for (final CastleRequirement r in t.placements) {
        expect(r.isSatisfiedBy(p, Color.black), isTrue, reason: '$r');
      }

      // Take 1 gold away → HandPiece fails
      p.blackHand.set(PieceType.gold, 1);
      expect(
        t.placements.every(
          (CastleRequirement r) => r.isSatisfiedBy(p, Color.black),
        ),
        isFalse,
      );
    });
  });
}
