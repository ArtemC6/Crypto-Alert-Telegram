import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'Screens/select_token.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebSocketChannel _channel, _byBitChannel;
  late Map<String, double> previousPrices;
  late Map<String, DateTime> lastUpdateTimes;
  late List<Map<String, dynamic>> coinsList;
  final String telegramBotToken = '8117770504:AAEOirevwh7Lj3xASFm3y0dqwK1QE9C1_VU';
  final String chatId = '1288898832';

  int selectedTime = 30; // Выбранное время для проверки изменений (в минутах)
  List<String> selectedCoins = [];
  String selectedPair = 'USDT';
  double priceChangeThreshold = 1.0;
  bool isHide = true;

  late Map<String, List<double>> priceHistory;
  double quickChangeThreshold = 1; // Порог для резких изменений (в процентах)
  int quickCheckTime = 1; // Время, за которое будет отслеживаться изменение (в секундах)

  @override
  void initState() {
    super.initState();
    previousPrices = {};
    lastUpdateTimes = {};
    coinsList = [];
    _loadSelectedCoins();
    _connectWebSocketBinance();
    // _connectWebSocketByBit();
  }

  void _loadSelectedCoins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCoins = prefs.getStringList('selectedCoins') ?? [];
    });
  }

  void _saveSelectedCoins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('selectedCoins', selectedCoins);
  }

  void _connectWebSocketBinance() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://stream.binance.com:9443/ws/!ticker@arr'),
    );

    _channel.stream.listen((message) {
      _processMessageBinance(message);
    });
  }

  void _connectWebSocketByBit() {
    _byBitChannel = WebSocketChannel.connect(
      Uri.parse('wss://stream.bybit.com/v5/public/spot'),
    );

    _byBitChannel.sink.add(jsonEncode({
      "op": "subscribe",
      "args": ["klineV2.1.BTCUSDT"]
    }));

    _byBitChannel.stream.listen(
      (message) {
        print('_______-');
        print(message);
        _processMessageByBit(message);
      },
    );
  }

  void _processMessageByBit(dynamic message) {
    final data = json.decode(message);

    if (data['topic'] == null) return; // Ignore non-topic messages

    String topic = data['topic'];
    if (topic.startsWith('klineV2.')) {
      var klineData = data['data'];
      if (klineData != null && klineData['kline'] != null) {
        var kline = klineData['kline'];
        String symbol = topic.split('.')[2]; // Extract symbol from topic
        double price = double.parse(kline['close']);
        double changePercentage = 0;
        String changeDirection = '';

        if (previousPrices.containsKey(symbol)) {
          double prevPrice = previousPrices[symbol]!;
          changePercentage = ((price - prevPrice) / prevPrice) * 100;
          changeDirection = price > prevPrice ? '📈' : '📉';
          DateTime currentTime = DateTime.now();
          DateTime lastUpdateTime = lastUpdateTimes[symbol]!;

          if (currentTime.difference(lastUpdateTime).inSeconds <= quickCheckTime) {
            if (changePercentage.abs() >= quickChangeThreshold && selectedCoins.contains(symbol)) {
              _sendTelegramNotification(symbol, changePercentage, changeDirection,
                  '${currentTime.difference(lastUpdateTime).inSeconds.toString()} seconds');
            }
          }

          if (currentTime.difference(lastUpdateTime).inSeconds >= selectedTime) {
            if (selectedCoins.contains(symbol) && changePercentage.abs() >= priceChangeThreshold) {
              String timeDifferenceMessage = selectedTime < 60
                  ? '${currentTime.difference(lastUpdateTime).inSeconds.toString()} seconds'
                  : '${currentTime.difference(lastUpdateTime).inMinutes.toString()} min';

              _sendTelegramNotification(
                  symbol, changePercentage, changeDirection, timeDifferenceMessage);
            }
          }
        }

        previousPrices[symbol] = price;
        lastUpdateTimes[symbol] = DateTime.now();

        setState(() {
          coinsList.add({
            'symbol': symbol,
            'price': price,
            'changePercentage': changePercentage,
          });
        });
      }
    }
  }

  void _processMessageBinance(dynamic message) {
    final data = json.decode(message);

    List<Map<String, dynamic>> updatedCoins = [];
    DateTime currentTime = DateTime.now();

    for (var coin in data) {
      String symbol = coin['s'];
      double price = double.parse(coin['c']);
      double changePercentage = 0;
      String changeDirection = '';

      if (!symbol.endsWith(selectedPair)) {
        continue;
      }

      if (previousPrices.containsKey(symbol)) {
        double prevPrice = previousPrices[symbol]!;
        changePercentage = ((price - prevPrice) / prevPrice) * 100;
        changeDirection = price > prevPrice ? '📈' : '📉';
        DateTime lastUpdateTime = lastUpdateTimes[symbol]!;

        if (currentTime.difference(lastUpdateTime).inSeconds <= quickCheckTime) {
          if (changePercentage.abs() >= quickChangeThreshold && selectedCoins.contains(symbol)) {
            _sendTelegramNotification(symbol, changePercentage, changeDirection,
                '${currentTime.difference(lastUpdateTime).inSeconds.toString()} seconds');
          }
        }

        if (currentTime.difference(lastUpdateTime).inSeconds >= selectedTime) {
          if (selectedCoins.contains(symbol) && changePercentage.abs() >= priceChangeThreshold) {
            String timeDifferenceMessage = '';

            if (selectedTime < 60) {
              timeDifferenceMessage =
                  '${currentTime.difference(lastUpdateTime).inSeconds.toString()} seconds';
            } else {
              timeDifferenceMessage =
                  '${currentTime.difference(lastUpdateTime).inMinutes.toString()} min';
            }

            _sendTelegramNotification(
                symbol, changePercentage, changeDirection, timeDifferenceMessage);
          }
        }
      }

      previousPrices[symbol] = price;
      lastUpdateTimes[symbol] = currentTime;

      updatedCoins.add({
        'symbol': symbol,
        'price': price,
        'changePercentage': changePercentage,
      });
    }

    if (isHide) {
      setState(() {
        coinsList = updatedCoins;
      });
    }
  }

  Future<void> _sendTelegramNotification(
      String symbol, double changePercentage, String changeDirection, String time) async {
    final String message =
        '$symbol $changeDirection price changed time $time - by ${changePercentage.toStringAsFixed(1)}%';
    final String url =
        'https://api.telegram.org/bot$telegramBotToken/sendMessage?chat_id=$chatId&text=$message';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("Telegram notification sent!");
      } else {
        print("Failed to send notification to Telegram.");
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
          availableCoins: coinsList,
          selectedCoins: selectedCoins,
          onCoinsSelected: (List<String> coins) {
            setState(() {
              selectedCoins = coins;
            });
            _saveSelectedCoins();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoins =
        coinsList.where((coin) => selectedCoins.contains(coin['symbol'])).toList();

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<int>(
                    value: selectedTime,
                    onChanged: (int? newValue) {
                      setState(() {
                        selectedTime = newValue!;
                      });
                    },
                    items: <int>[1, 3, 5, 15, 30, 60, 300, 600, 900]
                        .map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value secund${value > 1 ? 's' : ''}'),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<String>(
                    value: selectedPair,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedPair = newValue!;
                      });
                    },
                    items: ['USDT', 'BTC', 'ETH'].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                        setState(() {
                          priceChangeThreshold = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _openSelectCoinsScreen,
                child: Text('Select Coins for Notifications'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Selected Coins: ${selectedCoins.join(', ')}',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    isHide = !isHide;
                  });
                },
                child: Text(!isHide ? 'Show' : 'Hide'),
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
