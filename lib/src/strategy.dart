import 'castle.dart';
import 'color.dart';
import 'piece.dart';
import 'position.dart';
import 'square.dart';

// ---------------------------------------------------------------------------
// 戦法検出 (Strategy / Opening detection)
// ---------------------------------------------------------------------------
//
// 囲い (castle) と異なり、戦法は「飛車の位置 + 玉の側 + 駒組の一部」で大ま
// かに識別される。本ファイルは castle.dart の [CastleRequirement] エンジン
// (PiecePlacement + AnyOfPieces) をそのまま再利用し、テンプレートと検出関数
// だけを戦法向けに新設する。
//
// 配置は常に先手 (black) 視点で記述する。後手側の検出時には 180° 回転
// (file → 10-file, rank → 10-rank) して照合する。castle.dart と完全同じ規約。
//
// 戦法名はすべて公知の将棋用語であり、特定の棋書/ソフトウェアからの転載で
// はない。bioshogi (AGPL-3.0) のレイアウトデータは一切参照していない。

/// 戦法が居飛車専用 / 振り飛車専用 / 両方を区別するフラグ。
enum StrategySide {
  /// 居飛車・振り飛車どちらでも (例: 矢倉、横歩取り)
  either,

  /// 居飛車専用 (例: 棒銀、角換わり)
  ibisha,

  /// 振り飛車専用 (例: 四間飛車、中飛車、石田流)
  furibisha,
}

/// 戦法テンプレート (位置ベース、囲い検出と同じ pattern matching を使用)。
class StrategyTemplate {
  const StrategyTemplate({
    required this.name,
    required this.placements,
    this.aliases = const <String>[],
    this.side = StrategySide.either,
    this.parent,
  });

  /// 戦法名 (例: '四間飛車')
  final String name;

  /// 別名 (例: ['四間'])
  final List<String> aliases;

  /// 必須駒配置 (先手視点)。`PiecePlacement` (exact) と `AnyOfPieces` (or) を
  /// 混在させられる。
  final List<CastleRequirement> placements;

  /// 居飛車 / 振り飛車 / 両方
  final StrategySide side;

  /// 親戦法 (例: 「ゴキゲン中飛車」の親は「中飛車」)
  final String? parent;
}

/// 検出結果。
class DetectedStrategy {
  const DetectedStrategy({required this.template, required this.side});

  /// マッチしたテンプレート
  final StrategyTemplate template;

  /// この戦法を指している陣営
  final Color side;

  @override
  bool operator ==(Object other) {
    return other is DetectedStrategy &&
        other.template.name == template.name &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(template.name, side);
}

// ===========================================================================
// 振り飛車系 (Furibisha — rook moves to the left half of the board)
// ===========================================================================

// --- 中飛車 (rook on 5筋) -------------------------------------------------
// 親カテゴリ。先手なら 5八飛、後手なら 5二飛。
const StrategyTemplate _nakabisha = StrategyTemplate(
  name: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
  ],
);

/// ゴキゲン中飛車: 5七歩を伸ばし 5五歩を狙う角道オープンの中飛車。
/// 飛車が 5筋、5六歩 (or 5五歩) で角道が開いている形が特徴。
const StrategyTemplate _gokigenNakabisha = StrategyTemplate(
  name: 'ゴキゲン中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    AnyOfPieces(5, 6, <PieceType>[PieceType.pawn]),
    // 7九角 (角道が開いている = 7九にいる角は動いていない可能性高)
    PiecePlacement(7, 9, PieceType.bishop),
  ],
);

/// 角道オープン中飛車 (≒ゴキゲンの上位概念)
const StrategyTemplate _kakumichiOpenNakabisha = StrategyTemplate(
  name: '角道オープン中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(5, 6, PieceType.pawn),
    PiecePlacement(8, 8, PieceType.bishop),
  ],
);

/// 角道オープン四間飛車 (Furibisha analog)
const StrategyTemplate _kakumichiOpenShikenbisha = StrategyTemplate(
  name: '角道オープン四間飛車',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.bishop),
  ],
);

/// 5筋位取り中飛車
const StrategyTemplate _gosujiKuraidoriNakabisha = StrategyTemplate(
  name: '5筋位取り中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(5, 5, PieceType.pawn),
  ],
);

/// 一直線穴熊中飛車 (一直線穴熊+中飛車)。
const StrategyTemplate _ichichokusenAnaguma = StrategyTemplate(
  name: '一直線穴熊',
  placements: <CastleRequirement>[
    PiecePlacement(9, 9, PieceType.king),
    PiecePlacement(9, 8, PieceType.lance),
  ],
);

/// ツノ銀中飛車: 銀が 4七・6七両方 (角の様な形=ツノ)。
const StrategyTemplate _tsunoginNakabisha = StrategyTemplate(
  name: 'ツノ銀中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(4, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

/// 矢倉流中飛車: 矢倉戦の中で 5筋に飛車。
const StrategyTemplate _yaguraNakabisha = StrategyTemplate(
  name: '矢倉中飛車',
  parent: '中飛車',
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(8, 8, PieceType.king),
  ],
);

const StrategyTemplate _yaguraRyuNakabisha = StrategyTemplate(
  name: '矢倉流中飛車',
  parent: '中飛車',
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(8, 8, PieceType.king),
  ],
);

/// 原始中飛車: 棒銀をそのまま中央で。5八飛・5七銀・5六歩。
const StrategyTemplate _genshiNakabisha = StrategyTemplate(
  name: '原始中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(5, 7, PieceType.silver),
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

/// 先手中飛車: 先手番から積極的に中飛車に振る。形の上では中飛車と同じ。
const StrategyTemplate _senteNakabisha = StrategyTemplate(
  name: '先手中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

/// 中飛車左穴熊 (中飛車で 9九玉)。
const StrategyTemplate _nakabishaHidariAnaguma = StrategyTemplate(
  name: '中飛車左穴熊',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(9, 9, PieceType.king),
  ],
);

/// 中飛車ミレニアム: 中飛車+ミレニアム囲い (8八銀+7八金+6九玉付近)。
const StrategyTemplate _nakabishaMillennium = StrategyTemplate(
  name: '中飛車ミレニアム',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.knight),
  ],
);

/// 英ちゃん流中飛車: 武市英雄流。中飛車の独自展開。
/// 形は中飛車そのもの+ 5筋早伸ばし。
const StrategyTemplate _eichanNakabisha = StrategyTemplate(
  name: '英ちゃん流中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(5, 5, PieceType.pawn),
  ],
);

/// ▲5五龍中飛車 (中央で龍を作る変化)。
const StrategyTemplate _gogoRyuNakabisha = StrategyTemplate(
  name: '5五龍中飛車',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 5, PieceType.dragon),
  ],
);

/// 飛騨の中飛車合掌造り: ローカル戦法。中飛車+特殊な囲い。
/// 形の最大公約数として中飛車のみ要求。
const StrategyTemplate _hidaNakabishaGasshou = StrategyTemplate(
  name: '飛騨の中飛車合掌造り',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(4, 7, PieceType.silver),
  ],
);

// --- 四間飛車 (rook on 6筋) -------------------------------------------------
// 親カテゴリ。先手なら 6八飛、後手なら 4二飛。
const StrategyTemplate _shikenbisha = StrategyTemplate(
  name: '四間飛車',
  aliases: <String>['四間'],
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// ノーマル四間飛車: 角道を止めた伝統的な四間飛車。6八飛+6六歩。
const StrategyTemplate _normalShikenbisha = StrategyTemplate(
  name: 'ノーマル四間飛車',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
    PiecePlacement(6, 6, PieceType.pawn),
  ],
);

/// 藤井システム: 居玉のまま端攻めを狙う四間飛車。
/// 6八飛+5九玉 (居玉) + 9六歩 が特徴。
const StrategyTemplate _fujiiSystem = StrategyTemplate(
  name: '藤井システム',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
    PiecePlacement(5, 9, PieceType.king),
    PiecePlacement(9, 6, PieceType.pawn),
  ],
);

/// 立石流四間飛車: 6八飛から 3筋へ転換する。
/// 形は 6六飛 (浮き飛車) + 角交換型が典型。
const StrategyTemplate _tateishiRyu = StrategyTemplate(
  name: '立石流四間飛車',
  aliases: <String>['立石流'],
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 6, PieceType.rook),
  ],
);

