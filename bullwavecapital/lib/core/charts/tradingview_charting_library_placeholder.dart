import 'package:flutter/material.dart';

/// Shown when [TradingViewConfig.usesChartingLibrary] is true but JS bridge is not wired.
class TradingViewChartingLibraryPlaceholder extends StatelessWidget {
  final double height;

  const TradingViewChartingLibraryPlaceholder({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF050503),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1a1a18)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'TradingView Charting Library mode\n'
              'Set TRADINGVIEW_CHARTING_LIBRARY_URL and TRADINGVIEW_UDF_BASE_URL\n'
              'then wire UDF endpoints on the backend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
