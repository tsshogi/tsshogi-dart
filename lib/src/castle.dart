import 'color.dart';
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
// 配置は Wikipedia「将棋の囲い」および一般的な棋書 (羽生の頭脳・将棋世界
// 連載等) で広く知られている標準形を採用している。同名でも書籍ごとに 1〜2
// マス揺れがあるため、ここでは「玉と金銀の骨格」を最小集合として記述し、
// 端の歩は囲いとして最も特徴的なものだけを含める方針。
//
// なお、本テンプレ作成にあたり bioshogi (AGPL-3.0) のレイアウトデータは
// 一切参照していない。名称のみ公知の呼称として用い、配置は将棋の常識に基
// づき自前で起こした。
//
// === 元仕様テーブルからの修正 ===
// docs/plans 内のリファレンス表は file/rank 番号にずれや矛盾があったため、
// 以下を一般的な棋書の形に合わせて修正した。具体的にはほとんどの矢倉系で
// 玉位置が「7八」になっていたが、標準的な金矢倉/銀矢倉/総矢倉等は「8八玉」
// が正しい。各テンプレ直前のコメントに採用した形を簡潔に記載している。

// --- 矢倉系 ----------------------------------------------------------------
// 親カテゴリ。8八玉系の囲いの総称。子テンプレ (金矢倉/銀矢倉/片矢倉/総矢倉/
// 菱矢倉) は全て 8八玉 を共有するため、骨格は玉の位置のみで定義する
// (個別の駒位置は子テンプレに譲る)。これにより subset 性が保たれる。
const CastleTemplate _yaguraFamily = CastleTemplate(
  name: '矢倉囲い',
  aliases: <String>['矢倉'],
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
  ],
);

/// 金矢倉: 矢倉囲いの基本形。8八玉・7八金・6七金・7七銀。
/// 角換わり以外の相居飛車戦 (急戦矢倉/持久戦矢倉等) で広く用いられる。
const CastleTemplate _kinYagura = CastleTemplate(
  name: '金矢倉',
  aliases: <String>['本矢倉'],
  parent: '矢倉囲い',
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

/// 銀矢倉: 金矢倉の 6七金を銀に置き換えた発展形。受けが固いが攻めにくい。
const CastleTemplate _ginYagura = CastleTemplate(
  name: '銀矢倉',
  parent: '矢倉囲い',
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

/// 片矢倉: 金矢倉から玉頭の銀を一段下げた形 (7八銀)。早囲い系。
const CastleTemplate _kataYagura = CastleTemplate(
  name: '片矢倉',
  parent: '矢倉囲い',
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

/// 総矢倉: 金矢倉に 5七銀をプラスした重厚形。角換わり腰掛け銀対策で発展。
const CastleTemplate _souYagura = CastleTemplate(
  name: '総矢倉',
  parent: '矢倉囲い',
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
    PiecePlacement(7, 6, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

/// 菱矢倉: 6七・7七に銀、5七にも銀、6八に金を配する超重厚形。
const CastleTemplate _hishiYagura = CastleTemplate(
  name: '菱矢倉',
  parent: '矢倉囲い',
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(5, 6, PieceType.pawn),
    PiecePlacement(4, 6, PieceType.pawn),
  ],
);

/// 矢倉穴熊: 矢倉の玉を 9九まで深く囲った発展形。居飛車穴熊への組み替え途中で現れる。
/// 構造的には穴熊系 (9九玉) なので親は 穴熊囲い とする。
const CastleTemplate _yaguraAnaguma = CastleTemplate(
  name: '矢倉穴熊',
  parent: '穴熊囲い',
  placements: <PiecePlacement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 8, PieceType.gold),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(8, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
  ],
);

/// 早囲い: 矢倉戦の急ぎ囲い。6八玉・7九金・6九銀。手数を節約して攻めに回る。
/// 玉が 6八 で矢倉系 (8八玉) と subset 関係を結ばないため、parent は持たない。
const CastleTemplate _hayagakoi = CastleTemplate(
  name: '早囲い',
  placements: <PiecePlacement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.silver),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

// --- 美濃系 ----------------------------------------------------------------
// 親カテゴリ。3八玉系の振り飛車基本囲いの総称。子テンプレで金/銀の位置は
// 揺れる (本美濃の 4八金 vs 高美濃の 4七金、本美濃の 3九銀 vs 高美濃の 3七銀
// 等) ため、骨格は玉の位置のみとする。
const CastleTemplate _minoFamily = CastleTemplate(
  name: '美濃囲い',
  aliases: <String>['美濃'],
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
  ],
);

/// 本美濃: 美濃の標準形。3八玉・4八金・5八金・3九銀・1九香・1〜4七歩。
const CastleTemplate _honMino = CastleTemplate(
  name: '本美濃',
  parent: '美濃囲い',
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 7, PieceType.pawn),
    PiecePlacement(2, 7, PieceType.pawn),
    PiecePlacement(3, 7, PieceType.pawn),
    PiecePlacement(4, 7, PieceType.pawn),
  ],
);

/// 片美濃: 本美濃から 5八金が省略された形。振り飛車の最序盤で頻出。
const CastleTemplate _kataMino = CastleTemplate(
  name: '片美濃',
  aliases: <String>['片美濃囲い'],
  parent: '美濃囲い',
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 7, PieceType.pawn),
    PiecePlacement(2, 7, PieceType.pawn),
    PiecePlacement(3, 7, PieceType.pawn),
  ],
);

/// 高美濃: 本美濃の 4八金を 4七に上げた形。攻守両立で人気。
const CastleTemplate _takaMino = CastleTemplate(
  name: '高美濃',
  aliases: <String>['高美濃囲い'],
  parent: '美濃囲い',
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 7, PieceType.pawn),
    PiecePlacement(2, 7, PieceType.pawn),
    PiecePlacement(4, 6, PieceType.pawn),
  ],
);

