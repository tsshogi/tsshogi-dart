# Work Plan: ASCII Template → Dart Codegen

Date: 2026-05-11
Context: 囲い 135 + 戦法 250 を手書きの構造体で書いた結果、配置の視認性が低くタイポリスクが残る。ASCII 盤面を source-of-truth にしてビルド時にコード生成する方式へ移行する。

## アーキテクチャ

```
data/
  castles.txt        — 囲い ASCII テンプレ (人手編集)
  strategies.txt     — 戦法 ASCII テンプレ (人手編集)
tool/
  template_parser.dart        — ASCII → 中間表現
  generate_castles.dart       — data/castles.txt → lib/src/generated/castles.g.dart
  generate_strategies.dart    — data/strategies.txt → lib/src/generated/strategies.g.dart
  export_castles_to_ascii.dart  — 一回限り。現 knownCastles → data/castles.txt
  export_strategies_to_ascii.dart  — 一回限り。現 knownStrategies → data/strategies.txt
lib/src/
  castle.dart        — API only。const knownCastles を generated から取得
  strategy.dart      — 同上
  generated/
    castles.g.dart   — 自動生成、コミット対象
    strategies.g.dart — 同上
```

## ASCII テンプレファイル format

複数テンプレを単一ファイルに `===` 区切りで列挙。

```
# コメント行 (# or // 始まり) は無視。空行も無視。

=== name: 金矢倉
parent: 矢倉囲い
aliases: 本矢倉

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . P P P . . . .
P . S G . . . . .
. K G . . . . . .
. . . . . . . . .

=== name: 銀矢倉
parent: 矢倉囲い

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . P P P . . . .
P . S S . . . . .
. K G . . . . . .
. . . . . . . . .
```

### マストークン
- `.` 不問 (placement 無し)
- `K R B G S N L P` 駒種 (King/Rook/Bishop/Gold/Silver/kNight/Lance/Pawn)
- `+P +L +N +S +B +R` 成駒 (と金/成香/成桂/成銀/馬/竜)
- `[GS]`, `[G+R]` など 角括弧で AnyOfPieces

### 段位
- 行は段 (上から rank 1..9)
- 列は筋 (左から file 9..1、先手から見た向き)

### ヘッダ
- `=== name: <name>` 必須、テンプレ開始
- `parent: <name>` 任意
- `aliases: <a>, <b>` 任意、カンマ区切り
- `side: ibisha | furibisha | either` 戦法のみ任意 (デフォルト either)
- `description: <text>` 任意 (今回は使わない、人間用コメント)

## ワークフロー

1. (一回限り) `dart run tool/export_castles_to_ascii.dart` で現 knownCastles を ASCII 化、data/castles.txt を生成。同様に戦法も。
2. (毎回) data/*.txt を編集
3. (毎回) `dart run tool/generate_castles.dart` で lib/src/generated/*.g.dart を更新
4. lib/src/castle.dart / strategy.dart は generated を import するだけ
5. CI で「`dart run tool/generate_*.dart` を実行した結果が現 generated と一致するか」を将来チェック (今は手作業)

## Tasks

- [ ] Parser (`tool/template_parser.dart`) — ASCII セクション列 → 中間データクラス
- [ ] Forward codegen (`tool/generate_castles.dart`, `tool/generate_strategies.dart`)
- [ ] Reverse migration (`tool/export_*_to_ascii.dart`) — 一回限り
- [ ] data/castles.txt / data/strategies.txt 生成
- [ ] lib/src/generated/castles.g.dart / strategies.g.dart 生成
- [ ] lib/src/castle.dart を generated 使用にリファクタ (API 維持)
- [ ] lib/src/strategy.dart も同上
- [ ] テスト全部 pass (parametric self-match で sanity check)
- [ ] act 通過

## 注意

- AGPL 回避: ASCII format は独自設計 (フレーム文字なし、SFEN ベース、bioshogi の prefix DSL 不使用)
- 既存データは保持 (reverse migration で seed)。データの正確性レビューは後続作業
- `const` 性: 生成された `.g.dart` は全部 `const CastleTemplate(...)` で書く
- 手筋 (technique) は対象外 (move predicate ベースなので template 化しない)
