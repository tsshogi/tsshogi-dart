import 'package:test/test.dart';
import 'package:tsshogi/src/errors.dart';

void main() {
  group('errors', () {
    test('InvalidPieceNameError', () {
      final InvalidPieceNameError e = InvalidPieceNameError('XX');
      expect(e.data, 'XX');
      expect(e.toString(), 'Invalid piece name: XX');
      expect(e, isA<Exception>());
    });

    test('InvalidTurnError', () {
      final InvalidTurnError e = InvalidTurnError('?');
      expect(e.data, '?');
      expect(e.toString(), 'Invalid turn: ?');
      expect(e, isA<Exception>());
    });

    test('InvalidMoveError', () {
      final InvalidMoveError e = InvalidMoveError('7x7g');
      expect(e.data, '7x7g');
      expect(e.toString(), 'Invalid move: 7x7g');
      expect(e, isA<Exception>());
    });

    test('InvalidMoveNumberError', () {
      final InvalidMoveNumberError e = InvalidMoveNumberError('abc');
      expect(e.data, 'abc');
      expect(e.toString(), 'Invalid move number: abc');
      expect(e, isA<Exception>());
    });

    test('InvalidDestinationError', () {
      final InvalidDestinationError e = InvalidDestinationError('zz');
      expect(e.data, 'zz');
      expect(e.toString(), 'Invalid destination: zz');
      expect(e, isA<Exception>());
    });

    test('PieceNotExistsError', () {
      final PieceNotExistsError e = PieceNotExistsError('7g');
      expect(e.data, '7g');
      expect(e.toString(), 'Piece not exists: 7g');
      expect(e, isA<Exception>());
    });

    test('InvalidLineError', () {
      final InvalidLineError e = InvalidLineError('garbage');
      expect(e.data, 'garbage');
      expect(e.toString(), 'Invalid line: garbage');
      expect(e, isA<Exception>());
    });

    test('InvalidHandicapError (deprecated)', () {
      // ignore: deprecated_member_use_from_same_package
      final InvalidHandicapError e = InvalidHandicapError('???');
      expect(e.data, '???');
      expect(e.toString(), 'Invalid handicap: ???');
      expect(e, isA<Exception>());
    });

    test('InvalidBoardError', () {
      final InvalidBoardError e = InvalidBoardError('row5');
      expect(e.data, 'row5');
      expect(e.toString(), 'Invalid board: row5');
      expect(e, isA<Exception>());
    });

    test('InvalidHandPieceError', () {
      final InvalidHandPieceError e = InvalidHandPieceError('Z');
      expect(e.data, 'Z');
      expect(e.toString(), 'Invalid hand piece: Z');
      expect(e, isA<Exception>());
    });

    test('InvalidUSIError', () {
      final InvalidUSIError e = InvalidUSIError('not-usi');
      expect(e.data, 'not-usi');
      expect(e.toString(), 'Invalid USI: not-usi');
      expect(e, isA<Exception>());
    });

    test('errors can be thrown and caught by their concrete type', () {
      InvalidUSIError? caught;
      try {
        throw InvalidUSIError('bad');
      } on InvalidUSIError catch (e) {
        caught = e;
      }
      expect(caught, isA<InvalidUSIError>());
      expect(caught.data, 'bad');
    });

    test('different error types do not equal each other', () {
      // Default identity equality is fine; just verify constructor types stay
      // distinct.
      expect(InvalidUSIError('a'), isNot(equals(InvalidMoveError('a'))));
    });
  });
}