/// 銀冠: 高美濃の銀を 2七に上げた発展形。玉頭から横に強くなる持久戦形。
const CastleTemplate _ginKanmuri = CastleTemplate(
  name: '銀冠',
  parent: '美濃囲い',
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 6, PieceType.pawn),
    PiecePlacement(2, 6, PieceType.pawn),
    PiecePlacement(3, 7, PieceType.pawn),
  ],
);

/// ダイヤモンド美濃: 本美濃に 2八銀を加えた重厚形。銀ダイヤとも呼ばれる。
const CastleTemplate _diamondMino = CastleTemplate(
  name: 'ダイヤモンド美濃',
  aliases: <String>['銀ダイヤ'],
  parent: '美濃囲い',
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(2, 8, PieceType.silver),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 7, PieceType.pawn),
    PiecePlacement(2, 7, PieceType.pawn),
    PiecePlacement(4, 7, PieceType.pawn),
  ],
);

/// 木村美濃: 4七金型の美濃。木村義雄十四世名人が愛用したことから。
const CastleTemplate _kimuraMino = CastleTemplate(
  name: '木村美濃',
  parent: '美濃囲い',
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 7, PieceType.silver),
    PiecePlacement(1, 7, PieceType.pawn),
    PiecePlacement(2, 7, PieceType.pawn),
    PiecePlacement(4, 6, PieceType.pawn),
  ],
);

/// 左美濃: 居飛車側の美濃。玉は 7八/8八、金 6八・5九。対振り飛車急戦/持久戦両対応。
/// 玉が 7八 で振り飛車の美濃 (3八玉) と subset 関係を結ばないため parent なし。
const CastleTemplate _hidariMino = CastleTemplate(
  name: '左美濃',
  placements: <PiecePlacement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// 天守閣美濃: 左美濃の玉を 8七まで上げた形。対四間飛車の代表的囲い。
/// 玉が 8七 で振り飛車の美濃 (3八玉) と subset 関係を結ばないため parent なし。
const CastleTemplate _tenshukakuMino = CastleTemplate(
  name: '天守閣美濃',
  aliases: <String>['天守閣囲い'],
  placements: <PiecePlacement>[
    PiecePlacement(8, 7, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.pawn),
    PiecePlacement(8, 6, PieceType.pawn),
  ],
);

// --- 穴熊系 ----------------------------------------------------------------
// 親カテゴリ。9九玉系の堅陣の総称 (居飛車穴熊・ビッグ4・松尾流穴熊・矢倉穴熊)。
// 1九玉の振り飛車穴熊は別系統 (parent なし) として扱う。
// 子テンプレで香位置等が揺れる可能性に備え骨格は玉のみ。
const CastleTemplate _anagumaFamily = CastleTemplate(
  name: '穴熊囲い',
  aliases: <String>['穴熊'],
  placements: <PiecePlacement>[
    PiecePlacement(9, 9, PieceType.king),
  ],
);

/// 居飛車穴熊: 9九玉・9八香・8八銀・7九金。対振り飛車の代表的持久戦囲い。
const CastleTemplate _ibishaAnaguma = CastleTemplate(
  name: '居飛車穴熊',
  parent: '穴熊囲い',
  placements: <PiecePlacement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
  ],
);

/// 振り飛車穴熊: 1九玉・1八香・2九金・2八銀。振り飛車側の居飛車穴熊。
/// 玉が 1九 で 穴熊囲い (9九玉) と subset 関係を結ばないため parent なし。
const CastleTemplate _furibishaAnaguma = CastleTemplate(
  name: '振り飛車穴熊',
  placements: <PiecePlacement>[
    PiecePlacement(1, 9, PieceType.king),
    PiecePlacement(1, 8, PieceType.lance),
    PiecePlacement(2, 9, PieceType.gold),
    PiecePlacement(2, 8, PieceType.silver),
    PiecePlacement(1, 7, PieceType.pawn),
  ],
);

/// ビッグ4: 居飛車穴熊に金銀を 4 枚集めた最堅陣。
const CastleTemplate _big4 = CastleTemplate(
  name: 'ビッグ4',
  aliases: <String>['ビッグフォー'],
  parent: '穴熊囲い',
  placements: <PiecePlacement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
  ],
);

/// 松尾流穴熊: 居飛車穴熊の 7九銀型 (松尾歩八段考案)。攻守バランスに優れる。
const CastleTemplate _matsuoRyuAnaguma = CastleTemplate(
  name: '松尾流穴熊',
  parent: '穴熊囲い',
  placements: <PiecePlacement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(9, 7, PieceType.silver),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(9, 6, PieceType.pawn),
  ],
);

// --- 舟囲い・雁木・中住まい等 ---------------------------------------------

/// 舟囲い: 6九玉・5九金・4九金・5八銀。居飛車急戦の基本囲い。
const CastleTemplate _funaGakoi = CastleTemplate(
  name: '舟囲い',
  placements: <PiecePlacement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(4, 7, PieceType.pawn),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// 中原囲い: 6八玉・5八金・4九金・7八銀。中原誠十六世名人考案の縦長囲い。
const CastleTemplate _nakaharaGakoi = CastleTemplate(
  name: '中原囲い',
  placements: <PiecePlacement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
  ],
);

