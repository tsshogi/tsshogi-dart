import 'color.dart';
import 'direction.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'record.dart';
import 'square.dart';

// ---------------------------------------------------------------------------
// 手筋 (Technique) detection
// ---------------------------------------------------------------------------
//
// 手筋は囲い/戦法と違い「指し手」に依存する概念。各テンプレートは
// 直前の指し手 [move]、指す前の局面 [before]、指した後の局面 [after] を
// 受け取り判定する。
//
// 名称は将棋の公知用語のみを採用しており、bioshogi (AGPL-3.0) のソース
// および同名ファイル中のルール定義は一切参照していない。
// docs/plans/technique-all-names.txt の名前リスト (137 件) のみを参考に、
// 実装可能な手筋を本ファイル内で自前で起こした。
//
// === 採用方針 ===
// - 1 手 + 前後の局面で機械的に判定できるものを優先 (~80 件)。
// - 格言系 (例: 「名人に定跡なし」「両取り逃げるべからず」) は手筋ではない
//   ので除外。
// - 「形」を表す名称 (例: 「双玉接近」「銀冠の小部屋」「穴熊の姿焼き」等)
//   は手筋ではなく局面記述のため、本ファイルでは原則除外する。
// - 主観的判断を要するもの (例: 「駒の持ち腐れ」「駒得は正義」「ミニマリ
//   スト」) も除外。
// - 連続手で初めて成立する手筋 (例: 「継ぎ歩」「連打の歩」) は単発判定が
//   困難なため、現状は除外している (FIXME)。
//
// === 未実装名称 (意図的に除外) ===
// (technique-all-names.txt の 137 件中、本ファイルで実装しなかったもの)
//
// 2段ロケット / 3段ロケット / 4段ロケット / 5段ロケット / 6段ロケット / ロケット
//   — 飛 + 香 (or 飛複数) を同筋に重ねる「形」(position-based)。手筋ではな
//     く配置の表現のため除外。castle.dart / strategy.dart 側で扱う。
// タッチダウン                — 主観的。入玉の派生。
// ハッチ閉鎖                  — 主観的。
// パンドラの歩                — 出典が限定的なため除外。
// ポーンハンター              — 主観的。
// ミニマリスト                — 主観的。
// 位の確保                    — 主観的 (歩を伸ばす形勢判断を要する)。
// 全駒                        — 主観的。
// 勝ち確5三と                — 主観的。
// 双玉接近 / 双竜双馬陣 / 双馬結界
//                            — 配置 (formation)。手筋ではない。
// 名人に定跡なし              — 格言。
// 土下座の歩                  — 出典限定。
// 堅陣の金 / 壁金 / 壁銀 / 裸玉
//                            — 配置 (formation)。
// 大駒コンプリート / 大駒全ブッチ / 金銀コンプリート
//                            — 配置 (持ち駒 + 盤面の集計)。
// 封香連舞                    — 配置 (穴熊系派生)。
// 居飛車の税金                — 主観的。
// 屍の舞                      — 主観的。
// 序盤は角より飛車 / 序盤は飛車より角
//                            — 格言。
// 手得 / 手損                — 評価が必要 (-1〜+1 の手番損益)。
// 持将棋                      — 局面ルール (Record 終端で判定すべき)。
// 歩の錬金術師                — 主観的。
// 歩裏の歩 / 歩裏の香         — 配置 (敵歩の後ろの歩・香)。
// 端玉には端歩                — 格言。
// 蓋歩                        — 配置 (玉頭の歩)。
// 退場の金                    — 主観的。
// 道場出禁                    — 主観的。
// 穴熊の姿焼き / 穴熊再生      — 配置。
// 銀冠の小部屋                — 配置。
// 銀裾の歩                    — 出典限定。
// 駒の持ち腐れ / 駒得は正義    — 主観的 / 格言。
//
// === technique-all-names.txt に無い追加実装 ===
// 底歩       — 一般的な手筋用語。`底歩に香` の前提概念として独立実装。
// 合わせの歩 — 一般的な手筋用語。
// 控えの歩   — 一般的な手筋用語 (cf. 控えの桂)。
// 卓上の銀   — 大駒の脇に銀を置く一般的な手筋。
// 桂頭の歩   — 一般的な手筋用語 (桂頭の銀 / 桂頭の桂と対の概念)。

/// 手筋 (テクニック) のテンプレート抽象基底。
///
/// 各サブクラスは [matches] を実装し、指された 1 手とその前後の局面から
/// 自身の手筋に該当するかを判定する。判定は機械的なルールで近似するため、
/// 実戦的には false positive / false negative がありうる。各 FIXME 参照。
abstract class TechniqueTemplate {
  const TechniqueTemplate();

  /// 公式名 (例: 'たたきの歩')
  String get name;

  /// 別名 (例: ['叩きの歩'])
  List<String> get aliases => const <String>[];

  /// この指し手が手筋に該当するかを判定する。
  ///
  /// - [move]   : 直前に指された手 (`SpecialMove` ではなく必ず [Move])。
  /// - [before] : `move` が指される直前の局面 (move.color が手番)。
  /// - [after]  : `move` が指された直後の局面。
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after);
}

/// 検出結果。Record の何手目で発動したかを保持する。
class DetectedTechnique {
  const DetectedTechnique({
    required this.template,
    required this.ply,
    required this.color,
  });

  /// マッチした手筋テンプレート
  final TechniqueTemplate template;

  /// 手筋を発動した手数 (Record.current.ply ベース、1 始まり)
  final int ply;

  /// 手筋を指した側 (Move.color)
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is DetectedTechnique &&
      other.template.name == template.name &&
      other.ply == ply &&
      other.color == color;

  @override
  int get hashCode => Object.hash(template.name, ply, color);
}

// ---------------------------------------------------------------------------
// 公開 API
// ---------------------------------------------------------------------------

/// 単一の指し手に対して発動する手筋を全て返す。
List<TechniqueTemplate> detectTechniquesAtMove(
  Move move,
  ImmutablePosition before,
  ImmutablePosition after,
) {
  return <TechniqueTemplate>[
    for (final TechniqueTemplate t in knownTechniques)
      if (t.matches(move, before, after)) t,
  ];
}

/// 棋譜全体を走査して各手で発動した手筋を集める (重複あり版)。
///
/// 走査経路はアクティブブランチに従う ([Record.first.next] から線形)。
/// 分岐は辿らない。各手は `Position.doMove(..., ignoreValidation: true)` で
/// 適用するため、合法性チェックは行わない。
///
/// **重複あり**: 同じ手筋が複数手で発動すれば、その都度報告する。
/// 「たすきの銀」のように頻発する手筋は全 ply 分エントリが出る。
/// 「最初の 1 回だけ報告」が欲しい場合は [detectTechniquesFirstOccurrence] か
/// `record.techniques` (デフォルトは first-occurrence) を使う。
List<DetectedTechnique> detectTechniques(ImmutableRecord record) {
  final List<DetectedTechnique> results = <DetectedTechnique>[];
  final Position pos = record.initialPosition.clone();
  ImmutableNode? node = record.first.next;
  while (node != null) {
    final Object raw = node.move;
    if (raw is Move) {
      final ImmutablePosition before = pos.clone();
      pos.doMove(raw, ignoreValidation: true);
      final ImmutablePosition after = pos.clone();
      for (final TechniqueTemplate t in knownTechniques) {
        if (t.matches(raw, before, after)) {
          results.add(DetectedTechnique(
            template: t,
            ply: node.ply,
            color: raw.color,
          ));
        }
      }
    }
    node = node.next;
  }
  return results;
}

/// 棋譜全体を走査し、各 (テンプレ名, 陣営) を **最初に発動した 1 回だけ**
/// 報告する。同じ手筋が後続の手で再発動しても無視する (snapshot 重複防止)。
List<DetectedTechnique> detectTechniquesFirstOccurrence(
    ImmutableRecord record) {
  final List<DetectedTechnique> results = <DetectedTechnique>[];
  final Set<String> seen = <String>{};
  final Position pos = record.initialPosition.clone();
  ImmutableNode? node = record.first.next;
  while (node != null) {
    final Object raw = node.move;
    if (raw is Move) {
      final ImmutablePosition before = pos.clone();
      pos.doMove(raw, ignoreValidation: true);
      final ImmutablePosition after = pos.clone();
      for (final TechniqueTemplate t in knownTechniques) {
        if (!t.matches(raw, before, after)) continue;
        final String key = '${t.name}|${raw.color.value}';
        if (!seen.add(key)) continue;
        results.add(DetectedTechnique(
          template: t,
          ply: node.ply,
          color: raw.color,
        ));
      }
    }
    node = node.next;
  }
  return results;
}

