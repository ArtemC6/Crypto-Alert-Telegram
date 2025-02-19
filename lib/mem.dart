import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class GeckoTerminalApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.geckoterminal.com/api/v2',
      headers: {
        'accept': 'application/json',
      },
    ),
  );

  Future<Map<String, dynamic>?> getTokenInfo(String chain, String tokenAddress) async {
    try {
      final response = await _dio.get('/networks/$chain/tokens/$tokenAddress');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        print('Ошибка запроса: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Ошибка при получении данных: $e');
      return null;
    }
  }
}

class TokenInfoScreen extends StatefulWidget {
  @override
  _TokenInfoScreenState createState() => _TokenInfoScreenState();
}

class _TokenInfoScreenState extends State<TokenInfoScreen> {
  final _api = GeckoTerminalApi();
  final _controller = TextEditingController();
  Map<String, dynamic>? _tokenInfo;
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    final channel = WebSocketChannel.connect(Uri.parse('wss://mempool.space/signet/api/v1/ws'));

    // channel.sink.add(jsonEncode({
    //   "action": "track-address",
    //   "address": "B8UruRxFvAoTZoSg7waHFkGJ96nHPso5VbEkVAzapump"
    // }));

    channel.sink.add(
        '{"action": "track-address", "address": "B8UruRxFvAoTZoSg7waHFkGJ96nHPso5VbEkVAzapump"}');


    // Подписка на адрес
    // channel.sink.add(
    //     '{"action": "track-address", "address": "B8UruRxFvAoTZoSg7waHFkGJ96nHPso5VbEkVAzapump"}');

    // Слушаем обновления
    channel.stream.listen((message) {
      print('Получено обновление: $message');
    });
    super.initState();
  }

  void _fetchTokenInfo() async {
    setState(() {
      _isLoading = true;
    });
    final tokenInfo = await _api.getTokenInfo('solana', _controller.text);
    print(tokenInfo);
    setState(() {
      _tokenInfo = tokenInfo;
      _isLoading = false;
    });
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (_controller.text.isNotEmpty) {
        _fetchTokenInfo();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Token Info Finder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter Token Address',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _startAutoRefresh();
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTokenInfo,
              child: Text('Get Token Info'),
            ),
            SizedBox(height: 16),
            _isLoading
                ? CircularProgressIndicator()
                : _tokenInfo != null
                    ? Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: ${_tokenInfo?["data"]["attributes"]["name"] ?? "N/A"}'),
                              Text(
                                  'Symbol: ${_tokenInfo?["data"]["attributes"]["symbol"] ?? "N/A"}'),
                              Text(
                                  'Price USD: ${_tokenInfo?["data"]["attributes"]["price_usd"] ?? "N/A"}'),
                              Text(
                                  'Total Supply: ${_tokenInfo?["data"]["attributes"]["total_supply"] ?? "N/A"}'),
                              Text(
                                  'FDV USD: ${_tokenInfo?["data"]["attributes"]["fdv_usd"] ?? "N/A"}'),
                              Text(
                                  '24h Volume USD: ${_tokenInfo?["data"]["attributes"]["volume_usd"]["h24"] ?? "N/A"}'),
                              if (_tokenInfo?["data"]["attributes"]["image_url"] != null)
                                Image.network(_tokenInfo?["data"]["attributes"]["image_url"]),
                            ],
                          ),
                        ),
                      )
                    : Text('Enter a token address to fetch data'),
          ],
        ),
      ),
    );
  }
}
