import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptox/crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cryptox/crypto/crypto_page.dart';

class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget>
    with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _menuAnimation;
  final CryptoDetailPageState cryptoDetailPageState = CryptoDetailPageState();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<bool> _checkIfCryptoExists(String symbol) async {
    final doc = await _firestore.collection('cryptos').doc(symbol).get();
    return doc.exists;
  }

  Future<Crypto> _fetchCrypto(String symbol) async {
    final doc = await _firestore.collection('cryptos').doc(symbol).get();
    return Crypto(
      name: doc['name'],
      symbol: doc['symbol'],
      currentPrice: doc['current_price'],
      imageUrl: doc['image'],
      priceChange24h: doc['price_change_24h'],
      priceChangePercentage: doc['price_change_percentage_24h'],
      marketCapRank: doc['market_cap_rank'],
      high24h: doc['high_24h'],
      low24h: doc['low_24h'],
      totalVolume: doc['total_volume'],
      id: doc['id'],
    );
  }

  Future<void> _navigateToCryptoPage(String symbol, bool isBuy) async {
    final crypto = await _fetchCrypto(symbol);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CryptoDetailPage(
              crypto: crypto, openedFromChatbot: true, isBuy: isBuy),
        ),
      );
    }
  }

  Future<void> _navigate(String symbol) async {
    final crypto = await _fetchCrypto(symbol);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              CryptoDetailPage(crypto: crypto, openedFromChatbot: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated Menu Items
        if (_isMenuOpen)
          Positioned(
            right: 16,
            bottom: 80, // Adjust based on your bottom nav bar height
            child: FadeTransition(
              opacity: _menuAnimation,
              child: ScaleTransition(
                scale: _menuAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildCommandButton(
                        'Navigate', Icons.navigate_next_outlined, Colors.blue),
                    const SizedBox(height: 8),
                    _buildCommandButton(
                        'Buy', Icons.arrow_upward, Colors.green),
                    const SizedBox(height: 8),
                    _buildCommandButton(
                        'Sell', Icons.arrow_downward, Colors.red),
                  ],
                ),
              ),
            ),
          ),
        // Main Chatbot Button
        Positioned(
          right: 16,
          bottom: 16, // Adjust based on your bottom nav bar height
          child: _buildChatbotButton(),
        ),
      ],
    );
  }

  Widget _buildChatbotButton() {
    return GestureDetector(
      onTap: _toggleMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF000000),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF94).withOpacity(0.3),
              blurRadius: _isMenuOpen ? 20 : 10,
              spreadRadius: _isMenuOpen ? 2 : 1,
            ),
          ],
          border: Border.all(
            color: const Color(0xFF00FF94).withOpacity(0.5),
            width: 2,
          ),
        ),
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 300),
          turns: _isMenuOpen ? 0.125 : 0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Matrix-style background effect
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isMenuOpen ? 0.8 : 0.4,
                child: CustomPaint(
                  size: const Size(60, 60),
                  painter: MatrixRainPainter(),
                ),
              ),
              // Icon
              Icon(
                Icons.smart_toy_outlined,
                color: const Color(0xFF00FF94),
                size: 30,
                shadows: [
                  Shadow(
                    color: const Color(0xFF00FF94).withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandButton(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF000000),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (label == 'Navigate') {
              _showDarkDialog(
                context,
                'Navigate to Crypto',
                'Enter the symbol of the crypto you want to navigate to.',
                Colors.blue[900]!,
                Colors.blue,
                Icon(Icons.search_outlined, color: Colors.blue),
              );
            } else if (label == 'Buy') {
              _showDarkDialog(
                context,
                'Buy Crypto',
                'Enter the symbol of the crypto you want to buy.',
                Colors.green[800]!,
                Colors.green,
                Icon(Icons.shopify_outlined, color: Colors.green),
              );
            } else if (label == 'Sell') {
              _showDarkDialog(
                context,
                'Sell Crypto',
                'Enter the symbol of the crypto you want to sell.',
                Colors.red[800]!,
                Colors.red,
                Icon(Icons.sell_outlined, color: Colors.red),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDarkDialog(BuildContext context, String title, String description,
      Color color, Color borderColor, Icon icon) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          actionsPadding: EdgeInsets.only(right: 16.0, bottom: 8.0),
          title: Row(
            children: [
              icon,
              SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16.0,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.0),
              TextField(
                controller: textController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Symbol',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: color, width: 2.0),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  _checkIfCryptoExists(textController.text.toLowerCase())
                      .then((exists) {
                    if (exists) {
                      if (title == 'Navigate to Crypto') {
                        _navigate(textController.text.toLowerCase());
                      } else if (title == 'Buy Crypto') {
                        _navigateToCryptoPage(
                            textController.text.toLowerCase(), true);
                      } else if (title == 'Sell Crypto') {
                        _navigateToCryptoPage(
                            textController.text.toLowerCase(), false);
                      }
                      _toggleMenu();
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Crypto with symbol ${textController.text.toUpperCase()} does not exist.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid symbol.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                'Submit',
                style: TextStyle(
                  color: color,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Close',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          elevation: 8.0,
        );
      },
    );
  }
}

class MatrixRainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF94).withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw some random vertical lines for matrix effect
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
