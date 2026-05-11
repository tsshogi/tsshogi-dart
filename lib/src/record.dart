import 'dart:async';

import 'color.dart';
import 'errors.dart';
import 'helpers/time.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'square.dart';

const Map<PieceType, int> _usenHandTable = <PieceType, int>{
  PieceType.pawn: 81 + 10,
  PieceType.lance: 81 + 11,
  PieceType.knight: 81 + 12,
  PieceType.silver: 81 + 13,
  PieceType.gold: 81 + 9,
  PieceType.bishop: 81 + 14,
  PieceType.rook: 81 + 15,
  PieceType.king: 81 + 8,
  PieceType.promPawn: 81 + 2,
  PieceType.promLance: 81 + 3,
  PieceType.promKnight: 81 + 4,
  PieceType.promSilver: 81 + 5,
  PieceType.horse: 81 + 6,
  PieceType.dragon: 81 + 7,
};

const Map<int, PieceType> _usenHandReverseTable = <int, PieceType>{
  81 + 10: PieceType.pawn,
  81 + 11: PieceType.lance,
  81 + 12: PieceType.knight,
  81 + 13: PieceType.silver,
  81 + 9: PieceType.gold,
  81 + 14: PieceType.bishop,
  81 + 15: PieceType.rook,
  81 + 8: PieceType.king,
  81 + 2: PieceType.promPawn,
  81 + 3: PieceType.promLance,
  81 + 4: PieceType.promKnight,
  81 + 5: PieceType.promSilver,
  81 + 6: PieceType.horse,
  81 + 7: PieceType.dragon,
};

/// 棋譜メタデータのキー
enum RecordMetadataKey {
  title('title'),
  blackName('blackName'),
  whiteName('whiteName'),
  shitateName('shitateName'),
  uwateName('uwateName'),
  blackShortName('blackShortName'),
  whiteShortName('whiteShortName'),
  startDatetime('startDatetime'),
  endDatetime('endDatetime'),
  date('date'),
  tournament('tournament'),
  strategy('strategy'),
  timeLimit('timeLimit'),
  blackTimeLimit('blackTimeLimit'),
  whiteTimeLimit('whiteTimeLimit'),
  byoyomi('byoyomi'),
  timeSpent('timeSpent'),
  maxMoves('maxMoves'),
  jishogi('jishogi'),
  place('place'),
  postedOn('postedOn'),
  note('note'),
  scorekeeper('scorekeeper'),
  opusNo('opusNo'),
  opusName('opusName'),
  author('author'),
  publishedBy('publishedBy'),
  publishedAt('publishedAt'),
  source('source'),
  length('length'),
  integrity('integrity'),
  category('category'),
  award('award');

  const RecordMetadataKey(this.value);
  final String value;
}

/// 棋譜メタデータ(読み取り専用)
abstract interface class ImmutableRecordMetadata {
  Iterable<RecordMetadataKey> get standardMetadataKeys;
  String? getStandardMetadata(RecordMetadataKey key);
  Iterable<String> get customMetadataKeys;
  String? getCustomMetadata(String key);
}

/// 棋譜メタデータ
class RecordMetadata implements ImmutableRecordMetadata {
  final Map<RecordMetadataKey, String> _standard =
      <RecordMetadataKey, String>{};
  final Map<String, String> _custom = <String, String>{};

  @override
  Iterable<RecordMetadataKey> get standardMetadataKeys => _standard.keys;

  @override
  String? getStandardMetadata(RecordMetadataKey key) => _standard[key];

  void setStandardMetadata(RecordMetadataKey key, String? value) {
    if (value != null && value.isNotEmpty) {
      _standard[key] = value;
    } else {
      _standard.remove(key);
    }
  }

  @override
  Iterable<String> get customMetadataKeys => _custom.keys;

  @override
  String? getCustomMetadata(String key) => _custom[key];

  void setCustomMetadata(String key, String? value) {
    if (value != null && value.isNotEmpty) {
      _custom[key] = value;
    } else {
      _custom.remove(key);
    }
  }
}

/// 先手の対局者名をフルネーム優先で取得します。
String? getBlackPlayerName(ImmutableRecordMetadata metadata) {
  return metadata.getStandardMetadata(RecordMetadataKey.blackName) ??
      metadata.getStandardMetadata(RecordMetadataKey.blackShortName) ??
      metadata.getStandardMetadata(RecordMetadataKey.shitateName);
}

/// 後手の対局者名をフルネーム優先で取得します。
String? getWhitePlayerName(ImmutableRecordMetadata metadata) {
  return metadata.getStandardMetadata(RecordMetadataKey.whiteName) ??
      metadata.getStandardMetadata(RecordMetadataKey.whiteShortName) ??
      metadata.getStandardMetadata(RecordMetadataKey.uwateName);
}

/// 先手の対局者名を省略名優先で取得します。
String? getBlackPlayerNamePreferShort(ImmutableRecordMetadata metadata) {
  return metadata.getStandardMetadata(RecordMetadataKey.blackShortName) ??
      metadata.getStandardMetadata(RecordMetadataKey.blackName) ??
      metadata.getStandardMetadata(RecordMetadataKey.shitateName);
}

/// 後手の対局者名を省略名優先で取得します。
String? getWhitePlayerNamePreferShort(ImmutableRecordMetadata metadata) {
  return metadata.getStandardMetadata(RecordMetadataKey.whiteShortName) ??
      metadata.getStandardMetadata(RecordMetadataKey.whiteName) ??
      metadata.getStandardMetadata(RecordMetadataKey.uwateName);
}

