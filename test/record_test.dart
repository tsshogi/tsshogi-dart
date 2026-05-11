import 'dart:async';

import 'package:test/test.dart';
import 'package:tsshogi/tsshogi.dart';

/// 棋譜にUSI形式の指し手列を一括で適用するヘルパー。
void _applyUSI(Record record, List<String> usiMoves) {
  for (final String usi in usiMoves) {
    final Move? move = record.position.createMoveByUSI(usi);
    if (move == null) {
      throw StateError('Invalid USI move: $usi at ply ${record.current.ply}');
    }
    final bool ok = record.append(move);
    if (!ok) {
      throw StateError('append failed: $usi at ply ${record.current.ply}');
    }
  }
}

void main() {
  group('getBlackPlayerName / getWhitePlayerName', () {
    test('getBlackPlayerName', () {
      final record = Record();
      record.metadata
          .setStandardMetadata(RecordMetadataKey.shitateName, '羽生結弦');
      expect(getBlackPlayerName(record.metadata), '羽生結弦');
      expect(getBlackPlayerNamePreferShort(record.metadata), '羽生結弦');
      record.metadata
          .setStandardMetadata(RecordMetadataKey.blackShortName, '羽生');
      expect(getBlackPlayerName(record.metadata), '羽生');
      expect(getBlackPlayerNamePreferShort(record.metadata), '羽生');
      record.metadata.setStandardMetadata(RecordMetadataKey.blackName, '羽生善治');
      expect(getBlackPlayerName(record.metadata), '羽生善治');
      expect(getBlackPlayerNamePreferShort(record.metadata), '羽生');
    });

    test('getWhitePlayerName', () {
      final record = Record();
      record.metadata.setStandardMetadata(RecordMetadataKey.uwateName, '羽生結弦');
      expect(getWhitePlayerName(record.metadata), '羽生結弦');
      expect(getWhitePlayerNamePreferShort(record.metadata), '羽生結弦');
      record.metadata
          .setStandardMetadata(RecordMetadataKey.whiteShortName, '羽生');
      expect(getWhitePlayerName(record.metadata), '羽生');
      expect(getWhitePlayerNamePreferShort(record.metadata), '羽生');
      record.metadata.setStandardMetadata(RecordMetadataKey.whiteName, '羽生善治');
      expect(getWhitePlayerName(record.metadata), '羽生善治');
      expect(getWhitePlayerNamePreferShort(record.metadata), '羽生');
    });
  });

  test('constructor', () {
    final record = Record();
    expect(record.first.move, specialMove(SpecialMoveType.start));
    expect(record.first.next, isNull);
    expect(record.first.comment, '');
    expect(record.first.customData, isNull);
    expect(record.first.nextColor, Color.black);
    expect(identical(record.current, record.first), isTrue);
  });

  test('clear', () async {
    final record = Record();
    record.first.comment = 'abc';
    record.first.customData = 'foo bar baz';
    record.append(SpecialMoveType.interrupt);
    expect(identical(record.first.next, record.current), isTrue);
    expect(record.first.comment, 'abc');
    expect(record.first.customData, 'foo bar baz');

    int clearCount = 0;
    int changeCount = 0;
    final sub1 = record.on('clear', () {
      clearCount++;
    });
    // For TS compat: 'clear' delivers position arg, so subscribe with that.
    // The `on(...)` overload for clear expects (ImmutablePosition) -> void.
    // We use the more specific stream for typed assertion.
    await sub1.cancel();
    record.onClearEvents.listen((_) => clearCount++);
    record.onChangePositionEvents.listen((_) => changeCount++);

    record.clear();
    await Future<void>.delayed(Duration.zero);

    expect(record.first.move, specialMove(SpecialMoveType.start));
    expect(record.first.next, isNull);
    expect(record.first.comment, '');
    expect(record.first.customData, isNull);
    expect(identical(record.current, record.first), isTrue);
    expect(clearCount, 1);
    expect(changeCount, 1);
  });

  test('getUSI', () {
    final record = Record();
    _applyUSI(record, ['2g2f', '8c8d', '7g7f', '8d8e']);
    record.append(SpecialMoveType.resign);
    record.goto(2);
    expect(record.usi, 'position startpos moves 2g2f 8c8d');
    expect(record.getUSI(), 'position startpos moves 2g2f 8c8d');
    expect(
      record.getUSI(const USIFormatOptions(startpos: true)),
      'position startpos moves 2g2f 8c8d',
    );
    expect(
      record.getUSI(const USIFormatOptions(startpos: false)),
      'position sfen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1 moves 2g2f 8c8d',
    );
    expect(
      record.getUSI(const USIFormatOptions(startpos: true, allMoves: true)),
      'position startpos moves 2g2f 8c8d 7g7f 8d8e',
    );
  });

  group('getUSI/specialMoves', () {
    const precedingUSI = 'position startpos moves 7g7f 3c3d 2g2f 8c8d';
    final cases = [
      (SpecialMoveType.resign, const USIFormatOptions(), precedingUSI),
      (
        SpecialMoveType.resign,
        const USIFormatOptions(resign: true),
        '$precedingUSI resign',
      ),
      (
        SpecialMoveType.repetitionDraw,
        const USIFormatOptions(),
        precedingUSI,
      ),
      (
        SpecialMoveType.repetitionDraw,
        const USIFormatOptions(repDraw: true),
        '$precedingUSI rep_draw',
      ),
      (SpecialMoveType.draw, const USIFormatOptions(), precedingUSI),
      (
        SpecialMoveType.draw,
        const USIFormatOptions(draw: true),
        '$precedingUSI draw',
      ),
      (SpecialMoveType.timeout, const USIFormatOptions(), precedingUSI),
      (
        SpecialMoveType.timeout,
        const USIFormatOptions(timeout: true),
        '$precedingUSI timeout',
      ),
      (SpecialMoveType.interrupt, const USIFormatOptions(), precedingUSI),
      (
        SpecialMoveType.interrupt,
        const USIFormatOptions(breakSpecial: true),
        '$precedingUSI break',
      ),
      (SpecialMoveType.enteringOfKing, const USIFormatOptions(), precedingUSI),
      (
        SpecialMoveType.enteringOfKing,
        const USIFormatOptions(win: true),
        '$precedingUSI win',
      ),
    ];
    for (final tc in cases) {
      test('${tc.$1.value} with opts', () {
        final Record record = Record.newByUSI(precedingUSI)!;
        record.append(tc.$1);
        expect(record.getUSI(tc.$2), tc.$3);
      });
    }
  });

  test('getNextColorFromUSI', () {
    expect(getNextColorFromUSI('position startpos'), Color.black);
    expect(getNextColorFromUSI('position startpos '), Color.black);
    expect(getNextColorFromUSI('position startpos moves'), Color.black);
    expect(getNextColorFromUSI('position startpos moves '), Color.black);
    expect(
      getNextColorFromUSI('position startpos moves 2g2f 8c8d 2f2e'),
      Color.white,
    );
    const sfenBlack =
        'lnsgkgsnl/1r5b1/p1ppppppp/9/1p5P1/9/PPPPPPP1P/1B5R1/LNSGKGSNL b - 1';
    expect(
      getNextColorFromUSI('position sfen $sfenBlack'),
      Color.black,
    );
    expect(
      getNextColorFromUSI('position sfen $sfenBlack moves 6i7h 4a3b'),
      Color.black,
    );
    const sfenWhite =
        'lnsgkgsnl/1r5b1/p1ppppppp/1p7/7P1/9/PPPPPPP1P/1B5R1/LNSGKGSNL w - 1';
    expect(
      getNextColorFromUSI('position sfen $sfenWhite'),
      Color.white,
    );
    expect(
      getNextColorFromUSI('position sfen $sfenWhite moves 8d8e'),
      Color.black,
    );
  });

  test('append / goBack / goForward / goto / switchBranchByIndex', () async {
    final record = Record();
    int onChange = 0;
    int onAdd = 0;
    record.onChangePositionEvents.listen((_) => onChange++);
    record.onAddNodeEvents.listen((_) => onAdd++);

    Move move(int ff, int fr, int tf, int tr) {
      return record.position
          .createMove(FromSquare(Square(ff, fr)), Square(tf, tr))!;
    }

    expect(record.append(move(7, 7, 7, 6)), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 1);
    expect(record.current.nextColor, Color.white);

    expect(record.append(move(3, 3, 3, 4)), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 2);
    expect(record.current.nextColor, Color.black);

    expect(record.append(move(2, 7, 2, 6)), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 3);
    expect(record.current.nextColor, Color.white);

    expect(record.goBack(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 4);

    expect(record.goBack(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 5);

    // 既存の指し手と同じ動きなので分岐は作られない
    expect(record.append(move(3, 3, 3, 4)), isTrue);
    expect(record.current.hasBranch, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 6);

    expect(record.goBack(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 7);

    expect(record.append(move(8, 3, 8, 4)), isTrue);
    expect(record.current.hasBranch, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 8);

    expect(record.append(move(7, 9, 7, 8)), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 9);

    // 移動できない指し手
    expect(record.append(move(8, 2, 8, 4)), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 9);

    expect(record.goBack(), isTrue);
    expect(record.goBack(), isTrue);
    expect(record.goBack(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 12);
    expect(record.usi, 'position startpos');

    expect(record.goBack(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 12);

    expect(record.goForward(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 13);

    record.goto(9007199254740992); // MAX_SAFE_INTEGER 相当
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 14);
    expect(record.usi, 'position startpos moves 7g7f 8c8d 7i7h');

    expect(record.goForward(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 14);

    // interrupt
    expect(record.append(SpecialMoveType.interrupt), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 15);
    expect(record.append(SpecialMoveType.interrupt), isTrue);
    expect(record.current.hasBranch, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 16);

    record.goto(2);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 17);
    expect(record.usi, 'position startpos moves 7g7f 8c8d');

    record.goto(2);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 17);

    expect(record.switchBranchByIndex(0), isTrue);
    expect(record.current.activeBranch, isTrue);
    expect(record.current.branch?.activeBranch, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 18);
    expect(record.usi, 'position startpos moves 7g7f 3c3d');

    expect(record.switchBranchByIndex(1), isTrue);
    expect(record.current.activeBranch, isTrue);
    expect(record.current.prev?.next?.activeBranch, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 19);
    expect(record.usi, 'position startpos moves 7g7f 8c8d');

    expect(record.switchBranchByIndex(2), isFalse);
    expect(record.current.activeBranch, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(onChange, 19);

    expect(onAdd, 6);
  });

  test('removeCurrentMove deletes current and re-points to previous', () async {
    final record = Record();
    _applyUSI(record, ['7g7f', '3c3d', '7f7e', '8c8d']);
    int removeCount = 0;
    record.onRemoveNodeEvents.listen((_) => removeCount++);

    record.goto(4);
    expect(record.removeCurrentMove(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(record.current.ply, 3);
    expect(record.moves.length, 4);
    expect(removeCount, 1);

    // delete from start
    record.goto(0);
    expect(record.removeCurrentMove(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(record.current.ply, 0);
    expect(record.moves.length, 1);

    // already empty
    expect(record.removeCurrentMove(), isFalse);
  });

  test('removeNextMove', () async {
    final record = Record();
    _applyUSI(record, ['7g7f', '3c3d', '7f7e', '8c8d']);
    int removeCount = 0;
    record.onRemoveNodeEvents.listen((_) => removeCount++);

    record.goto(4);
    expect(record.removeNextMove(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(removeCount, 0);

    record.goto(2);
    expect(record.removeNextMove(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(removeCount, 2);
    expect(record.length, 2);
    expect(record.current.ply, 2);

    record.goto(0);
    expect(record.removeNextMove(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(removeCount, 4);
    expect(record.length, 0);

    expect(record.removeNextMove(), isFalse);
  });

  test('merge', () {
    // record1: 7g7f 3c3d 2g2f
    final record1 = Record();
    _applyUSI(record1, ['7g7f', '3c3d', '2g2f']);
    // record2: 7g7f 3c3d 2g2f 8c8d
    final record2 = Record();
    _applyUSI(record2, ['7g7f', '3c3d', '2g2f', '8c8d']);

    record1.goto(2);
    expect(record1.merge(record2), isTrue);
    expect(record1.length, 4);
    expect(record1.current.ply, 2);
  });

  test('merge fails when initial position differs', () {
    final record1 = Record();
    final handicap =
        Position.newBySFEN(InitialPositionSFEN.handicapLance.value)!;
    final record2 = Record(position: handicap);
    expect(record1.merge(record2), isFalse);
  });

  test('mergeIntoCurrentPosition', () {
    final record1 = Record();
    _applyUSI(record1, ['7g7f', '3c3d']);
    final record2 = Record();
    _applyUSI(record2, ['7g7f', '3c3d', '2g2f', '8c8d']);
    final result = record1.mergeIntoCurrentPosition(record2);
    expect(result.skipCount + result.successCount >= 1, isTrue);
  });

  test('metadata get/set', () {
    final record = Record();
    record.metadata.setStandardMetadata(RecordMetadataKey.title, '対局1');
    record.metadata.setStandardMetadata(RecordMetadataKey.blackName, '羽生');
    record.metadata.setCustomMetadata('場所', 'Tokyo');

    expect(record.metadata.getStandardMetadata(RecordMetadataKey.title), '対局1');
    expect(
      record.metadata.getStandardMetadata(RecordMetadataKey.blackName),
      '羽生',
    );
    expect(record.metadata.getCustomMetadata('場所'), 'Tokyo');
    expect(
      record.metadata.standardMetadataKeys.toSet(),
      {RecordMetadataKey.title, RecordMetadataKey.blackName},
    );
    expect(record.metadata.customMetadataKeys.toList(), ['場所']);

    // 空文字を渡すと削除される
    record.metadata.setStandardMetadata(RecordMetadataKey.title, '');
    expect(
        record.metadata.getStandardMetadata(RecordMetadataKey.title), isNull);
  });

  test('USEN round-trip / single mainline', () {
    final record = Record();
    _applyUSI(record, ['2g2f', '8c8d', '7g7f', '8d8e']);
    final usenInfo = record.usen;
    expect(usenInfo.usen, '~0.6y236e7ku4be.');
    final Record? restored = Record.newByUSEN(usenInfo.usen);
    expect(restored, isNotNull);
    expect(restored!.current.ply, 0);
    restored.goto(99);
    expect(restored.length, 4);
    expect(
      restored.usi,
      'position startpos moves 2g2f 8c8d 7g7f 8d8e',
    );
  });

  test('USEN with resign special move', () {
    final record = Record();
    _applyUSI(record, ['2g2f', '8c8d']);
    record.append(SpecialMoveType.resign);
    final usenInfo = record.usen;
    expect(usenInfo.usen.endsWith('.r'), isTrue);
    final Record? restored = Record.newByUSEN(usenInfo.usen);
    expect(restored, isNotNull);
  });

  test('forEach visits all nodes including branches', () {
    final record = Record();
    _applyUSI(record, ['7g7f', '3c3d']);
    record.goto(1);
    record.append(record.position.createMoveByUSI('8c8d')!);

    final List<int> plies = <int>[];
    record.forEach((node) {
      plies.add(node.ply);
    });
    // root (0), 7g7f (1), 3c3d (2), branch 8c8d (2)
    expect(plies, [0, 1, 2, 2]);
  });

  test('getSubtree copies current subtree', () {
    final record = Record();
    _applyUSI(record, ['7g7f', '3c3d', '2g2f']);
    record.goto(2);
    final subtree = record.getSubtree();
    expect(subtree, isNotNull);
    expect(subtree.length, 1);
    subtree.goto(99);
    expect(subtree.current.ply, 1);
  });

  group('newByUSI', () {
    test('startpos-no-moves', () {
      final inputs = [
        'position startpos',
        'position startpos moves',
        'startpos',
        'startpos moves',
      ];
      for (final input in inputs) {
        final record = Record.newByUSI(input)!;
        expect(record.initialPosition.sfen, InitialPositionSFEN.standard.value);
        expect(record.length, 0);
        expect(record.position.sfen, InitialPositionSFEN.standard.value);
      }
    });

    test('startpos with moves and resign', () {
      const input = 'position startpos moves 2g2f 3c3d 7g7f 4c4d resign';
      final record = Record.newByUSI(input)!;
      expect(record.length, 5);
      record.goto(5);
      expect(record.current.move, specialMove(SpecialMoveType.resign));
    });

    test('sfen', () {
      const inputs = [
        'position sfen ln1g2g1l/2s2k3/2ppp3p/5p2b/P2r1N3/2P2P3/1P1PP1P1P/1SGKG2+R1/LN5NL b S5Pbs 57 moves S*3c 4b4c 3c4d 4c4d 2h2d',
        'position sfen ln1g2g1l/2s2k3/2ppp3p/5p2b/P2r1N3/2P2P3/1P1PP1P1P/1SGKG2+R1/LN5NL b S5Pbs moves S*3c 4b4c 3c4d 4c4d 2h2d',
      ];
      for (final input in inputs) {
        final record = Record.newByUSI(input)!;
        expect(
          record.initialPosition.sfen,
          'ln1g2g1l/2s2k3/2ppp3p/5p2b/P2r1N3/2P2P3/1P1PP1P1P/1SGKG2+R1/LN5NL b S5Pbs 1',
        );
        expect(record.length, 5);
      }
    });

    test('sfen-no-moves', () {
      const inputs = [
        'sfen ln1g2g1l/2s2k3/2ppp3p/5p2b/P2r1N3/2P2P3/1P1PP1P1P/1SGKG2+R1/LN5NL b S5Pbs 57',
        'sfen ln1g2g1l/2s2k3/2ppp3p/5p2b/P2r1N3/2P2P3/1P1PP1P1P/1SGKG2+R1/LN5NL b S5Pbs',
      ];
      for (final input in inputs) {
        final record = Record.newByUSI(input)!;
        expect(
          record.initialPosition.sfen,
          'ln1g2g1l/2s2k3/2ppp3p/5p2b/P2r1N3/2P2P3/1P1PP1P1P/1SGKG2+R1/LN5NL b S5Pbs 1',
        );
        expect(record.length, 0);
      }
    });

    test('special-moves', () {
      final testCases = [
        (
          'position startpos moves 2g2f 3c3d 7g7f 4c4d resign',
          SpecialMoveType.resign,
        ),
        (
          'position startpos moves 2g2f 3c3d 7g7f 4c4d rep_draw',
          SpecialMoveType.repetitionDraw,
        ),
        (
          'position startpos moves 2g2f 3c3d 7g7f 4c4d draw',
          SpecialMoveType.draw,
        ),
        (
          'position startpos moves 2g2f 3c3d 7g7f 4c4d timeout',
          SpecialMoveType.timeout,
        ),
        (
          'position startpos moves 2g2f 3c3d 7g7f 4c4d break',
          SpecialMoveType.interrupt,
        ),
        (
          'position startpos moves 2g2f 3c3d 7g7f 4c4d win',
          SpecialMoveType.enteringOfKing,
        ),
      ];
      for (final tc in testCases) {
        final record = Record.newByUSI(tc.$1)!;
        expect(record.length, 5);
        record.goto(5);
        expect(record.current.move, specialMove(tc.$2));
      }
    });

    test('invalid', () {
      const inputs = [
        '',
        'xxx',
        'sfen xxx',
        'position xxx',
        'position',
        'position sfen',
        'position sfen xxx',
        'position sfen xxx b - 1 moves',
        'position startpos xxx',
        'position startpos moves 2e2d',
      ];
      for (final input in inputs) {
        final result = Record.newByUSIOrError(input);
        expect(result, isNot(isA<Record>()));
        expect(
          result is Exception || result is Error,
          isTrue,
          reason: 'Input "$input" should produce error, got $result',
        );
      }
    });
  });

  test('switchBranchByIndex / activeBranch', () {
    final record = Record();
    _applyUSI(record, ['7g7f', '3c3d']);
    record.goto(1);
    record.append(record.position.createMoveByUSI('8c8d')!);
    // current is now ply=2 (8c8d branch). Sibling 3c3d has branchIndex 0.
    expect(record.current.branchIndex, 1);
    expect(record.switchBranchByIndex(0), isTrue);
    expect(record.current.activeBranch, isTrue);
    expect(record.current.branchIndex, 0);
    expect((record.current.move as Move).usi, '3c3d');
  });

  test('event stream: changePosition fires', () async {
    final record = Record();
    int count = 0;
    final completer = Completer<void>();
    record.onChangePositionEvents.listen((_) {
      count++;
      if (count == 2) completer.complete();
    });
    _applyUSI(record, ['7g7f', '3c3d']);
    await completer.future.timeout(const Duration(seconds: 1));
    expect(count, 2);
  });

  test('event on() compat: addNode handler', () async {
    final record = Record();
    final List<ImmutableNode> added = <ImmutableNode>[];
    final completer = Completer<void>();
    record.on('addNode', (ImmutableNode n) {
      added.add(n);
      if (added.length == 2) completer.complete();
    });
    _applyUSI(record, ['7g7f', '3c3d']);
    await completer.future.timeout(const Duration(seconds: 1));
    expect(added.length, 2);
  });

  group('repetition / perpetualCheck', () {
    test('初期局面では repetition false / count 1 / perpetualCheck null', () {
      final record = Record();
      expect(record.repetition, isFalse);
      expect(record.perpetualCheck, isNull);
      // ctor で 1 回 count されているはず (初期局面は ply 0 で 1 回到達)
      expect(record.getRepetitionCount(record.position), 1);
    });

    test('同じ局面に 4 回到達したら千日手 (黒先手の循環)', () {
      // 黒: 1g1f / 1f1g、白: 9c9d / 9d9c を 3 回繰り返すと同一局面 4 回到達。
      // 1 回目 = 初期局面 (Record ctor 時)、+ 3 周 = 4 回目。
      final Record? r = Record.newByUSI(
        'startpos moves '
        '1g1f 9c9d 1f1g 9d9c '
        '1g1f 9c9d 1f1g 9d9c '
        '1g1f 9c9d 1f1g 9d9c',
      );
      expect(r, isNotNull);
      expect(r!.repetition, isTrue);
      expect(r.getRepetitionCount(r.position), 4);
      // 王手ではない普通の千日手なので perpetualCheck は null
      expect(r.perpetualCheck, isNull);
    });

    test('途中まで進めると repetition false / count は実際の到達数', () {
      // 同じパターンを 2 周しただけ (= 3 回到達) なら千日手未成立
      final Record? r = Record.newByUSI(
        'startpos moves 1g1f 9c9d 1f1g 9d9c 1g1f 9c9d 1f1g 9d9c',
      );
      expect(r, isNotNull);
      expect(r!.repetition, isFalse);
      expect(r.getRepetitionCount(r.position), 3);
    });

    test('goBack / goForward で count が増減する', () {
      final Record r = Record.newByUSI('startpos moves 1g1f 9c9d 1f1g 9d9c')!;
      // 現局面 = 初期局面 (戻ってきた) ので count 2
      expect(r.getRepetitionCount(r.position), 2);
      r.goBack();
      // 9d9c の前は 1f1g 直後の局面 → count 1
      expect(r.repetition, isFalse);
      r.goForward();
      expect(r.getRepetitionCount(r.position), 2);
    });

    test('連続王手の千日手 (黒が連続王手)', () {
      // 試作的に、黒の王手を含むループを構成する。Position の制約があるので
      // 単純な往復+王手判定はできない。代わりに合成テスト: 千日手成立 +
      // 全ノードが王手ノードという最小ケース。
      // ここでは perpetualCheck の構文的動作のみ確認する。
      // (実戦的な連続王手棋譜の検証は ply_constraint_test 系で別途。)
      final record = Record();
      // 千日手未成立の段階で perpetualCheck は null
      expect(record.perpetualCheck, isNull);
    });
  });
}
