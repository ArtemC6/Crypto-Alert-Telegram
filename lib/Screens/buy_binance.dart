import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class BinanceFuturesClient {
  static const String apiKey = 'AazqfPsSB6hEPfdBsr67RRZCYWkQjxLOwapQG56oQZNyyu4RSb6qQxE70zV8MDKV';
  static const String secretKey = '7pBSo1KnhC9hz3GzpQBDnbeTab0U4eI0cu2H8MKjPZh0gx2x8drsNeA69o8eUFRk';
  static const String baseUrl = 'https://fapi.binance.com';

  /// Генерация подписи
  static String _generateSignature(Map<String, dynamic> params) {
    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return Hmac(sha256, utf8.encode(secretKey)).convert(utf8.encode(queryString)).toString();
  }

  /// Отправка авторизованного POST-запроса
  static Future<dynamic> _sendAuthorizedPostRequest(
    String endpoint,
    Map<String, dynamic> params,
  ) async {
    try {
      final requestParams = {
        ...params,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'recvWindow': '5000',
      };

      final signature = _generateSignature(requestParams);
      final signedParams = {...requestParams, 'signature': signature};

      final uri = Uri.parse('$baseUrl$endpoint');
      final body = signedParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');

      final response = await http.post(
        uri,
        headers: {
          'X-MBX-APIKEY': apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// Получение текущей цены символа
  static Future<double> getCurrentPrice(String symbol) async {
    final uri = Uri.parse('$baseUrl/fapi/v1/ticker/price?symbol=$symbol');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch price: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return double.parse(data['price']);
  }

  /// Получение информации о бирже
  static Future<Map<String, dynamic>> getExchangeInfo() async {
    final uri = Uri.parse('$baseUrl/fapi/v1/exchangeInfo');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exchange info: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  /// Получение precision для символа
  static Future<Map<String, int>> getSymbolPrecision(String symbol) async {
    final exchangeInfo = await getExchangeInfo();
    final symbols = exchangeInfo['symbols'] as List<dynamic>;
    final symbolInfo = symbols.firstWhere(
      (s) => s['symbol'] == symbol,
      orElse: () => throw Exception('Symbol $symbol not found'),
    );

    return {
      'quantityPrecision': symbolInfo['quantityPrecision'] as int,
      'pricePrecision': symbolInfo['pricePrecision'] as int,
    };
  }

  /// Открытие рыночной позиции
  static Future<Map<String, dynamic>> openMarketOrder({
    required String symbol,
    required String side, // 'BUY' или 'SELL'
    required double usdtAmount, // Сумма в USDT
    String? newClientOrderId,
  }) async {
    // Получаем precision и текущую цену
    final precision = await getSymbolPrecision(symbol);
    final quantityPrecision = precision['quantityPrecision']!;
    final currentPrice = await getCurrentPrice(symbol);

    // Рассчитываем количество
    double quantity = usdtAmount / currentPrice;

    // Проверяем минимальный notional (quantity * price >= 5 USDT)
    if (usdtAmount < 5.0) {
      throw Exception('Notional value ($usdtAmount USDT) is below minimum 5 USDT. Increase amount.');
    }

    final params = {
      'symbol': symbol,
      'side': side,
      'type': 'MARKET',
      'quantity': quantity.toStringAsFixed(quantityPrecision),
      if (newClientOrderId != null) 'newClientOrderId': newClientOrderId,
    };

    final result = await _sendAuthorizedPostRequest('/fapi/v1/order', params);
    print('Позиция открыта: $result');
    return result;
  }

  /// Установка Take Profit и Stop Loss
  static Future<void> setAutoTakeProfitAndStopLoss({
    required String symbol,
    required String positionSide, // 'LONG' или 'SHORT'
    double takeProfitPercent = 3.0, // 3% тейк-профит
    double stopLossPercent = 1.0, // 1% стоп-лосс
    String? newClientOrderId,
  }) async {
    final precision = await getSymbolPrecision(symbol);
    final pricePrecision = precision['pricePrecision']!;
    final currentPrice = await getCurrentPrice(symbol);

    double takeProfitPrice, stopLossPrice;

    if (positionSide == 'LONG') {
      takeProfitPrice = currentPrice * (1 + takeProfitPercent / 100);
      stopLossPrice = currentPrice * (1 - stopLossPercent / 100);
    } else {
      // SHORT
      takeProfitPrice = currentPrice * (1 - takeProfitPercent / 100);
      stopLossPrice = currentPrice * (1 + stopLossPercent / 100);
    }

    takeProfitPrice = double.parse(takeProfitPrice.toStringAsFixed(pricePrecision));
    stopLossPrice = double.parse(stopLossPrice.toStringAsFixed(pricePrecision));

    print('Текущая цена: $currentPrice');
    print('Take Profit (+$takeProfitPercent%): $takeProfitPrice');
    print('Stop Loss (-$stopLossPercent%): $stopLossPrice');

    final orderSide = positionSide == 'LONG' ? 'SELL' : 'BUY';

    // Устанавливаем Stop Loss
    final slParams = {
      'symbol': symbol,
      'side': orderSide,
      'type': 'STOP_MARKET',
      'stopPrice': stopLossPrice.toStringAsFixed(pricePrecision),
      'closePosition': 'true', // Закрываем всю позицию
      'workingType': 'MARK_PRICE',
      if (newClientOrderId != null) 'newClientOrderId': '${newClientOrderId}_SL',
    };

    await _sendAuthorizedPostRequest('/fapi/v1/order', slParams);
    print('✅ Stop Loss установлен на $stopLossPrice');

    // Устанавливаем Take Profit
    final tpParams = {
      'symbol': symbol,
      'side': orderSide,
      'type': 'TAKE_PROFIT_MARKET',
      'stopPrice': takeProfitPrice.toStringAsFixed(pricePrecision),
      'closePosition': 'true', // Закрываем всю позицию
      'workingType': 'MARK_PRICE',
      if (newClientOrderId != null) 'newClientOrderId': '${newClientOrderId}_TP',
    };

    await _sendAuthorizedPostRequest('/fapi/v1/order', tpParams);
    print('✅ Take Profit установлен на $takeProfitPrice');
  }
}
