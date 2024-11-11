class Crypto {
  final String name;
  final String symbol;
  final double currentPrice;
  final String imageUrl;
  final double priceChange24h;
  final double priceChangePercentage;
  final double marketCapRank;
  final double high24h;
  final double low24h;
  final double totalVolume;
  final String id;

  Crypto({
    required this.name,
    required this.symbol,
    required this.currentPrice,
    required this.imageUrl,
    required this.priceChange24h,
    required this.priceChangePercentage,
    required this.marketCapRank,
    required this.high24h,
    required this.low24h,
    required this.totalVolume,
    required this.id,
  });

  factory Crypto.fromJson(Map<String, dynamic> json) {
    return Crypto(
      name: json['name'],
      symbol: json['symbol'],
      currentPrice: json['current_price'].toDouble(),
      imageUrl: json['image'],
      priceChange24h: json['price_change_percentage_24h'].toDouble(),
      priceChangePercentage: json['price_change_24h'].toDouble(),
      marketCapRank: json['market_cap_rank'].toDouble(),
      high24h: json['high_24h'].toDouble(),
      low24h: json['low_24h'].toDouble(),
      totalVolume: json['total_volume'].toDouble(),
      id: json['id'],
    );
  }
}
