import 'package:test/test.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/move.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/square.dart';

void main() {
  group('MoveOrigin', () {
    test('FromSquare equality / hashCode', () {
      final FromSquare a = FromSquare(Square(7, 7));
      final FromSquare b = FromSquare(Square(7, 7));
      final FromSquare c = FromSquare(Square(8, 7));
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == Object(), isFalse);
    });

    test('FromHand equality / hashCode', () {
      final FromHand a = const FromHand(PieceType.gold);
      final FromHand b = const FromHand(PieceType.gold);
      final FromHand c = const FromHand(PieceType.silver);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == Object(), isFalse);
    });

    test('FromSquare and FromHand do not equal each other', () {
      final FromSquare fs = FromSquare(Square(7, 7));
      final FromHand fh = const FromHand(PieceType.gold);
      expect(fs == fh, isFalse);
      expect(fh == fs, isFalse);
    });
  });

  group('Move', () {
    Move buildMove({
      MoveOrigin? from,
      Square? to,
      bool promote = false,
      Color color = Color.black,
      PieceType pieceType = PieceType.pawn,
      PieceType? capturedPieceType,
    }) {
      return Move(
        from ?? FromSquare(Square(7, 7)),
        to ?? Square(7, 6),
        promote,
        color,
        pieceType,
        capturedPieceType,
      );
    }

    test('equals / == compare every field', () {
      final Move a = buildMove();
      final Move b = buildMove();
      expect(a.equals(b), isTrue);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);

      expect(a.equals(buildMove(promote: true)), isFalse);
      expect(a.equals(buildMove(color: Color.white)), isFalse);
      expect(a.equals(buildMove(pieceType: PieceType.gold)), isFalse);
      expect(a.equals(buildMove(capturedPieceType: PieceType.pawn)), isFalse);
      expect(a.equals(buildMove(to: Square(7, 5))), isFalse);
      expect(a.equals(buildMove(from: FromSquare(Square(8, 7)))), isFalse);

      expect(a == Object(), isFalse);
    });

    test('equals(null) is false', () {
      expect(buildMove().equals(null), isFalse);
    });

    test('withPromote sets promote to true without touching other fields', () {
      final Move m = buildMove(promote: false);
      final Move p = m.withPromote();
      expect(p.promote, isTrue);
      expect(p.from, m.from);
      expect(p.to, m.to);
      expect(p.color, m.color);
      expect(p.pieceType, m.pieceType);
    });

    test('usi from FromSquare', () {
      final Move m = buildMove();
      expect(m.usi, '7g7f');
    });

    test('usi with promote', () {
      final Move m = buildMove(promote: true);
      expect(m.usi, '7g7f+');
    });

    test('usi from FromHand (drop)', () {
      final Move m = buildMove(
        from: const FromHand(PieceType.gold),
        to: Square(5, 5),
        pieceType: PieceType.gold,
      );
      expect(m.usi, 'G*5e');
    });
  });

  group('parseUSIMove', () {
    test('parses standard move', () {
      final ({MoveOrigin from, Square to, bool promote})? r =
          parseUSIMove('7g7f');
      expect(r, isNotNull);
      expect(r!.from, equals(FromSquare(Square(7, 7))));
      expect(r.to, equals(Square(7, 6)));
      expect(r.promote, isFalse);
    });

    test('parses move with promote', () {
      final r = parseUSIMove('2c2b+')!;
      expect(r.from, equals(FromSquare(Square(2, 3))));
      expect(r.to, equals(Square(2, 2)));
      expect(r.promote, isTrue);
    });

    test('parses drop (FromHand)', () {
      final r = parseUSIMove('G*5e')!;
      expect(r.from, equals(const FromHand(PieceType.gold)));
      expect(r.to, equals(Square(5, 5)));
      expect(r.promote, isFalse);
    });

    test('returns null on too-short input', () {
      expect(parseUSIMove(''), isNull);
      expect(parseUSIMove('7g'), isNull);
      expect(parseUSIMove('7g7'), isNull);
    });

    test('returns null on invalid drop piece', () {
      expect(parseUSIMove('Z*5e'), isNull);
    });

    test('returns null on invalid source square', () {
      expect(parseUSIMove('zz7f'), isNull);
    });

    test('returns null on invalid destination square', () {
      expect(parseUSIMove('7gzz'), isNull);
    });
  });

  group('SpecialMove', () {
    test('specialMove constructs PredefinedSpecialMove', () {
      final PredefinedSpecialMove m = specialMove(SpecialMoveType.resign);
      expect(m.type, SpecialMoveType.resign);
      expect(isKnownSpecialMove(m), isTrue);
    });

    test('anySpecialMove constructs AnySpecialMove', () {
      final AnySpecialMove m = anySpecialMove('カスタム終局');
      expect(m.name, 'カスタム終局');
      expect(isKnownSpecialMove(m), isFalse);
    });

    test('PredefinedSpecialMove equality / hashCode', () {
      const PredefinedSpecialMove a =
          PredefinedSpecialMove(SpecialMoveType.draw);
      const PredefinedSpecialMove b =
          PredefinedSpecialMove(SpecialMoveType.draw);
      const PredefinedSpecialMove c =
          PredefinedSpecialMove(SpecialMoveType.resign);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == Object(), isFalse);
    });

    test('AnySpecialMove equality / hashCode', () {
      const AnySpecialMove a = AnySpecialMove('反則勝ち');
      const AnySpecialMove b = AnySpecialMove('反則勝ち');
      const AnySpecialMove c = AnySpecialMove('反則負け');
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == Object(), isFalse);
    });

    test('isKnownSpecialMove distinguishes between subclasses', () {
      expect(isKnownSpecialMove(specialMove(SpecialMoveType.timeout)), isTrue);
      expect(isKnownSpecialMove(anySpecialMove('foo')), isFalse);
      expect(isKnownSpecialMove(Object()), isFalse);
    });

    test('areSameSpecialMoves matches by content (same subtype)', () {
      expect(
          areSameSpecialMoves(
            specialMove(SpecialMoveType.resign),
            specialMove(SpecialMoveType.resign),
          ),
          isTrue);
      expect(
          areSameSpecialMoves(
            anySpecialMove('foo'),
            anySpecialMove('foo'),
          ),
          isTrue);
    });

    test('areSameSpecialMoves: different content returns false', () {
      expect(
          areSameSpecialMoves(
            specialMove(SpecialMoveType.resign),
            specialMove(SpecialMoveType.draw),
          ),
          isFalse);
      expect(
          areSameSpecialMoves(
            anySpecialMove('foo'),
            anySpecialMove('bar'),
          ),
          isFalse);
    });

    test('areSameSpecialMoves: cross subtype returns false', () {
      expect(
          areSameSpecialMoves(
            specialMove(SpecialMoveType.resign),
            anySpecialMove('resign'),
          ),
          isFalse);
    });
  });

  group('areSameMoves', () {
    final Move move1 = Move(
      FromSquare(Square(7, 7)),
      Square(7, 6),
      false,
      Color.black,
      PieceType.pawn,
      null,
    );
    final Move move1Dup = Move(
      FromSquare(Square(7, 7)),
      Square(7, 6),
      false,
      Color.black,
      PieceType.pawn,
      null,
    );
    final Move move2 = Move(
      FromSquare(Square(8, 7)),
      Square(8, 6),
      false,
      Color.black,
      PieceType.pawn,
      null,
    );

    test('Move + Move: equal contents match', () {
      expect(areSameMoves(move1, move1Dup), isTrue);
    });

    test('Move + Move: different contents do not match', () {
      expect(areSameMoves(move1, move2), isFalse);
    });

    test('Move + SpecialMove: returns false', () {
      expect(areSameMoves(move1, specialMove(SpecialMoveType.resign)), isFalse);
      expect(areSameMoves(specialMove(SpecialMoveType.resign), move1), isFalse);
    });

    test('SpecialMove + SpecialMove: delegates to areSameSpecialMoves', () {
      expect(
          areSameMoves(
            specialMove(SpecialMoveType.resign),
            specialMove(SpecialMoveType.resign),
          ),
          isTrue);
      expect(
          areSameMoves(
            specialMove(SpecialMoveType.resign),
            specialMove(SpecialMoveType.draw),
          ),
          isFalse);
    });

    test('non-move/special arguments return false', () {
      expect(areSameMoves(Object(), Object()), isFalse);
      expect(areSameMoves(Object(), move1), isFalse);
    });
  });

  group('SpecialMoveType', () {
    test('all 16 enum values have unique .value strings', () {
      final Set<String> values =
          SpecialMoveType.values.map((SpecialMoveType v) => v.value).toSet();
      expect(values.length, SpecialMoveType.values.length);
    });

    test('try_ keeps wire-format "try"', () {
      expect(SpecialMoveType.try_.value, 'try');
    });
  });
}
