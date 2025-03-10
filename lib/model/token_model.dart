class MarketCapAndAge {
  final int age;
  final String marketCap;
  final String tokenName;
  final String symbol;
  final double price;
  final double price24h;
  final double volume24h;
  final int holders;
  final double liquidity;
  final DateTime creationTime;
  final double fdv;

  MarketCapAndAge({
    required this.age,
    required this.marketCap,
    required this.tokenName,
    required this.symbol,
    required this.price,
    required this.price24h,
    required this.volume24h,
    required this.holders,
    required this.liquidity,
    required this.creationTime,
    required this.fdv,
  });

  factory MarketCapAndAge.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as Map<String, dynamic>? ?? {};
    final token = json['token'] as Map<String, dynamic>? ?? {};
    final tokenMetrics = token['metrics'] as Map<String, dynamic>? ?? {};
    final periodStats = json['periodStats'] as Map<String, dynamic>? ?? {};
    final stats24h = periodStats['24h'] as Map<String, dynamic>? ?? {};

    final creationTime = DateTime.parse(json['creationTime'] as String? ?? DateTime.now().toIso8601String());
    final age = calculateAge(creationTime);

    return MarketCapAndAge(
      age: age,
      marketCap: (tokenMetrics['fdv'] as num?)?.toString() ?? '0',
      tokenName: json['name'] as String? ?? 'Unknown',
      symbol: json['symbol'] as String? ?? 'N/A',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      price24h: (stats24h['price']?['usd']?['first'] as num?)?.toDouble() ?? 0.0,
      volume24h: (stats24h['volume']?['total'] as num?)?.toDouble() ?? 0.0,
      holders: (tokenMetrics['holders'] as int?) ?? 0,
      liquidity: (metrics['liquidity'] as num?)?.toDouble() ?? 0.0,
      creationTime: creationTime,
      fdv: (tokenMetrics['fdv'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

int calculateAge(DateTime creationTime) {
  final now = DateTime.now();
  final difference = now.difference(creationTime);
  return difference.inMinutes;
}