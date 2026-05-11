import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/record.dart';
import 'package:tsshogi/src/strategy.dart';
import 'package:tsshogi/src/technique.dart';

/// 確認用 USI 棋譜を一覧で保持。追加するときはここに足すだけ。
const Map<String, String> _samples = <String, String>{
  '対振り急戦 (40手)':
      'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 '
          'moves 7g7f 3c3d 2g2f 8b4b 3i4h 5a6b 5i6h 7a7b 4i5h 6b7a 6h7h 7a8b '
          '5g5f 9c9d 2f2e 2b3c 7i6h 4c4d 6h5g 4a5b 3g3f 3a3b 9g9f 3b4c 2i3g '
          '4c5d 6i6h 6c6d 4g4f 5b6c 4h4g 7c7d 2h2i 8a7c 5g6f 8c8d 1g1f 7b8c '
          '8h7g 6a7b',
  '横歩取り (22手)':
      'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 '
          'moves 7g7f 3c3d 2g2f 8c8d 2f2e 8d8e 6i7h 4a3b 2e2d 2c2d 2h2d 8e8f '
          '8g8f 8b8f 2d3d 2b8h+ 7i8h 8f7f 8h7g 7f7d 3d7d 7c7d',
  '角換わり (40手)':
      'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 '
          'moves 7g7f 3c3d 2g2f 8c8d 6i7h 8d8e 8h2b+ 3a2b 7i8h 2b3c 8h7g 4a3b '
          '5i6h 7a6b 2f2e 5a5b 3i3h 6c6d 3g3f 6b6c 3h3g 6c5d 3g4f 7c7d 2i3g '
          '8a7c 2h2i 8b8a 4i4h 6a6b 6h7i 5b4b 9g9f 9c9d 1g1f 1c1d 5g5f 4b3a '
          '7i8h 3a2b',
};

void main() {
  for (final MapEntry<String, String> e in _samples.entries) {
    print('################ ${e.key} ################');
    final Record? r = Record.newByUSI(e.value);
    if (r == null) {
      print('PARSE FAILED\n');
      continue;
    }

    print('=== 囲い (record.castles) ===');
    for (final DetectedCastleAt c in r.castles) {
      print(
        '${c.ply.toString().padLeft(3)}手目: ${c.side.value.padRight(5)} '
        '${c.template.name}',
      );
    }

    print('\n=== 戦法 (record.strategies) ===');
    for (final DetectedStrategyAt s in r.strategies) {
      print(
        '${s.ply.toString().padLeft(3)}手目: ${s.side.value.padRight(5)} '
        '${s.template.name}',
      );
    }

    print('\n=== 手筋 (record.techniques) ===');
    for (final DetectedTechnique t in r.techniques) {
      print(
        '${t.ply.toString().padLeft(3)}手目: ${t.color.value.padRight(5)} '
        '${t.template.name}',
      );
    }
    print('');
  }
}