/// 棋譜からの手筋検出ユーティリティ。プロパティ形式で
/// `record.techniques` のように呼べる。
///
/// **デフォルトは first-occurrence**: 同じ (手筋, 陣営) は最初の 1 回のみ
/// 報告する。たすきの銀のように繰り返し発動する手筋でもエントリは 1 件
/// になる。
///
/// 全発動を取得したい場合は [detectTechniques] を直接呼ぶ。
///
/// ```dart
/// final r = Record.newByUSI(usi)!;
/// for (final t in r.techniques) {
///   print('${t.ply}手目: ${t.template.name} (${t.color.value})');
/// }
/// ```
extension ImmutableRecordTechniques on ImmutableRecord {
  /// この棋譜のアクティブブランチを走査し、各 (手筋, 陣営) を最初の 1 回
  /// だけ返す。
  List<DetectedTechnique> get techniques =>
      detectTechniquesFirstOccurrence(this);
}

// ---------------------------------------------------------------------------
// 共通ヘルパー
// ---------------------------------------------------------------------------

/// [color] 視点の「前方」 (敵陣方向) への 1 マス。
Square? _front(Square square, Color color, [int step = 1]) {
  final Square r = color == Color.black
      ? Square(square.file, square.rank - step)
      : Square(square.file, square.rank + step);
  return r.valid ? r : null;
}

/// [color] 視点の「後方」 (自陣方向) への 1 マス。
Square? _back(Square square, Color color, [int step = 1]) {
  final Square r = color == Color.black
      ? Square(square.file, square.rank + step)
      : Square(square.file, square.rank - step);
  return r.valid ? r : null;
}

/// move 後の局面で、[piece] が動いた先の駒の利きで取れる敵駒の数。
int _countEnemyTargetsFrom(
  ImmutablePosition position,
  Square from,
  Piece piece,
) {
  int count = 0;
  for (final Direction dir in movableDirections(piece)) {
    final MoveType? type = resolveMoveType(piece, dir);
    if (type == null) continue;
    Square sq = from.neighborByDirection(dir);
    int step = 0;
    while (sq.valid) {
      step += 1;
      final Piece? p = position.board.at(sq);
      if (p != null) {
        if (p.color != piece.color && p.type != PieceType.king) {
          count += 1;
        }
        break;
      }
      if (type == MoveType.short) break;
      sq = sq.neighborByDirection(dir);
      if (step > 8) break;
    }
  }
  return count;
}

/// [target] に [color] 側の利きがあるか (Board.hasPower のラッパー)。
bool _hasPower(ImmutablePosition position, Square target, Color color) {
  return position.board.hasPower(target, color);
}

/// 先手なら 1..3 段、後手なら 7..9 段 (敵陣) かを判定。
bool _isInPromotionZone(Color color, int rank) {
  return color == Color.black ? rank <= 3 : rank >= 7;
}

/// 先手なら 7..9 段、後手なら 1..3 段 (自陣) かを判定。
bool _isInOwnCamp(Color color, int rank) {
  return color == Color.black ? rank >= 7 : rank <= 3;
}

// ---------------------------------------------------------------------------
// 歩を打つ手筋
// ---------------------------------------------------------------------------

/// たたきの歩: 相手の駒の真ん前に歩を打つ手筋。
class _TatakiNoFu extends TechniqueTemplate {
  const _TatakiNoFu();
  @override
  String get name => 'たたきの歩';
  @override
  List<String> get aliases => const <String>['叩きの歩'];
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    // 打った歩の前方 1 マスに相手の駒 (玉以外も含む)
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    if (p == null) return false;
    if (p.color == move.color) return false;
    // 王前のたたきは「頭金/頭銀」と区別したいため king は除外しない
    return true;
  }
}

/// 垂れ歩: 敵陣の 1 段手前 (黒なら 4 段) に歩を打ち、と金作りを狙う手筋。
class _TareFu extends TechniqueTemplate {
  const _TareFu();
  @override
  String get name => '垂れ歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    if (move.color == Color.black) {
      return move.to.rank == 4;
    }
    return move.to.rank == 6;
  }
}

/// 底歩: 自陣の最下段に歩を打って受ける手筋。
class _SokoFu extends TechniqueTemplate {
  const _SokoFu();
  @override
  String get name => '底歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    if (move.color == Color.black) {
      return move.to.rank == 9;
    }
    return move.to.rank == 1;
  }
}

/// 金底の歩: 自陣最下段の金の真下に歩を打って受ける手筋。
class _KinSokoFu extends TechniqueTemplate {
  const _KinSokoFu();
  @override
  String get name => '金底の歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    // 自陣最下段に歩 打 (底歩) かつ、その真上に自分の金。
    final Color c = move.color;
    if (c == Color.black ? move.to.rank != 9 : move.to.rank != 1) {
      return false;
    }
    final Square? front = _front(move.to, c);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color == c && p.type == PieceType.gold;
  }
}

/// 金底の香: 自陣最下段の金の真下に香を打つ手筋。
class _KinSokoKyou extends TechniqueTemplate {
  const _KinSokoKyou();
  @override
  String get name => '金底の香';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.lance) return false;
    final Color c = move.color;
    if (c == Color.black ? move.to.rank != 9 : move.to.rank != 1) {
      return false;
    }
    final Square? front = _front(move.to, c);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color == c && p.type == PieceType.gold;
  }
}

/// 下段の香: 香を最下段に打つ受けの手筋 (金底の香より広義)。
class _GedanNoKyou extends TechniqueTemplate {
  const _GedanNoKyou();
  @override
  String get name => '下段の香';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.lance) return false;
    return move.color == Color.black ? move.to.rank == 9 : move.to.rank == 1;
  }
}

/// 底歩に香: 底歩を支える形で香を自陣の同じ筋に置く受け筋。
/// FIXME: 「同筋に底歩 + その上に香」を 1 手で構築する場合のみ簡易判定。
class _SokoFuNiKyou extends TechniqueTemplate {
  const _SokoFuNiKyou();
  @override
  String get name => '底歩に香';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.lance) return false;
    final Color c = move.color;
    // 香を打ったマスは自陣の上端寄り。
    if (!_isInOwnCamp(c, move.to.rank)) return false;
    // 同じ筋の最下段に自分の歩がある (底歩)
    final int backRank = c == Color.black ? 9 : 1;
    final Piece? bp = before.board.at(Square(move.to.file, backRank));
    return bp != null && bp.color == c && bp.type == PieceType.pawn;
  }
}

/// 合わせの歩: 相手の歩と同じ筋に歩を打ち、捌きを狙う手筋。
class _AwaseNoFu extends TechniqueTemplate {
  const _AwaseNoFu();
  @override
  String get name => '合わせの歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    // 同じ筋に相手の歩がある (1 段以上前)
    for (int rank = 1; rank <= 9; rank += 1) {
      if (rank == move.to.rank) continue;
      final Piece? p = before.board.at(Square(move.to.file, rank));
      if (p != null && p.color != move.color && p.type == PieceType.pawn) {
        return true;
      }
    }
    return false;
  }
}

/// 桂頭の歩: 相手の桂の真ん前 (頭) に歩を打って桂を釘付けにする手筋。
class _KeitouNoFu extends TechniqueTemplate {
  const _KeitouNoFu();
  @override
  String get name => '桂頭の歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color != move.color && p.type == PieceType.knight;
  }
}

/// 桂頭の桂: 相手の桂の頭に桂を打って圧迫する手筋。
class _KeitouNoKei extends TechniqueTemplate {
  const _KeitouNoKei();
  @override
  String get name => '桂頭の桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.knight) return false;
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color != move.color && p.type == PieceType.knight;
  }
}

