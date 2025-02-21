const cryptoList = [
  ...lowVolatilityCrypto,
  ...mediumVolatilityCrypto,
  ...highVolatilityCrypto,
];

const highVolatilityCrypto = [
  // Мемкоины (высокая волатильность)
  "DOGEUSDT", "SHIBUSDT", "PEPEUSDT", "FLOKIUSDT", "1000CATUSDT",
  "WIFUSDT", "BONKUSDT", "TURBOUSDT", "MEMEUSDT", "BOMEUSDT", // Replaced BABYDOGEUSDT
  "MEWUSDT", // Replaced FOMOUSDT (Cat in a Dog’s World, listed on Binance)
  "POPCATUSDT", // Replaced ELONUSDT (Popcat, trending meme coin)
  "BRETTUSDT", // Replaced KISHUUSDT (new meme coin on Binance)
  "NOTUSDT", // Replaced SAFEMOONUSDT (Notcoin, high volatility)
  "PONKEUSDT", // Replaced HUSKYUSDT (trending Solana meme coin)

  // Новые и трендовые монеты
  "SUIUSDT", "APTUSDT", "C98USDT", "DYDXUSDT", "ORDIUSDT",
  "INJUSDT", "SEIUSDT", "TIAUSDT", "MINAUSDT", "KASUSDT",
  "TAOUSDT", "ZETAUSDT", "JUPUSDT", "WLDUSDT", "PORTALUSDT",
  "PIXELUSDT", "ALTUSDT", "XAIUSDT", "STRKUSDT", "RONINUSDT",
  "BEAMUSDT", "ACEUSDT", "MAVUSDT", "IDUSDT", "CYBERUSDT",
  "TRUMPUSDT"

      // Социальные токены и Web3
      "MAGICUSDT", // Replaced  (Magic, Web3-related)
  "HOOKUSDT", "GALUSDT", // Replaced LADYSUSDT (Galxe, social/Web3)
  "RAREUSDT", // Replaced  (SuperRare, NFT/Web3)
  "API3USDT", "EDUUSDT", // Replaced UFOUSDT (EDU from Open Campus)
  "SOCUSDT", "CHESSUSDT", "VRAUSDT", "COTIUSDT",
  "GMRUSDT"

      // Метавселенные и NFT (часто волатильные)
      "GALAUSDT",
  "IMXUSDT",
  "APEUSDT",
  "FLOWUSDT",
  "SFPUSDT",
  "BLURUSDT", "MAVIAUSDT", "TVKUSDT", "SLPUSDT", "ALICEUSDT",
  "DGUSDT", "ERNUSDT", "YGGUSDT", "ILVUSDT", "COMBOUSDT",

  // DeFi (некоторые волатильные)
  "SUSHIUSDT", "RUNEUSDT", "CRVUSDT", "SNXUSDT", "YFIUSDT",
  "RAYUSDT", "JTOUSDT", "CAKEUSDT", "BAKEUSDT", "ALPHAUSDT",
  "QUICKUSDT", "BIFIUSDT", "SPELLUSDT", "TOMOUSDT", "OMGUSDT",

  // Дополнительные высоковолатильные монеты
  "CHZUSDT", "HOTUSDT", "VETUSDT", "ANKRUSDT", "STMXUSDT",
  "CELRUSDT", "DENTUSDT", "WINUSDT", "TFUELUSDT", "DATAUSDT",

  // Новые добавления с Binance (высокая волатильность) - УДВОЕНЫ
  "NOTUSDT", "NOTUSDT", "BRETTUSDT", "BRETTUSDT", "TNSRUSDT", "TNSRUSDT", "ONDOUSDT", "ONDOUSDT",
  "ZROUSDT", "ZROUSDT", "IOUSDT", "IOUSDT", "ZKFUSDT", "ZKFUSDT", "MYROUSDT", "MYROUSDT",
  "WENUSDT", "WENUSDT", "BNXUSDT", "BNXUSDT", "HIFIUSDT", "HIFIUSDT", "ARKMUSDT", "ARKMUSDT",
  "NFPUSDT", "NFPUSDT", "AIUSDT", "AIUSDT", "XVSUSDT", "XVSUSDT",

  // Предыдущие добавления (20 монет)
  "MOGUSDT", "BOMEUSDT", "MEWUSDT", "REZUSDT", // Replaced SILLYUSDT
  "DYMUSDT", "SSVUSDT", "FRONTUSDT", "AERGOUSDT", "BONDUSDT",
  "LEVERUSDT", "PDAUSDT", "VANRYUSDT", "DODOUSDT", "RIFUSDT",
  "PENDLEUSDT", "LINAUSDT", "SXPUSDT", "PERPUSDT", "SUPERUSDT",

  // Новые добавления (30 монет)
  "POPCATUSDT", "PUSHUSDT", "GROKUSDT", "SAMOUSDT", "DEGENUSDT",
  "BOMEUSDT", // Replaced MOODENGUSDT (Book of Meme)
  "GIGAUSDT", "PEPEUSDT", // Replaced MUMUUSDT
  "NPCUSDT", "NEIROUSDT", "TURBOUSDT", // Replaced TURBOSUSDT with TURBOUSDT
  "SHRAPUSDT", "LISTAUSDT", "OMNIUSDT", "BETAUSDT",
  "TRUUSDT", "FORTHUSDT", "RPLUSDT", "BIGTIMEUSDT", "HFTUSDT",
  "GMEUSDT", "SUNUSDT", "FIOUSDT", "MTLUSDT", "OGNUSDT",
  "TROYUSDT", "CLVUSDT", "PONKEUSDT", "STPTUSDT", "DOPUSDT"
];

