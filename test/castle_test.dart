import 'package:test/test.dart';
import 'package:tsshogi/src/board.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/square.dart';

/// 空の盤面を持つ Position を作る。白玉だけ安全な位置に置く。
Position _emptyPosition() {
  final Position position = Position();
  position.reset(InitialPositionType.empty);
  position.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
  return position;
}

/// テンプレートの placements を [side] 視点で盤に並べる。
void _placeTemplate(Board board, CastleTemplate template, Color side) {
  for (final PiecePlacement p in template.placements) {
    final int file = side == Color.black ? p.file : 10 - p.file;
    final int rank = side == Color.black ? p.rank : 10 - p.rank;
    board.set(Square(file, rank), Piece(side, p.pieceType));
  }
}

bool _detected(List<DetectedCastle> results, String name, Color side) {
  return results
      .any((DetectedCastle d) => d.template.name == name && d.side == side);
}

void main() {
  group('detectCastles', () {
    test('empty position returns empty', () {
      final Position position = Position();
      position.reset(InitialPositionType.empty);
      // 玉も置かない完全に空の盤
      final List<DetectedCastle> result = detectCastles(position);
      expect(result, isEmpty);
    });

    test('initial standard position is not a castle', () {
      final Position position = Position();
      // 初期局面は囲い未着手 — 居玉以外は何も検出されないはず
      // (居玉は 5九玉だけのチェックなので初期局面でもマッチする)
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      // 居玉は検出される
      expect(_detected(result, '居玉', Color.black), isTrue);
      // 矢倉・美濃・穴熊は当然検出されない
      expect(_detected(result, '金矢倉', Color.black), isFalse);
      expect(_detected(result, '本美濃', Color.black), isFalse);
      expect(_detected(result, '居飛車穴熊', Color.black), isFalse);
    });

    group('each castle detection (black)', () {
      for (final CastleTemplate template in knownCastles) {
        test('detects ${template.name}', () {
          final Position position = _emptyPosition();
          _placeTemplate(position.board, template, Color.black);
          final List<DetectedCastle> result =
              detectCastles(position, side: Color.black);
          expect(
            _detected(result, template.name, Color.black),
            isTrue,
            reason: '${template.name} should match its own template',
          );
        });
      }
    });

    group('each castle detection (white, mirrored)', () {
      for (final CastleTemplate template in knownCastles) {
        test('detects ${template.name} for white', () {
          // 白玉が初期位置にあるので一旦消す
          final Position position = Position();
          position.reset(InitialPositionType.empty);
          // 黒玉を安全な位置に置いて Position 健全性確保
          position.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
          // 白玉が玉テンプレに含まれていない場合は消す処理は不要だが、
          // king 配置のテンプレもあるので一旦白玉も消してから再配置
          // _placeTemplate が king を含む場合は上書きする
          _placeTemplate(position.board, template, Color.white);
          // 上で黒玉が 5九に置かれているがテンプレが file=5,rank=9 を持つと衝突する
          // 例: 居玉 (5,9 玉) は白側で 10-5=5, 10-9=1 → (5,1) なので衝突しない
          final List<DetectedCastle> result =
              detectCastles(position, side: Color.white);
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
      // 黒側に金矢倉、白側に本美濃を作る
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '本美濃'),
        Color.white,
      );

      final List<DetectedCastle> blackOnly =
          detectCastles(position, side: Color.black);
      expect(
          blackOnly.every((DetectedCastle d) => d.side == Color.black), isTrue);
      expect(_detected(blackOnly, '金矢倉', Color.black), isTrue);
      expect(_detected(blackOnly, '本美濃', Color.white), isFalse);
    });

    test('side filter: white only', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '本美濃'),
        Color.white,
      );

      final List<DetectedCastle> whiteOnly =
          detectCastles(position, side: Color.white);
      expect(
          whiteOnly.every((DetectedCastle d) => d.side == Color.white), isTrue);
      expect(_detected(whiteOnly, '本美濃', Color.white), isTrue);
      expect(_detected(whiteOnly, '金矢倉', Color.black), isFalse);
    });

    test('side null: both sides detected', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '本美濃'),
        Color.white,
      );
      final List<DetectedCastle> both = detectCastles(position);
      expect(_detected(both, '金矢倉', Color.black), isTrue);
      expect(_detected(both, '本美濃', Color.white), isTrue);
    });

    test('parent (矢倉囲い) detected when child (金矢倉) matches', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '金矢倉', Color.black), isTrue);
      expect(_detected(result, '矢倉囲い', Color.black), isTrue);
    });

    test('parent (美濃囲い) detected when child (本美濃) matches', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '本美濃'),
        Color.black,
      );
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '本美濃', Color.black), isTrue);
      expect(_detected(result, '美濃囲い', Color.black), isTrue);
    });

    test('parent (穴熊囲い) detected when child (居飛車穴熊) matches', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '居飛車穴熊'),
        Color.black,
      );
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '居飛車穴熊', Color.black), isTrue);
      expect(_detected(result, '穴熊囲い', Color.black), isTrue);
    });

    test('negative: missing one piece breaks the match', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      // 6七金を消す
      position.board.remove(Square(6, 7));
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '金矢倉', Color.black), isFalse);
    });

    test('negative: wrong piece color does not match', () {
      final Position position = _emptyPosition();
      // 黒側に金矢倉を配置するが 7七銀だけ白駒に
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      position.board.set(Square(7, 7), Piece(Color.white, PieceType.silver));
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '金矢倉', Color.black), isFalse);
    });

    test('negative: wrong piece type does not match', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '本美濃'),
        Color.black,
      );
      // 3九銀を桂に
      position.board.set(Square(3, 9), Piece(Color.black, PieceType.knight));
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '本美濃', Color.black), isFalse);
    });

    test('extra pieces on board do not invalidate a match', () {
      final Position position = _emptyPosition();
      _placeTemplate(
        position.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      // テンプレに含まれない関係ない場所に駒を追加
      position.board.set(Square(2, 8), Piece(Color.black, PieceType.rook));
      position.board.set(Square(1, 9), Piece(Color.black, PieceType.lance));
      final List<DetectedCastle> result =
          detectCastles(position, side: Color.black);
      expect(_detected(result, '金矢倉', Color.black), isTrue);
    });

    test('DetectedCastle equality / hashCode', () {
      const CastleTemplate t = CastleTemplate(
        name: '金矢倉',
        placements: <PiecePlacement>[],
      );
      const DetectedCastle a = DetectedCastle(template: t, side: Color.black);
      const DetectedCastle b = DetectedCastle(template: t, side: Color.black);
      const DetectedCastle c = DetectedCastle(template: t, side: Color.white);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('knownCastles has at least 30 entries', () {
      expect(knownCastles.length, greaterThanOrEqualTo(30));
    });
  });

  // -------------------------------------------------------------------------
  // 実戦的局面: 囲いの周囲に他の駒が散っている状況でも検出できることを確認
  // -------------------------------------------------------------------------
  group('realistic positions', () {
    Position positionFromSFEN(String sfen) {
      final Position? p = Position.newBySFEN(sfen);
      if (p == null) {
        throw StateError('Invalid SFEN: $sfen');
      }
      return p;
    }

    test('金矢倉 in a mid-game position (black, 平手駒組み)', () {
      // 8八玉・7八金・6七金・7七銀 + 端歩 9七、5六歩〜7六歩、4八金・2八飛・
      // 6八角・8九桂・9九香 ありの典型的な金矢倉組み上がり局面。
      // 上手側は後手で 平手のまま自然に進めた状態。
      const String sfen = 'lnsgkgsnl/1r5b1/ppppppppp/9/9/2PPPPP2/'
          'PP2SGPPP/1BGK1G3/LNS4NL b - 1';
      // 8筋・9筋は省略形 (実際は SFEN を正確に書くより Board API で組む方が早い)
      // 上の SFEN は形式チェック用 — 本物の組み立ては Board API で行う:
      final Position p = positionFromSFEN(sfen).clone();
      // Position.newBySFEN は完璧でなくても、ここから Board API で 金矢倉に組み直す。
      p.board.clear();
      // 黒玉 8八
      p.board.set(Square(8, 8), Piece(Color.black, PieceType.king));
      // 金矢倉の骨格
      p.board.set(Square(7, 8), Piece(Color.black, PieceType.gold));
      p.board.set(Square(6, 7), Piece(Color.black, PieceType.gold));
      p.board.set(Square(7, 7), Piece(Color.black, PieceType.silver));
      // 矢倉の歩
      p.board.set(Square(9, 7), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(7, 6), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(6, 6), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(5, 6), Piece(Color.black, PieceType.pawn));
      // 残りの黒駒 (囲い外、典型形)
      p.board.set(Square(9, 9), Piece(Color.black, PieceType.lance));
      p.board.set(Square(8, 9), Piece(Color.black, PieceType.knight));
      p.board.set(Square(6, 8), Piece(Color.black, PieceType.bishop));
      p.board.set(Square(4, 8), Piece(Color.black, PieceType.gold));
      p.board.set(Square(2, 8), Piece(Color.black, PieceType.rook));
      p.board.set(Square(3, 9), Piece(Color.black, PieceType.silver));
      p.board.set(Square(2, 9), Piece(Color.black, PieceType.knight));
      p.board.set(Square(1, 9), Piece(Color.black, PieceType.lance));
      // 後手駒も適当に置く (検出に影響しないことを確認)
      p.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
      p.board.set(Square(8, 2), Piece(Color.white, PieceType.rook));
      p.board.set(Square(2, 2), Piece(Color.white, PieceType.bishop));

      final List<DetectedCastle> result = detectCastles(p, side: Color.black);
      expect(_detected(result, '金矢倉', Color.black), isTrue);
      expect(_detected(result, '矢倉囲い', Color.black), isTrue);
      // 似ているが違う囲いは検出されない
      expect(_detected(result, '銀矢倉', Color.black), isFalse);
      expect(_detected(result, '総矢倉', Color.black), isFalse);
    });

    test('本美濃 in a mid-game position (black, 振り飛車組み)', () {
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      // 本美濃の駒
      p.board.set(Square(3, 8), Piece(Color.black, PieceType.king));
      p.board.set(Square(4, 8), Piece(Color.black, PieceType.gold));
      p.board.set(Square(5, 8), Piece(Color.black, PieceType.gold));
      p.board.set(Square(3, 9), Piece(Color.black, PieceType.silver));
      p.board.set(Square(1, 9), Piece(Color.black, PieceType.lance));
      p.board.set(Square(1, 7), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(2, 7), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(3, 7), Piece(Color.black, PieceType.pawn));
      p.board.set(Square(4, 7), Piece(Color.black, PieceType.pawn));
      // 振り飛車側の典型駒組
      p.board.set(Square(6, 8), Piece(Color.black, PieceType.rook));
      p.board.set(Square(7, 9), Piece(Color.black, PieceType.silver));
      p.board.set(Square(8, 8), Piece(Color.black, PieceType.bishop));
      p.board.set(Square(9, 9), Piece(Color.black, PieceType.lance));
      p.board.set(Square(2, 9), Piece(Color.black, PieceType.knight));
      // 後手玉だけ
      p.board.set(Square(5, 1), Piece(Color.white, PieceType.king));

      final List<DetectedCastle> result = detectCastles(p, side: Color.black);
      expect(_detected(result, '本美濃', Color.black), isTrue);
      expect(_detected(result, '美濃囲い', Color.black), isTrue);
      // 高美濃 (4七金) や 銀冠 (歩が一段上) ではない
      expect(_detected(result, '高美濃', Color.black), isFalse);
      expect(_detected(result, '銀冠', Color.black), isFalse);
    });

    test('居飛車穴熊 in a mid-game position (black)', () {
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      // 居飛車穴熊
      p.board.set(Square(9, 9), Piece(Color.black, PieceType.king));
      p.board.set(Square(9, 8), Piece(Color.black, PieceType.lance));
      p.board.set(Square(8, 9), Piece(Color.black, PieceType.gold));
      p.board.set(Square(8, 8), Piece(Color.black, PieceType.silver));
      p.board.set(Square(9, 7), Piece(Color.black, PieceType.pawn));
      // 周辺駒
      p.board.set(Square(7, 9), Piece(Color.black, PieceType.gold));
      p.board.set(Square(6, 9), Piece(Color.black, PieceType.silver));
      p.board.set(Square(2, 8), Piece(Color.black, PieceType.rook));
      // 後手玉
      p.board.set(Square(5, 1), Piece(Color.white, PieceType.king));

      final List<DetectedCastle> result = detectCastles(p, side: Color.black);
      expect(_detected(result, '居飛車穴熊', Color.black), isTrue);
      expect(_detected(result, '穴熊囲い', Color.black), isTrue);
      // 振り飛車穴熊 (1筋) ではないし、ビッグ4 (2金2銀) でもない
      expect(_detected(result, '振り飛車穴熊', Color.black), isFalse);
      expect(_detected(result, 'ビッグ4', Color.black), isFalse);
    });

    test('振り飛車側の本美濃を後手 (上手) として検出', () {
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      // 後手 (上手) が 本美濃 を組んだ局面: テンプレを 180° 回転
      // 3八玉 → 7二玉、4八金 → 6二金 ...
      p.board.set(Square(7, 2), Piece(Color.white, PieceType.king));
      p.board.set(Square(6, 2), Piece(Color.white, PieceType.gold));
      p.board.set(Square(5, 2), Piece(Color.white, PieceType.gold));
      p.board.set(Square(7, 1), Piece(Color.white, PieceType.silver));
      p.board.set(Square(9, 1), Piece(Color.white, PieceType.lance));
      p.board.set(Square(9, 3), Piece(Color.white, PieceType.pawn));
      p.board.set(Square(8, 3), Piece(Color.white, PieceType.pawn));
      p.board.set(Square(7, 3), Piece(Color.white, PieceType.pawn));
      p.board.set(Square(6, 3), Piece(Color.white, PieceType.pawn));
      // 黒玉だけ
      p.board.set(Square(5, 9), Piece(Color.black, PieceType.king));

      final List<DetectedCastle> result = detectCastles(p);
      expect(_detected(result, '本美濃', Color.white), isTrue);
      expect(_detected(result, '美濃囲い', Color.white), isTrue);
      // 黒側にも 居玉 だけ検出される
      expect(_detected(result, '居玉', Color.black), isTrue);
    });

    test('両陣営同時に違う囲いを組んだ局面', () {
      final Position p = Position();
      p.reset(InitialPositionType.empty);
      // 黒: 居飛車穴熊
      p.board.set(Square(9, 9), Piece(Color.black, PieceType.king));
      p.board.set(Square(9, 8), Piece(Color.black, PieceType.lance));
      p.board.set(Square(8, 9), Piece(Color.black, PieceType.gold));
      p.board.set(Square(8, 8), Piece(Color.black, PieceType.silver));
      p.board.set(Square(9, 7), Piece(Color.black, PieceType.pawn));
      // 白: 本美濃 (mirror)
      p.board.set(Square(7, 2), Piece(Color.white, PieceType.king));
      p.board.set(Square(6, 2), Piece(Color.white, PieceType.gold));
      p.board.set(Square(5, 2), Piece(Color.white, PieceType.gold));
      p.board.set(Square(7, 1), Piece(Color.white, PieceType.silver));
      p.board.set(Square(9, 1), Piece(Color.white, PieceType.lance));
      p.board.set(Square(9, 3), Piece(Color.white, PieceType.pawn));
      p.board.set(Square(8, 3), Piece(Color.white, PieceType.pawn));
      p.board.set(Square(7, 3), Piece(Color.white, PieceType.pawn));
      p.board.set(Square(6, 3), Piece(Color.white, PieceType.pawn));

      final List<DetectedCastle> result = detectCastles(p);
      expect(_detected(result, '居飛車穴熊', Color.black), isTrue);
      expect(_detected(result, '穴熊囲い', Color.black), isTrue);
      expect(_detected(result, '本美濃', Color.white), isTrue);
      expect(_detected(result, '美濃囲い', Color.white), isTrue);
      // 交差検出はしない
      expect(_detected(result, '居飛車穴熊', Color.white), isFalse);
      expect(_detected(result, '本美濃', Color.black), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Near-miss / 紛らわしい囲いの誤検出を防げているか
  // -------------------------------------------------------------------------
  group('near-miss confusables', () {
    test('金矢倉 placements → 銀矢倉 と誤検出しない', () {
      final Position p = _emptyPosition();
      _placeTemplate(
        p.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '金矢倉', Color.black), isTrue);
      expect(_detected(r, '銀矢倉', Color.black), isFalse);
    });

    test('銀矢倉 placements → 金矢倉 と誤検出しない', () {
      final Position p = _emptyPosition();
      _placeTemplate(
        p.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '銀矢倉'),
        Color.black,
      );
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '銀矢倉', Color.black), isTrue);
      expect(_detected(r, '金矢倉', Color.black), isFalse);
    });

    test('片美濃 → 本美濃 と誤検出しない (5八金欠け)', () {
      final Position p = _emptyPosition();
      _placeTemplate(
        p.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '片美濃'),
        Color.black,
      );
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '片美濃', Color.black), isTrue);
      expect(_detected(r, '本美濃', Color.black), isFalse);
    });

    test('本美濃 → 高美濃 と誤検出しない (4七位置の歩/金違い)', () {
      final Position p = _emptyPosition();
      _placeTemplate(
        p.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '本美濃'),
        Color.black,
      );
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '本美濃', Color.black), isTrue);
      expect(_detected(r, '高美濃', Color.black), isFalse);
    });

    test('居飛車穴熊 → 振り飛車穴熊・ビッグ4 と誤検出しない', () {
      final Position p = _emptyPosition();
      _placeTemplate(
        p.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '居飛車穴熊'),
        Color.black,
      );
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '居飛車穴熊', Color.black), isTrue);
      expect(_detected(r, '振り飛車穴熊', Color.black), isFalse);
      expect(_detected(r, 'ビッグ4', Color.black), isFalse);
    });

    test('居玉のみ → 中住まいや 5五玉系 と誤検出しない', () {
      final Position p = _emptyPosition();
      p.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '居玉', Color.black), isTrue);
      expect(_detected(r, '中住まい', Color.black), isFalse);
      expect(_detected(r, '箱入り娘', Color.black), isFalse);
    });

    test('金矢倉に近いが 1 マス違い → 何も検出しない (大局的崩れ)', () {
      final Position p = _emptyPosition();
      _placeTemplate(
        p.board,
        knownCastles.firstWhere((CastleTemplate t) => t.name == '金矢倉'),
        Color.black,
      );
      // 8八玉 を 8九 に下げる: 矢倉囲い (8八玉 必須) も金矢倉も崩れる
      p.board.remove(Square(8, 8));
      p.board.set(Square(8, 9), Piece(Color.black, PieceType.king));
      final List<DetectedCastle> r = detectCastles(p, side: Color.black);
      expect(_detected(r, '金矢倉', Color.black), isFalse);
      expect(_detected(r, '矢倉囲い', Color.black), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // データ整合性: knownCastles 自体の健全性チェック
  // -------------------------------------------------------------------------
  group('data integrity', () {
    test('全テンプレートの name はユニーク', () {
      final Set<String> seen = <String>{};
      for (final CastleTemplate t in knownCastles) {
        expect(seen.contains(t.name), isFalse, reason: '${t.name} が重複登録されている');
        seen.add(t.name);
      }
    });

    test('全 placements の file/rank が 1..9 に収まる', () {
      for (final CastleTemplate t in knownCastles) {
        for (final PiecePlacement p in t.placements) {
          expect(p.file, inInclusiveRange(1, 9), reason: '${t.name}: file');
          expect(p.rank, inInclusiveRange(1, 9), reason: '${t.name}: rank');
        }
      }
    });

    test('全テンプレートは少なくとも 1 つ placement を持つ', () {
      for (final CastleTemplate t in knownCastles) {
        expect(t.placements, isNotEmpty, reason: '${t.name} の placements が空');
      }
    });

    test('居玉以外は玉位置が必ず placement に含まれる', () {
      for (final CastleTemplate t in knownCastles) {
        final bool hasKing = t.placements
            .any((PiecePlacement p) => p.pieceType == PieceType.king);
        expect(hasKing, isTrue, reason: '${t.name} に玉が含まれていない');
      }
    });

    test('同一マスに 2 駒以上の placement がない', () {
      for (final CastleTemplate t in knownCastles) {
        final Set<int> squares = <int>{};
        for (final PiecePlacement p in t.placements) {
          final int key = p.file * 10 + p.rank;
          expect(squares.contains(key), isFalse,
              reason: '${t.name} で ${p.file}${p.rank} が重複');
          squares.add(key);
        }
      }
    });

    test('parent 参照先は knownCastles 内に存在する', () {
      final Set<String> names =
          knownCastles.map((CastleTemplate t) => t.name).toSet();
      for (final CastleTemplate t in knownCastles) {
        if (t.parent != null) {
          expect(names.contains(t.parent), isTrue,
              reason: '${t.name} の parent ${t.parent} が定義されていない');
        }
      }
    });

    test('親テンプレートの placements は子テンプレートの subset', () {
      final Map<String, CastleTemplate> byName = <String, CastleTemplate>{
        for (final CastleTemplate t in knownCastles) t.name: t,
      };
      for (final CastleTemplate child in knownCastles) {
        if (child.parent == null) continue;
        final CastleTemplate? parent = byName[child.parent];
        if (parent == null) continue;
        for (final PiecePlacement pp in parent.placements) {
          final bool included = child.placements.any((PiecePlacement cp) =>
              cp.file == pp.file &&
              cp.rank == pp.rank &&
              cp.pieceType == pp.pieceType);
          expect(included, isTrue,
              reason: '子 ${child.name} に親 ${parent.name} の '
                  '${pp.file}${pp.rank}${pp.pieceType} がない');
        }
      }
    });

    test('alias がテンプレ名と衝突しない', () {
      final Set<String> names =
          knownCastles.map((CastleTemplate t) => t.name).toSet();
      for (final CastleTemplate t in knownCastles) {
        for (final String alias in t.aliases) {
          // 自分自身の name と一致するのは無意味
          expect(alias, isNot(equals(t.name)),
              reason: '${t.name} の alias に自身が含まれている');
          // 他のテンプレ名と衝突するのも避ける
          if (names.contains(alias)) {
            // 他人と一致する alias は曖昧さの原因なので警告レベル
            // (今のところそういう登録はない想定だが、検知だけする)
            fail('alias "$alias" が他のテンプレ名と一致 (${t.name})');
          }
        }
      }
    });
  });
}