/// 棋譜を構成するノード(読み取り専用)
abstract interface class ImmutableNode {
  int get ply;
  ImmutableNode? get prev;
  ImmutableNode? get next;
  ImmutableNode? get branch;
  int get branchIndex;
  bool get activeBranch;
  Color get nextColor;

  /// [Move] または [SpecialMove] のいずれか。
  Object get move;
  bool get isCheck;
  String get comment;
  Object? get customData;
  String get sfen;
  String get displayText;
  String get timeText;
  bool get hasBranch;
  bool get isFirstBranch;
  bool get isLastMove;
  int get elapsedMs;
  int get totalElapsedMs;
  String get bookmark;
}

/// 棋譜を構成するノード
abstract interface class Node implements ImmutableNode {
  @override
  Node? get prev;
  @override
  Node? get next;
  @override
  Node? get branch;
  set comment(String value);
  set bookmark(String value);
  set customData(Object? value);
  void setElapsedMs(int elapsedMs);
}

class _NodeImpl implements Node {
  _NodeImpl({
    required this.ply,
    required _NodeImpl? prev,
    required this.branchIndex,
    required this.activeBranch,
    required this.nextColor,
    required this.move,
    required this.isCheck,
    required this.displayText,
    required this.sfen,
  }) : _prev = prev;

  @override
  int ply;
  _NodeImpl? _prev;
  _NodeImpl? _next;
  _NodeImpl? _branch;
  @override
  int branchIndex;
  @override
  bool activeBranch;
  @override
  Color nextColor;
  @override
  Object move;
  @override
  bool isCheck;
  @override
  String displayText;
  @override
  String sfen;
  @override
  String comment = '';
  @override
  Object? customData;
  @override
  int elapsedMs = 0;
  @override
  int totalElapsedMs = 0;
  @override
  String bookmark = '';

  @override
  _NodeImpl? get prev => _prev;
  set prev(_NodeImpl? value) => _prev = value;

  @override
  _NodeImpl? get next => _next;
  set next(_NodeImpl? value) => _next = value;

  @override
  _NodeImpl? get branch => _branch;
  set branch(_NodeImpl? value) => _branch = value;

  @override
  String get timeText {
    final String elapsed = millisecondsToMSS(elapsedMs);
    final String totalElapsed = millisecondsToHHMMSS(totalElapsedMs);
    return '$elapsed / $totalElapsed';
  }

  @override
  bool get hasBranch {
    final p = _prev;
    if (p == null) return false;
    final n = p._next;
    if (n == null) return false;
    return n._branch != null;
  }

  @override
  bool get isFirstBranch {
    final p = _prev;
    if (p == null) return true;
    return identical(p._next, this);
  }

  @override
  bool get isLastMove {
    if (_next == null) {
      return true;
    }
    _NodeImpl? p = _next;
    while (p != null) {
      if (p.move is Move) {
        return false;
      }
      p = p._branch;
    }
    return true;
  }

  void _updateTotalElapsedMs() {
    totalElapsedMs = elapsedMs;
    final pp = _prev?._prev;
    if (pp != null) {
      totalElapsedMs += pp.totalElapsedMs;
    }
  }

  @override
  void setElapsedMs(int elapsedMs) {
    this.elapsedMs = elapsedMs;
    _updateTotalElapsedMs();
    _NodeImpl? p = _next;
    final List<_NodeImpl> stack = <_NodeImpl>[];
    while (p != null) {
      p._updateTotalElapsedMs();
      if (p._branch != null) {
        stack.add(p._branch!);
      }
      if (p._next != null) {
        p = p._next;
      } else {
        p = stack.isEmpty ? null : stack.removeLast();
      }
    }
  }

  static _NodeImpl newRootEntry(ImmutablePosition position) {
    return _NodeImpl(
      ply: 0,
      prev: null,
      branchIndex: 0,
      activeBranch: true,
      nextColor: position.color,
      move: specialMove(SpecialMoveType.start),
      isCheck: false,
      displayText: '開始局面',
      sfen: position.sfen,
    );
  }
}

void _copyNodeMetadata(ImmutableNode source, Node target) {
  target.comment = source.comment;
  target.bookmark = source.bookmark;
  target.customData = source.customData;
  target.setElapsedMs(source.elapsedMs);
}

/// USI 形式出力時のオプション
class USIFormatOptions {
  const USIFormatOptions({
    this.startpos,
    this.resign,
    this.repDraw,
    this.draw,
    this.timeout,
    this.breakSpecial,
    this.win,
    this.allMoves,
  });

  /// 平手の場合に "startpos" を使用するかを指定します。デフォルトは true です。
  final bool? startpos;

  /// 投了 "resign" を出力に含めるかどうかを表します。デフォルトは false です。
  final bool? resign;

  /// 千日手 "rep_draw" を出力に含めるかどうかを表します。デフォルトは false です。
  final bool? repDraw;

  /// 引き分け "draw" を出力に含めるかどうかを表します。デフォルトは false です。
  final bool? draw;

  /// 時間切れ "timeout" を出力に含めるかどうかを表します。デフォルトは false です。
  final bool? timeout;