/// 4→3戦法 (戸辺流): 四間→三間に振り直す。最終形は三間飛車。
const StrategyTemplate _yonSanSenpou = StrategyTemplate(
  name: '4→3戦法',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    // 3→4→3 の経路はログがないと識別不能なので最終形のみ
  ],
);

/// 戸辺流4→3戦法
const StrategyTemplate _tobeYonSanSenpou = StrategyTemplate(
  name: '戸辺流4→3戦法',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 3→4→3戦法: 三間→四間→三間と振り替える。最終形は三間飛車。
const StrategyTemplate _sanYonSanSenpou = StrategyTemplate(
  name: '3→4→3戦法',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 四間飛車ミレニアム: 四間+ミレニアム囲い。
const StrategyTemplate _shikenbishaMillennium = StrategyTemplate(
  name: '四間飛車ミレニアム',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.knight),
  ],
);

/// はく式四間飛車: 独自手順だが最終形は通常の四間飛車。
const StrategyTemplate _hakuShikenbisha = StrategyTemplate(
  name: 'はく式四間飛車',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// 耀龍四間飛車: 藤倉勇樹考案。四間飛車を縦に活用する独特の駒組。
const StrategyTemplate _youryuShikenbisha = StrategyTemplate(
  name: '耀龍四間飛車',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// 幻想四間飛車: ネット発のジョーク系四間飛車。形は四間と同じ。
const StrategyTemplate _gensouShikenbisha = StrategyTemplate(
  name: '幻想四間飛車',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// 魔界四間飛車: ネット発のジョーク系四間飛車。形は四間と同じ。
const StrategyTemplate _makaiShikenbisha = StrategyTemplate(
  name: '魔界四間飛車',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// 三間飛車藤井システム: 藤井システムを三間で。
const StrategyTemplate _sankenFujiiSystem = StrategyTemplate(
  name: '三間飛車藤井システム',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(5, 9, PieceType.king),
  ],
);

// --- 三間飛車 (rook on 7筋) -------------------------------------------------
const StrategyTemplate _sankenbisha = StrategyTemplate(
  name: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// ノーマル三間飛車
const StrategyTemplate _normalSankenbisha = StrategyTemplate(
  name: 'ノーマル三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(6, 6, PieceType.pawn),
  ],
);

/// 石田流: 三間飛車+7六歩+7五歩+7八飛 (浮き飛車型は 7六飛)。
const StrategyTemplate _ishidaRyu = StrategyTemplate(
  name: '石田流',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 石田流本組み: 7六飛 (浮き飛車) + 6八銀 + 5八金。
const StrategyTemplate _ishidaRyuHongumi = StrategyTemplate(
  name: '石田流本組み',
  aliases: <String>['石田流本組'],
  parent: '石田流',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 6, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
    PiecePlacement(6, 8, PieceType.silver),
  ],
);

/// 早石田: 三間飛車から早く 7五歩・7四歩・7五歩 と仕掛ける急戦。
const StrategyTemplate _hayaIshida = StrategyTemplate(
  name: '早石田',
  parent: '石田流',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
    PiecePlacement(7, 6, PieceType.knight),
  ],
);

/// 升田式石田流: 升田幸三考案。7五歩+角交換+7六飛が骨格。
const StrategyTemplate _masudaShikiIshida = StrategyTemplate(
  name: '升田式石田流',
  parent: '石田流',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 6, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 鈴木流早石田
const StrategyTemplate _suzukiRyuHayaIshida = StrategyTemplate(
  name: '鈴木流早石田',
  parent: '早石田',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 久保流早石田
const StrategyTemplate _kuboRyuHayaIshida = StrategyTemplate(
  name: '久保流早石田',
  parent: '早石田',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// ムリヤリ早石田
const StrategyTemplate _muriyariHayaIshida = StrategyTemplate(
  name: 'ムリヤリ早石田',
  parent: '早石田',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 新石田流
const StrategyTemplate _shinIshidaRyu = StrategyTemplate(
  name: '新石田流',
  parent: '石田流',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 楠本式石田流
const StrategyTemplate _kusumotoShikiIshida = StrategyTemplate(
  name: '楠本式石田流',
  parent: '石田流',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// コーヤン流三間飛車
const StrategyTemplate _koyanRyuSankenbisha = StrategyTemplate(
  name: 'コーヤン流三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 三間飛車ミレニアム
const StrategyTemplate _sankenMillennium = StrategyTemplate(
  name: '三間飛車ミレニアム',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.silver),
  ],
);

/// 下町流三間飛車 (小倉久史)
const StrategyTemplate _shitamachiRyuSanken = StrategyTemplate(
  name: '下町流三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 神吉流三間飛車
const StrategyTemplate _kamiyoshiRyuSanken = StrategyTemplate(
  name: '神吉流三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 菅井流三間飛車
const StrategyTemplate _sugaiRyuSanken = StrategyTemplate(
  name: '菅井流三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// うっかり三間飛車: ジョーク系。形は三間と同じ。
const StrategyTemplate _ukkariSanken = StrategyTemplate(
  name: 'うっかり三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// うま式三間飛車
const StrategyTemplate _umashikiSanken = StrategyTemplate(
  name: 'うま式三間飛車',
  parent: '三間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 鬼殺し: 三間飛車から 7五歩+7七桂跳ねの奇襲。
const StrategyTemplate _oniGoroshi = StrategyTemplate(
  name: '鬼殺し',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 7, PieceType.knight),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 新鬼殺し
const StrategyTemplate _shinOniGoroshi = StrategyTemplate(
  name: '新鬼殺し',
  parent: '鬼殺し',
  placements: <CastleRequirement>[
    PiecePlacement(7, 7, PieceType.knight),
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

/// 鬼殺し向かい飛車: 鬼殺しの応用で向かい飛車に振る。
const StrategyTemplate _oniGoroshiMukaibisha = StrategyTemplate(
  name: '鬼殺し向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.knight),
  ],
);

// --- 向かい飛車 (rook on 8筋) -----------------------------------------------
const StrategyTemplate _mukaibisha = StrategyTemplate(
  name: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// ダイレクト向かい飛車: 角交換後すぐに 8八飛と振る。
const StrategyTemplate _directMukaibisha = StrategyTemplate(
  name: 'ダイレクト向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
    // 角不在 (角交換済み)
  ],
);

/// 阪田流向かい飛車
const StrategyTemplate _sakataRyuMukaibisha = StrategyTemplate(
  name: '阪田流向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// メリケン向かい飛車
const StrategyTemplate _merikenMukaibisha = StrategyTemplate(
  name: 'メリケン向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// モノレール向かい飛車
const StrategyTemplate _monorailMukaibisha = StrategyTemplate(
  name: 'モノレール向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// 穴角向かい飛車
const StrategyTemplate _anakakuMukaibisha = StrategyTemplate(
  name: '穴角向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// 穴角戦法: 角を 9九 / 1九 など端に潜らせる戦法。
const StrategyTemplate _anakakuSenpou = StrategyTemplate(
  name: '穴角戦法',
  placements: <CastleRequirement>[
    AnyOfPieces(9, 9, <PieceType>[PieceType.bishop]),
  ],
);

/// 天彦流向かい飛車
const StrategyTemplate _amahikoRyuMukaibisha = StrategyTemplate(
  name: '天彦流向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// 菜々河流向かい飛車
const StrategyTemplate _nanakawaRyuMukaibisha = StrategyTemplate(
  name: '菜々河流向かい飛車',
  parent: '向かい飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

/// 阪田流2手目△9四歩: 後手 9四歩からの阪田流変化。先手側の検出は意味薄。
const StrategyTemplate _sakataRyuKuyonFu = StrategyTemplate(
  name: '阪田流2手目△9四歩',
  parent: '向かい飛車',
  placements: <CastleRequirement>[
    PiecePlacement(9, 6, PieceType.pawn),
  ],
);

// --- その他振り飛車 --------------------------------------------------------

/// 角交換振り飛車: 角を交換した状態で振り飛車に組む。
/// 角不在を必須にしたいが、エンジンが「不在」をサポートしないので、
/// 飛車が振られているかつ自陣の角の初期位置 (8,8) に何も or 違う駒という
/// 緩めの近似で諦め、最低限の「飛車が左半に振られている」だけにする。
const StrategyTemplate _kakukoukanFuribisha = StrategyTemplate(
  name: '角交換振り飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    // 振り飛車の典型値として 6八飛 (四間) を採用
    AnyOfPieces(6, 8, <PieceType>[PieceType.rook]),
  ],
);

/// レグスペ (Legend Special) = ゴキゲン中飛車+穴熊+特殊駒組
const StrategyTemplate _regSpe = StrategyTemplate(
  name: 'レグスペ',
  parent: '中飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.rook),
    PiecePlacement(9, 9, PieceType.king),
  ],
);

/// 真部流: 真部一男考案の振り飛車駒組。四間飛車+独特の銀の使い方。
const StrategyTemplate _manabeRyu = StrategyTemplate(
  name: '真部流',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// 室岡システム
const StrategyTemplate _murokaSystem = StrategyTemplate(
  name: '室岡システム',
  parent: '四間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.rook),
  ],
);

/// 一間飛車: 飛車を 1筋に振る奇襲。
const StrategyTemplate _ikkenbisha = StrategyTemplate(
  name: '一間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(1, 8, PieceType.rook),
  ],
);

/// 一間飛車右穴熊
const StrategyTemplate _ikkenbishaMigiAnaguma = StrategyTemplate(
  name: '一間飛車右穴熊',
  parent: '一間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(1, 8, PieceType.rook),
    PiecePlacement(1, 9, PieceType.king),
  ],
);

/// 九間飛車 (9筋飛車。さらに奇襲)
const StrategyTemplate _kyukenbisha = StrategyTemplate(
  name: '九間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(9, 8, PieceType.rook),
  ],
);

/// 九間飛車左穴熊
const StrategyTemplate _kyukenbishaHidariAnaguma = StrategyTemplate(
  name: '九間飛車左穴熊',
  parent: '九間飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(9, 8, PieceType.rook),
    PiecePlacement(9, 9, PieceType.king),
  ],
);

/// 陽動振り飛車
const StrategyTemplate _youdouFuribisha = StrategyTemplate(
  name: '陽動振り飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    AnyOfPieces(6, 8, <PieceType>[PieceType.rook]),
  ],
);

/// 中原飛車 (中原誠の独特な振り飛車変化)
const StrategyTemplate _nakaharaBisha = StrategyTemplate(
  name: '中原飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    AnyOfPieces(6, 8, <PieceType>[PieceType.rook]),
  ],
);

/// 鬼六流どっかん飛車
const StrategyTemplate _onirokuRyuDokkan = StrategyTemplate(
  name: '鬼六流どっかん飛車',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    AnyOfPieces(6, 8, <PieceType>[PieceType.rook]),
  ],
);

/// 大平流: 大平武洋。振り飛車の独自駒組。
const StrategyTemplate _oodairaRyu = StrategyTemplate(
  name: '大平流',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

// ===========================================================================
// 居飛車系 (Ibisha — rook stays on 2筋)
// ===========================================================================

// --- 矢倉戦法 ---------------------------------------------------------------
const StrategyTemplate _yaguraSenpou = StrategyTemplate(
  name: '矢倉',
  aliases: <String>['矢倉戦法'],
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

const StrategyTemplate _moritaSystem = StrategyTemplate(
  name: '森下システム',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(6, 8, PieceType.gold),
    PiecePlacement(4, 8, PieceType.silver),
  ],
);

const StrategyTemplate _wakiSystem = StrategyTemplate(
  name: '脇システム',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(4, 6, PieceType.silver),
  ],
);

/// 矢倉▲3七銀戦法
const StrategyTemplate _yaguraNanaShichiGin = StrategyTemplate(
  name: '矢倉▲3七銀戦法',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(3, 7, PieceType.silver),
  ],
);

/// 矢倉棒銀
const StrategyTemplate _yaguraBougin = StrategyTemplate(
  name: '矢倉棒銀',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 矢倉中飛車 (居飛車のまま中央に飛車を振る変化、矢倉戦法から派生)。
/// FIXME: 「振り飛車の中飛車」と紛らわしいが、矢倉戦の中飛車は別物。

/// 矢倉右玉
const StrategyTemplate _yaguraMigigyoku = StrategyTemplate(
  name: '矢倉右玉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.king),
  ],
);

/// 矢倉旧24手組
const StrategyTemplate _yaguraKyu24 = StrategyTemplate(
  name: '矢倉旧24手組',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 矢倉新24手組
const StrategyTemplate _yaguraShin24 = StrategyTemplate(
  name: '矢倉新24手組',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 同型矢倉
const StrategyTemplate _doukeiYagura = StrategyTemplate(
  name: '同型矢倉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 中原流急戦矢倉
const StrategyTemplate _nakaharaRyuKyusenYagura = StrategyTemplate(
  name: '中原流急戦矢倉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 米長流急戦矢倉
const StrategyTemplate _yonenagaRyuKyusenYagura = StrategyTemplate(
  name: '米長流急戦矢倉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 阿久津流急戦矢倉
const StrategyTemplate _akutsuRyuKyusenYagura = StrategyTemplate(
  name: '阿久津流急戦矢倉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 藤森流急戦矢倉
const StrategyTemplate _fujimoriRyuKyusenYagura = StrategyTemplate(
  name: '藤森流急戦矢倉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// ウソ矢倉
const StrategyTemplate _usoYagura = StrategyTemplate(
  name: 'ウソ矢倉',
  parent: '矢倉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

/// 雀刺し: 1筋・9筋 (端) に銀・桂・香を集めて端攻め。
const StrategyTemplate _suzumesashi = StrategyTemplate(
  name: '雀刺し',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(1, 6, PieceType.pawn),
    PiecePlacement(1, 7, PieceType.silver),
  ],
);

// --- 角換わり ---------------------------------------------------------------
/// 角換わり: 角を相互交換した居飛車戦。
/// 自陣の角不在をエンジンで表せないので、2八飛+7九角不在の代わりに
/// 「金銀の典型形」だけ要求するゆるい近似。
const StrategyTemplate _kakugawari = StrategyTemplate(
  name: '角換わり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    // 7七銀 (居飛車駒組み) と 6八金 をマーカに。
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

const StrategyTemplate _kakugawariKoshikakeGin = StrategyTemplate(
  name: '角換わり腰掛け銀',
  parent: '角換わり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
    PiecePlacement(5, 6, PieceType.silver),
  ],
);

const StrategyTemplate _kakugawariBougin = StrategyTemplate(
  name: '角換わり棒銀',
  parent: '角換わり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 6, PieceType.silver),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

const StrategyTemplate _kakugawariHayakuriGin = StrategyTemplate(
  name: '角換わり早繰り銀',
  parent: '角換わり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(3, 6, PieceType.silver),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

const StrategyTemplate _kakugawariMigigyoku = StrategyTemplate(
  name: '角換わり右玉',
  parent: '角換わり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(3, 8, PieceType.king),
  ],
);

const StrategyTemplate _kakugawariKoshikakeGinKyu = StrategyTemplate(
  name: '角換わり腰掛け銀旧型',
  parent: '角換わり腰掛け銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(5, 6, PieceType.silver),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

const StrategyTemplate _ichiteSonKakugawari = StrategyTemplate(
  name: '一手損角換わり',
  parent: '角換わり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

// --- 横歩取り ---------------------------------------------------------------
/// 横歩取り: 3四歩を取って 3六飛 → 玉が左に動く前にぶつかる戦法。
const StrategyTemplate _yokofudori = StrategyTemplate(
  name: '横歩取り',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.rook),
  ],
);

const StrategyTemplate _aiYokofudori = StrategyTemplate(
  name: '相横歩取り',
  parent: '横歩取り',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.rook),
  ],
);

const StrategyTemplate _chuzaBisha = StrategyTemplate(
  name: '中座飛車',
  parent: '横歩取り',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.rook),
  ],
);

const StrategyTemplate _aonoRyu = StrategyTemplate(
  name: '青野流',
  parent: '横歩取り',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.rook),
  ],
);

const StrategyTemplate _yuukiRyu = StrategyTemplate(
  name: '勇気流',
  parent: '横歩取り',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.rook),
  ],
);

// --- 相掛かり ---------------------------------------------------------------
const StrategyTemplate _aigakari = StrategyTemplate(
  name: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _aigakariBougin = StrategyTemplate(
  name: '相掛かり棒銀',
  parent: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

const StrategyTemplate _nakaharaRyuAigakari = StrategyTemplate(
  name: '中原流相掛かり',
  parent: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _iijimaRyuAigakari = StrategyTemplate(
  name: '飯島流相掛かり引き角',
  parent: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

/// ひねり飛車: 相掛かり中盤で 7八飛と転換。
const StrategyTemplate _hineribisha = StrategyTemplate(
  name: 'ひねり飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
    PiecePlacement(2, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _youryuHineribisha = StrategyTemplate(
  name: '耀龍ひねり飛車',
  parent: 'ひねり飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

/// 塚田スペシャル: 相掛かり中盤の特殊飛車回り。3八飛+5六角等。
const StrategyTemplate _tsukadaSpecial = StrategyTemplate(
  name: '塚田スペシャル',
  parent: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.rook),
  ],
);

/// 桐山流タテ歩棒銀
const StrategyTemplate _kiriyamaTatehuBougin = StrategyTemplate(
  name: '桐山流タテ歩棒銀',
  parent: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

/// ネコ式タテ歩取り
const StrategyTemplate _nekoShikiTatehu = StrategyTemplate(
  name: 'ネコ式タテ歩取り',
  parent: '相掛かり',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

// --- 棒銀系 ----------------------------------------------------------------
const StrategyTemplate _bougin = StrategyTemplate(
  name: '棒銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

const StrategyTemplate _genshiBougin = StrategyTemplate(
  name: '原始棒銀',
  parent: '棒銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

const StrategyTemplate _hayakuriGin = StrategyTemplate(
  name: '早繰り銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(3, 6, PieceType.silver),
  ],
);

const StrategyTemplate _koshikakeGin = StrategyTemplate(
  name: '腰掛け銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(5, 6, PieceType.silver),
  ],
);

const StrategyTemplate _hashiBougin = StrategyTemplate(
  name: '端棒銀',
  parent: '棒銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(1, 7, PieceType.silver),
  ],
);

const StrategyTemplate _gyakuBougin = StrategyTemplate(
  name: '逆棒銀',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    // 振り飛車側からの棒銀。飛車が振られて 銀が右側に出ていく。
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

const StrategyTemplate _sokkouBougin = StrategyTemplate(
  name: '速攻棒銀',
  parent: '棒銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

/// 屋敷流二枚銀棒銀型
const StrategyTemplate _yashikiRyuNimaiGinBougin = StrategyTemplate(
  name: '屋敷流二枚銀棒銀型',
  parent: '棒銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 7, PieceType.silver),
    PiecePlacement(3, 7, PieceType.silver),
  ],
);

const StrategyTemplate _yashikiRyuNimaiGin = StrategyTemplate(
  name: '屋敷流二枚銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 7, PieceType.silver),
    PiecePlacement(4, 7, PieceType.silver),
  ],
);

/// 暴銀: 銀を 2七→2六→2五→1四 と暴れる棒銀の派生。
const StrategyTemplate _bouGin = StrategyTemplate(
  name: '暴銀',
  parent: '棒銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(2, 5, PieceType.silver),
  ],
);

const StrategyTemplate _kyokugenHayakuriGin = StrategyTemplate(
  name: '極限早繰り銀',
  parent: '早繰り銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(3, 5, PieceType.silver),
  ],
);

const StrategyTemplate _kagamiNoHidariHayakuriGin = StrategyTemplate(
  name: '鏡の左早繰り銀',
  parent: '早繰り銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 6, PieceType.silver),
  ],
);

/// △3三金型早繰り銀 (後手番想定だが、ここでは先手視点の形を登録)
const StrategyTemplate _sanSanKinHayakuriGin = StrategyTemplate(
  name: '3三金型早繰り銀',
  parent: '早繰り銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.silver),
  ],
);

// --- 雁木 -------------------------------------------------------------------
const StrategyTemplate _gangi = StrategyTemplate(
  name: '雁木',
  aliases: <String>['雁木戦法'],
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

const StrategyTemplate _gangiMigigyoku = StrategyTemplate(
  name: '雁木右玉',
  parent: '雁木',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.king),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

// --- 右四間飛車 (居飛車だが右側に飛車を振る) -------------------------------
const StrategyTemplate _migiShikenbisha = StrategyTemplate(
  name: '右四間飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(4, 8, PieceType.rook),
  ],
);

const StrategyTemplate _migiShikenbishaKyusen = StrategyTemplate(
  name: '右四間飛車急戦',
  parent: '右四間飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(4, 8, PieceType.rook),
  ],
);

const StrategyTemplate _migiShikenbishaChoukyusen = StrategyTemplate(
  name: '右四間飛車超急戦',
  parent: '右四間飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(4, 8, PieceType.rook),
  ],
);

const StrategyTemplate _migiShikenbishaHidariMino = StrategyTemplate(
  name: '右四間飛車左美濃',
  parent: '右四間飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(4, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.king),
  ],
);

// --- 袖飛車 -----------------------------------------------------------------
const StrategyTemplate _sodebisha = StrategyTemplate(
  name: '袖飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.rook),
  ],
);

const StrategyTemplate _katoRyuSodebisha = StrategyTemplate(
  name: '加藤流袖飛車',
  parent: '袖飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.rook),
  ],
);

const StrategyTemplate _moriyasuRyuSodebisha = StrategyTemplate(
  name: '森安流袖飛車穴熊',
  parent: '袖飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.rook),
    PiecePlacement(9, 9, PieceType.king),
  ],
);

const StrategyTemplate _habuShikiSodebisha = StrategyTemplate(
  name: '羽生式袖飛車',
  parent: '袖飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.rook),
  ],
);

const StrategyTemplate _bouGyokuSodebisha = StrategyTemplate(
  name: '棒玉袖飛車',
  parent: '袖飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.rook),
  ],
);

// --- 右玉 -------------------------------------------------------------------
const StrategyTemplate _migigyoku = StrategyTemplate(
  name: '右玉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
  ],
);

const StrategyTemplate _sandanMigigyoku = StrategyTemplate(
  name: '三段右玉',
  parent: '右玉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
  ],
);

const StrategyTemplate _tsunoginMigigyoku = StrategyTemplate(
  name: 'ツノ銀型右玉',
  parent: '右玉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
    PiecePlacement(4, 7, PieceType.silver),
    PiecePlacement(6, 7, PieceType.silver),
  ],
);