/// 桂頭の銀: 相手の桂の頭に銀を打って圧力をかける手筋。
class _KeitouNoGin extends TechniqueTemplate {
  const _KeitouNoGin();
  @override
  String get name => '桂頭の銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.silver) return false;
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color != move.color && p.type == PieceType.knight;
  }
}

/// 桂頭の玉: 自分の桂の前 2 マスに玉を寄せて桂を守る/活かす手筋。
/// FIXME: 玉が自桂の前 (knight 移動先候補) に寄った形を簡易判定。
class _KeitouNoGyoku extends TechniqueTemplate {
  const _KeitouNoGyoku();
  @override
  String get name => '桂頭の玉';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.king) return false;
    // 玉の移動先の前方 2 マスに自分の桂がいるか
    final Color c = move.color;
    final Square? frontKnight = _front(move.to, c, 2);
    if (frontKnight == null) return false;
    final Piece? p = after.board.at(frontKnight);
    return p != null && p.color == c && p.type == PieceType.knight;
  }
}

/// 桂頭攻め: 相手の桂頭 (前 1 マス) への攻め。歩以外も含む。
class _KeitouZeme extends TechniqueTemplate {
  const _KeitouZeme();
  @override
  String get name => '桂頭攻め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    // 駒種は問わず、相手の桂の頭に駒を運ぶ・打つ手。
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color != move.color && p.type == PieceType.knight;
  }
}

/// 歩頭の桂: 相手の歩の頭 (前) に飛び込む桂の手筋。
class _FuTouNoKei extends TechniqueTemplate {
  const _FuTouNoKei();
  @override
  String get name => '歩頭の桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight) return false;
    // 移動先の 1 マス手前 (敵陣方向) に相手の歩
    final Square? back = _back(move.to, move.color);
    if (back == null) return false;
    final Piece? p = before.board.at(back);
    return p != null && p.color != move.color && p.type == PieceType.pawn;
  }
}

/// 金頭の桂: 相手の金の頭の前方に桂をかける手筋。
class _KinTouNoKei extends TechniqueTemplate {
  const _KinTouNoKei();
  @override
  String get name => '金頭の桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight) return false;
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color != move.color && p.type == PieceType.gold;
  }
}

/// 角頭攻め: 相手の角の頭への攻め (歩・銀・他いずれの駒種でも)。
class _KakuTouZeme extends TechniqueTemplate {
  const _KakuTouZeme();
  @override
  String get name => '角頭攻め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null &&
        p.color != move.color &&
        (p.type == PieceType.bishop || p.type == PieceType.horse);
  }
}

/// 玉頭攻め: 相手の玉の頭への攻め。
class _GyokuTouZeme extends TechniqueTemplate {
  const _GyokuTouZeme();
  @override
  String get name => '玉頭攻め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    return p != null && p.color != move.color && p.type == PieceType.king;
  }
}

/// 玉頭戦: 相手玉の周囲 (2 マス以内) で攻防が行われる手筋。
/// FIXME: 玉の周囲 2 マス以内への攻撃手 (打 or 移動) を簡易判定。
class _GyokuTouSen extends TechniqueTemplate {
  const _GyokuTouSen();
  @override
  String get name => '玉頭戦';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    final int dx = (move.to.file - enemyKing.file).abs();
    final int dy = (move.to.rank - enemyKing.rank).abs();
    if (dx > 2 || dy > 2) return false;
    // 玉の頭 (前) を含む 5x5 圏内で、特に前方 2 段に絞る
    final Color enemy = reverseColor(move.color);
    final int frontSide = enemy == Color.black ? -1 : 1; // 玉から見た前は自玉視点
    final int rankDiff = (move.to.rank - enemyKing.rank) * frontSide;
    // rankDiff < 0 だと玉から見て後ろ。我々が攻める側なので「玉の頭 (玉の前)」
    // すなわち rankDiff > 0 のときが攻め。
    return rankDiff > 0;
  }
}

// ---------------------------------------------------------------------------
// 駒打ち手筋
// ---------------------------------------------------------------------------

/// 割り打ちの銀: 銀を打って 2 つの駒に両取りをかける手筋。
class _WaridashiNoGin extends TechniqueTemplate {
  const _WaridashiNoGin();
  @override
  String get name => '割り打ちの銀';
  @override
  List<String> get aliases => const <String>['割打ちの銀'];
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.silver) return false;
    final Piece dropped = Piece(move.color, PieceType.silver);
    final int targets = _countEnemyTargetsFrom(after, move.to, dropped);
    return targets >= 2;
  }
}

/// ふんどしの桂: 桂を打って 2 つの駒に両取りをかける手筋。
class _FundoshiNoKei extends TechniqueTemplate {
  const _FundoshiNoKei();
  @override
  String get name => 'ふんどしの桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.knight) return false;
    final Piece dropped = Piece(move.color, PieceType.knight);
    final int targets = _countEnemyTargetsFrom(after, move.to, dropped);
    return targets >= 2;
  }
}

/// 両取り: 1 手で 2 つの駒に当てる手筋 (汎用)。
class _RyoTori extends TechniqueTemplate {
  const _RyoTori();
  @override
  String get name => '両取り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Piece p = Piece(
      move.color,
      move.promote ? promotedPieceType(move.pieceType) : move.pieceType,
    );
    final int targets = _countEnemyTargetsFrom(after, move.to, p);
    return targets >= 2;
  }
}

/// 角による両取り: 角 (打 or 移動 or 成) で 2 つの駒に当てる手筋。
class _KakuRyoTori extends TechniqueTemplate {
  const _KakuRyoTori();
  @override
  String get name => '角による両取り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType after_ =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (after_ != PieceType.bishop && after_ != PieceType.horse) return false;
    final int targets =
        _countEnemyTargetsFrom(after, move.to, Piece(move.color, after_));
    return targets >= 2;
  }
}

/// 飛車による両取り: 飛 (打 or 移動 or 成) で 2 つの駒に当てる手筋。
class _HishaRyoTori extends TechniqueTemplate {
  const _HishaRyoTori();
  @override
  String get name => '飛車による両取り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType after_ =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (after_ != PieceType.rook && after_ != PieceType.dragon) return false;
    final int targets =
        _countEnemyTargetsFrom(after, move.to, Piece(move.color, after_));
    return targets >= 2;
  }
}

/// 卓上の銀: 中央のマスに銀を打って攻めの拠点を作る手筋。
/// FIXME: 「銀打」かつ移動先が中央 (4-6 筋 / 4-6 段) を簡易判定。
class _TakujouNoGin extends TechniqueTemplate {
  const _TakujouNoGin();
  @override
  String get name => '卓上の銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.silver) return false;
    final int f = move.to.file;
    final int r = move.to.rank;
    return f >= 4 && f <= 6 && r >= 4 && r <= 6;
  }
}

/// 田楽刺し: 1 つの香/飛で 2 駒以上を串刺しにする手筋。
class _DengakuZashi extends TechniqueTemplate {
  const _DengakuZashi();
  @override
  String get name => '田楽刺し';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType pt =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    // 串刺しは飛・香・竜の利き上 (縦の long move) で 2 駒以上を通す。
    if (pt != PieceType.lance &&
        pt != PieceType.rook &&
        pt != PieceType.dragon) {
      return false;
    }
    // 移動先から「前方」を見て駒数を数える。
    final Square from = move.to;
    int captured = 0;
    Square sq = _front(from, move.color) ?? from;
    if (sq.equals(from)) return false;
    int step = 0;
    while (sq.valid) {
      step += 1;
      final Piece? p = after.board.at(sq);
      if (p != null) {
        if (p.color == move.color) break;
        captured += 1;
        if (captured >= 2) return true;
      }
      sq = _front(sq, move.color) ?? sq;
      if (step > 8) break;
    }
    return false;
  }
}

/// 控えの歩: 自陣の深い位置 (1 段下の支え) に歩を打つ手筋。
class _HikaeNoFu extends TechniqueTemplate {
  const _HikaeNoFu();
  @override
  String get name => '控えの歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    // 自陣 (rank 7-8 for black) に歩打ち
    return move.color == Color.black
        ? move.to.rank == 7 || move.to.rank == 8
        : move.to.rank == 3 || move.to.rank == 2;
  }
}

