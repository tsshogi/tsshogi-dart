# Work Plan: 戦法 (Strategy) + 手筋 (Technique) Detection

Date: 2026-05-11
Related: docs/plans/castle-detection.md
References (factual only, no code/template copy): bioshogi (AGPL-3.0) のうち戦法・手筋の**名前リスト**のみ参照

## Goal

囲い検出に続き、戦法 (中飛車・四間飛車・角換わり・矢倉戦法 etc.) と手筋 (たたきの歩・垂れ歩・ふんどしの桂 etc.) の判定 API を追加する。フロントエンドで「現在の戦型: 四間飛車」「直前の手は『たたきの歩』」のような表示に使う。

## ライセンス方針

- bioshogi の AGPL-3.0 コード/データはコピーしない (囲い検出と同様)
- 戦法名・手筋名は公知の用語として参照する
- 配置や手順パターンは Wikipedia・将棋連盟資料・一般的な棋書知識に基づき自前で起こす

## Scope

両方を 1 PR でフルカバー。joke 名 (UFO金 / パンティを脱ぐ / カニカニ銀 等) でも実在する戦法/手筋なので全部含める。文献の揺れが大きいものは `AnyOfPieces` + FIXME で許す。

### 戦法 (Phase A): 静的検出、~246 件 (joke 含む全パターン)
- 位置ベース判定 (Position の盤上の駒配置を見る)
- 囲い検出インフラを流用 (sealed `Requirement` を共有設計)
- 主要 + 派生 + joke 名を含むフルセット
- 不明瞭なものは loose pattern + FIXME

### 手筋 (Phase B): 動的検出、~137 件 (joke 含む全パターン)
- 棋譜 (`Record`) の手順走査が必要 — 新インフラ
- 例:
  - **たたきの歩**: 相手駒の前 1 マスに歩を打つ
  - **垂れ歩**: 敵陣の 1 段手前 (黒なら 4 段目) に歩を打つ
  - **継ぎ歩**: 連続して同じ筋に歩を打つ
  - **底歩**: 自陣最下段に歩を打つ
  - **十字飛車**: 飛車を縦横両方の駒に当てる
  - **割り打ちの銀**: 銀打で 2 つの駒に両取り
  - **ふんどしの桂**: 桂で両取り
  - **両取り**: 一手で複数の駒に当てる手 (汎用)
  - **桂頭の銀**: 桂の前 1 マスに銀
  - **タダ捨て / 成捨て**: 取られる場所への駒打ち

## API 設計

### 戦法 (`lib/src/strategy.dart`)

```dart
/// 戦法テンプレート (位置ベース、囲いと同じ要領)
class StrategyTemplate {
  const StrategyTemplate({
    required this.name,
    required this.placements,
    this.aliases = const <String>[],
    this.side = StrategySide.either,
  });
  final String name;
  final List<String> aliases;
  final List<CastleRequirement> placements;  // 囲いと共有する型を再利用
  /// 戦法は居飛車/振り飛車どちら専用か (両陣営で検出するか、片方のみか)
  final StrategySide side;
}

enum StrategySide { either, ibisha, furibisha }

class DetectedStrategy {
  final StrategyTemplate template;
  final Color side;
}

const List<StrategyTemplate> knownStrategies = [...];

List<DetectedStrategy> detectStrategies(ImmutablePosition position, {Color? side});
```

`CastleRequirement` (sealed: `PiecePlacement` / `AnyOfPieces`) を `castle.dart` から再利用。`AnyOfPieces` で「歩 or 銀 で先手急戦」のような揺れに対応。

### 手筋 (`lib/src/technique.dart`)

```dart
/// 手筋テンプレート (動的、Move + 局面の組み合わせ)
abstract class TechniqueTemplate {
  String get name;
  List<String> get aliases;
  /// この指し手が手筋にマッチするか判定する。
  /// [move]: 直前の指し手
  /// [before]: 指し手前の局面
  /// [after]: 指し手後の局面
  bool matches(Move move, ImmutablePosition before, ImmutablePosition after);
}

class DetectedTechnique {
  final TechniqueTemplate template;
  final int ply;  // 何手目で発動したか
}

/// 棋譜全体を走査して各ノードで手筋を検出する
List<DetectedTechnique> detectTechniques(ImmutableRecord record);

/// 単一の指し手だけ判定 (リアルタイム用)
List<TechniqueTemplate> detectTechniquesAtMove(
  Move move,
  ImmutablePosition before,
  ImmutablePosition after,
);
```

代表的な手筋を `class TatakinoFuTechnique extends TechniqueTemplate` のように個別クラスで実装 (それぞれ専用判定ロジックが必要)。

### barrel 追加

```dart
// lib/tsshogi.dart
export 'src/strategy.dart';
export 'src/technique.dart';
```

## Tasks

### Agent 1 — 戦法 (Phase A)
- [ ] `lib/src/strategy.dart`: StrategyTemplate/DetectedStrategy/detectStrategies + 50-80 戦法
- [ ] `test/strategy_test.dart`: 各戦法の代表局面でマッチ確認 + 整合性

### Agent 2 — 手筋 (Phase B)
- [ ] `lib/src/technique.dart`: TechniqueTemplate 抽象基盤 + 30-50 具象クラス
- [ ] `test/technique_test.dart`: 各手筋について before/after を構築してマッチ検証

### QA
- [ ] `dart format` / `dart analyze` / `dart test` 通過
- [ ] act ローカル実行
- [ ] commitlint 形式で commit

## Risks / Notes

- **戦法は曖昧**: 同じ盤面が複数戦法に該当する場合あり (e.g. 4五歩早仕掛け = 急戦の一種)。複数マッチ可で OK。
- **手筋判定の精度**: 「ふんどしの桂」は両取り判定が必要、エンジン側で `isValidMove` 等の既存 API を活用。
- **two-side 対応**: 戦法は片陣営の組み方なので、後手側の検出は 180° 回転 (囲いと同じ)。
- **Move の `from` が `FromHand`**: 駒打ち系手筋 (打ち歩・打ち銀・打ち桂) の主要対象。
- **`Record` 依存**: 手筋検出は棋譜走査のため `Record` API が必須 (既に Phase 2 で実装済み)。