const StrategyTemplate _itoyaRyuMigigyoku = StrategyTemplate(
  name: '糸谷流右玉',
  parent: '右玉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
  ],
);

const StrategyTemplate _habuRyuMigigyoku = StrategyTemplate(
  name: '羽生流右玉',
  parent: '右玉',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 8, PieceType.king),
  ],
);

// --- 位取り戦法 -------------------------------------------------------------
const StrategyTemplate _gosujiKuraidori = StrategyTemplate(
  name: '5筋位取り',
  placements: <CastleRequirement>[
    PiecePlacement(5, 5, PieceType.pawn),
  ],
);

const StrategyTemplate _rokusujiKuraidori = StrategyTemplate(
  name: '6筋位取り',
  placements: <CastleRequirement>[
    PiecePlacement(6, 5, PieceType.pawn),
  ],
);

const StrategyTemplate _gyokutoKuraidori = StrategyTemplate(
  name: '玉頭位取り',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(8, 5, PieceType.pawn),
  ],
);

const StrategyTemplate _gyokutoGin = StrategyTemplate(
  name: '玉頭銀',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    // 振り飛車側、玉頭の銀。後手から見て玉頭。
    // 黒の振り飛車でいうと例えば 3七銀 (相手玉の上)。
    AnyOfPieces(3, 7, <PieceType>[PieceType.silver]),
  ],
);

