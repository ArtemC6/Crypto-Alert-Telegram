import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pump.fun Token Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TokenPriceMonitorScreen(),
    );
  }
}

class TokenPriceMonitorScreen extends StatefulWidget {
  const TokenPriceMonitorScreen({super.key});

  @override
  _TokenPriceMonitorScreenState createState() => _TokenPriceMonitorScreenState();
}

class _TokenPriceMonitorScreenState extends State<TokenPriceMonitorScreen> {
  final TextEditingController _tokenMintController = TextEditingController();
  WebSocketChannel? _channel;
  bool _isMonitoring = false;
  String _status = 'Disconnected';
  String _tokenName = 'N/A';
  String _tokenSymbol = 'N/A';
  String _tokenPrice = 'N/A';
  String _marketCap = 'N/A';
  String _lastTradeAmount = 'N/A';
  String _lastTradeTimestamp = 'N/A';
  bool _lastTradeIsBuy = false;
  double _solPrice = 121.0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _sid;
  String? _subscribedMint;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    _connectWebSocket(); // Автоматическое подключение при запуске
  }

  @override
  void dispose() {
    _cleanup();
    _tokenMintController.dispose();
    super.dispose();
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }

  Future<void> _connectWebSocket() async {
    if (_tokenMintController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token mint address')),
      );
      return;
    }

    _subscribedMint = _tokenMintController.text.trim();
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    setState(() {
      _isMonitoring = true;
      _status = 'Connecting... (Attempt ${_reconnectAttempts + 1})';
    });

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse('wss://frontend-api-v3.pump.fun/socket.io/?EIO=4&transport=websocket'),
        headers: {
          'Upgrade': 'websocket',
          'Origin': 'https://pump.fun',
          'Cache-Control': 'no-cache',
          'Accept-Language': 'ru,en;q=0.9',
          'Pragma': 'no-cache',
          'Connection': 'Upgrade',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
          'Sec-WebSocket-Version': '13',
          'Sec-WebSocket-Extensions': 'permessage-deflate; client_max_window_bits',
        },
      );

      _channel!.stream.listen(
            (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      _channel?.sink.add('40');
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _cleanup();
    if (_isMonitoring && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: pow(1, _reconnectAttempts).toInt()); // Увеличиваем задержку
      setState(() {
        _status = 'Disconnected. Reconnecting in ${delay.inSeconds}s... (Attempt $_reconnectAttempts)';
      });
      _reconnectTimer = Timer(delay, () {
        _establishConnection();
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      setState(() {
        _status = 'Max reconnection attempts reached';
        _isMonitoring = false;
        _reconnectAttempts = 0;
      });
    }
  }

  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) { // Увеличиваем интервал пинга
      if (_channel != null && _isMonitoring) {
        _channel?.sink.add('2');
        print('Sent ping');
      }
    });
  }

  void _subscribeToTradeRoom() {
    final mint = _subscribedMint!;
    final joinMessage = '42["joinTradeRoom",{"mint":"$mint"}]';
    _channel?.sink.add(joinMessage);
    setState(() {
      _status = 'Subscribed to trade room for mint: $mint';
    });
    print('Subscribed to trade room: $mint');
  }

  void _handleWebSocketMessage(dynamic message) {
    if (!mounted) return;

    try {
      if (message.startsWith('0')) {
        final data = jsonDecode(message.substring(1));
        _sid = data['sid'];
        setState(() {
          _status = 'Connected to WebSocket (SID: $_sid)';
          _reconnectAttempts = 0; // Сброс попыток при успешном подключении
        });
        _startPing();
        _subscribeToTradeRoom();
      } else if (message.startsWith('2')) {
        print('Received pong');
      } else if (message.startsWith('42')) {
        final jsonString = message.substring(2);
        final data = jsonDecode(jsonString);
        final event = data[0];
        final tradeData = data[1];

        if (tradeData['mint'] == _subscribedMint ||
            event == 'tradeCreated:$_subscribedMint') {
          setState(() {
            _status = 'New trade received for $_subscribedMint';
            _tokenName = tradeData['name'] ?? 'N/A';
            _tokenSymbol = tradeData['symbol'] ?? 'N/A';
            _marketCap = tradeData['usd_market_cap']?.toStringAsFixed(2) ?? 'N/A';

            final solAmount = tradeData['sol_amount'] / 1e9;
            final tokenAmount = tradeData['token_amount'] / 1e6;
            final priceInSol = solAmount / tokenAmount;
            final priceInUsd = priceInSol * _solPrice;
            _tokenPrice = priceInUsd.toStringAsFixed(6);

            _lastTradeAmount =
            '${solAmount.toStringAsFixed(4)} SOL (${(tradeData['token_amount'] / 1e6).toStringAsFixed(2)} $_tokenSymbol)';
            _lastTradeTimestamp = DateTime.fromMillisecondsSinceEpoch(tradeData['timestamp'] * 1000).toLocal().toString();
            _lastTradeIsBuy = tradeData['is_buy'];
          });
          print('Filtered trade data for $_subscribedMint: $tradeData');
        }
      }
    } catch (e) {
      print('Error processing WebSocket message: $e');
      setState(() {
        _status = 'Error processing message: $e';
      });
    }
  }

  void _disconnectWebSocket() {
    _cleanup();
    setState(() {
      _status = 'Disconnected';
      _isMonitoring = false;
      _reconnectAttempts = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pump.fun Token Monitor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _tokenMintController,
                decoration: const InputDecoration(
                  labelText: 'Token Mint Address',
                  hintText: 'Enter the token mint address (e.g., FCSjDJ1b2wMz286vCrDrJMS7Z8MhU7L183qewRf7pump)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isMonitoring ? null : _connectWebSocket,
                    child: const Text('Start Monitoring'),
                  ),
                  ElevatedButton(
                    onPressed: _isMonitoring ? _disconnectWebSocket : null,
                    child: const Text('Stop Monitoring'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Status: $_status', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              Text('Token Info:', style: Theme.of(context).textTheme.titleLarge),
              Text('Name: $_tokenName'),
              Text('Symbol: $_tokenSymbol'),
              Text('Price: \$$_tokenPrice USD'),
              Text('Market Cap: \$$_marketCap USD'),
              const SizedBox(height: 20),
              Text('Last Trade:', style: Theme.of(context).textTheme.titleLarge),
              Text('Amount: $_lastTradeAmount'),
              Text('Type: ${_lastTradeIsBuy ? 'Buy' : 'Sell'}'),
              Text('Timestamp: $_lastTradeTimestamp'),
            ],
          ),
        ),
      ),
    );
  }
}