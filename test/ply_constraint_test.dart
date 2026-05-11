// ply 制約 (plyEq / plyMax) のテンプレートが正しく扱われることを検証する。
//
// 位置ベース検出 (detectCastles / detectStrategies / position.castles /
// position.strategies) は ply 情報を持たないため、制約付きテンプレートを
// **常にスキップ** する。一方、record.castles / record.strategies は各
// ply の制約を評価する。

import 'package:test/test.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/strategy.dart';

void main() {
  group('CastleTemplate ply constraint', () {
    test('hasPlyConstraint: both null → false', () {
      const CastleTemplate t = CastleTemplate(
        name: 'no-ply',
        placements: <CastleRequirement>[],
      );
      expect(t.hasPlyConstraint, isFalse);
      expect(t.satisfiesPlyConstraint(0), isTrue);
      expect(t.satisfiesPlyConstraint(100), isTrue);
    });

    test('plyEq only: matches at exact ply, fails otherwise', () {
      const CastleTemplate t = CastleTemplate(
        name: 'eq1',
        placements: <CastleRequirement>[],
        plyEq: 1,
      );
      expect(t.hasPlyConstraint, isTrue);
      expect(t.satisfiesPlyConstraint(1), isTrue);
      expect(t.satisfiesPlyConstraint(0), isFalse);
      expect(t.satisfiesPlyConstraint(2), isFalse);
    });

    test('plyMax only: matches when ply <= max', () {
      const CastleTemplate t = CastleTemplate(
        name: 'max5',
        placements: <CastleRequirement>[],
        plyMax: 5,
      );
      expect(t.hasPlyConstraint, isTrue);
      expect(t.satisfiesPlyConstraint(0), isTrue);
      expect(t.satisfiesPlyConstraint(3), isTrue);
      expect(t.satisfiesPlyConstraint(5), isTrue);
      expect(t.satisfiesPlyConstraint(6), isFalse);
      expect(t.satisfiesPlyConstraint(7), isFalse);
    });

    test('plyEq + plyMax: both must hold', () {
      const CastleTemplate t = CastleTemplate(
        name: 'eq3max10',
        placements: <CastleRequirement>[],
        plyEq: 3,
        plyMax: 10,
      );
      expect(t.satisfiesPlyConstraint(3), isTrue);
      expect(t.satisfiesPlyConstraint(2), isFalse);
      expect(t.satisfiesPlyConstraint(4), isFalse);
      // ply=3 で plyMax=10 を超えないので OK。
      // plyEq=3 が支配的だが、明示的に「両方とも満たす」セマンティクスを確認。
    });
  });

  group('StrategyTemplate ply constraint', () {
    test('hasPlyConstraint: both null → false', () {
      const StrategyTemplate t = StrategyTemplate(
        name: 'no-ply',
        placements: <CastleRequirement>[],
      );
      expect(t.hasPlyConstraint, isFalse);
    });

    test('plyEq only: matches at exact ply only', () {
      const StrategyTemplate t = StrategyTemplate(
        name: 'eq2',
        placements: <CastleRequirement>[],
        plyEq: 2,
      );
      expect(t.satisfiesPlyConstraint(2), isTrue);
      expect(t.satisfiesPlyConstraint(1), isFalse);
      expect(t.satisfiesPlyConstraint(3), isFalse);
    });

    test('plyMax only: matches when ply <= max', () {
      const StrategyTemplate t = StrategyTemplate(
        name: 'max5',
        placements: <CastleRequirement>[],
        plyMax: 5,
      );
      expect(t.satisfiesPlyConstraint(3), isTrue);
      expect(t.satisfiesPlyConstraint(5), isTrue);
      expect(t.satisfiesPlyConstraint(6), isFalse);
      expect(t.satisfiesPlyConstraint(7), isFalse);
    });

    test('plyEq + plyMax: both must hold', () {
      const StrategyTemplate t = StrategyTemplate(
        name: 'eq3max10',
        placements: <CastleRequirement>[],
        plyEq: 3,
        plyMax: 10,
      );
      expect(t.satisfiesPlyConstraint(3), isTrue);
      expect(t.satisfiesPlyConstraint(2), isFalse);
      expect(t.satisfiesPlyConstraint(4), isFalse);
    });
  });

  group('Position-based detection ignores ply-constrained templates', () {
    test('detectStrategies: 初手▲3六歩戦法 (plyEq:1) は position だけでは発火しない', () {
      // 初手▲3六歩戦法 は plyEq: 1 を持つ実テンプレ。盤面だけ作っても
      // position ベース検出ではスキップされる。
      final Position position = Position();
      position.reset(InitialPositionType.empty);
      position.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      position.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      // 3六 = file 3, rank 6 に先手の歩を置く
      position.board.set(Square(3, 6), Piece(Color.black, PieceType.pawn));
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      final bool fired = result.any(
        (DetectedStrategy d) => d.template.name == '初手▲3六歩戦法',
      );
      expect(fired, isFalse, reason: 'plyEq 制約付きテンプレートは position 検出ではマッチしない');
    });

    test('detectCastles: ply 制約付きテンプレートは position だけでは発火しない', () {
      // ply 制約付きの castle テンプレを実データから探し、対応する盤面を
      // 作って position 検出ではスキップされることを確認する。
      final CastleTemplate? plyTemplate = knownCastles
          .where((CastleTemplate t) => t.hasPlyConstraint)
          .cast<CastleTemplate?>()
          .firstWhere((CastleTemplate? _) => true, orElse: () => null);
      if (plyTemplate == null) return; // 対応テンプレが無ければスキップ
      // テンプレ通りの盤面を作って position 検出すれば、通常なら発火する
      // 形でも plyTemplate.hasPlyConstraint であればスキップされるはず。
      final Position position = Position();
      position.reset(InitialPositionType.empty);
      position.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      // テンプレ placements を黒視点で配置 (簡易版)
      for (final CastleRequirement r in plyTemplate.placements) {
        if (r is PiecePlacement) {
          position.board
              .set(Square(r.file, r.rank), Piece(Color.black, r.pieceType));
        }
      }
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      final bool fired = result.any(
        (DetectedCastle d) => d.template.name == plyTemplate.name,
      );
      expect(fired, isFalse,
          reason: 'plyEq/plyMax 付き castle は position 検出ではマッチしない');
    });
  });

  group('Record-based detection enforces ply constraints', () {
    test('plyEq:1 の戦法は ply=1 で発火 (初手▲3六歩戦法)', () {
      // 初手▲3六歩戦法: plyEq: 1, placements: PiecePlacement(3, 6, pawn)
      // 平手から 3g3f を指すと ply=1 で 3六に黒歩が来るのでマッチする。
      final Record? record = Record.newByUSI('startpos moves 3g3f');
      expect(record, isNotNull);
      final List<DetectedStrategyAt> hits = record!.strategies
          .where((DetectedStrategyAt s) => s.template.name == '初手▲3六歩戦法')
          .toList();
      expect(hits.length, 1);
      expect(hits.single.ply, 1);
      expect(hits.single.side, Color.black);
    });

    test('plyEq:1 戦法は 後ろの ply で同形になっても再発火しない (first-occurrence)', () {
      // first-occurrence は (テンプレ名, 陣営) 単位なので、ply=1 で既に検出
      // 済みなら以降は seen に登録され重複検出されない。
      final Record? record = Record.newByUSI('startpos moves 3g3f 8c8d');
      expect(record, isNotNull);
      // ply=1 で 初手▲3六歩戦法 が出ているはず。ply=2 以降は出ない。
      final List<DetectedStrategyAt> hits = record!.strategies
          .where((DetectedStrategyAt s) => s.template.name == '初手▲3六歩戦法')
          .toList();
      expect(hits.length, 1);
      expect(hits.single.ply, 1);
    });

    test('plyEq:1 戦法は形だけ後で再現しても発火しない (中盤で 3六歩配置になっても)', () {
      // 平手から 7g7f → 3g3f と指す: ply=1 では 3六に歩なし (7六歩のみ)、
      // ply=3 で 3六に歩が来るが plyEq=1 なので発火してはいけない。
      final Record? record = Record.newByUSI('startpos moves 7g7f 3c3d 3g3f');
      expect(record, isNotNull);
      final List<DetectedStrategyAt> hits = record!.strategies
          .where((DetectedStrategyAt s) => s.template.name == '初手▲3六歩戦法')
          .toList();
      expect(hits, isEmpty, reason: 'plyEq=1 なので ply=3 で同形になっても発火しない');
    });

    test('plyEq:0 (初期局面) のテンプレが存在しない場合のサニティ', () {
      // 初期局面でしか発火しない戦法は無いが、Uターン飛車などは平手の
      // 初期局面 (ply=0) で発火する例である。これは plyEq:null なので
      // ply=0 でも検出される。
      final Record? record = Record.newByUSI('startpos');
      expect(record, isNotNull);
      // 平手初期では plyEq 制約付きテンプレートは ply=0 でマッチしない
      // ことを確認 (実テンプレで plyEq:0 が無い前提)。
      final List<DetectedStrategyAt> all = record!.strategies;
      for (final DetectedStrategyAt s in all) {
        if (s.template.plyEq != null) {
          expect(s.ply, s.template.plyEq,
              reason: '${s.template.name}: 検出 ply は plyEq と一致するはず');
        }
        if (s.template.plyMax != null) {
          expect(s.ply <= s.template.plyMax!, isTrue,
              reason:
                  '${s.template.name}: 検出 ply は plyMax 以下のはず (ply=${s.ply} max=${s.template.plyMax})');
        }
      }
    });
  });

  group('regression: 40-move 四間飛車', () {
    // 元バグ: 「初手▲3六歩戦法」「2手目△7四歩戦法」「3手目▲7七角戦法」
    // 「4手目△3三角戦法」が中盤の同形局面で誤発火していた。
    // ply 制約が import された今は発火してはいけない。
    test('「初手▲」「2手目△」「3手目▲」「4手目△」 が 21/32/16/39 で発火しない', () {
      const String usi =
          'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 '
          'moves 7g7f 3c3d 2g2f 8b4b 3i4h 5a6b 5i6h 7a7b 4i5h 6b7a 6h7h 7a8b 5g5f 9c9d '
          '2f2e 2b3c 7i6h 4c4d 6h5g 4a5b 3g3f 3a3b 9g9f 3b4c 2i3g 4c5d 6i6h 6c6d 4g4f '
          '5b6c 4h4g 7c7d 2h2i 8a7c 5g6f 8c8d 1g1f 7b8c 8h7g 6a7b';
      final Record? record = Record.newByUSI(usi);
      expect(record, isNotNull);
      final List<String> opening = <String>[
        '初手▲3六歩戦法',
        '2手目△7四歩戦法',
        '3手目▲7七角戦法',
        '4手目△3三角戦法',
        '2手目△6二銀戦法',
      ];
      for (final String name in opening) {
        final List<DetectedStrategyAt> hits = record!.strategies
            .where((DetectedStrategyAt s) => s.template.name == name)
            .toList();
        for (final DetectedStrategyAt h in hits) {
          // 仮に検出されたとしても、テンプレの plyEq と完全一致すること
          // (中盤の 21/32/16/39 のような ply では発火しない)。
          expect(h.template.plyEq, isNotNull,
              reason: '$name: plyEq 制約が無い (import 失敗?)');
          expect(h.ply, h.template.plyEq, reason: '$name: 検出 ply 不一致');
        }
      }
    });
  });
}
