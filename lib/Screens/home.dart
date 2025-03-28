import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';

import '../solana_chart.dart' show TokenChartScreen;
import 'select_token.dart';
import '../const.dart';
import '../model/chart.dart';
import '../model/token_model.dart';
import '../services/api.dart';
import '../services/storage.dart';
import '../utils.dart';

enum ExchangeType { binanceFutures, okx, huobi }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  WebSocketChannel? _channelSpotBinanceFeatured, _okxChannel, _huobiChannel;

  late List<Map<String, dynamic>> _coinsListBinanceFeature,
      coinsListOKX,
      coinsListHuobi;
  late List<Map<String, dynamic>> coinsListForSelect;

  List<String> selectedCoins = [];
  double priceChangeThreshold = 1.0;
  bool isHide = true;
  final isPlatform = kIsWeb ? 'Web' : 'Mobile';
  final Map<String, List<Map<String, dynamic>>> _priceHistoryBinance = {};
  final Map<String, List<Map<String, dynamic>>> _priceHistoryOKX = {};
  final Map<String, List<Map<String, dynamic>>> _priceHistoryHuobi = {};
  final Map<String, double> _volatilityMap = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  late final StorageService _storageService;
  List<ChartModel>? itemChartMain;
  DateTime? _lastMessageTimeBinance, _lastMessageTimeOKX, _lastMessageTimeHuobi;
  bool _isMonitoringBinance = false,
      _isMonitoringOKX = false,
      _isMonitoringHuobi = false;
  bool isRefresh = true;
  bool isScreen = false;
  final _chartKey = GlobalKey();
  List<dynamic> _previousTokens = [];
  final Set<String> _sentTokens = {};
  final Set<String> notifiedPoolIds = {};

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _coinsListBinanceFeature = [];
    coinsListOKX = [];
    coinsListHuobi = [];
    coinsListForSelect = [];
    itemChartMain = [];
    _loadScreen();
  }

  void _loadScreen() async {
    priceChangeThreshold = await _storageService.loadPriceChangeThreshold();
    isScreen = await _storageService.loadSelectedScreen();
    setState(() => priceChangeThreshold = priceChangeThreshold);

    if (!isScreen) {
      _fetchCoinData();
      _startTimer();
      connectWebSocketMem();
    }
  }

  Future<void> connectWebSocketMem() async {
    const String webSocketUrl = 'wss://trench-stream.jup.ag/ws';
    const Duration reconnectDelay = Duration(seconds: 2);
    late WebSocketChannel channel;

    void subscribeToChannels() {
      final subscriptions = [
        {"type": "subscribe:recent"},
        {"type": "subscribe:pool", "pools": []},
        {"type": "subscribe:txns", "assets": []}
      ];

      for (var subscription in subscriptions) {
        channel.sink.add(jsonEncode(subscription));
      }
    }

    Future<void> processPool(Map<String, dynamic> pool,
        {required int threshold}) async {
      if (!passesFilters(pool) || notifiedPoolIds.contains(pool['id'])) return;

      notifiedPoolIds.add(pool['id']);
      final tokenAddress = (pool['baseAsset']?['id'] as String?) ?? 'N/A';

      final marketCapAndAge = await fetchTokenInfo(tokenAddress);
      if (marketCapAndAge == null) return;

      final timestamp = marketCapAndAge.creationTimestamp != 0
          ? marketCapAndAge.creationTimestamp
          : marketCapAndAge.openTimestamp;

      final age = DateTime.now().difference(getDateTime(timestamp)).inMinutes;
      if (age > 40) return;

      final chartData = await fetchChartDataMem(tokenAddress);
      if (chartData == null || chartData.isEmpty) return;

      final chartImage = await showChartDialog(chartData);
      if (chartImage == null) return;

      final percent = await analyzeTokenWithAIMem(pool);
      if (percent > threshold) return;

      AudioPlayer().play(AssetSource('audio/coll.mp3'), volume: 0.8);
      sendTelegramNotificationMem(marketCapAndAge, percent, chartImage);
    }

    Future<void> handleMessage(dynamic message) async {
      try {
        final data = jsonDecode(message);
        final updates = data['data'] as List?;
        if (updates == null) return;

        for (var update in updates) {
          if (update['type'] == 'update' && update['pool'] != null) {
            processPool(update['pool'], threshold: 60);
          }
        }
      } catch (e) {
        print('Message processing error: $e');
      }
    }

    void reconnect() {
      Future.delayed(reconnectDelay, connectWebSocketMem);
    }

    try {
      channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));
      subscribeToChannels();

      channel.stream.listen(
        (message) => handleMessage(message),
        onError: (error) {
          print('WebSocket error: $error');
          reconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          reconnect();
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
      reconnect();
    }
  }

  Future<Uint8List?> showChartDialog(List<ChartModelMem> chartData) async {
    final chartKey = GlobalKey();
    Uint8List? chartImage;

    while (Navigator.of(context).canPop()) {
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(Duration(milliseconds: 20));
    }

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        final height = MediaQuery.of(context).size.height;

        Future.delayed(Duration(milliseconds: 150), () async {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return Dialog(
          insetPadding: const EdgeInsets.only(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: RepaintBoundary(
                key: chartKey,
                child: SfCartesianChart(
                  backgroundColor: Colors.black,
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    tooltipAlignment: ChartAlignment.near,
                  ),
                  primaryXAxis: NumericAxis(isVisible: false),
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePinching: true,
                    zoomMode: ZoomMode.xy,
                    selectionRectBorderWidth: 10,
                    enablePanning: true,
                    enableDoubleTapZooming: true,
                    enableMouseWheelZooming: true,
                    enableSelectionZooming: true,
                  ),
                  series: <CandleSeries>[
                    CandleSeries<ChartModelMem, int>(
                      enableSolidCandles: true,
                      enableTooltip: true,
                      dataSource: chartData,
                      xValueMapper: (ChartModelMem sales, _) => sales.time,
                      lowValueMapper: (ChartModelMem sales, _) => sales.low,
                      highValueMapper: (ChartModelMem sales, _) => sales.high,
                      openValueMapper: (ChartModelMem sales, _) => sales.open,
                      closeValueMapper: (ChartModelMem sales, _) => sales.close,
                      animationDuration: 0,
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    chartImage = await captureChart(chartKey);
    return chartImage;
  }

  bool passesFilters(Map<String, dynamic> pool) {
    final baseAsset = pool['baseAsset'] ?? {};

    final double marketCap =
        (baseAsset['mcap'] ?? pool['mcap'] ?? 0).toDouble();
    final double liquidity = (pool['liquidity'] ?? 0).toDouble();
    final double volume24h = (pool['volume24h'] ?? 0).toDouble();
    final int holders = (baseAsset['holderCount'] ?? 0) as int;
    final String createdAt =
        pool['createdAt'] ?? baseAsset['firstPool']?['CreatedAt'] ?? '';
    final double bondingCurve = (pool['bondingCurve'] ?? 0).toDouble();
    final double organicScore =
        (baseAsset['organicScore'] ?? pool['organicScore'] ?? 0).toDouble();
    final int organicBuyers24h =
        (baseAsset['organicBuyers24h'] ?? pool['organicBuyers24h'] ?? 0) as int;

    // Статистика
    final stats5m = pool['baseAsset']['stats5m'] ?? {};
    final stats24h = pool['baseAsset']['stats24h'] ?? {};

    final double priceChange5m = (stats5m['priceChange'] ?? 0).toDouble();
    final double buyVolume5m = (stats5m['buyVolume'] ?? 0).toDouble();
    final double sellVolume5m = (stats5m['sellVolume'] ?? 0).toDouble();
    final int numBuys5m = (stats5m['numBuys'] ?? 0) as int;
    final int numSells5m = (stats5m['numSells'] ?? 0) as int;
    final int numTraders5m = (stats5m['numTraders'] ?? 0) as int;
    final int numBuyers5m = (stats5m['numBuyers'] ?? 0) as int;
    final int numSellers5m = (stats5m['numSellers'] ?? 0) as int;

    final double buyVolume24h = (stats24h['buyVolume'] ?? 0).toDouble();
    final double sellVolume24h = (stats24h['sellVolume'] ?? 0).toDouble();
    final int numBuys24h = (stats24h['numBuys'] ?? 0) as int;
    final int numSells24h = (stats24h['numSells'] ?? 0) as int;
    final int numTraders24h = (stats24h['numTraders'] ?? 0) as int;
    final int numBuyers24h = (stats24h['numBuyers'] ?? 0) as int;
    final int numSellers24h = (stats24h['numSellers'] ?? 0) as int;

    final audit = baseAsset['audit'] ?? {};
    final bool mintAuthorityDisabled = audit['mintAuthorityDisabled'] ?? false;
    final bool freezeAuthorityDisabled =
        audit['freezeAuthorityDisabled'] ?? false;
    final double topHoldersPercentage =
        (audit['topHoldersPercentage'] ?? 0).toDouble();

    int age = 0;
    if (createdAt.isNotEmpty) {
      final createdDate = DateTime.tryParse(createdAt);
      if (createdDate != null) {
        age = DateTime.now().difference(createdDate).inMinutes;
      }

      if (age >= 60) return false;
    }

    final bool hasEnoughMarketCap = marketCap >= 5000 && marketCap <= 150000;
    final bool hasEnoughLiquidity = liquidity >= 4000;
    final bool hasEnoughVolume24h = volume24h >= 3000;
    final bool hasEnoughHolders = holders >= 35;
    final bool isNotTooOld = age <= 30;

    final bool hasHighVolume24h =
        buyVolume24h >= 3500 || sellVolume24h >= 3500; // Высокий объем торгов
    final bool hasEnoughTraders24h =
        numTraders24h >= 25; // Достаточно трейдеров за 24 часа
    final bool hasMoreBuysThanSells24h =
        numBuys24h > numSells24h; // Покупок больше, чем продаж
    final bool hasLowTopHoldersPercentage =
        topHoldersPercentage <= 30; // Низкая концентрация у крупных держателей

    final bool hasGoodOrganicScore =
        organicScore >= 30; // Хороший органический рост
    final bool hasEnoughOrganicBuyers =
        organicBuyers24h >= 30; // Достаточно органических покупателей

    return hasEnoughMarketCap &&
        hasEnoughLiquidity &&
        hasGoodOrganicScore &&
        hasEnoughOrganicBuyers &&
        hasEnoughVolume24h &&
        hasEnoughHolders &&
        freezeAuthorityDisabled &&
        mintAuthorityDisabled &&
        hasLowTopHoldersPercentage &&
        isNotTooOld &&
        hasMoreBuysThanSells24h &&
        hasEnoughTraders24h &&
        hasHighVolume24h;
  }

  bool _isTokenSent(String tokenAddress) {
    return _sentTokens.contains(tokenAddress);
  }

  Future<void> _startTimer() async {
    Timer.periodic(Duration(seconds: 2), (_) {
      _fetchAndUpdateTokens();
    });
  }

  Future<void> _fetchAndUpdateTokens() async {
    try {
      final tokens = await fetchTokensTop200();
      final currentTimeInSeconds =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final minTokenAgeInSeconds = 0 * 60;
      final maxTokenAgeInSeconds = 200 * 60;

      final sortedTokens = tokens.where((token) {
        final marketCap = parseDouble(token['marketCap']);
        final creationTime = token['createdAt'] as int;
        final tokenAgeInSeconds = currentTimeInSeconds - creationTime;
        final isOldEnough = tokenAgeInSeconds >= minTokenAgeInSeconds;
        final isNotTooOld = tokenAgeInSeconds <= maxTokenAgeInSeconds;
        final holders = parseInt(token['holders']);

        final liquidity = parseDouble(token['liquidity']);
        final txnCount24 = parseInt(token['txnCount24']);
        final uniqueBuys24 = parseInt(token['uniqueBuys24']);
        final uniqueSells24 = parseInt(token['uniqueSells24']);
        final volume24 = parseDouble(token['volume24']);

        final hasEnoughVolume = volume24 > 9000;
        final hasEnoughUniqueParticipants =
            uniqueBuys24 > 320 && uniqueSells24 > 220;
        final hasEnoughTransactions = txnCount24 > 280;
        final hasEnoughLiquidity = liquidity > 9000;
        final hasEnoughHolders = holders >= 550;

        final hasEnoughMarketCap = marketCap >= 10000 && marketCap <= 1000000 ||
            marketCap >= 100000 && marketCap < 3000000 ||
            marketCap >= 3000000 && marketCap < 5000000 ||
            marketCap >= 5000000 && marketCap < 20000000 ||
            marketCap >= 10000000 && marketCap < 50000000;

        return hasEnoughMarketCap &&
            isOldEnough &&
            isNotTooOld &&
            hasEnoughHolders &&
            hasEnoughLiquidity &&
            hasEnoughTransactions &&
            hasEnoughUniqueParticipants &&
            hasEnoughVolume;
      }).toList();

      _checkForNewTokens(sortedTokens);
      _previousTokens = List.from(sortedTokens);
    } catch (e) {
      print("Error fetching tokens: $e");
    }
  }

  void _checkForNewTokens(List<dynamic> sortedTokens) async {
    if (_previousTokens.isEmpty) return;

    final newTokens = sortedTokens.where((newToken) {
      final tokenSymbol = newToken['token']['symbol'];
      final tokenAddress = newToken['token']['address'];
      return !_previousTokens.any(
            (oldToken) =>
                oldToken['token']['symbol'] == tokenSymbol &&
                oldToken['token']['address'] == tokenAddress,
          ) &&
          !_isTokenSent(tokenAddress);
    }).toList();

    for (var token in newTokens) {
      final tokenAddress = token['token']['address'];
      final marketCapAndAge = await fetchTokenInfo(tokenAddress);

      final marketCap = marketCapAndAge?.marketCap ?? 0;

      if (marketCapAndAge != null) {
        final int timestamp = marketCapAndAge.creationTimestamp != 0
            ? marketCapAndAge.creationTimestamp
            : marketCapAndAge.openTimestamp;

        final int age =
            DateTime.now().difference(getDateTime(timestamp)).inMinutes;

        if (age <= 100) {
          if (age <= 3 && marketCap <= 100000 && marketCap >= 5000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 1);
          } else if (age <= 5 && marketCap <= 100000 && marketCap >= 10000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 2);
          } else if (age <= 15 && marketCap <= 150000 && marketCap >= 20000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 3);
          } else if (age <= 20 && marketCap <= 200000 && marketCap >= 30000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 4);
          } else if (age <= 30 && marketCap <= 300000 && marketCap >= 50000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 5);
          } else if (age <= 50 && marketCap <= 500000 && marketCap >= 70000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 6);
          }
        }
      }
    }
  }

  Future<void> _notifyAndSaveToken(
      token, TokenInfo marketCapAndAge, tokenAddress, int count) async {
    final scamProbability = await analyzeTokenWithAI(token, marketCapAndAge);
    if (int.parse(scamProbability) <= 60) {
      _sentTokens.add(tokenAddress);

      AudioPlayer().play(AssetSource('audio/coll.mp3'), volume: 0.8);
      final chartData = await fetchChartDataMem(tokenAddress);
      final chartImage = await showChartDialog(chartData!);

      if (chartImage != null) {
        sendTelegramNotificationMemCoins(
            token, scamProbability, marketCapAndAge, count, chartImage);
      }
    }
  }

  Future<void> _monitorBinanceConnection() async {
    _isMonitoringBinance = true;
    int reconnectAttempts = 0;
    const maxAttempts = 5;

    while (_isMonitoringBinance && mounted) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeBinance != null &&
          DateTime.now().difference(_lastMessageTimeBinance!).inSeconds >= 30) {
        print(
            'No data from Binance for 30s. Reconnecting ($reconnectAttempts/$maxAttempts)...');
        await _channelSpotBinanceFeatured?.sink.close();
        await _connectWebSocketBinance();

        reconnectAttempts++;
        if (reconnectAttempts >= maxAttempts) {
          print('Max attempts reached for Binance. Waiting 1 minute...');
          await Future.delayed(Duration(minutes: 1));
          reconnectAttempts = 0;
        } else {
          await Future.delayed(
              Duration(seconds: pow(2, reconnectAttempts).toInt()));
        }
      } else {
        reconnectAttempts = 0;
      }
    }
    _isMonitoringBinance = false;
  }

  Future<void> _monitorOKXConnection() async {
    _isMonitoringOKX = true;
    int reconnectAttempts = 0;
    const maxAttempts = 5;

    while (_isMonitoringOKX && mounted) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeOKX != null &&
          DateTime.now().difference(_lastMessageTimeOKX!).inSeconds >= 30) {
        print(
            'No data from OKX for 30s. Reconnecting ($reconnectAttempts/$maxAttempts)...');
        await _okxChannel?.sink.close();
        await _connectWebSocketOKX();

        reconnectAttempts++;
        if (reconnectAttempts >= maxAttempts) {
          print('Max attempts reached for OKX. Waiting 1 minute...');
          await Future.delayed(Duration(minutes: 1));
          reconnectAttempts = 0;
        } else {
          await Future.delayed(
              Duration(seconds: pow(2, reconnectAttempts).toInt()));
        }
      } else {
        reconnectAttempts = 0;
      }
    }
    _isMonitoringOKX = false;
  }

  Future<void> _monitorHuobiConnection() async {
    _isMonitoringHuobi = true;
    int reconnectAttempts = 0;
    const maxAttempts = 5;

    while (_isMonitoringHuobi && mounted) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeHuobi != null &&
          DateTime.now().difference(_lastMessageTimeHuobi!).inSeconds >= 30) {
        print(
            'No data from Huobi for 30s. Reconnecting ($reconnectAttempts/$maxAttempts)...');
        await _huobiChannel?.sink.close();
        await _connectWebSocketHuobi();

        reconnectAttempts++;
        if (reconnectAttempts >= maxAttempts) {
          print('Max attempts reached for Huobi. Waiting 1 minute...');
          await Future.delayed(Duration(minutes: 1));
          reconnectAttempts = 0;
        } else {
          await Future.delayed(
              Duration(seconds: pow(2, reconnectAttempts).toInt()));
        }
      } else {
        reconnectAttempts = 0;
      }
    }
    _isMonitoringHuobi = false;
  }

  Future<void> _fetchCoinData() async {
    try {
      final spotResponse = await http
          .get(Uri.parse('https://fapi.binance.com/fapi/v3/exchangeInfo'));
      if (spotResponse.statusCode == 200) {
        final exchangeData = json.decode(spotResponse.body);
        coinsListForSelect.addAll((exchangeData['symbols'] as List)
            .where((symbol) => symbol['status'] == 'TRADING')
            .map((symbol) => {'symbol': symbol['symbol']})
            .toList());
      }

      final binanceResponse = await http
          .get(Uri.parse('https://fapi.binance.com/fapi/v1/exchangeInfo'));
      if (binanceResponse.statusCode == 200) {
        final exchangeData = json.decode(binanceResponse.body);
        coinsListForSelect.addAll((exchangeData['symbols'] as List)
            .where((symbol) =>
                symbol['status'] == 'TRADING' &&
                symbol['symbol'].endsWith('USDT') &&
                symbol['contractType'] == 'PERPETUAL')
            .map((symbol) => {'symbol': symbol['symbol']})
            .toList());
      }

      setState(() => selectedCoins
          .addAll(coinsListForSelect.map((e) => e['symbol'] as String)));

      final tickerResponse = await http
          .get(Uri.parse('https://fapi.binance.com/fapi/v1/ticker/24hr'));
      if (tickerResponse.statusCode == 200) {
        final tickerData = json.decode(tickerResponse.body) as List;

        final topGainers = tickerData
            .where((ticker) => ticker['symbol'].endsWith('USDT'))
            .map((ticker) => {
                  'symbol': ticker['symbol'],
                  'priceChangePercent':
                      double.parse(ticker['priceChangePercent'])
                })
            .toList();

        topGainers.sort((a, b) =>
            b['priceChangePercent'].compareTo(a['priceChangePercent']));

        setState(() =>
            selectedCoins.addAll(topGainers.map((e) => e['symbol'] as String)));
      }

      _loadSelectedCoins();
    } catch (e) {
      print('Error fetching coin data: $e');
    }
  }

  void _loadSelectedCoins() async {
    selectedCoins.addAll(cryptoList);
    coinsListForSelect = coinsListForSelect.toSet().toList();
    setState(() => selectedCoins = selectedCoins.toSet().toList());
    _connectWebSocketBinance();
    _connectWebSocketOKX();
    _connectWebSocketHuobi();
  }

  void _saveSelectedCoins() async {
    selectedCoins = selectedCoins.toSet().toList();
    await _storageService.saveSelectedCoins(selectedCoins);
    _connectWebSocketBinance();
    _connectWebSocketOKX();
    _connectWebSocketHuobi();
  }

  void _deleteCoins() async {
    await _storageService.deleteCoins();
    setState(() => selectedCoins = []);
    _connectWebSocketBinance();
    _connectWebSocketOKX();
    _connectWebSocketHuobi();
  }

  Future<void> _connectWebSocketBinance() async {
    if (selectedCoins.isEmpty) {
      await _channelSpotBinanceFeatured?.sink.close();
      return;
    }
    await _channelSpotBinanceFeatured?.sink.close();

    String streams =
        selectedCoins.map((coin) => '${coin.toLowerCase()}@ticker').join('/');

    _channelSpotBinanceFeatured = WebSocketChannel.connect(
        Uri.parse('wss://fstream.binance.com/ws/$streams'));

    _channelSpotBinanceFeatured!.stream.listen(
      _processMessageBinance,
      onDone: () =>
          Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
      onError: (error) {
        print('Binance WebSocket error: $error');
        Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance);
      },
      cancelOnError: true,
    );

    _lastMessageTimeBinance = DateTime.now();
    if (!_isMonitoringBinance) _monitorBinanceConnection();
  }

  Future<void> _connectWebSocketOKX() async {
    if (selectedCoins.isEmpty) {
      print('No coins selected for OKX');
      await _okxChannel?.sink.close();
      return;
    }

    await _okxChannel?.sink.close();

    final validCoins = selectedCoins
        .where((coin) => coin.endsWith("USDT"))
        .map((coin) => coin.replaceAll("USDT", "-USDT"))
        .toList();

    _okxChannel = WebSocketChannel.connect(
        Uri.parse('wss://ws.okx.com:8443/ws/v5/public'));

    _okxChannel!.sink.add(jsonEncode({
      "op": "subscribe",
      "args": validCoins
          .map((symbol) => {"channel": "tickers", "instId": symbol})
          .toList()
    }));

    _okxChannel!.stream.listen(
      _processMessageOKX,
      onDone: () =>
          Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX),
      onError: (error) {
        print('OKX WebSocket error: $error');
        Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX);
      },
      cancelOnError: true,
    );

    _lastMessageTimeOKX = DateTime.now();
    if (!_isMonitoringOKX) _monitorOKXConnection();
  }

  Future<void> _connectWebSocketHuobi() async {
    await _huobiChannel?.sink.close();

    if (selectedCoins.isEmpty) {
      print('No coins selected for Huobi');
      return;
    }

    try {
      _huobiChannel =
          WebSocketChannel.connect(Uri.parse('wss://api.huobi.pro/ws'));

      final validCoins = selectedCoins
          .where((coin) => coin.endsWith('USDT'))
          .map((coin) => coin.toLowerCase())
          .toList();

      for (var symbol in validCoins) {
        _huobiChannel!.sink.add(jsonEncode({
          'sub': 'market.$symbol.ticker',
          'id': symbol,
        }));
      }

      _huobiChannel!.stream.listen(
        _processMessageHuobi,
        onDone: () =>
            Future.delayed(Duration(seconds: 2), _connectWebSocketHuobi),
        onError: (error) {
          print('Huobi WebSocket error: $error');
          Future.delayed(Duration(seconds: 2), _connectWebSocketHuobi);
        },
        cancelOnError: false,
      );

      _lastMessageTimeHuobi = DateTime.now();
      if (!_isMonitoringHuobi) _monitorHuobiConnection();
    } catch (e) {
      print('Huobi connection failed: $e');
      Future.delayed(Duration(seconds: 2), _connectWebSocketHuobi);
    }
  }

  void _processMessageBinance(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic>) return;

    final symbol = data['s'];
    final price = double.parse(data['c']);
    final timestamp = DateTime.now();

    _lastMessageTimeBinance = timestamp;
    _storePrice(symbol, price, timestamp, ExchangeType.binanceFutures);
    _checkPriceChange(symbol, price, timestamp, ExchangeType.binanceFutures);
    _updateCoinsList(symbol, price, ExchangeType.binanceFutures);
  }

  void _processMessageOKX(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic> ||
        data['arg'] == null ||
        data['data'] == null) {
      return;
    }

    final symbol = data['arg']['instId'].replaceAll("-USDT", "USDT");
    final price = double.parse(data['data'][0]['last']);
    final timestamp = DateTime.now();

    _lastMessageTimeOKX = timestamp;
    _storePrice(symbol, price, timestamp, ExchangeType.okx);
    _checkPriceChange(symbol, price, timestamp, ExchangeType.okx);
    _updateCoinsList(symbol, price, ExchangeType.okx);
  }

  void _processMessageHuobi(dynamic message) {
    try {
      String jsonString;
      if (message is Uint8List) {
        final decompressed = GZipCodec().decode(message);
        jsonString = utf8.decode(decompressed);
      } else if (message is String) {
        jsonString = message;
      } else {
        return;
      }

      final data = json.decode(jsonString);
      if (data is! Map<String, dynamic>) return;

      if (data.containsKey('ping')) {
        _huobiChannel!.sink.add(jsonEncode({"pong": data['ping']}));
        _lastMessageTimeHuobi = DateTime.now();
        return;
      }

      if (data['ch'] == null || data['tick'] == null) return;

      final channel = data['ch'] as String;
      if (!channel.contains('market.') || !channel.endsWith('.ticker')) return;

      final symbol = channel.split('.')[1].toUpperCase();
      final priceStr = data['tick']['lastPrice'] as dynamic;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['ts'] as int);

      if (priceStr == null) {
        print('Huobi: Missing price in message: $data');
        return;
      }

      final price =
          priceStr is String ? double.parse(priceStr) : priceStr.toDouble();

      _lastMessageTimeHuobi = timestamp;
      _storePrice(symbol, price, timestamp, ExchangeType.huobi);
      _checkPriceChange(symbol, price, timestamp, ExchangeType.huobi);
      _updateCoinsList(symbol, price, ExchangeType.huobi);
    } catch (e) {}
  }

  void _storePrice(String symbol, double price, DateTime timestamp,
      ExchangeType exchangeType) {
    final history = switch (exchangeType) {
      ExchangeType.binanceFutures => _priceHistoryBinance,
      ExchangeType.okx => _priceHistoryOKX,
      ExchangeType.huobi => _priceHistoryHuobi,
    };

    final coinsList = switch (exchangeType) {
      ExchangeType.binanceFutures => _coinsListBinanceFeature,
      ExchangeType.okx => coinsListOKX,
      ExchangeType.huobi => coinsListHuobi,
    };

    history.putIfAbsent(symbol, () => []);
    final priceHistory = history[symbol]!;

    priceHistory.add({'price': price, 'timestamp': timestamp});

    priceHistory.removeWhere((entry) =>
        timestamp.difference(entry['timestamp']).inSeconds >= 6 * 60);

    if (priceHistory.length > 2500) {
      priceHistory.removeRange(0, priceHistory.length - 2500);
    }

    if (isHide && priceHistory.length > 1) {
      final previousPrice = priceHistory[priceHistory.length - 2]['price'];
      final changePercentage = ((price - previousPrice) / previousPrice) * 100;
      final coinIndex =
          coinsList.indexWhere((coin) => coin['symbol'] == symbol);

      if (coinIndex != -1) {
        setState(
            () => coinsList[coinIndex]['changePercentage'] = changePercentage);
      }
    }
  }

  void _checkPriceChange(String symbol, double currentPrice, DateTime timestamp,
      ExchangeType exchangeType) {
    _checkTimeFrame(symbol, currentPrice, timestamp, exchangeType);
  }

  Future<void> _checkTimeFrame(String symbol, double currentPrice,
      DateTime timestamp, ExchangeType exchangeType) async {
    final history = switch (exchangeType) {
      ExchangeType.binanceFutures => _priceHistoryBinance[symbol],
      ExchangeType.okx => _priceHistoryOKX[symbol],
      ExchangeType.huobi => _priceHistoryHuobi[symbol],
    };

    if (history == null || history.isEmpty) return;

    final cutoffTime = timestamp.subtract(maxTimeFrame);
    final oldPriceData = history.lastWhere(
      (entry) => entry['timestamp'].isBefore(cutoffTime),
      orElse: () => history.first,
    );

    final oldPrice = oldPriceData['price'];
    final changePercent = ((currentPrice - oldPrice) / oldPrice) * 100;

    double baseThreshold = priceChangeThreshold;
    double adjustedThreshold = baseThreshold;

    if (lowVolatilityCrypto.contains(symbol)) {
      adjustedThreshold = baseThreshold * 0.3;
    } else if (mediumVolatilityCrypto.contains(symbol)) {
      adjustedThreshold = baseThreshold * 0.65;
    }

    final timeDifference = timestamp.difference(oldPriceData['timestamp']);
    final isWithinTimeRange =
        timeDifference.inSeconds >= 0 && timeDifference.inMinutes <= 5;

    if (changePercent.abs() >= adjustedThreshold && isWithinTimeRange) {
      final lastNotificationTime = _lastNotificationTimes[symbol];

      if (lastNotificationTime == null ||
          timestamp.difference(lastNotificationTime) >=
              Duration(seconds: 150)) {
        final timeDifferenceMessage =
            _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);

        _lastNotificationTimes[symbol] = timestamp;

        final itemChart = await _fetchHistoricalData(symbol);
        final chartKey = GlobalKey();
        Uint8List? chartImage;

        double? lastCandleAddPercent;
        double? lastCandlePriceChangePercent;
        bool isLastCandleAdd = false;

        if (itemChart != null && itemChart.length >= 2) {
          final lastCandle = itemChart.last;
          final prevCandle = itemChart[itemChart.length - 2];
          lastCandlePriceChangePercent =
              ((lastCandle.close! - prevCandle.close!) / prevCandle.close!) *
                  100.abs();

          lastCandleAddPercent = lastCandlePriceChangePercent +
              (lastCandlePriceChangePercent * 0.4);
          isLastCandleAdd = lastCandleAddPercent.abs() >= changePercent.abs();
        }

        if (isLastCandleAdd) {
          if (itemChart != null && itemChart.isNotEmpty) {
            AudioPlayer().play(AssetSource('audio/coll.mp3'), volume: 0.8);

            setState(() => itemChartMain = itemChart);
            while (Navigator.of(context).canPop()) {
              await SchedulerBinding.instance.endOfFrame;
              await Future.delayed(Duration(milliseconds: 20));
            }

            await showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) {
                final height = MediaQuery.of(context).size.height;

                Future.delayed(Duration(milliseconds: 150), () async {
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });

                return Dialog(
                  insetPadding: const EdgeInsets.only(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: 0,
                  ),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: RepaintBoundary(
                        key: chartKey,
                        child: SfCartesianChart(
                          backgroundColor: Colors.black,
                          title: ChartTitle(
                              text:
                                  '   $symbol  $timeDifferenceMessage  ${changePercent.abs().toStringAsFixed(2)}%',
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              alignment: ChartAlignment.center,
                              borderWidth: 2.5),
                          trackballBehavior: TrackballBehavior(
                            enable: true,
                            activationMode: ActivationMode.singleTap,
                            tooltipAlignment: ChartAlignment.near,
                          ),
                          primaryXAxis: NumericAxis(isVisible: false),
                          zoomPanBehavior: ZoomPanBehavior(
                            enablePinching: true,
                            zoomMode: ZoomMode.xy,
                            selectionRectBorderWidth: 10,
                            enablePanning: true,
                            enableDoubleTapZooming: true,
                            enableMouseWheelZooming: true,
                            enableSelectionZooming: true,
                          ),
                          series: <CandleSeries>[
                            CandleSeries<ChartModel, int>(
                              enableSolidCandles: true,
                              enableTooltip: true,
                              dataSource: itemChartMain ?? [],
                              xValueMapper: (ChartModel sales, _) => sales.time,
                              lowValueMapper: (ChartModel sales, _) =>
                                  sales.low,
                              highValueMapper: (ChartModel sales, _) =>
                                  sales.high,
                              openValueMapper: (ChartModel sales, _) =>
                                  sales.open,
                              closeValueMapper: (ChartModel sales, _) =>
                                  sales.close,
                              animationDuration: 0,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );

            chartImage = await captureChart(chartKey);
          }

          if (chartImage != null) {
            final exchangeName = switch (exchangeType) {
              ExchangeType.binanceFutures => 'Binance',
              ExchangeType.okx => 'OKX',
              ExchangeType.huobi => 'Huobi',
            };

            _sendTelegramNotification(
              symbol,
              currentPrice,
              changePercent,
              timeDifferenceMessage,
              currentPrice,
              exchangeName,
              chartImage,
              volatility: _volatilityMap[symbol],
              lastCandleAvgPriceChangePercent:
                  lastCandlePriceChangePercent?.abs(),
            );
          }
        }
      }
    }
  }

  void _updateCoinsList(
      String symbol, double price, ExchangeType exchangeType) {
    if (!isHide) return;
    List<Map<String, dynamic>> coinsList;

    coinsList = switch (exchangeType) {
      ExchangeType.binanceFutures => _coinsListBinanceFeature,
      ExchangeType.okx => coinsListOKX,
      ExchangeType.huobi => coinsListHuobi,
    };

    final existingCoinIndex =
        coinsList.indexWhere((coin) => coin['symbol'] == symbol);

    if (existingCoinIndex == -1) {
      final newCoin = {
        'symbol': symbol,
        'price': price,
        'changePercentage': 0.0,
      };

      if (exchangeType == ExchangeType.binanceFutures) {
        _coinsListBinanceFeature.add(newCoin);
        setState(() {
          _coinsListBinanceFeature
              .where((coin) => selectedCoins.contains(coin['symbol']))
              .toList()
              .sort((a, b) => b['price'].compareTo(a['price']));
        });
      } else {
        setState(() => coinsList.add(newCoin));
      }
    } else {
      setState(() => coinsList[existingCoinIndex]['price'] = price);
    }
  }

  Future<List<ChartModel>?> _fetchHistoricalData(String symbol) async {
    int limit = 60;
    try {
      final binanceResponse = await http.get(Uri.parse(
          'https://api.binance.com/api/v1/klines?symbol=$symbol&interval=5m&limit=$limit'));

      if (binanceResponse.statusCode == 200) {
        final data = json.decode(binanceResponse.body) as List;
        return data.map((item) => ChartModel.fromJson(item)).toList();
      } else {
        return _fetchFromBybit(symbol, limit);
      }
    } catch (e) {
      print('Error fetching from Binance: $e');
      return _fetchFromBybit(symbol, limit);
    }
  }

  Future<List<ChartModel>?> _fetchFromBybit(String symbol, int limit) async {
    try {
      final bybitResponse = await http.get(Uri.parse(
          'https://api.bybit.com/v5/market/kline?category=linear&symbol=${symbol}&interval=5&limit=$limit'));

      if (bybitResponse.statusCode == 200) {
        final jsonData = json.decode(bybitResponse.body);
        final retCode = jsonData['retCode'] as int?;
        final retMsg = jsonData['retMsg'] as String?;

        if (retCode == 0 &&
            jsonData['result'] != null &&
            jsonData['result']['list'] != null) {
          final data = jsonData['result']['list'] as List;
          return data.map((item) => ChartModel.fromJson(item)).toList();
        } else {
          print('Bybit API error - retCode: $retCode, retMsg: $retMsg');
          return null;
        }
      } else {
        print('Bybit API failed. Status code: ${bybitResponse.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching from Bybit: $e');
      return null;
    }
  }

  String _getTimeDifferenceMessage(
      DateTime currentTime, DateTime lastUpdateTime) {
    final difference = currentTime.difference(lastUpdateTime);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds';
    } else {
      return '${difference.inMinutes} min';
    }
  }

  Future<void> _sendTelegramNotification(
    String symbol,
    double currentPrice,
    double changePercent,
    String time,
    double price,
    String exchange,
    Uint8List? chartImage, {
    double? volatility,
    double? lastCandleAvgPriceChangePercent,
  }) async {
    final String direction = changePercent > 0 ? '📈' : '📉';
    final String binanceUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}';

    final String caption = '''
$direction *$symbol ${changePercent.abs().toStringAsFixed(1)}%* $time $direction

🔹 *Last Candle * ${lastCandleAvgPriceChangePercent?.toStringAsFixed(2) ?? 'N/A'}% $isPlatform
🔹 *Binance Link:* [$symbol]($binanceUrl)
  '''
        .trim();

    final String url =
        'https://api.telegram.org/bot$telegramBotToken/sendPhoto';

    try {
      final uri = Uri.parse(url);
      http.Response response;

      if (chartImage != null && chartImage.isNotEmpty) {
        var request = http.MultipartRequest('POST', uri)
          ..fields['chat_id'] = chatId
          ..fields['caption'] = caption
          ..fields['parse_mode'] = 'Markdown'
          ..files.add(http.MultipartFile.fromBytes(
            'photo',
            chartImage,
            filename: 'chart_${symbol}.png',
          ));

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.post(
          uri.replace(path: '/bot$telegramBotToken/sendMessage'),
          body: {
            'chat_id': chatId,
            'caption': caption,
            'parse_mode': 'Markdown',
          },
        );
      }

      if (response.statusCode != 200) {
        print("Failed to send Telegram notification. "
            "Status code: ${response.statusCode}, Response: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("Error sending Telegram notification: $e");
      print("Stack trace: $stackTrace");
    }
  }

  void _openSelectCoinsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectCoinsScreen(
          availableCoins: coinsListForSelect,
          selectedCoins: selectedCoins,
          onCoinsSelected: (List<String> coins) {
            setState(() => selectedCoins = coins);
            _saveSelectedCoins();
          },
        ),
      ),
    );
  }

  void _savePriceChangeThreshold(double value) async {
    await _storageService.savePriceChangeThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoinsBinance = _coinsListBinanceFeature
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList()
      ..sort((a, b) => b['price'].compareTo(a['price']));

    final filteredCoinsOKX = coinsListOKX
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList()
      ..sort((a, b) => b['price'].compareTo(a['price']));

    final filteredCoinsHuobi = coinsListHuobi
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList()
      ..sort((a, b) => b['price'].compareTo(a['price']));

    double myHeight = MediaQuery.of(context).size.height;
    double myWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Text('Price: ${priceChangeThreshold.toStringAsFixed(1)}%'),
                  Expanded(
                    child: Slider(
                      value: priceChangeThreshold,
                      min: 0.4,
                      max: 10.0,
                      divisions: 99,
                      label: '${priceChangeThreshold.toStringAsFixed(1)}%',
                      onChanged: (double value) {
                        setState(() => priceChangeThreshold = value);
                        _savePriceChangeThreshold(value);
                      },
                    ),
                  ),
                  CupertinoSwitch(
                    value: isScreen,
                    onChanged: (bool value) {
                      setState(() => isScreen = value);
                      _storageService.saveSelectedScreen(value);
                    },
                    // activeTrackColor: Colors.deepPurpleAccent,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Center(
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => isHide = !isHide);
                            filteredCoinsBinance.clear();
                            filteredCoinsOKX.clear();
                            filteredCoinsHuobi.clear();
                          },
                          child: Text(isHide
                              ? 'F ${filteredCoinsBinance.length} : O ${filteredCoinsOKX.length} : H ${filteredCoinsHuobi.length}'
                              : 'Show List'),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _openSelectCoinsScreen,
                  child: Icon(Icons.search, size: 16),
                ),
                ElevatedButton(
                  onPressed: _deleteCoins,
                  child: Icon(Icons.delete, size: 16),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _coinsListBinanceFeature = [];
                    coinsListOKX = [];
                    coinsListHuobi = [];
                    coinsListForSelect = [];
                    itemChartMain = [];

                    await _channelSpotBinanceFeatured?.sink.close();
                    await _huobiChannel?.sink.close();
                    await _okxChannel?.sink.close();

                    // Navigator.pushReplacement(
                    //     context,
                    //     MaterialPageRoute(
                    //         builder: (context) => TokenPriceMonitorScreen()));
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TokenChartScreen()));
                  },
                  child: Icon(Icons.refresh, size: 16),
                ),
              ],
            ),
            SizedBox(
                height: myHeight * (isHide ? 0.35 : 0.60),
                width: kIsWeb ? (myWidth * 0.3 < 200 ? 400 : 400) : myWidth,
                child: RepaintBoundary(
                  key: _chartKey,
                  child: SfCartesianChart(
                    backgroundColor: Colors.black,
                    trackballBehavior: TrackballBehavior(
                      enable: true,
                      activationMode: ActivationMode.singleTap,
                      tooltipAlignment: ChartAlignment.near,
                    ),
                    primaryXAxis: NumericAxis(isVisible: false),
                    zoomPanBehavior: ZoomPanBehavior(
                      enablePinching: true,
                      zoomMode: ZoomMode.xy,
                      selectionRectBorderWidth: 10,
                      enablePanning: true,
                      enableDoubleTapZooming: true,
                      enableMouseWheelZooming: true,
                      enableSelectionZooming: true,
                    ),
                    series: <CandleSeries>[
                      CandleSeries<ChartModel, int>(
                        enableSolidCandles: true,
                        enableTooltip: true,
                        dataSource: itemChartMain ?? [],
                        xValueMapper: (ChartModel sales, _) => sales.time,
                        lowValueMapper: (ChartModel sales, _) => sales.low,
                        highValueMapper: (ChartModel sales, _) => sales.high,
                        openValueMapper: (ChartModel sales, _) => sales.open,
                        closeValueMapper: (ChartModel sales, _) => sales.close,
                        animationDuration: 0,
                      )
                    ],
                  ),
                )),
            if (isHide)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCoinsHuobi.length,
                  itemBuilder: (context, index) {
                    final coin = filteredCoinsHuobi[index];
                    return ListTile(
                      title: Text('(Huobi) ${coin['symbol']}'),
                      subtitle: Text(
                        'Price: ${coin['price']}',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      trailing: Text(
                        'Change: ${coin['changePercentage'].toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (isHide)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCoinsOKX.length,
                  itemBuilder: (context, index) {
                    final coin = filteredCoinsOKX[index];
                    return ListTile(
                      title: Text('(OKX) ${coin['symbol']}'),
                      subtitle: Text(
                        'Price: ${coin['price']}',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      trailing: Text(
                        'Change: ${coin['changePercentage'].toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (isHide)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCoinsBinance.length,
                  itemBuilder: (context, index) {
                    final coin = filteredCoinsBinance[index];
                    return ListTile(
                      title: Text('(Binance) ${coin['symbol']}'),
                      subtitle: Text(
                        'Price: ${coin['price']}',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      trailing: Text(
                        'Change: ${coin['changePercentage'].toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