/// 控えの桂: 自陣に桂を打って後の跳ねを準備する手筋。
class _HikaeNoKei extends TechniqueTemplate {
  const _HikaeNoKei();
  @override
  String get name => '控えの桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.knight) return false;
    return _isInOwnCamp(move.color, move.to.rank);
  }
}

/// 自陣飛車: 自陣に飛車を打って受けを固める手筋。
class _JijinHisha extends TechniqueTemplate {
  const _JijinHisha();
  @override
  String get name => '自陣飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.rook) return false;
    return _isInOwnCamp(move.color, move.to.rank);
  }
}

/// 自陣角: 自陣に角を打って受けと反撃を兼ねる手筋。
class _JijinKaku extends TechniqueTemplate {
  const _JijinKaku();
  @override
  String get name => '自陣角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.bishop) return false;
    return _isInOwnCamp(move.color, move.to.rank);
  }
}

/// 遠見の角: 最下段 (or 自陣の遠隔) に角を打って遠くに利かせる手筋。
class _TomiNoKaku extends TechniqueTemplate {
  const _TomiNoKaku();
  @override
  String get name => '遠見の角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.bishop) return false;
    // 自陣最下段 or 段差 8 (rank 9 for black, rank 1 for white) に近い
    return move.color == Color.black ? move.to.rank == 9 : move.to.rank == 1;
  }
}

/// 二枚飛車: 自分の飛車が盤上にあるのに更に飛車を打つ手筋 (or 同筋に並ぶ)。
class _NimaiHisha extends TechniqueTemplate {
  const _NimaiHisha();
  @override
  String get name => '二枚飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    // 駒打ちかつ、すでに飛車 (or 竜) が盤上に自分側で存在。
    if (move.from is! FromHand) return false;
    for (final entry in before.board.listNonEmptySquares()) {
      if (entry.piece.color != move.color) continue;
      if (entry.piece.type == PieceType.rook ||
          entry.piece.type == PieceType.dragon) {
        return true;
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// 王 / 玉に対する手筋
// ---------------------------------------------------------------------------

/// 頭金: 相手玉の真ん前に金を置く詰めの基本手筋。
class _AtamaKin extends TechniqueTemplate {
  const _AtamaKin();
  @override
  String get name => '頭金';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType pt =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    // 金 (もしくは成駒の金相当) で前方が敵玉
    if (pt != PieceType.gold &&
        pt != PieceType.promPawn &&
        pt != PieceType.promLance &&
        pt != PieceType.promKnight &&
        pt != PieceType.promSilver) {
      return false;
    }
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? king = before.board.at(front);
    return king != null &&
        king.color != move.color &&
        king.type == PieceType.king;
  }
}

/// 頭銀: 相手玉の真ん前に銀を置く詰めの手筋。
class _AtamaGin extends TechniqueTemplate {
  const _AtamaGin();
  @override
  String get name => '頭銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.silver) return false;
    if (move.promote) return false;
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? king = before.board.at(front);
    return king != null &&
        king.color != move.color &&
        king.type == PieceType.king;
  }
}

/// 腹金: 相手玉の真横 (左右) に金を打つ詰めの手筋。
class _HaraKin extends TechniqueTemplate {
  const _HaraKin();
  @override
  String get name => '腹金';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType pt =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (pt != PieceType.gold &&
        pt != PieceType.promPawn &&
        pt != PieceType.promLance &&
        pt != PieceType.promKnight &&
        pt != PieceType.promSilver) {
      return false;
    }
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    return move.to.rank == enemyKing.rank &&
        (move.to.file - enemyKing.file).abs() == 1;
  }
}

/// 腹銀: 相手玉の真横 (左右) に銀を打つ詰めの手筋。
class _HaraGin extends TechniqueTemplate {
  const _HaraGin();
  @override
  String get name => '腹銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.silver) return false;
    if (move.promote) return false;
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    return move.to.rank == enemyKing.rank &&
        (move.to.file - enemyKing.file).abs() == 1;
  }
}

/// 尻金: 相手玉の真後ろに金を打つ手筋。
class _ShiriKin extends TechniqueTemplate {
  const _ShiriKin();
  @override
  String get name => '尻金';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType pt =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (pt != PieceType.gold &&
        pt != PieceType.promPawn &&
        pt != PieceType.promLance &&
        pt != PieceType.promKnight &&
        pt != PieceType.promSilver) {
      return false;
    }
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    // 玉から見た「後ろ」 (= 攻め側から見た「前」のさらに 1 段奥)
    final Color enemy = reverseColor(move.color);
    final Square? behindKing = _back(enemyKing, enemy);
    return behindKing != null && move.to.equals(behindKing);
  }
}

/// 尻銀: 相手玉の真後ろに銀を打つ手筋。
class _ShiriGin extends TechniqueTemplate {
  const _ShiriGin();
  @override
  String get name => '尻銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.silver) return false;
    if (move.promote) return false;
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    final Color enemy = reverseColor(move.color);
    final Square? behindKing = _back(enemyKing, enemy);
    return behindKing != null && move.to.equals(behindKing);
  }
}

/// 肩金: 相手玉の斜め前 (玉から見た左右肩) に金を打つ手筋。
class _KataKin extends TechniqueTemplate {
  const _KataKin();
  @override
  String get name => '肩金';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType pt =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (pt != PieceType.gold &&
        pt != PieceType.promPawn &&
        pt != PieceType.promLance &&
        pt != PieceType.promKnight &&
        pt != PieceType.promSilver) {
      return false;
    }
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    // 玉から見て前 1 段 + 横 1 列
    final Color enemy = reverseColor(move.color);
    final int frontRank =
        enemy == Color.black ? enemyKing.rank - 1 : enemyKing.rank + 1;
    return move.to.rank == frontRank &&
        (move.to.file - enemyKing.file).abs() == 1;
  }
}

/// 肩銀: 相手玉の斜め前に銀を打つ手筋。
class _KataGin extends TechniqueTemplate {
  const _KataGin();
  @override
  String get name => '肩銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.silver) return false;
    if (move.promote) return false;
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    final Color enemy = reverseColor(move.color);
    final int frontRank =
        enemy == Color.black ? enemyKing.rank - 1 : enemyKing.rank + 1;
    return move.to.rank == frontRank &&
        (move.to.file - enemyKing.file).abs() == 1;
  }
}

/// 裾金: 相手玉の斜め後ろに金を打つ手筋。
class _SusoKin extends TechniqueTemplate {
  const _SusoKin();
  @override
  String get name => '裾金';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final PieceType pt =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (pt != PieceType.gold &&
        pt != PieceType.promPawn &&
        pt != PieceType.promLance &&
        pt != PieceType.promKnight &&
        pt != PieceType.promSilver) {
      return false;
    }
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    final Color enemy = reverseColor(move.color);
    final int backRank =
        enemy == Color.black ? enemyKing.rank + 1 : enemyKing.rank - 1;
    return move.to.rank == backRank &&
        (move.to.file - enemyKing.file).abs() == 1;
  }
}

/// 裾銀: 相手玉の斜め後ろに銀を打つ手筋。
class _SusoGin extends TechniqueTemplate {
  const _SusoGin();
  @override
  String get name => '裾銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.silver) return false;
    if (move.promote) return false;
    final Square? enemyKing = before.board.findKing(reverseColor(move.color));
    if (enemyKing == null) return false;
    final Color enemy = reverseColor(move.color);
    final int backRank =
        enemy == Color.black ? enemyKing.rank + 1 : enemyKing.rank - 1;
    return move.to.rank == backRank &&
        (move.to.file - enemyKing.file).abs() == 1;
  }
}

// ---------------------------------------------------------------------------
// 王手・準王手系
// ---------------------------------------------------------------------------

