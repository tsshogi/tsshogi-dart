---
name: refactor
description: Refactor the tsshogi Dart source safely — improve internal variable/function names and remove redundant code without changing public API or breaking bioshogi fidelity. Use when asked to refactor, clean up, rename, or de-duplicate the library code. Runs the CI checks (format/analyze/test) after each change and commits incrementally in commitlint form.
---

# Refactor (tsshogi Dart)

Behaviour-preserving cleanup of `lib/` source: clearer internal names, less duplication.
This library is a faithful port of upstream TypeScript `tsshogi` and of bioshogi's
castle/strategy notation, so **fidelity beats cleverness** — never trade compatibility
for a tidier-looking diff.

## Golden rules

1. **Never edit generated files.** `lib/src/generated/*.g.dart` are produced by
   `tool/generate_castles.dart` / `tool/generate_strategies.dart` from
   `data/castles.txt` / `data/strategies.txt`. To change them, edit the data or the
   generator and regenerate — never hand-edit the `.g.dart`.
2. **Do not rename public API.** Exported names (see `lib/tsshogi.dart`) mirror upstream
   TypeScript `tsshogi` on purpose (`reverseColor`, `colorToSFEN`, `parseSFENColor`,
   `Hand.formatSFENOf`, …). Renaming breaks consumers and drifts from upstream. Refactor
   *inside* functions: locals, private helpers (`_name`), private fields, dead code.
3. **Behaviour must not change.** The 789-passing / 2-skipped test suite is the contract.
   If a rename or de-dup would change any output, stop.
4. **Small, reviewable steps.** One concern per commit. Refactor and behaviour change
   never share a commit.

## Where the value is

The data tables (`_movableDirectionMap`, `_sfenCharToColorMap`, `InitialPositionSFEN`, …)
are intentionally explicit — leave them. Look instead for:

- duplicated blocks (e.g. identical hand/point-counting in two functions → extract a helper);
- long `if`/`switch` chains that re-implement an existing map;
- awkward local names (`c`, `t`, `ret`, `tmp`, `s`) where intent is unclear;
- repeated literals that deserve a named constant.

## Loop for every change

Run from the repo root. The local Dart SDK may be a **beta** build while CI uses
**stable** — they format identically for `lib/` files (verify once with
`dart format --output=none --set-exit-if-changed lib`), so only format what you touch.

```bash
# 1. format only the files you edited (avoids beta-vs-stable drift in untouched files)
dart format <edited-file.dart> [...]

# 2. the three checks CI runs (.github/workflows/test.yaml)
dart analyze --fatal-infos --fatal-warnings
dart test --reporter failures-only
```

All three must pass before committing. Expect `+789 ... 2 skipped`.

### About `act`

CI is `.github/workflows/test.yaml` (`dart format` → `dart analyze` → `dart test`).
`act push -j test` reproduces it **only when the sandbox has network** — it clones
`dart-lang/setup-dart` and downloads the SDK. In an offline sandbox `act` fails with
`lookup github.com ... no such host`; that is an environment limit, not a code failure.
When `act` can't reach the network, the three `dart` commands above are the exact
equivalent — run them directly and say so.

## Committing

Per project convention (see auto-memory): branch off `develop`, never commit to
`master`/`develop` directly; messages in **English**; start the subject lowercase (or in
Japanese) so commitlint's `subject-case` passes; type from `.commitlintrc.yaml` — use
`refactor` for renames/de-dup, `format` for pure formatting.

```
refactor(<scope>): <lowercase imperative summary>

<why the change is behaviour-preserving, if not obvious>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

Commit after each self-contained change once the loop is green. Scope = the module
(`position`, `hand`, `errors`, …).