  /// 中断 "break" を出力に含めるかどうかを表します。デフォルトは false です。
  /// (TS の `break` キーを Dart の予約語回避のため `breakSpecial` にリネーム。)
  final bool? breakSpecial;

  /// 宣言勝ち "win" を出力に含めるかどうかを表します。デフォルトは false です。
  final bool? win;

  /// 全ての指し手を含めるかどうかを指定します。
  /// false の場合は現在の局面までの指し手のみが含まれます。デフォルトは false です。
  final bool? allMoves;
}

/// `mergeIntoCurrentPosition` の戻り値
class MergeResult {
  const MergeResult({required this.successCount, required this.skipCount});
  final int successCount;
  final int skipCount;
}

/// 棋譜(読み取り専用)
abstract interface class ImmutableRecord {
  ImmutableRecordMetadata get metadata;
  ImmutablePosition get initialPosition;
  ImmutablePosition get position;
  ImmutableNode get first;
  ImmutableNode get current;
  List<ImmutableNode> get moves;
  List<ImmutableNode> get movesBefore;
  int get length;
  ImmutableNode get branchBegin;
  bool get repetition;
  int getRepetitionCount(ImmutablePosition position);
  Color? get perpetualCheck;
  String get usi;
  String getUSI([USIFormatOptions? opts]);
  String get sfen;
  ({String usen, int branchIndex}) get usen;
  List<String> get bookmarks;
  void forEach(void Function(ImmutableNode node) handler);
  Record getSubtree();
}

/// 棋譜
class Record implements ImmutableRecord {
  Record({ImmutablePosition? position})
      : _metadata = RecordMetadata(),
        _initialPosition = position != null ? position.clone() : Position() {
    _position = _initialPosition.clone();
    _first = _NodeImpl.newRootEntry(_initialPosition);
    _current = _first;
  }

  RecordMetadata _metadata;
  ImmutablePosition _initialPosition;
  late Position _position;
  late _NodeImpl _first;
  late _NodeImpl _current;

  // Event controllers (broadcast for multiple subscribers).
  final StreamController<void> _onChangePositionCtrl =
      StreamController<void>.broadcast();
  final StreamController<ImmutablePosition> _onClearCtrl =
      StreamController<ImmutablePosition>.broadcast();
  final StreamController<ImmutableNode> _onAddNodeCtrl =
      StreamController<ImmutableNode>.broadcast();
  final StreamController<ImmutableNode> _onRemoveNodeCtrl =
      StreamController<ImmutableNode>.broadcast();

  /// 位置変更イベント
  Stream<void> get onChangePositionEvents => _onChangePositionCtrl.stream;
  Stream<ImmutablePosition> get onClearEvents => _onClearCtrl.stream;
  Stream<ImmutableNode> get onAddNodeEvents => _onAddNodeCtrl.stream;
  Stream<ImmutableNode> get onRemoveNodeEvents => _onRemoveNodeCtrl.stream;

  /// TS互換のイベント購読 API。
  /// "changePosition" / "clear" / "addNode" / "removeNode"
  StreamSubscription<dynamic> on(String event, Function handler) {
    switch (event) {
      case 'changePosition':
        return _onChangePositionCtrl.stream
            .listen((_) => (handler as void Function())());
      case 'clear':
        return _onClearCtrl.stream.listen(
          (ImmutablePosition pos) =>
              (handler as void Function(ImmutablePosition))(pos),
        );
      case 'addNode':
        return _onAddNodeCtrl.stream.listen(
          (ImmutableNode node) =>
              (handler as void Function(ImmutableNode))(node),
        );
      case 'removeNode':
        return _onRemoveNodeCtrl.stream.listen(
          (ImmutableNode node) =>
              (handler as void Function(ImmutableNode))(node),
        );
      default:
        throw ArgumentError('Unknown event: $event');
    }
  }

  /// StreamController を閉じます。
  Future<void> dispose() async {
    await _onChangePositionCtrl.close();
    await _onClearCtrl.close();
    await _onAddNodeCtrl.close();
    await _onRemoveNodeCtrl.close();
  }

  @override
  RecordMetadata get metadata => _metadata;

  @override
  ImmutablePosition get initialPosition => _initialPosition;

  @override
  ImmutablePosition get position => _position;

  @override
  Node get first => _first;

  @override
  Node get current => _current;

  @override
  List<Node> get moves {
    final List<_NodeImpl> result = _movesBefore;
    _NodeImpl? p = _current._next;
    while (p != null) {
      while (!p!.activeBranch) {
        p = p._branch;
      }
      result.add(p);
      p = p._next;
    }
    return result;
  }

  @override
  List<Node> get movesBefore => _movesBefore;

  List<_NodeImpl> get _movesBefore {
    final List<_NodeImpl> result = <_NodeImpl>[];
    result.insert(0, _current);
    _NodeImpl? p = _current._prev;
    while (p != null) {
      result.insert(0, p);
      p = p._prev;
    }
    return result;
  }

  @override
  int get length {
    int len = _current.ply;
    _NodeImpl? p = _current._next;
    while (p != null) {
      while (!p!.activeBranch) {
        p = p._branch;
      }
      len = p.ply;
      p = p._next;
    }
    return len;
  }

  @override
  Node get branchBegin {
    final prev = _current._prev;
    if (prev == null) return _current;
    return prev._next ?? _current;
  }

