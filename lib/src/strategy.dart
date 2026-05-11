import 'castle.dart';
import 'color.dart';
import 'generated/strategies.g.dart' as gen;
import 'position.dart';

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
List<DetectedStrategy> detectStrategies(
  ImmutablePosition position, {
  Color? side,
}) {
  final List<DetectedStrategy> results = <DetectedStrategy>[];
  for (final StrategyTemplate template in knownStrategies) {
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
