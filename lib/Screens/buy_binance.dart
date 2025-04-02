import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class BinanceFuturesClient {
  static const String apiKey = 'AazqfPsSB6hEPfdBsr67RRZCYWkQjxLOwapQG56oQZNyyu4RSb6qQxE70zV8MDKV';
  static const String secretKey = '7pBSo1KnhC9hz3GzpQBDnbeTab0U4eI0cu2H8MKjPZh0gx2x8drsNeA69o8eUFRk';
  static const String baseUrl = 'https://fapi.binance.com';

  // Кеш для хранения precision и exchangeInfo
  static final Map<String, Map<String, int>> _precisionCache = {};
  static Map<String, dynamic>? _exchangeInfoCache;
  static DateTime? _lastExchangeInfoUpdate;

  /// Генерация подписи (оставлена без изменений)
  static String _generateSignature(Map<String, dynamic> params) {
    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return Hmac(sha256, utf8.encode(secretKey)).convert(utf8.encode(queryString)).toString();
  }

  /// Оптимизированная отправка запросов
  static Future<dynamic> _sendAuthorizedPostRequest(
      String endpoint,
      Map<String, dynamic> params,
      ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final requestParams = {...params, 'timestamp': timestamp, 'recvWindow': '5000'};
    final signature = _generateSignature(requestParams);
    final signedParams = {...requestParams, 'signature': signature};

    final uri = Uri.parse('$baseUrl$endpoint');
    final body = signedParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');

    try {
      final response = await http.post(
        uri,
        headers: {
          'X-MBX-APIKEY': apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// Получение текущей цены с кешированием
  static Future<double> getCurrentPrice(String symbol) async {
    try {
      final uri = Uri.parse('$baseUrl/fapi/v1/ticker/price?symbol=$symbol');
      final response = await http.get(uri).timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch price: ${response.body}');
      }

      final data = jsonDecode(response.body);
      return double.parse(data['price']);
    } catch (e) {
      throw Exception('Price fetch failed: $e');
    }
  }

  /// Кеширование exchangeInfo
  static Future<Map<String, dynamic>> _getExchangeInfo() async {
    final now = DateTime.now();
    if (_exchangeInfoCache != null &&
        _lastExchangeInfoUpdate != null &&
        now.difference(_lastExchangeInfoUpdate!) < const Duration(minutes: 5)) {
      return _exchangeInfoCache!;
    }

    final uri = Uri.parse('$baseUrl/fapi/v1/exchangeInfo');
    final response = await http.get(uri).timeout(const Duration(seconds: 3));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exchange info: ${response.body}');
    }

    _exchangeInfoCache = jsonDecode(response.body);
    _lastExchangeInfoUpdate = now;
    return _exchangeInfoCache!;
  }

  /// Получение precision с кешированием
  static Future<Map<String, int>> getSymbolPrecision(String symbol) async {
    if (_precisionCache.containsKey(symbol)) {
      return _precisionCache[symbol]!;
    }

    final exchangeInfo = await _getExchangeInfo();
    final symbols = exchangeInfo['symbols'] as List<dynamic>;
    final symbolInfo = symbols.firstWhere(
          (s) => s['symbol'] == symbol,
      orElse: () => throw Exception('Symbol $symbol not found'),
    );

    final precision = {
      'quantityPrecision': symbolInfo['quantityPrecision'] as int,
      'pricePrecision': symbolInfo['pricePrecision'] as int,
    };

    _precisionCache[symbol] = precision;
    return precision;
  }

  /// Оптимизированное открытие позиции с параллельными запросами
  static Future<Map<String, dynamic>> openMarketOrder({
    required String symbol,
    required String side,
    required double usdtAmount,
    String? newClientOrderId,
  }) async {
    // Параллельно получаем precision и цену
    final futures = await Future.wait([
      getSymbolPrecision(symbol),
      getCurrentPrice(symbol),
    ]);

    final precision = futures[0] as Map<String, int>;
    final currentPrice = futures[1] as double;

    if (usdtAmount < 5.0) {
      throw Exception('Minimum order is 5 USDT');
    }

    final quantity = (usdtAmount / currentPrice).toStringAsFixed(precision['quantityPrecision']!);

    final params = {
      'symbol': symbol,
      'side': side,
      'type': 'MARKET',
      'quantity': quantity,
      if (newClientOrderId != null) 'newClientOrderId': newClientOrderId,
    };

    return await _sendAuthorizedPostRequest('/fapi/v1/order', params);
  }

  /// Оптимизированная установка TP/SL
  static Future<void> setAutoTakeProfitAndStopLoss({
    required String symbol,
    required String positionSide,
    double takeProfitPercent = 3.0,
    double stopLossPercent = 1.0,
    String? newClientOrderId,
  }) async {
    // Параллельно получаем precision и цену
    final futures = await Future.wait([
      getSymbolPrecision(symbol),
      getCurrentPrice(symbol),
    ]);

    final precision = futures[0] as Map<String, int>;
    final currentPrice = futures[1] as double;

    double takeProfitPrice, stopLossPrice;

    if (positionSide == 'LONG') {
      takeProfitPrice = currentPrice * (1 + takeProfitPercent / 100);
      stopLossPrice = currentPrice * (1 - stopLossPercent / 100);
    } else {
      takeProfitPrice = currentPrice * (1 - takeProfitPercent / 100);
      stopLossPrice = currentPrice * (1 + stopLossPercent / 100);
    }

    final formattedTP = takeProfitPrice.toStringAsFixed(precision['pricePrecision']!);
    final formattedSL = stopLossPrice.toStringAsFixed(precision['pricePrecision']!);

    final orderSide = positionSide == 'LONG' ? 'SELL' : 'BUY';

    // Параллельно устанавливаем TP и SL
    await Future.wait([
      _sendAuthorizedPostRequest('/fapi/v1/order', {
        'symbol': symbol,
        'side': orderSide,
        'type': 'TAKE_PROFIT_MARKET',
        'stopPrice': formattedTP,
        'closePosition': 'true',
        'workingType': 'MARK_PRICE',
        if (newClientOrderId != null) 'newClientOrderId': '${newClientOrderId}_TP',
      }),
      _sendAuthorizedPostRequest('/fapi/v1/order', {
        'symbol': symbol,
        'side': orderSide,
        'type': 'STOP_MARKET',
        'stopPrice': formattedSL,
        'closePosition': 'true',
        'workingType': 'MARK_PRICE',
        if (newClientOrderId != null) 'newClientOrderId': '${newClientOrderId}_SL',
      }),
    ]);
  }
}