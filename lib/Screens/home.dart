import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io'; // Добавлен для GZipCodec

import 'package:binanse_notification/Screens/select_token.dart';
import 'package:binanse_notification/Screens/twitter_monitor_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../const.dart';
import '../model/chart.dart';
import '../services/storage.dart';
import '../utils.dart';

enum ExchangeType { binanceFutures, okx, huobi }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  WebSocketChannel? _channelSpotBinanceFeatured, _okxChannelOne, _huobiChannel;

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
  final Map<String, Map<Duration, DateTime>> _lastNotificationTimesAll = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  late final StorageService _storageService;
  List<ChartModel>? itemChart;
  DateTime? _lastMessageTimeBinance, _lastMessageTimeOKX, _lastMessageTimeHuobi;
  bool _isMonitoringBinance = false,
      _isMonitoringOKX = false,
      _isMonitoringHuobi = false;

  bool isRefresh = true;
  final _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _coinsListBinanceFeature = [];
    coinsListOKX = [];
    coinsListHuobi = [];
    coinsListForSelect = [];
    itemChart = [];
    _fetchCoinData();
    _loadPriceChangeThreshold();
  }

  Future<void> _monitorBinanceConnection() async {
    _isMonitoringBinance = true;
    while (_isMonitoringBinance) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeBinance != null &&
          DateTime.now().difference(_lastMessageTimeBinance!).inSeconds >= 30) {
        print('No data received from Binance for 30 seconds. Reconnecting...');
        await _connectWebSocketBinance();
        break;
      }
    }
    _isMonitoringBinance = false;
  }

  Future<void> _monitorOKXConnection() async {
    _isMonitoringOKX = true;
    while (_isMonitoringOKX) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeOKX != null &&
          DateTime.now().difference(_lastMessageTimeOKX!).inSeconds >= 30) {
        print('No data received from OKX for 30 seconds. Reconnecting...');
        await _connectWebSocketOKX();
        break;
      }
    }
    _isMonitoringOKX = false;
  }

  Future<void> _monitorHuobiConnection() async {
    _isMonitoringHuobi = true;
    int reconnectAttempts = 0;
    const maxAttempts = 5;

    while (_isMonitoringHuobi) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeHuobi != null &&
          DateTime.now().difference(_lastMessageTimeHuobi!).inSeconds >= 30) {
        print(
            'No data from Huobi for 30 seconds. Attempting reconnect (${reconnectAttempts + 1}/$maxAttempts)...');
        await _huobiChannel?.sink.close();
        await _connectWebSocketHuobi();

        reconnectAttempts++;
        if (reconnectAttempts >= maxAttempts) {
          print('Max reconnection attempts reached for Huobi. Pausing...');
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

        coinsListForSelect = coinsListForSelect.toSet().toList();
        setState(() => selectedCoins
            .addAll(topGainers.take(24).map((e) => e['symbol'] as String)));
      }

      _loadSelectedCoins();
    } catch (e) {
      print('Error fetching coin data: $e');
    }
  }

  void _loadSelectedCoins() async {
    selectedCoins = await _storageService.loadSelectedCoins();
    selectedCoins.addAll(cryptoList);
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
      onError: (error) =>
          Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
      cancelOnError: true,
    );

    _lastMessageTimeBinance = DateTime.now();

    if (!_isMonitoringBinance) {
      _monitorBinanceConnection();
    }
  }

  Future<void> _connectWebSocketOKX() async {
    if (selectedCoins.isEmpty) {
      await _okxChannelOne?.sink.close();
      return;
    }

    await _okxChannelOne?.sink.close();

    final validCoins = selectedCoins
        .where((coin) => coin.endsWith("USDT"))
        .map((coin) => coin.replaceAll("USDT", "-USDT"))
        .toList();

    _okxChannelOne = WebSocketChannel.connect(
        Uri.parse('wss://ws.okx.com:8443/ws/v5/public'));

    _okxChannelOne!.sink.add(jsonEncode({
      "op": "subscribe",
      "args": validCoins
          .map((symbol) => {"channel": "tickers", "instId": symbol})
          .toList()
    }));

    _okxChannelOne!.stream.listen(
      _processMessageOKX,
      onDone: () =>
          Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX),
      onError: (error) =>
          Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX),
      cancelOnError: true,
    );

    _lastMessageTimeOKX = DateTime.now();

    if (!_isMonitoringOKX) {
      _monitorOKXConnection();
    }
  }

  Future<void> _connectWebSocketHuobi() async {
    // Закрываем существующее соединение, если оно есть
    await _huobiChannel?.sink.close();

    // Проверяем наличие выбранных монет
    if (selectedCoins.isEmpty) {
      print('No coins selected for Huobi, connection not established');
      return;
    }

    try {
      // Устанавливаем соединение
      _huobiChannel = WebSocketChannel.connect(Uri.parse('wss://api.huobi.pro/ws'));

      // Фильтруем и преобразуем монеты
      final validCoins = selectedCoins
          .where((coin) => coin.endsWith('USDT'))
          .map((coin) => coin.toLowerCase())
          .toList();

      // Подписываемся на стримы
      for (var symbol in validCoins) {
        _huobiChannel!.sink.add(jsonEncode({
          'sub': 'market.$symbol.ticker',
          'id': symbol,
        }));
      }

      // Настраиваем периодический пинг для поддержания соединения
      Timer? pingTimer;
      pingTimer = Timer.periodic(Duration(seconds: 10), (timer) {
        if (_huobiChannel?.closeCode != null) {
          timer.cancel();
          return;
        }
        _huobiChannel!.sink.add(jsonEncode({
          'ping': DateTime.now().millisecondsSinceEpoch,
        }));
      });

      // Слушаем поток сообщений
      _huobiChannel!.stream.listen(
        _processMessageHuobi,
        onDone: () {
          // print('Huobi WebSocket closed with code: ${_huobiChannel!.closeCode}');
          pingTimer?.cancel();
          Future.delayed(Duration(seconds: 2), _connectWebSocketHuobi);
        },
        onError: (error) {
          print('Huobi WebSocket error: $error');
          pingTimer?.cancel();
          Future.delayed(Duration(seconds: 2), _connectWebSocketHuobi);
        },
        cancelOnError: false,
      );

      _lastMessageTimeHuobi = DateTime.now();

      // Запускаем мониторинг, если он еще не активен
      if (!_isMonitoringHuobi) {
        _monitorHuobiConnection();
      }
    } catch (e) {
      print('Failed to connect to Huobi WebSocket: $e');
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
        print('Huobi: Unexpected message type: ${message.runtimeType}');
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
    } catch (e) {
      print('Huobi: Error processing message: $e, Message: $message');
    }
  }

  double _calculateVolatility(String symbol, ExchangeType exchangeType) {
    final history = switch (exchangeType) {
      ExchangeType.binanceFutures => _priceHistoryBinance[symbol],
      ExchangeType.okx => _priceHistoryOKX[symbol],
      ExchangeType.huobi => _priceHistoryHuobi[symbol],
    };

    if (history == null || history.length < 10) return 0.0;

    final prices = history.map((e) => e['price'] as double).toList();
    final mean = prices.reduce((a, b) => a + b) / prices.length;
    final variance =
        prices.map((p) => pow(p - mean, 2)).reduce((a, b) => a + b) /
            prices.length;
    return sqrt(variance);
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

    if (priceHistory.length > 500) {
      priceHistory.removeAt(0);
    } else {
      priceHistory.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >=
          Duration(minutes: 6).inMinutes);
    }

    _volatilityMap[symbol] = _calculateVolatility(symbol, exchangeType);

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
    for (final timeFrame in timeFrames) {
      _checkTimeFrame(symbol, currentPrice, timestamp, timeFrame, exchangeType);
    }
  }

  Future<void> _checkTimeFrame(String symbol, double currentPrice,
      DateTime timestamp, Duration timeFrame, ExchangeType exchangeType) async {
    final history = switch (exchangeType) {
      ExchangeType.binanceFutures => _priceHistoryBinance[symbol],
      ExchangeType.okx => _priceHistoryOKX[symbol],
      ExchangeType.huobi => _priceHistoryHuobi[symbol],
    };

    if (history == null || history.isEmpty) return;

    final cutoffTime = timestamp.subtract(timeFrame);
    final oldPriceData = history.lastWhere(
      (entry) => entry['timestamp'].isBefore(cutoffTime),
      orElse: () => {},
    );

    if (oldPriceData.isEmpty) return;

    final oldPrice = oldPriceData['price'];
    final changePercent = ((currentPrice - oldPrice) / oldPrice) * 100;

    double baseThreshold = priceChangeThreshold;
    double adjustedThreshold = baseThreshold;

    final volatility = _volatilityMap[symbol] ?? 0.0;
    adjustedThreshold = baseThreshold * (1 + volatility / 100);

    if (lowVolatilityCrypto.contains(symbol)) {
      adjustedThreshold = baseThreshold * 0.40;
    } else if (mediumVolatilityCrypto.contains(symbol)) {
      adjustedThreshold = baseThreshold * 0.70;
    }

    if (changePercent.abs() >= adjustedThreshold) {
      final lastNotificationTime =
          _lastNotificationTimesAll[symbol]?[timeFrame];
      final lastNotificationTimeForSymbol = _lastNotificationTimes[symbol];

      if (lastNotificationTimeForSymbol == null ||
          timestamp.difference(lastNotificationTimeForSymbol) >=
              Duration(seconds: 200)) {
        if (lastNotificationTime == null ||
            timestamp.difference(lastNotificationTime) >= timeFrame) {
          final timeDifferenceMessage =
              _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);

          _lastNotificationTimesAll.putIfAbsent(symbol, () => {});
          _lastNotificationTimesAll[symbol]![timeFrame] = timestamp;
          _lastNotificationTimes[symbol] = timestamp;
          history.remove(oldPriceData);

          final itemChart = await _fetchHistoricalData(symbol);
          final chartKey = GlobalKey();
          Uint8List? chartImage;

          if (itemChart != null && itemChart.isNotEmpty && mounted) {
            while (Navigator.of(context).canPop()) {
              await Future.delayed(Duration(milliseconds: 20));
            }

            if (mounted) {
              await showDialog(
                context: context,
                barrierColor: Colors.transparent,
                builder: (context) {
                  final height = MediaQuery.of(context).size.height;

                  Future.delayed(Duration(milliseconds: 50), () {
                    if (Navigator.canPop(context) && mounted) {
                      Navigator.pop(context);
                    }
                  });

                  return Dialog(
                    insetPadding: EdgeInsets.only(
                      left: 0,
                      right: 0,
                      bottom: height * 0.15,
                      top: height * 0.15,
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
                              CandleSeries<ChartModel, int>(
                                enableSolidCandles: true,
                                enableTooltip: true,
                                dataSource: itemChart,
                                xValueMapper: (ChartModel sales, _) =>
                                    sales.time,
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
          }

          if (chartImage != null) {
            final exchangeName = switch (exchangeType) {
              ExchangeType.binanceFutures => 'Binance(F)',
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

    switch (exchangeType) {
      case ExchangeType.binanceFutures:
        coinsList = _coinsListBinanceFeature;
        break;
      case ExchangeType.okx:
        coinsList = coinsListOKX;
        break;
      case ExchangeType.huobi:
        coinsList = coinsListHuobi;
        break;
    }

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
    int limit = 55;

    setState(() {});

    try {
      final binanceResponse = await http.get(Uri.parse(
          'https://fapi.binance.com/fapi/v1/klines?symbol=$symbol&interval=5m&limit=$limit'));

      if (binanceResponse.statusCode == 200) {
        final data = json.decode(binanceResponse.body) as List;
        setState(() =>
            itemChart = data.map((item) => ChartModel.fromJson(item)).toList());
        return itemChart;
      } else {
        print('Binance API failed. Status code: ${binanceResponse.statusCode}');
        return await _fetchFromHuobi(symbol, limit);
      }
    } catch (e) {
      print('Error fetching from Binance: $e');
      return await _fetchFromHuobi(symbol, limit);
    }
  }

  Future<List<ChartModel>?> _fetchFromHuobi(String symbol, int limit) async {
    try {
      final huobiSymbol = symbol.toLowerCase();
      final huobiResponse = await http.get(Uri.parse(
          'https://api.huobi.pro/market/history/kline?period=5min&size=$limit&symbol=$huobiSymbol'));

      if (huobiResponse.statusCode == 200) {
        final data = json.decode(huobiResponse.body);
        if (data['status'] == 'ok') {
          final klineData = data['data'] as List;
          setState(() => itemChart = klineData
              .map((item) => ChartModel(
                    time: item['id'].toDouble(),
                    open: item['open'].toDouble(),
                    high: item['high'].toDouble(),
                    low: item['low'].toDouble(),
                    close: item['close'].toDouble(),
                  ))
              .toList());
          return itemChart;
        } else {
          print('Huobi API error: ${data['err-msg']}');
          return null;
        }
      } else {
        print('Huobi API failed. Status code: ${huobiResponse.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching from Huobi: $e');
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
  }) async {
    final String direction = changePercent > 0 ? '📈' : '📉';
    final String binanceUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}';

    final String caption = '''
$direction *$symbol ($exchange)* $direction

🔹 *Symbol:* [$symbol]($symbol)
🔹 *Change:* ${changePercent.abs().toStringAsFixed(1)}%
🔹 *Timeframe:* $time
🔹 *Volatility:* ${volatility?.toStringAsFixed(2) ?? 'N/A'}%
🔹 *Platform:* $isPlatform
🔹 *Binance Link:* [$symbol]($binanceUrl)

💵 *Current Price:* ${currentPrice.toStringAsFixed(2)} USD
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

      if (response.statusCode == 200) {
        print(
            "Telegram notification ${chartImage != null ? 'with chart' : 'without chart'} sent successfully!");
      } else {
        print("Failed to send notification to Telegram."
            "Status code: ${response.statusCode}. "
            "Response: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("Error sending notification to Telegram: $e");
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

  void _loadPriceChangeThreshold() async {
    priceChangeThreshold = await _storageService.loadPriceChangeThreshold();
    setState(() => priceChangeThreshold = priceChangeThreshold);
  }

  void _savePriceChangeThreshold(double value) async {
    await _storageService.savePriceChangeThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoinsBinance = _coinsListBinanceFeature
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList()..sort((a, b) => b['price'].compareTo(a['price']));

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
                  Text(
                      'Price change threshold: ${priceChangeThreshold.toStringAsFixed(1)}%'),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Center(
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => isHide = !isHide);

                              filteredCoinsBinance.clear();
                              filteredCoinsOKX.clear();
                              filteredCoinsHuobi.clear();
                            },
                            child: Text(!isHide
                                ? 'F ${filteredCoinsBinance.length} : O ${filteredCoinsOKX.length} : H ${filteredCoinsHuobi.length}'
                                : 'F ${filteredCoinsBinance.length} : O ${filteredCoinsOKX.length} : H ${filteredCoinsHuobi.length}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openSelectCoinsScreen,
                    child: Icon(Icons.search, size: 18),
                  ),
                  SizedBox(width: 1),
                  ElevatedButton(
                    onPressed: _deleteCoins,
                    child: Icon(Icons.delete, size: 18),
                  ),
                  SizedBox(width: 1),
                  ElevatedButton(
                    onPressed: () async {
                      _coinsListBinanceFeature = [];
                      coinsListOKX = [];
                      coinsListHuobi = [];
                      coinsListForSelect = [];
                      itemChart = [];
                      setState(() {});
                      _fetchCoinData();
                      _loadPriceChangeThreshold();
                    },
                    child: Icon(Icons.refresh, size: 18),
                  ),
                ],
              ),
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
                        dataSource: itemChart ?? [],
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
