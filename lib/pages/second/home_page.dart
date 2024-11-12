import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptox/crypto/crypto_page.dart';
import 'package:cryptox/pages/first/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptox/crypto/crypto.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> favoriteCoins = [];
  final email = FirebaseAuth.instance.currentUser?.email;
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool loadingFavorites = true;
  String name = 'username';
  String emailText = 'email';
  double balance = 0.00;

  List<Crypto> _favoriteCryptos = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFavorites();
  }

  Future<void> toggleFavorite(Crypto crypto) async {
    if (user == null) return;

    final userFavRef = _firestore
        .collection('users')
        .doc(user?.email)
        .collection('favorites')
        .doc(crypto.symbol);

    if (_favoriteCryptos.contains(crypto)) {
      await userFavRef.delete();
      setState(() {
        _favoriteCryptos.remove(crypto);
      });
    } else {
      await userFavRef.set({'timestamp': FieldValue.serverTimestamp()});
      setState(() {
        _favoriteCryptos.add(crypto);
      });
    }
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    await prefs.setBool('remember_me', false);
  }

  Future<void> _loadFavorites() async {
    if (user == null) return;

    try {
      final favorites = await _firestore
          .collection('users')
          .doc(user?.email)
          .collection('favorites')
          .get();

      final favoriteCryptos = await Future.wait(
        favorites.docs.map((doc) async {
          final cryptoDoc =
              await _firestore.collection('cryptos').doc(doc.id).get();
          return Crypto.fromJson(cryptoDoc.data()!);
        }),
      );

      setState(() {
        _favoriteCryptos = favoriteCryptos;
        loadingFavorites = false;
      });
    } catch (_) {
      setState(() {
        loadingFavorites = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(user?.email).get();
    final userData = userDoc.data();
    if (userData != null) {
      setState(() {
        name = userData['username'] as String;
        emailText = userData['mail'] as String;
        balance = (userData['balance'] is int)
            ? (userData['balance'] as int).toDouble()
            : userData['balance'] as double;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0A0A),
              const Color(0xFF1A1A1A),
              Colors.black.withBlue(30),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileSection(),
                      const SizedBox(height: 24),
                      _buildBalanceCard(),
                      const SizedBox(height: 24),
                      _buildFavoritesHeader(),
                      const SizedBox(height: 16),
                      _buildFavoritesList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.black.withOpacity(0.7),
      expandedHeight: 60,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
            child: const Text(
              'CryptoX',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF94),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            Colors.black.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7B61FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B61FF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF9C8FFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emailText,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7B61FF).withOpacity(0.2),
              ),
              child: IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  await _clearCredentials();
                  mounted
                      ? Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        )
                      : null;
                },
                icon: const Icon(
                  Icons.logout_outlined,
                  color: Color(0xFF7B61FF),
                  size: 24,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            Colors.black.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00FF94).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF94).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00FF94), Color(0xFF00A3FF)],
            ).createShader(bounds),
            child: const Text(
              'Total Balance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: balance),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00FF94), Color(0xFF00A3FF)],
                ).createShader(bounds),
                child: Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FF94), Color(0xFF00A3FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '+3.28%',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '+\$540 today',
                style: TextStyle(
                  color: Color(0xFF00FF94),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesHeader() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF00FF94), Color(0xFF00A3FF)],
      ).createShader(bounds),
      child: const Text(
        'Favorites',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return loadingFavorites
        ? const Center(child: CircularProgressIndicator())
        : _favoriteCryptos.isEmpty
            ? ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00FF94), Color(0xFF00A3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'No favorites added yet.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : SizedBox(
                height: 300, // Adjust height as needed
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _favoriteCryptos.length,
                  itemBuilder: (context, index) {
                    final crypto = _favoriteCryptos[index];
                    final accentColor = HSLColor.fromAHSL(
                      1.0,
                      ((index * 137.5) % 360),
                      0.7,
                      0.5,
                    ).toColor();

                    return _buildCryptoCard(crypto, accentColor);
                  },
                ),
              );
  }

  Widget _buildCryptoCard(Crypto crypto, Color accentColor) {
    final priceChange = crypto.priceChange24h;
    final isPriceUp = priceChange >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CryptoDetailPage(crypto: crypto, openedFromChatbot: false),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withOpacity(0.2),
                            accentColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: Image.network(
                            crypto.imageUrl,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.currency_bitcoin);
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '#${crypto.marketCapRank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crypto.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        crypto.symbol.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${crypto.currentPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: accentColor.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPriceUp
                              ? [
                                  Colors.green[700]!,
                                  Colors.green[500]!,
                                ]
                              : [
                                  Colors.red[700]!,
                                  Colors.red[500]!,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (isPriceUp ? Colors.green : Colors.red)
                                .withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${isPriceUp ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _favoriteCryptos.contains(crypto)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.yellow,
                  ),
                  onPressed: () => toggleFavorite(crypto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
