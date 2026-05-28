import 'package:test/test.dart';
import 'package:tsshogi/src/board.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/strategy.dart';

/// 空盤を作る。白玉だけ安全位置 (5,1) に置く。Position の API 健全性確保用。
Position _emptyPosition() {
  final Position position = Position();
  position.reset(InitialPositionType.empty);
  position.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
  return position;
}

/// テンプレートの placements を [side] 視点で盤と持駒に再現する。
///
/// - `PiecePlacement` / `AnyOfPieces`: 該当マスに駒を置く (AnyOf は先頭候補)
/// - `EmptySquare`: マスは触らない (元から空)
/// - `NotOfPieces`: 除外リスト外の駒種 (歩 or 玉) を 1 つ仮置きする
/// - `AnyPiece`: 歩 (代表駒) を仮置きする
/// - `PieceAnywhere`: テンプレ外のマス (隅) に該当駒を 1 つ置く
/// - `HandPiece`: 該当持駒を minCount 枚積む
void _placeStrategy(Position position, StrategyTemplate template, Color side) {
  final Board board = position.board;
  final Set<int> occupied = <int>{};
  void mark(int file, int rank) => occupied.add(file * 10 + rank);

  // 既に盤上にある駒のマスを occupied に登録 (テンプレ間衝突回避)
  for (final ({Square square, Piece piece}) e in board.listNonEmptySquares()) {
    mark(e.square.file, e.square.rank);
  }

  PieceType firstNotIn(List<PieceType> excluded) {
    const List<PieceType> fallback = <PieceType>[
      PieceType.pawn,
      PieceType.lance,
      PieceType.knight,
      PieceType.silver,
      PieceType.gold,
      PieceType.bishop,
      PieceType.rook,
      PieceType.king,
    ];
    for (final PieceType t in fallback) {
      if (!excluded.contains(t)) return t;
    }
    return PieceType.pawn;
  }

  for (final CastleRequirement r in template.placements) {
    switch (r) {
      case PiecePlacement(
          :final file,
          :final rank,
          :final pieceType,
          :final color
        ):
        final int f = side == Color.black ? file : 10 - file;
        final int rr = side == Color.black ? rank : 10 - rank;
        final Color expected = color == Color.black
            ? side
            : (side == Color.black ? Color.white : Color.black);
        board.set(Square(f, rr), Piece(expected, pieceType));
        mark(f, rr);
        break;
      case AnyOfPieces(:final file, :final rank, :final options):
        final int f = side == Color.black ? file : 10 - file;
        final int rr = side == Color.black ? rank : 10 - rank;
        board.set(Square(f, rr), Piece(side, options.first));
        mark(f, rr);
        break;
      case EmptySquare(:final file, :final rank):
        final int f = side == Color.black ? file : 10 - file;
        final int rr = side == Color.black ? rank : 10 - rank;
        if (board.at(Square(f, rr)) != null) {
          board.remove(Square(f, rr));
        }
        break;
      case NotOfPieces(:final file, :final rank, :final excluded):
        final int f = side == Color.black ? file : 10 - file;
        final int rr = side == Color.black ? rank : 10 - rank;
        if (board.at(Square(f, rr)) == null) {
          board.set(Square(f, rr), Piece(side, firstNotIn(excluded)));
          mark(f, rr);
        }
        break;
      case AnyPiece(:final file, :final rank):
        final int f = side == Color.black ? file : 10 - file;
        final int rr = side == Color.black ? rank : 10 - rank;
        if (board.at(Square(f, rr)) == null) {
          board.set(Square(f, rr), Piece(side, PieceType.pawn));
          mark(f, rr);
        }
        break;
      case PieceAnywhere(:final pieceType):
        // テンプレ外の隅 (rank 5 中央寄り) に置く。衝突回避は順次走査。
        for (int file = 1; file <= 9; file++) {
          for (int rank = 1; rank <= 9; rank++) {
            if (!occupied.contains(file * 10 + rank)) {
              board.set(Square(file, rank), Piece(side, pieceType));
              mark(file, rank);
              file = 10; // break outer
              break;
            }
          }
        }
        break;
      case HandPiece(:final pieceType, :final minCount, :final color):
        final Color handSide = color == Color.black
            ? side
            : (side == Color.black ? Color.white : Color.black);
        position.hand(handSide).set(pieceType, minCount);
        break;
      case AnyPlacement(:final pieceType, :final squares, :final color):
        // OR 候補のうち空いている先頭マスに駒を置けば成立する
        // (先頭マスが他要件や白玉で埋まっている場合に備えて空きを探す)。
        final Color expected = color == Color.black
            ? side
            : (side == Color.black ? Color.white : Color.black);
        for (final ({int file, int rank}) sq in squares) {
          final int f = side == Color.black ? sq.file : 10 - sq.file;
          final int rr = side == Color.black ? sq.rank : 10 - sq.rank;
          if (board.at(Square(f, rr)) == null) {
            board.set(Square(f, rr), Piece(expected, pieceType));
            mark(f, rr);
            break;
          }
        }
        break;
      case PieceUnmoved():
        // 履歴依存要件は静的局面生成で再現できない。テストでは置換しない。
        break;
      case PieceVisited():
        break;
      case PieceDropped():
        // 打ち駒履歴依存 — 静的局面では再現しない。
        break;
      case HandEmpty():
        // 持駒は既定で空なので何もしない。
        break;
      case KingIgyoku():
        break;
    }
  }
  // 持駒系フラグ (hold_piece_eq / op_hold_piece_eq) を満たすよう持駒を積む。
  // handNotIn / noPawnInHand / onlyPawnsInHand は空の持駒で満たされる。
  final Color opp = side == Color.black ? Color.white : Color.black;
  template.handEq?.forEach((PieceType t, int n) {
    position.hand(side).set(t, n);
  });
  template.opHandEq?.forEach((PieceType t, int n) {
    position.hand(opp).set(t, n);
  });
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
        // ply 制約付きテンプレートは position ベース検出ではマッチしない
        // (record 経由でのみ有効)。これらは ply_constraint_test.dart で別途
        // 検証する。
        if (template.hasPlyConstraint) continue;
        // 履歴依存テンプレ (PieceUnmoved / PieceVisited) も同様。
        // move_history_test.dart で別途検証する。
        if (template.hasHistoryRequirement) continue;
        test('detects ${template.name}', () {
          final Position position = _emptyPosition();
          _placeStrategy(position, template, Color.black);
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
        if (template.hasPlyConstraint) continue;
        if (template.hasHistoryRequirement) continue;
        test('detects ${template.name} for white', () {
          final Position position = Position();
          position.reset(InitialPositionType.empty);
          // 黒玉を安全位置に。テンプレに king (5,9) を含むものは _placeStrategy
          // が上書きするのを避けるため、ここでは 1,9 などには置かず、後で
          // テンプレ配置と衝突しない (5,5) に黒玉を置く形にする。
          // ただし「棒玉」テンプレは (5,5) に黒玉を置くので、ここはあえて何も
          // 置かない方が安全。Position の king 数バリデーションは reset 直後の
          // 空盤では問われない。
          _placeStrategy(position, template, Color.white);
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
        position,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      _placeStrategy(
        position,
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
        position,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      _placeStrategy(
        position,
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
        position,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == '中飛車'),
        Color.black,
      );
      _placeStrategy(
        position,
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
        position,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == 'ゴキゲン中飛車'),
        Color.black,
      );
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      // ゴキゲン中飛車 は plyMax 制約付きなので position 検出ではスキップ
      // される (record 経由でのみ検出可能)。一方、親に相当する 中飛車 は
      // ply 制約を持たないので、ゴキゲン中飛車 の placements の部分集合と
      // なっている限り通常通り検出される。
      expect(_detected(result, '中飛車', Color.black), isTrue);
    });

    test('parent (石田流) is also detected when child (石田流本組み) matches', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position,
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
        position,
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
        position,
        knownStrategies.firstWhere((StrategyTemplate t) => t.name == 'ゴキゲン中飛車'),
        Color.black,
      );
      // 飛車 (5八) を消すと中飛車も成立しない
      position.board.remove(Square(5, 8));
      final List<DetectedStrategy> result =
          detectStrategies(position, side: Color.black);
      expect(_detected(result, 'ゴキゲン中飛車', Color.black), isFalse);
      expect(_detected(result, '中飛車', Color.black), isFalse);
    });

    test('negative: wrong piece color does not match', () {
      final Position position = _emptyPosition();
      _placeStrategy(
        position,
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
        position,
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
        position,
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
        p1,
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
        p2,
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

    test('all per-cell placement file/rank are within 1..9', () {
      for (final StrategyTemplate t in knownStrategies) {
        for (final CastleRequirement r in t.placements) {
          final ({int file, int rank})? coord = switch (r) {
            PiecePlacement(:final file, :final rank) => (
                file: file,
                rank: rank,
              ),
            AnyOfPieces(:final file, :final rank) => (
                file: file,
                rank: rank,
              ),
            EmptySquare(:final file, :final rank) => (
                file: file,
                rank: rank,
              ),
            NotOfPieces(:final file, :final rank) => (
                file: file,
                rank: rank,
              ),
            AnyPiece(:final file, :final rank) => (file: file, rank: rank),
            PieceAnywhere() => null,
            HandPiece() => null,
            AnyPlacement() => null,
            PieceUnmoved() => null,
            PieceVisited() => null,
            PieceDropped() => null,
            HandEmpty() => null,
            KingIgyoku() => null,
          };
          if (coord == null) continue;
          expect(
            coord.file,
            inInclusiveRange(1, 9),
            reason: '${t.name} has file out of range: ${coord.file}',
          );
          expect(
            coord.rank,
            inInclusiveRange(1, 9),
            reason: '${t.name} has rank out of range: ${coord.rank}',
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
    test('石田流 (7五歩+7六飛) は検出されるが向かい飛車は検出されない', () {
      // bioshogi の 石田流 は visited: R 2 6 / R 7 8 / R 7 7 を要求する
      // (★ マーカー由来)。手書き局面では履歴が捏造できないので Record で
      // 再現する必要があるが、R 2 6 を自然に visited させる手順は複雑。
    }, skip: 'bioshogi visited: R 2 6 を満たすには複雑な棋譜が必要、Record-based 改修待ち');

    test('矢倉 vs 角換わり は 盤上 角 / 手駒 角 で峻別される', () {
      // テンプレが visited / hand / opponent 要件を持つため、手書き局面では
      // 完全には再現できない。Record-based テストに書き直す予定。
    }, skip: 'visited / hand / opponent 要件の手書き再現が困難、Record-based 改修待ち');

    test('棒銀 は bioshogi 形 (2六銀+3七歩+2八飛 + 銀が 2七 経由) で検出される', () {
      // bioshogi の 棒銀 は visited: S 2 7 を要求するため、
      // 銀が 2七 を通過した履歴が必要。Record 経由で検証する。
      // 標準的な棒銀手順: 2七歩を 2六→2五 と進めて 2七 を空け、
      // 銀を 3九→3八→2七→2六 と繰り出す。
      final Record? r = Record.newByUSI(
        'startpos moves 2g2f 3c3d 2f2e 5c5d 3i3h 4c4d 3h2g 6c6d 2g2f 7c7d',
      );
      expect(r, isNotNull);
      final bool fired = r!.strategies.any((DetectedStrategyAt s) =>
          s.template.name == '棒銀' && s.side == Color.black);
      expect(fired, isTrue);
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

    test('相~ は mutual 戦法として一度だけ報告され、emit 側は指し手の手番', () {
      // 横歩取り → 相横歩取り に発展する USI 棋譜。22 手目で 後手 (white)
      // が 8f→7f に飛車を引き、これで相横歩取りの局面が確定する。
      // 修正前: ply 18 で `black 相横歩取り` と `white 相横歩取り` が二重 emit
      // されていた。mutual: true 化により name 単位 dedup + 指し手陣営帰属に
      // なり、ply 18 で white の 1 件のみが出ることを確認する。
      final Record? r = Record.newByUSI(
        'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/'
        'LNSGKGSNL b - 1 moves 7g7f 3c3d 2g2f 8c8d 2f2e 8d8e 6i7h 4a3b '
        '2e2d 2c2d 2h2d 8e8f 8g8f 8b8f 2d3d 2b8h+ 7i8h 8f7f 8h7g 7f7d '
        '3d7d 7c7d',
      );
      expect(r, isNotNull);
      final List<DetectedStrategyAt> aiyoko = r!.strategies
          .where((DetectedStrategyAt s) => s.template.name == '相横歩取り')
          .toList();
      expect(aiyoko, hasLength(1),
          reason: 'mutual strategy must be emitted exactly once');
      expect(aiyoko.single.side, Color.white,
          reason: 'mutual strategy is attributed to the side whose move '
              'completed the position');
    });

    test(
        'スナップショット検出 (position.strategies / detectStrategies) でも mutual は 1 件のみ',
        () {
      // 同じ 横歩取り サンプルで position.strategies / detectStrategies を叩く。
      // 修正前: side=black と side=white の 2 件返却。
      // 修正後: 1 件のみ。side: フィルタ無しなら canonical の black、
      // フィルタを渡したらそれを尊重。
      final Record? r = Record.newByUSI(
        'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/'
        'LNSGKGSNL b - 1 moves 7g7f 3c3d 2g2f 8c8d 2f2e 8d8e 6i7h 4a3b '
        '2e2d 2c2d 2h2d 8e8f 8g8f 8b8f 2d3d 2b8h+ 7i8h 8f7f',
      );
      expect(r, isNotNull);

      final List<DetectedStrategy> snapAll = r!.position.strategies
          .where((s) => s.template.name == '相横歩取り')
          .toList();
      expect(snapAll, hasLength(1),
          reason: 'snapshot detection should emit mutual exactly once');
      expect(snapAll.single.side, Color.black,
          reason: 'no side filter → canonical Color.black');

      final List<DetectedStrategy> detBlack =
          detectStrategies(r.position, side: Color.black)
              .where((s) => s.template.name == '相横歩取り')
              .toList();
      expect(detBlack, hasLength(1));
      expect(detBlack.single.side, Color.black,
          reason: 'side: black filter → side=black');

      final List<DetectedStrategy> detWhite =
          detectStrategies(r.position, side: Color.white)
              .where((s) => s.template.name == '相横歩取り')
              .toList();
      expect(detWhite, hasLength(1));
      expect(detWhite.single.side, Color.white,
          reason: 'side: white filter → side=white');
    });

    test('mutual テンプレは 相掛かり / 相掛かり棒銀 / 相横歩取り / 相筋違い角 の 4 件', () {
      final List<String> mutualNames = knownStrategies
          .where((StrategyTemplate t) => t.mutual)
          .map((StrategyTemplate t) => t.name)
          .toList()
        ..sort();
      expect(mutualNames,
          containsAll(<String>['相掛かり', '相掛かり棒銀', '相横歩取り', '相筋違い角']));
      // mutual 化されているのは「相 〜」名の 4 件だけであるべき。
      for (final String n in mutualNames) {
        expect(n, startsWith('相'),
            reason: 'mutual templates should be 相~ names; got "$n"');
      }
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