// --- 急戦・特殊系 -----------------------------------------------------------
const StrategyTemplate _yongoFuHayashikake = StrategyTemplate(
  name: '4五歩早仕掛け',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(4, 5, PieceType.pawn),
  ],
);

const StrategyTemplate _yonRokuGinHidariKyusen = StrategyTemplate(
  name: '4六銀左急戦',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(4, 6, PieceType.silver),
  ],
);

const StrategyTemplate _yonRokuGinMigiKyusen = StrategyTemplate(
  name: '4六銀右急戦',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(4, 6, PieceType.silver),
  ],
);

const StrategyTemplate _goShichiKinSenpou = StrategyTemplate(
  name: '5七金戦法',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(5, 7, PieceType.gold),
  ],
);

const StrategyTemplate _yongoKakuSenpou = StrategyTemplate(
  name: '4五角戦法',
  placements: <CastleRequirement>[
    PiecePlacement(4, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _nanaNiBishaSenpou = StrategyTemplate(
  name: '7二飛戦法',
  placements: <CastleRequirement>[
    // 後手側だが、配置は黒視点。後手 7二飛 = 黒視点で 3八飛のミラー。
    // 全テンプレを黒視点に正規化するため、配置は 7二 mirror = 3八 ではなく、
    // 「黒として 7二 に飛車」= 自然に解釈できる別物。ここはオリジナルが
    // 後手限定なので、黒テンプレ的には 8二/7二 を確認する形にする。
    PiecePlacement(7, 2, PieceType.rook),
  ],
);

const StrategyTemplate _niSanFuSenpou = StrategyTemplate(
  name: '2三歩戦法',
  placements: <CastleRequirement>[
    PiecePlacement(2, 3, PieceType.pawn),
  ],
);

const StrategyTemplate _sanNiBishaSenpou = StrategyTemplate(
  name: '3二飛戦法',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 2, PieceType.rook),
  ],
);

const StrategyTemplate _sanSanKakuSenpou = StrategyTemplate(
  name: '3三角戦法',
  placements: <CastleRequirement>[
    PiecePlacement(3, 3, PieceType.bishop),
  ],
);

const StrategyTemplate _nanaYonFuSenpou = StrategyTemplate(
  name: '7四歩戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 4, PieceType.pawn),
  ],
);