/// 雁木囲い: 7八玉・6八金・5九金・6七銀・5七銀。角換わり・雁木戦法の主力囲い。
const CastleTemplate _gangiGakoi = CastleTemplate(
  name: '雁木囲い',
  aliases: <String>['雁木'],
  placements: <PiecePlacement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(5, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(5, 6, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
  ],
);

/// 中住まい: 5九玉・4八金・6八金・5八銀。横歩取り・相掛かりで使う中央囲い。
const CastleTemplate _nakaZumai = CastleTemplate(
  name: '中住まい',
  placements: <PiecePlacement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(4, 7, PieceType.pawn),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// ミレニアム: 8八玉・7七桂・7八金・6八金・8七銀。2000年頃考案、対振り飛車。
/// 別名「カマボコ囲い」「トーチカ」「ミレニアム囲い」。
const CastleTemplate _millennium = CastleTemplate(
  name: 'ミレニアム',
  aliases: <String>['カマボコ囲い', 'トーチカ', 'ミレニアム囲い'],
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 7, PieceType.knight),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(8, 7, PieceType.silver),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.pawn),
    PiecePlacement(8, 6, PieceType.pawn),
    PiecePlacement(9, 7, PieceType.pawn),
  ],
);

/// elmo囲い: 6九玉・7八金・5九金・5八銀・歩 4〜7七。
/// AI elmo の自己対局で発見された対振り飛車急戦囲い。
const CastleTemplate _elmoGakoi = CastleTemplate(
  name: 'elmo囲い',
  aliases: <String>['エルモ囲い'],
  placements: <PiecePlacement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(4, 7, PieceType.pawn),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
  ],
);

/// 金無双: 3八玉・4九金・5九金・3九銀・1九香。対振り飛車の二枚金型。
/// 別名「二枚金」。
const CastleTemplate _kinMusou = CastleTemplate(
  name: '金無双',
  aliases: <String>['二枚金'],
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 7, PieceType.pawn),
    PiecePlacement(2, 7, PieceType.pawn),
    PiecePlacement(3, 7, PieceType.pawn),
  ],
);

/// アヒル囲い: 6九玉・5九金・7九金・4九銀・8九銀・歩を一段下げない原始形。
/// 短手数で組む奇襲系の囲い。
const CastleTemplate _ahiruGakoi = CastleTemplate(
  name: 'アヒル囲い',
  aliases: <String>['アヒル'],
  placements: <PiecePlacement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(4, 9, PieceType.silver),
    PiecePlacement(8, 9, PieceType.silver),
    PiecePlacement(4, 7, PieceType.pawn),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(8, 7, PieceType.pawn),
  ],
);

/// 居玉: 5九玉のまま囲わない原始的な形。奇襲戦法やアヒル戦法の初期に現れる。
const CastleTemplate _igyoku = CastleTemplate(
  name: '居玉',
  placements: <PiecePlacement>[
    PiecePlacement(5, 9, PieceType.king),
  ],
);

/// 箱入り娘: 5九玉・4八金・6八金・4九銀・6九銀。対振り飛車の中央集約囲い。
const CastleTemplate _hakoiriMusume = CastleTemplate(
  name: '箱入り娘',
  placements: <PiecePlacement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.silver),
    PiecePlacement(6, 9, PieceType.silver),
    PiecePlacement(4, 7, PieceType.pawn),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// ボナンザ囲い: AI「ボナンザ」が好んだ 6九玉・7九金型。elmo 囲いの先祖。
const CastleTemplate _bonanzaGakoi = CastleTemplate(
  name: 'ボナンザ囲い',
  placements: <PiecePlacement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(5, 8, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
  ],
);

/// 対振り銀冠: 居飛車側で組む銀冠 (7八玉・8七銀)。対振り持久戦で頻出。
/// (居飛車銀冠 は別エントリとして独立に存在)
const CastleTemplate _antiFuriGinKanmuri = CastleTemplate(
  name: '対振り銀冠',
  placements: <PiecePlacement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(8, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(9, 9, PieceType.lance),
    PiecePlacement(9, 6, PieceType.pawn),
    PiecePlacement(8, 6, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.pawn),
  ],
);

// ===========================================================================
// Phase B: 追加囲いテンプレート群
// ---------------------------------------------------------------------------
// 以下は Wikipedia 「将棋の囲い」および一般的棋書知識から再構成した囲い。
// 文献によって 1〜2 マスの揺れがある変種については AnyOfPieces で吸収するか、
// 「骨格 (玉 + 主要 2〜3 駒)」のみのゆるいテンプレートとした。曖昧な囲いには
// `// FIXME: loose pattern, verify with shogi reference` を付与している。
// ===========================================================================

// --- 矢倉系 (追加) ----------------------------------------------------------

/// 角矢倉: 7七角・6八金・5九金・7八銀・8八玉。角を矢倉に組み込んだ形。
const CastleTemplate _kakuYagura = CastleTemplate(
  name: '角矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 7, PieceType.bishop),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

/// 天野矢倉: 江戸期天野宗歩流の矢倉。8八玉・7八金・6八金・7七銀・6六歩。
const CastleTemplate _amanoYagura = CastleTemplate(
  name: '天野矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 6, PieceType.pawn),
  ],
);

/// 土居矢倉: 土居市太郎名誉名人考案。金矢倉の 7九金型 (6八金型) のバリエ。
const CastleTemplate _doiYagura = CastleTemplate(
  name: '土居矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// 菊水矢倉: 矢倉の 6七銀・7六歩型。攻守バランス型。
const CastleTemplate _kikusuiYagura = CastleTemplate(
  name: '菊水矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
  ],
);

/// 富士見矢倉: 7七桂跳ねの矢倉。8八玉・7八金・6七金・7七桂・6八銀。
const CastleTemplate _fujimiYagura = CastleTemplate(
  name: '富士見矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(7, 7, PieceType.knight),
    PiecePlacement(6, 8, PieceType.silver),
  ],
);

/// 銀立ち矢倉: 7七銀の代わりに 6七銀の立った矢倉。
const CastleTemplate _ginTachiYagura = CastleTemplate(
  name: '銀立ち矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(7, 7, PieceType.pawn),
  ],
);

