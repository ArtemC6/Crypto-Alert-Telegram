import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class DexScreenerApi {
  final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'accept': 'application/json',
      },
    ),
  );

  Future<List<dynamic>?> getTokenInfo(String chainId, String tokenAddress) async {

    final uri = 'https://api.dexscreener.com/tokens/v1/$chainId/$tokenAddress';
    print(uri);
    try {
      final response = await _dio.get(uri);

      print(response.data);

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
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

class TokenInfoScreen2 extends StatefulWidget {
  @override
  _TokenInfoScreenState createState() => _TokenInfoScreenState();
}

class _TokenInfoScreenState extends State<TokenInfoScreen2> with TickerProviderStateMixin {
  final _api = DexScreenerApi();
  final _controller = TextEditingController();
  List<dynamic>? _tokenInfo;
  Timer? _timer;

  final Map<String, AnimationController> _controllers = {};
  final Map<String, Animation<double>> _animations = {};
  final Map<String, double> _previousValues = {};

  void _startAnimation(String key, double newValue) {
    _controllers[key] ??= AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 30000),
    );

    _animations[key] = Tween<double>(
      begin: _previousValues[key] ?? newValue,
      end: newValue,
    ).animate(_controllers[key]!);

    if (_previousValues[key] != newValue) {
      _controllers[key]!.reset();
      _controllers[key]!.forward();
      _previousValues[key] = newValue;
    }
  }



  void _fetchTokenInfo() async {
    final tokenInfo = await _api.getTokenInfo(
        'solana', _controller.text); // Replace 'solana' with the actual chain ID if needed
    print(tokenInfo);
    setState(() {
      _tokenInfo = tokenInfo;
    });
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 800), (timer) {
      if (_controller.text.isNotEmpty) {
        _fetchTokenInfo();
      }
    });
  }

  Color _getChangeColor(String key, double newValue) {
    final oldValue = _previousValues[key];

    if (oldValue == null) {
      _previousValues[key] = newValue;
      return Colors.white;
    }

    if (newValue > oldValue) {
      _previousValues[key] = newValue;
      return Colors.green;
    } else if (newValue < oldValue) {
      _previousValues[key] = newValue;
      return Colors.red;
    }

    return Colors.white;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
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
            _tokenInfo != null && _tokenInfo!.isNotEmpty
                ? Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimatedText(
                      'Chain ID: ${_tokenInfo?[0]["chainId"] ?? "N/A"}',
                      keyValue: '',
                    ),
                    _buildAnimatedText(
                      'Dex ID: ${_tokenInfo?[0]["dexId"] ?? "N/A"}',
                      keyValue: '',
                    ),
                    _buildAnimatedText(
                      'Price USD: ${_tokenInfo?[0]["priceUsd"] ?? "N/A"}',
                      isPrice: true,
                      keyValue: 'priceUsd',
                    ),
                    _buildAnimatedText(
                      'Market Cap: ${_tokenInfo?[0]["marketCap"] ?? "N/A"}',
                      isPrice: true,
                      keyValue: 'marketCap',
                    ),
                    _buildAnimatedText(
                      'Volume: ${_tokenInfo?[0]["volume"] ?? "N/A"}',
                      isPrice: true,
                      keyValue: 'volume',
                    ),
                    _buildAnimatedText(
                      'FDV: ${_tokenInfo?[0]["fdv"] ?? "N/A"}',
                      isPrice: true,
                      keyValue: 'fdv',
                    ),
                    _buildAnimatedText(
                      'Pair Address: ${_tokenInfo?[0]["pairAddress"] ?? "N/A"}',
                      keyValue: '',
                    ),
                    _buildAnimatedText(
                      'Price Native: ${_tokenInfo?[0]["priceNative"] ?? "N/A"}',
                      isPrice: true,
                      keyValue: 'priceNative',
                    ),
                    _buildAnimatedText(
                      'Price Change: ${_tokenInfo?[0]["priceChange"] ?? "N/A"}',
                      keyValue: 'priceChange',
                    ),
                    if (_tokenInfo?[0]["info"]?["imageUrl"] != null)
                      Image.network(_tokenInfo?[0]["info"]["imageUrl"]),
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

  Widget _buildAnimatedText(String text, {bool isPrice = false, required String keyValue}) {
    final value = text.split(":").last.trim();

    if (isPrice && double.tryParse(value) != null) {
      double newValue = double.parse(value);
      Color color = _getChangeColor(keyValue, newValue);

      _startAnimation(keyValue, newValue);

      return AnimatedBuilder(
        animation: _animations[keyValue] ?? AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          return Text(
            text.replaceFirst(
                value,
                (_animations[keyValue]?.value ?? newValue).toStringAsFixed(2)
            ),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      );
    }

    return Text(text);
  }
}
