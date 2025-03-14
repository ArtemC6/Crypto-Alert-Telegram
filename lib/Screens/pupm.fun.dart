import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../const.dart';

class Trade {
  final String signature;
  final int solAmount;
  final int tokenAmount;
  final bool isBuy;
  final String user;
  final int timestamp;
  final String mint;
  final String name;
  final String symbol;
  final String description;
  final String imageUri;
  final double marketCap; // In SOL
  final double usdMarketCap; // In USD

  Trade({
    required this.signature,
    required this.solAmount,
    required this.tokenAmount,
    required this.isBuy,
    required this.user,
    required this.timestamp,
    required this.mint,
    required this.name,
    required this.symbol,
    required this.description,
    required this.imageUri,
    required this.marketCap,
    required this.usdMarketCap,
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      signature: json['signature'],
      solAmount: json['sol_amount'],
      tokenAmount: json['token_amount'],
      isBuy: json['is_buy'],
      user: json['user'],
      timestamp: json['timestamp'],
      mint: json['mint'],
      name: json['name'],
      symbol: json['symbol'],
      description: json['description'] ?? '',
      imageUri: json['image_uri'],
      marketCap: (json['market_cap'] as num).toDouble(),
      usdMarketCap: (json['usd_market_cap'] as num).toDouble(),
    );
  }
}

class WebSocketExample extends StatefulWidget {
  @override
  _WebSocketExampleState createState() => _WebSocketExampleState();
}

class _WebSocketExampleState extends State<WebSocketExample> {
  WebSocketChannel? channel;
  final List<Trade> trades = [];
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  final Set<String> _sentNotifications = {};

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    if (_isConnected || _reconnectAttempts >= _maxReconnectAttempts) return;

