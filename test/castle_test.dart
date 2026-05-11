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
}
