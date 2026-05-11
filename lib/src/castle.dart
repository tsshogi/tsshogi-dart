import 'color.dart';
import 'generated/castles.g.dart' as gen;
import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// 囲いテンプレートの 1 マス分の要件 (先手視点)。
///
/// [file] は 1〜9 の筋 (1 が先手から見た右端 = 1筋)。
/// [rank] は 1〜9 の段 (1 が上端、9 が先手の玉の初期段)。
///
/// サブクラス:
/// - [PiecePlacement]   — 駒種を指定して exact match
/// - [AnyOfPieces]      — 候補のいずれかにマッチ (例: 金 or 銀)
sealed class CastleRequirement {
  const CastleRequirement(this.file, this.rank);

  /// 1..9 (盤の右が 1)
  final int file;

  /// 1..9 (盤の上が 1、先手陣の最下段が 9)
  final int rank;

  /// 指定マスの駒 [piece] が要件を満たすかを判定する。
  /// [side] は対象陣営。要件を満たすには piece は非 null かつ
  /// piece.color == side でなければならない (色は常に必須)。
  bool isSatisfiedBy(Piece? piece, Color side);
}

/// 駒種を厳密に指定する要件 (exact match)。
///
/// 例: `PiecePlacement(7, 8, PieceType.gold)` は 7八に先手 (照合陣営) の金。
class PiecePlacement extends CastleRequirement {
  const PiecePlacement(super.file, super.rank, this.pieceType);

  /// 駒の種類 (色は照合時に [side] を当てはめる)
  final PieceType pieceType;

  @override
  bool isSatisfiedBy(Piece? piece, Color side) {
    if (piece == null) return false;
    if (piece.color != side) return false;
    return piece.type == pieceType;
  }

  @override
  bool operator ==(Object other) {
    return other is PiecePlacement &&
        other.file == file &&
        other.rank == rank &&
        other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash('PiecePlacement', file, rank, pieceType);
}

/// 駒種候補のいずれかにマッチする要件 (or 条件)。
///
/// 例: `AnyOfPieces(6, 7, [PieceType.gold, PieceType.silver])` は
/// 6七に金 or 銀。
class AnyOfPieces extends CastleRequirement {
  const AnyOfPieces(super.file, super.rank, this.options);

  /// 候補駒種 (このリストのいずれか 1 つにマッチすれば OK)
  final List<PieceType> options;

  @override
  bool isSatisfiedBy(Piece? piece, Color side) {
    if (piece == null) return false;
    if (piece.color != side) return false;
    return options.contains(piece.type);
  }

  @override
  bool operator ==(Object other) {
    if (other is! AnyOfPieces) return false;
    if (other.file != file || other.rank != rank) return false;
    if (other.options.length != options.length) return false;
    for (int i = 0; i < options.length; i++) {
      if (other.options[i] != options[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash('AnyOfPieces', file, rank, Object.hashAll(options));
}

/// 囲い (king defensive formation) のテンプレート。
///
/// 配置は常に先手 (black) 視点で記述する。後手の検出時には
/// 180° 回転 (file → 10-file, rank → 10-rank) して照合される。
class CastleTemplate {
  const CastleTemplate({
    required this.name,
    required this.placements,
    this.aliases = const <String>[],
    this.parent,
  });

  /// 囲い名 (例: '金矢倉')
  final String name;

  /// 別名
  final List<String> aliases;

  /// 親囲い (より広い分類、例: '矢倉囲い')。
  /// 親自身もテンプレートとして [knownCastles] に含まれる場合がある。
  final String? parent;

  /// 必須駒配置 (先手視点)。`PiecePlacement` (exact) と `AnyOfPieces` (or) を
  /// 混在させられる。
  final List<CastleRequirement> placements;
}

/// 局面における囲いの検出結果。
class DetectedCastle {
  const DetectedCastle({required this.template, required this.side});

  /// マッチしたテンプレート
  final CastleTemplate template;

  /// この囲いを構築している陣営
  final Color side;

  @override
  bool operator ==(Object other) {
    return other is DetectedCastle &&
        other.template.name == template.name &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(template.name, side);
}

// ---------------------------------------------------------------------------
// 既知の囲いテンプレート
// ---------------------------------------------------------------------------
//
// テンプレ本体は ASCII source-of-truth (data/castles.txt) から自動生成され、
// lib/src/generated/castles.g.dart に const リストとして書き出される。本ファ
// イルではそれを単に再エクスポートする。データを編集したい場合は
// data/castles.txt を直接書き換え、以下を実行する:
//
//   dart run tool/generate_castles.dart
//
// 囲いの考証ノート (bioshogi 不参照、玉位置等の修正履歴) は
// docs/plans/ascii-codegen.md および data/castles.txt 冒頭コメントを参照。

/// 既知の囲いテンプレート (135 件)。
///
/// 親カテゴリ (矢倉囲い・美濃囲い・穴熊囲い) も含む。
/// 子テンプレート (金矢倉等) がマッチすれば、親テンプレートも独立に判定される
/// (placements の包含関係が満たされていれば自然と両方検出される)。
const List<CastleTemplate> knownCastles = gen.castles;

/// 局面 [position] から囲いを検出する。
///
/// [side] が指定された場合はその陣営のみ、null の場合は両陣営を判定する。
/// 各テンプレートは先手視点で記述されており、後手判定では 180° 回転して
/// 照合する。テンプレートの全 placements を満たす駒が盤上にあれば検出。
/// テンプレートに含まれていない駒が他のマスにあっても判定には影響しない。
/// 複数の囲い (例: 金矢倉と矢倉囲い) が同時にマッチすることがある。
List<DetectedCastle> detectCastles(
  ImmutablePosition position, {
  Color? side,
}) {
  final List<DetectedCastle> results = <DetectedCastle>[];
  for (final CastleTemplate template in knownCastles) {
    if (side == null || side == Color.black) {
      if (_matchesTemplate(position, template, Color.black)) {
        results.add(DetectedCastle(template: template, side: Color.black));
      }
    }
    if (side == null || side == Color.white) {
      if (_matchesTemplate(position, template, Color.white)) {
        results.add(DetectedCastle(template: template, side: Color.white));
      }
    }
  }
  return results;
}

bool _matchesTemplate(
  ImmutablePosition position,
  CastleTemplate template,
  Color side,
) {
  for (final CastleRequirement req in template.placements) {
    final int file = side == Color.black ? req.file : 10 - req.file;
    final int rank = side == Color.black ? req.rank : 10 - req.rank;
    final Piece? piece = position.board.at(Square(file, rank));
    if (!req.isSatisfiedBy(piece, side)) {
      return false;
    }
  }
  return true;
}
