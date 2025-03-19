import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final now = DateTime.now().toUtc();
    final toTimestamp = now.millisecondsSinceEpoch;
    final fromTimestamp = 0; // Using 0 as in the original request

    final url = 'https://gmgn.ai/api/v1/token_candles/sol/$tokenAddress'
        '?device_id=c59b7099-e88b-4429-b966-0639de35fce3'
        '&client_id=gmgn_web_2025.0318.191422'
        '&from_app=gmgn'
        '&app_ver=2025.0318.191422'
        '&tz_name=Asia/Bishkek'
        '&tz_offset=21600'
        '&app_lang=en-US'
        '&resolution=15s'
        '&from=$fromTimestamp'
        '&to=$toTimestamp'
        '&limit=500';

    final headers = {
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'ru,en;q=0.9',
      'cookie': '_ga=GA1.1.1863043302.1732293754; sid=gmgn|da82b3b094181dbad8120c068626ca51; '
          '_ga_UGLVBMV4Z0=GS1.2.1739875344121859.00b3db0581efca8f9b5bff823615579d.'
          'uEE6NQFCK1/E0EADpJ+FUQ==.4QTgtUj3Dzl9RPpPT+BoBw==.R3Mb1P43pTcAINajl++vdw==.'
          'eWgkzJYDdUX13VyUbig4Fw==; '
          '__cf_bm=l3CmUqClfFMU4K1ywRH0LT_g6ivMFCTc.9HFPjIz6Hs-1742332158-1.0.1.1-'
          'wxXwdNdnXWO7l6_BQvWxpHPVqAgYW5Cn52ZyvbgOR2BW70fdjKoLY2yg5hikZ8ctLNkbJAz4.'
          'PXTqRqsCA9BBWiCnzUZQmQWgs4p1vc.L70; '
          'cf_clearance=CwbSQ2qunjQ2gM2vgVrxeCDMwYBudC_cgmAz6DNMmsU-1742332160-1.2.1.1-'
          'tWiQNU783.WXcb0tnsLkL8_cD90yMIvuv08uTUO93NXzWJw4YRQwT9HuLskVvPVhKif9dXgRlGpbLObpCVX.'
          'wndf08bDJvomRep92mkLcpv5fWhr7lGDpdIHrr3MPyrxM.kOrRa6PHLotVQKyJrYrWzFub30_CkPZVv1QY.'
          'lD1G8vjUy6k.xPjD7p21ZV5rmcLoqN4wDOOimtfXHzrchVuWzE6VF_ijDQuwZVxcnpQoJRZPx812x1tP3sVvOvf4Z2x97eCRua8yPc1p5KjOIHAhDgATHQjUlFSVUGCS.'
          'l3IHxheiqmwweCcmcr9gSdBnu_gkj5lpkqG7T_cNy3OzvO9MTF6MNlews_mhQMfE_Uk; '
          '_ga_0XM0LYXGC8=GS1.1.1742332158.94.1.1742332190.0.0.0',
      'priority': 'u=1, i',
      'referer': 'https://gmgn.ai/sol/token/Kf4sQtl9_$tokenAddress',
      'sec-ch-ua': '"Not A(Brand";v="8", "Chromium";v="132", "YaBrowser";v="25.2", "Yowser";v="2.5"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"macOS"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/132.0.0.0 YaBrowser/25.2.0.0 Safari/537.36',
    };

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> candles = data['data']['list'];
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenAddressController,
                    decoration: InputDecoration(
                      labelText: 'Enter Token Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                ElevatedButton(
                  onPressed: () {
                    if (_tokenAddressController.text.isNotEmpty) {
                      setState(() => isLoading = true);
                      fetchChartData(_tokenAddressController.text);
                    }
                  },
                  child: Text('Построить график'),
                ),
              ],
            ),

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
                    closeValueMapper: (ChartModel sales, _) => sales.close,
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
      open: double.parse(json['open']),
      high: double.parse(json['high']),
      low: double.parse(json['low']),
      close: double.parse(json['close']),
    );
  }
}