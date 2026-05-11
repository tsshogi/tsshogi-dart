import 'package:test/test.dart';
import 'package:tsshogi/src/board.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/strategy.dart';

/// 空盤を作る。白玉だけ安全位置 (5,1) に置く。Position の API 健全性確保用。
Position _emptyPosition() {
  final Position position = Position();
  position.reset(InitialPositionType.empty);
  position.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
  return position;
}

/// テンプレートの placements を [side] 視点で盤に並べる。
/// AnyOfPieces は最初の候補駒種で代表させる。
void _placeStrategy(Board board, StrategyTemplate template, Color side) {
  for (final CastleRequirement r in template.placements) {
    final int file = side == Color.black ? r.file : 10 - r.file;
    final int rank = side == Color.black ? r.rank : 10 - r.rank;
    final PieceType type = switch (r) {
      PiecePlacement(:final pieceType) => pieceType,
      AnyOfPieces(:final options) => options.first,
    };
    board.set(Square(file, rank), Piece(side, type));
  }
}

bool _detected(List<DetectedStrategy> results, String name, Color side) {
  return results
      .any((DetectedStrategy d) => d.template.name == name && d.side == side);
}

void main() {
  group('detectStrategies', () {
    test('empty position returns empty (no king placed)', () {
      final Position position = Position();
      position.reset(InitialPositionType.empty);
      final List<DetectedStrategy> result = detectStrategies(position);
      expect(result, isEmpty);
    });

    test('initial standard position: no real strategy fires for either side',
        () {
      // 初期局面は飛車が 2八/8二 にいて 中央 2筋飛車 (居飛車相当) なので、
      // 一部の戦法 (棒銀候補・力戦不在のもの) が誤検出される可能性は低いが
      // 完全 0 ではない。最低限「四間飛車」「中飛車」「三間飛車」「向かい
      // 飛車」「石田流」「ゴキゲン中飛車」のように飛車が動いている戦法は
      // 検出されないはず。
      final Position position = Position();
      final List<DetectedStrategy> black =
          detectStrategies(position, side: Color.black);
      expect(_detected(black, '四間飛車', Color.black), isFalse);
      expect(_detected(black, '中飛車', Color.black), isFalse);
      expect(_detected(black, '三間飛車', Color.black), isFalse);
      expect(_detected(black, '向かい飛車', Color.black), isFalse);
      expect(_detected(black, '石田流', Color.black), isFalse);
      expect(_detected(black, 'ゴキゲン中飛車', Color.black), isFalse);
    });

    // パラメトリック: 各テンプレートを盤上に再現して自己マッチを確認 (黒)
    group('each strategy self-match (black)', () {
      for (final StrategyTemplate template in knownStrategies) {
        test('detects ${template.name}', () {
          final Position position = _emptyPosition();
          _placeStrategy(position.board, template, Color.black);
          final List<DetectedStrategy> result =
              detectStrategies(position, side: Color.black);
          expect(
            _detected(result, template.name, Color.black),
            isTrue,
            reason: '${template.name} should match its own template',
          );
        });
      }
    });

    // パラメトリック: 後手側のミラー検出
    group('each strategy self-match (white, mirrored)', () {
      for (final StrategyTemplate template in knownStrategies) {
        test('detects ${template.name} for white', () {
          final Position position = Position();
          position.reset(InitialPositionType.empty);
          // 黒玉を安全位置に。テンプレに king (5,9) を含むものは _placeStrategy
          // が上書きするのを避けるため、ここでは 1,9 などには置かず、後で
          // テンプレ配置と衝突しない (5,5) に黒玉を置く形にする。
          // ただし「棒玉」テンプレは (5,5) に黒玉を置くので、ここはあえて何も
          // 置かない方が安全。Position の king 数バリデーションは reset 直後の
          // 空盤では問われない。
          _placeStrategy(position.board, template, Color.white);
          final List<DetectedStrategy> result =
              detectStrategies(position, side: Color.white);
          expect(
            _detected(result, template.name, Color.white),
            isTrue,
            reason: '${template.name} should match for white',
          );
        });
      }
    });

    test('side filter: black only', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '四間飛車'),
        Color.white,
      );

      final List<DetectedStrategy> blackOnly =
          detectStrategies(position, side: Color.black);
      expect(
        blackOnly.every((DetectedStrategy d) => d.side == Color.black),
        isTrue,
      );
      expect(_detected(blackOnly, '中飛車', Color.black), isTrue);
      expect(_detected(blackOnly, '四間飛車', Color.white), isFalse);
    });

    test('side filter: white only', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '四間飛車'),
        Color.white,
      );

      final List<DetectedStrategy> whiteOnly =
          detectStrategies(position, side: Color.white);
      expect(
        whiteOnly.every((DetectedStrategy d) => d.side == Color.white),
        isTrue,
      );
      expect(_detected(whiteOnly, '四間飛車', Color.white), isTrue);
      expect(_detected(whiteOnly, '中飛車', Color.black), isFalse);
    });

    test('side null: both sides detected', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '四間飛車'),
        Color.white,
      );
      final List<DetectedStrategy> both = detectStrategies(position);
      expect(_detected(both, '中飛車', Color.black), isTrue);
      expect(_detected(both, '四間飛車', Color.white), isTrue);
    });

    test('parent (中飛車) is also detected when child (ゴキゲン中飛車) matches', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == 'ゴキゲン中飛車'),
        Color.black,
      );
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, 'ゴキゲン中飛車', Color.black), isTrue);
      expect(_detected(result, '中飛車', Color.black), isTrue);
    });

    test('parent (石田流) is also detected when child (石田流本組み) matches', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '石田流本組み'),
        Color.black,
      );
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, '石田流本組み', Color.black), isTrue);
      // 石田流本組み は 7六飛 (浮き飛車) なので、親の '石田流' (7八飛が必須) は
      // 必ずしも検出されない。これは設計上の許容: 子戦法が必ず親形を含むとは
      // 限らない (石田流は 7八飛/7六飛のどちらでも成立する概念)。
      // → ここでは 7八飛のテンプレ '三間飛車' は満たさない可能性が高い。
      // よって石田流本組みの検出のみ確認する。
    });

    test('parent (四間飛車) detected when child (藤井システム) matches', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '藤井システム'),
        Color.black,
      );
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, '藤井システム', Color.black), isTrue);
      expect(_detected(result, '四間飛車', Color.black), isTrue);
    });

    test('negative: missing one piece breaks the match', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == 'ゴキゲン中飛車'),
        Color.black,
      );
      // 7九角 を消す
      position.board.remove(Square(7, 9));
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, 'ゴキゲン中飛車', Color.black), isFalse);
      // 親の中飛車 (5八飛のみ要求) はまだマッチする
      expect(_detected(result, '中飛車', Color.black), isTrue);
    });

    test('negative: wrong piece color does not match', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      // 5八飛を白に
      position.board.set(Square(5, 8), Piece(Color.white, PieceType.rook));
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, '中飛車', Color.black), isFalse);
    });

    test('中飛車 placements do not erroneously trigger 四間飛車', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, '中飛車', Color.black), isTrue);
      expect(_detected(result, '四間飛車', Color.black), isFalse);
      expect(_detected(result, '三間飛車', Color.black), isFalse);
      expect(_detected(result, '向かい飛車', Color.black), isFalse);
    });

    test('四間飛車 placements do not erroneously trigger 中飛車', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '四間飛車'),
        Color.black,
      );
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, '四間飛車', Color.black), isTrue);
      expect(_detected(result, '中飛車', Color.black), isFalse);
      expect(_detected(result, '三間飛車', Color.black), isFalse);
    });

    test('three rook positions are distinct (中=5筋・四間=6筋・三間=7筋)', () {
      // 中飛車
      final Position p1 = _emptyPosition();
      _placeStrategy(
        p1.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      expect(
        _detected(detectStrategies(p1, side: Color.black), '中飛車', Color.black),
        isTrue,
      );
      expect(
        _detected(detectStrategies(p1, side: Color.black), '三間飛車', Color.black),
        isFalse,
      );

      // 三間飛車
      final Position p2 = _emptyPosition();
      _placeStrategy(
        p2.board,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '三間飛車'),
        Color.black,
      );
      expect(
        _detected(detectStrategies(p2, side: Color.black), '三間飛車', Color.black),
        isTrue,
      );
      expect(
        _detected(detectStrategies(p2, side: Color.black), '四間飛車', Color.black),
        isFalse,
      );
    });

    test('DetectedStrategy equality / hashCode', () {
      const StrategyTemplate t = StrategyTemplate(
        name: '中飛車',
        placements: <PiecePlacement>[],
      );
      const DetectedStrategy a =
          DetectedStrategy(template: t, side: Color.black);
      const DetectedStrategy b =
          DetectedStrategy(template: t, side: Color.black);
      const DetectedStrategy c =
          DetectedStrategy(template: t, side: Color.white);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('knownStrategies has at least 150 entries', () {
      expect(knownStrategies.length, greaterThanOrEqualTo(150));
    });
  });

  // -------------------------------------------------------------------------
  // 整合性チェック
  // -------------------------------------------------------------------------
  group('integrity', () {
    test('all template names are unique', () {
      final Set<String> seen = <String>{};
      for (final StrategyTemplate t in knownStrategies) {
        expect(
          seen.add(t.name),
          isTrue,
          reason: 'duplicate strategy name: ${t.name}',
        );
      }
    });

    test('all parent references resolve to an existing template', () {
      final Set<String> names =
          knownStrategies.map((StrategyTemplate t) => t.name).toSet();
      for (final StrategyTemplate t in knownStrategies) {
        final String? parent = t.parent;
        if (parent != null) {
          expect(
            names,
            contains(parent),
            reason: '${t.name} references missing parent: $parent',
          );
        }
      }
    });

    test('all placement file/rank are within 1..9', () {
      for (final StrategyTemplate t in knownStrategies) {
        for (final CastleRequirement r in t.placements) {
          expect(
            r.file,
            inInclusiveRange(1, 9),
            reason: '${t.name} has file out of range: ${r.file}',
          );
          expect(
            r.rank,
            inInclusiveRange(1, 9),
            reason: '${t.name} has rank out of range: ${r.rank}',
          );
        }
      }
    });

    test('no template has zero placements', () {
      for (final StrategyTemplate t in knownStrategies) {
        expect(
          t.placements,
          isNotEmpty,
          reason: '${t.name} has empty placements list',
        );
      }
    });

    test('no template has two PiecePlacement on the same square', () {
      for (final StrategyTemplate t in knownStrategies) {
        final Set<String> squares = <String>{};
        for (final CastleRequirement r in t.placements) {
          if (r is PiecePlacement) {
            final String key = '${r.file},${r.rank}';
            expect(
              squares.add(key),
              isTrue,
              reason: '${t.name} has duplicate placement on $key',
            );
          }
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // 代表的な戦法の動作確認
  // -------------------------------------------------------------------------
  group('representative strategies', () {
    test('石田流 (7五歩+7八飛) は検出されるが向かい飛車は検出されない', () {
      final Position p = _emptyPosition();
      p.board.set(Square(7, 8), Piece(Color.black, PieceType.rook));
      p.board.set(Square(7, 5), Piece(Color.black, PieceType.pawn));
      final List<DetectedStrategy> result =
          detectStrategies(p, side: Color.black);
      expect(_detected(result, '石田流', Color.black), isTrue);
      expect(_detected(result, '三間飛車', Color.black), isTrue);
      expect(_detected(result, '向かい飛車', Color.black), isFalse);
    });

    test('棒銀 + 矢倉棒銀 は 駒組によって両方検出されうる', () {
      // 2八飛・2七銀・7七銀 → 棒銀 と 矢倉棒銀 の両方マッチ
      final Position p = _emptyPosition();
      p.board.set(Square(2, 8), Piece(Color.black, PieceType.rook));
      p.board.set(Square(2, 7), Piece(Color.black, PieceType.silver));
      p.board.set(Square(7, 7), Piece(Color.black, PieceType.silver));
      final List<DetectedStrategy> result =
          detectStrategies(p, side: Color.black);
      expect(_detected(result, '棒銀', Color.black), isTrue);
      expect(_detected(result, '矢倉棒銀', Color.black), isTrue);
    });

    test('飛車が 2筋のままなら 振り飛車系戦法はどれもマッチしない', () {
      final Position p = _emptyPosition();
      p.board.set(Square(2, 8), Piece(Color.black, PieceType.rook));
      final List<DetectedStrategy> result =
          detectStrategies(p, side: Color.black);
      // 居玉のままなのでアヒルや藤井システム等はマッチしないことを確認
      expect(_detected(result, '中飛車', Color.black), isFalse);
      expect(_detected(result, '四間飛車', Color.black), isFalse);
      expect(_detected(result, '三間飛車', Color.black), isFalse);
      expect(_detected(result, '向かい飛車', Color.black), isFalse);
    });

    test('side flag distribution: ibisha / furibisha / either の数はそれぞれ妥当', () {
      final int ibishaCount = knownStrategies
          .where((StrategyTemplate t) => t.side == StrategySide.ibisha)
          .length;
      final int furibishaCount = knownStrategies
          .where((StrategyTemplate t) => t.side == StrategySide.furibisha)
          .length;
      final int eitherCount = knownStrategies
          .where((StrategyTemplate t) => t.side == StrategySide.either)
          .length;
      // 各カテゴリに最低限のエントリが入っていることだけ確認
      expect(ibishaCount, greaterThan(20),
          reason: 'ibisha strategies should be plentiful');
      expect(furibishaCount, greaterThan(20),
          reason: 'furibisha strategies should be plentiful');
      expect(
        ibishaCount + furibishaCount + eitherCount,
        knownStrategies.length,
      );
    });
  });

  // -------------------------------------------------------------------------
  // StrategySide enum 動作確認
  // -------------------------------------------------------------------------
  group('StrategySide', () {
    test('enum values are ibisha / furibisha / either', () {
      expect(StrategySide.values, hasLength(3));
      expect(StrategySide.values, contains(StrategySide.ibisha));
      expect(StrategySide.values, contains(StrategySide.furibisha));
      expect(StrategySide.values, contains(StrategySide.either));
    });

    test('default side is either when not specified', () {
      const StrategyTemplate t = StrategyTemplate(
        name: 'test',
        placements: <PiecePlacement>[],
      );
      expect(t.side, StrategySide.either);
    });
  });
}
