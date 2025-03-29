import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';

import '../model/token_model.dart';
import '../services/api.dart';
import '../services/storage.dart';
import '../utils.dart';

class MemeCoinMonitor {
  WebSocketChannel? _channel;
  WebSocketChannel? _channelMemMonitoring;
  final Set<String> notifiedPoolIds = {};
  final Set<String> _sentTokens = {};
  List<dynamic> _previousTokens = [];
  final BuildContext context;
  final StorageService storageService;
  Timer? _timer;

  MemeCoinMonitor(this.context, this.storageService);

  Future<void> connectWebSocketMem() async {
    const String webSocketUrl = 'wss://trench-stream.jup.ag/ws';
    const Duration reconnectDelay = Duration(seconds: 2);
    late WebSocketChannel channel;
    late WebSocketChannel channelMemMonitoring;

    void subscribeToChannels() {
      final subscriptions = [
        {"type": "subscribe:recent"},
        {"type": "subscribe:pool", "pools": []},
        {"type": "subscribe:txns", "assets": []}
      ];

      for (var subscription in subscriptions) {
        channel.sink.add(jsonEncode(subscription));
      }
    }

    Future<void> processPool(Map<String, dynamic> pool,
        {required int threshold}) async {
      if (!passesFilters(pool) || notifiedPoolIds.contains(pool['id'])) return;

      notifiedPoolIds.add(pool['id']);
      final tokenAddress = (pool['baseAsset']?['id'] as String?) ?? 'N/A';

      final marketCapAndAge = await fetchTokenInfo(tokenAddress);
      if (marketCapAndAge == null) return;

      final timestamp = marketCapAndAge.creationTimestamp != 0
          ? marketCapAndAge.creationTimestamp
          : marketCapAndAge.openTimestamp;

      final age = DateTime.now().difference(getDateTime(timestamp)).inMinutes;
      if (age > 40) return;

      final chartData = await fetchChartDataMem(tokenAddress);
      if (chartData == null || chartData.isEmpty) return;

      final chartImage = await showChartDialog(chartData, context);
      if (chartImage == null) return;

      final percent = await analyzeTokenWithAIMem(pool);
      if (percent > threshold) return;

      AudioPlayer().play(AssetSource('audio/coll.mp3'), volume: 0.8);
      sendTelegramNotificationMem(marketCapAndAge, percent, chartImage);
    }

    Future<void> handleMessage(dynamic message) async {
      try {
        final data = jsonDecode(message);
        final updates = data['data'] as List?;
        if (updates == null) return;

        for (var update in updates) {
          if (update['type'] == 'update' && update['pool'] != null) {
            processPool(update['pool'], threshold: 60);
          }
        }
      } catch (e) {
        print('Message processing error: $e');
      }
    }

    void reconnect() {
      Future.delayed(reconnectDelay, connectWebSocketMem);
    }

    try {
      channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));
      subscribeToChannels();

