import 'dart:async';
import 'dart:convert';

import 'package:binanse_notification/Screens/select_token.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../const.dart';
import '../model/chart.dart';
import '../services/storage.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WebSocketChannel? _channelSpotBinance, _channelOrderBookBinance, _okxChannel;
  WebSocketChannel? _channelPumpFun;

  late List<Map<String, dynamic>> coinsListBinance, coinsListOKX;
  late List<Map<String, dynamic>> coinsListForSelect;

  List<String> selectedCoins = [];
  double priceChangeThreshold = 1.0;
  bool isHide = true, isOKXConnected = true;

  final Map<String, List<Map<String, dynamic>>> _priceHistoryBinance = {};
  final Map<String, Map<Duration, DateTime>> _lastNotificationTimesAll = {};
  final Map<String, DateTime> _lastNotificationTimes = {};

  final Map<String, List<Map<String, dynamic>>> _priceHistoryOKX = {};

  late final StorageService _storageService;
  Map<String, Map<String, dynamic>> _orderBooks = {};
  final Set<String> _shownNotifications = {};
  late TrackballBehavior trackballBehavior;

  List<ChartModel>? itemChart;

  bool isRefresh = true;

  @override
  void initState() {
    super.initState();
    trackballBehavior = TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap);
    _storageService = StorageService();
    coinsListBinance = [];
    coinsListOKX = [];
    coinsListForSelect = [];
    itemChart = []; // Инициализация

    _loadSelectedCoins();
    _fetchAvailableCoins();
    _loadPriceChangeThreshold();
  }

  Future<void> _fetchHistoricalData(String symbol, {int limit = 1000}) async {
    print(symbol);
    try {
      final response = await http.get(Uri.parse(
          'https://api.binance.com/api/v3/klines?symbol=$symbol&interval=1h&limit=$limit'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          itemChart = data.map((item) => ChartModel.fromJson(item)).toList();
        });
      } else {
        print('Failed to load historical data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching historical data: $e');
    }
  }

  void _connectWebSocketOrderBookBinance() {
    if (selectedCoins.isEmpty) {
      _channelOrderBookBinance?.sink.close();
      return;
    }

    _channelOrderBookBinance?.sink.close();

    String streams = selectedCoins.map((coin) => '${coin.toLowerCase()}@depth').join('/');

    _channelOrderBookBinance =
        WebSocketChannel.connect(Uri.parse('wss://stream.binance.com:9443/ws/$streams'));
    // WebSocketChannel.connect(Uri.parse('wss://fstream.binance.com/ws/$streams'));

    _channelOrderBookBinance!.stream.listen(
      (message) {
        _processOrderBookMessageBinance(message);
      },
      onDone: () => Future.delayed(const Duration(seconds: 5), _connectWebSocketOrderBookBinance),
      onError: (error) =>
          Future.delayed(const Duration(seconds: 5), _connectWebSocketOrderBookBinance),
      cancelOnError: true,
    );
  }

  void _processOrderBookMessageBinance(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic> ||
        !data.containsKey('b') ||
        !data.containsKey('a') ||
        !data.containsKey('s')) {
      return;
    }

    final symbol = data['s'];
    final bids = data['b'].cast<List<dynamic>>();
    final asks = data['a'].cast<List<dynamic>>();

    final currentPrice = double.tryParse(asks.isNotEmpty ? asks[0][0] : bids[0][0]) ?? 0.0;

    final orderBook = {
      'symbol': symbol,
      'bids': bids,
      'asks': asks,
      'timestamp': DateTime.now().millisecondsSinceEpoch, // Время обновления
    };

    setState(() {
      _orderBooks[symbol] = orderBook;
    });

    List<dynamic> oldestOrder = [];
    double lowestValue = double.infinity;
    String action = '';
    double volumeInUsdt = 0.0;

    // Проверяем биды
    for (final bid in bids) {
      if (bid.length > 1) {
        final bidValue = double.tryParse(bid[1]) ?? double.infinity;
        if (bidValue < lowestValue) {
          lowestValue = bidValue;
          oldestOrder = bid;
          action = 'BUY'; // Если ордер из бидов, то это покупка
          volumeInUsdt = (double.tryParse(bid[1]) ?? 0.0) * (double.tryParse(bid[0]) ?? 0.0);
        }
      }
    }

    // Проверяем аски
    for (final ask in asks) {
      if (ask.length > 1) {
        final askValue = double.tryParse(ask[1]) ?? double.infinity;
        if (askValue < lowestValue) {
          lowestValue = askValue;
          oldestOrder = ask;
          action = 'SELL'; // Если ордер из асков, то это продажа
          volumeInUsdt = (double.tryParse(ask[1]) ?? 0.0) * (double.tryParse(ask[0]) ?? 0.0);
        }
      }
    }

    if (oldestOrder.isNotEmpty) {
      final orderPrice = double.tryParse(oldestOrder[0]) ?? 0.0;
      final priceDifference = (orderPrice - currentPrice).abs();
      if (orderPrice != currentPrice) {
        // Рассчитываем процентное изменение
        double percentageDifference = (priceDifference / currentPrice) * 100;

        // Показываем уведомление только если процентное изменение больше 1%
        if (percentageDifference >= 1 && volumeInUsdt > 80000) {
          final notificationContent =
              "$symbol $action Цена $orderPrice - текущая $currentPrice, разница"
              " ${priceDifference.toStringAsFixed(2)} (${percentageDifference.toStringAsFixed(2)}%), Объем ${volumeInUsdt.toStringAsFixed(1)} USDT";
          if (!_shownNotifications.contains(notificationContent)) {
            print(notificationContent);
            _shownNotifications.add(notificationContent); // Add to shown notifications
            // showNotification(symbol, action, orderPrice, priceDifference, currentPrice,
            //     percentageDifference, volumeInUsdt);
          }
        }
      }
    }
  }

  void showNotification(
    String symbol,
    String action,
    double orderPrice,
    double priceDifference,
    double currentPrice,
    double percentageDifference,
    double volumeInUsdt,
  ) {
    String notification =
        "$symbol $action Цена $orderPrice - текущая $currentPrice, разница ${priceDifference.toStringAsFixed(2)}"
        " (${percentageDifference.toStringAsFixed(2)}%), Объем ${volumeInUsdt.toStringAsFixed(1)} USDT";
    print(notification); // Временное решение для отладки
  }

  Future<void> _fetchTopGainers() async {
    try {
      final response = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/24hr'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;

        final topGainers = data
            .where((ticker) => ticker['symbol'].endsWith('USDT'))
            .map((ticker) => {
                  'symbol': ticker['symbol'],
                  'priceChangePercent': double.parse(ticker['priceChangePercent'])
                })
            .toList();

        topGainers.sort((a, b) => b['priceChangePercent'].compareTo(a['priceChangePercent']));

        coinsListForSelect.addAll(topGainers.take(24).toList());
        coinsListForSelect = coinsListForSelect.toSet().toList();
        setState(() => selectedCoins.addAll(topGainers.take(24).map((e) => e['symbol'] as String)));

        _saveSelectedCoins();
      }
    } catch (e) {
      print('Error fetching top gainers: $e');
    }
  }

  Future<void> _fetchAvailableCoins() async {
    try {
      final response = await http.get(Uri.parse('https://api.binance.com/api/v3/exchangeInfo'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => coinsListForSelect.addAll((data['symbols'] as List)
            .where((symbol) => symbol['status'] == 'TRADING' && symbol['symbol'].endsWith('USDT'))
            .map((symbol) => {'symbol': symbol['symbol']})
            .toList()));
      }
    } catch (e) {
      print('Error fetching available coins: $e');
    }
  }

  void _connectWebSocketOKX() {
    if (selectedCoins.isEmpty) {
      print('No coins selected for OKX');
      _okxChannel?.sink.close();
      return;
    }

    _okxChannel?.sink.close();

    final validCoins = selectedCoins
        .where((coin) => coin.endsWith("USDT"))
        .map((coin) => coin.replaceAll("USDT", "-USDT"))
        .toList();

    _okxChannel = WebSocketChannel.connect(Uri.parse('wss://ws.okx.com:8443/ws/v5/public'));

    _okxChannel!.sink.add(jsonEncode({
      "op": "subscribe",
      "args": validCoins.map((symbol) => {"channel": "tickers", "instId": symbol}).toList()
    }));

    _okxChannel!.stream.listen(
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
  }

  void _processMessageOKX(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic> || data['arg'] == null || data['data'] == null) {
      return;
    }

    final symbol = data['arg']['instId'].replaceAll("-USDT", "USDT");
    final price = double.parse(data['data'][0]['last']);
    final timestamp = DateTime.now();

    _storePriceOKX(symbol, price, timestamp);
    _checkPriceChangeOKX(symbol, price, timestamp);
    if (isHide) _updateCoinsListOKX(symbol, price);
  }

  void _loadSelectedCoins() async {
    selectedCoins = await _storageService.loadSelectedCoins();
    selectedCoins.addAll(cryptoList);
    setState(() => selectedCoins
    = selectedCoins.toSet().toList());
    _connectWebSocketBinance();
    _connectWebSocketOKX();

    // _connectWebSocketOrderBookBinance();
  }

  void _connectWebSocketBinance() {
    if (selectedCoins.isEmpty) {
      _channelSpotBinance?.sink.close();
      return;
    }
    _channelSpotBinance?.sink.close();

    String streams = selectedCoins.map((coin) => '${coin.toLowerCase()}@ticker').join('/');
    _channelSpotBinance =
        WebSocketChannel.connect(Uri.parse('wss://stream.binance.com/ws/$streams'));

    _channelSpotBinance!.stream.listen(
      _processMessageBinance,
      onDone: () => Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
      onError: (error) => Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
      cancelOnError: true,
    );
  }

  void _saveSelectedCoins() async {
    selectedCoins = selectedCoins.toSet().toList();
    await _storageService.saveSelectedCoins(selectedCoins);
    _connectWebSocketBinance();
  }

  void _deleteCoins() async {
    await _storageService.deleteCoins();
    setState(() => selectedCoins = []);
    _connectWebSocketBinance();
  }

  void _processMessageBinance(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic>) return;

    final symbol = data['s'];
    final price = double.parse(data['c']);
    final timestamp = DateTime.now();

    _storePriceBinance(symbol, price, timestamp);
    _checkPriceChangeBinance(symbol, price, timestamp);
    if (isHide) _updateCoinsListBinance(symbol, price);
  }

  void _storePriceBinance(String symbol, double price, DateTime timestamp) {
    _priceHistoryBinance.putIfAbsent(symbol, () => []);
    final history = _priceHistoryBinance[symbol]!;

    history.add({'price': price, 'timestamp': timestamp});


    if (history.length > 1000) {
      print(history.length);

      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >= Duration(minutes: 6).inMinutes);
    }
    if (isHide) {
      if (history.length > 1) {
        final previousPrice = history[history.length - 2]['price'];
        final changePercentage = ((price - previousPrice) / previousPrice) * 100;
        final coinIndex = coinsListBinance.indexWhere((coin) => coin['symbol'] == symbol);
        if (coinIndex != -1) {
          setState(() => coinsListBinance[coinIndex]['changePercentage'] = changePercentage);
        }
      }
    }
  }

  void _storePriceOKX(String symbol, double price, DateTime timestamp) {
    _priceHistoryOKX.putIfAbsent(symbol, () => []);
    final history = _priceHistoryOKX[symbol]!;

    history.add({'price': price, 'timestamp': timestamp});

    if (history.length > 1000) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >= Duration(minutes: 6).inMinutes);
    }
    if (isHide) {
      if (history.length > 1) {
        final previousPrice = history[history.length - 2]['price'];
        final changePercentage = ((price - previousPrice) / previousPrice) * 100;
        final coinIndex = coinsListOKX.indexWhere((coin) => coin['symbol'] == symbol);
        if (coinIndex != -1) {
          setState(() => coinsListOKX[coinIndex]['changePercentage'] = changePercentage);
        }
      }
    }
  }

  void _checkPriceChangeBinance(String symbol, double currentPrice, DateTime timestamp) {
    for (final timeFrame in timeFrames) {
      _checkTimeFrameBinance(symbol, currentPrice, timestamp, timeFrame);
    }
  }

  void _checkPriceChangeOKX(String symbol, double currentPrice, DateTime timestamp) {
    for (final timeFrame in timeFrames) {
      _checkTimeFrameOKX(symbol, currentPrice, timestamp, timeFrame);
    }
  }

  void _checkTimeFrameBinance(
      String symbol, double currentPrice, DateTime timestamp, Duration timeFrame) {
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
      threshold = priceChangeThreshold * 0.65;
    }

    if (mediumVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.80;
    }

    if (changePercent.abs() >= threshold) {
      final lastNotificationTime = _lastNotificationTimesAll[symbol]?[timeFrame];
      final lastNotificationTimeForSymbol = _lastNotificationTimes[symbol];

      if (lastNotificationTimeForSymbol == null ||
          timestamp.difference(lastNotificationTimeForSymbol) >= Duration(seconds: 45)) {
        if (lastNotificationTime == null ||
            timestamp.difference(lastNotificationTime) >= timeFrame) {
          final timeDifferenceMessage =
              _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);

          _sendTelegramNotification(
              symbol, currentPrice, changePercent, timeDifferenceMessage, currentPrice, 'Binance');

          _lastNotificationTimesAll.putIfAbsent(symbol, () => {});
          _lastNotificationTimesAll[symbol]![timeFrame] = timestamp;
          _lastNotificationTimes[symbol] = timestamp;
          history.remove(oldPriceData);
        }
      }
    }
  }

  void _checkTimeFrameOKX(
      String symbol, double currentPrice, DateTime timestamp, Duration timeFrame) {
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
      threshold = priceChangeThreshold * 0.65;
    }

    if (mediumVolatilityCrypto.contains(symbol)) {
      threshold = priceChangeThreshold * 0.80;
    }

    if (changePercent.abs() >= threshold) {
      final lastNotificationTime = _lastNotificationTimesAll[symbol]?[timeFrame];
      final lastNotificationTimeForSymbol = _lastNotificationTimes[symbol];

      if (lastNotificationTimeForSymbol == null ||
          timestamp.difference(lastNotificationTimeForSymbol) >= Duration(seconds: 45)) {
        if (lastNotificationTime == null ||
            timestamp.difference(lastNotificationTime) >= timeFrame) {
          final timeDifferenceMessage =
              _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);

          _sendTelegramNotification(
              symbol, currentPrice, changePercent, timeDifferenceMessage, currentPrice, 'OKX');

          _lastNotificationTimesAll.putIfAbsent(symbol, () => {});
          _lastNotificationTimesAll[symbol]![timeFrame] = timestamp;
          _lastNotificationTimes[symbol] = timestamp;
          history.remove(oldPriceData);
        }
      }
    }
  }

  void _updateCoinsListBinance(String symbol, double price) {
    final existingCoinIndex = coinsListBinance.indexWhere((coin) => coin['symbol'] == symbol);

    if (existingCoinIndex == -1) {
      setState(() => coinsListBinance.add({
            'symbol': symbol,
            'price': price,
            'changePercentage': 0.0,
          }));
    } else {
      setState(() => coinsListBinance[existingCoinIndex]['price'] = price);
    }
  }

  void _updateCoinsListOKX(String symbol, double price) {
    final existingCoinIndex = coinsListOKX.indexWhere((coin) => coin['symbol'] == symbol);

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

  String _getTimeDifferenceMessage(DateTime currentTime, DateTime lastUpdateTime) {
    final difference = currentTime.difference(lastUpdateTime);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds';
    } else {
      return '${difference.inMinutes} min';
    }
  }

  Future<void> _sendTelegramNotification(
    String symbol,
    double changePercentage,
    double changeDirection,
    String time,
    double currentPrice,
    String exchange,
  ) async {
    final String direction = changeDirection > 0 ? '📈' : '📉';

    final String binanceUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}';

    final String message = '''
$direction *$symbol ($exchange)* $direction

🔹 *Symbol:* [$symbol]($symbol)
🔹 *Change:* ${changeDirection.abs().toStringAsFixed(1)}%  
🔹 *Timeframe:* $time
🔹 *Binance Link:* [$symbol]($binanceUrl)

💵 *Current Price:* ${currentPrice.toStringAsFixed(2)} USD  
  '''
        .trim();

    final String encodedMessage = Uri.encodeComponent(message);

    final String url =
        'https://api.telegram.org/bot$telegramBotToken/sendMessage?chat_id=$chatId&text=$encodedMessage&parse_mode=Markdown';

    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Telegram notification sent successfully!");
      } else {
        print("Failed to send notification to Telegram. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error sending notification to Telegram: $e");
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
    setState(() {
      priceChangeThreshold = priceChangeThreshold;
    });
  }

  void _savePriceChangeThreshold(double value) async {
    await _storageService.savePriceChangeThreshold(value);
  }

  void _toggleOKXConnection() {
    if (isOKXConnected) {
      _okxChannel?.sink.close();
      coinsListOKX.clear();
      setState(() => isOKXConnected = false);
    } else {
      _connectWebSocketOKX();
      setState(() => isOKXConnected = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoinsBinance = coinsListBinance
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList()
      ..sort((a, b) => b['price'].compareTo(a['price']));

    final filteredCoinsOKX = coinsListOKX
        .where((coin) => selectedCoins.contains(coin['symbol']))
        .toList()
      ..sort((a, b) => b['price'].compareTo(a['price']));

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // SfCartesianChart(
            //   trackballBehavior: trackballBehavior,
            //   zoomPanBehavior: ZoomPanBehavior(
            //       enablePinching: true, zoomMode: ZoomMode.x),
            //   series: <CandleSeries>[
            //     CandleSeries<ChartModel, int>(
            //         enableSolidCandles: true,
            //         enableTooltip: true,
            //         bullColor: Colors.green,
            //         bearColor: Colors.red,
            //         dataSource: itemChart!,
            //         xValueMapper: (ChartModel sales, _) =>
            //         sales.time,
            //         lowValueMapper: (ChartModel sales, _) =>
            //         sales.low,
            //         highValueMapper: (ChartModel sales, _) =>
            //         sales.high,
            //         openValueMapper: (ChartModel sales, _) =>
            //         sales.open,
            //         closeValueMapper: (ChartModel sales, _) =>
            //         sales.close,
            //         animationDuration: 55)
            //   ],
            // ),

            SizedBox(
              height: 4,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Text('Price change threshold: ${priceChangeThreshold.toStringAsFixed(1)}%'),
                  Expanded(
                    child: Slider(
                      value: priceChangeThreshold,
                      min: 0.1,
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
                                ? 'Show ${filteredCoinsBinance.length} : ${filteredCoinsOKX.length}'
                                : 'Hide ${filteredCoinsBinance.length} : ${filteredCoinsOKX.length}'),
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
                    onPressed: () => _fetchTopGainers(),
                    child: Text('Top'),
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

            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  alignment: WrapAlignment.center,
                  children: selectedCoins
                      .map((coin) => InkWell(
                            onTap: () => FlutterClipboard.copy(coin).then((_) {
                              _fetchHistoricalData(coin);
                              return ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Скопировано: $coin'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                coin,
                                style:
                                    TextStyle(fontSize: isHide ? 13.5 : 15.5, color: Colors.white),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),

            // Expanded(
            //   child: ListView.builder(
            //     itemCount: _orderBooks.length,
            //     itemBuilder: (context, index) {
            //       final symbol = _orderBooks.keys.elementAt(index);
            //       final orderBook = _orderBooks[symbol]!;
            //       return Card(
            //         margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            //         elevation: 6,
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(16),
            //         ),
            //         color: Colors.grey[900],
            //         // Darker background
            //         child: Theme(
            //           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            //           child: ExpansionTile(
            //             iconColor: Colors.white,
            //             collapsedIconColor: Colors.white,
            //             textColor: Colors.white,
            //             backgroundColor: Colors.grey[900],
            //             initiallyExpanded: false,
            //             title: Row(
            //               children: [
            //                 Icon(Icons.list_alt, size: 20, color: Colors.white),
            //                 SizedBox(width: 8),
            //                 Expanded(
            //                   child: Text(
            //                     'Order Book for ${orderBook['symbol']}',
            //                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            //                     overflow: TextOverflow.ellipsis,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //             children: [
            //               _buildOrderTable(
            //                   'Bids', orderBook['bids'] as List<List<dynamic>>, Colors.green),
            //               VerticalDivider(color: Colors.grey[700], thickness: 1),
            //               _buildOrderTable(
            //                   'Asks', orderBook['asks'] as List<List<dynamic>>, Colors.red),
            //             ],
            //           ),
            //         ),
            //       );
            //     },
            //   ),
            // )

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
                          color: coin['changePercentage'] < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                      trailing: Text(
                        'Change: ${coin['changePercentage'].toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0 ? Colors.red : Colors.green,
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
                          color: coin['changePercentage'] < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                      trailing: Text(
                        'Change: ${coin['changePercentage'].toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: coin['changePercentage'] < 0 ? Colors.red : Colors.green,
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

Widget _buildOrderTable(String title, List<List<dynamic>> orders, Color color) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order[0]}',
                        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      '${order[1]}',
                      style: TextStyle(color: color.withOpacity(0.7), fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