  /// 指定した局面で棋譜を初期化します。
  void clear({ImmutablePosition? position}) {
    _metadata = RecordMetadata();
    if (position != null) {
      _initialPosition = position.clone();
    }
    _position = _initialPosition.clone();
    _first = _NodeImpl.newRootEntry(_initialPosition);
    _current = _first;
    _onClearCtrl.add(_initialPosition);
    _onChangePositionCtrl.add(null);
  }

  /// 1手前に戻ります。
  bool goBack() {
    if (_goBack()) {
      _onChangePositionCtrl.add(null);
      return true;
    }
    return false;
  }

  bool _goBack() {
    final prev = _current._prev;
    if (prev != null) {
      final mv = _current.move;
      if (mv is Move) {
        _position.undoMove(mv);
      }
      _current = prev;
      return true;
    }
    return false;
  }

  /// 1手先に進みます。
  bool goForward() {
    if (_goForward()) {
      _onChangePositionCtrl.add(null);
      return true;
    }
    return false;
  }

  bool _goForward() {
    final next = _current._next;
    if (next != null) {
      _current = next;
      while (!_current.activeBranch) {
        _current = _current._branch!;
      }
      final mv = _current.move;
      if (mv is Move) {
        _position.doMove(mv, ignoreValidation: true);
      }
      return true;
    }
    return false;
  }

  /// アクティブな経路上で指定した手数まで移動します。
  void goto(int ply) {
    final int orgPly = _current.ply;
    _goto(ply);
    if (orgPly != _current.ply) {
      _onChangePositionCtrl.add(null);
    }
  }

  /// 指定したノードへ移動します。
  bool gotoNode(ImmutableNode node) {
    final List<ImmutableNode> variation = <ImmutableNode>[];
    ImmutableNode firstNode = node;
    ImmutableNode? p = node;
    while (p != null && p.prev != null) {
      variation.insert(0, p);
      firstNode = p.prev!;
      p = p.prev;
    }
    if (!identical(_first, firstNode)) {
      return false;
    }
    final _NodeImpl orgNode = _current;
    _goto(0);
    for (final ImmutableNode pv in variation) {
      _goForward();
      _switchBranchByIndex(pv.branchIndex);
    }
    if (!identical(orgNode, _current)) {
      _onChangePositionCtrl.add(null);
    }
    return true;
  }

  void _goto(int ply) {
    while (ply < _current.ply) {
      if (!_goBack()) {
        break;
      }
    }
    while (ply > _current.ply) {
      if (!_goForward()) {
        break;
      }
    }
  }

  /// 全ての分岐選択を初期化して最初のノードをアクティブにします。
  void resetAllBranchSelection() {
    _NodeImpl confluence = _current;
    _NodeImpl? node = _current;
    while (node != null && node._prev != null) {
      if (!node.isFirstBranch) {
        confluence = node._prev!;
      }
      node = node._prev;
    }
    _forEach((n) {
      n.activeBranch = n.isFirstBranch;
    });
    if (!identical(_current, confluence)) {
      while (!identical(_current, confluence)) {
        _goBack();
      }
      _onChangePositionCtrl.add(null);
    }
  }

  /// インデクスを指定して兄弟ノードを選択します。
  bool switchBranchByIndex(int index) {
    if (_current.branchIndex == index) {
      return true;
    }
    if (!_switchBranchByIndex(index)) {
      return false;
    }
    _onChangePositionCtrl.add(null);
    return true;
  }

  bool _switchBranchByIndex(int index) {
    if (_current.branchIndex == index) {
      return true;
    }
    final prev = _current._prev;
    if (prev == null) {
      return false;
    }
    bool ok = false;
    _NodeImpl? p = prev._next;
    while (p != null) {
      if (p.branchIndex == index) {
        p.activeBranch = true;
        final cur = _current;
        final mv = cur.move;
        if (mv is Move) {
          _position.undoMove(mv);
        }
        _current = p;
        final newMv = _current.move;
        if (newMv is Move) {
          _position.doMove(newMv, ignoreValidation: true);
        }
        ok = true;
      } else {
        p.activeBranch = false;
      }
      p = p._branch;
    }
    if (!ok) {
      _current.activeBranch = true;
    }
    return ok;
  }

  /// 指し手を追加して 1 手先に進みます。
  /// [move] は [Move] / [SpecialMove] / [SpecialMoveType] のいずれかを受け付けます。
  bool append(Object move, {bool ignoreValidation = false}) {
    if (_append(move, ignoreValidation: ignoreValidation)) {
      _onChangePositionCtrl.add(null);
      return true;
    }
    return false;
  }

