import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://api.coingecko.com/api/v3';

  Future<List<dynamic>> fetchCryptocurrencies() async {
    final response =
        await http.get(Uri.parse('$baseUrl/coins/markets?vs_currency=usd'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load cryptocurrency data');
    }
  }
}