/// 一文字矢倉: 8八玉・7八金・6八金・7七銀。金が一段に並ぶ形。
const CastleTemplate _ichimonjiYagura = CastleTemplate(
  name: '一文字矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 高矢倉: 8八玉・7八金・6七金・7七銀+8七銀。玉頭を高く積んだ形。
const CastleTemplate _takaYagura = CastleTemplate(
  name: '高矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(8, 7, PieceType.silver),
  ],
);

/// 四角矢倉: 8八玉・7八金・6八金・7七銀・6七銀の四角形。
const CastleTemplate _shikakuYagura = CastleTemplate(
  name: '四角矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

/// へこみ矢倉: 6七が金ではなく歩で「へこんでいる」変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _hekomiYagura = CastleTemplate(
  name: 'へこみ矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// 流れ矢倉: 7八金・6八銀・7七銀 流動的に組まれた変形矢倉。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _nagareYagura = CastleTemplate(
  name: '流れ矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 8, PieceType.silver),
  ],
);

/// 流線矢倉: 流れ矢倉の発展形、6七銀立ちの流線形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ryusenYagura = CastleTemplate(
  name: '流線矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    AnyOfPieces(7, 7, <PieceType>[PieceType.silver, PieceType.pawn]),
  ],
);

/// 右矢倉: 通常の矢倉を右側 (2八玉付近) に組んだ形。相振り飛車などで稀。
/// 玉が右側にあり通常の矢倉とは subset 関係を持たない。
const CastleTemplate _migiYagura = CastleTemplate(
  name: '右矢倉',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.king),
    PiecePlacement(3, 8, PieceType.gold),
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(3, 7, PieceType.silver),
  ],
);

/// 隅矢倉: 9八玉・8八金・7八金・8七銀の端寄り矢倉。穴熊一歩手前。
/// 玉が 9八 で標準の矢倉 (8八玉) と subset を結ばないため parent なし。
const CastleTemplate _sumiYagura = CastleTemplate(
  name: '隅矢倉',
  placements: <CastleRequirement>[
    PiecePlacement(9, 8, PieceType.king),
    PiecePlacement(8, 8, PieceType.gold),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(8, 7, PieceType.silver),
  ],
);

/// 矢倉早囲い: 早囲いの別表記。6八玉・7九金・6九銀。
const CastleTemplate _yaguraHayagakoi = CastleTemplate(
  name: '矢倉早囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.silver),
    PiecePlacement(7, 7, PieceType.pawn),
  ],
);

/// ムリヤリ矢倉: 強引に組み上げる急戦矢倉。8八玉・7八金・7七銀の最小骨格。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _muriyariYagura = CastleTemplate(
  name: 'ムリヤリ矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 無責任矢倉: 6七・7七 ともゆるい矢倉風。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _musekininYagura = CastleTemplate(
  name: '無責任矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    AnyOfPieces(7, 7, <PieceType>[PieceType.silver, PieceType.gold]),
  ],
);

/// 悪形矢倉: 形が乱れた矢倉。8八玉と 7八金だけは保つ。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _akugyouYagura = CastleTemplate(
  name: '悪形矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    AnyOfPieces(
        7, 7, <PieceType>[PieceType.silver, PieceType.gold, PieceType.pawn]),
  ],
);

/// 大盾囲い: 矢倉戦の特殊形。6七・7七 が 金 or 銀。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ootateGakoi = CastleTemplate(
  name: '大盾囲い',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    AnyOfPieces(6, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 7, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 大隅囲い: 大隅流のオリジナル囲い、矢倉の発展形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _oosumiGakoi = CastleTemplate(
  name: '大隅囲い',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(8, 7, PieceType.silver),
  ],
);

/// 金門矢倉: 金で門のように構える矢倉。8八玉・7八金・6八金。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kinmonYagura = CastleTemplate(
  name: '金門矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
  ],
);

/// 豆腐矢倉: 形が四角で「豆腐」と呼ばれる矢倉。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _toufuYagura = CastleTemplate(
  name: '豆腐矢倉',
  parent: '矢倉囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

// --- 雁木系 (追加) ----------------------------------------------------------
// 親カテゴリは設けず、'雁木囲い' を親として扱う子テンプレ群。

