import 'castle.dart';
import 'color.dart';
import 'generated/strategies.g.dart' as gen;
import 'move.dart';
import 'move_history.dart';
import 'piece.dart';
import 'position.dart';
import 'record.dart';

// ---------------------------------------------------------------------------
// 戦法検出 (Strategy / Opening detection)
// ---------------------------------------------------------------------------
//
// 囲い (castle) と異なり、戦法は「飛車の位置 + 玉の側 + 駒組の一部」で大ま
// かに識別される。本ファイルは castle.dart の [CastleRequirement] エンジン
// (PiecePlacement + AnyOfPieces) をそのまま再利用し、テンプレートと検出関数
// だけを戦法向けに新設する。
//
// 配置は常に先手 (black) 視点で記述する。後手側の検出時には 180° 回転
// (file → 10-file, rank → 10-rank) して照合する。castle.dart と完全同じ規約。
//
// 戦法名はすべて公知の将棋用語であり、特定の棋書/ソフトウェアからの転載で
// はない。bioshogi (AGPL-3.0) のレイアウトデータは一切参照していない。
//
// テンプレ本体は ASCII source-of-truth (data/strategies.txt) から自動生成
// され、lib/src/generated/strategies.g.dart に const リストとして書き出され
// る。データを編集したい場合は data/strategies.txt を直接書き換え、以下を
// 実行する:
//
//   dart run tool/generate_strategies.dart

/// 戦法が居飛車専用 / 振り飛車専用 / 両方を区別するフラグ。
enum StrategySide {
  /// 居飛車・振り飛車どちらでも (例: 矢倉、横歩取り)
  either,

  /// 居飛車専用 (例: 棒銀、角換わり)
  ibisha,

  /// 振り飛車専用 (例: 四間飛車、中飛車、石田流)
  furibisha,
}

/// 戦法テンプレート (位置ベース、囲い検出と同じ pattern matching を使用)。
class StrategyTemplate {
  const StrategyTemplate({
    required this.name,
    required this.placements,
    this.aliases = const <String>[],
    this.side = StrategySide.either,
    this.parent,
    this.plyEq,
    this.plyMax,
    this.evaluateAtGameEnd = false,
    this.outbreakSkip = false,
    this.killCountLteq,
    this.killOnly = false,
    this.orderKey,
    this.handEq,
    this.opHandEq,
    this.handNotIn = const <PieceType>[],
    this.noPawnInHand = false,
    this.onlyPawnsInHand = false,
  });

  /// 戦法名 (例: '四間飛車')
  final String name;

  /// 別名 (例: ['四間'])
  final List<String> aliases;

  /// 必須駒配置 (先手視点)。`PiecePlacement` (exact) と `AnyOfPieces` (or) を
  /// 混在させられる。
  final List<CastleRequirement> placements;

  /// 居飛車 / 振り飛車 / 両方
  final StrategySide side;

  /// 親戦法 (例: 「ゴキゲン中飛車」の親は「中飛車」)
  final String? parent;

  /// この戦法が成立する手数 (ply) の制約 (厳密一致)。
  ///
  /// 例: 「初手▲3六歩戦法」は `plyEq: 1` で、初手の局面のみマッチさせる。
  /// 非 null の場合、棋譜走査ベース検出 (`record.strategies`) では現在 ply が
  /// この値と一致するときのみマッチする。`plyMax` と併用可。
  /// 位置ベース検出 (`detectStrategies(position)`) では ply 情報が無いため、
  /// 非 null のテンプレートはスキップされる。
  final int? plyEq;

  /// この戦法が成立する手数 (ply) の上限。
  ///
  /// 例: 「相掛かり」は `plyMax: 6` で、序盤に限定。非 null の場合、棋譜走査
  /// ベース検出では現在 ply が <= plyMax のときのみマッチする。`plyEq` と
  /// 併用可。位置ベース検出では非 null のテンプレートはスキップされる。
  final int? plyMax;

  /// bioshogi `outbreak_skip`: 開戦 (歩・角以外が取られた) 後は判定しない。
  final bool outbreakSkip;

  /// bioshogi `kill_count_lteq`: これまでの総取り駒数がこの値以下のときのみ
  /// 成立 (例: 0 = 駒交換が一度も起きていない序盤のみ)。
  final int? killCountLteq;

