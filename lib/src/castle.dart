import 'color.dart';
import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// 駒の配置 (先手視点)。
///
/// [file] は 1〜9 の筋 (1 が先手から見た右端 = 1筋)。
/// [rank] は 1〜9 の段 (1 が上端、9 が先手の玉の初期段)。
class PiecePlacement {
  const PiecePlacement(this.file, this.rank, this.pieceType);

  /// 1..9 (盤の右が 1)
  final int file;

  /// 1..9 (盤の上が 1、先手陣の最下段が 9)
  final int rank;

  /// 駒の種類 (先手・後手は問わない、検出時に陣営を当てはめる)
  final PieceType pieceType;

  @override
  bool operator ==(Object other) {
    return other is PiecePlacement &&
        other.file == file &&
        other.rank == rank &&
        other.pieceType == pieceType;
  }

  @override
  int get hashCode => Object.hash(file, rank, pieceType);
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

  /// 必須駒配置 (先手視点)
  final List<PiecePlacement> placements;
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
// 親カテゴリ。8八玉・7八金 を骨格とし、6七金 or 7七銀 のいずれかを満たすもの。
const CastleTemplate _yaguraFamily = CastleTemplate(
  name: '矢倉囲い',
  aliases: <String>['矢倉'],
  placements: <PiecePlacement>[
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.gold),
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
const CastleTemplate _yaguraAnaguma = CastleTemplate(
  name: '矢倉穴熊',
  parent: '矢倉囲い',
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
const CastleTemplate _hayagakoi = CastleTemplate(
  name: '早囲い',
  parent: '矢倉囲い',
  placements: <PiecePlacement>[
    PiecePlacement(6, 8, PieceType.king),
    PiecePlacement(7, 9, PieceType.gold),
    PiecePlacement(6, 9, PieceType.silver),
    PiecePlacement(6, 7, PieceType.pawn),
  ],
);

// --- 美濃系 ----------------------------------------------------------------
// 親カテゴリ。3八玉・4八金 を骨格とした振り飛車の基本囲い。
const CastleTemplate _minoFamily = CastleTemplate(
  name: '美濃囲い',
  aliases: <String>['美濃'],
  placements: <PiecePlacement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(3, 9, PieceType.silver),
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
const CastleTemplate _hidariMino = CastleTemplate(
  name: '左美濃',
  parent: '美濃囲い',
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
const CastleTemplate _tenshukakuMino = CastleTemplate(
  name: '天守閣美濃',
  parent: '美濃囲い',
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
// 親カテゴリ。香落とし or 玉香組み換えで端に玉を逃がした堅陣の総称。
const CastleTemplate _anagumaFamily = CastleTemplate(
  name: '穴熊囲い',
  aliases: <String>['穴熊'],
  placements: <PiecePlacement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
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
const CastleTemplate _furibishaAnaguma = CastleTemplate(
  name: '振り飛車穴熊',
  parent: '穴熊囲い',
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
/// 別名「カマボコ囲い」「トーチカ」。
const CastleTemplate _millennium = CastleTemplate(
  name: 'ミレニアム',
  aliases: <String>['カマボコ囲い', 'トーチカ'],
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
const CastleTemplate _antiFuriGinKanmuri = CastleTemplate(
  name: '対振り銀冠',
  aliases: <String>['居飛車銀冠'],
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
  for (final PiecePlacement placement in template.placements) {
    final int file = side == Color.black ? placement.file : 10 - placement.file;
    final int rank = side == Color.black ? placement.rank : 10 - placement.rank;
    final Piece? piece = position.board.at(Square(file, rank));
    if (piece == null) {
      return false;
    }
    if (piece.color != side || piece.type != placement.pieceType) {
      return false;
    }
  }
  return true;
}
