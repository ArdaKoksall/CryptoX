import 'package:flutter/material.dart';
import 'package:cryptox/crypto/crypto.dart';
import 'package:cryptox/crypto/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CryptoProvider extends ChangeNotifier {
  List<Crypto> _allCryptos = [];
  List<Crypto> _filteredCryptos = [];
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const refreshThreshold = Duration(minutes: 3);

  List<Crypto> get allCryptos => _allCryptos;
  List<Crypto> get filteredCryptos => _filteredCryptos;
  bool get isLoading => _isLoading;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();

  Future<void> initializeCryptos() async {
    if (_allCryptos.isNotEmpty && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference < refreshThreshold) {
        return; // Use cached data if it's fresh enough
      }
    }

    await fetchCryptocurrencies();
  }

  Future<void> fetchCryptocurrencies() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      final List<dynamic> cryptoList =
          await _apiService.fetchCryptocurrencies();
      _allCryptos =
          cryptoList.map((crypto) => Crypto.fromJson(crypto)).toList();
      _filteredCryptos = List.from(_allCryptos);
      _lastFetchTime = DateTime.now();

      // Update Firestore in the background
      _updateFirestore();
    } catch (error) {
      // Try to load from Firestore cache if API fails
      await _loadFromFirestore();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateFirestore() async {
    for (var crypto in _allCryptos) {
      await _firestore.collection('cryptos').doc(crypto.symbol).set({
        'name': crypto.name,
        'symbol': crypto.symbol,
        'current_price': crypto.currentPrice,
        'image': crypto.imageUrl,
        'price_change_percentage_24h': crypto.priceChange24h,
        'price_change_24h': crypto.priceChangePercentage,
        'market_cap_rank': crypto.marketCapRank,
        'high_24h': crypto.high24h,
        'low_24h': crypto.low24h,
        'total_volume': crypto.totalVolume,
        'id': crypto.id,
      });
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      final cryptoSnapshot = await _firestore.collection('cryptos').get();
      _allCryptos = cryptoSnapshot.docs
          .map((doc) => Crypto.fromJson(doc.data()))
          .toList();
      _filteredCryptos = List.from(_allCryptos);
    } catch (error) {
      rethrow;
    }
  }

  void filterCryptos(String query) {
    if (query.isEmpty) {
      _filteredCryptos = List.from(_allCryptos);
    } else {
      _filteredCryptos = _allCryptos
          .where((crypto) =>
              crypto.name.toLowerCase().contains(query.toLowerCase()) ||
              crypto.symbol.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  void sortCryptos(String sortBy, bool ascending) {
    switch (sortBy) {
      case 'marketCapRank':
        _filteredCryptos.sort((a, b) => ascending
            ? a.marketCapRank.compareTo(b.marketCapRank)
            : b.marketCapRank.compareTo(a.marketCapRank));
        break;
      case 'name':
        _filteredCryptos.sort((a, b) =>
            ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
        break;
      case 'price':
        _filteredCryptos.sort((a, b) => ascending
            ? a.currentPrice.compareTo(b.currentPrice)
            : b.currentPrice.compareTo(a.currentPrice));
        break;
      case 'change':
        _filteredCryptos.sort((a, b) => ascending
            ? a.priceChange24h.compareTo(b.priceChange24h)
            : b.priceChange24h.compareTo(a.priceChange24h));
        break;
    }
    notifyListeners();
  }
}
