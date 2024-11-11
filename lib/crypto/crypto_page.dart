import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptox/crypto/crypto.dart';
import 'package:cryptox/crypto/crypto_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CryptoDetailPage extends StatefulWidget {
  final Crypto crypto;

  const CryptoDetailPage({super.key, required this.crypto});

  @override
  CryptoDetailPageState createState() => CryptoDetailPageState();
}

class CryptoDetailPageState extends State<CryptoDetailPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isByQuantity = true;
  double _currentHolding = 0.0;
  double _tradeAmount = 0.0;

  static const neonGreen = Color(0xFF00FF9F);
  static const neonRed = Color(0xFFFF0055);
  static const neonBlue = Color(0xFF00F0FF);
  static const neonPurple = Color(0xFFBF00FF);
  static const neonPink = Color(0xFFFF00FF);
  static const neonYellow = Color(0xFFFFE500);
  static const darkBackground = Color(0xFF0A0E17);
  static const cardBackground = Color(0xFF1A1E27);
  static const darkCardBackground = Color(0xFF141821);

  @override
  void initState() {
    super.initState();
    _loadCurrentHolding();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentHolding() async {
    try {
      final userEmail = _auth.currentUser?.email;
      if (userEmail != null) {
        final doc = await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('cryptos')
            .doc(widget.crypto.symbol.toLowerCase())
            .get();
        if (doc.exists) {
          setState(() {
            // Convert to double explicitly
            _currentHolding = (doc.data()?['quantity'] ?? 0).toDouble();
          });
        } else {
          setState(() {
            _currentHolding = 0.0;
          });
        }
      }
    } catch (e) {
      setState(() {
        _currentHolding = 0.0;
      });
    }
  }

  Future<double> _getUserBalance() async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return 0.0;

    try {
      final doc = await _firestore.collection('users').doc(userEmail).get();
      // Convert to double explicitly
      return (doc.data()?['balance'] ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _updateUserBalance(double amount, bool isDecrease) async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;

    await _firestore.collection('users').doc(userEmail).update({
      'balance': FieldValue.increment(isDecrease ? -amount : amount),
    });
  }

  Future<void> _updateCryptoHolding(double quantity, bool isBuy) async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;

    final cryptoRef = _firestore
        .collection('users')
        .doc(userEmail)
        .collection('cryptos')
        .doc(widget.crypto.symbol.toLowerCase());

    try {
      final tradeValue = quantity * widget.crypto.currentPrice;

      if (isBuy) {
        await cryptoRef.set({
          'quantity': FieldValue.increment(quantity),
          'symbol': widget.crypto.symbol.toLowerCase(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'totalSpent': FieldValue.increment(tradeValue),
        }, SetOptions(merge: true));
      } else {
        final currentDoc = await cryptoRef.get();
        if (currentDoc.exists) {
          // Convert to double explicitly
          final currentQuantity =
              (currentDoc.data()?['quantity'] ?? 0).toDouble();
          if (quantity >= currentQuantity) {
            await cryptoRef.delete();
          } else {
            await cryptoRef.update({
              'quantity': FieldValue.increment(-quantity),
              'lastUpdated': FieldValue.serverTimestamp(),
              'totalSpent': FieldValue.increment(-tradeValue),
            });
          }
        }
      }
      await _loadCurrentHolding();
    } catch (e) {
      throw Exception('Failed to update crypto holding');
    }
  }

  Future<double> _calculateProfit() async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return 0.0;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('cryptos')
          .doc(widget.crypto.symbol.toLowerCase())
          .get();

      if (doc.exists) {
        // Convert to double explicitly
        final totalSpent = (doc.data()?['totalSpent'] ?? 0).toDouble();
        final currentWorth = _currentHolding * widget.crypto.currentPrice;
        return currentWorth - totalSpent;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _showTradeDialog(bool isBuy) {
    _amountController.clear();
    _tradeAmount = 0.0;

    final primaryColor = isBuy ? neonGreen : neonRed;
    final secondaryColor = isBuy ? neonBlue : neonPink;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                darkCardBackground,
                darkBackground,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: primaryColor.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar at the top
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ).createShader(bounds),
                child: Text(
                  '${isBuy ? 'Buy' : 'Sell'} ${widget.crypto.symbol.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // Toggle chips with gradient background
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: darkCardBackground,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleChip(
                      'By Quantity',
                      _isByQuantity,
                      (selected) {
                        setState(() {
                          _isByQuantity = selected;
                          _amountController.clear();
                          _tradeAmount = 0.0;
                        });
                      },
                      primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildToggleChip(
                      'By Value (\$)',
                      !_isByQuantity,
                      (selected) {
                        setState(() {
                          _isByQuantity = !selected;
                          _amountController.clear();
                          _tradeAmount = 0.0;
                        });
                      },
                      primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              // Enhanced TextField
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: primaryColor.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
                decoration: InputDecoration(
                  labelText:
                      _isByQuantity ? 'Enter Quantity' : 'Enter Value in USD',
                  labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                  hintText: _isByQuantity
                      ? 'Amount in ${widget.crypto.symbol.toUpperCase()}'
                      : 'Amount in USD',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(
                    isBuy
                        ? Icons.add_shopping_cart
                        : Icons.remove_shopping_cart,
                    color: primaryColor,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: darkCardBackground,
                ),
                onChanged: (value) {
                  setState(() {
                    final inputValue = double.tryParse(value) ?? 0.0;
                    if (_isByQuantity) {
                      _tradeAmount = inputValue;
                    } else {
                      _tradeAmount = inputValue / widget.crypto.currentPrice;
                    }
                  });
                },
              ),
              const SizedBox(height: 25),
              // Trade summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: darkCardBackground,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isByQuantity ? 'Total Value:' : 'Quantity:',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ).createShader(bounds),
                      child: Text(
                        _isByQuantity
                            ? '\$${(_tradeAmount * widget.crypto.currentPrice).toStringAsFixed(2)}'
                            : '${_tradeAmount.toStringAsFixed(8)} ${widget.crypto.symbol.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isBuy) ...[
                const SizedBox(height: 20),
                _buildGradientButton(
                  onPressed: () async {
                    if (_currentHolding > 0) {
                      await _processTrade(false, _currentHolding);
                      _loadCurrentHolding();
                    } else {
                      _showErrorDialog(
                        'Insufficient Crypto Balance',
                        'You need to have some ${widget.crypto.symbol.toUpperCase()} to make a sale.',
                      );
                    }
                  },
                  text: 'Sell All',
                  gradient: LinearGradient(
                    colors: [neonRed, neonPink],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildGradientButton(
                onPressed: _tradeAmount > 0
                    ? () async {
                        final success =
                            await _processTrade(isBuy, _tradeAmount);
                        if (success) {
                          _loadCurrentHolding();
                        }
                      }
                    : null,
                text: '${isBuy ? 'Buy' : 'Sell'} Now',
                gradient: LinearGradient(
                  colors: isBuy ? [neonGreen, neonBlue] : [neonRed, neonPink],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: darkCardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: neonRed.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: neonRed.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: neonRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: neonRed,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [neonRed, neonPink],
                ).createShader(bounds),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildGradientButton(
                onPressed: () => Navigator.pop(context),
                text: 'OK',
                gradient: LinearGradient(
                  colors: [neonRed, neonPink],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(bool isBuy, double quantity, double value) {
    final primaryColor = isBuy ? neonGreen : neonRed;
    final secondaryColor = isBuy ? neonBlue : neonPink;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: darkCardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBuy ? Icons.check_circle_outline : Icons.sell,
                  color: primaryColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ).createShader(bounds),
                child: Text(
                  'Transaction Successful',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isBuy ? 'Bought' : 'Sold',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${quantity.toStringAsFixed(8)} ${widget.crypto.symbol.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: primaryColor.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${value.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildGradientButton(
                onPressed: () {
                  Navigator.pop(context); // Close the success dialog
                  Navigator.pop(context); // Close the trade dialog
                },
                text: 'Done',
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _processTrade(bool isBuy, double quantity) async {
    try {
      final userBalance = await _getUserBalance();
      final tradeValue = quantity * widget.crypto.currentPrice;

      if (isBuy) {
        if (userBalance < tradeValue) {
          _showErrorDialog(
            'Insufficient Balance',
            'You need \$${tradeValue.toStringAsFixed(2)} to make this purchase. Your current balance is \$${userBalance.toStringAsFixed(2)}.',
          );
          return false;
        }

        await _updateUserBalance(tradeValue, true);
        await _updateCryptoHolding(quantity, true);
        _showSuccessDialog(
          isBuy,
          quantity,
          tradeValue,
        );
      } else {
        if (_currentHolding < quantity) {
          _showErrorDialog(
            'Insufficient Crypto Balance',
            'You need ${quantity.toStringAsFixed(8)} ${widget.crypto.symbol.toUpperCase()} to make this sale. Your current holding is ${_currentHolding.toStringAsFixed(8)} ${widget.crypto.symbol.toUpperCase()}.',
          );
          return false;
        }

        await _updateUserBalance(tradeValue, false);
        await _updateCryptoHolding(quantity, false);
        _showSuccessDialog(
          isBuy,
          quantity,
          tradeValue,
        );
      }

      await _loadCurrentHolding();
      return true;
    } catch (e) {
      _showErrorDialog(
        e.toString(),
        'An error occurred while processing your transaction. Please try again.',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPriceUp = widget.crypto.priceChange24h >= 0;
    final currencyFormatter =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: darkBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(currencyFormatter, isPriceUp),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildPortfolioCard(),
                    const SizedBox(height: 24),
                    _buildPriceChart(),
                    const SizedBox(height: 24),
                    _buildTradeActions(),
                    const SizedBox(height: 24),
                    _buildMarketStats(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(
    String label,
    bool isSelected,
    Function(bool) onSelected,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.2),
                    primaryColor.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[600]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryColor : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required String text,
    required Gradient gradient,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? gradient
            : LinearGradient(
                colors: [Colors.grey[700]!, Colors.grey[600]!],
              ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: onPressed != null ? Colors.white : Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: onPressed != null
                    ? [
                        Shadow(
                          color: gradient.colors.first.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(NumberFormat formatter, bool isPriceUp) {
    return SliverAppBar.large(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: darkBackground,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: neonBlue),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/app_image.jpg', // Background image
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    darkBackground.withOpacity(0.3),
                    darkBackground.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            // Center-aligned content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Crypto icon with border effect
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: neonPink.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: neonPink.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: cardBackground,
                      backgroundImage: NetworkImage(widget.crypto.imageUrl),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Crypto name and symbol
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [neonPink, neonBlue],
                    ).createShader(bounds),
                    child: Text(
                      widget.crypto.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    widget.crypto.symbol.toUpperCase(),
                    style: TextStyle(
                      color: neonBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: neonBlue.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Current price
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isPriceUp
                          ? [neonGreen, neonBlue]
                          : [neonRed, neonPink],
                    ).createShader(bounds),
                    child: Text(
                      formatter.format(widget.crypto.currentPrice),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPriceChangeChip(isPriceUp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChangeChip(bool isPriceUp) {
    final primaryColor = isPriceUp ? neonGreen : neonRed;
    final secondaryColor = isPriceUp ? neonBlue : neonPink;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.2),
            secondaryColor.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPriceUp ? Icons.arrow_upward : Icons.arrow_downward,
            color: primaryColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [primaryColor, secondaryColor],
            ).createShader(bounds),
            child: Text(
              '${isPriceUp ? '+' : ''}${widget.crypto.priceChange24h.toStringAsFixed(2)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard() {
    return FutureBuilder<double>(
      future: _calculateProfit(),
      builder: (context, snapshot) {
        final profit = snapshot.data ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: neonPurple.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: neonPurple.withOpacity(0.1),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Your Portfolio',
                style: TextStyle(
                  color: neonPurple,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: neonPurple.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_currentHolding.toStringAsFixed(8)} ${widget.crypto.symbol.toUpperCase()}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: neonBlue.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${(_currentHolding * widget.crypto.currentPrice).toStringAsFixed(2)}',
                style: TextStyle(
                  color: neonBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: neonBlue.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profit: \$${profit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: profit >= 0 ? neonGreen : neonRed,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color:
                          (profit >= 0 ? neonGreen : neonRed).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceChart() {
    return CryptoPriceChart(
      cryptoId: widget.crypto.id,
      primaryColor: widget.crypto.priceChange24h >= 0 ? neonGreen : neonRed,
      secondaryColor: widget.crypto.priceChange24h >= 0 ? neonBlue : neonPink,
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeActions() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassButton(
            onPressed: () => _showTradeDialog(true),
            icon: Icons.add_circle_outline,
            label: 'Buy',
            gradient: [
              neonGreen.withOpacity(0.2),
              neonGreen.withOpacity(0.05),
            ],
            borderColor: neonGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassButton(
            onPressed: () => _showTradeDialog(false),
            icon: Icons.remove_circle_outline,
            label: 'Sell',
            gradient: [
              neonRed.withOpacity(0.2),
              neonRed.withOpacity(0.05),
            ],
            borderColor: neonRed,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: borderColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: borderColor.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkCardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: neonYellow.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: neonYellow.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Statistics',
            style: TextStyle(
              color: neonYellow,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: neonYellow.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildStatRow(
              'Market Cap Rank', '#${widget.crypto.marketCapRank}', neonGreen),
          _buildStatRow('24h High', '\$${widget.crypto.high24h}', neonBlue),
          _buildStatRow('24h Low', '\$${widget.crypto.low24h}', neonRed),
          _buildStatRow(
            'Volume',
            '\$${(widget.crypto.totalVolume)}',
            neonPurple,
          ),
        ],
      ),
    );
  }
}
