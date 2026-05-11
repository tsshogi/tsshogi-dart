import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/strategy.dart';
import 'package:tsshogi/src/technique.dart';

void main() {
  const String usi =
      'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 '
      'moves 7g7f 3c3d 2g2f 8b4b 3i4h 5a6b 5i6h 7a7b 4i5h 6b7a 6h7h 7a8b 5g5f 9c9d '
      '2f2e 2b3c 7i6h 4c4d 6h5g 4a5b 3g3f 3a3b 9g9f 3b4c 2i3g 4c5d 6i6h 6c6d 4g4f '
      '5b6c 4h4g 7c7d 2h2i 8a7c 5g6f 8c8d 1g1f 7b8c 8h7g 6a7b';
  final Record? r = Record.newByUSI(usi);
  if (r == null) {
    print('PARSE FAILED');
    return;
  }

  print('=== 囲い (record.castles, first-occurrence) ===');
  for (final DetectedCastleAt c in r.castles) {
    print(
      '${c.ply.toString().padLeft(3)}手目: ${c.side.value.padRight(5)} '
      '${c.template.name}',
    );
  }

  print('\n=== 戦法 (record.strategies, first-occurrence) ===');
  for (final DetectedStrategyAt s in r.strategies) {
    print(
      '${s.ply.toString().padLeft(3)}手目: ${s.side.value.padRight(5)} '
      '${s.template.name}',
    );
  }

  print('\n=== 手筋 (record.techniques, per-move) ===');
  for (final DetectedTechnique t in r.techniques) {
    print(
      '${t.ply.toString().padLeft(3)}手目: ${t.color.value.padRight(5)} '
      '${t.template.name}',
    );
  }
}
