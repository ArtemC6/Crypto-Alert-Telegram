import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SelectCoinsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> availableCoins;
  final List<String> selectedCoins;
  final Function(List<String>) onCoinsSelected;

  const SelectCoinsScreen({
    super.key,
    required this.availableCoins,
    required this.selectedCoins,
    required this.onCoinsSelected,
  });

  @override
  _SelectCoinsScreenState createState() => _SelectCoinsScreenState();
}

class _SelectCoinsScreenState extends State<SelectCoinsScreen> {
  late List<String> selectedCoins;
  late List<Map<String, dynamic>> filteredCoins;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    selectedCoins = List.from(widget.selectedCoins);
    filteredCoins = List.from(widget.availableCoins);
  }

  void _onSearchQueryChanged(String query) {
    setState(() {
      searchQuery = query;
      filteredCoins = widget.availableCoins
          .where((coin) => coin['symbol'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Coins ${filteredCoins.length}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search ${selectedCoins.length}',
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchQueryChanged,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredCoins.length,
              itemBuilder: (context, index) {
                final coin = filteredCoins[index];
                return ListTile(
                  title: Text(coin['symbol']),
                  trailing: CupertinoSwitch(
                    activeColor: Colors.deepPurpleAccent,
                    value: selectedCoins.contains(coin['symbol']),
                    onChanged: (bool value) {
                      setState(() {
                        if (value) {
                          selectedCoins.add(coin['symbol']);
                        } else {
                          selectedCoins.remove(coin['symbol']);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                widget.onCoinsSelected(selectedCoins);
                Navigator.pop(context);
              },
              child: Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