/// 新型雁木: 5七銀・6七銀の左右銀で組む現代雁木。7八玉・6八金・5九金。
/// 親 (雁木囲い) の歩構成と完全に一致するように 5六・6六・7七 歩も含める。
const CastleTemplate _shingataGangi = CastleTemplate(
  name: '新型雁木',
  parent: '雁木囲い',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(5, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(5, 6, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(4, 6, PieceType.pawn),
  ],
);

/// オールド雁木: 古典的な雁木 (3八玉系の振り飛車雁木とは別の居飛車型)。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _oldGangi = CastleTemplate(
  name: 'オールド雁木',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// オリジナル雁木: 4八銀型の古典雁木。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _originalGangi = CastleTemplate(
  name: 'オリジナル雁木',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(4, 8, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

/// ツノ銀雁木: 5七・6七銀を「ツノ」のように配する雁木。
/// 親 (雁木囲い) の全駒を含める形に拡張。
const CastleTemplate _tsunoGinGangi = CastleTemplate(
  name: 'ツノ銀雁木',
  parent: '雁木囲い',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(5, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(5, 6, PieceType.pawn),
    PiecePlacement(6, 6, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(4, 6, PieceType.pawn),
  ],
);

// --- 美濃系 (追加) ----------------------------------------------------------

/// 銀美濃: 美濃の左金 (5八) が銀になった形。
const CastleTemplate _ginMino = CastleTemplate(
  name: '銀美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 金美濃: 5八が金のままで 3九が金になった形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kinMino = CastleTemplate(
  name: '金美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.gold),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 升田美濃: 升田幸三実力制四代名人の指した美濃変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _masudaMino = CastleTemplate(
  name: '升田美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(2, 8, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 大山美濃: 大山康晴十五世名人愛用の美濃。本美濃に近いが 2八銀型。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _oyamaMino = CastleTemplate(
  name: '大山美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(2, 8, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 坊主美濃: 1九香が無く端が薄い (坊主頭) 美濃。
const CastleTemplate _bouzuMino = CastleTemplate(
  name: '坊主美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(1, 7, PieceType.pawn),
  ],
);

/// カブト美濃: 兜のような形の美濃変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kabutoMino = CastleTemplate(
  name: 'カブト美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// ずれ美濃: 通常の美濃の駒位置が 1 マスずれた形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _zureMino = CastleTemplate(
  name: 'ずれ美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    AnyOfPieces(4, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(4, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// ちょんまげ美濃: 玉頭に駒が一つ「ちょんまげ」のように立つ美濃変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _chonmageMino = CastleTemplate(
  name: 'ちょんまげ美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(3, 7, PieceType.knight),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 四枚美濃: 美濃に金銀計 4 枚を集めた重厚形。
const CastleTemplate _yonmaiMino = CastleTemplate(
  name: '四枚美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(4, 7, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 連盟美濃: 「連盟」と呼ばれる古い美濃形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _renmeiMino = CastleTemplate(
  name: '連盟美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(2, 9, PieceType.knight),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 美濃熊囲い: 美濃と穴熊の中間。2九玉が穴熊側に寄った形。
/// FIXME: loose pattern, verify with shogi reference (parent なし)
const CastleTemplate _minoGumaGakoi = CastleTemplate(
  name: '美濃熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(2, 9, PieceType.king),
    PiecePlacement(3, 9, PieceType.gold),
    PiecePlacement(3, 8, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
    PiecePlacement(1, 8, PieceType.pawn),
  ],
);

/// 銀冠穴熊: 居飛車穴熊+銀冠の混合。9九玉・9八香・8九金・8八銀・7七銀。
const CastleTemplate _ginKanmuriAnaguma = CastleTemplate(
  name: '銀冠穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 振り飛車銀冠穴熊: 振り飛車側の銀冠穴熊。玉 1九。
const CastleTemplate _furibishaGinKanmuriAnaguma = CastleTemplate(
  name: '振り飛車銀冠穴熊',
  placements: <CastleRequirement>[
    PiecePlacement(1, 9, PieceType.king),
    PiecePlacement(1, 8, PieceType.lance),
    PiecePlacement(2, 9, PieceType.gold),
    PiecePlacement(2, 8, PieceType.silver),
    PiecePlacement(3, 7, PieceType.silver),
  ],
);

/// 四枚銀冠: 銀冠に金銀計 4 枚集めた発展形。
const CastleTemplate _yonmaiGinKanmuri = CastleTemplate(
  name: '四枚銀冠',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(3, 7, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 片銀冠: 片美濃から銀を 2七に上げた形。
const CastleTemplate _kataGinKanmuri = CastleTemplate(
  name: '片銀冠',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 端玉銀冠: 玉を 1八/2八 まで端に寄せた銀冠。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _hashiGyokuGinKanmuri = CastleTemplate(
  name: '端玉銀冠',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.king),
    PiecePlacement(3, 8, PieceType.gold),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 振り飛車端玉銀冠: 振り飛車側の端玉銀冠。玉 1八。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _furibishaHashiGyokuGinKanmuri = CastleTemplate(
  name: '振り飛車端玉銀冠',
  placements: <CastleRequirement>[
    PiecePlacement(1, 8, PieceType.king),
    PiecePlacement(2, 8, PieceType.gold),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 居飛車銀冠: 居飛車側の銀冠 (対振り銀冠の別名扱いだが独立エントリ)。
/// 対振り銀冠との区別: 玉位置と銀位置は同じ。
const CastleTemplate _ibishaGinKanmuri = CastleTemplate(
  name: '居飛車銀冠',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(8, 7, PieceType.silver),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(8, 6, PieceType.pawn),
    PiecePlacement(9, 6, PieceType.pawn),
    PiecePlacement(7, 9, PieceType.gold),
  ],
);

/// 居飛車金冠: 居飛車の 8七金型の冠囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ibishaKinKanmuri = CastleTemplate(
  name: '居飛車金冠',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(8, 7, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 居飛車金美濃: 居飛車版の金美濃。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ibishaKinMino = CastleTemplate(
  name: '居飛車金美濃',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
  ],
);

/// 居飛車金無双: 居飛車側の金無双。7八玉と二枚金。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ibishaKinMusou = CastleTemplate(
  name: '居飛車金無双',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 9, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.silver),
  ],
);

// --- 穴熊系 (追加) ----------------------------------------------------------

/// 角換わり穴熊: 角換わり戦における穴熊。8八銀+7九金+居飛車穴熊型。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kakuGawariAnaguma = CastleTemplate(
  name: '角換わり穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(8, 9, PieceType.gold),
  ],
);

/// 入玉穴熊: 入玉模様の穴熊。9九玉に金銀が広く展開。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _nyuugyokuAnaguma = CastleTemplate(
  name: '入玉穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(7, 8, PieceType.gold),
  ],
);

/// 神吉流穴熊: 神吉宏充七段考案の穴熊変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kamiyoshiRyuAnaguma = CastleTemplate(
  name: '神吉流穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

/// 居飛穴音無しの構え: 居飛車穴熊から香を上げない静かな構え。
const CastleTemplate _ibianaOtonashi = CastleTemplate(
  name: '居飛穴音無しの構え',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(8, 9, PieceType.gold),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(9, 8, PieceType.lance),
  ],
);

/// 片穴熊: 銀香が一方しか付いていない不完全穴熊。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kataAnaguma = CastleTemplate(
  name: '片穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(8, 9, PieceType.gold),
  ],
);

