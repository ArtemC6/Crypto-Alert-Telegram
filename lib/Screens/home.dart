import 'dart:async';
import 'dart:convert';

import 'package:binanse_notification/Screens/select_token.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../const.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WebSocketChannel? _channelSpotBinance, _channelStopFuture, _byBitChannel;
  late List<Map<String, dynamic>> coinsList;
  late List<Map<String, dynamic>> coinsListForSelect;

  List<String> selectedCoins = [];
  double priceChangeThreshold = 1.0;
  bool isHide = true, isByBitActive = false;

  final Map<String, List<Map<String, dynamic>>> _priceHistory = {};
  final Map<String, Map<Duration, DateTime>> _lastNotificationTimes = {};
  final Duration _historyDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    coinsList = [];
    coinsListForSelect = [];
    _loadSelectedCoins();
    _fetchAvailableCoins();
    _loadPriceChangeThreshold();
  }
  void _connectWebSocketByBit() {
    if (cryptoListByBit.isEmpty) {
      _byBitChannel?.sink.close();
      return;
    }
    _byBitChannel?.sink.close();  // Close any previous connection
    const int maxStreamsPerRequest = 10;

    final chunks = List.generate(
      (cryptoListByBit.length / maxStreamsPerRequest).ceil(),
          (i) => cryptoListByBit.sublist(
        i * maxStreamsPerRequest,
        (i + 1) * maxStreamsPerRequest > cryptoListByBit.length
            ? cryptoListByBit.length
            : (i + 1) * maxStreamsPerRequest,
      ),
    );

    for (var chunk in chunks) {
      final validTopics = chunk
          .map((coin) => coin.endsWith("USDT") ? 'publicTrade.${coin.toUpperCase()}' : null)
          .where((topic) => topic != null)
          .cast<String>()
          .toList();

      if (validTopics.isNotEmpty) {
        _byBitChannel =
            WebSocketChannel.connect(Uri.parse('wss://stream.bybit.com/v5/public/spot'));

        _byBitChannel!.sink.add(jsonEncode({
          "op": "subscribe",
          "args": validTopics,
        }));

        _byBitChannel!.stream.listen(
          _processMessageByBit,
          onDone: () => Future.delayed(const Duration(seconds: 5), _connectWebSocketByBit),
          onError: (error) => Future.delayed(const Duration(seconds: 5), _connectWebSocketByBit),
          cancelOnError: true,
        );
      }
    }
  }



  void _processMessageByBit(dynamic message) {
    final data = json.decode(message);
    if (data is! Map<String, dynamic> || data['topic'] == null || data['data'] == null) return;

    final symbol = data['topic'].split('.')[1];
    final price = double.parse(data['data'][0]['p']);
    final timestamp = DateTime.now();

    _storePrice(symbol, price, timestamp);
    _checkPriceChange(symbol, price, timestamp);
    if (isHide) _updateCoinsList(symbol, price);
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

  void _loadSelectedCoins() async {
    setState(() => selectedCoins = cryptoList);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => selectedCoins = prefs.getStringList('selectedCoins') ?? []);
    _connectWebSocketBinance();
    // _connectWebSocketByBit();
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
    // _channelStopFuture =
    //     WebSocketChannel.connect(Uri.parse('wss://fstream.binance.com/ws/$streams'));

    _channelSpotBinance!.stream.listen(
      _processMessageBinance,
      onDone: () => Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
      onError: (error) => Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
      cancelOnError: true,
    );

    // _channelStopFuture!.stream.listen(
    //   _processMessageBinance,
    //   onDone: () => Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
    //   onError: (error) => Future.delayed(const Duration(seconds: 5), _connectWebSocketBinance),
    //   cancelOnError: true,
    // );
  }

  void _saveSelectedCoins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('selectedCoins', selectedCoins);
    _connectWebSocketBinance();
  }

  void _deleteCoins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('selectedCoins');
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
    const timeFrames = [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 3),
      Duration(minutes: 5),
    ];

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
    final String bybitUrl = 'https://www.bybit.com/en/trade/spot/${symbol.toLowerCase()}';

    // Ссылка для открытия в приложении Binance (используем веб-ссылку)
    final String binanceAppUrl =
        'https://www.binance.com/en/trade/${symbol.replaceAll("USDT", "_USDT")}?layout=pro';

    final String message = '''
🚨 *Price Alert!* 🚨
  
🔹 *Symbol:* [$symbol]($binanceUrl)
🔹 *Direction:* $direction $directionText
🔹 *Change:* ${changeDirection.toStringAsFixed(1)}%
🔹 *Timeframe:* $time

💵 *Current Price:* $currentPrice

🔗 [View on Binance Future]($binanceUrl)  
🔗 [View on Binance] Spot]($binanceAppUrl)
🔗 [View on Bybit]($bybitUrl)

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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      priceChangeThreshold = prefs.getDouble('priceChangeThreshold') ?? 1.0;
    });
  }

  void _savePriceChangeThreshold(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('priceChangeThreshold', value);
  }

  void _toggleByBitConnection() {
    if (isByBitActive) {
      print('ByBit connection closed');
      _byBitChannel?.sink.close();
      _byBitChannel = null;  // Reset the channel after closing it
    } else {
      // Подключаемся к Bybit
      _connectWebSocketByBit();
    }
    setState(() {
      isByBitActive = !isByBitActive;
    });
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
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: _toggleByBitConnection,
                      child: Text(isByBitActive ? 'Disconnect from Bybit' : 'Connect to Bybit'),
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