  bool _append(Object move, {bool ignoreValidation = false}) {
    // SpecialMoveType を SpecialMove へ変換。
    final Object actualMove =
        move is SpecialMoveType ? specialMove(move) : move;

    // 表示用テキスト (簡易版: KIF formatter は Phase 4)。
    final String displayText = _formatDisplayText(actualMove);

    // 局面を動かす。
    bool isCheck = false;
    if (actualMove is Move) {
      if (!_position.doMove(actualMove, ignoreValidation: ignoreValidation)) {
        return false;
      }
      isCheck = _position.checked;
    }

    // 特殊な指し手のノードの場合は前のノードに戻る。
    if (!identical(_current, _first) && _current.move is! Move) {
      _goBack();
    }

    // 最終ノードの場合は単に新しいノードを追加する。
    if (_current._next == null) {
      final _NodeImpl newNode = _NodeImpl(
        ply: _current.ply + 1,
        prev: _current,
        branchIndex: 0,
        activeBranch: true,
        nextColor: _position.color,
        move: actualMove,
        isCheck: isCheck,
        displayText: displayText,
        sfen: _position.sfen,
      );
      _current._next = newNode;
      _current = newNode;
      _current.setElapsedMs(0);
      _onAddNodeCtrl.add(_current);
      return true;
    }

    // 既存の兄弟ノードから選択を解除する。
    {
      _NodeImpl? p = _current._next;
      while (p != null) {
        p.activeBranch = false;
        p = p._branch;
      }
    }

    // 同じ指し手が既に存在する場合はそのノードへ移動して終わる。
    _NodeImpl lastBranch = _current._next!;
    {
      _NodeImpl? p = _current._next;
      while (p != null) {
        if (areSameMoves(actualMove, p.move)) {
          _current = p;
          _current.activeBranch = true;
          return true;
        }
        lastBranch = p;
        p = p._branch;
      }
    }

    // 兄弟ノードを追加する。
    final _NodeImpl branchNode = _NodeImpl(
      ply: _current.ply + 1,
      prev: _current,
      branchIndex: lastBranch.branchIndex + 1,
      activeBranch: true,
      nextColor: _position.color,
      move: actualMove,
      isCheck: isCheck,
      displayText: displayText,
      sfen: _position.sfen,
    );
    branchNode.setElapsedMs(0);
    lastBranch._branch = branchNode;
    _current = branchNode;
    _onAddNodeCtrl.add(_current);
    return true;
  }

  String _formatDisplayText(Object move) {
    if (move is Move) {
      return move.usi;
    }
    if (move is SpecialMove) {
      if (move is PredefinedSpecialMove) {
        return move.type.value;
      }
      if (move is AnySpecialMove) {
        return move.name;
      }
    }
    return '';
  }

  /// 次の兄弟ノードと順序を入れ替えます。
  bool swapWithNextBranch() {
    final branch = _current._branch;
    if (branch == null) return false;
    return _swapWithPreviousBranch(branch);
  }

  /// 前の兄弟ノードと順序を入れ替えます。
  bool swapWithPreviousBranch() {
    return _swapWithPreviousBranch(_current);
  }

  static bool _swapWithPreviousBranch(_NodeImpl target) {
    final prev = target._prev;
    if (prev == null || prev._next == null || identical(prev._next, target)) {
      return false;
    }
    if (identical(prev._next!._branch, target)) {
      final _NodeImpl pair = prev._next!;
      pair._branch = target._branch;
      target._branch = pair;
      prev._next = target;
      final int tmp = target.branchIndex;
      target.branchIndex = pair.branchIndex;
      pair.branchIndex = tmp;
      return true;
    }
    _NodeImpl p = prev._next!;
    while (p._branch != null) {
      if (identical(p._branch!._branch, target)) {
        final _NodeImpl pair = p._branch!;
        pair._branch = target._branch;
        target._branch = pair;
        p._branch = target;
        final int tmp = target.branchIndex;
        target.branchIndex = pair.branchIndex;
        pair.branchIndex = tmp;
        return true;
      }
      p = p._branch!;
    }
    return false;
  }

  /// 現在の指し手を削除します。
  bool removeCurrentMove() {
    final _NodeImpl target = _current;
    if (!goBack()) {
      return removeNextMove();
    }
    _onRemoveSubTree(target);
    if (identical(_current._next, target)) {
      _current._next = target._branch;
    } else {
      _NodeImpl? p = _current._next;
      while (p != null) {
        if (identical(p._branch, target)) {
          p._branch = target._branch;
          break;
        }
        p = p._branch;
      }
    }
    int branchIndex = 0;
    {
      _NodeImpl? p = _current._next;
      while (p != null) {
        p.branchIndex = branchIndex;
        branchIndex += 1;
        p = p._branch;
      }
    }
    if (_current._next != null) {
      _current._next!.activeBranch = true;
    }
    _onChangePositionCtrl.add(null);
    return true;
  }

  /// 後続の手を全て削除します。
  bool removeNextMove() {
    if (_current._next != null) {
      _NodeImpl? p = _current._next;
      while (p != null) {
        _onRemoveSubTree(p);
        p = p._branch;
      }
      _current._next = null;
      return true;
    }
    return false;
  }

  void _onRemoveSubTree(_NodeImpl root) {
    _NodeImpl p = root;
    while (true) {
      if (p._next != null) {
        p = p._next!;
        continue;
      }
      _onRemoveNodeCtrl.add(p);
      if (identical(p, root)) {
        return;
      }
      while (p._branch == null) {
        if (p._prev == null) {
          return;
        }
        p = p._prev!;
        _onRemoveNodeCtrl.add(p);
        if (identical(p, root)) {
          return;
        }
      }
      p = p._branch!;
    }
  }

  /// 棋譜をマージします。経過時間/コメント/しおりは自分の側を優先します。
  /// 初期局面が異なる場合はマージできません。
  bool merge(ImmutableRecord record) {
    if (_initialPosition.sfen != record.initialPosition.sfen) {
      return false;
    }
    final List<_NodeImpl> path = _movesBefore;
    _goto(0);
    mergeIntoCurrentPosition(record);
    for (int i = 1; i < path.length; i++) {
      _append(path[i].move, ignoreValidation: true);
    }
    return true;
  }

