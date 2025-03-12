import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../const.dart';
import '../model/token_model.dart';
import '../services/api.dart';
import '../utils.dart';

class TokenPriceMonitorScreen extends StatefulWidget {
  const TokenPriceMonitorScreen({super.key});

  @override
  _TokenPriceMonitorScreenState createState() =>
      _TokenPriceMonitorScreenState();
}

class _TokenPriceMonitorScreenState extends State<TokenPriceMonitorScreen> {
  final TextEditingController _tokenMintController = TextEditingController();
  bool _isMonitoring = false;
  String _status = 'Disconnected';
  double _lastNotifiedMarketCap = 0.0;
  double _marketCap = 0.0;
  double _changeThreshold = 30.0;
  Timer? _monitoringTimer;
  final Map<String, DateTime> _lastNotificationTimes = {};
  final Set<String> _sentNotifications = {};

  @override
  void initState() {
    super.initState();
    _loadChangeThreshold();
  }

  @override
  void dispose() {
    _tokenMintController.dispose();
    _monitoringTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChangeThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _changeThreshold = prefs.getDouble('changeThreshold') ?? 30.0;
    });
  }

  Future<void> _saveChangeThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('changeThreshold', value);
  }

  Future<void> _startMonitoring() async {
    if (_tokenMintController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token mint address')),
      );
      return;
    }

    setState(() {
      _isMonitoring = true;
      _status = 'Monitoring...';
    });

    final initialTokenInfo =
        await fetchTokenInfo(_tokenMintController.text.trim());
    if (initialTokenInfo != null) {
      _lastNotifiedMarketCap = initialTokenInfo.marketCap;
      _marketCap = initialTokenInfo.marketCap;
      _lastNotificationTimes[_tokenMintController.text] = DateTime.now();
    }

    _monitoringTimer =
        Timer.periodic(const Duration(milliseconds: 1), (_) async {
      final tokenAddress = _tokenMintController.text;
      final tokenInfo = await fetchTokenInfo(tokenAddress);

      if (tokenInfo != null) {
        final currentMarketCap = tokenInfo.marketCap;
        setState(() {
          _marketCap = currentMarketCap;
        });

        final marketCapChangePercentage =
            ((currentMarketCap - _lastNotifiedMarketCap) /
                    _lastNotifiedMarketCap) *
                100;

        if (marketCapChangePercentage.abs() >= _changeThreshold) {
          final lastNotificationTime = _lastNotificationTimes[tokenAddress];
          final now = DateTime.now();

          final timeDifference = lastNotificationTime != null
              ? now.difference(lastNotificationTime).inSeconds
              : 0;
          final isWithinFiveMinutes =
              lastNotificationTime == null || timeDifference <= 120;

          if (isWithinFiveMinutes &&
              (lastNotificationTime == null ||
                  now.difference(lastNotificationTime).inSeconds >= 5)) {
            final notificationKey = '$tokenAddress-$currentMarketCap';
            if (!_sentNotifications.contains(notificationKey)) {
              _lastNotificationTimes[tokenAddress] = now;
              _sentNotifications.add(notificationKey);
              _lastNotifiedMarketCap = currentMarketCap;

              await _sendTelegramNotification(tokenInfo,
                  marketCapChangePercentage, now, lastNotificationTime);
              setState(() {
                _status =
                    'Market cap changed by ${marketCapChangePercentage.toStringAsFixed(1)}%! Notification sent.';
              });
            }
          }
        }
      }
    });
  }

  Future<void> _sendTelegramNotification(
      TokenInfo tokenInfo,
      double changePercentage,
      DateTime currentTime,
      DateTime? lastNotificationTime) async {
    try {
      final String symbol = tokenInfo.symbol;
      final String name = tokenInfo.name;
      final String? imageUrl =
          tokenInfo.logo.isNotEmpty ? tokenInfo.logo : null;
      final String tokenAddress = tokenInfo.address;

      final int timestamp = tokenInfo.creationTimestamp != 0
          ? tokenInfo.creationTimestamp
          : tokenInfo.openTimestamp;
      final int age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000))
          .inMinutes;

      final Map<String, String> socialLinks = {};
      final String? discordLink = socialLinks['discord'];
      final String? telegramLink = socialLinks['telegram'];
      final String? twitterLink = socialLinks['twitter'];
      final String? websiteLink = socialLinks['website'];

      String socialLinksString =
          '🔹 *BulX:* ${'https://neo.bullx.io/terminal?chainId=1399811149&address=$tokenAddress'}\n\n';

      if (discordLink?.isNotEmpty ?? false) {
        socialLinksString += '🔹 *Discord:* $discordLink\n';
      }
      if (telegramLink?.isNotEmpty ?? false) {
        socialLinksString += '🔹 *Telegram:* $telegramLink\n';
      }
      if (twitterLink?.isNotEmpty ?? false) {
        socialLinksString += '🔹 *Twitter:* $twitterLink\n';
      }
      if (websiteLink?.isNotEmpty ?? false) {
        socialLinksString += '🔹 *Website:* $websiteLink\n';
      }

      final String changeDirection = changePercentage > 0 ? 'Up' : 'Down';
      final String directionIndicator = changePercentage > 0 ? '📈' : '📉';

      final String timeSinceLastChange = lastNotificationTime != null
          ? formatDuration(currentTime.difference(lastNotificationTime))
          : 'initial change';

      final String caption = '''
*Token Info: $name ($symbol)* 🚀

🔹 *Changed $changeDirection ${changePercentage.abs().toStringAsFixed(1)}% in $timeSinceLastChange!* $directionIndicator
🔹 *Market Cap:* \$${formatMarketCap(tokenInfo.marketCap.toString())}
🔹 *Age:* ${formatAge(age)}
🔹 *Address:* `$tokenAddress`

$socialLinksString

'''
          .trim();

      final String url =
          'https://api.telegram.org/bot$telegramBotToken/sendPhoto';
      final String messageUrl =
          'https://api.telegram.org/bot$telegramBotToken/sendMessage';

      http.Response response;

      if (imageUrl?.isNotEmpty ?? false) {
        final imageResponse = await http.get(Uri.parse(imageUrl!)).timeout(
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

          if (response.statusCode != 200) {
            print(
                "Ошибка отправки фото в Telegram: ${response.statusCode}, ${response.body}");
          }
        } else {
          print(
              "Не удалось загрузить изображение: ${imageResponse.statusCode}, размер: ${imageResponse.bodyBytes.length}");
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
                      setState(() {
                        _changeThreshold = value;
                      });
                      _saveChangeThreshold(value);
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
            TextField(
              controller: _tokenMintController,
              decoration: const InputDecoration(
                labelText: 'Token Mint Address',
                hintText: 'Enter the token mint address',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isMonitoring ? null : _startMonitoring,
              child: const Text('Start Monitoring'),
            ),
            const SizedBox(height: 20),
            Text('Status: $_status',
                style: Theme.of(context).textTheme.bodyMedium),
            Text('Market Cap: ${formatMarketCap(_marketCap.toString())}',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}


