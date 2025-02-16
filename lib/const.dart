const cryptoList = [
  ...lowVolatilityCrypto,
  ...mediumVolatilityCrypto,
  ...highVolatilityCrypto,
];

const highVolatilityCrypto = [
  // Мемкоины (высокая волатильность)
  "DOGEUSDT", "SHIBUSDT", "PEPEUSDT", "FLOKIUSDT", "1000CATUSDT",
  "WIFUSDT", "BONKUSDT", "TURBOUSDT", "MEMEUSDT", "BABYDOGEUSDT",

  // Новые и трендовые монеты
  "SUIUSDT", "APTUSDT", "C98USDT", "DYDXUSDT", "ORDIUSDT",
  "INJUSDT", "SEIUSDT", "TIAUSDT", "MINAUSDT", "KASUSDT",
  "TAOUSDT", "ZETAUSDT", "JUPUSDT", "WLDUSDT",

  // Социальные токены и Web3
  "TRUMPUSDT", "HOOKUSDT", "LADYSUSDT", "GMRUSDT",

  // Метавселенные и NFT (часто волатильные)
  "GALAUSDT", "IMXUSDT", "APEUSDT", "FLOWUSDT", "SFPUSDT",

  // DeFi (некоторые волатильные)
  "SUSHIUSDT", "RUNEUSDT", "CRVUSDT", "SNXUSDT", "YFIUSDT",

  // Дополнительные высоковолатильные монеты
  "CHZUSDT", "HOTUSDT", "STMXUSDT", "VETUSDT", "ANKRUSDT"
];

const mediumVolatilityCrypto = [
  // Смарт-контракты (L1, L2)
  "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT", "AVAXUSDT",
  "NEARUSDT", "ATOMUSDT", "FTMUSDT", "DOTUSDT", "TRXUSDT",

  // DeFi (менее волатильные)
  "UNIUSDT", "AAVEUSDT", "MKRUSDT", "COMPUSDT", "LINKUSDT",

  // Метавселенные и NFT (менее волатильные)
  "MANAUSDT", "SANDUSDT", "AXSUSDT", "ENJUSDT", "RNDRUSDT",

  // Layer 2 (Matic, Arbitrum, Optimism)
  "MATICUSDT", "ARBUSDT", "OPUSDT", "METISUSDT",

  // Платежные решения
  "XRPUSDT", "XLMUSDT", "ALGOUSDT", "HBARUSDT", "QNTUSDT",

  // AI и Big Data
  "FETUSDT", "OCEANUSDT", "AGIXUSDT", "AKTUSDT",

  // Социальные токены и Web3 (менее волатильные)
  "RLCUSDT", "MASKUSDT", "BANDUSDT",

  // Дополнительные средневолатильные монеты
  "EGLDUSDT", "ONEUSDT", "KAVAUSDT", "ZILUSDT", "IOTAUSDT"
];

const lowVolatilityCrypto = [
  // Базовые криптовалюты
  "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",

  // Дополнительные низковолатильные монеты
  "USDCUSDT", "USDTUSDT", "BUSDUSDT", "DAIUSDT", "TUSDUSDT",

  // Устойчивые проекты
  "ETCUSDT", "ZECUSDT", "BSVUSDT", "NEOUSDT", "QTUMUSDT"
];

const telegramBotToken = '8117770504:AAEOirevwh7Lj3xASFm3y0dqwK1QE9C1_VU';
const chatId = '1288898832';

const timeFrames = [
  Duration(seconds: 0),
  Duration(seconds: 1),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(seconds: 45),
  Duration(minutes: 1),
  Duration(minutes: 3),
  Duration(minutes: 5),
];
