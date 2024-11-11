class PortfolioItem {
  final String name;
  final String symbol;
  final double amount;
  final double currentPrice;
  final String imageUrl;
  final double percentageChange;
  final double priceChangePercentage;
  final double marketCap;
  final double high24h;
  final double low24h;
  final double totalVolume;
  final double totalSpent;
  final double profit;
  final double profitPercentage;
  final String id;

  PortfolioItem({
    required this.name,
    required this.symbol,
    required this.amount,
    required this.currentPrice,
    required this.imageUrl,
    required this.percentageChange,
    required this.priceChangePercentage,
    required this.marketCap,
    required this.high24h,
    required this.low24h,
    required this.totalVolume,
    required this.totalSpent,
    required this.profit,
    required this.profitPercentage,
    required this.id,
  });
}
