import 'package:test/test.dart';
import 'package:tsshogi/src/square.dart';

void main() {
  group('square', () {
    test('getters', () {
      final square = Square(3, 8);
      expect(square.file, 3);
      expect(square.rank, 8);
      expect(square.x, 6);
      expect(square.y, 7);
      expect(square.index, 69);
      expect(square.valid, isTrue);
    });

    test('border', () {
      expect(Square(1, 4).valid, isTrue);
      expect(Square(0, 4).valid, isFalse);

      expect(Square(9, 4).valid, isTrue);
      expect(Square(10, 4).valid, isFalse);

      expect(Square(4, 1).valid, isTrue);
      expect(Square(4, 0).valid, isFalse);

      expect(Square(4, 9).valid, isTrue);
      expect(Square(4, 10).valid, isFalse);
    });

    test('neighbor', () {
      final square = Square(2, 7);
      expect(square.neighbor(1, 2), equals(Square(1, 9)));
      expect(square.neighbor(-3, -5), equals(Square(5, 2)));
    });

    test('comparison', () {
      final square = Square(2, 7);
      expect(square.equals(square), isTrue);
      expect(square.equals(Square(2, 7)), isTrue);
      expect(square.equals(Square(3, 7)), isFalse);
      expect(square.equals(Square(2, 6)), isFalse);
    });

    test('sfen', () {
      expect(Square(1, 6).usi, '1f');
      expect(Square(2, 7).usi, '2g');
      expect(Square(3, 8).usi, '3h');
      expect(Square(4, 9).usi, '4i');
      expect(Square(5, 1).usi, '5a');
      expect(Square(6, 2).usi, '6b');
      expect(Square(7, 3).usi, '7c');
      expect(Square(8, 4).usi, '8d');
      expect(Square(9, 5).usi, '9e');

      expect(Square.newByUSI('1e'), equals(Square(1, 5)));
      expect(Square.newByUSI('2f'), equals(Square(2, 6)));
      expect(Square.newByUSI('3g'), equals(Square(3, 7)));
      expect(Square.newByUSI('4h'), equals(Square(4, 8)));
      expect(Square.newByUSI('5i'), equals(Square(5, 9)));
      expect(Square.newByUSI('6a'), equals(Square(6, 1)));
      expect(Square.newByUSI('7b'), equals(Square(7, 2)));
      expect(Square.newByUSI('8c'), equals(Square(8, 3)));
      expect(Square.newByUSI('9d'), equals(Square(9, 4)));

      // sfen is deprecated
      // ignore: deprecated_member_use_from_same_package
      expect(Square(1, 6).sfen, '1f');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(2, 7).sfen, '2g');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(3, 8).sfen, '3h');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(4, 9).sfen, '4i');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(5, 1).sfen, '5a');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(6, 2).sfen, '6b');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(7, 3).sfen, '7c');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(8, 4).sfen, '8d');
      // ignore: deprecated_member_use_from_same_package
      expect(Square(9, 5).sfen, '9e');

      // parseSFENSquare is deprecated
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('1e'), equals(Square(1, 5)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('2f'), equals(Square(2, 6)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('3g'), equals(Square(3, 7)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('4h'), equals(Square(4, 8)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('5i'), equals(Square(5, 9)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('6a'), equals(Square(6, 1)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('7b'), equals(Square(7, 2)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('8c'), equals(Square(8, 3)));
      // ignore: deprecated_member_use_from_same_package
      expect(Square.parseSFENSquare('9d'), equals(Square(9, 4)));
    });

    test('builder', () {
      expect(Square.newByXY(3, 4), equals(Square(6, 5)));
      expect(Square.newByIndex(67), equals(Square(5, 8)));
    });

    test('static', () {
      expect(Square.all, hasLength(81));
      expect(Square.all[0], equals(Square(9, 1)));
      expect(Square.all[8], equals(Square(1, 1)));
      expect(Square.all[9], equals(Square(9, 2)));
      expect(Square.all[80], equals(Square(1, 9)));
    });
  });
}
