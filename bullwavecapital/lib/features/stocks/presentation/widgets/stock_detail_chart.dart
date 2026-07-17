import 'package:flutter/material.dart';



import '../../../../core/charts/tradingview_chart.dart';

import '../../../../models/stock_model.dart';

import 'chart_interval_selector.dart';



/// Interval label shown in UI → backend candle interval.

const stockChartIntervals = <({String label, String apiInterval})>[

  (label: '1m', apiInterval: '1m'),

  (label: '5m', apiInterval: '5m'),

  (label: '30m', apiInterval: '30m'),

  (label: '1H', apiInterval: '1h'),

  (label: '1D', apiInterval: '1d'),

  (label: '1M', apiInterval: '90d'),

];



class StockDetailChart extends StatelessWidget {

  final String symbol;

  final String exchange;

  final List<CandleModel> candles;

  final bool isLoading;

  final String selectedLabel;

  final ValueChanged<String> onIntervalSelected;



  const StockDetailChart({

    super.key,

    required this.symbol,

    this.exchange = 'NSE',

    required this.candles,

    required this.isLoading,

    required this.selectedLabel,

    required this.onIntervalSelected,

  });



  String get _apiInterval {

    for (final item in stockChartIntervals) {

      if (item.label == selectedLabel) return item.apiInterval;

    }

    return '1d';

  }



  @override

  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        ClipRRect(

          borderRadius: BorderRadius.circular(12),

          child: TradingViewChart(

            symbol: symbol,

            exchange: exchange,

            intervalLabel: selectedLabel,

            apiInterval: _apiInterval,

            fallbackCandles: candles,

            isLoading: isLoading,

            height: 300,

          ),

        ),

        const SizedBox(height: 16),

        ChartIntervalSelector(

          selectedLabel: selectedLabel,

          onSelected: onIntervalSelected,

        ),

      ],

    );

  }

}


