import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';

import '../const.dart';
import '../model/token_model.dart';
import '../utils.dart';

import 'package:audioplayers/audioplayers.dart';

Future<void> sendTelegramNotificationMem(Map<String, dynamic> pool) async {
  try {
    final percent = await analyzeTokenWithAIMem(pool);
    print(percent);
    if (percent >= 70) return;
    AudioPlayer().play(AssetSource('audio/coll.mp3'), volume: 0.8);

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

Future<void> sendTelegramNotificationMemCoins(
    dynamic token,
    String scamProbability,
    TokenInfo marketCapAndAge,
    int count,
    Uint8List chartImage) async {
  try {
    final String symbol = token['token']['symbol'];
    final String name = token['token']['name'] ?? "Unknown";
    final String liquidity = formatMarketCap(token['liquidity']);
    final String? imageUrl = token['token']['imageThumbUrl'];
    final String tokenAddress = token['token']['address'];
    final String txnCount24 = (token['txnCount24'] ?? 0).toString();
    final String uniqueBuys24 = (token['uniqueBuys24'] ?? 0).toString();
    final String uniqueSells24 = (token['uniqueSells24'] ?? 0).toString();

    final socialLinks = token['token']['socialLinks'] ?? {};
    final String? discordLink = socialLinks['discord'];
    final String? telegramLink = socialLinks['telegram'];
    final String? twitterLink = socialLinks['twitter'];
    final String? websiteLink = socialLinks['website'];

    final int timestamp = marketCapAndAge.creationTimestamp != 0
        ? marketCapAndAge.creationTimestamp
        : marketCapAndAge.openTimestamp;

    final int age = DateTime.now().difference(getDateTime(timestamp)).inMinutes;

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

    final String caption = '''
*Новый токен обнаружен!* 🚀

🔹 *Название:* $name : $scamProbability% scam
🔹 *Символ:* $symbol
🔹 *Маркеткап:* ${formatMarketCap(marketCapAndAge.marketCap.toString())}
🔹 *Возраст:* ${formatAge(age)}
🔹 *Ликвидность:* $liquidity
🔹 *Транзакции:* $txnCount24
🔹 *Уникальные покупки:* $uniqueBuys24
🔹 *Уникальные продажи:* $uniqueSells24
🔹 *Холдеры:* ${token['holders'] ?? 'N/A'}

$count

$socialLinksString

`$tokenAddress`
'''
        .trim();

    final String mediaGroupUrl =
        'https://api.telegram.org/bot$telegramBotToken/sendMediaGroup';
    final String messageUrl =
        'https://api.telegram.org/bot$telegramBotToken/sendMessage';

    http.Response response;

    // Основное изображение
    final String effectiveImageUrl = marketCapAndAge.logo.isNotEmpty
        ? marketCapAndAge.logo
        : imageUrl ?? '';

    if (effectiveImageUrl.isNotEmpty || chartImage.isNotEmpty) {
      var request = http.MultipartRequest('POST', Uri.parse(mediaGroupUrl))
        ..fields['chat_id'] = chatId
        ..fields['media'] = jsonEncode([
          {
            'type': 'photo',
            'media': 'attach://photo1',
            'caption': caption,
            'parse_mode': 'Markdown',
          },
          {
            'type': 'photo',
            'media': 'attach://photo2',
          },
        ]);

      // Добавляем первое изображение (основное)
      if (effectiveImageUrl.isNotEmpty) {
        final imageResponse = await http.get(Uri.parse(effectiveImageUrl));
        if (imageResponse.statusCode == 200 && imageResponse.bodyBytes.isNotEmpty) {
          request.files.add(http.MultipartFile.fromBytes(
            'photo1',
            imageResponse.bodyBytes,
            filename: 'token_$symbol.png',
          ));
        }
      }

      // Добавляем второе изображение (график)
      if (chartImage.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'photo2',
          chartImage,
          filename: 'chart_$symbol.png',
        ));
      }

      final streamedResponse = await request.send();
      response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        print(
            "Ошибка отправки медиагруппы в Telegram: ${response.statusCode}, ${response.body}");
      }
    } else {
      // Если изображений нет, отправляем только текстовое сообщение
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
          "Ошибка отправки сообщения в Telegram: ${response.statusCode}, ${response.body}");
    }
  } catch (e) {
    print("Ошибка при отправке уведомления в Telegram: $e");
  }
}

Future<int> analyzeTokenWithAIMem(pool) async {
  try {
    const modelUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAqWi9myqNVmaClyPhXLgMbveKI9fJAsZs';

    final prompt = '''
Analyze the next token and determine if it is fraudulent. Specify the probability of fraud (0-100%) only the numbers are correct
$pool
''';

    final response = await http.post(
      Uri.parse(modelUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['candidates'] != null && result['candidates'].isNotEmpty) {
        final generatedText =
            result['candidates'][0]['content']['parts'][0]['text'].trim();
        final probability = generatedText.replaceAll(RegExp(r'\D'), '');
        return int.parse(probability);
      }
    }
  } catch (e) {
    print('Error analyzing token with Gemini: $e');
    return 0;
  }

  return 0; // Return default '0' in case of an error or empty response
}

