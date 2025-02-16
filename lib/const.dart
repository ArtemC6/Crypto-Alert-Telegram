// const cryptoList = [
//   // Базовые криптовалюты
//   "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",
//
//   // Смарт-контракты (L1, L2)
//   "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT", "AVAXUSDT",
//   "NEARUSDT", "ATOMUSDT", "FTMUSDT",
//
//   // DeFi
//   "UNIUSDT", "AAVEUSDT", "MKRUSDT", "COMPUSDT", "CRVUSDT",
//   "SNXUSDT", "YFIUSDT",
//
//   // Мемкоины (высокая волатильность)
//   "DOGEUSDT", "SHIBUSDT", "PEPEUSDT", "FLOKIUSDT", "1000CATUSDT",
//   "WIFUSDT", "BONKUSDT", "TURBOUSDT",
//
//   // Метавселенные и NFT
//   "MANAUSDT", "SANDUSDT", "AXSUSDT", "ENJUSDT", "GALAUSDT",
//
//   // Layer 2 (Matic, Arbitrum, Optimism)
//   "MATICUSDT", "ARBUSDT", "OPUSDT",
//
//   // Платежные решения
//   "XRPUSDT", "XLMUSDT", "ALGOUSDT",
//
//   // AI и Big Data
//   "FETUSDT", "OCEANUSDT", "AGIXUSDT",
//
//   // Социальные токены и Web3
//   "TRUMPUSDT", "RLCUSDT", "MASKUSDT", "BANDUSDT",
//
//   "SUIUSDT", "LUNAUSDT", "APTUSDT",
//   "C98USDT", "DYDXUSDT", "ORDIUSDT"
// ];

const cryptoList = [
  // Базовые криптовалюты
  "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",

  // Смарт-контракты (L1, L2)
  "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT", "AVAXUSDT",
  "NEARUSDT", "ATOMUSDT", "FTMUSDT", "DOTUSDT", "TRXUSDT",

  // DeFi
  "UNIUSDT", "AAVEUSDT", "MKRUSDT", "COMPUSDT", "CRVUSDT",
  "SNXUSDT", "YFIUSDT", "SUSHIUSDT", "LINKUSDT", "RUNEUSDT",

  // Мемкоины (высокая волатильность)
  "DOGEUSDT", "SHIBUSDT", "PEPEUSDT", "FLOKIUSDT", "1000CATUSDT",
  "WIFUSDT", "BONKUSDT", "TURBOUSDT", "MEMEUSDT", "BABYDOGEUSDT",

  // Метавселенные и NFT
  "MANAUSDT", "SANDUSDT", "AXSUSDT", "ENJUSDT", "GALAUSDT",
  "IMXUSDT", "APEUSDT", "RNDRUSDT", "FLOWUSDT",

  // Layer 2 (Matic, Arbitrum, Optimism)
  "MATICUSDT", "ARBUSDT", "OPUSDT", "METISUSDT", "IMXUSDT",

  // Платежные решения
  "XRPUSDT", "XLMUSDT", "ALGOUSDT", "HBARUSDT", "QNTUSDT",

  // AI и Big Data
  "FETUSDT", "OCEANUSDT", "AGIXUSDT", "RNDRUSDT", "AKTUSDT",

  // Социальные токены и Web3
  "TRUMPUSDT", "RLCUSDT", "MASKUSDT", "BANDUSDT", "HOOKUSDT",

  // Другие популярные и волатильные монеты
  "SUIUSDT", "LUNAUSDT", "APTUSDT", "C98USDT", "DYDXUSDT",
  "ORDIUSDT", "INJUSDT", "SEIUSDT", "TIAUSDT", "MINAUSDT",
  "KASUSDT", "TAOUSDT", "ZETAUSDT", "JUPUSDT", "WLDUSDT"
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
  "TRUMPUSDT", "HOOKUSDT",

  // Метавселенные и NFT (часто волатильные)
  "GALAUSDT", "IMXUSDT", "APEUSDT", "FLOWUSDT",

  // DeFi (некоторые волатильные)
  "SUSHIUSDT", "RUNEUSDT", "CRVUSDT", "SNXUSDT", "YFIUSDT"
];

const lowVolatilityCrypto = [
  // Базовые криптовалюты
  "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",

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
  "RLCUSDT", "MASKUSDT", "BANDUSDT"
];

const telegramBotToken = '8117770504:AAEOirevwh7Lj3xASFm3y0dqwK1QE9C1_VU';
const chatId = '1288898832';

const timeFrames = [
  Duration(seconds: 1),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 3),
  Duration(minutes: 5),
  Duration(minutes: 10),
];
