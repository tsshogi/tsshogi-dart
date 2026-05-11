import 'color.dart';
import 'piece.dart';

String _buildSFEN(int n, Piece piece) {
  if (n == 0) {
    return '';
  }
  return (n != 1 ? '$n' : '') + piece.sfen;
}

const List<PieceType> _orderRookFirst = [
  PieceType.rook,
  PieceType.bishop,
  PieceType.gold,
  PieceType.silver,
  PieceType.knight,
  PieceType.lance,
  PieceType.pawn,
];

const List<PieceType> _orderPawnFirst = [
  PieceType.pawn,
  PieceType.lance,
  PieceType.knight,
  PieceType.silver,
  PieceType.gold,
  PieceType.bishop,
  PieceType.rook,
];

/// 持ち駒(読み取り専用)
abstract interface class ImmutableHand {
  /// 持ち駒の枚数を取得します。
  int count(PieceType pieceType);

  /// 駒の種類ごとにハンドラーを呼び出します。
  void forEach(void Function(PieceType pieceType, int n) handler);

  /// 持ち駒の種類と枚数の一覧を取得します。
  List<({PieceType type, int count})> get counts;

  /// 先手の持ち駒に対してSFEN形式の文字列を取得します。
  String get sfenBlack;

  /// 後手の持ち駒に対してSFEN形式の文字列を取得します。
  String get sfenWhite;

  /// SFEN形式の文字列を取得します。
  String formatSFEN(Color color);
}

/// 持ち駒
class Hand implements ImmutableHand {
  Hand() {
    _counts = <PieceType, int>{
      PieceType.pawn: 0,
      PieceType.lance: 0,
      PieceType.knight: 0,
      PieceType.silver: 0,
      PieceType.gold: 0,
      PieceType.bishop: 0,
      PieceType.rook: 0,
    };
  }

  late Map<PieceType, int> _counts;

  /// 持ち駒の種類と枚数の一覧を取得します。
  @override
  List<({PieceType type, int count})> get counts {
    return _orderRookFirst
        .map((PieceType type) => (type: type, count: count(type)))
        .toList(growable: false);
  }

  /// 持ち駒の枚数を取得します。
  @override
  int count(PieceType pieceType) {
    final int c = _counts[pieceType] ?? 0;
    return c < 0 ? 0 : c;
  }

  /// 持ち駒の枚数を設定します。
  int set(PieceType pieceType, int count) {
    _counts[pieceType] = count;
    return count;
  }

  /// 持ち駒を追加します。
  int add(PieceType pieceType, int n) {
    final int c = (_counts[pieceType] ?? 0) + n;
    _counts[pieceType] = c;
    return c;
  }

  /// 持ち駒を減らします。
  int reduce(PieceType pieceType, int n) {
    final int c = (_counts[pieceType] ?? 0) - n;
    _counts[pieceType] = c;
    return c;
  }

  /// 駒の種類ごとにハンドラーを呼び出します。
  @override
  void forEach(void Function(PieceType pieceType, int n) handler) {
    for (final PieceType type in _orderPawnFirst) {
      handler(type, _counts[type] ?? 0);
    }
  }

  /// 先手の持ち駒に対してSFEN形式の文字列を取得します。
  @override
  String get sfenBlack => formatSFEN(Color.black);

  /// 後手の持ち駒に対してSFEN形式の文字列を取得します。
  @override
  String get sfenWhite => formatSFEN(Color.white);

  /// SFEN形式の文字列を取得します。
  @override
  String formatSFEN(Color color) {
    final StringBuffer ret = StringBuffer();
    for (final PieceType type in _orderRookFirst) {
      ret.write(_buildSFEN(count(type), Piece(color, type)));
    }
    final String s = ret.toString();
    if (s.isEmpty) {
      return '-';
    }
    return s;
  }

  /// SFEN形式の文字列を取得します。
  static String formatSFENOf(ImmutableHand black, ImmutableHand white) {
    final String b = black.sfenBlack;
    final String w = white.sfenWhite;
    if (b == '-' && w == '-') {
      return '-';
    }
    if (w == '-') {
      return b;
    }
    if (b == '-') {
      return w;
    }
    return b + w;
  }

  /// 指定した文字列が正しい持ち駒のSFENであるかどうかを判定します。
  static bool isValidSFEN(String sfen) {
    if (sfen == '-') {
      return true;
    }
    return RegExp(r'^(?:[0-9]{0,2}[PLNSGBRplnsgbr])+$').hasMatch(sfen);
  }

  /// 持ち駒のSFENを解析します。
  static ({Hand black, Hand white})? parseSFEN(String sfen) {
    if (sfen == '-') {
      return (black: Hand(), white: Hand());
    }
    final Iterable<RegExpMatch> matches =
        RegExp(r'([0-9]{0,2}[PLNSGBRplnsgbr])').allMatches(sfen);
    if (matches.isEmpty) {
      return null;
    }
    final Hand black = Hand();
    final Hand white = Hand();
    for (final RegExpMatch m in matches) {
      final String section = m.group(0)!;
      final int n = section.length >= 2
          ? int.parse(section.substring(0, section.length - 1))
          : 1;
      final Piece? piece = Piece.newBySFEN(section[section.length - 1]);
      if (piece == null) {
        return null;
      }
      if (piece.color == Color.black) {
        black.add(piece.type, n);
      } else {
        white.add(piece.type, n);
      }
    }
    return (black: black, white: white);
  }

  /// 別のオブジェクトからコピーします。
  void copyFrom(ImmutableHand hand) {
    for (final PieceType type in _orderPawnFirst) {
      _counts[type] = hand.count(type);
    }
  }
}
