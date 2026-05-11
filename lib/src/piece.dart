import 'color.dart';

/// 駒の種類
enum PieceType {
  pawn('pawn'),
  lance('lance'),
  knight('knight'),
  silver('silver'),
  gold('gold'),
  bishop('bishop'),
  rook('rook'),
  king('king'),
  promPawn('promPawn'),
  promLance('promLance'),
  promKnight('promKnight'),
  promSilver('promSilver'),
  horse('horse'),
  dragon('dragon');

  const PieceType(this.value);

  final String value;
}

const Map<PieceType, String> _standardPieceNameMap = {
  PieceType.pawn: '歩',
  PieceType.lance: '香',
  PieceType.knight: '桂',
  PieceType.silver: '銀',
  PieceType.gold: '金',
  PieceType.bishop: '角',
  PieceType.rook: '飛',
  PieceType.king: '玉',
  PieceType.promPawn: 'と',
  PieceType.promLance: '成香',
  PieceType.promKnight: '成桂',
  PieceType.promSilver: '成銀',
  PieceType.horse: '馬',
  PieceType.dragon: '竜',
};

/// 標準的な駒の名前を返します。
String standardPieceName(PieceType type) {
  return _standardPieceNameMap[type] ?? '';
}

const List<PieceType> pieceTypes = [
  PieceType.pawn,
  PieceType.lance,
  PieceType.knight,
  PieceType.silver,
  PieceType.gold,
  PieceType.bishop,
  PieceType.rook,
  PieceType.king,
  PieceType.promPawn,
  PieceType.promLance,
  PieceType.promKnight,
  PieceType.promSilver,
  PieceType.horse,
  PieceType.dragon,
];

const List<PieceType> handPieceTypes = [
  PieceType.pawn,
  PieceType.lance,
  PieceType.knight,
  PieceType.silver,
  PieceType.gold,
  PieceType.bishop,
  PieceType.rook,
];

const Map<PieceType, bool> _promotable = {
  PieceType.pawn: true,
  PieceType.lance: true,
  PieceType.knight: true,
  PieceType.silver: true,
  PieceType.gold: false,
  PieceType.bishop: true,
  PieceType.rook: true,
  PieceType.king: false,
  PieceType.promPawn: false,
  PieceType.promLance: false,
  PieceType.promKnight: false,
  PieceType.promSilver: false,
  PieceType.horse: false,
  PieceType.dragon: false,
};

/// 成ることができる駒かどうかを返します。
bool isPromotable(PieceType pieceType) {
  return _promotable[pieceType] ?? false;
}

const Map<PieceType, PieceType> _promoteMap = {
  PieceType.pawn: PieceType.promPawn,
  PieceType.lance: PieceType.promLance,
  PieceType.knight: PieceType.promKnight,
  PieceType.silver: PieceType.promSilver,
  PieceType.bishop: PieceType.horse,
  PieceType.rook: PieceType.dragon,
};

/// 成った時の駒の種類を返します。
PieceType promotedPieceType(PieceType pieceType) {
  return _promoteMap[pieceType] ?? pieceType;
}

const Map<PieceType, PieceType> _unpromoteMap = {
  PieceType.promPawn: PieceType.pawn,
  PieceType.promLance: PieceType.lance,
  PieceType.promKnight: PieceType.knight,
  PieceType.promSilver: PieceType.silver,
  PieceType.horse: PieceType.bishop,
  PieceType.dragon: PieceType.rook,
};

/// 成る前の駒の種類を返します。
PieceType unpromotedPieceType(PieceType pieceType) {
  return _unpromoteMap[pieceType] ?? pieceType;
}

const Map<PieceType, String> _toSFENCharBlack = {
  PieceType.pawn: 'P',
  PieceType.lance: 'L',
  PieceType.knight: 'N',
  PieceType.silver: 'S',
  PieceType.gold: 'G',
  PieceType.bishop: 'B',
  PieceType.rook: 'R',
  PieceType.king: 'K',
  PieceType.promPawn: '+P',
  PieceType.promLance: '+L',
  PieceType.promKnight: '+N',
  PieceType.promSilver: '+S',
  PieceType.horse: '+B',
  PieceType.dragon: '+R',
};

/// SFEN形式の駒種を表す文字列を返します。
String pieceTypeToSFEN(PieceType type) {
  return _toSFENCharBlack[type]!;
}

const Map<PieceType, String> _toSFENCharWhite = {
  PieceType.pawn: 'p',
  PieceType.lance: 'l',
  PieceType.knight: 'n',
  PieceType.silver: 's',
  PieceType.gold: 'g',
  PieceType.bishop: 'b',
  PieceType.rook: 'r',
  PieceType.king: 'k',
  PieceType.promPawn: '+p',
  PieceType.promLance: '+l',
  PieceType.promKnight: '+n',
  PieceType.promSilver: '+s',
  PieceType.horse: '+b',
  PieceType.dragon: '+r',
};