Future<String> analyzeTokenWithAI(
    dynamic token, TokenInfo marketCapAndAge) async {
  if (token == null || token.isEmpty || token.length < 2) return '0';
  try {
    const modelUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAqWi9myqNVmaClyPhXLgMbveKI9fJAsZs';

    final int timestamp = marketCapAndAge.creationTimestamp != 0
        ? marketCapAndAge.creationTimestamp
        : marketCapAndAge.openTimestamp;

    final int age = DateTime.now().difference(getDateTime(timestamp)).inMinutes;

    final prompt = '''
Analyze the next token and determine if it is fraudulent. Specify the probability of fraud (0-100%) only the numbers are correct
- Symbol: ${marketCapAndAge.symbol}
- Name: ${marketCapAndAge.name}
- Address: ${marketCapAndAge.address}
- Market Cap: ${marketCapAndAge.marketCap}
- Liquidity: ${marketCapAndAge.liquidity}
- Holders: ${marketCapAndAge.holderCount}
- 24h Volume: ${marketCapAndAge.price.volume24h}
- 24h Transactions: ${marketCapAndAge.price.swaps24h}
- 24h Unique Buys: ${marketCapAndAge.price.buys24h}
- 24h Unique Sells: ${marketCapAndAge.price.sells24h}
- Age: ${formatAge(age)}
- 24h Price Change: ${marketCapAndAge.price.price24h}
- 24h High: ${marketCapAndAge.price.price24h}
- 24h Low: ${marketCapAndAge.price.price24h}
- Image: ${marketCapAndAge.logo}
- Description: ${token['token']['description']}
- Website: ${token['token']['website']}
- Discord: ${token['token']['socialLinks']['discord']}
- Telegram: ${token['token']['socialLinks']['telegram']}
- Twitter: ${token['token']['socialLinks']['twitter']}
''';

    final response = await http.post(
      Uri.parse(modelUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['candidates'] != null && result['candidates'].isNotEmpty) {
        final generatedText =
            result['candidates'][0]['content']['parts'][0]['text'].trim();
        final probability = generatedText.replaceAll(RegExp(r'\D'), '');
        return probability;
      }
    }
  } catch (e) {
    print('Error analyzing token with Gemini: $e');
    return '0';
  }

  return '0'; // Return default '0' in case of an error or empty response
}

Future<void> fetchTokenData(String tokenAddress) async {
  final url = Uri.parse(
    'https://gmgn.ai/defi/quotation/v1/tokens/sol?device_id=c59b7099-e88b-4429-b966-0639de35fce3&client_id=gmgn_web_2025.0310.180936&from_app=gmgn&app_ver=2025.0310.180936&tz_name=Asia%2FBishkek&tz_offset=21600&app_lang=en-US&token_address=$tokenAddress',
  );

  final headers = {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'ru,en;q=0.9',
    'cookie':
        '_ga=GA1.1.1863043302.1732293754; _ga_0XM0LYXGC8=deleted; sid=gmgn%7Cda82b3b094181dbad8120c068626ca51; _ga_UGLVBMV4Z0=GS1.2.1739875344121859.00b3db0581efca8f9b5bff823615579d.uEE6NQFCK1%2FE0EADpJ%2BFUQ%3D%3D.4QTgtUj3Dzl9RPpPT%2BoBow%3D%3D.R3Mb1P43pTcAINajl%2B%2Bvdw%3D%3D.eWgkzJYDdUX13VyUbig4Fw%3D%3D; cf_clearance=nDc8NVRvVIdm7KYbvfvTVnlEMZOUcek8vPzfmLfhDKE-1741630418-1.2.1.1-9J6FjXQTorFvKNAo9q_LagTyAxvevqWYZI23qN4laNd6.0o5OtT8KcCReAiH0eMighoFfTBKdYwyKd06vT.JfPlnkIaMJTj6ad4VZ_nRRcZCwu1GNqY33WU1SnjLD_kyWksCSocADVLB7Y3lV9JLAfd4hG.rAtFKxO54xUNnLbTMInC2S1e94OY_sqnVkGjjjJc_UOnipBJe3hwJWQdIXmnE3TWaJx49J2qLQjOEuT.qllOqL3ux_IPeXEBRjVs6p9T8wdZeEUrAVIYH3q88vfgfxknbrGSoqwHoAE8F9wCVfYQoeT4bvorzSowvLlso.1IAfrWvEK460IzDkNFE6f1v5EjD4s517nw1OZGtJOI; __cf_bm=XHP55zBc1mXlYXRyy7va2BuvI2ITSschF5bfBdBDD.c-1741639724-1.0.1.1-uBEiSQA4wZVY3BCH_w.nKNSabyZr3v.Si1HXX.kNXfVZYC5U9rwj8MSfCTi9GjNjrdDjyOPdF0AzSvwBGBh7sv4SOxRalI3nYKa6OvyL47c; _ga_0XM0LYXGC8=GS1.1.1741639931.83.1.1741639949.0.0.0',
    'if-none-match': 'W/"192e-nTXDK3kNECqkldbwsQFhf7HuPy8"',
    'priority': 'u=1, i',
    'referer':
        'https://gmgn.ai/sol/token/Kf4sQtl9_4UdXLsCXkcat78UhykL2fq3Xm7cehdSiNifeyRcJpump',
    'sec-ch-ua':
        '"Not A(Brand";v="8", "Chromium";v="132", "YaBrowser";v="25.2", "Yowser";v="2.5"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"macOS"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 YaBrowser/25.2.0.0 Safari/537.36',
  };

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    // Успешный запрос
    final data = json.decode(response.body);
    print(data);
  } else {
    // Обработка ошибок
    print('Ошибка: ${response.statusCode}');
    print('Тело ответа: ${response.body}');
  }
}