/// 紙穴熊: 守りの薄い穴熊。玉+香+1〜2枚のみ。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kamiAnaguma = CastleTemplate(
  name: '紙穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 裸穴熊: 香だけある最小穴熊。
const CastleTemplate _hadakaAnaguma = CastleTemplate(
  name: '裸穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
  ],
);

/// 一枚穴熊: 玉+香+金銀いずれか 1 枚。
const CastleTemplate _ichimaiAnaguma = CastleTemplate(
  name: '一枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 二枚穴熊: 玉+香+金銀 2 枚。
const CastleTemplate _nimaiAnaguma = CastleTemplate(
  name: '二枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 三枚穴熊: 玉+香+金銀 3 枚。
const CastleTemplate _sanmaiAnaguma = CastleTemplate(
  name: '三枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 9, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 四枚穴熊: 玉+香+金銀 4 枚。
const CastleTemplate _yonmaiAnaguma = CastleTemplate(
  name: '四枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 8, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 五枚穴熊: 4 枚 + 6九/8七いずれかの追加 1 枚。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _gomaiAnaguma = CastleTemplate(
  name: '五枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 7, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 六枚穴熊: 5 枚 + さらに 1 枚積み増し。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _rokumaiAnaguma = CastleTemplate(
  name: '六枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 7, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 七枚穴熊: 6 枚 + さらに 1 枚。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _nanamaiAnaguma = CastleTemplate(
  name: '七枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(6, 9, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 八枚穴熊: 8 枚積み上げた最大穴熊。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _hachimaiAnaguma = CastleTemplate(
  name: '八枚穴熊',
  parent: '穴熊囲い',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
    AnyOfPieces(8, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 8, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(8, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(7, 7, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(6, 9, <PieceType>[PieceType.gold, PieceType.silver]),
    AnyOfPieces(6, 8, <PieceType>[PieceType.gold, PieceType.silver]),
  ],
);

/// 振り飛車ビッグ4: 振り飛車側のビッグ4 (1九玉)。
const CastleTemplate _furibishaBig4 = CastleTemplate(
  name: '振り飛車ビッグ4',
  placements: <CastleRequirement>[
    PiecePlacement(1, 9, PieceType.king),
    PiecePlacement(1, 8, PieceType.lance),
    PiecePlacement(2, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.gold),
    PiecePlacement(2, 8, PieceType.silver),
    PiecePlacement(3, 8, PieceType.silver),
  ],
);

/// 振り飛車ミレニアム: 振り飛車側のミレニアム (2八玉・3七桂)。
const CastleTemplate _furibishaMillennium = CastleTemplate(
  name: '振り飛車ミレニアム',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.king),
    PiecePlacement(3, 7, PieceType.knight),
    PiecePlacement(3, 8, PieceType.gold),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(4, 8, PieceType.gold),
  ],
);

/// 振り飛車エルモ: 振り飛車側のエルモ (4九玉)。
const CastleTemplate _furibishaElmo = CastleTemplate(
  name: '振り飛車エルモ',
  placements: <CastleRequirement>[
    PiecePlacement(4, 9, PieceType.king),
    PiecePlacement(3, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
  ],
);

/// 振り飛車天守閣美濃: 振り飛車側の天守閣美濃 (2七玉)。
const CastleTemplate _furibishaTenshukakuMino = CastleTemplate(
  name: '振り飛車天守閣美濃',
  placements: <CastleRequirement>[
    PiecePlacement(2, 7, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(3, 7, PieceType.silver),
  ],
);

/// 振り飛車四枚美濃: 振り飛車側の四枚美濃 (3八玉、二金二銀)。
/// 親美濃囲いと同 8八玉条件は満たすので parent 設定可。
const CastleTemplate _furibishaYonmaiMino = CastleTemplate(
  name: '振り飛車四枚美濃',
  parent: '美濃囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(4, 7, PieceType.silver),
  ],
);

/// 振り飛車串カツ囲い: 振り飛車側の串カツ。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _furibishaKushikatsuGakoi = CastleTemplate(
  name: '振り飛車串カツ囲い',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(3, 7, PieceType.silver),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(2, 8, PieceType.gold),
  ],
);

// --- その他追加囲い ----------------------------------------------------------

/// あずまや囲い: 6九玉・5九金・7九金・6八銀+屋根状の歩。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _azumayaGakoi = CastleTemplate(
  name: 'あずまや囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 8, PieceType.silver),
  ],
);

/// いかだ囲い: 玉と金銀が横一列に並ぶ平らな囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ikadaGakoi = CastleTemplate(
  name: 'いかだ囲い',
  placements: <CastleRequirement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(7, 9, PieceType.silver),
  ],
);

/// いちご囲い: 8八玉と 7八金+5九金のコンパクトな囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ichigoGakoi = CastleTemplate(
  name: 'いちご囲い',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.silver),
  ],
);

/// オリオン囲い: 玉・金・銀が三角に配される対振り飛車囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _orionGakoi = CastleTemplate(
  name: 'オリオン囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(6, 8, PieceType.pawn),
  ],
);

/// カギ囲い: 玉と金銀がカギ字状に配置された囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kagiGakoi = CastleTemplate(
  name: 'カギ囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(6, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