/// 王手飛車: 王手と同時に飛車にも当てる手筋。
class _OuteHisha extends TechniqueTemplate {
  const _OuteHisha();
  @override
  String get name => '王手飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Color enemy = reverseColor(move.color);
    if (!after.board.isChecked(enemy)) return false;
    final Piece moved = Piece(
      move.color,
      move.promote ? promotedPieceType(move.pieceType) : move.pieceType,
    );
    // 移動先の利きに敵の飛車 (or 竜) が含まれるか
    for (final Direction dir in movableDirections(moved)) {
      final MoveType? type = resolveMoveType(moved, dir);
      if (type == null) continue;
      Square sq = move.to.neighborByDirection(dir);
      int step = 0;
      while (sq.valid) {
        step += 1;
        final Piece? p = after.board.at(sq);
        if (p != null) {
          if (p.color != move.color &&
              (p.type == PieceType.rook || p.type == PieceType.dragon)) {
            return true;
          }
          break;
        }
        if (type == MoveType.short) break;
        sq = sq.neighborByDirection(dir);
        if (step > 8) break;
      }
    }
    return false;
  }
}

/// 王手角: 王手と同時に角にも当てる手筋。
class _OuteKaku extends TechniqueTemplate {
  const _OuteKaku();
  @override
  String get name => '王手角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Color enemy = reverseColor(move.color);
    if (!after.board.isChecked(enemy)) return false;
    final Piece moved = Piece(
      move.color,
      move.promote ? promotedPieceType(move.pieceType) : move.pieceType,
    );
    for (final Direction dir in movableDirections(moved)) {
      final MoveType? type = resolveMoveType(moved, dir);
      if (type == null) continue;
      Square sq = move.to.neighborByDirection(dir);
      int step = 0;
      while (sq.valid) {
        step += 1;
        final Piece? p = after.board.at(sq);
        if (p != null) {
          if (p.color != move.color &&
              (p.type == PieceType.bishop || p.type == PieceType.horse)) {
            return true;
          }
          break;
        }
        if (type == MoveType.short) break;
        sq = sq.neighborByDirection(dir);
        if (step > 8) break;
      }
    }
    return false;
  }
}

/// 準王手飛車: 王手なしで相手の飛 (or 竜) に当てる手筋。
class _JunOuteHisha extends TechniqueTemplate {
  const _JunOuteHisha();
  @override
  String get name => '準王手飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Color enemy = reverseColor(move.color);
    if (after.board.isChecked(enemy)) return false;
    final Piece moved = Piece(
      move.color,
      move.promote ? promotedPieceType(move.pieceType) : move.pieceType,
    );
    for (final Direction dir in movableDirections(moved)) {
      final MoveType? type = resolveMoveType(moved, dir);
      if (type == null) continue;
      Square sq = move.to.neighborByDirection(dir);
      int step = 0;
      while (sq.valid) {
        step += 1;
        final Piece? p = after.board.at(sq);
        if (p != null) {
          if (p.color != move.color &&
              (p.type == PieceType.rook || p.type == PieceType.dragon)) {
            return true;
          }
          break;
        }
        if (type == MoveType.short) break;
        sq = sq.neighborByDirection(dir);
        if (step > 8) break;
      }
    }
    return false;
  }
}

/// 準王手角: 王手なしで相手の角 (or 馬) に当てる手筋。
class _JunOuteKaku extends TechniqueTemplate {
  const _JunOuteKaku();
  @override
  String get name => '準王手角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Color enemy = reverseColor(move.color);
    if (after.board.isChecked(enemy)) return false;
    final Piece moved = Piece(
      move.color,
      move.promote ? promotedPieceType(move.pieceType) : move.pieceType,
    );
    for (final Direction dir in movableDirections(moved)) {
      final MoveType? type = resolveMoveType(moved, dir);
      if (type == null) continue;
      Square sq = move.to.neighborByDirection(dir);
      int step = 0;
      while (sq.valid) {
        step += 1;
        final Piece? p = after.board.at(sq);
        if (p != null) {
          if (p.color != move.color &&
              (p.type == PieceType.bishop || p.type == PieceType.horse)) {
            return true;
          }
          break;
        }
        if (type == MoveType.short) break;
        sq = sq.neighborByDirection(dir);
        if (step > 8) break;
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// 駒交換 / 駒得 / 駒捨て系
// ---------------------------------------------------------------------------

/// 角交換: 角を捌いて相手の角を取る手筋。
class _KakuKoukan extends TechniqueTemplate {
  const _KakuKoukan();
  @override
  String get name => '角交換';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.bishop &&
        move.pieceType != PieceType.horse) {
      return false;
    }
    if (move.capturedPieceType == null) return false;
    return move.capturedPieceType == PieceType.bishop ||
        move.capturedPieceType == PieceType.horse;
  }
}

/// 飛車先交換: 飛車先 (file 2 or 8) の歩を交換する手筋。
class _HishaSakiKoukan extends TechniqueTemplate {
  const _HishaSakiKoukan();
  @override
  String get name => '飛車先交換';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.pawn) return false;
    if (move.from is! FromSquare) return false;
    if (move.capturedPieceType != PieceType.pawn) return false;
    // 飛車先 = 黒なら 2 筋, 白なら 8 筋
    final int file = move.to.file;
    return move.color == Color.black ? file == 2 : file == 8;
  }
}

/// 角切り: 自分の角を相手に取らせる (=捨てる) 手筋。
/// 「自分が捨てた直後 = before に自陣の角」「after にはその位置に
/// 敵駒 (捕獲後) or 自駒なし」「相手が取れる場所」と検出するのは難しいため、
/// 「角で取らせるべく踏み込む」=「敵駒に取られる位置への角の進出 / 打」
/// で簡易判定。
class _KakuGiri extends TechniqueTemplate {
  const _KakuGiri();
  @override
  String get name => '角切り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.bishop &&
        move.pieceType != PieceType.horse) {
      return false;
    }
    // 移動先に踏み込んだ角に対し相手の利きがある (=取られる位置)
    return _hasPower(after, move.to, reverseColor(move.color));
  }
}

/// 飛車切り: 自分の飛車を相手に取らせる手筋。
class _HishaGiri extends TechniqueTemplate {
  const _HishaGiri();
  @override
  String get name => '飛車切り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    return _hasPower(after, move.to, reverseColor(move.color));
  }
}

/// 馬切り: 自分の馬を相手に取らせる手筋。
class _UmaGiri extends TechniqueTemplate {
  const _UmaGiri();
  @override
  String get name => '馬切り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.horse) return false;
    return _hasPower(after, move.to, reverseColor(move.color));
  }
}

/// 竜切り: 自分の竜を相手に取らせる手筋。
class _RyuGiri extends TechniqueTemplate {
  const _RyuGiri();
  @override
  String get name => '竜切り';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.dragon) return false;
    return _hasPower(after, move.to, reverseColor(move.color));
  }
}

// ---------------------------------------------------------------------------
// マッチアップ系 (取り方)
// ---------------------------------------------------------------------------

/// 角には角: 相手の角を自分の角で取る手筋。
class _KakuNihaKaku extends TechniqueTemplate {
  const _KakuNihaKaku();
  @override
  String get name => '角には角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.bishop) return false;
    return move.capturedPieceType == PieceType.bishop;
  }
}

/// 角には飛車: 相手の角を自分の飛車で取る手筋。
class _KakuNihaHisha extends TechniqueTemplate {
  const _KakuNihaHisha();
  @override
  String get name => '角には飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    return move.capturedPieceType == PieceType.bishop;
  }
}

/// 飛車には角: 相手の飛車を自分の角で取る手筋。
class _HishaNihaKaku extends TechniqueTemplate {
  const _HishaNihaKaku();
  @override
  String get name => '飛車には角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.bishop &&
        move.pieceType != PieceType.horse) {
      return false;
    }
    return move.capturedPieceType == PieceType.rook;
  }
}

/// 飛車には飛車: 相手の飛車を自分の飛車で取る手筋。
class _HishaNihaHisha extends TechniqueTemplate {
  const _HishaNihaHisha();
  @override
  String get name => '飛車には飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    return move.capturedPieceType == PieceType.rook;
  }
}

/// 馬には角: 相手の馬を自分の角で取る手筋。
class _UmaNihaKaku extends TechniqueTemplate {
  const _UmaNihaKaku();
  @override
  String get name => '馬には角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.bishop &&
        move.pieceType != PieceType.horse) {
      return false;
    }
    return move.capturedPieceType == PieceType.horse;
  }
}

