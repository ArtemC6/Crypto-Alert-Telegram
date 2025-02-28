import 'dart:async';
import 'dart:convert';

import 'package:binanse_notification/Screens/select_token.dart';
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  WebSocketChannel? _channelSpotBinanceFeatured,
      _channelSpotBinanceSpot,
      _okxChannelOne;

  late List<Map<String, dynamic>> _coinsListBinanceFeature,
      coinsListBinanceSpot,
      coinsListOKX;
  late List<Map<String, dynamic>> coinsListForSelect;

  List<String> selectedCoins = [];
  double priceChangeThreshold = 1.0;
  bool isHide = true, isOKXConnected = true;
  final isPlatform = kIsWeb ? 'Web' : 'Mobile';
  final Map<String, List<Map<String, dynamic>>> _priceHistoryBinance = {};
  final Map<String, List<Map<String, dynamic>>> _priceHistoryBinanceSpot = {};
  final Map<String, List<Map<String, dynamic>>> _priceHistoryOKX = {};

  final Map<String, Map<Duration, DateTime>> _lastNotificationTimesAll = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  late final StorageService _storageService;
  List<ChartModel>? itemChart;
  DateTime? _lastMessageTimeBinance, _lastMessageTimeOKX;
  bool _isMonitoringBinance = false, _isMonitoringOKX = false;

  bool isRefresh = true;
  final _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _coinsListBinanceFeature = [];
    coinsListBinanceSpot = [];
    coinsListOKX = [];
    coinsListForSelect = [];
    itemChart = [];

    _fetchAvailableCoins();
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

  Future<void> _fetchTopGainers() async {
    try {
      final response = await http
          .get(Uri.parse('https://fapi.binance.com/fapi/v1/ticker/24hr'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;

        final topGainers = data
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

        _saveSelectedCoins();
      }
    } catch (e) {
      print('Error fetching top gainers: $e');
    }
  }

  Future<void> _fetchAvailableCoins() async {
    try {
      final response = await http
          .get(Uri.parse('https://fapi.binance.com/fapi/v1/exchangeInfo'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        coinsListForSelect.addAll((data['symbols'] as List)
            .where((symbol) =>
                symbol['status'] == 'TRADING' &&
                symbol['symbol'].endsWith('USDT') &&
                symbol['contractType'] == 'PERPETUAL')
            .map((symbol) => {'symbol': symbol['symbol']})
            .toList());

        setState(() => selectedCoins
            .addAll(coinsListForSelect.map((e) => e['symbol'] as String)));
      }

      await _fetchTopGainers();
    } catch (e) {
      print('Error fetching available coins: $e');
    }

    _loadSelectedCoins();
  }

  void _loadSelectedCoins() async {
    selectedCoins = await _storageService.loadSelectedCoins();
    selectedCoins.addAll(cryptoList);
    setState(() => selectedCoins = selectedCoins.toSet().toList());
    _connectWebSocketBinance();
    _connectWebSocketOKX();
  }

  void _saveSelectedCoins() async {
    selectedCoins = selectedCoins.toSet().toList();
    await _storageService.saveSelectedCoins(selectedCoins);
    _connectWebSocketBinance();
    _connectWebSocketOKX();
  }

  void _deleteCoins() async {
    await _storageService.deleteCoins();
    setState(() => selectedCoins = []);
    _connectWebSocketBinance();
  }

  Future<void> _monitorOKXConnection() async {
    _isMonitoringOKX = true;
    while (_isMonitoringOKX) {
      await Future.delayed(Duration(seconds: 5));
      if (_lastMessageTimeOKX != null &&
          DateTime.now().difference(_lastMessageTimeOKX!).inSeconds >= 30) {
        print('No data received from Binance for 30 seconds. Reconnecting...');
        await _connectWebSocketOKX();
        break;
      }
    }
    _isMonitoringOKX = false;
  }

  Future<void> _connectWebSocketOKX() async {
    if (selectedCoins.isEmpty) {
      print('No coins selected for OKX');
      await _okxChannelOne?.sink.close();
      return;
    }

    await _okxChannelOne?.sink.close();

    final validCoins = selectedCoins
        .where((coin) => coin.endsWith("USDT"))
        .map((coin) => coin.replaceAll("USDT", "-USDT"))
        .take(200)
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
      onDone: () {
        if (!isOKXConnected) {
          print('OKX WebSocket connection closed. Reconnecting...');
          Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX);
        }
      },
      onError: (error) {
        if (!isOKXConnected) {
          print('OKX WebSocket error: $error. Reconnecting...');
          Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX);
        }
      },
      cancelOnError: true,
    );

    _lastMessageTimeOKX = DateTime.now();

    if (!_isMonitoringOKX) {
      _monitorOKXConnection();
    }
  }

  Future<void> _connectWebSocketBinance() async {
    if (selectedCoins.isEmpty) {
      await _channelSpotBinanceFeatured?.sink.close();
      await _channelSpotBinanceSpot?.sink.close();
      return;
    }
    await _channelSpotBinanceFeatured?.sink.close();
    await _channelSpotBinanceSpot?.sink.close();

    String streams =
        selectedCoins.map((coin) => '${coin.toLowerCase()}@ticker').join('/');

    _channelSpotBinanceFeatured = WebSocketChannel.connect(
        Uri.parse('wss://fstream.binance.com/ws/$streams'));

    // _channelSpotBinanceSpot = WebSocketChannel.connect(
    //     Uri.parse('wss://stream.binance.com/ws/$streams'));
    //
    // _channelSpotBinanceSpot!.stream.listen(
    //   _processMessageBinanceSpot,
    //   onDone: () =>
    //       Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
    //   onError: (error) =>
    //       Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
    //   cancelOnError: true,
    // );

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

    _storePriceOKX(symbol, price, timestamp);
    _checkPriceChangeOKX(symbol, price, timestamp);
    if (isHide) _updateCoinsListOKX(symbol, price);
  }

  void _processMessageBinance(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic>) return;

    final symbol = data['s'];
    final price = double.parse(data['c']);
    final timestamp = DateTime.now();

    _lastMessageTimeBinance = timestamp;
    _storePriceBinance(symbol, price, timestamp);
    _checkPriceChangeBinance(symbol, price, timestamp);
    if (isHide) _updateCoinsListBinance(symbol, price);
  }

  void _processMessageBinanceSpot(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic>) return;

    final symbol = data['s'];
    final price = double.parse(data['c']);
    final timestamp = DateTime.now();

    _lastMessageTimeBinance = timestamp;
    _storePriceBinanceSpot(symbol, price, timestamp);
    _checkPriceChangeBinanceSpot(symbol, price, timestamp);
    if (isHide) _updateCoinsListBinanceSpot(symbol, price);
  }

  void _storePriceBinance(String symbol, double price, DateTime timestamp) {
    _priceHistoryBinance.putIfAbsent(symbol, () => []);
    final history = _priceHistoryBinance[symbol]!;

    history.add({'price': price, 'timestamp': timestamp});

    if (history.length > 500) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >=
          Duration(minutes: 6).inMinutes);
    }
    if (isHide) {
      if (history.length > 1) {
        final previousPrice = history[history.length - 2]['price'];
        final changePercentage =
            ((price - previousPrice) / previousPrice) * 100;
        final coinIndex = _coinsListBinanceFeature
            .indexWhere((coin) => coin['symbol'] == symbol);
        if (coinIndex != -1) {
          setState(() => _coinsListBinanceFeature[coinIndex]
              ['changePercentage'] = changePercentage);
        }
      }
    }
  }

  void _storePriceBinanceSpot(String symbol, double price, DateTime timestamp) {
    _priceHistoryBinanceSpot.putIfAbsent(symbol, () => []);
    final history = _priceHistoryBinanceSpot[symbol]!;

    history.add({'price': price, 'timestamp': timestamp});

    if (history.length > 500) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >=
          Duration(minutes: 6).inMinutes);
    }
    if (isHide) {
      if (history.length > 1) {
        final previousPrice = history[history.length - 2]['price'];
        final changePercentage =
            ((price - previousPrice) / previousPrice) * 100;
        final coinIndex =
            coinsListBinanceSpot.indexWhere((coin) => coin['symbol'] == symbol);
        if (coinIndex != -1) {
          setState(() => coinsListBinanceSpot[coinIndex]['changePercentage'] =
              changePercentage);
        }
      }
    }
  }

  void _storePriceOKX(String symbol, double price, DateTime timestamp) {
    _priceHistoryOKX.putIfAbsent(symbol, () => []);
    final history = _priceHistoryOKX[symbol]!;

    history.add({'price': price, 'timestamp': timestamp});

    if (history.length > 500) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >=
          Duration(minutes: 6).inMinutes);
    }
    if (isHide) {
      if (history.length > 1) {
        final previousPrice = history[history.length - 2]['price'];
        final changePercentage =
            ((price - previousPrice) / previousPrice) * 100;
        final coinIndex =
            coinsListOKX.indexWhere((coin) => coin['symbol'] == symbol);
        if (coinIndex != -1) {
          setState(() =>
              coinsListOKX[coinIndex]['changePercentage'] = changePercentage);
        }
      }
    }
  }

  void _checkPriceChangeBinance(
      String symbol, double currentPrice, DateTime timestamp) {
    for (final timeFrame in timeFrames) {
      _checkTimeFrameBinance(symbol, currentPrice, timestamp, timeFrame);
    }
  }

  void _checkPriceChangeBinanceSpot(
      String symbol, double currentPrice, DateTime timestamp) {
    for (final timeFrame in timeFrames) {
      _checkTimeFrameBinanceSpot(symbol, currentPrice, timestamp, timeFrame);
    }
  }

  void _checkPriceChangeOKX(
      String symbol, double currentPrice, DateTime timestamp) {
    for (final timeFrame in timeFrames) {
      _checkTimeFrameOKX(symbol, currentPrice, timestamp, timeFrame);
    }
  }

  Future<void> _checkTimeFrameBinanceSpot(String symbol, double currentPrice,
      DateTime timestamp, Duration timeFrame) async {
    final history = _priceHistoryBinanceSpot[symbol];
    if (history == null || history.isEmpty) return;

    final cutoffTime = timestamp.subtract(timeFrame);
    final oldPriceData = history.lastWhere(
      (entry) => entry['timestamp'].isBefore(cutoffTime),
      orElse: () => {},
    );

    if (oldPriceData.isEmpty) return;

    final oldPrice = oldPriceData['price'];
    final changePercent = ((currentPrice - oldPrice) / oldPrice) * 100;

    double threshold = priceChangeThreshold;
    if (lowVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.60;
    }

    if (mediumVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.85;
    }

    if (changePercent.abs() >= threshold) {
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

          if (itemChart != null) {
            while (Navigator.of(context).canPop()) {
              await Future.delayed(Duration(milliseconds: 50));
            }

            await showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) {
                Future.delayed(Duration(milliseconds: 100), () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });

                return Dialog(
                  insetPadding: EdgeInsets.zero, // Removes default padding
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
                          primaryXAxis: NumericAxis(
                            isVisible: false,
                          ),
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
          }

          chartImage = await captureChart(chartKey);

          if (chartImage != null) {
            _sendTelegramNotification(
              symbol,
              currentPrice,
              changePercent,
              timeDifferenceMessage,
              currentPrice,
              'Binance(S)',
              chartImage,
            );
          }
        }
      }
    }
  }

  Future<void> _checkTimeFrameBinance(String symbol, double currentPrice,
      DateTime timestamp, Duration timeFrame) async {
    final history = _priceHistoryBinance[symbol];
    if (history == null || history.isEmpty) return;

    final cutoffTime = timestamp.subtract(timeFrame);
    final oldPriceData = history.lastWhere(
      (entry) => entry['timestamp'].isBefore(cutoffTime),
      orElse: () => {},
    );

    if (oldPriceData.isEmpty) return;

    final oldPrice = oldPriceData['price'];
    final changePercent = ((currentPrice - oldPrice) / oldPrice) * 100;

    double threshold = priceChangeThreshold;
    if (lowVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.60;
    }

    if (mediumVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.85;
    }

    if (changePercent.abs() >= threshold) {
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

          if (itemChart != null) {
            while (Navigator.of(context).canPop()) {
              await Future.delayed(Duration(milliseconds: 20));
            }

            await showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) {
                Future.delayed(Duration(milliseconds: 50), () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });

                return Dialog(
                  insetPadding: EdgeInsets.zero, // Removes default padding
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
                          primaryXAxis: NumericAxis(
                            isVisible: false,
                          ),
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
          }

          chartImage = await captureChart(chartKey);

          if (chartImage != null) {
            _sendTelegramNotification(
              symbol,
              currentPrice,
              changePercent,
              timeDifferenceMessage,
              currentPrice,
              'Binance(F)',
              chartImage,
            );
          }
        }
      }
    }
  }

  Future<void> _checkTimeFrameOKX(String symbol, double currentPrice,
      DateTime timestamp, Duration timeFrame) async {
    final history = _priceHistoryOKX[symbol];
    if (history == null || history.isEmpty) return;

    final cutoffTime = timestamp.subtract(timeFrame);
    final oldPriceData = history.lastWhere(
      (entry) => entry['timestamp'].isBefore(cutoffTime),
      orElse: () => {},
    );

    if (oldPriceData.isEmpty) return;

    final oldPrice = oldPriceData['price'];
    final changePercent = ((currentPrice - oldPrice) / oldPrice) * 100;

    double threshold = priceChangeThreshold;
    if (lowVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.60;
    }

    if (mediumVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.85;
    }

    if (changePercent.abs() >= threshold) {
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

          if (itemChart != null) {
            while (Navigator.of(context).canPop()) {
              await Future.delayed(Duration(milliseconds: 20));
            }
            await showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) {
                Future.delayed(Duration(milliseconds: 50), () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });

                return Dialog(
                  insetPadding: EdgeInsets.zero, // Removes default padding
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
                          primaryXAxis: NumericAxis(
                            isVisible: false,
                          ),
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
          }

          chartImage = await captureChart(chartKey);

          if (chartImage != null) {
            _sendTelegramNotification(
              symbol,
              currentPrice,
              changePercent,
              timeDifferenceMessage,
              currentPrice,
              'OKX',
              chartImage,
            );
          }
        }
      }
    }
  }

  void _updateCoinsListBinanceSpot(String symbol, double price) {
    final existingCoinIndex =
        coinsListBinanceSpot.indexWhere((coin) => coin['symbol'] == symbol);

    if (existingCoinIndex == -1) {
      setState(() => coinsListBinanceSpot.add({
            'symbol': symbol,
            'price': price,
            'changePercentage': 0.0,
          }));
    } else {
      setState(() => coinsListBinanceSpot[existingCoinIndex]['price'] = price);
    }
  }

  void _updateCoinsListBinance(String symbol, double price) {
    final existingCoinIndex =
        _coinsListBinanceFeature.indexWhere((coin) => coin['symbol'] == symbol);

    if (existingCoinIndex == -1) {
      _coinsListBinanceFeature.add({
        'symbol': symbol,
        'price': price,
        'changePercentage': 0.0,
      });
    } else {
      _coinsListBinanceFeature[existingCoinIndex]['price'] = price;
    }

    setState(() {
      _coinsListBinanceFeature
          .where((coin) => selectedCoins.contains(coin['symbol']))
          .toList()
          .sort((a, b) => b['price'].compareTo(a['price']));
    });
  }

  void _updateCoinsListOKX(String symbol, double price) {
    final existingCoinIndex =
        coinsListOKX.indexWhere((coin) => coin['symbol'] == symbol);

    if (existingCoinIndex == -1) {
      setState(() => coinsListOKX.add({
            'symbol': symbol,
            'price': price,
            'changePercentage': 0.0,
          }));
    } else {
      setState(() => coinsListOKX[existingCoinIndex]['price'] = price);
    }
  }

  Future<List<ChartModel>?> _fetchHistoricalData(
    String symbol,
  ) async {
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
        return await _fetchFromBybit(symbol, limit);
      }
    } catch (e) {
      print('Error fetching from Binance: $e');
      return await _fetchFromBybit(symbol, limit);
    }
  }

  Future<List<ChartModel>?> _fetchFromBybit(String symbol, int limit) async {
    try {
      final bybitResponse = await http.get(Uri.parse(
          'https://api.bybit.com/v5/market/kline?category=spot&symbol=$symbol&interval=5&limit=$limit'));

      if (bybitResponse.statusCode == 200) {
        final data = json.decode(bybitResponse.body);
        final List bybitData = data['result']['list'];
        setState(() => itemChart =
            bybitData.map((item) => ChartModel.fromJson(item)).toList());
        return itemChart;
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
    Uint8List? chartImage,
  ) async {
    final String direction = changePercent > 0 ? '📈' : '📉';
    final String binanceUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}';

    final String caption = '''
$direction *$symbol ($exchange)* $direction

🔹 *Symbol:* [$symbol]($symbol)
🔹 *Change:* ${changePercent.abs().toStringAsFixed(1)}%
🔹 *Timeframe:* $time
🔹 *Platform:* $exchange
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

  void _toggleOKXConnection() {
    if (isOKXConnected) {
      _okxChannelOne?.sink.close();
      coinsListOKX.clear();
      setState(() => isOKXConnected = false);
    } else {
      _connectWebSocketOKX();
      setState(() => isOKXConnected = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoinsBinance = _coinsListBinanceFeature
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList();

    final filteredCoinsOKX = coinsListOKX
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
            SizedBox(
              height: 4,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Text(
                      'Price change threshold: ${priceChangeThreshold.toStringAsFixed(1)}%'),
                  Expanded(
                    child: Slider(
                      value: priceChangeThreshold,
                      min: 0.3,
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
                              setState(() {
                                isHide = !isHide;
                              });
                            },
                            child: Text(!isHide
                                ? 'F ${filteredCoinsBinance.length} : S ${coinsListBinanceSpot.length} : O ${filteredCoinsOKX.length}'
                                : 'F ${filteredCoinsBinance.length} : S ${coinsListBinanceSpot.length} : O ${filteredCoinsOKX.length}'),
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
                  CupertinoSwitch(
                    value: isOKXConnected,
                    onChanged: (bool value) {
                      _toggleOKXConnection();
                    },
                    activeTrackColor: Colors.deepPurpleAccent,
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
                    primaryXAxis: NumericAxis(
                      isVisible: false,
                    ),
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
                        dataSource: itemChart!,
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
            if (isHide && isOKXConnected)
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
