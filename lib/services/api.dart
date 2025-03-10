import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';

import '../const.dart';
import '../model/token_model.dart';
import '../utils.dart';

Future<void> sendTelegramNotificationMemCoins(
    dynamic token,
    String scamProbability,
    MarketCapAndAge marketCapAndAge) async {
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

  String socialLinksString = '';

  socialLinksString +=
      '🔹 *BulX:* ${'https://neo.bullx.io/terminal?chainId=1399811149&address=$tokenAddress'}\n\n';

  if (discordLink != null && discordLink.isNotEmpty) {
    socialLinksString += '🔹 *Discord:* $discordLink\n';
  }
  if (telegramLink != null && telegramLink.isNotEmpty) {
    socialLinksString += '🔹 *Telegram:* $telegramLink\n';
  }
  if (twitterLink != null && twitterLink.isNotEmpty) {
    socialLinksString += '🔹 *Twitter:* $twitterLink\n';
  }
  if (websiteLink != null && websiteLink.isNotEmpty) {
    socialLinksString += '🔹 *Website:* $websiteLink\n';
  }

  final String caption = '''
*Новый токен обнаружен!* 🚀

🔹 *Название:* $name : $scamProbability% scam
🔹 *Символ:* $symbol
🔹 *Маркеткап:* ${formatMarketCap(marketCapAndAge.marketCap.toString())}
🔹 *Возраст:* ${formatAge(marketCapAndAge.age)}
🔹 *Ликвидность:* $liquidity
🔹 *Транзакции:* $txnCount24
🔹 *Уникальные покупки:* $uniqueBuys24
🔹 *Уникальные продажи:* $uniqueSells24
🔹 *Холдеры:* ${token['holders'] ?? 'N/A'}

$socialLinksString

`$tokenAddress`
'''
      .trim();

  final String url = 'https://api.telegram.org/bot$telegramBotToken/sendPhoto';
  final String messageUrl =
      'https://api.telegram.org/bot$telegramBotToken/sendMessage';

  try {
    http.Response response;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final imageResponse = await http.get(Uri.parse(imageUrl)).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception("Timeout loading image");
        },
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
          Duration(seconds: 10),
          onTimeout: () {
            print("Тайм-аут при отправке фото в Telegram");
            throw Exception("Timeout sending photo");
          },
        );
        response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          print(
              "Ошибка отправки фото в Telegram: ${response.statusCode}, ${response.body}");
        }
      } else {
        print(
            "Не удалось загрузить изображение: ${imageResponse.statusCode}, размер: ${imageResponse.bodyBytes.length}");
        // Отправляем только текст, если изображение не загружено
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
  } catch (e) {
    print("Ошибка при отправке уведомления в Telegram: $e");
  }
}

Future<String> analyzeTokenWithAI(
    dynamic token, MarketCapAndAge marketCapAndAge) async {
  if (token == null || token.isEmpty || token.length < 2) return '0';
  try {
    const modelUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAqWi9myqNVmaClyPhXLgMbveKI9fJAsZs';

    final prompt = '''
Analyze the next token and determine if it is fraudulent. Specify the probability of fraud (0-100%) only the numbers are correct
- Symbol: ${token['token']['symbol']}
- Name: ${token['token']['name']}
- Address: ${token['token']['address']}
- Market Cap: ${marketCapAndAge.marketCap}
- Liquidity: ${marketCapAndAge.liquidity}
- Holders: ${marketCapAndAge.holders}
- 24h Volume: ${marketCapAndAge.volume24h}
- 24h Transactions: ${token['txnCount24']}
- 24h Unique Buys: ${token['uniqueBuys24']}
- 24h Unique Sells: ${token['uniqueSells24']}
- Age: ${marketCapAndAge.age}
- 24h Price Change: ${token['change24']}
- 24h High: ${token['high24']}
- 24h Low: ${token['low24']}
- Image: ${token['token']['imageThumbUrl']}
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

Future<MarketCapAndAge> fetchDataCoin(String address) async {
  final url = Uri.parse(
      'https://www.dextools.io/shared/data/pair?address=$address&chain=solana&audit=true&locks=true');

  final response = await http.get(
    url,
    headers: {
      'sec-ch-ua-platform': '"macOS"',
      'Referer': 'https://www.dextools.io/app/en/solana/pair-explorer/$address',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Accept': 'application/json',
      'sec-ch-ua':
          '"Not(A:Brand";v="99", "Google Chrome";v="133", "Chromium";v="133"',
      'Content-Type': 'application/json',
      'sec-ch-ua-mobile': '?0',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    try {
      final results = data['data'] as List<dynamic>;

      if (results.isEmpty) {
        print('No results found.');
        return MarketCapAndAge(
          age: 0,
          marketCap: '0',
          tokenName: 'Unknown',
          symbol: 'N/A',
          price: 0.0,
          price24h: 0.0,
          volume24h: 0.0,
          holders: 0,
          liquidity: 0.0,
          creationTime: DateTime.now(),
          fdv: 0.0,
        );
      }

      // Берем первый результат
      final firstResult = results[0];
      return MarketCapAndAge.fromJson(firstResult);
    } catch (e) {
      print('Error fetching market cap and age: $e');
      return MarketCapAndAge(
        age: 0,
        marketCap: '0',
        tokenName: 'Error',
        symbol: 'N/A',
        price: 0.0,
        price24h: 0.0,
        volume24h: 0.0,
        holders: 0,
        liquidity: 0.0,
        creationTime: DateTime.now(),
        fdv: 0.0,
      );
    }
  } else {
    print('Failed to load data: ${response.statusCode}');
    return MarketCapAndAge(
      age: 0,
      marketCap: '0',
      tokenName: 'Unknown',
      symbol: 'N/A',
      price: 0.0,
      price24h: 0.0,
      volume24h: 0.0,
      holders: 0,
      liquidity: 0.0,
      creationTime: DateTime.now(),
      fdv: 0.0,
    );
  }
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
