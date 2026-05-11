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
  });
}