      channel.stream.listen(
        (message) => handleMessage(message),
        onError: (error) {
          print('WebSocket error: $error');
          reconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          reconnect();
        },
      );
    } catch (e) {
      print('WebSocket connection error: $e');
      reconnect();
    }
  }

  void startMonitoringTokens() {
    _startTimer();
  }

  Future<void> _startTimer() async {
    final List<String> solanaMemeTokens = [
      "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263", // BONK
      "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm", // WIF
      "6n7kLN4R8KiEPQ6wFXUZcNasqW4tQ2KaTjKrCpJDn4AM", // POPCAT
      "MEW1gQWJ3nEXg2qgERiKu7FAFj79PHvQVREQUzScPKs",  // MEOW
      "PENGuinx8WmdXTyGVrxrKmsmf9FKX6vX8rS7a3s19UN",  // PENG
      "8xM1hBit1i8f5vHyVwgAbrna9T38fP6w24F9nAQ7NFvW", // FART
      "5LafQUrXSHBnJTSjW4XsSHm9rUWsAzgepDLDsU3T3qao", // MUMU
      "6UE1R2HRvJHqDbmE7n5vD7wYbHPtnR1fXRE6KpE9P8G",  // GIGA
      "7bXqVp1m2m8W5n2cSZqH8JdgWq9wYqWAFp7nX6xkfZ7n", // SLERF
      "HhJpBhRR6cQNaXhRErP5f8jKXEEi3nRNgW3Rdg4nRKM1", // MYRO
      "G9tt98aYSznRk7jWsfuz9FnTdokxS6Brohdo9hSmvwTR", // SAMO
      "4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R", // RAY
      "AURYydfxJib1ZkTir1Jn1J9ECYUtjb6rKQVmtYaixWPP", // AURY
      "D3skXj4zUd2aHfsp1WwdkPi7a3WihmbXQYQFU1Z1J1Zk", // CHICKS
      "FANTafPFBAt93BNJVpdu25pGPmca3RfwdsDsRrT3LX1r", // FANT
      "H7ed7UgcLp3ax4X1CQ5WuWDn6d1pprfMMYiv5ejwLWWU", // SDOGE
      "7i5HgUzYfMoP5mM6rK7z4v5b5F7J5J5W5Y5Z5b5F7J5J", // MEOW
      "HxhWkVpk5NS4Ltg5nij2G671CKXFRKPK8vy271Ub4uEK", // HXH
      "5P3giWpPBrVKL8QP8roKM7NsLdi3ie1Nc2b5r9mGtvwb", // SLIM
      "7a4cXVvVT7kF6hS5q5LDqtzWfHfys4a9PoK6pf87RKwf", // SOLAPE
      "8PMHT4swUMtBzgHnh5U564N5sjPSiUz2cjEQzFnnP1Fo", // ROPE
      "9nEqaUcb16sQ3Tn1psbkWqyhPdLmfHWjKGymREjsAgTE", // WOOF
      "8upjSpvjcdpuzhfR1zriwg5NXkwDruejqNE9WNbPRtyA", // GRAPES
      "FnKE9n6aGjQoNWRBZXi4RuWQN3P6sZjY4nqzLk1JjFZ5", // SLIM
      "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU", // SAMO
      "HXqJgvfW31Q6xEZ1HoPiP4C1VEbAjXfLQrFVkGV7qDxr", // HXRO
      "8JnNWJ46yfdq8sKgT1Lk4G7WJ5e7d6Z8W6W5q5J5r5z5", // SOLCAT
      "7Q2afV64in6N6SeH6s1S5Z5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q5Q", // SOLDOGE
      "9nEqaUcb16sQ3Tn1psbkWqyhPdLmfHWjKGymREjsAgTE", // WOOF
      "FnKE9n6aGjQoNWRBZXi4RuWQN3P6sZjY4nqzLk1JjFZ5", // SLIM
      "8upjSpvjcdpuzhfR1zriwg5NXkwDruejqNE9WNbPRtyA", // GRAPES
      "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU", // SAMO
      "G9tt98aYSznRk7jWsfuz9FnTdokxS6Brohdo9hSmvwTR", // SAMO
      "HxhWkVpk5NS4Ltg5nij2G671CKXFRKPK8vy271Ub4uEK", // HXH
      "5P3giWpPBrVKL8QP8roKM7NsLdi3ie1Nc2b5r9mGtvwb", // SLIM
      "7a4cXVvVT7kF6hS5q5LDqtzWfHfys4a9PoK6pf87RKwf", // SOLAPE
      "8PMHT4swUMtBzgHnh5U564N5sjPSiUz2cjEQzFnnP1Fo", // ROPE
      "9nEqaUcb16sQ3Tn1psbkWqyhPdLmfHWjKGymREjsAgTE", // WOOF
      "FnKE9n6aGjQoNWRBZXi4RuWQN3P6sZjY4nqzLk1JjFZ5", // SLIM
      "8upjSpvjcdpuzhfR1zriwg5NXkwDruejqNE9WNbPRtyA", // GRAPES
      "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU", // SAMO
      "G9tt98aYSznRk7jWsfuz9FnTdokxS6Brohdo9hSmvwTR", // SAMO
      "HxhWkVpk5NS4Ltg5nij2G671CKXFRKPK8vy271Ub4uEK", // HXH
      "5P3giWpPBrVKL8QP8roKM7NsLdi3ie1Nc2b5r9mGtvwb", // SLIM
      "7a4cXVvVT7kF6hS5q5LDqtzWfHfys4a9PoK6pf87RKwf", // SOLAPE
      "8PMHT4swUMtBzgHnh5U564N5sjPSiUz2cjEQzFnnP1Fo", // ROPE
      "9nEqaUcb16sQ3Tn1psbkWqyhPdLmfHWjKGymREjsAgTE", // WOOF
      "FnKE9n6aGjQoNWRBZXi4RuWQN3P6sZjY4nqzLk1JjFZ5", // SLIM
      "8upjSpvjcdpuzhfR1zriwg5NXkwDruejqNE9WNbPRtyA", // GRAPES
      "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU", // SAMO
      "G9tt98aYSznRk7jWsfuz9FnTdokxS6Brohdo9hSmvwTR", // SAMO
      "HxhWkVpk5NS4Ltg5nij2G671CKXFRKPK8vy271Ub4uEK", // HXH
      "5P3giWpPBrVKL8QP8roKM7NsLdi3ie1Nc2b5r9mGtvwb", // SLIM
      "7a4cXVvVT7kF6hS5q5LDqtzWfHfys4a9PoK6pf87RKwf", // SOLAPE
      "8PMHT4swUMtBzgHnh5U564N5sjPSiUz2cjEQzFnnP1Fo", // ROPE
      "9nEqaUcb16sQ3Tn1psbkWqyhPdLmfHWjKGymREjsAgTE", // WOOF
      "FnKE9n6aGjQoNWRBZXi4RuWQN3P6sZjY4nqzLk1JjFZ5", // SLIM
      "8upjSpvjcdpuzhfR1zriwg5NXkwDruejqNE9WNbPRtyA", // GRAPES
      "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU", // SAMO
      "G9tt98aYSznRk7jWsfuz9FnTdokxS6Brohdo9hSmvwTR", // SAMO
    ];


    _timer = Timer.periodic(Duration(seconds: 2), (_) {
      // _fetchAndUpdateTokens();

      solanaMemeTokens.forEach((tokenAddress) async {
        // fetchTokenInfo(tokenAddress);
      });

    });
  }

  Future<void> _fetchAndUpdateTokens() async {
    try {
      final tokens = await fetchTokensTop200();
      final currentTimeInSeconds =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final minTokenAgeInSeconds = 0 * 60;
      final maxTokenAgeInSeconds = 200 * 60;

      final sortedTokens = tokens.where((token) {
        final marketCap = parseDouble(token['marketCap']);
        final creationTime = token['createdAt'] as int;
        final tokenAgeInSeconds = currentTimeInSeconds - creationTime;
        final isOldEnough = tokenAgeInSeconds >= minTokenAgeInSeconds;
        final isNotTooOld = tokenAgeInSeconds <= maxTokenAgeInSeconds;
        final holders = parseInt(token['holders']);

        final liquidity = parseDouble(token['liquidity']);
        final txnCount24 = parseInt(token['txnCount24']);
        final uniqueBuys24 = parseInt(token['uniqueBuys24']);
        final uniqueSells24 = parseInt(token['uniqueSells24']);
        final volume24 = parseDouble(token['volume24']);

        final hasEnoughVolume = volume24 > 9000;
        final hasEnoughUniqueParticipants =
            uniqueBuys24 > 320 && uniqueSells24 > 220;
        final hasEnoughTransactions = txnCount24 > 280;
        final hasEnoughLiquidity = liquidity > 9000;
        final hasEnoughHolders = holders >= 550;

        final hasEnoughMarketCap = marketCap >= 10000 && marketCap <= 1000000 ||
            marketCap >= 100000 && marketCap < 3000000 ||
            marketCap >= 3000000 && marketCap < 5000000 ||
            marketCap >= 5000000 && marketCap < 20000000 ||
            marketCap >= 10000000 && marketCap < 50000000;

        return hasEnoughMarketCap &&
            isOldEnough &&
            isNotTooOld &&
            hasEnoughHolders &&
            hasEnoughLiquidity &&
            hasEnoughTransactions &&
            hasEnoughUniqueParticipants &&
            hasEnoughVolume;
      }).toList();

      _checkForNewTokens(sortedTokens);
      _previousTokens = List.from(sortedTokens);
    } catch (e) {
      print("Error fetching tokens: $e");
    }
  }

  void _checkForNewTokens(List<dynamic> sortedTokens) async {
    if (_previousTokens.isEmpty) return;

    final newTokens = sortedTokens.where((newToken) {
      final tokenSymbol = newToken['token']['symbol'];
      final tokenAddress = newToken['token']['address'];
      return !_previousTokens.any(
            (oldToken) =>
                oldToken['token']['symbol'] == tokenSymbol &&
                oldToken['token']['address'] == tokenAddress,
          ) &&
          !_isTokenSent(tokenAddress);
    }).toList();

    for (var token in newTokens) {
      final tokenAddress = token['token']['address'];
      final marketCapAndAge = await fetchTokenInfo(tokenAddress);

      final marketCap = marketCapAndAge?.marketCap ?? 0;

      if (marketCapAndAge != null) {
        final int timestamp = marketCapAndAge.creationTimestamp != 0
            ? marketCapAndAge.creationTimestamp
            : marketCapAndAge.openTimestamp;

        final int age =
            DateTime.now().difference(getDateTime(timestamp)).inMinutes;

        if (age <= 100) {
          if (age <= 3 && marketCap <= 100000 && marketCap >= 5000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 1);
          } else if (age <= 5 && marketCap <= 100000 && marketCap >= 10000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 2);
          } else if (age <= 15 && marketCap <= 150000 && marketCap >= 20000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 3);
          } else if (age <= 20 && marketCap <= 200000 && marketCap >= 30000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 4);
          } else if (age <= 30 && marketCap <= 300000 && marketCap >= 50000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 5);
          } else if (age <= 50 && marketCap <= 500000 && marketCap >= 70000) {
            _notifyAndSaveToken(token, marketCapAndAge, tokenAddress, 6);
          }
        }
      }
    }
  }

  Future<void> _notifyAndSaveToken(dynamic token, TokenInfo marketCapAndAge,
      String tokenAddress, int count) async {
    final scamProbability = await analyzeTokenWithAI(token, marketCapAndAge);
    if (int.parse(scamProbability) <= 60) {
      _sentTokens.add(tokenAddress);

      AudioPlayer().play(AssetSource('audio/coll.mp3'), volume: 0.8);
      final chartData = await fetchChartDataMem(tokenAddress);
      final chartImage = await showChartDialog(chartData!, context);

      if (chartImage != null) {
        sendTelegramNotificationMemCoins(
            token, scamProbability, marketCapAndAge, count, chartImage);
      }
    }
  }

  bool _isTokenSent(String tokenAddress) {
    return _sentTokens.contains(tokenAddress);
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
        age = DateTime.now().difference(createdDate).inMinutes;
      }

      if (age >= 60) return false;
    }

    final bool hasEnoughMarketCap = marketCap >= 5000 && marketCap <= 150000;
    final bool hasEnoughLiquidity = liquidity >= 4000;
    final bool hasEnoughVolume24h = volume24h >= 3000;
    final bool hasEnoughHolders = holders >= 35;
    final bool isNotTooOld = age <= 30;

    final bool hasHighVolume24h = buyVolume24h >= 3500 || sellVolume24h >= 3500;
    final bool hasEnoughTraders24h = numTraders24h >= 25;
    final bool hasMoreBuysThanSells24h = numBuys24h > numSells24h;
    final bool hasLowTopHoldersPercentage = topHoldersPercentage <= 30;

    final bool hasGoodOrganicScore = organicScore >= 30;
    final bool hasEnoughOrganicBuyers = organicBuyers24h >= 30;

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

  void dispose() {
    _channel?.sink.close();
    _timer?.cancel();
  }
}