  /// 棋譜を現在の局面からのサブツリーとしてマージします。
  MergeResult mergeIntoCurrentPosition(
    ImmutableRecord record, {
    bool ignoreValidation = false,
  }) {
    final int begin = _current.ply;
    int? errorPly;
    int successCount = 0;
    int skipCount = 0;
    record.forEach((node) {
      if (node.ply == 0) {
        return;
      }
      final int ply = begin + node.ply - 1;
      if (errorPly != null && ply > errorPly!) {
        skipCount++;
        return;
      }
      _goto(ply);
      if (!_append(node.move, ignoreValidation: ignoreValidation)) {
        errorPly = ply;
        skipCount++;
        return;
      }
      errorPly = null;
      successCount++;
      if (node.elapsedMs != 0 && current.elapsedMs == 0) {
        current.setElapsedMs(node.elapsedMs);
      }
      if (node.comment.isNotEmpty && current.comment.isEmpty) {
        current.comment = node.comment;
      }
      if (node.bookmark.isNotEmpty && current.bookmark.isEmpty) {
        current.bookmark = node.bookmark;
      }
      if (node.customData != null && current.customData == null) {
        current.customData = node.customData;
      }
    });
    _goto(begin);
    return MergeResult(successCount: successCount, skipCount: skipCount);
  }

  /// 指定したしおりがある局面まで移動します。
  bool jumpToBookmark(String bookmark) {
    if (_current.bookmark == bookmark) {
      return true;
    }
    final _NodeImpl? node = _find((n) => n.bookmark == bookmark);
    if (node == null) {
      return false;
    }
    // 経路を ply -> node のマップで持つ。
    final Map<int, _NodeImpl> route = <int, _NodeImpl>{};
    _NodeImpl? p = node;
    int maxPly = node.ply;
    while (p != null) {
      route[p.ply] = p;
      if (p.ply > maxPly) maxPly = p.ply;
      p = p._prev;
    }
    while (!identical(_current, route[_current.ply])) {
      goBack();
    }
    while (route.length > _current.ply + 1 ||
        route.containsKey(_current.ply + 1)) {
      final _NodeImpl? next = route[_current.ply + 1];
      if (next == null) break;
      append(next.move);
    }
    _onChangePositionCtrl.add(null);
    return true;
  }

  @override
  bool get repetition => false; // PHASE3

  @override
  int getRepetitionCount(ImmutablePosition position) => 0; // PHASE3

  @override
  Color? get perpetualCheck => null; // PHASE3

  @override
  String get usi => getUSI();

  @override
  String getUSI([USIFormatOptions? opts]) {
    final String sfen = _initialPosition.sfen;
    final bool useStartpos =
        opts?.startpos != false && sfen == InitialPositionSFEN.standard.value;
    final String position =
        'position ${useStartpos ? 'startpos' : 'sfen ${_initialPosition.sfen}'}';
    final List<String> moves = <String>[];
    _NodeImpl p = _first;
    while (true) {
      while (!p.activeBranch) {
        p = p._branch!;
      }
      final mv = p.move;
      if (mv is Move) {
        moves.add(mv.usi);
      } else if (mv is PredefinedSpecialMove) {
        if (opts?.resign == true && mv.type == SpecialMoveType.resign) {
          moves.add('resign');
        } else if (opts?.repDraw == true &&
            mv.type == SpecialMoveType.repetitionDraw) {
          moves.add('rep_draw');
        } else if (opts?.draw == true && mv.type == SpecialMoveType.draw) {
          moves.add('draw');
        } else if (opts?.timeout == true &&
            mv.type == SpecialMoveType.timeout) {
          moves.add('timeout');
        } else if (opts?.breakSpecial == true &&
            mv.type == SpecialMoveType.interrupt) {
          moves.add('break');
        } else if (opts?.win == true &&
            mv.type == SpecialMoveType.enteringOfKing) {
          moves.add('win');
        }
      }
      if (p._next == null ||
          (opts?.allMoves != true && identical(p, _current))) {
        break;
      }
      p = p._next!;
    }
    if (moves.isEmpty) {
      return position;
    }
    return '$position moves ${moves.join(' ')}';
  }

  @override
  String get sfen => _position.getSFEN(_current.ply + 1);

  @override
  ({String usen, int branchIndex}) get usen {
    final String sfen0 = _initialPosition.sfen;
    String usen = sfen0 == InitialPositionSFEN.standard.value
        ? ''
        : sfen0
            .replaceFirst(RegExp(r' 1$'), '')
            .replaceAll('/', '_')
            .replaceAll(' ', '.')
            .replaceAll('+', 'z');
    String moves = '0.';
    String special = '';
    int lastPly = 0;
    int bi = 0;
    int branchIndex = 0;
    forEach((node) {
      if (node.ply == 0) {
        return;
      }
      final Object mv = node.move;
      if (lastPly + 1 != node.ply) {
        usen += '~$moves.$special';
        moves = '${node.ply - 1}.';
        bi++;
      }
      if (identical(_current, node)) {
        branchIndex = bi;
      }
      if (mv is! Move) {
        if (mv is PredefinedSpecialMove) {
          switch (mv.type) {
            case SpecialMoveType.resign:
              special = 'r';
              break;
            case SpecialMoveType.timeout:
              special = 't';
              break;
            case SpecialMoveType.maxMoves:
            case SpecialMoveType.impass:
            case SpecialMoveType.draw:
              special = 'j';
              break;
            default:
              special = 'p';
              break;
          }
        } else {
          special = 'p';
        }
        return;
      }
      final int from;
      final MoveOrigin origin = mv.from;
      if (origin is FromSquare) {
        from = (origin.square.rank - 1) * 9 + (origin.square.file - 1);
      } else if (origin is FromHand) {
        from = _usenHandTable[origin.pieceType]!;
      } else {
        return;
      }
      final int to = (mv.to.rank - 1) * 9 + (mv.to.file - 1);
      final int m = (from * 81 + to) * 2 + (mv.promote ? 1 : 0);
      moves += m.toRadixString(36).padLeft(3, '0');
      lastPly = node.ply;
    });
    usen += '~$moves.$special';
    return (usen: usen, branchIndex: branchIndex);
  }

