import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'Screens/home.dart';

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
      // home: WebSocketPage(),
      // home: TokenInfoScreen(),
      // home: TokenInfoScreen2(),
      home: MyHomePage(),
    );
  }
}

class WebSocketPage extends StatefulWidget {
  @override
  _WebSocketPageState createState() => _WebSocketPageState();
}

class _WebSocketPageState extends State<WebSocketPage> {
  final WebSocketChannel _channel = WebSocketChannel.connect(
    Uri.parse('wss://pumpportal.fun/api/data'),
  );

  List<Map<String, dynamic>> _messages = [];

  @override
  void dispose() {
    _channel.sink.close(status.goingAway);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PumpPortal WebSocket')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _channel.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  try {
                    final Map<String, dynamic> parsedData = jsonDecode(snapshot.data.toString());

                    print(parsedData);
                    _messages.insert(0, parsedData);
                    if (_messages.length > 1) _messages.removeLast();
                  } catch (e) {
                    print('Ошибка парсинга JSON: $e');
                  }

                  return ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final data = _messages[index];
                      return Card(
                        margin: EdgeInsets.all(8),
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🆔 Символ: ${data["mint"]}',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('📛 Имя: ${data["name"]}'),
                              Text('💰 Куплено: ${data["initialBuy"]}'),
                              Text('💲 SOL: ${data["solAmount"]}'),
                              Text('🏦 Рыночная кап. (SOL): ${data["marketCapSol"]}'),
                              Text('🔗 Ссылка: ${data["uri"]}'),
                              Text('🔗 Ссылка: ${data["uri"]}'),
                              Text('🔗 Ссылка: ${data["uri"]}'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return Center(child: CircularProgressIndicator());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                // _channel.sink.add('{"method": "subscribeNewToken"}');
                _channel.sink.add(
                    '{"method": "subscribeTokenTrade", "keys": ["9XxwT2umxtsgygx2FTxZg79KN4k2dKaktCHqBDQBpump"]}');

                // payload = {
                //   "method": "subscribeTokenTrade",
                //   "keys": ["91WNez8D22NwBssQbkzjy4s2ipFrzpmn5hfvWVe2aY5p"]  # array of token CAs to watch
                // }
                // await websocket.send(json.dumps(payload))
              },
              child: Text('Подписаться на новые токены'),
            ),
          ),
        ],
      ),
    );
  }
}

// {signature: 5i19GKaFmabsjGNZ73hfHmRySFwjtJjP94YNnTdSDPc7wktGM3rvVar2RZiqxwPwdgU7rf9oj6JrCCeXRs8BUqoh,
// mint: 3dnzgtfkHa1hmkm78sX8t8dU7vdrVHpox1QmveqUpump, traderPublicKey:
// DxpWneYSL8Dtccgiyd1yZrQZnVA3msrcStp1W7ciwsrf, txType: sell, tokenAmount: 140892.82456300035, solAmount: 0.041537208, newTokenBalance: 6903748.403573, bondingCurveKey: HAYc3TLF4jK6DXEHbf4ppUtzfLzxuZpo9YEdE2wS5jXU,
// vTokensInBondingCurve: 330505629.782907,
// vSolInBondingCurve: 97.39622293618429, marketCapSol: 294.688544337835, pool: pump}

class TokenInfo {
  final String slippage;

  TokenInfo({required this.slippage});

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      slippage: json['slippage'].toString(),
    );
  }
}

class TokenInfoScreen extends StatefulWidget {
  @override
  _TokenInfoScreenState createState() => _TokenInfoScreenState();
}

class _TokenInfoScreenState extends State<TokenInfoScreen> {
  final TextEditingController _tokenAddressController = TextEditingController();
  String _slippage = "Fetching...";

  Future<void> _fetchTokenInfo() async {
    final tokenAddress = _tokenAddressController.text;
    final response = await http.get(
      Uri.parse(
          'https://docs.gmgn.ai/index/cooperation-api-integrate-gmgn-eth-base-trading-api/get-the-recommended-slippage-value-of-eth-base-token?tokenAddress=$tokenAddress'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      setState(() {
        _slippage = data['slippage'].toString();
      });
    } else {
      setState(() {
        _slippage = "Failed to fetch data";
      });
      print('Failed to fetch data: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Token Info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tokenAddressController,
              decoration: InputDecoration(
                labelText: 'Enter Token Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTokenInfo,
              child: Text('Fetch Info'),
            ),
            SizedBox(height: 16),
            Text('Recommended Slippage: $_slippage'),
          ],
        ),
      ),
    );
  }
}
