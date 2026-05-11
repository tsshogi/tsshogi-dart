class InvalidPieceNameError implements Exception {
  InvalidPieceNameError(this.data);
  final String data;
  @override
  String toString() => 'Invalid piece name: $data';
}

class InvalidTurnError implements Exception {
  InvalidTurnError(this.data);
  final String data;
  @override
  String toString() => 'Invalid turn: $data';
}

class InvalidMoveError implements Exception {
  InvalidMoveError(this.data);
  final String data;
  @override
  String toString() => 'Invalid move: $data';
}

class InvalidMoveNumberError implements Exception {
  InvalidMoveNumberError(this.data);
  final String data;
  @override
  String toString() => 'Invalid move number: $data';
}

class InvalidDestinationError implements Exception {
  InvalidDestinationError(this.data);
  final String data;
  @override
  String toString() => 'Invalid destination: $data';
}

class PieceNotExistsError implements Exception {
  PieceNotExistsError(this.data);
  final String data;
  @override
  String toString() => 'Piece not exists: $data';
}

class InvalidLineError implements Exception {
  InvalidLineError(this.data);
  final String data;
  @override
  String toString() => 'Invalid line: $data';
}

@Deprecated('No longer used.')
class InvalidHandicapError implements Exception {
  InvalidHandicapError(this.data);
  final String data;
  @override
  String toString() => 'Invalid handicap: $data';
}

class InvalidBoardError implements Exception {
  InvalidBoardError(this.data);
  final String data;
  @override
  String toString() => 'Invalid board: $data';
}

class InvalidHandPieceError implements Exception {
  InvalidHandPieceError(this.data);
  final String data;
  @override
  String toString() => 'Invalid hand piece: $data';
}

class InvalidUSIError implements Exception {
  InvalidUSIError(this.data);
  final String data;
  @override
  String toString() => 'Invalid USI: $data';
}
