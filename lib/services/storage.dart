import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  Future<List<String>> loadSelectedCoins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('selectedCoins') ?? [];
  }

  Future<void> saveSelectedCoins(List<String> coins) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedCoins', coins);
  }

  Future<bool> loadSelectedScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isScreen') ?? false;
  }

  Future<void> saveSelectedScreen(bool isScreen) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isScreen', isScreen);
  }

  Future<double> loadPriceChangeThreshold() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('priceChangeThreshold') ?? 1.0;
  }

  Future<void> savePriceChangeThreshold(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('priceChangeThreshold', value);
  }

  Future<void> deleteCoins() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('selectedCoins');
  }
}