/// 馬には飛車: 相手の馬を自分の飛車で取る手筋。
class _UmaNihaHisha extends TechniqueTemplate {
  const _UmaNihaHisha();
  @override
  String get name => '馬には飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    return move.capturedPieceType == PieceType.horse;
  }
}

/// 龍には角: 相手の竜を自分の角で取る手筋。
class _RyuNihaKaku extends TechniqueTemplate {
  const _RyuNihaKaku();
  @override
  String get name => '龍には角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.bishop &&
        move.pieceType != PieceType.horse) {
      return false;
    }
    return move.capturedPieceType == PieceType.dragon;
  }
}

/// 龍には飛車: 相手の竜を自分の飛車で取る手筋。
class _RyuNihaHisha extends TechniqueTemplate {
  const _RyuNihaHisha();
  @override
  String get name => '龍には飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    return move.capturedPieceType == PieceType.dragon;
  }
}

// ---------------------------------------------------------------------------
// 不成 (移動先が成れるのに成らない手)
// ---------------------------------------------------------------------------

/// 銀不成: 銀が敵陣に入る (or 敵陣で動く) のに敢えて成らない手筋。
class _GinNarazu extends TechniqueTemplate {
  const _GinNarazu();
  @override
  String get name => '銀不成';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.silver) return false;
    if (move.promote) return false;
    final FromSquare fs = move.from as FromSquare;
    return _isInPromotionZone(move.color, fs.square.rank) ||
        _isInPromotionZone(move.color, move.to.rank);
  }
}

/// 角不成: 角が敵陣に入るのに成らない手筋。
class _KakuNarazu extends TechniqueTemplate {
  const _KakuNarazu();
  @override
  String get name => '角不成';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.bishop) return false;
    if (move.promote) return false;
    final FromSquare fs = move.from as FromSquare;
    return _isInPromotionZone(move.color, fs.square.rank) ||
        _isInPromotionZone(move.color, move.to.rank);
  }
}

/// 飛車不成: 飛車が敵陣に入るのに成らない手筋。
class _HishaNarazu extends TechniqueTemplate {
  const _HishaNarazu();
  @override
  String get name => '飛車不成';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.rook) return false;
    if (move.promote) return false;
    final FromSquare fs = move.from as FromSquare;
    return _isInPromotionZone(move.color, fs.square.rank) ||
        _isInPromotionZone(move.color, move.to.rank);
  }
}

// ---------------------------------------------------------------------------
// その他 / 単発判定
// ---------------------------------------------------------------------------

/// 端攻め: 1 筋 or 9 筋への攻め (歩・桂・銀・香等が端へ進出)。
class _HashiZeme extends TechniqueTemplate {
  const _HashiZeme();
  @override
  String get name => '端攻め';
  @override
  List<String> get aliases => const <String>['端攻撃'];
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.to.file != 1 && move.to.file != 9) return false;
    // 自陣の端 (rank 9 for black) より敵陣方向への進出のみ
    if (_isInOwnCamp(move.color, move.to.rank)) return false;
    return true;
  }
}

/// 端玉: 玉を端 (1 筋 / 9 筋) に寄せる手筋。
class _HashiGyoku extends TechniqueTemplate {
  const _HashiGyoku();
  @override
  String get name => '端玉';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.king) return false;
    return move.to.file == 1 || move.to.file == 9;
  }
}

/// 中段玉: 玉を中段 (5 段目周辺) に進出させる手筋。
class _ChudanGyoku extends TechniqueTemplate {
  const _ChudanGyoku();
  @override
  String get name => '中段玉';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.king) return false;
    return move.to.rank == 5;
  }
}

/// 玉単騎: 玉が他の駒と離れて単独行動する手筋。
/// FIXME: 「玉の周囲 1 マスに自駒がない状態で玉が動く」を簡易判定。
class _GyokuTanki extends TechniqueTemplate {
  const _GyokuTanki();
  @override
  String get name => '玉単騎';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.king) return false;
    // after で玉の周囲 8 マスに自駒なし
    for (final Direction dir in directions) {
      final Square sq = move.to.neighborByDirection(dir);
      if (!sq.valid) continue;
      final Piece? p = after.board.at(sq);
      if (p != null && p.color == move.color) return false;
    }
    return true;
  }
}

/// 玉飛接近: 玉と飛車が接近する手筋 (悪手の代表だが定型用語)。
class _GyokuHiSekkin extends TechniqueTemplate {
  const _GyokuHiSekkin();
  @override
  String get name => '玉飛接近';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.king &&
        move.pieceType != PieceType.rook &&
        move.pieceType != PieceType.dragon) {
      return false;
    }
    final Square? king = after.board.findKing(move.color);
    if (king == null) return false;
    // 自分の飛車 (or 竜) の位置
    for (final entry in after.board.listNonEmptySquares()) {
      if (entry.piece.color != move.color) continue;
      if (entry.piece.type == PieceType.rook ||
          entry.piece.type == PieceType.dragon) {
        final int dx = (entry.square.file - king.file).abs();
        final int dy = (entry.square.rank - king.rank).abs();
        if (dx <= 2 && dy <= 2) return true;
      }
    }
    return false;
  }
}

/// 入玉: 玉が敵陣 (3 段以内) に入る手筋。
class _Nyuugyoku extends TechniqueTemplate {
  const _Nyuugyoku();
  @override
  String get name => '入玉';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.king) return false;
    return _isInPromotionZone(move.color, move.to.rank) &&
        (move.from is! FromSquare ||
            !_isInPromotionZone(
                move.color, (move.from as FromSquare).square.rank));
  }
}

/// 浮き飛車: 飛車を 1 段浮かせる (rank 6 for black 等) 手筋。
class _UkiHisha extends TechniqueTemplate {
  const _UkiHisha();
  @override
  String get name => '浮き飛車';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.rook) return false;
    if (move.from is! FromSquare) return false;
    final FromSquare fs = move.from as FromSquare;
    // 飛車を初期段 (黒 8段 / 白 2段) から浮かせる
    if (move.color == Color.black) {
      return fs.square.rank == 8 && move.to.rank == 6;
    }
    return fs.square.rank == 2 && move.to.rank == 4;
  }
}

/// 守りの馬: 自陣に馬を引いて守りに使う手筋。
class _MamoriNoUma extends TechniqueTemplate {
  const _MamoriNoUma();
  @override
  String get name => '守りの馬';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    // 馬になる (or すでに馬) + 移動先が自陣
    final PieceType after_ =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (after_ != PieceType.horse) return false;
    return _isInOwnCamp(move.color, move.to.rank);
  }
}

/// と金攻め: と金 (成歩) で攻める手筋。
class _ToKinZeme extends TechniqueTemplate {
  const _ToKinZeme();
  @override
  String get name => 'と金攻め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    // 成歩を動かす (移動 with FromSquare) or 歩を成る手
    if (move.promote &&
        move.pieceType == PieceType.pawn &&
        move.from is FromSquare) {
      return true;
    }
    return move.pieceType == PieceType.promPawn;
  }
}

/// マムシのと金: と金で相手陣を駆け回る手筋 (と金攻めの強化版扱い)。
class _MamushiNoToKin extends TechniqueTemplate {
  const _MamushiNoToKin();
  @override
  String get name => 'マムシのと金';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.promPawn) return false;
    // 敵陣で動くと金 (黒なら rank<=3)
    return _isInPromotionZone(move.color, move.to.rank);
  }
}

/// 突き捨て: 歩を突いて捨てる (=取られる位置に進む) 手筋。
class _TsukiSute extends TechniqueTemplate {
  const _TsukiSute();
  @override
  String get name => '突き捨て';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.pawn) return false;
    if (move.from is! FromSquare) return false;
    if (move.capturedPieceType != null) return false;
    // 突いた歩が相手の利きにある (取られる)
    return _hasPower(after, move.to, reverseColor(move.color));
  }
}

