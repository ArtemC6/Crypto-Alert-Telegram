import 'dart:async';
import 'dart:convert';

import 'package:binanse_notification/Screens/select_token.dart';
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

  late List<Map<String, dynamic>> coinsList;
  late List<Map<String, dynamic>> coinsListForSelect;

  List<String> selectedCoins = [];
  double priceChangeThreshold = 1.0;
  bool isHide = true, isByBitActive = false;

  final Map<String, List<Map<String, dynamic>>> _priceHistory = {};
  final Map<String, Map<Duration, DateTime>> _lastNotificationTimes = {};
  final Duration _historyDuration = Duration(minutes: 5);

  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    coinsList = [];
    coinsListForSelect = [];
    _loadSelectedCoins();
    _fetchAvailableCoins();
    _loadPriceChangeThreshold();
  }

  Future<void> _fetchAvailableCoins() async {
    try {
      final response = await http.get(Uri.parse('https://api.binance.com/api/v3/exchangeInfo'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          coinsListForSelect = (data['symbols'] as List)
              .where((symbol) => symbol['status'] == 'TRADING' && symbol['symbol'].endsWith('USDT'))
              .map((symbol) => {'symbol': symbol['symbol']})
              .toList();
        });
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
        print('OKX WebSocket connection closed. Reconnecting...');
        Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX);
      },
      onError: (error) {
        print('OKX WebSocket error: $error. Reconnecting...');
        Future.delayed(const Duration(seconds: 5), _connectWebSocketOKX);
      },
      cancelOnError: true,
    );
  }

  void _processMessageOKX(dynamic message) {
    print('Received message from OKX: $message');
    final data = json.decode(message);
    if (data is! Map<String, dynamic> || data['arg'] == null || data['data'] == null) {
      print('Invalid message format or not a ticker');
      return;
    }

    final symbol = data['arg']['instId'].replaceAll("-USDT", "USDT");
    final price = double.parse(data['data'][0]['last']);
    final timestamp = DateTime.now();

    print('Processing OKX data: $symbol, $price, $timestamp');

    _storePrice(symbol, price, timestamp);
    _checkPriceChange(symbol, price, timestamp);
    if (isHide) _updateCoinsList(symbol, price);
  }

  void _loadSelectedCoins() async {
    selectedCoins = await _storageService.loadSelectedCoins();
    setState(() => selectedCoins = selectedCoins);
    _connectWebSocketBinance();
    // _connectWebSocketOKX();
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

    _storePrice(symbol, price, timestamp);
    _checkPriceChange(symbol, price, timestamp);
    if (isHide) _updateCoinsList(symbol, price);
  }

  void _storePrice(String symbol, double price, DateTime timestamp) {
    _priceHistory.putIfAbsent(symbol, () => []);
    final history = _priceHistory[symbol]!;

    history.add({'price': price, 'timestamp': timestamp});

    if (history.length > 300) {
      history.removeAt(0);
    } else {
      history.removeWhere((entry) =>
          timestamp.difference(entry['timestamp']).inMinutes >= _historyDuration.inMinutes);
    }
    if (isHide) {
      if (history.length > 1) {
        final previousPrice = history[history.length - 2]['price'];
        final changePercentage = ((price - previousPrice) / previousPrice) * 100;
        final coinIndex = coinsList.indexWhere((coin) => coin['symbol'] == symbol);
        if (coinIndex != -1) {
          setState(() => coinsList[coinIndex]['changePercentage'] = changePercentage);
        }
      }
    }
  }

  void _checkPriceChange(String symbol, double currentPrice, DateTime timestamp) {
    for (final timeFrame in timeFrames) {
      _checkTimeFrame(symbol, currentPrice, timestamp, timeFrame);
    }
  }

  void _checkTimeFrame(String symbol, double currentPrice, DateTime timestamp, Duration timeFrame) {
    final history = _priceHistory[symbol];
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
      final lastNotificationTime = _lastNotificationTimes[symbol]?[timeFrame];
      if (lastNotificationTime == null || timestamp.difference(lastNotificationTime) >= timeFrame) {
        history.remove(oldPriceData);

        final timeDifferenceMessage =
            _getTimeDifferenceMessage(timestamp, oldPriceData['timestamp']);
        _sendTelegramNotification(
            symbol, currentPrice, changePercent, timeDifferenceMessage, currentPrice);

        _lastNotificationTimes.putIfAbsent(symbol, () => {});
        _lastNotificationTimes[symbol]![timeFrame] = timestamp;
      }
    }
  }

  void _updateCoinsList(String symbol, double price) {
    final existingCoinIndex = coinsList.indexWhere((coin) => coin['symbol'] == symbol);

    if (existingCoinIndex == -1) {
      setState(() => coinsList.add({
            'symbol': symbol,
            'price': price,
            'changePercentage': 0.0,
          }));
    } else {
      setState(() => coinsList[existingCoinIndex]['price'] = price);
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
  ) async {
    final String direction = changeDirection > 0 ? '📈' : '📉';
    final String directionText = changeDirection > 0 ? 'up' : 'down';

    // Формируем ссылки на Binance и Bybit
    final String binanceUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}';

    final String message = '''
🚨 *Price Alert!* 🚨
  
🔹 *Symbol:* [$symbol]($binanceUrl)
🔹 *Direction:* $direction $directionText
🔹 *Change:* ${changeDirection.toStringAsFixed(1)}%
🔹 *Timeframe:* $time

💵 *Current Price:* $currentPrice


  ''';

    final String encodedMessage = Uri.encodeComponent(message);

    final String url =
        'https://api.telegram.org/bot$telegramBotToken/sendMessage?chat_id=$chatId&text=$encodedMessage&parse_mode=Markdown';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Telegram notification sent!");
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

  @override
  Widget build(BuildContext context) {
    final filteredCoins = coinsList.where((coin) => selectedCoins.contains(coin['symbol'])).toList()
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
                children: [
                  ElevatedButton(
                    onPressed: _openSelectCoinsScreen,
                    child: Text('Select Coins for Notifications'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _deleteCoins,
                    child: Text('Delete Coins'),
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
                      child: Text(!isHide ? 'Show' : 'Hide ${filteredCoins.length}'),
                    ),
                  ),
                ],
              ),
            ),
            if (isHide)
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCoins.length,
                  itemBuilder: (context, index) {
                    final coin = filteredCoins[index];
                    return ListTile(
                      title: Text(coin['symbol']),
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