  /// bioshogi `kill_only`: 直前の手で駒を取っているときのみ成立。
  final bool killOnly;

  /// bioshogi `order_key`: 手番限定 ('first' = 先手のみ / 'second' = 後手のみ)。
  /// 平手前提で 'first'→black / 'second'→white に対応付ける。
  final String? orderKey;

  /// bioshogi `hold_piece_eq`: 自分の持駒が完全一致のとき成立。
  final Map<PieceType, int>? handEq;

  /// bioshogi `op_hold_piece_eq`: 相手の持駒が完全一致のとき成立。
  final Map<PieceType, int>? opHandEq;

  /// bioshogi `hold_piece_not_in`: 自分の持駒にこれらを含まないとき成立。
  final List<PieceType> handNotIn;

  /// bioshogi `has_pawn_then_skip`: 自分の持駒に歩があれば不成立。
  final bool noPawnInHand;

  /// bioshogi `has_other_pawn_then_skip`: 自分の持駒に歩以外があれば不成立。
  final bool onlyPawnsInHand;

  /// このテンプレートが棋譜走査ゲート (outbreak/kill/order) を持つかを返す。
  bool get hasRecordGate =>
      outbreakSkip || killCountLteq != null || killOnly || orderKey != null;

  /// 棋譜走査ゲート (game-context 制約) を満たすか。局面単体検出では履歴が
  /// 無いため評価できず、本判定は `record.strategies` からのみ呼ばれる。
  bool passesRecordGate(Color side, MoveHistory history) {
    if (outbreakSkip && history.outbreakTurn != null) return false;
    if (killCountLteq != null && history.captureCount > killCountLteq!) {
      return false;
    }
    if (killOnly && !history.lastMoveCaptured) return false;
    if (orderKey != null) {
      final Color want = orderKey == 'first' ? Color.black : Color.white;
      if (side != want) return false;
    }
    return true;
  }

  /// このテンプレートが ply 制約 (`plyEq` または `plyMax`) を持つかを返す。
  bool get hasPlyConstraint => plyEq != null || plyMax != null;

  /// このテンプレートが履歴依存要件 (`PieceUnmoved` / `PieceVisited` /
  /// `KingIgyoku`) を含むかを返す。`true` の場合、位置ベース検出
  /// (`detectStrategies(position)`) では常にスキップされる。
  bool get hasHistoryRequirement {
    for (final CastleRequirement req in placements) {
      if (req is PieceUnmoved ||
          req is PieceVisited ||
          req is PieceDropped ||
          req is KingIgyoku) {
        return true;
      }
    }
    return false;
  }

  /// このテンプレートを「棋譜の最終手まで評価を遅延し、最終状態で 1 度だけ
  /// 判定する」べきかを示すフラグ。詳細は [CastleTemplate.evaluateAtGameEnd]
  /// を参照。
  final bool evaluateAtGameEnd;

  /// 与えられた手数 [ply] でこのテンプレートが ply 制約を満たすか。
  bool satisfiesPlyConstraint(int ply) {
    if (plyEq != null && plyEq != ply) return false;
    if (plyMax != null && ply > plyMax!) return false;
    return true;
  }
}

/// 検出結果。
class DetectedStrategy {
  const DetectedStrategy({required this.template, required this.side});

  /// マッチしたテンプレート
  final StrategyTemplate template;

  /// この戦法を指している陣営
  final Color side;