/// 突き違いの歩: 歩を斜めに動かす (=相手の歩を取る) 手筋。
class _TsukiChigaiNoFu extends TechniqueTemplate {
  const _TsukiChigaiNoFu();
  @override
  String get name => '突き違いの歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    // 歩は元々斜め移動不可。capturedPieceType != null かつ 歩 という条件は
    // 「成り捨て」を伴う取り方を想定する将棋用語のため、簡易判定:
    // 自歩が取ったマスに相手の歩がいた、かつ突きと同じ筋ではない。
    if (move.pieceType != PieceType.pawn) return false;
    if (move.capturedPieceType != PieceType.pawn) return false;
    if (move.from is! FromSquare) return false;
    final FromSquare fs = move.from as FromSquare;
    return fs.square.file != move.to.file;
  }
}

/// 連打の歩: 2 手連続で歩を打つ手筋。
/// FIXME: 単発の指し手では判定できない。常に false を返す stub。
class _RendaNoFu extends TechniqueTemplate {
  const _RendaNoFu();
  @override
  String get name => '連打の歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    // FIXME: 連続手の文脈が必要。現状は実装保留 (false 固定)。
    return false;
  }
}

/// 継ぎ歩: 直前と同じ筋に歩を打って継ぐ手筋。
/// FIXME: 直前の指し手の文脈が必要。常に false。
class _TsugiFu extends TechniqueTemplate {
  const _TsugiFu();
  @override
  String get name => '継ぎ歩';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    return false; // FIXME
  }
}

/// 継ぎ桂: 直前の桂と連携した桂跳ねの手筋。
/// FIXME: 直前手の文脈が必要。簡易: 桂跳ねで前方に自桂が既にある。
class _TsugiKei extends TechniqueTemplate {
  const _TsugiKei();
  @override
  String get name => '継ぎ桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight) return false;
    // 移動先の 2 マス先 (桂跳び着地点 from 視点で考えると次の継ぎ桂が跳ねうる場所)
    final Square? front2 = _front(move.to, move.color, 2);
    if (front2 == null) return false;
    final Piece? p = before.board.at(front2);
    return p != null && p.color == move.color && p.type == PieceType.knight;
  }
}

/// 吊るし桂: 既に駒が密集している中に桂を投入し攻めの拠点にする手筋。
/// FIXME: 「桂を打って王の近くで吊るす」=「相手玉の 2 マス前後 ± 1 筋」と簡易判定。
class _TsurushiKei extends TechniqueTemplate {
  const _TsurushiKei();
  @override
  String get name => '吊るし桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.knight) return false;
    // 桂を打ってその利き先に敵玉
    final Piece p = Piece(move.color, PieceType.knight);
    for (final Direction dir in movableDirections(p)) {
      final Square sq = move.to.neighborByDirection(dir);
      if (!sq.valid) continue;
      final Piece? target = before.board.at(sq);
      if (target != null &&
          target.color != move.color &&
          target.type == PieceType.king) {
        return true;
      }
    }
    return false;
  }
}

/// 高跳びの桂: 桂を取られる覚悟で大きく跳ねる手筋 (= 跳ねた先に相手の利き)。
class _TakatobiNoKei extends TechniqueTemplate {
  const _TakatobiNoKei();
  @override
  String get name => '高跳びの桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight) return false;
    if (move.from is! FromSquare) return false;
    return _hasPower(after, move.to, reverseColor(move.color));
  }
}

/// 急所の桂: 急所 (=相手玉から 2 マス以内) に桂を効かせる手筋。
class _KyushoNoKei extends TechniqueTemplate {
  const _KyushoNoKei();
  @override
  String get name => '急所の桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight) return false;
    final Square? king = before.board.findKing(reverseColor(move.color));
    if (king == null) return false;
    final int dx = (move.to.file - king.file).abs();
    final int dy = (move.to.rank - king.rank).abs();
    return dx <= 2 && dy <= 2;
  }
}

/// 技ありの桂: 桂で両取りや王手を狙う手筋 (=移動 or 打で targets >= 2)。
class _WazaariNoKei extends TechniqueTemplate {
  const _WazaariNoKei();
  @override
  String get name => '技ありの桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight) return false;
    final Piece dropped = Piece(move.color, PieceType.knight);
    return _countEnemyTargetsFrom(after, move.to, dropped) >= 2;
  }
}

/// 跳ね違いの桂: 跳ねるべき方向と異なる方向に跳ねる桂の手筋。
/// FIXME: 「右桂は左へ、左桂は右へ」の判定は file の位置に依存。
class _HaneChigaiNoKei extends TechniqueTemplate {
  const _HaneChigaiNoKei();
  @override
  String get name => '跳ね違いの桂';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.knight) return false;
    final FromSquare fs = move.from as FromSquare;
    // 右桂 (file 2 for black) が左 (file 増加方向) へ跳ねる、その逆も。
    if (move.color == Color.black) {
      if (fs.square.file == 2 && move.to.file == 3) return true;
      if (fs.square.file == 8 && move.to.file == 7) return true;
    } else {
      if (fs.square.file == 2 && move.to.file == 3) return true;
      if (fs.square.file == 8 && move.to.file == 7) return true;
    }
    return false;
  }
}

/// 三桂懐刃: 自陣に桂が 3 枚揃って攻撃に参加する手筋。
/// FIXME: 「自分の桂 (+ 成桂) の合計が盤上に 3 枚以上」になった指し手で発動。
class _SanKeiFutokoroKatana extends TechniqueTemplate {
  const _SanKeiFutokoroKatana();
  @override
  String get name => '三桂懐刃';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.knight &&
        move.pieceType != PieceType.promKnight) {
      return false;
    }
    int count = 0;
    for (final entry in after.board.listNonEmptySquares()) {
      if (entry.piece.color != move.color) continue;
      if (entry.piece.type == PieceType.knight ||
          entry.piece.type == PieceType.promKnight) {
        count += 1;
      }
    }
    return count >= 3;
  }
}

/// 一間竜: 自分の竜が相手玉の 1 マス隣に効く形を作る手筋。
class _IkkenRyu extends TechniqueTemplate {
  const _IkkenRyu();
  @override
  String get name => '一間竜';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    // 竜を動かす (or 飛車成) → 移動先と相手玉が距離 2 で直線上 (cross)。
    final PieceType after_ =
        move.promote ? promotedPieceType(move.pieceType) : move.pieceType;
    if (after_ != PieceType.dragon) return false;
    final Square? king = after.board.findKing(reverseColor(move.color));
    if (king == null) return false;
    final int dx = (move.to.file - king.file).abs();
    final int dy = (move.to.rank - king.rank).abs();
    // 1 マス間隔 (距離 2、十字方向)
    return (dx == 0 && dy == 2) || (dx == 2 && dy == 0);
  }
}

/// こびん攻め: 玉の斜め前 (こびん) を攻める手筋。
class _KobinZeme extends TechniqueTemplate {
  const _KobinZeme();
  @override
  String get name => 'こびん攻め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Square? king = before.board.findKing(reverseColor(move.color));
    if (king == null) return false;
    final Color enemy = reverseColor(move.color);
    // 玉の斜め前 = 玉から見て (frontLeft / frontRight) 1 マス
    final int frontRank = enemy == Color.black ? king.rank - 1 : king.rank + 1;
    return move.to.rank == frontRank && (move.to.file - king.file).abs() == 1;
  }
}

/// 雪隠詰め: 相手玉を端 (1 筋 or 9 筋) の最下段隅に追い込んで詰ます手筋。
/// FIXME: 王手 + 隣の隅マス到達という簡易判定。
class _SecchinZume extends TechniqueTemplate {
  const _SecchinZume();
  @override
  String get name => '雪隠詰め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Color enemy = reverseColor(move.color);
    if (!after.board.isChecked(enemy)) return false;
    final Square? king = after.board.findKing(enemy);
    if (king == null) return false;
    // 玉が隅の 4 マス (1,1)/(9,1)/(1,9)/(9,9) のいずれか
    return (king.file == 1 || king.file == 9) &&
        (king.rank == 1 || king.rank == 9);
  }
}

/// 都詰め: 玉を中央 (5,5) で詰ますロマン詰め筋。
class _MiyakoZume extends TechniqueTemplate {
  const _MiyakoZume();
  @override
  String get name => '都詰め';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    final Color enemy = reverseColor(move.color);
    if (!after.board.isChecked(enemy)) return false;
    final Square? king = after.board.findKing(enemy);
    if (king == null) return false;
    return king.file == 5 && king.rank == 5;
  }
}

