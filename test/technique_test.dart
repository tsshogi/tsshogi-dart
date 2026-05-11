import 'package:test/test.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/move.dart';
import 'package:tsshogi/src/piece.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/square.dart';
import 'package:tsshogi/src/technique.dart';

/// 空の盤を用意し、最低限の合法局面を作るために両玉だけ置く。
Position _emptyPosition({Color turn = Color.black}) {
  final Position position = Position();
  position.reset(InitialPositionType.empty);
  position.board.set(Square(5, 9), Piece(Color.black, PieceType.king));
  position.board.set(Square(5, 1), Piece(Color.white, PieceType.king));
  position.setColor(turn);
  return position;
}

/// before の clone と after (doMove 後) を返す。
({ImmutablePosition before, ImmutablePosition after}) _apply(
    Position pos, Move move) {
  final ImmutablePosition before = pos.clone();
  expect(pos.doMove(move, ignoreValidation: true), isTrue,
      reason: 'doMove failed for ${move.usi}');
  final ImmutablePosition after = pos.clone();
  return (before: before, after: after);
}

/// 検出結果に [name] が含まれるか。
bool _hits(List<TechniqueTemplate> hits, String name) =>
    hits.any((TechniqueTemplate t) => t.name == name);

/// 手番側の持ち駒を 1 枚補充する。
void _addHand(Position pos, Color side, PieceType type) {
  pos.hand(side).add(type, 1);
}

