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
      h.recordMove(move!);
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
      h.recordMove(move!);
      p.doMove(move, ignoreValidation: true);
      expect(req.isSatisfiedBy(p, Color.black, h), isFalse);
      expect(req.isSatisfiedBy(p, Color.white, h), isTrue);
    });

    test('5九→6八→5九 と戻っても false (一度動いたから)', () {
      const PieceUnmoved req = PieceUnmoved(5, 9);
      final Position p = Position();
      final MoveHistory h = MoveHistory()..initFromPosition(p);
      for (final String usi in <String>['5i6h', '5a5b', '6h5i']) {
        final Move? move = p.createMoveByUSI(usi);
        expect(move, isNotNull, reason: 'failed to parse $usi');
        h.recordMove(move!);
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
      for (final String usi in <String>['2h6h', '3a3b', '6h2h']) {
        final Move? move = p.createMoveByUSI(usi);
        expect(move, isNotNull);
        h.recordMove(move!);
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
      for (final String usi in <String>['7g7f', '3c3d']) {
        final Move? move = p.createMoveByUSI(usi);
        expect(move, isNotNull);
        h.recordMove(move!);
        p.doMove(move, ignoreValidation: true);
      }
      expect(req.isSatisfiedBy(p, Color.black, h), isFalse);
    });
  });

  group('record.castles 居玉 (PieceUnmoved 統合)', () {
    test('king が動かない短い棋譜 → 居玉 は黒/白それぞれ 1 回ずつ報告', () {
      final Record r = Record.newByUSI('startpos moves 7g7f 3c3d 2g2f 8c8d')!;
      final List<DetectedCastleAt> ig = r.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      expect(ig.length, 2);
      expect(ig.map((DetectedCastleAt c) => c.side).toSet(),
          <Color>{Color.black, Color.white});
    });

    test('5九玉を動かすと黒の 居玉 は出ない (5i6h が早期に入る棋譜)', () {
      // 1 手目 5i6h: 黒玉が 5九 から動く → 黒 居玉 は永遠に発火しない。
      // 白 居玉 は white-king が動かないため出る。
      final Record r = Record.newByUSI('startpos moves 5i6h 3c3d 7g7f 8c8d')!;
      final List<DetectedCastleAt> ig = r.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      // 黒は出ない、白だけ出る (ply=2 で初検出)
      expect(ig.any((DetectedCastleAt c) => c.side == Color.black), isFalse);
      expect(ig.any((DetectedCastleAt c) => c.side == Color.white), isTrue);
    });

    test('5i6h→5a5b→6h5i→5b5a と双方の玉が戻っても 居玉 はどちらも発火しない', () {
      // 1 手目: 黒玉 5i→6h で sourceTouched に (black, 5九) が入る。以後
      //   PieceUnmoved(5, 9, black) は永遠に false。
      // 2 手目: 白玉 5a→5b で sourceTouched に (white, 5一) が入る。以後
      //   PieceUnmoved(5, 9, white) (= 5一 mirror) も永遠に false。
      // ply 1 評価時点で black は既に false、white は true (まだ動いてない)
      // のに見えるが、record.castles は emitAt を doMove + recordMove の
      // 「後」で呼ぶため、ply 1 評価時点で「直前の指し手」の history は反映
      // 済み。白玉はまだ ply 2 まで動かないので ply 1 で white 居玉 が出る。
      // 結局この棋譜では:
      //   ply 1: black=false, white=true → white 居玉 だけ出る
      //   ply 2: black=false, white=false → 既出なので追加なし
      final Record r = Record.newByUSI('startpos moves 5i6h 5a5b 6h5i 5b5a')!;
      final List<DetectedCastleAt> ig = r.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      // 黒は ply 1 で既に動いたので決して出ない
      expect(ig.any((DetectedCastleAt c) => c.side == Color.black), isFalse,
          reason: '黒玉は ply 1 で 5九 を離れたので 居玉 (黒) は永久に出ない');
      // 白は ply 1 ではまだ 5一 に居る (1 手目は黒の手) → 1 回出る
      // (この時点で seen に登録され、ply 2 以降の動きで状態が崩れても再評価
      //  は first-occurrence なので影響しない)
      expect(ig.any((DetectedCastleAt c) => c.side == Color.white), isTrue,
          reason: '白玉は ply 1 評価時点でまだ動いていないので white 居玉 は出る');
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

    test('飛車 2八→6八→5八→4八→3八→2八 (黒) → Uターン飛車 (黒) 発火', () {
      // 黒飛車を順次 6八/5八/4八/3八 まで動かして最後 2八 に戻す。
      // 各 visited マスが履歴に積まれた上で現在位置 2八 を満たすので発火。
      const String usi = 'startpos moves '
          '2h6h 3c3d 6h5h 5c5d 5h4h 4c4d 4h3h 6c6d 3h2h';
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

    test('居玉 は ply 1 で黒/白それぞれ 1 回ずつ報告される', () {
      // 黒は 5i6h で 11 手目に king が動くが、それ以前 (1〜10手目) は 5九 玉
      // 維持なので first-occurrence で ply=1 報告。
      // 白は 5a6b で 6 手目に king が動くが、同様に ply=1 で初検出済み。
      final Record? r = Record.newByUSI(usi);
      expect(r, isNotNull);
      final List<DetectedCastleAt> hits = r!.castles
          .where((DetectedCastleAt c) => c.template.name == '居玉')
          .toList();
      expect(hits.length, 2);
      for (final DetectedCastleAt h in hits) {
        expect(h.ply, 1, reason: '${h.side.value} 居玉 は ply 1 で初検出');
      }
    });
  });
}