/// 銀ばさみ: 相手の銀を歩 (or 駒) で挟む手筋。
/// FIXME: 「動かした駒の利きに相手銀があり、銀の反対側にも自駒の利き」を簡易判定。
class _GinBasami extends TechniqueTemplate {
  const _GinBasami();
  @override
  String get name => '銀ばさみ';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.pieceType != PieceType.pawn) return false;
    // 動かした歩の前後左右に相手の銀がいる
    final Square? front = _front(move.to, move.color);
    if (front == null) return false;
    final Piece? p = before.board.at(front);
    if (p == null || p.color == move.color || p.type != PieceType.silver) {
      return false;
    }
    // さらに銀の向こう側 (front の前) に自駒の利きが必要だが簡易判定としては
    // 自陣の歩や桂が利いていればよい。
    final Square? front2 = _front(move.to, move.color, 2);
    if (front2 == null) return false;
    final Piece? p2 = before.board.at(front2);
    return p2 != null && p2.color == move.color;
  }
}

/// パンティを脱ぐ: 自陣最下段の右金を 1 段上げる手筋。
/// FIXME: 棋書出典の揺れあり。tentative。
class _PantyTechnique extends TechniqueTemplate {
  const _PantyTechnique();
  @override
  String get name => 'パンティを脱ぐ';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.gold) return false;
    final FromSquare fs = move.from as FromSquare;
    if (move.color == Color.black) {
      return (fs.square.file == 4 || fs.square.file == 5) &&
          fs.square.rank == 9 &&
          move.to.rank == 8;
    }
    return (fs.square.file == 5 || fs.square.file == 6) &&
        fs.square.rank == 1 &&
        move.to.rank == 2;
  }
}

/// 角不成 / 飛車不成 / 銀不成 系は既に上で定義済み。
/// たすきの銀 / たすきの角 : 銀 (or 角) で斜めにジグザグに動く手筋。
/// FIXME: 「斜め移動」 + 「promotion zone を含む」を簡易判定。
class _TasukiNoGin extends TechniqueTemplate {
  const _TasukiNoGin();
  @override
  String get name => 'たすきの銀';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.silver) return false;
    final FromSquare fs = move.from as FromSquare;
    // 斜め移動 (file と rank の両方が変化)
    final int dx = (move.to.file - fs.square.file).abs();
    final int dy = (move.to.rank - fs.square.rank).abs();
    if (dx != 1 || dy != 1) return false;
    return _isInOwnCamp(move.color, fs.square.rank) ||
        _isInOwnCamp(move.color, move.to.rank);
  }
}

class _TasukiNoKaku extends TechniqueTemplate {
  const _TasukiNoKaku();
  @override
  String get name => 'たすきの角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromSquare) return false;
    if (move.pieceType != PieceType.bishop) return false;
    final FromSquare fs = move.from as FromSquare;
    final int dx = (move.to.file - fs.square.file).abs();
    final int dy = (move.to.rank - fs.square.rank).abs();
    return dx == dy && dx >= 2;
  }
}

/// 駒柱: 同一筋に 9 枚の駒が並ぶロマン手筋。
class _KomaBashira extends TechniqueTemplate {
  const _KomaBashira();
  @override
  String get name => '駒柱';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    // 移動先の筋で 9 マスすべて埋まっている
    final int file = move.to.file;
    for (int r = 1; r <= 9; r += 1) {
      if (after.board.at(Square(file, r)) == null) return false;
    }
    return true;
  }
}

/// 歩切れ: 歩を打ち切って自分の歩持駒が 0 になる手筋。
class _FuGire extends TechniqueTemplate {
  const _FuGire();
  @override
  String get name => '歩切れ';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.pawn) return false;
    return after.hand(move.color).count(PieceType.pawn) == 0 &&
        before.hand(move.color).count(PieceType.pawn) >= 1;
  }
}

/// 角合い: 王手 (or 大駒の利き) に対し合駒として角を打つ手筋。
/// FIXME: 「自分が王手された状態で角打」を簡易判定。
class _KakuAi extends TechniqueTemplate {
  const _KakuAi();
  @override
  String get name => '幽霊角';
  @override
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after) {
    if (move.from is! FromHand) return false;
    if (move.pieceType != PieceType.bishop) return false;
    // before で自分が王手されている → 合駒で受け
    return before.board.isChecked(move.color);
  }
}

/// 跳ねの桂 (歩頭の桂と区別): 桂を初期段から 1 段跳ねる手筋。 — 既に `_FuTouNoKei` で歩頭は捕捉済。

// ---------------------------------------------------------------------------
// knownTechniques — 公開する手筋テンプレートの一覧
// ---------------------------------------------------------------------------

/// 既知の手筋テンプレート一覧。
const List<TechniqueTemplate> knownTechniques = <TechniqueTemplate>[
  // 歩を打つ・歩関連
  _TatakiNoFu(),
  _TareFu(),
  _SokoFu(),
  _KinSokoFu(),
  _KinSokoKyou(),
  _GedanNoKyou(),
  _SokoFuNiKyou(),
  _AwaseNoFu(),
  _KeitouNoFu(),
  _HikaeNoFu(),
  _TsukiSute(),
  _TsukiChigaiNoFu(),
  _RendaNoFu(),
  _TsugiFu(),
  _FuGire(),

  // 桂・銀の駒打ち / 攻め
  _KeitouNoKei(),
  _KeitouNoGin(),
  _KeitouNoGyoku(),
  _KeitouZeme(),
  _FuTouNoKei(),
  _KinTouNoKei(),
  _TakatobiNoKei(),
  _KyushoNoKei(),
  _WazaariNoKei(),
  _HaneChigaiNoKei(),
  _SanKeiFutokoroKatana(),
  _TsugiKei(),
  _TsurushiKei(),
  _HikaeNoKei(),

  // 玉に対する攻め
  _AtamaKin(),
  _AtamaGin(),
  _HaraKin(),
  _HaraGin(),
  _ShiriKin(),
  _ShiriGin(),
  _KataKin(),
  _KataGin(),
  _SusoKin(),
  _SusoGin(),
  _KobinZeme(),
  _GyokuTouZeme(),
  _GyokuTouSen(),
  _KakuTouZeme(),
  _SecchinZume(),
  _MiyakoZume(),

  // 王手・準王手
  _OuteHisha(),
  _OuteKaku(),
  _JunOuteHisha(),
  _JunOuteKaku(),

  // 駒打ち (銀・角・飛車)
  _WaridashiNoGin(),
  _FundoshiNoKei(),
  _RyoTori(),
  _KakuRyoTori(),
  _HishaRyoTori(),
  _TakujouNoGin(),
  _DengakuZashi(),

  // 自陣の打ち手筋
  _JijinHisha(),
  _JijinKaku(),
  _TomiNoKaku(),
  _NimaiHisha(),

  // 香・端
  _HashiZeme(),
  _HashiGyoku(),

  // 不成
  _GinNarazu(),
  _KakuNarazu(),
  _HishaNarazu(),

  // 駒交換・切り
  _KakuKoukan(),
  _HishaSakiKoukan(),
  _KakuGiri(),
  _HishaGiri(),
  _UmaGiri(),
  _RyuGiri(),

  // マッチアップ
  _KakuNihaKaku(),
  _KakuNihaHisha(),
  _HishaNihaKaku(),
  _HishaNihaHisha(),
  _UmaNihaKaku(),
  _UmaNihaHisha(),
  _RyuNihaKaku(),
  _RyuNihaHisha(),

  // 玉の動き
  _Nyuugyoku(),
  _UkiHisha(),
  _ChudanGyoku(),
  _GyokuTanki(),
  _GyokuHiSekkin(),
  _MamoriNoUma(),

  // と金 / 成駒
  _ToKinZeme(),
  _MamushiNoToKin(),

  // 一間竜
  _IkkenRyu(),

  // たすき
  _TasukiNoGin(),
  _TasukiNoKaku(),

  // その他
  _GinBasami(),
  _PantyTechnique(),
  _KakuAi(),
  _KomaBashira(),
];
