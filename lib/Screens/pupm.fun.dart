import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import '../const.dart';
import '../services/api.dart';
import '../utils.dart';

class PoolListScreen extends StatefulWidget {
  const PoolListScreen({super.key});

  @override
  State<PoolListScreen> createState() => _PoolListScreenState();
}

class _PoolListScreenState extends State<PoolListScreen> {
  late WebSocketChannel _channel;
  final Map<String, Map<String, dynamic>> _pools = {};
  final Set<String> _notifiedPoolIds = {};

  @override
  void initState() {
    super.initState();
    connectWebSocketMem();
  }

  void connectWebSocketMem() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://trench-stream.jup.ag/ws'),
    );

    _channel.sink.add(jsonEncode({"type": "subscribe:recent"}));
    _channel.sink.add(jsonEncode({"type": "subscribe:pool", "pools": []}));
    _channel.sink.add(jsonEncode({"type": "subscribe:txns", "assets": []}));

    _channel.stream.listen(
      (message) async {
        final data = jsonDecode(message);
        if (data['type'] == 'updates') {
          for (var update in data['data']) {
            if (update['type'] == 'update' && update['pool'] != null) {
              final pool = update['pool'];
              _pools[pool['id']] = pool;
              if (passesFilters(pool) &&
                  !_notifiedPoolIds.contains(pool['id'])) {
                sendTelegramNotificationMem(pool);
                _notifiedPoolIds.add(pool['id']);
              }
            }
          }
        } else if (data['type'] == 'new') {
          for (var newPool in data['data']) {
            if (newPool['type'] == 'new' && newPool['pool'] != null) {
              final pool = newPool['pool'];
              _pools[pool['id']] = pool;
              if (passesFilters(pool) &&
                  !_notifiedPoolIds.contains(pool['id'])) {
                _notifiedPoolIds.add(pool['id']);
                sendTelegramNotificationMem(pool);
              }
            }
          }
        }

        _pools.removeWhere((id, pool) {
          final baseAsset = pool['baseAsset'] ?? {};
          final String createdAt =
              pool['createdAt'] ?? baseAsset['firstPool']?['CreatedAt'] ?? '';
          if (createdAt.isNotEmpty) {
            final createdDate = DateTime.tryParse(createdAt);
            if (createdDate != null) {
              final ageInSeconds =
                  DateTime.now().difference(createdDate).inMinutes;
              return ageInSeconds > 600;
            }
          }
          return false;
        });
        setState(() {});
      },
      onError: (error) => print('WebSocket error: $error'),
      onDone: () {
        print('WebSocket closed');
        Future.delayed(const Duration(seconds: 2), connectWebSocketMem);
      },
    );
  }

  bool passesFilters(Map<String, dynamic> pool) {
    final baseAsset = pool['baseAsset'] ?? {};

    final double marketCap =
        (baseAsset['mcap'] ?? pool['mcap'] ?? 0).toDouble();
    final double liquidity = (pool['liquidity'] ?? 0).toDouble();
    final double volume24h = (pool['volume24h'] ?? 0).toDouble();
    final int holders = (baseAsset['holderCount'] ?? 0) as int;
    final String createdAt =
        pool['createdAt'] ?? baseAsset['firstPool']?['CreatedAt'] ?? '';
    final double bondingCurve = (pool['bondingCurve'] ?? 0).toDouble();
    final double organicScore =
        (baseAsset['organicScore'] ?? pool['organicScore'] ?? 0).toDouble();
    final int organicBuyers24h =
        (baseAsset['organicBuyers24h'] ?? pool['organicBuyers24h'] ?? 0) as int;

    // Статистика
    final stats5m = pool['baseAsset']['stats5m'] ?? {};
    final stats24h = pool['baseAsset']['stats24h'] ?? {};

    final double priceChange5m = (stats5m['priceChange'] ?? 0).toDouble();
    final double buyVolume5m = (stats5m['buyVolume'] ?? 0).toDouble();
    final double sellVolume5m = (stats5m['sellVolume'] ?? 0).toDouble();
    final int numBuys5m = (stats5m['numBuys'] ?? 0) as int;
    final int numSells5m = (stats5m['numSells'] ?? 0) as int;
    final int numTraders5m = (stats5m['numTraders'] ?? 0) as int;
    final int numBuyers5m = (stats5m['numBuyers'] ?? 0) as int;
    final int numSellers5m = (stats5m['numSellers'] ?? 0) as int;

    final double buyVolume24h = (stats24h['buyVolume'] ?? 0).toDouble();
    final double sellVolume24h = (stats24h['sellVolume'] ?? 0).toDouble();
    final int numBuys24h = (stats24h['numBuys'] ?? 0) as int;
    final int numSells24h = (stats24h['numSells'] ?? 0) as int;
    final int numTraders24h = (stats24h['numTraders'] ?? 0) as int;
    final int numBuyers24h = (stats24h['numBuyers'] ?? 0) as int;
    final int numSellers24h = (stats24h['numSellers'] ?? 0) as int;

    final audit = baseAsset['audit'] ?? {};
    final bool mintAuthorityDisabled = audit['mintAuthorityDisabled'] ?? false;
    final bool freezeAuthorityDisabled =
        audit['freezeAuthorityDisabled'] ?? false;
    final double topHoldersPercentage =
        (audit['topHoldersPercentage'] ?? 0).toDouble();

    int age = 0;
    if (createdAt.isNotEmpty) {
      final createdDate = DateTime.tryParse(createdAt);
      if (createdDate != null) {
        age = DateTime.now().difference(createdDate).inSeconds;
      }
    }

    final bool hasEnoughMarketCap = marketCap >= 6000 && marketCap <= 300000;
    final bool hasEnoughLiquidity = liquidity >= 5000;
    final bool hasEnoughVolume24h = volume24h >= 40000;
    final bool hasEnoughHolders = holders >= 200;
    final bool isNotTooOld = age <= 2000;

    final bool hasHighVolume24h =
        buyVolume24h >= 5000 || sellVolume24h >= 5000; // Высокий объем торгов
    final bool hasEnoughTraders24h =
        numTraders24h >= 60; // Достаточно трейдеров за 24 часа
    final bool hasMoreBuysThanSells24h =
        numBuys24h > numSells24h; // Покупок больше, чем продаж
    final bool hasLowTopHoldersPercentage =
        topHoldersPercentage <= 30; // Низкая концентрация у крупных держателей

    final bool hasGoodOrganicScore =
        organicScore >= 50; // Хороший органический рост
    final bool hasEnoughOrganicBuyers =
        organicBuyers24h >= 50; // Достаточно органических покупателей


    return hasEnoughMarketCap &&
        hasEnoughLiquidity &&
        hasGoodOrganicScore &&
        hasEnoughOrganicBuyers &&
        hasEnoughVolume24h &&
        hasEnoughHolders &&
        freezeAuthorityDisabled &&
        mintAuthorityDisabled &&
        hasLowTopHoldersPercentage &&
        isNotTooOld &&
        hasMoreBuysThanSells24h &&
        hasEnoughTraders24h &&
        hasHighVolume24h;
  }

  Future<void> sendTelegramNotificationMem(Map<String, dynamic> pool) async {
    try {
      final percent = await analyzeTokenWithAIMem(pool);
      print(percent);
      if (percent >= 70) return;

      final baseAsset = pool['baseAsset'] ?? {};
      final stats5m = pool['baseAsset']['stats5m'] ?? {};

      final double priceChange5m = (stats5m['priceChange'] ?? 0).toDouble();
      final double buyVolume5m = (stats5m['buyVolume'] ?? 0).toDouble();
      final double sellVolume5m = (stats5m['sellVolume'] ?? 0).toDouble();
      final int numBuys5m = (stats5m['numBuys'] ?? 0) as int;
      final int numSells5m = (stats5m['numSells'] ?? 0) as int;
      final int numTraders5m = (stats5m['numTraders'] ?? 0) as int;
      final int numBuyers5m = (stats5m['numBuyers'] ?? 0) as int;
      final int numSellers5m = (stats5m['numSellers'] ?? 0) as int;

      final String symbol = baseAsset['symbol'] ?? 'Unknown';
      final String name = baseAsset['name'] ?? 'Unknown';
      final String liquidity = pool['liquidity']?.toStringAsFixed(2) ?? 'N/A';
      final String? imageUrl = baseAsset['icon'];
      final String tokenAddress = baseAsset['id'] ?? 'N/A';
      final String marketCap = pool['mcap']?.toStringAsFixed(2) ??
          baseAsset['mcap']?.toStringAsFixed(2) ??
          'N/A';
      final String volume24h = pool['volume24h']?.toStringAsFixed(2) ?? 'N/A';
      final String holderCount = baseAsset['holderCount']?.toString() ?? 'N/A';
      final String createdAt =
          pool['createdAt'] ?? baseAsset['firstPool']?['CreatedAt'] ?? '';



      final double organicScore =
      (baseAsset['organicScore'] ?? pool['organicScore'] ?? 0).toDouble();
      final int organicBuyers24h =
      (baseAsset['organicBuyers24h'] ?? pool['organicBuyers24h'] ?? 0) as int;


      String socialLinksString =
          '🔹 *BulX:* ${'https://neo.bullx.io/terminal?chainId=1399811149&address=$tokenAddress'}\n\n';

      final audit = baseAsset['audit'] ?? {};
      final double topHoldersPercentage =
          (audit['topHoldersPercentage'] ?? 0).toDouble();

      final String caption = '''
*🔹$name* 🚀

🔹 *Symbol:* $symbol : $percent%  
🔹 *Market Cap:* ${formatMarketCapString(marketCap)}
🔹 *Age:* ${formatTime(createdAt)}
🔹 *Liquidity:* \$${formatMarketCapString(liquidity)}
🔹 *24h Volume:* \$${formatMarketCapString(volume24h)}
🔹 *Holders:* $holderCount

🔹 *Top Holders Percentage:* ${topHoldersPercentage.toStringAsFixed(1)}%


🔹 *priceChange5m:* $priceChange5m

🔹 *buyVolume5m:* $buyVolume5m
🔹 *sellVolume5m:* $sellVolume5m

🔹 *numBuys5m:* $numBuys5m
🔹 *numSells5m:* $numSells5m

🔹 *numTraders5m:* $numTraders5m

🔹 *numBuyers5m:* $numBuyers5m
🔹 *numSellers5m:* $numSellers5m

  

🔹 *Token Address:* `$tokenAddress`

$socialLinksString
'''
          .trim();

      final String url =
          'https://api.telegram.org/bot$telegramBotToken/sendPhoto';
      final String messageUrl =
          'https://api.telegram.org/bot$telegramBotToken/sendMessage';

      http.Response response;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final imageResponse = await http.get(Uri.parse(imageUrl));
        if (imageResponse.statusCode == 200 &&
            imageResponse.bodyBytes.isNotEmpty) {
          var request = http.MultipartRequest('POST', Uri.parse(url))
            ..fields['chat_id'] = chatId
            ..fields['caption'] = caption
            ..fields['parse_mode'] = 'Markdown'
            ..files.add(http.MultipartFile.fromBytes(
              'photo',
              imageResponse.bodyBytes,
              filename: 'pool_$symbol.png',
            ));

          final streamedResponse = await request.send();
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

      if (response.statusCode != 200) {
        print(
            "Failed to send Telegram notification: ${response.statusCode}, ${response.body}");
      } else {
        print("Notification sent successfully for token: $tokenAddress");
      }
    } catch (e) {
      print("Error sending Telegram notification: $e");
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedPools = _pools.values.toList()
      ..sort((a, b) {
        final aTime = (a['baseAsset']?['firstPool']?['CreatedAt'] ??
            a['createdAt'] ??
            '');
        final bTime = (b['baseAsset']?['firstPool']?['CreatedAt'] ??
            b['createdAt'] ??
            '');

        final aDate = DateTime.tryParse(aTime.toString()) ?? DateTime(0);
        final bDate = DateTime.tryParse(bTime.toString()) ?? DateTime(0);

        return bDate.compareTo(aDate);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana Pools'),
      ),
      body: _pools.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: sortedPools.length,
              itemBuilder: (context, index) {
                final pool = sortedPools[index];
                return PoolCard(pool: pool);
              },
            ),
    );
  }
}

