import 'package:test/test.dart';

import 'template_parser.dart';

void main() {
  group('parseTemplateFile', () {
    test('parses a single basic section', () {
      const String input = '''
=== name: 金矢倉
parent: 矢倉囲い
aliases: 本矢倉

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . S G . . . . .
. K G . . . . . .
. . . . . . . . .
''';
      final List<ParsedTemplate> templates = parseTemplateFile(input);
      expect(templates, hasLength(1));
      final ParsedTemplate t = templates.single;
      expect(t.name, '金矢倉');
      expect(t.parent, '矢倉囲い');
      expect(t.aliases, <String>['本矢倉']);
      expect(t.side, isNull);
      // 8八玉 → file 8, rank 8 → row 7 col 1
      final PlacementCell king = t.placements
          .firstWhere((PlacementCell p) => p.pieceTypes.single == 'king');
      expect(king.file, 8);
      expect(king.rank, 8);
      expect(king.kind, 'exact');
    });

    test('parses multiple sections separated by ===', () {
      const String input = '''
=== name: A
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .

=== name: B
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . K . . . . . .
. . . . . . . . .
''';
      final List<ParsedTemplate> templates = parseTemplateFile(input);
      expect(templates.map((ParsedTemplate t) => t.name), <String>['A', 'B']);
    });

    test('handles AnyOfPieces alternation', () {
      const String input = '''
=== name: alt
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . [GS] . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final List<ParsedTemplate> templates = parseTemplateFile(input);
      final PlacementCell alt = templates.single.placements
          .firstWhere((PlacementCell p) => p.kind == 'anyOf');
      expect(alt.pieceTypes, <String>['gold', 'silver']);
    });

    test('handles promoted pieces (+P, +B)', () {
      const String input = '''
=== name: prom
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . +P . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final List<ParsedTemplate> templates = parseTemplateFile(input);
      final PlacementCell promPawn = templates.single.placements
          .firstWhere((PlacementCell p) => p.pieceTypes.single == 'promPawn');
      expect(promPawn.file, 5);
      expect(promPawn.rank, 6);
    });

    test('handles +B (horse) alternation', () {
      const String input = '''
=== name: horseAlt
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . [G+R] . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell alt =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'anyOf');
      expect(alt.pieceTypes, <String>['gold', 'dragon']);
    });

    test('parses side header for strategies', () {
      const String input = '''
=== name: 中飛車
side: furibisha

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . R . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      expect(t.side, 'furibisha');
      final PlacementCell rook = t.placements
          .firstWhere((PlacementCell p) => p.pieceTypes.single == 'rook');
      expect(rook.file, 5);
      expect(rook.rank, 8);
    });

    test('skips comments and blank lines', () {
      const String input = '''
# leading comment
// also a comment

=== name: cmt
# inside header section
parent: P
// before grid

. . . . . . . . .  # trailing comment
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      expect(t.name, 'cmt');
      expect(t.parent, 'P');
    });

    test('throws on missing grid rows', () {
      const String input = '''
=== name: short
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      expect(
        () => parseTemplateFile(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on row with wrong cell count', () {
      const String input = '''
=== name: bad
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . .
''';
      expect(
        () => parseTemplateFile(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on unknown piece token', () {
      const String input = '''
=== name: bad
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. X . . . . . . .
. . . . . . . . .
''';
      expect(
        () => parseTemplateFile(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses underscore as empty-square requirement', () {
      const String input = '''
=== name: emp
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . _ . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell empty =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'empty');
      expect(empty.file, 5);
      expect(empty.rank, 5);
      expect(empty.pieceTypes, isEmpty);
    });

    test('parses asterisk as anyPiece requirement', () {
      const String input = '''
=== name: ap
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . * . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell ap =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'anyPiece');
      expect(ap.file, 5);
      expect(ap.rank, 5);
    });

    test('parses [!GS] as notOf requirement', () {
      const String input = '''
=== name: neg
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . [!GS] . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell neg =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'notOf');
      expect(neg.file, 6);
      expect(neg.rank, 5);
      expect(neg.pieceTypes, <String>['gold', 'silver']);
    });

    test('parses [!+P+L] negated alternation with promoted pieces', () {
      const String input = '''
=== name: negProm
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . [!+P+L] . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell neg =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'notOf');
      expect(neg.pieceTypes, <String>['promPawn', 'promLance']);
    });

    test('parses board: header into pieceAnywhere cells', () {
      const String input = '''
=== name: yagura
board: B
side: ibisha

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . R .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell pa = t.placements
          .firstWhere((PlacementCell p) => p.kind == 'pieceAnywhere');
      expect(pa.pieceTypes, <String>['bishop']);
    });

    test('parses board: with multiple pieces into multiple cells', () {
      const String input = '''
=== name: m
board: B R G

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final List<PlacementCell> pa = t.placements
          .where((PlacementCell p) => p.kind == 'pieceAnywhere')
          .toList();
      expect(pa.length, 3);
      expect(pa.map((PlacementCell p) => p.pieceTypes.single).toList(),
          <String>['bishop', 'rook', 'gold']);
    });

    test('parses hand: header into handPiece cells with default count 1', () {
      const String input = '''
=== name: kakukawari
hand: B
side: ibisha

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . R .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell hp =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'handPiece');
      expect(hp.pieceTypes, <String>['bishop']);
      expect(hp.minCount, 1);
    });

    test('parses hand: header with count "B*2"', () {
      const String input = '''
=== name: handCount
hand: B*2

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final PlacementCell hp =
          t.placements.firstWhere((PlacementCell p) => p.kind == 'handPiece');
      expect(hp.pieceTypes, <String>['bishop']);
      expect(hp.minCount, 2);
    });

    test('parses hand: header with multiple pieces "B R"', () {
      const String input = '''
=== name: handMulti
hand: B R

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      final List<PlacementCell> hp = t.placements
          .where((PlacementCell p) => p.kind == 'handPiece')
          .toList();
      expect(hp.length, 2);
      expect(hp.map((PlacementCell p) => p.pieceTypes.single).toList(),
          <String>['bishop', 'rook']);
      expect(hp.every((PlacementCell p) => p.minCount == 1), isTrue);
    });

    test('parses ply: <n> as plyEq', () {
      const String input = '''
=== name: opening
ply: 1

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      expect(t.plyEq, 1);
      expect(t.plyMax, isNull);
    });

    test('parses ply: max <n> as plyMax', () {
      const String input = '''
=== name: early
ply: max 8

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      expect(t.plyEq, isNull);
      expect(t.plyMax, 8);
    });

    test('parses ply: <n>, max <m> as both', () {
      const String input = '''
=== name: both
ply: 3, max 10

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      expect(t.plyEq, 3);
      expect(t.plyMax, 10);
    });

    test('omits ply: header → plyEq/plyMax both null', () {
      const String input = '''
=== name: noply

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      final ParsedTemplate t = parseTemplateFile(input).single;
      expect(t.plyEq, isNull);
      expect(t.plyMax, isNull);
    });

    test('throws on unknown side value', () {
      const String input = '''
=== name: bad
side: ohno

. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
. K . . . . . . .
. . . . . . . . .
''';
      expect(
        () => parseTemplateFile(input),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('buildGrid', () {
    test('round-trips exact placements', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
            file: 8, rank: 8, kind: 'exact', pieceTypes: <String>['king']),
        PlacementCell(
            file: 7, rank: 8, kind: 'exact', pieceTypes: <String>['gold']),
      ];
      final List<List<String>> grid = buildGrid(placements);
      expect(grid[7][1], 'K'); // rank 8 row idx 7, file 8 col idx 1
      expect(grid[7][2], 'G');
    });

    test('formats alternation as [GS]', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
          file: 6,
          rank: 7,
          kind: 'anyOf',
          pieceTypes: <String>['gold', 'silver'],
        ),
      ];
      final List<List<String>> grid = buildGrid(placements);
      expect(grid[6][3], '[GS]');
    });

    test('formats notOf as [!GS]', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
          file: 6,
          rank: 7,
          kind: 'notOf',
          pieceTypes: <String>['gold', 'silver'],
        ),
      ];
      final List<List<String>> grid = buildGrid(placements);
      expect(grid[6][3], '[!GS]');
    });

    test('formats empty as _ and anyPiece as *', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(file: 5, rank: 5, kind: 'empty'),
        PlacementCell(file: 4, rank: 5, kind: 'anyPiece'),
      ];
      final List<List<String>> grid = buildGrid(placements);
      expect(grid[4][4], '_');
      expect(grid[4][5], '*');
    });

    test('buildGrid skips pieceAnywhere/handPiece (not on the board)', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
          kind: 'pieceAnywhere',
          pieceTypes: <String>['bishop'],
        ),
        PlacementCell(
          kind: 'handPiece',
          pieceTypes: <String>['rook'],
          minCount: 2,
        ),
      ];
      final List<List<String>> grid = buildGrid(placements);
      for (final List<String> row in grid) {
        for (final String cell in row) {
          expect(cell, '.');
        }
      }
    });
  });

  group('formatBoardHeader / formatHandHeader', () {
    test('formatBoardHeader emits one line per pieceAnywhere cell', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
          kind: 'pieceAnywhere',
          pieceTypes: <String>['bishop'],
        ),
        PlacementCell(
          kind: 'pieceAnywhere',
          pieceTypes: <String>['rook'],
        ),
      ];
      expect(formatBoardHeader(placements), 'board: B R');
    });

    test('formatBoardHeader returns null when there are no pieceAnywhere', () {
      expect(formatBoardHeader(<PlacementCell>[]), isNull);
    });

    test('formatHandHeader omits *1 for default count', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
          kind: 'handPiece',
          pieceTypes: <String>['bishop'],
        ),
      ];
      expect(formatHandHeader(placements), 'hand: B');
    });

    test('formatPlyHeader returns null when both null', () {
      expect(formatPlyHeader(plyEq: null, plyMax: null), isNull);
    });

    test('formatPlyHeader emits "ply: <n>" for plyEq only', () {
      expect(formatPlyHeader(plyEq: 1, plyMax: null), 'ply: 1');
    });

    test('formatPlyHeader emits "ply: max <n>" for plyMax only', () {
      expect(formatPlyHeader(plyEq: null, plyMax: 8), 'ply: max 8');
    });

    test('formatPlyHeader emits "ply: <n>, max <m>" for both', () {
      expect(formatPlyHeader(plyEq: 3, plyMax: 10), 'ply: 3, max 10');
    });

    test('formatHandHeader includes *N when count > 1', () {
      final List<PlacementCell> placements = <PlacementCell>[
        PlacementCell(
          kind: 'handPiece',
          pieceTypes: <String>['bishop'],
          minCount: 2,
        ),
        PlacementCell(
          kind: 'handPiece',
          pieceTypes: <String>['rook'],
        ),
      ];
      expect(formatHandHeader(placements), 'hand: B*2 R');
    });
  });
}
