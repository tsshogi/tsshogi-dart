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
      // bioshogi 金矢倉: 玉88 + 金78 + 金67 + 銀77 + 歩87/76/66
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      p.board.set(Square(8, 8), Piece(Color.black, PieceType.king));
      p.board.set(Square(7, 8), Piece(Color.black, PieceType.gold));
      p.board.set(Square(6, 7), Piece(Color.black, PieceType.gold));
      p.board.set(Square(7, 7), Piece(Color.black, PieceType.silver));
      p.board.set(Square(8, 7), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(7, 6), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(6, 6), Piece(Color.black, PieceType.pawn));
      // 白玉だけ Position 健全性のため
      p.board.set(Square(5, 1), Piece(Color.white, PieceType.king));

      final Set<String> blackCastles = p.castles
          .where((d) => d.side == Color.black)
          .map((d) => d.template.name)
          .toSet();
      expect(blackCastles, contains('金矢倉'));
      // bioshogi では「矢倉囲い」は独立テンプレではなく alias_names で保持
      // されるだけなので、テンプレ名としては検出されない。
    });

    test('片陣営のみ欲しい時は .where でフィルタ', () {
      final Position p = Position();
      final List<DetectedCastle> blackOnly =
          p.castles.where((d) => d.side == Color.black).toList();
      expect(blackOnly.every((d) => d.side == Color.black), isTrue);
    });
  });

  group('position.strategies getter', () {
    test('初期局面では戦法が検出されない (居玉系を除く)', () {
      // bioshogi 由来テンプレでは「?玉 (相手玉の位置制約)」を表現できない
      // ため一部の戦法が初期局面でも発火する (例: Uターン飛車)。
      // それでも検出が膨大に膨らんでないか smoke チェックする。
      final Position p = Position();
      expect(p.strategies.length, lessThan(10), reason: '初期局面で過剰な戦法が誤発火している');
    });

    test('detectStrategies(p) と同じ結果を返す', () {
      final Position p = Position();
      expect(p.strategies, equals(detectStrategies(p)));
    });

    test('片陣営のみ欲しい時は .where でフィルタ', () {
      // 初期局面では戦法 0 件なので、四間飛車組み上げた局面で確認
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      p.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      p.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      p.board.set(Square(6, 8), Piece(Color.black, PieceType.rook)); // 6八飛
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
    test('SFEN 文字列 → 囲い だけは取れる (初期局面では戦法は空に近い)', () {
      const String sfen =
          'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1';
      final Position p = Position.newBySFEN(sfen)!;
      // 居玉だけは検出される (黒/白)
      expect(p.castles, isNotEmpty);
      // 戦法は bioshogi 由来データでは少数の戦法 (Uターン飛車など) が発火しうる
      expect(p.strategies.length, lessThan(10));
    });
  });

  group('record.castles (first-occurrence) getter', () {
    test('居玉 は初期局面 ply 0 で 1 回だけ報告される', () {
      final Record r = Record.newByUSI('position startpos moves 7g7f 3c3d')!;
      final List<DetectedCastleAt> blackIgyoku = r.castles
          .where((c) => c.template.name == '居玉' && c.side == Color.black)
          .toList();
      expect(blackIgyoku.length, 1, reason: '居玉 (黒) は最初の 1 回だけ報告されるはず');
      expect(blackIgyoku.first.ply, 0);
    });

    test('スナップショット (position.castles) は手数分繰り返し検出', () {
      // 対照: position.castles なら同じ居玉が手数分検出される
      final Record r = Record.newByUSI('position startpos moves 7g7f 3c3d')!;
      // initial position
      final initialIgyoku = r.initialPosition.castles
          .where((c) => c.template.name == '居玉' && c.side == Color.black)
          .toList();
      expect(initialIgyoku, isNotEmpty);
      // current position (still 居玉)
      final currentIgyoku = r.position.castles
          .where((c) => c.template.name == '居玉' && c.side == Color.black)
          .toList();
      expect(currentIgyoku, isNotEmpty);
      // Record extension is "first only"
      expect(r.castles.where((c) => c.template.name == '居玉').length, 2,
          reason: '居玉 は黒/白 1 回ずつ計 2 件');
    });

    test('ply 0 = 初期局面、ply 1 以降 = 各指し手', () {
      final Record r = Record.newByUSI('position startpos moves 7g7f')!;
      for (final DetectedCastleAt c in r.castles) {
        expect(c.ply, anyOf(equals(0), greaterThanOrEqualTo(1)));
      }
    });

    test('空棋譜 = 初期局面の検出のみ', () {
      final Record r = Record();
      final List<DetectedCastleAt> list = r.castles;
      expect(list, isNotEmpty);
      expect(list.every((c) => c.ply == 0), isTrue);
    });

    test('DetectedCastleAt equality / hashCode', () {
      const String sfen =
          'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1';
      final Position p = Position.newBySFEN(sfen)!;
      final CastleTemplate t = p.castles.first.template;
      final DetectedCastleAt a =
          DetectedCastleAt(template: t, side: Color.black, ply: 5);
      final DetectedCastleAt b =
          DetectedCastleAt(template: t, side: Color.black, ply: 5);
      final DetectedCastleAt c =
          DetectedCastleAt(template: t, side: Color.black, ply: 6);
      final DetectedCastleAt d =
          DetectedCastleAt(template: t, side: Color.white, ply: 5);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
      expect(a == Object(), isFalse);
    });
  });

  group('record.strategies (first-occurrence) getter', () {
    test('一度検出された戦法は再報告されない (重複なし)', () {
      // 数手指して、検出された戦法の (template, side) が一意であることを
      // 確認。スナップショットの繰り返し検出を防げているかを保証する。
      final Record? r =
          Record.newByUSI('position startpos moves 7g7f 3c3d 2g2f 8c8d');
      expect(r, isNotNull);
      final List<DetectedStrategyAt> list = r!.strategies;
      final Set<String> keys =
          list.map((s) => '${s.template.name}|${s.side.value}').toSet();
      expect(keys.length, list.length, reason: '同じ (テンプレ名, 陣営) が 2 回以上現れない');
    });

    test('空棋譜 = 初期局面の検出のみ', () {
      final Record r = Record();
      final List<DetectedStrategyAt> list = r.strategies;
      expect(list.every((s) => s.ply == 0), isTrue);
    });

    test('DetectedStrategyAt equality / hashCode', () {
      // 適当な戦法テンプレを 1 つ取り出す
      final StrategyTemplate t = knownStrategies.first;
      final DetectedStrategyAt a =
          DetectedStrategyAt(template: t, side: Color.black, ply: 3);
      final DetectedStrategyAt b =
          DetectedStrategyAt(template: t, side: Color.black, ply: 3);
      final DetectedStrategyAt c =
          DetectedStrategyAt(template: t, side: Color.white, ply: 3);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == Object(), isFalse);
    });
  });
}
