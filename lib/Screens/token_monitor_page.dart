import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../const.dart';
import '../utils.dart';

class TokenPriceMonitorScreen extends StatefulWidget {
  final String? initialTokenAddress;

  const TokenPriceMonitorScreen({super.key, this.initialTokenAddress});

  @override
  _TokenPriceMonitorScreenState createState() =>
      _TokenPriceMonitorScreenState();
}

class _TokenPriceMonitorScreenState extends State<TokenPriceMonitorScreen> {
  final TextEditingController _tokenMintController = TextEditingController();
  bool _isMonitoring = false;
  String _status = 'Disconnected';
  double _lastNotifiedMarketCap = 0.0;
  double _marketCap = 0.0, _marketCapChangePercentage = 0.0;
  double _changeThreshold = 30.0;
  double _notificationInterval = 120.0;
  Timer? _monitoringTimer;
  final Map<String, DateTime> _lastNotificationTimes = {};
  final Set<String> _sentNotifications = {};
  String? _currentTokenAddress;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _tokenMintController.addListener(_onTokenAddressChanged);
    if (widget.initialTokenAddress?.isNotEmpty ?? false) {
      _tokenMintController.text = widget.initialTokenAddress!;
      _startMonitoring(widget.initialTokenAddress!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tokenMintController.removeListener(_onTokenAddressChanged);
    _tokenMintController.dispose();
    _stopMonitoring();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _changeThreshold = prefs.getDouble('changeThreshold') ?? 30.0;
        _notificationInterval =
            prefs.getDouble('notificationInterval') ?? 120.0;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('changeThreshold', _changeThreshold);
    await prefs.setDouble('notificationInterval', _notificationInterval);
  }

  void _onTokenAddressChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final newTokenAddress = _tokenMintController.text.trim();

      if (newTokenAddress.isEmpty) {
        _stopMonitoring();
        if (mounted) {
          setState(() {
            _isMonitoring = false;
            _status = 'Disconnected';
            _marketCap = 0.0;
            _marketCapChangePercentage = 0.0;
          });
        }
        return;
      }

      if (newTokenAddress != _currentTokenAddress) {
        _stopMonitoring();
        _channel?.sink.close();
        _channel = null;

        _resetState();
        _startMonitoring(newTokenAddress);
      }
    });
  }

  void _resetState() {
    _stopMonitoring();
    _lastNotifiedMarketCap = 0.0;
    _marketCap = 0.0;
    _marketCapChangePercentage = 0.0;
    _lastNotificationTimes.clear();
    _sentNotifications.clear();
    _currentTokenAddress = null;
    _isConnected = false;
    _reconnectAttempts = 0;

    if (mounted) {
      setState(() {
        _status = 'Disconnected';
      });
    }
  }

  Future<void> _startMonitoring(String tokenAddress) async {
    if (tokenAddress.isEmpty) return;

    _currentTokenAddress = tokenAddress;

    if (mounted) {
      setState(() {
        _isMonitoring = true;
        _status = 'Fetching pool info...';
      });
    }

    final poolId = await _fetchPoolIdForToken(tokenAddress);
    if (poolId == null) {
      if (mounted) {
        setState(() {
          _status = 'Failed to fetch pool info';
          _isMonitoring = false;
        });
      }
      return;
    }

    _connectToWebSocket(tokenAddress, poolId);
  }

  Future<String?> _fetchPoolIdForToken(String tokenAddress) async {
    if (tokenAddress.isEmpty || tokenAddress.length < 32) return null;
    try {
      final response = await http.get(
        Uri.parse('https://datapi.jup.ag/v1/pools?assetIds=$tokenAddress'),
        headers: {
          'accept': 'application/json',
          'accept-language': 'ru,en;q=0.9',
          'origin': 'https://jup.ag',
          'referer': 'https://jup.ag/',
          'user-agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 YaBrowser/25.2.0.0 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['pools'] != null && jsonData['pools'].isNotEmpty) {
          return jsonData['pools'][0]['id'];
        }
      }
    } catch (e) {
      print('Failed to fetch pool info: $e');
    }
    return null;
  }

  void _connectToWebSocket(String tokenAddress, String poolId) {
    if (_isConnected || _reconnectAttempts >= _maxReconnectAttempts) return;

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse('wss://trench-stream.jup.ag/ws'),
        headers: {
          'Upgrade': 'websocket',
          'Origin': 'https://jup.ag',
          'Cache-Control': 'no-cache',
          'Accept-Language': 'ru,en;q=0.9',
        },
      );

      _channel!.sink.add('{"type":"subscribe:pool","pools":["$poolId"]}');
      _channel!.sink
          .add('{"type":"subscribe:txns","assets":["$tokenAddress"]}');

      _channel!.stream.listen(
        _handleWebSocketMessage,
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

      setState(() {
        _isConnected = true;
        _reconnectAttempts = 0;
        _status = 'Monitoring...';
      });
    } catch (e) {
      print('Failed to connect: $e');
      _handleDisconnect();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message.startsWith('{"type":"updates"')) {
      final jsonData = jsonDecode(message);
      final data = jsonData['data'][0];
      final pool = data['pool'];
      final baseAsset = pool['baseAsset'];

      _marketCap =
          (baseAsset['usdPrice'] ?? 0.0) * (baseAsset['circSupply'] ?? 0.0);

      if (_lastNotifiedMarketCap > 0) {
        _marketCapChangePercentage =
            ((_marketCap - _lastNotifiedMarketCap) / _lastNotifiedMarketCap) *
                100;
      } else {
        _marketCapChangePercentage = 0.0;
      }

      if (_marketCap > 0 && _lastNotifiedMarketCap == 0) {
        _lastNotifiedMarketCap = _marketCap;
      }

      if (mounted) {
        setState(() {});
      }

      if (_marketCap > 0 &&
          _marketCapChangePercentage.abs() >= _changeThreshold) {
        if (_currentTokenAddress != null) {
          _handleMarketCapChange(_currentTokenAddress!, _marketCap, baseAsset);
        }
      }
    }
  }

  void _handleMarketCapChange(String tokenAddress, double currentMarketCap,
      Map<String, dynamic> baseAsset) {
    final lastNotificationTime = _lastNotificationTimes[tokenAddress];
    final now = DateTime.now();

    final timeDifference = lastNotificationTime != null
        ? now.difference(lastNotificationTime).inSeconds
        : _notificationInterval.toInt();

    final isWithinInterval = timeDifference >= _notificationInterval.toInt();

    if (isWithinInterval &&
        currentMarketCap > 0 &&
        _marketCapChangePercentage.isFinite) {

      _lastNotificationTimes[tokenAddress] = now;
      _lastNotifiedMarketCap = currentMarketCap;

      _sendTelegramNotification(
        baseAsset['name'] ?? 'Unknown',
        baseAsset['symbol'] ?? 'N/A',
        baseAsset['icon'] ?? '',
        tokenAddress,
        currentMarketCap,
        _marketCapChangePercentage,
        now,
        lastNotificationTime,
      );

      if (mounted) {
        setState(() {
          _status =
              'Market cap changed by ${_marketCapChangePercentage.toStringAsFixed(1)}%! Notification sent.';
        });
      }
    }
  }

  void _handleDisconnect() {
    if (!_isConnected) return;

    setState(() {
      _isConnected = false;
    });
    _channel?.sink.close();
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
        _connectToWebSocket(_currentTokenAddress!,
            _fetchPoolIdForToken(_currentTokenAddress ?? '').toString());
      }
    });
  }

  Future<void> _sendTelegramNotification(
      String name,
      String symbol,
      String imageUri,
      String tokenAddress,
      double marketCap,
      double changePercentage,
      DateTime currentTime,
      DateTime? lastNotificationTime) async {
    try {
      final String caption = '''
*Token Info: $name ($symbol)* 🚀

🔹 *Changed ${changePercentage > 0 ? 'Up' : 'Down'} ${changePercentage.abs().toStringAsFixed(1)}% in ${lastNotificationTime != null ? formatDuration(currentTime.difference(lastNotificationTime)) : 'change'}!* ${changePercentage > 0 ? '📈' : '📉'}
🔹 *Market Cap:* \$${formatMarketCap(marketCap.toString())}
🔹 *Address:* `$tokenAddress`

🔹 *BullX:* https://neo.bullx.io/terminal?chainId=1399811149&address=$tokenAddress
'''
          .trim();

      final String url =
          'https://api.telegram.org/bot$telegramBotToken/sendPhoto';
      final String messageUrl =
          'https://api.telegram.org/bot$telegramBotToken/sendMessage';

      http.Response response;

      if (imageUri.isNotEmpty) {
        final imageResponse = await http.get(Uri.parse(imageUri)).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception("Timeout loading image"),
            );

        if (imageResponse.statusCode == 200 &&
            imageResponse.bodyBytes.isNotEmpty) {
          var request = http.MultipartRequest('POST', Uri.parse(url))
            ..fields['chat_id'] = chatId
            ..fields['caption'] = caption
            ..fields['parse_mode'] = 'Markdown'
            ..files.add(http.MultipartFile.fromBytes(
              'photo',
              imageResponse.bodyBytes,
              filename: 'token_$symbol.png',
            ));

          final streamedResponse = await request.send().timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception("Timeout sending photo"),
              );
          response = await http.Response.fromStream(streamedResponse);
        } else {
          response = await http.post(
            Uri.parse(messageUrl),
            body: {
              'chat_id': chatId,
              'text': caption,
              'parse_mode': 'Markdown',
            },
          );
        }
      } else {
        response = await http.post(
          Uri.parse(messageUrl),
          body: {
            'chat_id': chatId,
            'text': caption,
            'parse_mode': 'Markdown',
          },
        );
      }

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print(
            "Ошибка отправки сообщения в Telegram: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      print("Ошибка при отправке уведомления в Telegram: $e");
    }
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _currentTokenAddress = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Price Monitor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _changeThreshold,
                    min: 5.0,
                    max: 100.0,
                    divisions: 95,
                    label: '${_changeThreshold.toStringAsFixed(1)}%',
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _changeThreshold = value;
                        });
                      }
                      _saveSettings();
                    },
                  ),
                ),
                const SizedBox(width: 16.0),
                Text(
                  'Change: ${_changeThreshold.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _notificationInterval,
                    min: 10.0,
                    max: 180.0,
                    divisions: 170,
                    label: '${_notificationInterval.toStringAsFixed(0)} sec',
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _notificationInterval = value;
                        });
                      }
                      _saveSettings();
                    },
                  ),
                ),
                const SizedBox(width: 16.0),
                Text(
                  'Interval: ${_notificationInterval.toStringAsFixed(0)} sec',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            TextField(
              controller: _tokenMintController,
              decoration: const InputDecoration(
                labelText: 'Token Mint Address',
                hintText: 'Enter the token mint address',
              ),
            ),
            const SizedBox(height: 20),
            Text('Status: $_status',
                style: Theme.of(context).textTheme.bodyMedium),
            Text('Market Cap: ${formatMarketCap(_marketCap.toString())}',
                style: Theme.of(context).textTheme.bodyMedium),
            Text('Change: ${_marketCapChangePercentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
