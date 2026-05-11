# Work Plan: 囲い (Castle) Detection

Date: 2026-05-11
Related: docs/plans/tsshogi-dart-port.md
References (factual only, no code/template copy): bioshogi (AGPL-3.0) のうち囲いの**名前リスト**のみ参照

## Goal

ある局面 (`Position`) を見て、いまどんな囲い (矢倉/美濃/穴熊 ...) になっているかを判定する静的分類 API を `package:tsshogi` に追加する。フロントエンドで「現在の囲い: 金矢倉」のような表示に使う。

## ライセンス方針

- bioshogi の AGPL-3.0 ライセンスのコード/データは **コピーしない**
- 囲いの**名前** (「金矢倉」「美濃囲い」等の歴史的呼称) と**事実としての標準的駒配置**は著作物保護の対象外として参照する
- データソースは Wikipedia「将棋の囲い」、日本将棋連盟資料、一般的な将棋書籍の常識的な配置に基づき自分でテーブルを起こす
- bioshogi の ASCII テンプレート DSL (`!@*?~^○●★☆◆■□◇` 等のプレフィックス) は持ち込まず、Dart 構造体で別表現する

## Scope

- **Phase A (この PR)**: エンジン + データモデル + 主要 ~30 囲い + 静的検出 API + テスト
- **Phase B (後続 PR)**: 残りの ~70+ 囲いを追加して総数 100+ にする
- **Phase C (後続 PR)**: 手筋 (`technique`) 検出 — Record (棋譜) の走査が必要なため別設計
- 戦法 (`attack`/戦型) と注釈 (`note`) は当面対象外

## API 設計

```dart
// lib/src/castle.dart

/// 囲いテンプレート定義 (常に先手視点)
@immutable
class CastleTemplate {
  const CastleTemplate({
    required this.name,
    required this.placements,
    this.aliases = const [],
    this.parent,
  });

  /// 囲い名 (例: '金矢倉')
  final String name;

  /// 別名 (例: ['本矢倉'])
  final List<String> aliases;

  /// 親囲い (より広い分類、例: '矢倉囲い')
  final String? parent;

  /// 必須駒配置 (先手視点)
  final List<PiecePlacement> placements;
}

@immutable
class PiecePlacement {
  const PiecePlacement(this.file, this.rank, this.pieceType);
  /// 1..9 (盤の右が 1)
  final int file;
  /// 1..9 (盤の上が 1, 黒が下=9 段スタート)
  final int rank;
  final PieceType pieceType;
}

/// 検出結果
@immutable
class DetectedCastle {
  const DetectedCastle({
    required this.template,
    required this.side,
  });
  final CastleTemplate template;
  /// この囲いを構築している陣営
  final Color side;
}

/// 既知の囲いテンプレート (Phase A は ~30, Phase B で 100+)
const List<CastleTemplate> knownCastles = [...];

/// 局面から囲いを検出
List<DetectedCastle> detectCastles(
  ImmutablePosition position, {
  /// 検出対象の陣営 (null なら両方)
  Color? side,
});
```

## マッチング規則

1. 各 `CastleTemplate` は先手 (black) 視点で記述
2. 先手の検出: テンプレートの placements を盤上に直接照合
3. 後手の検出: 180° 回転 (file → 10-file, rank → 10-rank) して照合
4. 全 placements が満たされたら match (exact match のみ、wildcard なし v1)
5. 複数囲いが match することはあり得る (例: 金矢倉と矢倉囲いが同時)。全件返す

## データソース取得方針 (Phase A 主要 30)

これらは将棋の基本囲いとして公知の配置:

| ファミリ | 含める囲い |
|---|---|
| 矢倉 | 金矢倉、銀矢倉、片矢倉、総矢倉、菱矢倉、矢倉穴熊、角矢倉 |
| 美濃 | 本美濃、片美濃、高美濃、銀冠、ダイヤモンド美濃、木村美濃 |
| 穴熊 | 居飛車穴熊、振り飛車穴熊、ビッグ4、松尾流穴熊 |
| 舟囲い系 | 舟囲い、中原囲い、左美濃 |
| 雁木系 | 雁木囲い、矢倉雁木 |
| その他 | 中住まい、ミレニアム、elmo囲い |

優先 30、調整可。

## Files to create

- `lib/src/castle.dart` — エンジン + データモデル + Phase A 30 件
- `test/castle_test.dart` — 各囲いに対する標準局面 (SFEN) → match 期待値
- `lib/tsshogi.dart` の barrel に export 追加

## Tasks

### Single agent (high context, can do in one pass)
- [ ] `lib/src/castle.dart`: データモデル (`PiecePlacement`, `CastleTemplate`, `DetectedCastle`) と `detectCastles` 関数
- [ ] 主要 30 囲いのデータを公開棋書/Wikipedia 知識ベースで起こす
- [ ] `test/castle_test.dart`: 各囲い完成形 SFEN を作って match を検証 + 一部の near-miss 否定テスト
- [ ] `lib/tsshogi.dart` で `castle.dart` を export
- [ ] `dart format` / `dart analyze` / `dart test` 通過確認

## Risks / Notes

- **配置の正確性**: 同じ囲い名でも書籍によって微妙に違う (e.g. 高美濃の歩位置)。本 PR では Wikipedia の標準形を採用。Phase B でバリエーション追加検討。
- **重複 match**: 「金矢倉」と「矢倉囲い」が同時に match するのが正解。`parent` フィールドで関係明示。
- **wildcard なし v1**: bioshogi の `◆ (>=銀)` のような相対指定は今回入れない。Phase B で必要なら拡張。
- **盤面が囲い「以外」の駒で覆われていてもよい**: テンプレに無い駒が他のマスにあっても match 成立 (盤の囲い領域だけ判定)。
- **`@immutable` アノテーション**: `package:meta` が必要 (test 依存にぶら下がってる可能性あり)。なければ自作アノテーション or 省略。
