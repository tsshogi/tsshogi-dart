import 'package:test/test.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/move.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/square.dart';

void main() {
  group('position', () {
    test('getters', () {
      final Position position = Position();
      expect(position.color, Color.black);
      expect(
        position.board.at(Square(8, 2)),
        equals(Piece(Color.white, PieceType.rook)),
      );
      expect(position.hand(Color.black).count(PieceType.pawn), 0);
      expect(position.hand(Color.white).count(PieceType.pawn), 0);

      position.blackHand.add(PieceType.pawn, 1);
      position.whiteHand.add(PieceType.pawn, 2);
      expect(position.hand(Color.black).count(PieceType.pawn), 1);
      expect(position.hand(Color.white).count(PieceType.pawn), 2);
    });

    test('reset', () {
      final Position position = Position();
      position.reset(InitialPositionType.empty);
      expect(position.sfen, '9/9/9/9/9/9/9/9/9 b - 1');
      position.reset(InitialPositionType.standard);
      expect(
        position.sfen,
        'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      );
      position.reset(InitialPositionType.handicapLance);
      expect(
        position.sfen,
        'lnsgkgsn1/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicapRightLance);
      expect(
        position.sfen,
        '1nsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicapBishop);
      expect(
        position.sfen,
        'lnsgkgsnl/1r7/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicapRook);
      expect(
        position.sfen,
        'lnsgkgsnl/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicapRookLance);
      expect(
        position.sfen,
        'lnsgkgsn1/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicap2Pieces);
      expect(
        position.sfen,
        'lnsgkgsnl/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicap4Pieces);
      expect(
        position.sfen,
        '1nsgkgsn1/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicap6Pieces);
      expect(
        position.sfen,
        '2sgkgs2/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicap8Pieces);
      expect(
        position.sfen,
        '3gkg3/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.handicap10Pieces);
      expect(
        position.sfen,
        '4k4/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1',
      );
      position.reset(InitialPositionType.tsumeShogi);
      expect(
        position.sfen,
        '4k4/9/9/9/9/9/9/9/9 b 2r2b4g4s4n4l18p 1',
      );
      position.reset(InitialPositionType.tsumeShogi2Kings);
      expect(
        position.sfen,
        '4k4/9/9/9/9/9/9/9/4K4 b 2r2b4g4s4n4l18p 1',
      );
    });

    test('resetBySFEN', () {
      // normalized
      final List<String> testCases = <String>[
        InitialPositionSFEN.standard.value,
        InitialPositionSFEN.empty.value,
        InitialPositionSFEN.handicapLance.value,
        InitialPositionSFEN.handicapRightLance.value,
        InitialPositionSFEN.handicapBishop.value,
        InitialPositionSFEN.handicapRook.value,
        InitialPositionSFEN.handicapRookLance.value,
        InitialPositionSFEN.handicap2Pieces.value,
        InitialPositionSFEN.handicap4Pieces.value,
        InitialPositionSFEN.handicap6Pieces.value,
        InitialPositionSFEN.handicap8Pieces.value,
        InitialPositionSFEN.handicap10Pieces.value,
        InitialPositionSFEN.tsumeShogi.value,
        InitialPositionSFEN.tsumeShogi2Kings.value,
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p 1',
      ];
      for (final String tc in testCases) {
        final Position? position = Position.newBySFEN(tc);
        expect(position, isA<Position>());
        expect(position?.sfen, tc);
      }

      // not normalized
      final List<({String input, String output})> testCases2 =
          <({String input, String output})>[
        (
          input:
              'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p 100',
          output:
              'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p 1',
        ),
        (
          input:
              'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p',
          output:
              'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p 1',
        ),
        (
          input:
              'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b PNSR2pnsr',
          output:
              'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p 1',
        ),
      ];
      for (final tc in testCases2) {
        final Position? position = Position.newBySFEN(tc.input);
        expect(position, isA<Position>());
        expect(position?.sfen, tc.output);
      }

      // invalid
      final List<String> invalids = <String>[
        ' b - 1',
        'x b - 1',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L  RSNPrsn2p 1',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L x RSNPrsn2p 1',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b  1',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b x 1',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p ',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b RSNPrsn2p x',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L',
        'l+B5nl/4g1gk1/2b1p2p1/p1p2pp2/3s1P2p/P1P3PP1/1P2PSN1P/2G2GK2/L7L b',
      ];
      for (final String invalid in invalids) {
        expect(Position.newBySFEN(invalid), isNull);
      }
    });

    test('doMove', () {
      final Position position = Position();
      // 26FU(27)
      Move? move = position.createMove(FromSquare(Square(2, 7)), Square(2, 6));
      expect(move, isA<Move>());
      expect(move?.color, Color.black);
      expect(position.isValidMove(move!), isTrue);
      expect(position.doMove(move), isTrue);
      expect(position.board.at(Square(2, 7)), isNull);
      expect(
        position.board.at(Square(2, 6)),
        equals(Piece(Color.black, PieceType.pawn)),
      );
      // 34FU(33)
      move = position.createMove(FromSquare(Square(3, 3)), Square(3, 4));
      expect(move?.color, Color.white);
      expect(position.doMove(move!), isTrue);
      expect(position.board.at(Square(3, 3)), isNull);
      expect(
        position.board.at(Square(3, 4)),
        equals(Piece(Color.white, PieceType.pawn)),
      );
      // Invalid
      move = position.createMove(FromSquare(Square(2, 8)), Square(2, 6));
      expect(position.doMove(move!), isFalse);
      expect(position.color, Color.black);
      expect(position.doMove(move, ignoreValidation: true), isTrue);
      expect(position.color, Color.white);
      expect(position.board.at(Square(2, 8)), isNull);
      expect(
        position.board.at(Square(2, 6)),
        equals(Piece(Color.black, PieceType.rook)),
      );
      // ignoreValidation でも移動元の駒が存在しない場合は false を返す
      final Move move2 = Move(
        FromSquare(Square(1, 4)),
        Square(1, 3),
        true,
        position.color,
        PieceType.pawn,
        null,
      );
      expect(position.doMove(move2, ignoreValidation: true), isFalse);
    });

    group('isValidMove', () {
      test('black', () {
        // 元 KIF を SFEN に変換した盤面:
        // 後手の持駒：歩八 香 桂二 銀二 金二 角
        // 1段目: ・ ・ ・ ・v玉 ・ ・ ・ ・
        // 2段目: ・ ・ ・ ・ ・ ・ ・ ・ ・
        // 3段目: ・ ・ ・v香 角 ・ ・ ・ ・
        // 4段目: ・ ・ ・ ・v歩 ・ ・ ・ ・
        // 5段目: ・ ・ ・ 銀 ・ ・ ・ ・ ・
        // 6段目: ・ ・ ・ 玉 ・ ・ ・v龍 ・
        // 7段目: ・ ・ 歩 ・ 金 歩 ・ 歩 ・
        // 8段目: ・ ・ ・ ・ ・ ・ 桂 ・ ・
        // 9段目: ・ ・ ・ ・ ・ ・ ・ ・ ・
        // 先手の持駒：歩六 香二 桂 銀 金 飛
        // 先手番
        final Position position = Position.newBySFEN(
          '4k4/9/3lB4/4p4/3S5/3K3+r1/2P1GP1P1/6N2/9 b RGSN2L6Pb2g2s2nl8p 1',
        )!;
        Move buildMove(int ff, int fr, int tf, int tr) {
          return position.createMove(
            FromSquare(Square(ff, fr)),
            Square(tf, tr),
          ) as Move;
        }

        Move buildDrop(PieceType type, int tf, int tr) {
          return position.createMove(FromHand(type), Square(tf, tr)) as Move;
        }

        // 合法手
        expect(position.isValidMove(buildMove(2, 7, 2, 6)), isTrue);
        expect(position.isValidMove(buildMove(4, 7, 4, 6)), isTrue);
        expect(position.isValidMove(buildMove(3, 8, 2, 6)), isTrue);
        expect(position.isValidMove(buildMove(3, 8, 4, 6)), isTrue);
        expect(position.isValidMove(buildMove(5, 7, 4, 6)), isTrue);
        expect(position.isValidMove(buildMove(5, 7, 5, 6)), isTrue);
        expect(position.isValidMove(buildMove(5, 3, 2, 6)), isTrue);
        expect(
          position.isValidMove(buildMove(5, 3, 2, 6).withPromote()),
          isTrue,
        );
        expect(position.isValidMove(buildMove(6, 6, 6, 7)), isTrue);
        expect(position.isValidMove(buildMove(6, 6, 7, 5)), isTrue);
        expect(
          position.isValidMove(buildDrop(PieceType.pawn, 3, 6)),
          isTrue,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.lance, 4, 6)),
          isTrue,
        );
        // 王手放置
        expect(position.isValidMove(buildMove(7, 7, 7, 6)), isFalse);
        expect(position.isValidMove(buildMove(5, 3, 3, 5)), isFalse);
        expect(position.isValidMove(buildMove(6, 5, 5, 6)), isFalse);
        expect(position.isValidMove(buildMove(6, 6, 5, 5)), isFalse);
        expect(position.isValidMove(buildMove(6, 6, 5, 6)), isFalse);
        expect(position.isValidMove(buildMove(6, 6, 7, 6)), isFalse);
        // 筋違い
        expect(position.isValidMove(buildMove(5, 3, 1, 7)), isFalse);
        expect(position.isValidMove(buildMove(5, 3, 3, 6)), isFalse);
        // 味方の駒
        expect(position.isValidMove(buildMove(6, 6, 5, 7)), isFalse);
        expect(position.isValidMove(buildMove(6, 6, 7, 7)), isFalse);
        // 打てないマス
        expect(
          position.isValidMove(buildDrop(PieceType.pawn, 2, 6)),
          isFalse,
        );
        // 二歩
        expect(
          position.isValidMove(buildDrop(PieceType.pawn, 4, 6)),
          isFalse,
        );
        // 存在しない駒
        expect(
          position.isValidMove(buildDrop(PieceType.bishop, 3, 6)),
          isFalse,
        );
        // 相手の駒
        expect(position.isValidMove(buildMove(2, 6, 2, 5)), isFalse);
        // 異なる駒
        final Move invalidPieceMove = buildMove(4, 7, 4, 6);
        invalidPieceMove.pieceType = PieceType.silver;
        expect(position.isValidMove(invalidPieceMove), isFalse);
        // 異なる取った駒
        final Move invalidCapturedPieceMove = buildMove(2, 7, 2, 6);
        invalidCapturedPieceMove.capturedPieceType = PieceType.silver;
        expect(position.isValidMove(invalidCapturedPieceMove), isFalse);
        final Move invalidCapturedPieceMove2 = buildMove(2, 7, 2, 6);
        invalidCapturedPieceMove2.capturedPieceType = null;
        expect(position.isValidMove(invalidCapturedPieceMove2), isFalse);
        final Move invalidCapturedPieceMove3 = buildMove(4, 7, 4, 6);
        invalidCapturedPieceMove3.capturedPieceType = PieceType.silver;
        expect(position.isValidMove(invalidCapturedPieceMove3), isFalse);
        // 成り駒を打つ手
        final Move invalidPieceDrop = buildDrop(PieceType.bishop, 3, 6);
        invalidPieceDrop.promote = true;
        expect(position.isValidMove(invalidPieceDrop), isFalse);
        // 相手の駒を打つ手
        final Move invalidColorDrop = buildDrop(PieceType.bishop, 3, 6);
        invalidColorDrop.color = Color.white;
        expect(position.isValidMove(invalidColorDrop), isFalse);
      });

      test('white', () {
        final Position position = Position.newBySFEN(
          '4K4/+B6+R1/9/9/1l4b2/n4P3/5pps1/p1gr5/7k1 w 2G2S2N2L8Pgsnl6p 1',
        )!;
        Move buildMove(int ff, int fr, int tf, int tr) {
          return position.createMove(
            FromSquare(Square(ff, fr)),
            Square(tf, tr),
          ) as Move;
        }

        Move buildDrop(PieceType type, int tf, int tr) {
          return position.createMove(FromHand(type), Square(tf, tr)) as Move;
        }

        // 合法手
        expect(position.isValidMove(buildMove(2, 7, 2, 8)), isTrue);
        expect(
          position.isValidMove(buildMove(2, 7, 2, 8).withPromote()),
          isTrue,
        );
        expect(position.isValidMove(buildMove(3, 7, 3, 8)), isTrue);
        expect(
          position.isValidMove(buildMove(3, 7, 3, 8).withPromote()),
          isTrue,
        );
        expect(
          position.isValidMove(buildMove(9, 8, 9, 9).withPromote()),
          isTrue,
        );
        expect(position.isValidMove(buildMove(8, 5, 8, 8)), isTrue);
        expect(
          position.isValidMove(buildMove(8, 5, 8, 9).withPromote()),
          isTrue,
        );
        expect(
          position.isValidMove(buildMove(9, 6, 8, 8).withPromote()),
          isTrue,
        );
        expect(position.isValidMove(buildMove(7, 8, 7, 9)), isTrue);
        expect(position.isValidMove(buildMove(3, 5, 1, 3)), isTrue);
        expect(position.isValidMove(buildMove(3, 5, 2, 6)), isTrue);
        expect(
          position.isValidMove(buildMove(3, 5, 1, 7).withPromote()),
          isTrue,
        );
        expect(position.isValidMove(buildMove(3, 5, 4, 6)), isTrue);
        expect(
          position.isValidMove(buildMove(6, 8, 5, 8).withPromote()),
          isTrue,
        );
        expect(
          position.isValidMove(buildMove(6, 8, 1, 8).withPromote()),
          isTrue,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.pawn, 8, 8)),
          isTrue,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.lance, 8, 8)),
          isTrue,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.knight, 8, 7)),
          isTrue,
        );
        // 王手放置
        expect(position.isValidMove(buildMove(2, 7, 3, 8)), isFalse);
        expect(
          position.isValidMove(buildMove(4, 7, 4, 8).withPromote()),
          isFalse,
        );
        // 筋違い
        expect(position.isValidMove(buildMove(2, 7, 2, 6)), isFalse);
        expect(
          position.isValidMove(buildMove(3, 5, 5, 7).withPromote()),
          isFalse,
        );
        expect(
          position.isValidMove(buildMove(6, 8, 7, 8).withPromote()),
          isFalse,
        );
        expect(
          position.isValidMove(buildMove(6, 8, 8, 8).withPromote()),
          isFalse,
        );
        // 行き所の無い駒
        expect(position.isValidMove(buildMove(9, 8, 9, 9)), isFalse);
        expect(position.isValidMove(buildMove(8, 5, 8, 9)), isFalse);
        expect(position.isValidMove(buildMove(9, 6, 8, 8)), isFalse);
        expect(
          position.isValidMove(buildDrop(PieceType.pawn, 8, 9)),
          isFalse,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.lance, 8, 9)),
          isFalse,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.knight, 8, 8)),
          isFalse,
        );
        expect(
          position.isValidMove(buildDrop(PieceType.knight, 8, 9)),
          isFalse,
        );
        // 成れない駒
        expect(
          position.isValidMove(buildMove(3, 5, 2, 6).withPromote()),
          isFalse,
        );
        expect(
          position.isValidMove(buildMove(7, 8, 7, 9).withPromote()),
          isFalse,
        );
      });

      test('black/pawn_drop_mate', () {
        final Position position = Position.newBySFEN(
          '7B1/3R2n2/5kn2/4P4/5G3/9/9/9/4K4 b P 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(4, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isTrue);
        expect(position.isValidMove(move), isFalse);
      });

      test('black/no_pawn_drop_mate/capture', () {
        final Position position = Position.newBySFEN(
          '9/3R2n2/5kn2/4P4/5G3/9/9/9/4K4 b P 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(4, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isFalse);
        expect(position.isValidMove(move), isTrue);
      });

      test('black/no_pawn_drop_mate/king_movable', () {
        final Position position = Position.newBySFEN(
          '7B1/3R2n2/5kn2/4P4/6G2/9/9/9/4K4 b P 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(4, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isFalse);
        expect(position.isValidMove(move), isTrue);
      });

      test('black/no_pawn_drop_mate/block_dragon_effect', () {
        final Position position = Position.newBySFEN(
          '7B1/3R2n2/5kn2/3+R5/9/9/9/9/4K4 b P 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(4, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isFalse);
        expect(position.isValidMove(move), isTrue);
      });

      test('white/pawn_drop_mate', () {
        final Position position = Position.newBySFEN(
          '4k4/2l6/9/6r2/3KS2r1/3P5/4+p4/9/9 w p 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(6, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isTrue);
        expect(position.isValidMove(move), isFalse);
      });

      test('white/no_pawn_drop_mate/capture', () {
        final Position position = Position.newBySFEN(
          '4k4/2l6/9/6r2/3KS4/3P5/4+p4/9/9 w p 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(6, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isFalse);
        expect(position.isValidMove(move), isTrue);
      });

      test('white/no_pawn_drop_mate/king_movable', () {
        final Position position = Position.newBySFEN(
          '4k4/9/9/6r2/3KS2r1/3P5/4+p4/9/9 w p 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(6, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isFalse);
        expect(position.isValidMove(move), isTrue);
      });

      test('white/no_pawn_drop_mate/block_bishop_effect', () {
        final Position position = Position.newBySFEN(
          '4k4/9/9/6r2/1g1KS2r1/3P5/4+p4/9/9 w p 1',
        )!;
        final Move move = position.createMove(
          const FromHand(PieceType.pawn),
          Square(6, 4),
        ) as Move;
        expect(position.isPawnDropMate(move), isFalse);
        expect(position.isValidMove(move), isTrue);
      });
    });

    test('isValidEditing', () {
      final Position position = Position.newBySFEN(
        'ln1gkg1nl/1r1s3s1/pppppp1pp/6B2/9/2P4P1/PP1PPPP1P/1S5R1/LN1GKGSNL w Pb 10',
      )!;
      // Good: ☗49金 => 85
      expect(
        position.isValidEditing(Square(4, 9), Square(8, 5)),
        isTrue,
      );
      // Good: ☗49金 <=> ⛉83歩
      expect(
        position.isValidEditing(Square(4, 9), Square(8, 3)),
        isTrue,
      );
      // Bad: 48 => 85
      expect(
        position.isValidEditing(Square(4, 8), Square(8, 5)),
        isFalse,
      );
      // Good: ⛉82飛 => ☗
      expect(
        position.isValidEditing(Square(8, 2), Color.black),
        isTrue,
      );
      // Good: ⛉82飛 => ⛉
      expect(
        position.isValidEditing(Square(8, 2), Color.white),
        isTrue,
      );
      // Bad: 72 => ⛉
      expect(
        position.isValidEditing(Square(7, 2), Color.white),
        isFalse,
      );
      // Good: ☗持歩 => ⛉
      expect(
        position.isValidEditing(
          Piece(Color.black, PieceType.pawn),
          Color.white,
        ),
        isTrue,
      );
      // Bad: ☗持銀 => ⛉
      expect(
        position.isValidEditing(
          Piece(Color.black, PieceType.bishop),
          Color.white,
        ),
        isFalse,
      );
      // Good: ⛉持角 => ☗
      expect(
        position.isValidEditing(
          Piece(Color.white, PieceType.bishop),
          Color.black,
        ),
        isTrue,
      );
      // Bad: ⛉持銀 => ☗
      expect(
        position.isValidEditing(
          Piece(Color.white, PieceType.pawn),
          Color.black,
        ),
        isFalse,
      );
      // Good: ☗持歩 => 31
      expect(
        position.isValidEditing(
          Piece(Color.black, PieceType.pawn),
          Square(3, 1),
        ),
        isTrue,
      );
      // Bad: ☗持歩 => ⛉41金
      expect(
        position.isValidEditing(
          Piece(Color.black, PieceType.pawn),
          Square(4, 1),
        ),
        isFalse,
      );
      // Bad: ⛉51玉 => ⛉
      expect(
        position.isValidEditing(Square(5, 1), Color.white),
        isFalse,
      );
    });

    test('edit', () {
      final Position position = Position.newBySFEN(
        'ln1gkg1nl/1r1s3s1/pppppp1pp/6B2/9/2P4P1/PP1PPPP1P/1S5R1/LN1GKGSNL w Pb 10',
      )!;
      // Good: ☗49金 => 85
      expect(
        position.edit(
          PositionChange(
            move: PositionMoveChange(from: Square(4, 9), to: Square(8, 5)),
          ),
        ),
        isTrue,
      );
      expect(position.board.at(Square(4, 9)), isNull);
      expect(
        position.board.at(Square(8, 5)),
        equals(Piece(Color.black, PieceType.gold)),
      );
      // Bad: ☗49金 => 85
      expect(
        position.edit(
          PositionChange(
            move: PositionMoveChange(from: Square(4, 9), to: Square(8, 5)),
          ),
        ),
        isFalse,
      );
      expect(position.board.at(Square(4, 9)), isNull);
      expect(
        position.board.at(Square(8, 5)),
        equals(Piece(Color.black, PieceType.gold)),
      );
      // Good: ☗持歩 => 31
      expect(
        position.edit(
          PositionChange(
            move: PositionMoveChange(
              from: Piece(Color.black, PieceType.pawn),
              to: Square(3, 1),
            ),
          ),
        ),
        isTrue,
      );
      expect(
        position.board.at(Square(3, 1)),
        equals(Piece(Color.black, PieceType.pawn)),
      );
      // Good: ☗31歩 => ☗31と
      expect(
        position.edit(PositionChange(rotate: Square(3, 1))),
        isTrue,
      );
      expect(
        position.board.at(Square(3, 1)),
        equals(Piece(Color.black, PieceType.promPawn)),
      );
      // Good: ☗31と => ⛉31歩
      expect(
        position.edit(PositionChange(rotate: Square(3, 1))),
        isTrue,
      );
      expect(
        position.board.at(Square(3, 1)),
        equals(Piece(Color.white, PieceType.pawn)),
      );
      // Good: ⛉持角 => ☗
      expect(
        position.edit(
          PositionChange(
            move: PositionMoveChange(
              from: Piece(Color.white, PieceType.bishop),
              to: Color.black,
            ),
          ),
        ),
        isTrue,
      );
      expect(position.hand(Color.white).count(PieceType.bishop), 0);
      expect(position.hand(Color.black).count(PieceType.bishop), 1);
      // Good: ⛉81桂 => ⛉
      expect(
        position.edit(
          PositionChange(
            move: PositionMoveChange(from: Square(8, 1), to: Color.white),
          ),
        ),
        isTrue,
      );
      expect(position.board.at(Square(8, 1)), isNull);
      expect(position.hand(Color.white).count(PieceType.knight), 1);
    });

    test('listAttackers', () {
      final Position position = Position.newBySFEN(
        '+B3kg3/4n2b1/9/4p1+P2/9/4P4/3S5/5R3/4K4 w - 1',
      )!;
      expect(
        position.listAttackers(Square(4, 4)),
        equals(<Square>[
          Square(5, 2),
          Square(2, 2),
          Square(3, 4),
          Square(4, 8),
        ]),
      );
      expect(
        position.listAttackers(Square(4, 2)),
        equals(<Square>[
          Square(5, 1),
          Square(4, 1),
          Square(4, 8),
        ]),
      );
      expect(
        position.listAttackers(Square(5, 5)),
        equals(<Square>[
          Square(9, 1),
          Square(2, 2),
          Square(5, 4),
          Square(5, 6),
        ]),
      );
      expect(
        position.listAttackers(Square(5, 8)),
        equals(<Square>[
          Square(6, 7),
          Square(4, 8),
          Square(5, 9),
        ]),
      );
    });

    test('powerMap/initial', () {
      final Position position = Position();
      final powers = position.powerMap();
      expect(powers.black.length, 81);
      expect(powers.white.length, 81);
      // 5六(5筋6段): 5七の歩からの利きで black=1, white=0
      expect(powers.black[Square(5, 6).index], 1);
      expect(powers.white[Square(5, 6).index], 0);
      // 5四(5筋4段): 5三の歩からの利きで white=1, black=0
      expect(powers.black[Square(5, 4).index], 0);
      expect(powers.white[Square(5, 4).index], 1);
      // 5五: どちらの利きも届かない
      expect(powers.black[Square(5, 5).index], 0);
      expect(powers.white[Square(5, 5).index], 0);
    });

    test('powerMap/midgame', () {
      final Position position = Position.newBySFEN(
        '+B3kg3/4n2b1/9/4p1+P2/9/4P4/3S5/5R3/4K4 w - 1',
      )!;
      final powers = position.powerMap();
      // listAttackers のテストと同じマスで色別に集計されているか
      expect(powers.black[Square(4, 4).index], 2);
      expect(powers.white[Square(4, 4).index], 2);
      expect(powers.black[Square(4, 2).index], 1);
      expect(powers.white[Square(4, 2).index], 2);
      expect(powers.black[Square(5, 5).index], 2);
      expect(powers.white[Square(5, 5).index], 2);
      expect(powers.black[Square(5, 8).index], 3);
      expect(powers.white[Square(5, 8).index], 0);
    });

    test('sfen', () {
      const String sfen =
          'l2R2s1+P/4gg1k1/p1+P2lPp1/4p1p+b1/1p3G3/3pP1nS1/PP3KSP1/R8/L4G2+b b NL4Ps2np 1';
      final Position? position = Position.newBySFEN(sfen);
      expect(position, isA<Position>());
      expect(position?.color, Color.black);
      expect(
        position?.board.at(Square(4, 7)),
        equals(Piece(Color.black, PieceType.king)),
      );
      expect(
        position?.board.at(Square(4, 3)),
        equals(Piece(Color.white, PieceType.lance)),
      );
      expect(
        position?.board.at(Square(2, 4)),
        equals(Piece(Color.white, PieceType.horse)),
      );
      expect(position?.blackHand.count(PieceType.pawn), 4);
      expect(position?.blackHand.count(PieceType.lance), 1);
      expect(position?.blackHand.count(PieceType.knight), 1);
      expect(position?.blackHand.count(PieceType.silver), 0);
      expect(position?.whiteHand.count(PieceType.pawn), 1);
      expect(position?.whiteHand.count(PieceType.lance), 0);
      expect(position?.whiteHand.count(PieceType.knight), 2);
      expect(position?.whiteHand.count(PieceType.silver), 1);
      expect(position?.sfen, sfen);
    });

    group('judgeJishogiDeclaration', () {
      final List<
          ({
            String title,
            String sfen,
            int blackTotalPoint,
            int whiteTotalPoint,
            int blackPoint,
            int whitePoint,
            JishogiDeclarationResult black24,
            JishogiDeclarationResult black27,
            JishogiDeclarationResult white24,
            JishogiDeclarationResult white27,
          })> testCases = <({
        String title,
        String sfen,
        int blackTotalPoint,
        int whiteTotalPoint,
        int blackPoint,
        int whitePoint,
        JishogiDeclarationResult black24,
        JishogiDeclarationResult black27,
        JishogiDeclarationResult white24,
        JishogiDeclarationResult white27,
      })>[
        (
          title: 'sente_10pieces_28points',
          sfen:
              '2GK1+L3/2+P+S+R1G+N1/3+B1GG2/9/+r8/1+bs6/+p+p3+n3/2+n2k3/6+p2 b 2SN7P3l7p 375',
          blackTotalPoint: 28,
          whiteTotalPoint: 26,
          blackPoint: 28,
          whitePoint: 15,
          black24: JishogiDeclarationResult.draw,
          black27: JishogiDeclarationResult.win,
          white24: JishogiDeclarationResult.lose,
          white27: JishogiDeclarationResult.lose,
        ),
        (
          title: 'gote_5pieces_15points',
          sfen:
              '2GK1+L3/2+P+S+R1G+N1/3+B1GG2/9/9/+r+bs6/+p+p3+n3/2+n2k3/6+p2 w 2SN7P3l7p 374',
          blackTotalPoint: 28,
          whiteTotalPoint: 26,
          blackPoint: 28,
          whitePoint: 15,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.lose,
          white27: JishogiDeclarationResult.lose,
        ),
        (
          title: 'gote_10pieces_44points',
          sfen:
              '1+N2+N4/1K7/1+N+P6/9/5g3/4L1s2/1+l2pPg1+s/1s2b1b1+p/1+r4+p1k w 2Pr2gsn2l11p 378',
          blackTotalPoint: 8,
          whiteTotalPoint: 46,
          blackPoint: 6,
          whitePoint: 44,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.win,
          white27: JishogiDeclarationResult.win,
        ),
        (
          title: 'gote_10pieces_28points',
          sfen:
              '1+N4+B1+P/1K4+N+P1/1+L+P3B2/7P1/2G6/9/2G3+l1g/1+r1sppppg/1+l6k w 7Pr3s2nl3p 306',
          blackTotalPoint: 26,
          whiteTotalPoint: 28,
          blackPoint: 23,
          whitePoint: 28,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.draw,
          white27: JishogiDeclarationResult.win,
        ),
        (
          title: 'gote_10pieces_39points',
          sfen:
              'K6n1/+PG7/+P3G4/1P+P6/9/4P4/9/3p+bp+pps/3+pk1rr+b w SNL4P2g2s2n3l4p 416',
          blackTotalPoint: 14,
          whiteTotalPoint: 40,
          blackPoint: 11,
          whitePoint: 39,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.win,
          white27: JishogiDeclarationResult.win,
        ),
        (
          title: 'gote_10pieces_38points_cheked',
          sfen:
              'K6n1/+PG7/+P3G4/1P+P6/9/9/4P4/3pGp+pps/3+pkbrr+b w SNL4Pg2s2n3l4p 414',
          blackTotalPoint: 15,
          whiteTotalPoint: 39,
          blackPoint: 11,
          whitePoint: 38,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.lose,
          white27: JishogiDeclarationResult.lose,
        ),
        (
          title: 'gote_9pieces_38points',
          sfen:
              'K6n1/+PG7/+P3G4/1P+P6/9/9/4P4/3p1p+pps/3+pkbr1+b w GSNL4Prg2s2n3l4p 412',
          blackTotalPoint: 15,
          whiteTotalPoint: 39,
          blackPoint: 12,
          whitePoint: 38,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.lose,
          white27: JishogiDeclarationResult.lose,
        ),
        (
          title: 'uwate_9pieces_38points',
          sfen:
              'K6n1/+PG7/+P3G4/1P+P6/9/9/4P4/2+pp1p+ppp/1+p1+pkb3 w GSNL4Pr2n3lp 1',
          blackTotalPoint: 15,
          whiteTotalPoint: 39,
          blackPoint: 12,
          whitePoint: 38,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.lose,
          white27: JishogiDeclarationResult.lose,
        ),
        (
          title: 'uwate_10pieces_38points',
          sfen:
              'K6n1/+PG1P5/+P3G4/1P+P6/9/9/4P4/1p+pp1p+ppp/1+p1+pkb3 w GSNL3Pr2n3l 1',
          blackTotalPoint: 15,
          whiteTotalPoint: 39,
          blackPoint: 12,
          whitePoint: 38,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.win,
          white27: JishogiDeclarationResult.win,
        ),
        (
          title: 'hirate_initial',
          sfen:
              'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
          blackTotalPoint: 27,
          whiteTotalPoint: 27,
          blackPoint: 0,
          whitePoint: 0,
          black24: JishogiDeclarationResult.lose,
          black27: JishogiDeclarationResult.lose,
          white24: JishogiDeclarationResult.lose,
          white27: JishogiDeclarationResult.lose,
        ),
      ];
      for (final tc in testCases) {
        test(tc.title, () {
          final Position position = Position.newBySFEN(tc.sfen)!;
          expect(
            countJishogiPoint(position, Color.black),
            tc.blackTotalPoint,
          );
          expect(
            countJishogiPoint(position, Color.white),
            tc.whiteTotalPoint,
          );
          expect(
            countJishogiDeclarationPoint(position, Color.black),
            tc.blackPoint,
          );
          expect(
            countJishogiDeclarationPoint(position, Color.white),
            tc.whitePoint,
          );
          expect(
            judgeJishogiDeclaration(
              JishogiDeclarationRule.general24,
              position,
              Color.black,
            ),
            tc.black24,
          );
          expect(
            judgeJishogiDeclaration(
              JishogiDeclarationRule.general27,
              position,
              Color.black,
            ),
            tc.black27,
          );
          expect(
            judgeJishogiDeclaration(
              JishogiDeclarationRule.general24,
              position,
              Color.white,
            ),
            tc.white24,
          );
          expect(
            judgeJishogiDeclaration(
              JishogiDeclarationRule.general27,
              position,
              Color.white,
            ),
            tc.white27,
          );
        });
      }
    });
  });
}