/// カタ囲い: 「カタ」と呼ばれる片寄せ囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kataGakoi = CastleTemplate(
  name: 'カタ囲い',
  placements: <CastleRequirement>[
    PiecePlacement(7, 9, PieceType.king),
    PiecePlacement(6, 9, PieceType.gold),
    PiecePlacement(8, 9, PieceType.silver),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

/// カニ囲い: 6八玉・5八金・4九金・3九銀。原始的な居飛車序盤囲い。
const CastleTemplate _kaniGakoi = CastleTemplate(
  name: 'カニ囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

/// カニ缶囲い: カニ囲いの発展形 (蓋付き)。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kaniKanGakoi = CastleTemplate(
  name: 'カニ缶囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

/// カブト囲い: 玉頭に銀・金・銀の兜型を組む囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kabutoGakoi = CastleTemplate(
  name: 'カブト囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// かんぴょう囲い: 細長い「かんぴょう」状の囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kanpyouGakoi = CastleTemplate(
  name: 'かんぴょう囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 8, PieceType.pawn),
    PiecePlacement(6, 8, PieceType.pawn),
    PiecePlacement(5, 8, PieceType.pawn),
  ],
);

/// セメント囲い: 5九玉・4八金・6八金・5七銀・5八金などゴテゴテと固める囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _cementGakoi = CastleTemplate(
  name: 'セメント囲い',
  placements: <CastleRequirement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// チョコレート囲い: 矩形に金銀を並べる「チョコレート板」状の囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _chocolateGakoi = CastleTemplate(
  name: 'チョコレート囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

/// ツノ銀囲い: 「ツノ」状に銀を立てた囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _tsunoGinGakoi = CastleTemplate(
  name: 'ツノ銀囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(4, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

/// 片ツノ銀囲い: ツノ銀の片側だけ。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kataTsunoGinGakoi = CastleTemplate(
  name: '片ツノ銀囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

/// モノレール囲い: 一直線に駒が並ぶモノレール状の囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _monoRailGakoi = CastleTemplate(
  name: 'モノレール囲い',
  placements: <CastleRequirement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(7, 9, PieceType.silver),
    PiecePlacement(2, 9, PieceType.knight),
    PiecePlacement(8, 9, PieceType.knight),
  ],
);

/// 串カツ囲い: 玉頭に縦に駒を「串」のように並べる囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kushikatsuGakoi = CastleTemplate(
  name: '串カツ囲い',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(8, 8, PieceType.gold),
  ],
);

/// 文鎮囲い: 4八金・6八金・5九玉の重厚な中央囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _bunchinGakoi = CastleTemplate(
  name: '文鎮囲い',
  placements: <CastleRequirement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.silver),
  ],
);

/// 四段端玉: 玉を 9段目から離して四段目寄りに上がった端玉。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _yondanHashiGyoku = CastleTemplate(
  name: '四段端玉',
  placements: <CastleRequirement>[
    PiecePlacement(9, 6, PieceType.king),
    PiecePlacement(8, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
  ],
);

/// 雲隠れ玉: 玉を玉頭の歩・銀の影に隠した形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kumoGakureGyoku = CastleTemplate(
  name: '雲隠れ玉',
  placements: <CastleRequirement>[
    PiecePlacement(8, 7, PieceType.king),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(8, 6, PieceType.pawn),
  ],
);

/// 天空の城: 玉が高く上がる「ラピュタ」のような囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _tenkuuNoShiro = CastleTemplate(
  name: '天空の城',
  placements: <CastleRequirement>[
    PiecePlacement(8, 6, PieceType.king),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(9, 7, PieceType.pawn),
    PiecePlacement(8, 7, PieceType.pawn),
  ],
);

/// 舟囲いDX: 舟囲いを強化した発展形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _funaGakoiDX = CastleTemplate(
  name: '舟囲いDX',
  placements: <CastleRequirement>[
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(5, 8, PieceType.silver),
    PiecePlacement(7, 9, PieceType.silver),
  ],
);

/// 桐山流中原囲い: 桐山清澄九段流の中原囲いアレンジ。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kiriyamaRyuNakaharaGakoi = CastleTemplate(
  name: '桐山流中原囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(7, 8, PieceType.silver),
    PiecePlacement(5, 7, PieceType.pawn),
    PiecePlacement(6, 7, PieceType.pawn),
    PiecePlacement(7, 7, PieceType.pawn),
    PiecePlacement(8, 7, PieceType.pawn),
  ],
);

/// 左山囲い: 左側に山型に駒を積み上げた囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _hidariYamaGakoi = CastleTemplate(
  name: '左山囲い',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(8, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(8, 7, PieceType.silver),
  ],
);

/// 無敵囲い: 玉+金銀計 4 枚で固めた完全防御型。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _mutekiGakoi = CastleTemplate(
  name: '無敵囲い',
  placements: <CastleRequirement>[
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.gold),
    PiecePlacement(4, 8, PieceType.silver),
    PiecePlacement(6, 8, PieceType.silver),
  ],
);

/// 裏アヒル囲い: アヒル囲いを反転させた変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _uraAhiruGakoi = CastleTemplate(
  name: '裏アヒル囲い',
  placements: <CastleRequirement>[
    PiecePlacement(4, 9, PieceType.king),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.gold),
    PiecePlacement(2, 9, PieceType.silver),
    PiecePlacement(6, 9, PieceType.silver),
  ],
);

/// 裾固め: 玉の左右の歩を固めて裾を締めた形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _susoGatame = CastleTemplate(
  name: '裾固め',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(9, 8, PieceType.pawn),
    PiecePlacement(8, 7, PieceType.pawn),
  ],
);

/// 角道不突き左美濃: 角道を止めたまま組む左美濃。
const CastleTemplate _kakumichiFutsukiHidariMino = CastleTemplate(
  name: '角道不突き左美濃',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(7, 9, PieceType.bishop),
  ],
);

/// 金多伝: 金が多く前進した変則囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kinTaden = CastleTemplate(
  name: '金多伝',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

/// 銀多伝: 銀が多く前進した変則囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _ginTaden = CastleTemplate(
  name: '銀多伝',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// 金盾囲い: 金で盾を作るように並べる囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _kinTateGakoi = CastleTemplate(
  name: '金盾囲い',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.gold),
  ],
);

