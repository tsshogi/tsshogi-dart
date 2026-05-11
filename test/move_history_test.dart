// MoveHistory および履歴依存テンプレ (PieceUnmoved / PieceVisited) の
// 動作検証。
//
// 検証する性質:
//
// 1. MoveHistory の初期化 / recordMove で `_sourceTouched` と `_visited` が
//    正しく更新される。
// 2. PieceUnmoved は (a) 履歴 null では常に false、(b) 玉が動いた後は
//    false、(c) 玉が動いて戻ってきても (一度 from で出た) false。
// 3. PieceVisited は (a) 履歴 null では常に false、(b) 飛車が 6八 に居た
//    ことがあれば true (現在位置を問わない)、(c) 居たことがなければ false。
// 4. record.castles 経由で 居玉 は king が動かない側にだけ報告される。
//    king が動いた側 (5九→6八→5九 と戻っても) には報告されない。
// 5. record.strategies 経由で Uターン飛車 は (飛車 2八 + 6八/5八/4八/3八
//    を過去通過) を満たすときだけ報告される。初期局面 (飛車 2八 のみで
//    visited なし) では発火しない。

import 'package:test/test.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/move.dart';
import 'package:tsshogi/src/move_history.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/strategy.dart';

void main() {
  group('MoveHistory basics', () {
    test('init: 初期局面の駒配置が visited に登録される', () {
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      // 先手玉は 5九 に居る → hasVisited(black, king, 5, 9) は true
      expect(h.hasVisited(Color.black, PieceType.king, 5, 9), isTrue);
      // 後手玉は 5一 に居る → hasVisited(white, king, 5, 1) は true
      expect(h.hasVisited(Color.white, PieceType.king, 5, 1), isTrue);
      // どの駒もまだ動いていない → isUnmoved 全部 true
      expect(h.isUnmoved(Color.black, 5, 9), isTrue);
      expect(h.isUnmoved(Color.white, 5, 1), isTrue);
    });

    test('recordMove: from を sourceTouched, to を visited に登録', () {
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      // 7g7f (▲7六歩) を適用
      final Move? move = p.createMoveByUSI('7g7f');
      expect(move, isNotNull);
      h.recordMove(move!, 1);
      // 7g (7,7) から動いたので isUnmoved(black, 7, 7) は false
      expect(h.isUnmoved(Color.black, 7, 7), isFalse);
      // 動いていない別マス 7,8 (玉?ではないが) は依然 unmoved
      expect(h.isUnmoved(Color.black, 5, 9), isTrue);
      // 7f (7,6) に歩が居たことがある
      expect(h.hasVisited(Color.black, PieceType.pawn, 7, 6), isTrue);
    });
  });

  group('PieceUnmoved', () {
    test('history == null → 常に false', () {
      const PieceUnmoved req = PieceUnmoved(5, 9);
      final Position p = Position();
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
      expect(req.isSatisfiedBy(p, Color.black, null), isFalse);
    });

    test('初期局面 + 何も動かしていない → true (黒/白とも)', () {
      const PieceUnmoved blackKingUnmoved = PieceUnmoved(5, 9);
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      expect(blackKingUnmoved.isSatisfiedBy(p, Color.black, h), isTrue);
      // 後手側は (5, 9) を mirror して (5, 1) を見る
      expect(blackKingUnmoved.isSatisfiedBy(p, Color.white, h), isTrue);
    });

    test('5九玉が動いた後は black には false / white は依然 true', () {
      const PieceUnmoved req = PieceUnmoved(5, 9);
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      final Move? move = p.createMoveByUSI('5i6h');
      expect(move, isNotNull);
      h.recordMove(move!, 1);
      p.doMove(move, ignoreValidation: true);
      expect(req.isSatisfiedBy(p, Color.black, h), isFalse);
      expect(req.isSatisfiedBy(p, Color.white, h), isTrue);
    });

    test('5九→6八→5九 と戻っても false (一度動いたから)', () {
      const PieceUnmoved req = PieceUnmoved(5, 9);
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      int ply = 0;
      for (final String usi in <String>['5i6h', '5a5b', '6h5i']) {
        ply += 1;
        final Move? move = p.createMoveByUSI(usi);
        expect(move, isNotNull, reason: 'failed to parse $usi');
        h.recordMove(move!, ply);
        p.doMove(move, ignoreValidation: true);
      }
      // 黒玉は再び 5九 にあるが、過去に 5九 から動いた事実は消えない
      expect(req.isSatisfiedBy(p, Color.black, h), isFalse);
    });
  });

  group('PieceVisited', () {
    test('history == null → 常に false', () {
      const PieceVisited req = PieceVisited(6, 8, PieceType.rook);
      final Position p = Position();
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
    });

    test('飛車が 2八 → 6八 → 2八 と動けば 6八 visited は true', () {
      const PieceVisited req = PieceVisited(6, 8, PieceType.rook);
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      // 飛車を 2八 → 6八 → 2八 と移動 (validation は無視)
      int ply = 0;
      for (final String usi in <String>['2h6h', '3a3b', '6h2h']) {
        ply += 1;
        final Move? move = p.createMoveByUSI(usi);
        expect(move, isNotNull);
        h.recordMove(move!, ply);
        p.doMove(move, ignoreValidation: true);
      }
      expect(req.isSatisfiedBy(p, Color.black, h), isTrue);
      // 後手は 4二 に飛車が居たことがないので false
      expect(req.isSatisfiedBy(p, Color.white, h), isFalse);
    });

    test('飛車が動いていなければ 6八 visited は false', () {
      const PieceVisited req = PieceVisited(6, 8, PieceType.rook);
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      // 飛車を動かさず別の駒だけ進めた局面
      int ply = 0;
      for (final String usi in <String>['7g7f', '3c3d']) {
        ply += 1;
        final Move? move = p.createMoveByUSI(usi);
        expect(move, isNotNull);
        h.recordMove(move!, ply);
        p.doMove(move, ignoreValidation: true);
      }
      expect(req.isSatisfiedBy(p, Color.black, h), isFalse);
    });
  });

  group('KingIgyoku unit', () {
    test('history == null → 常に false', () {
      const KingIgyoku req = KingIgyoku();
      final Position p = Position();
      expect(req.isSatisfiedBy(p, Color.black), isFalse);
      expect(req.isSatisfiedBy(p, Color.black, null), isFalse);
    });

    test('king まだ動いていない (kingFirstMoved=null) → true', () {
      const KingIgyoku req = KingIgyoku();
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      expect(req.isSatisfiedBy(p, Color.black, h), isTrue);
      expect(req.isSatisfiedBy(p, Color.white, h), isTrue);
    });

    test('king が outbreak 前に動いた → false (戦いが起きる前に玉が動いた)', () {
      const KingIgyoku req = KingIgyoku();
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      // 1 手目で黒玉が動く。outbreak は起きていない (capture 無し)。
      final Move? move = p.createMoveByUSI('5i6h');
      expect(move, isNotNull);
      h.recordMove(move!, 1);
      p.doMove(move, ignoreValidation: true);
      expect(req.isSatisfiedBy(p, Color.black, h), isFalse);
      // 白玉は動いていないので依然 true。
      expect(req.isSatisfiedBy(p, Color.white, h), isTrue);
    });

    test('king が outbreak 後に動いた → true', () {
      const KingIgyoku req = KingIgyoku();
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      // 銀を取る手で outbreak を起こす (capturedPieceType = silver)。
      // 手筋に縛られず、Move を直接合成して capturedPieceType を渡す。
      final Move silverCapture = Move(
        FromSquare(Square(7, 8)),
        Square(7, 1),
        false,
        Color.black,
        PieceType.bishop,
        PieceType.silver,
      );
      h.recordMove(silverCapture, 1);
      expect(h.outbreakTurn, 1);
      // その後で 玉を動かす (ply 5 とする)
      final Move kingMove = Move(
        FromSquare(Square(5, 9)),
        Square(6, 8),
        false,
        Color.black,
        PieceType.king,
        null,
      );
      h.recordMove(kingMove, 5);
      expect(h.kingFirstMovedTurn(Color.black), 5);
      // 5 >= 1 なので 居玉 = true (戦いが激しくなってから動いた)
      expect(req.isSatisfiedBy(p, Color.black, h), isTrue);
    });
  });

  group('record.castles 居玉 (KingIgyoku + game-end 評価)', () {
    test('king が動かない短い棋譜 → 居玉 は黒/白それぞれ 1 回ずつ報告 (最終 ply)', () {
      // 4 手で双方の玉が動かない → 双方とも 居玉。emit ply は最終 ply (4)。
      final Record r = Record.newByUSI('startpos moves 7g7f 3c3d 2g2f 8c8d')!;
      final List<DetectedCastleAt> ig = r.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      expect(ig.length, 2);
      expect(ig.map((DetectedCastleAt c) => c.side).toSet(),
          <Color>{Color.black, Color.white});
      // game-end 評価なので emit ply は最終 ply (= 4)。
      for (final DetectedCastleAt c in ig) {
        expect(c.ply, 4, reason: '${c.side.value} 居玉 は最終 ply で 1 回 emit');
      }
    });

    test('5九玉を動かすと黒の 居玉 は出ない (outbreak 起きない場合)', () {
      // 1 手目 5i6h: 黒玉が 5九 から動く。outbreak は起きない (capture 無し)。
      // → 黒は kingMoved=1, outbreak=null → 居玉 false。
      // 白は king 動かない → 居玉 true (emit ply は最終 ply)。
      final Record r = Record.newByUSI('startpos moves 5i6h 3c3d 7g7f 8c8d')!;
      final List<DetectedCastleAt> ig = r.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      expect(ig.any((DetectedCastleAt c) => c.side == Color.black), isFalse,
          reason: '黒玉は outbreak 前に動いたので 居玉 (黒) は出ない');
      expect(ig.any((DetectedCastleAt c) => c.side == Color.white), isTrue,
          reason: '白玉は動いていないので 居玉 (白) は出る');
    });

    test('双方の玉が outbreak 前に動く → 居玉 はどちらも発火しない', () {
      // 5i6h→5a5b→6h5i→5b5a (capture 無し) → 黒/白とも king 動いて
      // outbreak null → 双方 false。
      final Record r = Record.newByUSI('startpos moves 5i6h 5a5b 6h5i 5b5a')!;
      final List<DetectedCastleAt> ig = r.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      expect(ig.any((DetectedCastleAt c) => c.side == Color.black), isFalse,
          reason: '黒玉は outbreak 前に動いたので 居玉 (黒) は出ない');
      expect(ig.any((DetectedCastleAt c) => c.side == Color.white), isFalse,
          reason: '白玉も outbreak 前に動いたので 居玉 (白) も出ない');
    });
  });

  group('record.strategies Uターン飛車 (PieceVisited 統合)', () {
    test('初期局面のみ (飛車 2八) → Uターン飛車 は発火しない (visited 履歴なし)', () {
      // 7g7f 3c3d を指しても、黒飛車は 2八 のまま、6八/5八/4八/3八 を
      // 過去 visited していない。よって発火不可。
      final Record r = Record.newByUSI('startpos moves 7g7f 3c3d')!;
      final bool fired = r.strategies
          .any((DetectedStrategyAt s) => s.template.name == 'Uターン飛車');
      expect(fired, isFalse);
    });

    test('飛車 2八→8八→7八→6八→5八→2八 (黒) → Uターン飛車 (黒) 発火', () {
      // bioshogi Uターン飛車テンプレは visited 5/6/7/8 を要求 (★ at 5八〜8八)。
      // 黒飛車を 8八→7八→6八→5八 と通過させて最後 2八 に戻す。
      // 各 visited マスが履歴に積まれた上で現在位置 2八 を満たすので発火。
      const String usi = 'startpos moves '
          '2h8h 3c3d 8h7h 5c5d 7h6h 4c4d 6h5h 6c6d 5h2h';
      final Record? r = Record.newByUSI(usi);
      expect(r, isNotNull);
      final List<DetectedStrategyAt> hits = r!.strategies
          .where((DetectedStrategyAt s) => s.template.name == 'Uターン飛車')
          .toList();
      // 黒側で出るはず (白は普通の初期飛車のままなので発火しない)
      expect(hits.any((DetectedStrategyAt s) => s.side == Color.black), isTrue);
      expect(
          hits.any((DetectedStrategyAt s) => s.side == Color.white), isFalse);
    });

    test('飛車 2八→6八 のまま戻さない → Uターン飛車 発火しない (現在位置 ≠ 2八)', () {
      // 6八飛車のまま、四間飛車形 (R at 6,8)。PieceVisited(6,8,R) は満たすが、
      // PiecePlacement(2,8,R) を満たさないため発火しない。
      final Record r = Record.newByUSI('startpos moves 2h6h 3c3d')!;
      final bool fired = r.strategies
          .any((DetectedStrategyAt s) => s.template.name == 'Uターン飛車');
      expect(fired, isFalse);
    });
  });

  group('regression: 40 手棋譜での Uターン飛車 / 居玉 の挙動', () {
    const String usi =
        'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 '
        'moves 7g7f 3c3d 2g2f 8b4b 3i4h 5a6b 5i6h 7a7b 4i5h 6b7a 6h7h 7a8b 5g5f 9c9d '
        '2f2e 2b3c 7i6h 4c4d 6h5g 4a5b 3g3f 3a3b 9g9f 3b4c 2i3g 4c5d 6i6h 6c6d 4g4f '
        '5b6c 4h4g 7c7d 2h2i 8a7c 5g6f 8c8d 1g1f 7b8c 8h7g 6a7b';

    test('Uターン飛車 は黒/白ともに発火しない', () {
      final Record? r = Record.newByUSI(usi);
      expect(r, isNotNull);
      final List<DetectedStrategyAt> hits = r!.strategies
          .where((DetectedStrategyAt s) => s.template.name == 'Uターン飛車')
          .toList();
      expect(hits, isEmpty,
          reason: '黒は飛車が 2筋から動かず、白は 8b4b で 4二 のままなので、どちらも visited 全制約は満たさない');
    });

    test('居玉 は両陣営とも発火しない (bioshogi 同等)', () {
      // 40 手棋譜の特性:
      // - 黒は 5i6h で 11 手目に king が動く (capture 無し → outbreak 起きない)
      // - 白は 5a6b で 6 手目に king が動く (同上)
      // - 駒交換が起きていない (歩・角以外の駒が取られていない) ので
      //   outbreak_turn = null
      // 結果: 黒は kingMoved=11, outbreak=null → 居玉 false
      //       白は kingMoved=6,  outbreak=null → 居玉 false
      // 両陣営とも 居玉 は emit されない (bioshogi の挙動と一致)。
      final Record? r = Record.newByUSI(usi);
      expect(r, isNotNull);
      final List<DetectedCastleAt> hits = r!.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      expect(hits, isEmpty,
          reason: 'outbreak が起きていない + king が早期に動いた → 居玉 は両陣営とも発火しない');
    });
  });
}
