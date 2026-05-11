// position.castles / position.strategies / record.techniques extension
// getter のテスト。中身は detectCastles / detectStrategies / detectTechniques
// に委譲してるだけなので、API シェイプと両陣営検出が動くことを確認する。

import 'package:test/test.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/strategy.dart';
import 'package:tsshogi/src/technique.dart';

void main() {
  group('position.castles getter', () {
    test('初期局面では 居玉 が両陣営で検出される', () {
      final Position p = Position();
      final List<DetectedCastle> list = p.castles;
      expect(list.any((d) => d.template.name == '居玉' && d.side == Color.black),
          isTrue);
      expect(list.any((d) => d.template.name == '居玉' && d.side == Color.white),
          isTrue);
    });

    test('detectCastles(p) と同じ結果を返す', () {
      final Position p = Position();
      expect(p.castles, equals(detectCastles(p)));
    });

    test('SFEN 経由で 金矢倉局面を組んで検出', () {
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      // 黒の金矢倉骨格
      p.board.set(Square(8, 8), Piece(Color.black, PieceType.king));
      p.board.set(Square(7, 8), Piece(Color.black, PieceType.gold));
      p.board.set(Square(6, 7), Piece(Color.black, PieceType.gold));
      p.board.set(Square(7, 7), Piece(Color.black, PieceType.silver));
      p.board.set(Square(9, 7), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(7, 6), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(6, 6), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(5, 6), Piece(Color.black, PieceType.pawn));
      // 白玉だけ Position 健全性のため
      p.board.set(Square(5, 1), Piece(Color.white, PieceType.king));

      final Set<String> blackCastles = p.castles
          .where((d) => d.side == Color.black)
          .map((d) => d.template.name)
          .toSet();
      expect(blackCastles, contains('金矢倉'));
      expect(blackCastles, contains('矢倉囲い'));
    });

    test('片陣営のみ欲しい時は .where でフィルタ', () {
      final Position p = Position();
      final List<DetectedCastle> blackOnly =
          p.castles.where((d) => d.side == Color.black).toList();
      expect(blackOnly.every((d) => d.side == Color.black), isTrue);
    });
  });

  group('position.strategies getter', () {
    test('初期局面の戦法 (主に 矢倉/角換わり/その他 居飛車系) を含む', () {
      final Position p = Position();
      final List<DetectedStrategy> list = p.strategies;
      // 何らかしら検出される (初期局面は飛車 2八 / 玉 5九 等で複数戦法
      // が match する設計)
      expect(list, isNotEmpty);
    });

    test('detectStrategies(p) と同じ結果を返す', () {
      final Position p = Position();
      expect(p.strategies, equals(detectStrategies(p)));
    });

    test('片陣営のみ欲しい時は .where でフィルタ', () {
      final Position p = Position();
      final List<DetectedStrategy> blackOnly =
          p.strategies.where((d) => d.side == Color.black).toList();
      expect(blackOnly.every((d) => d.side == Color.black), isTrue);
    });
  });

  group('record.techniques getter', () {
    test('初期局面 + 数手で発動した手筋を抽出', () {
      final Record r =
          Record.newByUSI('position startpos moves 7g7f 3c3d 8h2b+')!;
      final List<DetectedTechnique> list = r.techniques;
      // 8八角→2二角成 で 角交換 が発動するはず
      expect(list.any((d) => d.template.name == '角交換'), isTrue);
    });

    test('detectTechniques(r) と同じ結果を返す', () {
      final Record r = Record.newByUSI('position startpos moves 7g7f 3c3d')!;
      expect(r.techniques, equals(detectTechniques(r)));
    });

    test('空の棋譜 (指し手なし) では空リスト', () {
      final Record r = Record();
      expect(r.techniques, isEmpty);
    });
  });

  group('SFEN 経由の総合テスト', () {
    test('SFEN 文字列 → 囲い + 戦法 をまとめて取得', () {
      const String sfen =
          'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1';
      final Position p = Position.newBySFEN(sfen)!;
      expect(p.castles, isNotEmpty);
      expect(p.strategies, isNotEmpty);
    });
  });
}
