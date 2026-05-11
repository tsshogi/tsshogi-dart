# tsshogi (Dart) — LLM Context

Single-file reference for LLM coding assistants integrating this package.
Paste into context when working with `package:tsshogi`.

---

## What this is

Dart port of [sunfish-shogi/tsshogi](https://github.com/sunfish-shogi/tsshogi)
(TypeScript, MIT) — a 将棋 (Japanese shogi) library handling:

- Position / Board / Hand / Move / SFEN / USI / USEN serialization
- Record (game tree with branches, metadata, events)

Plus castle / strategy / technique detection ported as factual data from
[akicho8/bioshogi](https://github.com/akicho8/bioshogi) (Ruby, AGPL-3.0):

- 113 castles (囲い): 金矢倉, 美濃囲い, 居飛車穴熊, etc.
- 241 strategies (戦法): 四間飛車, 角換わり, 横歩取り, etc.
- 94 techniques (手筋): たたきの歩, ふんどしの桂, 角交換, etc.

License: MIT. Names + coordinate data treated as public-domain facts;
ASCII expression and prefix DSL are NOT carried over from bioshogi.

## Installing

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

Single barrel export. All public symbols come from here.

## Quick start

```dart
// 1. Parse SFEN → Position
final p = Position.newBySFEN(
  'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
)!;

// 2. Parse USI string → Record (full game)
final r = Record.newByUSI(
  'position startpos moves 7g7f 3c3d 2g2f 8c8d 2f2e 8d8e ...',
)!;

// 3. Detect castles / strategies / techniques
for (final c in r.castles) {
  print('${c.ply}手目: ${c.side.value} ${c.template.name}');
}
for (final s in r.strategies) {
  print('${s.ply}手目: ${s.side.value} ${s.template.name}');
}
for (final t in r.techniques) {
  print('${t.ply}手目: ${t.color.value} ${t.template.name}');
}

// 4. Apply move + introspect
p.doMove(parseUSIMove('7g7f')!);
print(p.sfen);
print(p.board.at(Square(7, 6)));  // Piece(Color.black, PieceType.pawn)
```

## Core types

### Color, PieceType (enums)

`Color` = `black` / `white` (先手/後手). `reverseColor(c)` flips.

`PieceType` = 14 entries: `pawn lance knight silver gold bishop rook king
promPawn promLance promKnight promSilver horse dragon`. Helpers:
`pieceTypes`, `handPieceTypes`, `isPromotable(t)`, `promotedPieceType(t)`,
`unpromotedPieceType(t)`, `pieceTypeToSFEN(t)`.

### Square

`Square(int file, int rank)` — `file` is 1..9 (1 = rightmost from black's
view = 1筋), `rank` is 1..9 (1 = top = white's 1段). `Square.all` is a
const list of 81 squares. `Square.newByUSI('7g')` parses USI.

### Piece

`Piece(Color color, PieceType type)`. Methods: `black()` / `white()` /
`withColor(c)`, `promoted()` / `unpromoted()`, `isPromotable()`,
`rotate()`. Getters: `id` ("black_gold"), `sfen` (`'G'` / `'+b'`).
Static `Piece.newBySFEN('+P')`. `==` / `hashCode` by `(color, type)`.

### Move / SpecialMove

```dart
sealed class MoveOrigin {}
class FromSquare extends MoveOrigin { final Square square; }
class FromHand extends MoveOrigin { final PieceType pieceType; }

class Move {
  Move(MoveOrigin from, Square to, bool promote, Color color,
       PieceType pieceType, PieceType? capturedPieceType);
  Move withPromote();          // returns copy with promote=true
  String get usi;              // "7g7f" / "7g7f+" / "G*5e"
}

({MoveOrigin from, Square to, bool promote})? parseUSIMove(String usi);

sealed class SpecialMove {}
class PredefinedSpecialMove extends SpecialMove {
  final SpecialMoveType type;  // resign / draw / mate / try_ / ...
}
class AnySpecialMove extends SpecialMove { final String name; }

PredefinedSpecialMove specialMove(SpecialMoveType t);
AnySpecialMove anySpecialMove(String name);
bool isKnownSpecialMove(Object move);
bool areSameMoves(Object a, Object b);  // Move | SpecialMove
```

### Board (ImmutableBoard / Board)

`Piece? at(Square s)`, `Iterable<({Square square, Piece piece})>
listNonEmptySquares()`, `Square? findKing(Color)`, `bool hasPower(Square
target, Color attacker, {Square? filled, Square? ignore})`, `bool
isChecked(Color kingColor)`, `String get sfen`.

Mutators on `Board`: `set(Square, Piece?)`, `remove(Square)`,
`swap(Square, Square)`, `clear()`, `resetBySFEN(String)`,
`copyFrom(ImmutableBoard)`.

### Hand (ImmutableHand / Hand)

`int count(PieceType)`, `void forEach((PieceType, int) handler)`,
`List<({PieceType type, int count})> get counts` (rook→pawn order),
`String get sfenBlack` / `sfenWhite`, `String formatSFEN(Color)`.

Mutators: `set/add/reduce(PieceType, int)`. Statics:
`Hand.formatSFENOf(black, white)` (renamed from TS `Hand.formatSFEN`
because Dart can't have same-name static + instance),
`Hand.parseSFEN(String)`.

### Position (ImmutablePosition / Position)

```dart
Position position = Position();              // 平手 standard start
position.reset(InitialPositionType.empty);   // clear
final p2 = Position.newBySFEN(sfen)!;

position.board                  // ImmutableBoard
position.color                  // 手番 (Color)
position.hand(Color side)       // ImmutableHand
position.checked                // bool
position.sfen / position.getSFEN(int nextPly)
position.clone()
position.doMove(Move, {bool ignoreValidation = false})  // returns bool
position.undoMove(Move)
position.isValidMove(Move)
position.createMove(MoveOrigin, Square)   // builds a Move with capture detection
position.createMoveByUSI(String)
position.isPawnDropMate(Move)
position.listAttackers(Square)
```

Jishogi (持将棋) helpers: `countExistingPieces(p)`,
`countNotExistingPieces(p)`, `countJishogiPoint(p, side)`,
`judgeJishogiDeclaration(JishogiDeclarationRule.general27, p, side)`.

### Record (ImmutableRecord / Record)

Game tree. Walks linearly through `first.next.next.next...` by default.
Branches available.

```dart
final r = Record();                                      // empty
final r2 = Record.newByUSI(usi)!;                        // parse
final r3 = Record.newByUSEN(usen)!;                      // compact format

r.append(Move move, {bool ignoreValidation = false})     // returns bool
r.goBack() / r.goForward() / r.goto(int ply)
r.first / r.current / r.position / r.initialPosition
r.moves                  // List<ImmutableNode> from current to end
r.metadata               // RecordMetadata (title / black / white / etc.)
r.usi / r.getUSI(USIFormatOptions(...))
r.sfen
r.usen                   // ({String usen, int branchIndex})
r.forEach((ply, node) {...})
r.onChangePositionEvents // Stream<void>
r.on('changePosition', handler)  // TS-compat
```

`Node.move` is `Move | SpecialMove` (use `is` checks). Node fields:
`ply, prev, next, branch, branchIndex, activeBranch, nextColor, isCheck,
comment, customData, sfen, displayText, timeText, hasBranch,
isFirstBranch, isLastMove, elapsedMs, totalElapsedMs, bookmark`.

## Detection: castles / strategies / techniques

Three independent detectors. All three respect side mirroring (templates
written from black's perspective, white side gets file → 10-file,
rank → 10-rank rotation).

### Castle detection

```dart
// Position snapshot
List<DetectedCastle> detectCastles(ImmutablePosition position,
                                   {Color? side});
extension on ImmutablePosition {
  List<DetectedCastle> get castles;   // both sides
}

// Record-based (first-occurrence + game-end igyoku evaluation)
extension on ImmutableRecord {
  List<DetectedCastleAt> get castles; // each (template,side) reported once
}

class DetectedCastle { CastleTemplate template; Color side; }
class DetectedCastleAt {
  CastleTemplate template; Color side; int ply;
}

class CastleTemplate {
  String name;                           // e.g. '金矢倉'
  List<String> aliases;                  // e.g. ['本矢倉']
  String? parent;                        // e.g. '矢倉囲い' (just metadata)
  List<CastleRequirement> placements;
  int? plyEq;                            // only fires at this ply
  int? plyMax;                           // only fires when ply <= plyMax
  bool evaluateAtGameEnd;                // 居玉: evaluated post-walk
}
```

Strategies mirror this exactly with `StrategyTemplate` /
`DetectedStrategy` / `DetectedStrategyAt`. Strategies also carry
`side: StrategySide.{either,ibisha,furibisha}` (居飛車 / 振り飛車 marker).

### CastleRequirement sealed family

```dart
sealed class CastleRequirement {
  bool isSatisfiedBy(ImmutablePosition position, Color side,
                     [MoveHistory? history]);
}

// Per-cell (file/rank in black's view; auto-rotated for white):
class PiecePlacement(int file, int rank, PieceType pieceType,
                    {Color color = Color.black});
  // color: Color.black = own (template-side), Color.white = opponent
class AnyOfPieces(int file, int rank, List<PieceType> options);
class EmptySquare(int file, int rank);
class NotOfPieces(int file, int rank, List<PieceType> excluded);
class AnyPiece(int file, int rank);

// Board / hand-wide (no rotation):
class PieceAnywhere(PieceType pieceType);
class HandPiece(PieceType pieceType, [int minCount = 1]);

// History-dependent (requires MoveHistory):
class PieceUnmoved(int file, int rank);
class PieceVisited(int file, int rank, PieceType pieceType);
class KingIgyoku();    // 居玉 — game-end-evaluated, see below
```

Templates with ply or history requirements behave specially:

- `hasPlyConstraint == true`: only evaluated inside `record.castles` /
  `record.strategies`, never from `position.castles`.
- `hasHistoryRequirement == true`: position-only matchers seed a
  `MoveHistory` with both the standard starting position and the queried
  position; mid-game-only requirements (Uターン飛車 transit through center)
  remain unsatisfied without an actual Record walk.
- `evaluateAtGameEnd == true`: skipped per-ply; evaluated once after the
  walk using final MoveHistory. Currently used by 居玉 templates.

### Technique detection

Techniques are MOVE-based, not position-based. Each
`TechniqueTemplate` subclass implements `bool matches(Move, before,
after)` and is checked against every move in the record.

```dart
abstract class TechniqueTemplate {
  String get name;
  List<String> get aliases;
  bool matches(Move move, ImmutablePosition before,
               ImmutablePosition after);
}

extension on ImmutableRecord {
  // First-occurrence dedup by (template.name, color).
  List<DetectedTechnique> get techniques;
}

// Without dedup (every fire):
List<DetectedTechnique> detectTechniques(ImmutableRecord record);
// Or single-move (interactive):
List<TechniqueTemplate> detectTechniquesAtMove(Move, before, after);

class DetectedTechnique {
  TechniqueTemplate template;
  int ply;
  Color color;
}
```

94 of 137 bioshogi technique names are implemented. The remaining 43 are
格言 (proverbs), formation snapshots, or subjective tactics that can't be
expressed as single-move predicates — see `docs/technique-coverage.md`.

### MoveHistory

```dart
class MoveHistory {
  MoveHistory();
  void initFromPosition(ImmutablePosition);
  void recordMove(Move move, int ply);

  // Predicates
  bool isUnmoved(Color side, int file, int rank);
  bool hasVisited(Color side, PieceType type, int file, int rank);
  int? kingFirstMovedTurn(Color side);
  int? get outbreakTurn;       // ply of first non-pawn/non-bishop capture
}
```

`record.castles` / `record.strategies` build a MoveHistory internally;
direct callers rarely need to.

## Gotchas

1. **File/rank coordinates are 1-indexed and follow shogi convention**.
   File 1 = rightmost from black's view (= 1筋). Rank 1 = top of board
   (= white's home / 1段). Black king starts at (5, 9). White king at
   (5, 1).

2. **All templates are written from black's perspective**. White side
   matching is automatic via file→10-file, rank→10-rank rotation. Don't
   rotate templates by hand.

3. **`position.castles` vs `record.castles`** differ:
   - `position.castles`: snapshot. Returns every matching template,
     repeatedly if you call it on consecutive plies.
   - `record.castles`: walks the record, emits each (template, side)
     only once at its first occurrence. Skips ply 0 (initial position).
     Recommended for UI display.

4. **`Record.newByUSI` returns `Record?`**. Null on parse failure. There
   is also `Record.newByUSIOrError` returning Record or Exception.

5. **`SpecialMoveType.try_` (trailing underscore)**: `try` is a Dart
   keyword; the wire-format value is still the string `'try'` via
   `.value`. Same for other reserved-name collisions.

6. **`USIFormatOptions.break` is renamed to `breakSpecial`** (Dart
   reserved word).

7. **`Hand.formatSFEN` static was renamed to `Hand.formatSFENOf`**
   (Dart doesn't allow static + instance to share a name).

8. **Phase 3 features are stubs**: `record.repetition` returns false,
   `record.getRepetitionCount` returns 0, `record.perpetualCheck` returns
   null. Sennichite and perpetual-check detection are intentionally
   deferred.

9. **Phase 4 formats are not ported**: KIF / KI2 / CSA / JKF / text.
   Only USI / SFEN / USEN are supported for now.

10. **居玉 (KingIgyoku) follows bioshogi semantics**: fires only if the
    king was unmoved at outbreak_turn (= ply of first non-pawn/bishop
    capture). Suppressed in `record.castles` when the same side has any
    other castle detected during the walk.

## Data editing workflow

To add or correct a castle / strategy template:

1. Edit `data/castles.txt` or `data/strategies.txt` directly.
   - 9 rows × 9 cells per template, space-separated tokens.
   - Cell tokens (own = uppercase, opponent = lowercase):
     `K R B G S N L P` (king/rook/bishop/gold/silver/knight/lance/pawn),
     `+P +L +N +S +B +R` (promoted variants),
     `k r b g s n l p` etc. for opponent,
     `.` no requirement, `_` must be empty,
     `*` any own piece, `[GS]` any of, `[!GS]` not of.
   - Header lines above the grid: `parent: ...`, `aliases: A, B`,
     `side: ibisha | furibisha | either`, `ply: 3` / `ply: max 10`,
     `board: B` (piece anywhere), `hand: B*2` (hand piece, min count),
     `unmoved: K 5 9`, `visited: R 6 8`, `igyoku: true`.
2. Run `dart run tool/generate_castles.dart` (or `generate_strategies`).
3. `dart test` to verify.

## Repository layout

```
lib/
  tsshogi.dart                public barrel
  src/
    color.dart piece.dart square.dart direction.dart errors.dart
    move.dart board.dart hand.dart position.dart record.dart
    castle.dart strategy.dart technique.dart move_history.dart
    helpers/time.dart
    generated/
      castles.g.dart           auto-generated, DO NOT EDIT
      strategies.g.dart        auto-generated, DO NOT EDIT
data/
  castles.txt                  ASCII source-of-truth for castles
  strategies.txt               ASCII source-of-truth for strategies
tool/
  template_parser.dart         shared parser
  generate_castles.dart        data/ → lib/src/generated/
  generate_strategies.dart
  import_bioshogi.dart         one-shot: bioshogi Ruby → our ASCII
  export_*.dart                reverse: in-memory data → ASCII
  consolidate_duplicates.dart  helper to merge duplicate templates
  purge_initial_match_templates.dart
test/                          dart test suite
docs/                          plans + coverage notes
bin/check_detection.dart       dev script: run detection on sample USIs
```

## Common tasks

### Adding a custom castle / strategy

Edit `data/*.txt`, regenerate, test.

### Reading a kifu (currently USI only)

```dart
final r = Record.newByUSI(usi);
if (r == null) throw FormatException('bad USI');
```

KIF / KI2 / CSA / JKF parsing is Phase 4 (not implemented). If you have
KIF input, you'll need an external parser (or build one) that emits USI
or constructs the Record directly via `Record.append(move)`.

### Listing legal moves at current position

There is no single "list legal moves" entry point; iterate squares and
call `position.createMove(from, to)` + `position.isValidMove(...)`. A
helper isn't currently provided — see Phase 3 plan.

### Running tests

```bash
dart pub get
dart format .
dart analyze
dart test
```

CI mirrors this via `.github/workflows/test.yaml`. Local CI: `act push
-W .github/workflows/test.yaml` (requires `act`).