void main() {
  group('detectTechniquesAtMove — basic positives', () {
    test('たたきの歩: 相手の駒の前に歩打ち', () {
      final Position pos = _emptyPosition();
      // 後手の銀を 7五 に配置
      pos.board.set(Square(7, 5), Piece(Color.white, PieceType.silver));
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(7, 6),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      final hits = detectTechniquesAtMove(move, r.before, r.after);
      expect(_hits(hits, 'たたきの歩'), isTrue);
    });

    test('垂れ歩: 黒 4 段への歩打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(5, 4),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '垂れ歩'),
          isTrue);
    });

    test('底歩: 黒 9 段への歩打ち', () {
      final Position pos = _emptyPosition();
      // 黒玉が 5九 にいるので 1九 に底歩を打つ
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(1, 9),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '底歩'), isTrue);
    });

    test('金底の歩: 自陣 5九の金の下 (この場合は不能なので 4九金+4八は無理) — 別形で', () {
      final Position pos = _emptyPosition();
      // 4九 に金 を置き、4八 がデフォルト空。底歩は 4 筋 9 段に打つ。
      // 玉は 5九 → 4九 へ移動させない (= 玉のままなら金は 4九 で OK)。
      // 構成: 黒玉 5九、黒金 4九、4 筋 9 段 = 4九 (金) なので底歩は不可。
      // よって 6 筋: 黒金 6九、底歩 6九 ... これも重なるので別配置:
      // 黒玉を 5九 から動かさず、黒金を 1九 ではなく 1八 とし、底歩を 1九 へ。
      // しかし金底の歩判定は「打った歩の前マスが自分の金」なので底歩(1九)の前 = 1八 に金が必要。
      pos.board.set(Square(1, 8), Piece(Color.black, PieceType.gold));
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(1, 9),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '金底の歩'),
          isTrue);
    });

    test('合わせの歩: 同じ筋に相手の歩あり', () {
      final Position pos = _emptyPosition();
      // 後手の歩を 5五 に置く
      pos.board.set(Square(5, 5), Piece(Color.white, PieceType.pawn));
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(5, 7),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '合わせの歩'),
          isTrue);
    });

    test('桂頭の歩: 後手の桂の前に歩打ち', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(3, 4), Piece(Color.white, PieceType.knight));
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(3, 5),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '桂頭の歩'),
          isTrue);
    });

    test('割り打ちの銀: 銀打で 2 駒に当てる', () {
      final Position pos = _emptyPosition();
      // 5五 に銀を打つと、左下 (4六)、右下 (6六)、左上 (4四)、右上 (6四)、上 (5四) に効く。
      // 相手の金を 4 四 と 6 四 に置けば 2 駒に当たる。
      pos.board.set(Square(4, 4), Piece(Color.white, PieceType.gold));
      pos.board.set(Square(6, 4), Piece(Color.white, PieceType.gold));
      _addHand(pos, Color.black, PieceType.silver);
      final Move move = Move(
        const FromHand(PieceType.silver),
        Square(5, 5),
        false,
        Color.black,
        PieceType.silver,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '割り打ちの銀'),
          isTrue);
    });

    test('ふんどしの桂: 桂打で 2 駒に当てる', () {
      final Position pos = _emptyPosition();
      // 黒桂 5 五 に打つと利きは 4三, 6三 (黒視点の前 1 段上, 左右 1 ずつ)。
      pos.board.set(Square(4, 3), Piece(Color.white, PieceType.gold));
      pos.board.set(Square(6, 3), Piece(Color.white, PieceType.gold));
      _addHand(pos, Color.black, PieceType.knight);
      final Move move = Move(
        const FromHand(PieceType.knight),
        Square(5, 5),
        false,
        Color.black,
        PieceType.knight,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), 'ふんどしの桂'),
          isTrue);
    });

    test('頭金: 相手玉の真ん前に金打ち', () {
      final Position pos = _emptyPosition();
      // 白玉は 5 一にデフォルト配置。5 二に金打ちで頭金。
      _addHand(pos, Color.black, PieceType.gold);
      final Move move = Move(
        const FromHand(PieceType.gold),
        Square(5, 2),
        false,
        Color.black,
        PieceType.gold,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '頭金'), isTrue);
    });

    test('頭銀: 相手玉の真ん前に銀打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.silver);
      final Move move = Move(
        const FromHand(PieceType.silver),
        Square(5, 2),
        false,
        Color.black,
        PieceType.silver,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '頭銀'), isTrue);
    });

    test('腹金: 相手玉の隣に金打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.gold);
      final Move move = Move(
        const FromHand(PieceType.gold),
        Square(4, 1),
        false,
        Color.black,
        PieceType.gold,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '腹金'), isTrue);
    });

    test('腹銀: 相手玉の隣に銀打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.silver);
      final Move move = Move(
        const FromHand(PieceType.silver),
        Square(4, 1),
        false,
        Color.black,
        PieceType.silver,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '腹銀'), isTrue);
    });

    test('王手飛車: 角の王手で飛車にも当てる', () {
      final Position pos = _emptyPosition();
      // 白玉 5 一、白飛 9 五 とし、黒角を 1 九 → 5 五へ動かす…のではなく
      // 簡単に黒角 5 三 (空白) に置き、白玉 5 一 (王手) + 白飛 5 七 (利き) はダメ。
      // 5 三 黒角の利きは斜め線。1 七にあったとして 5 三に向かう。
      // 簡単設定: 黒角 1 三、白飛 9 三、白玉 5 三。角を 5 三 経由ではなく、
      // 1 三 → 5 七 (移動) で 5 七 から斜め 5 一 へ王手なし。代わりに別の形にする。
      // 設定: 白玉 5 一、白飛 1 五、黒角 9 九。9 九 → 1 一 と動くと、
      // 移動先 1 一 から 5 一 (3 マス斜め) は別ライン、ダメ。
      //
      // 直接的設定: 角を 4 二 に動かして 5 一の王と 1 五 の飛 (斜め同列) に当てる。
      // 4 二 → 5 一 = 斜め 1 マス (王手成立)。4 二 → 1 五 = 斜め 3 マス。
      pos.board.set(Square(1, 5), Piece(Color.white, PieceType.rook));
      pos.board.set(Square(5, 3), Piece(Color.black, PieceType.bishop));
      final Move move = Move(
        FromSquare(Square(5, 3)),
        Square(4, 2),
        false,
        Color.black,
        PieceType.bishop,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '王手飛車'),
          isTrue);
    });

    test('王手角: 飛車で王手しつつ角にも当てる', () {
      final Position pos = _emptyPosition();
      // 白玉 5 一、白角 9 五、黒飛 5 九 → 5 五 へ動かす (5 一にも 9 五にも当たる)
      pos.board.set(Square(9, 5), Piece(Color.white, PieceType.bishop));
      pos.board.set(Square(5, 9), Piece(Color.black, PieceType.rook));
      // 黒玉は別位置に移動 (5 九が飛車)
      pos.board.set(Square(5, 9), Piece(Color.black, PieceType.rook));
      pos.board.set(Square(4, 9), Piece(Color.black, PieceType.king));
      final Move move = Move(
        FromSquare(Square(5, 9)),
        Square(5, 5),
        false,
        Color.black,
        PieceType.rook,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '王手角'),
          isTrue);
    });

    test('角交換: 角で角を取る', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(5, 5), Piece(Color.black, PieceType.bishop));
      pos.board.set(Square(3, 3), Piece(Color.white, PieceType.bishop));
      final Move move = Move(
        FromSquare(Square(5, 5)),
        Square(3, 3),
        false,
        Color.black,
        PieceType.bishop,
        PieceType.bishop,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '角交換'),
          isTrue);
    });

    test('飛車先交換: 2 筋の歩交換 (黒側)', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(2, 4), Piece(Color.black, PieceType.pawn));
      pos.board.set(Square(2, 3), Piece(Color.white, PieceType.pawn));
      final Move move = Move(
        FromSquare(Square(2, 4)),
        Square(2, 3),
        false,
        Color.black,
        PieceType.pawn,
        PieceType.pawn,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '飛車先交換'),
          isTrue);
    });

    test('銀不成: 銀が敵陣に入って成らない', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(5, 4), Piece(Color.black, PieceType.silver));
      final Move move = Move(
        FromSquare(Square(5, 4)),
        Square(5, 3),
        false,
        Color.black,
        PieceType.silver,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '銀不成'),
          isTrue);
    });

    test('入玉: 玉が敵陣に到達', () {
      final Position pos = _emptyPosition();
      // 黒玉を 5 四 に再配置して 5 三 へ移動する
      pos.board.set(Square(5, 9), null);
      pos.board.set(Square(5, 4), Piece(Color.black, PieceType.king));
      final Move move = Move(
        FromSquare(Square(5, 4)),
        Square(5, 3),
        false,
        Color.black,
        PieceType.king,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '入玉'), isTrue);
    });

    test('と金攻め: 歩が成る手', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(5, 4), Piece(Color.black, PieceType.pawn));
      final Move move = Move(
        FromSquare(Square(5, 4)),
        Square(5, 3),
        true,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), 'と金攻め'),
          isTrue);
    });

    test('端攻め: 1 筋へ歩打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.pawn);
      final Move move = Move(
        const FromHand(PieceType.pawn),
        Square(1, 5),
        false,
        Color.black,
        PieceType.pawn,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '端攻め'),
          isTrue);
    });

    test('端玉: 玉を 1 筋へ寄せる', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(5, 9), null);
      pos.board.set(Square(2, 9), Piece(Color.black, PieceType.king));
      final Move move = Move(
        FromSquare(Square(2, 9)),
        Square(1, 9),
        false,
        Color.black,
        PieceType.king,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '端玉'), isTrue);
    });

    test('自陣飛車: 自陣に飛車打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.rook);
      final Move move = Move(
        const FromHand(PieceType.rook),
        Square(5, 8),
        false,
        Color.black,
        PieceType.rook,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '自陣飛車'),
          isTrue);
    });

    test('遠見の角: 自陣最下段に角打ち', () {
      final Position pos = _emptyPosition();
      _addHand(pos, Color.black, PieceType.bishop);
      final Move move = Move(
        const FromHand(PieceType.bishop),
        Square(1, 9),
        false,
        Color.black,
        PieceType.bishop,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '遠見の角'),
          isTrue);
    });

    test('飛車切り: 飛車が相手の利きに踏み込む', () {
      final Position pos = _emptyPosition();
      // 黒飛 5 五、白歩 5 三 (= 5 五は白歩の利きに入る)
      pos.board.set(Square(5, 5), Piece(Color.black, PieceType.rook));
      pos.board.set(Square(5, 3), Piece(Color.white, PieceType.pawn));
      // 飛車を 5 四 に動かすと白歩の利きにある
      final Move move = Move(
        FromSquare(Square(5, 5)),
        Square(5, 4),
        false,
        Color.black,
        PieceType.rook,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '飛車切り'),
          isTrue);
    });

    test('白側でも検出される: 後手の頭金', () {
      // 黒玉に対し白が金で頭金を狙う。
      final Position pos = _emptyPosition(turn: Color.white);
      _addHand(pos, Color.white, PieceType.gold);
      final Move move = Move(
        const FromHand(PieceType.gold),
        Square(5, 8),
        false,
        Color.white,
        PieceType.gold,
        null,
      );
      final r = _apply(pos, move);
      expect(
          _hits(detectTechniquesAtMove(move, r.before, r.after), '頭金'), isTrue);
    });
  });

  group('negative cases', () {
    test('単なる飛車移動はたたきの歩にならない', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(2, 8), Piece(Color.black, PieceType.rook));
      final Move move = Move(
        FromSquare(Square(2, 8)),
        Square(2, 6),
        false,
        Color.black,
        PieceType.rook,
        null,
      );
      final r = _apply(pos, move);
      final hits = detectTechniquesAtMove(move, r.before, r.after);
      expect(_hits(hits, 'たたきの歩'), isFalse);
    });

    test('成れる位置で銀が成った場合は銀不成にはならない', () {
      final Position pos = _emptyPosition();
      pos.board.set(Square(5, 4), Piece(Color.black, PieceType.silver));
      final Move move = Move(
        FromSquare(Square(5, 4)),
        Square(5, 3),
        true,
        Color.black,
        PieceType.silver,
        null,
      );
      final r = _apply(pos, move);
      expect(_hits(detectTechniquesAtMove(move, r.before, r.after), '銀不成'),
          isFalse);
    });
  });

  group('detectTechniques (Record walk)', () {
    test('棋譜全体を走査して頭金を検出', () {
      final Position initial = _emptyPosition();
      _addHand(initial, Color.black, PieceType.gold);
      final Record record = Record(position: initial);
      final Move move = Move(
        const FromHand(PieceType.gold),
        Square(5, 2),
        false,
        Color.black,
        PieceType.gold,
        null,
      );
      record.append(move, ignoreValidation: true);
      final List<DetectedTechnique> results = detectTechniques(record);
      expect(results.any((d) => d.template.name == '頭金' && d.ply == 1), isTrue);
      expect(results.firstWhere((d) => d.template.name == '頭金').color,
          Color.black);
    });
  });

  group('integrity', () {
    test('knownTechniques is non-empty', () {
      expect(knownTechniques, isNotEmpty);
      expect(knownTechniques.length, greaterThanOrEqualTo(70));
    });

    test('all technique names are unique', () {
      final Set<String> seen = <String>{};
      for (final TechniqueTemplate t in knownTechniques) {
        expect(seen.contains(t.name), isFalse,
            reason: 'duplicate name: ${t.name}');
        seen.add(t.name);
      }
    });
  });
}