class PoolCard extends StatelessWidget {
  final Map<String, dynamic> pool;

  const PoolCard({super.key, required this.pool});

  @override
  Widget build(BuildContext context) {
    final baseAsset = pool['baseAsset'] ?? {};
    final stats5m = pool['stats5m'] ?? {};
    final stats1h = pool['stats1h'] ?? {};
    final audit = pool['audit'] ?? {};
    final firstPool = baseAsset['firstPool'] ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      if (baseAsset['icon'] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.network(
                            baseAsset['icon'],
                            width: 32,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.token),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          baseAsset['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  baseAsset['symbol'] ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Age ${formatTime(firstPool['CreatedAt'] ?? pool['createdAt'])}',
              style: const TextStyle(fontSize: 17, color: Colors.white),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Market Cap: \$${formatMarketCap(baseAsset['mcap']?.toStringAsFixed(2) ?? pool['mcap']?.toStringAsFixed(2)) ?? 'N/A'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DEX: ${pool['dex'] ?? 'N/A'}'),
                    Text('Type: ${pool['type'] ?? 'N/A'}'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Liquidity: \$${pool['liquidity']?.toStringAsFixed(2) ?? 'N/A'}'),
                    Text(
                        'Volume 24h: \$${pool['volume24h']?.toStringAsFixed(2) ?? 'N/A'}'),
                    Text(
                        'buyVolume 24h: \$${pool['buyVolume']?.toStringAsFixed(2) ?? 'N/A'}'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Holders: ${baseAsset['holderCount'] ?? 'N/A'}'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (pool['organicScoreLabel'] != null)
                  Chip(
                    label: Text(
                      pool['organicScoreLabel'],
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor:
                        _getOrganicScoreColor(pool['organicScoreLabel']),
                  ),
                if (pool['bondingCurve'] != null)
                  Chip(
                    label: Text(
                        'Bonding: ${pool['bondingCurve'].toStringAsFixed(2)}%'),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _getOrganicScoreColor(String? label) {
    switch (label?.toLowerCase()) {
      case 'high':
        return Colors.green.withOpacity(0.2);
      case 'medium':
        return Colors.yellow.withOpacity(0.2);
      case 'low':
        return Colors.red.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  String? formatMarketCap(String? value) {
    if (value == null) return null;
    final double? num = double.tryParse(value);
    if (num == null) return 'N/A';
    if (num >= 1000000) {
      return '\$${(num / 1000000).toStringAsFixed(2)}M';
    } else if (num >= 1000) {
      return '\$${(num / 1000).toStringAsFixed(2)}K';
    }
    return '\$${num.toStringAsFixed(2)}';
  }
}
// import 'package:flutter/material.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/io.dart';
// import 'dart:convert';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'WebSocket Example',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: WebSocketExample(),
//     );
//   }
// }
//
// class WebSocketExample extends StatefulWidget {
//   @override
//   _WebSocketExampleState createState() => _WebSocketExampleState();
// }
//
// class _WebSocketExampleState extends State<WebSocketExample> {
//   final WebSocketChannel channel = IOWebSocketChannel.connect(
//     'wss://trench-stream.jup.ag/ws',
//     headers: {
//       'Upgrade': 'websocket',
//       'Origin': 'https://jup.ag',
//       'Cache-Control': 'no-cache',
//       'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
//       'Pragma': 'no-cache',
//       'Connection': 'Upgrade',
//       'Sec-WebSocket-Key': 'T4nss8VZEVdvSV/RSnw4AA==',
//       'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
//       'Sec-WebSocket-Version': '13',
//       'Sec-WebSocket-Extensions': 'permessage-deflate; client_max_window_bits',
//     },
//   );
//
//   Map<String, dynamic>? latestData;
//
//   @override
//   void initState() {
//     super.initState();
//     channel.sink.add(jsonEncode({"type": "subscribe:recent"}));
//     channel.sink.add(jsonEncode({"type": "subscribe:pool", "pools": []}));
//     channel.sink.add(jsonEncode({"type": "subscribe:txns", "assets": []}));
//
//     channel.stream.listen((message) {
//       final data = jsonDecode(message);
//       setState(() {
//         latestData = data; // Сохраняем последние данные
//       });
//     }, onError: (error) {
//       print('WebSocket error: $error');
//     }, onDone: () {
//       print('WebSocket connection closed');
//     });
//   }
//
//   @override
//   void dispose() {
//     channel.sink.close();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('WebSocket Data'),
//       ),
//       body: latestData == null
//           ? Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Card(
//             elevation: 4,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: _buildDataWidgets(latestData!),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   List<Widget> _buildDataWidgets(Map<String, dynamic> data) {
//     final List<Widget> widgets = [];
//
//     // Парсим данные вручную и добавляем подписи
//     if (data['type'] != null) {
//       widgets.add(
//         _buildDataItem('Тип обновления', data['type']),
//       );
//     }
//
//     if (data['data'] != null && data['data'] is List) {
//       for (var i = 0; i < data['data'].length; i++) {
//         final item = data['data'][i];
//         if (item['pool'] != null) {
//           final pool = item['pool'];
//           // print(pool);
//           // print(pool['stats5m']['sellVolume']);
//           // print(pool['baseAsset']['circSupply']);
//           // print(pool['holderChange']);
//
//           // widgets.addAll([
//           //   _buildDataItem('ID пула', pool['id']),
//           //   _buildDataItem('Блокчейн', pool['chain']),
//           //   _buildDataItem('DEX', pool['dex']),
//           //   _buildDataItem('Тип пула', pool['type']),
//           //   _buildDataItem('Базовый актив', ''),
//           //   _buildDataItem('  Название', pool['baseAsset']['name']),
//           //   _buildDataItem('  Символ', pool['baseAsset']['symbol']),
//           //   _buildDataItem('  Десятичные разряды', pool['baseAsset']['decimals']),
//           //   _buildDataItem('  Общий объем', pool['baseAsset']['totalSupply']),
//           //   _buildDataItem('Цитатный актив', pool['quoteAsset']),
//           //   _buildDataItem('Создан', pool['createdAt']),
//           //   _buildDataItem('Обновлен', pool['updatedAt']),
//           //   Divider(),
//           // ]);
//
//           // Добавляем данные из stats24h
//           if (pool['stats24h'] != null) {
//             final stats24h = pool['stats24h'];
//             widgets.addAll([
//               _buildDataItem('Статистика за 24 часа', ''),
//               _buildDataItem('  Изменение цены', stats24h['priceChange']),
//               _buildDataItem('  Изменение держателей', stats24h['holderChange']),
//               _buildDataItem('  Объем покупок', stats24h['buyVolume']),
//               _buildDataItem('  Объем продаж', stats24h['sellVolume']),
//               _buildDataItem('  Органический объем покупок', stats24h['buyOrganicVolume']),
//               _buildDataItem('  Органический объем продаж', stats24h['sellOrganicVolume']),
//               _buildDataItem('  Количество покупок', stats24h['numBuys']),
//               _buildDataItem('  Количество продаж', stats24h['numSells']),
//               _buildDataItem('  Количество трейдеров', stats24h['numTraders']),
//               _buildDataItem('  Количество покупателей', stats24h['numBuyers']),
//               _buildDataItem('  Количество продавцов', stats24h['numSellers']),
//               Divider(),
//             ]);
//           }
//
//           // Добавляем данные из audit
//           if (pool['audit'] != null) {
//             final audit = pool['audit'];
//             widgets.addAll([
//               _buildDataItem('Аудит', ''),
//               _buildDataItem('  Отключена ли возможность выпуска токенов', audit['mintAuthorityDisabled']),
//               _buildDataItem('  Отключена ли возможность заморозки токенов', audit['freezeAuthorityDisabled']),
//               _buildDataItem('  Доля крупнейших держателей', audit['topHoldersPercentage']),
//               Divider(),
//             ]);
//           }
//         }
//       }
//     }
//
//     return widgets;
//   }
//
//   Widget _buildDataItem(String label, dynamic value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             '$label: ',
//             style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//           ),
//           Expanded(
//             child: Text(
//               '$value',
//               style: TextStyle(fontSize: 14),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
