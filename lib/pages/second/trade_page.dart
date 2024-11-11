import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptox/crypto/crypto.dart';
import 'package:cryptox/crypto/crypto_page.dart';
import 'package:cryptox/crypto/crypto_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TradePage extends StatefulWidget {
  const TradePage({super.key});

  @override
  TradePageState createState() => TradePageState();
}

class TradePageState extends State<TradePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Crypto> _filteredCryptos = [];
  final List<Crypto> _allCryptos = [];
  bool _isSearching = false;
  String _sortBy = 'marketCapRank'; // Default sorting method
  bool _ascending = true;
  late AnimationController _refreshIconController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userEmail = FirebaseAuth.instance.currentUser?.email;
  List<Crypto> _favoriteCryptos = [];
  Set<String> _favoriteSymbols = {};
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CryptoProvider>().initializeCryptos();
      _loadFavorites();
    });
  }

  void _onSearchChanged() {
    Provider.of<CryptoProvider>(context, listen: false)
        .filterCryptos(_searchController.text);
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
    });
  }

  Future<void> _loadFavorites() async {
    if (_userEmail == null) return;

    try {
      final favorites = await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('favorites')
          .get();

      setState(() {
        _favoriteSymbols = favorites.docs.map((doc) => doc.id).toSet();
      });

      _favoriteCryptos = [];
      for (String symbol in _favoriteSymbols) {
        final cryptoDoc =
            await _firestore.collection('cryptos').doc(symbol).get();
        if (cryptoDoc.exists) {
          _favoriteCryptos.add(Crypto.fromJson(cryptoDoc.data()!));
        }
      }

      // Sort favorites according to current sorting
      _sortFavorites();
    } catch (_) {}
  }

  void _sortFavorites() {
    final provider = Provider.of<CryptoProvider>(context, listen: false);
    provider.sortCryptos(_sortBy, _ascending);

    // Sort favorites list separately
    switch (_sortBy) {
      case 'marketCapRank':
        _favoriteCryptos.sort((a, b) => _ascending
            ? a.marketCapRank.compareTo(b.marketCapRank)
            : b.marketCapRank.compareTo(a.marketCapRank));
        break;
      case 'name':
        _favoriteCryptos.sort((a, b) => _ascending
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'price':
        _favoriteCryptos.sort((a, b) => _ascending
            ? a.currentPrice.compareTo(b.currentPrice)
            : b.currentPrice.compareTo(a.currentPrice));
        break;
      case 'change':
        _favoriteCryptos.sort((a, b) => _ascending
            ? a.priceChange24h.compareTo(b.priceChange24h)
            : b.priceChange24h.compareTo(a.priceChange24h));
        break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshIconController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(Crypto crypto) async {
    if (_userEmail == null) return;

    final userFavRef = _firestore
        .collection('users')
        .doc(_userEmail)
        .collection('favorites')
        .doc(crypto.symbol);

    setState(() {
      if (_favoriteSymbols.contains(crypto.symbol)) {
        _favoriteSymbols.remove(crypto.symbol);
        _favoriteCryptos.removeWhere((c) => c.symbol == crypto.symbol);
      } else {
        _favoriteSymbols.add(crypto.symbol);
        _favoriteCryptos.add(crypto);
      }

      if (_showFavorites) {
        _sortFavorites();
      }
    });

    if (_favoriteSymbols.contains(crypto.symbol)) {
      await userFavRef.set({'timestamp': FieldValue.serverTimestamp()});
    } else {
      await userFavRef.delete();
    }
  }

  void _sortCryptos(List<Crypto> cryptos) {
    switch (_sortBy) {
      case 'marketCapRank':
        cryptos.sort((a, b) => _ascending
            ? a.marketCapRank.compareTo(b.marketCapRank)
            : b.marketCapRank.compareTo(a.marketCapRank));
        break;
      case 'name':
        cryptos.sort((a, b) => _ascending
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'price':
        cryptos.sort((a, b) => _ascending
            ? a.currentPrice.compareTo(b.currentPrice)
            : b.currentPrice.compareTo(a.currentPrice));
        break;
      case 'change':
        cryptos.sort((a, b) => _ascending
            ? a.priceChange24h.compareTo(b.priceChange24h)
            : b.priceChange24h.compareTo(a.priceChange24h));
        break;
    }
  }

  void _onSort(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _ascending = !_ascending;
      } else {
        _sortBy = sortBy;
        _ascending = true;
      }
    });

    // Use the provider's sorting method
    Provider.of<CryptoProvider>(context, listen: false)
        .sortCryptos(sortBy, _ascending);

    // Sort favorites if showing favorites
    if (_showFavorites) {
      _sortFavorites();
    }
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E1E),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search cryptocurrencies...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.blue[400]),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.blue),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _filteredCryptos = List.from(_allCryptos);
                      _sortCryptos(_filteredCryptos);
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSortingOptions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildSortButton('Rank', 'marketCapRank'),
          _buildSortButton('Name', 'name'),
          _buildSortButton('Price', 'price'),
          _buildSortButton('24h Change', 'change'),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String sortValue) {
    final isSelected = _sortBy == sortValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onSort(sortValue), // Use the _onSort handler
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        Colors.blue[700]!,
                        Colors.blue[500]!,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        const Color(0xFF2A2A2A),
                        const Color(0xFF1E1E1E),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
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
                builder: (context) => CryptoDetailPage(crypto: crypto),
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
                      '\$${crypto.currentPrice.toString()}',
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
                    _favoriteSymbols.contains(crypto.symbol)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.yellow,
                  ),
                  onPressed: () => _toggleFavorite(crypto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Crypto Trading',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showFavorites ? Colors.red : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _showFavorites = !_showFavorites;
              });
            },
          ),
          RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              onPressed: () async {
                _refreshIconController.forward(from: 0.0);
                await Provider.of<CryptoProvider>(context, listen: false)
                    .fetchCryptocurrencies();
                setState(() {
                  _sortBy = 'marketCapRank';
                  _ascending = true;
                });
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSortingOptions(),
          Expanded(
            child: Consumer<CryptoProvider>(
              builder: (context, cryptoProvider, child) {
                if (cryptoProvider.isLoading &&
                    cryptoProvider.allCryptos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading cryptocurrencies...',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final cryptos = _showFavorites
                    ? _favoriteCryptos
                    : cryptoProvider.filteredCryptos;

                if (cryptos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No cryptocurrencies found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Colors.blue,
                  backgroundColor: const Color(0xFF1E1E1E),
                  onRefresh: () async {
                    await Provider.of<CryptoProvider>(context, listen: false)
                        .fetchCryptocurrencies();
                    setState(() {
                      _sortBy = 'marketCapRank';
                      _ascending = true;
                    });
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: _showFavorites
                        ? _favoriteCryptos.length
                        : cryptos.length,
                    itemBuilder: (context, index) {
                      final crypto = _showFavorites
                          ? _favoriteCryptos[index]
                          : cryptos[index];
                      final accentColor = HSLColor.fromAHSL(
                        1.0,
                        (index * 137.5) % 360,
                        0.7,
                        0.5,
                      ).toColor();

                      return _buildCryptoCard(crypto, accentColor);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
