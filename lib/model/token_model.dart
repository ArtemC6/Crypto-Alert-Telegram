class TokenInfo {
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final String logo;
  final String biggestPoolAddress;
  final int openTimestamp;
  final int holderCount;
  final String circulatingSupply;
  final String totalSupply;
  final String maxSupply;
  final String liquidity;
  final int creationTimestamp;
  final PriceInfo price;
  final double marketCap; // Add market cap

  TokenInfo({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.logo,
    required this.biggestPoolAddress,
    required this.openTimestamp,
    required this.holderCount,
    required this.circulatingSupply,
    required this.totalSupply,
    required this.maxSupply,
    required this.liquidity,
    required this.creationTimestamp,
    required this.price,
    required this.marketCap, // Add market cap
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    // Parse circulating supply and price
    final circulatingSupply = double.tryParse(json['circulating_supply'] ?? '0') ?? 0.0;
    final price = double.tryParse(json['price']['price'] ?? '0') ?? 0.0;

    // Calculate market cap
    final marketCap = circulatingSupply * price;

    return TokenInfo(
      address: json['address'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      decimals: json['decimals'] as int? ?? 0,
      logo: json['logo'] as String? ?? '',
      biggestPoolAddress: json['biggest_pool_address'] as String? ?? '',
      openTimestamp: json['open_timestamp'] as int? ?? 0,
      holderCount: json['holder_count'] as int? ?? 0,
      circulatingSupply: json['circulating_supply'] as String? ?? '0',
      totalSupply: json['total_supply'] as String? ?? '0',
      maxSupply: json['max_supply'] as String? ?? '0',
      liquidity: json['liquidity'] as String? ?? '0',
      creationTimestamp: json['creation_timestamp'] as int? ?? 0,
      price: PriceInfo.fromJson(json['price'] as Map<String, dynamic>? ?? {}),
      marketCap: marketCap, // Add calculated market cap
    );
  }
}

class PriceInfo {
  final String address;
  final String price;
  final String price1m;
  final String price5m;
  final String price1h;
  final String price6h;
  final String price24h;
  final int buys1m;
  final int buys5m;
  final int buys1h;
  final int buys6h;
  final int buys24h;
  final int sells1m;
  final int sells5m;
  final int sells1h;
  final int sells6h;
  final int sells24h;
  final String volume1m;
  final String volume5m;
  final String volume1h;
  final String volume6h;
  final String volume24h;
  final String buyVolume1m;
  final String buyVolume5m;
  final String buyVolume1h;
  final String buyVolume6h;
  final String buyVolume24h;
  final String sellVolume1m;
  final String sellVolume5m;
  final String sellVolume1h;
  final String sellVolume6h;
  final String sellVolume24h;
  final int swaps1m;
  final int swaps5m;
  final int swaps1h;
  final int swaps6h;
  final int swaps24h;
  final int hotLevel;

  PriceInfo({
    required this.address,
    required this.price,
    required this.price1m,
    required this.price5m,
    required this.price1h,
    required this.price6h,
    required this.price24h,
    required this.buys1m,
    required this.buys5m,
    required this.buys1h,
    required this.buys6h,
    required this.buys24h,
    required this.sells1m,
    required this.sells5m,
    required this.sells1h,
    required this.sells6h,
    required this.sells24h,
    required this.volume1m,
    required this.volume5m,
    required this.volume1h,
    required this.volume6h,
    required this.volume24h,
    required this.buyVolume1m,
    required this.buyVolume5m,
    required this.buyVolume1h,
    required this.buyVolume6h,
    required this.buyVolume24h,
    required this.sellVolume1m,
    required this.sellVolume5m,
    required this.sellVolume1h,
    required this.sellVolume6h,
    required this.sellVolume24h,
    required this.swaps1m,
    required this.swaps5m,
    required this.swaps1h,
    required this.swaps6h,
    required this.swaps24h,
    required this.hotLevel,
  });

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    return PriceInfo(
      address: json['address'] as String? ?? '',
      price: json['price'] as String? ?? '0',
      price1m: json['price_1m'] as String? ?? '0',
      price5m: json['price_5m'] as String? ?? '0',
      price1h: json['price_1h'] as String? ?? '0',
      price6h: json['price_6h'] as String? ?? '0',
      price24h: json['price_24h'] as String? ?? '0',
      buys1m: json['buys_1m'] as int? ?? 0,
      buys5m: json['buys_5m'] as int? ?? 0,
      buys1h: json['buys_1h'] as int? ?? 0,
      buys6h: json['buys_6h'] as int? ?? 0,
      buys24h: json['buys_24h'] as int? ?? 0,
      sells1m: json['sells_1m'] as int? ?? 0,
      sells5m: json['sells_5m'] as int? ?? 0,
      sells1h: json['sells_1h'] as int? ?? 0,
      sells6h: json['sells_6h'] as int? ?? 0,
      sells24h: json['sells_24h'] as int? ?? 0,
      volume1m: json['volume_1m'] as String? ?? '0',
      volume5m: json['volume_5m'] as String? ?? '0',
      volume1h: json['volume_1h'] as String? ?? '0',
      volume6h: json['volume_6h'] as String? ?? '0',
      volume24h: json['volume_24h'] as String? ?? '0',
      buyVolume1m: json['buy_volume_1m'] as String? ?? '0',
      buyVolume5m: json['buy_volume_5m'] as String? ?? '0',
      buyVolume1h: json['buy_volume_1h'] as String? ?? '0',
      buyVolume6h: json['buy_volume_6h'] as String? ?? '0',
      buyVolume24h: json['buy_volume_24h'] as String? ?? '0',
      sellVolume1m: json['sell_volume_1m'] as String? ?? '0',
      sellVolume5m: json['sell_volume_5m'] as String? ?? '0',
      sellVolume1h: json['sell_volume_1h'] as String? ?? '0',
      sellVolume6h: json['sell_volume_6h'] as String? ?? '0',
      sellVolume24h: json['sell_volume_24h'] as String? ?? '0',
      swaps1m: json['swaps_1m'] as int? ?? 0,
      swaps5m: json['swaps_5m'] as int? ?? 0,
      swaps1h: json['swaps_1h'] as int? ?? 0,
      swaps6h: json['swaps_6h'] as int? ?? 0,
      swaps24h: json['swaps_24h'] as int? ?? 0,
      hotLevel: json['hot_level'] as int? ?? 0,
    );
  }
}