# tsshogi (Dart)

Japanese 将棋 (shogi) library for Dart. Port of the TypeScript library
[sunfish-shogi/tsshogi](https://github.com/sunfish-shogi/tsshogi) — board,
position, moves, hands, SFEN/USI/USEN serialization, records (kifu trees) —
plus castle / strategy / technique detection ported as factual data from
[akicho8/bioshogi](https://github.com/akicho8/bioshogi).

- Pure Dart, no Flutter dependency. Dart SDK `^3.4.0`.
- MIT licensed (preserves upstream tsshogi copyright). Detection content
  is derived from public shogi terminology and coordinate data; the
  bioshogi DSL itself is not carried over.

## Install

Not published on `pub.dev`. Add it as a git dependency:

```yaml
# pubspec.yaml
dependencies:
  tsshogi:
    git:
      url: https://github.com/tsshogi/tsshogi-dart.git
      ref: v2.3.2
```

```bash
dart pub get
```

```dart
import 'package:tsshogi/tsshogi.dart';
```

Single barrel export — `lib/tsshogi.dart` is the only entry point.

## Quick start

```dart
import 'package:tsshogi/tsshogi.dart';

void main() {
  // Parse SFEN into a Position.
  final p = Position.newBySFEN(
    'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
  )!;
  print(p.sfen);

  // Apply a USI move.
  final move = p.createMoveByUSI('7g7f')!;
  p.doMove(move);
  print(p.board.at(Square(7, 6))); // Piece(Color.black, PieceType.pawn)

  // Parse a full game record (kifu).
  final r = Record.newByUSI(
    'position startpos moves 7g7f 3c3d 2g2f 8c8d 2f2e 8d8e',
  )!;

  // Walk detected formations and tactics.
  for (final c in r.castles) {
    print('${c.ply}手目: ${c.side.value} 囲い: ${c.template.name}');
  }
  for (final s in r.strategies) {
    print('${s.ply}手目: ${s.side.value} 戦法: ${s.template.name}');
  }
  for (final t in r.techniques) {
    print('${t.ply}手目: ${t.color.value} 手筋: ${t.template.name}');
  }
}
```

## What's in the box

| Area | Built-in templates / coverage |
|------|------|
| 囲い (castles) | 113 templates — 金矢倉, 美濃囲い, 居飛車穴熊, etc. |
| 戦法 (strategies) | 241 templates — 四間飛車, 角換わり, 横歩取り, etc. |
| 手筋 (techniques) | 94 implemented (137 catalogued; 43 are formation/idiomatic terms intentionally outside per-move detection) |
| Position / Board / Hand | full upstream TypeScript surface, including SFEN parse + format, USI/USEN, jishogi (持将棋) point counts |
| Record (kifu) | branch tree, USI/USEN round-trip, metadata, events |

Detection works both ways:

```dart
// Snapshot detection on a Position (no history needed):
final hits = detectCastles(p);
final strategies = detectStrategies(p);

// Record-based detection (uses move history; reports first occurrence
// per (template, side) only):
for (final c in r.castles) { ... }       // CastleTemplate first-match
for (final s in r.strategies) { ... }    // StrategyTemplate first-match
for (final t in r.techniques) { ... }    // technique per-move
```

## Tour of the source

- **Primitives** — `lib/src/color.dart`, `lib/src/piece.dart`,
  `lib/src/square.dart`, `lib/src/direction.dart`.
- **State** — `lib/src/board.dart`, `lib/src/hand.dart`,
  `lib/src/position.dart`.
- **Moves & records** — `lib/src/move.dart`, `lib/src/record.dart`,
  `lib/src/move_history.dart`.
- **Detection engines** — `lib/src/castle.dart` (the
  `CastleRequirement` sealed family that both castle *and* strategy
  detection reuse), `lib/src/strategy.dart`, `lib/src/technique.dart`.
- **Generated tables** — `lib/src/generated/castles.g.dart` and
  `lib/src/generated/strategies.g.dart` are produced from ASCII
  source-of-truth files; do not hand-edit. Regenerate with:

  ```bash
  dart run tool/generate_castles.dart
  dart run tool/generate_strategies.dart
  ```

  ASCII sources live in `data/castles.txt` / `data/strategies.txt`.

## Documentation

| File | Audience |
|------|----------|
| [`docs/llm-context.md`](docs/llm-context.md) | Single-file context dump for LLM coding assistants — full public API, gotchas, examples |
| [`llms.txt`](llms.txt) | LLM-friendly index linking the docs above |
| [`docs/plans/castle-detection.md`](docs/plans/castle-detection.md) | Castle detection design notes |
| [`docs/plans/strategy-technique-detection.md`](docs/plans/strategy-technique-detection.md) | Strategy + technique design notes |
| [`docs/technique-coverage.md`](docs/technique-coverage.md) | Per-technique implementation status |
| [`docs/plans/ascii-codegen.md`](docs/plans/ascii-codegen.md) | ASCII codegen pipeline (data/*.txt → *.g.dart) |

## Development

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings
dart test --reporter expanded --coverage=coverage
```

CI runs the same three commands. The `.claude/skills/refactor/SKILL.md`
skill documents the conventions used for safe refactoring (no edits to
`lib/src/generated/`, no renames of upstream-mirroring public API,
commitlint-shaped commits).

## License

[MIT](LICENSE). Retains the upstream tsshogi copyright. Castle / strategy
/ technique data is treated as factual public-domain shogi terminology;
the original bioshogi DSL and ASCII expressions are not redistributed.

## Acknowledgements

- [sunfish-shogi/tsshogi](https://github.com/sunfish-shogi/tsshogi) —
  upstream TypeScript implementation. Public API names mirror it.
- [akicho8/bioshogi](https://github.com/akicho8/bioshogi) — castle /
  strategy / technique catalogue (factual content only).