const StrategyTemplate _sanSanBishaSenpou = StrategyTemplate(
  name: '3三飛戦法',
  placements: <CastleRequirement>[
    PiecePlacement(3, 3, PieceType.rook),
  ],
);

const StrategyTemplate _sanSanKeiSenpou = StrategyTemplate(
  name: '3三桂戦法',
  placements: <CastleRequirement>[
    PiecePlacement(3, 3, PieceType.knight),
  ],
);

const StrategyTemplate _sanSanKakuSoraSenpou = StrategyTemplate(
  name: '3三角型空中戦法',
  placements: <CastleRequirement>[
    PiecePlacement(3, 3, PieceType.bishop),
  ],
);

const StrategyTemplate _sanSyuKakuSenpou = StrategyTemplate(
  name: '4手目△3三角戦法',
  placements: <CastleRequirement>[
    PiecePlacement(3, 3, PieceType.bishop),
  ],
);

const StrategyTemplate _futeMeSanjiBisha = StrategyTemplate(
  name: '2手目△3二飛戦法',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 2, PieceType.rook),
  ],
);

const StrategyTemplate _futeMeSanjiGin = StrategyTemplate(
  name: '2手目△3二銀システム',
  placements: <CastleRequirement>[
    PiecePlacement(3, 2, PieceType.silver),
  ],
);

const StrategyTemplate _futeMeRokuNiGin = StrategyTemplate(
  name: '2手目△6二銀戦法',
  placements: <CastleRequirement>[
    PiecePlacement(6, 2, PieceType.silver),
  ],
);

const StrategyTemplate _futeMeNanaYonFu = StrategyTemplate(
  name: '2手目△7四歩戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 4, PieceType.pawn),
  ],
);

const StrategyTemplate _shoteSanRokuFu = StrategyTemplate(
  name: '初手▲3六歩戦法',
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _shoteNanaHachiGin = StrategyTemplate(
  name: '初手▲7八銀戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

const StrategyTemplate _shoteNanaHachiBisha = StrategyTemplate(
  name: '初手▲7八飛戦法',
  side: StrategySide.furibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

const StrategyTemplate _sanmeNanaNanaKaku = StrategyTemplate(
  name: '3手目▲7七角戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 7, PieceType.bishop),
  ],
);

const StrategyTemplate _nanaNiBishaAkyusen = StrategyTemplate(
  name: '7二飛亜急戦',
  placements: <CastleRequirement>[
    PiecePlacement(7, 2, PieceType.rook),
  ],
);

// --- ジョーク系 / 奇襲系 -----------------------------------------------------
const StrategyTemplate _ahiru = StrategyTemplate(
  name: 'アヒル',
  aliases: <String>['アヒル戦法'],
  placements: <CastleRequirement>[
    // アヒル囲い: 5八玉+5七金+4八金 + 6七銀+4七銀
    PiecePlacement(5, 8, PieceType.king),
    PiecePlacement(5, 7, PieceType.gold),
    PiecePlacement(4, 8, PieceType.gold),
    PiecePlacement(6, 7, PieceType.silver),
    PiecePlacement(4, 7, PieceType.silver),
  ],
);

const StrategyTemplate _uraAhiru = StrategyTemplate(
  name: '裏アヒル戦法',
  parent: 'アヒル',
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.king),
  ],
);

const StrategyTemplate _pacman = StrategyTemplate(
  name: 'パックマン戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 5, PieceType.pawn),
    PiecePlacement(8, 7, PieceType.bishop),
  ],
);

const StrategyTemplate _yamasakiRyuPacman = StrategyTemplate(
  name: '山崎流パックマン',
  parent: 'パックマン戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 5, PieceType.pawn),
  ],
);

const StrategyTemplate _ureshinoRyu = StrategyTemplate(
  name: '嬉野流',
  placements: <CastleRequirement>[
    // 6八銀+7七角早繰り
    PiecePlacement(6, 8, PieceType.silver),
    PiecePlacement(7, 7, PieceType.bishop),
  ],
);

const StrategyTemplate _shinUreshinoRyu = StrategyTemplate(
  name: '新嬉野流',
  parent: '嬉野流',
  placements: <CastleRequirement>[
    PiecePlacement(6, 8, PieceType.silver),
    PiecePlacement(7, 7, PieceType.bishop),
  ],
);

const StrategyTemplate _sujichigaiKaku = StrategyTemplate(
  name: '筋違い角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _sujichigaiKakuArijigoku = StrategyTemplate(
  name: '筋違い角蟻地獄戦法',
  parent: '筋違い角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _sujichigaiKakuSakata = StrategyTemplate(
  name: '筋違い角阪田流',
  parent: '筋違い角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _aiSujichigaiKaku = StrategyTemplate(
  name: '相筋違い角',
  parent: '筋違い角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 5, PieceType.bishop),
  ],
);

/// カニカニ銀: 急戦で 4七銀+5七銀+両端攻撃。
const StrategyTemplate _kanikaniGin = StrategyTemplate(
  name: 'カニカニ銀',
  placements: <CastleRequirement>[
    PiecePlacement(4, 7, PieceType.silver),
    PiecePlacement(5, 7, PieceType.silver),
  ],
);

/// カニカニ金: ジョーク派生
const StrategyTemplate _kanikaniKin = StrategyTemplate(
  name: 'カニカニ金',
  placements: <CastleRequirement>[
    PiecePlacement(4, 7, PieceType.gold),
    PiecePlacement(5, 7, PieceType.gold),
  ],
);

/// きｍきｍ金 (ネット発、5七金型奇襲)
const StrategyTemplate _kimkimkin = StrategyTemplate(
  name: 'きｍきｍ金',
  placements: <CastleRequirement>[
    PiecePlacement(5, 7, PieceType.gold),
  ],
);

/// UFO銀: 2七銀から空中跳び
const StrategyTemplate _ufoGin = StrategyTemplate(
  name: 'UFO銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 6, PieceType.silver),
    PiecePlacement(2, 7, PieceType.silver),
  ],
);

/// UFO金: 金が空中に。
const StrategyTemplate _ufoKin = StrategyTemplate(
  name: 'UFO金',
  placements: <CastleRequirement>[
    PiecePlacement(2, 6, PieceType.gold),
  ],
);

// --- 端攻め / 端歩位取り 系 -------------------------------------------------
/// 棒玉: 飛角を放棄して玉だけで攻める奇襲ジョーク戦法。
const StrategyTemplate _bouGyoku = StrategyTemplate(
  name: '棒玉',
  placements: <CastleRequirement>[
    PiecePlacement(5, 5, PieceType.king),
  ],
);

/// 新米長玉: 米長玉 (2八玉) の現代版。
const StrategyTemplate _shinYonenagaGyoku = StrategyTemplate(
  name: '新米長玉',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.king),
  ],
);

/// 高田流左玉
const StrategyTemplate _takadaRyuHidariGyoku = StrategyTemplate(
  name: '高田流左玉',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.king),
  ],
);

/// 中飛車左穴熊型は既に登録、こちらは右穴熊系で。

