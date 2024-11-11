import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CryptoChartData {
  final DateTime date;
  final double price;

  CryptoChartData(this.date, this.price);
}

class CryptoPriceChart extends StatefulWidget {
  final String cryptoId;
  final Color primaryColor;
  final Color secondaryColor;

  const CryptoPriceChart({
    super.key,
    required this.cryptoId,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<CryptoPriceChart> createState() => _CryptoPriceChartState();
}

class _CryptoPriceChartState extends State<CryptoPriceChart> {
  List<CryptoChartData> chartData = [];
  bool isLoading = true;
  String selectedInterval = '7';

  @override
  void initState() {
    super.initState();
    fetchChartData();
  }

  Future<void> fetchChartData() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(
          'https://api.coingecko.com/api/v3/coins/${widget.cryptoId}/market_chart?vs_currency=usd&days=$selectedInterval'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = List<List<dynamic>>.from(data['prices']);

        chartData = prices.map((price) {
          return CryptoChartData(
            DateTime.fromMillisecondsSinceEpoch(price[0].toInt()),
            price[1].toDouble(),
          );
        }).toList();

        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E27), // cardBackground
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildIntervalSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildIntervalButton('24h', '1'),
        _buildIntervalButton('7d', '7'),
        _buildIntervalButton('30d', '30'),
        _buildIntervalButton('90d', '90'),
      ],
    );
  }

  Widget _buildIntervalButton(String label, String days) {
    final isSelected = selectedInterval == days;

    return GestureDetector(
      onTap: () {
        setState(() => selectedInterval = days);
        fetchChartData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    widget.primaryColor.withOpacity(0.2),
                    widget.secondaryColor.withOpacity(0.2),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? widget.primaryColor
                : widget.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? widget.primaryColor : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= chartData.length || value.toInt() < 0) {
                  return const SizedBox.shrink();
                }

                final date = chartData[value.toInt()].date;
                String text = '';

                if (selectedInterval == '1') {
                  text = '${date.hour}:00';
                } else {
                  text = '${date.day}/${date.month}';
                }

                return Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.price);
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                widget.primaryColor,
                widget.secondaryColor,
              ],
            ),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.primaryColor.withOpacity(0.2),
                  widget.secondaryColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBorder: BorderSide(
              color: widget.primaryColor.withOpacity(0.2),
            ),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = chartData[spot.x.toInt()].date;
                final price = spot.y;

                String dateStr = selectedInterval == '1'
                    ? '${date.hour}:00'
                    : '${date.day}/${date.month}';

                return LineTooltipItem(
                  '$dateStr\n\$${price.toStringAsFixed(2)}',
                  TextStyle(
                    color: widget.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