Future<void> fetchTokenData1() async {
  // Создаем экземпляр Dio

  try {
    // Выполняем GET запрос
  } catch (e) {
    print('Error occurred: $e');
  }
}

Future<TokenInfo?> fetchTokenInfo(String tokenAddress) async {
  final dio = Dio();
  final url = 'https://gmgn.ai/api/v1/mutil_window_token_info';
  final headers = {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'ru,en;q=0.9',
    'content-type': 'application/json',
    'referer': 'https://gmgn.ai/sol/token/$tokenAddress',
  };
  final params = {
    'from_app': 'gmgn',
    'tz_name': 'Asia/Bishkek',
    'tz_offset': 21600,
    'app_lang': 'en-US',
  };
  final data = {
    'chain': 'sol',
    'addresses': [tokenAddress]
  };

  try {
    final response = await dio.post(
      url,
      queryParameters: params,
      options: Options(headers: headers),
      data: data,
    );
    return TokenInfo.fromJson(response.data['data'][0]);
  } catch (e) {
    print('Error: $e');
  }
  return null;
}

Future<List<dynamic>> fetchTokensTop200() async {
  final dio = Dio();

  final url = 'https://www.defined.fi/api';

  final headers = {
    'content-type': 'application/json',
  };

  final data = {
    "operationName": "FilterTokens",
    "variables": {
      "filters": {
        "volume24": {"lte": 100000000000},
        "liquidity": {"lte": 1000000000},
        "marketCap": {"lte": 1000000000000},
        "createdAt": {"gte": 1741396500},
        "network": [1399811149],
        "trendingIgnored": false,
        "creatorAddress": null,
        "potentialScam": false,
      },
      "statsType": "FILTERED",
      "offset": 0,
      "rankings": [
        {"attribute": "trendingScore24", "direction": "DESC"},
      ],
      "limit": 200,
    },
    "query": """
      query FilterTokens(\$filters: TokenFilters, \$statsType: TokenPairStatisticsType, \$phrase: String, \$tokens: [String], \$rankings: [TokenRanking], \$limit: Int, \$offset: Int) {
        filterTokens(
          filters: \$filters
          statsType: \$statsType
          phrase: \$phrase
          tokens: \$tokens
          rankings: \$rankings
          limit: \$limit
          offset: \$offset
        ) {
          results {
            buyCount1
            buyCount12
            buyCount24
            buyCount4
            uniqueBuys1
            uniqueBuys12
            uniqueBuys24
            uniqueBuys4
            change1
            change12
            change24
            change4
            createdAt
            exchanges {
              address
              name
              tradeUrl
              iconUrl
              __typename
            }
            fdv
            high1
            high12
            high24
            high4
            holders
            lastTransaction
            liquidity
            low1
            low12
            low24
            low4
            marketCap
            pair {
              address
              token0
              token1
              __typename
            }
            quoteToken
            sellCount1
            sellCount12
            sellCount24
            sellCount4
            uniqueSells1
            uniqueSells12
            uniqueSells24
            uniqueSells4
            token {
              address
              name
              symbol
              isScam
              socialLinks {
                discord
                telegram
                twitter
                website
                __typename
              }
              imageThumbUrl
              imageSmallUrl
              imageLargeUrl
              info {
                description
                __typename
              }
              __typename
            }
            txnCount1
            txnCount12
            txnCount24
            txnCount4
            uniqueTransactions1
            uniqueTransactions12
            uniqueTransactions24
            uniqueTransactions4
            volume1
            volume12
            volume24
            volume4
            __typename
          }
          count
          page
          __typename
        }
      }
    """,
  };

  try {
    final response = await dio.post(
      url,
      options: Options(headers: headers),
      data: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return response.data['data']['filterTokens']['results'];
    } else {
      throw Exception("Error: ${response.statusCode}");
    }
  } catch (e) {
    throw Exception("Request failed: $e");
  }
}