  @override
  List<String> get bookmarks {
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    forEach((node) {
      if (node.bookmark.isNotEmpty && !seen.contains(node.bookmark)) {
        result.add(node.bookmark);
        seen.add(node.bookmark);
      }
    });
    return result;
  }

  @override
  void forEach(void Function(ImmutableNode node) handler) {
    _forEach((node) => handler(node));
  }

  void _forEach(void Function(_NodeImpl node) handler) {
    _find((node) {
      handler(node);
      return false;
    });
  }

  _NodeImpl? _find(bool Function(_NodeImpl node) handler) {
    _NodeImpl p = _first;
    while (true) {
      if (handler(p)) {
        return p;
      }
      if (p._next != null) {
        p = p._next!;
        continue;
      }
      while (p._branch == null) {
        if (p._prev == null) {
          return null;
        }
        p = p._prev!;
      }
      p = p._branch!;
    }
  }

  @override
  Record getSubtree() {
    final Record subtree = Record(position: _position);

    // メタデータをコピー
    for (final RecordMetadataKey key in RecordMetadataKey.values) {
      final String? value = _metadata.getStandardMetadata(key);
      if (value != null) {
        subtree._metadata.setStandardMetadata(key, value);
      }
    }
    for (final String key in _metadata.customMetadataKeys) {
      final String? value = _metadata.getCustomMetadata(key);
      if (value != null) {
        subtree._metadata.setCustomMetadata(key, value);
      }
    }

    // ノードをコピー
    _NodeImpl p = _current;
    _copyNodeMetadata(p, subtree.current);
    if (p._next == null) {
      return subtree;
    }
    p = p._next!;
    while (true) {
      subtree.append(p.move, ignoreValidation: true);
      _copyNodeMetadata(p, subtree.current);
      if (p._next != null) {
        p = p._next!;
        continue;
      }
      while (p._branch == null) {
        if (p._prev == null || identical(p._prev, _current)) {
          subtree.goto(0);
          return subtree;
        }
        subtree.goBack();
        p = p._prev!;
      }
      subtree.goBack();
      p = p._branch!;
    }
  }

  /// USI 形式の文字列から棋譜を読み込みます。失敗時は null を返します。
  static Record? newByUSI(String data) {
    final result = _newByUSI(data);
    return result is Record ? result : null;
  }

  /// USI 形式の文字列から棋譜を読み込みます。失敗時は Exception を返します。
  static Object newByUSIOrError(String data) {
    return _newByUSI(data);
  }

  static Object _newByUSI(String data) {
    const String positionStartpos = 'position startpos';
    const String startpos = 'startpos';
    const String prefixPositionStartpos = 'position startpos ';
    const String prefixPositionSFEN = 'position sfen ';
    const String prefixStartpos = 'startpos ';
    const String prefixSFEN = 'sfen ';
    const String prefixMoves = 'moves ';
    if (data == positionStartpos || data == startpos) {
      return Record();
    } else if (data.startsWith(prefixPositionStartpos)) {
      return _newByUSIFromMoves(data.substring(prefixPositionStartpos.length));
    } else if (data.startsWith(prefixPositionSFEN)) {
      return _newByUSIFromSFEN(data.substring(prefixPositionSFEN.length));
    } else if (data.startsWith(prefixStartpos)) {
      return _newByUSIFromMoves(data.substring(prefixStartpos.length));
    } else if (data.startsWith(prefixSFEN)) {
      return _newByUSIFromSFEN(data.substring(prefixSFEN.length));
    } else if (data.startsWith(prefixMoves)) {
      return _newByUSIFromMoves(data);
    } else {
      return InvalidUSIError(data);
    }
  }

  static Object _newByUSIFromSFEN(String data) {
    final List<String> sections = data.split(' ');
    if (sections.length < 3) {
      return InvalidUSIError(data);
    }
    final int movesIndex =
        sections.length == 3 || sections[3] == 'moves' ? 3 : 4;
    final Position? position =
        Position.newBySFEN(sections.sublist(0, movesIndex).join(' '));
    if (position == null) {
      return InvalidUSIError(data);
    }
    return _newByUSIFromMoves(
      sections.sublist(movesIndex).join(' '),
      position: position,
    );
  }