    try {
      channel = IOWebSocketChannel.connect(
        Uri.parse(
            'wss://frontend-api-v3.pump.fun/socket.io/?EIO=4&transport=websocket'),
        headers: {
          'Origin': 'https://pump.fun',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 YaBrowser/25.2.0.0 Safari/537.36',
        },
      );

// Listen to the stream first to handle handshake
      channel!.stream.listen(
        (message) {
          print('Received: $message');
          if (message == '0') {
// Socket.IO handshake complete
            setState(() {
              _isConnected = true;
              _reconnectAttempts = 0;
            });
          } else if (message.startsWith('42["tradeCreated"')) {
            final trade = _parseTradeMessage(message);
            setState(() {
              trades.add(trade);
            });
          } else if (message == '3') {
// Pong received, send ping back
            channel?.sink.add('2');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

// Start with Socket.IO handshake
      channel!.sink.add('40');

      Future.delayed(Duration(seconds: 1), () {
        channel?.sink.add(
            '42["joinTradeRoom",{"mint":"9KyEELfeJEL3wFgL1jGhGRWjdxMihozLncC13p9pump"}]');
      });
    } catch (e) {
      print('Failed to connect: $e');
      _handleDisconnect();
    }

// Ping every 25 seconds (Socket.IO default timeout is 30s)
    Timer.periodic(Duration(seconds: 25), (timer) {
      if (_isConnected) {
        channel?.sink.add('2'); // Socket.IO ping
      } else {
        timer.cancel();
      }
    });
  }

  void _handleDisconnect() {
    if (!_isConnected) return;

    setState(() {
      _isConnected = false;
    });
    channel?.sink.close();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnect attempts reached. Giving up.');
      return;
    }

    final delay = _initialReconnectDelay * (_reconnectAttempts + 1);
    print(
        'Reconnecting (${_reconnectAttempts + 1}/$_maxReconnectAttempts) in ${delay.inSeconds}s...');

    Timer(delay, () {
      if (mounted) {
        setState(() {
          _reconnectAttempts++;
        });
        _connectToWebSocket();
      }
    });
  }

  Trade _parseTradeMessage(String message) {
    final jsonString =
        message.replaceFirst('42["tradeCreated",', '').replaceFirst(']', '');
    final jsonData = jsonDecode(jsonString);
    final trade = Trade.fromJson(jsonData);

    final age =
        DateTime.now().difference(getDateTime(trade.timestamp)).inSeconds;
    if (age < 0 && trade.usdMarketCap > 30000) {
      _sendTelegramNotification(trade);
    }

    return trade;
  }

  Future<void> _sendTelegramNotification(Trade trade) async {
    try {
      final notificationKey = '${trade.signature}-${trade.timestamp}';
      if (_sentNotifications.contains(notificationKey)) return;

      final age =
          DateTime.now().difference(getDateTime(trade.timestamp)).inSeconds;

      final String caption = '''
*New Trade Alert: ${trade.name} (${trade.symbol})* 🚀

🔹 *Market Cap:* \$${formatMarketCap(trade.usdMarketCap.toString())}
🔹 *Age:* ${formatAgeSeconds(age)}
🔹 *Address:* ${trade.mint}
🔹 *BullX:* https://neo.bullx.io/terminal?chainId=1399811149&address=${trade.mint}
'''
          .trim();

      final String url =
          'https://api.telegram.org/bot$telegramBotToken/sendPhoto';
      final String messageUrl =
          'https://api.telegram.org/bot$telegramBotToken/sendMessage';

      http.Response response;

      if (trade.imageUri.isNotEmpty) {
        try {
          final imageResponse = await http
              .get(Uri.parse(trade.imageUri))
              .timeout(Duration(seconds: 5));
          if (imageResponse.statusCode == 200 &&
              imageResponse.bodyBytes.isNotEmpty) {
            var request = http.MultipartRequest('POST', Uri.parse(url))
              ..fields['chat_id'] = chatId
              ..fields['caption'] = caption
              ..fields['parse_mode'] = 'Markdown'
              ..files.add(http.MultipartFile.fromBytes(
                'photo',
                imageResponse.bodyBytes,
                filename: 'trade_${trade.symbol}.png',
              ));

            final streamedResponse =
                await request.send().timeout(Duration(seconds: 5));
            response = await http.Response.fromStream(streamedResponse);
          } else {
            throw Exception('Image load failed');
          }
        } catch (e) {
          response = await http.post(Uri.parse(messageUrl), body: {
            'chat_id': chatId,
            'text': caption,
            'parse_mode': 'Markdown',
          });
        }
      } else {
        response = await http.post(Uri.parse(messageUrl), body: {
          'chat_id': chatId,
          'text': caption,
          'parse_mode': 'Markdown',
        });
      }

      if (response.statusCode == 200) {
        _sentNotifications.add(notificationKey);
        print('Telegram notification sent');
      } else {
        print(
            'Telegram notification failed: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error sending Telegram notification: $e');
    }
  }

  String formatMarketCap(String value) {
    final formatter =
        NumberFormat.compactCurrency(symbol: '', decimalDigits: 2);
    return formatter.format(double.parse(value));
  }

  String formatAgeSeconds(int seconds) {
    return '$seconds sec';
  }

  DateTime getDateTime(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  @override
  void dispose() {
    channel?.sink.close();
    _isConnected = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'WebSocket Trades (${_isConnected ? "Connected" : "Disconnected"}) ${trades.length}'),
      ),
      body: ListView.builder(
        itemCount: trades.length,
        itemBuilder: (context, index) {
          final trade = trades[index];
          final int age =
              DateTime.now().difference(getDateTime(trade.timestamp)).inSeconds;

          if (age < 10 && trade.usdMarketCap > 30000) {
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(trade.imageUri),
                ),
                title: Text('${trade.name} (${trade.symbol})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Age: ${formatAgeSeconds(age)}'),
                    Text(
                        'Market Cap: \$${formatMarketCap(trade.usdMarketCap.toString())}'),
                  ],
                ),
              ),
            );
          }
          return Container();
        },
      ),
    );
  }
}
