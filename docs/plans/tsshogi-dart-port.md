# Work Plan: tsshogi の Dart 移植

Date: 2026-05-11
Upstream: https://github.com/sunfish-shogi/tsshogi (v2.3.2)

## Goal

`tsshogi` (TypeScript の将棋ライブラリ, MIT) を Dart にポートする。フロントエンドでの利用を想定し、まずはユーザー操作 (どこに指せるか / 局面保持 / 棋譜保持 / 成判定) が動くスコープを優先する。

## Scope (Phased)

ユーザー要件:

| # | 機能 | フェーズ |
|---|------|---------|
| 1a | ある局面での合法手列挙 | **Phase 1** |
| 1b | 詰み判定 (合法手なし) | Phase 3 |
| 2 | 千日手判定 | Phase 3 |
| 3 | 連続王手の千日手判定 | Phase 3 |
| 4 | 指定駒の合法手 (どこに移動できるか) | **Phase 1** |
| 5 | 棋譜情報の簡易保存 (Record 相当) | **Phase 2** |
| 6 | 局面情報の保存 | **Phase 1** |
| 7 | 指し手の成・不成判定 | **Phase 1** |

Phase 1+2 をまず完成させる。Phase 3 は別 PR で追加。Phase 4 (KIF/KI2/CSA/JKF/text) はフロント不要なため当面ポートしない (上流仕様維持のため index は将来差し込めるよう設計)。

## Repository Layout

リポジトリは現状ほぼ空 (`src/`, `__tests__/` のみ)。Dart 慣習に合わせて以下を採用:

```
/
├─ pubspec.yaml            (package: tsshogi, version: 2.3.2 — tsshogi に合わせる)
├─ analysis_options.yaml   (lints/recommended + 厳格設定)
├─ lib/
│  ├─ tsshogi.dart         (barrel — TS の src/index.ts に対応)
│  └─ src/
│     ├─ color.dart
│     ├─ piece.dart
│     ├─ square.dart
│     ├─ direction.dart
│     ├─ errors.dart
│     ├─ move.dart
│     ├─ board.dart
│     ├─ hand.dart
│     ├─ position.dart
│     ├─ record.dart        (Phase 2)
│     └─ helpers/
│        └─ time.dart       (Phase 2)
└─ test/
   ├─ piece_test.dart
   ├─ square_test.dart
   ├─ position_test.dart
   ├─ record_test.dart      (Phase 2)
   └─ time_test.dart        (Phase 2)
```

`src/` と `__tests__/` の空ディレクトリは削除する。

## Mapping (TS → Dart)

| TS パターン | Dart マッピング |
|---|---|
| `enum Color { BLACK = "black" }` (文字列列挙) | `enum Color { black('black'); final String value; const Color(this.value); }` (SFEN 等 wire format で文字列を保持) |
| `interface ImmutableX` | `abstract interface class ImmutableX` (Dart 3) |
| `class Y implements ImmutableY` | 同上 |
| `Move | SpecialMove` 共用体 | `sealed class MoveLike` + `Move` / `SpecialMove` |
| `Square | PieceType` (`Move.from`) | `sealed class MoveOrigin { class FromSquare; class FromHand; }` |
| `Record | Error` 返却 | 例外 throw に統一 (parse 系は `tryImportXxx` で `Result` 風) |
| `class FooError extends Error` | `class FooError implements Exception` |
| Vitest | `package:test` |
| イベント `on("changePosition", h)` | `Stream<Event>` 公開 (Phase 2) |

## Tests

tsshogi の vitest を Dart `package:test` に移植。Phase 1+2 の対象:

- `piece.spec.ts` (117 LOC) → `test/piece_test.dart`
- `square.spec.ts` (98 LOC) → `test/square_test.dart`
- `position.spec.ts` (836 LOC) → `test/position_test.dart` のうち、Phase 3 機能 (sennichite / perpetualCheck) に依存するケースは `skip` で残す
- `record.spec.ts` (1542 LOC) → `test/record_test.dart` (Phase 2 — basic tree/append/goBack/goto/branch のみ)
- 上記以外 (csa / jkf / kakinoki / text / detect) は Phase 4 対象、今回はポートしない

