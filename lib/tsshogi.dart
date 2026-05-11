/// Dart port of tsshogi — Japanese shogi library.
///
/// Mirrors src/index.ts from the upstream TypeScript implementation
/// (https://github.com/sunfish-shogi/tsshogi v2.3.2).
///
/// Phase 4 modules (text.dart / kakinoki.dart / csa.dart / jkf.dart /
/// detect.dart) are intentionally NOT ported in this initial release —
/// the upstream KIF/KI2/CSA/JKF/notation features are server-side concerns
/// for this project. See docs/plans/tsshogi-dart-port.md.

library tsshogi;

export 'src/helpers/time.dart';
export 'src/errors.dart';
export 'src/piece.dart';
export 'src/color.dart';
export 'src/direction.dart';
export 'src/square.dart';
export 'src/move.dart';
export 'src/board.dart';
export 'src/hand.dart';
export 'src/position.dart';
export 'src/record.dart';