  @override
  bool operator ==(Object other) {
    return other is DetectedStrategy &&
        other.template.name == template.name &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(template.name, side);
}

/// 既知の戦法テンプレート (250 件)。
///
/// 親カテゴリ (中飛車・四間飛車・矢倉等) と子テンプレ (ゴキゲン中飛車等) を
/// 混在させて格納している。1 局面で複数の戦法が同時に検出されることがある。
const List<StrategyTemplate> knownStrategies = gen.strategies;

/// 局面 [position] から戦法を検出する。
///
/// [side] が指定された場合はその陣営のみ、null の場合は両陣営を判定する。
/// 各テンプレートは先手視点で記述されており、後手判定では 180° 回転して
/// 照合する。テンプレートの全 placements を満たす駒が盤上にあれば検出。
/// テンプレートに含まれていない駒が他のマスにあっても判定には影響しない。
/// 複数の戦法 (例: 中飛車とゴキゲン中飛車) が同時にマッチすることがある。
///
/// 注: ply 制約 (`plyEq` / `plyMax`) を持つテンプレートは position のみでは
/// 検証できないため、本関数では **常にスキップ** される。
/// ply 制約を考慮した検出が必要な場合は `record.strategies` を使う。
List<DetectedStrategy> detectStrategies(
  ImmutablePosition position, {
  Color? side,
}) {
  final List<DetectedStrategy> results = <DetectedStrategy>[];
  // position-only 評価向け MoveHistory:
  //   - 標準初期局面の駒位置 (飛 2八 / 香 1九 等) を visited に登録
  //   - 現局面の駒位置も visited に登録 (現状の配置)
  // これで「飛車が 2八 (初期) と 6八 (現在) を visited」のような
  // bioshogi の `★` 由来要件が、棋譜走査無しでも標準ゲーム前提で満たされる。
  final MoveHistory history = MoveHistory()
    ..initFromPosition(Position())
    ..initFromPosition(position);
  for (final StrategyTemplate template in knownStrategies) {
    // ply 制約付きテンプレートは Record 経由でのみ判定可能。
    if (template.hasPlyConstraint) continue;
    // game-end 評価テンプレ (居玉 等) は record.strategies からのみ。
    if (template.evaluateAtGameEnd) continue;
    if (side == null || side == Color.black) {
      if (_matchesStrategyTemplate(position, template, Color.black,
          history: history)) {
        results.add(DetectedStrategy(template: template, side: Color.black));
      }
    }
    if (side == null || side == Color.white) {
      if (_matchesStrategyTemplate(position, template, Color.white,
          history: history)) {
        results.add(DetectedStrategy(template: template, side: Color.white));
      }
    }
  }
  return results;
}

bool _matchesStrategyTemplate(
  ImmutablePosition position,
  StrategyTemplate template,
  Color side, {
  MoveHistory? history,
}) {
  for (final CastleRequirement req in template.placements) {
    if (!req.isSatisfiedBy(position, side, history)) return false;
  }
  return passesHandConstraints(
    position,
    side,
    handEq: template.handEq,
    opHandEq: template.opHandEq,
    handNotIn: template.handNotIn,
    noPawnInHand: template.noPawnInHand,
    onlyPawnsInHand: template.onlyPawnsInHand,
  );
}

/// 局面からの戦法検出ユーティリティ。プロパティ形式で
/// `position.strategies` のように呼べる。手番は無視し両陣営の検出結果を返す。
///
/// 注: これは **スナップショット** 検出のため、戦法が成立した後の手でも
/// 同じ結果が出続ける。「初めて成立した手」を知りたい場合は
/// [ImmutableRecordStrategies.strategies] を使う。
///
/// ```dart
/// final p = Position.newBySFEN(sfen)!;
/// for (final s in p.strategies) {
///   print('${s.side.value}: ${s.template.name}');
/// }
/// ```
extension ImmutablePositionStrategies on ImmutablePosition {
  /// この局面で検出される戦法を返す (両陣営)。
  List<DetectedStrategy> get strategies => detectStrategies(this);
}

/// 棋譜の中で戦法が「初めて成立した手」を表す。
class DetectedStrategyAt {
  const DetectedStrategyAt({
    required this.template,
    required this.side,
    required this.ply,
  });

  /// マッチしたテンプレート
  final StrategyTemplate template;

  /// 戦法を採用している陣営
  final Color side;

  /// 初めてマッチした手数 (0 は初期局面)。
  final int ply;

  @override
  bool operator ==(Object other) =>
      other is DetectedStrategyAt &&
      other.template.name == template.name &&
      other.side == side &&
      other.ply == ply;

