import 'package:test/test.dart';
import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/strategy.dart';

/// 指定 SFEN の局面を作る (パース失敗時はテストを fail させる)。
Position _pos(String sfen) {
  final Position? p = Position.newBySFEN(sfen);
  expect(p, isNotNull, reason: 'SFEN parse failed: $sfen');
  return p!;
}

bool _hasStrategy(Position p, String name, {Color side = Color.black}) {
  return p.strategies
      .any((DetectedStrategy d) => d.template.name == name && d.side == side);
}

bool _hasCastle(Position p, String name, {Color side = Color.black}) {
  return p.castles
      .any((DetectedCastle d) => d.template.name == name && d.side == side);
}

/// USI 指し手列から Record を作り、棋譜走査で検出された戦法に [name] が
/// (陣営 [side] で) 含まれるかを返す。
bool _recordHasStrategy(String usi, String name, {Color side = Color.black}) {
  final Record? r = Record.newByUSI(usi);
  expect(r, isNotNull, reason: 'USI parse failed: $usi');
  return r!.strategies.any(
      (DetectedStrategyAt d) => d.template.name == name && d.side == side);
}

void main() {
  // -------------------------------------------------------------------------
  // はく式四間飛車
  //
  // bioshogi の定義 (attack_info.rb) では、shape は !角7七 + 飛6八 だが、
  // メタデータ drop_only:true + hold_piece_empty:true が決め手:
  //   - drop_only       → 7七 の角は「打ち駒」(角交換して持駒の角を打ち直し)
  //   - hold_piece_empty → 打ち直した後、持駒は空
  // つまり「角を盤上から上がって 7七 に来た」ノーマル四間飛車とは区別される。
  // drop_only は履歴依存なので静的局面では判定できず、棋譜走査で確認する。
  //
  // 実例 (bioshogi の はく式四間飛車.kif より):
  //   ▲7六歩 ▲6八飛 … ▲2二角成 △2二銀 (角交換) ▲7七角打 (自陣角)
  // -------------------------------------------------------------------------
  group('はく式四間飛車', () {
    test('角交換して7七へ角を打ち直す棋譜で検出する (positive)', () {
      // 16手目までに角交換、17手目 B*7g で 7七 へ打ち直し。飛は6八。
      const String usi = 'position startpos moves '
          '7g7f 3c3d 2h6h 8c8d 5i4h 5a4b 4h3h 4b3b 6i5h 7a6b '
          '1g1f 1c1d 3h2h 8d8e 8h2b+ 3a2b B*7g';
      expect(_recordHasStrategy(usi, 'はく式四間飛車'), isTrue,
          reason: '角交換 + 7七への打ち直し (自陣角) ははく式四間飛車のはず');
      expect(_recordHasStrategy(usi, '四間飛車'), isTrue);
    });

    test('角を動かして7七へ上がった四間飛車はく式と誤検出しない (negative)', () {
      // ▲7六歩→▲7七角 (8h7g, 盤上から移動) で 7七 角、▲6八飛。角交換なし。
      // 打ち駒ではない (drop_only 不成立) のではく式ではない。
      const String usi =
          'position startpos moves 7g7f 3c3d 8h7g 8c8d 2h6h 8d8e';
      expect(_recordHasStrategy(usi, '四間飛車'), isTrue);
      expect(_recordHasStrategy(usi, 'はく式四間飛車'), isFalse,
          reason: '7七の角が打ち駒でない (動いて上がった) のにはく式と誤検出している');
    });

    test('静的局面 (棋譜履歴なし) でははく式を検出しない (drop_only は履歴依存)', () {
      // 角7七・飛6八が盤にあっても、打ち駒履歴が無ければはく式は成立しない。
      final Position p = _pos('4k4/9/9/9/9/9/2B6/3R5/4K4 b - 1');
      expect(_hasStrategy(p, 'はく式四間飛車'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 雁木囲い (オールド雁木 / 新型雁木)
  //
  // bioshogi shape_info.rb は オールド雁木 に `*角` (角が 7七 または 8八) を
  // 必須としている。これは「居飛車で角を捌いていない」ことを担保しており、
  // 雁木が居飛車専用であることの裏付け。移植時にこの `*` を落としていたため、
  // 角の無い (= 飛車を振った) 局面でも雁木と誤検出していた。
  //   オールド雁木 (別名 雁木囲い): 銀6七5七 / 金7八5八 / 玉6九 + 角(7七|8八)
  //   新型雁木:                   銀6七4七 / 金7八5八 / 角6八 / 飛2九 / 7七空き
  // -------------------------------------------------------------------------
  group('雁木囲い', () {
    test('オールド雁木 (別名 雁木囲い): 角7七付きの形を検出する (positive)', () {
      // 角7七・銀6七5七・金7八5八・玉6九 = 教科書的な雁木囲い。
      final Position p = _pos('4k4/9/9/9/9/9/2BSS4/2G1G4/3K5 b - 1');
      expect(_hasCastle(p, 'オールド雁木'), isTrue);
    });

    test('角8八付きの形も検出する (positive: *角 の OR を確認)', () {
      // 角が初期位置 8八 に残っていてもよい (bioshogi の `*角` = 7七 or 8八)。
      final Position p = _pos('4k4/9/9/9/9/9/3SS4/1BG1G4/3K5 b - 1');
      expect(_hasCastle(p, 'オールド雁木'), isTrue);
    });

    test('角が7七にも8八にも無ければ雁木と判定しない (negative)', () {
      // 銀金玉の形は雁木だが角が捌けて (or 振り飛車で) 7七/8八に居ない局面。
      // 飛車を6八へ振った振り飛車形。雁木は居飛車専用なので成立しない。
      final Position p = _pos('4k4/9/9/9/9/9/3SS4/2GRG4/3K5 b - 1');
      expect(_hasCastle(p, 'オールド雁木'), isFalse,
          reason: '角が7七/8八に無い (居飛車でない) のに雁木と誤検出している');
    });

    test('新型雁木の形を検出する (positive)', () {
      // 銀6七・銀4七 / 金7八・角6八・金5八 / 飛2九、7七/4八/3八は空き。
      final Position p = _pos('4k4/9/9/9/9/9/3S1S3/2GBG4/7R1 b - 1');
      expect(_hasCastle(p, '新型雁木'), isTrue);
    });

    test('初期局面は雁木囲いを検出しない (negative)', () {
      final Position p = Position(); // 平手初期局面
      expect(_hasCastle(p, 'オールド雁木'), isFalse);
      expect(_hasCastle(p, '新型雁木'), isFalse);
    });
  });
}
