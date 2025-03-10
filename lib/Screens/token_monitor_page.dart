import 'dart:async';
import 'dart:convert';
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
      title: 'Token Price Monitor',
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
  final TextEditingController _poolIdController = TextEditingController(text: '171508434');
  final TextEditingController _tokenAddressController = TextEditingController();
  WebSocketChannel? _channel;
  bool _isMonitoring = false;
  String _status = 'Disconnected';
  String _baseTokenName = 'Unknown';
  String _quoteTokenName = 'Unknown';
  String _baseTokenPrice = 'N/A';
  String _quoteTokenPrice = 'N/A';
  String _baseTokenMarketCap = 'N/A';
  String _quoteTokenMarketCap = 'N/A';
  String _baseTokenAmount = 'N/A'; // Новая переменная для объема базового токена
  String _quoteTokenAmount = 'N/A'; // Новая переменная для объема котируемого токена
  int _lastSwapTimestamp = 0; // Новая переменная для времени последней сделки
  String _tokenAddress = '';
  String _tokenName = 'N/A';
  String _tokenPrice = 'N/A';
  String _tokenMarketCap = 'N/A';

  @override
  void dispose() {
    _disconnectWebSocket();
    _poolIdController.dispose();
    _tokenAddressController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    if (_poolIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a pool ID')),
      );
      return;
    }

    setState(() {
      _isMonitoring = true;
      _status = 'Connecting...';
    });

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse('wss://cables.geckoterminal.com/cable'),
        headers: {
          'Upgrade': 'websocket',
          'Origin': 'https://www.geckoterminal.com',
          'Sec-WebSocket-Version': '13',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        },
      );

      _channel!.stream.listen(
            (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _status = 'Error: $error';
            _isMonitoring = false;
          });
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            _status = 'Disconnected';
            _isMonitoring = false;
          });
        },
      );

      _subscribeToChannels();
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
      setState(() {
        _status = 'Failed to connect: $e';
        _isMonitoring = false;
      });
    }
  }

  void _subscribeToChannels() {
    final poolId = _poolIdController.text.trim();
    final subscribeSwapChannel = {
      "command": "subscribe",
      "identifier": jsonEncode({"channel": "SwapChannel", "pool_id": poolId}),
    };
    final subscribePoolChannel = {
      "command": "subscribe",
      "identifier": jsonEncode({"channel": "PoolChannel", "pool_id": poolId}),
    };

    _channel?.sink.add(jsonEncode(subscribeSwapChannel));
    _channel?.sink.add(jsonEncode(subscribePoolChannel));
    setState(() {
      _status = 'Subscribed to channels for pool ID: $poolId';
    });
    print('Subscribed to SwapChannel and PoolChannel for pool ID: $poolId');
  }

  void _handleWebSocketMessage(dynamic message) {
    if (!mounted) return;

    print('WebSocket message: $message');
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'ping') return;

      if (data['type'] == 'welcome') {
        setState(() {
          _status = 'Connected to WebSocket';
        });
      } else if (data['type'] == 'confirm_subscription') {
        setState(() {
          _status = 'Subscription confirmed: ${data['identifier']}';
        });
      } else if (data['type'] == 'reject_subscription') {
        setState(() {
          _status = 'Subscription rejected: ${data['identifier']}';
        });
      } else if (data['identifier'] != null && data['message'] != null) {
        final identifier = jsonDecode(data['identifier']);
        if (identifier['channel'] == 'SwapChannel') {
          final swapData = data['message']['data'];
          setState(() {
            _status = 'New swap received';
            // Обновляем цены токенов и объемы из свопа
            if (swapData['from_token_id'] == 38874034) {
              _baseTokenPrice = swapData['price_from_in_usd'];
              _quoteTokenPrice = swapData['price_to_in_usd'];
              _baseTokenAmount = swapData['from_token_amount'];
              _quoteTokenAmount = swapData['to_token_amount'];
            } else if (swapData['from_token_id'] == 4045901) {
              _baseTokenPrice = swapData['price_to_in_usd'];
              _quoteTokenPrice = swapData['price_from_in_usd'];
              _baseTokenAmount = swapData['to_token_amount'];
              _quoteTokenAmount = swapData['from_token_amount'];
            }
            _lastSwapTimestamp = swapData['block_timestamp'];
          });
          print('New swap data: $swapData');
        } else if (identifier['channel'] == 'PoolChannel') {
          final poolData = data['message']['data']['included'][0]['attributes'];
          setState(() {
            _status = 'Pool update received';
            _baseTokenName = poolData['base_name'];
            _quoteTokenName = poolData['quote_name'];
            _baseTokenPrice = poolData['base_price_in_usd'];
            _quoteTokenPrice = poolData['quote_price_in_usd'];
            // Проверяем наличие market cap в token_value_data
            final tokenValueData = data['message']['data']['data']['attributes']['token_value_data'];
            _baseTokenMarketCap = tokenValueData['38874034']['market_cap_in_usd']?.toString() ?? 'N/A';
            _quoteTokenMarketCap = tokenValueData['4045901']['market_cap_in_usd']?.toString() ?? 'N/A';
          });
          print('Pool update data: $poolData');
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
    _channel?.sink.close();
    setState(() {
      _status = 'Disconnected';
      _isMonitoring = false;
    });
  }

  void _updateTokenInfo() {
    final tokenAddress = _tokenAddressController.text.trim();
    if (tokenAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token address')),
      );
      return;
    }

    setState(() {
      _tokenAddress = tokenAddress;
      _tokenName = 'Loading...';
      _tokenPrice = 'Loading...';
      _tokenMarketCap = 'Loading...';
    });

    // Здесь можно добавить логику для получения информации о токене по его адресу
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _tokenName = 'Token Name';
        _tokenPrice = '\$1.23';
        _tokenMarketCap = '\$100,000,000';
      });
    });
  }

  String _formatTimestamp(int timestamp) {
    // Предполагаем, что timestamp в миллисекундах
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.toLocal()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Price Monitor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _poolIdController,
                decoration: const InputDecoration(
                  labelText: 'Pool ID',
                  hintText: 'Enter the pool ID (e.g., 171508434)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tokenAddressController,
                decoration: const InputDecoration(
                  labelText: 'Token Address',
                  hintText: 'Enter the token address',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _updateTokenInfo,
                child: const Text('Update Token Info'),
              ),
              const SizedBox(height: 10),
              Text('Status: $_status', style: Theme.of(context).textTheme.bodyMedium),
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
              Text('Token 1:', style: Theme.of(context).textTheme.titleLarge),
              Text('Name: $_baseTokenName'),
              Text('Price: \$$_baseTokenPrice USD'),
              Text('Market Cap: $_baseTokenMarketCap USD'),
              const SizedBox(height: 20),
              Text('Token 2:', style: Theme.of(context).textTheme.titleLarge),
              Text('Name: $_quoteTokenName'),
              Text('Price: \$$_quoteTokenPrice USD'),
              Text('Market Cap: $_quoteTokenMarketCap USD'),
              const SizedBox(height: 20),
              Text('Last Swap Details:', style: Theme.of(context).textTheme.titleLarge),
              Text('Base Token Amount: $_baseTokenAmount'),
              Text('Quote Token Amount: $_quoteTokenAmount'),
              Text('Timestamp: ${_formatTimestamp(_lastSwapTimestamp)}'),
              const SizedBox(height: 20),
              Text('Custom Token:', style: Theme.of(context).textTheme.titleLarge),
              Text('Address: $_tokenAddress'),
              Text('Name: $_tokenName'),
              Text('Price: $_tokenPrice'),
              Text('Market Cap: $_tokenMarketCap'),
            ],
          ),
        ),
      ),
    );
  }
}