import 'package:test/test.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';

void main() {
  group('piece', () {
    test('PieceType', () {
      expect(standardPieceName(PieceType.pawn), '歩');
      expect(standardPieceName(PieceType.lance), '香');
      expect(standardPieceName(PieceType.knight), '桂');
      expect(standardPieceName(PieceType.silver), '銀');
      expect(standardPieceName(PieceType.gold), '金');
      expect(standardPieceName(PieceType.bishop), '角');
      expect(standardPieceName(PieceType.rook), '飛');
      expect(standardPieceName(PieceType.king), '玉');
      expect(standardPieceName(PieceType.promPawn), 'と');
      expect(standardPieceName(PieceType.promLance), '成香');
      expect(standardPieceName(PieceType.promKnight), '成桂');
      expect(standardPieceName(PieceType.promSilver), '成銀');
      expect(standardPieceName(PieceType.horse), '馬');
      expect(standardPieceName(PieceType.dragon), '竜');

      expect(pieceTypeToSFEN(PieceType.pawn), 'P');
      expect(pieceTypeToSFEN(PieceType.lance), 'L');
      expect(pieceTypeToSFEN(PieceType.knight), 'N');
      expect(pieceTypeToSFEN(PieceType.silver), 'S');
      expect(pieceTypeToSFEN(PieceType.gold), 'G');
      expect(pieceTypeToSFEN(PieceType.bishop), 'B');
      expect(pieceTypeToSFEN(PieceType.rook), 'R');
      expect(pieceTypeToSFEN(PieceType.king), 'K');
      expect(pieceTypeToSFEN(PieceType.promPawn), '+P');
      expect(pieceTypeToSFEN(PieceType.promLance), '+L');
      expect(pieceTypeToSFEN(PieceType.promKnight), '+N');
      expect(pieceTypeToSFEN(PieceType.promSilver), '+S');
      expect(pieceTypeToSFEN(PieceType.horse), '+B');
      expect(pieceTypeToSFEN(PieceType.dragon), '+R');
    });

    test('getters', () {
      final blackKnight = Piece(Color.black, PieceType.knight);
      expect(blackKnight.id, 'black_knight');
      expect(blackKnight.sfen, 'N');

      final whiteHorse = Piece(Color.white, PieceType.horse);
      expect(whiteHorse.id, 'white_horse');
      expect(whiteHorse.sfen, '+b');
    });

    test('color', () {
      final blackKnight = Piece(Color.black, PieceType.knight);
      expect(blackKnight.black(), equals(Piece(Color.black, PieceType.knight)));
      expect(blackKnight.white(), equals(Piece(Color.white, PieceType.knight)));

      final whiteSilver = Piece(Color.white, PieceType.silver);
      expect(whiteSilver.black(), equals(Piece(Color.black, PieceType.silver)));
      expect(whiteSilver.white(), equals(Piece(Color.white, PieceType.silver)));
    });

    test('comparison', () {
      final whiteGold = Piece(Color.white, PieceType.gold);
      expect(whiteGold.equals(Piece(Color.white, PieceType.gold)), isTrue);
      expect(whiteGold.equals(Piece(Color.black, PieceType.gold)), isFalse);
      expect(whiteGold.equals(Piece(Color.white, PieceType.bishop)), isFalse);
    });

    test('promotion', () {
      expect(
        Piece(Color.black, PieceType.lance).promoted(),
        equals(Piece(Color.black, PieceType.promLance)),
      );
      expect(
        Piece(Color.white, PieceType.bishop).promoted(),
        equals(Piece(Color.white, PieceType.horse)),
      );
      expect(
        Piece(Color.white, PieceType.horse).promoted(),
        equals(Piece(Color.white, PieceType.horse)),
      );
      expect(
        Piece(Color.black, PieceType.gold).promoted(),
        equals(Piece(Color.black, PieceType.gold)),
      );

      expect(
        Piece(Color.white, PieceType.bishop).unpromoted(),
        equals(Piece(Color.white, PieceType.bishop)),
      );
      expect(
        Piece(Color.white, PieceType.horse).unpromoted(),
        equals(Piece(Color.white, PieceType.bishop)),
      );

      expect(Piece(Color.white, PieceType.bishop).isPromotable(), isTrue);
      expect(Piece(Color.white, PieceType.horse).isPromotable(), isFalse);
      expect(Piece(Color.white, PieceType.gold).isPromotable(), isFalse);
      expect(Piece(Color.white, PieceType.king).isPromotable(), isFalse);
    });

    test('rotation', () {
      var piece = Piece(Color.black, PieceType.pawn);
      piece = piece.rotate();
      expect(piece, equals(Piece(Color.black, PieceType.promPawn)));
      piece = piece.rotate();
      expect(piece, equals(Piece(Color.white, PieceType.pawn)));
      piece = piece.rotate();
      expect(piece, equals(Piece(Color.white, PieceType.promPawn)));
      piece = piece.rotate();
      expect(piece, equals(Piece(Color.black, PieceType.pawn)));
    });

    test('static', () {
      expect(Piece.isValidSFEN('N'), isTrue);
      expect(Piece.isValidSFEN('+N'), isTrue);
      expect(Piece.isValidSFEN('-N'), isFalse);
      expect(Piece.isValidSFEN(' N'), isFalse);
      expect(Piece.isValidSFEN('N '), isFalse);
      expect(Piece.isValidSFEN('+'), isFalse);
      expect(Piece.isValidSFEN('X'), isFalse);
      expect(Piece.isValidSFEN(''), isFalse);
      expect(Piece.isValidSFEN(' '), isFalse);

      expect(Piece.newBySFEN('+N'), equals(Piece(Color.black, PieceType.promKnight)));
      expect(Piece.newBySFEN('k'), equals(Piece(Color.white, PieceType.king)));
      expect(Piece.newBySFEN('XX'), isNull);
    });
  });
}
