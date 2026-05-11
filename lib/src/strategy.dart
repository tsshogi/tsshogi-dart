import 'castle.dart';
import 'color.dart';
import 'generated/strategies.g.dart' as gen;
import 'move.dart';
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

  /// このテンプレートが ply 制約 (`plyEq` または `plyMax`) を持つかを返す。
  bool get hasPlyConstraint => plyEq != null || plyMax != null;

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
  for (final StrategyTemplate template in knownStrategies) {
    // ply 制約付きテンプレートは Record 経由でのみ判定可能。
    if (template.hasPlyConstraint) continue;
    if (side == null || side == Color.black) {
      if (_matchesStrategyTemplate(position, template, Color.black)) {
        results.add(DetectedStrategy(template: template, side: Color.black));
      }
    }
    if (side == null || side == Color.white) {
      if (_matchesStrategyTemplate(position, template, Color.white)) {
        results.add(DetectedStrategy(template: template, side: Color.white));
      }
    }
  }
  return results;
}

bool _matchesStrategyTemplate(
  ImmutablePosition position,
  StrategyTemplate template,
  Color side,
) {
  for (final CastleRequirement req in template.placements) {
    if (!req.isSatisfiedBy(position, side)) return false;
  }
  return true;
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
  /// ply 制約 (`plyEq` / `plyMax`) を持つテンプレートは、各 ply で制約を満
  /// たすときのみ評価される。
  List<DetectedStrategyAt> get strategies {
    final List<DetectedStrategyAt> results = <DetectedStrategyAt>[];
    final Set<String> seen = <String>{};
    void emitAt(int ply, ImmutablePosition pos) {
      // ply 制約なしテンプレートは detectStrategies(pos) で一括判定。
      for (final DetectedStrategy d in detectStrategies(pos)) {
        final String key = '${d.template.name}|${d.side.value}';
        if (seen.add(key)) {
          results.add(DetectedStrategyAt(
            template: d.template,
            side: d.side,
            ply: ply,
          ));
        }
      }
      // ply 制約付きテンプレートは個別に評価。
      for (final StrategyTemplate template in knownStrategies) {
        if (!template.hasPlyConstraint) continue;
        if (!template.satisfiesPlyConstraint(ply)) continue;
        for (final Color side in const <Color>[Color.black, Color.white]) {
          if (!_matchesStrategyTemplate(pos, template, side)) continue;
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
    emitAt(0, pos);
    ImmutableNode? node = first.next;
    while (node != null) {
      final Object raw = node.move;
      if (raw is Move) {
        pos.doMove(raw, ignoreValidation: true);
        emitAt(node.ply, pos);
      }
      node = node.next;
    }
    return results;
  }
}
