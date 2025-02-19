class ChartModel {
  int time;
  double? open;
  double? high;
  double? low;
  double? close;

  ChartModel({required this.time, this.open, this.high, this.low, this.close});

  factory ChartModel.fromJson(List<dynamic> l) {
    return ChartModel(
      time: l[0] is int ? l[0] : int.parse(l[0].toString()), // Убедитесь, что time — это int
      open: l[1] is double ? l[1] : double.tryParse(l[1].toString()), // Преобразуем строку в double
      high: l[2] is double ? l[2] : double.tryParse(l[2].toString()),
      low: l[3] is double ? l[3] : double.tryParse(l[3].toString()),
      close: l[4] is double ? l[4] : double.tryParse(l[4].toString()),
    );
  }
}