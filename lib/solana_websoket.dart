import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SolanaTokenMonitorApp());
}

class SolanaTokenMonitorApp extends StatelessWidget {
  const SolanaTokenMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solana Token Monitor',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const TokenMonitorScreen(),
    );
  }
}

class TokenMonitorScreen extends StatefulWidget {
  const TokenMonitorScreen({super.key});

  @override
  State<TokenMonitorScreen> createState() => _TokenMonitorScreenState();
}

class _TokenMonitorScreenState extends State<TokenMonitorScreen> {
  final String rpcEndpoint =
      'https://mainnet.helius-rpc.com/?api-key=cd716db1-6133-46b4-9f2f-59f5b72c329b';
  final String wsEndpoint =
      'wss://mainnet.helius-rpc.com/?api-key=cd716db1-6133-46b4-9f2f-59f5b72c329b';
  final String rayFeePubkey = '7YttLkHDoNj9wyDur5pM1ejNaAvT9X4eqaYcHQqtj2G5';

  late IOWebSocketChannel channel;
  List<Map<String, dynamic>> tokenDataList = [];

  @override
  void initState() {
    super.initState();
    startMonitoring();
  }

  Future<String> getDataFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/new_solana_tokens.json';
  }

  Future<void> storeData(Map<String, dynamic> data) async {
    try {
      final filePath = await getDataFilePath();
      final file = File(filePath);
      List<dynamic> currentData = [];

      if (await file.exists()) {
        final content = await file.readAsString();
        currentData = jsonDecode(content);
      }

      currentData.add(data);
      await file.writeAsString(jsonEncode(currentData));
      print('Data stored successfully at $filePath');
    } catch (e) {
      print('Error storing data: $e');
    }
  }

  Future<Map<String, dynamic>?> getParsedTransaction(String signature) async {
    try {
      final response = await http.post(
        Uri.parse(rpcEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "jsonrpc": "2.0",
          "id": 1,
          "method": "getTransaction",
          "params": [
            signature,
            {"encoding": "jsonParsed", "maxSupportedTransactionVersion": 0, "commitment": "confirmed"}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          return data['result'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching transaction: $e');
      return null;
    }
  }

  void startMonitoring() async {
    try {
      channel = IOWebSocketChannel.connect(wsEndpoint);

      // Подписка на логи для rayFee
      final subscriptionRequest = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "logsSubscribe",
        "params": [
          {"mentions": [rayFeePubkey]},
          {"commitment": "confirmed"}
        ]
      };

      channel.sink.add(jsonEncode(subscriptionRequest));

      channel.stream.listen(
            (message) async {
          final data = jsonDecode(message);


          print(data);
          if (data['method'] == 'logsNotification') {
            final signature = data['params']['result']['value']['signature'];
            // print('Found new token signature: $signature');

            final tx = await getParsedTransaction(signature);
            if (tx != null && tx['meta']['err'] == null) {
              final signer = tx['transaction']['message']['accountKeys'][0]['pubkey'];
              print('Creator: $signer');

              final postTokenBalances = tx['meta']['postTokenBalances'] ?? [];
              final baseInfo = postTokenBalances.firstWhere(
                    (balance) =>
                balance['owner'] == '5Q544fKrFoe6tsEbD7S8EmxGTJYAKtTVhAW5Q5pge4j1' &&
                    balance['mint'] != 'So11111111111111111111111111111111111111112',
                orElse: () => {
                  'mint': '',
                  'owner': '',
                  'uiTokenAmount': {'decimals': 0, 'uiAmount': 0.0}
                },
              );

              final quoteInfo = postTokenBalances.firstWhere(
                    (balance) =>
                balance['owner'] == '5Q544fKrFoe6tsEbD7S8EmxGTJYAKtTVhAW5Q5pge4j1' &&
                    balance['mint'] == 'So11111111111111111111111111111111111111112',
                orElse: () => {
                  'mint': '',
                  'owner': '',
                  'uiTokenAmount': {'decimals': 0, 'uiAmount': 0.0}
                },
              );

              final newTokenData = {
                'lpSignature': signature,
                'creator': signer,
                'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                'baseInfo': {
                  'baseAddress': baseInfo['mint'],
                  'baseDecimals': baseInfo['uiTokenAmount']['decimals'],
                  'baseLpAmount': baseInfo['uiTokenAmount']['uiAmount'],
                },
                'quoteInfo': {
                  'quoteAddress': quoteInfo['mint'],
                  'quoteDecimals': quoteInfo['uiTokenAmount']['decimals'],
                  'quoteLpAmount': quoteInfo['uiTokenAmount']['uiAmount'],
                },
                'logs': data['params']['result']['value']['logs'],
              };

              await storeData(newTokenData);
              setState(() {
                tokenDataList.add(newTokenData);
              });
            }
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );
    } catch (e) {
      print('Error starting monitoring: $e');
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana Token Monitor'),
      ),
      body: tokenDataList.isEmpty
          ? const Center(child: Text('Monitoring new tokens...'))
          : ListView.builder(
        itemCount: tokenDataList.length,
        itemBuilder: (context, index) {
          final token = tokenDataList[index];
          return ListTile(
            title: Text('Signature: ${token['lpSignature']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Creator: ${token['creator']}'),
                Text('Timestamp: ${token['timestamp']}'),
                Text(
                    'Base: ${token['baseInfo']['baseAddress']} (${token['baseInfo']['baseLpAmount']} units)'),
                Text(
                    'Quote: ${token['quoteInfo']['quoteAddress']} (${token['quoteInfo']['quoteLpAmount']} units)'),
              ],
            ),
          );
        },
      ),
    );
  }
}