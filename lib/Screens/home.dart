import 'dart:async';
import 'dart:convert';

import 'package:binanse_notification/Screens/select_token.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../const.dart';
import '../services/storage.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WebSocketChannel? _channelSpotBinance, _channelStopFuture, _okxChannel;

  late List<Map<String, dynamic>> coinsListBinance, coinsListOKX;
  late List<Map<String, dynamic>> coinsListForSelect;

  List<String> selectedCoins = [];
  double priceChangeThreshold = 1.0;
  bool isHide = true, isOKXConnected = false;

  final Map<String, List<Map<String, dynamic>>> _priceHistoryBinance = {};
  final Map<String, Map<Duration, DateTime>> _lastNotificationTimesBinance = {};

  final Map<String, List<Map<String, dynamic>>> _priceHistoryOKX = {};
  final Map<String, Map<Duration, DateTime>> _lastNotificationTimesOKX = {};

  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    coinsListBinance = [];
    coinsListOKX = [];
    coinsListForSelect = [];
    _loadSelectedCoins();
    _fetchAvailableCoins();
    _loadPriceChangeThreshold();
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

        coinsListForSelect.addAll(topGainers.take(14).toList());
        setState(() => selectedCoins.addAll(topGainers.take(14).map((e) => e['symbol'] as String)));

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
    setState(() {});
    _connectWebSocketBinance();
  }

  void _connectWebSocketBinance() {
    if (selectedCoins.isEmpty) {
      _channelSpotBinance?.sink.close();
      _channelStopFuture?.sink.close();
      return;
    }
    _channelSpotBinance?.sink.close();
    _channelStopFuture?.sink.close();

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

    if (history.length > 500) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >= Duration(minutes: 10).inMinutes);
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

    if (history.length > 500) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >= Duration(minutes: 10).inMinutes);
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

    if (changePercent.abs() >= priceChangeThreshold) {
      final lastNotificationTime = _lastNotificationTimesBinance[symbol]?[timeFrame];
      if (lastNotificationTime == null || timestamp.difference(lastNotificationTime) >= timeFrame) {
        history.remove(oldPriceData);

        final timeDifferenceMessage =
            _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);
        _sendTelegramNotification(
            symbol, currentPrice, changePercent, timeDifferenceMessage, currentPrice, 'Binance');

        _lastNotificationTimesBinance.putIfAbsent(symbol, () => {});
        _lastNotificationTimesBinance[symbol]![timeFrame] = timestamp;
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

    if (changePercent.abs() >= priceChangeThreshold) {
      final lastNotificationTime = _lastNotificationTimesOKX[symbol]?[timeFrame];
      if (lastNotificationTime == null || timestamp.difference(lastNotificationTime) >= timeFrame) {
        history.remove(oldPriceData);

        final timeDifferenceMessage =
            _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);
        _sendTelegramNotification(
            symbol, currentPrice, changePercent, timeDifferenceMessage, currentPrice, 'OKX');

        _lastNotificationTimesOKX.putIfAbsent(symbol, () => {});
        _lastNotificationTimesOKX[symbol]![timeFrame] = timestamp;
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
    final String directionText = changeDirection > 0 ? 'up' : 'down';

    final String binanceUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}';

    final String message = '''
🚨 *$symbol ($exchange)* 🚨

🔹 *Symbol:* [$symbol]($symbol)
🔹 *Direction:* $direction $directionText
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
            SizedBox(
              height: 12,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _openSelectCoinsScreen,
                    child: Text('Select'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _deleteCoins,
                    child: Text('Delete'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      _fetchTopGainers();
                    },
                    child: Text('Top 10'),
                  ),
                  SizedBox(width: 10),
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Selected Coins: ${selectedCoins.join(', ')}',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            Center(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isHide = !isHide;
                        });
                      },
                      child: Text(!isHide
                          ? 'Show'
                          : 'Hide ${filteredCoinsBinance.length} : ${filteredCoinsOKX.length}'),
                    ),
                  ),
                ],
              ),
            ),
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
