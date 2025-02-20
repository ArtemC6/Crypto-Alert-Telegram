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
  "TAOUSDT", "ZETAUSDT", "JUPUSDT", "WLDUSDT", "PORTALUSDT", // Portal — игровой проект
  "PIXELUSDT", // Pixels — игра на блокчейне
  "ALTUSDT", // AltLayer — L2 решение
  "XAIUSDT", // xAI — AI-проект
  "STRKUSDT", // Starknet — L2 решение

  // Социальные токены и Web3
  "TRUMPUSDT", "HOOKUSDT", "LADYSUSDT", "GMRUSDT",

  // Метавселенные и NFT (часто волатильные)
  "GALAUSDT", "IMXUSDT", "APEUSDT", "FLOWUSDT", "SFPUSDT",
  "BLURUSDT", // Blur — NFT-платформа
  "MAVIAUSDT", // Heroes of Mavia — игровой проект

  // DeFi (некоторые волатильные)
  "SUSHIUSDT", "RUNEUSDT", "CRVUSDT", "SNXUSDT", "YFIUSDT",
  "RAYUSDT", // Raydium — DeFi на Solana
  "JTOUSDT", // Jito — Solana-проект

  // Дополнительные высоковолатильные монеты
  "CHZUSDT", "HOTUSDT", "VETUSDT", "ANKRUSDT", "STMXUSDT",

  // Новые добавления с Binance (высокая волатильность)
  "NOTUSDT", "BRETTUSDT", "TNSRUSDT", "ONDOUSDT", "ZROUSDT",
  "IOUSDT", // IO — проект AI
  "ZKFUSDT", // zkFair — L2 решение
  "MYROUSDT", // Myro — мемкоин на Solana
  "WENUSDT" // WEN — новый мемкоин
];

const mediumVolatilityCrypto = [
  // Смарт-контракты (L1, L2)
  "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT", "AVAXUSDT",
  "NEARUSDT", "ATOMUSDT", "FTMUSDT", "DOTUSDT", "TRXUSDT",
  "KLAYUSDT", // Klaytn — блокчейн-платформа
  "CELOUSDT", // Celo — блокчейн для платежей

  // DeFi (менее волатильные)
  "UNIUSDT", "AAVEUSDT", "MKRUSDT", "COMPUSDT", "LINKUSDT",
  "1INCHUSDT", // 1inch — агрегатор DEX
  "CVXUSDT", // Convex Finance — DeFi-протокол

  // Метавселенные и NFT (менее волатильные)
  "MANAUSDT", "SANDUSDT", "AXSUSDT", "ENJUSDT", "RNDRUSDT",
  "HIGHUSDT", // Highstreet — метавселенная
  "TLMUSDT", // Alien Worlds — NFT-игра

  // Layer 2 (Matic, Arbitrum, Optimism)
  "MATICUSDT", "ARBUSDT", "OPUSDT", "METISUSDT",
  "MNTUSDT", // Mantle — L2 решение
  "SKLUSDT", // Skale — блокчейн для масштабирования

  // Платежные решения
  "XRPUSDT", "XLMUSDT", "ALGOUSDT", "HBARUSDT", "QNTUSDT",
  "XDCUSDT", // XinFin — платежный блокчейн
  "IOSTUSDT", // IOST — блокчейн для dApps

  // AI и Big Data
  "FETUSDT", "OCEANUSDT", "AGIXUSDT", "AKTUSDT",
  "NMRUSDT", // Numeraire — AI-проект
  "CTXCUSDT", // Cortex — AI на блокчейне

  // Социальные токены и Web3 (менее волатильные)
  "RLCUSDT", "MASKUSDT", "BANDUSDT",
  "KEYUSDT", // SelfKey — идентификация в Web3
  "DENTUSDT", // Dent — мобильные данные на блокчейне

  // Дополнительные средневолатильные монеты
  "EGLDUSDT", "ONEUSDT", "KAVAUSDT", "ZILUSDT", "IOTAUSDT", "ZECUSDT",
  "RVNUSDT", // Ravencoin — блокчейн для токенизации
  "SCUSDT", // Siacoin — децентрализованное хранилище

  // Новые добавления с Binance (средняя волатильность)
  "STXUSDT", // Stacks — блокчейн для Bitcoin
  "PYTHUSDT", // Pyth Network — оракул для DeFi
  "GRTUSDT", // The Graph — данные для Web3
  "LDOUSDT", // Lido DAO — стейкинг ETH
  "ARUSDT" // Arweave — децентрализованное хранилище данных
];

const lowVolatilityCrypto = [
  // Базовые криптовалюты
  "BTCUSDT", "LTCUSDT", "BCHUSDT", "XMRUSDT", "DASHUSDT",

  // Дополнительные низковолатильные монеты
  "USDCUSDT", "USDTUSDT", "BUSDUSDT", "DAIUSDT", "TUSDUSDT",
  "FDUSDUSDT", // First Digital USD — стейблкоин от Binance
  "PAXGUSDT", // PAX Gold — подкрепленный золотом актив
  "WBTCUSDT", // Wrapped Bitcoin — стабильный актив, привязанный к BTC
  "USTCUSDT", // TerraClassic USD — восстановленный стейблкоин
  "XAUTUSDT", // Tether Gold — еще один актив, подкрепленный золотом

  // Устойчивые проекты
  "ETCUSDT", "BSVUSDT", "NEOUSDT", "QTUMUSDT",
  "ZENUSDT", // Horizen — приватный блокчейн
  "XVGUSDT", // Verge — приватные платежи

  // Новые добавления с Binance (низкая волатильность)
  "TWTUSDT", // Trust Wallet Token — токен кошелька
  "BNXUSDT", // BinaryX — игровой проект
  "MDTUSDT", // Measurable Data Token — данные на блокчейне
  "OGUSDT" // OG Fan Token — фан-токен
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