合否基準: 上記ファイルの `skip` 以外が全て pass。

## Tasks

### Agent A — Core Types (Phase 1 part 1)
- [ ] `lib/src/color.dart` — Color enum + reverseColor / SFEN ヘルパ
- [ ] `lib/src/piece.dart` — Piece クラス + PieceType enum + 全ヘルパ
- [ ] `lib/src/square.dart` — Square クラス (factory / static cache 含む)
- [ ] `lib/src/direction.dart` — Direction / VDirection / HDirection / MoveType + 移動可能方向テーブル
- [ ] `lib/src/errors.dart` — 11 種類のエラー
- [ ] `lib/src/move.dart` — Move + SpecialMove (sealed) + parseUSIMove + equality ヘルパ
- [ ] `test/piece_test.dart`
- [ ] `test/square_test.dart`

### Agent B — Board / Hand / Position (Phase 1 part 2)
- [ ] `lib/src/board.dart` — 9×9 盤、SFEN, listSquaresByColor/Piece, isChecked
- [ ] `lib/src/hand.dart` — 駒台、SFEN
- [ ] `lib/src/position.dart` — Position 本体、doMove/undoMove/isValidMove/createMove/createMoveByUSI/listAttackers/isPawnDropMate, SFEN, jishogi スコア計算
- [ ] `test/position_test.dart` (Phase 3 依存ケースは skip)

### Agent C — Record + Barrel (Phase 2)
- [ ] `lib/src/helpers/time.dart` — ms ↔ HH:MM:SS / M:SS
- [ ] `lib/src/record.dart` — Node tree + 分岐 + メタデータ + USI/USEN シリアライズ + 簡易イベント
- [ ] `lib/tsshogi.dart` — barrel
- [ ] `test/record_test.dart` (基本機能のみ — sennichite / perpetualCheck テストは skip)
- [ ] `test/time_test.dart`

### Agent QA — 検証
- [ ] `pubspec.yaml` / `analysis_options.yaml`
- [ ] 空の `src/`, `__tests__/` 削除
- [ ] `dart pub get`
- [ ] `dart analyze` — 警告ゼロ
- [ ] `dart test` — Phase 1+2 全 pass
- [ ] commitlint 形式でフェーズ毎にコミット

## Execution Order

1. **Sequential**: pubspec + analysis_options + barrel 雛形 を先に置く (QA 準備)
2. **Parallel**: Agent A と Agent B (B は A の型に依存するので A の API contract を先に固定するか、A 完了を待つ)
3. **Sequential**: Agent C は A+B の完了後
4. **Sequential**: Agent QA で全体検証 → コミット

A と B は API 依存があるため A 先行 → B 並行は不可。A 完了 → B/C 並行可能だが、C は Position に依存するので結局 A → B → C のシーケンシャル進行が安全。

## Deliverables

- `pubspec.yaml` — name=tsshogi version=2.3.2
- `lib/tsshogi.dart` + `lib/src/*.dart` — 10 ファイル
- `test/*_test.dart` — 5 ファイル
- `docs/plans/tsshogi-dart-port.md` (本ドキュメント)
- 各 Phase 毎の commit

## Risks / Notes

- **Square.all 静的キャッシュ**: TS は module load 時生成。Dart は top-level `final` で同等。
- **String 比較**: Dart String は UTF-16 単位、TS と同じ。kanji は `.length == 1` で扱える。
- **イベント emitter**: tsshogi の `on/off` を Stream に置き換え。後方互換性は不要 (Dart 側初出)。
- **USEN encoding**: `record.ts` の `usenHandTable` を忠実に移植。テストでラウンドトリップ確認必須。
- **Phase 3 機能**: テストファイルにケースは残し `skip` マーキング。実装は後続 PR。
- **Phase 4 (KIF/KI2/CSA/JKF/text/detect)**: 今回ポートしないが、`lib/tsshogi.dart` の barrel コメントで TODO 明記。
- **Agent Teams 制約**: 既存 `.claude/agents/{frontend,backend,qa}.md` は Cloudflare Workers + React 向けで Dart 非対応。今回は `general-purpose` agent を A/B/C に割り当てる。QA は手動 (dart コマンド) で実行。