const Map<String, PieceType> _sfenCharToTypeMap = {
  'P': PieceType.pawn,
  'L': PieceType.lance,
  'N': PieceType.knight,
  'S': PieceType.silver,
  'G': PieceType.gold,
  'B': PieceType.bishop,
  'R': PieceType.rook,
  'K': PieceType.king,
  '+P': PieceType.promPawn,
  '+L': PieceType.promLance,
  '+N': PieceType.promKnight,
  '+S': PieceType.promSilver,
  '+B': PieceType.horse,
  '+R': PieceType.dragon,
  'p': PieceType.pawn,
  'l': PieceType.lance,
  'n': PieceType.knight,
  's': PieceType.silver,
  'g': PieceType.gold,
  'b': PieceType.bishop,
  'r': PieceType.rook,
  'k': PieceType.king,
  '+p': PieceType.promPawn,
  '+l': PieceType.promLance,
  '+n': PieceType.promKnight,
  '+s': PieceType.promSilver,
  '+b': PieceType.horse,
  '+r': PieceType.dragon,
};

const Map<String, Color> _sfenCharToColorMap = {
  'P': Color.black,
  'L': Color.black,
  'N': Color.black,
  'S': Color.black,
  'G': Color.black,
  'B': Color.black,
  'R': Color.black,
  'K': Color.black,
  '+P': Color.black,
  '+L': Color.black,
  '+N': Color.black,
  '+S': Color.black,
  '+B': Color.black,
  '+R': Color.black,
  'p': Color.white,
  'l': Color.white,
  'n': Color.white,
  's': Color.white,
  'g': Color.white,
  'b': Color.white,
  'r': Color.white,
  'k': Color.white,
  '+p': Color.white,
  '+l': Color.white,
  '+n': Color.white,
  '+s': Color.white,
  '+b': Color.white,
  '+r': Color.white,
};

class _RotateResult {
  const _RotateResult(this.type, this.reverseColor);
  final PieceType type;
  final bool reverseColor;
}

const Map<PieceType, _RotateResult> _rotateMap = {
  PieceType.pawn: _RotateResult(PieceType.promPawn, false),
  PieceType.lance: _RotateResult(PieceType.promLance, false),
  PieceType.knight: _RotateResult(PieceType.promKnight, false),
  PieceType.silver: _RotateResult(PieceType.promSilver, false),
  PieceType.gold: _RotateResult(PieceType.gold, true),
  PieceType.bishop: _RotateResult(PieceType.horse, false),
  PieceType.rook: _RotateResult(PieceType.dragon, false),
  PieceType.king: _RotateResult(PieceType.king, true),
  PieceType.promPawn: _RotateResult(PieceType.pawn, true),
  PieceType.promLance: _RotateResult(PieceType.lance, true),
  PieceType.promKnight: _RotateResult(PieceType.knight, true),
  PieceType.promSilver: _RotateResult(PieceType.silver, true),
  PieceType.horse: _RotateResult(PieceType.bishop, true),
  PieceType.dragon: _RotateResult(PieceType.rook, true),
};

/// 駒(手番を含む)
class Piece {
  Piece(this.color, this.type);

  Color color;
  PieceType type;

  /// 先手番の駒に変換します。
  Piece black() => withColor(Color.black);

  /// 後手番の駒に変換します。
  Piece white() => withColor(Color.white);

  /// 手番を変更した駒を返します。
  Piece withColor(Color color) {
    return Piece(color, type);
  }

  /// 等しい駒かどうかを判定します。
  bool equals(Piece? piece) {
    if (piece == null) return false;
    return type == piece.type && color == piece.color;
  }

  @override
  bool operator ==(Object other) {
    return other is Piece && other.type == type && other.color == color;
  }

  @override
  int get hashCode => Object.hash(color, type);

  /// 成った駒を返します。
  Piece promoted() {
    final PieceType? t = _promoteMap[type];
    return Piece(color, t ?? type);
  }

  /// 成る前の駒を返します。
  Piece unpromoted() {
    final PieceType? t = _unpromoteMap[type];
    return Piece(color, t ?? type);
  }

  /// 成ることが可能な駒かどうかを返します。
  bool isPromotable() {
    return _promotable[type] ?? false;
  }

  /// 駒の向きと種類をローテートします。
  /// ex) 先手・歩 -> 先手・と -> 後手・歩 -> 後手・と -> 先手・歩
  Piece rotate() {
    final _RotateResult? r = _rotateMap[type];
    final Piece piece = Piece(color, r != null ? r.type : type);
    if (r != null && r.reverseColor) {
      piece.color = reverseColor(color);
    }
    return piece;
  }

  /// 手番と種類を一意に識別する ID を返します。
  String get id => '${color.value}_${type.value}';

  /// SFEN形式の文字列を取得します。
  String get sfen {
    switch (color) {
      case Color.black:
        return _toSFENCharBlack[type]!;
      case Color.white:
        return _toSFENCharWhite[type]!;
    }
  }

  /// 指定した文字列が正しいSFEN形式の駒かどうかを判定します。
  static bool isValidSFEN(String sfen) {
    return _sfenCharToTypeMap.containsKey(sfen);
  }

  /// SFEN形式の文字列から駒を生成します。
  static Piece? newBySFEN(String sfen) {
    final PieceType? type = _sfenCharToTypeMap[sfen];
    if (type == null) return null;
    final Color? color = _sfenCharToColorMap[sfen];
    if (color == null) return null;
    return Piece(color, type);
  }
}