  @override
  int get hashCode => Object.hash(template.name, side, ply);
}

/// 棋譜走査ベースの戦法検出。各戦法を「初めて成立した手」だけ報告する。
///
/// スナップショット形 ([ImmutablePositionStrategies.strategies]) と違い、
/// 一度検出された戦法は以降の手では再報告されない。例えば四間飛車が成立し
/// た後に関係ない手を指し続けても、ずっと検出され続けることはない。
///
/// ```dart
/// final r = Record.newByUSI('position startpos moves 7g7f ...')!;
/// for (final s in r.strategies) {
///   print('${s.ply}手目: ${s.side.value} ${s.template.name}');
/// }
/// ```
extension ImmutableRecordStrategies on ImmutableRecord {
  /// アクティブブランチを走査し、初めて成立した戦法を ply 順に返す。
  ///
  /// - ply 0 (初期局面) は走査対象外。最初の指し手以降のみ評価する。
  /// - ply 制約 (`plyEq` / `plyMax`) を持つテンプレートは、各 ply で制約
  ///   を満たすときのみ評価される。
  /// - 同じテンプレ名 + 陣営の組は最初の 1 回のみ報告 (snapshot 重複防止)。
  List<DetectedStrategyAt> get strategies {
    final List<DetectedStrategyAt> results = <DetectedStrategyAt>[];
    final Set<String> seen = <String>{};
    final MoveHistory history = MoveHistory()
      ..initFromPosition(initialPosition);
    void emitAt(int ply, ImmutablePosition pos) {
      // 1. ply 制約も履歴依存要件も無いテンプレートは detectStrategies(pos)
      //    で一括判定 (高速路)。
      for (final DetectedStrategy d in detectStrategies(pos)) {
        // game-context ゲート (開戦/取り駒数/手番) を棋譜履歴で検証。
        if (!d.template.passesRecordGate(d.side, history)) continue;
        final String key = '${d.template.name}|${d.side.value}';
        if (seen.add(key)) {
          results.add(DetectedStrategyAt(
            template: d.template,
            side: d.side,
            ply: ply,
          ));
        }
      }
      // 2. ply 制約付き / 履歴依存テンプレートは個別に評価。
      //    ただし evaluateAtGameEnd のものは per-ply で評価しない。
      for (final StrategyTemplate template in knownStrategies) {
        if (template.evaluateAtGameEnd) continue;
        if (!template.hasPlyConstraint && !template.hasHistoryRequirement) {
          continue;
        }
        if (template.hasPlyConstraint &&
            !template.satisfiesPlyConstraint(ply)) {
          continue;
        }
        for (final Color side in const <Color>[Color.black, Color.white]) {
          if (!_matchesStrategyTemplate(pos, template, side,
              history: history)) {
            continue;
          }
          if (!template.passesRecordGate(side, history)) continue;
          final String key = '${template.name}|${side.value}';
          if (seen.add(key)) {
            results.add(DetectedStrategyAt(
              template: template,
              side: side,
              ply: ply,
            ));
          }
        }
      }
    }

    final Position pos = initialPosition.clone();
    // ply 0 はスキップ。最初の指し手以降のみ評価する。
    ImmutableNode? node = first.next;
    int lastPly = 0;
    while (node != null) {
      final Object raw = node.move;
      if (raw is Move) {
        history.recordMove(raw, node.ply);
        pos.doMove(raw, ignoreValidation: true);
        emitAt(node.ply, pos);
        lastPly = node.ply;
      }
      node = node.next;
    }

    // game-end フェーズ: 最終 MoveHistory に基づいて 1 度だけ評価する。
    // 居玉 を持つ戦法テンプレートが該当する場合の挙動を castle.dart 側と
    // 揃える。`lastPly == 0` のとき (= 指し手 0) は走査対象外なので skip。
    if (lastPly > 0) {
      for (final StrategyTemplate template in knownStrategies) {
        if (!template.evaluateAtGameEnd) continue;
        for (final Color side in const <Color>[Color.black, Color.white]) {
          if (!_matchesStrategyTemplate(pos, template, side,
              history: history)) {
            continue;
          }
          final String key = '${template.name}|${side.value}';
          if (!seen.add(key)) continue;
          // 居玉系: 戦い開始 (outbreak_turn) を emit ply に使う。
          // 戦いが起きなかった棋譜なら最終 ply。
          final int emitPly = history.outbreakTurn ?? lastPly;
          results.add(DetectedStrategyAt(
            template: template,
            side: side,
            ply: emitPly,
          ));
        }
      }
    }
    return results;
  }
}