/// 離れ金無双: 金無双で金が離れて配置された変形。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _hanareKinMusou = CastleTemplate(
  name: '離れ金無双',
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
    PiecePlacement(1, 9, PieceType.lance),
  ],
);

/// 魔方陣: 玉を中心に金銀が3x3に配置される変則囲い。
/// FIXME: loose pattern, verify with shogi reference
const CastleTemplate _mahoujin = CastleTemplate(
  name: '魔方陣',
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(4, 9, PieceType.silver),
    PiecePlacement(6, 9, PieceType.silver),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// ▲7七金型雁木 → 「7七金型雁木」として登録。先手記号 ▲ は表示用なので除外。
/// 7七が金なので親 (雁木囲い、7七歩) とは異なる → parent なし。
const CastleTemplate _shichishichiKinGataGangi = CastleTemplate(
  name: '7七金型雁木',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
    PiecePlacement(7, 7, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(5, 9, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// 既知の囲いテンプレート (Phase A、~30 件)。
///
/// 親カテゴリ (矢倉囲い・美濃囲い・穴熊囲い) も含む。
/// 子テンプレート (金矢倉等) がマッチすれば、親テンプレートも独立に判定される
/// (placements の包含関係が満たされていれば自然と両方検出される)。
const List<CastleTemplate> knownCastles = <CastleTemplate>[
  // 親カテゴリ
  _yaguraFamily,
  _minoFamily,
  _anagumaFamily,
  // 矢倉系
  _kinYagura,
  _ginYagura,
  _kataYagura,
  _souYagura,
  _hishiYagura,
  _yaguraAnaguma,
  _hayagakoi,
  // 美濃系
  _honMino,
  _kataMino,
  _takaMino,
  _ginKanmuri,
  _diamondMino,
  _kimuraMino,
  _hidariMino,
  _tenshukakuMino,
  // 穴熊系
  _ibishaAnaguma,
  _furibishaAnaguma,
  _big4,
  _matsuoRyuAnaguma,
  // その他
  _funaGakoi,
  _nakaharaGakoi,
  _gangiGakoi,
  _nakaZumai,
  _millennium,
  _elmoGakoi,
  _kinMusou,
  _ahiruGakoi,
  _igyoku,
  _hakoiriMusume,
  _bonanzaGakoi,
  _antiFuriGinKanmuri,
  // === Phase B 追加 ===
  // 矢倉系
  _kakuYagura,
  _amanoYagura,
  _doiYagura,
  _kikusuiYagura,
  _fujimiYagura,
  _ginTachiYagura,
  _ichimonjiYagura,
  _takaYagura,
  _shikakuYagura,
  _hekomiYagura,
  _nagareYagura,
  _ryusenYagura,
  _migiYagura,
  _sumiYagura,
  _yaguraHayagakoi,
  _muriyariYagura,
  _musekininYagura,
  _akugyouYagura,
  _ootateGakoi,
  _oosumiGakoi,
  _kinmonYagura,
  _toufuYagura,
  // 雁木系
  _shingataGangi,
  _oldGangi,
  _originalGangi,
  _tsunoGinGangi,
  _shichishichiKinGataGangi,
  // 美濃系
  _ginMino,
  _kinMino,
  _masudaMino,
  _oyamaMino,
  _bouzuMino,
  _kabutoMino,
  _zureMino,
  _chonmageMino,
  _yonmaiMino,
  _renmeiMino,
  _minoGumaGakoi,
  // 銀冠/金冠系
  _ginKanmuriAnaguma,
  _furibishaGinKanmuriAnaguma,
  _yonmaiGinKanmuri,
  _kataGinKanmuri,
  _hashiGyokuGinKanmuri,
  _furibishaHashiGyokuGinKanmuri,
  _ibishaGinKanmuri,
  _ibishaKinKanmuri,
  _ibishaKinMino,
  _ibishaKinMusou,
  // 穴熊系
  _kakuGawariAnaguma,
  _nyuugyokuAnaguma,
  _kamiyoshiRyuAnaguma,
  _ibianaOtonashi,
  _kataAnaguma,
  _kamiAnaguma,
  _hadakaAnaguma,
  _ichimaiAnaguma,
  _nimaiAnaguma,
  _sanmaiAnaguma,
  _yonmaiAnaguma,
  _gomaiAnaguma,
  _rokumaiAnaguma,
  _nanamaiAnaguma,
  _hachimaiAnaguma,
  // 振り飛車側変種
  _furibishaBig4,
  _furibishaMillennium,
  _furibishaElmo,
  _furibishaTenshukakuMino,
  _furibishaYonmaiMino,
  _furibishaKushikatsuGakoi,
  // その他
  _azumayaGakoi,
  _ikadaGakoi,
  _ichigoGakoi,
  _orionGakoi,
  _kagiGakoi,
  _kataGakoi,
  _kaniGakoi,
  _kaniKanGakoi,
  _kabutoGakoi,
  _kanpyouGakoi,
  _cementGakoi,
  _chocolateGakoi,
  _tsunoGinGakoi,
  _kataTsunoGinGakoi,
  _monoRailGakoi,
  _kushikatsuGakoi,
  _bunchinGakoi,
  _yondanHashiGyoku,
  _kumoGakureGyoku,
  _tenkuuNoShiro,
  _funaGakoiDX,
  _kiriyamaRyuNakaharaGakoi,
  _hidariYamaGakoi,
  _mutekiGakoi,
  _uraAhiruGakoi,
  _susoGatame,
  _kakumichiFutsukiHidariMino,
  _kinTaden,
  _ginTaden,
  _kinTateGakoi,
  _hanareKinMusou,
  _mahoujin,
];

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