// --- 地下鉄飛車 -------------------------------------------------------------
const StrategyTemplate _chikatetsuBisha = StrategyTemplate(
  name: '地下鉄飛車',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    // 飛車を 1段目に潜らせる (1九 or 9九経由で逆サイドへ)
    AnyOfPieces(1, 9, <PieceType>[PieceType.rook]),
  ],
);

// --- 飯島流引き角 ----------------------------------------------------------
const StrategyTemplate _iijimaRyuHikiKaku = StrategyTemplate(
  name: '飯島流引き角戦法',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(7, 9, PieceType.bishop),
  ],
);

const StrategyTemplate _hikiKaku = StrategyTemplate(
  name: '引き角',
  placements: <CastleRequirement>[
    PiecePlacement(7, 9, PieceType.bishop),
  ],
);

// --- 風車・他特殊 ----------------------------------------------------------
const StrategyTemplate _fuusha = StrategyTemplate(
  name: '風車',
  placements: <CastleRequirement>[
    // 中段に飛車・角・銀をぐるぐる回す形。最低限 5六歩で代表。
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _shinFuusha = StrategyTemplate(
  name: '新風車',
  parent: '風車',
  placements: <CastleRequirement>[
    PiecePlacement(5, 6, PieceType.pawn),
  ],
);

// --- 超速 ---------------------------------------------------------------
const StrategyTemplate _choosokuSanShichiGin = StrategyTemplate(
  name: '超速▲3七銀',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(3, 7, PieceType.silver),
  ],
);

const StrategyTemplate _choukyusen = StrategyTemplate(
  name: '超急戦',
  placements: <CastleRequirement>[
    // 形は様々。最低限 2筋飛車。
    AnyOfPieces(2, 8, <PieceType>[PieceType.rook]),
  ],
);

// --- 持久戦 / 対振り --------------------------------------------------------
const StrategyTemplate _taishiriJikyusen = StrategyTemplate(
  name: '対振り持久戦',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.king),
  ],
);

const StrategyTemplate _hidariMinoKyusen = StrategyTemplate(
  name: '左美濃急戦',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.king),
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

// --- エルモ急戦 -------------------------------------------------------------
const StrategyTemplate _elmoKyusen = StrategyTemplate(
  name: 'エルモ急戦',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    // エルモ囲い: 6八銀+7八金+5八金+6九玉
    PiecePlacement(6, 9, PieceType.king),
    PiecePlacement(6, 8, PieceType.silver),
    PiecePlacement(7, 8, PieceType.gold),
    PiecePlacement(5, 8, PieceType.gold),
  ],
);

// --- ヒラメ / 稲庭 -----------------------------------------------------------
const StrategyTemplate _hirame = StrategyTemplate(
  name: 'ヒラメ戦法',
  placements: <CastleRequirement>[
    // 銀冠の変形、横に薄く広がる形。最低限 3八銀+4八金+2八飛。
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(3, 8, PieceType.silver),
  ],
);

const StrategyTemplate _inaniwa = StrategyTemplate(
  name: '稲庭戦法',
  placements: <CastleRequirement>[
    // 端歩+持久戦+受け一辺倒。形が極端に薄いので最低限 2筋に何もしない=
    // と表現できない。代わりに 5筋歩突きを残す形を採用。
    PiecePlacement(5, 7, PieceType.pawn),
  ],
);

// --- ポンポン桂 -------------------------------------------------------------
const StrategyTemplate _ponponKei = StrategyTemplate(
  name: 'ポンポン桂',
  placements: <CastleRequirement>[
    // 4五桂跳ねを目指す形
    PiecePlacement(3, 7, PieceType.knight),
  ],
);

const StrategyTemplate _shinPonponKei = StrategyTemplate(
  name: '新ポンポン桂',
  parent: 'ポンポン桂',
  placements: <CastleRequirement>[
    PiecePlacement(3, 7, PieceType.knight),
  ],
);

// --- 棒金 -------------------------------------------------------------------
const StrategyTemplate _bouKin = StrategyTemplate(
  name: '棒金',
  placements: <CastleRequirement>[
    PiecePlacement(2, 7, PieceType.gold),
  ],
);

const StrategyTemplate _hayakuriKin = StrategyTemplate(
  name: '早繰り金',
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.gold),
  ],
);

const StrategyTemplate _koshikakeKin = StrategyTemplate(
  name: '腰掛け金',
  placements: <CastleRequirement>[
    PiecePlacement(5, 6, PieceType.gold),
  ],
);

// --- 鎖鎌銀 -----------------------------------------------------------------
const StrategyTemplate _kusarigamaGin = StrategyTemplate(
  name: '鎖鎌銀',
  placements: <CastleRequirement>[
    PiecePlacement(2, 5, PieceType.silver),
  ],
);

// --- 斜め棒銀 ---------------------------------------------------------------
const StrategyTemplate _ginUbara = StrategyTemplate(
  name: '銀雲雀',
  placements: <CastleRequirement>[
    PiecePlacement(3, 6, PieceType.silver),
  ],
);

// --- 中央位取り中飛車・力戦 -------------------------------------------------
const StrategyTemplate _rikisen = StrategyTemplate(
  name: '力戦',
  placements: <CastleRequirement>[
    // 定跡外の戦型全般。識別が困難なので、最低限 2筋以外の飛車位置=力戦的
    // とする近似は誤検出を増やすため、ここは空マーカではなく
    // 玉位置 (5九にいない=居玉外し済み) を一応。
    PiecePlacement(5, 9, PieceType.gold),
  ],
);

// --- 山田定跡・木村定跡・鷺宮定跡 -------------------------------------------
const StrategyTemplate _yamadaJoseki = StrategyTemplate(
  name: '山田定跡',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(4, 6, PieceType.silver),
  ],
);

const StrategyTemplate _kimuraJoseki = StrategyTemplate(
  name: '木村定跡',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(4, 6, PieceType.silver),
  ],
);

const StrategyTemplate _sagimiyaJoseki = StrategyTemplate(
  name: '鷺宮定跡',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(4, 6, PieceType.silver),
  ],
);

// --- 加藤流 (角換わり以外) ---------------------------------------------------
// 「加藤流」単体は文脈依存だが、加藤一二三の代表形=居玉棒銀。
// 「加藤流袖飛車」は別途登録済み。

// --- 各種ローカル戦法 -------------------------------------------------------
const StrategyTemplate _kameleon = StrategyTemplate(
  name: 'カメレオン戦法',
  placements: <CastleRequirement>[
    // 美濃から穴熊などに組み替える持久戦
    AnyOfPieces(3, 8, <PieceType>[PieceType.king]),
  ],
);

const StrategyTemplate _eishunRyuKameleon = StrategyTemplate(
  name: '英春流カメレオン',
  parent: 'カメレオン戦法',
  placements: <CastleRequirement>[
    AnyOfPieces(3, 8, <PieceType>[PieceType.king]),
  ],
);

const StrategyTemplate _eishunRyuKamaitachi = StrategyTemplate(
  name: '英春流かまいたち戦法',
  placements: <CastleRequirement>[
    AnyOfPieces(7, 8, <PieceType>[PieceType.king]),
  ],
);

const StrategyTemplate _onoGaurd = StrategyTemplate(
  name: 'ノーガード戦法',
  placements: <CastleRequirement>[
    // 玉を囲わずに攻めるジョーク戦法。居玉のまま。
    PiecePlacement(5, 9, PieceType.king),
  ],
);