const mediumVolatilityCrypto = [
  // Смарт-контракты (L1, L2)
  "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT", "AVAXUSDT",
  "NEARUSDT", "ATOMUSDT", "FTMUSDT", "DOTUSDT", "TRXUSDT",
  "KLAYUSDT", "CELOUSDT", "ICPUSDT", "EGLDUSDT", "ONEUSDT",
  "KAVAUSDT", "ZILUSDT", "IOTAUSDT", "ZECUSDT", "RVNUSDT",
  "SCUSDT", "ONTUSDT", "WAXPUSDT", "LSKUSDT", "NULSUSDT",

  // DeFi (менее волатильные)
  "UNIUSDT", "AAVEUSDT", "MKRUSDT", "COMPUSDT", "LINKUSDT",
  "1INCHUSDT", "CVXUSDT", "SUSHIUSDT", "CRVUSDT", "SNXUSDT",
  "YFIUSDT", "BALUSDT", "RENUSDT", "KNCUSDT", "OXTUSDT",

  // Метавселенные и NFT (менее волатильные)
  "MANAUSDT", "SANDUSDT", "AXSUSDT", "ENJUSDT", "RNDRUSDT",
  "HIGHUSDT", "TLMUSDT", "ALICEUSDT", "DGUSDT", "ERNUSDT",
  "YGGUSDT", "ILVUSDT", "COMBOUSDT", "TVKUSDT", "SLPUSDT",

  // Layer 2 (Matic, Arbitrum, Optimism)
  "MATICUSDT", "ARBUSDT", "OPUSDT", "METISUSDT", "MNTUSDT",
  "SKLUSDT", "BOBAUSDT", "LRCUSDT", "IMXUSDT", "DUSKUSDT",

  // Платежные решения
  "XRPUSDT", "XLMUSDT", "ALGOUSDT", "HBARUSDT", "QNTUSDT",
  "XDCUSDT", "IOSTUSDT", "NANOUSDT", "XEMUSDT", "WAVESUSDT",

  // AI и Big Data
  "FETUSDT", "OCEANUSDT", "AGIXUSDT", "AKTUSDT", "NMRUSDT",
  "CTXCUSDT", "DTAUSDT", "PHBUSDT", "NKNUSDT", "DATAUSDT",

  // Социальные токены и Web3 (менее волатильные)
  "RLCUSDT", "MASKUSDT", "BANDUSDT", "KEYUSDT", "DENTUSDT",
  "CHZUSDT", "HOTUSDT", "VRAUSDT", "COTIUSDT", "SOCUSDT",

  // Новые добавления с Binance (средняя волатильность)
  "STXUSDT", "PYTHUSDT", "GRTUSDT", "LDOUSDT",
  "ARUSDT", "RADUSDT", "BICOUSDT", "GTCUSDT",
  "ENSUSDT", "ANTUSDT"
];

const lowVolatilityCrypto = [
  // Базовые криптовалюты
  "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",
  "ETCUSDT", "BSVUSDT", "NEOUSDT", "QTUMUSDT", "ZENUSDT",
  "XVGUSDT", "DOGEUSDT", "ZECUSDT", "RVNUSDT", "SCUSDT",

  // Стейблкоины и стабильные активы
  "USDCUSDT", "USDTUSDT", "BUSDUSDT", "DAIUSDT", "TUSDUSDT",
  "FDUSDUSDT", "PAXGUSDT", "WBTCUSDT", "USTCUSDT", "XAUTUSDT",
  "EURUSDT", "GBPUSDT", "AUDUSDT", "JPYUSDT", "KRWUSDT",

  // Устойчивые проекты
  "ETCUSDT", "BSVUSDT", "NEOUSDT", "QTUMUSDT", "ZENUSDT",
  "XVGUSDT", "DOGEUSDT", "ZECUSDT", "RVNUSDT", "SCUSDT",

  // Новые добавления с Binance (низкая волатильность)
  "TWTUSDT", "MDTUSDT", "OGUSDT", "VITEUSDT", "PERLUSDT",
  "REEFUSDT", "STMXUSDT", "CVCUSDT", "NMRUSDT", "LITUSDT",
  "UTKUSDT", "RLCUSDT", "MITHUSDT", "COSUSDT", "DOCKUSDT"
];

const telegramBotToken = '8117770504:AAEOirevwh7Lj3xASFm3y0dqwK1QE9C1_VU';
const chatId = '1288898832';

const timeFrames = [
  Duration(seconds: 0),
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 4),
  Duration(seconds: 5),
  Duration(seconds: 6),
  Duration(seconds: 7),
  Duration(seconds: 8),
  Duration(seconds: 9),
  Duration(seconds: 10),
  Duration(seconds: 11),
  Duration(seconds: 12),
  Duration(seconds: 13),
  Duration(seconds: 14),
  Duration(seconds: 15),
  Duration(seconds: 20),
  Duration(seconds: 25),
  Duration(seconds: 30),
  Duration(seconds: 35),
  Duration(seconds: 35),
  Duration(seconds: 40),
  Duration(seconds: 45),
  Duration(seconds: 50),
  Duration(seconds: 55),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 3),
  Duration(minutes: 4),
  Duration(minutes: 5),
];
