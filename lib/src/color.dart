/// 手番(先手・後手)
enum Color {
  /// 先手
  black('black'),

  /// 後手
  white('white');

  const Color(this.value);

  final String value;
}

/// 反対の手番を返します。
Color reverseColor(Color color) {
  return color == Color.black ? Color.white : Color.black;
}

/// SFEN形式の手番を取得します。
String colorToSFEN(Color color) {
  return color == Color.black ? 'b' : 'w';
}

/// 指定した文字列が正しいSFENの手番かどうかを判定します。
bool isValidSFENColor(String sfen) {
  return sfen == 'b' || sfen == 'w';
}

/// SFEN形式の手番を読み取ります。
Color parseSFENColor(String sfen) {
  return sfen == 'b' ? Color.black : Color.white;
}
