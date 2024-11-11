import 'dart:math';

import 'package:cryptox/crypto/crypto.dart';
import 'package:cryptox/crypto/crypto_page.dart';
import 'package:cryptox/crypto/portfolio_crypto.dart';
import 'package:cryptox/design/app_colors.dart';
import 'package:cryptox/design/cyber_lines_painter.dart';
import 'package:cryptox/design/grid_painter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  WalletPageState createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
  List<PortfolioItem> _portfolio = [];
  bool _isLoading = true;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  String _searchQuery = '';
  String _sortBy = 'value';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _loadUserPortfolio();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  List<PortfolioItem> get _filteredAndSortedPortfolio {
    // Create a copy of the portfolio to avoid modifying the original
    List<PortfolioItem> filtered = List.from(_portfolio);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.symbol.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort the filtered list
    _sortPortfolio(filtered);

    return filtered;
  }

  void _sortPortfolio(List<PortfolioItem> items) {
    items.sort((a, b) {
      try {
        switch (_sortBy) {
          case 'value':
            final valueA = a.amount * a.currentPrice;
            final valueB = b.amount * b.currentPrice;
            return valueB.compareTo(valueA);

          case 'name':
            final nameCompare =
                a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return nameCompare != 0
                ? nameCompare
                : a.symbol.toLowerCase().compareTo(b.symbol.toLowerCase());

          case 'change':
            // Updated from priceChange24h to percentageChange
            return b.percentageChange.compareTo(a.percentageChange);

          default:
            final valueA = a.amount * a.currentPrice;
            final valueB = b.amount * b.currentPrice;
            return valueB.compareTo(valueA);
        }
      } catch (_) {
        return 0;
      }
    });
  }

  double _calculateChartInterval() {
    final values = _filteredAndSortedPortfolio
        .map((item) => item.amount * item.currentPrice)
        .toList();
    if (values.isEmpty) return 1000;
    final maxValue = values.reduce((max, value) => value > max ? value : max);
    return max(maxValue / 5, 100);
  }

  FlTitlesData _getChartTitles() {
    final filteredPortfolio = _filteredAndSortedPortfolio;
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= filteredPortfolio.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                filteredPortfolio[index].symbol.toUpperCase(),
                style: TextStyle(
                  color: const Color(0xFF00FF9C).withOpacity(0.7),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            );
          },
          reservedSize: 30, // Added fixed reserved size
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            return Text(
              '\$${value.toInt()}',
              style: TextStyle(
                color: const Color(0xFF00FF9C).withOpacity(0.7),
                fontSize: 12,
              ),
            );
          },
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  Future<void> _loadUserPortfolio() async {
    try {
      setState(() => _isLoading = true);

      final userCryptosSnapshot = await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cryptos')
          .get();

      final Map<String, double> symbolToAmount = {};
      final Map<String, double> symbolToTotalSpent = {};
      final Map<String, Crypto> symbolToCrypto = {};

      // First pass: aggregate amounts and total spent for each symbol
      for (var doc in userCryptosSnapshot.docs) {
        final symbol = doc.id;
        final userAmount = (doc.data()['quantity'] as num).toDouble();
        final totalSpent =
            (doc.data()['totalSpent'] as num?)?.toDouble() ?? 0.0;

        symbolToAmount[symbol] = (symbolToAmount[symbol] ?? 0) + userAmount;
        symbolToTotalSpent[symbol] =
            (symbolToTotalSpent[symbol] ?? 0) + totalSpent;
      }

      // Second pass: fetch crypto data
      for (var entry in symbolToAmount.entries) {
        if (entry.value > 0) {
          final cryptoDoc =
              await _firestore.collection('cryptos').doc(entry.key).get();
          if (cryptoDoc.exists) {
            symbolToCrypto[entry.key] = Crypto.fromJson(cryptoDoc.data()!);
          }
        }
      }

      // Create portfolio items with profit calculations
      final List<PortfolioItem> newPortfolio = [];
      for (var entry in symbolToAmount.entries) {
        final symbol = entry.key;
        final amount = entry.value;
        final totalSpent = symbolToTotalSpent[symbol] ?? 0.0;
        final crypto = symbolToCrypto[symbol];

        if (crypto != null && amount > 0) {
          final currentWorth = amount * crypto.currentPrice;
          final profit = currentWorth - totalSpent;
          final profitPercentage =
              totalSpent > 0 ? (profit / totalSpent) * 100 : 0.0;

          newPortfolio.add(PortfolioItem(
            name: crypto.name,
            symbol: symbol,
            amount: amount,
            currentPrice: crypto.currentPrice,
            imageUrl: crypto.imageUrl,
            percentageChange: crypto.priceChange24h,
            priceChangePercentage: crypto.priceChangePercentage,
            marketCap: crypto.marketCapRank,
            high24h: crypto.high24h,
            low24h: crypto.low24h,
            totalVolume: crypto.totalVolume,
            totalSpent: totalSpent,
            profit: profit,
            profitPercentage: profitPercentage,
            id: crypto.id,
          ));
        }
      }

      setState(() {
        _portfolio = newPortfolio;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading portfolio: ${e.toString()}')),
        );
      }
    }
  }

  List<BarChartGroupData> _getChartData() {
    final filteredPortfolio = _filteredAndSortedPortfolio;
    return filteredPortfolio.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final value = item.amount * item.currentPrice;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: value,
            width: 16,
            color: item.percentageChange >= 0
                ? const Color(0xFF00FF9C)
                : const Color(0xFFFF006B),
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                item.percentageChange >= 0
                    ? const Color(0xFF00FF9C)
                    : const Color(0xFFFF006B),
                item.percentageChange >= 0
                    ? const Color(0xFF00BCD4)
                    : const Color(0xFFFF4081),
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPortfolio = _filteredAndSortedPortfolio;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black,
              Color(0xFF0A0E17),
              Color(0xFF141821),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Cyberpunk grid background
            CustomPaint(
              size: Size.infinite,
              painter: GridPainter(),
            ),
            // Main content
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadUserPortfolio,
                backgroundColor: Colors.black,
                color: const Color(0xFF00FF9C),
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    _buildPortfolioValue(),
                    _buildSearchAndSort(),
                    _buildChart(),
                    // Only use one SliverList for the portfolio items
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (_isLoading) {
                            return _buildShimmerItem();
                          }
                          if (index >= filteredPortfolio.length) {
                            return null;
                          }
                          //error here
                          return _buildPortfolioItem(filteredPortfolio[index]);
                        },
                        childCount: _isLoading ? 3 : filteredPortfolio.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Bar with neon glow effect
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.neonGreen.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGreen.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Search assets...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.neonGreen.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Sort Options with improved styling
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortButton(
                    label: 'Value',
                    sortValue: 'value',
                    icon: Icons.attach_money,
                    activeColor: AppColors.neonGreen,
                  ),
                  const SizedBox(width: 12),
                  _buildSortButton(
                    label: 'Name',
                    sortValue: 'name',
                    icon: Icons.sort_by_alpha,
                    activeColor: AppColors.neonBlue,
                  ),
                  const SizedBox(width: 12),
                  _buildSortButton(
                    label: '24h Change',
                    sortValue: 'change',
                    icon: Icons.trending_up,
                    activeColor: AppColors.neonPurple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton({
    required String label,
    required String sortValue,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _sortBy == sortValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = sortValue;
          // Force a resort of the portfolio
          _sortPortfolio(_portfolio);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : activeColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : activeColor.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : activeColor.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00FF9C), Color(0xFF00BCD4), Color(0xFF00FFFF)],
          ).createShader(bounds),
          child: const Text(
            'CRYPTO•WALLET',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 22,
              shadows: [
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 10.0,
                  color: Color(0xFF00FF9C),
                ),
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 20.0,
                  color: Color(0xFF00BCD4),
                ),
              ],
            ),
          ),
        ),
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Color(0xFF0A1014).withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: CyberlinesPainter(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00FFFF).withOpacity(0.3),
                    blurRadius: _glowAnimation.value * 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF00FFFF),
                ),
                onPressed: _loadUserPortfolio,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPortfolioValue() {
    final totalValue = _calculateTotalPortfolioValue();

    return SliverToBoxAdapter(
      child: _isLoading
          ? _buildShimmerValue()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A1014).withOpacity(0.8),
                      Color(0xFF141821).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF00FFFF).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00FFFF).withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL PORTFOLIO VALUE',
                            style: TextStyle(
                              color: Color(0xFF00FFFF),
                              fontSize: 14,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF00FFFF), Color(0xFF00BCD4)],
                            ).createShader(bounds),
                            child: Text(
                              '\$${totalValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildChart() {
    return SliverToBoxAdapter(
      child: _isLoading
          ? _buildShimmerChart()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A1014).withOpacity(0.8),
                      Color(0xFF141821).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF00FFFF).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00FFFF).withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        height: 300,
                        child: BarChart(
                          BarChartData(
                            barGroups: _getChartData(),
                            gridData: FlGridData(
                              show: true,
                              drawHorizontalLine: true,
                              horizontalInterval: _calculateChartInterval(),
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Color(0xFF00FFFF).withOpacity(0.1),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: _getChartTitles(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPortfolioItem(PortfolioItem item) {
    final percentageChangeColor = item.percentageChange >= 0
        ? const Color(0xFF00FF9F)
        : const Color(0xFFFF0055);
    final profitColor =
        item.profit >= 0 ? const Color(0xFF00FF9F) : const Color(0xFFFF0055);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: GestureDetector(
          onTap: () => _navigateToCryptoDetail(item),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.8),
                  const Color(0xFF1A1A3A).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00FF9C).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF9C).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF00FF9C).withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00FF9C),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF00FF9C).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  item.symbol.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF00FF9C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              height: 48,
                              width: 48,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      const Color(0xFF00FF9C).withOpacity(0.7),
                                      const Color(0xFF00BCD4).withOpacity(0.7),
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    '${item.amount.toStringAsFixed(4)} ${item.symbol.toUpperCase()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF00FF9C),
                                    Color(0xFF00BCD4)
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  '\$${(item.amount * item.currentPrice).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: percentageChangeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        percentageChangeColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.percentageChange >= 0
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: percentageChangeColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item.percentageChange.abs().toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: percentageChangeColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: profitColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: profitColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Invested',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '\$${item.totalSpent.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total Profit',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      item.profit >= 0
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: profitColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '\$${item.profit.abs().toStringAsFixed(2)} (${item.profitPercentage.abs().toStringAsFixed(2)}%)',
                                      style: TextStyle(
                                        color: profitColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  void _navigateToCryptoDetail(PortfolioItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CryptoDetailPage(
          crypto: Crypto(
            name: item.name,
            symbol: item.symbol,
            currentPrice: item.currentPrice,
            imageUrl: item.imageUrl,
            priceChange24h: item.percentageChange,
            high24h: item.high24h,
            low24h: item.low24h,
            totalVolume: item.totalVolume,
            marketCapRank: item.marketCap,
            id: item.id,
            priceChangePercentage: item.priceChangePercentage,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerValue() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A3A),
      highlightColor: const Color(0xFF00FF9C).withOpacity(0.1),
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildShimmerChart() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A3A),
      highlightColor: const Color(0xFF00FF9C).withOpacity(0.1),
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A3A),
      highlightColor: const Color(0xFF00FF9C).withOpacity(0.1),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  double _calculateTotalPortfolioValue() {
    return _portfolio.fold(
      0,
      (total, item) => total + (item.amount * item.currentPrice),
    );
  }
}