  static Object _newByUSIFromMoves(String data, {ImmutablePosition? position}) {
    final Record record = Record(position: position);
    if (data.isEmpty) {
      return record;
    }
    final List<String> sections = data.split(' ');
    if (sections[0] != 'moves') {
      return InvalidUSIError(data);
    }
    for (int i = 1; i < sections.length; i++) {
      final String token = sections[i];
      if (token == 'resign') {
        record.append(SpecialMoveType.resign);
        break;
      } else if (token == 'rep_draw') {
        record.append(SpecialMoveType.repetitionDraw);
        break;
      } else if (token == 'draw') {
        record.append(SpecialMoveType.draw);
        break;
      } else if (token == 'timeout') {
        record.append(SpecialMoveType.timeout);
        break;
      } else if (token == 'break') {
        record.append(SpecialMoveType.interrupt);
        break;
      } else if (token == 'win') {
        record.append(SpecialMoveType.enteringOfKing);
        break;
      }
      final parsed = parseUSIMove(token);
      if (parsed == null) {
        break;
      }
      Move? move = record._position.createMove(parsed.from, parsed.to);
      if (move == null) {
        return InvalidMoveError(token);
      }
      if (parsed.promote) {
        move = move.withPromote();
      }
      record.append(move, ignoreValidation: true);
    }
    return record;
  }

  /// USEN (Url Safe sfen-Extended Notation) 形式から棋譜を読み込みます。
  /// 失敗時は null を返します。
  static Record? newByUSEN(String usen, {int branchIndex = 0, int ply = 0}) {
    final result = _newByUSEN(usen, branchIndex: branchIndex, ply: ply);
    return result is Record ? result : null;
  }

  static Object _newByUSEN(String usen, {int branchIndex = 0, int ply = 0}) {
    final List<String> sections = usen.split('~');
    if (sections.length < 2) {
      return Exception('USEN must have at least 2 sections.');
    }
    final String sfen = sections[0]
        .replaceAll('_', '/')
        .replaceAll('.', ' ')
        .replaceAll('z', '+');
    final Position? position =
        sfen.isEmpty ? Position() : Position.newBySFEN('$sfen 1');
    if (position == null) {
      return Exception('Invalid SFEN in USEN.');
    }
    final Record record = Record(position: position);
    _NodeImpl activeNode = record._first;
    final RegExp digits = RegExp(r'[0-9]+');
    for (int si = 1; si < sections.length; si++) {
      final List<String> parts = sections[si].split('.');
      if (parts.length < 3) {
        return Exception('Invalid USEN section.');
      }
      final String n = parts[0];
      final String moves = parts[1];
      final String special = parts[2];
      if (!digits.hasMatch(n)) {
        return Exception('Invalid USEN ply format.');
      }
      record.goto(int.parse(n));
      for (int i = 0; i < moves.length; i += 3) {
        final int m = int.parse(moves.substring(i, i + 3), radix: 36);
        final int f = m ~/ 162;
        final MoveOrigin from;
        if (f < 81) {
          from = FromSquare(Square((f % 9) + 1, (f ~/ 9) + 1));
        } else {
          final PieceType? pt = _usenHandReverseTable[f];
          if (pt == null) {
            return Exception('Invalid USEN hand encoding.');
          }
          from = FromHand(pt);
        }
        final int t = (m % 162) ~/ 2;
        final Square to = Square((t % 9) + 1, (t ~/ 9) + 1);
        final bool promote = m % 2 == 1;
        Move? move = record._position.createMove(from, to);
        if (move == null) {
          return Exception('Invalid move in USEN.');
        }
        if (promote) {
          move = move.withPromote();
        }
        record.append(move, ignoreValidation: true);
        if (si - 1 == branchIndex && record._current.ply == ply) {
          activeNode = record._current;
        }
      }
      if (special == 'r') {
        record.append(specialMove(SpecialMoveType.resign));
      } else if (special == 't') {
        record.append(specialMove(SpecialMoveType.timeout));
      } else if (special == 'j') {
        record.append(specialMove(SpecialMoveType.impass));
      } else if (special == 'p') {
        record.append(specialMove(SpecialMoveType.interrupt));
      }
      if (si - 1 == branchIndex && record._current.ply == ply) {
        activeNode = record._current;
      }
    }
    if (identical(activeNode, record._first)) {
      record.goto(0);
    } else {
      final Map<int, _NodeImpl> route = <int, _NodeImpl>{};
      _NodeImpl? p = activeNode;
      while (p != null) {
        route[p.ply] = p;
        p = p._prev;
      }
      while (!identical(record._current, route[record._current.ply])) {
        record.goBack();
      }
      while (route.containsKey(record._current.ply + 1)) {
        final _NodeImpl? nxt = route[record._current.ply + 1];
        if (nxt == null) break;
        record.append(nxt.move);
      }
    }
    return record;
  }
}

/// USI 形式の文字列から次の手番を取得します。
Color getNextColorFromUSI(String usi) {
  final List<String> sections = usi.trim().split(' ');
  final Color baseColor;
  if (sections.length > 1 && sections[1] == 'startpos') {
    baseColor = Color.black;
  } else if (sections.length > 3 && sections[3] == 'b') {
    baseColor = Color.black;
  } else {
    baseColor = Color.white;
  }
  final int firstMoveIndex;
  if (sections.length > 1 && sections[1] == 'startpos') {
    firstMoveIndex = sections.length > 2 && sections[2] == 'moves' ? 3 : 2;
  } else {
    firstMoveIndex = sections.length > 6 && sections[6] == 'moves' ? 7 : 6;
  }
  return (sections.length - firstMoveIndex) % 2 == 0
      ? baseColor
      : reverseColor(baseColor);
}
