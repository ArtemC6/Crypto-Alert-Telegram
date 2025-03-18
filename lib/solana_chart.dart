import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TokenChartScreen extends StatefulWidget {
  @override
  _TokenChartScreenState createState() => _TokenChartScreenState();
}

class _TokenChartScreenState extends State<TokenChartScreen> {
  final TextEditingController _tokenAddressController = TextEditingController();
  List<ChartModel> chartData = [];
  bool isLoading = false;

  Future<List<ChartModel>> fetchChartData(String tokenAddress) async {

    final now = DateTime.now().toUtc(); // Текущее время в UTC
    final toTimestamp = now.millisecondsSinceEpoch; // Текущий timestamp в миллисекундах
    final fromTimestamp = toTimestamp - 4500000; // Минус 75 минут

    final url = 'https://datapi.jup.ag/v1/charts/ARc2rBbGxDNHmgM85sUuicBiWdJyBvaUfMxnGVu7gxSq?interval=15_SECOND&baseAsset=$tokenAddress&from=$fromTimestamp&to=$toTimestamp&candles=300&type=mcap';

    https://datapi.jup.ag/v1/charts/BPwZKCvmjuCKC5qtNPh3b7fnSp8mQmAhXhLdac21q873?interval=15_SECOND&baseAsset=CRXdH1ktnrTHmNVc6SBpWWLQKaBrJ7HY9duC5Bdipump&from=1742325800000&to=1742330300000&candles=300&type=mcap


    final headers = {
      'accept': 'application/json',
      'accept-language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
      'origin': 'https://jup.ag',
      'priority': 'u=1, i',
      'referer': 'https://jup.ag/',
      'sec-ch-ua': '"Chromium";v="134", "Not:A-Brand";v="24", "Google Chrome";v="134"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"macOS"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
      'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    };

    // Выполняем запрос
    final response = await http.get(Uri.parse(url), headers: headers);


    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> candles = data['candles'];
      setState(() {
        chartData = candles.map((item) => ChartModel.fromJson(item)).toList();
        isLoading = false;
      });
      return chartData;
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Token Chart'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tokenAddressController,
              decoration: InputDecoration(
                labelText: 'Enter Token Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_tokenAddressController.text.isNotEmpty) {
                  fetchChartData(_tokenAddressController.text);
                }
              },
              child: Text('Построить график'),
            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : Expanded(
                    child: SfCartesianChart(
                      backgroundColor: Colors.black,
                      title: ChartTitle(
                        text: 'Token Price Chart',
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        alignment: ChartAlignment.center,
                        borderWidth: 2.5,
                      ),
                      trackballBehavior: TrackballBehavior(
                        enable: true,
                        activationMode: ActivationMode.singleTap,
                        tooltipAlignment: ChartAlignment.near,
                      ),
                      primaryXAxis: NumericAxis(isVisible: false),
                      zoomPanBehavior: ZoomPanBehavior(
                        enablePinching: true,
                        zoomMode: ZoomMode.xy,
                        selectionRectBorderWidth: 10,
                        enablePanning: true,
                        enableDoubleTapZooming: true,
                        enableMouseWheelZooming: true,
                        enableSelectionZooming: true,
                      ),
                      series: <CandleSeries>[
                        CandleSeries<ChartModel, int>(
                          enableSolidCandles: true,
                          enableTooltip: true,
                          dataSource: chartData,
                          xValueMapper: (ChartModel sales, _) => sales.time,
                          lowValueMapper: (ChartModel sales, _) => sales.low,
                          highValueMapper: (ChartModel sales, _) => sales.high,
                          openValueMapper: (ChartModel sales, _) => sales.open,
                          closeValueMapper: (ChartModel sales, _) =>
                              sales.close,
                          animationDuration: 0,
                        )
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class ChartModel {
  int time;
  double? open;
  double? high;
  double? low;
  double? close;

  ChartModel({required this.time, this.open, this.high, this.low, this.close});

  factory ChartModel.fromJson(Map<String, dynamic> json) {
    return ChartModel(
      time: json['time'],
      open: json['open']?.toDouble(),
      high: json['high']?.toDouble(),
      low: json['low']?.toDouble(),
      close: json['close']?.toDouble(),
    );
  }
}
