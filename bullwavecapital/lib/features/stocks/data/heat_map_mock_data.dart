import 'package:flutter/material.dart';

/// Local mock data for the market heat map — no API integration.
class HeatMapStock {
  final String symbol;
  final String name;
  final double changePercent;
  final double marketCapCr;

  const HeatMapStock({
    required this.symbol,
    required this.name,
    required this.changePercent,
    required this.marketCapCr,
  });

  Color get heatColor {
    final p = changePercent;
    if (p >= 2.0) return const Color(0xFF065F46);
    if (p >= 1.0) return const Color(0xFF10B981);
    if (p >= 0.3) return const Color(0xFF34D399);
    if (p > -0.3) return const Color(0xFF475569);
    if (p > -1.0) return const Color(0xFFF87171);
    if (p > -2.0) return const Color(0xFFEF4444);
    return const Color(0xFF991B1B);
  }

  String get changeLabel {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }
}

class HeatMapMockData {
  HeatMapMockData._();

  static const stocks = [
    HeatMapStock(symbol: 'RELIANCE', name: 'Reliance Industries', changePercent: 1.42, marketCapCr: 1950000),
    HeatMapStock(symbol: 'TCS', name: 'Tata Consultancy', changePercent: 0.68, marketCapCr: 1450000),
    HeatMapStock(symbol: 'INFY', name: 'Infosys', changePercent: -0.24, marketCapCr: 780000),
    HeatMapStock(symbol: 'ICICIBANK', name: 'ICICI Bank', changePercent: 1.85, marketCapCr: 920000),
    HeatMapStock(symbol: 'HDFCBANK', name: 'HDFC Bank', changePercent: 0.92, marketCapCr: 1250000),
    HeatMapStock(symbol: 'SBIN', name: 'State Bank of India', changePercent: -1.12, marketCapCr: 680000),
    HeatMapStock(symbol: 'ADANIENT', name: 'Adani Enterprises', changePercent: -2.34, marketCapCr: 420000),
    HeatMapStock(symbol: 'LT', name: 'Larsen & Toubro', changePercent: 0.45, marketCapCr: 510000),
    HeatMapStock(symbol: 'ITC', name: 'ITC Ltd', changePercent: 0.18, marketCapCr: 580000),
    HeatMapStock(symbol: 'AXISBANK', name: 'Axis Bank', changePercent: -0.76, marketCapCr: 390000),
    HeatMapStock(symbol: 'KOTAKBANK', name: 'Kotak Mahindra Bank', changePercent: 1.05, marketCapCr: 380000),
    HeatMapStock(symbol: 'ULTRACEMCO', name: 'UltraTech Cement', changePercent: 0.55, marketCapCr: 320000),
    HeatMapStock(symbol: 'TATAMOTORS', name: 'Tata Motors', changePercent: 2.18, marketCapCr: 350000),
    HeatMapStock(symbol: 'TITAN', name: 'Titan Company', changePercent: -0.42, marketCapCr: 310000),
    HeatMapStock(symbol: 'ASIANPAINT', name: 'Asian Paints', changePercent: -1.65, marketCapCr: 290000),
    HeatMapStock(symbol: 'NESTLEIND', name: 'Nestlé India', changePercent: 0.31, marketCapCr: 240000),
    HeatMapStock(symbol: 'HCLTECH', name: 'HCL Technologies', changePercent: -0.88, marketCapCr: 460000),
    HeatMapStock(symbol: 'WIPRO', name: 'Wipro', changePercent: -1.42, marketCapCr: 250000),
    HeatMapStock(symbol: 'SUNPHARMA', name: 'Sun Pharma', changePercent: 0.74, marketCapCr: 430000),
    HeatMapStock(symbol: 'BHARTIARTL', name: 'Bharti Airtel', changePercent: 1.28, marketCapCr: 890000),
  ];
}
