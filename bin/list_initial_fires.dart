import 'package:tsshogi/src/castle.dart';
import 'package:tsshogi/src/color.dart';
import 'package:tsshogi/src/position.dart';
import 'package:tsshogi/src/strategy.dart';

void main() {
  final Position p = Position();
  print('=== 初期局面で誤発火する囲い (黒) ===');
  for (final DetectedCastle c
      in p.castles.where((d) => d.side == Color.black)) {
    print('  ${c.template.name}');
  }
  print('\n=== 初期局面で誤発火する戦法 (黒) ===');
  for (final DetectedStrategy s
      in p.strategies.where((d) => d.side == Color.black)) {
    print('  ${s.template.name}');
  }
}
