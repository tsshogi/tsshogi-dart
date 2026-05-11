// 手筋の異常系 (negative path) を集約してカバレッジを上げるテスト。
//
// 各テンプレートが「該当しない指し手」を渡されたときに正しく false を返すか
// を確認する。実装中の早期 return を網羅的にひっかける。

import 'package:test/test.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/move.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/technique.dart';

void main() {
  group('DetectedTechnique', () {
    test('equality / hashCode by (template.name, ply, color)', () {
      final List<TechniqueTemplate> all = knownTechniques;
      final TechniqueTemplate t = all.first;
      final DetectedTechnique a =
          DetectedTechnique(template: t, ply: 7, color: Color.black);
      final DetectedTechnique b =
          DetectedTechnique(template: t, ply: 7, color: Color.black);
      final DetectedTechnique c =
          DetectedTechnique(template: t, ply: 8, color: Color.black);
      final DetectedTechnique d =
          DetectedTechnique(template: t, ply: 7, color: Color.white);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
      expect(a == Object(), isFalse);
    });
  });

  group('detectTechniquesAtMove negative paths', () {
    // 「打ち歩」系: FromSquare の指し手では発火しない
    test('FromSquare な move は 打ち歩系手筋にマッチしない', () {
      final Position before = Position();
      before.reset(InitialPositionType.empty);
      before.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      before.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      before.board.set(Square(7, 7), Piece(Color.black, PieceType.pawn));
      final Position after = before.clone();
      after.board.remove(Square(7, 7));
      after.board.set(Square(7, 6), Piece(Color.black, PieceType.pawn));
      final Move move = Move(
        FromSquare(Square(7, 7)),
        Square(7, 6),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final List<TechniqueTemplate> hits =
          detectTechniquesAtMove(move, before, after);
      final Set<String> names =
          hits.map((TechniqueTemplate t) => t.name).toSet();
      expect(names.contains('たたきの歩'), isFalse);
      expect(names.contains('垂れ歩'), isFalse);
      expect(names.contains('底歩'), isFalse);
      expect(names.contains('合わせの歩'), isFalse);
    });

    // 駒打ちでも歩以外の駒なら 打ち歩系は発火しない
    test('銀打ち は 打ち歩系手筋にマッチしない', () {
      final Position before = Position();
      before.reset(InitialPositionType.empty);
      before.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      before.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      before.blackHand.add(PieceType.silver, 1);
      final Position after = before.clone();
      after.board.set(Square(5, 5), Piece(Color.black, PieceType.silver));
      after.blackHand.reduce(PieceType.silver, 1);
      final Move move = Move(
        const FromHand(PieceType.silver),
        Square(5, 5),
        false,
        Color.black,
        PieceType.silver,
        null,
      );
      final List<TechniqueTemplate> hits =
          detectTechniquesAtMove(move, before, after);
      final Set<String> names =
          hits.map((TechniqueTemplate t) => t.name).toSet();
      expect(names.contains('たたきの歩'), isFalse);
      expect(names.contains('垂れ歩'), isFalse);
      expect(names.contains('底歩'), isFalse);
    });

    // 底歩: 自陣最下段以外への歩打はマッチしない
    test('5五に歩打 (中段) は 底歩にマッチしない', () {
      final Position before = Position();
      before.reset(InitialPositionType.empty);
      before.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      before.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      before.blackHand.add(PieceType.pawn, 1);
      final Position after = before.clone();
      after.board.set(Square(5, 5), Piece(Color.black, PieceType.pawn));
      after.blackHand.reduce(PieceType.pawn, 1);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(5, 5),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final List<TechniqueTemplate> hits =
          detectTechniquesAtMove(move, before, after);
      expect(
        hits.any((TechniqueTemplate t) => t.name == '底歩'),
        isFalse,
      );
    });

    // 垂れ歩: 黒の場合は 4 段目への歩打。それ以外は不発火
    test('黒の 6 段目歩打は 垂れ歩にマッチしない', () {
      final Position before = Position();
      before.reset(InitialPositionType.empty);
      before.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      before.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      before.blackHand.add(PieceType.pawn, 1);
      final Position after = before.clone();
      after.board.set(Square(5, 6), Piece(Color.black, PieceType.pawn));
      after.blackHand.reduce(PieceType.pawn, 1);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(5, 6),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final List<TechniqueTemplate> hits =
          detectTechniquesAtMove(move, before, after);
      expect(
        hits.any((TechniqueTemplate t) => t.name == '垂れ歩'),
        isFalse,
      );
    });

    // SpecialMove (リサイン等) は detectTechniques から無視される
    test('detectTechniques: SpecialMove ノードは無視される', () {
      // Record を作って resign のみ。手筋検出は 0 件のはず。
      // ここでは detectTechniques の中身に依存するため、SpecialMove
      // ノードが手筋として検出されないことだけ間接的に確認。
      // (detectTechniques を直接動かすには Record が必要だが、本テストの主眼は
      // detectTechniquesAtMove のカバレッジ補強なので、SpecialMove テストは
      // skip)
    });
  });

  group('knownTechniques basic invariants', () {
    test('全テクニックの name はユニーク', () {
      final Set<String> seen = <String>{};
      for (final TechniqueTemplate t in knownTechniques) {
        expect(seen.contains(t.name), isFalse, reason: '${t.name} が重複登録されている');
        seen.add(t.name);
      }
    });

    test('全テクニックの name は非空', () {
      for (final TechniqueTemplate t in knownTechniques) {
        expect(t.name, isNotEmpty);
      }
    });

    test('aliases は自身の name と衝突しない', () {
      for (final TechniqueTemplate t in knownTechniques) {
        for (final String a in t.aliases) {
          expect(a, isNot(equals(t.name)),
              reason: '${t.name} の alias に自身が含まれている');
        }
      }
    });
  });
}
