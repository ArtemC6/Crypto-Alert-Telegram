const cryptoList = [
  // Базовые криптовалюты
  "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",

  // Смарт-контракты (L1, L2)
  "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT", "AVAXUSDT",
  "NEARUSDT", "ATOMUSDT", "FTMUSDT",

  // DeFi
  "UNIUSDT", "AAVEUSDT", "MKRUSDT", "COMPUSDT", "CRVUSDT",
  "SNXUSDT", "YFIUSDT",

  // Мемкоины (высокая волатильность)
  "DOGEUSDT", "SHIBUSDT", "PEPEUSDT", "FLOKIUSDT", "1000CATUSDT",
  "WIFUSDT", "BONKUSDT", "TURBOUSDT",

  // Метавселенные и NFT
  "MANAUSDT", "SANDUSDT", "AXSUSDT", "ENJUSDT", "GALAUSDT",

  // Layer 2 (Matic, Arbitrum, Optimism)
  "MATICUSDT", "ARBUSDT", "OPUSDT",

  // Платежные решения
  "XRPUSDT", "XLMUSDT", "ALGOUSDT",

  // AI и Big Data
  "FETUSDT", "OCEANUSDT", "AGIXUSDT",

  // Социальные токены и Web3
  "TRUMPUSDT", "RLCUSDT", "MASKUSDT", "BANDUSDT",

  "SUIUSDT", "LUNAUSDT", "APTUSDT",
  "C98USDT", "DYDXUSDT", "ORDIUSDT"
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
