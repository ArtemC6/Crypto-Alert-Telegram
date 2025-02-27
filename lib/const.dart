const cryptoList = [
  ...lowVolatilityCrypto,
  ...mediumVolatilityCrypto,
  ...highVolatilityCrypto,
];

const highVolatilityCrypto = [
  "DOGEUSDT", // Dogecoin
  "SHIBUSDT", // Shiba Inu
  "PEPEUSDT", // Pepe
  "FLOKIUSDT", // Floki Inu
  "1000CATUSDT", // Catcoin
  "WIFUSDT", // Dogwifhat
  "BONKUSDT", // Bonk
  "TURBOUSDT", // Turbo
  "MEMEUSDT", // Memecoin
  "BOMEUSDT", // Book of Meme
  "MEWUSDT", // Cat in a Dog’s World
  "POPCATUSDT", // Popcat
  "BRETTUSDT", // Brett
  "NOTUSDT", // Notcoin
  "PONKEUSDT", // Ponke
  "SUIUSDT", // Sui
  "APTUSDT", // Aptos
  "C98USDT", // Coin98
  "DYDXUSDT", // dYdX
  "ORDIUSDT", // Ordinals
  "INJUSDT", // Injective
  "SEIUSDT", // Sei
  "TIAUSDT", // Celestia
  "MINAUSDT", // Mina
  "KASUSDT", // Kaspa
  "TAOUSDT", // Tao
  "ZETAUSDT", // ZetaChain
  "JUPUSDT", // Jupiter
  "WLDUSDT", // Worldcoin
  "PORTALUSDT", // Portal
  "PIXELUSDT", // Pixels
  "ALTUSDT", // AltLayer
  "XAIUSDT", // Xai
  "STRKUSDT", // Starknet
  "RONINUSDT", // Ronin
  "BEAMUSDT", // Beam
  "ACEUSDT", // Fusionist
  "MAVUSDT", // Maverick Protocol
  "IDUSDT", // Space ID
  "CYBERUSDT", // CyberConnect
  "TRUMPUSDT", // TrumpCoin
  "MAGICUSDT", // Magic
  "HOOKUSDT", // Hooked Protocol
  "GALUSDT", // Galxe
  "RAREUSDT", // SuperRare
  "API3USDT", // API3
  "EDUUSDT", // Open Campus
  "SOCUSDT", // All Sports
  "CHESSUSDT", // Tranchess
  "VRAUSDT", // Verasity
  "COTIUSDT", // COTI
  "GMRUSDT", // GamerCoin
  "GALAUSDT", // Gala
  "IMXUSDT", // Immutable X
  "APEUSDT", // ApeCoin
  "FLOWUSDT", // Flow
  "SFPUSDT", // SafePal
  "BLURUSDT", // Blur
  "MAVIAUSDT", // Heroes of Mavia
  "TVKUSDT", // Terra Virtua Kolect
  "SLPUSDT", // Smooth Love Potion
  "ALICEUSDT", // MyNeighborAlice
  "DGUSDT", // DeGate
  "ERNUSDT", // Ethernity Chain
  "YGGUSDT", // Yield Guild Games
  "ILVUSDT", // Illuvium
  "COMBOUSDT", // Combo
  "SUSHIUSDT", // SushiSwap
  "RUNEUSDT", // THORChain
  "CRVUSDT", // Curve DAO Token
  "SNXUSDT", // Synthetix
  "YFIUSDT", // yearn.finance
  "RAYUSDT", // Raydium
  "JTOUSDT", // Jito
  "CAKEUSDT", // PancakeSwap
  "BAKEUSDT", // BakeryToken
  "ALPHAUSDT", // Alpha Finance Lab
  "QUICKUSDT", // QuickSwap
  "BIFIUSDT", // Beefy.Finance
  "SPELLUSDT", // Spell Token
  "TOMOUSDT", // TomoChain
  "OMGUSDT", // OMG Network
  "CHZUSDT", // Chiliz
  "HOTUSDT", // Holo
  "VETUSDT", // VeChain
  "ANKRUSDT", // Ankr
  "STMXUSDT", // StormX
  "CELRUSDT", // Celer Network
  "DENTUSDT", // Dent
  "WINUSDT", // WINkLink
  "TFUELUSDT", // Theta Fuel
  "DATAUSDT", // Streamr DATAcoin
  "TNSRUSDT", // Tensor
  "ONDOUSDT", // ONDO
  "ZROUSDT", // LayerZero
  "IOUSDT", // IO.NET
  "ZKFUSDT", // zkFair
  "MYROUSDT", // Myro
  "WENUSDT", // Wen
  "BNXUSDT", // BinaryX
  "HIFIUSDT", // Hifi Finance
  "ARKMUSDT", // Arkham
  "NFPUSDT", // NFPrompt
  "AIUSDT", // Sleepless AI
  "XVSUSDT", // Venus
  "MOGUSDT", // Mog Coin
  "REZUSDT", // Renzo
  "DYMUSDT", // Dymension
  "SSVUSDT", // SSV Network
  "FRONTUSDT", // Frontier
  "AERGOUSDT", // Aergo
  "BONDUSDT", // BarnBridge
  "LEVERUSDT", // LeverFi
  "PDAUSDT", // PlayDapp
  "VANRYUSDT", // Vanar Chain
  "DODOUSDT", // DODO
  "RIFUSDT", // RSK Infrastructure Framework
  "PENDLEUSDT", // Pendle
  "LINAUSDT", // Linear
  "SXPUSDT", // Solar
  "PERPUSDT", // Perpetual Protocol
  "SUPERUSDT", // SuperVerse
  "PUSHUSDT", // Push Protocol
  "GROKUSDT", // Grok
  "SAMOUSDT", // Samoyedcoin
  "DEGENUSDT", // Degen
  "GIGAUSDT", // GigaChad
  "NPCUSDT", // NPCoin
  "NEIROUSDT", // Neiro
  "SHRAPUSDT", // Shrapnel
  "LISTAUSDT", // Lista DAO
  "OMNIUSDT", // Omni Network
  "BETAUSDT", // Beta Finance
  "TRUUSDT", // TrueFi
  "FORTHUSDT", // Ampleforth Governance Token
  "RPLUSDT", // Rocket Pool
  "BIGTIMEUSDT", // Big Time
  "HFTUSDT", // Hashflow
  "GMEUSDT", // GameStop
  "SUNUSDT", // Sun Token
  "FIOUSDT", // FIO Protocol
  "MTLUSDT", // Metal
  "OGNUSDT", // Origin Protocol
  "TROYUSDT", // Troy
  "CLVUSDT", // Clover Finance
  "STPTUSDT", // Standard Tokenization Protocol
  "DOPUSDT" // Drops Ownership Power
];
const mediumVolatilityCrypto = [
  "ETHUSDT", // Ethereum
  "BNBUSDT", // Binance Coin
  "ADAUSDT", // Cardano
  "SOLUSDT", // Solana
  "AVAXUSDT", // Avalanche
  "NEARUSDT", // NEAR Protocol
  "ATOMUSDT", // Cosmos
  "FTMUSDT", // Fantom
  "DOTUSDT", // Polkadot
  "TRXUSDT", // TRON
  "KLAYUSDT", // Klaytn
  "CELOUSDT", // Celo
  "ICPUSDT", // Internet Computer
  "EGLDUSDT", // MultiversX
  "ONEUSDT", // Harmony
  "KAVAUSDT", // Kava
  "ZILUSDT", // Zilliqa
  "IOTAUSDT", // IOTA
  "ZECUSDT", // Zcash
  "RVNUSDT", // Ravencoin
  "SCUSDT", // Siacoin
  "ONTUSDT", // Ontology
  "WAXPUSDT", // WAX
  "LSKUSDT", // Lisk
  "NULSUSDT", // Nuls
  "UNIUSDT", // Uniswap
  "AAVEUSDT", // Aave
  "MKRUSDT", // Maker
  "COMPUSDT", // Compound
  "LINKUSDT", // Chainlink
  "1INCHUSDT", // 1inch
  "CVXUSDT", // Convex Finance
  "BALUSDT", // Balancer
  "RENUSDT", // Ren
  "KNCUSDT", // Kyber Network
  "OXTUSDT", // Orchid
  "MANAUSDT", // Decentraland
  "SANDUSDT", // The Sandbox
  "AXSUSDT", // Axie Infinity
  "ENJUSDT", // Enjin Coin
  "RNDRUSDT", // Render Token
  "HIGHUSDT", // Highstreet
  "TLMUSDT", // Alien Worlds
  "MATICUSDT", // Polygon
  "ARBUSDT", // Arbitrum
  "OPUSDT", // Optimism
  "METISUSDT", // MetisDAO
  "MNTUSDT", // Mantle
  "SKLUSDT", // SKALE Network
  "BOBAUSDT", // Boba Network
  "LRCUSDT", // Loopring
  "DUSKUSDT", // Dusk Network
  "XRPUSDT", // Ripple
  "XLMUSDT", // Stellar
  "ALGOUSDT", // Algorand
  "HBARUSDT", // Hedera Hashgraph
  "QNTUSDT", // Quant
  "XDCUSDT", // XDC Network
  "IOSTUSDT", // IOST
  "NANOUSDT", // Nano
  "XEMUSDT", // NEM
  "WAVESUSDT", // Waves
  "FETUSDT", // Fetch.ai
  "OCEANUSDT", // Ocean Protocol
  "AGIXUSDT", // SingularityNET
  "AKTUSDT", // Akash Network
  "NMRUSDT", // Numeraire
  "CTXCUSDT", // Cortex
  "DTAUSDT", // DATA
  "PHBUSDT", // Phoenix Global
  "NKNUSDT", // NKN
  "RLCUSDT", // iExec RLC
  "MASKUSDT", // Mask Network
  "BANDUSDT", // Band Protocol
  "KEYUSDT", // SelfKey
  "STXUSDT", // Stacks
  "PYTHUSDT", // Pyth Network
  "GRTUSDT", // The Graph
  "LDOUSDT", // Lido DAO
  "ARUSDT", // Arweave
  "RADUSDT", // Radicle
  "BICOUSDT", // Biconomy
  "GTCUSDT", // Gitcoin
  "ENSUSDT", // Ethereum Name Service
  "ANTUSDT" // Aragon
];
const lowVolatilityCrypto = [
  "BTCUSDT", // Bitcoin
  "LTCUSDT", // Litecoin
  "BCHUSDT", // Bitcoin Cash
  "XMRUSDT", // Monero
  "DASHUSDT", // Dash
  "ETCUSDT", // Ethereum Classic
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