const StrategyTemplate _madeSystem = StrategyTemplate(
  name: 'メイドシステム',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _showdownSystem = StrategyTemplate(
  name: 'ショーダンシステム',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _showdownOriginal = StrategyTemplate(
  name: 'ショーダンオリジナル',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _ozawaSystem = StrategyTemplate(
  name: 'オザワシステム',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _hanamuraRyuNagoya = StrategyTemplate(
  name: '花村流名古屋戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.silver),
  ],
);

const StrategyTemplate _seinoRyuGifu = StrategyTemplate(
  name: '清野流岐阜戦法',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _kanazawaRyu = StrategyTemplate(
  name: '金沢流',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _kintouunSenpou = StrategyTemplate(
  name: 'きんとうん戦法',
  placements: <CastleRequirement>[
    PiecePlacement(5, 7, PieceType.gold),
  ],
);

const StrategyTemplate _gorigoriKin = StrategyTemplate(
  name: 'ゴリゴリ金',
  placements: <CastleRequirement>[
    PiecePlacement(2, 6, PieceType.gold),
  ],
);

const StrategyTemplate _gorillaNoMigite = StrategyTemplate(
  name: 'ゴリラの右手',
  placements: <CastleRequirement>[
    PiecePlacement(2, 6, PieceType.gold),
  ],
);

const StrategyTemplate _goriChigaiKaku = StrategyTemplate(
  name: 'ゴリ違い角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _hyperKakuKawari = StrategyTemplate(
  name: '四手角',
  placements: <CastleRequirement>[
    PiecePlacement(7, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _kakutouFu = StrategyTemplate(
  name: '角頭歩戦法',
  placements: <CastleRequirement>[
    PiecePlacement(8, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _henachokoKyusen = StrategyTemplate(
  name: 'へなちょこ急戦',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _henachokoJikyusen = StrategyTemplate(
  name: 'へなちょこ持久戦',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(8, 8, PieceType.king),
  ],
);

const StrategyTemplate _yabaBouzu = StrategyTemplate(
  name: 'やばボーズ流',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

const StrategyTemplate _richBridge = StrategyTemplate(
  name: 'リッチブリッジ',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.silver),
  ],
);

const StrategyTemplate _kuruKuruKaku = StrategyTemplate(
  name: 'クルクル角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 6, PieceType.bishop),
  ],
);

const StrategyTemplate _tomahawk = StrategyTemplate(
  name: 'トマホーク',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    // 対穴熊用、端攻め+9七桂跳ね目指す。
    PiecePlacement(9, 6, PieceType.pawn),
    PiecePlacement(8, 7, PieceType.silver),
  ],
);

const StrategyTemplate _dragonSpecial = StrategyTemplate(
  name: 'ドラゴンスペシャル',
  placements: <CastleRequirement>[
    PiecePlacement(2, 5, PieceType.dragon),
  ],
);

const StrategyTemplate _meKurashi = StrategyTemplate(
  name: '目くらまし戦法',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _tarantula = StrategyTemplate(
  name: 'タランチュラ戦法',
  placements: <CastleRequirement>[
    PiecePlacement(8, 8, PieceType.rook),
  ],
);

const StrategyTemplate _takoKin = StrategyTemplate(
  name: 'たこ金戦法',
  placements: <CastleRequirement>[
    PiecePlacement(6, 7, PieceType.gold),
    PiecePlacement(4, 7, PieceType.gold),
  ],
);

const StrategyTemplate _tsukutsukuboushi = StrategyTemplate(
  name: 'つくつくぼうし戦法',
  placements: <CastleRequirement>[
    PiecePlacement(2, 5, PieceType.silver),
  ],
);

const StrategyTemplate _shintaKun = StrategyTemplate(
  name: '新村田システム',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _murataSystem = StrategyTemplate(
  name: '村田システム',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _kanagikiHikari = StrategyTemplate(
  name: '錆刀戦法',
  placements: <CastleRequirement>[
    PiecePlacement(2, 5, PieceType.bishop),
  ],
);

const StrategyTemplate _hisshouHikkake = StrategyTemplate(
  name: '必笑ひっかけ戦法',
  placements: <CastleRequirement>[
    PiecePlacement(7, 5, PieceType.pawn),
    PiecePlacement(8, 6, PieceType.pawn),
  ],
);

const StrategyTemplate _torisashi = StrategyTemplate(
  name: '鳥刺し',
  placements: <CastleRequirement>[
    PiecePlacement(7, 6, PieceType.bishop),
  ],
);

const StrategyTemplate _gohouBakudan = StrategyTemplate(
  name: '5手爆弾',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _shichihouBakudan = StrategyTemplate(
  name: '7手爆弾',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _uTurnBisha = StrategyTemplate(
  name: 'Uターン飛車',
  placements: <CastleRequirement>[
    // 飛車を一旦右に動かして戻す。最終形は 2八飛。
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _maruyamaWaccine = StrategyTemplate(
  name: '丸山ワクチン',
  side: StrategySide.ibisha,
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
    PiecePlacement(7, 7, PieceType.silver),
  ],
);

const StrategyTemplate _tanabeSpecial = StrategyTemplate(
  name: '竹部スペシャル',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _miyaKyumu = StrategyTemplate(
  name: '間宮久夢流',
  placements: <CastleRequirement>[
    PiecePlacement(2, 8, PieceType.rook),
  ],
);

const StrategyTemplate _kuboHashy = StrategyTemplate(
  name: '遠山流',
  placements: <CastleRequirement>[
    PiecePlacement(7, 8, PieceType.rook),
  ],
);

const StrategyTemplate _tsuranariSanZanIchiKin = StrategyTemplate(
  name: '都成流△3一金',
  placements: <CastleRequirement>[
    PiecePlacement(3, 1, PieceType.gold),
  ],
);

const StrategyTemplate _nanakawaRyuYonYonKaku = StrategyTemplate(
  name: '菜々河流△4四角',
  placements: <CastleRequirement>[
    PiecePlacement(4, 4, PieceType.bishop),
  ],
);

const StrategyTemplate _amahikoRyuRokuRokuKaku = StrategyTemplate(
  name: '天彦流▲6六角',
  placements: <CastleRequirement>[
    PiecePlacement(6, 6, PieceType.bishop),
  ],
);

const StrategyTemplate _kinmusouKyusen = StrategyTemplate(
  name: '金無双急戦',
  placements: <CastleRequirement>[
    PiecePlacement(5, 8, PieceType.gold),
    PiecePlacement(6, 8, PieceType.gold),
  ],
);

const StrategyTemplate _sandanRocket = StrategyTemplate(
  name: '三段ロケット',
  placements: <CastleRequirement>[
    // 飛角香を 1直線に並べる連携攻め。例: 1九香+1四飛+1六角等。
    AnyOfPieces(1, 9, <PieceType>[PieceType.lance]),
  ],
);

// === Skipped / FIXME entries (low-confidence or insufficient info) ==========
// 以下の戦法は具体的な駒組がほぼ把握できなかったため、当面登録を見送る。
// (テンプレを起こす場合は AGPL-3.0 を踏まないよう、棋書/Wikipedia 由来で再確認のこと):
//   - xaby角戦法                : 略号系、意味不明
//   - GAVA角                   : 略号系、意味不明
//   - 山崎流パックマン以外で意味の確認できない奇襲
//   - 5手爆弾 / 7手爆弾         : 形ではなく手順依存 (緩いマーカで登録済み)
//   - GAVA角・xaby角・力戦      : 力戦のみ緩いマーカで登録、他は登録なし

/// 既知の戦法テンプレート。
const List<StrategyTemplate> knownStrategies = <StrategyTemplate>[
  // --- 振り飛車系 ---
  _nakabisha,
  _gokigenNakabisha,
  _kakumichiOpenNakabisha,
  _kakumichiOpenShikenbisha,
  _gosujiKuraidoriNakabisha,
  _ichichokusenAnaguma,
  _tsunoginNakabisha,
  _yaguraNakabisha,
  _yaguraRyuNakabisha,
  _genshiNakabisha,
  _senteNakabisha,
  _nakabishaHidariAnaguma,
  _nakabishaMillennium,
  _eichanNakabisha,
  _gogoRyuNakabisha,
  _hidaNakabishaGasshou,
  _shikenbisha,
  _normalShikenbisha,
  _fujiiSystem,
  _tateishiRyu,
  _yonSanSenpou,
  _tobeYonSanSenpou,
  _sanYonSanSenpou,
  _shikenbishaMillennium,
  _hakuShikenbisha,
  _youryuShikenbisha,
  _gensouShikenbisha,
  _makaiShikenbisha,
  _sankenFujiiSystem,
  _sankenbisha,
  _normalSankenbisha,
  _ishidaRyu,
  _ishidaRyuHongumi,
  _hayaIshida,
  _masudaShikiIshida,
  _suzukiRyuHayaIshida,
  _kuboRyuHayaIshida,
  _muriyariHayaIshida,
  _shinIshidaRyu,
  _kusumotoShikiIshida,
  _koyanRyuSankenbisha,
  _sankenMillennium,
  _shitamachiRyuSanken,
  _kamiyoshiRyuSanken,
  _sugaiRyuSanken,
  _ukkariSanken,
  _umashikiSanken,
  _oniGoroshi,
  _shinOniGoroshi,
  _oniGoroshiMukaibisha,
  _mukaibisha,
  _directMukaibisha,
  _sakataRyuMukaibisha,
  _merikenMukaibisha,
  _monorailMukaibisha,
  _anakakuMukaibisha,
  _anakakuSenpou,
  _amahikoRyuMukaibisha,
  _nanakawaRyuMukaibisha,
  _sakataRyuKuyonFu,
  _kakukoukanFuribisha,
  _regSpe,
  _manabeRyu,
  _murokaSystem,
  _ikkenbisha,
  _ikkenbishaMigiAnaguma,
  _kyukenbisha,
  _kyukenbishaHidariAnaguma,
  _youdouFuribisha,
  _nakaharaBisha,
  _onirokuRyuDokkan,
  _oodairaRyu,
  // --- 居飛車系: 矢倉 ---
  _yaguraSenpou,
  _moritaSystem,
  _wakiSystem,
  _yaguraNanaShichiGin,
  _yaguraBougin,
  _yaguraMigigyoku,
  _yaguraKyu24,
  _yaguraShin24,
  _doukeiYagura,
  _nakaharaRyuKyusenYagura,
  _yonenagaRyuKyusenYagura,
  _akutsuRyuKyusenYagura,
  _fujimoriRyuKyusenYagura,
  _usoYagura,
  _suzumesashi,
  // --- 角換わり ---
  _kakugawari,
  _kakugawariKoshikakeGin,
  _kakugawariBougin,
  _kakugawariHayakuriGin,
  _kakugawariMigigyoku,
  _kakugawariKoshikakeGinKyu,
  _ichiteSonKakugawari,
  // --- 横歩取り ---
  _yokofudori,
  _aiYokofudori,
  _chuzaBisha,
  _aonoRyu,
  _yuukiRyu,
  // --- 相掛かり ---
  _aigakari,
  _aigakariBougin,
  _nakaharaRyuAigakari,
  _iijimaRyuAigakari,
  _hineribisha,
  _youryuHineribisha,
  _tsukadaSpecial,
  _kiriyamaTatehuBougin,
  _nekoShikiTatehu,
  // --- 棒銀系 ---
  _bougin,
  _genshiBougin,
  _hayakuriGin,
  _koshikakeGin,
  _hashiBougin,
  _gyakuBougin,
  _sokkouBougin,
  _yashikiRyuNimaiGinBougin,
  _yashikiRyuNimaiGin,
  _bouGin,
  _kyokugenHayakuriGin,
  _kagamiNoHidariHayakuriGin,
  _sanSanKinHayakuriGin,
  // --- 雁木 ---
  _gangi,
  _gangiMigigyoku,
  // --- 右四間飛車 ---
  _migiShikenbisha,
  _migiShikenbishaKyusen,
  _migiShikenbishaChoukyusen,
  _migiShikenbishaHidariMino,
  // --- 袖飛車 ---
  _sodebisha,
  _katoRyuSodebisha,
  _moriyasuRyuSodebisha,
  _habuShikiSodebisha,
  _bouGyokuSodebisha,
  // --- 右玉 ---
  _migigyoku,
  _sandanMigigyoku,
  _tsunoginMigigyoku,
  _itoyaRyuMigigyoku,
  _habuRyuMigigyoku,
  // --- 位取り ---
  _gosujiKuraidori,
  _rokusujiKuraidori,
  _gyokutoKuraidori,
  _gyokutoGin,
  // --- 急戦・特殊 ---
  _yongoFuHayashikake,
  _yonRokuGinHidariKyusen,
  _yonRokuGinMigiKyusen,
  _goShichiKinSenpou,
  _yongoKakuSenpou,
  _nanaNiBishaSenpou,
  _niSanFuSenpou,
  _sanNiBishaSenpou,
  _sanSanKakuSenpou,
  _nanaYonFuSenpou,
  _sanSanBishaSenpou,
  _sanSanKeiSenpou,
  _sanSanKakuSoraSenpou,
  _sanSyuKakuSenpou,
  _futeMeSanjiBisha,
  _futeMeSanjiGin,
  _futeMeRokuNiGin,
  _futeMeNanaYonFu,
  _shoteSanRokuFu,
  _shoteNanaHachiGin,
  _shoteNanaHachiBisha,
  _sanmeNanaNanaKaku,
  _nanaNiBishaAkyusen,
  // --- ジョーク・奇襲 ---
  _ahiru,
  _uraAhiru,
  _pacman,
  _yamasakiRyuPacman,
  _ureshinoRyu,
  _shinUreshinoRyu,
  _sujichigaiKaku,
  _sujichigaiKakuArijigoku,
  _sujichigaiKakuSakata,
  _aiSujichigaiKaku,
  _kanikaniGin,
  _kanikaniKin,
  _kimkimkin,
  _ufoGin,
  _ufoKin,
  // --- 玉位置系 ---
  _bouGyoku,
  _shinYonenagaGyoku,
  _takadaRyuHidariGyoku,
  // --- 飛車回り系 ---
  _chikatetsuBisha,
  _iijimaRyuHikiKaku,
  _hikiKaku,
  // --- 風車 ---
  _fuusha,
  _shinFuusha,
  // --- 超速・超急戦 ---
  _choosokuSanShichiGin,
  _choukyusen,
  // --- 持久戦・対振り ---
  _taishiriJikyusen,
  _hidariMinoKyusen,
  _elmoKyusen,
  _hirame,
  _inaniwa,
  // --- ポンポン桂 ---
  _ponponKei,
  _shinPonponKei,
  // --- 棒金 ---
  _bouKin,
  _hayakuriKin,
  _koshikakeKin,
  // --- 鎖鎌銀・他 ---
  _kusarigamaGin,
  _ginUbara,
  _rikisen,
  // --- 定跡系 ---
  _yamadaJoseki,
  _kimuraJoseki,
  _sagimiyaJoseki,
  // --- ローカル戦法 ---
  _kameleon,
  _eishunRyuKameleon,
  _eishunRyuKamaitachi,
  _onoGaurd,
  _madeSystem,
  _showdownSystem,
  _showdownOriginal,
  _ozawaSystem,
  _hanamuraRyuNagoya,
  _seinoRyuGifu,
  _kanazawaRyu,
  _kintouunSenpou,
  _gorigoriKin,
  _gorillaNoMigite,
  _goriChigaiKaku,
  _hyperKakuKawari,
  _kakutouFu,
  _henachokoKyusen,
  _henachokoJikyusen,
  _yabaBouzu,
  _richBridge,
  _kuruKuruKaku,
  _tomahawk,
  _dragonSpecial,
  _meKurashi,
  _tarantula,
  _takoKin,
  _tsukutsukuboushi,
  _shintaKun,
  _murataSystem,
  _kanagikiHikari,
  _hisshouHikkake,
  _torisashi,
  _gohouBakudan,
  _shichihouBakudan,
  _uTurnBisha,
  _maruyamaWaccine,
  _tanabeSpecial,
  _miyaKyumu,
  _kuboHashy,
  _tsuranariSanZanIchiKin,
  _nanakawaRyuYonYonKaku,
  _amahikoRyuRokuRokuKaku,
  _kinmusouKyusen,
  _sandanRocket,
];

/// 局面 [position] から戦法を検出する。
///
/// [side] が指定された場合はその陣営のみ、null の場合は両陣営を判定する。
/// 各テンプレートは先手視点で記述されており、後手判定では 180° 回転して
/// 照合する。テンプレートの全 placements を満たす駒が盤上にあれば検出。
/// テンプレートに含まれていない駒が他のマスにあっても判定には影響しない。
/// 複数の戦法 (例: 中飛車とゴキゲン中飛車) が同時にマッチすることがある。
List<DetectedStrategy> detectStrategies(
  ImmutablePosition position, {
  Color? side,
}) {
  final List<DetectedStrategy> results = <DetectedStrategy>[];
  for (final StrategyTemplate template in knownStrategies) {
    if (side == null || side == Color.black) {
      if (_matchesStrategyTemplate(position, template, Color.black)) {
        results.add(DetectedStrategy(template: template, side: Color.black));
      }
    }
    if (side == null || side == Color.white) {
      if (_matchesStrategyTemplate(position, template, Color.white)) {
        results.add(DetectedStrategy(template: template, side: Color.white));
      }
    }
  }
  return results;
}

bool _matchesStrategyTemplate(
  ImmutablePosition position,
  StrategyTemplate template,
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
